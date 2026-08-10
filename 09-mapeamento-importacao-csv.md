# 09 — Mapeamento da importação do rol (CSV → modelo)

> ## ⚠️ Documento parcialmente superado — leia o doc 12 primeiro
>
> Escrito **antes** do acesso ao arquivo. O `membros_rows.csv` real foi analisado em `12-perfil-dados-csv.md`, que mede os dados em vez de supô-los. Onde os dois divergirem, **vale o doc 12**.
>
> **Correções que o doc 12 impõe a este arquivo:**
> 1. São **2.622 linhas**, não ~1.669.
> 2. Datas em **ISO 8601** — pendência **P10 resolvida**, sem ambiguidade D/M.
> 3. `categoria` vem da coluna **`membro`**, não de `data_profissao_fe` (a regra do §3 abaixo erraria 50%).
> 4. `oficial` **deve** ser importado como `Oficio` — traz tipo e disponibilidade (§2.2 abaixo dizia o contrário).
> 5. `id_igreja` e `profissao_informada` **descartados** por instrução do usuário.
> 6. `sexo` **não pode ser obrigatório** — falta em 860 registros.
> 7. `numero_ordem` é **`AAAA` + sequência**, não inteiro sequencial.
> 8. Pendências **P7, P8 e P10 resolvidas** pelo doc 12; o script do §8 já foi executado.
>
> O que continua válido aqui: a **estratégia de explosão** (§1), o **processo de 3 passadas** (§5) e o **levantamento paralelo** (§6).

Origem: `membros_rows.csv`, 40 colunas, **2.622 linhas**.

> **A natureza do problema**: o CSV é um **registro achatado — uma linha por membro**. O modelo é **normalizado por eventos**. A importação não é um `COPY`; é uma **explosão de 1 linha em até 8 registros**. Este documento define essa explosão.

---

## 1. A explosão: 1 linha → N registros

```
                          ┌─→ Pessoa                    (sempre)
                          ├─→ Membro                    (se membro = verdadeiro)
                          ├─→ Admissao                  (se data_admissao preenchida)
                          ├─→ Demissao                  (se data_demissao preenchida)
1 linha do CSV ───────────┼─→ AtoPastoral BATISMO       (se data_batismo preenchida)
                          ├─→ AtoPastoral PROFISSAO_FE  (se data_profissao_fe preenchida)
                          ├─→ VinculoFamiliar CONJUGE   (se conjuge preenchido)
                          └─→ VinculoFamiliar PAI/MAE   (se nome_pai / nome_mae preenchidos)
```

> **CORRIGIDO pelo doc 12 §3.2**: a coluna `oficial` **não** é um flag booleano. Ela traz `Presbítero` (21), `Presbítero em disponibilidade` (13) e `Diácono` (7) — ou seja, **tipo de ofício e a distinção de disponibilidade** (RN-OFI-11). Deve gerar `Oficio` na importação, somando um 9º ramo à explosão acima.
>
> O que continua **não** vindo do CSV: `Ordenacao` (data), `Mandato` (instalação e término). Levantamento manual do §6 — agora **41 pessoas**, não 49.

---

## 2. Mapeamento coluna a coluna

Legenda: ✅ direto · 🔀 transformação · 🧩 explode em outra entidade · ❓ precisa de definição

### 2.1 → `Pessoa`

