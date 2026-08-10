# 13 — Spec do importador do rol

Algoritmo definitivo de migração de `membros_rows.csv` (2.622 linhas) para o modelo v3.
Todas as decisões estão fechadas (doc 07 blocos A/B, doc 12 P11–P18). **Este documento é implementável como está.**

---

## 1. Decisões aplicadas

| # | Decisão | Efeito no algoritmo |
|---|---|---|
| P11 (a) | Inferir categoria pela forma de admissão | §4.2 — resolve 466 dos 554 vazios |
| **P12 (b)** | **`situacao` manda sobre `data_demissao`** | §4.3 — e gera duas consequências, §6 |
| P13 | `Transferência presbitério` = membro ordenado ministro | `ORDENACAO_AO_MINISTERIO` |
| P14 (a) | `numero_ordem` preservado como texto, novos no mesmo padrão | §4.4 |
| P15 | Fotos disponíveis | §4.7 — migrar os 900 arquivos |
| P16 | Diáconos desatualizados, serão corrigidos no sistema novo | Importar os 7; sem alarme |
| **P17** | **O novo sistema substitui o atual** | §2 — importação única, sem sincronização |
| P18 (a) | Inferir sexo por prenome, marcando como inferido | §4.6 |

---

## 2. Estratégia (P17 = substituição)

Importação **única e definitiva**, não recorrente. Isso permite:

- **Uma transação só.** Tudo ou nada. Se qualquer erro bloqueante aparecer, `ROLLBACK`.
- **Sem lógica de reconciliação** (upsert, detecção de alterações, resolução de conflito). Seria o grosso da complexidade se fosse convivência.
- **`id_legado` preservado mesmo assim** — custa uma coluna e salva a auditoria: "de onde veio este registro?" continua respondível para sempre.

**Pré-requisito operacional**: congelar o sistema atual antes de exportar o CSV definitivo. Qualquer cadastro feito nele depois da exportação se perde. Combine uma data de corte com a secretaria.

---

## 3. Ordem de execução

```
1. Ler CSV e validar cabeçalho (40 colunas exatas)
2. Passada de validação  → aborta em erro bloqueante (§5)
3. BEGIN TRANSACTION
   3.1  pessoa                    (2.622)
   3.2  pessoa_contato            (~2.560)
   3.3  membro                    (2.622 — ver §4.1)
   3.4  admissao                  (~2.178)
   3.5  demissao                  (312)
   3.6  ato_pastoral + participante (~1.276)
   3.7  oficio                    (41)
   3.8  vinculo_familiar          (~1.119 casados por nome)
   3.9  marcação das filas de revisão
4. Conferência automática (§7) → se falhar, ROLLBACK
5. COMMIT
6. Migrar arquivos de foto (fora da transação)
7. Emitir relatório de importação
```

**Ordem importa**: `vinculo_familiar` roda por último porque depende de todas as pessoas já existirem para o casamento por nome.

---

## 4. Regras de transformação

### 4.1 `pessoa` e `membro` — quem vira membro

**Achado que corrige o doc 12 §3.1**: os 622 registros `Não membro` **não são não-membros**. Todos os 622 têm histórico de membresia (385 com `numero_ordem`, 292 com `meio_admissao`, 287 com `meio_demissao`). São **ex-membros**.

```
para cada linha:
    criar pessoa                                    → sempre (2.622)
    criar membro                                    → sempre (2.622)

    se membro == 'Não membro':
        membro.situacao  = DEMITIDO
        membro.categoria = inferir(meio_admissao)   # §4.2
        membro.pendencia_revisao = true  se não houver data/meio de demissão
```

> Criar `Membro` para os 622 preserva `numero_ordem`, datas de admissão e o motivo de saída. Tratá-los como `Pessoa` pura descartaria o histórico de 385 números de rol — exatamente o que a decisão A2-a mandou preservar.

### 4.2 `categoria` — P11(a)

