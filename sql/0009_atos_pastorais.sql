-- 0009 — atos pastorais e participantes · Doc 10 §7

-- oficiante_id e OPCIONAL: muitos dos ~1.276 atos historicos foram oficiados por
-- pastores que nunca existirao como pessoa neste banco (doc 09 §2.5).
CREATE TABLE ato_pastoral (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo                     tipo_ato_pastoral NOT NULL,
  data                     date NOT NULL,
  local                    text,
  oficiante_id             uuid REFERENCES pessoa(id),
  oficiante_nome_externo   text,
  igreja_externa_nome      text,
  congregacao_id           uuid REFERENCES congregacao(id),
  reportado_ao_conselho_em date,
  resolucao_registro_id    uuid REFERENCES resolucao(id),
  livro_registro           text,
  folha                    text,
  termo                    text,
  efeito_civil             boolean,
  inferido                 boolean NOT NULL DEFAULT false,
  sigiloso                 boolean NOT NULL DEFAULT false,   -- aconselhamento (B5-a)
  origem_migracao          boolean NOT NULL DEFAULT false,
  observacoes              text,
  criado_em                timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oficiante_identificado
    CHECK (oficiante_id IS NOT NULL OR oficiante_nome_externo IS NOT NULL)
);
CREATE INDEX ato_pastoral_tipo_data ON ato_pastoral (tipo, data);

CREATE TABLE participante_ato_pastoral (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ato_pastoral_id           uuid NOT NULL REFERENCES ato_pastoral(id) ON DELETE CASCADE,
  pessoa_id                 uuid REFERENCES pessoa(id),
  nome_externo              text,
  papel                     text NOT NULL,   -- BATIZANDO | PROFITENTE | NUBENTE | PAI | MAE | ...
  em_plena_comunhao_na_data boolean,         -- snapshot (RN-ATO-04)
  criado_em                 timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT participante_identificado
    CHECK (pessoa_id IS NOT NULL OR nome_externo IS NOT NULL)
);
CREATE INDEX participante_pessoa ON participante_ato_pastoral (pessoa_id);
CREATE INDEX participante_ato    ON participante_ato_pastoral (ato_pastoral_id);

ALTER TABLE admissao ADD CONSTRAINT admissao_ato_pastoral_fk
  FOREIGN KEY (ato_pastoral_id) REFERENCES ato_pastoral(id);
