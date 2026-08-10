# 06 — Módulos e casos de uso

Fatiamento funcional do sistema. Cada módulo lista entidades, casos de uso e as regras `RN-XX-00` que ele precisa cumprir.

**Prioridade**: 🟢 MVP · 🟡 v2 · ⚪ backlog
**IDs de caso de uso**: `UC-<MÓD>-<nº>`

Ordem de construção (dependência real):
`1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9`

---

## M1 🟢 Pessoas e Rol de Membros

*Base de tudo. Nada funciona antes disto.*

**Entidades**: `Pessoa`, `VinculoFamiliar`, `Membro`, `Admissao`, `Demissao`

| UC | Caso de uso | Regras |
|---|---|---|
| UC-M1-01 | Cadastrar pessoa | RN-MEM-01 |
| UC-M1-02 | Registrar vínculo familiar (pais, responsáveis, cônjuge, menor sob guarda) | RN-MEM-11, RN-ATO-04 |
| UC-M1-03 | Admitir membro comungante (7 formas) | RN-MEM-10, RN-MEM-15 |
| UC-M1-04 | Admitir membro não comungante (3 formas) | RN-MEM-11 |
| UC-M1-05 | Registrar profissão de fé → promover não comungante a comungante | RN-MEM-25, RN-ATO-05 |
| UC-M1-06 | Demitir membro (comungante e não comungante) | RN-MEM-20, RN-MEM-21 |
| UC-M1-07 | Mover membro para rol separado / excluir por ausência | RN-MEM-23 |
| UC-M1-08 | Consultar rol de comungantes e de não comungantes (com filtros e exportação) | RN-CON-30, RN-REL-02 |
| UC-M1-09 | Ver ficha do membro com histórico completo (admissão, disciplina, atos, mandatos) | RN-REL-01 |
| UC-M1-10 | Verificar "em plena comunhão" de um membro numa data | RN-MEM-06, RN-DIS-07 |
| UC-M1-11 | Lotar membro em congregação | RN-CNG-04 |
| UC-M1-12 | Registrar falecimento | RN-MEM-20 *f* |
| UC-M1-13 | Painel de alertas do rol (18 anos, paradeiro ignorado, cartas vencendo) | RN-MEM-23, RN-MEM-25 |

**Telas**: lista do rol · ficha da pessoa · ficha do membro (com abas: dados, histórico, família, atos, ofícios) · assistente de admissão · assistente de demissão · painel de alertas.

**Fora de escopo**: qualquer noção de "usuário do sistema". Membro ≠ login.

---

## M2 🟢 Oficialato e mandatos

**Entidades**: `Oficio`, `Ordenacao`, `Mandato`, `RelacaoPastoral`, `LicencaPastoral`, `TituloHonorifico`, `CargoDaMesa`, `Designacao`

| UC | Caso de uso | Regras |
|---|---|---|
| UC-M2-01 | Registrar ordenação de presbítero/diácono | RN-OFI-06, RN-OFI-07, RN-OFI-15, RN-OFI-16 |
| UC-M2-02 | Instalar oficial (abrir mandato) | RN-OFI-07, RN-OFI-09 |
| UC-M2-03 | Encerrar mandato com motivo | RN-OFI-12 |
| UC-M2-04 | Colocar/retirar presbítero de disponibilidade | RN-OFI-11 |
| UC-M2-05 | Consultar composição do Conselho **numa data** | RN-CON-01 |
| UC-M2-06 | Consultar composição da Junta Diaconal numa data | RN-DIA-02 |
| UC-M2-07 | Registrar relação pastoral (efetivo, auxiliar, evangelista) | RN-PAS-01 a RN-PAS-04 |
| UC-M2-08 | Registrar aprovação/posse pelo Presbitério | RN-PAS-02, RN-PAS-03 |
| UC-M2-09 | Registrar dissolução da relação pastoral | RN-PAS-12 |
| UC-M2-10 | Conceder licença ao pastor (férias, saúde, particulares, ausência > 10 dias) | RN-PAS-07 a RN-PAS-10 |
| UC-M2-11 | Eleger a Mesa do Conselho (anual) | RN-CON-11 |
| UC-M2-12 | Conferir título de emérito | RN-OFI-17, RN-PAS-14 |
| UC-M2-13 | Registrar designações não-oficiais (Art. 83 *x*, comissões locais) | RN-CON-41 |
| UC-M2-14 | Alertar mandatos a vencer (D-90) e ausências (6 meses) | RN-OFI-10, RN-OFI-12 *d* |
| UC-M2-15 | Verificar elegibilidade de um membro ao oficialato | RN-ELE-05 |

