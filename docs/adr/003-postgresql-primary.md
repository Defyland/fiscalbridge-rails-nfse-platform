# ADR 003: PostgreSQL as the default database

## Status

Accepted

## Context

FiscalBridge demonstrates behavior that depends on database-level guarantees: tenant-scoped uniqueness, check constraints, row locks for invoice sequence allocation, quota enforcement under concurrent writers, provider idempotency keys, optimistic locking, Solid Queue, Solid Cache, Solid Cable, Active Storage, and web sessions.

## Decision

Use PostgreSQL as the only runtime database for development, benchmark, CI, Docker Compose, and production.

## Consequences

- Docker Compose and CI run against `postgres:16`
- invoice sequence and quota tests can rely on PostgreSQL row-level locking semantics
- `db/schema.rb` is the primary schema dump
- Solid Queue, Solid Cache, Solid Cable, web auth sessions, and fiscal data share the same PostgreSQL deployment dependency
