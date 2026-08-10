# 10 — Schema do banco de dados (MVP)

Tradução do modelo v2 (doc 04) para tabelas. Cobre o MVP: **E1 (rol) + E2 (oficialato/Conselho) + E3 (atos pastorais/relatórios)**.

**DDL em PostgreSQL** por ser o rendering mais legível — a stack ainda não está decidida (doc 07, C8) e nada aqui depende de Postgres além de `citext` e dos tipos `date`/`numeric`. Portar para MySQL ou SQLite é troca de tipos.

**Convenções**
- `snake_case` em português (decisão B6-a). Sem acentos e sem cedilha em identificadores.
- Toda tabela: `id` (uuid), `criado_em`, `atualizado_em`.
- Tabelas de evento (`admissao`, `demissao`, `ordenacao`, `ato_pastoral`) são **append-only** por convenção — sem `UPDATE` fora de correção explícita.
- `id_legado` em tudo que vem da planilha, para reimportação e auditoria.

---

## 0. Tipos enumerados

```sql
CREATE TYPE sexo                AS ENUM ('M','F');
CREATE TYPE categoria_membro    AS ENUM ('COMUNGANTE','NAO_COMUNGANTE','NAO_DEFINIDO');

CREATE TYPE situacao_membro     AS ENUM (
  'ATIVO','EM_DISCIPLINA','ROL_SEPARADO','TRANSFERENCIA_EM_CURSO','DEMITIDO');

CREATE TYPE forma_admissao      AS ENUM (
  -- comungantes (CI Art. 16)
  'PROFISSAO_FE','PROFISSAO_FE_E_BATISMO','CARTA_TRANSFERENCIA',
  'JURISDICAO_A_PEDIDO','JURISDICAO_EX_OFFICIO','RESTAURACAO','DESIGNACAO_PRESBITERIO',
  -- nao comungantes (CI Art. 17)
  'BATISMO_INFANTIL','TRANSFERENCIA_DOS_PAIS','JURISDICAO_SOBRE_OS_PAIS');

CREATE TYPE forma_demissao      AS ENUM (
  -- comungantes (CI Art. 23 + linhas do formulario CSM-IPB)
  'EXCLUSAO_DISCIPLINA','EXCLUSAO_A_PEDIDO','EXCLUSAO_POR_AUSENCIA',
  'CARTA_TRANSFERENCIA','JURISDICAO_ASSUMIDA_POR_OUTRA','FALECIMENTO',
  'ORDENACAO_AO_MINISTERIO','MOVIMENTO_PARA_ROL_SEPARADO',
  -- nao comungantes (CI Art. 24)
  'MAIORIDADE_18','PROFISSAO_FE','SOLICITACAO_DOS_PAIS');

CREATE TYPE tipo_oficio         AS ENUM ('PRESBITERO_REGENTE','DIACONO','MINISTRO');
CREATE TYPE situacao_oficio     AS ENUM ('EM_EXERCICIO','DISPONIBILIDADE','DEPOSTO','EMERITO');

CREATE TYPE motivo_fim_mandato  AS ENUM (
  'TERMINO_SEM_REELEICAO','MUDANCA_RESIDENCIA','DEPOSICAO',
  'AUSENCIA_6_MESES','EXONERACAO_ADMINISTRATIVA','EXONERACAO_A_PEDIDO','FALECIMENTO');

CREATE TYPE tipo_relacao_pastoral AS ENUM ('EFETIVO','AUXILIAR','EVANGELISTA','MISSIONARIO');
CREATE TYPE orgao_reuniao       AS ENUM (
  'CONSELHO','ASSEMBLEIA','JUNTA_DIACONAL','ORGANIZACAO_INTERNA','ADMINISTRACAO_CIVIL');
CREATE TYPE natureza_materia    AS ENUM ('ESPIRITUAL','ADMINISTRATIVA');
CREATE TYPE status_presenca     AS ENUM ('PRESENTE','AUSENTE_JUSTIFICADO','AUSENTE_NAO_JUSTIFICADO');

CREATE TYPE tipo_ato_pastoral   AS ENUM (
  'BATISMO_INFANTIL','BATISMO_ADULTO','PROFISSAO_DE_FE','SANTA_CEIA','CASAMENTO',
  'FUNERAL','VISITA_PASTORAL','ACONSELHAMENTO','UNCAO_ENFERMOS','BENCAO_APOSTOLICA');

CREATE TYPE tipo_congregacao    AS ENUM ('PONTO_DE_PREGACAO','CONGREGACAO');
CREATE TYPE natureza_organizacao AS ENUM ('SOCIEDADE_COM_ESTATUTO','DEPARTAMENTO_OU_MINISTERIO');
CREATE TYPE categoria_ipb       AS ENUM ('UCP','UPA','UMP','SAF','UPH','OUTRAS');
```

