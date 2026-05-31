# Senior Technical Validation

## Portfolio review checklist

| Area | Evidence | Why it matters |
| --- | --- | --- |
| Domain modeling | fiscal profiles, customers, service invoices, provider requests, audit logs | Shows a believable fiscal product, not CRUD-only scaffolding |
| Consistency | organization row locks, idempotency keys, API/backoffice optimistic locking, transaction-boundary tests | Prevents duplicate fiscal documents and stale state writes |
| Async workflows | issue/cancel/status jobs and outbox dispatch | Mirrors real provider workflows and retry behavior |
| Hybrid product surface | API contract plus ERB/Hotwire backoffice | Shows both machine integration and human operations |
| Failure handling | provider timeout leaves invoice pending with evidence; duplicate callbacks are idempotent | Handles fiscal uncertainty explicitly |
| Security | token digests, RBAC matrix, tenant isolation, callback token, cache-backed rate limiting, expiring sessions | Covers the main API and backoffice threat surfaces |
| Observability | JSON logs, request/correlation ids, Prometheus metrics, OpenTelemetry hooks | Makes production behavior inspectable |
| Documentation | OpenAPI, ADRs, runbooks, architecture, benchmarks | Makes design and operations reviewable |

## Known trade-offs

- The provider is sandbox-only. The adapter boundary is in place; real municipal providers would implement the same result contract.
- Solid Queue, Solid Cache, and Solid Cable currently share the primary PostgreSQL database. That keeps the deployment simple; a larger installation can move them to separate PostgreSQL databases without changing the product boundary.
- Provider callbacks use a static token in this slice. Production should add signed payloads with timestamp replay protection.
- Backoffice authentication intentionally stops at password-based auth with expiring server-side sessions. A regulated deployment should add MFA and SSO.

## Senior bar assessment

FiscalBridge passes the portfolio bar for a backend challenge because it demonstrates product shape, non-trivial fiscal state transitions, tenant isolation, transactional integrity, async provider interaction, web operations, cache-backed protections, verified fiscal evidence, failure-aware testing, observability, security docs, and reproducible engineering artifacts.
