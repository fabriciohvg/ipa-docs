# 02 — Glossário do domínio (linguagem ubíqua)

Termo canônico → significado na CI/IPB → como aparece no modelo.
Referências `Art. N` são da Constituição da IPB.

## Estrutura e governo

| Termo | Significado | No modelo |
|---|---|---|
| **Igreja local** | Comunidade de crentes professos com governo próprio, que reside no Conselho (Art. 4º) | `Igreja` (singleton — a IPA) |
| **Concílio** | Assembleia de ministros e presbíteros com poder de jurisdição (Art. 59). Os quatro: Conselho, Presbitério, Sínodo, Supremo Concílio (Art. 60) | Só `Conselho` é modelado; os demais são fronteira |
| **Conselho** | O concílio da igreja local. Composto do pastor (ou pastores) e dos presbíteros **em exercício** (Art. 75). Governa e administra a igreja (Art. 8º) | `Conselho` + `MembroDoConselho` (derivado) |
| **Assembleia geral da igreja** | Todos os membros **em plena comunhão**; reúne-se ao menos 1×/ano (Art. 9º) | `Assembleia` |
| **Mesa do Conselho** | Vice-Presidente, Secretário(s) e Tesoureiro, eleitos anualmente. O pastor é o Presidente nato (Arts. 78 e 84) | `CargoDaMesa` (com mandato anual) |
| **Junta Diaconal** | Corpo dos diáconos, estabelecido e orientado pelo Conselho, regido por regimento que o Conselho aprova (Arts. 58 e 83 *g*) | `JuntaDiaconal` |
| **Congregação** | Comunidade sem governo próprio, sob a jurisdição do Conselho da igreja-mãe (Art. 4º §§1º–2º; Art. 83 *r*) | `Congregacao` |
| **Ponto de pregação** | Estágio anterior à congregação, mesmo enquadramento jurídico (Art. 4º §2º) | `Congregacao.tipo = PONTO_DE_PREGACAO` |
| **Sociedade interna / organização doméstica** | SAF, UMP, UPH, UPA, UCP etc. Estatutos aprovados pelo Conselho, diretoria empossada por ele, livros e tesouraria examinados por ele (Art. 83 *h*, *o*, *p*, *q*) | `SociedadeInterna` |
| **Autarquia / entidade paraeclesiástica** | Entidades autônomas subordinadas a concílio (Art. 105) ou apenas participadas (Art. 107) | Fora de escopo (raro em igreja local) |

## Pessoas, membresia e papéis

| Termo | Significado | No modelo |
|---|---|---|
| **Membro** | Pessoa batizada e inscrita no rol (Art. 11) | `Membro` (papel de `Pessoa`) |
| **Comungante** | Membro que fez pública profissão de fé; goza de todos os direitos (Arts. 12–13) | `Membro.categoria = COMUNGANTE` |
| **Não comungante** | Menor de 18 anos batizado na infância, sem profissão de fé (Art. 12) | `Membro.categoria = NAO_COMUNGANTE` |
| **Em plena comunhão** | Comungante sem disciplina em vigor — condição para votar, ser votado, comungar e apresentar filhos ao batismo (Arts. 9º, 13 §3º, 112) | Estado derivado, não campo digitado |
| **Rol de membros** | Registro obrigatório e atualizado de comungantes e não comungantes (Art. 83 *l*) | Visão sobre `Membro` |
| **Rol separado** | Rol dos membros de paradeiro ignorado há 1 ano; exclusão após mais 2 anos (Art. 23 §2º) | `Membro.situacao = ROL_SEPARADO` |
| **Profissão de fé** | Ato público que torna o membro comungante (Arts. 12, 16 *a*–*b*) | `AtoPastoral.tipo = PROFISSAO_DE_FE` |
| **Jurisdição *ex officio*** | Arrolamento de membro presbiteriano residente há 1 ano nos limites da igreja, sem carta (Arts. 16 *e*, 22 §2º) | Forma de admissão |
| **Jurisdição a pedido** | Arrolamento, mediante pedido escrito e fundamentado, de quem vem de outra comunidade evangélica (Arts. 16 *d*, 20) | Forma de admissão |
| **Carta de transferência** | Documento que certifica plena comunhão na data de expedição; válida por **6 meses**; destino determinado (Arts. 18–22) | `CartaDeTransferencia` |
| **Restauração** | Readmissão de quem fora afastado ou excluído (Art. 16 *f*) | Forma de admissão |
| **Disciplina** | Ato do Conselho de impor ou relevar penas (Art. 83 *c*); pode levar à exclusão (Art. 23 *a*) | `MedidaDisciplinar` (mínima — Código de Disciplina é outro documento) |

## Oficialato

