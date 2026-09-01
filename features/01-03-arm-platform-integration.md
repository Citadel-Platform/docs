# Feature 1.3 — ARM Platform Integration

## Scope
Integrate ARM into the central Citadel Platform experience after the core module and CLI workflows are stable, while preserving standalone ARM usability.

## Tasks

### Task 1.3.1 — Platform navigation entry
- Add ARM product card in the central Citadel console.
- Route users to ARM overview, issues, cases, reports, and project settings.
- Preserve deep links into case and issue details.

### Task 1.3.2 — Internal self-monitoring
- Embed ARM Tooling in Citadel Flutter apps where appropriate.
- Capture platform UI errors with Citadel app/project metadata.
- Keep screenshots optional and best-effort.

### Task 1.3.3 — Aggregate reporting path
- Define when ARM aggregates should be exported to BigQuery.
- Keep raw case evidence in project-local boundaries unless explicitly approved.
- Preserve the split between shared platform auth/registry data in `citadel-platform` and client-owned telemetry/evidence data in external Firebase projects.
- Add report rollups only after retention and data-boundary decisions are resolved.

### Task 1.3.4 — Optional intake gateway decision
- Evaluate whether direct Firestore/Storage mode is sufficient.
- Add an intake gateway only if concrete needs exist: validation, rate limiting, multi-sink fanout, non-Firebase clients, or stricter access control.

## Definition of done
Reviewed 30/08/26 against the tree.

- [x] ARM appears in central product navigation — a launch page and fourteen
      routes under `/arm` in the Console shell.
- [x] Citadel apps can report internal UI failures through ARM — the Console
      itself depends on `arm_tooling` and reports through it.
- [x] Aggregate reporting boundaries are documented —
      `_dev/docs/arm_aggregate_reporting_boundary.md`.
- [x] Intake gateway is either deferred with rationale or specified —
      deferred, with the current posture and the reason written down in
      `_dev/docs/arm_intake_gateway_posture.md`.