| Coluna CSV | Campo | | Observação |
|---|---|:-:|---|
| `id` | `idLegado` | 🔀 | **Preservar.** Chave de rastreio da migração e de reimportações |
| `nome` | `nomeCompleto` | ✅ | Normalizar espaços duplos; **não** alterar caixa (nomes têm "de", "da", "e") |
| `foto` | `fotoUrl` | ❓ | É caminho de arquivo, URL ou base64? Ver P7 |
| `data_nascimento` | `dataNascimento` | 🔀 | Formato de data — ver §4 |
| `naturalidade` | `naturalidade` | 🆕 | **Campo novo em `Pessoa`** |
| `sexo` | `sexo` | 🔀 | Normalizar para `M`/`F`. **Crítico**: o relatório do Presbitério segmenta tudo por sexo (doc 08 §4). Linha sem sexo é erro bloqueante, não aviso |
| `estado_civil` | `estadoCivil` | 🔀 | Mapear para enum; ver P8 |
| `escolaridade` | `escolaridade` | ✅ | |
| `profissao` | `profissao` | ✅ | |
| `profissao_informada` | `profissaoInformada` | ❓ | Por que duas colunas? Hipótese: `profissao` normalizada / `profissao_informada` texto livre. Ver P8 |
| `telefone` | `contatos[]` tipo TELEFONE | 🧩 | Pode conter 2 números num campo só (como no formulário: "3324-4046 e 98411-8298") — **separar** |
| `email` | `contatos[]` tipo EMAIL | 🧩 | Validar formato; e-mail inválido não bloqueia |
| `endereco`, `complemento`, `bairro`, `cidade`, `cep` | `endereco` (embutido) | 🔀 | ⚠️ **Não há coluna de número** — o número provavelmente está dentro de `endereco`. Não tentar separar automaticamente; importar como veio |
| `notes` | `observacoes` | ✅ | |
| `created_at`, `updated_at` | `criadoEmLegado`, `atualizadoEmLegado` | 🔀 | Guardar para auditoria; **não** usar como data de admissão |

### 2.2 → `Membro`

| Coluna CSV | Campo | | Observação |
|---|---|:-:|---|
| `numero_ordem` | `numeroRol` | ✅ | Decisão B3-a: permanente, nunca reutilizado. **Verificar duplicatas antes de importar** |
| `membro` | — | 🔀 | Flag que decide **se cria `Membro`**. Ver P8 para os valores possíveis |
| `situacao` | `situacao` | ❓ | Mapear para `ATIVO`/`EM_DISCIPLINA`/`ROL_SEPARADO`/`TRANSFERENCIA_EM_CURSO`/`DEMITIDO`. **Ver P8 — mapeamento mais importante da migração** |
| `id_igreja` | `congregacaoId` | ❓ | **Ver P9.** Hipótese forte: aponta para congregação/ponto de pregação (a IPA tem 2 + 1). Se for isso, é a única fonte de lotação que existe |
| — | `categoria` | 🔀 | **Derivado, não importado**: `COMUNGANTE` se `data_profissao_fe` preenchida; senão `NAO_COMUNGANTE`. Ver §3 |
| `data_batismo` | `dataBatismo` | ✅ | Denormalizado do ato |
| `data_profissao_fe` | `dataProfissaoFe` | ✅ | Denormalizado do ato |
| `data_admissao` | `dataAdmissao` | ✅ | |
| `data_demissao` | `dataDemissao` | ✅ | |
| `ata` | `ataAdmissaoLegado` | 🔀 | Texto livre (nº/data da ata). **Não** tentar vincular a `Ata` — as atas antigas não estão no sistema (decisão A2-a). Guardar como texto |
| `oficial` | — | ⚠️ | **Não importar como ofício.** Usar só para gerar a lista de trabalho do §6 |

### 2.3 → `Admissao` (evento)

| Coluna | Campo | Observação |
|---|---|---|
| `data_admissao` | `data` | Se vazia e `membro` = verdadeiro → **erro bloqueante**: não existe membro sem admissão (RN-MEM-10) |
| `meio_admissao` | `forma` | ❓ Mapear para as 7 formas de comungante / 3 de não comungante. **Ver P8** |
| — | `resolucaoId` | Nulo na carga histórica (não há atas no sistema — A2-a). Marcar `origemMigracao = true` |
| `igreja_batismo` / `igreja_profissao_fe` | `igrejaOrigemNome` | Usar quando `meio_admissao` = transferência/jurisdição |

### 2.4 → `Demissao` (evento)

| Coluna | Campo | Observação |
|---|---|---|
| `data_demissao` | `data` | |
| `meio_demissao` | `forma` | ❓ **Ver P8.** Deve cobrir as 6 formas do Art. 23 + `ORDENACAO_AO_MINISTERIO` + `MOVIMENTO_PARA_ROL_SEPARADO` (doc 08 §4.1) |
| — | `resolucaoId` | Nulo, `origemMigracao = true` |

