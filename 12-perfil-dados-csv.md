# 12 — Perfil dos dados reais do rol

Análise de `membros_rows.csv`: **2.622 registros**, 40 colunas. Substitui as suposições dos docs 08 e 09 por fatos medidos.

---

## 1. Resumo executivo

| O que se confirmou | O que se derrubou |
|---|---|
| Datas em **ISO 8601** (`1979-01-23`) — sem ambiguidade D/M · M/D | O relatório estatístico **não** serve de critério de validação (instrução sua, e os dados confirmam: divergência de ~108 pessoas) |
| `meio_admissao` e `meio_demissao` mapeiam **quase perfeitamente** nas formas da CI | `categoria` **não** pode ser derivada de `data_profissao_fe` — só 33% dos comungantes a têm preenchida |
| `oficial` traz ofício **e** disponibilidade — vale muito mais que o flag booleano que eu supunha | `sexo` **não pode ser obrigatório**: falta em 860 registros (32,8%) |
| `numero_ordem` sem duplicatas | `numero_ordem` **não é sequencial simples** — é `AAAA` + sequência |
| Telefone limpo, um número por campo | `id_igreja`, `profissao_informada` — descartados por instrução sua |

**Três problemas de dados que precisam de decisão antes da importação** (§5): 521 ativos sem categoria · 860 sem sexo · 34 nomes duplicados.

---

## 2. Preenchimento por coluna

| Coluna | Preenchido | % | Leitura |
|---|---:|---:|---|
| `id`, `nome`, `oficial`, `situacao`, `updated_at` | 2.622 | 100% | Confiáveis |
| `created_at` | 2.492 | 95% | |
| `data_nascimento` | 2.177 | 83% | Bom |
| `estado_civil` | 2.169 | 83% | |
| `meio_admissao` | 2.170 | 83% | **Melhor que `data_admissao`** |
| `membro` | 2.068 | 79% | ⚠️ 554 vazios |
| `naturalidade` | 1.845 | 70% | |
| `profissao` | 1.833 | 70% | |
| `data_admissao` | 1.737 | 66% | ⚠️ |
| `sexo` | 1.762 | 67% | ⚠️ **crítico** |
| `endereco` / `cidade` / `cep` | ~1.700 | 65% | |
| `numero_ordem` | 1.644 | 63% | ⚠️ |
| `telefone` | 1.539 | 59% | |
| `nome_mae` / `nome_pai` | ~1.220 | 47% | |
| `escolaridade` | 1.180 | 45% | |
| `email` | 1.024 | 39% | |
| `ata` | 977 | 37% | Como você antecipou |
| `foto` | 900 | 34% | |
| `conjuge` | 838 | 32% | |
| `data_profissao_fe` | 641 | 24% | ⚠️ **não serve para derivar categoria** |
| `data_batismo` | 635 | 24% | |
| `meio_demissao` | 437 | 17% | |
| `data_demissao` | 312 | 12% | |
| `notes` | 90 | 3% | Poucos, mas **valiosos** (§4.6) |

---

## 3. Domínios reais das colunas categóricas

### 3.1 `membro` → `Membro.categoria`

| Valor | Qtd | Destino |
|---|---:|---|
| `Comungante` | 1.291 | `Membro(COMUNGANTE)` |
| `Não membro` | 622 | **`Pessoa` sem `Membro`** — ou membro demitido (§4.2) |
| *(vazio)* | 554 | ⚠️ **indefinido** — ver P11 |
| `Não comungante` | 155 | `Membro(NAO_COMUNGANTE)` |

**Esta coluna é a única fonte confiável de categoria.** A regra que eu havia proposto no doc 09 §3 ("comungante se tiver `data_profissao_fe`") produziria 641 comungantes em vez de 1.291 — **erro de 50%**. Regra corrigida: `categoria` vem de `membro`, e `data_profissao_fe` é apenas um dado histórico opcional.

### 3.2 `oficial` → `Oficio`

| Valor | Qtd | Destino |
|---|---:|---|
| `Não oficial` | 2.581 | nada |
| `Presbítero` | 21 | `Oficio(PRESBITERO_REGENTE, EM_EXERCICIO)` |
| `Presbítero em disponibilidade` | 13 | `Oficio(PRESBITERO_REGENTE, DISPONIBILIDADE)` |
| `Diácono` | 7 | `Oficio(DIACONO, EM_EXERCICIO)` |

