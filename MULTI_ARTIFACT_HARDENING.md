# Multi-artifact hardening — 04/09/26

Five weaknesses, found by driving `user-test-1` to a working WhatsApp agent and
then auditing what that exposed. Written before any of them was fixed, so the
order and the reasoning can be checked against what was actually done.

## The register that was missing

F-069 through F-077 existed only in commit messages and code comments when this
was written. `PRODUCTION_PUSH_AND_TEST.md` stopped at F-066. The Manifold rules
gap in that file records the same class of defect reaching production **three
times**; an unwritten register is how a fourth happens. They are recorded at the
bottom of this file and belong in the main register.

## The five

### 1. Cost scales with artifacts x clients, and it is always-on
Every runtime carries `minScale=1`: one permanently warm Cloud Run instance
(1 vCPU, 512Mi) per artifact per client, plus a queue and two service accounts.
Ten clients with five agents each is fifty idle instances billed continuously.
`min=0` trades that for a cold start on a customer's first message. Nobody has
chosen; it is inherited from the single-runtime era when one instance per client
was the whole cost.

### 2. "Per project" assumptions break silently once a project has several artifacts
The one that matters, because it is the only one that fails without saying so.
Confirmed instances:

* **FIXED 04/09/26 (F-076).** `exigenceRuntimeServiceAccounts` was plural in
  name, returned a set, and yielded only the project's own runtime — so an
  agent asking what its artifact may do was refused and every run died on its
  first step.
* **OPEN.** `platform_project_inventory_service` reports exactly one Exigence
  runtime per project, from `offeringScope.exigence.runtimeUrl`. An agent's
  runtime is a second always-on Cloud Run service that the operator's own
  resource inventory does not show.
* **OPEN.** The same file's live observation matches deployed services by
  `candidate.uri == recordedRuntimeUrl`. Nothing observes an agent's service, so
  an agent whose runtime is deleted drifts silently — the F-001 finding the
  inventory exists to make first-class, reintroduced for agents.
