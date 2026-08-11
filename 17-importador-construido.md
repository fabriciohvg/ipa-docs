# 17 — Importador construído e executado

Implementação da spec do doc 13. Código em **`docs/import/importar_rol.py`** (~470 linhas, Python 3 + `psycopg`).

**Foi executado de verdade**: PostgreSQL 17 local, as 12 migrations de `sql/` aplicadas, o `membros_rows.csv` real (2.622 linhas). Importação concluída, conferência do doc 13 §7 passou, e as consultas de domínio (rol, busca, plena comunhão, estatística) respondem corretamente.

---

## 1. Por que Python

O doc 14 §7 já previa: *"pode ser Python, se for mais rápido para você — ele só fala SQL"*.

Três razões concretas:
1. **Roda uma vez** (P17: o sistema novo substitui o antigo). Não é código de aplicação; é ferramenta descartável.
2. **Não depende do projeto Next existir.** Você pode importar o rol hoje, antes de escrever uma linha de TypeScript.
3. **Zero acoplamento.** Fala SQL puro, não conhece Drizzle nem o schema TS. Se o modelo mudar, o importador não quebra — ele já terá cumprido a função.

Se preferir TypeScript, o porte é direto: a lógica está em funções puras (`transformar()` não toca no banco).

---

## 2. Como rodar

```bash
pip install -r import/requirements.txt

# 1. VALIDAR — le, transforma e relata SEM escrever nada
python import/importar_rol.py --csv membros_rows.csv --validar

# 2. IMPORTAR — transacao unica; qualquer erro faz ROLLBACK
python import/importar_rol.py --csv membros_rows.csv \
       --dsn "$DATABASE_URL_UNPOOLED" --importar
```

⚠️ Use a connection string **direta** do Neon (sem `-pooler`) — doc 15 §3.
⚠️ Rode primeiro numa **branch** do Neon (doc 15 §6). É repetível lá, irreversível na main.

**Salvaguardas embutidas:**
- Cabeçalho diferente das 40 colunas → aborta antes de qualquer processamento.
- Valor categórico desconhecido em `membro`/`oficial`/`situacao`/`meio_admissao`/`meio_demissao` → **bloqueante**. Se alguém cadastrou algo novo no sistema antigo depois de 10/08, você fica sabendo em vez de importar lixo.
- Conferência de contagens roda **antes** do `COMMIT`; divergiu, `ROLLBACK`.

---

## 3. Calibração da inferência de sexo (P18a)

Em vez de lista genérica de nomes, o script **constrói o mapa prenome→sexo a partir dos próprios 1.762 registros que já têm sexo**. Cobre os nomes que de fato ocorrem na IPA e não inventa regra para nome que não existe aqui.

Validei por **cross-validation em 5 folds** sobre os registros com sexo conhecido:

| Parâmetros | Cobertura | Acurácia | Erros |
|---|---:|---:|---:|
| `min_ocorrencias=3, confiança=0.90` | 41,1% | 99,0% | 7 |
| **`min_ocorrencias=2, confiança=0.90`** ← escolhido | **49,8%** | **99,0%** | 9 |
| `min_ocorrencias=2, confiança=0.80` | 50,3% | 99,0% | 9 |
| `min_ocorrencias=1, confiança=0.99` | 57,8% | 98,2% | 18 |

`min_oc=2` ganha 8,7 pontos de cobertura pela **mesma** acurácia. Descer para `min_oc=1` troca mais 8 pontos pelo **dobro** de erro — e sexo decide elegibilidade ao oficialato (RN-OFI-03), então não compensa.

Resultado: **483 inferidos, 377 seguem sem sexo.** Nomes ambíguos (Darci, Nair, Ariel…) não atingem a confiança e ficam nulos de propósito.

**Todo inferido vai para a fila de revisão**, em raia própria (`sexo inferido, a confirmar`), separada de quem simplesmente não tem sexo. Com ~1% de erro esperado, são ~5 pessoas com sexo errado — e a coluna `sexo_inferido` permite filtrá-las a qualquer momento.

---

## 4. Resultado da execução

### Registros criados

| Tabela | Qtd |
|---|---:|
| `pessoa` | 2.622 |
| `membro` | 2.622 |
| `pessoa_contato` | 2.563 |
| `admissao` | 2.178 |
| `demissao` | 312 |
| `ato_pastoral` | 1.276 |
| `participante_ato_pastoral` | 1.276 |
| `vinculo_familiar` | 980 |
| `oficio` | 41 |

### Rol resultante

| | COMUNGANTE | NAO_COMUNGANTE | NAO_DEFINIDO |
|---|---:|---:|---:|
| **Total** | 2.038 | 166 | 418 |
| **Ativos** | 1.644 | 148 | 84 |

`situacao`: **1.876 ativos · 746 demitidos** · categoria inferida em **758** · plena comunhão: **1.644**

`oficio`: 21 presbíteros em exercício · 13 em disponibilidade · 7 diáconos

---

## 5. ⚠️ Correção ao doc 13 §7

**As contagens de categoria que eu havia previsto estavam erradas.** O erro era meu e só apareceu ao rodar:

| | Doc 13 §7 previa | Real |
|---|---:|---:|
| `COMUNGANTE` | 1.751 | **2.038** |
| `NAO_COMUNGANTE` | 161 | **166** |
| `NAO_DEFINIDO` | 88 | **418** |
| `categoria_inferida` | 466 | **758** |

