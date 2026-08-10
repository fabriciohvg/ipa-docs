# 11 — Spec M1: Pessoas e Rol de Membros

Primeiro módulo a construir (Entrega **E1**). Estrutura conforme o padrão fixado no doc 01, FASE 5.

---

## Objetivo em uma frase

Manter em dia o rol de membros comungantes e não comungantes da IPA — obrigação direta do Conselho pelo Art. 83 *l* — com histórico de admissão e demissão suficiente para que a estatística anual ao Presbitério se calcule sozinha.

---

## Contexto que dimensiona o módulo

| Fato | Origem | Consequência |
|---|---|---|
| **2.622 registros**; 1.777 ativos (1.125 comungantes · 131 não comungantes · **521 sem categoria**) | CSV real (doc 12) | Listagem paginada e busca são requisito, não melhoria |
| **831 admissões históricas por jurisdição a pedido**, contra 386 por transferência | CSV | Jurisdição é o caminho principal, não a exceção |
| **860 sem sexo · 554 sem categoria · 447 inativos sem data de demissão · 34 nomes duplicados** | CSV | **A fila de revisão é funcionalidade de primeira classe**, não relatório de erro |
| `oficial` traz 21 presbíteros, 13 em disponibilidade, 7 diáconos | CSV | 41 ofícios já importáveis na E1 |
| 2 congregações + 1 ponto de pregação | Decisão A3-b | Lotação obrigatória desde a E1 |
| Operadores: secretária, secretário do Conselho, pastores | Decisão B7 | Duas UX no mesmo módulo — ver §5.1 |

⚠️ **Os números do relatório estatístico 2025 não servem de validação** (instrução do usuário; divergência real de 108 pessoas). O rol do sistema passa a ser a fonte da verdade.

---

## Entidades envolvidas

**Donas**: `Pessoa` · `PessoaContato` · `VinculoFamiliar` · `Membro` · `Admissao` · `Demissao`
**Consumidas**: `Congregacao` (lotação) · `AtoPastoral` (batismo e profissão de fé) · `Resolucao` (ato do Conselho que admitiu/demitiu)

**Dependência mínima para começar**: migrations `001–004` do doc 10.

> **Acoplamento com M3 resolvido assim**: enquanto o módulo de reuniões não existir, `admissao.resolucao_id` e `demissao.resolucao_id` ficam nulos e a UI pede apenas **"nº e data da ata"** em texto livre (`ata_admissao_legado`). Quando M3 entrar, o campo vira seletor de resolução. **M1 não espera por M3.**

---

## Casos de uso

### UC-M1-01 — Cadastrar pessoa
**Ator**: secretária · **Gatilho**: alguém novo aparece na igreja
**Passos**: informar nome e sexo (obrigatórios) → demais dados → salvar.
**Resultado**: `Pessoa` criada, ainda **sem** vínculo de membro.
**Regra**: RN-MEM-01. `sexo` é bloqueante — sem ele a estatística não fecha (doc 08 §4).

### UC-M1-02 — Registrar vínculo familiar
**Ator**: secretária · **Gatilho**: cadastro de família, batismo infantil
**Passos**: buscar pessoa relacionada → escolher tipo → marcar "menor sob guarda" se aplicável.
**Resultado**: `VinculoFamiliar` bidirecional.
**Regras**: RN-MEM-11, RN-TRF-03, RN-ATO-04.
**Nota**: se a pessoa relacionada não existir no sistema, gravar em `nome_pai_texto`/`nome_mae_texto`/`nome_conjuge_texto` sem forçar cadastro.

### UC-M1-03 — Admitir membro comungante ⭐
**Ator**: secretária ou secretário do Conselho · **Gatilho**: resolução do Conselho admitindo alguém
**Passos**:
1. Selecionar pessoa existente ou cadastrar nova.
2. Escolher a forma (7 opções do Art. 16) — **jurisdição em primeiro lugar na lista**, por ser a mais usada.
3. Preencher os campos condicionais da forma (§4.1).
4. Informar data da admissão e nº/data da ata.
5. Definir lotação (sede, congregação ou ponto de pregação).
6. Sistema atribui `numero_rol` sequencial.

**Resultado**: `Membro(COMUNGANTE, ATIVO)` + `Admissao`.
**Regras**: RN-MEM-10, RN-MEM-13, RN-MEM-15.
**Validações**: pessoa não pode já ter `Membro` ativo · jurisdição a pedido exige documento escrito com razões (RN-MEM-13) · jurisdição *ex officio* só sobre presbiterianos (RN-MEM-14) · *ex officio* exige 1 ano de residência (RN-MEM-12).