---

## 1. Igreja e congregações

```sql
CREATE TABLE igreja (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome                text NOT NULL,
  cnpj                text,
  data_organizacao    date,
  presbiterio_nome    text,
  presbiterio_sigla   text,
  sinodo_nome         text,
  sinodo_sigla        text,
  logradouro          text, numero_endereco text, complemento text,
  bairro              text, cidade text, uf char(2), cep text,
  caixa_postal        text, caixa_postal_cep text,
  email               citext, site text,
  estatuto_url        text, estatuto_aprovado_em date,
  criado_em           timestamptz NOT NULL DEFAULT now(),
  atualizado_em       timestamptz NOT NULL DEFAULT now()
);

-- singleton: garante uma unica igreja
CREATE UNIQUE INDEX igreja_unica ON igreja ((true));

CREATE TABLE igreja_telefone (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  igreja_id uuid NOT NULL REFERENCES igreja(id) ON DELETE CASCADE,
  numero    text NOT NULL,
  rotulo    text
);

CREATE TABLE congregacao (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome                 text NOT NULL,
  tipo                 tipo_congregacao NOT NULL,
  logradouro text, numero_endereco text, bairro text, cidade text, uf char(2), cep text,
  data_estabelecimento date,
  resolucao_id         uuid,          -- FK adicionada depois de resolucao
  responsavel_id       uuid,          -- FK adicionada depois de pessoa
  status               text NOT NULL DEFAULT 'ATIVA',
  id_legado            text,
  criado_em            timestamptz NOT NULL DEFAULT now(),
  atualizado_em        timestamptz NOT NULL DEFAULT now()
);
```

---

## 2. Pessoas

```sql
CREATE TABLE pessoa (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome_completo       text NOT NULL,
  data_nascimento     date,
  sexo                sexo,                   -- NULLABLE: falta em 860 registros reais (doc 12 §5.2)
  sexo_inferido       boolean NOT NULL DEFAULT false,
  naturalidade        text,
  estado_civil        text,
  civilmente_capaz    boolean NOT NULL DEFAULT true,
  cpf                 text, rg text,
  logradouro text, numero_endereco text, complemento text,
  bairro text, cidade text, uf char(2), cep text,
  profissao           text,
  profissao_informada text,
  escolaridade        text,
  nome_pai_texto      text,
  nome_mae_texto      text,
  nome_conjuge_texto  text,
  data_casamento      date,
  data_falecimento    date,
  foto_url            text,
  observacoes         text,
  id_legado           text UNIQUE,
  criado_em           timestamptz NOT NULL DEFAULT now(),
  atualizado_em       timestamptz NOT NULL DEFAULT now()
);

-- ⚠️ CORRIGIDO no doc 15 §5 — nao use to_tsvector aqui.
-- tsvector so acha palavra inteira: "silv" nao encontraria "Silva".
-- Para busca de pessoa por nome, use trigram + wrapper IMMUTABLE de unaccent:
--
--   CREATE EXTENSION IF NOT EXISTS unaccent;
--   CREATE EXTENSION IF NOT EXISTS pg_trgm;
--   CREATE FUNCTION f_unaccent(text) RETURNS text
--     LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
--     RETURN unaccent('unaccent', $1);
--
CREATE INDEX pessoa_nome_busca ON pessoa
  USING gin (f_unaccent(lower(nome_completo)) gin_trgm_ops);
CREATE INDEX pessoa_nascimento ON pessoa (data_nascimento);

CREATE TABLE pessoa_contato (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id uuid NOT NULL REFERENCES pessoa(id) ON DELETE CASCADE,
  tipo      text NOT NULL,            -- TELEFONE | CELULAR | EMAIL | WHATSAPP
  valor     text NOT NULL,
  principal boolean NOT NULL DEFAULT false
);
CREATE INDEX pessoa_contato_pessoa ON pessoa_contato (pessoa_id);

CREATE TABLE vinculo_familiar (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id         uuid NOT NULL REFERENCES pessoa(id) ON DELETE CASCADE,
  relacionado_id    uuid NOT NULL REFERENCES pessoa(id) ON DELETE CASCADE,
  tipo              text NOT NULL,    -- PAI | MAE | RESPONSAVEL_LEGAL | CONJUGE | FILHO
  menor_sob_guarda  boolean NOT NULL DEFAULT false,
  vigente_de        date, vigente_ate date,
  criado_em         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT vinculo_nao_reflexivo CHECK (pessoa_id <> relacionado_id),
  CONSTRAINT vinculo_unico UNIQUE (pessoa_id, relacionado_id, tipo)
);
```

