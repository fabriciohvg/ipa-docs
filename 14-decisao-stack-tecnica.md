# 14 — Decisão de stack técnica

Última decisão adiada (doc 07, C8: *"só faz sentido escolher depois das specs"*). As specs estão prontas, então chegou a hora.

---

## 1. O que o sistema realmente precisa fazer

Destilado dos docs 10, 11 e 13 — não do que "sistemas de igreja" costumam ter:

| Necessidade | Peso | Observação |
|---|---|---|
| **Formulários com validação condicional** | 🔴 alto | O assistente de admissão muda os campos conforme a forma escolhida (7 variantes) |
| **Listagem com busca, filtro e paginação** | 🔴 alto | 2.622 registros, busca por nome parcial **sem acento** |
| **Filas de revisão com edição em lote** | 🔴 alto | ~1.500 itens; a tela mais usada nos primeiros meses |
| **Script de importação** | 🟡 pontual | Roda uma vez. Pode até ser fora da aplicação |
| **Exportação PDF e CSV** | 🟡 médio | Rol, atas, relatório ao Presbitério |
| **Migrations versionadas** | 🔴 alto | 12 migrations já especificadas |
| **Auth** | ⚪ depois | Adiado (C1), mas **vai chegar** — escolher algo onde adicionar seja trivial |

## 2. O que **não** importa aqui

Vale explicitar, porque é onde projetos pequenos se perdem imitando arquitetura de projetos grandes:

- **Escala.** 2.622 registros e ~10 usuários. Cabe em qualquer coisa. Um SQLite num Raspberry Pi aguentaria.
- **Performance.** Nenhuma consulta deste sistema é lenta em Postgres com os índices do doc 10.
- **Tempo real, offline, mobile app.** Nada nas specs pede isso.
- **Microserviços, filas, cache.** Não.

**O gargalo deste projeto é o seu tempo e a sua energia**, não a máquina. Toda escolha técnica deve ser avaliada por "quanto código eu *não* escrevo".

---

## 3. A regra que decide

> **Escolha o que você já domina.**

Não é conselho genérico — é específico ao seu contexto:

1. **Projeto longo com um dev só.** Você vai voltar a este código depois de semanas sem tocá-lo. Stack familiar significa retomar em minutos em vez de reaprender.
2. **TDAH.** Aprender framework novo *e* modelar domínio novo ao mesmo tempo é a receita para o projeto morrer no mês dois. O domínio já é difícil — a Constituição da IPB tem 152 artigos. Não some uma segunda curva de aprendizado.
3. **Sistema de igreja dura décadas.** Tecnologia entediante e estável vale mais que moderna.

Se você já sabe Laravel, use Laravel. Se já sabe Rails, use Rails. Se já sabe Next, use Next. **A pior escolha é a que exige tutorial.**

---

## 4. O que o sistema atual sugere sobre você

Pistas do CSV (doc 12 §4): UUIDs como PK, `created_at` com timezone `+00`, caminhos `picture/<nome>_<uuid>.jpeg`.

Isso é a assinatura de **Postgres + Supabase**. Provavelmente você já tem conta, projeto e alguma familiaridade com o ecossistema — o que puxa a decisão para o mundo JS/TS.

Se estiver certo, a recomendação abaixo é praticamente automática. Se estiver errado, ignore e vá pela regra do §3.

---

## 5. Três caminhos concretos

### 🟢 (a) Next.js + TypeScript + Postgres — *recomendado se você já vive em JS/TS*

```
Next.js (App Router) · TypeScript
Postgres (Supabase — o mesmo que já existe)
Drizzle ORM  (migrations SQL de verdade, próximas ao doc 10)
shadcn/ui + Tailwind  (tabelas, formulários e modais prontos)
Zod  (validação compartilhada entre formulário e servidor)
react-hook-form
```

**A favor**: Server Actions eliminam a camada de API para um app interno · Zod expressa bem as validações condicionais do assistente de admissão · shadcn dá tabela com filtro e paginação sem escrever CSS · adicionar Supabase Auth depois é meia tarde · você reaproveita o banco atual.

**Contra**: mais peças para montar que um framework batteries-included · App Router tem armadilhas de cache que confundem.

### 🟢 (b) Laravel + Filament — *recomendado se você já sabe PHP*

**A favor**: **Filament gera as telas de CRUD, filtro, busca e ação em lote** — as filas de revisão praticamente saem de graça, e elas são o volume de trabalho da E1 · migrations, validação, PDF e auth já vêm na caixa · hospedagem trivial e barata.

