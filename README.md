# FiscalBridge

FiscalBridge is a multi-tenant hybrid Rails monolith for Brazilian NFS-e issuance workflows. It keeps an API-first integration contract while adding a server-rendered backoffice for fiscal operations, provider evidence, audit review, and safe retries.

## 1. What is this product?

FiscalBridge is an NFS-e platform with API-token authentication, browser session authentication, tenant isolation, provider request tracking, asynchronous issuance/cancellation jobs, Active Storage evidence, and append-only audit logs. It intentionally uses a sandbox provider adapter so the repository is runnable locally while still exposing the same boundaries a production fiscal integration would need.

## 2. Problem it solves

Fiscal operations are consistency-sensitive: duplicate issue requests can create tax exposure, provider timeouts must be safely replayable, and invoices need evidence trails across local state, provider protocol, XML/PDF artifacts, and cancellation requests. FiscalBridge turns those concerns into explicit domain services, tests, OpenAPI contracts, and runbooks.

## 3. Target users

- SaaS companies that issue service invoices after subscription or usage events
- Marketplaces and fintech platforms that need tenant-scoped fiscal operations
- Operations teams that need auditable NFS-e status, provider protocol, and retry evidence
- Engineering reviewers assessing senior Rails backend execution

## 4. Main features

- tenant bootstrap with owner API token returned once
- role-based membership management with token rotation and revocation
- fiscal profile registry for issuer legal identity and municipal configuration
- customer registry with CPF/CNPJ normalization
- idempotent service invoice creation via `Idempotency-Key`
- bounded cursor pagination on registry and invoice list endpoints
- optimistic-lock protected issue, cancel, and provider status polling commands
- sandbox NFS-e provider adapter with success, rejection, timeout, and cancellation paths
- provider callback endpoint protected by `X-Provider-Token`, with fail-closed production configuration
- ERB/Hotwire backoffice for dashboard, invoice lifecycle inspection, provider evidence, memberships, fiscal profiles, and customers
- Rails-style web auth with `User`, `Session`, signed cookies, `bcrypt`, and tenant role reuse through `Membership`
- Solid Queue, Solid Cache, and Solid Cable on PostgreSQL instead of Redis/Sidekiq
- Active Storage attachments for XML/PDF fiscal artifacts
- structured audit log, outbox events, Prometheus metrics, health/readiness endpoints, and OpenTelemetry hooks

## 5. Architecture overview

The app is a Rails hybrid monolith. API controllers remain thin request/authorization boundaries for machine clients. Web controllers use ERB/Hotwire and session auth for human operations. Domain services own transactions and state changes. ActiveJob workers run through Solid Queue and call provider adapters after commit. Provider evidence is stored in `provider_requests`, fiscal artifacts in Active Storage, domain events in `outbound_events`, and operator/provider actions in `audit_logs`.

The formal architecture, runtime topology, and architectural invariants are documented in [`docs/architecture/overview.md`](docs/architecture/overview.md).

```text
Client API -> ApiController -> Domain services -> PostgreSQL
Operator UI -> ERB/Hotwire -> Domain services -> Active Storage
                                      |             -> audit_logs
                                      |             -> outbound_events
                                      +-> Solid Queue -> sandbox NFS-e adapter -> provider_requests
Provider webhook -> callback controller -> Providers::ApplyCallback
```

## 6. Tech stack

- Ruby 3.4.9 and Rails 8.1 hybrid mode
- PostgreSQL 16 as the runtime database
- ERB, Turbo, Stimulus, Importmap, and Propshaft
- Solid Queue, Solid Cache, Solid Cable, Active Job, Active Storage, Action Mailer
- Rails-style auth with `bcrypt`, `CurrentAttributes`, and signed sessions
- Minitest, fixtures, system tests with Capybara, SimpleCov, RuboCop Rails Omakase, Brakeman, bundler-audit
- Kamal, Thruster, Docker, Docker Compose, Railway demo deployment, and k6 benchmark scenarios
- OpenTelemetry instrumentation, structured JSON logs, Prometheus text metrics

