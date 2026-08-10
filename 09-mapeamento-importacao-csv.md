# 09 — Mapeamento da importação do rol (CSV → modelo)

Origem: planilha/CSV informado na decisão **A4-a**, 40 colunas, ~1.669+ linhas.

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

**Importante**: `Oficio`, `Ordenacao` e `Mandato` **não vêm do CSV**. A coluna `oficial` é só um flag booleano — não traz tipo de ofício, data de ordenação nem mandato. Esses dados terão de ser levantados à parte (ver §6), e são justamente os que a decisão A2-a considerou insubstituíveis (Art. 25 §1º).

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

## 3. Derivação de `categoria` (comungante × não comungante)

Não existe coluna para isso no CSV, mas é a segmentação central do relatório ao Presbitério (doc 08 §4).

```
se data_profissao_fe preenchida        → COMUNGANTE
senão se idade >= 18 anos              → ⚠️ INCONSISTENTE — revisar manualmente
senão                                  → NAO_COMUNGANTE
```

O caso do meio é real e provavelmente numeroso: **adulto batizado, sem profissão de fé registrada**. Pelo Art. 12 ele não é comungante; mas pelo Art. 24 *c* também já deveria ter saído do rol de não comungantes. Ver PENDÊNCIA P3 do doc 08 — em 2025 a IPA não registrou nenhuma exclusão de não comungante, o que sugere que essas pessoas estão acumuladas no rol.

**O importador deve emitir uma lista dessas pessoas para decisão do Conselho**, não escolher sozinho.

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

**Conferência final obrigatória** — a importação só é aceita se reproduzir o relatório de 2025 (doc 08 §4.3):

```
comungantes ativos      == 1.404   (662 M / 742 F)
não comungantes ativos  ==   265   (109 M / 156 F)
rol total               == 1.669   (771 M / 898 F)
```

Se não bater, o problema está no mapeamento de `situacao` ou `membro` — não na aritmética. Este é o melhor teste de aceitação que existe para a E1, e ele veio de graça com o PDF.

### Classificação de erros

| Nível | Exemplos | Comportamento |
|---|---|---|
| **Bloqueante** | sem nome; sem sexo; `membro`=sim sem `data_admissao`; `numero_ordem` duplicado; `meio_admissao` desconhecido | Aborta a importação |
| **Aviso** | sem data de nascimento; e-mail inválido; pai/mãe não casados por nome; tipo de batismo inferido | Importa e lista para revisão |
| **Silencioso** | campo opcional vazio | Nada |

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

## 7. Pendências desta análise

Todas resolvidas por um comando só, exceto P9 e P10 — ver §8.

### P7 — Tipos das colunas ambíguas
`foto` é caminho, URL ou base64? `nome_pai`, `nome_mae`, `conjuge` são texto ou id de outra linha?
**Resposta:**

### P8 — Domínios das colunas categóricas
Preciso dos **valores distintos** de: `situacao`, `meio_admissao`, `meio_demissao`, `membro`, `oficial`, `estado_civil`, e a diferença entre `profissao` e `profissao_informada`.
> Sem isso, o mapeamento de formas de admissão/demissão é chute — e é ele que faz o relatório fechar em 1.404.
**Resposta:**

### P9 — O que é `id_igreja`?
**Hipótese**: id da congregação/ponto de pregação (a IPA tem 2 + 1 = 3). **Alternativa**: resquício de um sistema multi-igreja, com o mesmo valor em todas as linhas.
> Se for congregação, é a única fonte de lotação existente e precisa ser mapeada antes da E1.
**Resposta:**

### P10 — Formato das datas
`M/D/AAAA` (como no PDF) ou `D/M/AAAA`?
> Confirme olhando qualquer linha com dia > 12. Errar aqui corrompe tudo em silêncio.
**Resposta:**

---

## 8. Comando para responder P7, P8 e P10 de uma vez

Rode no terminal, com o CSV à mão, e me mande a saída:

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
