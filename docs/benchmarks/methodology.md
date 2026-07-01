# Benchmark Methodology

Benchmarks use k6 and the `bin/benchmark` runner. The runner can manage a Rails benchmark server, prepare the database, inject `SECRET_KEY_BASE_DUMMY=1` for the benchmark environment, disable PostgreSQL statement timeout during benchmark database reset, wait for `/ready`, execute a scenario, export the k6 summary, and sample server CPU/RSS.

Scenarios:

- smoke: low-volume sanity check
- load: steady authenticated tenant activity
- stress: increasing sustained concurrency
- spike: abrupt traffic ramp-up and recovery

The workload covers:

- `POST /v1/organizations`
- `GET /v1/organization`
- `POST /v1/fiscal_profiles`
- `POST /v1/customers`
- `POST /v1/service_invoices`
- `GET /v1/service_invoices/:public_id`

Reported metrics include p50, p95, p99 latency, throughput, error rate, CPU, and RSS.

The managed server uses `BENCHMARK_PORT` with a default of `3204`, and the runner probes `PATH`, `GOBIN`/`GOPATH`, and common Homebrew locations before failing for `k6`. Set `K6_BIN` to pin a specific binary when needed.