**Contra**: sai do ecossistema Supabase (dá para apontar o Postgres dele mesmo assim) · fica preso ao padrão visual do Filament.

> Se você conhece PHP mesmo que superficialmente, **esta é a opção que gera menos código para este projeto específico**. Um admin gerado cobre M1 quase inteiro.

### 🟡 (c) Rails 8 — *se você já sabe Ruby*

**A favor**: melhor experiência de migrations e console do mercado; o console é ideal para investigar dados sujos, que é o que você vai fazer bastante.
**Contra**: sem admin gerado tão forte quanto Filament; comunidade menor no Brasil.

---

## 6. Recomendação

1. **Você já domina alguma das três?** → use essa. Fim.
2. **Domina JS/TS e já usa Supabase?** → **(a) Next.js**.
3. **Não domina nenhuma, ou quer o caminho mais curto até a E1 funcionando?** → **(b) Laravel + Filament**, pelo argumento do CRUD gerado.

---

## 7. Decisões independentes de stack

Valem em qualquer caminho — decida uma vez e não revisite.

| Item | Decisão | Motivo |
|---|---|---|
| **Banco** | **Postgres** | O doc 10 usa enums nativos, índice parcial e GIN. Trocar por MySQL/SQLite custa reescrever metade do schema |
| **Busca sem acento** | extensão `unaccent` + índice GIN | "jose silva" precisa achar "José da Silva". Resolver no banco, não na aplicação |
| **Migrations** | versionadas em arquivo, no repositório | Nunca alterar schema pelo painel do Supabase — vira divergência silenciosa |
| **Importador** | **script separado**, não rota da aplicação | Roda uma vez (doc 13). Não merece virar feature. Pode ser Python, se for mais rápido para você — ele só fala SQL |
| **PDF** | HTML + impressão do navegador na v1 | Rol e listas são tabelas. Biblioteca de PDF só quando a ata exigir layout fiel |
| **Testes** | só nas regras da CI | Testar `Oficio`/`Mandato`, elegibilidade, plena comunhão e o importador. **Não** testar CRUD gerado |
| **Deploy** | um ambiente só | 10 usuários internos. Staging separado é cerimônia que você não vai manter |
| **Backup** | automático do Postgres + cópia do CSV original | O CSV de origem é o único artefato irrecuperável. Guarde-o em dois lugares |

---

## 8. Pendências

### P21 — Qual stack?
- [ ] (a) Next.js + TypeScript + Postgres
- [ ] (b) Laravel + Filament
- [ ] (c) Rails
- [ ] (d) Outra — qual?

**O que eu preciso saber para ajudar melhor**: em que você programa hoje com conforto? E existe algo que você **não** quer usar?

**Decisão:** (a)

### P22 — Reaproveitar o Supabase atual?
- [ ] **(a) Recomendado** — novo projeto Supabase, banco limpo, importação do zero. O schema antigo não serve ao modelo v3.
- [ ] (b) Mesmo projeto, schema novo ao lado do antigo.
- [ ] (c) Sair do Supabase.

> (a) evita conviver com tabelas mortas durante a transição. O sistema antigo continua de pé, intocado, até a virada — e o CSV de 10/08 já está congelado (P20).

**Decisão:** (a) Postgres no Neon DB

### P23 — Onde vai rodar?
Servidor da igreja, VPS, Vercel/Railway, máquina local?
> Com 10 usuários, o plano gratuito de qualquer PaaS resolve. A pergunta real é quem paga e quem tem acesso quando você não estiver disponível — isso é continuidade, não infraestrutura.

**Decisão:** Vercel

---

## 9. Depois desta decisão

O caminho até o primeiro uso real:

```
P21 decidida
   ↓
migrations 001–005 (doc 10)            ~1 sessão
   ↓
importador (doc 13 §11, passos 2–6)    ~2–3 sessões
   ↓
tela de rol + busca + ficha (doc 11)   ~2–3 sessões
   ↓
fila de revisão (UC-M1-15)             ~2 sessões
   ↓
▶ SECRETARIA COMEÇA A USAR
```

Depois disso, o resto do M1 e o M2 entram sem pressa, com o sistema já em uso.

**O marco que importa não é "M1 completo" — é "a secretaria abriu o sistema em vez da planilha".** Tudo antes disso é investimento; tudo depois é melhoria.
