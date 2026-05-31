# Deployment Readiness

FiscalBridge needs the Rails web/API process, Solid Queue workers, PostgreSQL, storage for artifacts, and provider credentials.

## Current posture

- Hybrid Rails monolith with API and backoffice surfaces.
- PostgreSQL-backed application, queue, cache, cable, session, and storage metadata.
- Health, readiness, metrics, traces, and structured logs.
- Provider sandbox adapter for deterministic local behavior.

## Deferred platform work

- Kubernetes manifests are deferred until provider credentials, artifact storage, and worker concurrency are stable.
- Service mesh is not required for the MVP; provider adapter boundaries, retries, audit, and idempotency are the current controls.
- Managed secret storage should replace local environment variables for real homologation or production providers.
