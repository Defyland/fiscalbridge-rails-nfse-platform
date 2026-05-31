# Provider Contract Drift

Use this runbook when a fiscal provider adapter or callback changes shape and invoice workflows start failing.

## Triage

- Identify the adapter method involved: `issue`, `cancel`, `fetch_status`, `download_xml`, or `download_pdf`.
- Compare provider response fields with the provider port documented in `docs/adr/005-provider-ports-and-adapters.md`.
- Check provider request evidence hashes and callback idempotency keys.
- Confirm environment separation: homologation and production must not share credentials.

## Recovery

- Keep invoice state pending when provider truth is uncertain.
- Patch the adapter translation layer, not the domain service, when only protocol shape changed.
- Replay failed provider requests after idempotency and evidence hashes are confirmed.
- Record manual retries in audit logs.
