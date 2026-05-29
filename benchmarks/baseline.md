# Benchmark Baseline

FiscalBridge includes four k6 scenarios:

- smoke: verifies the service is ready and the authenticated fiscal workflow succeeds
- load: exercises steady customer/profile/invoice traffic
- stress: raises concurrency to expose quota and sequence contention
- spike: applies abrupt traffic changes to observe recovery

Run a scenario with:

```sh
bin/benchmark smoke
bin/benchmark load
bin/benchmark stress
bin/benchmark spike
```

Each run writes:

- `benchmarks/results/<scenario>-summary.txt`
- `benchmarks/results/<scenario>-summary.json`
- `benchmarks/results/<scenario>-resource-samples.tsv`
- `benchmarks/results/<scenario>-server.log`
