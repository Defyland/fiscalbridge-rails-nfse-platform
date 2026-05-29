# FiscalBridge Engineering Baseline

This repository follows the initiative-wide standards below.

## Mandatory outcomes

- product-grade `README.md` with product and engineering sections
- `openapi.yaml` once the HTTP surface exists
- `docs/adr/`, `docs/architecture/`, `docs/benchmarks/`, `docs/api/`, `docs/diagrams/`, and `docs/runbooks/`
- atomic Conventional Commit history
- GitHub Actions for lint, tests, security, build, coverage, and OpenAPI validation
- observability with structured logs, metrics, traces, request IDs, and readiness endpoints
- documented k6 performance baselines

## FiscalBridge-specific emphasis

- provider adapter contracts decoupled from the fiscal domain
- idempotent invoice issuance keyed by organization and request identity
- async issue, cancel, status polling, and document generation jobs
- append-only fiscal audit logs with correlation-aware provider evidence
- traceable invoice lifecycle transitions across local and provider states
- failure coverage for provider timeouts, duplicate callbacks, and safe reprocessing

## Phase 0 boundary

This repository intentionally stops before scaffolding Rails, provider adapters, queues, or fiscal document generation. The goal of this phase is only to lock scope and standards.
