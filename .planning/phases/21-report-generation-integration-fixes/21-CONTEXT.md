# Phase 21: Report Generation & Integration Fixes - Context

**Gathered:** 2026-03-25
**Status:** Ready for planning

<vision>
## How This Should Work

The final consolidated report is the product — it's what lawyers, regulators, and users actually see. Every handoff point in the pipeline needs to hold together: from document intake, through individual and cross-document analysis, through compliance checking, all the way to the final report.

Right now, the concern is that things break at every handoff. Findings get detected but don't always make it into the consolidated report. Summary counts may not match detail sections. What Plaid says, what document analysis found, and what the compliance engine flagged should cross-reference cleanly — and likely don't in all cases.

This phase is about making the entire chain trustworthy. If a violation was detected, it must appear in the report. If numbers are cited, they must be consistent. If cross-system data is referenced, it must match.

</vision>

<essential>
## What Must Be Nailed

- **Report correctness** — The final consolidated report must be correct, complete, and trustworthy. Everything upstream exists to serve this deliverable.
- **No lost findings** — Every violation and issue detected anywhere in the pipeline must appear in the final report. Zero tolerance for silently dropped results.
- **Consistent numbers** — Summary tallies, violation counts, risk scores, and finding counts must be consistent across all report sections.
- **Clean cross-referencing** — Plaid data, document analysis findings, and compliance engine flags must align when referenced together.

</essential>

<boundaries>
## What's Out of Scope

- No new report types — fixing existing consolidated report and RESPA letters only, no new formats or templates
- No UI changes — purely backend pipeline and report generation fixes, frontend dashboard stays as-is
- No performance optimization — fixing correctness, not speed

</boundaries>

<specifics>
## Specific Ideas

No specific requirements — the goal is a thorough integrity pass across the full pipeline, fixing whatever is broken at each handoff point.

</specifics>

<notes>
## Additional Context

This is the final phase of the v4.0 Bug Fix & Stability Sprint. Phases 18-20 fixed backend stability, frontend UI issues, and pipeline accuracy (OCR, classification, compliance rules). Phase 21 closes the loop by ensuring everything that was improved upstream actually flows correctly into the final deliverable.

The user expects issues at every handoff point — this should be treated as a comprehensive audit of the report generation pipeline, not a targeted fix for one known bug.

</notes>

---

*Phase: 21-report-generation-integration-fixes*
*Context gathered: 2026-03-25*