---

## 3. Membresia

```sql
CREATE TABLE membro (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id           uuid NOT NULL UNIQUE REFERENCES pessoa(id),
  numero_rol          text UNIQUE,           -- 'AAAA'+sequencia (ex.: '20181567') — doc 12 §4
  categoria           categoria_membro NOT NULL DEFAULT 'NAO_DEFINIDO',
  categoria_inferida  boolean NOT NULL DEFAULT false,
  situacao            situacao_membro NOT NULL DEFAULT 'ATIVO',
  pendencia_revisao   boolean NOT NULL DEFAULT false,
  congregacao_id      uuid REFERENCES congregacao(id),
  data_batismo        date,
  data_profissao_fe   date,
  data_admissao       date,
  data_demissao       date,
  ata_admissao_legado text,
  id_legado           text UNIQUE,
  criado_em           timestamptz NOT NULL DEFAULT now(),
  atualizado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX membro_pendencia ON membro (pendencia_revisao) WHERE pendencia_revisao;

CREATE INDEX membro_situacao   ON membro (situacao, categoria);
CREATE INDEX membro_congregacao ON membro (congregacao_id);
```

> ### ⚠️ Duas `CHECK` removidas na v3 — os dados reais as violam
>
> ```sql
> -- REMOVIDA: 859 dos 1.291 comungantes nao tem data_profissao_fe (doc 12 §3.1)
> CONSTRAINT comungante_tem_profissao
>   CHECK (categoria <> 'COMUNGANTE' OR data_profissao_fe IS NOT NULL)
>
> -- REMOVIDA: 447 inativos sem data_demissao e 2 ativos com data (doc 12 §3.3)
> CONSTRAINT demissao_coerente
>   CHECK ((situacao = 'DEMITIDO') = (data_demissao IS NOT NULL))
> ```
>
> As duas expressam regras corretas da Constituição, mas **como `CHECK` impediriam a importação de 1.300+ registros legítimos**. Viram **validações de aplicação com fila de revisão** (`pendencia_revisao`), não invariantes de banco. Reintroduzi-las depois da limpeza é uma migration de uma linha — e aí sim o banco protege o que já está limpo.

```sql
```

### `admissao` e `demissao` (eventos)

```sql
CREATE TABLE admissao (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membro_id          uuid NOT NULL REFERENCES membro(id) ON DELETE CASCADE,
  data               date,          -- NULLABLE: 441 admissoes historicas sem data (doc 13 §6.3)
  forma              forma_admissao NOT NULL,
  resolucao_id       uuid,                   -- FK adicionada depois
  igreja_origem_nome text,
  carta_id           uuid,
  documento_url      text,                   -- obrigatorio na jurisdicao a pedido (RN-MEM-13)
  ato_pastoral_id    uuid,
  origem_migracao    boolean NOT NULL DEFAULT false,
  observacoes        text,
  criado_em          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX admissao_data ON admissao (data);
CREATE INDEX admissao_membro ON admissao (membro_id);

CREATE TABLE demissao (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membro_id           uuid NOT NULL REFERENCES membro(id) ON DELETE CASCADE,
  data                date,          -- NULLABLE pelo mesmo motivo da admissao
  forma               forma_demissao NOT NULL,
  resolucao_id        uuid,
  igreja_destino_nome text,
  motivo              text,
  origem_migracao     boolean NOT NULL DEFAULT false,
  criado_em           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX demissao_data ON demissao (data);
CREATE INDEX demissao_membro ON demissao (membro_id);
```

> **Por que `data` é indexada nas duas**: toda a estatística anual é `WHERE data BETWEEN '2025-01-01' AND '2025-12-31' GROUP BY forma, sexo`. É a consulta mais cara do sistema e roda com 1.669+ membros.

### Visão de plena comunhão

`em_plena_comunhao` **nunca é coluna** (RN-MEM-06). É visão:

```sql
CREATE VIEW membro_em_plena_comunhao AS
SELECT m.id AS membro_id
FROM membro m
WHERE m.categoria = 'COMUNGANTE'      -- NAO_DEFINIDO nunca entra
  AND m.situacao  = 'ATIVO'
  AND NOT EXISTS (
        SELECT 1 FROM medida_disciplinar md
        JOIN processo_disciplinar pd ON pd.id = md.processo_id
        WHERE pd.membro_id = m.id
          AND md.suspende_plena_comunhao
          AND md.relevada_em IS NULL
          AND (md.data_fim IS NULL OR md.data_fim >= current_date));
```

*Enquanto o módulo de disciplina não existir (⚪ por A5/C2), a visão degrada para as duas primeiras condições — sem quebrar nada quando as tabelas entrarem.*

---

## 4. Oficialato

```sql
CREATE TABLE oficio (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id      uuid NOT NULL REFERENCES pessoa(id),
  tipo           tipo_oficio NOT NULL,
  situacao       situacao_oficio NOT NULL DEFAULT 'EM_EXERCICIO',
  data_fim       date, motivo_fim text,
  criado_em      timestamptz NOT NULL DEFAULT now(),
  atualizado_em  timestamptz NOT NULL DEFAULT now()
);

-- RN-OFI-05: ninguem exerce dois oficios ao mesmo tempo (CI Art. 29)
CREATE UNIQUE INDEX oficio_um_em_exercicio
  ON oficio (pessoa_id) WHERE situacao = 'EM_EXERCICIO';

CREATE TABLE ordenacao (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oficio_id              uuid NOT NULL UNIQUE REFERENCES oficio(id) ON DELETE CASCADE,
  data                   date NOT NULL,
  local                  text,
  resolucao_id           uuid,
  ministro_oficiante_id  uuid REFERENCES pessoa(id),
  oficiante_nome_externo text,
  aceitou_doutrina       boolean NOT NULL DEFAULT true,   -- RN-OFI-16
  origem_migracao        boolean NOT NULL DEFAULT false,
  observacoes            text
);
```

> **`UNIQUE` em `oficio_id`** é a tradução literal do Art. 25 §1º: **uma ordenação por ofício, para sempre.** O reeleito ganha `mandato` novo, nunca `ordenacao` nova. É a constraint que impede o erro nº 3 do doc 03.

```sql
CREATE TABLE ordenacao_participante (       -- presbiteros que impuseram as maos (RN-OFI-19g)
  ordenacao_id uuid NOT NULL REFERENCES ordenacao(id) ON DELETE CASCADE,
  pessoa_id    uuid NOT NULL REFERENCES pessoa(id),
  PRIMARY KEY (ordenacao_id, pessoa_id)
);

CREATE TABLE mandato (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oficio_id              uuid NOT NULL REFERENCES oficio(id) ON DELETE CASCADE,
  eleicao_id             uuid,
  data_instalacao        date NOT NULL,
  data_termino_previsto  date NOT NULL,
  data_termino_efetivo   date,
  motivo_termino         motivo_fim_mandato,
  numero_reconducao      integer NOT NULL DEFAULT 1,
  origem_migracao        boolean NOT NULL DEFAULT false,
  criado_em              timestamptz NOT NULL DEFAULT now(),

  -- RN-OFI-09: exercicio limitado a 5 anos (CI Art. 54)
  CONSTRAINT mandato_max_cinco_anos
    CHECK (data_termino_previsto <= data_instalacao + INTERVAL '5 years'),
  CONSTRAINT mandato_ordem_datas
    CHECK (data_termino_previsto > data_instalacao)
);

-- um mandato vigente por oficio
CREATE UNIQUE INDEX mandato_um_vigente
  ON mandato (oficio_id) WHERE data_termino_efetivo IS NULL;

CREATE INDEX mandato_a_vencer ON mandato (data_termino_previsto)
  WHERE data_termino_efetivo IS NULL;      -- alerta D-90 (RN-OFI-10)
```

