# 18 — Plano de implementação das telas

Ponto de partida: repo Next.js com shadcn/ui, Tailwind, Drizzle e schema já gerado por `drizzle-kit pull`. Banco Neon populado com os dados reais.

Plano em **14 passos**, agrupados em 3 entregas. Cada passo tem um entregável e um critério de pronto objetivo. Ordem por dependência real — não pule.

---

## Passo 0 — Antes de escrever tela (10 min)

Encontrei um problema no que já foi importado. O importador calcula **15 motivos de pendência** por pessoa, mas até agora gravava só o booleano `pendencia_revisao`. A tela de fila de revisão — a mais importante dos primeiros meses — não teria como mostrar *por quê* nem filtrar por fila.

Três motivos nem são recuperáveis por consulta, porque a informação de origem não existe mais no schema: `marcado 'Revisar' no legado`, `'Não membro' com situação Ativo` e `vínculo familiar ambíguo`.

```bash
# 1. aplicar a migration nova
psql "$DATABASE_URL_UNPOOLED" -f sql/0013_pendencia_motivos.sql

# 2. reimportar — o banco JA tem os dados, entao precisa de --limpar
python import/importar_rol.py --csv membros_rows.csv \
       --dsn "$DATABASE_URL_UNPOOLED" --importar --limpar

# 3. regenerar o schema TS (pendencia_motivos e forma_arbitrada sao colunas novas)
npx drizzle-kit pull
```

> ⚠️ **`--limpar` apaga e recarrega.** Sem ele, o importador **recusa** rodar em banco populado — a `UNIQUE` em `id_legado` já impediria de qualquer forma, com `ROLLBACK` limpo.
>
> `--limpar` faz `TRUNCATE ... CASCADE` nas 9 tabelas do importador. O CASCADE também esvazia qualquer outra tabela que as referencie (`reuniao`, `eleicao`, `presenca`…). **Isso é seguro agora**, porque só existem dados de importação. A partir da Entrega C, quando houver atas e resoluções de verdade, **nunca mais use `--limpar`** — a partir dali, correções são feitas pela tela, não por reimportação.

A migration também adiciona `forma_arbitrada` em `admissao`/`demissao`: 8 admissões e 11 demissões não tinham forma no legado e recebiam uma arbitrada **em silêncio**, indistinguível de uma real. Agora ficam marcadas.

**Pronto quando** esta consulta devolver as 15 filas:

```sql
SELECT motivo, count(*) FROM pessoa, unnest(pendencia_motivos) motivo
GROUP BY 1 ORDER BY 2 DESC;
```

> ⚠️ Reimportar apaga e recria tudo. Faça numa **branch** do Neon (doc 15 §6), confira, e só então repita na principal.

---

## Três armadilhas que vão te custar tempo

### A. O driver `neon-http` **não suporta transação**

O doc 15 §2 recomendou `@neondatabase/serverless` no modo HTTP. Para leitura é ótimo. Mas `db.transaction()` **lança erro** nesse driver — e o UC-M1-05 (profissão de fé = demissão + admissão + mudança de categoria + ato pastoral, tudo ou nada) exige transação.

Use **dois clientes**:

```ts
// db/index.ts
import { drizzle } from 'drizzle-orm/neon-http'
import { drizzle as drizzlePool } from 'drizzle-orm/neon-serverless'
import { Pool } from '@neondatabase/serverless'
import * as schema from './schema'

// leitura: HTTP, mais rápido em serverless
export const db = drizzle(process.env.DATABASE_URL!, { schema })

// escrita transacional: WebSocket, suporta transaction()
export const dbTx = drizzlePool(new Pool({ connectionString: process.env.DATABASE_URL! }),
                                { schema })
```

Descobrir isso no passo 10, com o formulário pronto, é frustrante. Descobrir agora é uma linha de config.

### B. `drizzle-kit pull` não gera views

`membro_em_plena_comunhao` (RN-MEM-06) provavelmente **não** apareceu no schema gerado. Confira. Se faltar, declare à mão:

```ts
import { pgView, uuid } from 'drizzle-orm/pg-core'
export const membroEmPlenaComunhao = pgView('membro_em_plena_comunhao', {
  membroId: uuid('membro_id'),
  pessoaId: uuid('pessoa_id'),
}).existing()
```

`.existing()` diz ao Drizzle para usar a view sem tentar criá-la.

### C. A busca precisa de SQL cru

A consulta validada (doc 16 §3) usa `f_unaccent` e um `LIKE` **por palavra digitada**. Drizzle não expressa isso com o query builder — use o template `sql`:

```ts
import { sql, and } from 'drizzle-orm'

const termo = (q ?? '').trim().split(/\s+/).filter(t => t.length >= 2)
const filtroNome = termo.length
  ? and(...termo.map(t =>
      sql`f_unaccent(lower(${pessoa.nomeCompleto})) LIKE '%' || f_unaccent(lower(${t})) || '%'`))
  : undefined
```

