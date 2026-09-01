# Feature 0.0 — Sauron Directive: Re-Prioritisation and Competitive Posture

> **Read this file at the start of every session, immediately after AGENTS.md and CURRENT_TASK.md.** It supersedes prior sequencing where stated, and records deliberate reversals of earlier decisions. When a reversal below conflicts with DECISIONS.md or DECISIONS_NEEDED.md, this file wins; document the change in DECISIONS.md with a pointer back here.

## Why this exists
Citadel is not a generic SaaS bet. It is the instrumented delivery platform for WHS client engagements in the Singapore SME market, and a data/reps engine for the operator's research programme. Every feature must serve at least one of: (a) faster client onboarding and retention, (b) sellable compliance/ROI evidence (PSG/EDG/EDGE grant reporting, PDPA), (c) agent-operations capability with audit-grade safety, (d) telemetry that can be legitimately licensed for research. Features that serve none of these are deferred by default.

## Deliberate reversals (record in DECISIONS.md)
1. **Exigence is reactivated.** The earlier "leave Exigence without development" ruling is reversed. Exigence is now the strategic wedge: agent automations with human-in-the-loop approvals, audit logs, and cost telemetry are the highest-differentiation offering for 2026–27 SME clients. Features 4.1–4.3 (replaced/new specs in this folder) define the MVP.
2. **Baker is resumed in sequence, but its first slice stays light.** It is a
   superdev-only developer accelerator: Factory provides component kits,
   recipes and an agent context pack for rapid MVP bootstrapping; Devstation is
   a Console-operated, Terraform-provisioned development VM per client. It is
   not a public no-code product, manifest-driven designer or upgrade engine.
3. **Conduit settled decisions stand** (RepaintBoundary capture, app-authored custom events). New Conduit work is additive reporting (Feature 3.9), not capture-layer rework.

## Priority ladder (release sequencing after current v0.1 console pass)
1. **P1 — Finish and commit the v0.1 Platform Console UX pass** (already VERIFIED per CURRENT_TASK.md; commit, then Conduit visual alignment continues as scheduled).
2. **P2 — Feature 0.7: Client Onboarding Kit + Telemetry Licensing.** Onboarding must compress to ≤2 working days of operator effort; licensing/retention config is contractual plumbing that must exist before client #2 signs.
3. **P3 — Feature 1.4: ARM Alerting, SLOs and OTel alignment.** Retention driver: clients must be *notified*, not just able to look. Also the parity gap versus Sentry-class tools.
4. **P4 — Features 4.1 → 4.2 → 4.3: Exigence MVP** (runtime → console/SDK → observability+evals). Strict order; runtime first.
5. **P5 — Feature 3.9: Conduit ROI Reporting and Grant Evidence Exports.** Must land before the first grant-funded client's reporting milestone.
6. Everything else (heatmaps depth, VoC expansion) queues behind these.

## Competitive posture (what "competitive and exceeding" means, concretely)
- **vs Sentry/Crashlytics (ARM):** match — release health, alert rules, issue grouping; exceed — recovery snapshots of user-entered data, client-owned data plane (evidence never leaves the client's Firebase project), operator-embedded triage service.
- **vs PostHog/Amplitude (Conduit):** match — funnels, session replay, web analytics; exceed — grant-grade ROI/report exports mapped to PSG/EDG/EDGE evidence requirements; SME-priced.
- **vs Langfuse/LangSmith/AgentOps (Exigence observability):** match — traces, token/cost accounting, evals; exceed — OpenTelemetry GenAI semantic conventions natively (portability is the survival trait as the category consolidates), plus HITL approvals and append-only audit as first-class, not add-ons.
- **vs n8n/Zapier/Temporal-based shops (Exigence runtime):** match — durable, retryable workflows; exceed — typed tool permissions, approval gates, per-step cost telemetry, and client-boundary data residency, delivered as a managed service.
- **Structural differentiators (never trade away):** client-owned data plane; grant-literacy baked into reporting; PDPA-conscious defaults; every autonomous action idempotent, auditable, reversible.

## Standing guardrails (bind all features in this folder)
- Cheap-first GCP: Firestore, Cloud Run (scale-to-zero), Cloud Tasks, Cloud Scheduler, Cloud Functions, GCS. **No BigQuery, no generally always-on VMs, no managed Temporal/Kafka** without flagging cost to the operator first. Baker Devstations are the explicit VM exception and must expose stop/suspend and idle-cost controls.
- Customer evidence data stays in customer Firebase/GCP projects. Citadel-owned Firestore holds only registry, config, auth scopes, and pointers.
- The Console is the single control and observation plane. External systems
  remain authoritative for their live state, so the Console observes,
  reconciles and verifies them rather than merely mirroring intended config.
- Manual work is a temporary product gap, not a supported end state. When a
  provider requires a human step, the Console owns the guided workflow,
  context, validation and completion check.
- The end-state suite includes Manifold, the project-scoped omnichannel inbox
  joining ARM/Conduit context, Exigence action, Baker repair escalation and
  Palisade-governed data flow. It does not displace the priority ladder until a
  Manifold phase is scheduled.
- All new telemetry/trace schemas align to OpenTelemetry semantic conventions (GenAI conventions for Exigence) even where transport is Firestore documents — fields must map 1:1 so an OTel exporter can be added without schema migration.
- Important cross-system behaviour is accepted through functional,
  integration, E2E and browser tests where applicable; fabricated fixtures do
  not substitute for provider/runtime semantics.
- Firebase Auth (email/pwd + Google) everywhere; operator project provisioning is driven and verified through the Console, with CLI parity where useful; retention is configurable per project.
- Terraform for any GCP resource; tags mandatory; flutter analyze / terraform validate gates unchanged.

## Definition of done
Reviewed 30/08/26 against the tree. These are documentation and
structure checks from the planning reset; each is verified below rather than
assumed.

- [x] This file referenced from AGENTS.md session workflow — step 0 of the
      session workflow reads it before anything else, alongside the 14/08/26
      section of DECISIONS.md.
- [x] Reversals above recorded in DECISIONS.md with date and rationale — the
      14/08/26 entry, and the 26–30/08/26 entries that reverse parts of it in
      turn (Baker as a superdev-only Factory, Manifold replacing Intercom,
      per-resource Data Handling for the local runner).
- [x] Release plan in `_dev/docs/release_timeline.md` re-sequenced to the
      priority ladder.
- [x] Each feature file in this folder moved into `_dev/features/` (replacing same-named files where applicable)