**Validações de destaque**: nunca dois ofícios em exercício na mesma pessoa (RN-OFI-05); mandato ≤ 5 anos (RN-OFI-09); reeleição **não** cria nova ordenação (RN-OFI-07); pastor não entra no rol de membros (RN-PAS-15).

---

## M3 🟢 Conselho: reuniões, resoluções e atas

*O coração probatório do sistema.*

**Entidades**: `Reuniao`, `Convocacao`, `Presenca`, `Resolucao`, `Ata`, `ManifestacaoEmAta`

| UC | Caso de uso | Regras |
|---|---|---|
| UC-M3-01 | Convocar reunião do Conselho (com registro de convocação a todos os presbíteros) | RN-CON-08, RN-CON-09 |
| UC-M3-02 | Instalar reunião com verificação automática de quórum | RN-CON-02, RN-CON-03 |
| UC-M3-03 | Registrar presença (presente, ausente justificado, ausente não justificado) | RN-OFI-13 |
| UC-M3-04 | Registrar resolução com natureza (espiritual/administrativa) e votação | RN-CON-04, RN-CON-20 a RN-CON-41 |
| UC-M3-05 | Marcar resolução como *ad referendum* e referendá-la depois | RN-CON-03, RN-CON-06 |
| UC-M3-06 | Redigir, aprovar e assinar ata | RN-REL-01 |
| UC-M3-07 | Registrar dissentimento ou protesto (protesto exige razões) | RN-CON-14 |
| UC-M3-08 | Registrar observações do Presbitério e sua cientificação | RN-REL-05 |
| UC-M3-09 | Gerar livro de atas do exercício (PDF paginado) | RN-REL-04 |
| UC-M3-10 | Registrar designação de presidência por outro ministro / vice-presidente | RN-CON-07 |
| UC-M3-11 | Registrar submissão de caso ao Presbitério (matéria sem interpretação firmada) | RN-CON-16 |
| UC-M3-12 | Eleger representante ao Presbitério | RN-CON-38 |
| UC-M3-13 | Alertar descumprimento da periodicidade trimestral | RN-CON-08 |

**Bloqueios de UI**: não instalar reunião sem convocação registrada (RN-CON-09); não deliberar admissão/transferência/disciplina sem ministro presidindo (RN-CON-06); não salvar protesto sem razões (RN-CON-14).

**Modelo de redação**: cada `Resolucao` deve gerar automaticamente o parágrafo padrão da ata, para o secretário não redigir do zero.

---

## M4 🟢 Assembleia e eleições

**Entidades**: `Assembleia`, `Eleicao`, `AptoAVotar`, `Candidatura`, `Presenca`

| UC | Caso de uso | Regras |
|---|---|---|
| UC-M4-01 | Convocar assembleia (ordinária/extraordinária) por resolução do Conselho | RN-ASM-02, RN-ELE-02 |
| UC-M4-02 | Definir se a pauta exige membros civilmente capazes | RN-ASM-04 |
| UC-M4-03 | Gerar e congelar lista de aptos a votar e a ser votados | RN-ELE-04, RN-ELE-05 |
| UC-M4-04 | Registrar instrução da igreja pelo pastor (D-30) | RN-ELE-03 |
| UC-M4-05 | Fixar número de vagas e instruções do pleito | RN-ELE-02 |
| UC-M4-06 | Registrar candidaturas e aceite do cargo | RN-OFI-15 |
| UC-M4-07 | Apurar votos e registrar resultado | RN-ELE-01 |
| UC-M4-08 | Verificar regularidade do pleito e idoneidade dos eleitos | RN-ELE-06 |
| UC-M4-09 | Registrar presença na assembleia (com marcação de capacidade civil) | RN-ASM-04 |
| UC-M4-10 | Registrar deliberações não eleitorais (estatutos, patrimônio, orçamento, emeritados) | RN-ASM-03 |
| UC-M4-11 | Registrar quem presidiu a assembleia (pastor → auxiliar → vice-presidente) | RN-ASM-05 |
| UC-M4-12 | Gerar ata da assembleia | RN-REL-01 |

