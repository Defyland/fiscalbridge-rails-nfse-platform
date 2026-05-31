# FiscalBridge Event Contracts

FiscalBridge events describe fiscal document lifecycle transitions and provider evidence. They are outbox events first and webhook candidates later.

## Goals

- make fiscal lifecycle changes explicit and replayable;
- give downstream consumers stable versioned contracts;
- keep provider evidence and local state transitions correlated;
- preserve compatibility when new provider metadata is added;
- distinguish homologation and production events.

## Envelope

Every fiscal event must include:

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `event_id` | string | yes | Unique event id. Consumers must deduplicate on this field. |
| `event_type` | string | yes | Version-independent event name, for example `service_invoice.issued`. |
| `schema_version` | integer | yes | Major schema version for the event payload. |
| `occurred_at` | datetime | yes | Time the domain event occurred, not the delivery time. |
| `producer` | string | yes | Always `fiscalbridge` for events emitted by this app. |
| `organization_id` | string | yes | Tenant boundary for the event. |
| `service_invoice_id` | string | yes | Public invoice id, for example `NFS-000001`. |
| `correlation_id` | string | yes | Request/job/provider correlation id. |
| `provider` | string | yes | Provider adapter name, for example `sandbox_nfse`. |
| `environment` | string | yes | `homologation`, `production`, or `sandbox`. |
| `payload` | object | yes | Event-specific payload with stable top-level fields plus a `service_invoice` snapshot. |

Example envelope:

```json
{
  "event_id": "evt_01HXZ7KJFM8VB4TFYJ94P7QKVM",
  "event_type": "service_invoice.issued",
  "schema_version": 1,
  "occurred_at": "2026-05-29T18:30:00Z",
  "producer": "fiscalbridge",
  "organization_id": "acme",
  "service_invoice_id": "NFS-000001",
  "correlation_id": "req_01HXZ7KJFM8VB4TFYJ94P7QKVM",
  "provider": "sandbox_nfse",
  "environment": "sandbox",
  "payload": {
    "provider_invoice_number": "NFSE-NFS-000001",
    "provider_protocol": "PROTO-NFS-000001-3",
    "xml_sha256": "f4d6f0f8d0a4f08f49f8e8f4d90ec5dbda3b7f5d8e0f2d2e2f6f8f1d7b1a0e11",
    "pdf_sha256": "d4c6f0f8d0a4f08f49f8e8f4d90ec5dbda3b7f5d8e0f2d2e2f6f8f1d7b1a0e22"
  }
}
```

## Event catalog

| Event type | Version | Producer moment | Required payload fields | Notes |
| --- | --- | --- | --- | --- |
| `service_invoice.created` | v1 | After local invoice creation transaction commits. | `status`, `amount_cents`, `customer_document`, `fiscal_profile_id`, `idempotency_key`, `lock_version` | Local event; provider has not been called. |
| `service_invoice.issue_requested` | v1 | After issue command transitions invoice to `pending_issue`. | `status`, `provider_request_id`, `idempotency_key`, `lock_version` | Indicates provider work was scheduled, not completed. |
| `service_invoice.issued` | v1 | After provider confirms issuance and artifacts are persisted. | `provider_invoice_number`, `provider_verification_code`, `provider_protocol`, `issued_at`, `xml_sha256`, `pdf_sha256`, `provider_request_id` | External webhook candidate. |
| `service_invoice.rejected` | v1 | After provider rejects issuance. | `provider_protocol`, `rejection_reason`, `provider_request_id` | Rejection is terminal until the invoice is edited/reissued. |
| `service_invoice.cancel_requested` | v1 | After cancel command transitions invoice to `pending_cancellation`. | `provider_invoice_number`, `cancellation_reason`, `provider_request_id`, `lock_version` | Indicates provider cancellation work was scheduled. |
| `service_invoice.cancelled` | v1 | After provider confirms cancellation. | `provider_invoice_number`, `provider_protocol`, `cancelled_at`, `provider_request_id` | External webhook candidate. |
| `service_invoice.cancellation_failed` | v1 | After provider refuses cancellation. | `provider_invoice_number`, `provider_protocol`, `rejection_reason`, `provider_request_id` | Requires operator review. |
| `service_invoice.status_polled` | v1 | After a provider status reconciliation completes. | `provider_invoice_number`, `provider_protocol`, `provider_status`, `provider_request_id` | Should not hide local/provider drift. |
| `service_invoice.provider_timeout` | v1 | After provider call times out or is unavailable. | `operation`, `provider_request_id`, `last_error`, `retryable` | Invoice usually remains pending for safe reprocessing. |

## Compatibility policy

- Consumers deduplicate by `event_id`.
- Event names are stable; breaking payload changes require a new
  `schema_version`.
- New optional payload fields are backward compatible.
- Required payload fields must not be removed from an existing version.
- Field meaning must not change within the same version.
- Provider request identifiers, provider protocols, and payload hashes are
  evidence fields and should not be removed without a new version.
- Duplicate provider callbacks must not create duplicate state transitions or
  duplicate externally delivered events.
- Homologation and production events must be distinguishable through
  `environment` and provider metadata.

## Payload rules

- Use public invoice ids, not internal numeric ids, for externally delivered
  events.
- Keep event-specific required fields at the top level of `payload`; the nested
  `payload.service_invoice` object is a convenience snapshot and is not a
  substitute for the stable contract fields.
- Include provider identifiers only after the provider has returned them.
- Include SHA-256 fields only for the exact artifact bytes persisted to storage.
- Include `provider_request_id` whenever an event is caused by provider
  communication.
- Do not include raw XML/PDF bodies in events.
- Do not include API tokens, provider credentials, certificates, or signed
  artifact URLs.
- Put provider-specific fields under `payload.provider_metadata` when they are
  useful but not part of the stable contract.

## Delivery semantics

FiscalBridge stores fiscal lifecycle events in `outbound_events` inside the same
transaction as the corresponding state transition. For `service_invoice.*`
events, `outbound_events.payload` is the versioned external envelope documented
above. Delivery is asynchronous and at-least-once: failed delivery attempts store
`next_attempt_at`, enqueue the next retry, and are also covered by a recurring
due-event sweeper. Consumers must be idempotent and should store the last
processed `event_id` or a provider-specific idempotency key.

## Versioned schemas

- [service_invoice_created.v1.json](service_invoice_created.v1.json)
- [service_invoice_issued.v1.json](service_invoice_issued.v1.json)
- [service_invoice_rejected.v1.json](service_invoice_rejected.v1.json)
- [service_invoice_cancelled.v1.json](service_invoice_cancelled.v1.json)

The JSON schemas currently cover externally relevant lifecycle events. Internal
events such as `issue_requested`, `cancel_requested`, `status_polled`, and
`provider_timeout` are versioned in this catalog and can receive schema files
before being exposed to external webhook consumers. The existing schema files
validate both the shared envelope and the externally relevant event-specific
payload fields.
