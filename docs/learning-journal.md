# Learning Journal

Este journal documenta a história do repositório até o commit `b2ae720`, que é o
`HEAD` gravado no momento desta edição.

## Como este journal usa evidências

- Base primária:
  `git log`, `README.md`, `openapi.yaml`, `docs/architecture/overview.md`,
  `docs/implementation/senior-project-walkthrough.md`, controllers, services e
  testes do repositório.

- Quando este texto diz que uma mudança "resolveu" ou "hardened" alguma coisa:
  a afirmação se apoia na mensagem do commit, nos arquivos tocados e nos testes
  ou docs adicionados no mesmo trecho do histórico.

- Quando o histórico não prova a ordem interna de red/green/refactor:
  o texto descreve só o que o diff permite afirmar.

- Escopo:
  commits já gravados até `b2ae720`. Se novas mudanças forem adicionadas depois
  desta edição, o journal precisa ser avançado junto.

## O que o histórico não prova

- O histórico não prova integração com provedores municipais reais.
  O que ele prova é um adapter sandbox tratado com seriedade suficiente para
  ensinar boundaries, retries, evidência e callbacks.

- O histórico não prova incidentes reais de produção.
  Ele mostra riscos modelados, contracts, testes e endurecimentos locais.

- O histórico não prova o debate privado de alternativas.
  Quando uma alternativa rejeitada não aparece em commit, README, ADR ou doc
  explícita, este journal trata a comparação como inferência comparativa.

## 1. Objetivo do projeto

FiscalBridge existe para ensinar como modelar emissão de NFS-e em um monólito
Rails híbrido sem reduzir o problema a CRUD de fatura. O repositório quer deixar
explícito que o trabalho real está em:

- idempotência de comandos fiscais;
- transições de estado auditáveis;
- evidência de provedor;
- separação entre API de máquina e backoffice humano;
- eventos assíncronos que não mentem sobre o que foi confirmado localmente.

Ao terminar este journal, o leitor deve conseguir:

- seguir um invoice request do controller até os services de emissão, callback,
  auditoria e outbox;
- explicar por que o backoffice foi mantido no mesmo deployable;
- apontar quais testes dão confiança para isolamento por tenant, contratos e
  retries;
- descrever os trade-offs entre um adapter sandbox honesto e uma integração real.

## 2. Como ler o repositório primeiro, em ordem de aprendizado

1. Comece por `README.md`.
   Ele fixa o problema do produto e os artefatos que importam: provider
   evidence, Active Storage fiscal artifacts, audit log e outbox.

2. Leia `docs/architecture/overview.md`.
   O mapa mental do produto vem antes do detalhe dos services.

3. Leia `config/routes.rb` e `openapi.yaml`.
   Aqui aparecem os dois eixos do produto: `/v1` para máquinas e a superfície
   de backoffice para humanos.

4. Leia `app/controllers/api_controller.rb` e depois
   `app/controllers/v1/service_invoices_controller.rb`.
   Isso mostra autenticação, envelope e a borda HTTP do fluxo mais importante.

5. Siga o caminho principal de escrita:
   `app/services/invoices/create.rb`
   `app/services/invoices/issue.rb`
   `app/services/invoices/apply_issue_result.rb`
   `app/services/invoices/cancel.rb`
   `app/services/invoices/apply_cancellation_result.rb`

6. Só então leia os eventos:
   `app/services/events/publisher.rb`
   `app/services/events/delivery.rb`
   `app/jobs/outbound_event_dispatch_job.rb`

7. Depois leia a camada humana:
   `app/controllers/backoffice/service_invoices_controller.rb`
   `app/controllers/sessions_controller.rb`
   `app/controllers/dashboard_controller.rb`

8. Feche com os testes:
   `test/integration/service_invoices_flow_test.rb`
   `test/integration/authorization_and_isolation_test.rb`
   `test/services/provider_adapter_contract_test.rb`
   `test/services/events_publisher_contract_test.rb`
   `test/system/backoffice_service_invoices_test.rb`

### O que ignorar na primeira passada

- Não comece por `docs/implementation/senior-project-walkthrough.md`.
  Ele é ótimo para revisão e entrevista, não para a primeira leitura.

- Não trate `provider_requests` e callbacks como detalhe tardio.
  Em produto fiscal, isso é parte do domínio principal.

- Não comece por métricas ou benchmark.
  Primeiro entenda por que o comando fiscal e a evidência existem.

## 3. História cronológica da implementação

### Fase 1: fundação, slice fiscal e primeiros contratos (`4d1c3c6` a `080313e`, 2026-05-29)

- O projeto começou por baseline documental e scaffold Rails.
- O primeiro corte útil veio rápido: workflows centrais de NFS-e, API e testes de
  compliance já no mesmo dia.
- Isso sugere uma escolha de escopo correta: o repo queria ensinar o fluxo fiscal
  inteiro, não crescer como app genérico antes de tocar o domínio.
