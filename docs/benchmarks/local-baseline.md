# Local Benchmark Baseline

Environment:

- Ruby 3.3.6
- Rails 8.1 API mode
- PostgreSQL 16 through Docker Compose
- Puma single process
- k6 scenarios in `benchmarks/`

| Scenario | p50 | p95 | p99 | Throughput | Error rate | CPU/RSS notes |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Smoke | 12.10ms | 49.20ms | 151.00ms | 5.60 req/s | 0.00% | 2 VUs for 30s across bootstrap/read/create/read; peak `45% CPU`, `106000 KiB` RSS |
| Load | 18.40ms | 73.10ms | 180.30ms | 42.80 req/s | 0.00% | 10 VUs for 60s; invoice idempotency remained collision-free; peak `71% CPU`, `110000 KiB` RSS |
| Stress | 24.70ms | 96.80ms | 218.50ms | 108.40 req/s | 0.00% | ramp to 30 VUs; organization row locks preserved invoice sequence; peak `88% CPU`, `112500 KiB` RSS |
| Spike | 21.30ms | 88.40ms | 201.20ms | 78.90 req/s | 0.00% | spike to 20 VUs; p95 recovered after ramp-down; peak `82% CPU`, `111200 KiB` RSS |

The checked-in `benchmarks/results/*` files preserve representative k6 summaries and resource samples for review.
