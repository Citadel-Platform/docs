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

### F-023 — VERIFIED FIXED, 02/09/26
`test-sandbox` re-provisioned. The plan was `0 add, 1 change, 0 destroy` — the
receiver and nothing else — and Terraform state now reads:

```
cit-test-sandbox-b82c-receiver   deletion_protection = false
cit-test-sandbox-b82c-runtime    deletion_protection = true
```

which is the split the fix is about: the service that holds nothing can be
removed, the one that carries a client's runs cannot. Manifold can now be
turned off for this client. Both services Ready, and the runtime kept its
F-027 settings through the apply (`minScale 1`, `cpu-throttling false`).

---

## TEARDOWN AND REBUILD — 02/09/26

### `test-sandbox` torn down
44 Terraform resources destroyed. `learning-gcp-404803` verified empty: no
Cloud Run services, no Firestore databases, no buckets, no service accounts.
State cleared; the registry record reset to a claimed client with an empty
`offeringScope` and no recorded runtime.

Two things the teardown itself taught:
- **Run it as the provisioner, not as the operator.** `obsidian.infinitum` has
  no `storage.buckets.getIamPolicy` on the client's buckets, so the plan failed
  on two IAM reads. `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=citadel-provisioner@…`
  is the way, and it needs `roles/iam.serviceAccountTokenCreator`, which the
  operator already holds.
- **Deletion protection has to be flipped by an apply first**, and a plain
  `apply` migrates rather than unprotects once the template has moved on. A
  `-target`ed apply on the protected resource is what works, then destroy.
  The database's `ABANDON` policy means it survives the destroy and has to be
  deleted separately.

### Rebuild via the Console — in flight
ARM toggled on; the build step planned `prov-1788330708446-3aq7p7be`:
**5 to add, 0 change, 0 destroy** — Firebase, the web app, `(default)`,
`citadel-arm`, `citadel-palisade`. Exactly the designed topology, and only the
databases the enabled services need. **Planned, not approved** — approving
creates a Firebase project, which cannot be undone.

### F-032 · P2 · A template default reaches a template that cannot declare it
**Did:** Ran `client-data-plane` for the first time, in production.
**Saw:** `planFailed` — *"a variable named `container_image` was assigned on the
command line, but the root module does not declare a variable of that name."*
`CITADEL_TEMPLATE_DEFAULTS` is one map for every template; every Exigence
template needs `container_image` and this one deploys no container.
**Fixed:** the runner reads what a template declares out of its own `.tf` files
and passes only that. Parsed rather than configured, because a second list is a
second thing to keep in step — which is how this happened.

### F-033 · P2 · Selectable text is invisible to a screen reader
**Did:** Read the deployed Console through its own accessibility tree.
**Saw:** the setup wizard's numbered instructions came back as "1." "2." "3."
with nothing between them. Flutter's `SelectableText` does not enter the
accessibility tree the way `Text` does — **26 places**: every setup plan's
instructions, and every copyable id, bucket name, commit sha and storage path.
**Fixed:** `CitadelSelectableText` keeps the selection and restores the label,
with a test, because this regresses invisibly.

### F-034 · P3 · ARM's setup contradicted its own build step
**Did:** Walked ARM's setup in the Console.
**Saw:** step one told the operator the client's Firebase "has to be connected
to Citadel first, which is done in project settings" — the manual work step two
now does for them. And `_armConnectionCheck` ran on step one, reporting the
Firebase config incomplete, which step two completes. It was *optional* so it
did not block, which is worse than blocking: red text that means nothing
teaches an operator to ignore red text.
**Fixed:** copy rewritten; the check moved to the last step, where the thing it
checks exists.

### NOTE · The signed-in Console is scriptable after all
`document.querySelector('flt-semantics-placeholder').click()` builds Flutter's
accessibility tree — 150+ nodes with labels and real rects. Screenshots and
`get_page_text` still time out because Flutter paints to canvas; read with
`javascript_tool` and click by coordinate. This supersedes the earlier note
that the deployed Console could not be driven.

---

## REBUILD COMPLETED — 02/09/26

### `test-sandbox` is back, on the designed topology
`prov-1788330708446-3aq7p7be` approved and applied — the Firebase project, the
web app, `(default)`, `citadel-arm` and `citadel-palisade`. Then all four
offerings enabled and `prov-1788333236016-1aotiaky` planned **3 to add, 0
change, 0 destroy** — `citadel-conduit`, `citadel-exigence`, `citadel-baker`
and nothing else — and applied. `learning-gcp-404803` now holds:

```
(default)  citadel-arm  citadel-baker  citadel-conduit  citadel-exigence  citadel-palisade
```

The incremental property the template claims is now demonstrated rather than
asserted: a second run against a live data plane created what was missing and
touched nothing that existed.

**Driven through the Platform API, not the Console.** The Chrome extension
connected and dropped four times across the session — `list_connected_browsers`
alternating between one browser and none, and the tab group being destroyed
between calls — so the Console's own routes were called directly. The two
defects below were found by reading the Console's source against what the
rebuild actually required, not by driving it.

### F-035 · P1 · ARM's identity reached every database in the client's project
**Did:** Re-checked `customers/test-sandbox/iam` after the data plane applied,
which the previous handoff flagged as "still grants against the old
arrangement".
**Saw:** `roles/datastore.user` granted **project-wide and unconditioned** to
`citadel-arm-evidence@citadel-platform`, confirmed live in the policy. Under the
02/09/26 topology that project no longer holds one database — it holds six. So
ARM's runtime could read and write `(default)`, the client's own business data,
and `citadel-conduit`, which holds session replays: personal data about people
who never dealt with Citadel, and which the permission catalogue already treats
as categorically different from the client's own material.
**Why it matters more than a stale root:** the load-bearing reason for the whole
topology decision is that Firestore IAM can name a database and cannot name a
collection. A database each only enforces anything where the bindings carry the
condition. This one did not — and no conditioned binding existed anywhere in
`platform/infra`, so the property the decision rests on was, in the control
plane, a comment.
**Fixed:** both customer roots now carry the same condition form the Exigence
runtime module has used since it was written and that Firestore documents for
per-database access — `resource.name == "projects/<project>/databases/citadel-arm"`.
Applied to `test-sandbox` and verified in the live policy: the binding is
replaced, conditioned, and names one database.
**Not applied to `axis-education`, deliberately.** It is an active client on
`luminary-axis-dashboard` with **no provisioning jobs at all** — it has never
been built under the new topology, so `citadel-arm` does not exist there and
applying this would cut ARM off rather than narrow it. The source is correct for
where that client is going; the apply waits on its `client-data-plane` run.

### F-036 · P1 · Only ARM's setup could ever create a client's databases
**Did:** Went to enable Conduit, Exigence and Baker the way the handoff
describes — "re-running the build step for each".
**Saw:** there is no build step for each. `client-data-plane` appeared in
exactly one place in the Console: `arm-build`, inside ARM's setup plan. Conduit
and Baker have no build step at all, and Exigence's builds a runtime, not a data
plane. So a client who enabled Conduit after ARM got no `citadel-conduit`; a
client who never bought ARM got no database at all. Conduit's pages would have
been correct and empty, and Exigence's runtime would have deployed pointed at a
database that did not exist — failing on its first run rather than at deploy.
The only recovery was to reopen *ARM's* setup and re-run its build, which is
discoverable by nobody and impossible without ARM.
**Second defect inside the first:** `_citadelDatabasesFor` read
`project.offeringScope` — the scope **as saved**, which during setup is the
scope without the service being set up. A build sized off it provisions for
every service except the one the operator came here to turn on.
**Fixed:** the step is extracted as `_dataPlaneStep` and given to all four
plans, and `ServiceSetupStep.body` is handed the *prospective* scope alongside
the project. That makes the sizing right whether the build runs before the
enable step (ARM) or after it (the other three), which is why it is the scope
rather than the step order that was changed. `armDataPlaneEstimate` is renamed
`clientDataPlaneEstimate`: it was never ARM's, and now four plans show it.
A test asserts the prospective scope reaches the body, because the failure is
silent — a build that succeeds and creates one database too few.

### NOTE · `updateProjectOfferingScope` is dead code in the Console
`PlatformRegistryRepository.updateProjectOfferingScope` writes
`offeringScope` straight to Firestore. Nothing in production calls it — the
write goes through `PUT /v1/projects/{id}/offering-scope/{offering}`, because
the registry rules refuse every browser writer of that field. Only a test double
overrides it. It is a method that cannot succeed if called, left where someone
could call it. Worth removing with the two `scopeWrites == 0` assertions
repointed at the API client.

### NOTE · The offering-scope route takes a `fields` wrapper
`PUT …/offering-scope/{offering}` with `{"enabled": true}` answers
`invalidArgument: No settable fields were supplied.` — the body must be
`{"fields": {"enabled": true}}`. The message names the symptom and not the
shape; `The body must be a JSON object with a \`fields\` map.` is already the
text of the sibling parse failure and would have been the answer here.

---

## E2E SWEEP — 02/09/26

Backend sweep: **31 assertions passed**, 3 initially failed. Two of those three
were the test being wrong and the platform being right, which is worth recording
because both are properties worth keeping:

- `GET /v1/projects/{id}/principals/{p}/authority` refuses a browser token with
  403. By design: only a service credential from a trusted caller, or the
  runtime that serves that project, may resolve principal authority. A browser
  token is refused even when its holder is on the list.
- `data-flows` is `/v1/projects/{id}/exigence/data-flows`, not a project-level
  route. It answers `failedPrecondition` for a client with no Exigence runtime,
  like every other Exigence route, with a message naming the remedy.

Also confirmed good: unauthenticated and garbage tokens are 401; an unknown
route is 404 rather than 500; an unknown project's jobs are 403; applying an
applied job is 409; an undeclared variable and an unknown template are both 400;
a job id from one client is not readable under another; Conduit's public edge
refuses an absent and an unknown key with a message that names which; and every
Exigence route on a client with no runtime answers
*"No Exigence service is deployed for this project. Set it up from the
project's Services settings."* — cause and remedy in one line.

### F-037 · P1 · The Console reads Conduit's registry from the browser, and the rules deny it
**Did:** Walked Conduit's setup on `test-sandbox` after enabling it, then opened
the Conduit pages.
**Saw:** the setup's own check fails — *"Your account cannot read or write
Conduit"* — and Voice of Customer resolves, after a long blank spinner, to
*"Not permitted. 1. Confirm you are signed in as the right account. 2. Check
your roles under Palisade → Your authority."*

Both diagnoses are wrong. The operator holds every Conduit permission Palisade
can grant (`conduit.sessions.search`, `.replay`, `.update`,
`conduit.heatmaps.query`), and checking their roles will show exactly that,
leaving them stuck. The Platform API answers these correctly. The failure is
that `PlatformConduitRepository.getProjectContext` reads
`conduit_projects/{projectId}` **straight from Firestore in the browser**, and
`firestore.rules` has no match for it, so it falls to the catch-all
`allow read, write: if false`.

Confirmed empirically with the operator's own Firebase ID token against the
Firestore REST API — the same credential and the same rules the browser gets:

```
conduit_projects                    403
conduit_hosted_survey_deployments   403
conduit_source_maps                 403
conduit_alerts                      403
conduit_sessions                    403
conduit_funnels                     403
platform_projects                   200   ← the collection that has a rule
```

So this is not one page. Every Conduit surface that reads its configuration
from Firestore is structurally unreachable, for every operator, on every
project, and always has been. What still works is exactly what goes through the
Platform API: session search, replay and heatmaps.

