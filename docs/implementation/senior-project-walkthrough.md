# Senior project walkthrough

## 1. Visao geral do projeto

**Nome:** FiscalBridge (`fiscalbridge-rails-nfse-platform`)

**Stack:** Ruby 3.4.9, Rails 8.1, PostgreSQL 16, ERB, Turbo, Stimulus,
Importmap, Propshaft, Minitest, fixtures, Capybara/Selenium, Solid Queue,
Solid Cache, Solid Cable, Active Job, Active Storage, bcrypt, Kamal, Thruster,
Docker, RuboCop Rails Omakase, Brakeman, bundler-audit e OpenTelemetry.

**Tipo:** monolito Rails hibrido, com API B2B e backoffice web server-rendered.

**Objetivo:** demonstrar uma plataforma multi-tenant para emissao operacional de
NFS-e, com contrato API, backoffice, idempotencia, locking, fila assincroma,
evidencia fiscal, auditoria, observabilidade e plano de hardening.

O problema central e fiscal: emitir, consultar e cancelar notas de servico sem
duplicidade, sem perda de evidencia e sem vazar dados entre tenants. O dominio
principal envolve `Organization`, `Membership`, `FiscalProfile`, `Customer`,
`ServiceInvoice`, `ProviderRequest`, `AuditLog` e `OutboundEvent`.

A stack foi escolhida para seguir a direcao moderna do Rails 8: um monolito
coeso, PostgreSQL como dependencia principal, Hotwire para backoffice, Solid
Queue/Cache/Cable para reduzir infraestrutura externa e Minitest/fixtures para
testes alinhados ao framework.

O que torna o projeto senior nao e a quantidade de endpoints; e a combinacao de
decisoes: fronteiras transacionais claras, idempotencia, optimistic locking,
row locking onde importa, outbox com claim transacional, evidencia fiscal
versionavel, contratos de evento testados, paginacao limitada, seguranca por
camadas, testes de falha, CI, Docker, OpenAPI, runbooks e documentacao de
trade-offs.

## 2. Como o projeto foi iniciado

Sequencia provavel e defensavel para iniciar este repo do zero:

```bash
rails _8.1.3_ new fiscalbridge-rails-nfse-platform -d postgresql --skip-jbuilder
cd fiscalbridge-rails-nfse-platform

bundle add bcrypt
bundle add solid_queue solid_cache solid_cable
bundle add kamal --require=false
bundle add thruster --require=false
bundle add opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp
bundle add opentelemetry-instrumentation-rack
bundle add opentelemetry-instrumentation-action_pack
bundle add opentelemetry-instrumentation-active_job
bundle add opentelemetry-instrumentation-active_record
bundle add opentelemetry-instrumentation-active_support

bundle add --group development,test rubocop-rails-omakase brakeman bundler-audit simplecov
bundle add --group development,test capybara selenium-webdriver

bin/rails active_storage:install
bin/rails generate solid_queue:install
bin/rails generate solid_cache:install
bin/rails generate solid_cable:install

bin/rails db:create
bin/rails db:migrate
```

Esses comandos geram a estrutura Rails base: `app/`, `config/`, `db/`, `test/`,
`bin/`, `Gemfile`, `config/routes.rb`, ambientes, initializers, Minitest,
Propshaft, Importmap, Turbo e Stimulus. As instalacoes adicionais criam as
tabelas/configuracoes de Active Storage e Solid runtime: `config/queue.yml`,
`config/cache.yml`, `config/cable.yml`, migrations de storage/cache/queue/cable
e pontos de entrada para jobs.

Essa base foi escolhida porque o produto precisava ser uma aplicacao Rails
completa, nao uma API isolada. O backoffice e parte do valor tecnico: ele prova
auth web, sessoes, UI operacional, Capybara, Selenium e Hotwire.

## 3. Primeira estrutura criada manualmente

Depois do bootstrap, os primeiros arquivos manuais deveriam ser:

- `openapi.yaml`: contrato externo da API. Criado cedo para guiar controllers,
  testes de contrato e exemplos HTTP.
- `docs/architecture/overview.md`: visao de componentes e fluxo principal.
  Resolve o problema de explicar a arquitetura antes do codigo crescer.
