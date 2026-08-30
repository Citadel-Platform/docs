# Citadel SITREP

**26/08/26.** Written from the live cloud and the code, not from the tracking
documents. Everything stated here was checked; where something was not
checked, it says so.

---

## 0. The shape of the thing, in one page

Citadel is a platform with **five service lines plus Palisade** per client project, one
**Console** (Flutter web) that operates them, one **Platform API** that every
surface goes through, and a **permission system** (Palisade) that decides who
may do what.

The most important structural fact: **Citadel holds the control plane, the
client's own Google Cloud project holds the data.** Definitions, permissions,
project records and billing live in Citadel's Firestore. Runs, evidence,
documents and results live in the client's project, in a Firestore database of
their own. A client's runtime is granted access to exactly one database, so it
cannot reach another client's data at all.

The second structural fact about the current deployment: **only Exigence has a
working per-client infrastructure build.** ARM and Conduit currently attach to
the client's existing Firebase project. The target adds Baker Devstation
infrastructure and Manifold connectors/data paths, both provisioned and
reconciled from the Console.

| Product | What it is | Has its own infra? |
|---|---|---|
| **ARM** | Error and incident records from a client's app | No — reads client's Firebase |
| **Conduit** | Web analytics, session replay, alerting | No — reads client's Firebase |
| **Exigence** | Automations and AI agents that do work | **Yes** — runtime, queue, database, bucket |
| **Palisade** | Identity and permissions for all of the above | No — it *is* Citadel's registry |
| **Baker** | Named in the Console; directory is empty | Not built |
| **Manifold** | Omnichannel inbox and repair bridge | WhatsApp built, unproven against Meta |

---

## 1. What works, and where you do it

Legend: **Console** = clickable in the web UI · **CLI** = `citadel …` terminal
command · **Manual** = someone edits Terraform, runs a script, or edits
Firestore by hand. Every Manual entry below is a current product gap: the
settled end state brings it into a guided, validated Console flow.

### 1.1 Palisade — identity and permissions

The permission catalogue has **52 permissions** (37 Exigence, 6 platform, 5
ARM, 4 Conduit) and **3 roles**: `roles/citadel.superdev`,
`roles/citadel.viewer`, `roles/citadel.invoker`.

| Capability | Where |
|---|---|
| See a project's grants, and what each *actually* resolves to | Console |
| Grant / change / remove someone's access to a project | Console |
| See your own effective authority | Console |
| Claim a project you just created | Console (automatic) |
| Add a new permission or role to the catalogue | **Manual** — edit `catalogue.json`, redeploy |

A useful detail: the grants screen shows the grant *and* what it resolves to,
because they differ whenever a role is unknown, an identity is disabled, or the
offering is switched off. A screen showing only the grant would misreport all
three.

Permissions never reach the browser. Resolution happens inside the Platform API
under its own service account, so the collection holding authority is not
readable by a signed-in user at all.

### 1.2 ARM — incident records

| Capability | Where |
|---|---|
| List issues, list cases, open a case | Console |
| Change an issue's or case's status | Console |
| Turn ARM on for a project, name the monitored environment | Console |
| Connect the client's Firebase project | Console (project settings) |
| **Let Citadel read the client's project** | **Manual** — Terraform in the client boundary root |
| Embed capture in the client's app | **Manual** — client installs the ARM SDK |

ARM's own backend is one service, `citadel-arm-evidence`, already deployed.
Nothing is built per client.

### 1.3 Conduit — analytics and replay

| Capability | Where |
|---|---|
| Search sessions, replay a session, annotate one | Console |
| Heatmaps, journeys, funnels, voice-of-customer analytics | Console |
| Turn Conduit on, name the dataset | Console |
| Site sending events | **Manual** — client installs the tag |

Not verified this session: whether the Conduit ingest service is deployed
anywhere. There is no Conduit Cloud Run service in either project, so ingestion
presumably runs in the client's project or is not yet live. **Treat Conduit as
unverified.**

### 1.4 Exigence — automations and agents

