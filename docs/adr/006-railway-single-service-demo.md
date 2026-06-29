# ADR 006: Railway Single-Service Demo Deployment

## Status

Accepted

## Context

FiscalBridge already had a production-oriented Dockerfile, explicit `/up` and
`/ready` endpoints, and a Kamal deployment shape. What it lacked was a small
public deploy surface for evaluator use.

The repository also depends on background job processing for invoice workflows.
For a reviewer demo, running a second worker service would add operational
weight without teaching much more about the product boundary.

## Options considered

- Keep Kamal as the only deployment path.
  Rejected because it leaves reviewers without a lightweight public run path.
- Add a Railway path with a separate worker service.
  Rejected because it spreads a demo across more services than necessary.
- Add a Railway single-service path with `SOLID_QUEUE_IN_PUMA=true`.
  Chosen because it reuses the current image and keeps the public demo small.

## Decision

Add `railway.json`, `RAILWAY_DEPLOY.md`, and `bin/docker-entrypoint`, and
document Railway as a single-service demo topology using managed PostgreSQL plus
`SOLID_QUEUE_IN_PUMA=true`.

## Consequences

Positive:

- the repository gains a lightweight public deploy path;
- the hybrid API plus backoffice surface becomes reviewer-runnable;
- boot-time `db:prepare` is explicit for container deploys.

Negative:

- the Railway path is not the final multi-process production shape;
- queue work shares the web process in demo mode;
- provider and compliance concerns still need real production infrastructure.

## Verification evidence

- `PATH=/Users/allanflavio/.asdf/shims:$PATH bin/ci`
- `PATH=/Users/allanflavio/.asdf/shims:$PATH /Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/eval-harness/bin/eval-harness . --output /tmp/fiscalbridge-ai-ready.md`