```
membro == 'Comungante'      → COMUNGANTE
membro == 'Não comungante'  → NAO_COMUNGANTE
membro vazio ou 'Não membro':
    meio_admissao ∈ { 'Batismo infantil',
                      'Jurisdição sobre os responsáveis',
                      'Transferência dos responsáveis',
                      'Transferência dos pais' }   → NAO_COMUNGANTE
    meio_admissao preenchido (demais formas)       → COMUNGANTE
    meio_admissao vazio                            → NAO_DEFINIDO
    em ambos os casos inferidos: categoria_inferida = true
```

**Resultado medido**: 1.751 comungantes · 161 não comungantes · 88 `NAO_DEFINIDO` · **466 inferidos**.
A regra resolve 466 dos 554 vazios; sobram **88** para triagem manual — bem abaixo dos 521 originais.

### 4.3 `situacao` — P12(b), `situacao` manda

```
situacao == 'Ativo'    → ATIVO
situacao == 'Inativo'  → DEMITIDO
situacao == 'Revisar'  → ATIVO + pendencia_revisao = true
```

**Resultado medido**: 1.876 ativos · 746 demitidos · 99 em revisão.

> `Revisar` não é estado eclesiástico e não existe no enum. Vira `ATIVO` + pendência: o registro segue utilizável, sinalizado. Ver a consequência em §6.2.

### 4.4 `numero_ordem` — P14(a)

Preservado como **texto**, sem alteração. Estrutura real: `AAAA` + 4 dígitos, sempre 8 caracteres, sem duplicatas.

| Ano | Qtd | Faixa da sequência |
|---|---:|---|
| 2018 | 957 | 1245 – 2694 |
| 2019 | 161 | 2764 – 2998 |
| 2020 | 27 | 3006 – 3073 |
| 2021 | 70 | 3096 – 3411 |
| 2022 | 188 | 3483 – 3743 |
| 2023 | 203 | 3810 – 5003 |
| **2024** | 38 | **100 – 138** |

⚠️ **A convenção mudou.** De 2018 a 2023 a sequência foi **contínua entre anos** (2018 termina em 2694, 2019 começa em 2764). Em **2024 ela reiniciou em 100** — alguém passou a numerar por ano.

**Regra proposta para números novos** (confirmar — §9, P19): seguir a convenção de 2024, ou seja `AAAA` + sequência **reiniciada a cada ano**, começando em `0001`. Para 2026, o primeiro seria `20260001`.

### 4.5 `admissao` e `demissao`

```
se data_admissao OU meio_admissao preenchido:
    criar admissao(
        data          = data_admissao,          # pode ser NULL → ver §6.3
        forma         = mapa_admissao[meio_admissao],
        origem_migracao = true,
        igreja_origem_nome = igreja_batismo ou igreja_profissao_fe (quando aplicável),
        resolucao_id  = NULL)                   # não há atas no sistema (A2-a)

se data_demissao preenchido:
    criar demissao(data, forma = mapa_demissao[meio_demissao], origem_migracao = true)
```

**Mapa de admissão** (12 valores → 10 formas, sem órfãos):

| CSV | `forma_admissao` |
|---|---|
| Jurisdição a pedido (831) | `JURISDICAO_A_PEDIDO` |
| Profissão de fé e batismo (578) | `PROFISSAO_FE_E_BATISMO` |
| Transferência (386) | `CARTA_TRANSFERENCIA` |
| Profissão de fé (232) | `PROFISSAO_FE` |
| Batismo infantil (84) | `BATISMO_INFANTIL` |
| Restauração (27) | `RESTAURACAO` |
| Jurisdição sobre os responsáveis (14) | `JURISDICAO_SOBRE_OS_PAIS` |
| Jurisdição ex-offício (11) | `JURISDICAO_EX_OFFICIO` |
| Transferência dos responsáveis (4) · Transferência dos pais (2) | `TRANSFERENCIA_DOS_PAIS` |
| Designação do presbitério (1) | `DESIGNACAO_PRESBITERIO` |

