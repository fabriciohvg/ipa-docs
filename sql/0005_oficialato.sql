-- 0005 — oficios, ordenacoes, mandatos e relacao pastoral · Doc 10 §4

CREATE TABLE oficio (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id     uuid NOT NULL REFERENCES pessoa(id),
  tipo          tipo_oficio NOT NULL,
  situacao      situacao_oficio NOT NULL DEFAULT 'EM_EXERCICIO',
  data_fim      date,
  motivo_fim    text,
  origem_migracao boolean NOT NULL DEFAULT false,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER oficio_atualizado BEFORE UPDATE ON oficio
  FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();

-- RN-OFI-05 / CI Art. 29: ninguem exerce dois oficios ao mesmo tempo
CREATE UNIQUE INDEX oficio_um_em_exercicio
  ON oficio (pessoa_id) WHERE situacao = 'EM_EXERCICIO';
CREATE INDEX oficio_tipo_situacao ON oficio (tipo, situacao);

-- CI Art. 25 §1: o oficio e perpetuo — UMA ordenacao por oficio, para sempre.
-- O reeleito ganha mandato novo, nunca ordenacao nova (RN-OFI-07).
CREATE TABLE ordenacao (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oficio_id              uuid NOT NULL UNIQUE REFERENCES oficio(id) ON DELETE CASCADE,
  data                   date NOT NULL,
  local                  text,
  resolucao_id           uuid,   -- FK em 0007
  ministro_oficiante_id  uuid REFERENCES pessoa(id),
  oficiante_nome_externo text,
  aceitou_doutrina       boolean NOT NULL DEFAULT true,  -- RN-OFI-16
  origem_migracao        boolean NOT NULL DEFAULT false,
  observacoes            text,
  criado_em              timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ordenacao_participante (   -- presbiteros que impuseram as maos (RN-OFI-19g)
  ordenacao_id uuid NOT NULL REFERENCES ordenacao(id) ON DELETE CASCADE,
  pessoa_id    uuid NOT NULL REFERENCES pessoa(id),
  PRIMARY KEY (ordenacao_id, pessoa_id)
);

CREATE TABLE mandato (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oficio_id             uuid NOT NULL REFERENCES oficio(id) ON DELETE CASCADE,
  eleicao_id            uuid,   -- FK em 0008
  data_instalacao       date NOT NULL,
  data_termino_previsto date NOT NULL,
  data_termino_efetivo  date,
  motivo_termino        motivo_fim_mandato,
  numero_reconducao     integer NOT NULL DEFAULT 1,
  origem_migracao       boolean NOT NULL DEFAULT false,
  criado_em             timestamptz NOT NULL DEFAULT now(),
  -- RN-OFI-09 / CI Art. 54: exercicio limitado a 5 anos
  CONSTRAINT mandato_max_cinco_anos
    CHECK (data_termino_previsto <= data_instalacao + INTERVAL '5 years'),
  CONSTRAINT mandato_ordem_datas
    CHECK (data_termino_previsto > data_instalacao)
);

CREATE UNIQUE INDEX mandato_um_vigente
  ON mandato (oficio_id) WHERE data_termino_efetivo IS NULL;
CREATE INDEX mandato_a_vencer ON mandato (data_termino_previsto)
  WHERE data_termino_efetivo IS NULL;   -- alerta D-90 (RN-OFI-10)

CREATE TABLE relacao_pastoral (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id                uuid NOT NULL REFERENCES pessoa(id),
  tipo                     tipo_relacao_pastoral NOT NULL,
  data_inicio              date NOT NULL,
  data_posse               date,
  data_termino_previsto    date,
  data_termino_efetivo     date,
  motivo_termino           text,
  eleicao_id               uuid,   -- FK em 0008
  presbiterio_aprovou_em   date,
  presbiterio_documento    text,
  vencimentos              numeric(12,2),
  vencimentos_aprovados_em date,
  jubilado_em              date,
  criado_em                timestamptz NOT NULL DEFAULT now(),
  -- RN-PAS-02 / RN-PAS-03: 5 anos para efetivo, 1 ano para auxiliar
  CONSTRAINT prazo_por_tipo CHECK (
    data_termino_previsto IS NULL
    OR (tipo = 'EFETIVO'  AND data_termino_previsto <= data_inicio + INTERVAL '5 years')
    OR (tipo = 'AUXILIAR' AND data_termino_previsto <= data_inicio + INTERVAL '1 year')
    OR tipo IN ('EVANGELISTA','MISSIONARIO'))
);
CREATE INDEX relacao_pastoral_vigente ON relacao_pastoral (pessoa_id)
  WHERE data_termino_efetivo IS NULL;

-- O Presidente do Conselho NAO tem linha aqui: e o pastor, ex officio (RN-CON-05).
CREATE TABLE cargo_da_mesa (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id     uuid NOT NULL REFERENCES pessoa(id),
  cargo         text NOT NULL,   -- VICE_PRESIDENTE | SECRETARIO | TESOUREIRO
  ano_exercicio integer NOT NULL,
  resolucao_id  uuid,            -- FK em 0007
  criado_em     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT mesa_cargo_unico UNIQUE (cargo, ano_exercicio, pessoa_id)
);
