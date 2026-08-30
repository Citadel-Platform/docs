# Feature 4.1 — Exigence Automation Runtime (REWRITTEN 14/08/26)

> Supersedes the prior 4.1 spec. The durable-execution substrate built under
> that spec is largely retained; what changes is that LangGraph now owns graph
> execution and Citadel owns only the guarantees LangGraph does not provide.
> See DECISIONS.md 14/08/26 for the reversals and their rationale.

## Scope
A durable, auditable execution runtime for operator-authored LangGraph
artifacts running against client projects. Citadel is the safety, cost and
evidence layer; LangGraph is the execution engine.

## Division of responsibility — do not blur this

| Concern | Owner |
|---|---|
| Graph state, branching, node retries, streaming | LangGraph |
| Human-in-the-loop pause/resume | LangGraph `interrupt()` / `Command(resume)` |
| Checkpoint persistence | Citadel Firestore checkpointer (LangGraph's interface) |
| Tool authorization, deny-by-default | Citadel |
| Budget reservation before provider I/O, exact settlement | Citadel |
| Hash-chained audit chain | Citadel |
| Effect receipts, reverse-order compensation | Citadel |
| Project kill switch, cost attribution | Citadel |

If a capability exists in LangGraph and can be configured and monitored
programmatically, use LangGraph's. Do not reimplement it.

## Task 4.1.R1 — Firestore checkpointer
- Implement `BaseCheckpointSaver` (`.put`, `.putWrites`, `.getTuple`, `.list`)
  over the existing Firestore journal in the **client** project. `thread_id` is
  the Citadel `runId`.
- Validate against `@langchain/langgraph-checkpoint-validation`. The conformance
  suite passing is the acceptance gate — do not hand-roll equivalent tests.
- Preserve the existing immutable sequenced-event representation as the backing
  store. Checkpoint writes become journal events; projections continue to serve
  Console reads.
- Reconcile granularity explicitly: a LangGraph superstep maps to a Citadel
  activity. Document the mapping in `_dev/docs/` before implementing.
- Pending writes from partially-completed supersteps map onto the existing
  activity-attempt records so a resumed graph does not re-run completed nodes.

## Task 4.1.R2 — Retire the duplicated mechanisms
Delete or demote, with tests removed in the same commit:
- Bespoke approval suspend/resume mechanics → LangGraph `interrupt()`.
- Run/step status state machine → LangGraph graph state.
- `configuration_control.ts` template gating and `UnsupportedExecutableTemplateError`.
- `reference_automation.ts` / `reference_runtime*.ts` → becomes one example artifact.

Retain unchanged: `policy.ts`, `budget_reservation.ts`, `audit.ts`, `cost.ts`,
`compensation*.ts`, `tool_execution_gate.ts`, `model_execution.ts`,
`gcs_payload_store.ts`, `task_dispatch.ts`, `task_receiver.ts`,
`project_kill_switch.ts`, `webhook_trigger.ts`, `schedule_dispatcher.ts`.

Approval **routing projection** and the Console inbox survive — only the
suspend/resume mechanics are replaced.

## Task 4.1.R3 — Policy-gated tool binding
- Every tool a graph can call is wrapped so the Citadel policy gate,
  budget reservation and audit write happen before the tool executes, and the
  effect receipt is written after.
- A LangGraph node calling an unauthorized tool must fail closed with an audit
  event, not throw an unhandled error.
- Risky scope tags (write, external_comms, financial, destructive) raise a
  LangGraph `interrupt()` rather than a Citadel-specific suspend.

## Task 4.1.R4 — Engine hardening (carried from the pre-rewrite assessment)
- **Determinism guard**: lint rule plus CI replay-equivalence assertion. Nothing
  currently stops orchestrator code calling `Date.now()`/`Math.random()`.
- **Version gate**: refuse to resume a run whose orchestrator code version
  differs from the version pinned at run start, rather than replaying divergent
  logic. Config pinning already exists; code pinning does not.
- **Durable timers**: long waits via Cloud Tasks `scheduleTime` (supports up to
  30 days). Currently only event-driven suspend exists.
- Raise the Cloud Tasks queue from its current 5/sec, 10 concurrent once real
  traffic justifies it.

## Known scaling boundaries — record, do not fix prematurely
- Firestore sustains ~1 write/sec per document, so a **single run** is bounded to
  roughly 1–5 transitions/sec. Concurrent runs are unaffected.
- Cloud Run cold start ~1–3s on Node; sparse traffic pays it per dispatch.
- Escape hatch if step volume outgrows this: evaluate Restate self-hosted first,
  then Temporal. Flag cost before adopting. The trigger has not fired.

## Definition of done
- [ ] `@langchain/langgraph-checkpoint-validation` passes against the Firestore checkpointer
- [ ] A LangGraph artifact survives forced crash mid-graph and resumes at the exact superstep
- [ ] `interrupt()` holds ≥48h with zero compute cost and resumes from the Console
- [ ] Every tool call is policy-gated, budget-reserved and audited before execution
- [ ] Duplicate dispatch proven idempotent under forced double-delivery
- [ ] Audit trail reconstructs a full run without application logs
- [ ] Cost records within ±2% of provider-reported usage; budget hard-stop fires in test
- [ ] Determinism guard, version gate and durable timers are implemented and tested
- [ ] Deleted modules are gone with their tests, not left dead
- [ ] `terraform validate` passes; all resources tagged