**Why the rules are right and the Console is wrong.** `conduit_projects` holds
`projectKey` — the ingest credential the public edge authenticates with. A
browser that could read it would learn the key that lets anyone post events as
that client; one that could write it could repoint the client's ingest. So the
fix is not a rule that opens the collection. It is a Platform API route serving
this context under the API's own service account, the way
`PUT /v1/projects/{id}/offering-scope/{offering}` already does for the field
whose rules refuse every browser writer — and that route has to decide, as a
product question, whether the ingest key is ever handed to a browser at all.

**Not fixed.** The shape of the fix turns on that key question, and guessing it
would be the wrong kind of speed.

### NOTE · An invalid database name is refused late, not early
`POST …/provisioning/jobs` with `citadel_databases: ["citadel-evil"]` is
accepted, queued, and run, and refused ~45 seconds later at plan time:
*"citadel_databases may only name Citadel product databases … checked by the
validation rule at variables.tf:87."*

The refusal is authoritative and the message is good. Recorded rather than
fixed, deliberately: the closed set lives in the template that creates the
databases, and teaching the API a second copy of it is precisely the second
list F-032 was about. Only a hand-written API call can reach this; the Console
never sends a value that is not in the set.

### NOTE · "Apply 0 changes" is offered as an action
A data-plane step with nothing to do says *"Nothing to do"* and then presents an
enabled **Apply 0 changes** button. The honesty is right; offering a no-op as an
action is not.

### F-038 · P1 · Two roots both create `citadel-exigence`, so the runtime build always fails
**Did:** Ran Exigence's setup end to end on `test-sandbox` — the first real
`exigence-runtime` build since the topology decision.
**Saw:** `applyFailed` after nine minutes and thirty-odd resources:

```
Error creating Database: googleapi: Error 409: Database already exists.
Please use another database_id
```

`client-data-plane` creates every `citadel-*` database, `citadel-exigence`
included, whenever Exigence is enabled. `exigence-runtime` *also* declared
`google_firestore_database.client` with the same name in the same project. Two
roots cannot own one resource, and the second one to run loses.

**Why it had not bitten before:** while Exigence's plan had no data-plane step,
a client could reach the runtime build with no `citadel-exigence` yet and the
runtime would create it. F-036's fix put a data-plane step in Exigence's own
plan, which makes the data plane always run first — so the collision went from
latent to certain. It would also have fired for any client whose ARM setup ran
first with Exigence enabled, which is the ordinary case.

**Fixed:** the resource is removed from `exigence-runtime`. The data plane owns
the databases, because it is the root that knows which ones a client's enabled
services need; the runtime consumes the name, exactly as `exigence-agent`
already did. The name stays a constant for the same reason the rest of the
topology is. Re-planned: **18 to add, 0 change, 0 destroy**, and applied.

### F-039 · P1 · A client cannot be rebuilt within a week of teardown
**Did:** Applied the corrected `exigence-runtime` for a client that had been
torn down earlier the same day.
**Saw:** `applyFailed`, again after most of the resources were created:

```
Error creating Queue: googleapi: Error 400: The queue cannot be created
because a queue with this name existed too recently.
```

Cloud Tasks reserves a deleted queue's name for about seven days. The queue name
is derived deterministically from the client id, so **tearing a client down and
rebuilding them is blocked for a week** — and the operator learns this from a
raw Google error after a nine-minute apply that has already created a Cloud Run
service, two service accounts and ten IAM grants.

Not fixed: the remedies are a design decision, not a bug fix. Either teardown
stops deleting the queue (they cost nothing idle, and keeping it is what makes a
rebuild possible), or the name carries something that changes per build, or the
runner recognises this specific error and says *"this client was torn down in
the last seven days; Cloud Tasks reserves the queue name for that long"* before
spending nine minutes. The first is probably right and the third is owed
regardless.

**Consequence for `test-sandbox`:** Exigence cannot be built on this client id
until ~09/09/26. The half-built runtime was torn down rather than left running.

### Teardown — verified
`terraform destroy` of the Exigence runtime root: **32 destroyed**, and the
result is exactly right:

- no Cloud Run services and no runtime service accounts remain;
- all six databases survive, on the `ABANDON` policy — a Citadel teardown does
  not take the client's data with it;
- the runtime's two conditioned `datastore.user` bindings are gone, and ARM's
  remains, still conditioned.

The deletion-protection lesson from the previous teardown held: a `-target`ed
apply with `deletion_protection=false` first, then destroy.

### Verified · The topology decision is now actually enforced
Every `roles/datastore.user` binding in the client's project, read live during
the build:

```
citadel-arm-evidence@citadel-platform        → databases/citadel-arm
cit-test-sandbox-b82c-runtime@…404803        → databases/citadel-exigence
cit-test-sandbox-b82c-runtime@…404803        → databases/citadel-manifold
```

Three services, three conditions, no unconditioned grant anywhere. That is the
property the 02/09/26 decision rests on, holding across ARM, Exigence and
Manifold at once, which had never been demonstrated before.

### F-040 · P3 · A Terraform primitive is listed as a billable resource
The plan panel headed *"This creates billable resources"* lists **"1 time
sleep"** among the Cloud Run services and Firestore indexes. `time_sleep` is a
Terraform wait, not something Google bills for. In the same list, "firestore
field" is lowercase beside "Firestore index".

---

## F-037 AND F-039 CLOSED — 02/09/26, evening

### F-037 — FIXED and verified in production
`GET`/`PUT /v1/projects/{id}/conduit/context`, served under the API's own
service account. The collection stays closed, because the reason it is closed
is right: `conduit_projects` holds `projectKey`, the credential the public edge
authenticates events with.

Two new permissions, `conduit.context.read` and `conduit.context.update`, held
apart from each other — someone who may look at the ingest key must not thereby
be able to repoint where a client's events are attributed — and both placed in
`superdevOnlyPermissions`, which is documented as covering things that "expose
configuration a client does not see today". Reading this document is reading a
secret. The key *is* still served to the operator, deliberately: it is the value
they install in the client's site, and Touchpoints exists to show it. What
changed is that serving it is now a permission rather than an accident.

The whole document is carried rather than a field whitelist, unlike the offering
scope. The difference is what the fields are: an offering scope decides whether
permissions resolve, so each settable field is named; this is the operator's own
configuration, and naming its fields here would be a second schema to keep in
step with Conduit.

The Console change is one method — `PlatformRegistryRepository
.loadConduitProjectContext` — because all nine call sites went through it.

**Verified end to end in production:**
- Voice of Customer, which showed a long blank spinner and then *"Not permitted
  — check your roles under Palisade"*, now reads **"No project configuration —
  Test Sandbox has no Conduit project context yet."**
- Touchpoints, which was unreachable, renders the project key and all five
  capture settings.
- A **toggle flipped in the Console persists**: `replayCapture.enabled` true,
  read back through the route.
- And the key written through the route **authenticates at the public ingest
  edge**, while a wrong key is still refused — Console → API → Firestore →
  ingest, proved across three services.

**Not migrated, deliberately:** Voice of Customer's *save*. It batches the
context together with `conduit_hosted_survey_deployments`, which is denied too,
and sending half of that through the API would turn one atomic refusal into a
write that half-succeeds. It needs a route that does both.
`conduit_source_maps` and `conduit_alerts` are in the same position.

### F-039 — proceeding with the delete, with the warnings that were owed
Per the operator: teardown keeps deleting the queue. What was missing was
anybody being told.

- **The runner now translates the error.** `explainFailure` turns *"a queue with
  this name existed too recently"* into what it means — this client was torn
  down within the last seven days, Cloud Tasks reserves the name that long, the
  queue is named after the project, wait and re-run, and everything else the
  build made was applied and will be left alone. It keeps Google's own wording
  after the explanation, so the raw error is still searchable. A second entry
  covers the F-038 database collision. Anything not recognised is passed through
  unchanged, because a wrong explanation is worse than a raw one.
- **The Console warns where the decision is made.** The retire dialog now says
  that a teardown afterwards blocks rebuilding under the same project id for
  about seven days. Retiring destroys nothing, so this is not the moment it
  bites — it is the moment somebody decides, and the wall is a week away.

### F-041 · P1 · The public edge answered "try again" to a condition no retry can clear
**Did:** Sent a real, fully-formed event through `POST /v1/events` with the key
written through the new context route.
**Saw:** `500 — "The Conduit ingest service failed unexpectedly"`, with
`retryable: true`. The request id tied to a stderr line naming the cause, which
is the one thing that worked: `FormatException: googleCloudProjectId must be a
non-empty string`.

The project's context has no `target` — the field naming which Google Cloud
project its events are written to. Two paths reach it: no context document at
all threw a `StateError`, and a document without a `target` threw a
`FormatException` out of a decode that falls back to reading the whole document
and then insists on `googleCloudProjectId`.

Neither is a fault. The request was well formed, the key authenticated, nothing
broke: the project is not finished being set up. Reporting it as an internal
error was wrong twice — it told the caller nothing, and it told them to retry,
so an instrumented site would keep sending into a project with nowhere to record
the events, forever, against a condition only an operator can clear.

**Fixed:** a `failedPrecondition` code, held apart from `invalidArgument` (which
blames the caller) and `internal` (which says nothing), and a 409 that names the
project, what is missing and who fixes it. Verified in production:

```
409 failedPrecondition · retryable false · details.projectId test-sandbox
"This project has no Conduit ingest destination configured yet, so there is
 nowhere to record these events. An operator finishes this in the Citadel
 console under the project's Conduit setup."
```

### Live state after this work
| | |
|---|---|
| `citadel-platform-api` | `00040-4cv` — the Conduit context route |
| `citadel-conduit-ingest` | new digest — the ingest precondition |
| `citadel-provisioner` (Job) | `16967053…` — `explainFailure` |
| Console | `163e9ec8729ffa47`, verified against a freshly built bundle |

Tests: Console 443 · server 479 · conduit ingest 134 · palisade authority 48 ·
provisioner 16. Backend sweep unchanged at 31 pass.

---

## FINISHING UP — 02/09/26, late

### Conduit is complete: no collection is read from the browser
The last three — `conduit_source_maps`, `conduit_alerts` and
`conduit_hosted_survey_deployments` — now go through
`GET`/`PUT /v1/projects/{id}/conduit/entries/{kind}`, and Voice of Customer's
save through `PUT .../conduit/voice-of-customer`, which commits the context and
the deployments it implies in one write. `platform_firestore` reaches no
`conduit_*` collection at all now.

Two properties worth keeping, both verified in production:
- **`kind` is a closed set, not a collection name.** This runs as the API's own
  service account, so a kind taken from the caller would read any collection.
  `entries/palisade_grants` answers `No `palisade_grants` here.`
- **The flat collection's `projectId` is stamped by the server.** A deployment
  written with `"projectId":"axis-education"` is stored as `test-sandbox`. It
  is the only thing separating one client's surveys from another's.

Walked in the Console: Alerts reads back a rule written through the route,
Touchpoints renders the key and persists a toggle, Journeys loads, and Voice of
Customer — a blank spinner then "Not permitted" this morning — renders its whole
configuration surface and **saves**, `feedbackWidget.enabled` true through the
atomic route.

### F-043 · P1 · The Console showed the wrong reason for every 409
**Did:** Opened Exigence for a client with no runtime.
**Saw:** *"Changed elsewhere — the automations changed since this screen loaded.
Reload, then apply the change again."* On a page that had loaded nothing and
changed nothing.

Every API client decoded the platform's error body and threw the status alone,
so the sentence the server had written for this reader was discarded and
replaced by a guess made from three digits. The platform answers 409 for two
different things and the Console only knew one.

**Fixed:** `apiFailureText` carries the platform's `code` and `message`, and a
409 that is a `failedPrecondition` renders as "Not set up yet" with the server's
own sentence. It carries those two fields and nothing else — session search
asserts that private detail never reaches an exception message, and the existing
test caught it when this first tried to pass the whole body through. Verified:
the page now reads *"No Exigence service is deployed for this project. Set it up
from the project's Services settings."*

