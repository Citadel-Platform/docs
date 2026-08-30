# Agent artifacts — handoff snapshot

> **Superseded 27/08/26.** This preserves historical live-test evidence for a
> customer-written container path that contradicted the 14/08/26
> operator-only-authoring decision. Its source, APIs, CLI, template and SDK
> have been removed. The deployed demo-sandbox resources and stale registry
> field require a separately reviewed Terraform/data decommission; do not use
> this document as current operating guidance.

**Updated 26/08/26.** The chain is closed end to end. A customer-written Dart
agent ran on demo-sandbox, held for a person, resumed on their decision, and
wrote. Everything below is live unless marked otherwise.

## The chain closed

All four runs on `demo-sandbox` are `succeeded` and all four approvals are
resolved. Nothing is pending.

| run | artifact | result |
|---|---|---|
| `run-cfce2e14…` | `agent.invoice-triage` | succeeded, seq 29 |
| `run-40b42956…` | `agent.invoice-triage` | succeeded, seq 29 |
| `run-ddc3ab22…` | `exigence.reference.summary` | succeeded, seq 30 |
| `run-7a9e8c0c…` | `exigence.reference.summary` | succeeded, seq 30 |

The agent run resolved like this:

```
act-0   succeeded   fetched https://citadel.obsivision.com/
act-1   succeeded   agent.store.write, after a person approved it
act-2…5 skipped     the agent finished before its ceiling
result  succeeded
```

What the approver read was the sentence the Dart agent wrote — not a tool name:

> File https://citadel.obsivision.com/ for manual review

and the approval carries `resolvedBy: firebaseIdToken:VqvN416T…`, the operator
as the Platform API states them. The write landed in `invoices`, keyed
`run-cfce2e14…:act-1:act-1`:

```json
{ "sourceUrl": "https://citadel.obsivision.com/", "verdict": "review" }
```

**The replay model passed its live test.** On resume the agent re-executed
`run()` from the top and asked for the same write with the same arguments;
`act-2…5` are `skipped`, which is the status that exists because an agent
declares the most steps it may take and stops when it is done.

## Getting there took four more fixes

None were hypothetical; every one was refusing a real decision in production.
All four are the same species as the eight before them — a rule that lived in
several places and was corrected in some of them.

**1. Approval-resolve reached the wrong runtime** (`platform_proxy_handler.dart`).
`_runOwner` read a top-level `projectId` to validate the run-detail response.
That envelope is `{"run": {…}}` — the coordinate rides *on the run*. The check
could never pass, so every resolution fell back to the project's runtime instead
of the artifact's, and the agent's runtime never saw it. Now reads
`run['projectId']`, which keeps the same guarantee: a response about another
project cannot decide where this project's mutation is sent.

The `per-artifact routing` test missed it because its stub answered
`{"projectId": …, "run": {…}}`, a shape the runtime does not produce. The stub
now matches the real envelope and fails against the old code with the exact
production symptom.

**2–4. The operator's actor id was refused in three more places.** The platform
states a person as `<credential type>:<subject>`; `actorIdPattern` allows the
colon and `validateActorId` exists for exactly this. Three call sites still ran
it through the identifier pattern, which does not:

- `firestore_journal.validateApprovalResolution` — `resolvedBy` on the write;
- `validation.validateAuditEvent` — `actorId` on the audit append;
- `validation.validateApproval` — `resolvedBy` on the **read-back**, which
  failed the resolution *after* the decision was already durable. An operator
  was told nothing was recorded about a write that had happened.

`approval.requestedBy` stays an identifier on purpose: an artifact asks, a
person answers.

## Latent instances of the same rule, now also fixed

These were not reachable from the approval path but would have failed the same
way the moment an operator reached them:

- `task_dispatch.validateCommand` — `requestedBy` on `cancel_run`. Operator run
  cancellation from the Console could never have dispatched.
- `project_kill_switch` and `firestore_project_kill_switch` — `requestedBy`.
- `configuration_repository.validatePointer` — `updatedBy`, so a
  Console-driven configuration publish would have been refused.

Each has a regression test, and each test was confirmed to fail without its
fix. The configuration pointer is covered by the emulator suite, which was run.

## What is deployed

| | |
|---|---|
| Exigence runtime image | `runtime@sha256:9163a781…` (tag `agents-4`) |
| Agent container image | `agent-invoice-triage@sha256:095c12be…` (tag `v1`) |
| Platform API image | `citadel-platform-api@sha256:0c1e6350…` (tag `agents-2`) |
| Provisioner image | `citadel-provisioner@sha256:681706c4…` (tag `agents-1`) |

Live revisions: `citadel-platform-api-00023-74d`,
`cit-demo-sandbox-de61-runtime-00004-2k2`,
`cit-demo-sandbox-2778-runtime-00003-ht9`.

In `learning-gcp-404803`:

- `cit-demo-sandbox-de61-agent` — the Dart container. Runs as
  `cit-demo-sandbox-de61-agent@…`, which holds **no grants at all**. Invocable
  only by the runtime below.
- `cit-demo-sandbox-de61-runtime` — the Exigence runtime serving
  `agent.invoice-triage`. Its own service account, task queue and scheduler.
- `cit-demo-sandbox-2778-runtime` — the client's original runtime. Serves
  `exigence.reference.summary`. **No longer untouched:** it was on an image
  predating all of this work, which meant its own approvals could not resolve
  either, so it now runs the same `agents-4` build as the agent's runtime.

Published configuration for `agent.invoice-triage` is generation 1, tools
`agent.http.fetch, agent.model.generate, agent.store.write, agent.notify`,
ceiling 6 steps. The Palisade principal `agent.invoice-triage` holds
`exigence.tools.read`, `exigence.tools.write`, `exigence.communications.send`
on `demo-sandbox`.

