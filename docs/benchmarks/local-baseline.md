# Local Benchmark Baseline

Environment:

- Ruby 3.4.9
- Rails 8.1 hybrid mode
- PostgreSQL 16 through Docker Compose
- Puma single process
- k6 scenarios in `benchmarks/`
- measurements refreshed on `2026-07-01`
- managed benchmark server starts on `BENCHMARK_PORT=3204` by default
- benchmark database reset disables `statement_timeout` only for the setup phase

| Scenario | p50 | p95 | p99 | Throughput | Error rate | CPU/RSS notes |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Smoke | 43.71ms | 343.60ms | 1268.85ms | 4.36 req/s | 0.00% | 2 VUs for 30s across bootstrap/read/create/read; peak `40.2% CPU`, `139328 KiB` RSS |
| Load | 76.67ms | 245.95ms | 405.12ms | 43.48 req/s | 0.00% | 10 VUs for 60s; invoice idempotency remained collision-free; peak `53.4% CPU`, `156336 KiB` RSS |
| Stress | 154.11ms | 467.20ms | 617.58ms | 64.56 req/s | 0.00% | ramp to 30 VUs; organization row locks preserved invoice sequence; peak `64.0% CPU`, `150080 KiB` RSS |
| Spike | 108.90ms | 450.80ms | 762.55ms | 50.76 req/s | 0.00% | spike to 20 VUs; p95 recovered after ramp-down; peak `84.8% CPU`, `147536 KiB` RSS |

The checked-in `benchmarks/results/*` files preserve the current post-fix k6 summaries and resource samples for review. Re-run the scenarios after deployment tuning because Solid Queue/Cache and full-stack middleware change the runtime profile.
