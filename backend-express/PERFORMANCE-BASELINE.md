# Performance Baseline

Performance targets and baseline measurements for Mortgage Guardian backend.

## Performance Targets

| Metric | Target | Suite |
|--------|--------|-------|
| API p99 latency | < 1000 ms | api |
| Health endpoint p99 latency | < 50 ms | health |
| Memory peak RSS | < 100 MB | memory |
| Error rate | < 1% | all |
| Stress p99 @ 100 connections | < 1000 ms | stress |

## Endpoint Baselines

TBD — requires running server. Run `npm run loadtest` to generate baselines.

Baseline JSON files are written to `loadtest/results/baseline-YYYY-MM-DD.json`.

## Stress Test Results

TBD — requires running server. Run `npm run loadtest:stress` to generate results.

## Memory Profile

TBD — requires running server. Run `npm run loadtest:memory` to generate profile.

Key metrics captured:
- Initial RSS, heap used, heap total
- Peak RSS during sustained load (50 connections, 30 seconds)
- Post-load RSS after 5-second GC cooldown
- Leak detection: warn if post-load RSS > 1.5x initial

## How to Run

Ensure the server is running before executing load tests:

```bash
# Start the server
npm run dev

# In another terminal, run individual suites:
npm run loadtest:health    # Health/readiness endpoint baselines
npm run loadtest:api       # API endpoint load tests
npm run loadtest:stress    # High-concurrency stress tests
npm run loadtest:memory    # Memory profiling under sustained load

# Run all suites:
npm run loadtest           # Runs all suites (health, api, stress, memory)
```

### Environment Variables

- `LOADTEST_BASE_URL` — Override the target URL (default: `http://localhost:3000`)

### Interpreting Results

- **PASS**: p99 latency <= 1000 ms AND error rate <= 1%
- **FAIL**: p99 latency > 1000 ms OR error rate > 1%
- **Memory PASS**: Peak RSS < 100 MB
- **Memory WARN**: Post-load RSS > 1.5x initial RSS (potential leak)

Results are printed as a summary table and also written to `loadtest/results/` as JSON baselines when running the `all` suite.
