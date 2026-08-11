# 15 — Setup e guia de implementação

Stack fechada (doc 14): **Next.js + TypeScript · Postgres no Neon · deploy na Vercel**.
Este documento leva do zero até o primeiro `SELECT` no rol importado.

---

## 1. O que a escolha do Neon muda em relação ao doc 14

O doc 14 assumia Supabase. Sair dele altera três pontos concretos — nenhum deles ruim, mas todos precisam de decisão explícita:

| Item | Supabase (assumido) | **Neon + Vercel (real)** |
|---|---|---|
| **Armazenamento de fotos** | Supabase Storage | ❗ **Neon não tem storage** — 900 fotos precisam de destino. Ver P24 |
| **Auth (quando chegar)** | Supabase Auth | Auth.js, Clerk ou better-auth. Não decidir agora, só não se pintar num canto |
| **Conexão com o banco** | connection string única | ❗ Neon tem **duas**: pooled e direta. Usar a errada quebra migration ou runtime. Ver §3 |

**O que melhora**: o *branching* do Neon é feito sob medida para o seu maior risco. Você pode criar uma branch do banco, rodar a importação dos 2.622 registros, conferir os números do doc 13 §7, e **descartar a branch** se algo estiver errado — quantas vezes quiser, sem `DROP DATABASE` e sem medo. Use isso.

---

## 2. Stack fechada

```
next            (App Router)
typescript
drizzle-orm + drizzle-kit
@neondatabase/serverless      driver HTTP, ideal para funções serverless
tailwindcss + shadcn/ui
zod                           validação compartilhada form ↔ servidor
react-hook-form
tsx                           roda o importador localmente
```

**Fora, de propósito**: biblioteca de PDF (doc 14 §7 — impressão do navegador na v1) · gerenciador de estado (Server Components resolvem) · camada de API REST (Server Actions) · Docker (Vercel + Neon não pedem).

---

## 3. As duas connection strings do Neon ⚠️

O erro nº 1 de quem começa no Neon. O painel entrega duas URLs:

```bash
# .env.local

# POOLED — host contém "-pooler". Use no runtime da aplicação.
DATABASE_URL="postgresql://...@ep-xxx-pooler.region.aws.neon.tech/ipa?sslmode=require"

# DIRETA — sem "-pooler". Use em migrations e no importador.
DATABASE_URL_UNPOOLED="postgresql://...@ep-xxx.region.aws.neon.tech/ipa?sslmode=require"
```

| Uso | String | Por quê |
|---|---|---|
| App na Vercel | **pooled** | Cada invocação serverless abre conexão; sem pool, o limite estoura |
| `drizzle-kit migrate` | **direta** | DDL e transações longas não funcionam bem através do pooler |
| Importador (§6) | **direta** | Uma transação única de 2.622 linhas — precisa de sessão estável |

---

## 4. Migrations: o doc 10 é a fonte da verdade

**Recomendação forte**: não deixe o Drizzle gerar o schema a partir do TypeScript. Faça o contrário.

O schema do doc 10 usa três coisas que ORMs traduzem mal:

- **enums nativos do Postgres** (11 deles)
- **índices únicos parciais** — `oficio_um_em_exercicio ... WHERE situacao = 'EM_EXERCICIO'`, que é a tradução literal do Art. 29
- **índice GIN** para busca por nome

Fluxo recomendado:

```bash
# 1. Escreva as migrations como SQL puro, copiando o doc 10
drizzle/0001_tipos.sql
drizzle/0002_igreja.sql
...
drizzle/0012_view_plena_comunhao.sql

# 2. Aplique
npx drizzle-kit migrate

# 3. Gere o schema TypeScript a partir do banco real
npx drizzle-kit pull
```

Assim o SQL do doc 10 entra **verbatim**, sem tradução, e o TypeScript vem depois — refletindo o que existe de fato. Se um dia divergirem, o banco ganha.

### Posso colar o SQL no SQL Editor do console do Neon?

**Pode** — a regra do doc 14 §7 é sobre **onde o SQL mora**, não sobre como ele é aplicado.

O que não pode é o banco ter um estado que nenhum arquivo do repositório descreve. Isso custaria: recriar o banco do zero (inclusive numa branch limpa para testar a importação, §6), saber quando e por que cada mudança entrou, e um `drizzle-kit pull` gerando TypeScript a partir de um estado irreproduzível.

**Se o arquivo `.sql` está no repositório e o banco corresponde a ele, tanto faz o meio.** Para a carga inicial das 12 migrations, colar no console é aceitável.

O console é inclusive **melhor** para o teste que o §5 pede antes de tudo:

```sql
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
SELECT unaccent('José da Silva');
```