**Causa**: eu simulei tratando os 622 `Não membro` como um balde separado, sem inferência. Mas o §4.2 da própria spec manda inferir categoria para eles também — e faz sentido: são ex-membros, e saber se um ex-membro era comungante importa para o histórico.

Aplicando a regra como especificada: 622 `Não membro` (292 com forma de admissão) + 554 vazios (466 com forma) = **758 inferidos**; os 418 restantes ficam `NAO_DEFINIDO`.

Confere: 2.038 + 166 + 418 = 2.622 ✓

**Todas as demais contagens do doc 13 §7 bateram exatamente** — pessoa, membro, admissão, demissão, atos pastorais, ofícios, situação.

---

## 6. Decisão que precisei tomar (desvio do doc 13 §4.1)

O doc 13 tinha uma contradição interna: o **§4.1** mandava forçar `situacao = DEMITIDO` para todo `Não membro`, mas o **§4.3** (sua decisão P12b) diz que a coluna `situacao` manda. E 23 registros são `Não membro` **com** `situacao = Ativo`.

**Resolvi honrando P12b literalmente**: `situacao` sempre vem da coluna `situacao`. Os 23 contraditórios entram como `ATIVO` e vão para a fila com o motivo `'Não membro' com situação Ativo`.

Por que assim: P12b foi decisão sua e explícita; o §4.1 era elaboração minha. Sobrepor a decisão do usuário em silêncio, num caso de borda, é como sistemas passam a mentir. E esses 23 não têm `numero_ordem`, nem forma de admissão, nem de demissão — são registros vazios que ninguém consegue classificar sem olhar. Fila de revisão é o destino certo.

---

## 7. Filas de revisão geradas

**1.588 pessoas · 3.164 itens** (uma pessoa pode estar em várias filas).

| Fila | Qtd | Prioridade |
|---|---:|---|
| Categoria inferida, a confirmar | 758 | Média — amostragem basta |
| Sexo inferido, a confirmar | 483 | Média — 99% de acerto esperado |
| Admissão sem data | 441 | Baixa |
| Sem categoria (`NAO_DEFINIDO`) | 418 | **Alta** — fora de listas de voto |
| Sem sexo | 377 | **Alta** — trava a estatística |
| Demitido sem evento de demissão | 311 | Baixa — histórico antigo |
| Marcado `Revisar` no legado | 99 | Média |
| Tem anotação em `notes` | 90 | Média — contêm correções manuais |
| Nome duplicado | 78 | **Alta** — 34 nomes, risco de duplicidade real |
| Tipo de batismo indeduzível | 39 | Baixa |
| `Não membro` com situação Ativo | 23 | **Alta** — contradição direta |
| Vínculo familiar ambíguo | 15 | Baixa |
| Ativo com data de demissão | 13 | **Alta** — contradição direta |
| Demissão sem forma registrada | 11 | Baixa |
| Admissão sem forma registrada | 8 | Baixa |

### Vínculos familiares

980 criados: 361 cônjuges · 316 mães · 303 pais.
Não casados, guardados como texto: 913 mães · 908 pais · 239 cônjuges — a maioria dos pais não é membro da IPA, como o doc 12 §4.4 antecipava. Nenhuma pessoa fantasma foi criada.

---

## 8. A consequência mais concreta da lacuna de sexo

Consulta real de estatística, feita no banco importado — admissões de 2025 por forma e sexo, que é exatamente a Seção III do formulário CSM-IPB:

```
         forma          | masc | fem | total
------------------------+------+-----+-------
 CARTA_TRANSFERENCIA    |   16 |  23 |    87
 JURISDICAO_A_PEDIDO    |   13 |  14 |    51
 PROFISSAO_FE_E_BATISMO |   15 |  13 |    38
```

**`masc + fem` não fecha com `total`** — 87 transferências, mas só 39 com sexo conhecido. O relatório ao Presbitério **não fecha** enquanto a fila de sexo não for trabalhada.

Isso é ótimo, não ruim: dá à secretaria um motivo tangível para trabalhar a fila. Não é "limpar dados por higiene" — é "sem isso o relatório do Presbitério não sai".

---

## 9. O que o importador **não** faz

| Ausente | Motivo | Onde entra |
|---|---|---|
| `ordenacao` e `mandato` | O CSV não tem datas | Levantamento manual, 41 pessoas (doc 09 §6) |
| Migração das fotos | Depende da P24 (Neon não tem storage) | Doc 13 §8 |
| Deduplicação | Fusão de pessoas é decisão humana | Fila de revisão, UC-M1-15 |
| Congregações | Não há coluna confiável (`id_igreja` descartado) | Cadastro manual — são 3 |
| `resolucao_id` nos eventos | Não há atas no sistema (A2-a) | Tudo marcado `origem_migracao = true` |

---

## 10. Próximo passo

O banco está populado e consultável. O caminho agora:

1. **Rode numa branch do Neon** e confira os números desta página.
2. **Cadastre as 3 congregações** e a `igreja` (1 linha) — dados do doc 08 §2.
3. **Levante os 41 ofícios**: data de ordenação e mandato vigente, com o secretário do Conselho. É o dado insubstituível da decisão A2-a e não vem do CSV.
4. **Tela de rol + busca** (doc 11) — a consulta por token do doc 16 §3 já está validada.
5. **Fila de revisão** (UC-M1-15) — 1.588 pessoas esperando, com prioridade definida no §7 acima.

Responda **P25/P26** (doc 15 §11) se quiser que eu faça o scaffold do Next e as primeiras telas.
