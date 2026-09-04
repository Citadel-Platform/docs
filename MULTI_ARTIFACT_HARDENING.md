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