- `docs/architecture/data-consistency.md`: registra idempotencia, locking,
  transacoes e outbox. Criado cedo porque consistencia e o risco principal.
- `docs/security/threat-model.md`: ameacas, mitigacoes e riscos aceitos.
  Evita tratar seguranca como checklist tardio.
- `config/authorization_matrix.yml`: RBAC declarativo por papel. Evita espalhar
  permissao em controllers.
- `app/controllers/api_controller.rb`: boundary comum para auth, rate limit,
  headers, erro JSON e helpers de idempotencia/locking.
- `app/models/current.rb`: contexto por request usando `CurrentAttributes`.
  Centraliza actor, tenant, request id e correlation id.
- `app/services/security/`: autenticacao por token, autorizacao e rate limit.
  Isola seguranca de controllers.
- `app/services/invoices/`, `app/services/customers/` e
  `app/services/fiscal_profiles/`: casos de uso transacionais do dominio e dos
  cadastros operacionais.
  Evita fat models e controllers com regra de negocio.
- `app/services/providers/`: adapter do provedor NFS-e sandbox. Preserva a
  fronteira para provedores reais.
- `app/services/events/` e `app/services/auditing/`: outbox e audit log.
  Separam evidencia operacional de mutacoes de dominio.
- `docs/adr/`: ADRs para registrar decisoes, como PostgreSQL sobre SQLite e
  monolito Rails hibrido sobre SPA/microservicos.

## 4. Ordem correta de implementacao

### Fase 1 - Setup base

Foi criada a app Rails 8, configurado PostgreSQL, gems de qualidade, Docker,
CI, RuboCop, Brakeman, bundler-audit e SimpleCov.

Arquivos tocados: `Gemfile`, `config/database.yml`, `.github/workflows/ci.yml`,
`Dockerfile`, `docker-compose.yml`, `README.md`.

Decisao: comecar com Rails completo, nao `--api`, porque o objetivo final inclui
API e backoffice. Alternativa descartada: React SPA com API separada; aumentaria
complexidade sem melhorar o fluxo operacional.

### Fase 2 - Modelagem de dominio

Foram modelados tenants, membros, perfis fiscais, clientes, notas, provider
requests, audit logs e outbox.

Arquivos: `app/models/organization.rb`, `membership.rb`, `fiscal_profile.rb`,
`customer.rb`, `service_invoice.rb`, `provider_request.rb`, `audit_log.rb`,
`outbound_event.rb`.

Decisao: tenant como `Organization` e actor API como `Membership`. Alternativa:
um modelo unico `User`; foi descartado porque API tokens B2B e usuarios humanos
tem ciclos de vida diferentes.

### Fase 3 - Banco de dados/migrations

Foram criadas constraints, indices unicos por tenant, `lock_version`, tabelas
Solid, Active Storage e sessoes.

Arquivos: `db/migrate/*`, `db/schema.rb`.

Decisao: constraints no banco para invariantes criticas. Alternativa: validar
somente no Rails; descartada porque concorrencia e imports podem furar app-only
validation.

### Fase 4 - Casos de uso/services

Foram implementados `Invoices::Create`, `Issue`, `Cancel`, `PollStatus`,
`ApplyIssueResult`, `ApplyCancellationResult`, services transacionais para
clientes/perfis fiscais, provider sandbox, auditoria e outbox.

Arquivos: `app/services/invoices/*`, `app/services/customers/*`,
`app/services/fiscal_profiles/*`, `app/services/providers/*`,
`app/services/auditing/*`, `app/services/events/*`.

Decisao: services transacionais para mutacoes. Alternativa: callbacks em models;
descartada porque esconderiam side effects como jobs, eventos e provider calls.

### Fase 5 - Controllers/API/UI

Foram criados controllers REST `v1`, contrato OpenAPI, backoffice ERB/Hotwire,
dashboard, auth web e endpoints de plataforma.

Arquivos: `app/controllers/api_controller.rb`, `app/controllers/v1/*`,
`app/controllers/backoffice/*`, `app/views/backoffice/*`,
`app/views/sessions/*`, `config/routes.rb`, `openapi.yaml`.

Decisao: API fina e UI server-rendered. Alternativa: controllers com regra de
negocio; descartada para manter testabilidade e consistencia.

