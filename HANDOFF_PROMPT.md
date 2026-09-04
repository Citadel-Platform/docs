# Handoff — 02/09/26

Read this, then `DECISIONS.md` (the topology decision in full, then the evening's
four trade-offs), then `DECISIONS_NEEDED.md` for what is waiting on a person,
then `_dev/features/00-03` Task 0.3.6, then `PRODUCTION_PUSH_AND_TEST.md` for
the findings log — F-001 through F-048.

**A long day, in five parts.** The F-001..F-031 backlog cleared and deployed.
Where a client's data lives changed, on a decision taken mid-session, and most
of the platform moved with it. `test-sandbox` was rebuilt on the new topology.
Every Conduit collection came off the browser's Firestore path and onto the
Platform API. And a client was created from nothing on a Google Cloud project
that had never held one, which is where most of the interesting findings came
from — including why creating a project had been impossible.

The sections below are in that order. If you only read one thing, read
"Exigence, proven end to end" and the four open questions it points at.

---

## 1. The findings backlog — closed

Twenty-seven findings fixed, deployed, and verified against production. Two of
them I found while verifying the others:

- **F-029** — the provisioner recorded `offeringScope.exigence.runtimeUrl` for
  *every* template, and `exigence-agent` emits a `cloud_run_uri` too.
  Provisioning an agent would have repointed the whole project at a runtime
  that serves one artifact and refuses everything else. The client's Exigence
  would have gone dark with nothing saying why.
- **F-031** — a provisioned runtime's own reference automation had no Palisade
  identity and no grant, so a freshly built client listed an automation that
  could not execute a single step. Every new client would have hit it.

**The proof that mattered:** an Exigence run completing end to end on
`test-sandbox` — four steps through a real human approval gate — which exercises
run creation, Cloud Tasks self-delivery, the permission gate in all three
outcomes (allow, approval-required, deny), the approval hold, and the audit
trail. That is what confirmed F-027, which had been the blocker.

**Corrections I made to my own earlier claims**, both recorded in the findings
log: F-030 was first written as "nothing explains a failed step", which was
wrong and wrong because of a bad probe — the audit route exists and answers.
And I diagnosed the first failed run as a boundary-pattern problem when it was
a missing identity.

---

## 2. Where a client's data lives — decided and built today

`DECISIONS.md` 02/09/26 has the whole thing. The short version:

Each client gets **their own Google Cloud project**, holding their `(default)`
business database, their dev/test/staging copies when Baker's Deployments is on,
and **one `citadel-*` database per Citadel product** they have enabled.

**The load-bearing reason, which is worth not losing:** Firestore IAM conditions
can name a *database* and cannot name a *collection*. One shared `citadel-data`
would put ARM's, Conduit's, Exigence's and Manifold's service accounts on the
same resource with application code as the only separation — and Conduit holds
session replays, which the permission catalogue already treats as categorically
different from the client's own material. A database each is what makes that
difference enforced rather than advisory.

Built: 0.3.6.b through .f. `client-data-plane` replaces `arm-data-plane`; ARM
reads `citadel-arm`; Exigence `citadel-exigence`; Manifold `citadel-manifold`
with its own IAM binding; `environment` tags every ARM record and filters both
list routes; `host_project_id` and `run_host_suffix` resolve per client from the
project record, and the runner reads the suffix back off the first address it
deploys.

Then, once existing clients were confirmed disposable, every compatibility hedge
came out. There is no fallback database name left anywhere: a setting whose only
correct value is the constant is a way to be wrong.

---

## 3. What driving the deployed Console found

The signed-in Console **is** scriptable, contrary to the note in earlier
sessions. One line first:

```js
document.querySelector('flt-semantics-placeholder').click();
```

Flutter only builds its accessibility tree on request. That click builds it —
150+ nodes with labels and real rects. Screenshots still time out (canvas
rendering); use `javascript_tool` to read and coordinate-clicks to act.

Four things reading the code had not shown:

1. **The Console was stale.** The ARM build step was committed and never
   deployed. Deploy after committing Console work, and verify the bundle hash.
