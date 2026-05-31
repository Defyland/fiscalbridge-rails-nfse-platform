# Fiscal threat model

## Scope

This model focuses on fiscal risks specific to NFS-e workflows:

- duplicated issuance or cancellation commands;
- forged or replayed provider callbacks;
- leakage of XML/PDF fiscal artifacts;
- audit log tampering or incompleteness;
- accidental mixing of homologation and production environments.

The general application threat model remains in [`threat-model.md`](threat-model.md).

## Assets

| Asset | Why it matters |
| --- | --- |
| `service_invoices` state | Represents the local fiscal lifecycle and drives operator decisions. |
| Provider protocol and invoice number | Evidence that the municipality/provider accepted or rejected a fiscal command. |
| Provider idempotency key | Prevents duplicate fiscal documents under retries. |
| XML/PDF artifacts | Sensitive fiscal documents containing customer, issuer, service, value, and provider metadata. |
| `provider_requests` | Evidence of outbound calls, callbacks, responses, failures, and retries. |
| `audit_logs` | Operator and system accountability trail. |
| Provider credentials/certificates | Authority to issue or cancel fiscal documents. |
| Homologation/production config | Prevents test data from reaching production and production documents from being handled as tests. |

## Trust boundaries

- API clients cross into FiscalBridge with bearer tokens.
- Backoffice operators cross into FiscalBridge with browser sessions.
- Solid Queue jobs cross from internal state into provider adapters.
- Fiscal providers cross into FiscalBridge through callback endpoints.
- Active Storage crosses from application authorization into artifact storage.
- Homologation and production provider configurations cross from deployment
  secrets into adapter runtime.

## Threats and controls

| Threat | Attack or failure mode | Impact | Current controls | Residual risk | Production hardening |
| --- | --- | --- | --- | --- | --- |
| Duplicate issuance | Client retries `issue`; job retries after timeout; operator submits stale tab; provider receives repeated request. | Duplicate fiscal document, tax exposure, manual cancellation. | API `If-Match`, web `lock_version`, row lock inside command transaction, provider request idempotency key, state machine guards, audit log. | Sandbox cannot prove real provider idempotency behavior. | Certify each provider adapter against provider-side idempotency/replay semantics; add reconciliation alerts for duplicate provider numbers. |
| Duplicate cancellation | Operator or job repeats cancellation while provider response is unknown. | Incorrect local state or repeated cancellation request. | `can_cancel?`, `pending_cancellation`, provider request evidence, cancellation idempotency key. | Real providers may have different cancellation windows and irreversible status codes. | Adapter-specific cancellation state mapping and reconciliation jobs. |
| False callback | Attacker posts callback with fake provider protocol or status. | Unauthorized invoice state change. | Callback endpoint requires `X-Provider-Token`, rejects unsupported statuses before evidence is written, and fails closed in production when no token is configured. | Static shared token is not sufficient for production-grade providers. | Signed callbacks with timestamp, nonce, body digest, certificate pinning where supported, replay window, and provider IP allowlists if reliable. |
| Callback replay | Valid callback is resent to trigger duplicate side effects. | Duplicate provider request evidence, repeated state transitions, noisy events. | Provider callback idempotency key and duplicate callback tests. | Provider callback identifiers may be absent or inconsistent. | Canonical replay key per provider using protocol, invoice number, timestamp, and payload digest. |
| XML/PDF leakage | Artifact URLs or blobs are exposed outside tenant scope. | Customer/issuer fiscal data breach. | Active Storage attachments, tenant-scoped invoice reads, no public signed-download API yet. | Local storage/backend policy is not a complete production artifact policy. | Signed tenant-scoped download endpoints, short TTL, audit on download, object storage private buckets, encryption, retention policy. |
| Artifact tampering | Stored XML/PDF differs from provider response. | Invalid evidence, audit failure, reconciliation errors. | Provider-returned bytes are hashed; `xml_sha256` and `pdf_sha256` persisted; checksum format constraints. | Sandbox documents are not legally signed municipal documents. | Validate provider signatures, XML schemas, certificate chain, and store immutable object versions. |
| Audit log tampering | Operator/system action is modified or deleted. | Loss of accountability during fiscal dispute. | Append-oriented `audit_logs`, explicit audit writes in domain services, tests tied to workflows. | Database admins can still mutate rows; no cryptographic chain. | Append-only database role, hash chain, external log shipping, WORM retention, and alerting on audit table mutation. |
| Missing audit event | Command succeeds but audit/outbox record is absent. | Incomplete evidence and harder incident response. | Domain services write state, audit, provider request, and outbox in one transaction. | A new command could forget the pattern. | Contract tests for every fiscal command and repository compliance checks for required audit events. |
| Homologation/production mix-up | Homologation credentials or endpoints are used for production invoices, or production credentials receive test payloads. | Legal invalidity, customer data leak, provider penalties. | Environment appears in provider configuration and is part of the documented provider port contract. | Current sandbox is not a real two-environment provider. | Separate secret namespaces, storage prefixes, provider accounts, deployment targets, database records, visual UI environment markers, and deploy-time validation. |
| Provider credential leak | API token/certificate for provider is exposed in repo/logs. | Unauthorized issuance/cancellation. | Secrets are environment-based; repo does not store provider credentials. | Local `.env` and operator machines remain risks. | Managed secret storage, certificate rotation, least-privilege provider accounts, and log scrubbing. |

## Required fiscal security invariants

- A fiscal command must be idempotent or explicitly reject stale state.
- Provider state must not be trusted without provider evidence.
- Provider callbacks must never be treated as authenticated user commands.
- XML/PDF artifacts must be private by default and tenant-scoped at read time.
- Artifact bytes must be hashed before or during persistence.
- Audit writes must happen in the same transaction as the state transition they
  describe.
- Homologation and production must use separate credentials, endpoints, storage
  prefixes, and operational alerts.

## Test and evidence mapping

| Risk | Evidence in repo |
| --- | --- |
| Duplicate or stale issue/cancel commands | `ServiceInvoicesFlowTest`, `BackofficeServiceInvoicesTest`, command services with row locks. |
| Provider timeout and uncertain state | `FailureScenariosTest`, `provider_requests` failure records. |
| Duplicate callback | `FailureScenariosTest`. |
| Artifact integrity | `ServiceInvoiceJobsTest`, `xml_sha256`, `pdf_sha256`, Active Storage attachments. |
| Tenant isolation for fiscal resources | `AuthorizationAndIsolationTest`. |
| Rate limiting around auth/API abuse | `RateLimitingAndMetricsTest`, `BackofficeAuthenticationTest`. |

## Open production questions

- Which real provider or municipality is the first production target?
- Does the provider support idempotency keys, signed callbacks, XML signature
  validation, and separate homologation credentials?
- What retention period and immutability policy apply to XML/PDF artifacts?
- Should fiscal artifact downloads be exposed to API clients, backoffice users,
  or both?
- What audit evidence must be exported to external SIEM or immutable storage?
