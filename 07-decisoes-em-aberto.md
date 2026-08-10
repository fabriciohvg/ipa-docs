# 07 — Decisões em aberto

Perguntas que a Constituição **não** responde e que só você (ou o Conselho/secretaria da IPA) pode responder. Cada uma vem com **minha recomendação já marcada** — se concordar, é só confirmar; se discordar, troque.

Formato: `[ ]` pendente · `[x]` decidido. Anote a resposta na linha **Decisão:**.

---

# BLOCO A — Bloqueantes (responda estas 5 primeiro)

Sem elas, o modelo não fecha. Com elas, quase todo o resto se resolve sozinho.

---

### A1 — Escopo da primeira versão

Qual conjunto entra na v1?

- [ ] **(a) Recomendado** — E1+E2+E3 do doc 06: rol de membros, oficialato/mandatos, Conselho/atas, atos pastorais, relatório e estatística anual.
- [ ] (b) Só o rol (E1). Menor risco, entrega em semanas.
- [ ] (c) Tudo (E1–E6). Alto risco de nunca terminar.

> **Por que (a)**: é exatamente o conjunto que a CI obriga o Conselho a manter e a entregar ao Presbitério (Art. 83 *j*, *l*, *m* e Art. 68). Fora disso, o sistema é conveniência; dentro, é obrigação legal cumprida.

**Decisão:** (a)

---

### A2 — Histórico retroativo

O sistema começa do zero ou digitaliza o passado?

- [ ] **(a) Recomendado** — Fotografia + histórico raso: cadastrar o rol atual completo, os ofícios/ordenações de quem está vivo e ativo (data de ordenação e mandato vigente), e daí para frente registrar tudo. Atas antigas ficam em PDF anexo, sem estruturar.
- [ ] (b) Só do zero: nada de passado. Barato, mas você perde "quem era presbítero em 2019" e a data de ordenação, que a CI trata como perpétua (Art. 25 §1º).
- [ ] (c) Digitalização completa de atas e róis antigos. Projeto de digitação de meses.

> **Por que (a)**: o Art. 25 §1º torna a data de ordenação um dado permanente e insubstituível — perder isso é irreversível. Já as deliberações antigas você consulta no livro físico quando precisar.

**Decisão:** (a)

---

### A3 — A IPA tem congregações ou pontos de pregação hoje?

- [ ] (a) Não tem nenhum → M7 sai do MVP, `Membro.congregacaoId` fica nulo sempre (mas **mantenha o campo**).
- [ ] (b) Tem congregação(ões) → M7 sobe para 🟢 e precisa entrar na E1, porque afeta o rol e a estatística desde o começo.
- [ ] (c) Tem só ponto(s) de pregação → M7 fica 🟡, mas cadastre o ponto já na E1.

> Responda pelo que **existe hoje**, não pelo que se planeja.

**Decisão:** (b)

---

### A4 — De onde vêm os dados atuais do rol?

- [ ] (a) Planilha (Excel/Google Sheets) → precisa de importador; me mande o cabeçalho das colunas.
- [ ] (b) Outro sistema de gestão de igreja → precisa de exportação; qual sistema?
- [ ] (c) Só livro físico / papel → digitação manual; o cadastro precisa ser rápido de teclar (ordem de campos importa muito).
- [ ] (d) Mistura dos anteriores.

> Isso muda o design da primeira tela construída. Com (c), a tela de cadastro precisa ser otimizada para digitação em série, não para consulta.

**Decisão:** (a). Cabeçalho das colunas (.csv): id,numero_ordem,nome,foto,endereco,complemento,bairro,cidade,cep,telefone,email,data_nascimento,naturalidade,sexo,estado_civil,conjuge,data_casamento,escolaridade,profissao,nome_pai,nome_mae,id_igreja,membro,oficial,data_batismo,pastor_batismo,igreja_batismo,data_profissao_fe,pastor_profissao_fe,igreja_profissao_fe,data_admissao,meio_admissao,data_demissao,meio_demissao,situacao,created_at,updated_at,ata,notes,profissao_informada

---

### A5 — Finanças entram no sistema?

- [ ] **(a) Recomendado** — Não na v1. Manter só `Orcamento` (para o registro exigido no Art. 9º §1º *d*) e a `DeliberacaoPatrimonial` de imóveis (Art. 9º §1º *f*). Dízimos, ofertas e contabilidade ficam fora.
- [ ] (b) Sim, completo: dízimos, ofertas, contas a pagar, prestação de contas.
- [ ] (c) Só controle de contribuições por membro.

> **Por que (a)**: finanças é o módulo de maior volume de dados, maior sensibilidade e menor relação com a Constituição. Se entrar cedo, engole o projeto. E (b) provavelmente já é atendido por um contador ou software fiscal.

**Decisão:** (a)

---

# BLOCO B — Importantes (responda depois do bloco A, antes das specs)

### B1 — Composição atual do Conselho

Quantos presbíteros em exercício? Há pastor auxiliar? Há pastor evangelista?

> Impacta o cálculo de quórum (RN-CON-02) e o regime excepcional do Art. 76 §1º, que só vale com **3 presbíteros ou menos**.

**Decisão:** 20 presbíteros em exercício; há pastores auxiliares; não há pastores evangelistas.