Lembre: `%jose silva%` como pedaço único **não acha** "José da Silva" — o "da" no meio quebra. Um `LIKE` por palavra, unidos por `AND`.

---

# ENTREGA A — Sistema consultável

Objetivo: abrir o navegador e ver os 2.622 registros reais. Nenhuma escrita ainda.

### Passo 1 — Camada de dados

`db/index.ts` (os dois clientes acima) · `db/queries/membros.ts` · `.env.local` com as duas connection strings.

Regra: **nenhum componente importa `db` direto.** Toda consulta vive em `db/queries/`. Quando a auth chegar (C1), a verificação entra num lugar só.

**Pronto quando** um Server Component imprime `SELECT count(*) FROM pessoa` = 2.622.

### Passo 2 — Shell e navegação

`app/layout.tsx` com sidebar: **Rol · Revisão · Ofícios · Relatórios**. Só o primeiro item funciona.

**Pronto quando** navega entre rotas sem erro de hidratação.

### Passo 3 — Lista do rol ⭐

`app/(rol)/membros/page.tsx` — Server Component, paginação **no servidor** via `searchParams` (`?page=2`), 50 por página. Não use tabela client-side com 2.622 linhas.

Colunas: nº de rol · nome · categoria · situação · congregação · marcador de pendência.

```ts
const membros = await db.select({...})
  .from(membro).innerJoin(pessoa, eq(pessoa.id, membro.pessoaId))
  .where(filtro).orderBy(pessoa.nomeCompleto)
  .limit(50).offset((page - 1) * 50)
```

**Pronto quando** a primeira página mostra 50 pessoas reais e o total bate com 2.622.

### Passo 4 — Busca e filtros

Busca por nome (armadilha C) + filtros de categoria, situação e congregação. Estado na URL, não em `useState` — link compartilhável e histórico funcionando.

**Pronto quando** digitar `jose silva` acha "José da Silva" e `?situacao=ATIVO` devolve 1.876.

### Passo 5 — Ficha do membro

`app/(rol)/membros/[id]/page.tsx`, abas: **Dados · Histórico · Família · Atos · Ofícios**.

- Histórico: `admissao` + `demissao` em linha do tempo. Marque `forma_arbitrada` com aviso visível.
- Família: `vinculo_familiar` nos **dois sentidos** (`pessoa_id` OU `relacionado_id` — o índice `vinculo_relacionado` existe para isso), mais os `nome_*_texto` de quem não casou.
- Cabeçalho com **selo de plena comunhão** e, quando negativo, o motivo.

**Pronto quando** uma pessoa com 3 vínculos e 2 atos mostra tudo.

### Passo 6 — Fila de revisão (leitura) ⭐

`app/(rol)/revisao/page.tsx`. Página inicial lista as 15 filas com contagem; clicar abre a lista daquele motivo.

```ts
sql`${pessoa.pendenciaMotivos} @> ARRAY[${motivo}]::text[]`   // usa o índice GIN
```

Ordem sugerida (doc 17 §7): `sem categoria` → `sem sexo` → `nome duplicado` → `ativo com data de demissão` → `'Não membro' com situação Ativo` → o resto.

**Pronto quando** as 15 filas aparecem com as contagens do doc 17 §7 e cada uma abre.

> **Marco.** Aqui o sistema já vale como consulta. Mostre ao Conselho antes de seguir — retorno cedo vale mais que funcionalidade.

---

# ENTREGA B — A secretaria começa a usar

Objetivo: resolver as 1.588 pendências. É aqui que o sistema passa a ser trabalho real, não demonstração.

### Passo 7 — Primeira mutação: resolver pendência ⭐

Server Actions em `app/(rol)/revisao/actions.ts`. Edição **em lote** direto na lista:

| Fila | Ação | Efeito |
|---|---|---|
| Sem sexo · Sexo inferido | escolher M/F | grava `sexo`, zera `sexo_inferido`, remove motivo |
| Sem categoria · Categoria inferida | comungante / não comungante | grava `categoria`, zera `categoria_inferida` |
| Ativo com data de demissão | manter ativo / demitir | limpa `data_demissao` ou muda `situacao` |
| Nome duplicado | mesma pessoa / homônimos | marca; **fusão fica para depois** |

Padrão da action:

```ts
'use server'
export async function resolverSexo(pessoaId: string, sexo: 'M' | 'F') {
  await db.update(pessoa).set({
    sexo, sexoInferido: false,
    pendenciaMotivos: sql`array_remove(array_remove(${pessoa.pendenciaMotivos},
                          'sem sexo'), 'sexo inferido, a confirmar')`,
  }).where(eq(pessoa.id, pessoaId))
  revalidatePath('/revisao')
}
```

Mantenha `pendencia_revisao` coerente: `= cardinality(pendencia_motivos) > 0`.

**Não implemente fusão de duplicatas agora.** É irreversível e envolve mover eventos entre pessoas. Marcar já resolve; fusão fica para quando o resto estiver estável.