> **Superseded capability notice, 27/08/26.** The customer-written agent
> container path described below was a regression against the 14/08/26
> operator-only authorship decision. Its source, APIs, CLI, Terraform template,
> per-artifact routing and SDK are retired. The historical demo-sandbox
> resources remain pending an explicit Terraform/data decommission and are not
> a supported product surface. The generic Artifact registry and governed
> run/approval operations remain.

This is the large one. Grouped by what you are trying to do.

**Running work**

| Capability | Where |
|---|---|
| List automations/agents, see runs, see a run's steps and evidence | Console |
| Trigger a run by hand | Console · CLI |
| Cancel a running run | Console · CLI |
| Approve or reject a held action | Console · CLI |
| Read a run's audit trail | Console |
| Turn an automation on/off | Console · CLI |
| Set a schedule (cron) | Console |
| Configure a webhook trigger | Console |

**Agents (customer-written containers)**

| Capability | Where |
|---|---|
| See which tools an agent may call | Console · CLI (`agents tools`) |
| See an agent's published configuration | Console · CLI (`agents show`) |
| Publish a new configuration generation | Console · CLI (`agents publish`) |
| **Scaffold a new agent project** | **Manual** — copy `agent_sdk/example` |
| **Build and push the agent's image** | **Manual** — `agent_sdk/cloudbuild.agent.yaml` |
| **Provision the agent's runtime** | **Manual** — provisioner, `exigence-agent` template |

The Console shows agents in the existing list but **does not yet show** an
agent's step ceiling, its image digest, or which container decides — even
though the API already returns all three.

**Knowledge Base**

| Capability | Where |
|---|---|
| Add a source, list sources, remove one, sync one | Console |
| List / edit / remove entries | Console |
| Ask the corpus a question (chat) | Console |
| Change retrieval settings | Console |

Formats accepted: plain text, Markdown, CSV, TSV, JSON, XML, YAML, HTML.
**PDF, Word, Excel and PowerPoint are explicitly refused** with "not supported
yet" — deliberately a distinct message from "unsupported type", so it does not
read as a mistake by whoever uploaded it.

Sources come from a **synced folder read by the local runner** (Google Drive
for Desktop presents Drive as an ordinary folder, which is how Drive is ingested
without Drive OAuth) or an HTTPS URL. Browser OAuth to Drive and Microsoft Graph
is deliberately not built yet.

**Money**

| Capability | Where |
|---|---|
| Per-run and per-component cost | Console |
| Set a spending cap per run | Console · CLI |
| Invoices: list, open, create, issue, void | Console |
| Credit notes | Console |
| Payment reconciliation | Console |

Stripe is a payment processor only; invoices are Citadel's own records.

**The client's own machine (localbridge)**

A small program the client runs on their computer. Today's implementation sends
instructions and returns bounded evidence. The target Palisade Data Handling
Boundary decides per resource whether it is inaccessible, processed in situ,
relayed only to Citadel, or relayed to an allowlisted third party. There is no
machine-wide bypass. All routes remain authenticated, project-scoped, audited,
visible, and revocable.

- **Outbound only.** It asks Citadel for work; Citadel never dials in. No
  inbound port, no VPN.
- **The boundary lives on the client's machine**, in a file they control.
  Citadel can ask for less than it allows, never more.

| Instruction | Supported |
|---|---|
| Read a file, list files, write a file, append to a file | ✅ |
| Read a web page, click in a browser | ✅ |
| Append rows to an Excel workbook (`.xlsx`) | ✅ |
| **Read** a spreadsheet structurally | ❌ not built |
| PowerPoint, anything | ❌ not built |

Issuing a client a runner credential is **Manual** — a script,
`tool/issue_runner_credential.dart`. The secret is shown once and stored only as
a hash.

### 1.5 The gap that matters most

Provisioning and publishing routes require a **Firebase token**, which only a
browser can produce. A user account cannot mint one from a terminal. So those
routes **cannot be driven from a terminal at all** — today they need either a
browser, or an operator impersonating the provisioner service account. This is
the single biggest ergonomics gap in the platform.