### Fase 6 - Validacoes e regras de negocio

Foram adicionadas normalizacoes, RBAC, tenant scoping, idempotencia,
`If-Match`, `lock_version` em forms web, rate limit, session expiry e checksum
de evidencia fiscal.

Arquivos: models, `ApiController`, `ApplicationController`,
`Backoffice::ServiceInvoicesController`, `Security::RateLimiter`,
`config/authorization_matrix.yml`.

Decisao: combinar validacao Rails, constraints SQL e locking. Alternativa:
confiar em fila/eventual consistency; descartada porque emissao fiscal exige
consistencia forte nos comandos.

### Fase 7 - Testes

Foram criados Minitest, fixtures, integration tests, job tests, service tests e
system tests com rack driver e Selenium.

Arquivos: `test/models/*`, `test/integration/*`, `test/jobs/*`,
`test/services/*`, `test/system/*`, `test/fixtures/*`,
`test/application_system_test_case.rb`.

Decisao: Minitest/fixtures para seguir Rails. Alternativa: RSpec/FactoryBot;
descartada porque adicionaria DSL e custo sem necessidade para este repo.

### Fase 8 - Observabilidade/logs/errors

Foram adicionados JSON logs, request/correlation id, metricas Prometheus,
OpenTelemetry opt-in, `/up`, `/ready` e `/metrics`.

Arquivos: `app/controllers/platform_controller.rb`,
`app/middleware/middleware/request_context.rb`,
`app/services/observability/*`, `config/initializers/open_telemetry.rb`,
`config/initializers/logging.rb`.

Decisao: observabilidade embutida mas sem vendor lock-in. Alternativa: acoplar a
Datadog/New Relic; descartada para manter repo portavel.

### Fase 9 - Docker/infra

Foram adicionados Dockerfile, Compose, Kamal, Thruster, worker `bin/jobs`,
PostgreSQL 16, CI com lint/test/security e build de imagem.

Arquivos: `Dockerfile`, `docker-compose.yml`, `config/deploy.yml`,
`bin/jobs`, `.github/workflows/ci.yml`.

Decisao: app e jobs como processos separados no mesmo monolito. Alternativa:
Sidekiq/Redis; descartada ate haver escala comprovada.

### Fase 10 - Refino final

Foram adicionados hardenings: sessoes server-side expiraveis, cookie secure,
user-agent check, namespace distribuido de rate limit, row lock transacional em
comandos, checksums de evidencia fiscal persistidos, Selenium em CI e docs de
trade-offs.

Arquivos: `app/models/session.rb`, `app/models/service_invoice.rb`,
`app/controllers/application_controller.rb`, `app/services/security/rate_limiter.rb`,
`app/services/invoices/*`, `docs/security/production-hardening-tradeoffs.md`.

Decisao: resolver o que e honesto para o repo e documentar o que depende de
infra/provedor real. Alternativa: simular MFA, assinatura fiscal e provedor real;
descartada porque seria teatro tecnico.

## 5. Commits atomicos

### commit 01: chore: bootstrap rails 8 postgres application

Arquivos:
- `Gemfile`
- `config/database.yml`
- `config/routes.rb`
- `test/test_helper.rb`

Motivo:
- Criar a base Rails/PostgreSQL.

Decisao tecnica:
- Rails full app em vez de `--api`, antecipando backoffice Hotwire.

### commit 02: chore: add quality and security toolchain

Arquivos:
- `Gemfile`
- `config/bundler-audit.yml`
- `.github/workflows/ci.yml`

Motivo:
- Adicionar RuboCop, Brakeman, bundler-audit e SimpleCov.

Decisao tecnica:
- Gates de qualidade desde o inicio, nao no final.

### commit 03: docs: add project specification and architecture skeleton

Arquivos:
- `README.md`
- `docs/architecture/overview.md`
- `docs/architecture/data-consistency.md`
- `docs/security/threat-model.md`

Motivo:
- Registrar problema, dominio, riscos e criterios de avaliacao.

Decisao tecnica:
- Documentar intencao antes de espalhar implementacao.

### commit 04: feat: model tenant fiscal domain