**Pronto quando** a secretária classifica 20 pessoas sem sexo e o contador da fila cai.

### Passo 8 — Edição da ficha

Formulário com `react-hook-form` + Zod (`lib/validacao/pessoa.ts`), **o mesmo schema no cliente e na action**.

Validações que a Constituição exige: data de admissão não futura nem anterior ao nascimento; `civilmente_capaz` e `sexo` visíveis porque decidem elegibilidade (RN-MEM-04, RN-OFI-03).

**Pronto quando** editar e recarregar mantém o valor, e data inválida é recusada nos dois lados.

---

# ENTREGA C — Substitui a planilha

### Passo 9 — Assistente de admissão

`app/(rol)/membros/novo/page.tsx`. Passos: pessoa → forma → campos condicionais → ata e lotação → revisão.

Campos condicionais por forma: doc 11 §5.3. **Jurisdição a pedido primeiro na lista** — foi 831 das admissões históricas, é o caminho principal, não a exceção.

Número de rol via `SELECT proximo_numero_rol()`. ⚠️ Sob dois cadastros simultâneos, `MAX()+1` colide: capture a violação da `UNIQUE` e tente de novo.

**Pronto quando** uma admissão por jurisdição cria `pessoa` + `membro` + `admissao` com o próximo número correto.

### Passo 10 — Profissão de fé (a transação) ⭐

UC-M1-05. **Use `dbTx`** (armadilha A). Quatro escritas, tudo ou nada:

```ts
await dbTx.transaction(async (tx) => {
  await tx.insert(demissao).values({ membroId, data, forma: 'PROFISSAO_FE' })
  await tx.insert(admissao).values({ membroId, data, forma: 'PROFISSAO_FE' })
  await tx.update(membro).set({ categoria: 'COMUNGANTE', dataProfissaoFe: data })
          .where(eq(membro.id, membroId))
  const [ato] = await tx.insert(atoPastoral)
          .values({ tipo: 'PROFISSAO_DE_FE', data, oficianteId }).returning()
  await tx.insert(participanteAtoPastoral)
          .values({ atoPastoralId: ato.id, pessoaId, papel: 'PROFITENTE' })
})
```

Os dois eventos existem porque o formulário CSM-IPB lança a mesma pessoa como saída dos não comungantes **e** entrada dos comungantes. Um evento só quebra o fechamento dos dois quadros — e foi exatamente o que o sistema antigo perdeu: **zero** demissões por profissão de fé em todo o histórico (doc 12 §3.5).

**Pronto quando** promover um não comungante gera os 5 registros e a contagem de cada rol muda em 1.

### Passo 11 — Demissão

Modal com forma, data, ata e confirmação explícita. Nunca oferecer exclusão do registro — membro sai por `Demissao`.

**Pronto quando** demitir tira a pessoa do rol ativo e ela continua na ficha com histórico.

### Passo 12 — Exportações

Rol de comungantes, não comungantes e lista de aptos (só plena comunhão). CSV nativo; PDF via impressão do navegador com `@media print` (doc 14 §7) — nada de biblioteca de PDF ainda.

**Pronto quando** o PDF do rol sai paginado e legível.

### Passo 13 — Painel de alertas

UC-M1-13: não comungantes fazendo 18 anos (D-180 e D-0), paradeiro ignorado, admissões sem ata.

⚠️ **Confirme a P3 do doc 08 antes de ligar a baixa por maioridade.** A IPA hoje não dá baixa aos 18 — ligar sem avisar faz o sistema propor centenas de exclusões no primeiro dia.

### Passo 14 — Estatística anual

A consulta da Seção III do CSM-IPB, agrupada por forma **e sexo**.

Mostre o fechamento: `ano_anterior + admissões − demissões = ano_atual`. Ele **não vai fechar** enquanto houver gente sem sexo — e isso é a melhor justificativa que existe para a fila do passo 7. Deixe a discrepância visível na tela, não escondida.

---

## Resumo

| Entrega | Passos | Resultado |
|---|---|---|
| **A — Consultar** | 0–6 | 2.622 registros navegáveis, buscáveis, com filas visíveis |
| **B — Limpar** | 7–8 | Secretaria trabalhando as 1.588 pendências |
| **C — Operar** | 9–14 | Admissões, demissões e relatório saem do sistema |

Ao fim da **A**, mostre ao Conselho. Ao fim da **B**, a planilha vira histórico. A **C** pode levar meses e tudo bem — o sistema já estará em uso.

**Se travar**: volte ao passo 3. Lista do rol funcionando com dados reais é o que sustenta o resto.

---

## Fora deste plano

Ofícios e mandatos (M2) dependem do levantamento manual das 41 pessoas — dado que não vem do CSV e precisa do secretário do Conselho. Reuniões e atas (M3), assembleia e eleições (M4), cartas (M6): specs quando chegar a vez, com o sistema já em uso e a secretaria dando retorno. Não escreva agora — seria adivinhar.