---

## 2. What is actually deployed right now

Two Google Cloud projects are in play.

### 2.1 `citadel-platform` — Citadel's own control plane

**Services (Cloud Run)**

| Service | Job |
|---|---|
| `citadel-platform-api` | The single front door. Everything goes through it. Public, but every route is authenticated and permission-checked. |
| `citadel-exigence-runtime` | The original shared Exigence runtime. |
| `citadel-arm-evidence` | ARM's evidence intake. |

**Job (Cloud Run Jobs)**

| Job | Purpose |
|---|---|
| `citadel-provisioner` | Runs Terraform to build client infrastructure. |

**Storage**

| Bucket | Holds |
|---|---|
| `citadel-platform-terraform-state` | All Terraform state and saved plans |
| `citadel-platform-exigence-demo-payloads` | Large run payloads (demo) |
| `citadel-platform_cloudbuild` | Build sources |

**Database:** one Firestore `(default)` in `us-central1` — the registry.
Holds project records (`platform_projects`), identities and grants
(`palisade_identities`, `palisade_grants`), automation definitions, and
provisioning jobs.

**Queue & schedule:** `citadel-exigence-runtime` task queue;
`citadel-exigence-schedule-dispatcher` running **every minute** (enabled).

**Service accounts (9):** api, exigence-runtime, exigence-invoker, arm-evidence,
provisioner, two builders, Firebase admin, default compute.

### 2.2 `learning-gcp-404803` — currently standing in as the client project

⚠️ **This is a leftover.** `host_project_id` still points here instead of
`citadel-platform`. Flipping it back and tearing this down is the stated
endgame and has not begun.

Two client projects live here, `demo-sandbox` and `exigence-lab`:

| Resource | `demo-sandbox` | `exigence-lab` |
|---|---|---|
| Firestore database | `demo-sandbox` (nam5) | `exigence-lab` (nam5) |
| Payload bucket | `cit-demo-sandbox-2778-payloads` | `cit-exigence-lab-7db5-payloads` |
| Runtime service | `cit-demo-sandbox-2778-runtime` | `cit-exigence-lab-7db5-runtime` |
| Task queue | one per runtime | one per runtime |
| Schedule dispatcher | **paused** (project's own) · **enabled** (agent's) | paused |
| Agent | `cit-demo-sandbox-de61-agent` + its own runtime | — |

`demo-sandbox` is the one carrying a deployed agent, so it has **two** Exigence
runtimes: its own (`…-2778-…`) and the agent's (`…-de61-…`), plus the agent's
container.

**Terraform state prefixes in use (14)** — including
`provisioner/exigence-runtime/demo-sandbox`,
`provisioner/exigence-agent/demo-sandbox/agent.invoice-triage`, and older
hand-run roots under `exigence/…` and `platform/production/…`.

### 2.3 The naming pattern

Everything a client owns is prefixed `cit-<client>-<hash>-…`. The hash keeps
two clients with similar names from colliding. An agent gets its **own** prefix
(`de61`) distinct from the project's (`2778`), because an agent is separately
deployed infrastructure, not part of the project's runtime.

---

## 3. How a new project gets built

### 3.1 Creating the project — no infrastructure yet

1. An operator with the "create projects" capability fills in the form in the
   Console.
2. A project record is written to `platform_projects` in Citadel's registry.
3. The Console immediately **claims** it: because nobody holds a grant on a
   brand-new project, there is one special route that bootstraps the creator's
   grant. It refuses unless the project records that person as its creator *and*
   carries no grants yet — so it can be used exactly once, by the right person.
4. The operator connects the client's Firebase project in project settings.

Nothing has been built in the cloud at this point. A project is a record and a
set of permissions.

### 3.2 Turning a service on

Each service has a **setup plan** in the Console — a sequence of steps with
explanations and live checks. Every plan ends by writing an "enabled" flag and
the service's settings onto the project record.