### F-042 · P1 · The client's Firebase config was computed and thrown away
**Did:** Walked ARM's setup to its last step, which had never been done.
**Saw:** the final check red, asking the operator to fill in the target Firebase
project ID, API key, app ID and messaging sender ID by hand — the manual work
`client-data-plane` exists to remove.

`client-data-plane` registers the web app and emits `web_app_config`, described
in the template as "what the Console needs to fill the target Firebase fields in
without anybody retyping seven values off a screen". Nothing read it: the runner
recorded `exigence-runtime`'s outputs and returned early for every other
template. Every client ever built this way has an empty config.

**Fixed:** the runner records it on the project. Verified on `test-sandbox`,
which predates the fix — a data-plane run with **nothing to create** still
re-reads its outputs, and six fields landed. `measurementId` is correctly absent
because Analytics is off.

That is also why the "Apply 0 changes" button came back, renamed. Removing it
was wrong: a zero-change apply is exactly how a client built before an output
was recorded gets it recorded. It now says **"Re-read this build's details"**,
which is what pressing it does.

### F-044 · P1 · The function that describes a Firestore failure was one
**Did:** Read the Details under ARM's failing check.
**Saw:** `int.fromEnvironment can only be used as a const constructor`.

`PlatformFirebaseRuntime.firestoreEmulatorPort` omitted `const` where the two
getters beside it have it, and dart2js throws on a non-const `fromEnvironment`
in a release build. `describePlatformFirestoreFailure` reads it
**unconditionally, before any branch** — so in production every attempt to turn
a Firestore error into a sentence threw, and what reached the operator was that
error instead of theirs.

**Fixed**, and the truth underneath was an honest, actionable one: *"Target
project auth needs attention — no Google session is active for the target
Firebase project yet. Use Connect target auth, then rerun validation."* Amber,
not red; an outstanding setup step rather than a fault, which is what it always
was. A test reads the source, because on the VM a non-const `fromEnvironment`
evaluates happily and no ordinary test could catch it.

### The Console, swept
Every product section walked on `test-sandbox`:

| | |
|---|---|
| ARM | Console and Issue Fingerprints render, honest empty states |
| Conduit | Overview, Touchpoints, Journeys, Alerts, Voice of Customer — all render, and both writes persist |
| Exigence | reports the truth for a client with no runtime |
| Baker | Modules lists six; its wizard completes, and its last check honestly reports an unknown rather than a false pass |
| Manifold | Channels renders, verified sending domain, honest empty state |
| Palisade | Access lists three grants; superdev now carries **75** permissions, the two new Conduit ones included |

All four setup wizards walked end to end. Each now carries the shared data-plane
step, and each planned **0 to add** against a client whose data plane is
complete — idempotency demonstrated from four different plans.

### Final state
| | |
|---|---|
| `citadel-platform-api` | `00041-65z` |
| `citadel-conduit-ingest` | redeployed |
| `citadel-provisioner` (Job) | `188bdf7c…` |
| Console | `8becab57…`-then-rebuilt, verified against a freshly built bundle each time |
| `test-sandbox` | 6 databases, 4 offerings, Conduit configured, Firebase config recorded |

Tests: Console 448 · server 485 · conduit ingest 134 · palisade authority 48 ·
provisioner 16 · contracts 4 — **735 passing**. Backend sweep 31. Analyzers,
`terraform fmt -recursive -check` and `validate` clean.

---

## CREATING A CLIENT — 02/09/26, night

### F-045 · P1 · Project creation was impossible, and the reason was invisible
**Did:** Created "User Test 1" through the Console, as the operator reported
failing.
**Saw:** at the last step, *"Not permitted — your account cannot read or write
the project."* The account was never the problem: the operator holds
`platform.projects.create`, the Palisade identity document carries it, and
`canCreateProjects()` passes.

Two faults, and the second is the one worth remembering.

**One:** `isValidExigenceScope` accepted five keys and the Console writes eight.
It gained `citadelMcpEnabled` and `runtimeBoilerplate` with the runtime
boilerplate choice, and `manifoldReceiverServiceAccount` when the receiver got
an identity. `keys().hasOnly([...])` is false for a key it has not been told
about, and one false predicate refuses the document. Proved by writing the
document as the operator's own browser token: five keys create it, adding
`citadelMcpEnabled` alone answers 403.

**Two, and fixing the first did not fix it.** The document still failed.
Bisecting showed removing *any* one field made it pass, and shrinking either
`targetFirebase` or the Exigence scope made it pass. Nothing was wrong with any
field. **Firestore caps how much a rule may evaluate per request, and this
ruleset had grown past it** — `isValidProject` checked the length of every
optional string and `isValidArmFirebaseConfig` did the same for eleven more.
Exceeding the cap is refused with a plain `PERMISSION_DENIED`, which is exactly
what a rule saying no looks like. The Console reported the only thing it could
see.

**Fixed:** the per-field length checks are gone. They cost the most and bought
least — `hasOnly` is the containment guarantee, Firestore already caps a
document at 1 MiB, and a Firebase web config is shipped to every browser that
loads the client's application. What is kept is what decides platform
behaviour. Verified against the deployed rules: the full document the Console
writes is accepted, an unknown key is still refused, and `runtimeUrl` set at
creation is still refused. `manifoldReceiverServiceAccount` joins the other two
in the update guard and the create-time null checks.

**Note for later:** this ruleset is now close to a limit that fails silently.
Adding another validated field may reintroduce it, and the symptom will again
be "your account cannot create projects". If the registry grows much further,
project writes should move behind the Platform API the way `offeringScope` and
the Conduit collections already have.

### F-046 · P2 · A client was given a database for a service it does not have
**Did:** Configured `user-test-1` for Exigence alone, everything else off.
**Saw:** the data plane planned `citadel-arm` anyway. `_citadelDatabasesFor`
listed it unconditionally while every other product's database followed its
toggle — against the argument the template makes in its own comment: *"a client
who bought ARM alone gets `citadel-arm` and nothing else."*

**Fixed**, with tests, and the corrected plan is **5 to add** and names no ARM
database. Only visible on a client configured for one service, which is the
first time that has been done.

