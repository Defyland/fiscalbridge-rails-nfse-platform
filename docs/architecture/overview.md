# Architecture Overview

FiscalBridge is organized around explicit boundaries:

- **HTTP boundary**: versioned JSON API controllers validate authentication, authorization, idempotency, and optimistic-lock preconditions.
- **Domain services**: `Invoices::Create`, `Invoices::Issue`, `Invoices::Cancel`, and membership services own transaction boundaries and state transitions.
- **Provider boundary**: `Providers::SandboxNfseClient` represents the external NFS-e provider adapter contract.
- **Async boundary**: ActiveJob workers perform provider calls after database commit.
- **Evidence boundary**: `provider_requests`, `audit_logs`, and `outbound_events` preserve fiscal and operational evidence.

```mermaid
flowchart LR
  Client["API client"] --> API["Rails API controllers"]
  API --> Auth["Token auth + RBAC"]
  Auth --> Services["Domain services"]
  Services --> DB["PostgreSQL"]
  Services --> Outbox["outbound_events"]
  Services --> Audit["audit_logs"]
  Services --> Jobs["ActiveJob workers"]
  Jobs --> Provider["Sandbox NFS-e adapter"]
  Provider --> Evidence["provider_requests"]
  Callback["Provider callback"] --> CallbackAPI["Callback controller"]
  CallbackAPI --> Evidence
```

The app uses tenant-scoped database lookups everywhere a user-visible resource is read. Public invoice ids are unique only inside a tenant; numeric ids stay internal.
