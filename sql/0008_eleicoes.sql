-- 0008 — assembleia, eleicoes e lista congelada de aptos · Doc 10 §6

CREATE TABLE eleicao (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id                 uuid NOT NULL REFERENCES reuniao(id),  -- a assembleia
  cargo_em_disputa           text NOT NULL,   -- PASTOR_EFETIVO | PRESBITERO | DIACONO
  numero_de_vagas            integer NOT NULL CHECK (numero_de_vagas > 0),
  resolucao_determinou_id    uuid REFERENCES resolucao(id),
  data_instrucao_da_igreja   date,            -- RN-ELE-03: minimo D-30
  instrucoes_do_pleito       text,
  status                     text NOT NULL DEFAULT 'CONVOCADA',
  regularidade_verificada_em date,
  criado_em                  timestamptz NOT NULL DEFAULT now()
);

-- RN-ELE-04: snapshot congelado. Sem ela, "quem podia votar em 2019?" so tem resposta errada.
CREATE TABLE apto_a_votar (
  eleicao_id             uuid NOT NULL REFERENCES eleicao(id) ON DELETE CASCADE,
  membro_id              uuid NOT NULL REFERENCES membro(id),
  pode_votar             boolean NOT NULL,
  pode_ser_votado        boolean NOT NULL,
  motivo_inelegibilidade text,
  PRIMARY KEY (eleicao_id, membro_id)
);

CREATE TABLE candidatura (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  eleicao_id             uuid NOT NULL REFERENCES eleicao(id) ON DELETE CASCADE,
  pessoa_id              uuid NOT NULL REFERENCES pessoa(id),
  indicado_pelo_conselho boolean NOT NULL DEFAULT false,
  aceitou_o_cargo        boolean,
  objecao_do_conselho    boolean NOT NULL DEFAULT false,
  motivo_objecao         text,
  votos_recebidos        integer,
  resultado              text,   -- ELEITO | NAO_ELEITO | SUPLENTE
  criado_em              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT candidatura_unica UNIQUE (eleicao_id, pessoa_id)
);

ALTER TABLE mandato          ADD CONSTRAINT mandato_eleicao_fk
  FOREIGN KEY (eleicao_id) REFERENCES eleicao(id);
ALTER TABLE relacao_pastoral ADD CONSTRAINT relacao_pastoral_eleicao_fk
  FOREIGN KEY (eleicao_id) REFERENCES eleicao(id);
