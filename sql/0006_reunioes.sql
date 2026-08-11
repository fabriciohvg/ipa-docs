-- 0006 — reunioes, convocacoes, presenca, resolucoes e atas · Doc 10 §5

CREATE TABLE reuniao (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  orgao                     orgao_reuniao NOT NULL,
  carater                   text NOT NULL DEFAULT 'ORDINARIA',   -- ORDINARIA | EXTRAORDINARIA
  data_hora                 timestamptz NOT NULL,
  local                     text,
  presidente_id             uuid REFERENCES pessoa(id),
  secretario_id             uuid REFERENCES pessoa(id),
  presidencia_ad_referendum boolean NOT NULL DEFAULT false,
  status                    text NOT NULL DEFAULT 'CONVOCADA',
  -- campos de assembleia
  tipo_pauta                text,
  exige_civilmente_capazes  boolean NOT NULL DEFAULT false,   -- RN-ASM-04
  criado_em                 timestamptz NOT NULL DEFAULT now(),
  atualizado_em             timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER reuniao_atualizado BEFORE UPDATE ON reuniao
  FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();
CREATE INDEX reuniao_orgao_data ON reuniao (orgao, data_hora DESC);

-- RN-CON-09 / CI Art. 82: reuniao do Conselho sem convocacao a TODOS os presbiteros
-- e ilegal. A regra e de aplicacao: exige a lista de presbiteros em exercicio NA DATA.
CREATE TABLE convocacao (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id      uuid NOT NULL REFERENCES reuniao(id) ON DELETE CASCADE,
  data_convocacao date NOT NULL,
  meio            text NOT NULL,   -- PUBLICA | INDIVIDUAL | AMBAS
  convocante_id   uuid REFERENCES pessoa(id),
  motivo          text NOT NULL,   -- PERIODICA | PASTOR | VICE_PRESIDENTE | PEDIDO_PRESBITEROS | ORDEM_PRESBITERIO
  pauta_previa    text,
  comprovante_url text,
  criado_em       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX convocacao_reuniao ON convocacao (reuniao_id);

CREATE TABLE presenca (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id       uuid NOT NULL REFERENCES reuniao(id) ON DELETE CASCADE,
  pessoa_id        uuid NOT NULL REFERENCES pessoa(id),
  status           status_presenca NOT NULL,
  justificativa    text,
  qualidade        text NOT NULL DEFAULT 'MEMBRO_EFETIVO',  -- EX_OFFICIO | CONVIDADO | VISITANTE
  civilmente_capaz boolean,   -- snapshot para RN-ASM-04
  pode_votar       boolean NOT NULL DEFAULT true,
  criado_em        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT presenca_unica UNIQUE (reuniao_id, pessoa_id)
);
-- cessacao de oficio por ausencia de 6 meses (RN-OFI-12d) e varredura por pessoa
CREATE INDEX presenca_pessoa ON presenca (pessoa_id, status);

CREATE TABLE resolucao (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id                uuid NOT NULL REFERENCES reuniao(id) ON DELETE CASCADE,
  numero                    text,
  tipo                      text NOT NULL,
  ementa                    text NOT NULL,
  texto_integral            text,
  natureza_materia          natureza_materia NOT NULL DEFAULT 'ESPIRITUAL',
  votos_favor               integer,
  votos_contra              integer,
  abstencoes                integer,
  ad_referendum             boolean NOT NULL DEFAULT false,
  referendada_em_reuniao_id uuid REFERENCES reuniao(id),
  submetida_ao_presbiterio  boolean NOT NULL DEFAULT false,
  sigiloso                  boolean NOT NULL DEFAULT false,   -- B5-a / CI Art. 72
  criado_em                 timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX resolucao_reuniao ON resolucao (reuniao_id);
CREATE INDEX resolucao_pendente_referendo ON resolucao (reuniao_id)
  WHERE ad_referendum AND referendada_em_reuniao_id IS NULL;

CREATE TABLE ata (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reuniao_id                 uuid NOT NULL UNIQUE REFERENCES reuniao(id) ON DELETE CASCADE,
  numero                     text,
  texto_integral             text,
  status                     text NOT NULL DEFAULT 'RASCUNHO',
  aprovada_em_reuniao_id     uuid REFERENCES reuniao(id),
  arquivo_url                text,
  observacoes_presbiterio    text,
  data_exame_presbiterio     date,
  cientificada_em_reuniao_id uuid REFERENCES reuniao(id),
  criado_em                  timestamptz NOT NULL DEFAULT now(),
  atualizado_em              timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER ata_atualizado BEFORE UPDATE ON ata
  FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();

-- RN-CON-14 / CI Art. 65 §2: "Todo protesto deve ser acompanhado das razoes que o
-- justifiquem, SOB PENA DE NAO SER REGISTRADO EM ATA." A unica regra da Constituicao
-- que se traduz literalmente numa CHECK.
CREATE TABLE manifestacao_em_ata (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ata_id               uuid NOT NULL REFERENCES ata(id) ON DELETE CASCADE,
  pessoa_id            uuid NOT NULL REFERENCES pessoa(id),
  tipo                 text NOT NULL,   -- DISSENTIMENTO | PROTESTO
  texto                text NOT NULL,
  razoes               text,
  resposta_do_concilio text,
  criado_em            timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT protesto_exige_razoes
    CHECK (tipo <> 'PROTESTO' OR (razoes IS NOT NULL AND length(trim(razoes)) > 0))
);
CREATE INDEX manifestacao_ata ON manifestacao_em_ata (ata_id);