**Nota**: o sistema **não precisa** ser urna eletrônica. Registrar apuração já resolve. Votação digital é ⚪ backlog e traz problemas de sigilo que a CI não regula.

---

## M5 🟢 Atos pastorais e registros eclesiásticos

**Entidades**: `AtoPastoral`, `ParticipanteAtoPastoral`

| UC | Caso de uso | Regras |
|---|---|---|
| UC-M5-01 | Registrar batismo infantil (com pais/responsáveis em plena comunhão) | RN-ATO-04, RN-CON-39 |
| UC-M5-02 | Registrar batismo de adulto + profissão de fé | RN-MEM-10 *b* |
| UC-M5-03 | Registrar profissão de fé | RN-ATO-05 |
| UC-M5-04 | Registrar celebração da Santa Ceia (data, oficiante, presbíteros que distribuíram) | RN-ATO-01, RN-ATO-02 |
| UC-M5-05 | Registrar casamento religioso com efeito civil | RN-ATO-01 *c* |
| UC-M5-06 | Registrar funeral | RN-ATO-06 |
| UC-M5-07 | Registrar visitas e aconselhamentos pastorais | RN-PAS-16 |
| UC-M5-08 | Gerar relatório periódico de atos pastorais para o Conselho | RN-PAS-06, RN-ATO-03 |
| UC-M5-09 | Emitir certificados (batismo, profissão de fé, casamento) | ⚪ conveniência |
| UC-M5-10 | Numeração de livro/folha/termo compatível com os livros físicos | RN-REL-01 |

**Validação central**: sacramentos, bênção apostólica e casamento só podem ter como oficiante alguém com ofício de ministro (RN-ATO-01). Presbítero **distribui** a Ceia, não a administra (RN-ATO-02).

---

## M6 🟡 Transferências

**Entidades**: `CartaDeTransferencia`

| UC | Caso de uso | Regras |
|---|---|---|
| UC-M6-01 | Emitir carta de transferência (destino determinado, validade 6 meses) | RN-TRF-01, RN-TRF-04 |
| UC-M6-02 | Bloquear emissão para membro sob processo | RN-MEM-22 |
| UC-M6-03 | Registrar confirmação de recebimento pela igreja destino → demitir | RN-TRF-07 |
| UC-M6-04 | Registrar recusa com razões → devolver membro ao rol | RN-TRF-06 |
| UC-M6-05 | Expirar carta automaticamente aos 6 meses | RN-TRF-04 |
| UC-M6-06 | Receber carta de outra igreja → admitir membro | RN-MEM-10 *c* |
| UC-M6-07 | Registrar jurisdição *ex officio* (1 ano de residência) | RN-MEM-12 |
| UC-M6-08 | Registrar jurisdição a pedido (com documento escrito e razões) | RN-MEM-13, RN-MEM-14 |
| UC-M6-09 | Comunicar igreja de origem sobre transferência efetivada | RN-TRF-07 |
| UC-M6-10 | Gerar PDF da carta no modelo da IPB | RN-TRF-04 |

---

## M7 🟡 Congregações e sociedades internas

**Entidades**: `Congregacao`, `SociedadeInterna`, `DiretoriaSociedade`, `ExameDeLivros`, `JuntaDiaconal`

| UC | Caso de uso | Regras |
|---|---|---|
| UC-M7-01 | Estabelecer ponto de pregação / congregação por resolução | RN-CNG-02 |
| UC-M7-02 | Promover ponto de pregação a congregação | RN-CNG-01 |
| UC-M7-03 | Listar membros lotados numa congregação | RN-CNG-04 |
| UC-M7-04 | Cadastrar sociedade interna e aprovar estatuto | RN-SOC-01 |
| UC-M7-05 | Dar posse à diretoria da sociedade | RN-SOC-01 |
| UC-M7-06 | Registrar exame de livros de atas e tesouraria, com observações | RN-SOC-02 |
| UC-M7-07 | Suspender medida votada por sociedade | RN-SOC-03 |
| UC-M7-08 | Aprovar regimento da Junta Diaconal | RN-DIA-01 |
| UC-M7-09 | Registrar reuniões e presença da Junta Diaconal | RN-DIA-03 |

---

## M8 🟢 Relatórios e estatística

*É a saída obrigatória. Justifica o sistema inteiro perante o Presbitério.*

**Entidades**: `RelatorioAnual`, `EstatisticaAnual`

