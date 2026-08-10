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
| 12 | `12-perfil-dados-csv.md` | **Perfil medido dos 2.622 registros reais** | **Fonte da verdade sobre os dados** |

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
- [x] **CSV real perfilado — P7, P8, P9 e P10 resolvidas**
- [x] Schema do banco (MVP) ajustado aos dados reais
- [x] Spec do M1 com fila de revisão
- [ ] **Você**: responder P11–P18 (doc 12 §7)
- [ ] Implementar E1 (migrations 001–005 + importador + rol + fila de revisão)

## Números reais da IPA (do CSV, não do relatório)

**2.622 registros** · 1.777 ativos: 1.125 comungantes · 131 não comungantes · **521 sem categoria**
21 presbíteros · 13 presbíteros em disponibilidade · 7 diáconos · 2 congregações · 1 ponto de pregação

**Lacunas conhecidas**: 860 sem sexo · 554 sem categoria · 447 inativos sem data de demissão · 34 nomes duplicados.
O rol chega sujo, e limpá-lo é trabalho de meses — por isso a fila de revisão é funcionalidade, não relatório.

## Próxima ação (uma só)

Abra `12-perfil-dados-csv.md` e responda **P11, P12 e P14** — as três que travam o importador (o que fazer com os 521 sem categoria, como resolver situação × data de demissão, e o formato do número de rol).

**P17 é a mais importante estrategicamente**: existe um sistema rodando hoje? Se sim, o novo substitui ou convive? Isso muda o projeto inteiro.

Se estiver sem energia: leia só o §5 do doc 12. São os três problemas de dados em uma página.