- Base usada:
  commits `4d1c3c6`, `adf2f80`, `88c81d1`, `080313e`; `README.md`,
  `openapi.yaml`, `app/services/invoices/*`,
  `test/integration/service_invoices_flow_test.rb`.

### Fase 2: evidência de produto, CI e backoffice híbrido (`fc1e82c` a `3b71221`, 2026-05-29 a 2026-05-30)

- A documentação deixou de ser só setup e passou a explicar produto, risco
  fiscal e superfície operacional.
- Em seguida entrou o backoffice híbrido. Essa foi a principal virada de
  arquitetura: o repositório deixou de ser só API para demonstrar também a
  operação humana do ciclo fiscal.
- Base usada:
  commits `fc1e82c`, `f35adb8`, `776ed9a`, `3b71221`;
  `docs/architecture/overview.md`,
  `app/controllers/backoffice/*`,
  `app/controllers/sessions_controller.rb`,
  `test/system/backoffice_service_invoices_test.rb`.

### Fase 3: endurecimento de confiabilidade e contratos públicos (`26d408c` a `b2ae720`, 2026-05-31)

- Esta fase é quase toda sobre correção de limites do produto, não sobre nova
  feature vistosa.
- `26d408c` e `52472eb` apertam confiabilidade de workflow e consistência do
  registry.
- `a5f2b39` e `fd20dad` puxam a trilha assíncrona para o mesmo nível de rigor do
  fluxo síncrono, com dispatch e payload contracts.
- `589332b`, `60e0b1d` e `b2ae720` mostram o passo final de uma mente mais
  production-shaped: estabilizar rate limiting, conter memória de histogramas e
  validar respostas reais contra schema.
- Base usada:
  commits `26d408c`, `52472eb`, `a5f2b39`, `fd20dad`, `9037f84`, `589332b`,
  `60e0b1d`, `b2ae720`; `test/integration/openapi_response_contract_test.rb`,
  `test/integration/rate_limiting_and_metrics_test.rb`,
  `test/services/events_publisher_contract_test.rb`.

## Features importantes como unidades completas

### Emissão, cancelamento e polling com evidência de provedor

- Problema que resolve:
  um invoice fiscal não pode ser modelado como simples mudança local de status.
  O produto precisa guardar pedido, retorno, erro, retry e estado reconciliável.

- Commits principais:
  `88c81d1`, `26d408c`, `a5f2b39`, `fd20dad`.

- Arquivos principais:
  `app/services/invoices/create.rb`,
  `app/services/invoices/issue.rb`,
  `app/services/invoices/poll_status.rb`,
  `app/services/invoices/apply_issue_result.rb`,
  `app/services/invoices/apply_cancellation_result.rb`,
  `app/models/provider_request.rb`.

- Por que a solução final tomou essa forma:
  o produto preferiu deixar o adapter sandbox pequeno, mas cercado por services
  e testes que explicitam o ciclo fiscal em vez de esconder o problema dentro do
  provider client.

- Alternativa plausível:
  fazer o controller orquestrar parte do fluxo e deixar o adapter absorver
  estados intermediários. O repositório foi na direção oposta.

- Testes que protegem a feature:
  `test/integration/service_invoices_flow_test.rb`,
  `test/jobs/service_invoice_jobs_test.rb`,
  `test/services/provider_adapter_contract_test.rb`.

### Monólito híbrido com API e backoffice

- Problema que resolve:
  máquinas precisam de um contrato estável; humanos precisam de sessão,
  dashboard, inspeção de artefatos e retries operacionais.

- Commits principais:
  `3b71221`, `589332b`.

- Arquivos principais:
  `app/controllers/backoffice/*`,
  `app/controllers/sessions_controller.rb`,
  `app/controllers/dashboard_controller.rb`,
  `test/system/backoffice_authentication_test.rb`,
  `test/system/backoffice_service_invoices_test.rb`.

- Prós:
  mantém a operação perto do domínio e do mesmo banco.

- Contras:
  aumenta a superfície do deployable e puxa system tests para o centro da
  confiabilidade humana.

### Outbox, contracts e payload schema

- Problema que resolve:
  side effects externos não podem depender de interpretação vaga do payload.

- Commits principais:
  `a5f2b39`, `fd20dad`, `b2ae720`.

- Arquivos principais:
  `app/services/events/publisher.rb`,
  `app/services/events/delivery.rb`,
  `test/services/events_publisher_contract_test.rb`,
  `test/integration/openapi_response_contract_test.rb`.

- O que isso ensina:
  “evento publicado” e “resposta pública” são contratos diferentes, mas ambos
  merecem teste de forma explícita.

## 4. Decisão por decisão

- Provider sandbox em vez de integração municipal real:
  escolhido para manter o repositório rodável e didático.
  Prós: reproduz boundaries e falhas locais.
  Contras: não prova certificação real.

