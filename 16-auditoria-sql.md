# 16 — Auditoria do SQL e migrations finais

Os arquivos executáveis estão em **`docs/sql/0001…0012.sql`**. Foram **aplicados e testados** em PostgreSQL 17.10 local (mesma major do Neon), banco limpo, na ordem, sem erro.

> **A partir daqui, `docs/sql/` é a fonte da verdade do schema.** O doc 10 continua valendo como *explicação* — por que cada tabela existe e qual artigo ela traduz —, mas o SQL a rodar é o desta pasta. Onde divergirem, vale `sql/`.

---

## 1. Resultado

```
✓ 0001_extensoes_e_tipos.sql      ✓ 0007_fks_adiadas.sql
✓ 0002_igreja_congregacao.sql     ✓ 0008_eleicoes.sql
✓ 0003_pessoa.sql                 ✓ 0009_atos_pastorais.sql
✓ 0004_membro.sql                 ✓ 0010_designacao.sql
✓ 0005_oficialato.sql             ✓ 0011_relatorio_anual.sql
✓ 0006_reunioes.sql               ✓ 0012_view_plena_comunhao.sql
```

**Testes de comportamento** — cada regra da Constituição foi provocada com um `INSERT` que deveria falhar:

| Teste | Regra | Resultado |
|---|---|---|
| Inserir segunda igreja | Sistema mono-igreja | ✅ bloqueado |
| Dois ofícios em exercício para a mesma pessoa | CI Art. 29 / RN-OFI-05 | ✅ bloqueado |
| Ofício adicional em **disponibilidade** | RN-OFI-11 — *deve permitir* | ✅ permitido |
| Segunda ordenação no mesmo ofício | CI Art. 25 §1º / RN-OFI-07 | ✅ bloqueado |
| Mandato de 6 anos | CI Art. 54 / RN-OFI-09 | ✅ bloqueado |
| Dois mandatos vigentes no mesmo ofício | RN-OFI-09 | ✅ bloqueado |
| Protesto sem razões | CI Art. 65 §2º / RN-CON-14 | ✅ bloqueado |
| Dissentimento sem razões | *deve permitir* | ✅ permitido |
| Pastor auxiliar com mandato de 2 anos | CI Art. 34 *c* / RN-PAS-03 | ✅ bloqueado |
| Ato pastoral sem oficiante algum | RN-ATO-01 | ✅ bloqueado |
| `proximo_numero_rol(2026)` com `20260001` existente | P19a | ✅ `20260002` |
| `proximo_numero_rol(2027)` | P19a | ✅ `20270001` |
| Trigger `atualizado_em` muda no `UPDATE` | — | ✅ |
| View de plena comunhão exclui `DEMITIDO` e `NAO_DEFINIDO` | RN-MEM-06 | ✅ |

---

## 2. Erros que teriam quebrado a execução

Quatro problemas fariam o SQL do doc 10 falhar na primeira tentativa.

### 2.1 `f_unaccent` existia apenas como comentário
O índice `pessoa_nome_busca` chamava `f_unaccent(...)`, mas a função só aparecia dentro de um bloco comentado. Erro: *function f_unaccent(text) does not exist*.
→ Agora é DDL real em `0001`.

### 2.2 Extensão `citext` nunca criada
`igreja.email citext` exige `CREATE EXTENSION citext`. Erro: *type "citext" does not exist*.
→ Criada em `0001`, junto de `unaccent` e `pg_trgm`.

### 2.3 A view de plena comunhão referenciava tabelas inexistentes
`membro_em_plena_comunhao` fazia `JOIN` com `medida_disciplinar` e `processo_disciplinar` — que só entram no M9 (⚪, decisão C2). O doc dizia "a visão degrada para as duas primeiras condições", mas o SQL escrito **não degradava**: falharia na criação.
→ `0012` traz a versão sem disciplina, com o comentário de como estendê-la depois via `CREATE OR REPLACE VIEW`.

### 2.4 Dependência circular com `organizacao_interna`
O §8 do doc 10 criava a tabela; o §11 mandava **não** criá-la; e `designacao` e `reuniao` tinham FK para ela. Qualquer ordem de execução quebrava.
→ Resolvido honrando a decisão real (a IPA não tem sociedade com estatuto): a tabela **não** é criada, e as duas colunas de FK foram removidas. Reintroduzir depois é uma migration de três linhas.