### 2.5 → `AtoPastoral`

| Colunas | Registro gerado |
|---|---|
| `data_batismo` + `pastor_batismo` + `igreja_batismo` | `AtoPastoral(tipo = BATISMO_INFANTIL ou BATISMO_ADULTO, data, oficianteNomeExterno, igrejaExternaNome)` + `ParticipanteAtoPastoral(papel = BATIZANDO)` |
| `data_profissao_fe` + `pastor_profissao_fe` + `igreja_profissao_fe` | `AtoPastoral(tipo = PROFISSAO_DE_FE, …)` + `ParticipanteAtoPastoral(papel = PROFITENTE)` |

**🆕 Dois campos novos obrigatórios em `AtoPastoral`:**
- `oficianteNomeExterno` (texto) — o pastor que batizou pode ser de outra igreja, ter falecido ou nunca existir como `Pessoa` no sistema. **`oficianteId` precisa ser opcional.**
- `igrejaExternaNome` (texto) — o ato pode ter ocorrido em outra igreja.

Sem esses dois campos, ~1.669 registros históricos de batismo e profissão de fé não têm onde entrar.

**Regra de tipo de batismo**: se `data_batismo` e `data_profissao_fe` forem a mesma data (ou distarem < 30 dias) → `BATISMO_ADULTO`; se o batismo ocorreu antes dos 18 anos da pessoa → `BATISMO_INFANTIL`; caso contrário → `BATISMO_ADULTO`. Marcar como `inferido = true` para revisão.

### 2.6 → `VinculoFamiliar`

| Coluna | Vínculo gerado | Observação |
|---|---|---|
| `nome_pai` | `PAI` | ❓ É texto ou id? Ver P7. Se texto: tentar casar por nome exato dentro do rol; **não casando, guardar como texto** em `Pessoa.nomePaiTexto` |
| `nome_mae` | `MAE` | idem, `Pessoa.nomeMaeTexto` |
| `conjuge` | `CONJUGE` + `data_casamento` | idem. Se casar por nome, criar vínculo bidirecional **uma única vez** (evitar duplicata A→B e B→A) |

**🆕 Campos novos em `Pessoa`**: `nomePaiTexto`, `nomeMaeTexto`, `nomeConjugeTexto`, `dataCasamento`. Guardam o dado bruto quando o casamento por nome falha — e ele vai falhar bastante.

---

## 3. Derivação de `categoria` — ❌ SEÇÃO ERRADA, SUBSTITUÍDA

Eu havia proposto derivar a categoria de `data_profissao_fe`. **Os dados reais derrubam a regra**: só 432 dos 1.291 comungantes têm esse campo preenchido (33%). A regra produziria 641 comungantes em vez de 1.291 — **erro de 50%**.

**Regra correta** (doc 12 §3.1): a categoria vem da coluna **`membro`** (`Comungante` 1.291 · `Não comungante` 155 · `Não membro` 622 · vazio 554). `data_profissao_fe` é apenas dado histórico opcional.

Para os 554 vazios, ver pendência **P11** do doc 12.

---

## 4. Formatos e normalização

| Item | Cuidado |
|---|---|
| **Datas** | O PDF exportado mostra `7/14/1953` e `1/30/2026` — formato **M/D/AAAA (americano)**. Se o CSV vier da mesma origem, `03/04/2020` é **4 de março**, não 3 de abril. **Confirmar antes de importar** (P10) — errar aqui corrompe 1.669 registros silenciosamente |
| **Datas vazias** | `0000-00-00`, `01/01/1900`, `-`, `N/A` → nulo |
| **Números** | O PDF mostra `1,216` (milhar com vírgula). Se houver valores numéricos no CSV, tratar |
| **Encoding** | Testar UTF-8 e Latin-1. Nome com acento corrompido é irreversível depois |
| **Espaços** | `trim()` em tudo; colapsar espaços internos duplos |
| **Booleanos** | `membro`, `oficial` podem vir como `1/0`, `S/N`, `Sim/Não`, `true/false` — ver P8 |

---

## 5. Processo de importação (obrigatoriamente em 3 passadas)