**Only the current Exigence plan has a build step.** ARM and Conduit plans are:
explain what is needed → collect names → turn it on → verify. The work those
services need is in the *client's* project (grant Citadel read access, install
the SDK or tag), which is Terraform or a code change on the client's side, not
something Citadel builds.

When implemented, Baker adds a fixed Terraform Devstation template with one VM
per client. Manifold adds provider connectors and client-data-plane message
storage. Both must use the same reviewed plan/apply and reconciliation model.

### 3.3 The provisioning flow, when there is something to build

This is the part with the strongest safety rules, and they are worth
understanding.

```
Console  ──POST plan──►  Platform API  ──►  Cloud Run Job (citadel-provisioner)
                              │                       │
                              │                  terraform init + plan
                              │                       │
                              │              plan saved to GCS
   ◄──── what would be built, and what it costs ──────┘

Console  ──POST apply──►  Platform API  ──►  same Job, apply mode
                                                      │
                                            terraform apply (saved plan)
                                                      │
                                          resources exist; URL recorded
                                          back onto the project record
```

**The rules that make this safe:**

1. **It never runs submitted Terraform.** The caller names one of a fixed set of
   templates and supplies values for that template's *declared* variables.
   Nothing else reaches the runner. A service that executed caller-supplied HCL
   while holding a service account that can create cloud resources would be the
   most damaging thing this platform could get wrong.
2. **Plan and apply are separate permissions.** A plan shows what would be built
   and costs nothing. An apply spends money. Someone who reaches the apply route
   without the approve route can still create nothing.
3. **Apply refuses without a recorded human approval.** The runner checks who
   approved, by name, before it will apply.
4. **Apply replays the saved plan**, not a fresh one — so what is built is what
   was reviewed.
5. **State is scoped per deployment, not per project.** This was a real bug: a
   project-wide prefix meant a second agent's apply saw the first agent's
   resources as drift and would have destroyed them.

There are exactly **two templates**:

| Template | Required inputs |
|---|---|
| `exigence-runtime` | `customer_project_id`, `client` |
| `exigence-agent` | `client`, `customer_project_id`, `agent_id`, `agent_container_image`, `client_name_prefix`, `client_database_id`, `client_payload_bucket` |

The agent template requires a **digest-pinned image** and refuses a tag, so a
build can only ever name one exact image. It also requires the client's database
and bucket rather than defaulting them — it *attaches to* what the runtime
template already made, and a default would be the platform guessing at names it
has not read.

### 3.4 What `exigence-runtime` actually creates

Building Exigence for a client creates, in the client's project:

- a **Firestore database** named after the client — their runs and evidence
- a **payload bucket** — for anything too large to put in a document
- a **runtime service account**, granted access to *exactly that one database*
- an **invoker service account** — the identity queued work runs as
- a **Cloud Tasks queue** — every step is a queued task, which is what makes
  runs durable and retryable
- a **Cloud Run service** — the runtime
- a **Cloud Scheduler job**, once a minute, to start anything due
- a **Secret Manager secret** for the model provider credential
- **three Firestore indexes** — two for Knowledge Base vector search, one for
  monthly cost roll-ups
- the IAM to tie those together, plus Vertex AI and logging access

### 3.5 What `exigence-agent` adds

For each agent, on top of the above:

- a **service account for the agent container that holds no permissions at all**
- a **Cloud Run service** for the customer's container
- an IAM rule making it **invocable only by its own runtime**
- **a second complete Exigence runtime** — its own queue, scheduler and service
  account — because an agent is separately deployed and separately gated

The agent container is deliberately powerless. It cannot reach Google Cloud,
the database, or the internet on its own authority. It only *decides*; the
runtime *performs*, and every action goes through the permission gate.

### 3.6 How Exigence sub-features use that infrastructure