**Correção importante ao doc 09 §2.2**: eu havia escrito que `oficial` era só um flag e não deveria virar ofício. Errado — a coluna traz **tipo de ofício e a distinção de disponibilidade** (RN-OFI-11, Art. 54 §2º), que é exatamente a nuance que eu temia perder. **Pode e deve ser importada.**

Consistência: os 21 presbíteros são todos `Comungante` + `Ativo`. Limpo.

O que ainda **não** vem: `data_ordenacao`, `data_instalacao`, `data_termino_previsto`. Continuam no levantamento manual do doc 09 §6 — mas agora são **41 pessoas**, não 49.

⚠️ **Diáconos**: a coluna traz 7; o relatório 2025 declara 28. A Junta Diaconal está subrepresentada no CSV. Ver P16.

### 3.3 `situacao`

| Valor | Qtd | Leitura |
|---|---:|---|
| `Ativo` | 1.777 | |
| `Inativo` | 746 | |
| `Revisar` | 99 | **flag de qualidade de dado, não estado eclesiástico** |

⚠️ **`situacao` não é confiável sozinha para derivar `DEMITIDO`**:

| | com `data_demissao` | sem |
|---|---:|---:|
| Ativo | 2 | 1.775 |
| Inativo | **299** | **447** |
| Revisar | 11 | 88 |

**447 inativos sem data de demissão** e 2 ativos com data de demissão. A importação precisa de uma regra de precedência explícita (§5, P12).

`Revisar` não tem correspondente no modelo — é fila de trabalho. Proposta: `Membro.pendenciaRevisao = true`, preservando a `situacao` real ao lado.

### 3.4 `meio_admissao` → `forma_admissao`

| Valor no CSV | Qtd | `forma_admissao` |
|---|---:|---|
| `Jurisdição a pedido` | 831 | `JURISDICAO_A_PEDIDO` |
| `Profissão de fé e batismo` | 578 | `PROFISSAO_FE_E_BATISMO` |
| *(vazio)* | 452 | — |
| `Transferência` | 386 | `CARTA_TRANSFERENCIA` |
| `Profissão de fé` | 232 | `PROFISSAO_FE` |
| `Batismo infantil` | 84 | `BATISMO_INFANTIL` |
| `Restauração` | 27 | `RESTAURACAO` |
| `Jurisdição sobre os responsáveis` | 14 | `JURISDICAO_SOBRE_OS_PAIS` |
| `Jurisdição ex-offício` | 11 | `JURISDICAO_EX_OFFICIO` |
| `Transferência dos responsáveis` | 4 | `TRANSFERENCIA_DOS_PAIS` |
| `Transferência dos pais` | 2 | `TRANSFERENCIA_DOS_PAIS` |
| `Designação do presbitério` | 1 | `DESIGNACAO_PRESBITERIO` |

**Mapeamento 1-para-1 completo.** As 10 formas dos Arts. 16 e 17 estão todas representadas — o rol foi mantido com a linguagem da Constituição. Nenhum valor órfão.

### 3.5 `meio_demissao` → `forma_demissao`

| Valor no CSV | Qtd | `forma_demissao` |
|---|---:|---|
| *(vazio)* | 2.185 | — |
| `Exclusão por ausência` | 193 | `EXCLUSAO_POR_AUSENCIA` |
| `Transferência` | 173 | `CARTA_TRANSFERENCIA` |
| `Falecimento` | 35 | `FALECIMENTO` |
| `Jurisdição assumida` | 25 | `JURISDICAO_ASSUMIDA_POR_OUTRA` |
| `Transferência dos responsáveis` | 6 | `CARTA_TRANSFERENCIA` (não comungante) |
| `Transferência conselho` | 3 | ❓ ver P13 |
| `Transferência presbitério` | 1 | ❓ ver P13 |
| `Solicitação dos responsáveis` | 1 | `SOLICITACAO_DOS_PAIS` |

**Ausentes no CSV, presentes na CI**: `EXCLUSAO_DISCIPLINA`, `EXCLUSAO_A_PEDIDO`, `MOVIMENTO_PARA_ROL_SEPARADO`, `ORDENACAO_AO_MINISTERIO`, `MAIORIDADE_18`, `PROFISSAO_FE`.