2. **Step one contradicted step two** — it told the operator to connect the
   client's Firebase by hand, which the next step now does for them.
3. **A check failing on its own successor's output.** `_armConnectionCheck` ran
   on step one and reported the Firebase config incomplete, which the build step
   completes. It was *optional* so it did not block — which is worse, not
   better: red text that means nothing teaches an operator to ignore red text.
4. **26 places of text invisible to a screen reader.** Flutter's
   `SelectableText` does not reach the accessibility tree the way `Text` does.
   Every setup plan's instructions, and every copyable id, bucket name, commit
   sha and storage path, rendered visually and was silent to assistive
   technology. `CitadelSelectableText` fixes it and a test guards it, because
   this regresses invisibly.

---

## Live state, 02/09/26

| | |
|---|---|
| `citadel-platform-api` | `00039-4fp` |
| `citadel-arm-evidence` | `00006-fsz` |
| `citadel-conduit-ingest` | live |
| `citadel-provisioner` (Job) | `e35bd9a5…` — `client-data-plane`, variable filtering |
| Exigence runtime image | `48b5d0a6…`, pinned in `CITADEL_TEMPLATE_DEFAULTS` |
| Console | deployed, bundle hash verified, includes all four fixes above |

Tests: server 470 · Console 438 · exigence 801 · CLI 173 · Conduit 132 ·
Palisade 48 · ARM 35 · api 37 · tooling_core 8 · contracts 4 · rules 4 ·
provisioner 13. All analyzers and `tsc` clean; every template and the runtime
module validate.

---

## What this session did — 02/09/26, later

### `test-sandbox` is rebuilt, on the designed topology
The plan the last session left unapproved was approved on the operator's
explicit say-so and applied. Then all four offerings were enabled and a second
`client-data-plane` run planned **3 to add, 0 change, 0 destroy** and applied.
`learning-gcp-404803` holds `(default)` plus `citadel-arm`, `citadel-baker`,
`citadel-conduit`, `citadel-exigence` and `citadel-palisade`. The template's
incremental claim — "creates what is missing and leaves the rest" — is now
demonstrated against a live data plane rather than asserted.

**The Console was never driven.** The Chrome extension connected and dropped
four times; its routes were called directly instead. That is worth knowing
because the last handoff's "the Console is scriptable after all" note is not
what failed — the extension was.

### Two P1s, and the second one is why the first was worth chasing

**F-035 — ARM's identity reached every database in the client's project.**
`roles/datastore.user`, project-wide and unconditioned, live in the policy. The
last handoff flagged this root as "still grants against the old arrangement",
which undersells it. Under the old arrangement the client's project held one
database and the grant was correct. Under the new one it holds six, so the grant
handed ARM's runtime the client's own business data and Conduit's session
replays.

The thing worth not losing: **no conditioned IAM binding existed anywhere in
`platform/infra`.** The whole topology decision rests on Firestore IAM being
able to name a database, and that only enforces something where a binding
carries the condition. In the control plane it was a comment. The Exigence
runtime module had the working form all along — `resource.name ==
"projects/<p>/databases/<db>"` — so the fix was to use the idiom that already
existed, not to invent one.

**F-036 — only ARM's setup could ever create a client's databases.** Going to do
what this handoff said to do — "re-run the build step for each" — found there is
no build step for each. `client-data-plane` appeared in exactly one place in the
Console. Conduit and Baker had none; Exigence's builds a runtime. So enabling
Conduit after ARM created no `citadel-conduit`, and a client who never bought
ARM had no path to a database at all — Conduit correct and empty, Exigence's
runtime deployed pointing at something that did not exist.

Inside it, a second defect: `_citadelDatabasesFor` read the scope **as saved**,
which during setup is the scope without the service being set up. Fixing the
step placement alone would not have fixed that, which is why the change is to
hand every step body the *prospective* scope — right whether the build runs
before the enable step (ARM) or after it (the other three).

---

## Live state, 02/09/26 (later)