---

### B2 — Sociedades internas existentes

Quais funcionam na IPA hoje? (SAF, UPH, UMP, UPA, UCP, coral, ministérios…)

> Nem toda organização da igreja é "sociedade doméstica" no sentido do Art. 83 *p*/*q* — só as que têm estatuto e diretoria empossada pelo Conselho. Ministérios informais são `Designacao` (RN-CON-41), não `SociedadeInterna`.

**Decisão:** Nenhum, atualmente possui ministérios designados com liberança, mas sem estatuto, ainda que lideres desses ministérios tenham sido designados pelo Conselho com duração de 1 ano.

---

### B3 — Numeração do rol

- [ ] **(a) Recomendado** — Número sequencial permanente, nunca reutilizado, mantido mesmo após demissão.
- [ ] (b) Renumerar periodicamente.
- [ ] (c) Sem número, só nome.

> **Por que (a)**: a rastreabilidade histórica exigida pelo Art. 83 *j* fica impossível com renumeração.

**Decisão:** (a)

---

### B4 — Formulário de estatística do Presbitério

Você consegue uma cópia do **formulário de relatório/estatística** que o Presbitério de Anápolis (ou o Supremo Concílio, via Art. 143 *d*) exige da igreja?

> Isso define os campos finais de `EstatisticaAnual` (doc 04, §9). Sem ele, eu chuto os campos históricos e você retrabalha depois. **É o item de maior retorno por esforço da lista inteira.**

**Decisão:** Sim, este é o modelo [Relatório estatística](./relatorio-igreja.pdf).

---

### B5 — Visibilidade de dados sensíveis

Disciplina, aconselhamento pastoral e processos são sigilosos por natureza (as sessões do Conselho não são públicas — Art. 72).

- [ ] **(a) Recomendado** — Marcar as entidades sensíveis com flag `sigiloso` desde já e **não exibi-las** em nenhuma listagem geral, mesmo sem sistema de permissões. Quando a autenticação chegar, a regra já existe.
- [ ] (b) Deixar tudo visível por enquanto e tratar depois.

> **Por que (a)**: você adiou permissões, não confidencialidade. Marcar agora custa um booleano; retrofitar custa uma auditoria.

**Decisão:** (a)

---

### B6 — Nomes de entidades no código

- [ ] **(a) Recomendado** — Português, como no doc 04 (`Membro`, `Oficio`, `Mandato`, `Resolucao`).
- [ ] (b) Inglês (`Member`, `Office`, `Term`, `Resolution`).
- [ ] (c) Híbrido: código em inglês, domínio em português.

> **Por que (a)**: `presbitero_regente`, `plena_comunhao` e `ad_referendum` não têm tradução que sobreviva à conversa com o secretário do Conselho. Custo de escrever `Oficio` sem acento é zero.

**Decisão:** (a)

---

### B7 — Como a secretaria trabalha hoje

Quem vai operar o sistema? Uma secretária? O secretário do Conselho (presbítero voluntário)? O pastor?

> Muda tudo em UX. Voluntário que usa 1×/mês precisa de assistentes passo a passo; secretária diária precisa de telas densas e atalhos de teclado.

**Decisão:** Secretária, secretário do Conselho, pastores, etc.

---

# BLOCO C — Adiadas conscientemente (não decida agora)

Registre aqui o que aparecer, para não ocupar espaço na sua cabeça.

### C1 — Autenticação e permissões
Fora de escopo por decisão sua. O modelo já está preparado: papéis (`Oficio`, `CargoDaMesa`, `RelacaoPastoral`) mapeiam direto para perfis de acesso quando chegar a hora.

### C2 — Código de Disciplina
Não está neste repositório. O módulo M9 fica em esqueleto até você conseguir o texto. **Se conseguir o PDF, adicione ao projeto** — eu extraio as regras no mesmo formato do doc 03.

### C3 — Multi-igreja
Fora de escopo. Mitigado: `Igreja` é tabela (não constante) e nada no modelo assume tenant único de forma irreversível.

### C4 — Portal do membro / app
Membros consultarem os próprios dados, atualizarem endereço, verem carteirinha. Depende de C1.

### C5 — Votação eletrônica em assembleia
A CI não regula sigilo de voto em igreja local. Registrar apuração já basta (doc 06, M4).

### C6 — Integração com o Presbitério
Hoje o intercâmbio é papel. Se um dia houver sistema presbiterial, o pacote do UC-M8-04 vira API.

### C7 — Liturgia e agenda de cultos
Art. 83 *s* ("velar pela regularidade dos serviços religiosos") permitiria um módulo de escalas e agenda de cultos. É conveniência, não obrigação constitucional.

### C8 — Stack técnica
Deliberadamente não decidida ainda. Só faz sentido escolher depois das specs (FASE 5 do roadmap) — nenhuma decisão até aqui depende de linguagem ou framework.

---

## Como me devolver isto

Edite este arquivo preenchendo as linhas **Decisão:** e me avise. Eu então:

1. Atualizo o doc 04 para v2 com os ajustes.
2. Gero o schema de banco (`10-schema.md`).
3. Escrevo a spec do M1 (`08-spec-m1-rol-de-membros.md`).

Se travar, responda **só o A1** e mande. Dá para seguir com isso.
