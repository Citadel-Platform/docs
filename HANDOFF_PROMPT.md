# Handoff — 02/09/26, the client data topology, and what driving the Console found

Read this, then `DECISIONS.md` 02/09/26 (the topology decision in full), then
`_dev/features/00-03` Task 0.3.6, then `PRODUCTION_PUSH_AND_TEST.md` for the
findings log.

Two separate bodies of work happened today. The first cleared the F-001..F-031
backlog and deployed it. The second changed where a client's data lives, on a
decision taken mid-session, and is the reason most of the platform moved.

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

## NEXT — pick up here

### The task in flight: re-provision `test-sandbox` through the Console

`test-sandbox` was **torn down completely** — 44 Terraform resources destroyed,
`learning-gcp-404803` verified empty (no Cloud Run, no databases, no buckets, no
service accounts), state cleared, and the registry record reset to a claimed
client with `offeringScope` empty and no recorded runtime.

**Where it stopped:** ARM was toggled on in the Console, its build step queued a
real `client-data-plane` job, and that job **planned successfully**:

```
prov-1788330708446-3aq7p7be   planned   add 5, change 0, destroy 0
  google_firebase_project.client
  google_firebase_web_app.client
  google_firestore_database.client_production          ← (default)
  google_firestore_database.citadel["citadel-arm"]
  google_firestore_database.citadel["citadel-palisade"]
```

Exactly the designed topology, and only the databases the enabled services need.
**It is planned and not approved.** Approving it creates a Firebase project,
which cannot be undone.

Then: enable **Conduit**, **Exigence** and **Baker** the same way, re-running the
build step for each — it creates what is missing and leaves the rest — and
confirm each new `citadel-*` database appears. `test-sandbox` had all four
enabled before the teardown.

### Then
- **0.3.6.a's browser half.** The server side is built, deployed and tested:
  `PlatformClientProjectBootstrap` and `POST /v1/projects/{id}/bootstrap`, which
  enables the base APIs and grants the provisioner its roles under the
  operator's own OAuth token. Only its two refusal paths are proven — a real
  success needs a real token, which needs the browser step: a Console button
  that opens the Google popup with the `cloud-platform` scope. That needs an
  OAuth client ID created in `citadel-platform`, which is production config and
  was deliberately left for the operator.
- **The IAM read-modify-write has never touched a live policy.** Unit-tested,
  including that it preserves existing bindings and sends the etag back. Worth
  watching the first time it runs for real.

### Known incomplete
- `test-sandbox`'s **`customers/test-sandbox/iam` root** still grants against
  the old arrangement. Re-check it once the data plane is applied.
- **F-016/F-022's Console half** for Watchdog is done; the equivalent
  per-section treatment on other proxy-backed pages was not surveyed.