**Mapa de demissão** (P13 aplicada):

| CSV | `forma_demissao` |
|---|---|
| Exclusão por ausência (193) | `EXCLUSAO_POR_AUSENCIA` |
| Transferência (173) · Transferência dos responsáveis (6) · **Transferência conselho (3)** | `CARTA_TRANSFERENCIA` |
| Falecimento (35) | `FALECIMENTO` |
| Jurisdição assumida (25) | `JURISDICAO_ASSUMIDA_POR_OUTRA` |
| **Transferência presbitério (1)** | **`ORDENACAO_AO_MINISTERIO`** ← P13 |
| Solicitação dos responsáveis (1) | `SOLICITACAO_DOS_PAIS` |

`Falecimento` também preenche `pessoa.data_falecimento` com a data de demissão.

### 4.6 `sexo` — P18(a)

```
'MASCULINO' → M ; 'FEMININO' → F
vazio → inferir do primeiro prenome por lista de nomes;
        se confiança alta:  sexo = inferido, sexo_inferido = true
        se ambíguo:         sexo = NULL, pendencia_revisao = true
```

Lista de prenomes ambíguos a tratar explicitamente como nulos: *Darci, Nair, Ariel, Alcides, Aparecido/a, Jacy, Iraci, Domingos, Remy, Neri, Wilson/Vilson*… Montar a partir dos próprios 860 nomes, não de uma lista genérica.

⚠️ **Nunca inferir sexo em registro que já o tem.** E marcar sempre — a inferência afeta elegibilidade ao oficialato (RN-OFI-03), onde um erro tem consequência eclesiástica.

### 4.7 `oficio` — 41 registros

```
'Presbítero'                    → oficio(PRESBITERO_REGENTE, EM_EXERCICIO)   21
'Presbítero em disponibilidade' → oficio(PRESBITERO_REGENTE, DISPONIBILIDADE) 13
'Diácono'                       → oficio(DIACONO, EM_EXERCICIO)               7
```

**Sem `ordenacao` e sem `mandato`** — o CSV não traz datas. Criar o `Oficio` já permite montar a composição do Conselho; ordenação e mandato entram pelo levantamento manual (doc 09 §6, 41 pessoas).

⚠️ Enquanto não houver `Mandato`, os alertas de D-90 (RN-OFI-10) e de ausência de 6 meses (RN-OFI-12 *d*) ficam inativos. Não é bug.

### 4.8 Atos pastorais

```
se data_batismo:
    ato_pastoral(tipo    = BATISMO_INFANTIL se idade_no_batismo < 18 senão BATISMO_ADULTO,
                 data    = data_batismo,
                 oficiante_nome_externo = pastor_batismo,
                 igreja_externa_nome    = igreja_batismo,
                 inferido = true,            # o tipo é deduzido
                 origem_migracao = true)
    + participante(pessoa, papel = BATIZANDO)

se data_profissao_fe:
    ato_pastoral(PROFISSAO_DE_FE, data, pastor_profissao_fe, igreja_profissao_fe)
    + participante(pessoa, papel = PROFITENTE)
```

Se `data_nascimento` estiver vazia, o tipo de batismo não é dedutível → `BATISMO_ADULTO` + `pendencia_revisao`.

### 4.9 Vínculos familiares

```
para cada campo em (conjuge, nome_pai, nome_mae):
    normalizar (trim, minúsculas, sem acentos, espaços colapsados)
    se casar com exatamente UMA pessoa → criar vinculo_familiar
    se casar com VÁRIAS               → não criar, pendencia_revisao
    se não casar                      → gravar em pessoa.nome_*_texto
```

**Esperado**: ~554 cônjuges, ~274 pais, ~291 mães casados. Cônjuge gera vínculo **bidirecional, criado uma única vez** — controlar para não duplicar A→B e B→A.

### 4.10 Demais campos

