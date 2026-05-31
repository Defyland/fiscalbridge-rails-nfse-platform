# ADR 004: Hybrid Rails Monolith With DHH Stack

## Status

Accepted.

## Context

FiscalBridge started as an API-first Rails platform for NFS-e issuance. That remains the most important product boundary because customers integrate through service APIs, idempotency keys, provider callbacks, and audit evidence.

The project also needs to demonstrate modern Rails production judgment. A serious NFS-e platform has human operations: fiscal teams inspect invoices, retry provider work, audit callbacks, rotate tokens, and download fiscal evidence. Keeping those workflows outside the app would hide important product and operational complexity.

## Decision

FiscalBridge will become a hybrid Rails monolith:

- The public `v1` API remains the integration contract.
- A server-rendered backoffice is added with ERB, Turbo, Stimulus, Importmap, and Propshaft.
- Human authentication uses Rails-style session auth with `User`, `Session`, `bcrypt`, signed cookies, and a narrow `Current.user`/`Current.session` boundary.
- API authentication remains bearer-token based through `Membership` tokens.
- Active Job runs on Solid Queue outside tests.
- Rails cache uses Solid Cache outside tests.
- Action Cable uses Solid Cable for production/development readiness.
- Active Storage stores provider XML/PDF evidence instead of relying only on external URL fields.
- PostgreSQL is the only supported runtime database.

## Consequences

This keeps the product honest: machines use the API, humans use the backoffice, and both share the same domain services and database constraints. The app avoids a React SPA, Sidekiq, Redis, and separate services until there is measured scale pressure.

The first implementation intentionally keeps the backoffice operational and narrow. It shows invoice status, provider evidence, audit logs, memberships, customers, fiscal profiles, and safe invoice commands. It does not duplicate every API write path immediately.

## Production Readiness Criteria

- API contract continues to pass existing request tests.
- Web auth is separate from API tokens.
- Queue/cache/cable are configured without Redis.
- XML/PDF fiscal evidence can be stored by Active Storage.
- System tests cover sign-in and core backoffice invoice inspection/actions.
- Deployment docs include Kamal, Thruster, Docker, PostgreSQL, and Solid worker processes.
