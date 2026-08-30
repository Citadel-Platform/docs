# Handoff — 29/08/26 06:45

Read `DECISIONS.md` (28/08/26 entries), then `CURRENT_TASK.md`. This brief
covers only what changed in this session and what it leaves you.

## Where the work stands

Phase 2's Artifact substrate is complete. The immutable Artifact revision is
the single authoritative record: it owns typed graph and trigger configuration
and pins every shared resource and Palisade boundary by digest. Everything that
competed with it is deleted, not deprecated.

Nine commits across four repositories:

    citadel_core       1eae5b4  retire the Exigence configuration proxy routes
                       03dede0  pin boundaries a bootstrapped artifact publishes against
                       8896111  publish Access and Effect Boundaries as revisions
                       7e8f83d  refuse a boundary id nothing could ever pin
    citadel_core/exigence
                       80f549b  own typed configuration in artifact revisions
                       3cf98e5  run from artifact revisions, not an active pointer
                       b763dba  pin boundaries a bootstrapped artifact publishes against
                       a95d1ed  hold the platform's coordinate contract from this side
    citadel_platform   633d95f  remove the unreachable artifact configuration surface
                       6c12e60  manage Access and Effect Boundaries
                       7483d04  say the Exigence build step needs published boundaries

All four working trees are clean.

## The three things worth knowing before you touch anything

**1. A run snapshot is one coordinate, not six.** It names an Artifact revision
and its digest. The revision digest already covers the typed configuration and
the evidence coordinates of every shared resource it pins, so everything is
proved transitively. There is no longer a combination of versions a run can
record that no publication ever produced. If you add an input a run depends on,
it belongs inside the revision or behind a digest-pinned reference — not
alongside the snapshot.

**2. `resourceId:revision:digest` is a three-language contract.** The Platform
API composes it in Dart, Terraform validates it, the TypeScript runtime parses
it into a revision. They disagreed once already: both boundary services
accepted `@` in a boundary id and both parsers reject it, so such a boundary
published cleanly and could never be pinned. Two contract tests now hold the
grammars together —
`citadel_core/platform/server/test/platform_artifact_authority_contract_test.dart`
and `citadel_core/exigence/test/platform_authority_contract.test.ts`. The
patterns are quoted literally in both, deliberately: change one and the test
fails showing you the two spellings. Do not "fix" that by importing a shared
constant none of the three languages can see.

**3. Authority is composed server-side.** A provisioning caller names the
boundaries it means (`access_boundary_id`, `effect_boundary_id`,
`data_handling_boundary_id`, `artifact_identity_id`, each defaulting to
`default`); the API resolves those names to pinned coordinates.
`artifact_authority` is a *resolved* variable — naming it is refused, not
ignored, because a digest from a browser could bind an artifact to a revision
nobody reviewed. Resolution runs again at apply rather than carrying the plan's
answer.

## What is verified, and what is not

Gates, all passing: 556 Exigence unit + 96 Firestore emulator, 212 platform
server (1 emulator-gated), 31 platform API, 291 Console, 173 CLI, 46 Palisade
authority. `terraform validate` passes on the runtime module and on the
provisioning template with its module staged as the image build stages it.

The Console flow was driven in a real browser: three boundary tables render and
fail independently, the rule-line validation blocks and names the offending
line, publishing re-renders only its own table, and revisions increment per
boundary with history kept.

**The HTTP seam is unproven.** The Console's real `HttpPlatformWorkspaceClient`,
the `/access-boundaries` and `/effect-boundaries` routes under a real Firebase
ID token, and a console-driven provisioning build have never run together. The
browser E2E used the seed workspace with an in-memory transport double; the
emulator tests drive real Firestore but not the routes above it. **The deployed
API predates every commit in this session.** Treat "the tests pass" as covering
each layer, not the joins — that distinction is exactly what Phase R cost five
production-fatal defects to learn.

## Added 29/08/26 — platform owners

A configured set of accounts now gets `superdev` on every project, written per
project when the project is claimed (`CITADEL_PLATFORM_OWNERS`, and
`platform_owners` on the runtime module; the production root names the
operator). This resolved the 15/08/26 global-owner question: there is still no
global grant, only a global *rule* that writes an ordinary project-scoped one.

It fires **only on a claim**, so projects that already exist are covered by
`tool/reconcile_platform_owners.dart` instead — which adds only what is
missing, and reports rather than corrects an owner holding less than superdev.
A read-only dry run on 29/08/26 found the operator already holding superdev on
all four live projects (`axis-education`, `citadel-platform`, `demo-sandbox`,
`exigence-lab`), so there is nothing outstanding.

The one thing to watch: a project created but never claimed has no grants for
anyone. The Console claims immediately after creating and is the only creation
path today, so a second one must claim too.

## What to do next, in the order I would do it