```sql
CREATE TABLE relacao_pastoral (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id                  uuid NOT NULL REFERENCES pessoa(id),
  tipo                       tipo_relacao_pastoral NOT NULL,
  data_inicio                date NOT NULL,
  data_posse                 date,
  data_termino_previsto      date,
  data_termino_efetivo       date,
  motivo_termino             text,
  eleicao_id                 uuid,
  presbiterio_aprovou_em     date,
  presbiterio_documento      text,
  vencimentos                numeric(12,2),
  vencimentos_aprovados_em   date,
  jubilado_em                date,
  criado_em                  timestamptz NOT NULL DEFAULT now(),

  -- RN-PAS-02 / RN-PAS-03: 5 anos para efetivo, 1 ano para auxiliar
  CONSTRAINT prazo_por_tipo CHECK (
    data_termino_previsto IS NULL
    OR (tipo = 'EFETIVO'  AND data_termino_previsto <= data_inicio + INTERVAL '5 years')
    OR (tipo = 'AUXILIAR' AND data_termino_previsto <= data_inicio + INTERVAL '1 year')
    OR tipo IN ('EVANGELISTA','MISSIONARIO'))
);

CREATE INDEX relacao_pastoral_vigente ON relacao_pastoral (pessoa_id)
  WHERE data_termino_efetivo IS NULL;

CREATE TABLE cargo_da_mesa (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id      uuid NOT NULL REFERENCES pessoa(id),
  cargo          text NOT NULL,        -- VICE_PRESIDENTE | SECRETARIO | TESOUREIRO
  ano_exercicio  integer NOT NULL,
  resolucao_id   uuid,
  CONSTRAINT mesa_cargo_unico UNIQUE (cargo, ano_exercicio, pessoa_id)
);
```

> **O Presidente do Conselho não tem linha aqui.** É o pastor, *ex officio* (RN-CON-05). Criar registro para ele seria modelar uma eleição que a Constituição não prevê.

---

## 5. Reuniões, resoluções e atas

```sql
CREATE TABLE reuniao (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  orgao                     orgao_reuniao NOT NULL,
  organizacao_interna_id    uuid,
  carater                   text NOT NULL DEFAULT 'ORDINARIA',
  data_hora                 timestamptz NOT NULL,
  local                     text,
  presidente_id             uuid REFERENCES pessoa(id),
  secretario_id             uuid REFERENCES pessoa(id),
  presidencia_ad_referendum boolean NOT NULL DEFAULT false,
  status                    text NOT NULL DEFAULT 'CONVOCADA',
  -- campos de assembleia
  tipo_pauta                text,
  exige_civilmente_capazes  boolean NOT NULL DEFAULT false,  -- RN-ASM-04
  criado_em                 timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX reuniao_orgao_data ON reuniao (orgao, data_hora DESC);

CREATE TABLE convocacao (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id        uuid NOT NULL REFERENCES reuniao(id) ON DELETE CASCADE,
  data_convocacao   date NOT NULL,
  meio              text NOT NULL,   -- PUBLICA | INDIVIDUAL | AMBAS
  convocante_id     uuid REFERENCES pessoa(id),
  motivo            text NOT NULL,   -- PERIODICA | PASTOR | VICE_PRESIDENTE | PEDIDO_PRESBITEROS | ORDEM_PRESBITERIO
  pauta_previa      text,
  comprovante_url   text,
  CONSTRAINT convocacao_antes_da_reuniao CHECK (true)  -- validado na aplicacao
);
```

> **RN-CON-09 (Art. 82)** — reunião do Conselho sem convocação a todos os presbíteros é **ilegal**. A regra é de aplicação, não de banco: exige comparar a convocação com a lista de presbíteros em exercício **na data**, que muda ao longo do tempo. Ver spec M3.

```sql
CREATE TABLE presenca (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id         uuid NOT NULL REFERENCES reuniao(id) ON DELETE CASCADE,
  pessoa_id          uuid NOT NULL REFERENCES pessoa(id),
  status             status_presenca NOT NULL,
  justificativa      text,
  qualidade          text NOT NULL DEFAULT 'MEMBRO_EFETIVO',  -- EX_OFFICIO | CONVIDADO | VISITANTE
  civilmente_capaz   boolean,       -- snapshot para RN-ASM-04
  pode_votar         boolean NOT NULL DEFAULT true,
  CONSTRAINT presenca_unica UNIQUE (reuniao_id, pessoa_id)
);
CREATE INDEX presenca_pessoa ON presenca (pessoa_id, status);
```

> Índice em `(pessoa_id, status)` porque a cessação de ofício por ausência de 6 meses (RN-OFI-12 *d*) é uma varredura por pessoa — e é a consulta que ninguém lembra de indexar.

