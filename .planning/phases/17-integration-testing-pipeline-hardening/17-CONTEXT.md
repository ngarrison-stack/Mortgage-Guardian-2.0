# Phase 17: Integration Testing & Pipeline Hardening - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<vision>
## How This Should Work

This is the capstone phase that validates the entire v3.0 Forensic Analysis Engine works as a unified system. The full document lifecycle — intake, OCR, classification, analysis, cross-document comparison, federal/state compliance checking, and consolidated reporting — gets tested end-to-end as a single flow.

The primary purpose is a **regression safety net**. These tests lock in the current pipeline behavior so that any future changes to Phases 10-16 services are immediately caught if they break the chain. It's not about proving things work today — it's about guaranteeing you'll know the instant something stops working tomorrow.

Beyond the happy path, every external service boundary (Claude API, Plaid, Supabase, Redis) gets systematically tested for failure scenarios. The pipeline must degrade gracefully at each boundary — never crash, always produce a meaningful response.

Performance guardrails round it out: timing assertions that fail if pipeline steps regress beyond target times, plus resource tracking to ensure memory and connections are cleaned up properly across multiple document processing runs.

</vision>

<essential>
## What Must Be Nailed

- **Pipeline integrity** — The full intake-to-report pipeline must be tested as a single flow. If any step breaks the chain, a test catches it immediately. This is the non-negotiable core.
- **Service boundary failure testing** — Systematically test failure at every external boundary (Claude, Plaid, Supabase, Redis) and verify the pipeline responds correctly — degrades, doesn't crash.
- **Performance guardrails** — Timing assertions in tests (steps complete within target times) AND resource tracking (memory, connections, cleanup). The pipeline must be fast and clean.

</essential>

<boundaries>
## What's Out of Scope

- No new features — purely testing and hardening, no new API endpoints, services, or capabilities
- No frontend/iOS testing — strictly backend pipeline validation
- No UI testing — this is about the API and service layer, not the presentation layer

</boundaries>

<specifics>
## Specific Ideas

- End-to-end tests that exercise the full pipeline: document upload → OCR → classification → individual analysis → cross-document forensics → federal compliance → state compliance → consolidated report generation
- Failure injection at each external service boundary to verify graceful degradation
- Timing assertions that act as canaries — if a future change makes classification go from 2s to 20s, the test fails
- Resource leak detection across multiple sequential pipeline runs

</specifics>

<notes>
## Additional Context

This phase completes the v3.0 Forensic Analysis Engine milestone. The test suite currently stands at 42 suites with 1145 tests — all passing. Phase 17 adds the integration layer that ties all the individual service tests together into pipeline-level validation.

The regression safety net framing is key: these tests exist primarily for the future, not the present. They lock in behavior so the platform can evolve confidently.

</notes>

---

*Phase: 17-integration-testing-pipeline-hardening*
*Context gathered: 2026-03-14*
