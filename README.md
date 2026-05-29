# FiscalBridge

NFS-e and NF-e fiscal platform built in Ruby on Rails to showcase rich business rules, external provider workflows, and auditable fiscal operations.

## Status

Phase 0 bootstrap only. This repository currently establishes naming, scope, documentation structure, and engineering expectations. It does not yet contain a Rails application scaffold, fiscal adapters, background jobs, or document generation code.

## Product intent

FiscalBridge is planned as a fiscal platform for SaaS companies, fintechs, and marketplaces that need to create, issue, track, cancel, audit, and reprocess NFS-e and later NF-e documents through provider adapters and asynchronous workflows.

## Planned stack

- Ruby on Rails API
- PostgreSQL
- Redis
- Solid Queue or Sidekiq
- OpenAPI
- OpenTelemetry
- Prometheus and Grafana
- Docker Compose
- RSpec
- k6
- MinIO as an optional fake XML and PDF storage layer

## Engineering focus

This project is meant to demonstrate:

- provider adapter patterns for heterogeneous fiscal integrations
- stateful invoice workflows with idempotent issuance and cancellation
- append-only auditability for sensitive fiscal actions
- background jobs for provider communication and retries
- multi-tenant API design with traceable document lifecycle
- failure-aware testing around provider timeouts, duplicates, and reprocessing

## Bootstrap contents

- repository initialized and synchronized with GitHub
- mandatory documentation folders created
- baseline engineering spec captured in `docs/engineering-baseline.md`

## Next phase

The first implementation slice should prioritize organizations, fiscal profiles, customers, service invoices, provider adapters, idempotent issue requests, and auditable invoice status transitions.