### UC-M1-04 — Admitir membro não comungante
**Ator**: secretária · **Gatilho**: batismo infantil ou transferência dos pais
**Passos**: selecionar/criar pessoa → escolher forma (3 opções do Art. 17) → **vincular pai/mãe/responsável (obrigatório)** → data e ata.
**Resultado**: `Membro(NAO_COMUNGANTE, ATIVO)` + `Admissao`.
**Regras**: RN-MEM-11, RN-ATO-04.
**Validação**: ao menos um responsável **em plena comunhão** na data (RN-MEM-06). Se nenhum estiver, **avisar e permitir prosseguir com justificativa** — a decisão é do Conselho, não do sistema.

### UC-M1-05 — Profissão de fé: promover não comungante a comungante ⭐
**Ator**: secretária · **Gatilho**: profissão de fé examinada pelo Conselho
**Passos**: abrir ficha do não comungante → "Registrar profissão de fé" → data, oficiante, ata.
**Resultado**, numa **transação única**:
1. `Demissao(forma = PROFISSAO_FE)` do rol de não comungantes
2. `Admissao(forma = PROFISSAO_FE)` no rol de comungantes
3. `Membro.categoria` → `COMUNGANTE`, `data_profissao_fe` preenchida
4. `AtoPastoral(PROFISSAO_DE_FE)` + participante

**Regras**: RN-MEM-25, RN-ATO-05.
**Por que os dois eventos**: o formulário oficial lança a mesma pessoa como *saída* dos não comungantes e *entrada* dos comungantes (37 e 14 em 2025). Um evento só quebra o fechamento dos dois quadros.

### UC-M1-06 — Demitir membro
**Ator**: secretária ou secretário do Conselho · **Gatilho**: resolução do Conselho
**Passos**: abrir ficha → "Demitir" → escolher forma → data e ata → confirmar.
**Resultado**: `Demissao` + `Membro.situacao = DEMITIDO`.
**Regras**: RN-MEM-20, RN-MEM-21, RN-MEM-22.
**Validações**: bloquear se houver processo disciplinar em andamento e a forma for transferência ou exclusão a pedido (RN-MEM-22) — regra já escrita, ativa quando M9 existir.

### UC-M1-07 — Rol separado e exclusão por ausência
**Ator**: secretário do Conselho · **Gatilho**: alerta do sistema (1 ano de paradeiro ignorado)
**Passos**: painel de alertas → selecionar pessoas → "Propor rol separado" → registrar ata → confirmar.
**Resultado**: `Demissao(MOVIMENTO_PARA_ROL_SEPARADO)` + `situacao = ROL_SEPARADO`.
**Regra**: RN-MEM-23.
⚠️ **Entrar no rol separado retira da contagem de comungantes** (doc 08 §4.1). Após mais 2 anos, o alerta propõe exclusão — ver pendência P2 do doc 08 antes de implementar a segunda etapa.

### UC-M1-08 — Consultar o rol
**Ator**: todos · **Gatilho**: uso diário
**Filtros**: categoria · situação · congregação · sexo · faixa etária · período de admissão · forma de admissão.
**Ações**: exportar CSV/PDF · lista de aniversariantes · rol para assembleia (só comungantes em plena comunhão).
**Regras**: RN-CON-30, RN-REL-02.

### UC-M1-09 — Ficha completa do membro
Abas: **Dados** · **Histórico** (admissões, demissões, mudanças de categoria em linha do tempo) · **Família** · **Atos pastorais** · **Ofícios e mandatos** (vem de M2).
**Regra**: RN-REL-01.

### UC-M1-10 — Verificar plena comunhão numa data
**Ator**: sistema (interno) e usuário (consulta)
Consulta da view `membro_em_plena_comunhao`. É a checagem mais usada do sistema todo: voto, elegibilidade, Ceia, apresentar filho ao batismo.
**Regras**: RN-MEM-06, RN-DIS-07.

### UC-M1-11 — Lotar membro em congregação
Trocar lotação entre sede, congregações e ponto de pregação. Sem rol próprio (RN-CNG-04): é lotação, não jurisdição.

### UC-M1-12 — Registrar falecimento
Preenche `Pessoa.data_falecimento` e gera `Demissao(FALECIMENTO)` em um passo.
**Regra**: RN-MEM-20 *f*.

### UC-M1-13 — Painel de alertas do rol ⭐
**Ator**: secretário do Conselho · **Gatilho**: antes de cada reunião do Conselho

| Alerta | Prazo | Regra |
|---|---|---|
| Não comungantes fazendo 18 anos | D-180 e D-0 | RN-MEM-21 *c* |
| Paradeiro ignorado há 1 ano | contínuo | RN-MEM-23 |
| No rol separado há 2 anos | contínuo | RN-MEM-23 |
| Admissões/demissões sem nº de ata | contínuo | RN-REL-01 |
| Membros sem sexo ou sem data de admissão | contínuo | integridade da estatística |