Com 1.669 linhas, importar "e ver no que dá" não é opção.

| Passada | O que faz | Saída |
|---|---|---|
| **1. Perfilar** | Não escreve nada. Lê o CSV e produz: valores distintos de cada coluna categórica, contagem de vazios por coluna, duplicatas de `numero_ordem` e de `nome`, datas fora de faixa | `relatorio-perfilagem.md` |
| **2. Simular** | Executa toda a transformação em memória e reporta o que **seria** criado, com todos os erros e avisos por linha | `relatorio-simulacao.md` |
| **3. Executar** | Importa de verdade, em transação única, guardando `idLegado` em tudo | `relatorio-importacao.md` |

**Conferência final** — ❌ **critério anterior revogado**. Eu propunha validar contra o relatório de 2025 (1.404 / 265 / 1.669). O usuário determinou que **os números do relatório não batem com o rol e não devem servir de critério**, e os dados confirmam: o CSV tem 1.777 ativos contra 1.669 do relatório.

**Critério revisado** (doc 12 §6):

1. As **2.622 linhas** entram sem perda — nenhuma descartada em silêncio.
2. Nenhum valor de `membro`, `oficial`, `meio_admissao` ou `meio_demissao` fica sem mapeamento.
3. As contagens por categoria e situação batem com **o CSV de origem**, não com o relatório.
4. As três filas de revisão são geradas nos totais esperados: ~521 sem categoria, ~860 sem sexo, ~34 nomes duplicados.

### Classificação de erros

| Nível | Exemplos | Comportamento |
|---|---|---|
| **Bloqueante** | sem nome; `numero_ordem` duplicado; valor desconhecido em `membro`/`oficial`/`meio_admissao`/`meio_demissao` | Aborta a importação |
| **Aviso** | **sem sexo (860)**; **sem categoria (554)**; sem data de admissão (273 entre ativos); inativo sem data de demissão (447); nome duplicado (34); pai/mãe não casados por nome; tipo de batismo inferido | Importa e enfileira para revisão |
| **Silencioso** | campo opcional vazio | Nada |

> **Correção**: "sem sexo" e "sem data de admissão" eram bloqueantes na v1 deste documento. Com 860 e 273 ocorrências reais, bloquear inviabilizaria a importação inteira. Viraram avisos com fila de revisão.

---

## 6. O que o CSV **não** traz (levantamento paralelo)

Estes dados não existem na planilha e precisam ser coletados à mão. **Comece por eles agora** — não dependem de código e são o caminho crítico da E2.

| Dado | Onde buscar | Volume | Por quê |
|---|---|---|---|
| **Ofícios e datas de ordenação** | Atas do Conselho / livro de registro | ~49 pessoas (21 presbíteros + 28 diáconos) | Art. 25 §1º: o ofício é perpétuo. É o dado insubstituível da decisão A2-a |
| **Mandatos vigentes** (instalação + término previsto) | Atas | ~49 | Sem isso não há alerta de D-90 (RN-OFI-10) nem composição do Conselho |
| **Relações pastorais** (tipo, início, aprovação do Presbitério) | Atas / Presbitério | 9 pastores | Define quem preside e quem vota |
| **Mesa do Conselho do exercício** | Ata da primeira reunião do ano | 3–5 pessoas | Secretário assina o relatório (Seção VI) |
| **Congregações e pontos de pregação** | — | 3 | Decisão A3-b; e `id_igreja` do CSV pode depender disso (P9) |
| **Organizações internas** | — | 4 | Doc 08 §3.3 |
| **Escola Dominical** | — | 3 escolas, 22 professores | Doc 08 §6.1 |

**Sugestão prática**: monte uma planilha simples com `nome · ofício · data_ordenacao · data_instalacao_mandato_atual` e preencha com o secretário do Conselho enquanto o importador é construído. 49 linhas resolvem a E2 inteira.

---

## 7. Pendências desta análise — **todas resolvidas**

