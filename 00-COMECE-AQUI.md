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
| 04 | `04-modelo-de-entidades.md` | **v2** — entidades, atributos, invariantes, diagrama ER | Referência central do modelo |
| 05 | `05-maquinas-de-estado.md` | Ciclos de vida (membro, mandato, carta, relação pastoral) | Ao implementar transições/status |
| 06 | `06-modulos-e-casos-de-uso.md` | Módulos do app e casos de uso por entidade | Ao fatiar o backlog |
| 07 | `07-decisoes-em-aberto.md` | Decisões do usuário — **respondido** | Histórico das escolhas |
| 08 | `08-analise-relatorio-estatistico.md` | Decodificação do formulário CSM-IPB (contrato de saída) | Ao implementar relatórios |
| 09 | `09-mapeamento-importacao-csv.md` | CSV de origem → modelo, coluna a coluna | Ao construir o importador |
| 10 | `10-schema-banco.md` | DDL do MVP, constraints e índices | Ao criar as migrations |
| 11 | `11-spec-m1-rol-de-membros.md` | Spec do primeiro módulo (E1) | **Para começar a codar** |

### Insumos

- `constituicao-igreja-presbiteriana.md` — fonte da verdade, 152 artigos
- `relatorio-igreja.pdf` — relatório estatístico oficial 2025 (CSM-IPB 2021 v8.0), já analisado no doc 08

## Estado atual

- [x] Constituição lida e catalogada
- [x] Roadmap, glossário, regras constitucionais
- [x] Modelo de entidades v1 → **v2**
- [x] Máquinas de estado · módulos e casos de uso
- [x] Decisões do bloco A e B respondidas
- [x] Relatório estatístico oficial analisado
- [x] Mapeamento da importação do CSV
- [x] Schema do banco (MVP)
- [x] Spec do M1
- [ ] **Você**: rodar o script de perfilagem do CSV (doc 09 §8) e responder P7–P10
- [ ] Implementar E1 (migrations 001–004 + importador + rol)

## Números da IPA (do relatório 2025)

1.669 membros (1.404 comungantes · 265 não comungantes) · 9 pastores · 21 presbíteros · 28 diáconos · 2 congregações · 1 ponto de pregação · 3 escolas dominicais.

Isto não é uma igreja pequena — paginação, busca e importação em lote são requisitos desde o primeiro dia.

## Próxima ação (uma só)

Rode o script do **doc 09, §8** sobre o CSV do rol e me mande a saída. Ele responde de uma vez as pendências P7, P8 e P10 — que são o que falta para o importador ficar pronto.

Se estiver sem energia para isso: leia só o `11-spec-m1-rol-de-membros.md`. É o que se transforma em código.
