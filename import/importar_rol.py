#!/usr/bin/env python3
"""
Importador do rol da Igreja Presbiteriana de Anapolis.
membros_rows.csv (2.622 linhas) -> schema v3 (docs/sql/0001..0012).

Especificacao: doc 13. Decisoes aplicadas: P11a, P12b, P13, P14a, P18a.
Roda UMA vez (doc 13 §2 - o novo sistema substitui o atual, P17).

Uso:
    python importar_rol.py --csv membros_rows.csv --dsn "$DATABASE_URL_UNPOOLED" --validar
    python importar_rol.py --csv membros_rows.csv --dsn "$DATABASE_URL_UNPOOLED" --importar

--validar  le, transforma e relata SEM escrever nada no banco.
--importar executa tudo numa transacao unica; qualquer erro faz ROLLBACK.

IMPORTANTE: use a connection string DIRETA do Neon (sem "-pooler"). Doc 15 §3.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import unicodedata
import uuid
from collections import Counter, defaultdict
from datetime import date, datetime

import psycopg

# ---------------------------------------------------------------- mapeamentos
# Doc 12 §3.4 - 12 valores do CSV para as 10 formas dos Arts. 16 e 17. Sem orfaos.
MEIO_ADMISSAO = {
    "Jurisdição a pedido": "JURISDICAO_A_PEDIDO",
    "Profissão de fé e batismo": "PROFISSAO_FE_E_BATISMO",
    "Transferência": "CARTA_TRANSFERENCIA",
    "Profissão de fé": "PROFISSAO_FE",
    "Batismo infantil": "BATISMO_INFANTIL",
    "Restauração": "RESTAURACAO",
    "Jurisdição sobre os responsáveis": "JURISDICAO_SOBRE_OS_PAIS",
    "Jurisdição ex-offício": "JURISDICAO_EX_OFFICIO",
    "Transferência dos responsáveis": "TRANSFERENCIA_DOS_PAIS",
    "Transferência dos pais": "TRANSFERENCIA_DOS_PAIS",
    "Designação do presbitério": "DESIGNACAO_PRESBITERIO",
}

# Doc 12 §3.5 + P13: "Transferência presbitério" = membro ordenado ministro (CI Art. 23 §3)
MEIO_DEMISSAO = {
    "Exclusão por ausência": "EXCLUSAO_POR_AUSENCIA",
    "Transferência": "CARTA_TRANSFERENCIA",
    "Falecimento": "FALECIMENTO",
    "Jurisdição assumida": "JURISDICAO_ASSUMIDA_POR_OUTRA",
    "Transferência dos responsáveis": "CARTA_TRANSFERENCIA",
    "Transferência conselho": "CARTA_TRANSFERENCIA",
    "Transferência presbitério": "ORDENACAO_AO_MINISTERIO",
    "Solicitação dos responsáveis": "SOLICITACAO_DOS_PAIS",
}

# P11a - formas que so cabem a nao comungante (menor apresentado pelos responsaveis)
FORMAS_NAO_COMUNGANTE = {
    "Batismo infantil",
    "Jurisdição sobre os responsáveis",
    "Transferência dos responsáveis",
    "Transferência dos pais",
}

# Doc 12 §3.2 - a coluna traz tipo de oficio E a distincao de disponibilidade
OFICIAL = {
    "Não oficial": None,
    "Presbítero": ("PRESBITERO_REGENTE", "EM_EXERCICIO"),
    "Presbítero em disponibilidade": ("PRESBITERO_REGENTE", "DISPONIBILIDADE"),
    "Diácono": ("DIACONO", "EM_EXERCICIO"),
}

# P12b - a coluna `situacao` manda sobre data_demissao
SITUACAO = {"Ativo": "ATIVO", "Inativo": "DEMITIDO", "Revisar": "ATIVO"}

SEXO = {"MASCULINO": "M", "FEMININO": "F"}

COLUNAS_ESPERADAS = [
    "id", "numero_ordem", "nome", "foto", "endereco", "complemento", "bairro",
    "cidade", "cep", "telefone", "email", "data_nascimento", "naturalidade",
    "sexo", "estado_civil", "conjuge", "data_casamento", "escolaridade",
    "profissao", "nome_pai", "nome_mae", "id_igreja", "membro", "oficial",
    "data_batismo", "pastor_batismo", "igreja_batismo", "data_profissao_fe",
    "pastor_profissao_fe", "igreja_profissao_fe", "data_admissao",
    "meio_admissao", "data_demissao", "meio_demissao", "situacao",
    "created_at", "updated_at", "ata", "notes", "profissao_informada",
]

# tabelas que o importador escreve — usadas pela checagem de banco vazio e por --limpar
TABELAS_IMPORTADAS = [
    "participante_ato_pastoral", "ato_pastoral", "vinculo_familiar",
    "pessoa_contato", "admissao", "demissao", "oficio", "membro", "pessoa",
]

# descartadas por instrucao do usuario (doc 12 §4)
DESCARTADAS = {"id_igreja", "profissao_informada", "updated_at", "created_at"}


# ------------------------------------------------------------------ utilidades
def g(linha: dict, campo: str) -> str:
    return (linha.get(campo) or "").strip()


def normalizar(nome: str) -> str:
    """minusculas, sem acento, espacos colapsados - para casar nomes."""
    s = unicodedata.normalize("NFKD", nome.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", s).strip()


def parse_data(valor: str, origem: str, erros: list) -> date | None:
    if not valor:
        return None
    try:
        return datetime.strptime(valor[:10], "%Y-%m-%d").date()
    except ValueError:
        erros.append(f"data invalida em {origem}: {valor!r}")
        return None


def primeiro_nome(nome: str) -> str:
    partes = normalizar(nome).split()
    return partes[0] if partes else ""


class Pendencias:
    """Filas de revisao do UC-M1-15. Uma pessoa pode estar em varias."""

    def __init__(self):
        self.por_pessoa: dict[str, set[str]] = defaultdict(set)
        self.contagem: Counter = Counter()

    def add(self, pessoa_id: str, motivo: str) -> None:
        self.por_pessoa[pessoa_id].add(motivo)
        self.contagem[motivo] += 1


# --------------------------------------------------- inferencia de sexo (P18a)
def montar_mapa_sexo(linhas: list[dict], min_ocorrencias: int = 2,
                     confianca: float = 0.90) -> dict[str, str]:
    """
    Constroi prenome -> sexo a partir dos 1.762 registros que JA tem sexo.

    Usar a propria populacao e melhor que lista generica: cobre os nomes que
    realmente ocorrem na IPA e nao inventa regra para nome que nao existe aqui.
    Nomes ambiguos (Darci, Nair, Ariel...) ficam de fora por nao atingirem a
    confianca, e viram pendencia de revisao em vez de chute.

    Parametros calibrados por validacao cruzada em 5 folds sobre os registros
    que tem sexo (doc 17 §3):
        min_oc=3 conf=0.90 -> cobertura 41.1%  acuracia 99.0%
        min_oc=2 conf=0.90 -> cobertura 49.8%  acuracia 99.0%   <- escolhido
        min_oc=1 conf=0.99 -> cobertura 57.8%  acuracia 98.2%
    Mais cobertura pela mesma acuracia. Descer para min_oc=1 troca 8pp de
    cobertura por o dobro de erro, e sexo decide elegibilidade ao oficialato
    (RN-OFI-03) - nao vale.
    """
    contagem: dict[str, Counter] = defaultdict(Counter)
    for linha in linhas:
        sexo = SEXO.get(g(linha, "sexo"))
        pnome = primeiro_nome(g(linha, "nome"))
        if sexo and pnome:
            contagem[pnome][sexo] += 1

    mapa = {}
    for pnome, cont in contagem.items():
        total = sum(cont.values())
        if total < min_ocorrencias:
            continue
        sexo, n = cont.most_common(1)[0]
        if n / total >= confianca:
            mapa[pnome] = sexo
    return mapa


# ----------------------------------------------------------------- leitura
def ler_csv(caminho: str) -> list[dict]:
    with open(caminho, encoding="utf-8-sig", newline="") as fh:
        leitor = csv.DictReader(fh)
        cabecalho = leitor.fieldnames or []
        if cabecalho != COLUNAS_ESPERADAS:
            faltando = set(COLUNAS_ESPERADAS) - set(cabecalho)
            sobrando = set(cabecalho) - set(COLUNAS_ESPERADAS)
            raise SystemExit(
                f"BLOQUEANTE: cabecalho diferente do esperado.\n"
                f"  faltando: {sorted(faltando) or '-'}\n"
                f"  sobrando: {sorted(sobrando) or '-'}"
            )
        return list(leitor)


# ------------------------------------------------------------ transformacao
def transformar(linhas: list[dict]) -> dict:
    """Le o CSV e devolve os registros prontos. Nao toca no banco."""
    erros: list[str] = []
    avisos: Counter = Counter()
    pend = Pendencias()
    mapa_sexo = montar_mapa_sexo(linhas)

    pessoas, contatos, membros = [], [], []
    admissoes, demissoes, oficios = [], [], []
    atos, participantes = [], []
    # (nome normalizado) -> [pessoa_id]  para casar vinculos familiares
    indice_nome: dict[str, list[str]] = defaultdict(list)
    dados_vinculo = []  # (pessoa_id, campo, valor) resolvido na 2a passada

    numeros_rol = set()

    for i, linha in enumerate(linhas, start=2):  # 2 = 1a linha de dados
        ctx = f"linha {i}"
        pessoa_id = str(uuid.uuid4())
        membro_id = str(uuid.uuid4())

        nome = g(linha, "nome")
        if not nome:
            erros.append(f"{ctx}: nome vazio")
            continue

        # ---------- valores categoricos (desconhecido = BLOQUEANTE, doc 13 §5)
        v_membro = g(linha, "membro")
        if v_membro not in ("", "Comungante", "Não comungante", "Não membro"):
            erros.append(f"{ctx}: valor desconhecido em `membro`: {v_membro!r}")
        v_oficial = g(linha, "oficial")
        if v_oficial not in OFICIAL:
            erros.append(f"{ctx}: valor desconhecido em `oficial`: {v_oficial!r}")
        v_situacao = g(linha, "situacao")
        if v_situacao not in SITUACAO:
            erros.append(f"{ctx}: valor desconhecido em `situacao`: {v_situacao!r}")
        v_meio_adm = g(linha, "meio_admissao")
        if v_meio_adm and v_meio_adm not in MEIO_ADMISSAO:
            erros.append(f"{ctx}: valor desconhecido em `meio_admissao`: {v_meio_adm!r}")
        v_meio_dem = g(linha, "meio_demissao")
        if v_meio_dem and v_meio_dem not in MEIO_DEMISSAO:
            erros.append(f"{ctx}: valor desconhecido em `meio_demissao`: {v_meio_dem!r}")
        if erros:
            continue

        # ---------- datas
        d_nasc = parse_data(g(linha, "data_nascimento"), f"{ctx}/nascimento", erros)
        d_batismo = parse_data(g(linha, "data_batismo"), f"{ctx}/batismo", erros)
        d_prof = parse_data(g(linha, "data_profissao_fe"), f"{ctx}/profissao_fe", erros)
        d_adm = parse_data(g(linha, "data_admissao"), f"{ctx}/admissao", erros)
        d_dem = parse_data(g(linha, "data_demissao"), f"{ctx}/demissao", erros)
        d_casam = parse_data(g(linha, "data_casamento"), f"{ctx}/casamento", erros)

        # ---------- sexo (P18a)
        sexo = SEXO.get(g(linha, "sexo"))
        sexo_inferido = False
        if sexo is None:
            palpite = mapa_sexo.get(primeiro_nome(nome))
            if palpite:
                sexo, sexo_inferido = palpite, True
                # ~1% de erro esperado. Sexo decide elegibilidade ao oficialato
                # (RN-OFI-03), entao vai para a fila - em raia propria, para nao
                # se misturar com quem esta simplesmente sem sexo.
                pend.add(pessoa_id, "sexo inferido, a confirmar")
            else:
                pend.add(pessoa_id, "sem sexo")

        # ---------- categoria (P11a)
        if v_membro == "Comungante":
            categoria, cat_inferida = "COMUNGANTE", False
        elif v_membro == "Não comungante":
            categoria, cat_inferida = "NAO_COMUNGANTE", False
        else:  # vazio ou "Não membro" -> inferir pela forma de admissao
            if v_meio_adm in FORMAS_NAO_COMUNGANTE:
                categoria, cat_inferida = "NAO_COMUNGANTE", True
            elif v_meio_adm:
                categoria, cat_inferida = "COMUNGANTE", True
            else:
                categoria, cat_inferida = "NAO_DEFINIDO", False
                pend.add(pessoa_id, "sem categoria (NAO_DEFINIDO)")
            if cat_inferida:
                pend.add(pessoa_id, "categoria inferida, a confirmar")

        # ---------- situacao (P12b: a coluna `situacao` manda)
        situacao = SITUACAO[v_situacao]
        if v_situacao == "Revisar":
            pend.add(pessoa_id, "marcado 'Revisar' no legado")
        # doc 13 §6.2 - ATIVO com data de demissao e contradicao direta
        if situacao == "ATIVO" and d_dem:
            pend.add(pessoa_id, "ativo com data de demissao")
        # doc 13 §6.1 - DEMITIDO sem nenhum dado de demissao: nao ha evento a criar
        if situacao == "DEMITIDO" and not d_dem and not v_meio_dem:
            pend.add(pessoa_id, "demitido sem evento de demissao")
        # 'Não membro' marcado como ativo e contraditorio (23 casos)
        if v_membro == "Não membro" and situacao == "ATIVO":
            pend.add(pessoa_id, "'Nao membro' com situacao Ativo")

        # ---------- numero de rol (P14a: preservar como texto)
        numero_rol = g(linha, "numero_ordem") or None
        if numero_rol:
            if numero_rol in numeros_rol:
                erros.append(f"{ctx}: numero_ordem duplicado: {numero_rol}")
            numeros_rol.add(numero_rol)

        notes = g(linha, "notes")
        if notes:
            pend.add(pessoa_id, "tem anotacao em `notes`")

        pessoas.append({
            "id": pessoa_id,
            "nome_completo": nome,
            "data_nascimento": d_nasc,
            "sexo": sexo,
            "sexo_inferido": sexo_inferido,
            "naturalidade": g(linha, "naturalidade") or None,
            "estado_civil": g(linha, "estado_civil") or None,
            "logradouro": g(linha, "endereco") or None,
            "complemento": g(linha, "complemento") or None,
            "bairro": g(linha, "bairro") or None,
            "cidade": g(linha, "cidade") or None,
            "cep": g(linha, "cep") or None,
            "profissao": g(linha, "profissao") or None,
            "escolaridade": g(linha, "escolaridade") or None,
            "data_casamento": d_casam,
            # falecimento vem da demissao por falecimento
            "data_falecimento": d_dem if v_meio_dem == "Falecimento" else None,
            "foto_url": g(linha, "foto") or None,
            "observacoes": notes or None,
            "id_legado": g(linha, "id"),
        })
        indice_nome[normalizar(nome)].append(pessoa_id)

        for campo, tipo in (("telefone", "TELEFONE"), ("email", "EMAIL")):
            valor = g(linha, campo)
            if valor:
                contatos.append({"pessoa_id": pessoa_id, "tipo": tipo,
                                 "valor": valor, "principal": True})

        for campo in ("conjuge", "nome_pai", "nome_mae"):
            valor = g(linha, campo)
            if valor:
                dados_vinculo.append((pessoa_id, campo, valor))

        membros.append({
            "id": membro_id,
            "pessoa_id": pessoa_id,
            "numero_rol": numero_rol,
            "categoria": categoria,
            "categoria_inferida": cat_inferida,
            "situacao": situacao,
            "data_batismo": d_batismo,
            "data_profissao_fe": d_prof,
            "data_admissao": d_adm,
            "data_demissao": d_dem,
            "ata_admissao_legado": g(linha, "ata") or None,
            "id_legado": g(linha, "id"),
        })

        # ---------- admissao (doc 13 §4.5): basta ter data OU meio
        if d_adm or v_meio_adm:
            if not v_meio_adm:
                pend.add(pessoa_id, "admissao sem forma registrada")
            if not d_adm:
                pend.add(pessoa_id, "admissao sem data")
            admissoes.append({
                "membro_id": membro_id,
                "data": d_adm,
                # `forma` e NOT NULL. Quando o legado nao registrou, arbitramos a
                # forma dominante e MARCAMOS — sem forma_arbitrada, essas 8 linhas
                # ficariam indistinguiveis de uma jurisdicao a pedido real.
                "forma": MEIO_ADMISSAO.get(v_meio_adm) or "JURISDICAO_A_PEDIDO",
                "forma_arbitrada": not v_meio_adm,
                "observacoes": None if v_meio_adm else "forma nao registrada no legado",
                "igreja_origem_nome": (g(linha, "igreja_profissao_fe")
                                       or g(linha, "igreja_batismo") or None),
            })

        # ---------- demissao: so com data (doc 13 §6.1)
        if d_dem:
            demissoes.append({
                "membro_id": membro_id,
                "data": d_dem,
                "forma": MEIO_DEMISSAO.get(v_meio_dem) or "EXCLUSAO_A_PEDIDO",
                "forma_arbitrada": not v_meio_dem,
                "motivo": None if v_meio_dem else "forma nao registrada no legado",
            })
            if not v_meio_dem:
                pend.add(pessoa_id, "demissao sem forma registrada")

        # ---------- oficio (doc 12 §3.2)
        info = OFICIAL[v_oficial]
        if info:
            tipo_of, sit_of = info
            oficios.append({"pessoa_id": pessoa_id, "tipo": tipo_of, "situacao": sit_of})

        # ---------- atos pastorais (doc 13 §4.8)
        if d_batismo:
            if d_nasc:
                infantil = (d_batismo - d_nasc).days < 18 * 365.25
                tipo_ato = "BATISMO_INFANTIL" if infantil else "BATISMO_ADULTO"
            else:
                tipo_ato = "BATISMO_ADULTO"
                pend.add(pessoa_id, "tipo de batismo indeduzivel (sem nascimento)")
            ato_id = str(uuid.uuid4())
            atos.append({
                "id": ato_id, "tipo": tipo_ato, "data": d_batismo,
                "oficiante_nome_externo": g(linha, "pastor_batismo") or "nao registrado",
                "igreja_externa_nome": g(linha, "igreja_batismo") or None,
                "inferido": True,
            })
            participantes.append({"ato_pastoral_id": ato_id, "pessoa_id": pessoa_id,
                                  "papel": "BATIZANDO"})

        if d_prof:
            ato_id = str(uuid.uuid4())
            atos.append({
                "id": ato_id, "tipo": "PROFISSAO_DE_FE", "data": d_prof,
                "oficiante_nome_externo": g(linha, "pastor_profissao_fe") or "nao registrado",
                "igreja_externa_nome": g(linha, "igreja_profissao_fe") or None,
                "inferido": False,
            })
            participantes.append({"ato_pastoral_id": ato_id, "pessoa_id": pessoa_id,
                                  "papel": "PROFITENTE"})

    # ---------- 2a passada: vinculos familiares (doc 13 §4.9)
    vinculos, textos_pessoa = [], defaultdict(dict)
    pares_conjuge: set[frozenset] = set()
    TIPO = {"conjuge": "CONJUGE", "nome_pai": "PAI", "nome_mae": "MAE"}
    COLUNA_TEXTO = {"conjuge": "nome_conjuge_texto", "nome_pai": "nome_pai_texto",
                    "nome_mae": "nome_mae_texto"}

    for pessoa_id, campo, valor in dados_vinculo:
        candidatos = [p for p in indice_nome.get(normalizar(valor), []) if p != pessoa_id]
        if len(candidatos) == 1:
            alvo = candidatos[0]
            if campo == "conjuge":
                par = frozenset((pessoa_id, alvo))
                if par in pares_conjuge:
                    continue
                pares_conjuge.add(par)
            vinculos.append({"pessoa_id": pessoa_id, "relacionado_id": alvo,
                             "tipo": TIPO[campo]})
            avisos[f"vinculo {TIPO[campo]} casado por nome"] += 1
        else:
            textos_pessoa[pessoa_id][COLUNA_TEXTO[campo]] = valor
            if len(candidatos) > 1:
                pend.add(pessoa_id, "vinculo familiar ambiguo (homonimos)")
                avisos[f"vinculo {TIPO[campo]} ambiguo"] += 1
            else:
                avisos[f"vinculo {TIPO[campo]} nao encontrado (guardado como texto)"] += 1

    # ---------- nomes duplicados
    for nome_norm, ids in indice_nome.items():
        if len(ids) > 1:
            for pid in ids:
                pend.add(pid, "nome duplicado")

    for p in pessoas:
        for coluna, valor in textos_pessoa.get(p["id"], {}).items():
            p[coluna] = valor
        motivos = sorted(pend.por_pessoa.get(p["id"], ()))
        p["pendencia_motivos"] = motivos
        p["pendencia_revisao"] = bool(motivos)
    for m in membros:
        m["pendencia_revisao"] = bool(pend.por_pessoa.get(m["pessoa_id"]))

    return {
        "erros": erros, "avisos": avisos, "pendencias": pend,
        "pessoas": pessoas, "contatos": contatos, "membros": membros,
        "admissoes": admissoes, "demissoes": demissoes, "oficios": oficios,
        "atos": atos, "participantes": participantes, "vinculos": vinculos,
        "mapa_sexo": mapa_sexo,
    }


# ---------------------------------------------------------------- persistencia
def gravar(conn: psycopg.Connection, d: dict) -> None:
    cur = conn.cursor()

    cur.executemany(
        """INSERT INTO pessoa (id, nome_completo, data_nascimento, sexo, sexo_inferido,
             naturalidade, estado_civil, logradouro, complemento, bairro, cidade, cep,
             profissao, escolaridade, nome_pai_texto, nome_mae_texto, nome_conjuge_texto,
             data_casamento, data_falecimento, foto_url, observacoes, pendencia_revisao,
             pendencia_motivos, id_legado)
           VALUES (%(id)s, %(nome_completo)s, %(data_nascimento)s, %(sexo)s,
             %(sexo_inferido)s, %(naturalidade)s, %(estado_civil)s, %(logradouro)s,
             %(complemento)s, %(bairro)s, %(cidade)s, %(cep)s, %(profissao)s,
             %(escolaridade)s, %(nome_pai_texto)s, %(nome_mae_texto)s,
             %(nome_conjuge_texto)s, %(data_casamento)s, %(data_falecimento)s,
             %(foto_url)s, %(observacoes)s, %(pendencia_revisao)s,
             %(pendencia_motivos)s, %(id_legado)s)""",
        [{**{c: None for c in ("nome_pai_texto", "nome_mae_texto", "nome_conjuge_texto")},
          **p} for p in d["pessoas"]])

    cur.executemany(
        """INSERT INTO pessoa_contato (pessoa_id, tipo, valor, principal)
           VALUES (%(pessoa_id)s, %(tipo)s, %(valor)s, %(principal)s)""", d["contatos"])

    cur.executemany(
        """INSERT INTO membro (id, pessoa_id, numero_rol, categoria, categoria_inferida,
             situacao, pendencia_revisao, data_batismo, data_profissao_fe, data_admissao,
             data_demissao, ata_admissao_legado, id_legado)
           VALUES (%(id)s, %(pessoa_id)s, %(numero_rol)s, %(categoria)s,
             %(categoria_inferida)s, %(situacao)s, %(pendencia_revisao)s, %(data_batismo)s,
             %(data_profissao_fe)s, %(data_admissao)s, %(data_demissao)s,
             %(ata_admissao_legado)s, %(id_legado)s)""", d["membros"])

    cur.executemany(
        """INSERT INTO admissao (membro_id, data, forma, forma_arbitrada, observacoes,
             igreja_origem_nome, origem_migracao)
           VALUES (%(membro_id)s, %(data)s, %(forma)s, %(forma_arbitrada)s,
             %(observacoes)s, %(igreja_origem_nome)s, true)""", d["admissoes"])

    cur.executemany(
        """INSERT INTO demissao (membro_id, data, forma, forma_arbitrada, motivo,
             origem_migracao)
           VALUES (%(membro_id)s, %(data)s, %(forma)s, %(forma_arbitrada)s,
             %(motivo)s, true)""", d["demissoes"])

    cur.executemany(
        """INSERT INTO oficio (pessoa_id, tipo, situacao, origem_migracao)
           VALUES (%(pessoa_id)s, %(tipo)s, %(situacao)s, true)""", d["oficios"])

    cur.executemany(
        """INSERT INTO ato_pastoral (id, tipo, data, oficiante_nome_externo,
             igreja_externa_nome, inferido, origem_migracao)
           VALUES (%(id)s, %(tipo)s, %(data)s, %(oficiante_nome_externo)s,
             %(igreja_externa_nome)s, %(inferido)s, true)""", d["atos"])

    cur.executemany(
        """INSERT INTO participante_ato_pastoral (ato_pastoral_id, pessoa_id, papel)
           VALUES (%(ato_pastoral_id)s, %(pessoa_id)s, %(papel)s)""", d["participantes"])

    cur.executemany(
        """INSERT INTO vinculo_familiar (pessoa_id, relacionado_id, tipo)
           VALUES (%(pessoa_id)s, %(relacionado_id)s, %(tipo)s)
           ON CONFLICT DO NOTHING""", d["vinculos"])


def banco_ja_populado(conn: psycopg.Connection) -> dict[str, int]:
    """Conta o que ja existe nas tabelas que este script escreve."""
    cur = conn.cursor()
    existente = {}
    for tabela in TABELAS_IMPORTADAS:
        n = cur.execute(f"SELECT count(*) FROM {tabela}").fetchone()[0]
        if n:
            existente[tabela] = n
    return existente


def limpar(conn: psycopg.Connection) -> None:
    """
    Zera as tabelas do importador. TRUNCATE ... CASCADE porque as FKs entre elas
    sao circulares na pratica (admissao -> ato_pastoral -> pessoa).

    CASCADE tambem esvazia qualquer OUTRA tabela que referencie estas — reuniao,
    eleicao, presenca etc. Isso e seguro enquanto so houver dados de importacao,
    que e o caso ate a Entrega C do doc 18. Depois disso, NAO use --limpar:
    reimportar passa a destruir atas e resolucoes de verdade.
    """
    conn.cursor().execute(f"TRUNCATE {', '.join(TABELAS_IMPORTADAS)} CASCADE")


def conferir(conn: psycopg.Connection, d: dict) -> list[tuple[str, int, int]]:
    """Doc 13 §7 - roda ANTES do commit. Discrepancia = ROLLBACK."""
    cur = conn.cursor()
    esperado = [
        ("pessoa", "SELECT count(*) FROM pessoa", len(d["pessoas"])),
        ("membro", "SELECT count(*) FROM membro", len(d["membros"])),
        ("pessoa_contato", "SELECT count(*) FROM pessoa_contato", len(d["contatos"])),
        ("admissao", "SELECT count(*) FROM admissao", len(d["admissoes"])),
        ("demissao", "SELECT count(*) FROM demissao", len(d["demissoes"])),
        ("oficio", "SELECT count(*) FROM oficio", len(d["oficios"])),
        ("ato_pastoral", "SELECT count(*) FROM ato_pastoral", len(d["atos"])),
        ("participante", "SELECT count(*) FROM participante_ato_pastoral",
         len(d["participantes"])),
    ]
    falhas = []
    for nome, sql, alvo in esperado:
        obtido = cur.execute(sql).fetchone()[0]
        if obtido != alvo:
            falhas.append((nome, alvo, obtido))
    return falhas


# ---------------------------------------------------------------- relatorio
def relatar(d: dict) -> None:
    p = print
    p("\n" + "=" * 66)
    p("REGISTROS A CRIAR")
    p("=" * 66)
    for rotulo, chave in (("pessoa", "pessoas"), ("membro", "membros"),
                          ("pessoa_contato", "contatos"), ("admissao", "admissoes"),
                          ("demissao", "demissoes"), ("oficio", "oficios"),
                          ("ato_pastoral", "atos"),
                          ("participante_ato_pastoral", "participantes"),
                          ("vinculo_familiar", "vinculos")):
        p(f"  {rotulo:28s} {len(d[chave]):6d}")

    cat = Counter(m["categoria"] for m in d["membros"])
    sit = Counter(m["situacao"] for m in d["membros"])
    p("\n  categoria:  " + "  ".join(f"{k}={v}" for k, v in cat.most_common()))
    p("  situacao:   " + "  ".join(f"{k}={v}" for k, v in sit.most_common()))
    p(f"  categoria inferida (P11a):  {sum(m['categoria_inferida'] for m in d['membros'])}")
    p(f"  sexo inferido (P18a):       {sum(p_['sexo_inferido'] for p_ in d['pessoas'])}")
    p(f"  sem sexo apos inferencia:   {sum(1 for p_ in d['pessoas'] if not p_['sexo'])}")

    ofc = Counter((o["tipo"], o["situacao"]) for o in d["oficios"])
    p("\n  oficios:")
    for (t, s), n in sorted(ofc.items()):
        p(f"    {t:20s} {s:16s} {n:4d}")

    p("\n" + "=" * 66)
    p(f"FILAS DE REVISAO  ({len(d['pendencias'].por_pessoa)} pessoas, "
      f"{sum(d['pendencias'].contagem.values())} itens)")
    p("=" * 66)
    for motivo, n in d["pendencias"].contagem.most_common():
        p(f"  {n:6d}  {motivo}")

    p("\n" + "-" * 66)
    p("AVISOS")
    for aviso, n in d["avisos"].most_common():
        p(f"  {n:6d}  {aviso}")
    p(f"\n  prenomes no mapa de sexo: {len(d['mapa_sexo'])}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Importador do rol da IPA")
    ap.add_argument("--csv", required=True)
    ap.add_argument("--dsn", help="connection string DIRETA do Neon (sem -pooler)")
    modo = ap.add_mutually_exclusive_group(required=True)
    modo.add_argument("--validar", action="store_true", help="nao escreve nada")
    modo.add_argument("--importar", action="store_true", help="grava numa transacao unica")
    ap.add_argument("--limpar", action="store_true",
                    help="APAGA os dados de importacao antes de gravar (reimportacao)")
    args = ap.parse_args()

    linhas = ler_csv(args.csv)
    print(f"CSV lido: {len(linhas)} linhas, cabecalho conferido.")

    d = transformar(linhas)

    if d["erros"]:
        print(f"\n{len(d['erros'])} ERRO(S) BLOQUEANTE(S):")
        for e in d["erros"][:40]:
            print(f"  - {e}")
        if len(d["erros"]) > 40:
            print(f"  ... e mais {len(d['erros']) - 40}")
        print("\nNada foi importado.")
        return 1

    relatar(d)

    if args.validar:
        print("\n>> MODO VALIDACAO: nada foi escrito no banco.")
        return 0

    if not args.dsn:
        print("\n--importar exige --dsn")
        return 1

    with psycopg.connect(args.dsn) as conn:
        existente = banco_ja_populado(conn)
        if existente and not args.limpar:
            print("\n>> BANCO JA POPULADO. Nada foi feito.")
            for tabela, n in existente.items():
                print(f"     {tabela:28s} {n:6d} registros")
            print("\n   Este importador roda UMA vez (doc 13 §2). Para reimportar:")
            print("     1. crie uma branch do Neon (doc 15 §6), ou")
            print("     2. rode de novo com --limpar para apagar e recarregar.")
            print("\n   --limpar so e seguro enquanto o banco tiver apenas dados de")
            print("   importacao. Depois que houver atas e resolucoes, ele destroi.")
            return 1

        try:
            if args.limpar and existente:
                limpar(conn)
                print(f"\nTabelas zeradas: {', '.join(existente)}")
            gravar(conn, d)
            falhas = conferir(conn, d)
            if falhas:
                conn.rollback()
                print("\n>> CONFERENCIA FALHOU - ROLLBACK:")
                for nome, alvo, obtido in falhas:
                    print(f"   {nome}: esperado {alvo}, obtido {obtido}")
                return 1
            conn.commit()
        except Exception as exc:
            conn.rollback()
            print(f"\n>> ERRO, ROLLBACK: {exc}")
            return 1

    print("\n>> IMPORTACAO CONCLUIDA. Conferencia do doc 13 §7 passou.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