| # | Pergunta | Resposta |
|---|---|---|
| **P7** | Tipos das colunas ambíguas | `foto` = caminho relativo `picture/nome_uuid.jpeg`. `nome_pai`, `nome_mae`, `conjuge` = **texto puro**, zero UUIDs (doc 12 §4) |
| **P8** | Domínios das colunas categóricas | Medidos e mapeados 1-a-1 no doc 12 §3. Nenhum valor órfão em `meio_admissao`; 2 a esclarecer em `meio_demissao` (P13) |
| **P9** | O que é `id_igreja`? | **Descartado** — dados inconsistentes (`IP Anápolis` misturado com `3265`), por instrução do usuário |
| **P10** | Formato das datas | **ISO 8601** (`1979-01-23`). Sem ambiguidade. O risco de corrupção silenciosa não existe |

Pendências novas, abertas pelos dados reais: **P11 a P18**, no doc 12 §7.

---

## 8. Script de perfilagem — ✅ já executado

Resultados no doc 12. Mantido aqui para reexecução quando a planilha for atualizada.

```bash
# ajuste o caminho do arquivo
CSV=rol.csv

python3 - "$CSV" <<'PY'
import csv, sys, collections
cat = ['situacao','meio_admissao','meio_demissao','membro','oficial',
       'estado_civil','id_igreja','sexo']
amostra = ['foto','nome_pai','nome_mae','conjuge','ata',
           'profissao','profissao_informada','data_nascimento','data_admissao']

with open(sys.argv[1], encoding='utf-8-sig', newline='') as f:
    linhas = list(csv.DictReader(f))

print(f"TOTAL DE LINHAS: {len(linhas)}\n")

print("=== VALORES DISTINTOS (colunas categóricas) ===")
for c in cat:
    if c not in linhas[0]:
        print(f"\n[{c}] -- coluna ausente"); continue
    cont = collections.Counter((r.get(c) or '').strip() for r in linhas)
    print(f"\n[{c}] {len(cont)} valores distintos")
    for v, n in cont.most_common(30):
        print(f"    {n:6d}  {v!r}")

print("\n=== AMOSTRA (3 valores não vazios por coluna) ===")
for c in amostra:
    if c not in linhas[0]:
        print(f"[{c}] -- ausente"); continue
    vals = [ (r.get(c) or '').strip() for r in linhas ]
    nv = [v for v in vals if v][:3]
    print(f"[{c}] vazios={sum(1 for v in vals if not v)}/{len(vals)}  exemplos={nv}")

print("\n=== DATAS: dia > 12 indica formato D/M ===")
import re
for c in ['data_nascimento','data_admissao','data_batismo']:
    if c not in linhas[0]: continue
    p1 = p2 = 0
    for r in linhas:
        m = re.match(r'^\s*(\d{1,2})[/-](\d{1,2})[/-]\d{2,4}', r.get(c) or '')
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            if a > 12: p1 += 1
            if b > 12: p2 += 1
    print(f"[{c}] 1o campo>12: {p1}   2o campo>12: {p2}   -> "
          f"{'D/M/AAAA' if p1 and not p2 else 'M/D/AAAA' if p2 and not p1 else 'INDETERMINADO'}")

print("\n=== DUPLICATAS ===")
for c in ['numero_ordem','id','nome']:
    if c not in linhas[0]: continue
    cont = collections.Counter((r.get(c) or '').strip() for r in linhas if (r.get(c) or '').strip())
    dup = {k: v for k, v in cont.items() if v > 1}
    print(f"[{c}] {len(dup)} valores duplicados" + (f" -> ex.: {list(dup.items())[:5]}" if dup else ""))

print("\n=== CONFERÊNCIA COM O RELATÓRIO 2025 ===")
print("esperado: comungantes 1404 | nao-comungantes 265 | total 1669")
tem_pf = sum(1 for r in linhas if (r.get('data_profissao_fe') or '').strip())
print(f"linhas com data_profissao_fe preenchida: {tem_pf}")
PY
```

Cole a saída aqui ou me avise que rodou — com ela eu fecho o mapeamento e escrevo o importador.

> **Privacidade**: a saída mostra contagens e no máximo 3 exemplos por coluna. Se algum exemplo trouxer dado pessoal que você prefira não colar, apague a linha — os valores distintos das colunas categóricas são o que realmente importa.
