# 08 — Análise do relatório estatístico oficial (CSM-IPB 2021 v8.0)

Fonte: `relatorio-igreja.pdf` — *Informações Cadastrais e Estatísticas de Comunidade Presbiteriana*, exercício **2025**, preenchido pela IPA.
Sínodo de Anápolis (SAN) · Presbitério de Anápolis (PANA) · formulário `CSM-IPB - 2021-v.8.0`.

> **Este documento é o contrato de saída do sistema**: o formulário que a igreja é obrigada a entregar ao Presbitério (RN-REL-04) define quais eventos o modelo precisa registrar.
>
> ### ⚠️ Ressalvas do usuário — três partes deste documento NÃO valem
>
> 1. **Os números de membros do relatório não batem com o rol e não servem de critério de validação.** Todo o §4.3 e o "teste de aceitação" derivado dele estão **revogados** — o critério revisado está no doc 12 §6. O rol do sistema passa a ser a fonte da verdade; o relatório do próximo exercício sairá dele, e não o contrário.
> 2. **As informações de sociedades internas e departamentos (§3.3) não devem ser consideradas.** Hoje a IPA tem vários ministérios designados **sem formalidade alguma além do registro em ata dos respectivos líderes**. Não há sociedade com estatuto. → `OrganizacaoInterna` **volta a 🟡**; a modelagem correta desses ministérios é `Designacao` (RN-CON-41), que já existe no modelo. A "contradição com a decisão B2" que eu apontei era minha, não sua: eu tratei o formulário como fato e sua resposta como erro.
> 3. **As informações de Escola Bíblica (§3.2 e §6.1) não entram agora.** `EscolaDominical`, `TurmaEBD` e `AtuacaoEBD` saem do MVP → ⚪ backlog.
>
> O que **continua válido**: a decodificação da estrutura do formulário (quais campos existem), o mapeamento das formas de admissão/demissão para as linhas do relatório (§4.1 e §4.2), e as duas correções de modelo que ele revelou — `ORDENACAO_AO_MINISTERIO` e `MOVIMENTO_PARA_ROL_SEPARADO` como formas de demissão.

---

## 1. Porte real da IPA (muda decisões de UX)

| Indicador | 2025 | 2024 |
|---|---:|---:|
| Comungantes | **1.404** (662 M / 742 F) | 1.216 |
| Não comungantes | **265** (109 M / 156 F) | 282 |
| **Rol total** | **1.669** (771 M / 898 F) | 1.498 |
| Pastores | 9 | |
| Presbíteros | 21 | |
| Diáconos | 28 | |
| Congregações | 2 | |
| Pontos de pregação | 1 | |
| Escolas dominicais | 3 (22 professores, 450 alunos) | |
| Departamentos internos | 4 (645 membros vinculados) | |

**Consequências diretas para o projeto:**

1. **Não é uma igreja pequena.** 1.669 pessoas e +188 comungantes de saldo em um ano. Telas de listagem precisam de paginação, busca por nome parcial e filtros desde a E1 — não dá para renderizar tudo.
2. **O Conselho tem ~30 membros** (9 pastores + 21 presbíteros). O quórum espiritual (RN-CON-02) é pastor + 7 presbíteros; o administrativo (RN-CON-04) é 16. **O regime excepcional do Art. 76 §1º nunca se aplica aqui** — pode sair do MVP.
3. **Jurisdição foi a maior via de entrada em 2025: 121 admissões**, contra 45 por profissão de fé e batismo e 17 por transferência. O assistente de admissão precisa tratar jurisdição como caminho principal, não como exceção.
4. **A importação inicial traz ~1.669+ linhas** (mais os demitidos históricos). O importador precisa de relatório de erros linha a linha, não de "deu erro".

---

## 2. Seção I — Identificação