* **Considered and NOT a defect.** `ExigenceRoutingResolver` sends every
  control-plane call for a project to the single recorded `runtimeUrl`. It reads
  as wrong and its own docstring is now stale ("Exigence is single-tenant: a
  runtime is pinned to one project"), but administration is journal-level and
  every artifact in a project shares one database — cancelling sixteen
  superharness runs through the client's reference runtime worked for that
  reason. An agent-only project cannot exist today, because `exigence-agent`
  derives the client invoker from `client_name_prefix` and writes its route into
  the client's database. Left alone, docstring corrected, assumption written
  down so the next reader does not have to rediscover it.

### 3. A template that has never been applied is a broken template
F-073: `exigence-agent` had never once been applied — 56 `exigence-runtime` and
16 `client-data-plane` jobs against zero. Applying it took six plan/apply cycles
and surfaced a duplicate `outputs.tf`, a missing `actAs` grant (F-072) and an
unrecorded runtime identity (F-076). None was caught by a test.

The same shape elsewhere: `platform_rules_contract_test` held a hardcoded copy
of the offerings list, went stale, and let the Manifold rules gap through — the
third occurrence of that exact gap. Hardcoded copies of enumerable things, and
infrastructure proven only by running it.

### 4. Provisioning is slow, serial and hand-driven
Each plan and each apply is a separate Cloud Run job execution, 5-15 minutes per
round trip. The duplicate `outputs.tf` — an error `terraform validate` reports
in under a second — cost a full build, deploy and plan cycle to find.

### 5. The authority check is an uncached read plus a collection list per run start
`projectRuntimeServiceAccounts` reads the project document and lists
`artifactRuntimes` on every principal-authority request. Deliberate ("a stale
yes is worse than a slow no") and correct for an authorisation decision, but it
is on the hot path of every run and unbounded in the number of agents.

## Order of work

1. **Template validation in the test suite** (3, 4). Cheapest, catches a whole
   class locally, and is the safety net the rest of the work is done over.
2. **Agents are first-class in the registry and the inventory** (2). The only
   silent one.
3. **Derive, do not copy** (3). Hunt the remaining hardcoded enumerations.
4. **The authority lookup's cost** (5). Evaluate before changing; correctness
   first, and a cache on an authorisation decision needs an argument.
5. **`minScale` as a deliberate choice** (1). Needs a product decision, so it is
   surfaced rather than silently changed.

---

# What was actually done — 04/09/26

## 1. Cost — assessed, nothing changed, and the assessment was wrong

This was written up as an unconsidered default inherited from the
single-runtime era. It is not. `min_instances = 1` carries a comment and a
finding: a run's kickoff returns long before the run is over and the next step
arrives as a Cloud Tasks callback minutes later, so scale-to-zero plus
throttled idle CPU recycles the instance between the two and the callback
cold-starts without the graph state. The symptom is "no available instance" and
a run that fails at step 1. **One warm instance is a correctness requirement,
not a latency preference. See F-027.**

So `min=0` is not available, and the cost is real: one warm instance per
artifact per client. The only lever that would change it is a runtime serving
several artifacts, which trades away the "serves one, refuses the rest"
isolation the authority model leans on. Left alone deliberately; recorded here
so the next person does not re-derive it, and so the earlier claim in this file
is not left standing uncorrected.

## 2. Per-project assumptions — fixed (F-078)

The provisioning runner records each agent's address beside its identity. The
inventory emits a node per agent, sorted so it does not reorder between reads.
The live observer matches each agent's service the same way it matches the
project's own.

One thing worth recording, because it happened while fixing it: the first
version of the drift check was nested inside `if (recordedRuntimeUrl != null)`,
so an agent would not have been observed unless the *client* had a runtime of
its own — the same "per project" assumption, one level down, written by the
change meant to remove it. The Cloud Run listing is now gated on the project's
own address **or** any agent's, and a test covers exactly that case. It was
confirmed to fail against the nested version.

## 3. Untested templates — fixed

`template_validity_test` stages every template the way the image stages it,
reading the stagings out of the Dockerfile so the two cannot drift, and runs
`terraform init -backend=false` and `terraform validate`. Every template
directory is discovered rather than listed. Confirmed to fail against the
duplicate `output` block that cost a full build/deploy/plan cycle to find.

Three templates validate in about eleven seconds.

## 4. Provisioning round trips — improved by (3), not otherwise changed

The class of error that cost the most time is now caught locally in seconds.
The remaining slowness is plan and apply being two separate job executions,
which is the approval gate working as designed: an operator approves a plan and
the apply runs that plan. Not changed.

## 5. The authority lookup — evaluated, cache refused, real bug found

A cache was considered and rejected. The existing comment is right that a stale
"yes" on "who may ask what an artifact may do" is worse than a slow "no", and
there is no evidence the read hurts.

Evaluating it did surface a defect introduced with F-076: both new readers used
a single `list` with `pageSize: 100` and no page token. A project's hundred and
first agent would have been absent from the inventory and — far worse — refused
when it asked what its artifact may do, which is F-076 again with a page
boundary for a cause. Both readers now share one helper that follows the pages.

## 6. Derive, do not copy — one more guard (F-079)

`ProjectOfferingScope` is freezed with a default on every field, so a
construction that omits an offering compiles and silently resets it, and the
settings screen rewrites `offeringScope` wholesale — an omission deletes what
the operator had. That is exactly how Manifold was dropped. The settings
encoder is now checked against `Offering.values`, so a sixth offering fails a
test instead of a customer's project. Confirmed to fail with `manifold` removed.

The three other `ProjectOfferingScope` constructions that omit offerings are
seed data, where showing an offering as off is honest. Checked, left alone.

## Findings this file adds

* **F-078** — an agent's runtime was invisible to the inventory and unobserved
  by the drift check.
* **F-079** — the Console's settings save could silently drop an offering, and
  nothing but a reviewer's attention stopped it.