| Campo | Destino |
|---|---|
| `id` | `pessoa.id_legado` |
| `telefone` | `pessoa_contato(TELEFONE, principal = true)` |
| `email` | `pessoa_contato(EMAIL, principal = true)` |
| `endereco`, `complemento`, `bairro`, `cidade`, `cep` | campos de endereço; **não separar número** |
| `naturalidade`, `estado_civil`, `escolaridade`, `profissao` | diretos |
| `nome`, `data_nascimento` | diretos |
| `data_casamento` | `pessoa.data_casamento` |
| `ata` | `membro.ata_admissao_legado` |
| `notes` | `pessoa.observacoes` + `pendencia_revisao = true` (90 registros) |
| `foto` | `pessoa.foto_url` após migrar o arquivo (§8) |
| `created_at` | ignorado (é data de digitação, não evento eclesiástico) |
| `id_igreja`, `profissao_informada`, `updated_at` | **descartados** |

---

## 5. Níveis de erro

| Nível | Condição | Ação |
|---|---|---|
| **Bloqueante** | cabeçalho diferente de 40 colunas · `nome` vazio · `numero_ordem` duplicado · valor desconhecido em `membro`/`oficial`/`situacao`/`meio_admissao`/`meio_demissao` · data fora do padrão ISO | Aborta tudo |
| **Pendência** | sem sexo após inferência · `NAO_DEFINIDO` · `situacao = Revisar` · demitido sem dados de demissão · ativo com data de demissão · `notes` preenchido · nome duplicado · vínculo ambíguo · tipo de batismo indeduzível | Importa e enfileira |
| **Silencioso** | campo opcional vazio | Nada |

**Valor categórico desconhecido é bloqueante de propósito**: hoje todos os valores mapeiam. Se um novo aparecer no CSV definitivo, é sinal de que alguém cadastrou algo entre a análise e a exportação — e precisa ser decidido, não adivinhado.

---

## 6. Consequências de P12(b) — leia antes de rodar

Você escolheu que `situacao` manda sobre `data_demissao`. Escolha legítima e mais simples de explicar à secretaria. Ela produz três situações que o importador precisa tratar explicitamente:

### 6.1 — 311 demitidos sem nenhum evento de demissão

746 registros viram `DEMITIDO`, mas **311 não têm data nem forma de demissão**. Como `demissao.data` é obrigatória, não há evento a criar.

**Tratamento**: `membro.situacao = DEMITIDO`, **sem** registro em `demissao`, `pendencia_revisao = true`.

**Efeito prático**: a pessoa não aparece no rol ativo (correto), mas nenhuma estatística de "demitidos no ano X" a contabiliza — o que também está certo, já que o ano é desconhecido. A tabela de eventos permanece honesta: só contém demissões realmente datadas.

### 6.2 — 13 ativos com data de demissão preenchida

2 com `situacao = Ativo` e 11 com `Revisar`, todos com `data_demissao`. Por P12(b), permanecem **ATIVO**.

**Tratamento**: manter `ATIVO`, preservar o valor em `membro.data_demissao` (a `CHECK` de coerência foi removida justamente por isso — doc 10 §3), **não** criar evento de demissão, `pendencia_revisao = true`.

São 13 casos. A secretaria decide um a um se a pessoa saiu ou não.

### 6.3 — 441 admissões sem data

Registros com `meio_admissao` mas sem `data_admissao`. Criar `admissao` com `data = NULL` exige tornar a coluna nullable.

**Recomendação**: tornar `demissao.data` e `admissao.data` **nullable**, com `pendencia_revisao`. A alternativa — não criar o evento — descartaria a forma de admissão de 441 pessoas, que é dado real e recuperável apenas do CSV.

> Migration correspondente: `ALTER TABLE admissao ALTER COLUMN data DROP NOT NULL;` (idem `demissao`). Restaurar o `NOT NULL` depois da limpeza é uma linha.

---

## 7. Conferência automática (roda antes do COMMIT)

