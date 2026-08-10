# 01 — Roadmap: da Constituição ao modelo

Objetivo final: sair de um texto jurídico de 152 artigos e chegar em **entidades + regras + specs** prontas para virar código.

Formato pensado para TDAH: cada passo tem **1 entregável**, **critério de "pronto"** objetivo e **estimativa de fôlego** (não de relógio). Nunca faça dois passos no mesmo dia se estiver rendendo pouco — a ordem importa mais que a velocidade.

---

## Visão geral das fases

```
FASE 1  Extrair       →  o que a Constituição diz sobre igreja local    [FEITO]
FASE 2  Nomear        →  glossário / linguagem ubíqua                    [FEITO]
FASE 3  Modelar       →  entidades, atributos, relações                  [FEITO — v1]
FASE 4  Decidir       →  suas escolhas locais                            [VOCÊ]
FASE 5  Especificar   →  casos de uso → telas → schema
FASE 6  Cortar        →  MVP: o que entra na v1 do app
```

---

## FASE 1 — Extrair (feito)

**Entregável**: `03-regras-constitucionais-igreja-local.md`

Método usado (registrado para você repetir se um dia entrar o Código de Disciplina ou os Princípios de Liturgia, que a CI cita nos Arts. 151–152 mas não contém):

1. Ler capítulo por capítulo marcando cada artigo com uma etiqueta:
   - `LOCAL` → age dentro da igreja local (entra no sistema)
   - `FRONTEIRA` → a igreja local envia/recebe algo do Presbitério (entra como campo/documento, não como fluxo)
   - `FORA` → só Presbitério/Sínodo/SC (ignorar)
2. Para cada `LOCAL`, escrever a regra em uma frase imperativa testável.
   - Ruim: "O mandato é de cinco anos."
   - Bom: "Um mandato de presbítero ou diácono não pode ter duração superior a 5 anos (CI Art. 54)."
3. Classificar a regra: **estrutura** (existe uma coisa), **restrição** (validação), **processo** (sequência de atos) ou **prazo** (temporal).

**Pronto quando**: toda regra `LOCAL` tem ID, texto imperativo e referência de artigo.

---

## FASE 2 — Nomear (feito)

**Entregável**: `02-glossario-dominio.md`

Regra de ouro: **o nome no código é o nome que o secretário do Conselho usa na ata.** Se a pessoa do cartório eclesiástico chama de "rol de comungantes", a tabela não vai se chamar `active_members`.

**Pronto quando**: nenhum termo do modelo é inventado — todos aparecem na CI ou no uso corrente da igreja.

---

## FASE 3 — Modelar (feito, v1)

**Entregáveis**: `04-modelo-de-entidades.md`, `05-maquinas-de-estado.md`

Método usado, em 4 passadas:

1. **Substantivos**: varrer as regras e listar todo substantivo concreto → candidatos a entidade.
2. **Filtro pessoa/papel**: separar o que é **pessoa** (existe uma vez) do que é **papel** (Membro, Presbítero, Tesoureiro — pode acumular, começa e termina). Este é o ponto onde 90% dos sistemas de igreja erram.
3. **Filtro estado/evento**: para cada mudança de status, perguntar "a igreja precisa saber *quando* e *por qual ato* isso mudou?". Se sim, vira **evento registrado** (uma linha de histórico), não um campo sobrescrito. A CI é obsessiva com isso — quase tudo exige registro em ata.
4. **Fechamento conciliar**: todo ato relevante da igreja local nasce de uma decisão do **Conselho** ou da **Assembleia**. Amarrar cada evento à reunião que o originou.

**Pronto quando**: você consegue responder, olhando só o modelo: *"quem era presbítero em 12/03/2019 e qual ata o ordenou?"*

---

## FASE 4 — Decidir  ← **VOCÊ ESTÁ AQUI**

**Entregável**: `07-decisoes-em-aberto.md` respondido (bloco A no mínimo).

Não são decisões técnicas. São decisões sobre **como a IPA funciona de fato**, que a Constituição deixa em aberto. Ninguém além de você (ou do secretário do Conselho) sabe responder.

**Pronto quando**: bloco A tem 5 respostas.

---

## FASE 5 — Especificar

**Entregável**: `08-specs-<modulo>.md`, um por módulo, na ordem do `06-modulos-e-casos-de-uso.md`.

Estrutura fixa de cada spec (para não gastar energia decidindo formato):

```markdown
# Spec — <Módulo>

## Objetivo em uma frase
## Entidades envolvidas
## Casos de uso  (UC-XXX-01: ator, gatilho, passos, resultado)
## Regras aplicáveis  (lista de RN-XX-00 do doc 03)
## Telas  (lista + campos + ações)
## Dados que entram / saem  (relatórios, cartas, atas)
## Fora de escopo
```

Ordem sugerida (dependência real, não gosto pessoal):

1. **Pessoas & Rol de Membros** — base de tudo, nada funciona sem isso
2. **Oficialato & Mandatos** — depende de Pessoas
3. **Conselho: reuniões, atas e resoluções** — depende de Oficialato
4. **Assembleia & Eleições** — depende de Rol e Conselho
5. **Atos pastorais & Registros eclesiásticos** — depende de Pessoas
6. **Transferências (cartas)** — depende de Rol
7. **Congregações & Sociedades internas** — depende de Conselho
8. **Relatórios & Estatística** — depende de todo o resto (é a saída)
9. **Patrimônio & Finanças** — pode ir por fora, acoplamento baixo

**Pronto quando**: cada spec cabe em uma leitura de 10 minutos e não contradiz o doc 03.

---

## FASE 6 — Cortar (MVP)

**Entregável**: `09-mvp.md`

Critério de corte proposto: entra na v1 só o que **substitui uma planilha ou caderno que a secretaria usa hoje**. Todo o resto é v2.

Aposta minha, sujeita à sua realidade: v1 = módulos 1, 2, 5 e 8 (rol, oficialato, atos pastorais, relatório anual). São exatamente os dados que o Conselho é obrigado a manter (CI Art. 83, alíneas *j*, *l*, *m*) e a enviar ao Presbitério (CI Art. 68).

---

## Se você travar

- **Travou no volume?** Trabalhe só na FASE 5, módulo 1. Ignore o resto dos arquivos.
- **Travou na dúvida "isso é entidade ou campo?"** → é entidade se a igreja precisa saber *quando mudou* e *quem decidiu*. Senão, é campo.
- **Travou em "e se um dia precisar de X?"** → escreva X em `07-decisoes-em-aberto.md`, bloco C (futuro), e siga. Não modele futuro.
