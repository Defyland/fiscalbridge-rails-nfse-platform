# DHH Stack Hybrid Migration Plan

## Goal

Convert FiscalBridge from a Rails API-only portfolio project into a production-shaped hybrid Rails monolith while preserving the API-first NFS-e integration contract.

## Phase 1: Runtime Foundation

- Upgrade runtime declaration to Ruby 3.4+.
- Keep Rails 8.x and remove SQLite runtime fallback.
- Enable full-stack Rails middleware and views.
- Add Propshaft, Importmap, Turbo, Stimulus, bcrypt, Solid Queue, Solid Cache, Solid Cable, Active Storage, Kamal, Thruster, Capybara, and Selenium.
- Configure Active Job, cache, and cable to use Solid components outside tests.
- Keep Minitest as the test framework.

Acceptance:

- Existing `v1` controllers inherit from a dedicated API base controller.
- Web controllers inherit from `ApplicationController`.
- No API route changes are required for existing clients.

## Phase 2: Authentication Split

- Add `User` and `Session` models for human web access.
- Keep `Membership` as the tenant role and API-token principal.
- Link each `User` to a `Membership`.
- Use signed session cookies and `Current.user`/`Current.session` only inside request scope.
- Expire sessions server-side, prune excess sessions, and rate-limit login attempts through the shared cache-backed limiter.

Acceptance:

- Web sign-in works with email and password.
- API bearer-token authentication still works independently.
- A compromised API token does not create a browser session.
- Expired sessions and repeated invalid login attempts are rejected by system tests.

## Phase 3: Backoffice

- Add ERB/Hotwire screens for dashboard, service invoices, customers, fiscal profiles, and memberships.
- Provide operator actions for issue, poll status, and cancel using existing domain services.
- Keep write operations behind optimistic lock values already present in the domain.
- Submit the operator-rendered lock value with each state-changing backoffice form.

Acceptance:

- Operators can inspect invoice lifecycle, provider requests, audit events, and tenant context.
- Backoffice actions reuse the same services tested by the API.
- Stale operator pages cannot issue, cancel, or poll with an implicitly refreshed lock version.

## Phase 4: Fiscal Evidence

- Add Active Storage attachments to service invoices for XML and PDF artifacts.
- Keep `xml_url` and `pdf_url` in API payloads for backward compatibility until a signed-download API is added.
- Attach provider-returned bytes after SHA-256 verification rather than regenerating evidence in the application layer.

Acceptance:

- The model can attach XML/PDF files.
- The backoffice shows whether fiscal artifacts are present.
- Provider response metadata stores artifact digests without persisting raw artifact bodies in `provider_requests`.

## Phase 5: Deployment Shape

- Add Kamal deployment configuration.
- Run Puma behind Thruster in Docker.
- Document the `web` and Solid Queue worker processes.
- Keep PostgreSQL as the single required external dependency.

Acceptance:

- CI remains PostgreSQL based.
- Docker build has a production command suitable for Kamal.
- Operational docs describe required environment variables and processes.

## Senior Review Bar

The migration is not considered complete just because pages render. The senior bar is:

- Clear boundaries between machine clients and human operators.
- Domain services reused rather than duplicated in controllers.
- Idempotency, locking, RBAC, tenant scoping, audit logging, and provider evidence preserved.
- Tests cover API behavior and web workflow behavior.
- Browser system tests can run with Selenium/Chrome in CI while local development keeps a fast rack-test path.
- Deployment has explicit worker, storage, queue, cache, cable, and secret assumptions.
