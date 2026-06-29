# ADR 007: Publish The Repo Under MIT

## Status

Accepted

## Context

`fiscalbridge-rails-nfse-platform` is already a public portfolio asset with
architecture docs, tests, CI, Railway guidance, and reviewer-facing operational
material. Without an explicit license, reuse and adaptation remain legally
ambiguous even though the technical intent is to expose a studyable specialist
project.

## Decision

Add an explicit MIT license and reference it from the README.

## Consequences

Positive:

- the public reuse surface becomes explicit instead of implied;
- portfolio reviewers can study and adapt the repo without license guesswork;
- downstream examples can point to an unambiguous reuse contract.

Negative:

- reuse is broadly permitted with limited reciprocity requirements;
- the license does not force derivative improvements to stay public.

## Verification evidence

- `PATH=/Users/allanflavio/.asdf/shims:$PATH /Users/allanflavio/Documents/projects/PERSONAL/backend-challenges/eval-harness/bin/eval-harness . --output /tmp/fiscalbridge-ai-ready.md`