Arquivos:
- `app/models/organization.rb`
- `app/models/membership.rb`
- `app/models/fiscal_profile.rb`
- `app/models/customer.rb`
- `app/models/service_invoice.rb`
- `db/migrate/20260529100000_create_fiscalbridge_core.rb`

Motivo:
- Criar entidades centrais e constraints.

Decisao tecnica:
- Multi-tenancy por `organization_id` e indices compostos.

### commit 05: feat: add token authentication and authorization matrix

Arquivos:
- `app/services/security/token_authenticator.rb`
- `app/services/security/authorizer.rb`
- `config/authorization_matrix.yml`
- `app/controllers/api_controller.rb`

Motivo:
- Proteger API B2B com bearer token e RBAC.

Decisao tecnica:
- Tokens armazenados como digest, nunca em claro.

### commit 06: feat: implement organization bootstrap and membership lifecycle

Arquivos:
- `app/controllers/v1/organizations_controller.rb`
- `app/controllers/v1/memberships_controller.rb`
- `app/services/tokens/issuer.rb`
- `test/integration/organizations_flow_test.rb`
- `test/integration/membership_token_lifecycle_test.rb`

Motivo:
- Permitir criar tenant e gerenciar atores.

Decisao tecnica:
- Token inicial exibido uma unica vez no bootstrap.

### commit 07: feat: add fiscal profiles and customers api

Arquivos:
- `app/controllers/v1/fiscal_profiles_controller.rb`
- `app/controllers/v1/customers_controller.rb`
- `test/integration/fiscal_profiles_and_customers_flow_test.rb`

Motivo:
- Registrar emissor e tomador antes da nota.

Decisao tecnica:
- Normalizacao e unicidade por tenant.

### commit 08: feat: implement idempotent service invoice creation

Arquivos:
- `app/services/invoices/create.rb`
- `app/controllers/v1/service_invoices_controller.rb`
- `test/integration/service_invoices_flow_test.rb`

Motivo:
- Criar NFS-e local com `Idempotency-Key`.

Decisao tecnica:
- Numero sequencial protegido por lock no tenant.

### commit 09: feat: add provider request tracking and sandbox adapter

Arquivos:
- `app/models/provider_request.rb`
- `app/services/providers/sandbox_nfse_client.rb`
- `app/jobs/issue_service_invoice_job.rb`
- `app/jobs/cancel_service_invoice_job.rb`

Motivo:
- Separar estado local de chamadas ao provedor.

Decisao tecnica:
- Adapter sandbox com contrato parecido com provedor real.

### commit 10: feat: add invoice issue cancel and status commands

Arquivos:
- `app/services/invoices/issue.rb`
- `app/services/invoices/cancel.rb`
- `app/services/invoices/poll_status.rb`
- `app/jobs/status_poll_service_invoice_job.rb`

Motivo:
- Controlar transicoes do ciclo de vida fiscal.

Decisao tecnica:
- Services transacionais com jobs enfileirados apos commit.

### commit 11: feat: add audit log and transactional outbox

Arquivos:
- `app/models/audit_log.rb`
- `app/models/outbound_event.rb`
- `app/services/auditing/logger.rb`
- `app/services/events/publisher.rb`
- `app/jobs/outbound_event_dispatch_job.rb`

Motivo:
- Registrar evidencia operacional e eventos.

Decisao tecnica:
- Outbox evita publicar evento para transacao que falhou.

### commit 12: feat: enforce optimistic locking and idempotency contracts

Arquivos:
- `app/controllers/api_controller.rb`
- `app/controllers/v1/service_invoices_controller.rb`
- `app/services/invoices/*`
- `test/integration/failure_scenarios_test.rb`

Motivo:
- Rejeitar comandos contra versao stale.

Decisao tecnica:
- API usa `If-Match`; web usa `lock_version` renderizado.

### commit 13: feat: add platform health metrics and telemetry

Arquivos:
- `app/controllers/platform_controller.rb`
- `app/services/observability/metrics_registry.rb`
- `config/initializers/open_telemetry.rb`
- `config/initializers/logging.rb`

Motivo:
- Tornar app operavel.

Decisao tecnica:
- Prometheus/OpenTelemetry sem vendor lock-in.

### commit 14: feat: add rails hybrid backoffice

