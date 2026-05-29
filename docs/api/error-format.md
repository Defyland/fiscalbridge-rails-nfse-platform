# Error Format

All application errors use a stable envelope:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Human-readable summary",
    "details": {
      "field": ["field-level errors"]
    },
    "request_id": "request-id",
    "correlation_id": "correlation-id"
  }
}
```

Known error codes:

- `missing_parameter`
- `missing_idempotency_key`
- `unauthorized`
- `forbidden`
- `not_found`
- `conflict`
- `invalid_transition`
- `precondition_required`
- `precondition_failed`
- `validation_failed`
- `rate_limited`

`Retry-After` is present on `rate_limited` responses. `If-Match` errors use `precondition_required` when the header is absent and `precondition_failed` when it cannot be parsed.
