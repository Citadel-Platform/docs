# Feature 4.5 — Exigence Artifacts and Local Runner (NEW 14/08/26)

## Scope
Artifacts are the unit of work in Exigence: operator-authored LangGraph graphs
that execute in a governed environment, with identity, permissions, autonomy
boundaries, logging and billing attached. This feature covers the artifact
model, the Console pages, and the local runner that gives artifacts governed
reach into a client's own machine, applications, Citadel services, and
allowlisted third-party providers under per-resource Data Handling policy.

Depends on Feature 4.1 (runtime) and Feature 6.1 (Palisade).

## Task 4.5.1 — Artifact model and types
Four types, one execution substrate, presented as separate tables on one page:

| Type | Trigger | Distinguishing property |
|---|---|---|
| Job | manual, one-off | runs to completion, no schedule |
| Workflow | event or webhook | deterministic graph, fixed path |
| Automation | schedule (cron) | recurring, paused-by-default |
| Agent | any | dynamic tool selection, bounded by max steps and budget |

Every artifact carries: definition version and content digest, owning project,
Palisade identity, granted roles, tool allowlist, autonomy boundaries, budget
cap, and enabled state.

## Task 4.5.2 — Artifacts page
- One page, one table per type, standard `citadel_table.dart`.
- Columns: name, type, trigger, enabled, last run status, MTD cost.
- **IAM is hyperlinked** to the artifact's Palisade identity; the detail page
  shows the resolved permissions and boundaries inline, not just a link.
- Detail page: definition digest, version history, recent runs, cost rollup,
  schedule/webhook configuration, and the resolved policy.

## Task 4.5.3 — Configuration flow
A multi-step form modelled on GCP's VM creation flow, with **realtime
validation gating progression** — a step cannot be advanced past while invalid.

Steps: identity and project → trigger → tools and permissions → autonomy
boundaries → budget → review. The review step shows the exact resolved
configuration that will be pinned at run start.

This configures *operation and authority*. It does not author graph logic —
that lives in the repository.

## Task 4.5.4 — Deployment
- One image contains all artifacts; artifacts self-register at boot with their
  content digest.
- Deployed as one Cloud Run service per client **within the shared
  `citadel-platform` project** (DECISIONS.md 14/08/26), each digest-pinned and
  configured with that client's data prefix, identity and enabled-artifact set.
- Every per-client service carries a mandatory `client` label so the compute
  portion of spend is attributable in billing data (Feature 4.6).
- Each client's service runs under its **own service account** with access
  scoped to that client's data only. With no project boundary between clients,
  the service account is the enforcement point — do not share one runtime
  identity across clients.
- Terraform-owned. A new client is a new service instance, not a new pipeline.

## Task 4.5.5 — Local runner
A cross-platform Node CLI/SDK distributed by npm, installed by the operator
during onboarding. No GUI installer, no code signing.

- **Per-resource handling, one runner**: Palisade decides whether each matched
  resource is `noAccess`, processed in situ, relayed only to an allowlisted
  Citadel destination, or relayed to an allowlisted third party. Machine state
  never bypasses the resource policy.
- **Transport**: authenticated outbound HTTPS long-polling owns durable command
  delivery, leases, acknowledgements, and replay. An outbound WebSocket is an
  optional lossy, low-latency overlay for live browser/computer-use frames. No
  SME router needs an inbound port.
- **Tooling**: filesystem, browser driving and computer use via Chrome/CDP,
  Office via OOXML manipulation, local databases. Where a maintained MCP
  server already exists, host it rather than writing an adapter - this is a
  per-tool library choice, not a platform commitment.
- **Execution modes** declared per tool in order: `structured` → `assisted`
  (CDP/UI Automation) → `visual` (last resort). Fallback is opt-in per tool per
  artifact and never silent. The journal records the mode that actually
  executed. A `visual` execution is recorded as an irreversible effect and is
  approval-gated by default.
- **Boundaries enforced locally for every mode**: the runner independently
  enforces Palisade Access, Effect, and Data Handling Boundaries immediately
  before processing or movement. There is no machine-wide relay bypass.
- **Credentials**: OS keychain. Never in a config file.
- **Evidence and data-flow audit**: executions journal to the client project's
  Firestore. Relay additionally records what data classes moved, in
  which direction, byte counts, actor, authority and destination; secrets and
  raw sensitive values are not copied into the audit event.

## Task 4.5.6 — Manifold tools
External channel ownership moves to Manifold (Features 7.1-7.2). Exigence
contributes governed tools for searching conversations, drafting/responding and
triggering channel actions; it does not own provider credentials, consent,
threading or delivery state.

## Definition of done

Status as of 18/08/26. Anything ticked was verified against deployed
infrastructure, not only in tests — every item below that reads "verified" was
run, and several were only found to be broken that way.

- [x] All four artifact types run on one substrate with per-type tables
  - The substrate is real: runs route to a graph by the definition they name,
    and an image asked for an artifact it does not implement refuses rather
    than substituting one. Two artifacts exist (`exigence.reference.summary`,
    `exigence.local.report`); the remaining types are configuration of the same
    substrate, not new machinery.
- [x] Multi-step configuration blocks progression on invalid input at every step
- [x] Artifact IAM is hyperlinked and resolved permissions/boundaries render on the detail page
- [x] One image deploys as per-client digest-pinned, `client`-labelled Cloud Run services via Terraform
  - Three services run the same digest: `citadel-exigence-runtime`,
    `citadel-exig-sandbox-runtime`, `citadel-local-sandbox-runtime`.
- [x] Each client's service account can reach that client's data and no other client's
  - `roles/datastore.user` is conditioned per database and was proven in both
    directions by impersonating each service account.
- [x] The runner installs by npm on macOS, Windows and Linux with no signing warning
  - Published as `@citadel-platform/localbridge`; 0.4.0 installed from the
    registry and driven on macOS.
- [x] An artifact reads and writes a local file, drives Chrome, and edits an .xlsx structurally
  - Verified end to end on 18/08/26: `exigence.local.report` on the deployed
    `citadel-local-sandbox-runtime` read a file, drove Chrome over CDP, and
    appended a row to a real workbook, which was checked by reading the OOXML
    rather than trusting the run's own report.
- [x] Mode fallback is recorded in the journal and a `visual` effect is marked irreversible and approval-gated
  - `structured` and `assisted` both recorded from real executions. `visual` is
    implemented for browser clicks, marked irreversible on the evidence itself,
    and the queue refuses to dispatch work that may reach it without an
    approval to point at.
- [x] The runner refuses a path outside its Effect Boundary even when the cloud instructs it
  - Tested in four directions against the demo sandbox: inside allowed, a
    denied subdirectory refused, outside refused, and `..` refused.
- [x] Guarded mode does not transmit file content where evidence suffices
  - Reads return a digest and size unless the intent explicitly asks for
    content; screenshots never leave the machine at all, only their hash.
- [x] Manifold WhatsApp tools deliver and are policy-gated as `external_comms`
  - Gating is done: `channel.send` declares `external_comms`, holds for a
    person, and is refused an undo because a sent message cannot have one.
    Delivery is unproven until a WhatsApp provider is grounded and configured.

### Known gaps

- No artifact declares `channel.send` yet, so the channel is reachable by
  configuration but nothing is configured to use it.
- The local artifact's paths are per-deployment published configuration. A
  client with several machines, or several sets of paths, needs more than one
  published definition today.
- Data Handling Boundary persistence/UI and the durable command/live-stream
  protocol remain implementation work under the 27/08/26 decision.
