# Production hardening trade-offs

This document records the senior-review caveats that would come up in a strong
technical interview or production readiness review. The repo is intentionally a
portfolio/challenge implementation, but the architecture should make the next
production steps explicit instead of hiding them.

## Executive summary

The project now handles the practical hardening that fits this repository:

- expiring server-side browser sessions;
- session fixation mitigation through `reset_session` on login;
- production-only `Secure` session cookies;
- browser session rejection when the stored user-agent no longer matches;
- cache-backed rate limiting with a stable namespace suitable for shared Solid
  Cache storage;
- transactional row locking around invoice commands that depend on rendered web
  `lock_version` values;
- provider-returned fiscal artifacts attached through Active Storage with
  SHA-256 verification and digest persistence on `service_invoices`.
- transactional outbox retries that persist the next attempt, enqueue delayed
  retries, claim work under row lock, and sweep due pending or stale processing
  events.
- provider callbacks that fail closed in production when the shared callback
  token is not configured.
- bounded cursor pagination on registry and invoice list endpoints.
- Prometheus HTTP histograms backed by aggregate bucket counters instead of
  unbounded per-request duration arrays.
- integration tests that validate OpenAPI required response fields against real
  controller responses.

The remaining production gaps are not accidental. They need real operational
inputs: legal provider credentials, certificate strategy, fraud/risk appetite,
infrastructure topology, observability targets, and compliance requirements.

## Auth and session hardening

### Concern

A production backoffice should not rely only on a signed cookie. A reviewer
would ask about server-side revocation, idle timeout, fixation, stolen-cookie
reuse, device posture, MFA, and operator lifecycle.

### What this repo implements now

- `sessions` are server-side records with `expires_at` and `last_seen_at`.
- Expired sessions are destroyed on resume.
- Suspended memberships invalidate the linked browser user.
- Login rotates the Rails session with `reset_session`.
- The custom session cookie is `HttpOnly`, `SameSite=Lax`, expires with the
  server-side session, and is `Secure` in production.
- A resumed browser session must match the original user-agent.
- Active sessions are capped per user and stale records are pruned.

### Why this is enough for this repo

The goal is to demonstrate Rails 8 conventions and fiscal workflow design
without introducing external identity infrastructure. Adding MFA, SSO, device
management, or risk-based auth would be speculative without a target customer
security model.

### Production follow-up

- Add MFA or SSO/SAML/OIDC according to buyer profile.
- Add admin-visible session inventory and remote revoke.
- Add password reset and email verification flows.
- Consider shorter idle timeout for privileged roles.
- Add audit events for login success, login failure, logout, session expiry,
  suspicious user-agent mismatch, password reset, and MFA events.
- If using reverse proxies, configure trusted proxies before using IP-based
  security decisions.

## Distributed rate limiting

### Concern

An in-memory limiter does not hold under multiple Puma processes, multiple
containers, or deploy rollouts. Even cache-backed limiting can be wrong if each
process uses different cache namespaces.

### What this repo implements now

- Rate limiting uses `Rails.cache.increment` with TTL windows.
- The default namespace is stable across processes and can be overridden with
  `RATE_LIMIT_NAMESPACE`.
- Cache keys hash the logical identifier instead of storing raw emails, tokens,
  or IP strings in cache keys.
- Tests can rotate the namespace through `Security::RateLimiter.reset!` without
  affecting production behavior.

### Why this is enough for this repo

Rails 8's Solid Cache keeps the stack self-contained on PostgreSQL, which is the
point of the DHH-style stack being evaluated here. For this portfolio workload,
a fixed-window limiter is simple, deterministic, and easy to test.

### Production follow-up

- Validate cache-store atomicity and latency under expected write contention.
- Add route-specific limits for login, token-authenticated API calls, provider
  callbacks, and expensive invoice operations.
- Add account-level and organization-level limits, not only token/IP limits.
- Put coarse abuse protection at the edge: CDN/WAF/load balancer.
- Move to Redis or a dedicated limiter only if measured contention or
  cross-region topology justifies it.

