-- 0010 — designacoes (ministerios informais e encargos do Art. 83 x) · Doc 10 §8
--
-- organizacao_interna NAO entra: a IPA nao tem sociedade com estatuto hoje, so
-- ministerios designados com registro em ata dos lideres (decisao B2 + doc 08).
-- Escola Dominical e relatorio financeiro tambem ficam para depois.

CREATE TABLE designacao (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id    uuid NOT NULL REFERENCES pessoa(id),
  tipo         text NOT NULL,   -- LIDER_MINISTERIO | CUIDADO_ENFERMOS | COMISSAO_LOCAL | ...
  descricao    text,
  data_inicio  date NOT NULL,
  data_fim     date,
  resolucao_id uuid REFERENCES resolucao(id),
  criado_em    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT designacao_ordem_datas CHECK (data_fim IS NULL OR data_fim >= data_inicio)
);
CREATE INDEX designacao_pessoa  ON designacao (pessoa_id);
CREATE INDEX designacao_vigente ON designacao (tipo) WHERE data_fim IS NULL;