Terraform state for the agent is at
`gs://citadel-platform-terraform-state/provisioner/exigence-agent/demo-sandbox/agent.invoice-triage`.

## Standing privilege to review

`user:obsidian.infinitum@gmail.com` was granted
**`roles/iam.serviceAccountTokenCreator` on
`citadel-provisioner@citadel-platform.iam.gserviceaccount.com`**, so Terraform
could run locally as the identity that already holds the right roles in the
client project.

**It is load-bearing for deploying to the client project today**, which it was
not when this was written. Neither account can do it alone: `siddharth` can
deploy Cloud Run in `learning-gcp-404803` but cannot pull from the
`citadel-platform` registry, and `obsidian` is the reverse. Impersonating the
provisioner is the only path that holds both, and it is how the two runtime
rollouts above were done. Removing the grant closes that path, so remove it
together with deciding what replaces it. Remove it with:

```
gcloud iam service-accounts remove-iam-policy-binding \
  citadel-provisioner@citadel-platform.iam.gserviceaccount.com \
  --project=citadel-platform --member=user:obsidian.infinitum@gmail.com \
  --role=roles/iam.serviceAccountTokenCreator
```

It exists because a **user account cannot mint an audience-scoped identity
token**, so the Platform API's provisioning and publish routes could not be
driven from a terminal at all. Those routes want a Firebase ID token, which
means a browser. Worth fixing properly: either a service-credential path for
operators, or drive it from the Console.

## Working files (outside the repo)

- Staged Terraform root: `<scratchpad>/exigence-agent` — the committed template
  plus `modules/runtime` copied in and `agent.auto.tfvars` for demo-sandbox.
- Impersonated ADC: `<scratchpad>/provisioner-adc.json` — wraps the local ADC
  user to act as the provisioner. Used by the publish tool and Firestore reads.

## What changed in the tree

**Agent artifacts (new).** `agent_harness_graph.ts` (unrolled, one node per
step opportunity, because the approval hold's identity derives from the node
name), `agent_protocol.ts`, `agent_container_client.ts`, `agent_tools.ts`,
`agent_runtime.ts`, `agent_bundle.ts`, `tool/publish_agent_configuration.ts`,
and the `citadel_exigence_agent` Dart SDK with a worked `example/`.

**Per-artifact routing.** A project now has one runtime per agent plus its own.
`offeringScope.exigence.artifactRuntimes.{definitionId}` in the registry says
where each answers; `ExigenceRoutingResolver` reads the whole table in one
document read. Approval-resolve and cancel are addressed by run rather than
artifact and end in a Cloud Tasks dispatch, so they ask the project's runtime
which artifact owns the run before routing — after authorisation, and only for
projects that actually have agents.

**Bugs found and fixed on the way** (each was live, none were hypothetical):

- `run_start.ts` hard-coded the two artifacts it knew, so an agent could never
  have started; and its duplicate-start check looked for a step named `fetch`,
  so a redelivered start for any other artifact returned early and the run sat
  created and never dispatched.
- `completeRun` required every step to have succeeded, so an agent stopping
  early would report `running` forever. New `skipped` step status.
- The artifact registrar reconciled per *client*, so a second runtime deleted
  the first's registrations on every boot.
- The artifact listing read the reference automation's `version`/`enabled`/
  schedule for every row — an agent someone disabled listed as enabled.
- The schedule dispatcher started every schedule in the project, so a scheduled
  agent would have been enqueued onto the wrong runtime's queue.
- Two agents in one project collided on shared configuration resource ids.
- The provisioner's Terraform state prefix was per project, so a second agent's
  apply would have destroyed the first agent's infrastructure. Now
  instance-scoped, in `lib/` with a test, because that is the highest-cost
  mistake in that image.
- `INGRESS_TRAFFIC_INTERNAL_ONLY` on the agent container looked like a free
  second boundary and was not: Cloud Run egress goes to the internet without a
  VPC connector, so the runtime's own call arrived as external and Cloud Run
  answered 404. IAM is the boundary.
- The agent root declared the client database's Firestore indexes, which the
  client's own root already owns. `manage_database_indexes` now follows
  database ownership.

## Gates

All green: 572 Exigence TS (479 pass, 93 emulator-gated) **plus 95 emulator
tests run against a real Firestore and all passing**, 162 platform server,
179 CLI, 45 Palisade, 14 provisioner, 8 Dart SDK and example. `dart analyze`,
`flutter analyze` and `tsc --noEmit` clean everywhere.

The emulator suite is worth running on this area specifically: three of the
four bugs above survived a passing unit suite because the fixtures were fakes
that never reach the real validators.

## Not done

- **Nothing is committed.** Everything in this document lives in the working
  tree across `citadel_core/exigence` and `citadel_core/platform/server`, and
  the deployed images were built from it. That is the largest open risk here.
- **Console**: agents render under the existing "Agents" section with no
  change, but nothing shows an agent's ceiling, its image digest, or which
  container decides. `ExigenceDefinitionResource` already carries all three.
- **`citadel agents init|dev|deploy`**: `publish|show|tools` exist and are
  tested; scaffolding a new agent and building/pushing its image are still
  manual (`agent_sdk/cloudbuild.agent.yaml` does the build).
- **Conduit and Palisade** verification — not started this session.
- **`host_project_id`** still points at `learning-gcp-404803`; flipping it back
  to `citadel-platform` and tearing down demo-sandbox/exigence-lab is the
  original endgame and has not begun.
