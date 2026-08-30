# Exigence + Palisade Phase Plan
Written 14/08/26. Handoff document — assume the reader has not seen the
conversation that produced it.

## How to use this document
Read in this order before touching code:
1. `AGENTS.md` — workflow, hard rules, sub-agent tiers
2. `DECISIONS.md` **14/08/26 section** — reverses several previously settled
   decisions; earlier entries may contradict it and lose
3. `CURRENT_TASK.md` — current phase and its definition of done
4. This document
5. The feature file for the phase you are starting

Every phase below has an acceptance gate. Do not start the next phase until the
current gate passes. Report honestly if a gate fails — a failed gate stated
plainly is worth more than a passed checkbox that isn't true.

## Ground truth, verified 14/08/26
Verified against the live `citadel-platform` project and the repository, not
against the tracking documents, which were stale.

| Fact | Evidence |
|---|---|
| Exigence runtime is 43 TS modules, 146 tests, 12 emulator integrations | `citadel_core/exigence` |
| Feature 4.2 is code-complete, including webhooks, schedules, config API, Console, CLI | commits `28e2321`, `7921594`, `7322749` |
| Deployed image is commit `27ce195`, predating the operator API (`9742d9c`) | digest `sha256:7493fe4c…` |
| Platform API has no Exigence env vars | six env vars, all ARM |
| Task target URL is `https://citadel.invalid/v1/tasks` | Cloud Run env |
| Zero Cloud Scheduler jobs exist | `gcloud scheduler jobs list` |
| No Exigence run has ever executed in production | `_dev/test_status.md` |
| No GCP Organization; 15 loose projects | `gcloud organizations list` |
| Billing account: `01CE01-2F5F0F-99D522` (OBSVSN Sauron External) | `gcloud billing` |

## What Citadel is — read this before designing anything
Citadel is an **internal delivery platform for a solo operator** serving small
and independent businesses. The operator is the only author of executable logic.
Clients get scoped Console access to their own results, telemetry and invoices.

This invalidates any design that protects the runtime from untrusted authors.
There are no untrusted authors. Several earlier decisions optimised for a threat
model that does not exist; they are reversed in `DECISIONS.md` 14/08/26.

---

# Phase R — Repair (prerequisite for everything)

**Goal:** the existing stack actually runs in production.
**Feature files:** none — this is remediation.
**Detail:** see `CURRENT_TASK.md`, which owns the task breakdown.

**Acceptance gate:** one real end-to-end run with live Vertex inference —
trigger → model call → approval → resume → effect receipt → cost settlement →
verified audit chain — plus zero Terraform drift.

Nothing below starts until this passes. Phase R is small (roughly a day) and it
de-risks every later phase by proving the substrate executes at all.

---

# Phase 1 — LangGraph runtime rewrite ‖ Palisade IAM

These two run in parallel; Phase 2 needs both.

## 1A — LangGraph runtime rewrite
**Feature file:** `_dev/features/04-01-exigence-automation-runtime.md`

Order matters:
1. **Write the superstep↔activity mapping doc first** into `_dev/docs/`.
   This is the hardest design task in the plan. Do not start coding the
   checkpointer until the mapping is written down and reviewed.
2. Implement the Firestore `BaseCheckpointSaver`.
3. Pass `@langchain/langgraph-checkpoint-validation`. This is the gate — do not
   substitute hand-written equivalents.
4. Wrap tool binding with the existing policy gate, budget reservation and audit.
5. Delete the duplicated mechanisms (4.1.R2), tests included, in the same commits.
6. Engine hardening (4.1.R4): determinism guard, version gate, durable timers.
7. OTel GenAI semconv field map — pulled forward from Feature 4.3 because the
   schema is soft now and frozen once client runs exist.

