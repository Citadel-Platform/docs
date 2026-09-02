# Production push + full-platform test — runbook, decisions, findings

Started 01/09/26 by `claude-sonnet-5` on operator instruction: "push Citadel
into production, create a new client `test-sandbox` backed by
`learning-gcp-404803`, and make every feature work end to end."

---

## Phase 0 — DONE

- **All gates green.** `dart analyze` (14 pkgs) + `flutter analyze` clean;
  exigence `tsc --noEmit` clean; CLI 173, ARM svc 33, Conduit ingest 129,
  Palisade 48, Platform api 37, Platform server 436, provisioner 13,
  customer_rules 4, Console 418, exigence 795 (125 emulator-gated, not run).
- **Merged to `main` and pushed**, all six repos:
  - `citadel_platform` `4259191..f96e3ec`
  - `citadel-core` `4f0f101..d7d79bb` (incl. new commit: drop `conduit_alert_events` rules match)
  - `exigence` `0c18342..48f7a89`
  - `conduit` `a75e99f..89f77a3` (incl. new commit: geo seam + `conduit_alert_events` removal)
  - `ARM` `cc3ce32..145fdce`
  - `citadel-cli` already at `origin/main`
- **Auth path confirmed.** `_dev/scripts/mint_operator_id_token.sh` mints a
  real Firebase ID token; `GET /v1/workspace` on the deployed API returns 200
  with the operator's authority. Terminal → API → provisioner Job path works
  (last provisioner run 31/08, invoked by the API SA).

## What is actually deployed today

| Project | Service | Note |
|---|---|---|
| `citadel-platform` | `citadel-platform-api` (rev updated 31/08) | the front door |
| `citadel-platform` | `citadel-arm-evidence` | ARM intake |
| `citadel-platform` | job `citadel-provisioner` | builds client infra |
| `learning-gcp-404803` | `cit-demo-project-5ec5-runtime` | demo-project's Exigence runtime |

No Exigence runtime in `citadel-platform` (by design — client runtimes live in
the client project). **No Conduit service anywhere.** Console live at
`https://citadel-platform.web.app` / `https://citadel.obsivision.com`.

Operator (`obsidian.infinitum@gmail.com`) holds `roles/citadel.superdev` on
`axis-education` in the deployed registry. It holds **no grant on
`demo-project`** — `/v1/projects/demo-project/exigence/*` returns 403.

---

## DECISIONS — ANSWERED 01/09/26, proceeding

- **D1 = yes.** Build `citadel-conduit-ingest` as a public, key-authenticated
  Cloud Run service in `citadel-platform` (mirrors `citadel-arm-evidence`).
  New `modules/conduit` + wired into the `runtime` root.
- **D2 = yes, and mount MCP too.** Mount the signature-verified Manifold
  inbound webhooks AND the Exigence MCP endpoint. Use a simple bearer/shared-
  secret auth on MCP for the test pass.
- **D3 = yes.** Delete Firestore databases `demo-project`, `demo-sandbox`,
  `exigence-lab` in `learning-gcp-404803` (irreversible, no backup) after
  destroying `demo-project`'s runtime infra.
- **D4 = no — build it.** Author a real `templates/exigence-agent` Terraform
  template, provision a sample agent for `test-sandbox`, and exercise the agent
  machinery end to end.

**Standing instruction:** nothing in Citadel is to be left untested by the end.

## EXECUTION ORDER (working through this)

### Phase 1 — code fixes + prod deploy
- [x] **F-011** dead `exigence_service_url` fallback → `""`. In `runtime/main.tf`
      working tree; lands with the conduit agent's `runtime/main.tf` commit.
- [x] **F-004** `PUT /v1/projects/{id}/offering-scope/{offering}` — server
      (`PlatformOfferingScopeService`, field-mask, `platform.projects.update`
      gate, protected Exigence fields) + Console rewire. Committed & pushed:
      `citadel-core@20a8328`, `citadel-platform@44f8e86`. Server 443 tests (+7),
      Console 419 (+1).
- [~] **D1** — **another agent owns this.** `modules/conduit/*` + `cloudbuild.conduit.yaml`
      + `runtime` root wiring are in the working tree (not mine, not committed).
      Left alone. The `citadel_conduit_ingest` package still needs to read the
      env contract the module sets (`CONDUIT_HOSTED_SURVEY_SIGNING_SECRET`,
      rate limits, `CITADEL_PLATFORM_FIRESTORE_DATABASE`).
- [x] **D2** — **already built** in the merged code. `composeExecutableRuntime`
      mounts `createCitadelMcpHandler` on every private runtime (operator holds
      `run.invoker` → call it with `gcloud auth print-identity-token` = the
      "simple MCP" auth), and mounts `manifold.webhook` / `manifold.emailWebhook`
      when the runtime carries channels. The `exigence-runtime` module deploys a
      separate `allUsers` public receiver service when `manifold_enabled=true`.
      No code needed — Phase 3 exercises it.
- [x] **D4** — `templates/exigence-agent/` authored (Superharness agent runtime
      for a client; shares the client DB/bucket; `terraform validate` clean),
      provisioner `Dockerfile` copies the module in, `platform_provisioning_service.dart`
      has the `exigence-agent` entry, `tool/publish_superharness_configuration.ts`
      publishes the agent's config. Committed & pushed: `citadel-core@6ed8791`,
      `exigence@23eb1fa`. Server provisioning suite +3.
- [x] Build images (sonnet-5, tags `s5-<ts>`) — all four SUCCESS.
- [x] **`provisioner` root applied** against `citadel-platform` (`0 add, 1
      change, 0 destroy` — Job image + `CITADEL_TEMPLATE_DEFAULTS`). Committed
      `citadel-core@97a00f1`. The Job now carries the `exigence-agent` template.
      (Reverted an incidental provider lock bump 7.45→7.46 to keep roots in step.)
- [ ] **`runtime` root apply — conduit agent owns** (per operator, option 1).
      **Digests to put in `runtime/images.auto.tfvars`:**
      ```
      platform_api_image = us-central1-docker.pkg.dev/citadel-platform/citadel-platform-services/citadel-platform-api@sha256:c2dae58e5d0822eda587c75b62fc16ab6f653405fe62998452930a464ab89e7f
      arm_evidence_image = us-central1-docker.pkg.dev/citadel-platform/citadel-platform-services/citadel-arm-evidence@sha256:283555a607b22d28af82095c277b4c82a8286ffcc5d1e063fdaccebbb3e3e145
      ```
      **Keep the F-011 two lines** (`exigence_service_url` /
      `exigence_service_audience` = `""`) already in the working-tree
      `runtime/main.tf` alongside the conduit block. Pin the google provider to
      **7.45.0** (`terraform init -upgrade=false` or match the committed lock).
- [x] **`runtime` root applied by sonnet-5** (conduit agent had applied
      conduit-only with stale digests). API `00032-nbn` + ARM `00004` on the
      new images. Verified: `/v1/workspace` 200, `/alerts` 200 (**F-012 fixed**),
      offering-scope route live (**F-004**), `CITADEL_EXIGENCE_SERVICE_URL` env
      gone (**F-011**), CORS from web.app 204.
- [x] **F-013 / F-014 fixed and deployed** (`citadel-core@3b1ab24`). API
      **`00033-r2r`**, image `sha256:95f5be91…`. Verified in prod:
      `/palisade/anomalies` 200, `/palisade/deployment-drift` 200 (both were
      500).

**Phase 1 platform deploy — DONE** (Console excepted):
| Service | State |
|---|---|
| `citadel-platform-api` | `00033-r2r` — F-004, F-011, F-012, F-013, F-014 |
| `citadel-arm-evidence` | `00004` — tickets |
| `citadel-conduit-ingest` | live (conduit agent) |
| `citadel-provisioner` (Job) | new image — carries `exigence-agent` template |
| Console | blocked on `firebase login` |
- [ ] Console deploy — **blocked**: `firebase` CLI is logged in as
      `siddharth.chitikela@gmail.com` (no Firebase access to citadel-platform);
      ADC is `obsidian.infinitum` and the Firebase Mgmt API answers 200 for it,
      but `firebase-tools` won't use ADC while a stored login exists. Needs
      `firebase login` as obsidian, or a service-account key. Console bundle is
      built and ready at `citadel_platform/build/web/`.
- [ ] `production_e2e.sh` (repoint its stale URL first)

### Phase 2 — demo-project teardown is MOSTLY DONE ALREADY

Checked 01/09 after the runtime apply — `learning-gcp-404803` is already clean:
- **Firestore DBs `demo-project` / `demo-sandbox` / `exigence-lab`: gone** (D3
  already executed by the parallel effort — `gcloud firestore databases list`
  → 0 items).
- **`cit-demo-project-5ec5-runtime` + its bucket/queue/SAs: gone**
  (`provisioner/exigence-runtime/demo-project` state has 0 resources).