Arquivos:
- `app/controllers/backoffice/*`
- `app/controllers/dashboard_controller.rb`
- `app/views/backoffice/*`
- `app/views/dashboard/*`
- `app/assets/stylesheets/application.css`

Motivo:
- Criar UI operacional para NFS-e.

Decisao tecnica:
- ERB/Hotwire em vez de React SPA.

### commit 15: feat: add browser auth with server-side sessions

Arquivos:
- `app/models/user.rb`
- `app/models/session.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/application_controller.rb`
- `db/migrate/20260529161000_create_hybrid_runtime_foundation.rb`
- `db/migrate/20260529162000_harden_web_sessions.rb`

Motivo:
- Autenticar operadores humanos.

Decisao tecnica:
- `User` separado de `Membership`, mas vinculado a ele.

### commit 16: feat: add active storage fiscal evidence

Arquivos:
- `db/migrate/20260529160044_create_active_storage_tables.active_storage.rb`
- `app/services/invoices/apply_issue_result.rb`
- `app/services/providers/sandbox_nfse_client.rb`
- `test/jobs/service_invoice_jobs_test.rb`

Motivo:
- Persistir XML/PDF como evidencia fiscal.

Decisao tecnica:
- Armazenar bytes retornados pelo provider, nao somente URLs.

### commit 17: fix: harden rate limits sessions and web locks

Arquivos:
- `app/services/security/rate_limiter.rb`
- `app/controllers/application_controller.rb`
- `app/services/invoices/issue.rb`
- `app/services/invoices/cancel.rb`
- `app/services/invoices/poll_status.rb`
- `test/system/backoffice_authentication_test.rb`

Motivo:
- Fechar ressalvas de producao proxima.

Decisao tecnica:
- Rate limit distribuido via cache e row lock dentro da transacao.

### commit 18: feat: persist fiscal evidence digests

Arquivos:
- `db/migrate/20260529164000_add_fiscal_evidence_digests_to_service_invoices.rb`
- `app/models/service_invoice.rb`
- `app/services/invoices/apply_issue_result.rb`
- `openapi.yaml`

Motivo:
- Tornar checksums consultaveis no agregado da nota.

Decisao tecnica:
- Constraints SQL para formato SHA-256.

### commit 19: test: add system tests and selenium ci coverage

Arquivos:
- `test/application_system_test_case.rb`
- `test/system/backoffice_authentication_test.rb`
- `test/system/backoffice_service_invoices_test.rb`
- `.github/workflows/ci.yml`
- `Dockerfile`

Motivo:
- Validar UI real com Capybara e Chrome.

Decisao tecnica:
- Rack driver local rapido, Selenium para fluxo real.

### commit 20: docs: document senior validation and production hardening

Arquivos:
- `docs/senior-technical-validation.md`
- `docs/security/production-hardening-tradeoffs.md`
- `docs/implementation/dhh-hybrid-migration-plan.md`
- `README.md`

Motivo:
- Explicar trade-offs e proximos passos de producao.

Decisao tecnica:
- Transparencia sobre o que foi implementado e o que exige contexto real.

## 6. Explicacao das decisoes tecnicas

### Arquitetura

Problema: o dominio fiscal precisa de consistencia e operacao humana.

Solucao: monolito Rails hibrido.

Senioridade: mantem transacoes locais, reduz infraestrutura e ainda suporta API
e UI. Alternativa descartada: microservicos, porque distribuiriam invariantes
fiscais cedo demais.

### Separacao de responsabilidades

Problema: controllers e models inchariam com regras fiscais.

Solucao: controllers como boundaries, models com invariantes locais e services
para casos de uso.

Senioridade: facilita testes, transacoes explicitas e revisao de side effects.
Alternativa descartada: callbacks extensivos em models.

### Modelagem do dominio

Problema: separar tenant, ator API, operador humano e nota fiscal.

Solucao: `Organization`, `Membership`, `User`, `Session`, `ServiceInvoice` e
`ProviderRequest`.

Senioridade: permite RBAC, token lifecycle e sessao web sem misturar conceitos.
Alternativa descartada: `User` unico para tudo.

### Validacao

Problema: regras precisam sobreviver concorrencia.

