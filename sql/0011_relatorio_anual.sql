-- 0011 — relatorio anual ao Presbiterio · Doc 10 §9

-- estatistica e jsonb CONGELADO no fechamento, nao consulta refeita a cada abertura:
-- o relatorio entregue precisa continuar mostrando os mesmos numeros anos depois.
CREATE TABLE relatorio_anual (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercicio                 integer NOT NULL UNIQUE,
  texto_atividades          text,
  apresentado_reuniao_id    uuid REFERENCES reuniao(id),
  enviado_ao_presbiterio_em date,
  arquivo_url               text,
  estatistica               jsonb,
  fechado_em                timestamptz,
  criado_em                 timestamptz NOT NULL DEFAULT now(),
  atualizado_em             timestamptz NOT NULL DEFAULT now()
);
CREATE TRIGGER relatorio_anual_atualizado BEFORE UPDATE ON relatorio_anual
  FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();