| | |
|---|---|
| `citadel-platform-api` | `00039-4fp` |
| `citadel-arm-evidence` | `00006-fsz` |
| `citadel-conduit-ingest` | `00003-wvv` |
| `test-sandbox` data plane | applied — 6 databases, all four offerings on |
| `citadel-arm-evidence` on the client project | conditioned to `citadel-arm` |
| Console | rebuilt and deployed; live bundle `edb70453ac7d2a12` verified against a **freshly built** local one |

Tests: Console 439 · server 470 · provisioner 13 · contracts 4. Analyzers clean;
`terraform fmt -recursive -check` and `validate` clean on both customer roots.

---

## The E2E pass — 02/09/26, evening

31 backend assertions pass. Two of the three that failed were the test being
wrong and the platform being right (a browser token is refused principal
authority by design; `data-flows` is an Exigence route, not a project one), and
both are properties worth keeping. Chrome was finally usable — the extension was
not broken, **Chrome was being restarted between calls**, which closes the MCP
tab group; `exit_type` was `Normal` and there were no crash reports. Everything
in one `browser_batch` starting from `navigate`, and it works.

Four more defects, three of them P1, and every one of them needed the thing to
actually run:

- **F-037 — the whole Conduit section of the Console is unreachable.** It reads
  `conduit_projects` and four sibling collections straight from Firestore in the
  browser, and `firestore.rules` has no match for any of them, so they fall to
  `allow read, write: if false`. Proved with the operator's own ID token against
  the Firestore REST API: six Conduit collections 403, `platform_projects` 200.
  The rules are right — that document holds `projectKey`, the ingest credential
  — so the fix is an API route, and it needs a product answer first: does a
  browser ever get to see that key? **Left for that decision.**
- **F-038 — `exigence-runtime` and `client-data-plane` both created
  `citadel-exigence`.** 409 after thirty resources. Fixed: the data plane owns
  the databases. Re-planned 18/0/0 and applied.
- **F-039 — a client cannot be rebuilt for a week after teardown.** Cloud Tasks
  reserves a deleted queue's name for ~7 days and the name is derived from the
  client id. The operator finds out from a raw Google error after a nine-minute
  apply. Not fixed; the remedy is a design call.
- **A regression I introduced and caught.** F-036 gave Exigence's plan two
  adjacent body steps; Flutter reused the first's State, so "Build the service"
  showed the data plane's finished job, said "Nothing to do", and queued
  nothing. Keyed by step id, with a test that fails without it.

**Verified, and this is the one worth keeping:** every `roles/datastore.user`
binding in the client's project is now conditioned to exactly one database —
ARM to `citadel-arm`, the Exigence runtime to `citadel-exigence` and
`citadel-manifold`. Three services, three conditions, no unconditioned grant.
That is the property the topology decision rests on, holding across all of them
at once, which had never been shown before.

**Teardown verified:** 32 destroyed; no services or runtime identities left; all
six databases survive on `ABANDON`, so a Citadel teardown does not take the
client's data with it; ARM's conditioned binding intact.

---

## Live state, 02/09/26 (evening)

| | |
|---|---|
| `citadel-platform-api` | `00039-4fp` |
| `citadel-arm-evidence` | `00006-fsz` |
| `citadel-conduit-ingest` | `00003-wvv` |
| `citadel-provisioner` (Job) | `590cd503…` — F-038 |
| Console | `410c87ec5c1dad3c`, verified against a freshly built local bundle |
| `test-sandbox` | data plane only: 6 databases, 4 offerings on, no Cloud Run |

Tests: Console 440 · server 470 · provisioner 13 · contracts 4. Analyzers,
`terraform fmt -recursive -check` and `validate` clean.

---

## F-037 and F-039 closed — 02/09/26, evening

**F-037 — fixed.** `GET`/`PUT /v1/projects/{id}/conduit/context`, served under
the API's own service account. The collection stays closed because the reason it
is closed is right: it holds the ingest key. Two new permissions, read and write
held apart, both superdev-only — which is where `superdevOnlyPermissions` says
things go when they "expose configuration a client does not see today". The key
is still served to the operator, deliberately: it is what they install in the
client's site. What changed is that serving it is a permission rather than an
accident.

