-- 0013 — motivos da pendencia de revisao
--
-- O importador calcula 15 motivos distintos por pessoa (doc 17 §7), mas ate aqui
-- so o booleano `pendencia_revisao` era gravado. A tela de fila de revisao
-- (UC-M1-15) precisa filtrar POR MOTIVO — "quem esta sem sexo", "quem ficou
-- NAO_DEFINIDO" — e nao apenas saber que ha algo pendente.
--
-- Alguns motivos sao derivaveis por consulta (sexo IS NULL, categoria='NAO_DEFINIDO'),
-- mas tres NAO sao, porque a informacao de origem nao existe mais no schema:
--   - 'marcado Revisar no legado'        (a coluna situacao='Revisar' virou ATIVO)
--   - 'Nao membro com situacao Ativo'    (a coluna membro='Não membro' nao e persistida)
--   - 'vinculo familiar ambiguo'         (homonimos resolvidos em memoria)
-- Guardar o array resolve os 15 de uma vez e evita 15 consultas diferentes.

ALTER TABLE pessoa ADD COLUMN pendencia_motivos text[] NOT NULL DEFAULT '{}';

-- filtro por motivo: WHERE 'sem sexo' = ANY(pendencia_motivos)
CREATE INDEX pessoa_pendencia_motivos ON pessoa USING gin (pendencia_motivos);

COMMENT ON COLUMN pessoa.pendencia_motivos IS
  'Filas de revisao a que a pessoa pertence. Vazio = sem pendencia. Ver doc 17 §7.';

-- Rastreia admissao cuja forma nao existia no legado: o importador precisa gravar
-- alguma forma (a coluna e NOT NULL), entao marca aqui que o valor foi arbitrado.
-- Sem isso, 8 admissoes ficariam indistinguiveis de uma jurisdicao a pedido real.
ALTER TABLE admissao ADD COLUMN forma_arbitrada boolean NOT NULL DEFAULT false;
ALTER TABLE demissao ADD COLUMN forma_arbitrada boolean NOT NULL DEFAULT false;
