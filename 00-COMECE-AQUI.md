# 00 — Comece aqui

Mapa dos documentos de modelagem do sistema de gestão da **Igreja Presbiteriana de Anápolis (IPA)**, derivado da Constituição da IPB (CI/IPB).

## Regras deste projeto de documentação

1. **Fonte da verdade**: `constituicao-igreja-presbiteriana.md`. Toda regra do sistema precisa apontar para um artigo (ex.: `CI Art. 54`) ou ser marcada explicitamente como **[DECISÃO LOCAL]** (não vem da Constituição, é escolha da IPA).
2. **Escopo**: apenas o que uma **igreja local** faz. Presbitério, Sínodo e Supremo Concílio aparecem só como *fronteira* (o que sai e o que entra), nunca como funcionalidade.
3. **Sem auth/permissões por enquanto** — conforme definido. Onde a Constituição exige que um ato seja privativo de alguém (ex.: só o ministro administra sacramentos), isso é registrado como **regra de negócio**, não como permissão de tela. Vira permissão depois, de graça.
4. **Idioma do modelo**: nomes de entidades em português. `Presbitero`, `Conselho`, `RolDeMembros` — traduzir destrói o significado canônico.

## Ordem de leitura

| # | Arquivo | O que é | Quando usar |
|---|---------|---------|-------------|
| 01 | `01-roadmap-modelagem.md` | Passo a passo até o modelo pronto | Painel de controle das fases |
| 02 | `02-glossario-dominio.md` | Vocabulário canônico (termo → significado → entidade) | Sempre que ficar em dúvida sobre um nome |
| 03 | `03-regras-constitucionais-igreja-local.md` | Regras extraídas da CI, numeradas (RN-XX-00) | Ao implementar validações |
| 04 | `04-modelo-de-entidades.md` | **v3** — entidades, atributos, invariantes, diagrama ER | Referência central do modelo |
| 05 | `05-maquinas-de-estado.md` | Ciclos de vida (membro, mandato, carta, relação pastoral) | Ao implementar transições/status |
| 06 | `06-modulos-e-casos-de-uso.md` | Módulos do app e casos de uso por entidade | Ao fatiar o backlog |
| 07 | `07-decisoes-em-aberto.md` | Decisões do usuário — **respondido** | Histórico das escolhas |
| 08 | `08-analise-relatorio-estatistico.md` | Estrutura do formulário CSM-IPB ⚠️ *3 ressalvas no topo* | Ao implementar relatórios |
| 09 | `09-mapeamento-importacao-csv.md` | ⚠️ *parcialmente superado pelo doc 12* | Estratégia de importação |
| 10 | `10-schema-banco.md` | DDL do MVP, constraints e índices | Ao criar as migrations |
| 11 | `11-spec-m1-rol-de-membros.md` | Spec do primeiro módulo (E1) | **Para começar a codar** |
| 12 | `12-perfil-dados-csv.md` | Perfil medido dos 2.622 registros reais | Fonte da verdade sobre os dados |
| 13 | `13-spec-importador.md` | **Algoritmo completo da migração** | **Para implementar o importador** |

### Insumos

- `constituicao-igreja-presbiteriana.md` — fonte da verdade jurídica, 152 artigos
- `membros_rows.csv` — rol atual, 2.622 registros, analisado no doc 12
- `relatorio-igreja.pdf` — relatório estatístico 2025; usado só para entender a **estrutura** do formulário (os números não valem como validação)

## Estado atual

- [x] Constituição lida e catalogada
- [x] Roadmap, glossário, regras constitucionais
- [x] Modelo de entidades v1 → v2 → **v3**
- [x] Máquinas de estado · módulos e casos de uso
- [x] Decisões dos blocos A e B respondidas
- [x] Formulário estatístico decodificado (com ressalvas)
- [x] **CSV real perfilado — P7 a P10 resolvidas**
- [x] Schema do banco (MVP) ajustado aos dados reais
- [x] Spec do M1 com fila de revisão
- [x] **P11–P18 respondidas · spec do importador escrito e simulado**
- [ ] **Você**: responder P19 e P20 (doc 13 §9) — pequenas, não travam o começo
- [ ] Implementar E1 (migrations 001–005 → importador → rol → fila de revisão)

## Números da importação (simulados com as regras já decididas)

**2.622 pessoas · 2.622 membros**
1.751 comungantes · 161 não comungantes · 88 sem categoria definida · 466 com categoria inferida
1.876 ativos · 746 demitidos
2.178 admissões · 312 demissões · 1.276 atos pastorais · 41 ofícios (21 presbíteros, 13 em disponibilidade, 7 diáconos)

**Filas de revisão geradas**: ~1.500 itens. Não é sinal de importação ruim — é o estado real do rol ficando visível pela primeira vez.

## Próxima ação (uma só)

Comece a implementar: **migrations `001–005`** do doc 10, depois o importador seguindo o doc 13 §11 (12 passos, na ordem).

Os passos 1–5 já produzem um rol consultável. Se a energia acabar aí, o projeto já tem valor.

Se preferir fechar as pontas antes: P19 e P20 do doc 13 §9 são duas perguntas curtas (padrão de numeração para novos membros e data de congelamento do sistema atual).