## 7. Domain model

| Model | Purpose | Key constraints |
| --- | --- | --- |
| `Organization` | Tenant, fiscal owner, quota and sequence boundary | unique `slug`, invoice quota, invoice sequence |
| `Membership` | API actor with role and token lifecycle | token digest uniqueness, token expiry/revocation |
| `User` | Human backoffice identity linked to a membership | unique email, one user per membership, password digest |
| `Session` | Signed-cookie browser session backing record | belongs to user, IP/user-agent evidence |
| `FiscalProfile` | NFS-e issuer identity and municipal configuration | tenant-scoped CNPJ uniqueness |
| `Customer` | Service taker identity | tenant-scoped document uniqueness |
| `ServiceInvoice` | Local NFS-e lifecycle | tenant-scoped `public_id`, tenant-scoped `idempotency_key`, optimistic `lock_version` |
| `ProviderRequest` | Provider call/callback evidence | globally unique provider idempotency key |
| `AuditLog` | Append-only operational evidence | polymorphic auditable resource |
| `OutboundEvent` | Transactional outbox event | retry state and dead-letter-style failed status |

## 8. API documentation

The canonical HTTP contract is [`openapi.yaml`](openapi.yaml). Examples and error payloads live in [`docs/api/http-examples.md`](docs/api/http-examples.md) and [`docs/api/error-format.md`](docs/api/error-format.md).

Primary endpoints:

- `POST /v1/organizations`
- `GET /v1/organization`
- `GET|POST /v1/memberships`
- `PATCH /v1/memberships/:id/rotate_token`
- `PATCH /v1/memberships/:id/revoke_token`
- `GET|POST|PATCH /v1/fiscal_profiles`
- `GET|POST|PATCH /v1/customers`
- `GET|POST /v1/service_invoices`
- `POST /v1/service_invoices/:id/issue`
- `POST /v1/service_invoices/:id/cancel`
- `POST /v1/service_invoices/:id/poll_status`
- `POST /v1/provider_callbacks/nfse`

## 9. Async or event architecture

Mutating services write the database record, audit log, and outbox event in one transaction. Jobs are enqueued only after commit. Issuance, cancellation, and status polling use ActiveJob workers backed by Solid Queue and the `Providers::SandboxNfseClient` adapter. Provider callbacks are idempotent through the callback id stored as a provider request idempotency key. Outbox dispatch claims events inside a database transaction, skips active in-flight work, recovers stale `processing` events through the recurring sweeper, and uses a local log delivery adapter by default so the repo remains self-contained without silently pretending to call an external webhook.

Supported domain events include `service_invoice.created`, `service_invoice.issue_requested`, `service_invoice.issued`, `service_invoice.rejected`, `service_invoice.cancel_requested`, `service_invoice.cancelled`, `service_invoice.cancellation_failed`, `service_invoice.status_polled`, and `service_invoice.provider_timeout`. Versioning and compatibility rules are documented in [docs/events/README.md](docs/events/README.md).

## 10. Database design

PostgreSQL is required because invoice numbering and quota enforcement rely on row locks around the organization record. Service invoices expose `public_id` values such as `NFS-000001`, allocated inside the invoice creation transaction. `lock_version` protects issue/cancel/status commands from stale clients through `ETag` and `If-Match`. Solid Queue, Solid Cache, Solid Cable, web sessions, and Active Storage metadata also live in PostgreSQL.

## 11. Testing strategy

The suite uses Minitest and covers:

- model validations and normalization
- organization bootstrap and membership token lifecycle
- fiscal profile, customer, and invoice API flows
- RBAC and tenant isolation
- idempotent invoice creation
- asynchronous issue/cancel jobs
- fixture-backed backoffice authentication and service invoice system flows, with Selenium/Chrome enabled in CI
- expired sessions, login rate limiting, and stale backoffice command protection
- provider timeout and duplicate callback failure scenarios
- outbox retry/failure behavior
- transaction rollback boundaries
- OpenAPI required response fields checked against real API responses
- repository compliance against this initiative's general spec

