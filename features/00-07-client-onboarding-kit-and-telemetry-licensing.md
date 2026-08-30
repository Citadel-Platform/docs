# Feature 0.7 — Client Onboarding Kit and Telemetry Licensing (NEW)

## Status
Active after CLI `83e7f86` and Core `df68474`. Manifest,
deterministic planning, registry/API/Firestore/Storage/access read observations,
cross-project IAM observation, and a deny-by-default customer-rules foundation
are complete. Active Firestore/Storage Rules release observation is also
complete. IAM Terraform rendering, protected remote state, confirmed planning,
and reviewed saved-plan apply are complete, while rules deployment is gated on
server replacements for direct client paths. Onboarding
automation, retention enforcement, licensing export, and Console surfaces remain.

### 18/07/26 manifest foundation
- `citadel_cli` owns the independently versioned operator workflow.
- Schema `v1` is strict YAML with JSON-compatible values and Freezed value
  models. It captures the specified identifiers, Firebase Secret Manager config
  reference, service flags, roles, retention classes, alert defaults, budget
  caps, and licensing contract.
- Credential-like fields accept only full Secret Manager version resources;
  inline secrets, API keys, tokens, passwords, webhooks, and credentials are
  rejected with exact manifest paths.
- `project validate --manifest` performs local validation and `project onboard
  --manifest` emits an explicit dry-run summary. Neither command mutates cloud
  resources or runs Terraform yet.
- The planner covers registry, APIs, Firestore, Storage, rules, access, IAM,
  alerting, reporting schedules, and Terraform in stable order. Unknown required
  observations block the plan; disabled-service capabilities are explicitly not
  applicable; observed drift becomes a required change.
- `project onboard` renders the local no-observations plan and states that no
  live readiness checks ran. Next: read-only registry and API observations,
  followed by rules, storage, IAM, and Terraform-backed reconciliation.
- Normalized registry and required-API observation contracts distinguish an
  unavailable or permission-denied source from a successful missing result.
  Comparisons produce stable exact evidence and feed the planner without using
  preview registry seeds or inferring a required API set. This slice is committed
  as CLI `7977057`.
- The registry transport/schema and Service Usage policy decisions are settled
  in `DECISIONS.md`.
- The recommended live-source decisions are approved. The CLI now performs only
  `gcloud services list --enabled` against the manifest Firebase project,
  compares the explicit five-service baseline, preserves permission/source
  failures as unknown, supports `--offline`, and renders evidence into the plan.
  This slice is committed as CLI `438bbc1`.
- The real `citadel-platform` project has all five baseline APIs enabled. The
  Platform REST registry client is complete as CLI `e0b2b27`; preview registry
  seeds remain prohibited as live evidence.
- Default Firestore database observation now uses only the read-only gcloud
  describe command. A nonempty resource is satisfied, authoritative not-found
  is drift, and permission/source/malformed-output failures remain unknown. The
  real `citadel-platform` default database exists; the example customer target
  remains truthfully permission-blocked. This slice is committed as CLI
  `6d283df`.
- Shared project/access resource and JSON contracts are Core `25ba440`. Storage
  identity/readiness is complete as CLI `6e7526c`.
- Project access consistency is complete as CLI `c73e77d`. The read-only client
  calls the exact access resource, compares manifest roles with both the project
  projection and per-email index evidence, detects stale indexes, and preserves
  unavailable or denied sources as unknown rather than false drift.
- The composable customer-rules foundation is Core `df68474`. It renders stable
  ARM/Conduit Firestore collection boundaries and Storage rules as an explicit
  client-denied server-only baseline, refuses undefined Exigence rules, and is
  covered by unit tests plus isolated Firestore/Storage emulator startup.
- Server-only access is settled as CLI `5a27760`: one validated non-secret
  manifest service account receives a deduplicated project-level Datastore User
  grant for ARM/Conduit and bucket-level Storage Object User for ARM. Exact
  read-only gcloud IAM policy checks classify missing unconditional bindings as
  drift and denied/malformed sources as unknown. Exigence remains undefined.
- No IAM or rules mutation ran. Deny-all rule deployment remains gated until
  server ingress and query APIs replace active ARM/Conduit client operations.
- Active Rules release observation is complete as CLI `1092431`. It reads the
  exact Firestore and optional bucket Storage release/ruleset chains from the
  fixed Firebase Rules API, compares their single-file source with Core's
  assembled source, preserves denied/malformed/unavailable reads as unknown,
  and adds `firebaserules.googleapis.com` to the six-service baseline. Analysis
  is clean, all 122 tests pass, and no ruleset or release was changed.
- Review-only IAM Terraform rendering is complete as CLI `e5831ca`. The nested
  command requires an explicit manifest and new output directory, derives only
  additive ARM/Conduit IAM member resources from the canonical requirement
  builder, refuses undefined Exigence grants, and atomically refuses overwrite.
  It has no backend, plan/apply execution, rules, API/resource creation, or
  registry mutation. Analysis is clean, all 134 tests pass, native compilation
  succeeds, and a real output formats and validates with Terraform 1.15.8 and
  Google provider 7.40.0. No Cloud or Firebase resource was changed.
- The Terraform state boundary is complete as CLI `1436b22`. A one-resource
  bootstrap created the private, versioned, labeled, deletion-protected
  `citadel-platform-terraform-state` bucket with 30-day soft delete, then
  migrated its state to locked prefix `bootstrap/state-bucket`. Customer
  modules now render a partial GCS backend and isolated
  `customers/{projectId}/iam` configuration. The locked post-migration plan is
  empty, live bucket settings match, all 134 tests pass, and documentation
  distinguishes normal operation from one-time bootstrap and recovery.