| Sub-feature | What it uses |
|---|---|
| Running an automation | Task queue → Cloud Run runtime → journal in the client's Firestore |
| Steps and retries | Each step is a queued task; the journal records every attempt |
| Approvals | Run suspends in the journal; approval resolution re-queues it |
| Schedules | Scheduler fires every minute; dispatcher starts what is due |
| Webhooks | Signed HTTPS call into the runtime |
| Model calls | Vertex AI, via the runtime's IAM; cost metered per call |
| Knowledge Base | Documents chunked and embedded into the client's Firestore; the two vector indexes make search work |
| Large payloads | The payload bucket, referenced from the journal |
| Cost and budget | Component costs in Firestore; the monthly index; budget reserved before spending |
| Audit | A hash-chained event log in the client's Firestore |
| Agents | The agent's own container, runtime, queue and scheduler |
| Local machine work | No cloud infra — the client's runner polls outbound |

Notice what this means: **a client's data never leaves their project.** The
runtime that touches it runs in their project, under a service account scoped to
their one database. Citadel's registry holds definitions and permissions, not
content.

---

## 4. Known gaps and risks

**Blocking or close to it**

- **`host_project_id` points at `learning-gcp-404803`.** Client infrastructure
  is being built in what was a personal sandbox. Moving it to `citadel-platform`
  and tearing the sandbox down is the endgame and has not started.
- **Feature branches are now published.** The four `feat/agent-artifacts`
  branches are on their GitHub remotes; merging and release promotion remain
  separate operator decisions.
- **Provisioning cannot be driven from a terminal** (§1.5). It needs a browser
  or service-account impersonation.
- **A standing privilege is load-bearing.** `obsidian.infinitum@gmail.com` holds
  token-creator on the provisioner service account. It is currently the *only*
  way to deploy into the client project — neither operator account can do it
  alone. Removing it closes that path, so remove it together with deciding what
  replaces it.

**Unverified**

- **Conduit and Palisade were not verified** against live infrastructure this
  session. No Conduit service exists in either project.
- **Baker** is an offering in the Console with an empty directory.
- **Manifold's WhatsApp path is built but unproven against Meta.** Channel
  record and publication, Console channels page and inbox, send connector,
  webhook verification and receipt, consent/opt-out, and conversation
  threading all exist and are tested. Nothing has spoken to Meta: it needs a
  WABA id, a phone number id, three Secret Manager version paths and a test
  recipient. The webhook endpoint is also not mounted on any service — doing so
  means accepting unauthenticated requests, which is a deployment decision.

**Missing features, in rough order of value**

1. **Read a spreadsheet.** `sheet.append` exists; there is no `sheet.read`. The
   code that edits `.xlsx` already parses the file, so this is the cheapest
   worthwhile addition.
2. **Office documents in the Knowledge Base.** PDF/Word/Excel/PowerPoint are
   refused. This is what stops "ask my slides a question".
3. **PowerPoint instructions** for the local runner.
4. **Console gaps for agents** — ceiling, image digest, deciding container.
5. **`citadel agents init|dev|deploy`** — scaffolding and image builds are
   manual.
6. **Complete Console ground truth** — several supported operations remain
   manual or CLI-only, and live resource drift is not yet presented in one
   reconciled inventory.
7. **Trusted runner relay** — direct data relay and inbound browser/computer-use
   actions are specified but not implemented.
8. **Palisade hardening** — end-to-end flow inventory, external attack
   detection, leak detection, and policy-drift alerting remain planned work.

---

## 5. Answering the common question

> *Can I build a LangGraph agent that reads the Knowledge Base, works with my
> local Excel and PowerPoint, and calls public APIs?*

**Mostly yes, today.** LangGraph is already the engine — it is a real dependency
and nine modules build on it. Artifacts *are* LangGraph graphs.

| Requirement | Status |
|---|---|
| Search the Knowledge Base | ✅ built end to end (`agent.knowledge.search`) |
| Call public APIs | ✅ built (`agent.http.fetch`) |
| Append to a local Excel workbook | ✅ built (`sheet.append`) |
| **Read** a local Excel workbook | ❌ needs `sheet.read` |
| Work with PowerPoint | ❌ nothing built |

So an agent that searches the corpus, calls APIs, and writes rows into a
workbook works now. Reading spreadsheets and touching slides is the gap.