Três cuidados ao usar o console:

1. **Confira a branch selecionada** — o editor executa contra a branch ativa, e você vai ter várias ao testar a importação.
2. **Um arquivo por vez, na ordem.** Se um statement falhar no meio de um bloco grande, sobra estado parcial sem mensagem clara.
3. **Depois de aplicar tudo, rode `drizzle-kit pull`** na conexão direta — independe de como o DDL entrou.

**A partir do momento em que o app estiver na Vercel e a secretaria usando**, migre para `drizzle-kit migrate`. Aí alterar schema pelo console vira risco real: deploy e banco podem divergir sem ninguém notar.

Configure `drizzle.config.ts` com `dialect: 'postgresql'` e a URL **direta**.

---

## 5. Busca sem acento — a armadilha que vai te pegar

O doc 14 §7 pede busca que ache "José da Silva" digitando "jose silva". A implementação óbvia **não funciona**:

```sql
-- ISTO FALHA: "functions in index expression must be marked IMMUTABLE"
CREATE INDEX ON pessoa (unaccent(nome_completo));
```

`unaccent()` é `STABLE`, não `IMMUTABLE`, porque depende de um dicionário que poderia mudar. Postgres recusa indexá-la. A solução padrão é um wrapper:

```sql
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- wrapper IMMUTABLE: fixa o dicionário e permite indexar
CREATE FUNCTION f_unaccent(text) RETURNS text
  LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
  RETURN unaccent('unaccent', $1);

-- indice trigram: cobre busca parcial no meio do nome
CREATE INDEX pessoa_nome_busca ON pessoa
  USING gin (f_unaccent(lower(nome_completo)) gin_trgm_ops);
```

Consulta correspondente — ⚠️ **corrigida no doc 16 §3 após teste real**:

```sql
-- ERRADO (o que eu havia escrito): exige substring contigua.
-- "jose silva" NAO acha "José da Silva", porque o "da" quebra a sequencia.
-- Testado: retorna 0 linhas.
WHERE f_unaccent(lower(nome_completo)) LIKE '%' || f_unaccent(lower($1)) || '%'

-- CERTO: um LIKE por palavra digitada, unidos por AND
SELECT * FROM pessoa
WHERE f_unaccent(lower(nome_completo)) LIKE '%jose%'
  AND f_unaccent(lower(nome_completo)) LIKE '%silv%'
ORDER BY nome_completo
LIMIT 50;
```

A aplicação quebra o termo digitado em palavras e monta um `LIKE` para cada uma.

> **Correção ao doc 10**: eu havia especificado `gin (to_tsvector('portuguese', nome_completo))`. Funciona para palavra inteira, mas não para trecho parcial ("silv" não acha "Silva"). Trigram resolve acento e digitação parcial de uma vez. Já corrigido em `sql/0003_pessoa.sql`.

✅ **`unaccent`, `pg_trgm` e `citext` foram testadas** em PostgreSQL 17 — as três criam sem problema. O `citext` era necessário e estava faltando no doc 10 (doc 16 §2.2).

---

## 6. O importador roda na sua máquina, não na Vercel ⚠️

Funções serverless da Vercel têm limite de duração. A importação é **uma transação única com 2.622 linhas e ~7.000 registros derivados** (doc 13 §7). Ela vai estourar o limite — e pior, um timeout no meio de uma transação aberta é exatamente o cenário que você não quer depurar.

```
scripts/importar-rol.ts     → roda com `npx tsx`, localmente, conexão DIRETA
```

O doc 14 §7 já tinha decidido "script separado, não rota da aplicação". Com Vercel, isso deixa de ser preferência e vira **requisito**.

**Roteiro seguro, aproveitando o branching do Neon:**

```bash
# 1. cria branch do banco a partir da main
neon branches create --name teste-importacao

# 2. roda o importador apontando para a branch
DATABASE_URL_UNPOOLED=<url-da-branch> npx tsx scripts/importar-rol.ts

# 3. confere os numeros do doc 13 §7
# 4. deu certo?  repete na main.   deu errado?  descarta a branch e ajusta
neon branches delete teste-importacao
```

Você pode errar quantas vezes precisar. Use isso — a importação é irreversível na produção, mas infinitamente repetível numa branch.

---

## 7. Estrutura de pastas sugerida

