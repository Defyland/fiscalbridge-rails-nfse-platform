# Common Issues Runbook

## `401 unauthorized`

- verify the `Authorization: Bearer` header is present
- check whether the token was rotated or revoked
- check `api_token_expires_at` for the membership

## `403 forbidden`

- inspect `config/authorization_matrix.yml`
- confirm the membership role is one of `owner`, `admin`, `operator`, or `auditor`
- auditors cannot create, issue, cancel, or poll invoices

## `400 missing_idempotency_key`

- add an `Idempotency-Key` header to `POST /v1/service_invoices`
- retry with the same key only when replaying the same logical invoice request

## `409 invalid_transition`

- read the invoice again and use the returned `ETag` in `If-Match`
- confirm the invoice is in a valid state for the command
- issue accepts `draft` or `rejected`; cancel accepts only `issued`

## Provider timeout during issue

- invoice remains `pending_issue`
- inspect the latest `provider_requests` row with `action=issue`
- verify `error_message` and `correlation_id`
- retry the same invoice issue through an operator workflow after checking provider-side status

## Duplicate provider callback

- duplicate callbacks return `202 accepted`
- confirm only one `provider_requests.idempotency_key` exists for the callback id
- repeated callbacks should not create additional fiscal state transitions

## Outbound event stuck in pending

- inspect `outbound_events.last_error`, `attempts_count`, and `next_attempt_at`
- unsupported events are marked `failed`
- transient delivery failures are retried with exponential delay