Verified end to end: Voice of Customer went from "Not permitted — check your
roles" to "No project configuration"; Touchpoints, which was unreachable, renders
the key and every capture setting; a toggle flipped in the Console persists; and
the key written through the route authenticates at the public ingest edge while
a wrong key is still refused. Console → API → Firestore → ingest.

Still owed: Voice of Customer's *save*, plus `conduit_source_maps` and
`conduit_alerts`. VoC batches the context with `conduit_hosted_survey_deployments`,
which is denied too, so migrating half would turn an atomic refusal into a write
that half-succeeds. It needs a route that does both.

**F-039 — the queue still gets deleted, per the operator, and now people are
told.** The runner translates *"a queue with this name existed too recently"*
into what it means and what to do, keeping Google's wording after it; anything
unrecognised passes through unchanged, because a wrong explanation is worse than
a raw one. The retire dialog says a later teardown blocks rebuilding for about
seven days — said where the decision is made, since that is a week before it
bites.

**F-041, found doing it.** A real event through the public edge answered
`500 … retryable: true` for a project whose context has no ingest target. The
request was fine and nothing broke — the project simply is not finished being
set up — so an instrumented site would have retried forever against a condition
only an operator can clear. Now a 409 `failedPrecondition` naming the project,
what is missing and who fixes it.

---

## Live state, 02/09/26 (end)

| | |
|---|---|
| `citadel-platform-api` | `00040-4cv` — the Conduit context route |
| `citadel-conduit-ingest` | redeployed — the ingest precondition |
| `citadel-arm-evidence` | `00006-fsz` |
| `citadel-provisioner` (Job) | `16967053…` — `explainFailure`, F-038 |
| Console | `163e9ec8729ffa47`, verified against a freshly built bundle |
| `test-sandbox` | data plane only: 6 databases, 4 offerings, Conduit configured |

Tests: Console 443 · server 479 · conduit ingest 134 · palisade authority 48 ·
provisioner 16 · contracts 4. Backend sweep 31 pass. Analyzers, `terraform fmt
-recursive -check` and `validate` clean.

---

## Finished up — 02/09/26, late

**Conduit is complete.** The last three closed collections got routes, and
`platform_firestore` reaches no `conduit_*` collection at all now. Voice of
Customer's save — the awkward one, because it writes the context and the survey
deployments it implies — got a route that commits both together. Two properties
worth keeping, both verified in production: `kind` is a closed set rather than a
collection name (this runs as the API's service account, so a caller-supplied
kind would read anything), and the flat collection's `projectId` is stamped by
the server, since it is the only thing separating one client's surveys from
another's.

**Three more P1s, each found by walking something nobody had walked.**

*F-043* — every API client threw the status alone and discarded the platform's
own sentence, so a client with no Exigence runtime was told its automations
"changed since this screen loaded" on a page that had changed nothing. The
Console now carries the platform's `code` and `message` — and only those two
fields, because session search asserts that private detail never reaches an
exception message, and its test caught the first attempt to pass the whole body.

*F-042* — `client-data-plane` registers the client's web app and emits its whole
Firebase configuration, described in the template as what saves anybody retyping
seven values off a screen. Nothing read it. So the last step of the flow that
exists to remove the manual Firebase work ended by asking for it back. This is
also why "Apply 0 changes" came back, renamed: a zero-change apply is exactly how
a client built before an output existed gets that output recorded, and the button
now says what pressing it does.

*F-044* — the best one. `describePlatformFirestoreFailure` read a non-const
`int.fromEnvironment` unconditionally, and dart2js throws on that in a release
build. So in production **the function that turns a Firestore error into a
sentence was itself throwing**, and what reached the operator was its error
instead of theirs. Underneath was an honest, actionable message all along. A test
reads the source, because on the VM a non-const `fromEnvironment` evaluates
happily and no ordinary test could have caught it.

**The Console is swept.** Every product section walked on `test-sandbox`, and all
four setup wizards end to end — each carrying the shared data-plane step, each
planning 0 to add against a complete data plane. Idempotency from four plans.