---

## 3. O achado mais importante: a busca não funcionava

O doc 15 §5 prometia que digitar **"jose silva"** acharia **"José da Silva"** — e esse era o critério de pronto do passo 6 da primeira semana. A consulta que eu havia especificado **retorna zero linhas**:

```sql
-- ERRADO: exige substring contígua
WHERE f_unaccent(lower(nome_completo)) LIKE '%' || f_unaccent(lower('jose silva')) || '%'
```

`"José da Silva"` sem acento é `"jose da silva"`. A busca procura `"jose silva"` como pedaço **contíguo**, e o `"da"` no meio quebra a correspondência. Confirmado no banco de testes: 0 linhas.

**A forma correta é quebrar a busca em tokens e aplicar `AND`:**

```sql
-- CERTO: um LIKE por palavra digitada
SELECT * FROM pessoa
WHERE f_unaccent(lower(nome_completo)) LIKE '%jose%'
  AND f_unaccent(lower(nome_completo)) LIKE '%silv%'
ORDER BY nome_completo
LIMIT 50;
```

Testado: retorna `José da Silva`. A aplicação monta um `LIKE` por palavra do termo digitado.

**Opcional, como "você quis dizer?"** — o operador de similaridade do `pg_trgm` tolera erro de digitação:

```sql
SET pg_trgm.similarity_threshold = 0.3;
SELECT nome_completo, similarity(f_unaccent(lower(nome_completo)), 'jose silva') AS s
FROM pessoa WHERE f_unaccent(lower(nome_completo)) % 'jose silva' ORDER BY s DESC;
```

No teste retornou `José da Silva` (0.79) **e** `João Silva` (0.57). Útil como sugestão quando o `AND` por token não achar nada — nunca como busca principal, porque traz gente demais.

⚠️ **Detalhe do índice trigram**: ele só é aproveitado com tokens de **3 caracteres ou mais**. Buscar "jo" faz varredura completa — irrelevante com 2.622 linhas, mas bom saber antes de estranhar o plano de execução.

---

## 4. Correções silenciosas

Não quebrariam a execução, mas produziriam comportamento errado ou dado mentiroso.

| # | Problema | Correção |
|---|---|---|
| 1 | **`atualizado_em` nunca era atualizado** — coluna existia, ninguém escrevia nela. Um campo que mente é pior que campo ausente | Trigger `set_atualizado_em()` em `igreja`, `congregacao`, `pessoa`, `membro`, `oficio`, `reuniao`, `ata`, `relatorio_anual` |
| 2 | **`sigiloso` não existia no schema** — a decisão B5-a e o doc 15 §8 afirmam que o campo já existe. Não existia | Adicionado em `resolucao` e `ato_pastoral` (aconselhamento, disciplina) |
| 3 | `CHECK (true)` em `convocacao` | Removido — no-op que só confunde |
| 4 | `membro_pendencia ON membro (pendencia_revisao) WHERE pendencia_revisao` — indexa a coluna que já é o predicado, inútil | `ON membro (numero_rol) WHERE pendencia_revisao` |
| 5 | `resolucao_pendente_referendo ON resolucao (id)` — índice sobre a PK | `ON resolucao (reuniao_id) WHERE ...` |
| 6 | ~10 tabelas sem `criado_em`, contra a própria convenção do doc 10 | Padronizado em todas |
| 7 | `admissao.carta_id` apontava para `carta_de_transferencia`, que é 🟡 e não existe | Coluna removida; volta com o M6 |
| 8 | `pessoa.profissao_informada` | Removida — descartada por instrução sua (doc 12 §4) |
| 9 | Fila de revisão de sexo e duplicidade é de **pessoa**, não de membro, mas `pendencia_revisao` só existia em `membro` | Adicionado `pessoa.pendencia_revisao` + índice parcial |
| 10 | `oficio` sem `origem_migracao`, embora os 41 ofícios venham do CSV | Adicionado |
| 11 | Estatística agrupa por `forma`, mas só havia índice por `data` | `admissao_forma` e `demissao_forma` em `(forma, data)` |
| 12 | Faltavam índices em FKs muito consultadas | `vinculo_relacionado`, `participante_ato`, `convocacao_reuniao`, `manifestacao_ata`, `oficio_tipo_situacao` |