```sql
CREATE TABLE resolucao (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id               uuid NOT NULL REFERENCES reuniao(id) ON DELETE CASCADE,
  numero                   text,
  tipo                     text NOT NULL,
  ementa                   text NOT NULL,
  texto_integral           text,
  natureza_materia         natureza_materia NOT NULL DEFAULT 'ESPIRITUAL',
  votos_favor              integer, votos_contra integer, abstencoes integer,
  ad_referendum            boolean NOT NULL DEFAULT false,
  referendada_em_reuniao_id uuid REFERENCES reuniao(id),
  submetida_ao_presbiterio boolean NOT NULL DEFAULT false,
  criado_em                timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX resolucao_reuniao ON resolucao (reuniao_id);
CREATE INDEX resolucao_pendente_referendo ON resolucao (id)
  WHERE ad_referendum AND referendada_em_reuniao_id IS NULL;

CREATE TABLE ata (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id               uuid NOT NULL UNIQUE REFERENCES reuniao(id) ON DELETE CASCADE,
  numero                   text,
  texto_integral           text,
  status                   text NOT NULL DEFAULT 'RASCUNHO',
  aprovada_em_reuniao_id   uuid REFERENCES reuniao(id),
  arquivo_url              text,
  observacoes_presbiterio  text,
  data_exame_presbiterio   date,
  cientificada_em_reuniao_id uuid REFERENCES reuniao(id)
);

CREATE TABLE manifestacao_em_ata (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ata_id               uuid NOT NULL REFERENCES ata(id) ON DELETE CASCADE,
  pessoa_id            uuid NOT NULL REFERENCES pessoa(id),
  tipo                 text NOT NULL,     -- DISSENTIMENTO | PROTESTO
  texto                text NOT NULL,
  razoes               text,
  resposta_do_concilio text,
  -- RN-CON-14 (Art. 65 §2): protesto sem razoes nao se registra
  CONSTRAINT protesto_exige_razoes
    CHECK (tipo <> 'PROTESTO' OR (razoes IS NOT NULL AND length(trim(razoes)) > 0))
);
```

> Esta é a única regra da Constituição que se traduz **literalmente** numa `CHECK`: *"Todo protesto deve ser acompanhado das razões que o justifiquem, **sob pena de não ser registrado em ata**"*.

Agora as FKs adiadas:

```sql
ALTER TABLE admissao    ADD FOREIGN KEY (resolucao_id) REFERENCES resolucao(id);
ALTER TABLE demissao    ADD FOREIGN KEY (resolucao_id) REFERENCES resolucao(id);
ALTER TABLE ordenacao   ADD FOREIGN KEY (resolucao_id) REFERENCES resolucao(id);
ALTER TABLE cargo_da_mesa ADD FOREIGN KEY (resolucao_id) REFERENCES resolucao(id);
ALTER TABLE congregacao ADD FOREIGN KEY (resolucao_id) REFERENCES resolucao(id);
ALTER TABLE congregacao ADD FOREIGN KEY (responsavel_id) REFERENCES pessoa(id);
```

---

## 6. Assembleia e eleições

```sql
CREATE TABLE eleicao (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id                uuid NOT NULL REFERENCES reuniao(id),   -- a assembleia
  cargo_em_disputa          text NOT NULL,      -- PASTOR_EFETIVO | PRESBITERO | DIACONO
  numero_de_vagas           integer NOT NULL CHECK (numero_de_vagas > 0),
  resolucao_determinou_id   uuid REFERENCES resolucao(id),
  data_instrucao_da_igreja  date,               -- RN-ELE-03: minimo D-30
  instrucoes_do_pleito      text,
  status                    text NOT NULL DEFAULT 'CONVOCADA',
  regularidade_verificada_em date
);

CREATE TABLE apto_a_votar (              -- snapshot congelado (RN-ELE-04)
  eleicao_id               uuid NOT NULL REFERENCES eleicao(id) ON DELETE CASCADE,
  membro_id                uuid NOT NULL REFERENCES membro(id),
  pode_votar               boolean NOT NULL,
  pode_ser_votado          boolean NOT NULL,
  motivo_inelegibilidade   text,
  PRIMARY KEY (eleicao_id, membro_id)
);

CREATE TABLE candidatura (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  eleicao_id              uuid NOT NULL REFERENCES eleicao(id) ON DELETE CASCADE,
  pessoa_id               uuid NOT NULL REFERENCES pessoa(id),
  indicado_pelo_conselho  boolean NOT NULL DEFAULT false,
  aceitou_o_cargo         boolean,
  objecao_do_conselho     boolean NOT NULL DEFAULT false,
  motivo_objecao          text,
  votos_recebidos         integer,
  resultado               text,        -- ELEITO | NAO_ELEITO | SUPLENTE
  CONSTRAINT candidatura_unica UNIQUE (eleicao_id, pessoa_id)
);

ALTER TABLE mandato          ADD FOREIGN KEY (eleicao_id) REFERENCES eleicao(id);
ALTER TABLE relacao_pastoral ADD FOREIGN KEY (eleicao_id) REFERENCES eleicao(id);
```