Se qualquer linha falhar → `ROLLBACK`.

| Verificação | Esperado |
|---|---:|
| `pessoa` | 2.622 |
| `membro` | 2.622 |
| `membro.categoria = COMUNGANTE` | 1.751 |
| `membro.categoria = NAO_COMUNGANTE` | 161 |
| `membro.categoria = NAO_DEFINIDO` | 88 |
| `membro.categoria_inferida = true` | 466 |
| `membro.situacao = ATIVO` | 1.876 |
| `membro.situacao = DEMITIDO` | 746 |
| `admissao` | 2.178 |
| `demissao` | 312 |
| `ato_pastoral` (batismo) | 635 |
| `ato_pastoral` (profissão de fé) | 641 |
| `oficio` total | 41 |
| ↳ presbítero em exercício | 21 |
| ↳ presbítero em disponibilidade | 13 |
| ↳ diácono | 7 |
| `numero_rol` distintos | 1.644 |
| Linhas sem correspondência | **0** |

**A regra de ouro**: `count(pessoa) == 2.622`. Qualquer linha perdida em silêncio invalida a importação.

---

## 8. Migração das fotos (P15)

Fora da transação — falha de arquivo não pode derrubar o banco.

```
para cada linha com foto:
    origem  = <storage atual>/picture/<arquivo>
    destino = <novo storage>/pessoas/<pessoa_id>.<ext>
    copiar; se sucesso → pessoa.foto_url = destino
            se falhar  → registrar no relatório, seguir
```

900 arquivos. Renomear por `pessoa_id` elimina a dependência do nome antigo (`picture/fellipe_<uuid>.jpeg`), que embute o primeiro nome e é frágil.

---

## 9. Pendências residuais

### P19 — Numeração para novos membros
A convenção mudou em 2024 (sequência reiniciou em 100). Confirmo o padrão para 2026 em diante?
- [ ] **(a) Recomendado** — `AAAA` + 4 dígitos reiniciando a cada ano; 2026 começa em `20260001`.
- [ ] (b) Continuar a sequência contínua de 2023 (próximo seria `20265004`).
- [ ] (c) Outro — a secretaria tem uma regra que não está visível nos dados.

**Decisão:** (a)

### P20 — Data de corte
Qual data o sistema atual congela para a exportação definitiva do CSV?
**Decisão:** Data de hoje 2026-08-10

---

## 10. Filas de revisão geradas (entrada do UC-M1-15)

| Fila | Volume | Prioridade |
|---|---:|---|
| Sem sexo após inferência | ~150–300 (dos 860) | Alta — afeta elegibilidade |
| `NAO_DEFINIDO` | 88 | Alta — fora de listas de voto |
| Categoria inferida, a confirmar | 466 | Média — amostragem basta |
| Demitidos sem evento de demissão | 311 | Baixa — histórico antigo |
| `situacao = Revisar` do legado | 99 | Média |
| Nomes duplicados | 34 | Alta — risco de duplicidade real |
| Registros com `notes` | 90 | Média — contêm correções manuais |
| Ativos com data de demissão | 13 | Alta — contradição direta |
| Admissões sem data | 441 | Baixa |

Total de itens: ~1.500, com sobreposição entre filas. **Não é sinal de importação ruim** — é o estado real do rol ficando visível pela primeira vez.

---

## 11. Ordem de implementação sugerida

1. Migrations `001–005` (doc 10) + `ALTER` de §6.3
2. Leitor de CSV + validação de cabeçalho
3. Passada de validação com relatório (sem escrever nada)
4. `pessoa` + `pessoa_contato`
5. `membro` com as regras §4.2 e §4.3
6. `admissao` + `demissao`
7. `ato_pastoral` + participantes
8. `oficio`
9. `vinculo_familiar`
10. Conferência automática (§7)
11. Migração de fotos
12. Relatório final de importação

Os passos 1–5 já produzem um rol consultável. Se a energia acabar aí, o projeto tem valor.