## 12. Performance benchmarks

The `benchmarks/` directory contains k6 smoke, load, stress, and spike scenarios. The scripts exercise tenant bootstrap, authenticated organization reads, customer/profile setup, invoice creation, and invoice reads. The runner starts the managed benchmark server on an isolated port by default (`BENCHMARK_PORT=3204`) and measured local results are documented in [`docs/benchmarks/local-baseline.md`](docs/benchmarks/local-baseline.md).

## 13. Observability

- JSON logs include severity, timestamp, request id, and correlation id.
- `X-Request-ID`, `X-Correlation-ID`, and `X-Trace-ID` are propagated on responses where available.
- `/up` exposes liveness.
- `/ready` checks database readiness and job adapter state.
- `/metrics` exports Prometheus-compatible HTTP and outbox counters/histograms, with request durations stored as bounded bucket counters rather than retained raw samples.
- OpenTelemetry export is opt-in through `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`, or `OTEL_TRACES_EXPORTER`.
- [`docs/diagrams/grafana-fiscalbridge-overview.json`](docs/diagrams/grafana-fiscalbridge-overview.json) defines a Grafana dashboard.

## 14. Security considerations

- bearer API tokens are stored only as SHA-256 digests
- browser users authenticate through `bcrypt` password digests and signed session cookies backed by expiring server-side `sessions`
- tokens expire and can be rotated or revoked
- RBAC is configured in [`config/authorization_matrix.yml`](config/authorization_matrix.yml)
- tenant isolation is enforced through `current_organization` scoped lookups
- rate limiting is enforced through `Rails.cache` before authentication to protect API token, IP, and login paths
- backoffice issue/cancel/status commands carry the rendered `lock_version` to reject stale operator pages
- provider XML/PDF artifacts are attached from provider-returned bytes with SHA-256 verification metadata
- provider callbacks require `X-Provider-Token`
- secrets are read from environment variables, not source-controlled credentials
- threat model and authorization matrix are documented under [`docs/security/`](docs/security)
- fiscal-specific threats are documented in [`docs/security/fiscal-threat-model.md`](docs/security/fiscal-threat-model.md)
- provider adapter boundaries and fiscal event contracts are documented in [`docs/adr/005-provider-ports-and-adapters.md`](docs/adr/005-provider-ports-and-adapters.md) and [`docs/events/README.md`](docs/events/README.md)
- deployment readiness is documented in [`docs/architecture/deployment-readiness.md`](docs/architecture/deployment-readiness.md)
- senior hardening trade-offs are documented in [`docs/security/production-hardening-tradeoffs.md`](docs/security/production-hardening-tradeoffs.md)
- interview-style technical walkthrough is documented in [`docs/implementation/senior-project-walkthrough.md`](docs/implementation/senior-project-walkthrough.md)

## 15. Trade-offs and decisions

- Sandbox provider instead of real municipality adapters: keeps the repo runnable and deterministic while preserving adapter boundaries.
- Monolith over microservices: the fiscal domain benefits from transaction boundaries and one deployable unit at this stage.
- ERB/Hotwire over React SPA: operator workflows are mostly forms, tables, filters, and state transitions.
- Solid Queue/Cache/Cable over Redis/Sidekiq: one PostgreSQL dependency is enough until measured scale says otherwise.
- API-token auth remains for B2B integrations; Rails-style session auth is added for human operators.
- Production hardening is explicit: this repo implements the self-contained controls that fit a challenge and documents the controls that need real provider, compliance, and infrastructure inputs.

## 15A. How to evaluate this repo in 5 minutes

1. Prove the repository contract is green:

```sh
bin/ci
```

2. In one terminal, boot the full local stack on an isolated port:

```sh
APP_PORT=3101 docker compose up --build
```

3. In a second terminal, prove health, readiness, and tenant bootstrap:

