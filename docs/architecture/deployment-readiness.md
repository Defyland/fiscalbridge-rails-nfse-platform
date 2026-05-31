# Deployment Readiness

FiscalBridge needs the Rails web/API process, Solid Queue workers, PostgreSQL, storage for artifacts, and provider credentials.

## Current posture

- Hybrid Rails monolith with API and backoffice surfaces.
- PostgreSQL-backed application, queue, cache, cable, session, and storage metadata.
- Health, readiness, metrics, traces, and structured logs.
- Provider sandbox adapter for deterministic local behavior.
- Transactional outbox workers with a local log delivery adapter by default.
- Bounded API pagination for registry and invoice list endpoints.

## Self-contained runtime knobs

- `OUTBOUND_EVENT_DELIVERY_ADAPTER=log` is the default. It records delivery metadata to structured logs without sending customer or fiscal payload bodies to an external system.
- Any unsupported delivery adapter fails the outbox attempt and records retry metadata instead of marking the event dispatched.
- Real webhook delivery is intentionally deferred until a target downstream contract, signing scheme, and retry/SLA policy exist.

## Deferred platform work

- Kubernetes manifests are deferred until provider credentials, artifact storage, and worker concurrency are stable.
- Service mesh is not required for the MVP; provider adapter boundaries, retries, audit, and idempotency are the current controls.
- Managed secret storage should replace local environment variables for real homologation or production providers.
