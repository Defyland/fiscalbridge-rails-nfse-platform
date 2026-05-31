# Threat Model

## Scope

FiscalBridge protects tenant fiscal profiles, customer identities, service invoice state, provider protocol evidence, API tokens, browser sessions, attached fiscal artifacts, and audit logs.

Fiscal-specific abuse cases are expanded in [`fiscal-threat-model.md`](fiscal-threat-model.md), including duplicate issuance, false callbacks, XML/PDF leakage, audit-log integrity, and homologation/production separation.

## Trust boundaries

- external API clients cross into the Rails API with bearer tokens
- backoffice users cross into the Rails web surface with signed session cookies
- provider callbacks cross into the callback endpoint with `X-Provider-Token`
- background jobs cross into the sandbox provider adapter
- database records cross tenant boundaries only through explicit bugs, so all lookups are tenant-scoped

## Primary threats

| Threat | Impact | Mitigation | Residual risk |
| --- | --- | --- | --- |
| Token theft | Unauthorized invoice access or issuance | SHA-256 token digests, expiration, rotation, revocation, cache-backed rate limiting | No device binding in this scope |
| Session theft | Unauthorized backoffice access | signed cookies, expiring server-side `sessions`, `bcrypt`, session pruning, membership state checks | No MFA in this scope |
| Tenant breakout | One tenant reads another tenant's invoices | `current_organization` scoped lookups and isolation tests | Raw SQL must preserve this pattern |
| Duplicate issuance | Provider receives repeated issue request | tenant idempotency key on invoice creation and provider request idempotency keys | Real adapters need provider-side idempotency support |
| Provider spoofing | Fake callback changes fiscal state | `X-Provider-Token`; documented future signed callbacks | Static token is acceptable only for sandbox |
| Stale client write | Old state overwrites a newer invoice transition | `ETag` and `If-Match` on API commands; rendered `lock_version` on backoffice forms | Clients must preserve headers and forms must not strip hidden fields |
| Fiscal evidence tampering | Stored XML/PDF does not match provider response | provider-returned artifact bytes are attached with SHA-256 verification before persistence | Sandbox PDF remains simplified evidence, not a municipal legal document |
| Provider timeout | Local state loses provider uncertainty | timeout leaves invoice pending and provider request failed for safe reprocessing | Manual operator workflow still needed |

## Tests mapped to threats

- token revocation: `MembershipTokenLifecycleTest`
- session authentication, expiry, and login throttling: `BackofficeAuthenticationTest`
- tenant breakout: `AuthorizationAndIsolationTest`
- duplicate issuance: `InvoiceSequenceTest`
- provider spoofing and duplicate callback: `FailureScenariosTest`
- stale client write: `ServiceInvoicesFlowTest`, request precondition tests, and `BackofficeServiceInvoicesTest`
- provider timeout: `FailureScenariosTest`
- fiscal evidence integrity: `ServiceInvoiceJobsTest`

## Transversal architecture additions

- Provider callbacks are untrusted input and must stay behind token or signature verification.
- Issue and cancel commands require idempotency because duplicate fiscal documents are operationally expensive.
- XML and PDF artifacts are sensitive fiscal evidence; download and storage flows must preserve tenant scoping and audit entries.
- Homologation and production providers must remain separate configuration boundaries.
- Provider adapters are outbound ports; domain services should depend on their contract, not provider protocol details.