## Web locking and operator commands

### Concern

The API uses `If-Match` semantics, but web forms cannot naturally submit HTTP
precondition headers. A stale browser tab can otherwise enqueue commands against
an invoice state the operator did not actually review.

### What this repo implements now

- Backoffice issue/cancel/status forms submit the rendered `lock_version`.
- Invoice command services reject stale versions.
- Commands now acquire a database row lock inside the transaction before checking
  the expected version.
- Web controllers rescue stale object errors and invalid transitions into an
  operator-facing redirect instead of leaking exceptions.

### Why this is enough for this repo

Hidden `lock_version` fields are the normal Rails/HTML way to carry optimistic
state through forms. Row locks keep the command side correct without building a
custom Hotwire concurrency protocol.

### Production follow-up

- Add richer conflict pages that show "your version" versus "current version".
- Broadcast invoice updates with Turbo Streams/Solid Cable so stale tabs become
  visible before submit.
- Add role-specific confirmation for irreversible fiscal actions.
- Add command-level idempotency keys for repeated browser submissions.
- Track operator command attempts in audit logs, including rejected stale
  attempts.

## Fiscal evidence realism

### Concern

Simulated XML/PDF is not legal fiscal evidence. A real NFS-e integration must
preserve provider-returned documents, validation metadata, protocol numbers,
digital signatures, storage immutability, and reconciliation status.

### What this repo implements now

- The sandbox provider returns XML/PDF bytes instead of only fake URLs.
- Issuance verifies provider SHA-256 digests before attaching artifacts.
- Active Storage stores XML/PDF files.
- `service_invoices` persists `xml_sha256`, `pdf_sha256`, and
  `evidence_recorded_at`.
- Provider request payloads keep non-binary response metadata for audit.

### Why this is enough for this repo

Real provider evidence needs municipal sandbox credentials, certificate handling,
provider-specific XML schemas, and legal storage policy. Implementing fake
certificate/signature flows would look more sophisticated but would not be more
truthful.

### Production follow-up

- Implement provider adapters per municipality or aggregator contract.
- Validate XML against provider schemas before persistence.
- Verify digital signatures and certificate chains where the provider supports
  them.
- Store artifacts in object storage with versioning, retention, and object lock
  if the compliance profile requires WORM behavior.
- Add signed download endpoints instead of exposing storage URLs directly.
- Build reconciliation jobs that compare local invoice state against provider
  state and raise operational alerts on drift.

## Outbound event delivery realism

### Concern

A repo can easily pretend to have webhooks by marking rows as dispatched without
actually delivering anywhere. That creates false confidence: retry code looks
green, but no downstream system ever sees the event.

### What this repo implements now

- Outbox dispatch claims rows under database lock before delivery.
- Active `processing` events are skipped; stale `processing` events are swept and
  retried.
- The default delivery adapter is an explicit local log sink, not an accidental
  no-op.
- Unsupported delivery adapter configuration fails the event back into retry
  metadata instead of losing the signal.
- Fiscal `service_invoice.*` event payloads expose documented stable top-level
  fields and tests assert schema-required payload fields.

### Why this is enough for this repo

Real webhook delivery needs endpoint ownership, authentication/signing, retry
SLOs, replay tooling, and customer-facing subscription management. Those are
product and infrastructure decisions. The local adapter keeps the repo honest:
it proves the outbox mechanics without inventing fake external infrastructure.

### Production follow-up

- Add a signed HTTP webhook adapter with timestamp replay protection.
- Store delivery response status, latency, and downstream endpoint id.
- Add dead-letter inspection and replay controls in the backoffice.
- Add subscription management and per-tenant webhook secrets.
- Add contract tests against representative downstream consumers.

## Final position

For a senior Rails portfolio review, this is now defensible: the repo states the
trade-offs, implements the high-value hardening that fits a self-contained Rails
8 monolith, and names the production work that would require real business and
infrastructure decisions.