Solucao: validacoes Rails, constraints SQL, indices unicos, optimistic locking e
row locks.

Senioridade: protege tanto app quanto banco. Alternativa descartada: somente
validacao em formulario/controller.

### Testes

Problema: a app tem API, jobs, UI e falhas de provider.

Solucao: Minitest, fixtures, integration tests, job tests, service tests, system
tests e compliance tests.

Senioridade: cobre comportamento e riscos, nao so linhas. Alternativa
descartada: mockar tudo em unit tests isolados.

### Tratamento de erro

Problema: clientes precisam de erros previsiveis e operadores precisam de UX
segura.

Solucao: JSON envelope na API, redirects/alerts no backoffice, `Retry-After` em
rate limit e conflitos para versoes stale.

Senioridade: separa experiencia de maquina e humana. Alternativa descartada:
expor exceptions Rails para consumidores.

### Seguranca

Problema: tokens, sessoes, tenants e callbacks sao superficies criticas.

Solucao: token digest, RBAC, tenant scoping, signed session cookie, server-side
sessions, rate limit, provider token e threat model.

Senioridade: defesa em camadas. Alternativa descartada: confiar em obscuridade
ou apenas em controller filters simples.

### Performance

Problema: evitar gargalos prematuros sem ignorar hot paths.

Solucao: indices compostos, limits em listagens, includes para evitar N+1, fila
assincroma para provider e k6 benchmarks.

Senioridade: otimiza onde ha risco real. Alternativa descartada: cachear tudo
antes de medir.

### Escalabilidade

Problema: crescer sem quebrar simplicidade operacional.

Solucao: Solid Queue/Cache/Cable sobre PostgreSQL, processos separados para app
e jobs, Docker/Kamal.

Senioridade: escala verticalmente e por processos antes de adicionar Redis ou
microservicos. Alternativa descartada: Sidekiq/Redis sem necessidade medida.

### Observabilidade

Problema: falhas fiscais precisam ser rastreaveis.

Solucao: request id, correlation id, metricas, OpenTelemetry, audit log,
provider requests e outbox.

Senioridade: combina observabilidade tecnica e evidencia de negocio. Alternativa
descartada: logs soltos sem correlacao.

### Trade-offs

Problema: portfolio precisa ser executavel sem credenciais reais.

Solucao: provider sandbox com fronteira clara e docs de hardening.

Senioridade: nao finge integracao fiscal legal; mostra onde ela entraria.
Alternativa descartada: XML/certificado fake com aparencia de producao.

## 7. Walkthrough para entrevista

Sure. I’ll walk you through the project from the architecture down to the
implementation details.

FiscalBridge is a Rails 8 hybrid monolith for Brazilian NFS-e workflows. It
serves two audiences: API clients that create and operate service invoices, and
backoffice operators who need to inspect invoice lifecycle, provider evidence,
audit logs, and retry-sensitive fiscal operations.

The core architectural decision was to keep this as a monolith. The fiscal
domain has strong consistency requirements: invoice numbering, quota checks,
idempotency, provider requests, audit logs, and outbound events all benefit from
local database transactions. Splitting this into services early would make the
hard parts distributed without proving a scaling need.

The domain is tenant-scoped around `Organization`. API actors are
`Memberships`, browser users are `Users` linked to memberships, and invoices are
represented by `ServiceInvoice`. Provider interactions are tracked separately in
`ProviderRequest`, while `AuditLog` and `OutboundEvent` give us operational
evidence and an integration boundary.

The main flow starts with a tenant bootstrap that returns an owner API token
once. The client creates fiscal profiles and customers, then creates invoices
with an `Idempotency-Key`. Invoice issue, cancel, and status-poll commands are
protected by optimistic locking. The API uses `If-Match`; the backoffice submits
the rendered `lock_version`. The command services acquire a row lock inside the
transaction, validate the expected version, write provider requests, audit logs,
and outbox events, then enqueue Active Job work only after commit.

For the async side, I used Solid Queue instead of Sidekiq because Rails 8 gives
us a PostgreSQL-backed queue that fits this self-contained deployment. The
sandbox provider adapter returns realistic metadata plus XML/PDF bytes. The app
verifies SHA-256 digests, stores artifacts through Active Storage, and persists
the evidence checksums on the invoice.

