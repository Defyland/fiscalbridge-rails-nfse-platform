# ADR 003: PostgreSQL as the default database

## Status

Accepted

## Context

FiscalBridge demonstrates behavior that depends on database-level guarantees: tenant-scoped uniqueness, check constraints, row locks for invoice sequence allocation, quota enforcement under concurrent writers, provider idempotency keys, and optimistic locking. SQLite is useful for a self-contained demo, but it does not represent the production concurrency model expected from a fiscal backend.

## Decision

Use PostgreSQL as the default database for development, benchmark, CI, Docker Compose, and production. Keep SQLite as an explicit fallback through `DATABASE_ADAPTER=sqlite3`.

## Consequences

- Docker Compose and CI run against `postgres:16`
- invoice sequence and quota tests can rely on PostgreSQL row-level locking semantics
- `db/schema.rb` is the primary schema dump
- `db/schema.sqlite.rb` exists only for fallback local runs
