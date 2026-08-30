# Feature 4.2 — Exigence Operations Console and SDK (REWRITTEN 14/08/26)

> Supersedes the prior 4.2 spec. Task 4.2.2 (config-first definition editor) is
> **cancelled** — see DECISIONS.md 14/08/26. The Console operates artifacts; it
> does not author them.

## Scope
Surface the Exigence runtime for operating artifacts: run, watch, approve,
audit, and account for cost. Authoring happens in the repository.
The Console is the system of record for execution state; any unavoidable manual
step must still appear as a guided flow with validation and completion checks.

## Page structure (supersedes the prior page list)
The Exigence nav becomes five pages. Knowledge Base (4.4), Artifacts (4.5) and
Billing (4.6) have their own feature files; this file owns Executions and
Approvals and the shared shell.

| Page | Owner |
|---|---|
| Knowledge Base | Feature 4.4 |
| Artifacts | Feature 4.5 |
| Executions | **this file** |
| Approvals | **this file** |
| Billing | Feature 4.6 |

## Task 4.2.1 — Executions
- Run list per project: artifact, trigger source, status, duration, cost.
- Run detail: LangGraph node timeline with status, duration, retries; expandable
  node I/O redacted per scope tags; cost per node; cross-link to trace (4.3) and
  to the audit event that authorized each effect.
- Cancel a run with a required reason; cancellation performs declared
  compensation in reverse completion order.
- Explicit no-data / not-configured states everywhere (hard rule #1).

## Task 4.2.2 — CANCELLED
Definition and configuration editing is removed. The existing template,
schedule, provider, webhook and budget dialogs in
`platform_exigence_pages.dart` are re-pointed:
- **Template dialog** — delete.
- **Schedule / webhook dialogs** — retain. These configure *operation* of an
  existing artifact, not its logic, and both are already backed by
  `schedule_dispatcher.ts` and `webhook_trigger.ts`.
- **Provider / budget dialogs** — retain, move under Billing (4.6).

## Task 4.2.3 — Approvals
- Pending-approval inbox per project, most-urgent first, consistent with ARM's
  triage convention.
- Approve/reject with required note. Resolution issues LangGraph
  `Command(resume=…)` against the run's thread and writes an audit event.
- Approval requests raised by a `visual`-mode local tool are labelled
  irreversible in the inbox, because compensation cannot reverse them.

## Task 2.4.4 — SDK
Retain the existing Dart SDK (`triggerAutomation`, `getRun`, `streamRunStatus`,
approval deep links) unchanged — it is already implemented and tested. Extend
only where 4.5 requires a new trigger surface.

## Task 4.2.5 — CLI
Retain the existing `citadel exigence` command set unchanged — list, enable,
disable, run, cancel, approvals list/resolve, budget set are implemented and
authenticated by Google OIDC.

## Definition of done
- [x] Full lifecycle drivable from the Console: trigger → watch nodes live →
      approve → inspect audit → see cost. Proven live in the Phase R acceptance
      run; the Executions page now opens on the project's runs rather than
      requiring an identifier (30/08/26).
- [x] Role scoping enforced (viewer read-only, developer no budget edits, admin
      full) — proved against production code by the permission-map equivalence
      test, which enumerates every operation against every role combination.
- [x] Cancelled template surface is deleted, not merely hidden — the runtime
      routes, the proxy operations and the Console dialogs went in one change
      (15/08/26); the dead Configuration nav item that still matched
      `/exigence/configuration` was removed 30/08/26.
- [x] Retained dialogs are wired to a runtime that actually serves them.
      Verified live: all six surviving operational routes answer 200. This is
      also where a gap was found — the Console's artifact runs table called a
      `GET` that had never been proxied, so it could only ever have 404'd.
- [x] `flutter analyze` zero warnings; widget tests for run detail and
      approvals inbox — 333 tests pass.
- [x] All new copy is production-visible, no dev-facing meta commentary.

**Open, deliberately:** the run detail's cross-link to a trace waits on Feature
4.3, which owns tracing.