```
app/
  (rol)/
    membros/
      page.tsx                 lista com busca e filtros
      [id]/page.tsx            ficha (abas do UC-M1-09)
      novo/page.tsx            assistente de admissão
    revisao/
      page.tsx                 filas do UC-M1-15   ← construa cedo
  layout.tsx
db/
  schema.ts                    gerado por drizzle-kit pull
  queries/
    membros.ts                 consultas do rol
    elegibilidade.ts           plena comunhao, RN-ELE-05
drizzle/
  0001_tipos.sql ... 0012_*.sql
lib/
  validacao/
    admissao.ts                schemas Zod por forma de admissao
    membro.ts
  dominio/
    plena-comunhao.ts          RN-MEM-06
    elegibilidade.ts           RN-ELE-05, RN-OFI-03
scripts/
  importar-rol.ts
  perfilar-csv.ts
```

**A regra de organização**: `lib/dominio/` guarda as regras da Constituição, puras e testáveis, sem tocar em banco nem em React. É a única parte do código que precisa de teste (doc 14 §7) e a única que não pode ser reescrita sem consultar o doc 03.

---

## 8. Preparar para auth sem implementar auth

A decisão C1 adiou permissões. Duas providências que custam quase nada agora e evitam retrabalho depois:

1. **Toda mutação passa por uma Server Action em `app/**/actions.ts`** — nunca por acesso direto ao banco a partir do componente. Quando a auth chegar, a verificação entra no topo de cada action, num lugar só.
2. **Campo `sigiloso` já existe no modelo** (decisão B5-a). Respeite-o nas consultas desde já: registros sigilosos não aparecem em listagem geral, mesmo sem login. Você adiou permissões, não confidencialidade.

Não instale biblioteca de auth agora.

---

## 9. Deploy

```
Vercel → importar repositório do GitHub
Environment Variables:
  DATABASE_URL           (pooled)
  DATABASE_URL_UNPOOLED  (direta — só se algum job precisar)
  BLOB_READ_WRITE_TOKEN  (se P24 = Vercel Blob)
```

**Um ambiente só** (doc 14 §7). Os *preview deployments* da Vercel já dão ambiente de teste por PR, de graça e sem manutenção — apontando para uma branch do Neon, se quiser isolar dados.

⚠️ **Sobre continuidade**: crie o projeto Vercel e o Neon numa conta que **não seja pessoal e intransferível**. Um sistema de igreja sobrevive ao voluntário que o escreveu. Idealmente uma conta com o e-mail institucional da IPA, com você como membro. É a coisa mais barata de fazer agora e a mais cara de corrigir depois.

---

## 10. Ordem da primeira semana

| # | Tarefa | Pronto quando |
|---|---|---|
| 1 | Criar projeto Neon + `create-next-app` + Drizzle | `SELECT 1` funciona do Next |
| 2 | Migrations `0001`–`0004` (doc 10) com as extensões do §5 | Tabelas `pessoa`, `membro`, `admissao`, `demissao` existem |
| 3 | `drizzle-kit pull` | `db/schema.ts` gerado |
| 4 | Passada de validação do importador (doc 13 §5) | Relatório sem erro bloqueante, **sem escrever nada** |
| 5 | Importador completo numa branch do Neon | Números do doc 13 §7 batem |
| 6 | Tela de lista com busca | Digitar "jose silva" acha "José da Silva" |
| 7 | Ficha do membro (aba Dados) | Abre e mostra o histórico |
| 8 | Fila de revisão (UC-M1-15) | Secretária consegue classificar os 88 `NAO_DEFINIDO` |

Ao fim do passo 5 você tem 2.622 pessoas no banco. Ao fim do 6, algo demonstrável para o Conselho.

---

## 11. Pendências

### P24 — Onde ficam as 900 fotos?
O Neon não tem storage de arquivos.
- [ ] **(a) Recomendado** — **Vercel Blob**. Integração nativa, sem conta nova, custo desprezível neste volume.
- [ ] (b) Cloudflare R2 — mais barato em escala, irrelevante para 900 arquivos.
- [ ] (c) Manter no storage atual e só referenciar a URL.
- [ ] (d) Não migrar fotos na v1.

> (a) mantém tudo em uma conta só, que é o que importa para continuidade (§9).

**Decisão:**

### P25 — Onde fica o repositório?
Este projeto está em `~/Projects/ipa/docs`. A aplicação vai em `~/Projects/ipa/app`, na raiz `~/Projects/ipa`, ou em outro lugar? Já existe repositório git?

> Sugestão: `~/Projects/ipa` como raiz do repo, com `docs/` e `app/` lado a lado. A documentação versionada junto do código é o que mantém o doc 03 vivo — e ele é a única fonte das regras.

**Decisão:**

### P26 — Quer que eu faça o scaffold?
Posso criar o projeto Next, configurar Drizzle e Neon, escrever as migrations `0001`–`0004` a partir do doc 10 e o script de perfilagem — deixando pronto para você rodar o primeiro `drizzle-kit migrate`.

**Decisão:**
