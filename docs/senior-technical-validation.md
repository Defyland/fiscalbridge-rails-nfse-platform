# Senior Technical Validation

## Portfolio review checklist

| Area | Evidence | Why it matters |
| --- | --- | --- |
| Domain modeling | fiscal profiles, customers, service invoices, provider requests, audit logs | Shows a believable fiscal product, not CRUD-only scaffolding |
| Consistency | organization row locks, idempotency keys, optimistic locking, transaction-boundary tests | Prevents duplicate fiscal documents and stale state writes |
| Async workflows | issue/cancel/status jobs and outbox dispatch | Mirrors real provider workflows and retry behavior |
| Failure handling | provider timeout leaves invoice pending with evidence; duplicate callbacks are idempotent | Handles fiscal uncertainty explicitly |
| Security | token digests, RBAC matrix, tenant isolation, callback token, rate limiting | Covers the main API threat surfaces |
| Observability | JSON logs, request/correlation ids, Prometheus metrics, OpenTelemetry hooks | Makes production behavior inspectable |
| Documentation | OpenAPI, ADRs, runbooks, architecture, benchmarks | Makes design and operations reviewable |

## Known trade-offs

- The provider is sandbox-only. The adapter boundary is in place; real municipal providers would implement the same result contract.
- ActiveJob async is enough for a local proof. A production deployment should use Solid Queue or Sidekiq with retry/dead-letter observability.
- Provider callbacks use a static token in this slice. Production should add signed payloads with timestamp replay protection.

## Senior bar assessment

FiscalBridge passes the portfolio bar for a backend challenge because it demonstrates product shape, non-trivial fiscal state transitions, tenant isolation, transactional integrity, async provider interaction, failure-aware testing, observability, security docs, and reproducible engineering artifacts.
