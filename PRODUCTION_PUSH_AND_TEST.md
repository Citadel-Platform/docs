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
  instance" (F-027). `learning-gcp-404803` is capacity/quota-constrained for
  Cloud Run right now — the same thing stalling provisioner Jobs 5–12 min
  (F-019). A run was created after 9 retries and failed at step 1. **This is
  GCP infra in that project/region, not Citadel** — but it blocks the run /
  approval / agent-loop / KB-sync tests. `obsidian.infinitum` can't raise the
  quota or set min-instances (viewer only on that project).

### What's NOT done / needs the operator
- **Cloud Run capacity on `learning-gcp-404803`** — the blocker for Exigence
  runs. Needs the project owner (`siddharth.chitikela@gmail.com`) to check the
  Cloud Run CPU quota / request an increase, or set the runtime min-instances
  to 1. Until then, run / approval / schedule / KB-sync / agent-loop testing
  can't proceed on test-sandbox.
- **Firebase on `learning-gcp-404803`** — same owner. Blocks ARM/Conduit
  **data-plane** testing (F-024).
- **Sample Superharness agent runtime** — the `exigence-agent` template, the
  publish tool, the `artifact.superharness` identity and its published config
  are all in place; the agent's own `exigence-runtime`-style deployment was not
  applied this session (another ~30-min provisioning cycle under F-019).
- **F-016 / F-022 / F-023 / F-021 / F-018 / F-017 / F-026** — documented, not
  fixed (Console + server changes, or procurement).

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
real 5xx and returns a `describeFailure` body. Also: `test-sandbox`'s ARM/Conduit
data plane can't be fully tested until Firebase is added to `learning-gcp-404803`
(needs `siddharth.chitikela@gmail.com`, the project owner).

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

### F-027 · NOTE · Client runtime cold-start returns 500/502 (Cloud Run capacity, learning-gcp today)
**Did:** Called `/exigence/{automations,runs}` on the freshly-provisioned
`test-sandbox` runtime.
**Saw:** intermittent 500 "The request was aborted because there was no
available instance" (Cloud Run) → forwarded by the Platform API as 502
"invalid response". `GET` succeeded on retry 1; `POST /runs` needed several.
`min_instance_count = 0` + Cloud Run capacity pressure in `learning-gcp-404803`
on 01/09. Not code — but the Platform API marking these `retryable: true` (it
does) and the Console retrying once would smooth it.

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