- Confirmed plan-only execution is complete as CLI `67fda57`. The CLI requires
  exact project confirmation, verifies every rendered file, rejects Terraform
  source injection and existing plans, and runs only bounded init/plan/show
  commands. All 149 tests pass; no customer plan or apply was run live.
- Saved-plan integrity and explicit apply are complete as CLI `83e7f86`.
  Planning atomically records SHA-256 bindings for the complete semantic
  manifest, rendered bundle, plan bytes, project, and exact action summary.
  Apply separately confirms the project, rejects any mismatch before mutation,
  invokes only the reviewed saved plan, requires a zero-drift follow-up plan,
  and writes a replay-prevention receipt. All 161 tests pass and native
  compilation succeeds; no live customer plan, IAM mutation, or Rules
  deployment ran.
- The customer server-path audit is recorded in
  `_dev/docs/customer_server_path_audit.md`. It identifies direct ARM issue/case
  reads and status mutations plus all Conduit analytics/replay customer
  Firestore reads and funnel/session mutations. Conduit `4e66198` now prevents
  the public SDK project key from authorizing session search, replay retrieval,
  session metadata changes, or heatmap queries: those routes fail closed unless
  a host injects an operator authorizer. The Platform-to-product identity
  topology remains the decision required before console migration.

## Scope
Compress new-client onboarding to ≤2 working days of operator effort, and make data governance (retention, PDPA posture, research-telemetry licensing) contractual plumbing that is configured once at onboarding and enforced by the platform thereafter. This is the prerequisite for scaling beyond client #1 and precedes Exigence work in the priority ladder (Feature 0.0).

## Context
Onboarding today is manual scripts plus tribal knowledge (prepare_monitored_projects.dart, check_arm_firebase_config.sh, bootstrap_console_firestore.mjs). Each new engagement must stamp out: monitored-project preparation, registry entry, roles, alert/report defaults, retention, and the signed data-usage terms. The licensing pipeline exists so anonymised operational telemetry can be legitimately exported for the operator's research programme — strictly opt-in per contract, PDPA-conscious, with opt-out honoured mechanically, not procedurally.

## Tasks

### Task 0.7.1 — Project configuration contract
- One YAML/JSON manifest per client project capturing: identifiers, environment, Firebase client config reference, enabled services (ARM/Conduit/Exigence), roles (developer/viewer emails), retention periods per data class (cases, screenshots, snapshots, Conduit events, reports, Exigence journals/traces), alert defaults, budget caps, and the licensing block (researchLicense: granted/denied, scope, anonymisation profile, effective date, contract reference).
- The Platform API/registry stores intended project configuration; the Console
  drives onboarding and re-checks drift against live provider state.
- The existing YAML/JSON manifest remains an import/export and CLI parity
  format, not the operator's required control surface.

### Task 0.7.2 — Onboarding automation
- Consolidate existing helper scripts behind Platform API/provisioner
  operations driven from the Console: Firebase/GCP API checks,
  Firestore/Storage offers, rules, registry/access, alerting and schedules.
  Each step is confirm-before-change, resumable and idempotent; the CLI may call
  the same operations for parity and diagnostics.
- Produce an onboarding report artefact (what was created/verified, with links) stored in the client project — doubles as the client-facing setup deliverable.

### Task 0.7.3 — Retention enforcement
- Scheduled Cloud Function per project applies the manifest's retention: deletes/expires cases, screenshots, snapshots, events, reports past their windows (GCS lifecycle rules where possible — cheapest path — Firestore TTL policies where supported, batch deletes otherwise).
- Every purge run logs a summary AuditEvent; Console shows retention status per data class.

### Task 0.7.4 — Research telemetry licensing pipeline
- Export job (scheduled, per project, only when researchLicense = granted): reads consented data classes, applies the anonymisation profile — strip identifiers, hash user/session ids with per-project salt, drop free-text fields unless explicitly whitelisted, coarsen timestamps — and writes to a Citadel-owned research GCS bucket, versioned, with a manifest of source project (pseudonymised), window, schema version.
- Opt-out is mechanical: flipping the manifest to denied disables the job and (on request) tombstones prior exports for that project.
- _dev/docs: a short data-map + DPIA-lite template per project (what is collected, purpose, retention, sharing) that can be attached to client contracts. [OPEN: confirm final contract clause wording with the operator before first export runs.]

### Task 0.7.5 — Console surfaces
- Project settings page: editable retention/licensing configuration, complete
  onboarding workflow, observed-state evidence, drift and repair actions.
- Contractual changes require explicit review/confirmation and audit through
  the Platform API; they do not require leaving the Console for a manifest/CLI.

## Definition of done
- [ ] A fresh test project onboards end-to-end from manifest in ≤2 hours of wall-clock operator time
- [ ] Drift validation catches a manually broken registry entry and a missing API in test
- [ ] Retention purge verified per data class on emulator + one live test project; purge audit visible in Console
- [ ] Licensing export produces anonymised output that passes a re-identification spot check (no raw ids, no unwhitelisted free text); denied flag provably halts exports
- [ ] Existing helper scripts marked deprecated in favour of CLI flow; docs updated
- [ ] A fresh project is fully onboarded and drift-repaired from the Console without CLI/manual scripts