1. **Deploy and prove the seam.** Build and deploy the Platform API, publish an
   Access and an Effect Boundary for a real project through the Console as a
   signed-in operator, then drive a provisioning plan and confirm the job's
   variables carry a resolved `artifact_authority`. Until that runs, no client
   can actually be built.

2. **Decide what a Console republication looks like.** `enabled`, schedules,
   webhook secrets and graph inputs are all fields of an immutable revision
   now, so changing any of them means publishing a new one. The Console has no
   flow for that, which is why the artifacts list lost its Enable/Disable
   toggle — I removed it rather than leave a button calling a deleted route.
   This is the largest missing capability.

3. ~~**Feature 4.5's last acceptance item: Manifold Meta WhatsApp.**~~ — built
   29/08/26, see the section below.

## Traps

- ~~`npm run test:firestore-emulator` fails before reaching the tests~~ —
  fixed 29/08/26. firebase-tools 13.35.1 cannot load its own
  `universal-analytics` dependency under this environment's Node 21; the pin is
  now 14.19.0 and `npm run test:firestore-emulator` runs the whole suite (101
  tests). Do not lower the pin. The emulator is on 127.0.0.1:**8187**, not 8080.
- Dart emulator tests must send `Authorization: Bearer owner`. The rules deny
  every browser read and write of the boundary collections, and the emulator
  enforces them; the deployed API reaches Firestore as a service account whose
  credentials bypass rules.
- The provisioning template cannot be validated in place — its
  `source = "./modules/runtime"` is materialised at image build. Stage
  `citadel_core/exigence/infra/modules/runtime` at `modules/runtime` first.
- Publishing a boundary is the only way to change one. There is no update path
  and there should not be one.


## Added 30/08/26 — Manifold WhatsApp is feature-complete in code

Feature 7.1's definition of done is met except for the one item that needs
Meta. 653 Exigence unit tests, 110 integration tests, 312 Console tests, 235
platform server tests, 46 Palisade tests. Four repos clean.

| Definition of done | State |
| --- | --- |
| A WhatsApp connector ingests, threads and replies through the project inbox | Done |
| Duplicate and out-of-order provider events are proven safe | Done |
| Message bodies and attachments never cross client boundaries | Done |
| Consent/opt-out and delivery failures are enforced and visible | Done |
| Provider sandbox/live integration tests and browser inbox E2E pass | Browser E2E done; **live blocked** |

What exists: the channel record and its publication (Console form included),
the Meta send connector, webhook verification and receipt, the public webhook
endpoint, consent and opt-out, conversation threading, delivery state,
attachment collection into the client's bucket, the Console inbox, and human
replies from it.

### Where the next agent picks up

**1. Nothing is composed into a running runtime.** Every piece above is built
and unit-tested in isolation; `runtime_composition.ts` wires none of it. That
is the single largest remaining gap and it is blocked behind the Exigence
runtime deploy, which needs an Artifact revision published for `demo-project`
first. Do that before anything else in Manifold — until it is done, none of
this has ever run as a whole.

**2. The webhook is not mounted.** `createTaskReceiverHttpServer` takes an
optional `webhook` handler and nothing passes one. Serving it means the Cloud
Run service accepts unauthenticated requests, which is Sid's decision, not a
wiring detail. Ask before switching it on.

**3. Live validation needs Meta.** A WABA id, a phone number id, three Secret
Manager version paths (access token, verify token, **app secret** — the app
secret signs deliveries and is not the verify token) and a test recipient. Sid
is setting up the Business Account.

**4. Feature 7.1's remaining task text**, beyond the definition of done:
assignment, internal notes and drafts (Task 7.1.4), and settling retention and
data-classification choices (Task 7.1.2) before production use. Neither is a
DoD item; both are real product gaps.

**5. Feature 7.2** — Manifold Console and cross-service resolution — is
untouched and depends on this plus ARM, Conduit, Exigence, Baker and Palisade.

### Traps specific to this work

- **Phone numbers are E.164 with the leading `+`, everywhere.** The webhook
  normalises Meta's bare `6591234567` to `+6591234567`, and the connector,
  consent ledger and conversation store all expect that form. This already
  broke once and every unit test passed while it was broken, because each
  fixture spelled it the way its own component wanted.
  `whatsapp_receive_path.test.ts` exists to catch it: it drives a real Meta
  payload end to end and its fakes run the real validators. **Do not add a
  fake to that file that skips validation** — that is precisely what let the
  bug through.
- **The delivery-status lookup is a collection-group query** and needs the
  index in `exigence/infra/modules/runtime/main.tf`. Without it every message
  stays at `sent` for ever, which looks like a working channel.
- The channel record's third secret is `webhookSigningSecret`, Meta's *app
  secret*. The verify token is used once, at subscription time, and proves
  nothing about a delivery.
