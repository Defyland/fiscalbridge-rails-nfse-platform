# FiscalBridge Engineering Baseline

FiscalBridge satisfies the initiative-wide baseline through a working Rails API, a server-rendered backoffice, documented HTTP contract, automated tests, CI, security controls, observability, benchmark artifacts, and operational runbooks.

## Mandatory outcomes

- product-grade `README.md` with all 19 required sections
- `openapi.yaml` with versioned API paths and shared error responses
- `docs/adr/`, `docs/architecture/`, `docs/benchmarks/`, `docs/api/`, `docs/diagrams/`, and `docs/runbooks/`
- GitHub Actions covering lint, security, tests, OpenAPI linting, Docker build, and coverage artifact upload
- system tests covering the backoffice authentication and invoice evidence flow
- observability with JSON logs, request/correlation ids, traces, readiness, and Prometheus metrics using bounded histogram bucket counters
- k6 benchmark scenarios and measured result artifacts

## FiscalBridge-specific evidence

- provider adapter contract decoupled from fiscal domain services
- idempotent invoice creation keyed by organization and request identity
- async issue, cancel, and status-poll jobs
- ERB/Hotwire backoffice using the same domain services as the API
- Rails-style session auth separated from API tokens
- Solid Queue/Cache/Cable and Active Storage configured on PostgreSQL
- append-only audit logs with provider request evidence
- traceable invoice lifecycle transitions across local and provider states
- failure coverage for provider timeouts, duplicate callbacks, stale preconditions, tenant isolation, and safe reprocessing
- plan-based seat and invoice quotas
- PostgreSQL row-lock design for invoice sequence and quota behavior