| Campo do formulário | Entidade | Situação |
|---|---|---|
| Ano | `RelatorioAnual.exercicio` | ✅ |
| Sínodo + sigla (SAN) | `Igreja.sinodoNome`, `Igreja.sinodoSigla` | ⚠️ **falta sigla** |
| Presbitério + sigla (PANA) | `Igreja.presbiterioNome`, `Igreja.presbiterioSigla` | ⚠️ **falta sigla** |
| Nome (Igreja/Congregação) | `Igreja.nome` | ✅ |
| Endereço, Nº, Complemento, Bairro, Cidade, UF, CEP | `Igreja.endereco` | ✅ |
| Caixa Postal + CEP da Cx. P. | `Igreja.caixaPostal` | ⚠️ **falta** |
| Telefones | `Igreja.telefones[]` | ⚠️ **falta ser lista** |
| E-mail | `Igreja.email` | ⚠️ **falta** |
| Data de organização (14/07/1953) | `Igreja.dataOrganizacao` | ✅ |
| CNPJ (00.045.369/0001-10) | `Igreja.cnpj` | ✅ |
| Site | `Igreja.site` | ⚠️ **falta** |

**Ação**: ampliar `Igreja` com `sinodoSigla`, `presbiterioSigla`, `caixaPostal`, `caixaPostalCep`, `telefones[]`, `email`, `site`.

---

## 3. Seção II — Estrutura da comunidade

### 3.1 Liderança formal

| Campo | Derivação a partir do modelo | Situação |
|---|---|---|
| Pastores | count `RelacaoPastoral` ativa em 31/12 | ✅ |
| Licenciados | — | 🆕 **não existe no modelo** |
| Presbíteros | count `Oficio(PRESBITERO_REGENTE, EM_EXERCICIO)` | ✅ |
| Diáconos | count `Oficio(DIACONO, EM_EXERCICIO)` | ✅ |
| Evangelistas | count `RelacaoPastoral(EVANGELISTA)` | ✅ |
| Missionários | count `RelacaoPastoral(MISSIONARIO)` | ✅ |
| Candidatos | — | 🆕 **não existe no modelo** |

**🆕 Nova entidade `VinculoMinisterial`** (🟡): cobre `LICENCIADO` e `CANDIDATO_AO_MINISTERIO`. São pessoas da igreja local em processo perante o **Presbitério** (CI Art. 115: quem se sente chamado apresenta atestado **do Conselho** declarando vocação demonstrada). A igreja não conduz o processo, mas **conta essas pessoas** e emite o atestado.

Campos: `pessoaId`, `tipo` (`CANDIDATO` \| `LICENCIADO`), `dataAtestadoDoConselho`, `resolucaoAtestadoId`, `dataLicenciatura`, `dataOrdenacao`, `status` (`ATIVO` \| `ORDENADO` \| `CASSADO`), `presbiterioNome`.

### 3.2 Estrutura do trabalho

| Campo | Derivação | Situação |
|---|---|---|
| Congregações da Igreja (2) | count `Congregacao(tipo=CONGREGACAO, ATIVA)` | ✅ |
| Pontos de Pregação (1) | count `Congregacao(tipo=PONTO_DE_PREGACAO, ATIVA)` | ✅ |
| Escolas Dominicais (3) | — | 🆕 **lacuna** |
| Professores da Escola Dominical (22) | — | 🆕 **lacuna** |
| Alunos EBD ano atual (450) | — | 🆕 **lacuna** |
| Alunos EBD ano anterior (450) | — | 🆕 **lacuna** |

**🆕 Lacuna 1 — Escola Dominical.** Ver §6.1.

### 3.3 Departamentos internos

Colunas do formulário: **Nº Deptos.** e **Nº de Membros**. Linhas fixas: `UCP`, `UPA`, `UMP`, `SAF`, `UPH`, `Outras`, `TOTAIS`.

Declarado pela IPA em 2025:

| Linha | Nº Deptos. | Nº Membros |
|---|---:|---:|
| UCP | 1 | 340 |
| UPA / UMP / SAF / UPH | — | — |
| Outras | 3 | 305 |
| **TOTAIS** | **4** | **645** |

