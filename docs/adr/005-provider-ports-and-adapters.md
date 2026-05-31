# ADR 005: Use Ports and Adapters for Fiscal Providers

## Status

Accepted.

## Context

Fiscal providers vary by municipality, environment, protocol, authentication,
status polling, cancellation behavior, document download format, XML schema,
certificate requirements, rate limits, and homologation/production behavior.
Coupling invoice state transitions directly to provider clients would make the
domain hard to test, hard to certify, and risky to evolve.

The domain must remain stable even when a provider changes SOAP/REST endpoints,
municipal schemas, authentication headers, certificate chains, retry semantics,
or document retrieval flows.

## Decision

FiscalBridge treats fiscal providers as outbound adapters behind a stable fiscal
provider port. Domain services own invoice state transitions, idempotency,
locking, audit logs, provider request evidence, and outbox events. Provider
adapters translate between provider-specific protocols and this internal
contract.

The expected fiscal provider port is:

| Method | Responsibility | Required input | Required output |
| --- | --- | --- | --- |
| `issue(invoice, idempotency_key:, environment:)` | Submit an invoice for authorization/issuance. | `ServiceInvoice` aggregate, deterministic provider idempotency key, `homologation` or `production` environment. | `ProviderResult` with `status`, provider protocol, provider invoice number when issued, verification code when present, timestamps, raw metadata, and document references or artifact bodies when available. |
| `cancel(invoice, idempotency_key:, reason:, environment:)` | Request cancellation for an already issued invoice. | Issued `ServiceInvoice`, deterministic cancellation idempotency key, cancellation reason, environment. | `ProviderResult` with `cancelled` or `cancellation_failed` status, provider protocol, cancellation timestamp, rejection message when present, and raw metadata. |
| `fetch_status(invoice, environment:)` | Reconcile local state with provider state. | `ServiceInvoice` with provider identifiers/protocols, environment. | `ProviderResult` with current provider status, protocol, provider invoice number, issued/cancelled timestamps, rejection/cancellation messages, and raw metadata. |
| `download_xml(invoice, environment:)` | Retrieve the fiscal XML artifact from the provider or artifact endpoint. | `ServiceInvoice` with provider document identifiers, environment. | `ProviderDocument` with binary/string body, content type, filename, SHA-256 digest, provider document URL when applicable, and retrieval timestamp. |
| `download_pdf(invoice, environment:)` | Retrieve the fiscal PDF/DANFSE artifact from the provider or artifact endpoint. | `ServiceInvoice` with provider document identifiers, environment. | `ProviderDocument` with binary body, content type, filename, SHA-256 digest, provider document URL when applicable, and retrieval timestamp. |

### Result contract

Adapters should normalize provider responses into a stable result envelope:

```ruby
ProviderResult = Data.define(
  :provider_name,
  :environment,
  :operation,
  :status,
  :provider_protocol,
  :provider_invoice_number,
  :provider_verification_code,
  :issued_at,
  :cancelled_at,
  :message,
  :xml_url,
  :pdf_url,
  :xml_sha256,
  :pdf_sha256,
  :raw_metadata
)

ProviderDocument = Data.define(
  :provider_name,
  :environment,
  :document_type,
  :body,
  :content_type,
  :filename,
  :sha256,
  :source_url,
  :retrieved_at,
  :raw_metadata
)
```

The current sandbox adapter is intentionally lightweight, but real adapters must
conform to these semantics before they are used by domain services.

### Error contract

Adapters should either return a normalized failure `ProviderResult` or raise a
typed provider error that jobs can classify:

- `Providers::TimeoutError`: request timeout or temporary network failure.
- `Providers::AuthenticationError`: invalid credential, certificate, token, or
  environment configuration.
- `Providers::ValidationError`: provider rejected request shape or fiscal data.
- `Providers::DuplicateRequestError`: provider reports duplicate idempotency key
  or duplicate fiscal document.
- `Providers::UnavailableError`: provider maintenance or rate-limit condition.
- `Providers::ContractError`: adapter could not normalize an unexpected provider
  response.

Jobs are responsible for recording failed provider evidence. Domain services are
responsible for deciding whether the invoice remains pending, rejected, issued,
cancelled, or requires reconciliation.

### Idempotency and consistency rules

- Domain services generate provider idempotency keys; adapters must not invent
  them.
- `issue` and `cancel` must be safe to retry with the same idempotency key.
- Provider callbacks are not trusted as commands; they are reconciliation input.
- `download_xml` and `download_pdf` must calculate SHA-256 over the exact bytes
  persisted to Active Storage.
- Homologation and production credentials, endpoints, certificates, and storage
  prefixes must be separate configuration namespaces.

## Consequences

- Sandbox, national NFS-e, municipal NFS-e, and future NF-e providers can evolve independently.
- Homologation and production credentials remain adapter configuration, not domain behavior.
- Provider evidence can be hashed and audited consistently.
- Provider contract drift can be tested at the adapter boundary.
- Domain services can stay deterministic and testable with a sandbox adapter.
- Full hexagonal folder structure is deferred; the important boundary is the
  provider contract, not directory ceremony.

## Alternatives considered

- **Direct provider client calls from jobs:** simpler initially, but spreads
  provider protocol details across jobs and makes replacement/testing harder.
- **Provider-specific domain services:** makes every municipality a domain
  branch and increases regression risk.
- **External integration microservice:** useful at higher scale or when multiple
  products share providers, but premature while transaction boundaries are still
  local to FiscalBridge.
