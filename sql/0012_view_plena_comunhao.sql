-- 0012 — plena comunhao (RN-MEM-06) · Doc 10 §3
--
-- Nunca e coluna: e estado derivado. Versao atual sem disciplina (modulo M9 ainda
-- nao existe, decisao C2). Quando processo_disciplinar/medida_disciplinar entrarem,
-- substituir por CREATE OR REPLACE VIEW acrescentando o NOT EXISTS.

CREATE VIEW membro_em_plena_comunhao AS
SELECT m.id AS membro_id, m.pessoa_id
FROM membro m
WHERE m.categoria = 'COMUNGANTE'   -- NAO_DEFINIDO nunca entra
  AND m.situacao  = 'ATIVO';

-- gera o proximo numero de rol no padrao AAAA+4 digitos (P19a).
-- ATENCAO: sob concorrencia, use dentro de transacao com retry na UNIQUE de numero_rol.
CREATE FUNCTION proximo_numero_rol(p_ano integer DEFAULT extract(year from current_date)::int)
RETURNS text LANGUAGE sql AS $$
  SELECT p_ano::text || lpad((
    COALESCE(MAX(substring(numero_rol from 5 for 4)::int), 0) + 1)::text, 4, '0')
  FROM membro
  WHERE numero_rol ~ '^[0-9]{8}$' AND substring(numero_rol from 1 for 4) = p_ano::text;
$$;