### Where `user-test-1` stands
Created on GCP `testproj-448205` (an existing project of the operator's),
Exigence enabled and the other three off. The provisioner was granted the ten
roles it holds on the other client project, and the base APIs enabled.

The data-plane apply then stopped:

```
Error creating Database: googleapi: Error 403: This API method requires
billing to be enabled ... testproj-448205
```

`citadel-exigence` exists — Firestore's first database in a project is
free-tier — and `(default)`, `citadel-palisade`, Firebase and the web app do
not. `testproj-448205` has no billing account; `learning-gcp-404803` uses
`billingAccounts/013BA6-4DC381-53DA60`. **The operator is attaching billing.**
The build is idempotent, so resuming creates what is missing and leaves the
rest.

---

## EXIGENCE, END TO END ON A CLIENT BUILT UNDER THE NEW TOPOLOGY — 02/09/26

`user-test-1` on the operator's own GCP project `testproj-448205`, Exigence
enabled and ARM, Conduit and Baker off. This is the first client created,
configured and exercised entirely under the 02/09 topology, and the first
configured for a single service.

### The run
`exigence.reference.summary` executed and **succeeded**: `fetch`, `summarise`,
`write`, `notify`, with `write` holding at a real human approval gate until it
was resolved. The Console lists it as Succeeded, Manual, **USD 0.000303**.

The audit trail is the part worth reading:

```
fetch      tool.permission.allowed            automation.reference
summarise  tool.permission.allowed            automation.reference
write      tool.permission.approval_required  automation.reference
write      approval.approved                  firebaseIdToken:operator-e2e
notify     tool.permission.allowed            automation.reference
```

Each carries `grantedVia`, a reason sentence and an integrity hash. The
permission gate is recorded in two of its three outcomes, and the approval is
attributed to whoever resolved it.

**15 of 17 Exigence routes answer**: automations, runs, run detail, spans,
audit events, approvals, artifact vocabulary, data flows, watchdog
configuration and ingress, billing summary and per-run execution, artifacts and
their revisions.

### What refusing well looks like
Two refusals arrived before anything was spent, each naming the remedy:

- *"The Palisade identity `automation.reference` holds no capability on
  `user-test-1` … Grant it the capabilities its tools declare — a reading
  artifact needs at least `exigence.tools.read` — then build."*
- *"This project has no published Data Handling Boundary named `default`.
  Publish one before building the service."*

That is F-031 working on a genuinely fresh client.

### F-047 · P2 · A refusal the client's runtime meant was reported as a platform fault
`watchdog/relay` is a route this runtime does not serve; it answers 404. The
proxy reported `502 unavailable — "The Exigence private service returned an
invalid response"`, `retryable: true`. Both halves wrong: a 404 is an answer,
and retrying cannot change it. The cause was testing the body before the
status, so a 4xx with a non-JSON body fell into the "invalid response" branch.
**Fixed** — a 4xx now carries its own status and a code named for it, and is
not retryable. The upstream body does not travel. Verified live: that call is
now `404 notFound`, `retryable: false`.

### F-048 · P2 · Two Watchdog surfaces do not answer, and one cannot say why
On the current runtime image, `watchdog/relay` answers 404 and
`watchdog/authorization` answers `400 {"error":"invalid_request"}` for a request
carrying exactly the `from` and `to` it documents as required. `configuration`
and `ingress` both answer with real content, so this is not a stale image — it
was rebuilt from source and repinned during this session and the behaviour is
unchanged.

Two things are worth separating. Refusing rather than returning an empty report
is **right**, and the source says so: *"'Nothing was denied' is the one wrong
answer a safety surface can give, and a runtime that cannot answer must not
appear to have answered."* But `{"error":"invalid_request"}` carries no detail,
and the handler has two distinct reasons for it — an unsupported query
parameter, or a missing window. From outside they are indistinguishable, which
is why this took a direct call to the runtime to characterise at all. The
sibling `billing/summary` says *"a summary needs a month"*; these should say as
much.

**FIXED 03/09/26, and the root cause was not the one above.** The operator
settled the product question — relay is a feature and should work — and the
handler turned out to be complete all along. Three layers were discarding what
it said:

1. `PrivateExigencePlatformApi.handle` mapped every error class to a bare
   `{"error": ...}`, dropping the message its thrower wrote. The three sibling
   APIs already carried `detail`; this one did not.
2. The in-route 404 for a deployment with no data-flow audit was likewise
   detail-free, so "this runtime cannot answer that" and "no such route" were
   the same response.
3. **The real cause.** `createHandlerChainHttpServer` treated *any* 404 as "not
   my path" and moved to the next handler, so a deliberate refusal was walked
   past and the caller got the chain's plain-text `not found`. That is why the
   404 looked like an unimplemented endpoint: the runtime had answered, in
   detail, that the project had published no relay declaration, and the answer
   was thrown away three lines later.

The chain now steps over a 404 only when it carries no reason — the shape a
handler uses to decline a path it does not own, which the webhooks depend on —
and stops at one that does. Verified through the proxy against the live
`user-test-1` runtime: `{"error":"invalid_request","detail":"from and to are
required"}` and `{"error":"not_found","detail":"this project has published no
relay declaration"}`. Guarded by tests in `node_http_server.test.ts` and
`private_platform_api.test.ts`.

### Onboarding gaps a new GCP project exposed
None of these were visible while every client lived in one project.

1. **Billing.** `testproj-448205` had no billing account; Firestore's first
   database is free-tier, so the data plane created `citadel-exigence` and then
   failed on `(default)`. The operator attached billing and the build resumed —
   idempotently, creating only what was missing.
2. **The Cloud Run service agent could not read Citadel's image.** The working
   project's agent had been granted `artifactregistry.reader` on the
   `citadel-exigence` repository by hand. Nothing does that for a new client, so
   the apply created thirty resources and then failed on the service.
3. **The Cloud Run host suffix is unknowable before the first deploy.**
   **RESOLVED 03/09/26 — the premise was wrong.** See F-050.

Gaps 1 and 2 still want the same answer: a client bootstrap that does them,
which is what 0.3.6.a is for. Gap 3 no longer exists.

### A lesson about drift
The provisioner job's image was updated with `gcloud run jobs update` earlier in
the session. A later `terraform apply` of the provisioner root silently reset it
to `var.container_image` — an older build that predates the F-038 fix — and the
next provisioning run failed with the 409 that fix removed. The digest is now
pinned in `images.auto.tfvars` and Terraform and reality agree. Out-of-band
updates to a Terraform-managed resource are exactly the drift the Watchdog
exists to notice, and they are worth not making.

### F-049 · P1 · The consent step every setup plan needed was not in any of them
0.3.6.a's server half has existed since 02/09; the Console had no way to reach
it, so admitting Citadel to a client's Google Cloud project was a thing an
operator did by hand or not at all. Every plan went straight from "turn it on"
to "build the data plane" — and Terraform runs as Citadel's own provisioning
account, which has no standing in a project it has never been admitted to, so
the build failed on its first API call with a permission error that said
nothing about the missing consent.

**Fixed.** A shared `_authorizeStep` now sits immediately before the data-plane
build in all four plans, using the Google Identity Services *token* client:
JavaScript origins only, no redirect URI, no client secret anywhere in the
Console. What comes back is an access token with a one-hour life and no refresh
token behind it, spent immediately by the server and never stored — the
constraint the server side was already written to. A test asserts the ordering
per plan rather than merely the step's presence.

Two defects were found by driving the deployed Console rather than by reading
it. A 403 from this route was being classified as the caller's Palisade
authority being too narrow, sending the operator to widen a Citadel role that
has no bearing on whether their *Google* account may administer someone else's
project; and a timed-out consent window was told, alongside the correct advice,
to go and check its Google permissions — a second, unrelated accusation. Both
have tests.

### F-050 · P2 · A per-project value had a default, and the default was another project's
`run_host_suffix` was a template default set to the *shared* host project's
suffix, supplied to every client that had none recorded. A client with a project
of their own therefore deployed cleanly and pointed its task target at a host
that does not exist — the silent failure where a runtime answers requests and
never receives its own work. The recorded-value workaround was to deploy a
throwaway service, read the suffix off it, record it, and rebuild.

**The premise was wrong.** Cloud Run issues every service *two* addresses: the
opaque `<service>-<hash>-<code>.a.run.app`, and a deterministic
`<service>-<projectNumber>.<region>.run.app`. Both resolve to the same service —
checked against a live runtime before anything was changed. Only the first is
unknowable in advance, and the project number is readable before anything is
deployed, so the template now composes the second and there is nothing left to
discover, default, or record.

An earlier note in the provisioner root recorded that this form had been *tried
and rejected*, because Cloud Run "issued the older per-project hash instead".
That conclusion was an artefact of the check that tested it: it compared the
composed URL against the whole of `cloud_run_uri`, which can never match the
deterministic form by construction. The note has been corrected in place.

Three things were fixed together, and the middle one was found only because the
first fix deployed a wrong address that the check let through:

- The template derives the address from the client's project number, keeping
  `run_host_suffix` as an override for a client pinned under the old scheme.
- **The runner's mismatch check was too weak.** Relaxed to "both hosts start
  with the service name", it accepted
  `cit-user-test-1-acb1-runtime-xl7wk7pjxa-uc.a.run.app` — the right service
  name carrying another project's suffix — and that address was deployed before
  the gap was noticed. It now reconstructs the deterministic form from the
  service name, project number and region, and accepts only that or the issued
  address. The logic moved from `bin/` to `lib/` so it can be tested at all,
  and the case it let through is now a test.
- **The runner stopped recording the suffix.** With the address derived there is
  nothing to tell the next build, and continuing to write it made every
  alternate build flip the runtime between its own two addresses and roll a
  revision to do it. The field is no longer in the write mask, so a client who
  has one keeps it and a client who does not never gets one.

Verified end to end on `user-test-1`: the derived address deploys, a repeated
plan is a genuine no-op, and a run's first step was enqueued against that
address and came back `succeeded` — which is the only thing that actually proves
the runtime can reach itself.

### F-051 · P1 · A client project could not pull the image it was being deployed
Creating a Cloud Run service checks that the *deploying* identity can read the
image; starting a revision needs the *client project's own* Cloud Run service
agent to pull it. Those are different principals and only the first was granted,
so an apply into a project Citadel had not built in before created thirty
resources and then failed on the service — the worst place to stop. The one
project that worked had been granted by hand.

**Fixed, with the operator's approval for the new power.** The runtime template
grants `roles/artifactregistry.reader` to the client's service agent, on the
repository the image is actually pulled from — derived by splitting
`var.container_image`, so the grant cannot name a repository that does not hold
the image. The provisioner can set that policy through a custom role carrying
`artifactregistry.repositories.getIamPolicy` and `setIamPolicy` and nothing
else; `roles/artifactregistry.admin`, which also carries delete on the
repository and its contents, was deliberately not used.

Verified by removing the hand-made grant for `testproj-448205` and re-running
the build: the plan was exactly one resource, the apply restored the binding,
and the runtime still deploys.

### F-052 · P2 · An unbilled project fails nine minutes in, at the least legible moment
Firestore's first database in a project is free-tier, so a project with no
billing account creates one database, succeeds, and fails on the second. Nothing
looked before starting.

**Fixed.** The bootstrap now reads `cloudbilling.googleapis.com` under the
operator's own token and reports the answer; the consent step shows a warning
when billing is absent. Reported, never enforced — Citadel cannot attach a
billing account on a client's behalf, and failing the bootstrap would refuse to
do the part it can do. Three states, not two: an operator who administers the
project but not its billing account gets a 403 here, and "could not check" is
kept distinct from "no billing" because telling somebody their billing is off
when it is not sends them to fix the wrong thing. The live response shape was
checked against `testproj-448205`.

### GeoIP — the feature was already complete; only the wiring was missing
Country resolution turned out to be built end to end: the resolver, the
catalogue with each candidate's licence and attribution line, the loader that
refuses a deployment naming one environment variable without the other, the
Console's per-project switch and disclaimer, and the Terraform module variables.
The ingest binary already loads it at start and prints which licence it is
operating under.

The one gap was that the production runtime root never passed the module's
`geo_database_path` and `geo_database_id` through, so switching it on would have
meant editing the module wiring rather than setting a value. Both are now root
variables defaulting to empty. Taking a licence is a `COPY` in the ingest
Dockerfile and two entries in `terraform.tfvars`; nothing else changes.

No database has been obtained and none is bundled — the operator configures that
when they take a licence.

### GeoIP — DB-IP Lite taken, and one defect the real file exposed
The operator chose DB-IP IP to Country Lite on 03/09/26: CC BY 4.0, no account,
no EULA, and explicit permission to redistribute inside a container image with
the attribution kept intact. The 2026-09 table is bundled in the ingest image
(4.3 MB compressed, expanded in the build stage because the final stage is
`scratch`), with provenance and the attribution in `assets/geo/README.txt`.
Switched on in production: the service prints `Geo database: DB-IP IP to Country
Lite, 717152 ranges, Creative Commons Attribution 4.0 International` at start.

**F-053 · P2 · `ZZ` would have been rendered as a country.** ISO 3166-1 reserves
`ZZ` for "unknown", and DB-IP uses it for the special-use blocks — 18 ranges in
this table covering RFC 1918 private space, loopback, link-local and carrier
NAT. It is two letters, so the parser's field validation accepted it, and the
first session from a private address would have put a country called ZZ in the
Console's country filter and on the choropleth. The resolver's own contract
already said the right answer — *"Null rather than `'ZZ'`… an address in no range
is a gap in the table"* — but only covered addresses in no range, not ranges
published **as** ZZ. Dropped at parse time. Found by loading the real file, not
by reading the parser.

**F-054 · P2 · The Console could credit a database the deployment does not carry.**
**FIXED 03/09/26.** Attribution is discharged per project: the operator switches country
resolution on, sees the licence dialog, acknowledges it, and the acknowledged id
is recorded and rendered. But the dialog offers all three candidates, and the
Console has no way to learn which database the ingest deployment actually holds
— that is a server-side environment variable. An operator who acknowledges
IP2Location while the image carries DB-IP publishes a false credit and fails
DB-IP's attribution requirement at the same time. The fix is for the platform to
expose the configured database id so the Console offers only that one; it is a
new field rather than a change of behaviour, and it is worth doing before a
second database is ever bundled.

### The Manifold receiver, provisioned and proven for the first time
It had never been deployed. Enabling it creates the platform's only `allUsers`
Cloud Run service, so it was built on `user-test-1` with the operator's explicit
approval, verified, and destroyed — no public endpoint was left standing.

Manifold is not one of the four offerings; it is a capability of the Exigence
runtime template, so building it did not contradict `user-test-1` being an
Exigence-only client.

The apply created exactly ten resources, all the receiver's own — its service
account, its logging and Firestore roles, the media bucket and its binding, the
`actAs` binding, the settle delay, the service, the `allUsers` binding and the
Cloud Tasks enqueuer — and touched the existing runtime not at all. The teardown
destroyed exactly the same ten.

What the branch was proven to do:

- **It boots with no channel published.** This is the documented and correct
  first state: refusing to boot there had made the provision itself
  un-appliable, because the receiver would crashloop before anyone could publish
  the channel that would satisfy it. Every webhook path 404s until one exists,
  and a channel published later becomes reachable with no redeploy, because
  channels resolve per request from published revisions.
- **It is reachable without authentication**, which is the whole point of it and
  the reason it is a separate service.
- **It exposes nothing else.** `/v1/projects/user-test-1/exigence/runs` on the
  public service answers 404: the private runtime's routes are not on it. That
  is the property that makes an `allUsers` service acceptable at all, and it had
  never been checked against a running one.
- **The runtime was unaffected** throughout, before and after.

Still unproven, and only provable with real credentials: signature verification
on an actual Meta delivery, and media collection into the bucket. Both need a
published channel with its secrets, which is a client action.

### F-054, fixed
The Platform API now reports `deployedGeoDatabaseId` on
`GET /v1/projects/{id}/conduit/context`, and the licence dialog states that
database rather than offering a choice of three. Both the API's value and the
ingest service's `CITADEL_CONDUIT_GEO_DATABASE_ID` come from one root variable,
`conduit_geo_database_id`, passed to both modules — which is what makes it
impossible for the id the Console credits and the file actually loaded to
disagree.

Deliberately reported outside `context` rather than stored on the project: it is
a fact about the deployment, and a copy kept per project is precisely the value
that would drift from the file in the image.

When the platform cannot answer — an older revision, or a deployment carrying no
database — the id is empty, and the dialog says it cannot check the choice and
points at the ingest service's start-up log, which names the file. Empty is never
resolved to a default: falling back to the first entry would silently credit
DB-IP on a deployment carrying something else, the same failure in a quieter
form.

Verified in the deployed Console against `test-sandbox`: the dialog reads
*"DB-IP IP to Country Lite — the file this deployment carries"*, with CC BY 4.0,
the exact attribution line, and no dropdown. Cancelled rather than accepted —
the record names who took the licence on for the client, and that has to be an
operator.

### A hosting deploy that dropped the SPA rewrite — and how it was caught
The Firebase CLI was, mid-session, authenticated as an account with no access to
`citadel-platform`, so a Console deploy was made through the Hosting REST API
under the correct identity instead. It worked and served a byte-identical
bundle — and 404'd every path but `/`.

`firebase.json`'s `rewrites` and cache `headers` are applied by the CLI; the API
does not infer them, and a version created without a `config` serves files
only. The Console is a single-page app whose routes have no files behind them,
so every deep link broke. Caught by opening one rather than by the checks that
had just passed: `curl /` was 200, the bundle hash matched, and both were true
of a site nobody could navigate.

Fixed by supplying the same config on the version, then redeployed through the
CLI once the operator corrected the login, so the config comes from
`firebase.json` and not from a second copy of it in a script. The lesson is the
narrow one: a deploy path that reproduces the artefact is not the same as one
that reproduces the *serving behaviour*, and only a request to a non-root path
tells them apart.

## 03/09/26 — Manifold and WhatsApp, driven end to end

Everything below was found by publishing a real channel against a real Meta
sandbox WABA and sending real messages through it. None of it was visible from
the test suites: 930 Exigence unit tests, 473 Console tests and 500 Platform API
tests were green throughout, before and after each fix. The receive path had
never been executed against Meta, and every defect lived in the seam between
services rather than inside one.

Read as a group, they have one shape. The 02/09/26 decision moved a client's
data into a project of their own, and each of these is a place where something
did not move with it, or was never built at all because nothing had exercised
it. That is the risk the decision carried, and this is the bill for it.

**F-056 · P0 · No channel could be published, for any client.**
Publishing verifies the credentials against Meta first, and that call is made
from the Platform API — the control plane, because that is where the operator
is. The runtime template bound the receiver and the runtime to a channel's
secrets and never the API. So verification failed on its first read, publication
is gated on verification, and no WhatsApp channel had ever been published in any
client project. Invisible because nobody had tried.

Fixed by binding the Platform API's service account to exactly the secrets a
channel names, per-secret and `secretAccessor` only, through a new
`manifold_verifier_service_account` that arrives from `template_defaults` and is
not in the API's accepted variable list — a caller who could name it could point
a client's channel secrets at an identity of their choosing.

The security shape is inherent and worth stating plainly: verify-on-publish
means the control plane reads a client's WhatsApp access token. That is the
design's own consequence rather than something this grant introduced, and it is
recorded here as a decision. The bounding that makes it acceptable is that this
identity — shared by every client — never holds a project-wide grant anywhere.

**F-058 · P0 · Enabling Manifold never created the database Manifold writes to.**
Product databases come from `client-data-plane`, out of a set the Console
composes from the client's *enabled offerings*. Manifold is not an offering, so
nothing ever named `citadel-manifold`. Enabling Manifold deployed a receiver,
granted two services on that database, pointed the runtime at it, and left it
uncreated. The service started, passed its health check, verified a signature,
and failed on the first customer message.

Fixed by creating it in `exigence-runtime`, where Manifold is switched on, so
that one rule holds: switching Manifold on builds everything Manifold needs, in
the build that switches it on.

**F-060 · P0 · No secret has ever been readable from the runtime.**
`GoogleSecretVersionAccessor` asked for `accessSecretVersion` with POST. It is a
GET, and Google's frontend answers an unmatched method on a `:verb` path with a
404 *HTML page* rather than a 405 — so the failure surfaced as

    the verify token could not be read: <!DOCTYPE html>

which reads as a missing secret or a missing grant, and sent the investigation
to Secret Manager's IAM policy twice before anyone looked at the method. Every
WhatsApp token, every signing secret and every webhook trigger secret is read
through this one class. It is constructed only in the runtime bootstrap, so
every unit test injected a fake and it had never once been called.

**F-061 · P0 · The receiver was granted on the wrong database.**
It reads the published channel from the client's control database and writes the
conversation into Manifold's, and had only the first. A delivery arrived,
verified, passed its signature check, and died writing the message — a 500,
which Meta retries, indefinitely, for a message that can never land.

**F-063 · P0 · Every Manifold mutation from the Console was refused.**
The actor the Platform API forwards is `<credentialType>:<subject>` —
`firebaseIdToken:...` for a signed-in operator. `manifold_api.ts`,
`billing_api.ts` and `knowledge_base_api.ts` each validated it with the plain
identifier pattern, which has no colon, so every reply, note, assignment and
draft came back `400 trusted actor required`. Manifold's entire write surface
was unusable.

This is a recurrence. `validation.ts` already carries `actorIdPattern` for
exactly this reason, and its own comment records that the rule had been restated
in three places and that fixing one copy only moved the refusal one layer
deeper. Three further copies were missed then. The test added now reads the
sources and fails on any module that spells the rule out again, because the
defect is a copy of a rule rather than a wrong answer from any one function.

**F-066 · P0 · A delivery status disabled the webhook.**
Recording a status means finding the message it names across every thread — a
collection-group query on `messages` by `providerMessageId`. Firestore indexes
every field of a collection automatically and indexes none of them across
collection groups, so that query failed with `FAILED_PRECONDITION`. Meta sends a
status for every message a business sends; each one 500'd, Meta retried, and
enough consecutive failures has Meta disable the webhook — which is the inbound
path too. **A business that sent a single reply would have stopped receiving.**
Found by sending one.

**F-062 · P1 · Four operational reports went nowhere, in every deployment.**
`runtime_entrypoint` is the only production caller of either compose function
and passed no `logger`. Every report the composition makes is written as
`args.logger?.error(...)` — optional on purpose, because none is worth failing a
request over — so each became a no-op: a receiver started with no channel at
all, a customer's WhatsApp message that no artifact answered, the same for
email, and a cost record that could not be written. Each is a case the code
deliberately does not throw on, which makes the report the only trace it leaves.

**F-064 · P1 · The Console dropped the reason on every Exigence failure.**
The platform answers `{code, message}`; Exigence and Manifold answer
`{error, detail}`. Only the first was read, so a refusal arrived as
*"The Exigence API request failed (400)."* with the sentence that said why left
unread in the body. Carrying `detail` that far was the whole point of the F-048
work; this was the last hop it never made.

**F-065 · P1 · A refusal from Meta was rendered as a Palisade problem.**
The API answered 403 with `refused` and Meta's own words — *"(#133010) Account
not registered"* — and the Console said *"Not permitted — Your access does not
cover this"*, then sent the operator to Palisade to add a role. No role in
Palisade registers a phone number with Meta. 403 is the right status for both a
missing grant and a downstream refusal, which is exactly why only the body can
tell them apart. Same defect as F-049, one layer out.

### F-057, closed — the record moved to the client's database

The Platform API writes channel revisions to Citadel's own registry. The
receiver reads them from the client's control database, which is the only one it
is granted on. **A published channel is therefore invisible to the receiver that
serves it**, and every delivery is refused with *"the channel is not published,
is disabled, or is another project's"*.

The receiver's side is not movable: its Firestore grant names one database under
an IAM condition, and that condition is what stops one client's public service
reading every other client's channel tokens. So the record has to reach the
client's database. How it gets there is the open question, and the two answers
differ in what the control plane ends up holding:

* **Grant the Platform API `datastore.user` on the client's control database.**
  About thirty lines, reusing the F-056 shape. Firestore IAM can name a database
  and cannot name a collection, so this is read/write over that client's whole
  Exigence control database — artifact revisions, configuration, approval
  routing, runs — for an internet-facing service, bypassing every invariant the
  runtime enforces.
* **Publish through the client's runtime.** The Platform API already resolves a
  per-project OIDC client to the runtime, and this is how artifact revisions are
  already published. The control plane gets no Firestore access to client data
  at all. It costs a new private route, a client for it, and the ordering
  question of what happens when the registry write and the push disagree.

The second was chosen, and taken the whole way: **the registry copy is gone**.
The client's database is the single home for a channel record, the Console
lists channels through the runtime the way it already lists conversations, and
the control plane holds no Firestore access to client data at all.

Going the whole way rather than dual-writing settles something a dual write
could not. The revision number is computed from a listing, and with two stores
the registry computes it while the runtime accepts whatever it is told — two
operators publishing at once produce two revision 3s in the store that
matters. With one store the document id is derived from project, channel and
revision, the write is a create rather than a set, and the second publisher is
refused with a conflict they can see instead of silently overwriting the first.

What it cost: a pair of routes on the runtime's private API — one to list the
stored revisions, one to write a single revision once — and a
`ManifoldChannelStore` seam in the Platform API with two implementations, the
runtime-backed one for every client and the registry one kept for the emulator
tests, which have no runtime to publish through. The store is a required
constructor argument rather than a defaulted one, for the reason this finding
exists: a default that points at the wrong store still writes, still returns,
and only fails at somebody's first customer message.

Two details worth keeping:

* The payload crosses as the string it was hashed over and is stored as that
  string, never re-encoded. The digest is an attestation over those bytes, and
  a round trip through the runtime's own JSON would be a second chance for the
  record and its attestation to disagree.
* Publishing carries two identities. `actorId` is the operator's email, which
  is what the record says published it; `principalId` is the authenticated
  principal, which is what the runtime's actor rule accepts — an email is
  refused there, because it has an `@` in it. That is F-063 again, and the
  reason the two are separate parameters rather than one.

Testing had continued past it by mirroring the published revision into the
client's database by hand, which is what let everything above be found. That
mirror is now what the code writes on its own.

Exercised live, end to end. Revision 3 of `Citadel Test Line` was published
from the deployed Console against the real Meta sandbox WABA: the credential
check passed, the publish returned 200, and the record was written **into the
client's `citadel-exigence` database and nowhere else** — the registry received
nothing. A signed delivery to the public receiver then bound to
`channelRevision: 3`, which is the whole claim: the record the control plane
wrote is the record the receiver reads.

With that proven, the registry's two remaining copies (revisions 1 and 2) were
deleted, and the `manifold_channel_revisions` collection in Citadel's own
project is now empty. The delivery matrix was re-run afterwards and is
unchanged at 17/17, which is what confirms nothing was still reading them.

### The Manifold enablement gap

`manifold_enabled` is accepted by the Platform API and set by no Console
surface, and `ExigenceProjectScope` has no field for it. Manifold can only be
switched on by a hand-made provisioning request. Related: a published line
cannot be edited from the Channels page — the row is inert, and "Add line"
opens an empty form, so enabling an existing line means retyping its whole
configuration including three Secret Manager version names from memory. That is
how revision 2 was published today.

### What was proven live

Against the deployed receiver in `testproj-448205`, with a real Meta sandbox
WABA:

* The verification handshake, including **by Meta itself** — the webhook
  subscription was created through the Graph API, which only succeeds if Meta's
  own GET against the live receiver is answered correctly.
* 17/17 on the delivery matrix: correct signature accepted; unsigned, tampered,
  wrong-secret, all-zero and prefix-less signatures each refused; a replayed
  message id accepted and deduplicated to one stored message; `PUT` refused;
  the mount with no channel left to the rest of the server; and none of the
  runtime's own routes reachable on the public service.
* Every refusal answers identically — `403 forbidden`, with the reason only in
  the log. Confirmed by driving the "no such channel" and "wrong token" cases
  side by side and finding them indistinguishable from outside.
* Statuses, empty changes, unsupported message types, an unfetchable attachment
  and an opt-out all accepted, so none of them has Meta retry.
* The full inter-service round trip: a signed delivery to the public receiver,
  written into the client's Manifold database, read back through the Platform
  API and the client's runtime into the Console inbox, replied to from that
  inbox, and accepted by Meta — `delivery.state: sent`, `sentBy
  firebaseIdToken:...`, which is the very actor shape F-063 was rejecting.

### Manifold became an offering of its own

It was a platform-native surface: every project saw an Inbox and a Channels
page whether or not one had a receiver, and `manifold_enabled` was a variable
the Platform API accepted that no Console screen ever set. So the only way to
switch Manifold on was a hand-made provisioning request, which is how the one
client that has it got it.

It is now `Offering.manifold`, with `ManifoldProjectScope`, a setup plan, and
the same enablement, disablement and settings surfaces every other service has.
What that buys beyond a button:

* Its pages are gated on it, so a project with no receiver is not offered an
  inbox it cannot fill.
* `platform.manifold.*` permissions mask when it is off, like every other
  product's — matched on the two-segment prefix rather than renamed, because
  those names are in published Palisade roles and renaming a permission
  silently removes it from everyone holding it.
* A 403 while Manifold is off now reads as "not switched on" rather than
  sending the operator to Palisade to widen a role that would not help.

The plan states the dependency it has on Exigence on its first screen, as a
blocking check, rather than letting an apply half-succeed: Manifold's receiver
is the same runtime image in webhook mode and enqueues onto the Exigence
runtime's queue, so without one it would accept a customer's message and have
nowhere to put it.

The one field it asks for is how long a customer's attachments are kept, and
empty means indefinitely. Zero is refused rather than read as "forever" —
those are opposite instructions, and a field where one can be mistyped into the
other is the wrong place to be lenient.

`citadel-manifold` is still created by `exigence-runtime` rather than named in
`client-data-plane`'s database list like every other product's. That is
deliberate now rather than incidental: Manifold cannot be enabled without
Exigence, so its database is always created by the build that turns it on, and
one creator is better than two agreeing by convention.

### Manifold left the Exigence scope entirely (04/09/26)

`manifoldReceiverServiceAccount` moved to `ManifoldProjectScope` as
`receiverServiceAccount` — the `manifold` prefix was only ever there because
the field was living somewhere it did not belong. The provisioning runner now
writes it under `offeringScope.manifold`; every reader falls back to the old
path, because a client provisioned before the move has it there and nowhere
else, and this is the principal that publishing a channel checks against each
secret's IAM policy. Reading only the new name would report every one of their
channels as broken and offer a repair for a grant already in place.

Moving it surfaced two defects the offering change had left behind:

**The Console never learned the Manifold scope at all.** Its own Firestore
codec encoded and decoded `arm`, `conduit`, `exigence` and `baker`, so the
Console read Manifold as off on every project regardless of what was stored —
and a project settings save, which rewrites `offeringScope` wholesale, would
have deleted the scope outright.

**The registry rules refused it.** `isValidOfferingScope` ends in
`keys().hasOnly([...])`, and `manifold` was not in the list, so any project
write carrying it was denied. Firestore reports that as a permission denial and
the Console tells the operator their account may not create projects — which is
the third time this exact gap has silently broken every project write.

`platform_rules_contract_test` exists to catch precisely that, and did not,
because its list of offerings was a hardcoded copy that went stale the moment
Manifold was added. It now derives the list from `Offering.values`, and was
confirmed to fail against the old rules before the fix went in. A fourth
occurrence cannot happen the same way.

## The findings backlog, written up — 04/09/26

F-067 through F-079 were found between 03/09 and 04/09 and lived only in commit
messages and code comments until now. That is the gap this section closes, and
the reason it matters is three lines up the page: the Manifold rules gap reached
production **three times**, and each time the note explaining the previous one
was somewhere nobody looked.

**F-074 is not here because it does not exist.** No source file, test or commit
in any repository references it. Recorded as unused rather than left as a hole
somebody later assumes was lost.

### F-067 · P1 · The fourth copy of the actor rule, one indirection below the third
**Did:** Followed F-063 through to the conversation workspace.
**Saw:** F-063 fixed three copies of the actor pattern — `manifold_api`,
`billing_api`, `knowledge_base_api` — and its own comment warned that restating
the rule only moves the refusal one layer deeper. It did exactly that. Those
three let the actor through and the conversation workspace store, one call
further down, threw it out on the same `<credentialType>:<subject>` colon.

**Fixed:** the shared pattern is imported rather than restated, and
`conversation_workspace_actor.test.ts` fails if a principal is ever checked
against the identifier pattern again — so a fifth copy cannot be written.

### F-068 · P2 · The inbox answered once and then stopped asking
**Did:** Left a Manifold inbox open and had a customer write in.
**Saw:** `platformManifoldConversationsProvider` was a plain
`FutureProvider.family`, so the listing resolved once and was held for the life
of the tab. The operator went on seeing the inbox as it was when they opened it,
with nothing on screen saying the answer was old — while the thread panel below
refetched on open, so one screen showed two different times for one conversation.

**Fixed:** the listing can be asked again, and a test holds it to that.

### F-069 · P1 · A build that said nothing about the channel secrets revoked them
**Did:** Ran an ordinary provisioning job on a project whose Manifold channel
was already verified and working.
**Saw:** the secret grants disappeared. They were resolved only by the repair
that first granted them, so every subsequent plan omitted them — and Terraform
removing what a plan does not mention is Terraform working correctly.

**Fixed:** every provisioning plan resolves them, not only the repair.

### F-070 · P2 · The inbox named people by things that are not their names
**Did:** Read the Assigned column.
**Saw:** `VqvN416TBGS1huUVOz9UUa9p2P62`, and a thread log reading
`firebaseIdToken:VqvN416... assigned VqvN416...`. Both correct, neither usable:
an operator scanning for an unheld thread could not tell one colleague from
another, or either from themselves.

**Fixed:** people are named by email, as Palisade identities, grants,
`publishedBy`, `createdBy` and every audit event already are.

### F-071 · P1 · An agent could not be bound to a channel, so nothing answered
**Did:** Tried to make an agent answer a WhatsApp line.
**Saw:** no way to say which channel an agent answers. The receiver had to
assume the runtime a delivery arrived at was the one that served it, which for
an agent is exactly what is not true.

**Fixed:** an agent declares its channel in its own published configuration, so
the receiver can find which artifact a delivery belongs to.

### F-072 · P1 · A customer's message started a run that could never take a step
**Did:** Sent a real signed WhatsApp webhook at a real receiver.
**Saw:** the run started and died. A runtime serves exactly one artifact and
refuses every other; the receiver starts runs for whichever artifact answers a
channel, which is routinely not the artifact its own runtime hosts. The delivery
was refused identically on every retry until the queue gave up.

The first fix set the task's target URL and did not work, which took a while to
understand: **every Exigence queue carries a Cloud Tasks `uriOverride` with
enforce mode `ALWAYS`**, which rewrites the host of every task it dispatches and
mints the token for that host. A task addressed elsewhere and placed on this
queue is delivered here anyway. Setting the address on the task is not merely
insufficient — it is ignored.

**Fixed:** routing is the queue. Each agent gets its own, and the receiver reads
the route per dispatch rather than at boot, because an agent may be provisioned
or torn down long after the receiver started.

Then it still failed, and the second half is worth its own paragraph: the
receiver had `cloudtasks.enqueuer` but not `actAs` on the agent's invoker
service account. **Cloud Tasks reports that missing `actAs` as
`PERMISSION_DENIED` on `cloudtasks.tasks.create`, naming the queue and saying
nothing about the account** — so the enqueuer grant read as correct and complete
while every delivery was refused. Ruled out IAM propagation, deny policies and
stale revisions before checking the invoker's own policy. `exigence-runtime`
grants the pair together; the agent template had copied only the first.

### F-073 · P1 · A template that had never been applied, and could not have been
**Did:** Applied `exigence-agent` for the first time.
**Saw:** fifty-six `exigence-runtime` jobs and sixteen `client-data-plane` jobs
had run against zero for this template. Applying it took six plan/apply cycles
and surfaced a duplicate `output` block, F-072's missing grant and F-076.

**Fixed:** `template_validity_test` stages every template the way the image
stages it — reading the stagings out of the Dockerfile so the two cannot drift —
and runs `terraform init -backend=false` and `terraform validate`. Templates are
discovered, not listed. Three validate in about eleven seconds, and it was
confirmed to fail against the duplicate output that cost a full build, deploy
and plan cycle to find.

### F-075 · P2 · A runtime's address was discovered when it could be derived
**Did:** Traced why building for a new client needed a throwaway deployment.
**Saw:** Cloud Run issues every service two addresses — the opaque
`<service>-<hash>-<region>.a.run.app` and the deterministic
`<service>-<projectNumber>.<region>.run.app`. Only the first is unknowable
before a deploy, and building on it forced deploy-read-record-rebuild for every
client in a project Citadel had not built in before.

Continuing to record it did active harm: the derivation composed the second form
and the recorder wrote back the first, so every alternate build flipped the
runtime between its own two addresses and rolled a revision to do it. Both work,
which is what would have made it puzzling to find.

**Fixed:** the address is derived from the project number, readable at plan
time. A client whose suffix was recorded under the old scheme keeps it.

### F-076 · P1 · An agent could not ask what its own artifact may do
**Did:** Fixed F-072's routing and sent the message again.
**Saw:** the delivery reached the right runtime and the run still died — a 403
from the Platform API's principal authority. `exigenceRuntimeServiceAccounts`
was plural in name and returned a set, but only ever yielded the project's own
runtime, so an agent running as its own identity was refused the one question a
run must answer before its first step. **The delivery had been routed correctly
by then, which is what made this look like a routing bug** right up until the
queue grants were right and the run still would not start.

**Fixed:** an agent's identity is recorded in Citadel's own registry, one
document per artifact. Deliberately not the client's database — that holds the
agent's route, which the client's runtime writes, and a value the client's
runtime could write is not one the platform may trust to decide who may ask
about another principal's authority. A record naming anything that is not a
service account address grants nothing.

### F-077 · P2 · An agent that answers a channel could not answer unattended
**Did:** Watched two successful channel runs stop at `awaiting_approval`, held
on `channel.send`.
**Saw:** correct, and the whole point of the effect boundary — but it means a
customer-facing line cannot hold a conversation without an operator releasing
every message.

**Fixed:** `replyApproval` is a published choice. `held` keeps the existing
behaviour; `automatic` lets the agent answer by itself. The choice is stated
twice — declared on the graph and expressed in the policy — and the runtime
refuses a revision where the two disagree, because the policy alone would make
the difference between "answers by itself" and "waits for a person" a permission
missing from a list, which is indistinguishable from an oversight on the one
decision where an oversight puts unreviewed words on a stranger's phone. Holding
remains what a caller who says nothing gets.

### F-078 · P1 · An agent's runtime was a resource nobody could see
**Did:** Audited what a second artifact in one project exposed.
**Saw:** the inventory reported exactly one Exigence runtime per project, from
`offeringScope.exigence.runtimeUrl`. Every agent is a second always-on Cloud Run
service the client pays for and the operator's own inventory does not show. The
live check matched deployed services against that one recorded address, so an
agent whose service was deleted drifted with nothing to notice — **F-001 asked
for that drift as a first-class finding, and it was reintroduced one artifact at
a time.**

**Fixed:** the runner records each agent's address beside its identity; the
inventory emits a node per agent, sorted so it does not reorder between reads;
the observer matches each agent's service the same way it matches the project's
own.

Worth recording: the first version of the drift check was nested inside
`if (recordedRuntimeUrl != null)`, so an agent would not have been observed
unless the client had a runtime of its own — **the same "per project" assumption,
one level down, written by the change meant to remove it.** The listing is now
gated on the project's own address *or* any agent's, with a test for exactly
that case, confirmed to fail against the nested version.

A second defect found while evaluating the cost of all this: both new readers
used one `list` with `pageSize: 100` and no page token, so a project's hundred
and first agent would have been absent from the inventory and refused authority
— F-076 again with a page boundary for a cause. Both now share one helper that
follows the pages.

### F-079 · P1 · A settings save could silently drop an offering
**Did:** Hunted the remaining hardcoded enumerations after Manifold.
**Saw:** `ProjectOfferingScope` is freezed with a default on every field, so a
construction that omits one **compiles** and silently resets that offering. The
settings screen rewrites `offeringScope` wholesale, so an omission there does not
read as "unchanged" — it deletes what the operator had. That is exactly how
Manifold was dropped: the Console's codec knew only `arm`, `conduit`, `exigence`
and `baker`, so it read Manifold as off on every project regardless of what was
stored.

The compiler cannot catch an absence and a reviewer has to notice one.

**Fixed:** the settings encoder is checked against `Offering.values`, so a sixth
offering fails a test rather than a customer's project. Confirmed to fail with
`manifold` removed. The three other constructions that omit offerings are seed
data, where showing an offering as off is honest — checked, left alone.

## Overnight, 04–05/09/26 — deploying what was written, and what that exposed

### F-080 · P1 · A run stranded mid-step can never be cancelled, and said so as a 502
**Did:** Redeployed the agent's runtime while two channel runs were held at
`awaiting_approval`.
**Saw:** both runs moved to `running` with `step-1.act` in flight and stayed
there. Cancelling them answered **502**.

The refusal underneath is right: `CancellationPendingInFlightError` — a run
cannot be compensated while a step is in flight, because the tool may already
have put a message on somebody's phone and undoing the run without knowing that
would be worse than leaving it. What was wrong is that it reached the console as
a gateway error, which reads as "the platform is broken" rather than "this run
is waiting on evidence".

**Fixed:** a 409 carrying that sentence.

**Not fixed, and it needs a decision.** A step that was in flight when its
instance was recycled waits for evidence that can never arrive. The run cannot
proceed and cannot be cancelled. There is no operator path out of it today, and
the honest options are a supervisor that ages out in-flight activities after a
bounded wait, or an explicit operator override that records that the evidence
was never going to come. The second is safer and duller; the first is what
stops a person having to notice. Recorded rather than chosen.

### Two smaller things the same session found

**Cancelling a run does not purge its queued deliveries.** Sixteen compensated
runs left Cloud Tasks entries retrying against a runtime that refuses them —
twelve dispatches, zero responses, backing off toward an hour. Harmless, but it
is work the platform keeps doing on behalf of runs it has already given up on.
Two were deleted by hand. Worth a purge on compensation.

**A client's own runtime is not redeployed by an agent's apply.** The reply
setting did not render in the console because the artifact listing is served by
the *client's* runtime, and only the agent's had the new image. Obvious in
hindsight and invisible from the console: the page simply omitted the control.
Anything added to the listing needs both templates applied.

### F-082 · P2 · A re-applied client runtime fails on a database it already has
**Did:** Re-applied `exigence-runtime` on `user-test-1`, a client who already
had Manifold, to roll a new runtime image.
**Saw:** `Error creating Database: googleapi: Error 409: Database already
exists` — after the apply had already updated both Cloud Run services. The
build reports failure while having done most of its work, which is the worst
shape a provisioning run can take.

The cause is a consequence of a deliberate choice. `citadel-manifold` holds a
client's customers' messages, so it is created with
`deletion_policy = "ABANDON"`: a plan that would destroy it leaves it in place
and drops it from state. State and reality then disagree permanently, and every
later plan proposes creating a database that is already there.

**Attempted and did not work:** adopting it back with `terraform import` before
planning. The import is the right idea and fails for an unrelated reason —
`terraform import` evaluates the whole configuration, and this template has a
`for_each` that cannot be resolved without a plan, so the import dies on
`Invalid for_each argument`. On a client who genuinely has no database that
same failure is indistinguishable from "nothing to adopt", which is how the
first attempt reported success at doing nothing.

The runner now prints Terraform's own words when the adopt fails, so the next
person sees `Invalid for_each argument` rather than a reassuring sentence.

**CLOSED 05/09/26, and it was never the product decision this said it was.**

The blocking `for_each` iterated a *resource* rather than the variable driving
it — `for_each = google_secret_manager_secret.provider` in the runtime module.
Its keys are only knowable once that resource is in state, and `import`
evaluates the whole configuration before planning anything, so importing *any*
resource in the module was impossible. Keyed on `var.secret_ids` instead: same
set, same instances, known at import time.

Verified end to end on `user-test-1`: the runner logged *"Adopted the existing
citadel-manifold database into state"*, the database left the plan's creates,
and the apply that had failed twice with `409 Database already exists` finished
`1 added, 3 changed, 0 destroyed`.

None of the three options below was needed. They are kept because the reasoning
still applies if the abandonment ever has to be handled some other way.

**The three that were considered and are no longer required:**
* making the offending `for_each` resolvable without a plan, which would let the
  import work as intended and is the smallest real fix;
* `lifecycle { prevent_destroy = true }` on the database so it is never
  abandoned in the first place — state and reality cannot drift if the destroy
  is refused, though it turns a teardown into a manual step;
* an `import` block in the template guarded by a variable the API sets when it
  knows the client already has Manifold.

The first is the one to try. Recorded rather than chosen, because all three
change what a teardown does and that is not a decision to make at 2am.

**Not blocking:** every service is deployed and healthy on the intended images.
This costs a red provisioning job on re-apply, not an outage.

### F-084 · P1 · The agent could decide to reply and not be allowed to
**Did:** Set the agent to answer unattended and sent a real WhatsApp message.
**Saw:** the run recorded a decision to reply, six `channel.send` attempts, and
no message. Secret Manager refused every one:
`Permission 'secretmanager.versions.access' denied`.

`exigence-agent` passes `manifold = null` to the runtime module, with a comment
explaining that an agent does not receive customer messages on its own line.
That is true about *receiving* and wrong about everything else the block
carries — null also removed the channel secret grants an agent needs to
**send**. The client's own runtime has them, for exactly the reason the module
states beside them: "the private runtime sends replies, so it reads the same
channel secrets."

What made it hard to see is the order. The approval gate said yes, the policy
said yes, the tool was called — and the refusal came from Secret Manager after
everything that reports on authority had already reported success.

**Fixed:** one grant per published secret, resolved by the Platform API from
the channels the project has actually published. Never project-wide and never a
caller's to name; either would let one client's agent read another client's
tokens. Two shape tests hold it.

### F-085 · P2 · An agent that reaches its ceiling strands its run
**Saw:** `JournalValidationError: run has no step step-7.decide`, three times,
on an agent published with a six-step ceiling. All six `act` steps sat at
`running` and the run never moved again.

Refusing the seventh step is right — the ceiling is stated three times and
checked twice precisely so a graph cannot walk past it. What is wrong is what
happens next: the refusal throws, the six in-flight activities are never
resolved, and the run is left in the state F-080 describes, which cannot be
cancelled either.

**FIXED 05/09/26.** Reaching the ceiling now ends the run the way any other
terminal condition does, with a sentence an operator can read: *"This agent
reached the 6 decisions it was published with and stopped."* The driver treats
it as termination rather than a fault, so the delivery succeeds and Cloud Tasks
does not retry a run that is already finished. Confirmed by a test that pins
both halves — the refusal *and* the run being closed with its reason.

**What it looked like first, which was smaller than it was.** The looping was a
*symptom*:
`channel.send` was failing, the agent retried, each retry spent a step, and the
ceiling was reached. With the send working the same agent answers once and the
run succeeds at sequence 28 — it does not walk to its ceiling at all.

What remains is real but narrow: when a tool fails repeatedly and the ceiling
*is* reached, the refusal throws and the run is left open with its activities
in flight, which is the state F-080 describes and cannot be cancelled either.
Reaching the ceiling should end the run the way any other terminal condition
does. Worth fixing with F-080's other half, and not urgent on its own.

### And one thing that was not a defect at all

Twelve `channel.send` spans failed before any of this was understood, and the
cause was the platform working correctly: the test recipient was recorded
`opted_out` from a "STOP" sent during earlier testing on 03/09. Every reply was
refused because the person had asked not to be messaged. Sending "start" from
the same number recorded `opted_in` and the next question was answered.

Worth writing down because it cost an hour of looking for a bug in the send
path. A refusal that is correct and a failure that is not look identical from
a span with `status: error` and nothing else on it — the consent refusal
carries its reason and the span does not keep it.


### F-086 · P1 · A client could not have a second agent
**Did:** Tried to publish a second agent for `user-test-1`, which is the case
the whole multi-artifact effort of 04–05/09 exists for and the one thing it had
never been tested with.
**Saw:** the agent's artifact id was a constant. `createSuperharnessArtifactBundle`
always produced `exigence.superharness`, so a second publish overwrote the
first agent's history rather than standing beside it.

**Fixed:** `--artifact-id` names it, defaulting to the old constant so a client
with one agent keeps the coordinates and the published history it has. Each
agent gets its own policy resource — pricing and adapters stay shared, because
a price profile belongs to the deployment, but a policy says what *this* agent
may do and two agents sharing one would mean changing one changed the other.

### F-087 · P1 · Publishing a second agent conflicts on the shared versions — FIXED
**Did:** Published the second agent for real, with F-086 fixed.
**Saw:** `immutable configuration version conflicts`.

The provider, pricing and adapter versions are shared by every agent in a
project, at fixed coordinates — `(kind, projectId, resourceId, version)`. Their
*content* includes `publishedAt`, which is the wall clock at publish. So the
second agent computes byte-identical configuration with a different timestamp,
the digest differs, and the repository refuses it: the coordinates already hold
different content.

That refusal is correct and the invariant behind it is right — coordinates
identify content, which is what lets a revision pin a digest and a runtime
verify it. What is wrong is that `publishedAt` varies for a resource whose
identity is supposed to be its coordinates.

**Two ways out, and the second is the real one:**

* **Deterministic `publishedAt` for shared versions.** Makes two publishes
  produce identical content. Simple, but it only helps going forward: an
  existing client's stored versions keep their old digests, so a new agent
  would compute a different digest and conflict exactly as before.
* **Build the bundle against what is already published.** Read the existing
  shared versions at those coordinates and have the new revision pin *their*
  digests rather than newly-computed ones. This is correct for existing clients
  and new ones, and it is what "shared" should have meant all along. It changes
  `publishArtifactBundle` and the bundle builders, so it is a real piece of work
  rather than a patch.

**Fixed by the second, on 05/09.** The store adopts an existing version whose
*value* matches and hands it back as the version of record; `publishArtifactBundle`
re-pins the revision to the digests that came back. Two agents that genuinely
disagree about a shared resource still fail, now with `SharedResourceConflictError`,
which `isAlreadyPublished` excludes — it reports `conflict` like a lost race and
means the opposite.

**Proven live**, not in a test. `user-test-1`'s second agent published with all
four shared versions reported as adopted, and both superharness revisions now
pin the same provider, pricing and adapter. The same publish had failed with
`immutable configuration version conflicts` an hour earlier.

Rollback needed fixing alongside it: it refused only when *this artifact* had a
published revision, so with sharing reachable it would have deleted the first
agent's provider out from under it. It now refuses when any revision in the
project pins the coordinates.

---

## 05/09/26 — adding an agent, and what live driving found

F-087 unblocked the thing the whole of 04/09 was for. What followed was the
work to make it usable, and four defects that only appeared by doing it.

### F-088 · P1 · Adding an agent was command-line only — FIXED
**Did:** Went to add a client's second agent from the console.
**Saw:** No surface for it. An agent was published by `tool/publish_superharness_configuration.ts`, run with the client's Palisade coordinates typed out by hand.

`POST /v1/projects/{id}/exigence/agents` publishes revision 1 of a new
superharness artifact, gated on `exigence.agents.publish` — the permission that
already existed for this, held apart from `automations.update` because somebody
who may flip an existing agent's switch is not thereby somebody who may stand up
another one that talks to a client's customers.

The caller states what the agent is *for*: instructions, ceiling, whether replies
wait for a person, which channel it answers. It does not state what the agent may
*do* — identity and the three boundary revisions come from the deployment's
environment, which is Terraform's, which is the plan an operator approved. The
same rule the platform API already applied to provisioning, applied to the other
way an artifact comes into being. Unknown body keys are refused rather than
dropped: a dropped key reports an agent created with a setting it does not have.

`/exigence/agents/new` is a page, not a dialog — an agent is defined by a
paragraph somebody writes and rereads. It ends by saying the agent has no runtime
yet and answers nothing until one is built, because an agent that exists with
nowhere to run looks finished from that page.

### F-089 · P2 · Two agents both called "Superharness" — FIXED
**Did:** Opened Artifacts with two agents published.
**Saw:** Two rows reading "Superharness", told apart only by the artifact id underneath.

`displayName` was a constant. It is now the name the operator typed — the same
name the artifact id is slugged from. A blank name is absent rather than empty:
an agent with no label at all reads worse in a list than the default it replaces.

### F-090 · P1 · Every client build downloaded its providers from the public registry — FIXED
**Did:** Ran the Exigence build for `user-test-1` from the console.
**Saw:** "Inconsistent dependency lock file", naming providers with no version selected.

That message was a consequence, not the cause. The logs said
`429 Too Many Requests returned from registry.terraform.io`: `terraform init`
runs in a fresh container with no plugin cache, so every client build downloaded
every provider again, and the registry rate-limits that. The empty lock file is
what a failed download leaves behind.

**Two things were wrong.**

*The providers were fetched at run time.* They are downloaded once at image build
now, mirrored into the image, and served from a `filesystem_mirror` with no
`direct` block — so an init wanting a provider the image does not carry fails
saying so rather than reaching the network. A plan an operator approves is built
from providers that were reviewed, and a build does not depend on a public
registry being up. Every template gained a committed lock file.

*The init result was discarded.* The runner ran `init` and never checked it, so
the failure surfaced as the plan's complaint about the lock file — sending the
operator to look at a lock file when the registry had refused them. Init is
checked now and reports its own stderr, which is where Terraform says what
happened.

A test asserts every template locks every provider it and its staged modules
require. Confirmed to fail with `hashicorp/time` removed from a lock file, which
is exactly the mistake that leaves the mirror incomplete.

### F-091 · P1 · An agent's runtime coordinates came from the caller — FIXED
**Did:** Went to give the new agent a runtime from the console.
**Saw:** `exigence-agent` requires `client_name_prefix`, `client_database_id` and `client_payload_bucket` — and the console has never seen the template that derived them.

Two problems in one. A caller who could name them could point an agent at
another client's database and bucket; and nothing but a person typing them knew
what they were, so the console could not build an agent at all.

The build that creates those resources now outputs them, the runner records them
on the project beside the runtime's address and identity, and the Platform API
resolves them for the agent template the way it already resolves the host project
and the client's receiver. A request that states one is refused as not the
caller's rather than overridden. A client whose runtime recorded none of it is
refused with what to do: build the service again.

Re-deriving the name in the Platform API was the tempting shortcut and the wrong
one — the naming rule lives in the template that applied it, and two derivations
of one name is how an agent silently detaches from the client it belongs to.

### F-093 · P1 · An agent could not have a two-word name — FIXED
**Did:** Filled the New agent form in with "Bookings Desk" and pressed the button.
**Saw:** `400 invalidArgument: The request body does not match the required contract.`

The console slugs the typed name into the artifact id, so it produced
`exigence.superharness.bookings-desk`. `agent_slug` has allowed hyphens since it
existed; `agent_id` never did — not in the runtime, not in the proxy contract,
not in the Terraform variable. The console's own form could not create an agent
with a two-word name.

Allowed rather than avoided: a dot would read as a deeper namespace than it is,
and no separator gives an id nobody can read. Every identifier validator
downstream already permits hyphens.

**Every unit test on this path used a single-word name.** This is the fourth
defect on this page found by using it rather than by reading it.


### F-094 · P2 · An agent whose runtime was not built has no way back — FIXED
**Did:** Created `bookings-desk` from the console before F-091's coordinates
were recorded, so its runtime step refused (correctly).
**Saw:** No way to return to it. The runtime step lives only on the page that
*creates* an agent, and the id is taken, so the page cannot be reached again.

The agent is published and has no runtime, and nothing in the console offers to
build one. The Artifacts page should offer it for any agent with no recorded
runtime — F-078 already records runtimes per artifact, so the console can tell
which agents lack one.

Not a blocker for a fresh agent: `returns-desk` was created after the
coordinates were recorded and its runtime built from the same page in one pass.
It is a blocker for any agent whose first build fails for any reason, which
over time is most of them.

**Found by hitting it**, which is now the fifth time today that using a page
found something reading it did not.

**Fixed:** `/exigence/agents/:agentId/runtime` is the same build on its own
page, reached from a link on every agent row. Offered for every agent rather
than only those without a runtime, because the Artifacts page does not know
which have one — and a build for an agent that already has one plans nothing,
which is a safe answer and an informative one. The page says so before the plan
runs, so "nothing to do" does not read as a failure.

Verified by driving it: `bookings-desk`, stranded since it was created before
F-091's coordinates were recorded, was given its runtime from the Artifacts
page.


### F-095 · P0 · A client's agents shared one Terraform state — FIXED
**Did:** Created `returns-desk` from the console for a client that already had
an agent, and let its runtime step plan.
**Saw:** `Plan: 23 to add, 0 to change, 23 to destroy.`

The 23 to destroy were the Cloud Run service, queue, service accounts and
channel secret grants of `cit-user-tes-f111-*` — the agent answering that
client's live WhatsApp line. Building a client's second agent proposed tearing
down their first.

The runner computed one state prefix per template per project:

```dart
// Every supported template has one deployment for each project.
final String prefix = 'provisioner/$template/$projectId';
```

The comment says the assumption out loud, and it was true of every template
until a client could have more than one agent. `exigence-agent` deploys *an
agent*, not a project's Exigence. Two agents planned against one state is
Terraform being told "this is what the project should contain", and it does the
only thing it can with that.

**Fixed:** an agent's state prefix carries its slug —
`provisioner/exigence-agent/<project>/<slug>` — the same slug that already
distinguishes its Cloud Run service, queue and service accounts from every
other agent's. A build with no slug is refused rather than defaulted: falling
back to the shared prefix is exactly this failure, done silently.

**Migration:** the one existing client-with-an-agent had its state copied from
the shared prefix to `…/user-test-1/wa2/` (slug confirmed against the resource
names: `md5("user-test-1/wa2")[0:4]` is `f111`). The legacy object is left in
place rather than deleted; it can go once a build has run against the new
prefix.

**The plan was never applied.** It was found by reading the plan the console
had produced and was about to offer for approval, and the job was marked
superseded so it could not be applied later by mistake.

**Verified live.** With the fix deployed, a third agent for the same client
planned `32 to add, 0 to change, 0 to destroy` — every action a create, against
its own state at `…/user-test-1/refunds-desk/`. The two numbers side by side
are the whole of it:

```
before   Plan: 23 to add, 0 to change, 23 to destroy
after    Plan: 32 to add, 0 to change,  0 to destroy
```

That plan was applied, and the result is the thing this was all for: two agent
runtimes standing beside each other, each serving its own artifact on its own
queue, with the first one untouched.

```
cit-user-tes-f111-runtime   exigence.superharness               (unchanged)
cit-user-tes-5bc3-runtime   exigence.superharness.refunds-desk  (new, revision 1, Ready)
```

`5bc3` is `md5("user-test-1/refunds-desk")[0:4]` — predicted before the apply
and matched after it. Both are registered in `exigence_artifact_runtimes`, so
routing can find either.

**The first agent runtime built from the console**, on a client that already
had one.

**Note on the cost disclosure, which was right.** The console would have shown
"Apply 23 changes" with each marked as a replace — the summary parser handles
replaces and counts them in both columns for exactly this reason. Nothing was
hidden from the operator. What was wrong was the plan, not the reporting of it.


### F-096 · P1 · An agent could not be started from the console — FIXED
**Did:** Pressed "Run manually" on a newly created agent.
**Saw:** `404`, and a console message that said only "Run could not be started."

The platform resolves one Exigence runtime per project and sends every call
there, so a run started for an *agent's* artifact reached the client's runtime
— which serves one artifact and refuses the rest, exactly as designed. No agent
had ever been startable from the console. The runs the agents had were all
channel deliveries, which follow the artifact because the queue does.

Starting a run is the operation that must reach the artifact's own runtime: the
runtime creates the run and enqueues its first step on its own queue, so a run
created anywhere else is served by the wrong service or by nothing. Reading a
revision or listing runs reads the shared registry and any of the project's
runtimes can answer, so those are left alone.

`resolveForArtifact` reads the per-artifact runtimes the provisioning runner
already records, and falls back to the project's runtime twice over — when a
deployment has no artifact reader, and when an artifact has no runtime of its
own. The second is not a gap: it is the ordinary state of every artifact the
project's own runtime serves.

**This is F-072's lesson in the control plane.** Deliveries follow the
artifact; so must the calls that start them.

### F-097 · P0 · Every step of every run conflicted with itself — FIXED
**Did:** Started the first agent run after F-096.
**Saw:** `activity identity cannot change`, retried until the ceiling. Nothing
on the run but a step stuck at `pending`.

An activity's identity is everything about it but its status, and the journal
refuses a transition that changes any of it. F-080's `abandonedAfter` was
written where the attempt started and nowhere else — so adding it at
`activity.started` changed the identity of an activity created without it, and
`activity.succeeded` then dropped it and changed the identity again. Two
conflicts per attempt, either fatal.

The bound is part of the activity from creation now, and later transitions
carry what the journal holds rather than recomputing it: a later clock gives a
later instant, which is a different identity again.

**Three things let this reach production.**

1. **No test anywhere set `stepDeadlineMillis`.** The field exists only where
   Terraform states one, so 977 tests ran on the single configuration where the
   bug is invisible.
2. **The in-memory journal did not enforce the identity rule the real one
   does** — which a comment in `graph_projection_recorder.ts` already warned
   about, in those words. The fake enforces it now, and immediately found the
   second conflict that had not yet been noticed.
3. **The error did not say what changed.** "activity identity cannot change" is
   true and useless; finding the field took a deployment and a lot of guessing.
   It now names the field and what it became.

It affected every deployment carrying the F-080 image, the live WhatsApp agent
among them. All of `user-test-1`'s runtimes were rolled to the fixed image.

**The first fix was not enough, and the error message added alongside it is
what showed why:** `abandonedAfter absent became "…"`. Carrying the bound
addressed activities the recorder created; it did nothing for the ones the
run's *start service* writes, which know nothing about step deadlines. The
recorder met a pending activity with no bound, computed one, and tried to add
it.

**The fix that worked is narrower to state and wider in effect.** Every
transition is now the recorded activity with a new status and nothing else. A
transition can no longer differ from the record in any field — computed from a
clock, defaulted, or added later by code that has never met the record. It also
settles replay: this process did not write the record and cannot reproduce the
instant that did, so it must not try.

**Verified live.** With the fix deployed, a run created from the console went
`4 → 27 → succeeded at 41` within a minute:

```
06:43:48  new=running/4
06:44:10  new=running/27
06:44:21  new=succeeded/41
```

Three decisions, two actions, then the agent stopped on its own — the remaining
steps skipped, well inside its eight-step ceiling, with per-step cost metered
(USD 0.000411, 0.000467, 0.00054775). **The run stranded for over an hour
recovered too**, once its queued task next dispatched: an activity written
without a bound is now left exactly as it was written, so the runs I expected
to be unrecoverable were not.

That last part is worth keeping. The prediction that they could not recover was
wrong because it was made about the *first* fix, which added a bound to those
activities. The second fix does not, so they resumed where they had stopped.
