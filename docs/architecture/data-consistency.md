# Data Consistency

## Transaction boundaries

### Tenant bootstrap

- boundary: `Organizations::Bootstrap.call!`
- creates organization, owner membership, audit log, and outbox event atomically
- returns the raw owner API token only after commit

### Invoice creation

- boundary: `Invoices::Create.call!`
- locks the organization row
- checks monthly invoice quota
- allocates the next `NFS-000001` style tenant invoice id
- creates the invoice with tenant-scoped idempotency key
- increments organization quota counters
- writes audit and outbox records

### Invoice issue and cancellation

- boundaries: `Invoices::Issue.call!` and `Invoices::Cancel.call!`
- require `If-Match` to match `lock_version`
- transition local state to `pending_issue` or `pending_cancellation`
- create provider request evidence before enqueueing jobs after commit
- write audit and outbox records in the same transaction

### Provider result application

- boundaries: `Invoices::ApplyIssueResult.call!`, `Invoices::ApplyCancellationResult.call!`, and `Providers::ApplyCallback.call!`
- update service invoice state and provider request evidence together
- duplicate callbacks are accepted through provider idempotency key uniqueness

## Indexes and constraints

- `organizations.slug` unique
- `memberships.organization_id + email` unique
- `memberships.api_token_digest` unique
- `fiscal_profiles.organization_id + tax_id` unique
- `customers.organization_id + document_number` unique
- `service_invoices.organization_id + public_id` unique
- `service_invoices.organization_id + idempotency_key` unique
- `provider_requests.idempotency_key` unique
- check constraints enforce role, state, invoice status, positive amounts, and retry counters
- foreign keys protect all tenant-owned relationships

## Optimistic locking

`service_invoices.lock_version` is exposed through `ETag` on API reads and writes. API issue, cancel, and status poll commands require `If-Match`. Backoffice issue, cancel, and status poll forms submit the `lock_version` rendered to the operator. A stale client receives `409 conflict` through `Invoices::InvalidTransition`; a stale operator action is rejected before changing invoice state.

## Fiscal evidence integrity

Provider issue results include XML/PDF artifact bytes and SHA-256 digests. `Invoices::ApplyIssueResult` verifies the digest before attaching artifacts through Active Storage. Provider request response payloads keep digests and metadata, not raw artifact bodies.

## Isolation assumptions

The production path assumes PostgreSQL read committed isolation plus explicit organization row locks for invoice sequence allocation and quota enforcement. PostgreSQL is now the only supported runtime database.

## Migration strategy

Schema changes should be backward compatible first: add nullable columns or tables, deploy code that writes both shapes if needed, backfill in batches, then tighten constraints in a later migration.

## Rollback strategy

Rollback must preserve provider evidence. If an application deploy is rolled back, pending provider requests remain in the database and can be retried by the previous worker code because provider action names and idempotency keys are stable.