| UC | Caso de uso | Regras |
|---|---|---|
| UC-M8-01 | Gerar estatística anual **derivada dos eventos** | RN-REL-01 |
| UC-M8-02 | Compor relatório anual de atividades | RN-REL-03 |
| UC-M8-03 | Apresentar relatório à assembleia | RN-REL-03, RN-ASM-03 *d* |
| UC-M8-04 | Gerar **pacote para o Presbitério**: credenciais + livro de atas + relatório + estatística | RN-REL-04 |
| UC-M8-05 | Registrar observações do Presbitério às atas | RN-REL-05 |
| UC-M8-06 | Dashboard do Conselho: rol, oficiais, mandatos, pendências | — |
| UC-M8-07 | Relatório de movimento do rol num período | RN-REL-02 |
| UC-M8-08 | Relatório de frequência de oficiais às reuniões | RN-OFI-13 |

**Regra de ouro**: nenhum número da estatística é digitado. Se for preciso digitar, falta evento no modelo.

---

## M9 ⚪ Patrimônio, finanças e disciplina

Módulos de acoplamento baixo — podem esperar ou ser terceirizados.

| UC | Caso de uso | Regras |
|---|---|---|
| UC-M9-01 | Cadastrar bens e imóveis | RN-PAT-01 |
| UC-M9-02 | Registrar parecer do Conselho + deliberação da assembleia sobre imóvel | RN-PAT-01, RN-ASM-06 |
| UC-M9-03 | Registrar orçamento anual e sua apresentação à assembleia | RN-REL-06 |
| UC-M9-04 | Registrar contribuições (dízimos e ofertas) | RN-PAT-04 |
| UC-M9-05 | Registrar remessa de dízimo ao Supremo Concílio | RN-PAT-05 |
| UC-M9-06 | Abrir processo disciplinar (esqueleto) | RN-DIS-01 |
| UC-M9-07 | Aplicar e relevar penas | RN-DIS-01 |
| UC-M9-08 | Registrar restauração de excluído | RN-DIS-04 |

⚠️ **Disciplina depende do Código de Disciplina da IPB**, que não está neste repositório. Construir só o esqueleto e o efeito colateral sobre `emPlenaComunhao`.

---

## Mapa módulo × entidade

| Entidade | M1 | M2 | M3 | M4 | M5 | M6 | M7 | M8 | M9 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Pessoa | ● | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ○ |
| Membro | ● | ○ | ○ | ○ | ○ | ● | ○ | ○ | ○ |
| Admissao / Demissao | ● | | | | ○ | ● | | ○ | ○ |
| Oficio / Ordenacao / Mandato | | ● | ○ | ○ | ○ | | ○ | ○ | ○ |
| RelacaoPastoral | | ● | ○ | ○ | ○ | | | ○ | |
| Reuniao / Presenca / Resolucao / Ata | ○ | ○ | ● | ● | ○ | ○ | ○ | ● | ○ |
| Eleicao / AptoAVotar / Candidatura | | ○ | ○ | ● | | | | | |
| AtoPastoral | ○ | | ○ | | ● | | | ○ | |
| CartaDeTransferencia | ○ | | ○ | | | ● | | ○ | |
| Congregacao / SociedadeInterna | ○ | | ○ | | ○ | | ● | ○ | |
| RelatorioAnual / EstatisticaAnual | ○ | ○ | ○ | ○ | ○ | ○ | ○ | ● | ○ |
| Bem / Orcamento / ProcessoDisciplinar | ○ | | ○ | ○ | | ○ | | ○ | ● |

● dono · ○ consome

---

## Sugestão de fatiamento por entrega

| Entrega | Conteúdo | Resultado prático |
|---|---|---|
| **E1** | M1 completo | A secretaria abandona a planilha do rol |
| **E2** | M2 + M3 | Conselho registra atas e mandatos; para de perder histórico |
| **E3** | M5 + M8 | Atos pastorais registrados e estatística anual sai sozinha |
| **E4** | M4 | Eleições auditáveis com lista de aptos congelada |
| **E5** | M6 + M7 | Cartas e sociedades internas |
| **E6** | M9 | Patrimônio, finanças e disciplina |

Após **E3**, o sistema já entrega o pacote que a igreja é obrigada a levar ao Presbitério (RN-REL-04). Esse é o marco de "vale a pena".
