-- 0004 — rol de membros e eventos de admissao/demissao · Doc 10 §3

CREATE TABLE membro (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id           uuid NOT NULL UNIQUE REFERENCES pessoa(id),
  numero_rol          text UNIQUE,   -- 'AAAA'+sequencia, ex.: '20181567' (doc 12 §4)
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

CREATE TRIGGER membro_atualizado BEFORE UPDATE ON membro
  FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();

CREATE INDEX membro_situacao    ON membro (situacao, categoria);
CREATE INDEX membro_congregacao ON membro (congregacao_id);
CREATE INDEX membro_pendencia   ON membro (numero_rol) WHERE pendencia_revisao;

-- Nao ha CHECK "comungante tem profissao de fe" nem "demitido tem data de demissao":
-- os dados reais as violam em 1.300+ registros legitimos (doc 10 §3, doc 12 §3.1/§3.3).
-- Sao validacoes de aplicacao com fila de revisao.

CREATE TABLE admissao (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membro_id          uuid NOT NULL REFERENCES membro(id) ON DELETE CASCADE,
  data               date,   -- NULLABLE: 441 admissoes historicas sem data (doc 13 §6.3)
  forma              forma_admissao NOT NULL,
  resolucao_id       uuid,   -- FK em 0007
  igreja_origem_nome text,
  documento_url      text,   -- obrigatorio na jurisdicao a pedido (RN-MEM-13)
  ato_pastoral_id    uuid,   -- FK em 0009
  origem_migracao    boolean NOT NULL DEFAULT false,
  observacoes        text,
  criado_em          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX admissao_data   ON admissao (data);
CREATE INDEX admissao_membro ON admissao (membro_id);
CREATE INDEX admissao_forma  ON admissao (forma, data);

CREATE TABLE demissao (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  membro_id           uuid NOT NULL REFERENCES membro(id) ON DELETE CASCADE,
  data                date,   -- NULLABLE pelo mesmo motivo da admissao
  forma               forma_demissao NOT NULL,
  resolucao_id        uuid,   -- FK em 0007
  igreja_destino_nome text,
  motivo              text,
  origem_migracao     boolean NOT NULL DEFAULT false,
  criado_em           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX demissao_data   ON demissao (data);
CREATE INDEX demissao_membro ON demissao (membro_id);
CREATE INDEX demissao_forma  ON demissao (forma, data);