**Watch for:** LangGraph JS trails Python, notably on HITL resume
(langchain-ai/langgraphjs#1308). If `interrupt()`/resume proves unworkable in JS,
that is a genuine escalation to the operator, not something to work around
silently — it was chosen with the risk known.

**Acceptance gate:** conformance suite passes; a LangGraph artifact survives
forced crash mid-graph and resumes at the exact superstep; `interrupt()` holds
≥48h at zero compute and resumes from the Console; deleted modules are gone.

## 1B — Palisade IAM
**Feature file:** `_dev/features/06-01-palisade-iam.md`

1. Extract the authorization model already learned in ARM and Exigence.
2. Build identities, permissions, boundaries, roles.
3. Resolved-effective-authority view — this is the intuitiveness requirement and
   the main thing separating Palisade from cloud IAM.
4. Migrate Exigence's policy kernel and ARM's role resolution to consume it.

**Acceptance gate:** existing ARM and Exigence access resolves **identically**
before and after migration, proven by test. Behaviour-preserving migration is
non-negotiable — a security refactor that changes behaviour silently is worse
than no refactor.

---

# Phase 2 — Artifacts and the local runner
**Feature file:** `_dev/features/04-05-exigence-artifacts-and-local-runner.md`
**Depends on:** 1A and 1B.

1. Artifact model and the four types on one substrate.
2. Artifacts page with per-type tables and hyperlinked IAM.
3. Multi-step configuration flow with progression-blocking realtime validation.
4. Per-client Cloud Run deployment via Terraform (one image, N digest-pinned services).
5. **Local runner** — the operator's stated key differentiator. Node CLI on npm
   with per-resource Data Handling policy: no access, in-situ processing,
   Citadel-only relay, or allowlisted third-party relay. Durable HTTPS commands
   and an optional live WebSocket overlay support browser/computer use without
   an inbound client-machine port.

**Isolation is the risk in this phase.** Client workloads and data use the
per-client project boundary decided on 25/08/26, plus dedicated service
accounts and Palisade authority. Treat cross-client leakage as the top-severity
defect class and test it adversarially, not incidentally.

**Acceptance gate:** an artifact reads and writes a local file, drives Chrome,
and structurally edits an `.xlsx` on a real client machine — with the mode
recorded in the journal, and the runner refusing a path outside its Effect
Boundary even when the cloud instructs it. Plus: one client's service account
provably cannot read another client's data.

---

# Phase 3 — Knowledge Base
**Feature file:** `_dev/features/04-04-exigence-knowledge-base.md`
**Depends on:** Phase 1 (retrieval tool needs the policy gate), Phase 2 (local
folder ingestion needs the runner).

**Design around Drive OAuth staying in Testing status.** Refresh tokens are
revoked after 7 days and the test-user list caps at 100 (both verified
14/08/26). Prefer ingesting a synced Drive folder through the local runner — no
OAuth, no expiry, no cap — over browser OAuth. Expired consent must render as
"reauthorization required", never as a silently stale corpus.

**Acceptance gate:** four source types ingest and index; the per-row toggle
adds and removes vectors; re-fetching unchanged content does not re-embed or
re-charge; a LangGraph artifact retrieves through the policy gate; a
prefix-less query against in-project client data fails closed.

---

# Phase 4 — Billing
**Feature file:** `_dev/features/04-06-exigence-billing.md`
**Depends on:** Phase 2.

**BigQuery is deferred, not adopted** (DECISIONS.md 14/08/26). It was permitted
to buy per-client attribution from per-project billing; the single-project
decision removed that benefit, so it would now add a pipeline and a standing
cost for platform totals the billing console already shows. Do not build it.
**Self-metering is the only attribution source** — validate it against one full
month's real invoice before issuing any client invoice.

**Acceptance gate:** an execution's itemised component costs sum to its total;
rollups are correct execution → artifact → client → month; metered totals
reconcile against the real invoice with a stored variance factor; an invoice
issues, pays through Stripe, and status returns; duplicate webhook delivery does
not double-record.

---

# Phase 5 — Executions, observability, Watchdog
**Feature files:** `04-02` (Executions), `04-03` (observability),
`06-02` (Watchdog)

1. **Shared telemetry package first.** Extract into `citadel_core` so ARM Console
   and Exigence Executions share one schema and one widget set. Build the shared
   package before either consumer. Where functionality overlaps, one
   implementation — this is an explicit no-drift requirement.
2. Executions views (4.2.1) on the shared package.
3. Trace views (4.3.2) — the semconv field map already exists from Phase 1A.
4. Watchdog across Citadel data flows: external attack signals, leakage,
   policy drift, and complete ingress/egress visibility (6.2).

---

# Phase 6 — Evals
**Feature file:** `04-03`, Task 4.3.3

Structurally blocked until artifacts have production traffic — the dataset model
seeds from real consented runs, and there are currently zero. Do not start this
early; there is nothing to seed from.

---

# Standing rules for this plan

- **Never fabricate data.** Hard rule #1. Every live-data element shows real data
  or an honest "no data" / "not configured" state, including in tests and debug.
- **Terraform for every GCP resource.** No `gcloud create`/`delete`.
- **No secrets in files.** Secret Manager references only.
- **No BigQuery.** The 14/08/26 permission for billing export was superseded the
  same day by the single-project decision, which removed its justification.
- **Per-client data boundary.** Platform control data stays in
  `citadel-platform`; client workload data and provisioned resources use the
  per-client project boundary decided on 25/08/26, with dedicated identities
  and Palisade authority. Cross-client leakage remains the top-severity defect
  class.
- **Gates before commit:** `flutter analyze` zero warnings; `terraform validate`
  passes; tests written or updated for changed code.
- **Log every session** to `_dev/session_log.md` in the `AGENTS.md` format, and
  update `_dev/test_status.md` when test status changes.
- **Unsettled architecture goes to `DECISIONS_NEEDED.md`**, and you continue with
  unblocked work. Do not invent architecture.
- **Ground third-party APIs.** Never use an external API without evidence it
  exists as described. Verify against current documentation.

## Verified external facts used in this plan
Re-verify if significant time has passed.

- `@langchain/langgraph-checkpoint` v1.0.0 exposes `BaseCheckpointSaver` with
  `.put`, `.putWrites`, `.getTuple`, `.list`.
- `@langchain/langgraph-checkpoint-validation` is an official conformance suite.
- Official checkpointers exist for Postgres, SQLite, Redis, MongoDB — all
  requiring always-on infrastructure. None for Firestore.
- LangGraph HITL is `interrupt()` + `Command(resume=…)`, requiring a checkpointer
  and a stable `thread_id`.
- Firestore vector search: `findNearest`, max 2048 dimensions, max 1000 documents
  returned, Node client supported, one read charged per 100 index entries scanned
  plus document reads for results.
- Google OAuth in **Testing** publishing status with External user type: refresh
  tokens revoked after 7 days, test-user allowlist capped at 100. Internal
  (Workspace-only) apps are exempt from both, but Internal cannot authorize
  client accounts outside the operator's Workspace.
- Google Drive scopes are *sensitive* (review required), not *restricted* (paid
  third-party assessment required).