---

## 5. Adições

### `proximo_numero_rol(ano)` — implementa P19a

```sql
SELECT proximo_numero_rol();       -- ano corrente
SELECT proximo_numero_rol(2026);   -- '20260001' se nao houver nenhum de 2026
```

Ignora números fora do padrão de 8 dígitos, então o legado inconsistente não atrapalha.

⚠️ **Concorrência**: como já anotado no doc 13 §4.4, `MAX()+1` sob dois cadastros simultâneos gera duplicata. A `UNIQUE` em `numero_rol` **impede o dado errado**, mas a aplicação precisa capturar a violação e tentar de novo. Com secretária, secretário e pastores cadastrando ao mesmo tempo (B7), isso vai acontecer.

### Comentários com a regra ao lado da constraint

Cada restrição não óbvia carrega o artigo que a origina, direto no `.sql`:

```sql
-- RN-OFI-05 / CI Art. 29: ninguem exerce dois oficios ao mesmo tempo
CREATE UNIQUE INDEX oficio_um_em_exercicio
  ON oficio (pessoa_id) WHERE situacao = 'EM_EXERCICIO';
```

Daqui a dois anos, quem encontrar essa constraint vai saber **por que** ela existe sem precisar abrir o doc 03.

---

## 6. Como rodar

**No console do Neon** (aceitável para a carga inicial — doc 15 §4): abra cada arquivo, cole, execute, **um por vez e na ordem**.

**Ou pela linha de comando**, com a connection string **direta** (sem `-pooler`):

```bash
for f in sql/0*.sql; do
  echo "-> $f"
  psql "$DATABASE_URL_UNPOOLED" -v ON_ERROR_STOP=1 -f "$f" || break
done
```

Depois: `npx drizzle-kit pull` para gerar `db/schema.ts` a partir do banco real.

### Conferência pós-execução

Valores conferidos no banco de teste após as 12 migrations:

```sql
SELECT count(*) FROM information_schema.tables
 WHERE table_schema='public' AND table_type='BASE TABLE';   -- 28 tabelas
SELECT count(*) FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
 WHERE n.nspname='public' AND t.typtype='e';                -- 14 enums
SELECT count(*) FROM pg_indexes WHERE schemaname='public';  -- 70 indices
SELECT count(*) FROM information_schema.triggers
 WHERE trigger_schema='public';                             -- 8 triggers
SELECT count(*) FROM information_schema.views
 WHERE table_schema='public';                               -- 1 view

SELECT proximo_numero_rol(2026);                            -- '20260001' em banco vazio
SELECT * FROM membro_em_plena_comunhao LIMIT 1;             -- existe, vazia
```

---

## 7. O que ficou de fora, de propósito

| Ausente | Motivo | Volta quando |
|---|---|---|
| `usuario`, `papel`, `permissao` | Sem auth na v1 (C1) | Ao implementar login |
| `carta_de_transferencia` | 🟡 — 173 transferências em todo o histórico contra 831 jurisdições | M6 / E5 |
| `organizacao_interna` | Não há sociedade com estatuto na IPA (B2) | Se surgir uma |
| `escola_dominical`, `turma_ebd`, `atuacao_ebd` | Instrução sua: EBD fica para depois | Quando decidir |
| `relatorio_financeiro_anual` | 🟡 — não bloqueia a E1 | Ao fechar o exercício |
| `processo_disciplinar`, `medida_disciplinar` | Depende do Código de Disciplina (C2) | Se conseguir o texto |
| `bem`, `orcamento`, `contribuicao` | Decisão A5-a | — |

Nenhum desses é referenciado pelas 12 migrations. Não há FK pendente nem coluna órfã esperando tabela.

---

## 8. Próximo passo

O banco está pronto para receber os 2.622 registros. Volte ao **doc 13 §11**, passo 2: leitor de CSV e passada de validação.

E aproveite o branching do Neon (doc 15 §6) — a importação é irreversível em produção, mas infinitamente repetível numa branch.
