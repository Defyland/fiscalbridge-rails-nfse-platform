# Container Diagram

```mermaid
flowchart TB
  Client["SaaS or marketplace backend"] --> API["FiscalBridge Rails API"]
  Operator["Fiscal operations user"] --> API
  Provider["Municipal NFS-e provider"] --> Callback["Provider callback endpoint"]
  API --> DB["PostgreSQL"]
  API --> Jobs["ActiveJob worker"]
  Jobs --> ProviderAdapter["Sandbox provider adapter"]
  ProviderAdapter --> ProviderEvidence["provider_requests table"]
  API --> Metrics["Prometheus /metrics"]
  Metrics --> Grafana["Grafana dashboard"]
  API --> Logs["Structured JSON logs"]
  Callback --> DB
```
