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
| 01 | `01-roadmap-modelagem.md` | Passo a passo até o modelo pronto | **Leia agora.** É seu painel de controle |
| 02 | `02-glossario-dominio.md` | Vocabulário canônico (termo → significado → entidade) | Sempre que ficar em dúvida sobre um nome |
| 03 | `03-regras-constitucionais-igreja-local.md` | Regras extraídas da CI, numeradas (RN-XX-00) | Ao implementar validações |
| 04 | `04-modelo-de-entidades.md` | Entidades, atributos, relacionamentos, diagrama ER | Ao criar o schema do banco |
| 05 | `05-maquinas-de-estado.md` | Ciclos de vida (membro, mandato, carta, relação pastoral) | Ao implementar transições/status |
| 06 | `06-modulos-e-casos-de-uso.md` | Módulos do app e casos de uso por entidade | Ao fatiar o backlog |
| 07 | `07-decisoes-em-aberto.md` | O que **você** precisa decidir, com recomendação minha | Quando travar |

## Estado atual

- [x] Constituição lida e catalogada
- [x] Roadmap definido
- [x] Glossário
- [x] Regras constitucionais extraídas (escopo igreja local)
- [x] Modelo de entidades v1
- [x] Máquinas de estado
- [x] Módulos e casos de uso
- [ ] **Você**: responder `07-decisoes-em-aberto.md`
- [ ] Modelo v2 (após decisões) → schema de banco → specs de tela

## Próxima ação (uma só)

Abra `07-decisoes-em-aberto.md` e responda **apenas o bloco A (decisões bloqueantes, 5 perguntas)**. Ignore o resto por enquanto. Sem essas 5, o modelo não fecha; com elas, o resto se resolve sozinho.
