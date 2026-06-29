# Railway Deploy

This guide configures FiscalBridge as a single-service Railway deployment for
public demo and reviewer evaluation.

## Runtime shape

- builder: `Dockerfile`
- activation health check: `/up`
- readiness endpoint available separately at `/ready`
- database migration/bootstrap: `bin/docker-entrypoint` runs `db:prepare`
- background jobs: `SOLID_QUEUE_IN_PUMA=true` keeps Solid Queue execution in
  the web process for the demo topology

The Railway path is intentionally smaller than the Kamal topology. It proves the
hybrid product surface without introducing a second container layout.

## Required variables

Set these in Railway:

```bash
RAILS_ENV=production
DATABASE_URL=<managed-postgres-url>
SECRET_KEY_BASE=<generated-secret>
RAILS_MASTER_KEY=<local config/master.key>
PROVIDER_CALLBACK_TOKEN=<shared-callback-token>
SOLID_QUEUE_IN_PUMA=true
TARGET_PORT=3000
HTTP_PORT=80
```

Optional variables:

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=<collector-endpoint>
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=<traces-endpoint>
OTEL_TRACES_EXPORTER=otlp
```

## Five-minute verification

After deploy:

```bash
curl -fsS "$RAILWAY_PUBLIC_DOMAIN/up"
curl -fsS "$RAILWAY_PUBLIC_DOMAIN/ready"
curl -fsS "$RAILWAY_PUBLIC_DOMAIN/metrics"
```

Then sign in to `/session/new` or bootstrap a tenant through `POST /v1/organizations`
and exercise one create-plus-issue invoice path from
[docs/api/http-examples.md](docs/api/http-examples.md).

## Limits

- This is a demo topology, not the final production shape.
- Queue execution shares the web process in Railway mode.
- The sandbox provider remains intentionally local and does not prove municipal
  integrations or compliance hosting requirements.
