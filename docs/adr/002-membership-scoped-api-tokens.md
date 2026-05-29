# ADR 002: Use membership-scoped API tokens

## Status

Accepted

## Context

FiscalBridge is a B2B service API. The first slice needs auditable actors, token rotation, revocation, and role-based authorization without adding OAuth complexity.

## Decision

Each membership owns one active API token digest. Raw tokens are returned only when created or rotated. Tokens expire after 90 days and can be revoked.

## Consequences

- audit logs can attribute operator actions to memberships
- token storage avoids raw secret persistence
- future JWT/OAuth support can be added at the authentication boundary without changing tenant-scoped domain services