> **Achado relevante**: não há **nenhuma** demissão por `Profissão de fé` de não comungante. Quando uma criança professa fé, o registro é simplesmente **editado** de "Não comungante" para "Comungante" — e a passagem se perde. É exatamente o histórico que o UC-M1-05 (transação demissão+admissão) existe para preservar daqui em diante. Não dá para reconstruir o passado.

### 3.6 `sexo` e `estado_civil`

`FEMININO` 1.001 · `MASCULINO` 761 · **vazio 860**
`CASADO` 1.127 · `SOLTEIRO` 897 · vazio 453 · `DIVORCIADO` 90 · `VIÚVO` 44 · `UNIÃO ESTÁVEL` 11

---

## 4. Formatos e semântica das demais colunas

| Coluna | Formato real | Tratamento |
|---|---|---|
| `id` | UUID, sem duplicatas | → `pessoa.id_legado` |
| `numero_ordem` | **`AAAA` + sequência**: `20181567`, `20240138`. Distribuição: 2018→957, 2023→203, 2022→188, 2019→161, 2021→70, 2024→38, 2020→27 | ⚠️ **não é inteiro sequencial** — ver P14 |
| datas | **ISO `AAAA-MM-DD`** | Direto. Pendência P10 do doc 09: **resolvida** |
| `created_at` / `updated_at` | `2026-03-11 19:21:21.66177+00` — timestamp com timezone | Origem é um Postgres (provável Supabase). Ver P17 |
| `foto` | caminho relativo: `picture/nome_uuid.jpeg` | Caminho de storage, não URL. Ver P15 |
| `conjuge`, `nome_pai`, `nome_mae` | **texto puro**, zero UUIDs | Casamento por nome — taxas em §4.4 |
| `telefone` | dígitos, um número por campo (`62986221306`) | Limpo. Formatar na exibição |
| `naturalidade` | `CIDADE/UF` maiúsculo | Direto |
| `endereco` | logradouro **com** número embutido (`R. 09, 177`) | Não tentar separar |
| `igreja_batismo` | quase sempre "Igreja Presbiteriana de Anápolis" | → `ato_pastoral.igreja_externa_nome` |
| `pastor_batismo` | nomes (`Samuel Vieira`) | → `ato_pastoral.oficiante_nome_externo` |
| `ata` | número puro (`970`, `949`) | → `membro.ata_admissao_legado` |
| `id_igreja` | misto: `IP Anápolis` e `3265` | **Descartado** (instrução sua) |
| `profissao_informada` | duplica `profissao` | **Descartado** (instrução sua) |

### 4.4 Casamento de vínculos familiares por nome

| Campo | Casam com alguém do rol | Taxa |
|---|---:|---:|
| `conjuge` | 554 / 838 | **66%** |
| `nome_mae` | 291 / 1.232 | 24% |
| `nome_pai` | 274 / 1.211 | 23% |

Cônjuges casam bem (ambos costumam ser membros). Pais raramente — a maioria não é membro da IPA. Confirma o desenho: criar `VinculoFamiliar` quando casar; senão gravar em `nome_pai_texto` / `nome_mae_texto` / `nome_conjuge_texto`. **Sem forçar cadastro de pessoas fantasma.**

### 4.6 `notes` — 90 registros, alto valor

Amostra real:

> `Duplicidade / Ata 949: Carta de transferência para Igreja Presbiteriana Pioneira / Ata 965`
> `Não constava no rol, por isso foi arrolado e em seguida transferido na ata 947.`
> `duplicidade 945 e 949`

São **anotações de correção do próprio rol**, muitas sinalizando duplicidade. Importar como `pessoa.observacoes` e **gerar fila de revisão manual** — não tentar interpretar automaticamente.

---

## 5. Os três problemas de dados

### 5.1 ⚠️ 521 registros ativos sem categoria

Dos 554 com `membro` vazio, **521 estão `Ativo`**. Diagnóstico:

| Indício | Valor |
|---|---|
| `meio_admissao` preenchido | 463 / 521 (89%) |
| `data_nascimento` preenchido | 487 / 521 (93%) |
| `data_admissao` preenchido | 330 / 521 |
| `created_at` em **2026-03 / 2026-04** | 401 / 521 |
| Meios: Jurisdição a pedido 206 · Transferência 130 · Prof. de fé e batismo 76 · Prof. de fé 45 · Batismo infantil 6 | |

**Conclusão**: não são registros ruins — são **membros de verdade** cadastrados recentemente (março/abril de 2026) em que a coluna `membro` não foi preenchida. 89% têm forma de admissão registrada.

**Regra de inferência possível** (a confirmar em P11): `Batismo infantil` e `Jurisdição sobre os responsáveis` → não comungante; as demais formas → comungante. Isso classificaria 463 dos 521. Os 58 restantes ficam para triagem manual.

### 5.2 ⚠️ 860 registros sem sexo

Distribuição entre os **ativos**:

| Categoria | Ativos | Sem sexo |
|---|---:|---:|
| Comungante | 1.125 | **103** |
| Não comungante | 131 | **45** |
| *(vazio)* | 521 | **361** |

Como toda estatística ao Presbitério é segmentada por sexo, o campo importa — mas **não pode ser obrigatório na importação**. Correção no schema (doc 10): `sexo` passa a **nullable**, com pendência de preenchimento em vez de erro bloqueante.

**Mitigação barata**: inferência por prenome resolve a maioria em segundos e deixa só os ambíguos (Darci, Nair, Ariel…) para revisão manual. Sempre marcada como inferida.

### 5.3 ⚠️ 34 nomes duplicados

Amostra:

```
Mariana Borges Pereira            nasc=2014-03-27 Comungante Ativo | nasc=2014-03-27 (vazio) Ativo
Elisa Valentina Corrêa de Freitas nasc=2012-03-30 (vazio) Ativo    | nasc=2012-03-30 (vazio) Ativo
João Gabriel Andrade Roriz Monteiro nasc=2008-08-08 (vazio) Revisar| nasc=2008-08-08 (vazio) Ativo
Júlia Ribeiro Fernandes           nasc=-          Comungante Ativo | nasc=2011-12-06 (vazio) Ativo
```

**Mesma data de nascimento na maioria** → são duplicatas reais, não homônimos. Somadas às marcações de "duplicidade" em `notes`, formam a fila de deduplicação.

**Importar tudo e marcar**, nunca mesclar automaticamente. Fusão de pessoas é decisão humana.

---

## 6. Reconciliação com o relatório 2025 (diagnóstico, **não** validação)

Você já determinou que os números do relatório não devem servir de critério de aceite. Registro a comparação apenas para dimensionar a distância:

| | Relatório 2025 | CSV |
|---|---:|---:|
| Comungantes | 1.404 | 1.125 ativos |
| Não comungantes | 265 | 131 ativos |
| Sem categoria | — | 521 ativos |
| **Total ativo** | **1.669** | **1.777** |

Diferença de 108 no total. Se a inferência de §5.1 rodar, os 521 se distribuem e a distância cai — mas **não haverá coincidência exata, e não se deve buscá-la.** O rol do sistema passa a ser a fonte da verdade; o relatório do ano que vem sairá dele.

**Critério de aceite da importação, revisado**:
1. As 2.622 linhas entram sem perda — nenhuma descartada silenciosamente.
2. Nenhum valor de `meio_admissao` / `meio_demissao` / `membro` / `oficial` fica sem mapeamento.
3. As contagens por categoria e situação batem com o CSV de origem, não com o relatório.
4. As três filas de revisão (§5) são geradas com os totais esperados: ~521, ~860, ~34.

---

## 6.1 Correção a este documento após a simulação

Ao simular as regras decididas, dois pontos do §3.1 e do §5.1 se mostraram imprecisos:

1. **Os 622 `Não membro` são ex-membros, não não-membros.** Todos os 622 têm histórico de membresia (385 com `numero_ordem`, 292 com `meio_admissao`, 287 com `meio_demissao`). Devem receber `Membro(situacao = DEMITIDO)`, não ficar como `Pessoa` pura — caso contrário 385 números de rol históricos se perdem. Ver doc 13 §4.1.
2. **A inferência de P11(a) resolve mais do que eu estimei**: 466 registros classificados, sobrando **88** em `NAO_DEFINIDO` (eu havia estimado 58 sobre uma base menor). Números finais medidos no doc 13 §7.

