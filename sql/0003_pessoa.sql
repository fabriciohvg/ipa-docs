-- 0003 — pessoas, contatos e vinculos familiares · Doc 10 §2

CREATE TABLE pessoa (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome_completo       text NOT NULL,
  data_nascimento     date,
  sexo                sexo,          -- NULLABLE: falta em 860 registros reais (doc 12 §5.2)
  sexo_inferido       boolean NOT NULL DEFAULT false,
  naturalidade        text,
  estado_civil        text,
  civilmente_capaz    boolean NOT NULL DEFAULT true,
  cpf                 text,
  rg                  text,
  logradouro          text,
  numero_endereco     text,
  complemento         text,
  bairro              text,
  cidade              text,
  uf                  char(2),
  cep                 text,
  profissao           text,
  escolaridade        text,
  nome_pai_texto      text,          -- fallback quando o casamento por nome falha
  nome_mae_texto      text,
  nome_conjuge_texto  text,
  data_casamento      date,
  data_falecimento    date,
  foto_url            text,
  observacoes         text,
  pendencia_revisao   boolean NOT NULL DEFAULT false,
  id_legado           text UNIQUE,
  criado_em           timestamptz NOT NULL DEFAULT now(),
  atualizado_em       timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER pessoa_atualizado BEFORE UPDATE ON pessoa
  FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();

-- busca por nome parcial, sem acento (doc 16 §3)
CREATE INDEX pessoa_nome_busca ON pessoa
  USING gin (f_unaccent(lower(nome_completo)) gin_trgm_ops);
CREATE INDEX pessoa_nascimento ON pessoa (data_nascimento);
CREATE INDEX pessoa_pendencia   ON pessoa (nome_completo) WHERE pendencia_revisao;

CREATE TABLE pessoa_contato (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id uuid NOT NULL REFERENCES pessoa(id) ON DELETE CASCADE,
  tipo      text NOT NULL,   -- TELEFONE | CELULAR | EMAIL | WHATSAPP
  valor     text NOT NULL,
  principal boolean NOT NULL DEFAULT false,
  criado_em timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX pessoa_contato_pessoa ON pessoa_contato (pessoa_id);

CREATE TABLE vinculo_familiar (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pessoa_id        uuid NOT NULL REFERENCES pessoa(id) ON DELETE CASCADE,
  relacionado_id   uuid NOT NULL REFERENCES pessoa(id) ON DELETE CASCADE,
  tipo             text NOT NULL,  -- PAI | MAE | RESPONSAVEL_LEGAL | CONJUGE | FILHO
  menor_sob_guarda boolean NOT NULL DEFAULT false,
  vigente_de       date,
  vigente_ate      date,
  criado_em        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT vinculo_nao_reflexivo CHECK (pessoa_id <> relacionado_id),
  CONSTRAINT vinculo_unico UNIQUE (pessoa_id, relacionado_id, tipo)
);
CREATE INDEX vinculo_relacionado ON vinculo_familiar (relacionado_id);