- **Still present:** `customers/demo-project/iam` state (3 IAM resources on
  `learning-gcp-404803` — the observer custom role + 2 member bindings), and
  the `demo-project` record in the Citadel registry (`platform_projects` +
  grants).

Remaining Phase 2:
- [x] Destroy `customers/demo-project/iam` (3 resources on learning-gcp)
- [x] Remove the `demo-project` registry record + grant (manual Firestore —
      `platform_projects/demo-project`, `palisade_grants/…|demo-project`)
- [x] **`test-sandbox` created + claimed** — `platform_projects/test-sandbox`
      written via Firestore (no `POST /v1/projects` route, F-017), then
      `POST /v1/projects/test-sandbox/grants/claim` → operator superdev.
      `learning-gcp-404803` GCP + Firebase project id; **no Firebase project
      exists on learning-gcp** (obsidian isn't owner; owner is
      siddharth.chitikela). ARM/Conduit data-plane needs Firebase added there.
- [x] Published `default` Data Handling / Access / Effect boundaries via API
      (F-018 — undocumented prerequisite, no tooling for Data Handling).
- [x] **`customers/test-sandbox/iam` applied** (`citadel-core@10b0cb0`) — ARM
      evidence `datastore.user` + inventory observer role **with the
      `getIamPolicy` fix** (F-014).
- [~] **Provisioning Exigence for `test-sandbox`** — plan `planned` (44
      resources, `manifold_enabled=true`), **apply in progress**. Note: the
      first provisioner Cloud Run Job execution hung 12 min in "Waiting for
      execution to start" then resolved after a cancel + retry (F-019 — Cloud
      Run Jobs execution stall; not code).
- [ ] Provision a sample Superharness agent (`exigence-agent` template + the
      publish tool)
- [ ] Enable ARM + Conduit for `test-sandbox`
- [ ] Clean stale state prefixes (`exigence/demo*`, `provisioner/exigence-runtime/
      {demo-sandbox,exigence-lab}`, `provisioner/exigence-agent/...`)

#### Built image digests (s5 session)
```
citadel-platform-api    sha256:c2dae58e5d0822eda587c75b62fc16ab6f653405fe62998452930a464ab89e7f
citadel-arm-evidence    sha256:283555a607b22d28af82095c277b4c82a8286ffcc5d1e063fdaccebbb3e3e145
citadel-provisioner     sha256:f583733a45628a3f1a8161e27875c866782c3b934ade4b217ccdbc93bd351082  (applied)
citadel-exigence/runtime sha256:d5d8f1d0a58624332a2fb8481f724d9a8b8ae606d0a94a1ddab03cde8540aa6d  (in provisioner defaults, applied)
```

#### Known follow-up cleanup (not blocking)
- `PlatformRegistryRepository.updateProjectOfferingScope` in
  `citadel_platform/lib/src/app/platform_firestore.dart` is now dead (the
  service-setup dialog calls the API instead). Left in place to avoid churn on
  the repo the conduit agent is editing; remove with its test stub later.
- `updateProjectSettings` still writes `offeringScope` from the browser. It
  works today because the settings form round-trips the loaded `runtimeUrl`, so
  `exigenceRuntimeUrlPreserved()` passes — but it should move to a
  `PUT /v1/projects/{id}/settings` route on the same principle as F-004.

### Phase 2 — decommission demo-project, stand up test-sandbox
- [ ] Destroy `provisioner/exigence-runtime/demo-project` state
- [ ] Destroy `customers/demo-project/iam`
- [ ] Delete Firestore DBs `demo-project`, `demo-sandbox`, `exigence-lab` (D3)
- [ ] Clean stale state prefixes
- [ ] Create `test-sandbox` (Console/API) + claim + connect Firebase
- [ ] Provision Exigence for `test-sandbox`
- [ ] `customers/test-sandbox/iam` boundary root
- [ ] Provision a sample agent (D4)
- [ ] Enable ARM + Conduit for `test-sandbox`

### Phase 3 — exercise every feature against `test-sandbox`
- [ ] Palisade, ARM (+tickets), Conduit, Exigence (runs/approvals/schedules/
      webhooks/KB/billing/localbridge/MCP), Manifold (lines/inbox/consent),
      Baker (catalogue/deployments/devstation), Watchdog (5 detectors + sweep +
      digest), Dashboard alert panel. Real resources, edge cases, concurrency.

---

## BLOCKING DECISIONS — (resolved; kept for context)

### D1. Conduit ingest has no deployment infrastructure
`citadel_conduit_ingest` has a `Dockerfile` and passes 129 tests, but there is
**no Terraform for it anywhere** and it has never been deployed. "Every feature
works" requires it running and receiving events. The repo does not say where it
goes. Options:
- **(a)** New Cloud Run service `citadel-conduit-ingest` in `citadel-platform`,
  public, key-authenticated per capture source (mirrors ARM evidence). I write
  a `modules/conduit` + wire it into the `runtime` root.
- **(b)** Per-client, provisioned like the Exigence runtime (new template).
- **(c)** Defer Conduit ingest; test everything else; Conduit stays "config
  only, no live ingest" as it is today.

→ **Which?** (a) is the smallest real build and matches how ARM works.

### D2. Unauthenticated inbound endpoints (Manifold + MCP)
For Manifold email (Svix webhook) and WhatsApp (Meta webhook) to *receive*, and
for the Exigence MCP endpoint to be reachable, unauthenticated HTTP surfaces
must be mounted. SITREP flags each as "a deployment decision, not wiring."
- Manifold email/WhatsApp inbound: mount on the client runtime? Signature-
  verified (Svix / Meta), so unauthenticated-but-verified.
- MCP endpoint: its caller-auth model (which run is calling) is an undecided
  seam.

