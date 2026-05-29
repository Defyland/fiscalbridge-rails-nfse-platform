# Threat Model

## Scope

FiscalBridge protects tenant fiscal profiles, customer identities, service invoice state, provider protocol evidence, API tokens, and audit logs.

## Trust boundaries

- external API clients cross into the Rails API with bearer tokens
- provider callbacks cross into the callback endpoint with `X-Provider-Token`
- background jobs cross into the sandbox provider adapter
- database records cross tenant boundaries only through explicit bugs, so all lookups are tenant-scoped

## Primary threats

| Threat | Impact | Mitigation | Residual risk |
| --- | --- | --- | --- |
| Token theft | Unauthorized invoice access or issuance | SHA-256 token digests, expiration, rotation, revocation, rate limiting | No device binding in this scope |
| Tenant breakout | One tenant reads another tenant's invoices | `current_organization` scoped lookups and isolation tests | Raw SQL must preserve this pattern |
| Duplicate issuance | Provider receives repeated issue request | tenant idempotency key on invoice creation and provider request idempotency keys | Real adapters need provider-side idempotency support |
| Provider spoofing | Fake callback changes fiscal state | `X-Provider-Token`; documented future signed callbacks | Static token is acceptable only for sandbox |
| Stale client write | Old state overwrites a newer invoice transition | `ETag` and `If-Match` on state commands | Clients must preserve headers |
| Provider timeout | Local state loses provider uncertainty | timeout leaves invoice pending and provider request failed for safe reprocessing | Manual operator workflow still needed |

## Tests mapped to threats

- token revocation: `MembershipTokenLifecycleTest`
- tenant breakout: `AuthorizationAndIsolationTest`
- duplicate issuance: `InvoiceSequenceTest`
- provider spoofing and duplicate callback: `FailureScenariosTest`
- stale client write: `ServiceInvoicesFlowTest` and request precondition tests
- provider timeout: `FailureScenariosTest`
