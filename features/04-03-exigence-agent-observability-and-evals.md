# Feature 4.3 — Exigence Agent Observability and Evals

> AMENDED 14/08/26. Three changes:
> 1. **No drift with ARM.** Executions telemetry is extracted into a shared
>    package in `citadel_core` — one schema, one widget set — consumed by both
>    the ARM Console and the Exigence Executions pages. Where functionality
>    overlaps, there is one implementation. Build the shared package before
>    either consumer's views.
> 2. **Task 4.3.1 pulls forward.** The OTel GenAI semconv field mapping is
>    cheap now while the schema is soft and expensive once client runs exist.
>    Do the field map with the Feature 4.1 rewrite, not after.
> 3. **Task 4.3.3 (evals) stays last.** It seeds datasets from real consented
>    runs, of which there are currently zero. It is structurally blocked until
>    artifacts have production traffic.
>
> Spans map to LangGraph nodes rather than to a bespoke step model.

## Scope
Trace, evaluate, and report on Exigence automations to Langfuse/LangSmith-class capability, differentiated by OpenTelemetry GenAI semantic-convention alignment, client-owned data plane, and audit-grade linkage to the runtime journal. Depends on Features 4.1–4.2.

## Context
The LLM-observability category is consolidating into platforms; portability via OTel GenAI conventions is the survival trait for independents, and 60%+ of teams are expected to adopt AI eval/observability tooling by 2028. Citadel's edge is not another dashboard — it is that traces, approvals, audits and costs are one linked record, stored in the client's own project.

## Tasks

### Task 4.3.1 — OTel GenAI-aligned trace model
- Trace schema mapping 1:1 to GenAI semantic conventions: invoke_agent / invoke_workflow / execute_tool / model-call spans with standard attributes (model, tokens in/out, cost, tool name, error type).
- Persist spans in the client project's Firestore keyed under the run; span IDs cross-link to journal stepIds and AuditEvents (one click from "what happened" to "who approved it").
- Provide an optional OTLP exporter (Cloud Run sidecar-less, batch) so a client or the operator can mirror spans to any OTel backend without schema migration.

### Task 4.3.2 — Console trace views
- Waterfall/tree view per run; multi-turn conversation view for chat-style automations; error and retry annotations; token/cost heat per span.
- Aggregates per automation: p50/p95 latency, failure rate by tool, cost per successful outcome, approval-cycle time.

### Task 4.3.3 — Eval harness v1
- Dataset model: curated input/expected-output cases per automation, seeded from real (consented) runs; golden-set pinning.
- Offline eval run: execute definition against dataset in dry-run mode (tools mocked or sandbox-flagged), score with rule-based checks + LLM-as-judge (provider-abstracted), store scores with dataset/version/model provenance.
- Regression gate: an automation definition or prompt change can require eval pass ≥ threshold before enable — mirrors the platform's analyze/test gating culture.

### Task 4.3.4 — Guardrails hooks
- Pre/post step hooks: PII pattern screening on outbound payloads, output-schema validation, configurable blocked-action rules; violations create AuditEvents and can force approval escalation instead of hard failure.

## Definition of done
- [x] Every demo-run span validates against the GenAI semconv field map
      (documented table in `_dev/docs/otel_genai_field_map.md`) — the map came
      first (15/08/26) and `src/trace_span.ts` emits against it (30/08/26),
      with tests that fail if `gen_ai.system` returns or if money appears under
      a `gen_ai.*` key.
- [x] Trace ↔ journal ↔ audit cross-links navigable in Console both directions
      — a trace row links to the audit event that authorised it, and the audit
      page names the event a trace sent the operator to read.
- [ ] Eval run produces stored, versioned scores; regression gate blocks a
      deliberately degraded prompt in test — **structurally blocked** (Task
      4.3.3): datasets seed from real consented runs, of which there are zero.
- [~] OTLP mirror — the exporter is written and tested (`src/trace_otlp.ts`):
      stored spans go out as OTLP/HTTP JSON, batched, per-project opt-in, with
      no endpoint by default. It is a copy and cannot fail a run; a collector
      that is down costs a counted dropped batch. **Not yet verified against a
      real external backend**, which is what the tick waits on — and what a
      test against a fake collector cannot stand in for.
- [x] No client evidence data leaves the client project by default; mirror is
      per-project opt-in config — spans are stored in the client's own
      Firestore beside the journal, and there is no exporter to leave by.

**Also fixed here:** every model and tool span named a parent `invoke_agent`
span that nothing emitted, so a trace arrived at any backend as a set of
orphans pointing at an id resolving to nothing. `GraphProjectionRecorder` now
writes the run span when a run succeeds or fails — after the journal
transition, never instead of it.

**Also delivered:** Task 4.3.4 guardrails, in `src/guardrails.ts` — pattern
screening on outbound payloads, output-shape checking against the tool's own
declared schema, and configurable blocked actions. A violation escalates to a
person and writes an audit event rather than failing the run, and a finding
never carries the value it found.

**Open:** Task 4.3.2's aggregates (p50/p95 latency, failure rate by tool, cost
per successful outcome, approval-cycle time) need runs to aggregate over. The
per-run trace view is built; the cross-run statistics are not.
