# ADR 001: Keep a SQLite fallback for local demos

## Status

Accepted

## Context

Portfolio reviewers should be able to run FiscalBridge without first provisioning PostgreSQL. The fiscal domain still needs PostgreSQL for concurrency-sensitive verification.

## Decision

The app defaults to PostgreSQL but supports `DATABASE_ADAPTER=sqlite3` for isolated local runs. SQLite uses `db/schema.sqlite.rb` and is not treated as the production consistency model.

## Consequences

- local demos can run with a single process
- CI and Docker continue to validate PostgreSQL
- concurrency tests and docs explicitly call out PostgreSQL as the authoritative path