**Este painel é o produto real do módulo.** É o que transforma o sistema de arquivo passivo em ferramenta que lembra o Conselho de suas obrigações.

⚠️ Nada aqui executa sozinho. O sistema **propõe**; o Conselho **resolve** (doc 05, §gatilhos).

### UC-M1-14 — Importar o CSV inicial ⭐
**Ator**: você, uma vez · **Gatilho**: implantação
Três passadas — perfilar, simular, executar — conforme doc 09 §5. Mapeamentos definitivos no doc 12 §3.
**Critério de aceite** (revisado): 2.622 linhas sem perda · nenhum valor categórico sem mapeamento · contagens iguais às do CSV de origem · filas de revisão nos totais esperados.

### UC-M1-15 — Fila de revisão de dados ⭐ *(novo)*
**Ator**: secretária · **Gatilho**: pós-importação e uso contínuo

Consequência direta do doc 12 §5: o rol chega com lacunas conhecidas, e resolvê-las **é trabalho de meses**. Precisa ser uma tela, não um relatório.

| Fila | Volume | Ação |
|---|---:|---|
| Sem categoria (`NAO_DEFINIDO`) | ~521 | Classificar comungante / não comungante / não membro. Mostrar forma de admissão ao lado — ela sugere a resposta em 89% dos casos |
| Sem sexo | ~860 | Preencher; aceitar sugestão por prenome (marcada como inferida) |
| Nomes duplicados | ~34 | Comparar lado a lado e marcar "mesma pessoa" ou "homônimos" — **nunca mesclar automaticamente** |
| `situacao = Revisar` no legado | 99 | Triagem livre |
| Inativos sem data de demissão | 447 | Informar data e forma, ou reativar |
| Ativos sem `numero_ordem` | 277 | Atribuir número no padrão `AAAA`+sequência |

**Requisitos**: edição em lote, filtro por fila, contador de progresso visível, e **capacidade de adiar** um item sem perdê-lo. Quem opera isso vai voltar dezenas de vezes.

**Regra**: item em revisão **não** bloqueia o uso do registro. O membro aparece no rol normalmente, com um marcador discreto.

---

## Regras aplicáveis (checklist de implementação)

`RN-MEM-01` `RN-MEM-02` `RN-MEM-03` `RN-MEM-04` `RN-MEM-05` `RN-MEM-06` `RN-MEM-08`
`RN-MEM-10` `RN-MEM-11` `RN-MEM-12` `RN-MEM-13` `RN-MEM-14` `RN-MEM-15`
`RN-MEM-20` `RN-MEM-21` `RN-MEM-22` `RN-MEM-23` `RN-MEM-24` `RN-MEM-25`
`RN-CON-21` `RN-CON-30` `RN-REL-01` `RN-REL-02` `RN-CNG-04` `RN-ATO-04` `RN-ATO-05`

---

## Telas

### 5.1 Duas UX no mesmo módulo (decisão B7)

| Perfil | Uso | Desenho |
|---|---|---|
| **Secretária** — diário | cadastro em série, consulta constante | Tabela densa, atalhos de teclado, `Tab` percorrendo campos na ordem do CSV, salvar com `Ctrl+Enter`, "salvar e novo" |
| **Secretário do Conselho / pastores** — mensal | conferir antes da reunião, registrar decisões | Assistentes passo a passo, linguagem da ata, painel de alertas na home |

**Resolução**: as mesmas telas, com **modo assistente** (padrão) e **modo rápido** (alternável e memorizado por usuário quando houver login). Não construir duas interfaces.

### 5.2 Lista de telas

| Tela | Elementos | Prioridade |
|---|---|---|
| **Rol de membros** | busca por nome parcial, filtros (§UC-M1-08), paginação de 50, colunas configuráveis, exportar | 1 |
| **Ficha da pessoa/membro** | 5 abas do UC-M1-09, cabeçalho com nome, nº de rol, categoria, situação e selo de plena comunhão | 2 |
| **Assistente de admissão** | passo 1 pessoa · passo 2 forma · passo 3 campos condicionais · passo 4 ata e lotação · revisão | 3 |
| **Assistente de profissão de fé** | fluxo curto do UC-M1-05 | 4 |
| **Demissão** | modal com forma, data, ata e confirmação explícita | 5 |
| **Painel de alertas** | agrupado por tipo, ação em lote, "gerar pauta para o Conselho" | 6 |
| **Cadastro rápido** | tela densa de digitação em série | 7 |
| **Importador** | upload, perfilagem, simulação, erros linha a linha, execução | 8 |

### 5.3 Campos condicionais por forma de admissão