- Monólito híbrido em vez de API pura:
  escolhido porque a operação fiscal humana é parte do domínio.
  Prós: menos salto mental entre máquina e operação.
  Contras: mais superfície de autenticação e UI.

- Contracts executáveis para eventos e OpenAPI:
  escolhidos para reduzir deriva documental.
  Prós: o repo passa a dizer menos “confie em mim”.
  Contras: o custo de manutenção de schema sobe.

## 5. Erros, correções e endurecimentos

- O histórico mostra que confiabilidade do workflow não ficou certa na primeira
  passagem; ela foi endurecida em `26d408c`.
- A consistência do registry precisou de outra passada em `52472eb`.
- Dispatch de eventos e payload contracts também vieram depois do core inicial,
  em `a5f2b39` e `fd20dad`.
- A fase final apertou pontos clássicos de specialist:
  rate limiting de backoffice, bounded metrics memory e schema validation real.

## 6. Como os testes foram usados

- Primeiro o projeto provou o fluxo fiscal central.
- Depois passou a cercar as bordas que um repositório menos maduro costuma
  deixar vagas: contracts de provider, contracts de eventos, rate limiting,
  OpenAPI response schema e system flow de backoffice.

## 7. Quais testes protegem quais decisões

- Isolamento e auth:
  `test/integration/authorization_and_isolation_test.rb`,
  `test/services/security_authorizer_test.rb`.

- Fluxo fiscal:
  `test/integration/service_invoices_flow_test.rb`,
  `test/jobs/service_invoice_jobs_test.rb`.

- Contratos públicos e assíncronos:
  `test/integration/openapi_response_contract_test.rb`,
  `test/services/events_publisher_contract_test.rb`,
  `test/services/provider_adapter_contract_test.rb`.

- Operação humana:
  `test/system/backoffice_authentication_test.rb`,
  `test/system/backoffice_service_invoices_test.rb`.

## 8. Timeline dos commits atômicos

| Commit | Problema de aprendizado | Mudança principal | Sinal de verificação |
| --- | --- | --- | --- |
| `4d1c3c6` | O que este repo quer ensinar? | baseline documental | docs iniciais |
| `adf2f80` | Como preparar a base Rails? | scaffold do runtime | build local |
| `88c81d1` | Como modelar o ciclo fiscal? | workflows centrais de NFS-e | core implementado |
| `080313e` | Como provar o slice fiscal? | testes de workflow e compliance | testes adicionados |
| `fc1e82c` | Como explicar o produto? | evidência de produto | docs |
| `f35adb8` | Como verificar continuamente? | automação de CI e benchmark | workflow/commands |
| `776ed9a` | Como tornar o reset confiável? | estabilidade do reset de banco | CI |
| `3b71221` | Como operar o fluxo? | backoffice híbrido | system tests |
| `26d408c` | Onde o workflow ainda quebrava? | hardening de confiabilidade | testes/integração |
| `52472eb` | Como evitar drift no registry? | consistência de API do registry | integração |
| `a5f2b39` | Como endurecer side effects? | dispatch de eventos mais seguro | tests/services |
| `fd20dad` | Como impedir drift de payload? | contracts de eventos fiscais | contract tests |
| `9037f84` | Como explicar a barra de qualidade? | docs de quality hardening | docs |
| `589332b` | Como estabilizar o backoffice? | spec de rate limiting | test/integration |
| `60e0b1d` | Como conter custo de métricas? | histograma bounded | metrics test/readiness |
| `b2ae720` | Como provar respostas reais? | schema validation de OpenAPI | openapi response tests |

## 8A. Perguntas de recuperação

- Qual é a diferença entre “invoice state local” e “provider evidence” neste repo?
- Que teste você abriria primeiro para validar um refactor do fluxo de emissão?
- Por que o backoffice está no mesmo monólito em vez de ser dashboard separado?

## 9. Comandos de terminal que um specialist usaria aqui

Para reconstruir o raciocínio hoje:

```bash
git log --oneline --reverse
git show --stat 3b71221
bin/rails test test/integration/service_invoices_flow_test.rb
bin/rails test test/services/provider_adapter_contract_test.rb
bin/rails test test/services/events_publisher_contract_test.rb
bin/rails test:system
bin/rubocop
bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bundle exec bundler-audit check --update
```

## 10. Como adicionar a próxima feature sem quebrar a aula

Se a próxima feature for, por exemplo, um novo provider adapter:

1. fixe o contrato público em `openapi.yaml` ou docs de evento;
2. crie o service boundary antes de espalhar lógica no controller;
3. escreva ou ajuste contract tests do provider;
4. só depois exponha a ação no backoffice, se ela também for operacional.

## 11. Limites de produção deixados de propósito

- não prova integração municipal real;
- não prova volume alto com artefatos fiscais pesados;
- não prova governança regulatória fora do escopo do sandbox;
- não tenta ensinar billing ou accounting completo além do fluxo fiscal estudado.
