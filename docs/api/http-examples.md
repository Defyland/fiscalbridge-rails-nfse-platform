# HTTP Examples

## Bootstrap tenant

```sh
curl -X POST http://localhost:3000/v1/organizations \
  -H "Content-Type: application/json" \
  -d '{
    "organization": {
      "name": "Acme Fiscal Ops",
      "slug": "acme-fiscal-ops",
      "legal_name": "Acme Fiscal Ops Ltda",
      "tax_id": "11222333000181",
      "municipal_registration": "123456",
      "plan": "growth"
    },
    "owner": {
      "email": "owner@acme.test",
      "full_name": "Owner Admin"
    }
  }'
```

The response includes the owner `api_token` once. Store it outside the repository.

## Create fiscal profile

```sh
curl -X POST http://localhost:3000/v1/fiscal_profiles \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "fiscal_profile": {
      "legal_name": "Acme Fiscal Ops Ltda",
      "tax_id": "11222333000181",
      "municipal_registration": "123456",
      "city_code": "3550308",
      "service_list_item": "01.07",
      "taxation_regime": "simples_nacional",
      "environment": "sandbox"
    }
  }'
```

## Create customer

```sh
curl -X POST http://localhost:3000/v1/customers \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "customer": {
      "legal_name": "Buyer Ltda",
      "document_type": "cnpj",
      "document_number": "22333444000155",
      "email": "finance@buyer.test",
      "city_code": "3550308"
    }
  }'
```

## Create service invoice

```sh
curl -X POST http://localhost:3000/v1/service_invoices \
  -H "Authorization: Bearer $TOKEN" \
  -H "Idempotency-Key: invoice-2026-0001" \
  -H "Content-Type: application/json" \
  -d '{
    "service_invoice": {
      "fiscal_profile_id": 1,
      "customer_id": 1,
      "service_description": "Software implementation services",
      "service_code": "6201501",
      "amount_cents": 15000,
      "tax_rate_bps": 200,
      "iss_withheld": false
    }
  }'
```

Repeating the same `Idempotency-Key` returns the original invoice with `idempotent_replay: true`.

## Issue service invoice

Read the invoice first and reuse its `ETag` value:

```sh
curl http://localhost:3000/v1/service_invoices/NFS-000001 \
  -H "Authorization: Bearer $TOKEN"
```

Then issue it:

```sh
curl -X POST http://localhost:3000/v1/service_invoices/NFS-000001/issue \
  -H "Authorization: Bearer $TOKEN" \
  -H 'If-Match: "0"'
```

The API returns `202 accepted`; the job records provider evidence and transitions the invoice to `issued` or `rejected`.

## Cancel service invoice

```sh
curl -X POST http://localhost:3000/v1/service_invoices/NFS-000001/cancel \
  -H "Authorization: Bearer $TOKEN" \
  -H 'If-Match: "2"' \
  -H "Content-Type: application/json" \
  -d '{
    "cancellation": {
      "reason": "Customer requested cancellation"
    }
  }'
```

## Provider callback

```sh
curl -X POST http://localhost:3000/v1/provider_callbacks/nfse \
  -H "X-Provider-Token: local-provider-token" \
  -H "Content-Type: application/json" \
  -d '{
    "callback": {
      "callback_id": "provider-callback-123",
      "provider_invoice_number": "NFSE-NFS-000001",
      "status": "issued",
      "provider_protocol": "PROTO-123"
    }
  }'
```

## Validation failure example

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Amount cents must be greater than 0",
    "details": {
      "amount_cents": ["must be greater than 0"]
    },
    "request_id": "req-123",
    "correlation_id": "corr-123"
  }
}
```

## Authorization failure example

An `auditor` attempting to issue an invoice receives:

```json
{
  "error": {
    "code": "forbidden",
    "message": "auditor cannot perform service_invoices_issue."
  }
}
```

## Tenant-isolation failure example

A valid token from tenant B reading `NFS-000001` from tenant A receives `404 not_found`; the API does not disclose that the invoice exists in another tenant.