> `apto_a_votar` é a tabela que ninguém acha necessária até a primeira eleição contestada. Sem ela, a pergunta *"quem podia votar em 2019?"* só tem resposta errada.

---

## 7. Atos pastorais

```sql
CREATE TABLE ato_pastoral (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo                   tipo_ato_pastoral NOT NULL,
  data                   date NOT NULL,
  local                  text,
  oficiante_id           uuid REFERENCES pessoa(id),     -- OPCIONAL
  oficiante_nome_externo text,                            -- pastor de fora / historico
  igreja_externa_nome    text,
  congregacao_id         uuid REFERENCES congregacao(id),
  reportado_ao_conselho_em date,
  resolucao_registro_id  uuid REFERENCES resolucao(id),
  livro_registro text, folha text, termo text,
  efeito_civil           boolean,
  inferido               boolean NOT NULL DEFAULT false,
  origem_migracao        boolean NOT NULL DEFAULT false,
  observacoes            text,
  criado_em              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oficiante_identificado
    CHECK (oficiante_id IS NOT NULL OR oficiante_nome_externo IS NOT NULL)
);
CREATE INDEX ato_pastoral_tipo_data ON ato_pastoral (tipo, data);

CREATE TABLE participante_ato_pastoral (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ato_pastoral_id           uuid NOT NULL REFERENCES ato_pastoral(id) ON DELETE CASCADE,
  pessoa_id                 uuid REFERENCES pessoa(id),
  nome_externo              text,
  papel                     text NOT NULL,
  em_plena_comunhao_na_data boolean,      -- snapshot (RN-ATO-04)
  CONSTRAINT participante_identificado
    CHECK (pessoa_id IS NOT NULL OR nome_externo IS NOT NULL)
);
CREATE INDEX participante_pessoa ON participante_ato_pastoral (pessoa_id);

ALTER TABLE admissao ADD FOREIGN KEY (ato_pastoral_id) REFERENCES ato_pastoral(id);
```

> `oficiante_id` opcional + `CHECK` de identificação é o que permite importar os ~1.669 batismos históricos, muitos oficiados por pastores que nunca existirão como `pessoa` neste banco.

---

## 8. Estrutura, EBD e relatórios

```sql
CREATE TABLE organizacao_interna (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome                        text NOT NULL,
  natureza                    natureza_organizacao NOT NULL,
  categoria_ipb               categoria_ipb NOT NULL,
  numero_membros_vinculados   integer,
  estatuto_aprovado_em        date,
  resolucao_estatuto_id       uuid REFERENCES resolucao(id),
  regimento_url               text,
  status                      text NOT NULL DEFAULT 'ATIVA',
  -- deveres do Art. 83 o/p/q so valem com estatuto
  CONSTRAINT estatuto_so_com_natureza
    CHECK (estatuto_aprovado_em IS NULL OR natureza = 'SOCIEDADE_COM_ESTATUTO')
);
ALTER TABLE reuniao ADD FOREIGN KEY (organizacao_interna_id)
  REFERENCES organizacao_interna(id);

CREATE TABLE designacao (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id              uuid NOT NULL REFERENCES pessoa(id),
  organizacao_interna_id uuid REFERENCES organizacao_interna(id),
  tipo                   text NOT NULL,
  descricao              text,
  data_inicio            date NOT NULL,
  data_fim               date,
  resolucao_id           uuid REFERENCES resolucao(id)
);

CREATE TABLE escola_dominical (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome           text NOT NULL,
  congregacao_id uuid REFERENCES congregacao(id),
  status         text NOT NULL DEFAULT 'ATIVA'
);

CREATE TABLE turma_ebd (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  escola_dominical_id uuid NOT NULL REFERENCES escola_dominical(id) ON DELETE CASCADE,
  nome                text NOT NULL,
  faixa_etaria        text,
  ano_letivo          integer NOT NULL
);

CREATE TABLE atuacao_ebd (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  turma_ebd_id uuid NOT NULL REFERENCES turma_ebd(id) ON DELETE CASCADE,
  pessoa_id    uuid REFERENCES pessoa(id),
  nome_externo text,                         -- aluno nao membro
  papel        text NOT NULL,                -- PROFESSOR | ALUNO
  ano_letivo   integer NOT NULL,
  CONSTRAINT atuacao_identificada
    CHECK (pessoa_id IS NOT NULL OR nome_externo IS NOT NULL)
);

CREATE TABLE relatorio_anual (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercicio                integer NOT NULL UNIQUE,
  texto_atividades         text,
  apresentado_reuniao_id   uuid REFERENCES reuniao(id),
  enviado_ao_presbiterio_em date,
  arquivo_url              text,
  estatistica              jsonb,        -- snapshot congelado no fechamento
  fechado_em               timestamptz
);

CREATE TABLE relatorio_financeiro_anual (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercicio                integer NOT NULL,
  quadro                   text NOT NULL,   -- REALIZADO_ANO_ANTERIOR | PREVISAO_PROXIMO_EXERCICIO
  saldo_ano_anterior       numeric(14,2),
  rec_dizimos              numeric(14,2), rec_ofertas             numeric(14,2),
  rec_ofertas_missionarias numeric(14,2), rec_ofertas_especificas numeric(14,2),
  rec_financeiras          numeric(14,2), rec_emprestimos_ipb     numeric(14,2),
  rec_parcerias            numeric(14,2), rec_outras              numeric(14,2),
  des_patrimonio           numeric(14,2), des_causas_locais       numeric(14,2),
  des_evangelismo_local    numeric(14,2), des_missoes             numeric(14,2),
  des_acao_social          numeric(14,2), des_sustento_pastoral   numeric(14,2),
  des_verba_presbiterial   numeric(14,2), des_dizimo_supremo      numeric(14,2),
  des_emprestimos_ipb      numeric(14,2), des_outras              numeric(14,2),
  CONSTRAINT financeiro_unico UNIQUE (exercicio, quadro)
);
```