Security is layered. API tokens are stored as digests, authorization is driven
by a matrix, tenant scoping is enforced at query boundaries, rate limiting uses
Rails.cache with a stable namespace, and browser authentication uses bcrypt plus
server-side expiring sessions. Sessions are protected against fixation, use
secure cookies in production, and are rejected when the stored user-agent no
longer matches.

Testing follows Rails conventions: Minitest, fixtures, integration tests for API
flows, job tests for provider outcomes, service tests for transaction
boundaries, and system tests for the backoffice. The project also has Selenium
coverage for real browser behavior, Brakeman, bundler-audit, RuboCop, OpenAPI
linting, and Docker image builds.

The main trade-off is that the provider is sandboxed. That is intentional. A
real NFS-e provider integration requires municipal credentials, certificates,
schema validation, legal storage decisions, and reconciliation processes. The
repo does not fake that; it documents the boundary and implements the adapter,
evidence, audit, and retry architecture that a real provider would plug into.

If I continued from here, I would add signed artifact downloads, richer operator
conflict resolution with Turbo Streams, MFA or SSO depending on customer profile,
provider-specific XML schema validation, reconciliation jobs, and WORM/object
lock storage if the compliance requirement demanded it.

## 8. Perguntas dificeis que podem surgir

### Why did you choose a monolith?

Because the hardest problems here are consistency problems, not independent
scaling problems. Invoice numbering, idempotency, provider evidence, audit logs
and outbox writes benefit from a single PostgreSQL transaction. I would split
only after measuring a bounded context with independent scaling needs.

### How would this scale?

First by running more Puma and Solid Queue workers, tuning PostgreSQL, adding
indexes from query plans, and moving static/artifact delivery to object storage.
If Solid Queue or Solid Cache became a bottleneck under measured contention, I
would introduce Redis or a dedicated queue. I would not start there without
evidence.

### How do you guarantee consistency?

I combine idempotency keys, database uniqueness, row locks, optimistic
`lock_version`, transactions, and after-commit job enqueueing. The command
service writes the domain state, audit evidence and outbox in one transaction
before external work happens.

### How do retries work?

Invoice creation is idempotent via `Idempotency-Key`. Provider calls are tracked
as `ProviderRequest` records with provider idempotency keys. Jobs can retry
without losing evidence, and provider timeouts leave explicit failed/pending
state instead of pretending success.

### What happens under high concurrency?

Concurrent invoice creation locks the organization row before allocating the
next invoice sequence. Concurrent issue/cancel commands check the rendered
`lock_version` and lock the invoice row inside the transaction. Stale commands
are rejected instead of silently applying to newer state.

### Why not use Sidekiq and Redis?

Rails 8 gives Solid Queue and Solid Cache on PostgreSQL, which is enough for a
self-contained SaaS-style monolith until scale proves otherwise. Adding Redis
early increases operational surface. I would move to Sidekiq/Redis if throughput
or latency data justified it.

### How did you test this?

The project has model tests, integration tests for API flows, job tests for
provider success/failure, service tests for transactions, system tests for the
backoffice, Selenium browser tests, OpenAPI contract checks, Brakeman,
bundler-audit, RuboCop and Docker build validation.

### What are the main trade-offs?

The main trade-off is realism versus runnability. The provider is sandboxed so
the repo can run locally and in CI, but the adapter boundary, provider request
evidence, Active Storage artifacts and checksum persistence are production-shaped.

### How do you handle tenant isolation?

Authentication sets `Current.organization`; controllers query through
`current_organization` rather than global ids. Database uniqueness is scoped by
organization where needed, and tests cover cross-tenant access returning not
found or forbidden.

### What would you improve before real production?

I would add MFA/SSO, session inventory and remote revoke, signed artifact
downloads, provider XML schema validation, certificate/signature verification,
reconciliation jobs, WORM storage policy for fiscal evidence, and edge-level
rate limiting.

### What makes this senior rather than CRUD?

The project treats fiscal workflows as consistency-sensitive operations. It
models idempotency, locking, async boundaries, evidence, auditability,
observability, security hardening, CI gates and documented trade-offs. CRUD is
only the surface; the important work is protecting state transitions.