---

## 7. Decisões pendentes — ✅ **todas respondidas**

| # | Decisão | Onde foi aplicada |
|---|---|---|
| P11 | (a) inferir categoria pela forma de admissão | doc 13 §4.2 |
| P12 | **(b) `situacao` manda** | doc 13 §4.3 — **três consequências tratadas em §6** |
| P13 | `Transferência presbitério` = ordenação ao ministério | doc 13 §4.5 |
| P14 | (a) preservar `numero_ordem` como texto | doc 13 §4.4 — abriu a **P19** |
| P15 | fotos disponíveis | doc 13 §8 |
| P16 | diáconos desatualizados, correção no sistema novo | doc 13 §4.7 |
| P17 | **substitui** o sistema atual | doc 13 §2 — importação única, sem sincronização |
| P18 | (a) inferir sexo por prenome | doc 13 §4.6 |

Pendências novas abertas pela simulação: **P19** (numeração de novos membros) e **P20** (data de corte), no doc 13 §9.

<details>
<summary>Texto original das decisões (histórico)</summary>

### P11 — Os 521 ativos sem categoria
- [ ] **(a) Recomendado** — inferir pela forma de admissão (Batismo infantil / Jurisdição sobre os responsáveis → não comungante; demais → comungante), marcar `categoriaInferida = true`, e gerar fila de revisão.
- [ ] (b) Importar todos como `NAO_DEFINIDO` e revisar 521 à mão.
- [ ] (c) Não importar até a secretaria classificar na planilha.

**Decisão:** (a)

### P12 — Precedência entre `situacao` e `data_demissao`
447 inativos não têm data de demissão; 2 ativos têm.
- [ ] **(a) Recomendado** — `data_demissao` ou `meio_demissao` preenchidos ⇒ `DEMITIDO` (o evento manda). Inativo sem nenhum dos dois ⇒ importar como `ATIVO` + `pendenciaRevisao`. Ativo com data de demissão ⇒ `DEMITIDO` + pendência.
- [ ] (b) `situacao` manda sempre.

**Decisão:** (b) para a importação, situação manda.

### P13 — `Transferência conselho` (3) e `Transferência presbitério` (1)
O que significam? Hipótese: transferência processada via Conselho × via Presbitério — ambas `CARTA_TRANSFERENCIA`. Ou "presbitério" seria membro ordenado ministro (`ORDENACAO_AO_MINISTERIO`, Art. 23 §3º)?
**Decisão:** "presbitério" seria membro ordenado ministro

### P14 — `numero_ordem` com prefixo de ano
O formato é `AAAA` + sequência (`20181567`), 63% preenchido, sem duplicatas. Isso contradiz a decisão B3-a (inteiro sequencial permanente).
- [ ] **(a) Recomendado** — preservar como **texto**, exatamente como está, e gerar novos no mesmo padrão (`AAAA` + sequência do ano). Continuidade total com o que a secretaria já usa.
- [ ] (b) Renumerar tudo sequencialmente (perde a referência dos livros físicos).
- [ ] (c) Manter o legado em campo separado e criar numeração nova.

**Decisão:** (a)

### P15 — Fotos
900 caminhos `picture/nome_uuid.jpeg`. Você tem acesso aos arquivos para migrar junto?
**Decisão:** Sim

### P16 — Diáconos
O CSV traz 7 diáconos; o relatório 2025 declara 28. A Junta Diaconal está no rol de outro lugar ou os registros nunca foram atualizados?
**Decisão:** registros estão desatualizados, em breve vamos atualizar já no sistema novo.

### P17 — Sistema de origem
`created_at` com timezone, UUIDs e caminhos `picture/` indicam um Postgres/Supabase em uso desde março de 2026. Existe uma aplicação rodando hoje? Se sim, o novo sistema **substitui** ou **convive** com ela?
> Muda a estratégia: substituição = importação única; convivência = sincronização, que é outro projeto.

**Decisão:** substitui

### P18 — Inferência de sexo por prenome
- [ ] **(a) Recomendado** — inferir e marcar como inferido, deixando os ambíguos em branco para revisão.
- [ ] (b) Deixar todos os 860 em branco.

**Decisão:** (a)

</details>
