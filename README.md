# FiscalBridge

FiscalBridge is a multi-tenant Rails API for Brazilian NFS-e issuance workflows. It models the operational core a SaaS, fintech, or marketplace would need to register fiscal profiles, onboard customers, create service invoices, issue them through provider adapters, cancel them, and preserve provider evidence for audit and reprocessing.

## 1. What is this product?

FiscalBridge is an NFS-e platform with API-token authentication, tenant isolation, provider request tracking, asynchronous issuance/cancellation jobs, and append-only audit logs. It intentionally uses a sandbox provider adapter so the repository is runnable locally while still exposing the same boundaries a production fiscal integration would need.

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
- optimistic-lock protected issue, cancel, and provider status polling commands
- sandbox NFS-e provider adapter with success, rejection, timeout, and cancellation paths
- provider callback endpoint protected by `X-Provider-Token`
- structured audit log, outbox events, Prometheus metrics, health/readiness endpoints, and OpenTelemetry hooks

## 5. Architecture overview

The app is a Rails API. Controllers are thin request/authorization boundaries. Domain services own transactions and state changes. ActiveJob workers call provider adapters after commit. Provider evidence is stored in `provider_requests`, domain events in `outbound_events`, and operator/provider actions in `audit_logs`.

```text
Client API -> Rails controllers -> Domain services -> PostgreSQL
                                      |             -> audit_logs
                                      |             -> outbound_events
                                      +-> ActiveJob -> sandbox NFS-e adapter -> provider_requests
Provider webhook -> callback controller -> Providers::ApplyCallback
```

## 6. Tech stack

- Ruby 3.3.6 and Rails 8.1 API mode
- PostgreSQL 16 as the primary database
- SQLite fallback for isolated local runs via `DATABASE_ADAPTER=sqlite3`
- ActiveJob async/test adapters
- Minitest, SimpleCov, RuboCop Rails Omakase, Brakeman, bundler-audit
- OpenTelemetry instrumentation, structured JSON logs, Prometheus text metrics
- Docker Compose and k6 benchmark scenarios

## 7. Domain model

| Model | Purpose | Key constraints |
| --- | --- | --- |
| `Organization` | Tenant, fiscal owner, quota and sequence boundary | unique `slug`, invoice quota, invoice sequence |
| `Membership` | API actor with role and token lifecycle | token digest uniqueness, token expiry/revocation |
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

Mutating services write the database record, audit log, and outbox event in one transaction. Jobs are enqueued only after commit. Issuance, cancellation, and status polling use ActiveJob workers and the `Providers::SandboxNfseClient` adapter. Provider callbacks are idempotent through the callback id stored as a provider request idempotency key.

Supported domain events include `service_invoice.created`, `service_invoice.issue_requested`, `service_invoice.issued`, `service_invoice.rejected`, `service_invoice.cancel_requested`, `service_invoice.cancelled`, `service_invoice.cancellation_failed`, `service_invoice.status_polled`, and `service_invoice.provider_timeout`.

## 10. Database design

PostgreSQL is the default database because invoice numbering and quota enforcement rely on row locks around the organization record. Service invoices expose `public_id` values such as `NFS-000001`, allocated inside the invoice creation transaction. `lock_version` protects issue/cancel/status commands from stale clients through `ETag` and `If-Match`.

## 11. Testing strategy

The suite uses Minitest and covers:

- model validations and normalization
- organization bootstrap and membership token lifecycle
- fiscal profile, customer, and invoice API flows
- RBAC and tenant isolation
- idempotent invoice creation
- asynchronous issue/cancel jobs
- provider timeout and duplicate callback failure scenarios
- outbox retry/failure behavior
- transaction rollback boundaries
- repository compliance against this initiative's general spec

## 12. Performance benchmarks

The `benchmarks/` directory contains k6 smoke, load, stress, and spike scenarios. The scripts exercise tenant bootstrap, authenticated organization reads, customer/profile setup, invoice creation, and invoice reads. Measured local results are documented in [`docs/benchmarks/local-baseline.md`](docs/benchmarks/local-baseline.md).

## 13. Observability

- JSON logs include severity, timestamp, request id, and correlation id.
- `X-Request-ID`, `X-Correlation-ID`, and `X-Trace-ID` are propagated on responses where available.
- `/up` exposes liveness.
- `/ready` checks database readiness and job adapter state.
- `/metrics` exports Prometheus-compatible HTTP and outbox counters/histograms.
- [`docs/diagrams/grafana-fiscalbridge-overview.json`](docs/diagrams/grafana-fiscalbridge-overview.json) defines a Grafana dashboard.

## 14. Security considerations

- bearer API tokens are stored only as SHA-256 digests
- tokens expire and can be rotated or revoked
- RBAC is configured in [`config/authorization_matrix.yml`](config/authorization_matrix.yml)
- tenant isolation is enforced through `current_organization` scoped lookups
- rate limiting is enforced before authentication to protect token and IP paths
- provider callbacks require `X-Provider-Token`
- secrets are read from environment variables, not source-controlled credentials
- threat model and authorization matrix are documented under [`docs/security/`](docs/security)

## 15. Trade-offs and decisions

- Sandbox provider instead of real municipality adapters: keeps the repo runnable and deterministic while preserving adapter boundaries.
- ActiveJob async adapter instead of Sidekiq/Solid Queue: enough for local portfolio validation; queue migration is documented.
- PostgreSQL primary with SQLite fallback: CI and Docker validate PostgreSQL behavior, while SQLite keeps quick local runs possible.
- API-token auth instead of OAuth/JWT: simpler for B2B service integrations and easier to audit in this scope.

## 16. How to run locally

```sh
docker compose up --build
```

Then call `http://localhost:3000/up` or bootstrap a tenant with `POST /v1/organizations`.

For a host-run fallback:

```sh
bundle install
bin/rails db:prepare
bin/rails server
```

Use `DATABASE_ADAPTER=sqlite3` when PostgreSQL is not available.

## 17. How to run tests

```sh
bin/rails test
bin/rubocop
bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bundle exec bundler-audit check --update
```

The full CI workflow is defined in [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## 18. Failure scenarios

- missing or invalid bearer token returns `401`
- insufficient role returns `403`
- cross-tenant invoice lookup returns `404`
- missing `Idempotency-Key` returns `400`
- stale `If-Match` returns `409`
- invoice quota exhaustion returns `422`
- provider timeout leaves the invoice in `pending_issue` with failed provider evidence for reprocessing
- duplicate provider callback is accepted without duplicating provider request evidence
- unsupported outbound events are marked `failed` with `last_error`

## 19. Roadmap

- add real municipal provider adapters behind the sandbox contract
- replace async ActiveJob adapter with Solid Queue or Sidekiq
- add webhook subscription delivery for downstream fiscal events
- add XML/PDF object storage with signed download URLs
- add signed provider callbacks with timestamp replay protection
- add NF-e product invoice support as a separate bounded context
