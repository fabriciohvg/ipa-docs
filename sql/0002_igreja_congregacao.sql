-- 0002 — igreja (singleton) e congregacoes · Doc 10 §1

CREATE TABLE igreja (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome                text NOT NULL,
  cnpj                text,
  data_organizacao    date,
  presbiterio_nome    text,
  presbiterio_sigla   text,
  sinodo_nome         text,
  sinodo_sigla        text,
  logradouro          text,
  numero_endereco     text,
  complemento         text,
  bairro              text,
  cidade              text,
  uf                  char(2),
  cep                 text,
  caixa_postal        text,
  caixa_postal_cep    text,
  email               citext,
  site                text,
  estatuto_url        text,
  estatuto_aprovado_em date,
  criado_em           timestamptz NOT NULL DEFAULT now(),
  atualizado_em       timestamptz NOT NULL DEFAULT now()
);

-- singleton: no maximo uma igreja (RN-IGR-01, sistema mono-igreja)
CREATE UNIQUE INDEX igreja_unica ON igreja ((true));

CREATE TRIGGER igreja_atualizado BEFORE UPDATE ON igreja
  FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();

CREATE TABLE igreja_telefone (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  igreja_id uuid NOT NULL REFERENCES igreja(id) ON DELETE CASCADE,
  numero    text NOT NULL,
  rotulo    text,
  criado_em timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE congregacao (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome                 text NOT NULL,
  tipo                 tipo_congregacao NOT NULL,
  logradouro           text,
  numero_endereco      text,
  bairro               text,
  cidade               text,
  uf                   char(2),
  cep                  text,
  data_estabelecimento date,
  resolucao_id         uuid,   -- FK em 0007 (resolucao ainda nao existe)
  responsavel_id       uuid,   -- FK em 0007 (pessoa criada em 0003)
  status               text NOT NULL DEFAULT 'ATIVA',
  id_legado            text,
  criado_em            timestamptz NOT NULL DEFAULT now(),
  atualizado_em        timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER congregacao_atualizado BEFORE UPDATE ON congregacao
  FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();
