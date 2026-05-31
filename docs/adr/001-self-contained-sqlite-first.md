# ADR 001: Keep a SQLite fallback for local demos

## Status

Superseded by ADR 004

## Context

Portfolio reviewers should be able to run FiscalBridge without first provisioning PostgreSQL. The fiscal domain still needs PostgreSQL for concurrency-sensitive verification.

## Decision

The original decision allowed `DATABASE_ADAPTER=sqlite3` for isolated local runs. ADR 004 supersedes this because the project now targets a production-shaped Rails 8 hybrid monolith with Solid Queue, Solid Cache, Solid Cable, Active Storage, and PostgreSQL as the single runtime database.

## Consequences

- local demos now use Docker Compose with PostgreSQL
- CI and Docker validate the same database family used in production
- concurrency tests and docs no longer need a SQLite caveat