→ **Mount the signature-verified Manifold webhooks? Leave MCP endpoint
unmounted (test MCP's three refusals only, which are already proven in prod)?**

### D3. Three Firestore databases to delete — irreversible, no backup
To repurpose `learning-gcp-404803` for `test-sandbox`:
- `projects/learning-gcp-404803/databases/demo-project` — demo-project's live
  control plane + all run/evidence data
- `projects/learning-gcp-404803/databases/demo-sandbox` — abandoned (open item)
- `projects/learning-gcp-404803/databases/exigence-lab` — abandoned (open item)

Deletion is `gcloud firestore databases update --no-delete-protection` then
`... delete`. **The Terraform template deliberately refuses to do this.**

→ **Confirm: delete all three.** (demo-project's runtime infra — Cloud Run,
queue, scheduler, SAs, bucket — I destroy via its provisioner state first.)

### D4. exigence-agent provisioning cannot be tested
`templates/exigence-agent/` is an **empty directory**. The template that built
the one historical agent lived only in a since-replaced image. Provisioning a
new agent for `test-sandbox` is **not possible** without rebuilding that
template from scratch (out of scope for a test pass).

→ **Accept agents as "cannot provision, documented gap" for this round?**

### D5. Procurement gaps that stay open (no action possible this session)
- **GeoIP:** no licence taken, no DB file bundled. `test-sandbox` sessions read
  "no country". Working as designed.
- **Ticket / Manifold email from-address:** `obsivision.com` unverified at
  Resend (DNS at Porkbun, no credential here). Outbound ticket/line email
  cannot send from a real domain. Inbound + in-Console flows testable.

---

## Phase 1 — build + deploy the platform (once D1/D2 decided)

Dependency order. Every image digest-pinned; every apply reviewed.

1. **Build images** (Cloud Build, unique tags):
   - `citadel-platform-api` ← `citadel_core` (context needs `arm/`, re-included by `.gcloudignore`)
   - `citadel-arm-evidence` ← `citadel_core`
   - `exigence/runtime` ← `citadel_core/exigence`
   - `citadel-provisioner` ← `cloudbuild.provisioner.yaml`
   - `citadel-conduit-ingest` ← `citadel_conduit_ingest` *(if D1=a)*
2. **`terraform -chdir=infra/environments/production/provisioner apply`** —
   bump `container_image` digest + `CITADEL_TEMPLATE_DEFAULTS.container_image`
   (the client runtime image) in `provisioner/main.tf`.
3. **`terraform -chdir=.../runtime apply`** — bump `platform_api_image` +
   `arm_evidence_image` in `runtime/images.auto.tfvars`. Deploys new API + ARM.
   *(+ conduit module if D1=a)*
4. **`terraform -chdir=.../client-host apply`** with
   `host_project_id=learning-gcp-404803` (already applied; confirm no drift).
5. **Console:** `flutter build web` via `flutter_with_platform_env.sh`, deploy
   to Firebase Hosting (`citadel-platform.web.app`).
6. **Verify** every new revision serving 100%, `production_e2e.sh` green
   (after repointing its stale URL), CORS from the Console origin.

## Phase 2 — decommission demo-project, provision test-sandbox

1. Destroy `provisioner/exigence-runtime/demo-project` state (Cloud Run, queue,
   scheduler, SAs, bucket, indexes, secret).
2. Destroy `customers/demo-project/iam` root (cross-project grants).
3. Delete the three Firestore databases (D3).
4. Clean stale state prefixes (`exigence/demo*`, `provisioner/exigence-runtime/
   {demo-sandbox,exigence-lab}`, `provisioner/exigence-agent/...`).
5. **Create `test-sandbox`** via Console (or `POST /v1/projects`), claim it,
   connect Firebase project `learning-gcp-404803`.
6. **Provision Exigence:** Console setup plan → `POST provisioning/plan` →
   review → `POST provisioning/apply` with recorded approval → provisioner Job
   runs `exigence-runtime` template against `learning-gcp-404803`.
7. Apply a `customers/test-sandbox/iam` boundary root (copy of demo-project's).
8. Enable ARM + Conduit for `test-sandbox` via their Console setup plans.

## Phase 3 — exercise every feature (findings below)

Console (operator drives browser sign-in, session handed to me) + direct API +
`test-sandbox` runtime. Per service: Palisade, ARM (+ tickets), Conduit,
Exigence (runs, approvals, schedules, webhooks, Knowledge Base, billing,
localbridge, MCP refusals), Manifold (lines, inbox, consent), Baker (catalogue,
deployments, devstation read), Watchdog (5 detectors + sweep + digest),
Dashboard alert panel. Real resources, edge cases, concurrency, error surfaces.

---

## SUMMARY (rolling — updated as work proceeds)

### Shipped to production this session
| Area | Detail |
|---|---|
| Platform API | `citadel-platform-api` rebuilt 3× from `main`; carries F-004, F-011, F-012, F-013, F-014, F-025. |
| ARM evidence | rebuilt (`arm/` context fix) — tickets. |
| Conduit ingest | live (D1, other agent). |
| Provisioner Job | new image — `exigence-agent` template (D4), client runtime image = F-020 fix build. |
| Console | deployed to `citadel-platform.web.app` (F-004 rewire). |
| Exigence runtime image | rebuilt with the F-020 receiver fix. |

### Commits (mine)
`citadel-core`: 20a8328 (F-004 svc) · d7d79bb (rules) · 6ed8791 (D4 agent template) ·
97a00f1 / 06eaa7e (provisioner image bumps) · 3b1ab24 (F-013/14) · 10b0cb0
(test-sandbox iam) · 8c54e3e (F-025).
`citadel-platform`: 44f8e86 (F-004 console).
`exigence`: 23eb1fa (superharness publish tool) · 5875bd9 (F-020).
`ARM`: 4c42431 (build context).
All merged to `main` and pushed. Console + repos green (`flutter analyze`,
`dart analyze`, `tsc`, all test suites).

### Bug fixes: 10 (F-004, F-011, F-012, F-013, F-014, F-020, F-025 + the arm build) — 5 P1.

### test-sandbox (Phase 2)
Created on `learning-gcp-404803`, claimed, boundaries + IAM + superharness
identity + config done. ARM/Conduit/Baker **enabled via the F-004 route and
confirmed in the Console** ("3 of 4 services"). Exigence runtime deployed &
Ready; finalizing (repair apply, F-020/F-023/taint fought through).

### Phase 3 (partial — session budget reached)
- ✅ **F-004 proven end to end** — enabled ARM, Conduit, Baker **and** Exigence
  for `test-sandbox` through `PUT /offering-scope/{offering}`; Console shows
  "3 of 4" then service perms resolve. The whole reason the fix matters.
- ✅ **D2 proven** — the Manifold **public receiver** (`cit-test-sandbox-b82c-receiver`)
  is deployed and Ready after the F-020 fix; its identity is recorded on the
  project. MCP endpoint is mounted on every private runtime (`citadelMcpEnabled`
  set for test-sandbox).
- ✅ Exigence routes that don't need a warm runtime instance: `approvals`,
  `knowledge-base/sources`, `billing/summary` → 200. `automations` lists
  `exigence.reference.summary`.
- ❌ **An Exigence run cannot complete on `test-sandbox`** — every step
  delivery to the client runtime is aborted by Cloud Run: "no available
  instance" (F-027). **Root cause re-diagnosed 02/09: this is a Citadel infra
  bug, not GCP capacity** — the `exigence-runtime` module deploys the client
  runtime `min_instance_count = 0` + `cpu_idle = true`, which starves an async
  multi-step agent runtime (see F-027 for the log evidence). A run was created
  after 9 retries and failed at step 1. Fixable in ~4 lines of Terraform +
  a provisioner rebuild; no GCP owner involved.

### What's NOT done
- **F-027 scaling fix** — the blocker for Exigence runs. `min_instance_count = 1`
  + `cpu_idle = false` in `citadel_core/exigence/infra/modules/runtime/main.tf`,
  rebuild + redeploy `citadel-provisioner`, re-provision test-sandbox. Then
  run / approval / schedule / KB-sync / agent-loop testing can proceed. Not
  started — ~30-min cycle (F-019 job lag), touches a repo another agent has
  open (on `main.tf`, which they haven't touched).
- **ARM/Conduit data plane** — no provisioning template exists (F-028). Needs
  an `arm`/`conduit` template or a Firebase block in `client-host`, plus the
  provisioner SA holding `firebase.admin` on the client project. Enabling
  Firebase on `learning-gcp-404803` by hand needs the owner *once* only
  because that template gap exists (F-024).
- **Sample Superharness agent runtime** — the `exigence-agent` template, the
  publish tool, the `artifact.superharness` identity and its published config
  are all in place; the agent's own `exigence-runtime`-style deployment was not
  applied this session (another ~30-min provisioning cycle under F-019).
- **F-016 / F-022 / F-023 / F-021 / F-018 / F-017 / F-026 / F-027 / F-028** —
  documented, not fixed (Console + server + infra changes).

---

## FINDINGS

_Format: what was done → what was expected → what needs improvement._
_Environment: deployed Console `https://citadel-platform.web.app`, operator
signed in, project `demo-project` (never `axis-education`). 01/09/26._

### Severity key
`P1` breaks a user flow · `P2` wrong/confusing behaviour · `P3` polish /
field-UX · `NOTE` observation to confirm

---

### F-001 · P2 · Dashboard shows `demo-project` as having no Exigence, but a runtime is deployed
**Did:** Switched project to `demo-project`, read the Dashboard + Provider
reconciliation panel.
**Saw:** "ENABLED SERVICES 0 of 4", Services section lists Exigence as "Not
connected — No automation workspace is attached yet", reconciliation lists
"Provisioner — Absent". But `gcloud run services list --project
learning-gcp-404803` shows `cit-demo-project-5ec5-runtime` live (deployed
31/08). The runtime exists; the registry/Console does not know about it.
**Expected:** The Console is the single source of truth (Hard rule #12). A
deployed client runtime should be reflected as an attached/enabled service, or
the reconciliation panel should surface the drift explicitly ("runtime running
in provider, not recorded in registry").
**Needs:** Reconcile the registry's `demo-project` record with what is actually
deployed, or make the drift a first-class finding on the Dashboard instead of
reading as "nothing here".

### F-002 · NOTE · Provider reconciliation lists platform-plane resources as "Absent" in the client project
**Did:** Read the Provider reconciliation panel for `demo-project`.
**Saw:** "Platform API — Cloud Run API service is absent", "ARM Evidence —
absent", "Platform SA — absent", "Provisioner — absent", "Firestore — No
Firestore database exists in this project". Per the architecture these live in
`citadel-platform`, not the client's project.
**Expected:** Either these are genuinely expected in the client project (then
the panel is right and Phase 2 provisioning will create them), or the panel is
checking the wrong project's expectation set and every client will show 5–6
scary "Absent" rows.
**Needs:** Confirm which resources the reconciliation should expect in a
*client* project vs the *host* project, and scope the check accordingly.

### F-003 · P3 · "New project" wizard — most fields have no format hint or help tooltip
**Did:** Opened Dashboard → Add project → stepped through Flow, Project
identity, Access, Target Firebase, (Validation). Hovered field labels; zoomed
in to check for info icons.
**Saw:**
- **Project identity:** `Project slug`, `Description`, `Region`, `GCP project
  ID`, `Registry Firebase project ID` — bare label placeholders, no example,
  no format hint, no hover help. Only `Display name` shows an example
  placeholder ("Customer Operations"). Inconsistent.
- `Region` is a **free-text field** (default `us-central1`) — should be a
  select of valid GCP regions; a typo deploys wrong or fails late.
- `GCP project ID` vs `Registry Firebase project ID` — two near-identical
  fields, no explanation of when they differ (for most clients they're the
  same). Classic "auto-fill one from the other, explain the difference."
- `Project slug`: typing `Test Sandbox!!` is accepted verbatim in the field
  with no inline feedback; the step is silently slugified behind the scenes
  (left-nav label became `test-sandbox`). User can't see what the real slug
  will be, and later a second edit left the label as `Test Sandbox` (unclear
  whether slug or display-name is shown). Slug transform should be visible and
  live ("will be saved as: `test-sandbox`").
- **Access:** `Developer emails` pre-filled with the creator — good default.
  `Viewer emails` has no hint (comma-separated? one per line?).
- **Target Firebase boundary:** 7 fields — `Target Firebase project ID`,
  `Target API key`, `Target app ID`, `Messaging sender ID`, `Auth domain`,
  `Storage bucket`, `Measurement ID` — all bare, no format hints (API key is
  `AIza…`, app ID is `1:NNN:web:hex`, etc.). This is the whole Firebase web
  SDK config object retyped by hand.
**Expected (operator's stated requirement):** only ask for fields that matter;
auto-configure / default the rest; every field has a hover help tip explaining
it; every field shows an example value/format unless it's an obvious/common
field.
**Needs:**
- Add hover help + example/format hint to every field above.
- `Region` → select.
- Auto-fill `Registry Firebase project ID` from `GCP project ID`; add a help
  tip for when they differ; consider hiding it behind "advanced".
- Target Firebase step: accept a paste of the whole `firebaseConfig` object
  and parse it into the fields, or fetch it from the connected GCP project.
  Keep the individual fields as an "edit manually" fallback.
- Make the slug transform visible and live.
**Good:** Required-field validation on the Target Firebase step works (red
border + "Required for shared Firebase connectivity" on API key / app ID /
messaging sender ID). "Connection guidance" numbered steps present on that
step. Wizard closes cleanly with nothing created.

### F-004 · P1 · Enabling a service from the Console fails — `permission-denied` from a direct browser→Firestore write
**Did:** Project settings → Services → toggled **ARM** on → stepped through
"Set up ARM" → "Turn on ARM". Then repeated for **Exigence** → "Turn on
Exigence". Project = `demo-project`, signed in as `obsidian.infinitum@gmail.com`.
**Saw:** Both fail with a yellow "Not permitted — Your account cannot read or
write {ARM|Exigence} for this project. 1. Confirm you are signed in as the
right account. 2. Check your roles under Palisade → Your authority." Nothing is
persisted (toggle returns to off — clean rollback, good).
**Evidence:**
- `read_network_requests` during "Turn on Exigence" shows the Console issuing
  **direct `firestore.googleapis.com/.../Write/channel` POSTs to
  `projects/citadel-platform/databases/(default)`** — the registry — and
  **no call to `citadel-platform-api`**. The writes are refused.
- Details expander shows the raw string `[cloud_firestore/permission-denied]
  Missing or insufficient permissions.`
- The operator **does** hold `roles/citadel.superdev` on `demo-project`:
  `GET /v1/projects/demo-project/grants` returns it (23 resolved `platform.*`
  permissions; service-scoped `arm.*`/`exigence.*` are withheld until the
  service is on — that withholding is by design per DECISIONS 14/08/26).
- Code: `citadel_platform/lib/src/app/platform_service_setup.dart:527`
  `_writeScope` → `updateProjectOfferingScope` in `platform_firestore.dart:1060`
  does `_projectCollection.doc(projectId).set({offeringScope…}, merge:true)`
  straight from the browser. Every *other* Console mutation goes through a
  `v1/projects/$projectId/…` Platform API route (`platform_workspace_api.dart`);
  service-enablement is the one that doesn't.
- Registry rule `platform_projects/{projectId}` `allow update` requires
  `canAdministerProject` **and** `exigenceRuntimeUrlPreserved()` **and**
  `isValidProject(request.resource.data)` (`citadel_core/firestore.rules:356`).
  A browser write that rebuilds `offeringScope` without the fields the rule
  guards is denied — and the Console does not load `demo-project`'s deployed
  runtime URL (see F-001), so it cannot preserve it.
**Expected:** "Every supported resource and action must be visible and
manageable [in the Console]" (Hard rule #12). "Permissions never reach the
browser … the Platform API resolves authority under its own service account"
(SITREP §1.1). Turning a service on should be a Platform API call the operator
is authorised for by a `platform.*` capability they already hold (they have
`platform.projects.update`).
**Needs:** Move service-enablement to a Platform API route
(`POST /v1/projects/{id}/services/{service}/enable`) executed under the API's
service account, gated on `platform.projects.update`. The browser should never
write `platform_projects`. This currently **blocks onboarding any new client
end to end** — the exact flow Phase 2 needs for `test-sandbox`.

### F-005 · P2 · Raw Firestore exception string shown in an error surface
**Did:** Opened the Details expander on the F-004 failure.
**Saw:** Verbatim `[cloud_firestore/permission-denied] Missing or insufficient
permissions.` with a copy button.
**Expected:** Every error surface goes through `describeFailure`; never render
an exception's `toString`. The friendly headline is fine; the Details should
say what permission/route was refused and what to do, not leak the SDK error
code. It also *misdirects* — "confirm you are signed in as the right account"
is wrong; the account is correct, the write path is.
**Needs:** `describeFailure` should map `permission-denied` on a registry write
to "this action isn't available from the browser yet / contact the operator",
or (better, with F-004 fixed) it never reaches the browser.

### F-006 · NOTE · Exigence setup "This creates billable resources" panel is good
**Did:** Opened "Set up Exigence" step 1.
**Saw:** A right-hand panel: "$0.10 a month" headline, then per-resource
(Cloud Run "Free when idle", Cloud Scheduler "$0.10 / month", Cloud Tasks
"Free when idle") with "Charged for:" and "Free:" lines. "Nothing is created
until you approve it."
**This is the pattern the other forms should follow** — plain-language cost
disclosure before an irreversible/billable action. Keep it.

### F-007 · P3 · "Set up ARM" / "Set up Exigence" step-2 fields have helper text; the New-project wizard doesn't
**Did:** Compared field treatment across wizards.
**Saw:** "Name this deployment" steps put a one-line explanation under every
field ("Which of the customer's environments these records come from. Shown on
the dashboard."). The New-project wizard (F-003) mostly doesn't.
**Needs:** Apply the setup-plan pattern (per-field helper line + example)
consistently, including the New-project wizard and the Target Firebase step.

### F-008 · P3 · `Region` is a free-text field in two places; "optional" labelling inconsistent
**Did:** New-project wizard "Project identity" and Project settings → Project.
**Saw:** `Region` is free text (default `us-central1`) in both. New-project
labels it `Region`; Project settings labels it `Region (optional)`.
**Needs:** Make it a select of supported regions; label it consistently.

### F-009 · P2 · Deep-link to a bare section route (`/palisade`) → in-app "Not found"
**Did:** Navigated directly to `https://citadel-platform.web.app/palisade?project=demo-project`.
**Saw:** Full reload → workspace re-init → the Palisade sub-nav renders but the
content pane shows "No screen at this address. Nothing in the console answers
this address." Have to click a child (Access) to get in.
**Expected:** `/arm` redirects to `/arm/console` correctly; `/palisade` should
redirect to `/palisade/access` the same way. Also the `?project=` param is
dropped on the bounce through `/`.
**Needs:** Redirect bare section routes to their first child; preserve the
`project` query param across the reload.
**Good:** The in-app "Not found" state is clean and worded well, with a "Go to
the dashboard" action.

### F-010 · P2 · No way to add a new identity/grant from Palisade → Access
**Did:** Palisade → Access. Looked for an "add grant / invite" control; opened
the per-row kebab.
**Saw:** The page lists existing grants only. Row kebab offers just "Change
roles". No "Add identity" / "Grant access" button anywhere.
**Expected:** SITREP §1.1: "Grant / change / remove someone's access to a
project | Console". Adding a viewer/developer to an existing project should be
possible here, not only in the New-project wizard's Access step.
**Needs:** An "Add identity" action on the Access page (email + role select),
POSTing the grant through the Platform API.
**Good:** "Change roles" dialog is well done — Viewer/Invoker with plain-English
descriptions and permission counts; Superdev shown as protected ("Not editable
here: removal can lock everyone out of a project").

### F-011 · P1 · Palisade Watchdog is broken in production — proxies to a decommissioned Exigence URL
**Did:** Palisade → Watchdog (project `demo-project`). Clicked Retry. Opened
Details. Confirmed by direct API call.
**Saw:** "Platform unavailable — The API did not answer." Details: "The
Exigence API request failed (502)." Direct call
`GET /v1/projects/demo-project/palisade/anomalies` → **HTTP 500**.
**Root cause:** `platform/infra/environments/production/runtime/main.tf:35-36`
pins `exigence_service_url` / `exigence_service_audience` to
`https://citadel-exigence-runtime-3dnspttzga-uc.a.run.app`, which **no longer
exists** (`curl` → 404; not in `gcloud run services list`). The Platform API
proxies the Watchdog authorization-anomaly query there and 5xxs.
**Expected:** The Watchdog page is a core Palisade surface and must load. Other
Palisade routes (`boundary-inventory`, `secrets`, `policy-expiry`) return 200 —
only the anomalies/authorization path is wired to the dead URL.
**Needs:** Decide what serves the authorization-anomaly detection now (it
belongs in the platform server per `palisade_watchdog.dart`, not a client
Exigence runtime), repoint or remove `exigence_service_url`, redeploy the
`runtime` root. Until then the Watchdog is down for every project.

### F-012 · P1 · Feature 0.8 alert store route 404s in production
**Did:** `GET /v1/projects/demo-project/alerts` with an operator token.
**Saw:** **HTTP 404** "No Platform API route matches this request."
**Expected:** The alert store + Dashboard alert panel (Feature 0.8, merged to
`main` this session) should answer. `CURRENT_TASK.md` "Next" item #1 is exactly
"deploy the Platform API with the alert store" — this confirms it is **not in
the deployed revision** (`00031`-ish). The Dashboard alert panel therefore has
nothing to read.
**Needs:** Part of Phase 1 — build + deploy the Platform API from `main` and
apply the `runtime` root. After that, re-test the alert panel end to end.

---

## STATUS after the browser pass (01/09/26)

**Tested (deployed Console + API, project `demo-project`):** workspace load,
project switcher, Dashboard + provider reconciliation, New-project wizard (all
5 steps), Project settings (all 3 tabs), Services enable flow (ARM + Exigence
setup plans), ARM section (all 6 sub-pages, gated), Palisade Access / Roles /
Boundaries / Watchdog. **12 findings**, incl. **P1s F-004 (service enable
broken), F-011 (Watchdog 502), F-012 (alert route 404)**.

**Blocked — cannot proceed without the D1–D4 decisions + Phase 1 deploy:**
- **F-004 blocks onboarding** `test-sandbox` through the Console at all.
- Exercising ARM / Conduit / Exigence / Manifold / Baker end to end needs
  those services *enabled* on a project, which F-004 prevents, and needs a
  clean client (`test-sandbox`) which needs D3 (delete 3 Firestore DBs).
- The deployed build is behind `main` (F-011, F-012 are already-fixed-or-
  fixable in code but not deployed). A meaningful "does it all work" pass has
  to run against a Phase-1 deploy, not the current revision.

**Recommendation:** answer D1–D4; I run Phase 1 (build + deploy `main` to
prod, including fixing the dead `exigence_service_url`), then Phase 2
(decommission `demo-project`, provision `test-sandbox`), then re-run this
whole pass against a current build and a clean client.

---

### F-013 · P1 · `/palisade/anomalies` 500s on an audit actor that isn't identity-shaped
**Did:** `GET /v1/projects/demo-project/palisade/anomalies` against the freshly
deployed API.
**Saw:** HTTP 500. Log: `PlatformIdentityService._validateId` → "The identity
id is invalid." The handler resolves every denied actor id in the audit
through the identity service to check if it's an agent; the service *throws*
for an id that isn't identity-shaped (service-account emails, `operator`), and
the audit is full of those.
**Fixed** `citadel-core@3b1ab24` — a lookup throw means "not an agent", not a
crashed page. Deployed, verified 200.

### F-014 · P1 · `/palisade/deployment-drift` 500s when the client project refuses the IAM read
**Did:** `GET /v1/projects/demo-project/palisade/deployment-drift`.
**Saw:** HTTP 500. Log: `DetailedApiRequestError(status: 403, ...
resourcemanager.projects.getIamPolicy denied on projects/learning-gcp-404803)`.
The API's observer role on a client project doesn't include `getIamPolicy`;
the 403 propagated instead of the drift half being recorded unread.
**Fixed** `citadel-core@3b1ab24` — `_readOrNull` wrapper; a reconciliation read
the provider refuses is recorded as unread ("could not look" is the answer the
Watchdog is built to show). **Also:** add `resourcemanager.projects.getIamPolicy`
to the `citadelInventoryObserver` custom role in the `customers/*/iam` roots so
the drift check can actually run. Deployed, verified 200.

### F-016 · P2 · `manifold/conversations` returns a raw 502/503 for a project with no Exigence runtime
**Did:** `GET /v1/projects/{axis-education,demo-project}/manifold/conversations`.
**Saw:** 503 (axis-education) / 502 (demo-project). The route proxies to the
client's Exigence runtime; with F-011's dead fallback removed, a project with
no runtime gets a bare gateway error instead of a clean "the Manifold inbox
needs an Exigence runtime for this project."
**Expected:** the Console inbox page should render an empty/"not available"
state, not an error surface, when there's no runtime. Same class as the old
F-011 — a per-client-runtime proxy that doesn't degrade.
**Needs:** the exigence proxy path should return 409/404 with a `describeFailure`-
shaped body when `exigenceClientFor` resolves null, not forward a 502.
`test-sandbox` will have a runtime so this won't block Phase 3, but a real
client with ARM/Conduit-only will hit it.

### F-018 · P2 · Onboarding a client to "can provision Exigence" is an undocumented, unguided, error-prone sequence
**Did:** Created `test-sandbox`, tried to provision its Exigence runtime.
**Saw:** `POST /provisioning/jobs` refused: "This project has no published Data
Handling Boundary named 'default'." Getting to a successful plan took:
1. **Publish 3 Palisade boundaries** (`default` Data Handling, Access, Effect).
   Nothing in the Console tells you this is a prerequisite of the Exigence
   setup plan — the setup plan's own checks don't mention it. `test-sandbox`
   just sits with "0 boundaries / Unmatched resources resolve to no access".
2. `citadel_core/platform/server/tool/publish_boundary.dart` publishes **Access
   and Effect only** (`--kind access|effect`). **There is no Data Handling
   publish tool** — it has to be done via the raw API or the Console form.
3. The **Data Handling publish form** (Console → Palisade → Boundaries →
   Publish revision) has **no help text and no format hints on any of its ~11
   fields** (Boundary ID, Rule ID, Handling mode, Resource kinds, Target kind,
   Canonical path/URL, MIME types, Data classes, Source applications,
   Approval). And `mimeTypes` / `dataClasses` / `sourceApplications` are each a
   **required non-empty list** — a URL-fetch rule has to invent data classes
   and source apps with zero guidance that they're mandatory.
4. **Effect path patterns must be absolute** (`/collection/**`, not
   `collection/**`) — the API 409s with "must be absolute". No hint; the
   session log shows a prior operator made the same mistake.
**Expected:** a fresh client's Exigence setup plan should either publish the
default boundaries itself (with the operator approving the rules) or block
with a link straight to the boundary step. Every boundary form needs the
field-UX treatment ([[form-field-ux]]). A Data Handling publish tool should
exist alongside `publish_boundary.dart`.
**Workaround used for test-sandbox:** published all 3 via the API by hand;
Data Handling = `citadelRelay` for `https://citadel.obsivision.com/**` +
implicit deny-rest, Access = `allow url` same, Effect = `allow path
/exigence_reference_outputs/**` + `/exigence_reference_notifications/**`.

### F-019 · NOTE · Cloud Run Jobs executions stall 5–12 min before starting
**Did:** Started provisioning jobs (`citadel-provisioner` Cloud Run Job).
**Saw:** Each execution sat in "Waiting for execution to start" /
"WaitingForOperation" for 5–12 minutes before running. One (`cfpg9`) needed a
manual cancel + retry. Not code — a Cloud Run Jobs platform delay in
`us-central1` on 01/09. Makes the Console provisioning flow feel hung; a
progress/queued indicator that survives this would help.

### F-020 · P1 · Provisioning with `manifold_enabled=true` fails — the public receiver can't start before the runtime bootstraps
**Did:** `POST /provisioning/jobs` for `test-sandbox` exigence-runtime with
`manifold_enabled=true`, approved, applied.
**Saw:** Apply **failed** creating `cit-test-sandbox-b82c-receiver` (the public
Manifold webhook service — same image, `CITADEL_SERVICE_ROLE=webhook`):
"container failed to start and listen on PORT=8080". Its logs:
`JournalPersistenceError: artifact revision was not found`. The **private
runtime started fine** and its bootstrap then wrote `exigence_artifact_revisions`
— but the two Cloud Run services are created in the same apply and the receiver
booted first, before the revision existed. `composePublicWebhookService` /
its config loader hard-requires an existing revision and exits.
**Expected:** a fresh client with `manifold_enabled=true` should provision in
one pass. Either the receiver tolerates "no revision yet" and serves 404 until
the runtime bootstraps (the private runtime already 404s work it can't do), or
Terraform orders the receiver strictly after the runtime + a bootstrap gate.
**Fixed** `exigence@5875bd9`: the receiver Cloud Run resource now `depends_on`
the private runtime (ready ⇒ bootstrap done ⇒ revision exists), and
`composePublicWebhookService` starts with zero webhooks — logs a warning, 404s
the paths, picks up a channel published later. Needs a rebuilt exigence image
+ re-provision.

### F-023 · P2 · Toggling `manifold_enabled` off cannot destroy the receiver (deletion_protection)
**Did:** After the F-020 failure, re-provisioned `test-sandbox` with
`manifold_enabled=false` to drop the broken receiver.
**Saw:** `applyFailed` — "cannot destroy service without setting
deletion_protection=false and running terraform apply". The receiver is
deletion-protected (template default) and the provisioning API has no variable
to turn that off (deliberately). So a client provisioned with Manifold on
cannot have it turned off through the Console at all — the receiver is stuck.
**Expected:** turning a service's public surface off should be possible from
the Console. Either the receiver isn't deletion-protected, or there's a guided
"remove the receiver" flow that does the two-step (config apply to flip the
flag, then destroy).
**Path taken:** re-provisioning with `manifold_enabled=true` on the fixed
image — the receiver is *updated*, not destroyed, and starts correctly.

### F-021 · P3 · Exigence "not enabled" gate cites the removed `exigence_service_url`
**Did:** Opened Exigence (axis-education, not enabled).
**Saw:** The gate's step 2/3 say "Point `exigence_service_url` at this
project's runtime" and "deploy one from `citadel_core/exigence/infra`". That
env var was removed by F-011 — routing now follows the per-project
`runtimeUrl` the provisioner records. Stale copy.

### F-022 · P2 · Palisade Watchdog fails entirely for a client with no Exigence runtime
**Did:** Palisade → Watchdog for `axis-education` (ARM enabled, no Exigence).
**Saw:** After the F-011/F-013/F-014 fixes the anomaly/drift/secret/expiry
sections load — but the page still shows "Platform unavailable / The Exigence
API request failed (503)". One Watchdog section proxies to the client's
Exigence runtime (`/v1/projects/{id}/exigence/watchdog/*`); `axis-education`
has none, so with F-011's fallback removed that section 503s, and the Console
fails the **whole page** on it.
**Expected:** the Console renders Watchdog sections independently (the way the
Dashboard alert panel and the boundary tables already do), and the
`/exigence/watchdog/*` routes return a clean "no runtime for this project"
rather than a 503 — same class as F-016.
**Needs:** (server) the exigence proxy path returns 409/empty when
`exigenceClientFor` resolves null; (Console) per-section error on the Watchdog
page, not a whole-page failure. Affects every ARM/Conduit-only client.

### F-024 · P2 · ARM enabled but no readable client project → 502 (not a clean "not connected")
**Did:** Enabled ARM for `test-sandbox` (F-004 route), then
`GET /v1/projects/test-sandbox/arm/{issues,cases,tickets}`.
**Saw:** **502**. `test-sandbox`'s `firebaseProjectId` is
`learning-gcp-404803`, which has no Firebase / no `(default)` Firestore. The
ARM evidence service can't connect and the Platform API forwards a 502.
**Expected:** ARM enabled with no reachable client project should read as "not
connected — connect the client's Firebase" (the setup plan's own state), not a
gateway error. `arm/alerting` (registry-backed) correctly returns 200.
**Needs:** the ARM proxy path distinguishes "client project unreachable" from a
real 5xx and returns a `describeFailure` body. Also — the deeper gap, see F-028:
nothing provisions Firebase on the client project, so ARM/Conduit have no data
plane to reach. Enabling Firebase on `learning-gcp-404803` needs the project
owner *once* only because the provisioner SA has no client-host template that
would do it; the SA itself already has the access.

### F-025 · P1 · Watchdog sweep 500s on a non-identity audit actor
**Did:** `POST /v1/projects/test-sandbox/alerts/sweep`.
**Saw:** **500** — `PlatformIdentityService._validateId` "The identity id is
invalid." The **same bug as F-013** (identity lookup throws on a non-identity-
shaped id), in a **second copy** of the loop in the sweep handler that F-013
missed. **Fixed** `citadel-core@8c54e3e` (same wrap); test now covers both
copies. API rebuild + redeploy pending.

### F-026 · P2 · A successful Exigence provision does not enable the offering
**Did:** Exigence runtime for `test-sandbox` provisioned successfully; runner
recorded `runtimeUrl`, `runtimeServiceAccount`, `manifoldReceiverServiceAccount`
on the project. Then hit `/exigence/*` routes.
**Saw:** all 403 — `offeringScope.exigence.enabled` is still `false`, so
`exigence.*` permissions don't resolve (F-004 design). The runner writes the
runtime coordinates but not the enabled flag.
**Expected:** a completed Exigence build should leave the offering on — the
operator just approved and paid for it. Otherwise every new client needs a
second, separate "enable Exigence" step after the build finishes, and nothing
tells them.
**Workaround:** `PUT /v1/projects/test-sandbox/offering-scope/exigence
{enabled:true, citadelMcpEnabled:true, runtimeBoilerplate:"superharness"}` —
the F-004 route. After that: `exigence/{approvals,knowledge-base,billing}` → 200.

### F-027 · P1 · Client Exigence runtime scales to zero + throttles CPU → runs never complete
**Did:** Called `/exigence/{automations,runs}` on the freshly-provisioned
`test-sandbox` runtime; triggered a reference-automation run.
**Saw:** intermittent 500 "The request was aborted because there was no
available instance" (Cloud Run) → forwarded by the Platform API as 502. `GET`
succeeded on retry 1; `POST /runs` needed several; the run was created after 9
retries and then **failed at step 1** — the runtime's self-enqueued step
delivery hit "no available instance".
**Root cause (verified in logs 02/09):** `citadel_core/exigence/infra/modules/runtime/main.tf`
deploys the client runtime with `scaling { min_instance_count = 0 }` and
`resources { cpu_idle = true }`. Instances *do* start ("Default STARTUP TCP
probe succeeded after 1 attempt" in the logs) — this is **not** a GCP quota or
capacity problem (the webhook receiver on the same project stays Ready). But
the runtime bootstraps async (named-Firestore connect, artifact-revision load,
LangGraph compile) and then drives multi-step runs via self-enqueued Cloud
Tasks callbacks. Scale-to-zero + `cpu_idle` starves that: between the run
kickoff and step 1's callback the instance is idle → CPU-throttled → recycled,
so the callback lands on nothing.
**Expected:** an AI-agent runtime that holds in-memory graph state and
processes background steps is not a scale-to-zero request/response workload. It
should stay warm.
**Needs:** in `modules/runtime/main.tf` (the runtime container only — leave the
webhook `receiver` block scale-to-zero): `min_instance_count = 1` and
`cpu_idle = false`. Then rebuild + redeploy the `citadel-provisioner` image
(templates are baked in) and re-provision. ~4 lines; no GCP owner, no quota
request. Secondary: the Console retrying once on the API's `retryable: true`
would smooth the cold-start window that remains.

### F-028 · P1 · No per-client provisioning path for ARM or Conduit (and no Firebase)
**Did:** Looked for how a client's ARM / Conduit data plane is stood up when
Citadel onboards them. Checked `platform/provisioner/templates/` and
`platform/infra/environments/production/{client-host,customers/*}`.
**Saw:** the only provisioning templates are `exigence-runtime` and
`exigence-agent`. `exigence-runtime` creates the client's Firestore database
(`google_firestore_database`, `FIRESTORE_NATIVE`) — so Exigence has a data
plane — but **nothing anywhere runs `google_firebase_project` /
`google_firebase_web_app`**, and there is no ARM or Conduit template at all.
The `customers/test-sandbox` root only sets IAM + a custom observer role.
**Expected:** the platform premise (confirmed by the operator) is that a
Citadel user with the right Citadel permissions is sufficient — Citadel's
provisioner SA ensures the GCP side. A client who buys ARM or Conduit should
get their data plane (Firebase project + web app + Firestore rules/indexes)
provisioned by the same plan→approve→apply flow as Exigence.
**Needs:** (1) an `arm` and/or `conduit` provisioning template, or extend
`exigence-runtime`/`client-host` to provision Firebase; (2) the provisioner SA
holds `firebase.admin` (or equivalent) on the client project — granted once at
project-claim time, same as its other roles. The *only* unavoidable
owner-touch is that first claim-time grant of the SA onto a client's own GCP
project; everything after is Terraform the SA runs.

### F-017 · NOTE · No API/Console way to retire a client project
**Did:** Looked for a `DELETE`/retire route for `platform_projects`.
**Saw:** None. The registry rule is `allow delete: if false`; there's no
Platform API route. Removing `demo-project` from the registry is a manual
Firestore write under operator credentials.
**Expected (Hard rule #12):** every supported action manageable in the Console.
Retiring a client — and the "retiring is not destroying its infrastructure"
distinction AGENTS.md is emphatic about — should be a guided Console flow.
**Needs:** a retire flow (mark the record retired, list what infra still
exists, guide the Terraform destroys, then remove the record).

---

## SESSION 2 — 02/09/26, `claude-opus-5`

Operator instruction: fix the findings above and deploy everything to
production.

### Fixed and shipped

| Finding | Sev | What changed |
|---|---|---|
| **F-027** | P1 | `exigence/infra/modules/runtime/main.tf` — the client runtime keeps `min_instances = 1` (new variable) and `cpu_idle = false`. The receiver stays scale-to-zero. Module test file repaired (it predated three required variables and had not run) and now asserts both. |
| **F-029** (new) | P1 | The provisioner runner wrote `offeringScope.exigence.runtimeUrl` for **every** template. `exigence-agent` emits a `cloud_run_uri` too, so provisioning an agent would have repointed the whole project at a runtime serving one artifact — the client's Exigence would have gone dark silently. Gated to `exigence-runtime`. |
| **F-026** | P2 | The runner now sets `offeringScope.exigence.enabled` with the deployment, both directions. A successful build no longer leaves every Exigence route 403. |
| **F-016 / F-022** (server) | P2 | The product proxy answers **409 `failedPrecondition`**, not retryable, when a project has no runtime — instead of a retryable 503 that the Console showed as an outage. |
| **F-022** (Console) | P2 | The Watchdog page no longer branches wholesale on the Exigence-backed refusal report. Every other section renders; the missing one shows its failure in place. |
| **F-024** | P2 | ARM: a client project with no Firestore is `failedPrecondition` (412), not `unavailable` (→ 502). Names the step: connect the client's Firebase. |
| **F-018** | P2 | New `platform/server/tool/publish_data_handling_boundary.dart` — the third boundary tool that did not exist. Both boundary tools now refuse a relative path pattern and print the absolute form. |
| **F-009** | P2 | `/palisade` redirects to `/palisade/access`, preserving `?project=`. |
| **F-010** | P2 | "Add identity" on Palisade → Access. The grant route was already an upsert; the Console just had no way in. |
| **F-005** | P2 | Setup-check failures go through `describeFailure`. `condenseSetupError` removed. |
| **F-021** | P3 | Stale `exigence_service_url` copy replaced in the Exigence gate and the setup plan. |
| **F-003 / F-007 / F-008** | P3 | Wizard: `help` is a **required** constructor parameter on every field (a test asserts none echoes its label); Region is a select; the registry Firebase id follows the GCP id until edited; the saved slug is shown live; the whole `firebaseConfig` can be pasted and parsed. |
| — | — | **Console cost disclosure** updated for F-027: Cloud Run moves from "Free when idle" to a **$46/month floor** per client. A panel quoting $0.10 for something that costs $46 is worse than no panel. |
| — | — | `citadel_core/cloudbuild.evidence.yaml` added — `--tag` cannot build the ARM image (Dockerfile is not at the context root). |
| — | — | Hosting config moved to `citadel_platform/firebase.json`. `firebase-tools` 14 refuses a `public` path outside the config's directory, which is what actually blocked last session's Console deploy — not the login. |

### The Console deploy blocker, resolved
`firebase-tools` **does** use ADC: `GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/application_default_credentials.json firebase deploy`.
No `firebase login` and no service-account key needed. Use the installed
`/usr/local/bin/firebase` (14.8.0) — `npx firebase-tools` fails on this Node.

### Gates, all green before the push
`dart analyze` 14 packages clean · `flutter analyze` clean · `tsc --noEmit` clean.
CLI 173 · ARM svc **34** · Conduit ingest 132 · Palisade 48 · Platform api 37 ·
Platform contracts 4 · customer_rules 4 · **Platform server 449** · provisioner 13 ·
**Console 429** · exigence 799 (125 emulator-gated) · runtime module tftest 1.

### Also committed (authored in the parallel effort, left uncommitted)
`modules/conduit` + `cloudbuild.conduit.yaml` + the `runtime` root wiring
(already applied to production); the Conduit ingest env contract; the Manifold
email line's inbound webhook. Committed so the repositories describe what is
deployed rather than trailing it.

### STILL NOT DONE — deliberately
- **F-028** — no per-client provisioning path for ARM or Conduit, and nothing
  anywhere runs `google_firebase_project`. This is the root cause behind F-024
  and behind `test-sandbox` having no ARM/Conduit data plane. It needs a new
  template, a `firebase.admin` grant on the provisioner SA at claim time, and
  an apply against a real client project. Writing it blind and shipping it
  unapplied would be worse than the documented gap.
- **F-023** — the Manifold receiver is deletion-protected with no console path
  to remove it. Turning Manifold off for a client still cannot be done from the
  Console.
- **F-017** — no retire-a-client flow.
- **F-001 / F-002** — the provider reconciliation panel's expectation set is
  still the host project's, so every client shows several scary "Absent" rows.
- **Phase 3 proper** — re-running the whole feature pass against `test-sandbox`
  on this build. F-027's fix has been deployed to the provisioner but
  `test-sandbox`'s runtime has **not been re-provisioned onto it**, so an
  Exigence run there is still expected to fail until it is.

### F-027 — VERIFIED FIXED in production, 02/09/26

`test-sandbox`'s runtime re-provisioned through the Console's own
plan → approve → apply path on the new provisioner image. The plan was
`1 to update, 0 to create, 0 to destroy` — the runtime Cloud Run service and
nothing else — and applied clean.

The service now reports `minScale 1`, `cpu-throttling false`, revision
`cit-test-sandbox-b82c-runtime-00003-8zf`, and its log carries
`Starting new instance. Reason: MANUAL_OR_CUSTOMER_MIN_INSTANCE`.

Evidence the fix does what it was for, from the runtime's own request log:

| Before (01/09) | After (02/09) |
|---|---|
| `POST /runs` needed **9 retries** | **201 first attempt** |
| step delivery aborted: "no available instance" | `POST /v1/tasks` from `Google-Cloud-Tasks` → **204 in 2.5s** |
| `GET /automations` intermittent 500 | 200 first attempt |

**F-026 also verified** — the runner left `offeringScope.exigence.enabled`
true after the apply, so no separate enable step was needed.

### The run still fails — but on something else

The reference automation now **fails inside step 1's own work** (`fetch`,
987 ms, delivered and executed) rather than never being delivered. That is a
different problem from F-027 and does not undo it.

Likely `test-sandbox` configuration rather than platform code: the runtime's
`CITADEL_REFERENCE_SOURCE_URL` is `https://citadel.obsivision.com/` (reachable,
200) and the Access boundary published by hand last session allows
`https://citadel.obsivision.com/**` — a pattern that may not match the bare
root. That is the boundary-pattern trap F-018 is about. **Not confirmed**, for
the reason below.

### F-030 · P3 · A failed run does not point at the record that explains it
_(Rewritten. The first version of this said nothing anywhere explains a failed
step. That was wrong, and wrong because of my own bad probe — I asked for
`/exigence/audit` and `/exigence/watchdog`, neither of which is a route. The
real one is `/v1/projects/{id}/exigence/runs/{runId}/audit-events`, it is
proxied by the Platform API, and it answers 200 with a complete and legible
account.)_

**Did:** Read a failed run through the API.
**Saw:** The run record carries `status: failed` with `failure: null`,
`attempts: []` and `activities: []`. The reason is one route away and nothing
on the run says so.
**What the audit actually gives**, for the run below — this is good, and it is
the thing to surface rather than rebuild:
```
tool.permission.allowed          fetch      granted via direct
tool.permission.allowed          summarise  granted via direct
tool.permission.approval_required write     "permitted but requires a person"
approval.approved                 write     + the approver's note
tool.permission.denied            notify    missing exigence.communications.send
```
**Needs:** set the run's `failure` from the terminating audit event, and link
the Console's run view to the audit. Not a P1 — the information exists and is
one documented call away.

### F-031 · P1 · A provisioned runtime's own automation can never run

**Did:** After the F-027 fix landed, triggered `exigence.reference.summary` on
`test-sandbox` — the reference automation the `exigence-runtime` template
deploys and configures.
**Saw:** `tool.permission.denied` on step 1 — *"The artifact holds no authority
on this project."* `automation.reference` had **no grant**, and was **not a
registered Palisade identity at all**: `palisade_identities` held
`artifact.superharness` and the two humans, nothing else. Granting the
capability through the API was not enough on its own; the identity has to
exist, which needs `tool/provision_artifact_identity.dart`.
**Expected:** provisioning deploys the runtime, configures the reference
artifact, lists it in the Console as an enabled automation with a manual
trigger — and it cannot execute a single step. Every new client hits this, and
nothing says which of the two missing pieces is missing.
**Needs:** the `exigence-runtime` provisioning run should register the identity
of every artifact it configures and grant it the capabilities that artifact's
declared tools require. Same class as F-026: a build that finishes and leaves
the operator one undocumented step short of a working product.

### RUN MACHINERY — VERIFIED END TO END, 02/09/26

After registering `automation.reference` and granting it
`exigence.tools.read`, `exigence.tools.write` and `exigence.communications.send`:

`run-4ea72d62fe137f3974cbfa1a137e6d453106e512d434372c00866597e9a2ec25`
**succeeded** — all four steps, through a real human approval gate:

| Step | Result |
|---|---|
| `fetch` | succeeded, 1.7s |
| `summarise` | succeeded, 2.8s |
| `write` | held for approval → approved through the API → succeeded |
| `notify` | succeeded |

So the following are now proven on real infrastructure, not inferred: run
creation, multi-step self-delivery over Cloud Tasks, the tool permission gate
(allow, approval-required and deny all three observed), the approval hold and
resolution, the audit trail, and F-027's warm instance underneath all of it.

### F-031 — FIXED, 02/09/26

`artifactAuthorityResolver` now reads the artifact's principal alongside the
boundaries it pins, and refuses the plan when that principal could not act.
Three distinct refusals, because they are fixed three different ways:

| State | Refusal |
|---|---|
| identity not registered in Palisade | *"No Palisade identity … exists … Register it and grant it the capabilities its tools declare"* |
| identity registered but disabled | *"… is disabled, so every run … would be refused"* |
| registered, holds nothing on this project | *"… holds no capability on … Grant it the capabilities its tools declare — a reading artifact needs at least exigence.tools.read"* |

At **plan** time, so the operator learns before spending anything on a build
that cannot work — the same principle as the 409s this session put on the
proxy paths.

**It refuses rather than granting**, and that is deliberate. The capabilities
an artifact needs include `exigence.communications.send` and
`exigence.financial.execute` — messaging a client's customers and moving their
money. A platform that conferred those as a side effect of an apply would be
granting an agent authority no person had approved. Whoever builds the artifact
decides what it may do; this only declines to build one that can do nothing.

**Known limit, stated rather than hidden:** it cannot check that the
capabilities *match the tools the artifact declares*, because those
declarations live in the runtime image and not the control plane. It checks
that the principal can act at all, and the message names the minimum. Closing
that gap needs the artifact's tool manifest in the control plane, which is a
larger change.

Both provisioning templates resolve `artifact_authority`, so `exigence-agent`
gets the same check as `exigence-runtime`.

Server 452 tests (+3).

---

## SESSION 2, SECOND PASS — the rest of the findings

### F-001 / F-002 — FIXED
The reconciliation observer was listing Cloud Run services, Cloud Run Jobs and
service accounts **in the client's project** and looking there for the Platform
API, the ARM evidence service, their two service accounts and the Terraform
runner. Those are one deployment shared by every client and they live in
`citadel-platform`. It even asked whether the client project held
`citadel-platform-api@<the client>.iam.gserviceaccount.com` — an address that
has never existed anywhere. So the panel was right, about the wrong project,
for every client.

Those lookups now target the host project and the nodes say whose they are.
And there is a node for the thing the client actually owns: its own Exigence
runtime, from the address the provisioner records, checked live in the client's
project. When the two disagree it says so — the registry routing a project
somewhere nothing answers is the drift F-001 asked to be made first-class,
rather than "absent".

### F-023 — FIXED
The Manifold receiver is no longer deletion-protected, so Manifold can be
turned off. Protection exists to stop an apply losing something that cannot be
recreated; the receiver holds nothing — it verifies a signature and hands the
message to the private runtime, where the conversation and the media live. The
private runtime and the secrets keep theirs, and the module test asserts the
split rather than leaving it to be read.

### F-017 — FIXED
`POST /v1/projects/{id}/retire`, gated on `platform.projects.update`.

A POST, not a DELETE, because nothing is deleted. The record is marked
`archived` with who and when; the runtime address, grants and offering scope
all survive, because a record that forgot where the runtime was would leave
infrastructure nothing could find its way back to.

The one mistake this flow can cause is a client who looks closed and is still
being billed, so a project with live infrastructure is **refused** with a 409
naming what keeps running — the runtime and its queue and scheduler, the
Manifold receiver and its media bucket, the client's Firestore database and
payload bucket. Named, not counted. The second attempt carries
`acknowledgeRemaining`.

### F-030 — FIXED
The driver had the gate's sentence and was throwing it away: `onDenied` took
the run id and dropped the denial string beside it. It now carries it,
`failRun` records it on the run, the Firestore journal reads it back — without
the decoder change the field would have been written and silently dropped on
every read — and the Console shows it beside the status badge. The audit stays
the fuller record.

### F-028 — BUILT, NOT APPLIED
`templates/arm-data-plane`: brings Firebase into existence on the project a
client already has, registers one web app, and emits the whole web SDK config
as one object — the seven values the Console's target-Firebase step otherwise
asks somebody to retype. `client-host` enables the two Firebase APIs and grants
the provisioner `roles/firebase.managementServiceAgent` (the narrow role, not
`firebase.admin` — this builds the data plane, it does not read the client's
records). Registered in the provisioning service; the Dockerfile already copies
the whole templates directory.

`terraform validate` clean, service tests cover the registration and the closed
variable set.

**Deliberately not applied.** `google_firebase_project` is a one-way door: a
GCP project given Firebase cannot cleanly be un-given it. The first apply
against a real client project is an operator's decision, not a deploy step.
Two things to know before making it:
1. `client-host` must be re-applied against `learning-gcp-404803` first, to
   enable the APIs and grant the role.
2. Then `POST /provisioning/jobs {template: "arm-data-plane"}` for
   `test-sandbox`, review the plan (it should read "2 to add"), approve.
   After that ARM's 412 should become a 200.

### Gates
`dart analyze` clean · `flutter analyze` clean · `tsc --noEmit` clean.
Platform server **462** · Console **431** · exigence **801** · ARM 34 ·
runtime module tftest 1 · every other suite unchanged.

### Second pass — deployed and verified, 02/09/26

API **`00037-qf6`**, provisioner Job on the new image. Roots applied:
provisioner `0/1/0`, runtime `0/1/0` then `3/0/0` (the observer's read roles).

| Check | Result |
|---|---|
| F-017 retire, no acknowledgement | **409**, naming the runtime URL, the Manifold receiver and bucket, and the client's Firestore and payload bucket |
| F-031 refusal | still **invalidArgument** with the register-it message |
| F-016/F-022 | **409** |
| F-024 | **412** |
| workspace, alerts, anomalies, drift, automations, runs, grants, inventory | **200** |

**F-001 / F-002 verified**, and fixing them found one more thing. Pointing the
observer at the host project turned five "Absent" rows into five
`permissionDenied` ones: the Platform API had no read access to its own
project and had never needed any, because it had always been looking at the
client's. `permissionDenied` was already the better of the two answers — "could
not look" is a fact where "absent" was an assertion about a project the
resources have never been in — and three narrow read roles
(`run.viewer`, `iam.serviceAccountViewer`, `serviceusage.serviceUsageConsumer`,
not `roles/viewer`) make it useful. The panel now reads:

```
gcp-project          healthy    gcp-platform-api   healthy
gcp-enabled-apis     healthy    gcp-arm-evidence   healthy
gcp-client-runtime   healthy    gcp-platform-sa    healthy
gcp-provisioner-job  healthy    gcp-arm-sa         healthy
gcp-firestore        absent     <- true: learning-gcp-404803 has no default
                                   database. F-028's gap, reporting itself.
```

### What is still open
- **F-028 apply** — built and committed, not applied. `client-host` first
  (Firebase APIs + the provisioner role), then `arm-data-plane` for
  `test-sandbox`. `google_firebase_project` is a one-way door, so the first
  apply is an operator's decision.
- **F-017 has no Console flow.** The route exists and is tested; there is no
  button. Hard rule #12 is not satisfied for retiring until there is one.
- **F-023 needs a re-provision to reach `test-sandbox`.** Its receiver is still
  deletion-protected from the earlier apply; the template change only lands on
  the next `exigence-runtime` build.

### Third pass — 02/09/26

- **F-017 completed.** The route shipped with nothing to call it, so retiring
  was still a Firestore edit. "Retire client" now sits under the project's
  identity fields and apart from them — it is the one control on that dialog
  that is not a setting. Two round trips on purpose: the first is refused by
  the API with the list of surviving infrastructure, and *that* list is what
  the confirmation shows, so the warning and the service cannot disagree about
  what a client actually has. A client with nothing deployed skips the
  confirmation entirely; a ceremony with an empty list in it teaches operators
  to click through the one that matters.
- **F-028 prerequisite applied.** `client-host` against `learning-gcp-404803`,
  `3 added`: `firebase.googleapis.com`, `firebaserules.googleapis.com` and
  `roles/firebase.managementServiceAgent` for the provisioner. All reversible.
  **No Firebase project was created** — that is `arm-data-plane`, and it stays
  the operator's call. It is now a single approve away.
- **F-023 re-provision** of `test-sandbox` started, to land the unprotected
  receiver on the client that already had a protected one.

Console **435** tests, deployed and hash-verified against the local build.
API `00037-qf6`.

### The remaining known gap
F-030's runtime half is committed but not deployed: the Platform API and the
Console carry the `failure` field, and `test-sandbox`'s runtime will not emit
one until the exigence image is rebuilt and the client re-provisioned onto it.
That image also carries the parallel effort's Manifold email work — committed,
`tsc` clean, 801 tests — so rebuilding it deploys both. Worth doing as one
deliberate step rather than folded into another change.