---

## Live state, 03/09/26 — read back from the deployments

| | |
|---|---|
| `citadel-platform-api` | `citadel-platform-api-00044-6n8` |
| `citadel-arm-evidence` | `citadel-arm-evidence-00006-fsz` |
| `citadel-conduit-ingest` | `citadel-conduit-ingest-00004-p5p` |
| `citadel-provisioner` (Job) | `70e83f64…`, pinned in `provisioner/images.auto.tfvars` |
| Exigence runtime image | `e20494ed…`, in `CITADEL_TEMPLATE_DEFAULTS` |
| Console bundle | rebuilt and deployed 03/09 with the OAuth client id compiled in |
| `user-test-1` | GCP `testproj-448205` · Exigence only · `(default)`, `citadel-exigence`, `citadel-palisade` · runtime addressed at the **derived** `https://cit-user-test-1-acb1-runtime-351182428948.us-central1.run.app` · no `runHostSuffix` recorded · repeated plans are no-ops · a run's first step enqueued and returned `succeeded` |
| `test-sandbox` | GCP `learning-gcp-404803` · 6 databases · 4 offerings · Conduit configured · no Cloud Run · Exigence blocked until ~09/09/26 |
| `axis-education` | GCP `luminary-axis-dashboard` · **not migrated**, no provisioning jobs |

`user-test-1` is deliberately the one client with **no** `runHostSuffix`
recorded: it is the worked example of the derived address (F-050). Clearing that
field is how any client moves onto it.

Onboarding a client into a fresh Google Cloud project is no longer manual. The
consent step admits Citadel (F-049), the bootstrap says whether the project can
be billed (F-052), the runtime template grants the client's service agent read
on the image repository (F-051), and the runtime's own address is derived rather
than discovered (F-050). The four gaps a new project exposed on 02/09 are closed.

Both digests are pinned in Terraform and agree with what is deployed. The
Console bundle was verified against a freshly built local one on every deploy —
that check only proves "local matches remote", so it is only worth anything
when the local build is fresh.

Tests: Console 452 · server 487 · conduit ingest 134 · exigence runtime 801 ·
palisade authority 48 · provisioner 16 · contracts 4. Analyzers,
`terraform fmt -recursive -check` and `validate` clean.

---

## NEXT — pick up here

**The four things waiting on a person are written up in `DECISIONS_NEEDED.md`
02/09/26**, with what each blocks: whether Exigence should serve relay
observations at all (F-048), an OAuth client ID in `citadel-platform`, what the
client bootstrap must actually do now that a fresh GCP project has shown it, and
the order `axis-education` has to be migrated in. Today's own trade-offs — why
the registry rules stopped validating schema, why Conduit's configuration is
superdev-only, why an upstream error contributes only its code and message, and
why a teardown still deletes the queue — are in `DECISIONS.md` 02/09/26
(evening).


### F-048 — two Watchdog surfaces, and a product question
`watchdog/relay` answers 404 and `watchdog/authorization` refuses a window it
documents as required, on an image built from today's source — so this is a gap
in the runtime, not a stale deployment. Refusing rather than returning an empty
report is right and the source argues for it. What is wrong is that
`{"error":"invalid_request"}` carries no detail while the handler has two
distinct reasons for it, so from outside they are indistinguishable. The
underlying question — whether relay observations are meant to be served at all —
is a product one.

### 0.3.6.a, now with three concrete jobs
It was "enable the base APIs and grant the provisioner its roles". This session
found what else a new client project needs: billing attached, the Cloud Run
agent granted on the image repository, and the host suffix discovered and
recorded. It still needs an OAuth client ID created in `citadel-platform`.

### `axis-education` — last, as the operator asked
No provisioning jobs at all. Run `client-data-plane` there first; its customer
root carries the F-035 IAM fix in source and must not be applied until
`citadel-arm` exists.

### `test-sandbox` is Exigence-blocked until ~09/09/26
The reserved Cloud Tasks queue name. `user-test-1` supersedes it as the Exigence
test client.
