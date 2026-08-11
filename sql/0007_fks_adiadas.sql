-- 0007 — FKs que dependiam de resolucao/pessoa · Doc 10 §5 (fim)

ALTER TABLE congregacao   ADD CONSTRAINT congregacao_resolucao_fk
  FOREIGN KEY (resolucao_id)   REFERENCES resolucao(id);
ALTER TABLE congregacao   ADD CONSTRAINT congregacao_responsavel_fk
  FOREIGN KEY (responsavel_id) REFERENCES pessoa(id);
ALTER TABLE admissao      ADD CONSTRAINT admissao_resolucao_fk
  FOREIGN KEY (resolucao_id)   REFERENCES resolucao(id);
ALTER TABLE demissao      ADD CONSTRAINT demissao_resolucao_fk
  FOREIGN KEY (resolucao_id)   REFERENCES resolucao(id);
ALTER TABLE ordenacao     ADD CONSTRAINT ordenacao_resolucao_fk
  FOREIGN KEY (resolucao_id)   REFERENCES resolucao(id);
ALTER TABLE cargo_da_mesa ADD CONSTRAINT cargo_da_mesa_resolucao_fk
  FOREIGN KEY (resolucao_id)   REFERENCES resolucao(id);