| Forma | Campos que aparecem |
|---|---|
| Profissão de fé | data, oficiante, ata |
| Profissão de fé e batismo | data, oficiante, ata, tipo de batismo |
| Carta de transferência | igreja de origem, data da carta, data da carta recebida |
| Jurisdição a pedido | igreja de origem, **documento escrito com razões (obrigatório)** |
| Jurisdição *ex officio* | igreja de origem presbiteriana, **data de início da residência** (validar 1 ano) |
| Restauração | data da exclusão anterior, resolução de restauração |
| Designação do Presbitério | documento do Presbitério |

### 5.4 Detalhes que evitam retrabalho

- **Selo de plena comunhão** visível no cabeçalho da ficha, com o motivo quando negativo. Evita a pergunta "esse pode votar?" cem vezes por ano.
- **Nunca oferecer exclusão do registro.** Membro sai por `Demissao`, com forma e data. `DELETE` só existe para erro de digitação, com confirmação dupla.
- **Data de admissão não pode ser futura** e não pode ser anterior à data de nascimento.
- **`numero_rol` sugerido automaticamente**, mas editável na importação (a planilha já tem `numero_ordem`).
- **Busca tolerante a acento e a nome parcial** — "jose silva" acha "José da Silva".

---

## Dados que entram / saem

**Entram**: CSV inicial (doc 09) · cadastro manual · resoluções do Conselho (via M3, depois).

**Saem**:

| Saída | Formato | Destino |
|---|---|---|
| Rol de comungantes | PDF/CSV | Conselho, assembleia (Art. 83 *l*) |
| Rol de não comungantes | PDF/CSV | Conselho |
| Movimento do rol no período | PDF | Base da estatística anual (M8) |
| Lista de aptos a votar | PDF | Assembleia (M4, RN-ELE-04) |
| Pauta de pendências do rol | PDF | Reunião do Conselho |
| Aniversariantes do mês | lista | Uso pastoral |

---

## Fora de escopo (deste módulo)

- Login, perfis e permissões (doc 07, C1)
- Cartas de transferência como documento e fluxo → M6
- Reuniões, resoluções e atas estruturadas → M3
- Ofícios, ordenações e mandatos → M2
- Processo disciplinar → M9 (a regra de bloqueio fica escrita e inerte)
- Contribuições e finanças → decisão A5-a
- Portal do membro → doc 07, C4

---

## Critérios de pronto (E1)

- [ ] Migrations `001–004` aplicadas (`005` em seguida, para os 41 ofícios do CSV)
- [ ] CRUD de pessoa com `sexo` **opcional** e pendência de revisão
- [ ] Vínculos familiares com fallback em texto
- [ ] Admissão nas 7 formas de comungante e 3 de não comungante, com campos condicionais
- [ ] Demissão em todas as formas, incluindo `ORDENACAO_AO_MINISTERIO` e `MOVIMENTO_PARA_ROL_SEPARADO`
- [ ] Profissão de fé como transação demissão+admissão
- [ ] `emPlenaComunhao` como view, nunca como campo
- [ ] Lotação em congregação
- [ ] Busca por nome parcial, tolerante a acento, com paginação
- [ ] Painel de alertas com os 5 tipos
- [ ] Importador em 3 passadas
- [ ] **Tela de fila de revisão** (UC-M1-15) com as 6 filas
- [ ] **Teste de aceite**: 2.622 linhas sem perda, zero valores categóricos órfãos, contagens iguais às do CSV
- [ ] Exportação do rol em PDF e CSV

---

## Riscos conhecidos

| Risco | Mitigação |
|---|---|
| ~~Formato de data invertido~~ | **Eliminado**: datas em ISO 8601 (doc 12 §4) |
| ~~`meio_admissao` sem mapeamento~~ | **Eliminado**: os 12 valores mapeiam 1-a-1 nas formas da CI (doc 12 §3.4) |
| **521 ativos sem categoria** vão parar em listas de voto e elegibilidade | `NAO_DEFINIDO` nunca entra em `emPlenaComunhao`; fila de revisão prioritária |
| Fila de revisão nunca ser trabalhada e o rol permanecer sujo | Contador de progresso visível; pauta de pendências para o Conselho (UC-M1-13) |
| Deduplicação automática fundir pessoas distintas | **Nunca mesclar sozinho** — 34 nomes duplicados vão para comparação lado a lado |
| Não comungantes com maioridade vencida | Pendência P3 do doc 08 — **confirmar antes** de ligar a baixa automática, ou o sistema propõe centenas de exclusões no primeiro dia |
| Sistema de origem continuar em uso em paralelo | Pendência **P17** do doc 12 — decidir substituição × convivência **antes** de importar |