> ### ⚠️ Contradição com a decisão B2
>
> Você respondeu em B2: *"Nenhum[a] [sociedade interna], atualmente possui ministérios designados com liderança, mas sem estatuto"*.
>
> Mas o relatório de 2025 declara **4 departamentos com 645 membros vinculados**, incluindo uma UCP.
>
> As duas coisas podem ser verdadeiras ao mesmo tempo — e é isso que o modelo precisa refletir: existem **organizações internas que são contadas na estatística** sem serem **sociedades domésticas com estatuto aprovado** no sentido do Art. 83 *p*/*q*.
>
> **Resolução proposta (ver PENDÊNCIA P1, §7)**: uma entidade só, `OrganizacaoInterna`, com dois eixos independentes:
> - `natureza`: `SOCIEDADE_COM_ESTATUTO` (dispara os deveres do Art. 83 *o*, *p*, *q*: aprovar estatuto, dar posse à diretoria, examinar livros) · `DEPARTAMENTO_OU_MINISTERIO` (só liderança designada, Art. 83 *x* / RN-CON-41)
> - `categoriaIPB`: `UCP` \| `UPA` \| `UMP` \| `SAF` \| `UPH` \| `OUTRAS` — **existe unicamente para somar as linhas deste formulário**
>
> Assim, um ministério de louvor sem estatuto é `DEPARTAMENTO_OU_MINISTERIO` + `OUTRAS`, entra no total de 645 e **não** dispara exame de livros. Nada é forçado a ter estatuto.
>
> Isso promove `OrganizacaoInterna` de 🟡 para 🟢 — ela é obrigatória para fechar a Seção II.

**Liderança designada por 1 ano** (o que você descreveu em B2) = `Designacao` com `dataInicio`/`dataFim` e `resolucaoId`, apontando para a `OrganizacaoInterna`. Modelo já suporta; só falta o vínculo.

---

## 4. Seção III — Rol de membros

**A descoberta mais importante: tudo é segmentado por MASC / FEM / TOTAL.** Toda contagem de entrada e saída precisa ser desdobrada por sexo. `Pessoa.sexo` deixa de ser conveniência e passa a ser **obrigatório** (já era, por RN-OFI-03).

### 4.1 Comungantes — linhas do formulário → formas do modelo

| Linha do formulário | 2025 | `Admissao.forma` / `Demissao.forma` do modelo |
|---|---:|---|
| **ADMISSÃO** | | |
| Profissão de Fé | 14 | `PROFISSAO_FE` |
| Profissão de Fé e Batismo | 45 | `PROFISSAO_FE_E_BATISMO` |
| Transferência | 17 | `CARTA_TRANSFERENCIA` |
| Jurisdição | **121** | `JURISDICAO_A_PEDIDO` **+** `JURISDICAO_EX_OFFICIO` *(o formulário funde as duas)* |
| Restauração | 0 | `RESTAURACAO` |
| Designação do Presbitério | 0 | `DESIGNACAO_PRESBITERIO` |
| **DEMISSÃO** | | |
| Transferência | 2 | `CARTA_TRANSFERENCIA` |
| Falecimento | 5 | `FALECIMENTO` |
| Exclusão | 2 | `EXCLUSAO_DISCIPLINA` **+** `EXCLUSAO_A_PEDIDO` **+** `EXCLUSAO_POR_AUSENCIA` *(fundidas)* |
| **Ordenação** | 0 | 🆕 `ORDENACAO_AO_MINISTERIO` — **faltava no modelo** |
| **Rol Separado** | 0 | 🆕 `MOVIMENTO_PARA_ROL_SEPARADO` — **faltava no modelo** |

**Duas correções obrigatórias no doc 04:**

1. **`ORDENACAO_AO_MINISTERIO` é forma de demissão.** Eu havia tratado o Art. 23 §3º (membro ordenado ministro vai para o rol do Presbitério) como `[FRONTEIRA]` informativa. O formulário oficial o trata como **linha de saída do rol**. Corrigido.

2. **`ROL_SEPARADO` é saída, não apenas status.** O formulário lista "Rol Separado" entre as **demissões**, ou seja: mover alguém para o rol separado **subtrai** do total de comungantes do ano.
   → Consequência dura para o modelo: `Membro.situacao = ROL_SEPARADO` **não conta** em "Comungantes Ano Atual". A máquina de estados do doc 05 precisa gerar um evento `Demissao` na entrada do rol separado e um evento `Admissao(RESTAURACAO)` se a pessoa for localizada.
   → E gera a **PENDÊNCIA P2** (§7): quando alguém já no rol separado é excluído 2 anos depois (RN-MEM-23), isso conta de novo na linha "Exclusão"? Se contar, a pessoa sai do rol duas vezes.

### 4.2 Não comungantes

| Linha do formulário | 2025 | `forma` do modelo |
|---|---:|---|
| **ADMISSÃO** — Batismo | 18 | `BATISMO_INFANTIL` |
| Transferência | 2 | `TRANSFERENCIA_DOS_PAIS` |
| Jurisdição ex-officio | 0 | `JURISDICAO_SOBRE_OS_PAIS` |
| **DEMISSÃO** — Profissão de Fé | 37 | `PROFISSAO_FE` |
| Transferência | 0 | `CARTA_TRANSFERENCIA` |
| Falecimento | 0 | `FALECIMENTO` |
| Exclusão | 0 | `EXCLUSAO` |

**Observação crítica**: o formulário **não tem linha para "atingiu 18 anos"**, embora o Art. 24 *c* a preveja como forma de demissão. Só existe "Exclusão". → **PENDÊNCIA P3** (§7).

### 4.3 Fechamento aritmético (validação do sistema)

O formulário se valida sozinho, e o sistema deve reproduzir exatamente:

```
Comungantes Ano Atual   = Comungantes Ano Anterior + Σ Admissões − Σ Demissões
1.404                   = 1.216 + 197 − 9              ✔ (diferença declarada: +188)

Não Comung. Ano Atual   = Não Comung. Ano Anterior + Σ Admissões − Σ Demissões
265                     = 282 + 20 − 37                 ✔ (diferença declarada: −17)

ROL ATUAL = Comungantes + Não Comungantes = 1.404 + 265 = 1.669   ✔
```

E o mesmo tem de fechar em cada coluna (MASC e FEM) separadamente.

**Regra de implementação**: o UC-M8-01 deve rodar essa conferência e **recusar-se a fechar o relatório** se algum eixo não bater. Um relatório que não fecha significa evento faltando ou data errada — exatamente o erro que o sistema existe para eliminar.

---

## 5. Seção IV — Informações financeiras

> ### ⚠️ Isto conflita parcialmente com a decisão A5

Você decidiu (A5-a) deixar finanças fora da v1. Mas o formulário anual **exige** dois quadros financeiros completos: **movimento do ano anterior** e **previsão orçamentária do próximo exercício**.

**O conflito é menor do que parece**: o formulário pede apenas **totais por rubrica**, uma vez por ano. Não pede lançamento, extrato nem conciliação.

**Resolução proposta**: criar `RelatorioFinanceiroAnual` — ~40 campos numéricos digitados uma vez por ano pelo tesoureiro, sem qualquer módulo de finanças. Isso preserva integralmente a decisão A5 (nada de dízimos, ofertas individuais, contas a pagar) e fecha a obrigação constitucional.

| Bloco | Rubricas (idênticas nos dois quadros) |
|---|---|
| Saldo | Saldo do ano anterior |
| **Receitas** | Dízimos · Ofertas · Ofertas Missionárias · Ofertas Específicas · Receitas Financeiras · Empréstimos IPB/JPEF · Parcerias · Outras Receitas · **Total da Receita Anual** · **Grande Total** |
| **Despesas** | Patrimônio · Causas Locais · Evangelismo Local · Missões · Ação Social · **Sustento Pastoral** · **Verba Presbiterial** · **Dízimo ao Supremo Concílio** · Empréstimos IPB/JPEF · Outras Despesas · **Total da Despesa Anual** · **Saldo Ano Seguinte** · **Grande Total** |

Cada rubrica tem valor **e percentual** (o percentual é calculado, não digitado — no PDF os campos aparecem como `#DIV/0!`, sinal de que a planilha de origem estava com os valores em branco).

Três rubricas amarram no modelo já existente: `Sustento Pastoral` ↔ `RelacaoPastoral.vencimentos` (RN-PAT-06); `Dízimo ao Supremo Concílio` ↔ RN-PAT-05; `Patrimônio` ↔ `DeliberacaoPatrimonial`.

---

## 6. Lacunas encontradas no modelo v1

### 6.1 🆕 Escola Dominical — não existe no modelo

O formulário exige 4 números: nº de escolas dominicais, nº de professores, nº de alunos do ano atual e do ano anterior.

Duas opções (ver **PENDÊNCIA P4**):

- **(a) Mínimo** — campos digitados anualmente em `EstatisticaAnual`. Custo quase zero, mas não ajuda a secretaria no dia a dia.
- **(b) Recomendado** — entidade `EscolaDominical` (nome, congregação, ativa) + `TurmaEBD` (nome, faixa etária) + `AtuacaoEBD` (pessoa, papel `PROFESSOR`\|`ALUNO`, turma, período). Os 4 números viram derivação, e a igreja ganha um controle que hoje não tem. Custo: um módulo pequeno a mais.

Note que **os 450 alunos aparecem idênticos nos dois anos** — sinal clássico de número repetido por falta de controle. Argumento a favor de (b).

### 6.2 🆕 Licenciados e candidatos ao ministério

Resolvido pela entidade `VinculoMinisterial` (§3.1). O gatilho real é o Art. 115 *b*: o **Conselho** emite o atestado de vocação. É ato do Conselho, logo é `Resolucao`, logo pertence ao sistema.

### 6.3 🆕 Departamentos internos sem estatuto

Resolvido pela entidade `OrganizacaoInterna` com dois eixos (§3.3).

---

## 7. Pendências abertas por esta análise

Responda quando puder — nenhuma bloqueia o início da E1.

### P1 — Departamentos internos
Quais são, hoje, as 4 organizações internas declaradas (1 UCP + 3 "Outras")? Alguma tem estatuto aprovado pelo Conselho e diretoria empossada (Art. 83 *q*)?
**Recomendação**: classificar todas como `DEPARTAMENTO_OU_MINISTERIO` até que alguma apresente estatuto.
**Resposta:**

### P2 — Exclusão de quem está no rol separado
Quando um membro no rol separado é excluído após 2 anos (RN-MEM-23), a exclusão é lançada de novo na linha "Exclusão" do formulário?
**Recomendação**: **não** — ele já saiu da contagem ao entrar no rol separado; lançar de novo subtrai a mesma pessoa duas vezes e quebra o fechamento aritmético. Confirmar com o secretário do Conselho.
**Resposta:**

### P3 — Não comungante que completa 18 anos
Em que linha do formulário isso é lançado? O Art. 24 *c* prevê a demissão, mas o formulário só tem "Exclusão".
**Observação**: em 2025 saíram 37 não comungantes por profissão de fé e **nenhum** por exclusão — o que sugere que a IPA hoje **não** dá baixa por maioridade, mantendo a pessoa no rol. Isso merece confirmação, porque tem efeito direto sobre 265 pessoas.
**Recomendação**: mapear para "Exclusão" e alertar o Conselho antes de cada baixa automática.
**Resposta:**

### P4 — Escola Dominical
Opção (a) números digitados ou (b) módulo com turmas, professores e alunos?
**Recomendação**: (b), pela evidência dos 450 repetidos.
**Resposta:**

### P5 — Quem preenche o quadro financeiro?
O tesoureiro do Conselho digita os ~40 totais anuais, ou esses números vêm prontos de um contador/planilha?
**Recomendação**: campo digitado com importação de planilha opcional depois.
**Resposta:**

### P6 — Seção V
O PDF salta da Seção IV para a VI. Há uma Seção V no formulário original (talvez oculta na planilha de origem)?
**Resposta:**

---

## 8. Efeito consolidado sobre a prioridade dos módulos

Tabela revisada após as ressalvas do usuário (§ topo do documento):

| Módulo | v1 | v2 | **v3 (vigente)** | Motivo |
|---|:-:|:-:|:-:|---|
| M7 Congregações | 🟡 | 🟢 | **🟢** | Decisão A3-b: 2 congregações + 1 ponto de pregação existem hoje |
| Organizações internas | 🟡 | 🟢 | **🟡** | Ressalva 2: só ministérios informais → modelar como `Designacao` |
| Escola Dominical | — | 🟢 | **⚪** | Ressalva 3: fora por ora |
| `VinculoMinisterial` | — | 🟡 | **🟡** | Licenciados/candidatos — atestado é ato do Conselho (Art. 115 *b*) |
| `RelatorioFinanceiroAnual` | ⚪ | 🟢 | **🟡** | Obrigação real do formulário, mas não bloqueia a E1 |
| Regime excepcional Art. 76 §1º | 🟢 | ⚪ | **⚪** | 21 presbíteros — nunca se aplica |
| M9 Finanças (dízimos, ofertas) | ⚪ | ⚪ | **⚪** | Mantido fora, conforme A5 |

O modelo vigente está no doc `04-modelo-de-entidades.md` (v3).
