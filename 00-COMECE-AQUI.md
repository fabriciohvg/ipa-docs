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
| 13 | `13-spec-importador.md` | Algoritmo completo da migração | Para implementar o importador |
| 14 | `14-decisao-stack-tecnica.md` | Escolha da stack + decisões técnicas fixas | Histórico da decisão |
| 15 | `15-setup-implementacao.md` | Setup Next + Neon + Vercel, armadilhas e ordem da 1ª semana | Ao começar a codar |
| 16 | `16-auditoria-sql.md` | Auditoria do SQL + migrations testadas | Antes de rodar as migrations |
| 17 | `17-importador-construido.md` | Importador executado: números reais e filas geradas | Antes de importar |
| 18 | `18-plano-de-telas.md` | **Plano de 14 passos para as telas** | **Agora — é o que vira código** |

### Executáveis

- **`sql/0001…0012.sql`** — as 12 migrations, aplicadas e testadas em PostgreSQL 17. **É a fonte da verdade do schema** (o doc 10 virou explicação).
- **`import/importar_rol.py`** — importador do rol, executado contra o CSV real e o schema real. Modos `--validar` e `--importar`.
- **`sql/0013_pendencia_motivos.sql`** — ⚠️ migration nova: grava os 15 motivos de pendência e marca formas arbitradas. Rode antes das telas (doc 18, passo 0).

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
- [x] **P11–P20 respondidas · importador especificado e simulado**
- [x] **Modelagem encerrada** — fases 1 a 6 do roadmap fechadas
- [x] **Stack escolhida**: Next.js + TypeScript · Postgres no Neon · Vercel
- [x] **Migrations escritas, auditadas e testadas** em PostgreSQL 17 (`sql/`, doc 16)
- [x] **Migrations aplicadas no Neon** ✔
- [x] **Importador construído e executado** contra o CSV real (`import/`, doc 17)
- [x] **Importado no Neon com os dados reais** ✔
- [x] **Repo Next.js configurado** (shadcn, Tailwind, Drizzle + pull) — P25/P26 resolvidas na prática
- [ ] **Você**: passo 0 do doc 18 — migration `0013` + reimportar + `drizzle-kit pull`
- [ ] Entrega A (passos 1–6): rol navegável → mostrar ao Conselho
- [ ] Entrega B (7–8): secretaria trabalha as pendências
- [ ] Entrega C (9–14): admissões, demissões e relatório saem do sistema
- [ ] Pendente: P24 (onde ficam as 900 fotos)

## Números da importação (medidos em execução real, doc 17)

**2.622 pessoas · 2.622 membros**
2.038 comungantes · 166 não comungantes · 418 sem categoria · 758 com categoria inferida
1.876 ativos · 746 demitidos · **1.644 em plena comunhão**
2.178 admissões · 312 demissões · 1.276 atos pastorais · 980 vínculos familiares
41 ofícios: 21 presbíteros em exercício, 13 em disponibilidade, 7 diáconos

**Filas de revisão**: 1.588 pessoas, 3.164 itens. Não é sinal de importação ruim — é o estado real do rol ficando visível pela primeira vez.

## Próxima ação (uma só)

**Passo 0 do doc 18**, numa branch do Neon — 10 minutos:

```bash
psql "$DATABASE_URL_UNPOOLED" -f sql/0013_pendencia_motivos.sql
python import/importar_rol.py --csv membros_rows.csv --dsn "$DATABASE_URL_UNPOOLED" --importar
npx drizzle-kit pull
```

Sem isso, a tela de fila de revisão não consegue mostrar *por que* cada pessoa precisa de revisão.

Depois: doc 18, passos 1 a 6 (Entrega A).

```
passo 0 → rol navegável → fila de revisão → secretaria limpa os dados
                                                     ↓
                                     ▶ A PLANILHA VIRA HISTÓRICO
```

⚠️ **Aviso operacional (P20)**: o CSV de 10/08/2026 é a exportação definitiva. Todo cadastro feito no sistema antigo a partir de agora se perde na virada — combine isso com a secretaria hoje, não na véspera.

⚠️ **Continuidade (doc 15 §9)**: crie as contas Neon e Vercel com e-mail institucional da IPA, não pessoal. Um sistema de igreja sobrevive ao voluntário que o escreveu. É barato agora e caro depois.