```sh
slug="acme-fiscal-ops-$(date +%s)"
owner_email="owner-${slug}@acme.test"
curl -s http://127.0.0.1:3101/up
curl -s http://127.0.0.1:3101/ready
curl -s -X POST http://127.0.0.1:3101/v1/organizations \
  -H "Content-Type: application/json" \
  -d '{
    "organization": {
      "name": "Acme Fiscal Ops",
      "slug": "'"$slug"'",
      "legal_name": "Acme Fiscal Ops Ltda",
      "tax_id": "11.222.333/0001-81",
      "municipal_registration": "123456",
      "plan": "growth",
      "monthly_invoice_limit": 750
    },
    "owner": {
      "email": "'"$owner_email"'",
      "full_name": "Owner Admin"
    }
  }'
```

What those checks prove:

- `bin/ci` proves the Rails, system, security, OpenAPI, and seed contract that
  backs the repo's public claims.
- `docker compose up --build` proves the documented local stack boots with
  PostgreSQL, web, and jobs together instead of relying on manual migration
  prep or hidden container ordering.
- `/up` and `/ready` prove the runtime and database boot path are live.
- `POST /v1/organizations` proves the public API can bootstrap a tenant on a
  fresh local stack.

## 16. How to run locally

```sh
docker compose up --build
```

Then open `http://localhost:3000`, call `http://localhost:3000/up`, or bootstrap a tenant with `POST /v1/organizations`.
If port 3000 is already in use, run with `APP_PORT=3001 docker compose up --build` and open `http://localhost:3001`.
The web service prepares the database automatically before it boots, and the
jobs service waits for the web container to start before joining the stack.

Seeded backoffice credentials:

```text
owner@acme.test / password123
```

For a host-run fallback:

```sh
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server
```

Run `bin/jobs` in a second process when you want Solid Queue jobs to be processed locally.

For a public reviewer-facing deployment, use the Railway path in
[RAILWAY_DEPLOY.md](RAILWAY_DEPLOY.md). It keeps PostgreSQL as the runtime
database and enables `SOLID_QUEUE_IN_PUMA=true` so the demo can run as a single
service.

## 17. How to run tests

```sh
bin/rails test
TEST_WORKERS=10 bin/rails test
bin/rails test:system
SYSTEM_TEST_DRIVER=selenium bin/rails test:system
bin/rubocop
bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bundle exec bundler-audit check --update
```

The full CI workflow is defined in [`.github/workflows/ci.yml`](.github/workflows/ci.yml).
Railway demo deployment is documented in [RAILWAY_DEPLOY.md](RAILWAY_DEPLOY.md)
and [ADR 006](docs/adr/006-railway-single-service-demo.md).

## 18. Failure scenarios

- missing or invalid bearer token returns `401`
- insufficient role returns `403`
- cross-tenant invoice lookup returns `404`
- missing `Idempotency-Key` returns `400`
- stale `If-Match` returns `409`
- stale backoffice invoice actions are rejected instead of applying the newest server-side lock implicitly
- invoice quota exhaustion returns `422`
- provider timeout leaves the invoice in `pending_issue` with failed provider evidence and can be retried with the same provider idempotency key
- duplicate provider callback is accepted without duplicating provider request evidence
- invalid provider callback status is rejected before evidence is written
- missing production provider callback token fails closed instead of using local defaults
- unsupported outbound delivery adapter fails the event into retry instead of marking it dispatched
- unsupported outbound events are marked `failed` with `last_error`
- invalid browser credentials keep the operator out of the backoffice
- repeated browser login attempts are rate limited
- expired browser sessions are rejected and removed
- suspended memberships invalidate human access because `User` is linked to `Membership`

## 19. Roadmap

- add real municipal provider adapters behind the sandbox contract
- add webhook subscription delivery for downstream fiscal events
- add signed-download API endpoints for XML/PDF fiscal artifacts
- add signed provider callbacks with timestamp replay protection
- add NF-e product invoice support as a separate bounded context

## 20. License

MIT. See [LICENSE.txt](./LICENSE.txt).