| Termo | Significado | No modelo |
|---|---|---|
| **Oficial** | Quem exerce função na esfera de doutrina, governo ou beneficência: ministro, presbítero regente ou diácono (Art. 25) | `Oficio` + `Mandato` |
| **Ministro do Evangelho** (= presbítero docente) | Oficial consagrado pelo Presbitério; prega, administra sacramentos, governa com os presbíteros (Art. 30). **Pertence ao rol do Presbitério, não ao da igreja** (Art. 23 §3º; Art. 27 §2º) | `Pessoa` + `RelacaoPastoral`; **não** entra no `Membro` |
| **Presbítero regente** | Representante imediato do povo, eleito pela igreja e ordenado pelo Conselho (Art. 50) | `Oficio.tipo = PRESBITERO_REGENTE` |
| **Diácono** | Oficial eleito pela igreja e ordenado pelo Conselho, sob supervisão dele (Art. 53) | `Oficio.tipo = DIACONO` |
| **Ofício vs. exercício** | O ofício é **perpétuo**; o exercício é **temporário** (Art. 25 §1º) | `Oficio` (perpétuo) ≠ `Mandato` (temporário) |
| **Ordenação** | Admitir o vocacionado ao ofício, por imposição de mãos e oração do concílio (Art. 109 §1º). **Acontece uma vez.** | `Ordenacao` (evento único por ofício) |
| **Instalação** | Investir a pessoa no cargo para o qual foi eleita e ordenada (Art. 109 §2º). **Acontece a cada mandato.** | `Mandato.dataInstalacao` |
| **Disponibilidade** | Situação do presbítero cujo mandato terminou sem reeleição; pode, se convidado, distribuir a Ceia e participar de ordenações (Art. 54 §2º) | `Oficio.situacao = DISPONIBILIDADE` |
| **Emérito** | Título honorífico da assembleia: Pastor (Art. 44), Presbítero e Diácono com +25 anos de serviço (Art. 57) | `TituloHonorifico` |
| **Deposição** | Perda do ofício por disciplina (Arts. 48 *a*, 56 *c*) | Motivo de cessação |
| **Jubilação** | Aposentadoria do ministro, proposta pelo Presbitério e efetivada pelo SC (Art. 49) | Campo informativo em `Pessoa`/`RelacaoPastoral` |

## Relação pastoral

| Termo | Significado | No modelo |
|---|---|---|
| **Pastor Efetivo** | Ministro **eleito e instalado** na igreja, por prazo máximo de 5 anos, reelegível (Arts. 33 §1º, 34 *a*) | `RelacaoPastoral.tipo = EFETIVO` |
| **Pastor Auxiliar** | Trabalha sob a direção do pastor, sem jurisdição sobre a igreja, mas com **voto e assento *ex officio* no Conselho**; designado pelo Conselho por **1 ano** (Arts. 33 §2º, 34 *c*) | `RelacaoPastoral.tipo = AUXILIAR` |
| **Pastor Evangelista** | Designado pelo Presbitério para dirigir igreja(s) ou trabalho incipiente (Arts. 33 §3º, 34 *d*) | `RelacaoPastoral.tipo = EVANGELISTA` |
| **Dissolução da relação pastoral** | Fim do vínculo: a pedido do pastor, a pedido da igreja, ou administrativamente pelo Presbitério (Art. 138) | `RelacaoPastoral.motivoTermino` |
| **Vencimentos** | Sustento fixado pela igreja, com aprovação do Presbitério (Art. 35) | `RelacaoPastoral.vencimentos` |

## Atos, documentos e registros

| Termo | Significado | No modelo |
|---|---|---|
| **Ata** | Registro oficial da reunião do concílio; examinada pelo Presbitério (Art. 88 *i*); recebe dissentimentos e protestos (Art. 65) | `Ata` |
| **Dissentimento** | Manifestação escrita de opinião diferente da maioria (Art. 65 §1º) | `ManifestacaoEmAta.tipo = DISSENTIMENTO` |
| **Protesto** | Declaração formal e enfática contra deliberação considerada errada ou injusta; **sem razões, não se registra** (Art. 65 §2º) | `ManifestacaoEmAta.tipo = PROTESTO` |
| ***Ad referendum*** | Ato válido provisoriamente, pendente de confirmação na reunião seguinte (Arts. 76 §1º, 78) | `Resolucao.adReferendum` |
| ***Quorum*** | Pastor + 1/3 dos presbíteros, nunca menos de 2 presbíteros (Art. 76). Matéria administrativa exige maioria dos membros (Art. 77) | Validação em `ReuniaoDoConselho` |
| **Sacramentos** | Batismo e Santa Ceia — administração privativa do ministro (Art. 31 *a*) | `AtoPastoral` |
| **Ato pastoral** | Atos que o ministro reporta periodicamente ao Conselho **para registro** (Art. 36, parágrafo único) | `AtoPastoral` |
| **Relatório e estatística** | Prestação anual à igreja (Art. 83 *m*) e ao Presbitério, junto com o livro de atas (Arts. 68, 70 *l*) | `RelatorioAnual` |

## Termos que **não** entram (fronteira ou fora de escopo)

`Presbitério`, `Sínodo`, `Supremo Concílio`, `Comissão Executiva`, `legislatura`, `licenciatura`, `candidato ao ministério`, `tutor eclesiástico`, `secretaria geral`, `junta missionária`.

Aparecem no sistema apenas como **texto/referência** em documentos que sobem ou descem (ex.: "aprovado pelo Presbitério em ___"), nunca como fluxo gerenciado.