> **`relatorio_anual.estatistica` é `jsonb` congelado no fechamento**, e não uma consulta refeita a cada abertura. O relatório de 2025 entregue ao Presbitério precisa continuar mostrando 1.404 comungantes mesmo depois de alguém corrigir uma data de 2025 em 2027. Derivar sempre é certo para conferir; errado para arquivar.

---

## 9. Índices que decidem a performance

Com 1.669 membros e ~15 anos de eventos, quatro consultas dominam:

| Consulta | Índice |
|---|---|
| Busca de pessoa por nome parcial | `pessoa_nome_busca` (GIN + `pg_trgm` sobre `f_unaccent(lower(nome))`) |
| Estatística anual por forma e sexo | `admissao_data`, `demissao_data` + join em `pessoa.sexo` |
| Composição do Conselho numa data | `mandato_um_vigente`, `oficio_um_em_exercicio` |
| Ausência de 6 meses por pessoa | `presenca_pessoa` |

---

## 10. Ordem de criação (migrations)

```
001  tipos enumerados
002  igreja, igreja_telefone, congregacao
003  pessoa, pessoa_contato, vinculo_familiar
004  membro, admissao, demissao
005  oficio, ordenacao, ordenacao_participante, mandato, relacao_pastoral, cargo_da_mesa
006  reuniao, convocacao, presenca, resolucao, ata, manifestacao_em_ata
007  FKs adiadas (resolucao_id nas tabelas de evento)
008  eleicao, apto_a_votar, candidatura
009  ato_pastoral, participante_ato_pastoral
010  designacao                        (organizacao_interna e EBD ficam para depois)
011  relatorio_anual                   (relatorio_financeiro_anual fica para depois)
012  view membro_em_plena_comunhao
```

`001–004` são suficientes para a E1 e para rodar a importação do CSV.
`005` entra logo em seguida: a coluna `oficial` do CSV já traz 41 ofícios prontos para importar (doc 12 §3.2).

---

## 11. O que **não** está no schema, de propósito

| Ausente | Motivo |
|---|---|
| `usuario`, `papel`, `permissao` | Decisão do usuário: sem auth na v1 (doc 07, C1) |
| `escola_dominical`, `turma_ebd`, `atuacao_ebd` | ⚪ — instrução do usuário: Escola Bíblica fica para depois. **Remover das migrations 010** |
| `organizacao_interna` | 🟡 — não há sociedade com estatuto na IPA; ministérios informais usam `designacao` |
| `relatorio_financeiro_anual` | 🟡 — não bloqueia a E1 |
| `carta_de_transferencia` | 🟡 — 173 transferências em todo o histórico, contra 831 admissões por jurisdição; entra na E5 |
| `processo_disciplinar`, `medida_disciplinar` | ⚪ — depende do Código de Disciplina (C2). A view `membro_em_plena_comunhao` já as prevê |
| `bem`, `orcamento`, `contribuicao` | ⚪ — decisão A5-a. O formulário é atendido por `relatorio_financeiro_anual` |
| `presbiterio`, `sinodo` | Fora de escopo: são texto em `igreja`, não entidades |
