30/08/26 — Exigence 4.5.6: an artifact can actually send through Manifold

- PASS exigence `npm run check`, 593 unit (was 592), 119 emulator

FOUND, and it is the same shape as the 30/08 webhook gap: the channel tool and
the WhatsApp connector were both built and unit-tested, `lateBoundWhatsAppChannel`
existed for exactly this purpose, and **nothing composed them together**.
`bindChannelSend` / `ChannelSendExecutor` appear nowhere in the runtime, so an
artifact could not reply to a customer at all. 04-05's last open item.

`composeManifold` now returns `toolChannelsFor(runId)`. A factory rather than a
map because `threadRecordingChannel` has to record *which run* said it, and the
run is not known when the runtime is composed — that attribution is the
thread's evidentiary value, since "why did we tell them that" has to lead to a
run, its artifact revision, and the approval that let it send.

The composed chain is consent gate → thread recorder → resolved channel, built
at the moment of sending because a channel's configuration is a published
revision an operator can disable or repoint between two messages.

DEDUPLICATED: the human reply path was building that same chain inline. Both
now go through one `composedChannel`, differing only in whether the message is
attributed to a person or a run. Two copies is how one of them quietly stops
passing the consent gate.

ADDED `whatsAppChannelId` in TypeScript, restating one value from the Dart
catalogue across a language boundary because the runtime cannot read it.
Pinned by `manifold_tool_channel.test.ts`, **verified by deliberate breakage** —
changing the Dart mapping to `'wa'` fails the test; restored.

CLOSED the gap this entry first reported. Two composition tests in
`manifold_composition.test.ts` drive `composeManifold` and send through the
channel an artifact would actually use: the message reaches the connector,
lands in the thread attributed to `run-8f21` with no `sentBy`, and a
consent-refused recipient is not sent to at all. 595 unit tests (was 593).

- STILL INHERITED: the *policy* gate itself. The channel tool declares
  `external_comms` requiring `exigence.communications.send` and `policy.ts`
  refuses a tool the artifact has not declared or the project has not enabled;
  both are tested in `channel_tool_binding.test.ts` against the generic tool.
  What these new tests prove is the composition — that the channel an artifact
  is handed is consent-gated and thread-recording — not the LangGraph binding
  around it.

30/08/26 — Palisade Watchdog 6.2.1: authorization anomaly detection

- PASS platform/server `dart analyze`, 310 tests (was 302)

`palisade_watchdog.dart` reads the audit built earlier today and finds
principals being refused more than ordinarily. Denials are ordinary — a console
asking whether a button should be shown and being told no is the permission
system working — so a detector that fired on them would be turned off.

Two shapes told apart, and this is the substance of the detector:

- **`persistentRefusal`** — one permission refused repeatedly. Something was
  deployed expecting authority nobody granted and will fail identically
  forever. Worth fixing, not worth waking somebody.
- **`probing`** — several *distinct* permissions refused. Something looking for
  what it can reach.

Reporting both as "N denials" buries the second in the first, because
misconfigurations produce far larger numbers than probing does. Tested with 40
denials of one permission ranking below 3 denials of three different ones.

Agents are held to a lower threshold (3 vs 5) and sort first. That is the
feature's stated purpose: an artifact is autonomous, so nobody watches it be
refused, and it does not mistype a URL or click the wrong tab. Ordering is the
alert — an operator reads the top of the list and nothing else, so the artifact
nobody is watching sits above the human who keeps opening a page they cannot
see, regardless of volume.

`agentIdentityIds` is passed in rather than inferred from the id. Inferring
from a naming convention would stop working the day somebody named an agent
differently, and the failure would be a missing alert rather than a visible
error.

Rows the build cannot read are skipped, not guessed at: the audit is
append-only and grows as products are added, and a detector inventing a denial
from an unreadable row would raise an alarm about nothing.

- NOT DONE: nothing calls it. No route, no schedule, no alert delivery — 6.2.1
  also wants aggregation surfaced, and 6.2.5 says breaches route through ARM
  alerting rather than a new channel. Tasks 6.2.2, 6.2.3 and 6.2.4 untouched.

30/08/26 — Palisade 6.1.1 identity routes, and DoD 1 as far as an API goes

- PASS platform/server `dart analyze`, 302 tests (was 296)
- PASS palisade/authority 48, citadel_platform `flutter analyze`

Added `platform.identities.manage` as a **tenant capability**, not a project
permission. An identity exists once and is granted into projects, so scoping
its creation to a project would let whoever administers one project mint
principals another project's grants could then name.

Routes: `POST /v1/identities`, `PATCH /v1/identities/{id}`,
`GET /v1/identities/{id}`. Wired in `bin/citadel_platform_api.dart`.

Pinned by test:
- Registration answers with the principal **disabled**.
- An unknown `type` is refused, not defaulted — defaulting would register a
  principal as something nobody asked for, and the type is what an operator
  reads to know what they are looking at.
- The response carries no `password`, `secret`, `token` or `apiKey`. None are
  held: Firebase Auth proves who a principal is, Palisade records what they may
  do, and a field here would mean the registry had started keeping credentials.
- Without the tenant capability, nothing is written.
- An unauthenticated caller reaches no identity route.

DoD 1 is now served by an API. No Console surface, so an operator still cannot
do it from a screen, and credential lifecycle remains undecided — Firebase Auth
owns credentials and what that leaves Palisade to manage has never been
settled.

30/08/26 — Palisade 6.1.1: identity registration and disabling

- PASS platform/server `dart analyze`, 296 tests (was 289)

`PlatformIdentityService` on the existing `palisade_identities` collection.
All five types register in one registry — the point of 6.1.1 is that an
artifact's authority is inspectable where a person's is, and a separate store
for agents would make "what can this thing do" a different question depending
on what the thing was. Tested across every `IdentityType`.

Three refusals worth stating:

- **A new principal is created disabled.** One that could act the instant it
  was registered would be usable in the window before anybody decided what it
  may do. Register, grant, then enable.
- **Registering over an existing id is refused, not upserted.** The id is what
  grants and audit entries name; rewriting one would repoint every grant held
  against it and every past entry describing it, with nothing recording that
  the principal had changed.
- **There is no delete.** Authority is audited, and an identity removed from
  the registry leaves audit entries naming a principal nobody can look up.
  Disabling withholds every permission — proven here against
  `resolveEffectiveAuthority`, which returns no permissions and no boundaries
  for a disabled identity — while keeping the record readable.

- NOT DONE: no routes and no Console surface, so DoD 1's "manageable" is
  currently manageable by a service and not by an operator. Credential
  lifecycle (6.1.1's third bullet) is untouched — Firebase Auth owns
  credentials and what that leaves Palisade to manage is undecided.

30/08/26 — Palisade 6.1 DoD status, verified item by item

- PASS citadel_core/localbridge — 54 tests, after re-running `sync:boundary`

DoD 7 and 8 were already satisfied and are now confirmed rather than assumed:

- **DoD 8 (the local runner enforces boundaries independently).** The runner
  has the boundary engine as a *generated copy* — `localbridge/src/boundary.ts`
  is synced from `palisade/boundary/src/boundary.ts` by `tool/sync-boundary.mjs`
  on `prebuild`. Re-ran the sync: byte-identical, no drift. The same tool syncs
  `catalogue.ts`, so today's new permissions (`exigence.context.read`,
  `platform.audit.read`) reached the runner and its 54 tests still pass.
- **DoD 7 (ARM resolves project roles from Palisade).** No `platform_access` or
  project-role model remains anywhere in `citadel_core/arm`. ARM's routes are
  proxy operations mapped to `arm.issues.*` / `arm.cases.*` in the permission
  map, so its authorization already resolves through Palisade with nothing of
  its own left to migrate.
- **DoD 5** is served by `/v1/projects/{p}/principals/{id}/authority`.

Feature 6.1 now stands at: DoD 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 (Manifold half),
12 done. Outstanding:

- **DoD 1** — identity CRUD. The five types exist and resolve; creating,
  disabling and credential lifecycle do not. Largest remaining piece.
- **DoD 11**, data-relay half — Manifold permissions resolve and fail closed;
  data-relay ones are catalogued but nothing exercises them.
- **DoD 13** — adversarial integration/E2E gates. Unit-level adversarial
  coverage is genuinely good (traversal, symlink escape, host lookalikes,
  scheme rejection, malformed patterns, cross-project ids); what is missing is
  the integrated and live/sandbox runs the task explicitly says unit vectors
  cannot replace.
- **06-02 Watchdog** — entirely untouched, 10 DoD items.

30/08/26 — Palisade DoD 12 complete: the audit has a Console view

- PASS citadel_platform `flutter analyze`, 331 tests (was 326)

`PlatformAuditPage` at `/audit`, behind `platform.audit.read`. One view for
both authorization outcomes and data flows, because they answer one question
and two timelines get correlated by hand.

Rows render from untyped maps rather than a decoded model. The audit is
append-only and its shape grows as products are added; a row this build did
not anticipate would otherwise vanish from the one view that is supposed to
show everything. Tested with a data-flow-shaped row carrying neither
`permission` nor `allowed` — it still appears.

Both outcomes are listed, and only a denial is coloured: a view that
highlighted every allowed request would leave nothing to notice.

An empty table reads as a quiet project, which is only safe to say because an
unwired store answers 503 at the API and lands in the failure branch instead.

- STILL OPEN in 6.1: identity CRUD (DoD 1), ARM resolving project roles from
  Palisade (DoD 7), the local runner enforcing boundaries independently
  (DoD 8), and adversarial integration/E2E gates (DoD 13). The data-flow audit
  has no adapter onto the store — `auditedFlow` writes to its own sink
  interface and nothing bridges TypeScript runtime to control-plane storage.
  That bridge is deliberately not built yet: the correlation source does not
  exist, so it would be a pipe with nothing flowing through it.
- 06-02 Palisade Watchdog is entirely untouched.

30/08/26 — Palisade 6.1 DoD 12: the audit has somewhere to land, and a route

- PASS platform/server `dart analyze`, 289 tests (was 286)
- PASS palisade/authority 48, platform/api 31, exigence 592

FOUND: no audit storage existed anywhere. `AuditEvent` is modelled and the
Console has a `recentAuditEvents` field, and nothing has ever written or read
one — `platform_firestore.dart:710` hardcodes it empty. So DoD 9's records had
nowhere to go and DoD 12 had nothing to show.

BUILT `PlatformAuditStore` (`platform_audit_store.dart`), one collection for
both authorization outcomes and cross-product data flows. One rather than two,
because they answer one question — what happened, who did it, were they
entitled — and two timelines correlated by hand is how the link between "was
allowed to read the sessions" and "read the sessions" gets lost.

In the **control plane**, which inverts the usual rule and does so on purpose.
Conversations live in the client's data plane because they are the client's
customers' words; an audit of Citadel's operators acting on a client's project
is Citadel's record of its own conduct, and putting it where the client runtime
can write would let a compromised runtime edit the log of what it did.

Document ids are `audit-<millis>-<counter>` so id order is creation order and
the listing is servable by the single-field index Firestore keeps for every
field. Ordering by `createdAt` would need a composite index, and indexes here
are Terraform's — a console fix would have become an infrastructure change that
silently returns nothing until applied.

ADDED `platform.audit.read`, superdev-only. The record is mostly Citadel
operators acting on a client's project, and handing a client the log of which
operator was refused what would show them the shape of Citadel's own access
controls. A client-facing view of their own data flows is a reasonable thing to
want later and is a different, smaller record.

ADDED `GET /v1/projects/{id}/audit`, served in the control plane and never
proxied. An unwired store answers **503, not an empty list**: "no activity" and
"no audit store" are different answers and only one means the project is quiet.
Tested.

WIRED in `bin/citadel_platform_api.dart`, so the sink and the reader are both
live rather than accepted-and-ignored.

- NOT DONE: no Console view yet, so DoD 12 is served by the API and not by a
  screen. The data-flow audit from earlier today still has no adapter onto this
  store — `auditedFlow` writes to its own sink interface and nothing bridges
  the two.

30/08/26 — Palisade 6.1 DoD 9: every authorization outcome is audited

- PASS platform/server `dart analyze`, 286 tests (was 281)

Added `PlatformAuthorizationRecord` and an optional
`authorizationAudit` sink on the proxy handler, threaded through all 38
`_proxyProductRequest` call sites. Both outcomes are recorded, not just
denials: an audit of refusals answers "who was stopped" and leaves "who was
let in", and the damaging access is almost always one that succeeded.

Recorded at the request seam rather than inside `_canAccessProject`, which is
a pure predicate on a hot path. One request that checks three permissions
produced one authorization outcome; three entries would describe an event that
did not happen three times. Tested.

The record carries coordinates and the decision — operation, project, actor,
required permission, allow/deny — and never the request body. A test posts a
card number in a reply body and asserts it never reaches the record.

A failing sink never changes an outcome. The decision was made on authority
that resolved correctly, so refusing because the *recording* failed would deny
a caller for a fault that is not theirs, and an audit is not permitted to
invent denials. Tested.

- NOT DONE: no sink implementation. The handler accepts one and the production
  entrypoint does not pass it, so nothing is written yet — DoD 12 (one audit
  view) still needs storage plus the Console surface, shared with the
  data-flow audit built earlier today.

30/08/26 — Palisade 6.1 DoD 4 and 10, and the Manifold browser E2E completed

- PASS palisade/authority `dart analyze`, 48 tests (was 46)
- PASS platform/server `dart analyze`, 281 tests (was 275)
- PASS platform/api 31, citadel_platform `flutter analyze`

DoD 4 — roles bundle boundaries. `Role` gained `boundaries`, carried opaquely
the way `Grant.boundaries` are. A role's boundaries are *added* to a grant's
rather than replacing them: boundary evaluation is most-restrictive-wins, so
adding can only narrow, and letting a role override a grant would let a role
widen reach, which is backwards. `resolveEffectiveAuthority` gained an optional
`roleLookup` so a project can define its own named roles (6.1.3) instead of
only the shipped three. A disabled identity resolves to no boundaries at all,
so a consumer reading the list without checking `active` cannot be handed
reach.

DoD 10 — deny-by-default when Palisade is unreachable, now proven by test
(`palisade_fail_closed_test.dart`). The behaviour was already correct; nothing
asserted it.

CAUGHT IN MY OWN TEST, worth recording: the first version asserted only "not
2xx", which every route satisfies by answering "not configured" long before it
resolves any authority — so the file would have passed without once reaching
the seam it exists to guard. It now asserts 503 *and* that the body names
Palisade, which is what proves the request got as far as needing an authority
and was refused for lacking one. Coverage is the families reachable without
standing up a product service: workspace, and all three provisioning routes,
the last deliberately because a read failing open shows something that is not
there while a write failing open changes something. The store and launcher
`fail()` if touched.

BROWSER E2E COMPLETE for the Manifold inbox, and the earlier note here was
wrong. An internal note was filed in a real browser: it appears under
"Internal — Not sent to the customer", attributed and timestamped, below the
reply box and nowhere near the thread.

ROOT CAUSE of the harness trouble: navigating a *freshly created* tab straight
to the Flutter Console destroys the canvas — title changes, then every action
times out and the tab group disappears. Navigating an *already-warm* tab to the
same URL works. Proved by elimination: not the extension (survived a restart),
not window size, not a stale service worker (a clean origin failed
identically), not the server, and not tabs generally (example.com in a new tab
screenshots first try). Warm the tab on a trivial page first.

Consequently the previous entry's claim that "the Flutter canvas answers
neither wheel scroll nor Page Down" was false — scrolling works fine once the
tab is healthy. That is what had made the notes section unreachable.

30/08/26 — Palisade 6.1.5: the data-flow capability and audit

- PASS `citadel_core/palisade/authority` — `dart analyze`, 46 tests, catalogue
  regenerated (both `catalogue.json` and the TypeScript export)
- PASS `citadel_core/palisade/boundary` — `tsc --noEmit`, 26 tests (was 18)
- PASS `citadel_core/exigence` — `npm run check`, 592 unit
- PASS `citadel_core/platform/api` 31, `citadel_core/platform/server` 275

RESOLVED, and it was the Manifold blocker: added `exigence.context.read` as a
sixth agent capability, with a `context` tool scope. Reading another product's
record of a client's *end users* is now separable from reading the client's own
documents. The subjects differ — a handbook is the client's material, a session
replay is personal data about somebody who never dealt with Citadel — and one
capability for both made "may read our handbook, may not read our customers'
replays" inexpressible. Cataloguing Manifold and data-relay permissions is
Task 6.1.5's own first bullet, so this sits inside the feature rather than
beside it.

DELIBERATE EDIT to `catalogue_export_test.dart`: `context.read` joins
`tools.read` as a capability that does not hold for approval. The test existed
to force exactly this edit rather than allow a silent one.
`approvalRequiredCapabilities` means "effects the platform cannot safely
reverse", and a read has no effect to reverse; that this read is more sensitive
makes it the Data Handling Boundary's question, which carries its own approval
policy per data class, source and destination.

BUILT: `data_flow_audit.ts` in `palisade/boundary`. Every entry names the
actor, direction, data class, resolved capability, grant path and outcome, and
**never the data**. Enforced rather than left to callers: a reason longer than
512 characters is refused rather than truncated, a refused flow cannot claim a
record count, a denial with no reason is refused, and a failed read records the
error's *name* — a provider's message can carry the query it failed on, and the
query is made of the data. `auditedFlow` wraps the read so recording is a
property of the seam and not of whoever adds the next one.

The sink deliberately fails silently, opposite to the consent gate: consent
decides whether an effect may happen, this describes one that already has, and
throwing would report a failure while leaving the read done.

- NOT DONE: no sink implementation and no Console view. The audit records
  nowhere yet, so DoD item 12 ("every cross-product data flow visible in one
  audit view") is unmet. `auditedFlow` is unused until the correlation source
  exists, which needs ARM/Conduit transport for the runtime.
- STILL OPEN in 6.1: roles bundle permissions but not boundaries (DoD 4);
  fail-closed-when-Palisade-unreachable (DoD 10) is unverified; adversarial
  E2E gates (DoD 13) are not written.

30/08/26 — Manifold 7.2.1 correlation engine

- PASS `cd citadel_core/exigence && npm run check`
- PASS `npm test` — 592 unit (was 579; +13 correlation)

BUILT: `correlation.ts` proposes what a customer's report is about, from ARM
issues and Conduit sessions in a window taken backwards from when they wrote
in. It proposes and never asserts — Citadel does not know who the person
messaging on WhatsApp is in Conduit's session data, and cross-channel identity
resolution is deferred by 7.2.1. Every candidate carries checkable reasons;
several are returned whenever the evidence does not separate them; and
`ambiguous` is stated rather than inferred from the count, because a list of
one is the case most likely to be read as an identification.

A test asserts a result never contains "matched", "identified", "this
customer" or "belongs to". An agent reading those words acts as though the
question is settled.

ASSESSED, NOT BUILT: 7.2.2 governed response is already satisfied by existing
architecture — human and artifact replies share one channel with the consent
gate inside the thread recorder, the channel tool declares `external_comms`
requiring `exigence.communications.send`, and `langgraph_tool_binding.ts`
already raises approval holds. Nothing to add; worth a test rather than code.

BLOCKED, decision needed: the correlation source and tool binding cannot be
written until it is settled which capability lets an artifact read ARM and
Conduit. `agentCapabilities` is a closed set of five, so the tool would default
to `exigence.tools.read` — the same capability that searches the client's own
documents. Reading a client's handbook and reading their end users' session
replays are different sensitivities with different subjects. See
`DECISIONS_NEEDED.md` 30/08/26.

BLOCKED, operator: live WhatsApp validation is deferred at the operator's
direction — Meta Developer account creation is blocked, so no sandbox WABA
exists. Nothing in Manifold has run against Meta.

30/08/26 — the receiver's grant: reported, and repaired through Terraform

- PASS `citadel_core/platform/api` — `dart analyze`, 31 tests
- PASS `citadel_core/platform/contracts` — `dart analyze`, 4 tests
- PASS `citadel_core/platform/server` — `dart analyze`, 275 tests (was 259;
  +10 grant checks, +6 repair route)
- PASS `citadel_core/platform/provisioner` — `dart analyze`, 10 tests
- PASS `citadel_core/palisade/authority` — `dart analyze`, 46 tests
- PASS `citadel_platform` — `flutter analyze`, 326 tests (was 321)
- PASS `terraform validate` on `citadel_core/exigence/infra/modules/runtime`

VERIFIED BY DELIBERATE BREAKAGE: `manifoldSecretProjectId` restates
`host_project_id`'s default from the exigence-runtime template. Changing the
template to `citadel-elsewhere` fails
`manifold_receiver_grant_test.dart` — "the host project this checks against is
the one Terraform grants in" — showing both spellings. Template restored.

DECIDED, and recorded in `DECISIONS.md` 30/08/26: `Resolve` raises a
provisioning plan rather than writing the IAM binding. The module uses
`google_secret_manager_secret_iam_member`, which is non-authoritative, so a
direct binding would in fact survive an apply — but it would be invisible to
the configuration, and the grant would work today and vanish the next time the
project was built from scratch.

TWO PREREQUISITES this exposed, both now built:
- The receiver's identity was a Terraform *output*, and outputs are not
  persisted. It is now recorded on the project beside the runtime URL.
- `ProvisioningJob` recorded no variables, so a repair composing a request from
  scratch would have reset every optional variable it did not restate —
  `name_prefix`, `environment`, `manifold_media_retention_days`, the boundary
  ids. The caller-supplied request is now recorded on the job.

- NOT COVERED: no browser E2E for the Resolve panel. It is widget-tested —
  that the effects are named before the button is offered, that `unknown`
  offers no repair, that a granted project shows nothing, that resolving says
  plainly nothing was applied, and that somebody who cannot plan is not shown
  the control.
- NOT COVERED: the repair has never raised a real plan. The route is tested
  against a fake launcher; no Terraform has run.
- MIGRATION, and it will look like a bug: projects provisioned before today
  have no recorded request and no recorded receiver. Their panel reads
  "unknown" and offers no repair until they are provisioned once more. That is
  deliberate — the alternative was a plan built on defaults.

30/08/26 — Manifold 7.1.4: assignment, internal notes and drafts

- PASS `cd citadel_core/exigence && npm run check`
- PASS `npm test` — 579 unit (was 568; +11 route-contract tests for the
  workspace endpoints)
- PASS `npm run test:firestore-emulator` — 119 (was 110; +9 for the workspace
  store), run three times consecutively clean
- PASS `cd citadel_core/platform/server && dart analyze` and `dart test` — 259
  (was 256)
- PASS `cd citadel_core/palisade/authority && dart analyze` and `dart test` — 46;
  `dart run tool/export_catalogue.dart` regenerated for the new permission
- PASS `cd citadel_platform && flutter analyze` and `flutter test` — 321
  (was 314)

FIXED, and it was a pre-existing flake my new file made likely: both Manifold
integration test files swept the whole `manifold_conversations` collection on
teardown. Node runs test files in parallel against one emulator, so a sweep
deleted the other file's fixtures mid-test and failed whichever test was
unlucky, nowhere near the cause. Both cleanups are now scoped to their own
projectId.

DECIDED: `platform.manifold.conversations.manage` gates assignment, notes and
drafts — reading included. A client reading their own inbox is reading their
customers' words, which are theirs; an internal note is what one operator told
another about that customer. Superdev-only for now, because there is no role
for the people who would hold it and both viewer and invoker are defined as
changing nothing.

## Browser E2E — the inbox, driven in Chrome

`flutter build web -t lib/main_dev.dart` served with an SPA fallback on
**127.0.0.1:8793**, not 8792: the operator's own `flutter run` held 8792 for the
duration and killing it would have taken their session with it.

- PASS The inbox lists an `Assigned` column, and a thread nobody holds reads
  "Nobody" rather than an empty cell.
- PASS Claiming a thread: `Unassigned` / "Assign to me" becomes `Yours` /
  "Release", and the listing shows the assignee.
- PASS A draft saved from the reply box survives closing and re-opening the
  panel, restored into the field.

- FOUND AND FIXED, and only a browser could have shown it: the open thread was
  held as a *copy* of the conversation taken when the row was tapped. Claiming
  refreshed the table and left the panel still offering "Assign to me", so the
  next click would have sent `expectedAssignee: null` against a thread the
  operator already held, and been refused. The panel now resolves the open
  thread out of the listing on every build. Regression test:
  `platform_manifold_inbox_test.dart` — "the open panel follows the listing
  rather than a snapshot".

- NOT PROVEN IN A BROWSER: the internal notes section. It renders below the
  fold, and the Flutter canvas answered neither wheel scroll nor Page Down;
  resizing the window did not change the captured viewport either. Notes are
  covered by widget tests only — that the section is hidden without
  `manage`, that a note reaches the runtime with the actor from the header,
  and that the note control is not the send control.

- STILL UNPROVEN, unchanged by this work: the HTTP seam. No part of Manifold
  has run outside a test. The deployed Platform API predates all of it, the
  Exigence runtime has never been deployed with any of it, and live Meta
  validation still needs a WABA, a phone number id, three Secret Manager
  versions and a test recipient.

08/06/26 12:45
- PASS `cd arm/tooling && flutter pub get`
- PASS `cd arm/tooling && flutter analyze`
- PASS `cd arm/console && flutter pub get`
- PASS `cd arm/console && flutter analyze`
- NOT RUN: `flutter analyze` for `citadel_platform`; no code changes were made to the site app in this task.
- NOT RUN: Terraform validation; no Terraform files exist in the active CitadelPlatform scaffold yet.

08/06/26 12:45
- PASS `cd citadel_platform && flutter pub get`
- PASS `cd citadel_platform && dart run build_runner build`
- PASS `cd citadel_platform && flutter test`
- PASS `cd citadel_platform && flutter analyze`
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

08/06/26 13:05
- NOT RUN: `flutter analyze` for ARM packages; only Firebase alias, docs, and tracked sample config were updated.
- NOT RUN: Firebase app config generation; the active environment can target GCP project `citadel-platform`, but authoritative Firebase web-app credentials were not retrievable here.

08/06/26 13:46
- PASS `cd citadel_core/platform/contracts && dart pub get`
- PASS `cd citadel_core/platform/contracts && dart run build_runner build`
- PASS `cd citadel_core/platform/contracts && dart test`
- PASS `cd citadel_core/platform/contracts && dart analyze`
- PASS `cd citadel_platform && flutter pub get`
- PASS `cd citadel_platform && flutter test`
- PASS `cd citadel_platform && flutter analyze`
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

08/06/26 14:02
- PASS `cd citadel_core/platform/api && dart pub get`
- PASS `cd citadel_core/platform/api && dart run build_runner build`
- PASS `cd citadel_core/platform/api && dart test`
- PASS `cd citadel_core/platform/api && dart analyze`
- PASS `cd citadel_cli && dart pub get`
- PASS `cd citadel_cli && dart test`
- PASS `cd citadel_cli && dart analyze`
- PASS `cd citadel_cli && dart run bin/citadel_cli.dart validate registry`
- NOT RUN: Terraform validation; `terraform` CLI is not installed in the current environment, so Feature 0.3 cannot yet satisfy the required validation gate.

08/06/26 16:01
- PASS `cd citadel_core/platform/api && dart run build_runner build`
- PASS `cd citadel_core/platform/api && dart test`
- PASS `cd citadel_core/platform/api && dart analyze`
- PASS `cd citadel_cli && dart test`
- PASS `cd citadel_cli && dart analyze`
- PASS `cd citadel_cli && dart run bin/citadel_cli.dart validate protocols`
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

08/06/26 16:20
- PASS `cd citadel_core/arm/tooling && flutter pub get`
- PASS `cd citadel_core/arm/tooling && flutter analyze`
- PASS `cd citadel_core/arm/tooling && flutter test`
- PASS `cd citadel_core/arm/console && flutter pub get`
- PASS `cd citadel_core/arm/console && flutter test`
- PASS `cd citadel_core/arm/console && flutter analyze`
- PASS `cd citadel_core/platform/api && dart pub get`
- PASS `cd citadel_core/platform/api && dart test`
- PASS `cd citadel_core/platform/api && dart analyze`
- PASS `cd citadel_cli && dart test`
- PASS `cd citadel_cli && dart analyze`
- PASS `cd citadel_cli && dart run bin/citadel_cli.dart validate registry`
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

08/06/26 17:27
- PASS `cd citadel_platform && flutter pub get`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

09/06/26 08:25
- PASS `cd citadel_platform && flutter pub get`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- PASS browser verification against `flutter run -d web-server --web-port 7357` for `/dashboard` and `/arm/console?project=core-platform`
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

09/06/26 09:46
- PASS `cd citadel_platform && dart format lib/src/app/platform_arm_pages.dart`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- PASS browser verification against `flutter run -d web-server --web-port 7357` for `/arm/monitoring?project=core-platform`, `/arm/escalations?project=core-platform`, `/arm/issues?project=core-platform`, `/arm/issues/issue-save-draft-timeout?project=core-platform`, and `/arm/cases?project=core-platform`
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

09/06/26 12:33
- PASS `cd citadel_platform && flutter pub get`
- PASS `cd citadel_platform && dart format lib/main.dart lib/src/app/citadel_platform_app.dart lib/src/app/platform_arm_pages.dart lib/src/app/platform_pages.dart lib/src/app/platform_shell.dart lib/src/app/platform_state.dart lib/src/design_system/citadel_primitives.dart lib/src/design_system/citadel_shell.dart lib/src/design_system/citadel_theme.dart lib/src/app/platform_firestore.dart lib/src/app/platform_project_admin.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- PASS `cd citadel_core && npx -y firebase-tools@latest deploy --only firestore:rules --project citadel-platform`
- PASS `cd citadel_core && npx -y firebase-tools@latest deploy --only auth --project citadel-platform`
- PASS `flutter run -d chrome` startup smoke for `citadel_platform` after the runtime zone fix; no startup zone mismatch remained
- PASS platform registry bootstrap for `platform_tenants/tenant-citadel`, `platform_projects/core-platform`, and `platform_access/obsidian.infinitum@gmail.com` in Firestore
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

09/06/26 14:21
- PASS `cd citadel_platform && dart format lib/firebase_options.dart lib/src/app/citadel_platform_app.dart lib/src/app/platform_firestore.dart test/platform_firestore_test.dart`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- PASS `cd citadel_platform && flutter run -d chrome` startup smoke with live Firebase dart-defines after making Firestore emulator usage opt-in
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

09/06/26 14:30
- PASS `cd citadel_platform && chmod +x scripts/flutter_with_platform_env.sh`
- PASS `cd citadel_platform && bash -n scripts/flutter_with_platform_env.sh`
- PASS `cd citadel_platform && bash scripts/flutter_with_platform_env.sh --help`
- NOT RUN: Flutter analyzer/tests; only the local run helper script and README usage docs changed in this pass.
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

09/06/26 15:19
- PASS `cd citadel_platform && dart format lib/src/app/platform_firestore.dart lib/src/app/platform_pages.dart lib/src/app/platform_project_admin.dart lib/src/app/platform_project_onboarding.dart lib/src/app/platform_shell.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; local chrome-devtools transport is still unavailable in this environment, so the onboarding UI change was validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

15/06/26 15:37
- PASS `cd citadel_platform && dart format lib/src/app/platform_arm_pages.dart lib/src/app/platform_shell.dart lib/src/app/platform_pages.dart lib/src/app/citadel_platform_app.dart lib/src/design_system/citadel_shell.dart lib/src/design_system/citadel_primitives.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the Browser plugin runtime exposed only page listing/selection in this environment and did not expose the required in-app browser control path for localhost verification.
- NOT RUN: Terraform validation; Terraform-dependent features remain intentionally deferred.

16/06/26 10:13
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter pub get`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart run build_runner build`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test`
- NOT RUN: Browser automation; this pass validated the embedded SDK through unit tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 10:46
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter pub get`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test`
- NOT RUN: Browser automation; the browser-runtime additions were validated through unit tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 11:10
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart format lib/src/runtime/conduit_browser_bindings_factory_web.dart lib/src/conduit_sdk.dart test/src/conduit_sdk_test.dart`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test`
- NOT RUN: Browser automation; the runtime interception patch was validated through unit tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 11:22
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart run build_runner build`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test`
- NOT RUN: Browser automation; the new attention config and SDK attention API coverage were validated through unit tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 13:04
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test`
- NOT RUN: Browser automation; the attention wrapper and browser-side compression path were validated through widget/unit tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 13:10
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart pub get`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart run build_runner build --delete-conflicting-outputs`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format bin lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test`
- NOT RUN: Browser automation; this task added a pure-Dart ingest service package with HTTP handler/unit coverage only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 13:59
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart run build_runner build --delete-conflicting-outputs`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the Conduit platform pages and feedback widget were validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 14:07
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart run build_runner build`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the poll trigger engine and aligned Conduit platform surfaces were validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 14:12
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart run build_runner build`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the survey widget, branching flow, and aligned Conduit platform surfaces were validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 15:08
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart run build_runner build`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the replay/heatmap capture foundation and aligned Conduit platform surfaces were validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 15:59
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart run build_runner build --delete-conflicting-outputs`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format bin lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test`

25/06/26 08:03
- NOT RUN: `flutter analyze` for `citadel_core/arm/tooling`; this pass only clarified package docs and package-local development instructions for raw ARM error capture semantics.

17/06/26 13:32
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the Conduit analytics dashboard and heatmap
  deep-link flow were validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.
- PASS `cd citadel_platform && dart format lib/src/app/platform_firestore.dart lib/src/app/platform_project_onboarding.dart lib/src/app/platform_conduit_repository.dart lib/src/app/platform_conduit_pages.dart lib/src/app/citadel_platform_app.dart lib/src/app/platform_shell.dart`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the shared target Firebase registry refactor and live Conduit repository path were validated through static analysis and automated tests only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the replay/heatmap console shell changes were validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 16:22
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart run build_runner build --delete-conflicting-outputs`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the replay retrieval, curation, and heatmap query console updates were validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

16/06/26 16:44
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart pub get`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart run build_runner build --delete-conflicting-outputs`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`

- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test`
- PASS `cd citadel_platform && flutter pub get`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the new replay player and heatmap renderer surfaces were validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/06/26 14:01
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the repository-backed Conduit Experience Monitoring dashboard was validated through widget tests and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.


17/06/26 14:59
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart run build_runner build --delete-conflicting-outputs`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the grouped-error replay handoff plus Conduit experience settings panels were validated through repository, unit, and widget coverage only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/06/26 15:10
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart run build_runner build --delete-conflicting-outputs`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test`
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- PASS `npx -y firebase-tools@latest firestore:databases:list --project citadel-platform` verified the platform Firestore instance remains the standard native `(default)` database before extending alerting control collections.
- NOT RUN: Browser automation; the new `/conduit/alerts` surface was validated through repository, unit, and widget coverage only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

26/06/26 11:24
- PASS `cd citadel_platform && dart format lib/src/app/citadel_platform_app.dart lib/src/app/platform_arm_pages.dart lib/src/app/platform_arm_status.dart lib/src/app/platform_firestore.dart lib/src/app/platform_state.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test`
- NOT RUN: Browser automation; the ARM timeline/status/payload UI changes were validated through widget coverage and static analysis only.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

26/06/26 11:44
- PASS `cd citadel_core/arm/tooling && dart format lib/src/arm_client.dart test/src/arm_client_test.dart`
- PASS `cd citadel_core/arm/tooling && flutter analyze`
- PASS `cd citadel_core/arm/tooling && flutter test`
- NOT RUN: Browser automation; this pass only changed ARM SDK session-context capture behavior, unit coverage, and docs.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

26/06/26 12:17
- PASS `cd citadel_core/arm/tooling_core && dart pub get`
- PASS `cd citadel_core/arm/tooling_core && dart analyze`
- PASS `cd citadel_core/arm/tooling_core && dart test`
- PASS `cd citadel_core/arm/tooling_server && dart pub get`
- PASS `cd citadel_core/arm/tooling_server && dart analyze`
- PASS `cd citadel_core/arm/tooling_server && dart test`
- PASS `cd citadel_core/arm/tooling && flutter pub get`
- PASS `cd citadel_core/arm/tooling && flutter analyze`
- PASS `cd citadel_core/arm/tooling && flutter test`
- NOT RUN: External consumer migration (`LAD_Server`, `DashboardUI`) was not
  part of this slice; validation covered the shared ARM packages only.

17/07/26 18:18
- PASS `cd citadel_platform && dart format lib/src/app/platform_conduit_pages.dart lib/src/design_system/citadel_primitives.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 21/21 tests passed, including narrow-width Replay table interaction and Alerts editor layout coverage.
- NOT RUN: Browser automation; responsive behavior was validated through widget tests and static analysis in this pass.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 18:18
- PASS `cd citadel_platform && dart format lib/src/app/platform_conduit_pages.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 22/22 tests passed, including narrow-width Experience editor/table and Alerts table coverage.
- NOT RUN: Browser automation; the browser-control runtime was not exposed in this session.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 18:43
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart run build_runner build --delete-conflicting-outputs`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 41/41 tests passed.
- NOT RUN: Browser automation; this pure-Dart aggregation slice has no browser surface.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 18:59
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 25/25 tests passed, including Journey route/search, flow reroot, grouping persistence, and narrow-width coverage.
- NOT RUN: Browser automation; responsive behavior was validated through widget tests and static analysis in this pass.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 19:12
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 44/44 tests passed, including hierarchical and exact-prefix path coverage.
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 26/26 tests passed, including real Sunburst arc filtering and sub-340px layout coverage.
- NOT RUN: Browser automation; radial interaction and responsive behavior were validated through widget tests and static analysis.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 19:32
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 50/50 tests passed, including funnel matching, timing, comparison, and codec coverage.
- FAIL `npx -y firebase-tools@latest firestore:databases:list --project citadel-platform` — the current CLI identity received HTTP 403; the previously verified Standard native `(default)` database remains the target and no database provisioning or index deployment was attempted.
- NOT RUN: Browser automation; this pure-Dart core slice has no browser surface.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 19:50
- PASS `cd citadel_platform && dart format lib test`
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 33/33 tests passed, including funnel persistence, both comparison modes, dirty-draft protection, truthful zero-count bars, and compact-width readability.
- FAIL `npx -y firebase-tools@latest firestore:databases:list --project citadel-platform` — the current CLI identity received HTTP 403; the previously verified Standard native `(default)` database remains the target and no database provisioning or index deployment was attempted.
- NOT RUN: Live customer-project Firestore integration; repository behavior and customer-boundary paths were validated through contracts, preview adapters, static analysis, and widget tests.
- NOT RUN: Browser automation; responsive behavior was validated through widget tests and static analysis.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 20:08
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib test`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 50/50 tests passed, including deterministic entered-step and dropped-at-step session cohorts.
- PASS `cd citadel_platform && dart format lib/src/app/citadel_platform_app.dart lib/src/app/platform_conduit_funnels_page.dart lib/src/app/platform_conduit_pages.dart lib/src/app/platform_conduit_repository.dart test/platform_conduit_repository_test.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 37/37 tests passed, including shared funnel routes, exact entered/drop-off Replay drill-down, empty cohorts, and reset behavior.
- NOT RUN: Live customer-project Firestore integration; exact-session query batching and boundary paths were validated through repository and widget tests.
- NOT RUN: Browser automation; responsive and navigation behavior were validated through widget tests and static analysis.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 20:23
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib/src/conduit_analytics.dart test/src/conduit_analytics_test.dart`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 53/53 tests passed, including event-time metrics, safe five-class attribution, real-time visitor deduplication, URL grouping, and OS dimensions.
- PASS `cd citadel_platform && dart format lib/src/app/platform_conduit_pages.dart lib/src/app/platform_conduit_repository.dart test/platform_conduit_repository_test.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 38/38 tests passed, including analytics source drilldown, Heatmap routing, OS rendering, explicit granularity, and all prior platform coverage.
- NOT RUN: Live customer-project Firestore integration; bounded query behavior was reviewed statically and preview behavior was covered through repository and widget tests.
- NOT RUN: Browser automation; responsive behavior was validated through Flutter widget tests and static analysis.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 20:49
- PASS `cd citadel_platform && dart format lib/src/app/platform_conduit_choropleth.dart lib/src/app/platform_conduit_pages.dart test/platform_conduit_choropleth_test.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 40/40 tests passed, including real US and Singapore geometry hit testing, responsive 320px rendering, truthful empty state, and Analytics integration.
- PASS reduced Natural Earth asset validation — 242 country features including Singapore; checked-in GeoJSON is approximately 1.3 MB and registered as a Flutter asset.
- NOT RUN: Browser automation; projection, pointer/touch interaction, responsive behavior, and integration were validated through Flutter widget tests.
- NOT RUN: Live customer-project Firestore integration; this slice consumes the already-tested country aggregation response and adds no new backend query.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 20:58
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 55/55 tests passed, including event-time, project-isolation, country, URL-grouping, and reversed-window Experience coverage.
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 41/41 tests passed, including Experience country filtering and grouped-page preview behavior.
- NOT RUN: Live customer-project Firestore integration; bounded query construction was reviewed statically and preview behavior was covered by repository/widget tests.
- NOT RUN: Browser automation; filter behavior and responsive rendering were validated through Flutter widget tests.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 21:12
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 56/56 tests passed, including mixed-method API grouping, exact cohorts, elapsed offsets, and negative-offset clamping.
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 44/44 tests passed, including exact-cohort route round-trip, JS detail, elapsed Replay seek, matching rage Heatmap routing, and narrow list actions.
- NOT RUN: Live customer-project Firestore integration; exact-session batching and customer-boundary reads are covered by repository logic and preview/widget tests.
- NOT RUN: Browser automation; route, interaction, and responsive behavior were validated through Flutter widget tests.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 21:21
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 57/57 tests passed, including project/range isolation, reversed ranges, exact uptime/P95, and latest recovery state.
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 45/45 tests passed, including current synthetic status and unsafe/non-HTTP/status/window/occurrence input rejection.
- NOT RUN: Live customer-project Firestore integration; bounded query construction was reviewed statically and preview/widget behavior is covered.
- NOT RUN: Browser automation; form and status behavior were validated through Flutter widget tests.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 21:27
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 45/45 tests passed, including absence of Slack webhook plaintext, rule/history redaction, and email-only alert-rule persistence.
- NOT RUN: Live customer-project Firestore integration; credential rendering and persistence behavior were covered through preview repository and widget tests.
- NOT RUN: Browser automation; alert editor and table behavior were validated through Flutter widget tests.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 21:36
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 47/47 tests passed, including one-time key hydration, deliberate clear preservation, independent project probes, and full draft reset across project switches.
- NOT RUN: Live customer-project Firestore integration; project context hydration and switching were covered with two independent preview-repository contexts.
- NOT RUN: Browser automation; project selector routing and editor lifecycle behavior were validated through Flutter widget tests.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 21:50
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 58/58 tests passed, including rule filtering, precedence, custom naming, inactive body conditions, and deterministic ordering.
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 48/48 tests passed, including project-rule propagation, custom-name rendering, and unavailable response-body controls.
- NOT RUN: Live customer-project Firestore integration; rule propagation is wired directly and preview repository behavior is covered.
- NOT RUN: Browser automation; API settings and Experience rendering were validated through Flutter widget tests.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 21:59
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib/src/conduit_experience.dart test/src/conduit_experience_test.dart`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 59/59 tests passed, including poor-session thresholds, deterministic timing waterfalls, and sessions spanning the event-window boundary.
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 49/49 tests passed, including waterfall expansion and exact poor-session Replay routing.
- NOT RUN: Live customer-project Firestore integration; event-first participant loading was reviewed statically and the spanning-session aggregation path is covered by regression tests.
- NOT RUN: Browser automation; responsive controls and navigation were validated through Flutter widget tests.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 22:29
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format lib/src/conduit_experience.dart lib/src/conduit_ingest_service.dart lib/src/conduit_firestore_persistence.dart test/src/conduit_experience_test.dart test/src/conduit_ingest_handler_test.dart`
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 62/62 tests passed, including typed/legacy fingerprints, counted dimensions, atomic diagnostics, bounded trends, exact offsets, filtered search, and waterfall selection regressions.
- PASS `cd citadel_platform && dart format lib/src/app/citadel_platform_app.dart lib/src/app/platform_conduit_pages.dart lib/src/app/platform_conduit_repository.dart test/platform_conduit_repository_test.dart test/widget_test.dart`
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 51/51 tests passed, including counted error detail, millisecond replay, cohort pre-seek, trusted exact cohorts, and distinct waterfall replay behavior.
- NOT RUN: Live customer-project Firestore integration; compatibility, event fallback, and exact-cohort paths were covered through pure/core, preview repository, and widget regressions.
- NOT RUN: Browser automation; responsive details, charts, and navigation were validated through Flutter widget tests.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

17/07/26 22:54
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 74/74 tests passed, including SDK-compatible VoC payload acceptance, strict project/tenant and response-shape validation, safe persistence IDs, project-scoped idempotency, schema round-trips, and exact customer-Firestore paths.
- NOT RUN: Live customer-project Firestore integration; the customer target boundary and absence of a platform-target response copy are covered by the Firestore document-store integration tests.
- NOT RUN: Platform analysis/tests; no `citadel_platform` code changed in this slice.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

18/07/26 09:08
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 75/75 tests passed, including complete VoC config round-trips, legacy defaults, enabled-only delivery, canonical identity, nested builder fields, and bounded config caching.
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test` — 38/38 tests passed, including exhaustive supported VoC enum parsing and legacy aliases.
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 60/60 tests passed, including feedback contract validation, persisted feedback/poll/survey builders, branching, shareable-definition preservation, narrow layouts, and project draft reset.
- NOT RUN: Live customer-project Firestore integration; config codecs, repository persistence, delivery, and UI behavior are covered by schema, handler, transport, repository, and widget tests.
- NOT RUN: Browser automation; responsive editing and route changes were validated through Flutter widget tests.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

18/07/26 09:30
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 80/80 tests passed, including occurrence-time/project isolation, reversed ranges, deterministic ties, sentiment, poll distributions, branching/multi-choice survey answers, NPS, lifecycle completion, word frequency, and exact epoch response timestamps.
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 65/65 tests passed, including bounded empty adapters, epoch-over-legacy dedupe, analytics rendering, narrow response cards, deterministic pagination, exact Replay routing, and complete escaped CSV output.
- PASS `cd citadel_platform && flutter build web` — release web build completed; CSV Blob/anchor interop compiled for the web target and the Wasm dry run succeeded.
- NOT RUN: Live customer-project Firestore emulator integration; the remaining Feature 3.8 end-to-end audit now owns that verification path.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

18/07/26 09:36
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test` — 40/40 tests passed, including direct first-visit, custom-event, one-second time-on-page, and exact scroll-depth poll activation.
- NOT RUN: Firebase emulator end-to-end persistence; no Firebase emulator configuration or target project is present in the repository, and current persistence coverage uses the in-memory Firestore document-store adapter.
- NOT RUN: Terraform validation; no Terraform files were changed in this task.

18/07/26 10:18
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format --output=none --set-exit-if-changed lib bin test` — 32 files formatted, none changed.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart test` — 95/95 tests passed, including hosted projections, signed-token scope/expiry/tamper rejection, revision checks, branching and answer validation, unavailable-response uniformity, rate limiting, private credential resolution, proxy persistence, HTML escaping, CSP-compatible rendering, and public HTTP routes.
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart compile exe bin/citadel_conduit_hosted_surveys.dart -o /tmp/citadel_conduit_hosted_surveys` — the hosted-service executable compiled successfully.
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter analyze` — no issues found.
- PASS `cd citadel_core/conduit/citadel_conduit_sdk && flutter test` — 40/40 ordinary tests passed; the dedicated emulator test was correctly skipped without `FIRESTORE_EMULATOR_HOST`.
- PASS `cd citadel_core/conduit && ./tool/run_voc_emulator_e2e.sh` — the isolated `demo-citadel-voc` Firestore emulator E2E rendered and submitted feedback, poll, and branching-survey widgets through HTTP and verified all three persisted documents.
- PASS `cd citadel_platform && flutter analyze` — no issues found.
- PASS `cd citadel_platform && flutter test` — 73/73 tests passed, including atomic deployment synchronization, stable opaque IDs, revision rotation, disable-without-delete behavior, full shareable-survey editing/validation, and publication status/URL rendering.
- PASS `cd citadel_platform && flutter build web` — release web build completed and the Wasm dry run succeeded.
- PASS `git diff --check` in both changed repositories — no whitespace errors.
- NOT RUN: Docker image build; the Docker CLI is installed but its local daemon is unavailable. Native Dart executable compilation covers the service entrypoint, but the container image itself remains unverified.
- NOT RUN: Terraform validation or production Cloud Run deployment; Terraform is unavailable, no `.tf` files were changed, and production provisioning remains explicitly deferred.

18/07/26 11:37
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed lib test bin` — all 7 Dart source files are formatted.
- PASS `cd citadel_cli && dart analyze` — no issues found.
- PASS `cd citadel_cli && dart test` — 18/18 tests passed, covering complete `v1` parsing, strict fields, retention, roles, licensing, Secret Manager references, inline-secret rejection, neutral token budgets, schema/service rejection, malformed YAML, CLI dry-run behavior, diagnostics, missing paths, and unreadable files.
- PASS `cd citadel_cli && dart run bin/citadel_cli.dart project validate --manifest example/project_manifest.yaml` — the real example file validates as production schema `v1`.
- PASS `cd citadel_cli && dart run bin/citadel_cli.dart project onboard --manifest example/project_manifest.yaml` — the real example produces the explicit no-cloud/no-Terraform dry-run summary.
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli` — native CLI executable compiled successfully.
- PASS `cd citadel_cli && git diff --check` — no handwritten whitespace errors; Freezed output is marked generated and whitespace-exempt.
- NOT RUN: Terraform validation or cloud integration; this slice deliberately contains no `.tf` files and performs no cloud mutation.

18/07/26 11:44
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed lib test bin` — all 10 Dart source files are formatted.
- PASS `cd citadel_cli && dart analyze` — no issues found.
- PASS `cd citadel_cli && dart test` — 23/23 tests passed, covering stable capability order, status precedence, unknown blockers, observed drift, satisfied state, ARM/Conduit applicability, and command-level dry-run rendering.
- PASS `cd citadel_cli && dart run bin/citadel_cli.dart project validate --manifest example/project_manifest.yaml` — the real example file validates as production schema `v1`.
- PASS `cd citadel_cli && dart run bin/citadel_cli.dart project onboard --manifest example/project_manifest.yaml` — the real example produces a blocked ten-step no-observations plan and states that no live checks or mutations ran.
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli` — native CLI executable compiled successfully.
- PASS `cd citadel_cli && git diff --check` — no handwritten whitespace errors; Freezed output is marked generated and whitespace-exempt.
- NOT RUN: Terraform validation or cloud integration; this planner slice contains no `.tf` files and performs no cloud reads or mutations.

18/07/26 11:53
- PASS `cd citadel_cli && dart run build_runner build` — Freezed observation contracts generated successfully.
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed lib test bin` — all 13 Dart source files are formatted.
- PASS `cd citadel_cli && dart analyze` — no issues found.
- PASS `cd citadel_cli && dart test` — 31/31 tests passed, including exact registry matches/mismatches, successful missing lookup drift, unavailable/permission-denied unknown state, explicit required-API comparison, deterministic missing-service order, and planner precedence integration.
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli` — native CLI executable compiled successfully.
- PASS `cd citadel_cli && git diff --check` — no handwritten whitespace errors; Freezed output is marked generated and whitespace-exempt.
- NOT RUN: Live registry or Service Usage reads; their transport, authoritative fields, and required policy are recorded as decisions rather than inferred.
- NOT RUN: Terraform validation; this slice contains no `.tf` files and performs no cloud mutation.

18/07/26 11:55
- PASS `CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11 gcloud version` — Google Cloud SDK 569.0.0 loads successfully; the default Homebrew Python 3.14 runtime currently crashes while loading gcloud commands.
- OBSERVED `gcloud services list --enabled --project=citadel-platform` — the active `siddharth.chitikela@gmail.com` account receives `AUTH_PERMISSION_DENIED`, confirming that the future adapter must preserve permission denial as unknown rather than report APIs missing.

18/07/26 12:17
- PASS `CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11 gcloud auth list --filter=status:ACTIVE` — active account is `obsidian.infinitum@gmail.com`; configured project is `citadel-platform`.
- PASS read-only enabled-service listing for `citadel-platform` — all five approved baseline APIs (`firebase`, `firestore`, `storage`, `identitytoolkit`, and `securetoken`) are enabled.
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed lib test bin` — all 15 Dart source files are formatted.
- PASS `cd citadel_cli && dart analyze` — no issues found.
- PASS `cd citadel_cli && dart test` — 44/44 tests passed, including exact gcloud arguments, parsing/deduplication, empty success, permission signatures, safe failures, invalid project IDs, async live/offline command rendering, satisfied evidence, and observed API drift.
- PASS `CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11 dart run bin/citadel_cli.dart project onboard --manifest example/project_manifest.yaml` — the command performs no mutations, keeps the unconfigured registry unknown, and reports the real permission-denied `customer-portal-prod` API read as unknown rather than drift.
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli` — native CLI executable compiled successfully.
- PASS `cd citadel_cli && git diff --check` — no whitespace errors.
- NOT RUN: Platform REST registry integration; the approved endpoint/client is the next slice and no deployed endpoint is currently configured.
- NOT RUN: Terraform validation; no `.tf` files changed and all cloud operations were read-only.

18/07/26 12:26
- PASS `CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11 gcloud firestore databases describe --database='(default)' --project=citadel-platform --format='value(name)' --quiet` — returned `projects/citadel-platform/databases/(default)` with no mutation.
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed lib test bin` — all 18 Dart source files are formatted.
- PASS `cd citadel_cli && dart analyze` — no issues found.
- PASS `cd citadel_cli && dart test` — 60/60 tests passed, including exact read-only Firestore command arguments, present/missing/denied/unavailable/malformed outcomes, safe diagnostics, shared gcloud support regression, comparator evidence, and CLI live/offline rendering.
- PASS `CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11 dart run bin/citadel_cli.dart project onboard --manifest example/project_manifest.yaml` — the real customer target permission denial remains an unknown Firestore blocker rather than missing drift, with no mutation.
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli` — native CLI executable compiled successfully.
- PASS `cd citadel_cli && git diff --check` — no whitespace errors.
- NOT RUN: Storage, rules, access, IAM, or Platform REST reads; their missing contracts are consolidated in `DECISIONS_NEEDED.md`.
- NOT RUN: Terraform validation; no `.tf` files changed and all cloud operations were read-only.

18/07/26 12:51
- PASS `cd citadel_core/platform/contracts && dart format --output=none --set-exit-if-changed . && dart analyze && dart test` — formatting and analysis are clean; 4/4 tests passed.
- PASS `cd citadel_core/platform/api && dart run build_runner build && dart format --output=none --set-exit-if-changed . && dart analyze && dart test` — generated output rebuilt locally and remains ignored; analysis is clean and 14/14 tests passed, including canonical registry/error JSON and access projection/index consistency.
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed . && dart analyze && dart test` — formatting and analysis are clean; 68/68 tests passed, including canonical REST mapping, safe HTTP classification, explicit dev headers, and loopback runner configuration.
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli_registry_check` — native CLI executable compiled successfully.
- PASS `git diff --check` in `citadel_core` and `citadel_cli` before their commits — no whitespace errors; generated Core output was not committed.
- NOT RUN: A deployed Platform REST endpoint check; the client is covered by injected transport and loopback HTTP integration because no endpoint URL is configured.
- NOT RUN: Terraform validation; no `.tf` files changed and all implemented operations are read-only.

18/07/26 12:58
- PASS installed `gcloud storage buckets describe --help` review — confirms the read-only `gcloud storage buckets describe gs://bucket` contract and supported format/project flags.
- PASS `cd citadel_cli && dart run build_runner build && dart format --output=none --set-exit-if-changed . && dart analyze && dart test` — generated parts rebuilt locally and ignored; analysis is clean and 78/78 tests passed, including bucket manifest validation, exact command arguments, and missing/denied/unavailable evidence.
- PASS `CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11 gcloud storage buckets list --project=citadel-platform --format='value(name)' --quiet` — successful read-only inventory returned no buckets.
- PASS read-only describe of `gs://citadel-platform.firebasestorage.app` — returned authoritative `not found: 404`, matching the adapter's drift classifier.
- PASS `cd citadel_cli && dart run bin/citadel_cli.dart project validate --manifest example/project_manifest.yaml` — updated ARM example with explicit bucket validates.
- PASS read-only example onboarding — registry remains unconfigured, API/Firestore remain permission-unknown, and the declared bucket is truthfully reported missing without mutation.
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli_storage_check` — native executable compiled successfully.
- PASS clean two-repository archive verification — regenerated Freezed output in Core contracts, Core API, then CLI from committed files only; CLI analysis is clean and all 78 tests pass.
- NOT RUN: Terraform validation; no `.tf` files changed and all cloud operations were read-only.

18/07/26 13:11
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed . && dart analyze && dart test` — formatting and analysis are clean; 84/84 tests passed, including exact project-access routing, projection/index consistency, stale-index drift, safe denied/unavailable outcomes, and online/offline runner integration.
- PASS loopback Platform REST integration — registry and access observations used their exact routes, and development headers were absent without explicit environment opt-in.
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli_access_check` — native executable compiled successfully.
- PASS `cd citadel_core/platform/customer_rules && dart format --output=none --set-exit-if-changed . && dart analyze && dart test` — formatting and analysis are clean; 4/4 rules assembly tests passed.
- PASS rendered ARM/Conduit rules followed by `JAVA_HOME=/opt/homebrew/opt/openjdk@21 PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH npx -y firebase-tools@latest emulators:exec --config tool/emulator/firebase.json --project demo-citadel-rules --only firestore,storage "true"` — Firestore Standard edition and Storage emulators accepted the rendered rules and exited cleanly.
- OBSERVED Firebase CLI live database listing for `citadel-platform` returned HTTP 403 under its separate CLI credential; this did not block isolated emulator verification and no live resource was mutated.
- NOT RUN: Terraform validation; no `.tf` files changed.

18/07/26 14:11
- PASS `node --version` and `npx -y firebase-tools@latest --version` — Node `v26.0.0` and Firebase CLI `15.24.0` are available.
- PASS `npx -y firebase-tools@latest login:list` — authenticated as `obsidian.infinitum@gmail.com`.
- PASS `npx -y firebase-tools@latest firestore:databases:list --project citadel-platform` — default database is Standard edition and Firestore Native.
- PASS `cd citadel_cli && dart run build_runner build` — three ignored Freezed outputs regenerated successfully.
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed . && dart analyze && dart test` — formatting and analysis are clean; 105/105 tests passed, including exact IAM commands, conditional-binding rejection, malformed/denied safety, stable requirements, manifest principal validation, and runner integration.
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli_iam_check` — native executable compiled successfully.
- PASS `CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.11 gcloud projects get-iam-policy citadel-platform --format='json(bindings)' --quiet` — live project IAM policy read succeeded without mutation.
- PASS live read-only example onboarding — customer target IAM permission denial remains unknown rather than false missing drift, and the command applied no cloud or Terraform changes.
- PASS `cd citadel_cli && git diff --check` — no whitespace errors.
- NOT RUN: IAM mutation, Firebase Rules deployment, or Terraform validation; the slice is read-only and no `.tf` files changed.
18/07/26 14:24
- PASS `cd citadel_cli && dart pub get`
- PASS `cd citadel_cli && dart run build_runner build`
- PASS `cd citadel_cli && dart analyze`
- PASS `cd citadel_cli && dart test` (122 tests)
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli_rules_check`
- PASS live read-only Firebase Rules release and ruleset retrieval for `citadel-platform` with quota-project attribution
- NOT RUN: Terraform validation; no Terraform files were generated or changed in this slice.

18/07/26 14:38
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed .`
- PASS `cd citadel_cli && dart analyze`
- PASS `cd citadel_cli && dart test` (134 tests)
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli_terraform_render_check`
- PASS real `project terraform render` output and strict repeat-render no-overwrite exit `73`
- PASS `terraform fmt -check -diff` for the generated IAM module
- PASS `terraform init -backend=false -input=false` with `hashicorp/google` `7.40.0`
- PASS `terraform validate` for the generated IAM module
- NOT RUN: `terraform plan` or `terraform apply`; remote state is not settled and no Cloud/Firebase mutation is allowed from this slice.

18/07/26 16:07
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed . && dart analyze && dart test` (134 tests)
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli_gcs_backend_check`
- PASS bootstrap `terraform fmt -check`, provider initialization, and `terraform validate` with Google provider `7.40.0`
- PASS reviewed bootstrap plan: exactly one protected Storage bucket add, zero changes, zero destroys
- PASS saved-plan apply: `citadel-platform-terraform-state` created with one add and no other mutation
- PASS interactive local-to-GCS state migration to `bootstrap/state-bucket`, normalized state equivalence, remote state listing, and locked zero-change plan
- PASS live bucket verification: `US-CENTRAL1`, Standard, uniform access, public-access prevention, versioning, 30-day soft delete, and required labels
- PASS real rendered customer module initialization against `customers/customer-portal/iam` and `terraform validate`
- NOT RUN: customer IAM apply or Firebase Rules deployment; both remain separate boundaries.

18/07/26 16:15
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed . && dart analyze && dart test` (149 tests)
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli_plan_check`
- PASS exact command, confirmation, tamper/injection, action parsing, timeout, output-bound, and no-apply coverage
- NOT RUN: live customer Terraform plan or apply; isolated process doubles only.

18/07/26 16:38
- PASS `cd citadel_cli && dart format --output=none --set-exit-if-changed lib test && dart analyze && dart test` (161 tests)
- PASS `cd citadel_cli && dart compile exe bin/citadel_cli.dart -o /tmp/citadel_cli_apply_boundary`
- PASS exact saved-plan/receipt commands, semantic-manifest and rendered-bundle integrity, plan-byte tamper rejection, strict receipt parsing, summary reinspection, failure/timeout handling, zero-drift enforcement, and replay refusal
- PASS `cd citadel_cli && git diff --check`
- NOT RUN: live customer Terraform plan/apply or Firebase Rules deployment; no approved real customer manifest was supplied and no `.tf` file changed.

18/07/26 16:49
- PASS `cd citadel_core/conduit/citadel_conduit_ingest && dart format --output=none --set-exit-if-changed lib test bin && dart analyze && dart test` (98 tests)
- PASS `dart compile exe bin/citadel_conduit_ingest.dart -o /tmp/citadel_conduit_ingest_authorized`
- PASS `dart compile exe bin/citadel_conduit_hosted_surveys.dart -o /tmp/citadel_conduit_hosted_surveys_authorized`
- PASS privileged Conduit queries fail closed without an authorizer and expose only bounded operation/project/auth context to an injected authorizer; public SDK ingest routes retain existing behavior
- NOT RUN: Platform console HTTP migration, live Cloud Run deployment, customer Firebase access, or Rules deployment; operator query topology is awaiting decision.

18/07/26 18:05
- PASS `citadel_core/platform/api` analysis and 15 tests; `citadel_core/platform/server` analysis and 6 tests.
- PASS `citadel_core/conduit/citadel_conduit_ingest` analysis and 100 tests for the shared session-search wire codec and existing ingest behavior.
- PASS `citadel_platform` analysis and 21 focused proxy/repository tests; ordinary session search uses the Platform API client, HTTPS, bounded JSON, Firebase bearer identity, and cross-project rejection.
- PASS ARM `tooling_core`, `tooling`, and `tooling_server` analysis with 5, 5, and 6 tests respectively for normalized release identity propagation.
- PASS Exigence `npm run check` and `npm test` (4 tests); npm audit reported zero vulnerabilities.
- NOT RUN: full Platform test suite/release web build, live Cloud Run deployment, customer Firebase access, or Firebase Rules deployment. No Cloud/Firebase resource or Terraform file changed.

18/07/26 20:28
- PASS `citadel_core/platform/server` analysis and 11 tests for five project-scoped ARM routes plus privileged Conduit search, replay, metadata, and heatmap proxying.
- PASS `citadel_core/arm/citadel_arm_service` analysis and 6 tests for fail-closed authorization, bounded pagination, consistent detail, attributed mutations, and strict response decoding.
- PASS `citadel_core/conduit/citadel_conduit_ingest` analysis and 100 tests after exact session-ID cohort filtering.
- PASS `citadel_core/exigence` `npm run check && npm test` (9 tests) for strict journal validation, legal transitions, duplicate dispatch, explicit retry, and deterministic resume.
- PASS `citadel_platform` `flutter analyze`, focused ARM/Conduit API tests, full `flutter test` (82 tests), and release web build.
- NOT RUN: live Cloud Run deployment, customer Firebase access, Firebase Rules deployment, or Terraform validation; no Cloud/Firebase resource or `.tf` file changed.

18/07/26 22:23
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript checking, build, and all 23 tests pass.
- PASS provider profiles: Vertex IAM defaults, installed-adapter enforcement, Secret Manager-only API credentials, and credential-free HTTPS custom endpoints.
- PASS agent IAM: declaration plus project allowlist, role bindings, permission completeness, approval defaults/override, and denial audit evidence.
- PASS durable approvals: idempotent request/resolution, conflicting replay refusal, exact expiry, late-decision refusal, and JSON-safe payloads.
- PASS audit/cost safety: verified SHA-256 chain, tamper and corrupt-append refusal, idempotent currency-separated costs, and exact/overspent budget hard stops.
- NOT RUN: provider SDK calls, Firestore emulator persistence, Cloud Tasks, Cloud Run deployment, Secret Manager access, or Terraform; this slice is storage/cloud neutral.

18/07/26 22:46
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript checking and build are clean; 26/26 ordinary tests pass and the emulator-only integration test skips outside its harness.
- PASS `cd citadel_core/exigence && JAVA_HOME=/opt/homebrew/opt/openjdk@21 PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH npm run test:firestore-emulator` — isolated Firestore Standard emulator proved atomic projections/events, duplicate idempotency, stale-write rejection, transition validation, ordered replay, and reconstructed projection equivalence.
- PASS `cd citadel_core/exigence && npm audit --omit=dev` — zero production dependency vulnerabilities.
- PASS `cd citadel_core/exigence && git diff --check` — no whitespace errors before commit.
- NOT RUN: live Firestore access, Cloud Tasks, Cloud Run deployment, Secret Manager access, or Terraform; no production Cloud/Firebase resource changed.

18/07/26 22:51
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript checking and build are clean; 29/29 ordinary tests pass and the Firestore emulator test skips outside its harness.
- PASS Cloud Tasks adapter coverage — stable hashed names, versioned JSON, OIDC audience/service account, exact schedule conversion, duplicate `ALREADY_EXISTS`, explicit retry command, invalid configuration, and failure propagation boundaries are exercised without cloud access.
- PASS `cd citadel_core/exigence && npm audit --omit=dev && git diff --check` — zero production dependency vulnerabilities and no whitespace errors.
- NOT RUN: live Cloud Tasks queue, Cloud Run delivery, Terraform, or production Firestore; queue resources and retry configuration remain Terraform-owned.

18/07/26 22:56
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript checking and 29/29 ordinary tests pass.
- PASS Firestore emulator forced-crash recovery — a pending attempt advances to running, the worker is treated as crashed before completion, immutable events rebuild the same projection, and `pendingActivities` returns the exact running attempt without incrementing it.
- PASS `npm audit --omit=dev` and `git diff --check` — zero production vulnerabilities and no whitespace errors.
- NOT RUN: deployed Cloud Run crash, live Cloud Tasks delivery, or Terraform; this proof covers the journal recovery substrate only.

18/07/26 22:58
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript checking and build are clean; 33/33 ordinary tests pass and the emulator-only integration skips outside its harness.
- PASS task receiver coverage — exact route/queue provenance, matching command identity, strict dispatch/retry decoding, unknown-field and content-type rejection, body bounds, and retryable processor failure propagation.
- PASS `npm audit --omit=dev` and `git diff --check` — zero production vulnerabilities and no whitespace errors.
- NOT RUN: live Cloud Tasks delivery or Cloud Run IAM; the receiver is cloud-neutral and deployment remains Terraform-owned.

18/07/26 23:13
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript checking and build are clean; 38/38 ordinary tests pass and the emulator-only integration skips outside its harness.
- PASS activity payload policy — mandatory secret-key and configured JSON-pointer redaction, canonical digest stability, exact 128 KiB boundary, deterministic spill paths, binary redaction assertion, invalid JSON/pointer rejection, and GCS evidence validation.
- PASS Firestore emulator — redacted input and terminal output evidence survive immutable event storage/replay while compact activity projections retain only execution state; crash recovery still returns the exact running attempt.
- PASS `npm audit --omit=dev` and `git diff --check` — zero production vulnerabilities and no whitespace errors.
- NOT RUN: live GCS, Cloud Tasks, Cloud Run, Vertex AI, or Terraform; no production resource changed.

19/07/26 08:01
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript checking and build are clean; 42/42 ordinary tests pass and two emulator-only integrations skip outside their harness.
- PASS `cd citadel_core/exigence && JAVA_HOME=/opt/homebrew/opt/openjdk@21 PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH npm run test:firestore-emulator` — both hybrid journal and fresh-processor forced-crash recovery integrations pass against Firestore Standard emulation.
- PASS processor semantics — input resolves once, running redelivery loads journal evidence, post-effect crash resumes the same attempt/key, durable failure does not auto-retry, exact failed attempt retry reuses input, and commands ahead of durable state fail closed.
- PASS `npm audit --omit=dev` and `git diff --check` — zero production vulnerabilities and no whitespace errors.
- NOT RUN: live Cloud Tasks, Cloud Run, GCS, Vertex AI, Secret Manager, or Terraform; no production resource changed.

19/07/26 08:21
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript checking and build are clean; 52/52 ordinary tests pass and two emulator-only integrations skip outside their harness.
- PASS customer-GCS adapter coverage — generation-zero multipart upload, exact digest preflight, matching collision idempotency, conflicting-object refusal, bounded metadata, token hygiene, and sanitized upstream failure.
- PASS Vertex Gemini adapter coverage — regional/global routing, ADC bearer auth, configured model request construction, bounded validation/parsing, provider token usage, blocked prompts, malformed usage, token hygiene, and sanitized upstream failure.
- PASS `cd citadel_core/exigence && npm audit --audit-level=moderate && git diff --check` — zero dependency vulnerabilities and no whitespace errors.
- NOT RUN: live GCS, Vertex AI, Cloud Tasks, Cloud Run, or Terraform; no production resource changed.

19/07/26 08:30
- PASS `cd citadel_core/exigence/infra/modules/runtime && terraform fmt -check -diff -recursive && terraform validate && terraform test` with Terraform 1.15.8 and locked Google provider 7.40.0.
- PASS mocked plan assertions — Cloud Run minimum instances remain zero, mandatory labels are present, the dedicated invoker grant is exact, task retries are bounded, queue URI override is mandatory, new schedules are paused, and secret containers are labeled.
- PASS `cd citadel_core/exigence && git diff --check` before commit.
- NOT RUN: `terraform plan` against GCP or `terraform apply`; no Cloud/Firebase resource or IAM policy changed.

19/07/26 08:52
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript checking and build are clean; 57/57 ordinary tests pass and four emulator integrations skip outside their harness.
- PASS `npm run test:firestore-emulator` with Java 21 — approval request/resolution, 49-hour zero-event suspension, exact approval-event recovery, payload-free routing, stale-route immunity, customer audit hash chaining, and replay equivalence all pass.
- PASS durable tool gate coverage — denial audits without approval, risky redelivery creates one audit plus one request, pending remains suspended, and authoritative approval permits the same invocation without a second request.
- PASS `npm audit --audit-level=moderate` and `git diff --check` — zero vulnerabilities and no whitespace errors.
- NOT RUN: live customer/Citadel Firestore, Cloud Run, Cloud Tasks, Vertex AI, GCS, or Terraform apply; no production resource changed.

19/07/26 16:06
- PASS `cd citadel_core/exigence && npm run check && npm test` - TypeScript checking and build are clean; 60/60 ordinary tests pass and five emulator integrations skip outside their harness.
- PASS `npm run test:firestore-emulator` with Java 21 - all five integrations pass, including two concurrent 60-nano reservations against one 100-nano project cap, exactly one committed reservation, and duplicate-safe exact settlement.
- PASS precise pricing coverage - exact provider token categories, effective-dated profile selection, aggregate nano-unit ceiling, currency separation, large integer totals, and missing/ambiguous profile rejection.
- PASS `npm audit --audit-level=moderate` and `git diff --check` - zero vulnerabilities and no whitespace errors.
- NOT RUN: live customer/Citadel Firestore, Cloud Run, Cloud Tasks, Vertex AI, GCS, or Terraform apply; no production resource changed.

19/07/26 16:46
- PASS `cd citadel_core/exigence && npm run check && npm test` - TypeScript checking and build are clean; 66/66 ordinary tests pass and seven emulator integrations skip outside their harness.
- PASS `npm run test:firestore-emulator` with Java 21 - all seven integrations pass, including retained uncertain reservations, cancel-vs-in-flight execution, rejected post-cancel dispatch, and atomic approval/run/step cancellation with replay equivalence.
- PASS tier/mode pricing coverage - half-open token boundaries, exact provider modes, persisted selection evidence, duplicate IDs, invalid ranges, missing matches, and intersecting selector rejection.
- PASS `npm audit --audit-level=moderate` and `git diff --check` - zero vulnerabilities and no whitespace errors.
- NOT RUN: live customer/Citadel Firestore, Cloud Run, Cloud Tasks, Vertex AI, GCS, or Terraform apply; no production resource changed.

19/07/26 17:12
- PASS `cd citadel_core/exigence && npm run check && npm test` - TypeScript checking and build are clean; 83 ordinary tests pass and eight emulator integrations skip outside their harness.
- PASS `cd citadel_core/exigence && JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH npm run test:firestore-emulator` - all eight Standard-edition integrations pass, including audit-first cancellation, approval termination, redelivery idempotency, projection replay, and in-flight result preservation.
- PASS compensation/kill-switch coverage - explicit evidence mapping, receipt-gated failed effects, reverse completion order, stable identities, start-block-before-fanout, paginated partial progress, retry-only-failed dispatch, and cyclic-page refusal.
- PASS `npm audit --audit-level=high` and `git diff --check` - zero vulnerabilities and no whitespace errors.
- NOT RUN: live customer/Citadel Firestore, Cloud Run, Cloud Tasks, Vertex AI, GCS, or Terraform apply; no production resource changed and no manual configuration is required.

19/07/26 17:41
- PASS `cd citadel_core/exigence && npm run check && npm test` - TypeScript checking and build are clean; 85 ordinary tests pass and nine emulator integrations skip outside their harness.
- PASS `cd citadel_core/exigence && JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH npm run test:firestore-emulator` - all nine Standard-edition integrations pass, including atomic effect receipts, replay-validated compensation attempts, project start blocking, monotonic run pointers, paginated fanout, nested partial outcomes, and retry completion.
- PASS `npm audit --audit-level=high` and `git diff --check` - zero vulnerabilities and no whitespace errors.
- NOT RUN: live Citadel/customer Firestore, Cloud Run, Cloud Tasks, Vertex AI, GCS, or Terraform apply; no production resource changed and no manual configuration is required.

19/07/26 17:53
- PASS `cd citadel_core/exigence && npm run check && npm test` - TypeScript checking and build are clean; 87 ordinary tests pass and nine emulator integrations skip outside their harness.
- PASS `cd citadel_core/exigence && JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home PATH=/opt/homebrew/opt/openjdk@21/bin:$PATH npm run test:firestore-emulator` - all nine Standard-edition integrations pass, including the real cancellation handler through durable compensation, payload recovery, audit append, terminal aggregation, redelivery idempotency, and replay equivalence.
- PASS compensation executor coverage - stable attempt/effect identity, transport-crash resume, independent-failure continuation, complete/partial terminal projections, direct status-machine rules, and duplicate delivery without repeated effects.
- PASS `npm audit --audit-level=high` and `git diff --check` - zero vulnerabilities and no whitespace errors.
- NOT RUN: live Citadel/customer Firestore, Cloud Run, Cloud Tasks, Vertex AI, GCS, or Terraform apply; no production resource changed and no manual configuration is required.

19/07/26 18:08
- PASS `cd citadel_core/exigence && npm run check && npm test` - TypeScript checking and build are clean; 96 ordinary tests pass and nine emulator integrations skip outside their harness.
- PASS Java 21 Firestore emulator suite - all nine Standard-edition integrations pass, including concurrent hard-budget enforcement and cancellation compensation replay.
- PASS model/reference coverage - reserve-before-provider ordering, exact settlement, non-chargeable release, uncertain reconciliation, stable crash identity, approval suspension/resume, and durable reference-run completion.
- PASS `npm audit --audit-level=high` and `git diff --check` - zero vulnerabilities and no whitespace errors.
- NOT RUN: live Cloud Run, Cloud Tasks, Vertex AI, GCS, Secret Manager, or Terraform apply; no production resource changed and no manual configuration is required.

19/07/26 18:24
- PASS `cd citadel_core/exigence && npm run check && npm test` - 102 ordinary tests pass; ten emulator-only tests skip outside their harness.
- PASS Java 21 Firestore emulator suite - all ten Standard-edition integrations pass, including full reference execution with budget, approval, forced write crash, stable redelivery, effect receipts, notification, completion, and replay.
- PASS Cloud Run HTTP coverage, dependency audit, and diff checks.
- NOT RUN: live Cloud Run/Tasks, Vertex AI, GCS, Secret Manager, or Terraform apply; production composition is decision-blocked on configuration authority.

22/07/26 12:54
- PASS `cd citadel_core/exigence && npm run check && npm test` - TypeScript checking and build are clean; 131 ordinary tests pass and 12 emulator integrations skip outside their harness.
- PASS Java 21 Firestore emulator suite - all 12 Standard-edition integrations pass, including configuration resolution, complete reference crash/replay, and immutable idempotent run-start evidence.
- PASS runtime/bootstrap Terraform formatting, validation, and mocked module tests; both concrete demo roots validate with their backends disabled.
- PASS live bootstrap apply - 14 additions, zero changes/deletions, followed by an exact zero-drift plan; the reviewed five-part runtime configuration is active in control Firestore.
- PASS Cloud Build for diagnostic runtime bundle `27ce195`, pinned at `sha256:7493fe4c60c5c97c953d44822b7131c8851fa9b290e62f624c9f044b64be951c`.
- PASS live runtime Terraform apply and recovery - private Cloud Run revision `citadel-exigence-runtime-00002-5kz` is Ready, its startup TCP probe passes, the bounded Cloud Tasks queue is RUNNING, only the dedicated invoker has `roles/run.invoker`, and the final Terraform plan reports no changes.
- NOT RUN: live Vertex inference or a complete customer automation; deployment health is verified without creating chargeable model work or fabricated customer data.

22/07/26 14:05
- PASS `cd citadel_core/exigence && npm run check && npm test` - TypeScript checking and build are clean; 146 ordinary tests pass, 12 emulator-only integrations skip, and no tests fail.
- PASS latest Java 21 Exigence Firestore emulator run - all 12 Standard-edition integrations pass; cancellation added no persistence schema and its ordinary suite covers audit-first convergence, semantic conflicts, project isolation, terminal runs, and in-flight retryability.
- PASS `cd citadel_core/exigence/sdk && dart analyze --fatal-infos && dart test` - analysis is clean and all 10 SDK tests pass.
- PASS Platform API/server verification - Dart analysis is clean; the route-contract package has 18 passing tests and the fail-closed proxy server has 20 passing tests.
- PASS `cd citadel_platform && flutter analyze && flutter test && flutter build web --release` - zero analyzer issues, all 110 tests pass, and the release web build succeeds.
- PASS cancellation Console coverage - authenticated exact request envelopes, project/run response scoping, role gating, required bounded reasons, stable retry keys, duplicate results, and state refreshes pass.
- NOT RUN: deployment of the Feature 4.2 runtime/Platform API/Console bundle. The live Terraform-managed runtime remains the verified zero-drift Feature 4.1 revision pending the recorded Feature 4.2 decisions; no manual Cloud or Firebase action is required.

28/07/26 16:11
- PASS `cd /Users/OBSiDIAN/Downloads/Shelves/VSCode/Repositories/LuminaryAxisDashboard/DashboardUI && flutter test --platform chrome` — 56 tests pass, including the authenticated ARM intake sink contract; `flutter build web --release` succeeds.
- PASS `cd /Users/OBSiDIAN/Downloads/Shelves/VSCode/Repositories/LuminaryAxisDashboard/LAD_Server/lad_server && dart analyze && dart test` — analysis is clean and all 19 tests pass, including bounded Firebase-token ARM intake validation.
- PASS read-only Firebase CLI observation — `luminary-axis-dashboard` default Firestore is Standard edition in `asia-southeast1`.
- NOT RUN: Firebase emulator rule validation requires Java 21; this machine exposes Java 19 only. No Luminary Cloud Run deployment or Firebase rules release was performed.

14/08/26 19:40
- PASS `cd citadel_core/platform/server && dart analyze --fatal-infos && dart test` - clean analysis, all 36 tests pass including the new Exigence upstream envelope validation.
- FAIL then PASS `cd citadel_cli && dart analyze --fatal-infos && dart test` - arrived with 4 analyzer issues and 2 failing tests (`triggers with an exact JSON object payload`, `lists and resolves approvals`, both exit 1 instead of 0). Cause was two under-specified fixtures omitting `definitionId` and `runId` that the real runtime always sends. After correcting the fixtures and the analyzer issues: clean analysis, all 173 tests pass.
- PASS `cd citadel_platform && flutter analyze && flutter test` - zero analyzer issues, all 119 tests pass.
- NOT RUN: `flutter build web --release`, Firestore emulator integrations, Exigence TypeScript suite, `terraform validate`, and any deployment. No cloud resource was changed.

14/08/26 21:30
- PASS `cd citadel_core/exigence && npm test` — 169 tests, 156 pass, 13 emulator-only skip, 0 fail. Suite grew by the task-driver test; receiver and network-policy fixtures now send what Cloud Tasks and public DNS actually send.
- PASS `cd citadel_core/exigence && npm run test:firestore-emulator` — all 13 Firestore integrations pass. Two arrival failures were a test-isolation defect (both files raced one budget ledger document under parallel `node --test`), fixed by giving the budget test its own project. The script now pins firebase-tools 13.35.1 because @latest requires Java 21 and this machine has Java 19.
- PASS `cd citadel_core/platform/server && dart analyze && dart test` — clean, all 36 tests pass with the Exigence proxy client wired in the entrypoint.
- PASS `terraform validate` + `terraform plan` — exigence demo runtime/bootstrap and platform production runtime/bootstrap all validate and report zero drift after apply.
- PASS Phase R acceptance run in production — run-c5bf2bff…1441: trigger → fetch (real HTTPS source) → summarise (live Vertex gemini-3.1-flash-lite, 309000 nanos USD settled) → write approval held and resolved → resume → write + notify effect receipts durable in Firestore → budget ledger 2026-08 settled (606000 nanos spent across two live runs, zero dangling reservations) → audit chain of 5 events verified with the runtime's own verifyAuditChain. Durable cancellation was also exercised live (three earlier runs cancelled cleanly through in-flight evidence).

14/08/26 23:20
- PASS `cd citadel_core/exigence && npm run test:checkpointer` — LangGraph's official conformance suite, **714 tests, 0 fail**, run unmodified under vitest against the Firestore emulator. This is the Feature 4.1 Task 4.1.R1 acceptance gate.
- PASS `cd citadel_core/exigence && npm run test:firestore-emulator` — 17 integrations pass (13 pre-existing plus 4 new checkpointer ones covering delta-storage state retention, forced-crash resume at the exact superstep, durable interrupt/resume across a fresh saver instance, and deleteThread's retention-hold refusal).
- FAIL then PASS — the real-graph delta test failed on arrival with `'' !== 'written-once'`: storing only the channels named in `newVersions` silently dropped a channel written in the first superstep and never rewritten, while all 714 conformance tests still passed. Fixed by keying channel values on (channel, version) in their own documents and resolving each channel named in `channel_versions` on read. Recorded in the mapping doc §6.5 as the clearest example of a gate that cannot see a production defect.
- PASS `cd citadel_core/exigence && npm test` — 173 tests, 156 pass, 17 emulator-only skip, 0 fail.
- PASS `cd citadel_core/exigence && npm run check` — TypeScript clean.

14/08/26 23:55
- PASS `cd citadel_core/exigence && npm test` — 178 tests, 161 pass, 17 emulator-only skip, 0 fail, including 5 new tool-binding tests.
- FAIL then PASS — two tool-binding tests arrived asserting audit action names I had invented (`tool.invocation.allowed`/`denied`); the real names are `tool.permission.allowed`/`denied`. Corrected the fixtures, not the code.
- PASS `npm run test:checkpointer` — 714 conformance tests still green after the tool-binding work.
- PASS `npm run test:firestore-emulator` — 17 integrations still green.

15/08/26 00:40
- PASS `cd citadel_core/exigence && npm test` — 175 tests, 158 pass, 17 emulator-only skip, 0 fail (3 tests removed with the template gating they covered).
- PASS `cd citadel_core/platform/server && dart analyze && dart test` — clean, 36 tests pass after the proxy operations were removed.
- PASS `cd citadel_platform && flutter analyze && flutter test && flutter build web --release` — zero analyzer issues, 118 tests pass, release build succeeds.
- FAIL then PASS — pruning the Console tests initially cut past the end of the last widget test and took the shared fixtures with it, and removing the freezed models also removed `ExigenceConfigurationMutationOutcome`, which the surviving mutation results still use. Both caught by `flutter analyze`; the enum was restored and the test bounded at its group's closing brace.
- PASS live route verification after deploy — retired routes return 404 (`/templates`, `/definitions/{id}`) and every surviving operational route returns 200 (`automations`, `approvals`, `budget`, `providers`, `schedules/{id}`, `webhooks/{id}`).
- PASS `terraform plan` — zero drift on the Exigence demo runtime and the Platform production runtime after deploying both new images.

15/08/26 01:30
- PASS `cd citadel_core/exigence && npm test` — 176 tests, 159 pass, 17 emulator-only skip, 0 fail (adds the Cloud Tasks scheduling-horizon test).
- PASS `npm run test:firestore-emulator` — 18 integrations pass, including the new version gate: same code version resumes, a changed one fails closed, `list` stays readable for the stranded thread, and an unconfigured saver leaves the gate inert.
- PASS `npm run test:checkpointer` — 714 conformance tests still green with the version gate present, because it is opt-in and the suite configures no code version.

15/08/26 02:10
- PASS `cd citadel_core/platform/server && dart analyze && dart test` — clean, 73 tests pass, including 37 new authorization golden vectors (32 exhaustive input combinations plus 5 property assertions).
- The golden vectors independently confirm the role-derivation table written in `_dev/docs/palisade_authorization_model_extraction.md`: the expected-role formula was derived from the extraction and matched every combination.

15/08/26 02:45
- PASS `cd citadel_core/platform/server && dart analyze && dart test` — clean, 78 tests pass, adding 5 Palisade migration equivalence tests.
- The equivalence test proves the *model*, not an implementation: Palisade does not exist yet, so the new roles are declared locally in the test. Every grant combination against every access class resolves identically under the current and Palisade role models; operator and analyst are never produced by any input; admin is never held without developer; invoker reaches read access and nothing else.

15/08/26 03:30
- PASS `cd citadel_core/palisade && npm run check && npm test` — new package, TypeScript clean, 14 adversarial boundary tests pass.
- FAIL then PASS — one test asserted that `canonicalPath("/../../etc/passwd")` throws. It does not: `posix.normalize` clamps `..` at the root, exactly as the operating system does, so the correct canonical form is `/etc/passwd`. The test was wrong, not the code; rewritten to assert the clamping and then that the clamped path is denied on its merits by a client-scoped allow.
- The symlink test runs against a real temporary filesystem and demonstrates the escape rather than describing it: string matching alone allows reading a private key through a symlink out of an allowed directory, and only `realpath` denies it.

15/08/26 04:15
- PASS `cd citadel_core/palisade && npm run check && npm test` — 32 tests pass (14 boundary, 13 authority, 5 migration equivalence).
- FAIL then PASS — the migration-equivalence test failed on arrival for `exigenceProviderList` and `exigenceBudgetGet`. Both are `configurationRead` routes that viewers cannot reach today, but the viewer role I had written held `exigence.providers.list` and `exigence.budget.get`. The migration would therefore have granted clients a view of provider configuration and spend they do not have. Removed from viewer and marked superdev-only; the role model doc records the correction.
- Note on coverage: the Dart model-equivalence test could not have caught this, because it compares role sets against access classes rather than per-permission access. The TypeScript test runs the real `resolveEffectiveAuthority` over all 25 operations, which is why it did.
- FAIL then PASS — `describeEffectiveAuthority` returned a bare "no authority" for an identity whose only grant named a misspelled role, hiding the cause behind an answer that looked deliberate. Warnings are now appended in every branch.

15/08/26 05:00
- PASS `cd citadel_core/palisade/boundary && npm test` — 14 boundary tests, unchanged by the restructure.
- PASS `cd citadel_core/palisade/authority && dart analyze && dart test` — clean, 18 tests (13 authority, 5 migration equivalence) ported from TypeScript with their substance intact.
- The TypeScript authority implementation and its tests are deleted, not left alongside the Dart ones; each concern now has exactly one implementation.

15/08/26 06:00
- PASS `cd citadel_core/palisade/authority && dart analyze && dart test` — 25 tests (13 authority, 5 migration equivalence, 7 provisioning).
- PASS `cd citadel_core/platform/server && dart analyze && dart test` — clean, 95 tests, adding 5 permission-map tests and 12 Palisade resolver tests.
- PASS live backfill dry run then apply against `citadel-platform` — produced exactly current effective access (superdev for the operator on both projects, superdev for the second account on axis-education). Verified afterwards that `palisade_identities` and `palisade_grants` exist with the expected contents and that `platform_access` and `platform_projects` are unchanged at 2 documents each.
- NOT RUN: any switchover of the Platform API to permission checks, and no redeploy. Production still authorizes exactly as before; nothing reads the new collections yet.

15/08/26 07:00
- PASS `cd citadel_core/platform/server && dart analyze && dart test` — zero analyzer issues, 55 tests. The suite shrank from 95 because the old resolver was deleted with its golden vectors and three duplicate resolver tests, replaced by 12 Palisade resolver tests against the correct registry shape.
- PASS live resolution against the real backfilled registry, through the production resolver: the operator resolves to all 30 permissions on both projects, the second account to 30 on axis-education and 0 on core-platform, an unregistered address to 0 everywhere. That matches current effective access exactly.
- PASS deploy — Platform API rebuilt and applied, zero Terraform drift, unauthenticated and unregistered callers refused 403 by the app (`x-powered-by: Dart with package:shelf`), no errors in the service logs.
- ~~NOT VERIFIED end to end~~ **VERIFIED 15/08/26 07:30** — see the entry below. Rollback digest if ever needed: `citadel-platform-api@sha256:ed17275adf1a5043a69d57b22febe303707b58f147464c85f01cd182e5631b81`.
- One curiosity, believed pre-existing and not investigated further: `/healthz` returns a Google HTML 404 externally and never reaches the container, while every other path reaches the app. The internal Cloud Run startup probe on that same path passes, which is why the revision is Ready.

15/08/26 07:30
- PASS authenticated end-to-end verification of the deployed Palisade-backed Platform API, closing the gap left earlier. A real Firebase ID token was minted for the operator by signing a custom token with the Firebase Admin service account through IAM signJwt — no key downloaded — and exchanging it at the Identity Toolkit, which is the same exchange the Console's SDK performs. Token audience `citadel-platform`, email `obsidian.infinitum@gmail.com`.
- Results: `arm/issues` returns **200** on both `core-platform` and `axis-education`; every Exigence route returns **403** on both. The 403 is correct, not a regression — `offeringScope.exigence.enabled` is `false` on both projects, so the project-usability check carried across from the old resolver refuses them exactly as it did before. `arm` is the only enabled offering and it works.
- The token was destroyed immediately after use; the minting script contains no secrets and is kept in the session scratchpad only.
- NOT TESTED: the second account's live token path. `siddharth.chitikela@gmail.com` holds grants but has no Firebase Auth user record — it has never signed in — so there is no token to mint. Its per-project scoping was proven instead through the production resolver against live data: 30 permissions on axis-education, 0 on core-platform.

15/08/26 09:30
- PASS `cd citadel_core/palisade/authority && dart analyze && dart test` (36 tests)
- PASS `cd citadel_core/palisade/boundary && npm test` (14 tests)
- PASS `cd citadel_core/platform/contracts && dart analyze && dart test` (4 tests)
- PASS `cd citadel_core/platform/api && dart analyze && dart test` (18 tests)
- PASS `cd citadel_core/platform/server && dart analyze && dart test` (79 tests)
- PASS `cd citadel_platform && flutter analyze && flutter test` (127 tests)
- PASS `cd exigence && npm test` (168 pass, 18 skipped — Firestore emulator suites)
- PASS `terraform validate` and zero-drift `terraform plan` for
  citadel_core/platform/infra/environments/production/runtime and
  exigence/infra/environments/demo/runtime
- Deployed: Platform API @sha256:fd7660fb, Console hosting release
  1786784377307000, Firestore ruleset 50013b6c-49ff-4c6f-92f3-efe734f4ca0c
  (rollback ruleset fa2976c4-92ea-44c4-a9c2-75d402aa69dc), Exigence runtime
  @sha256:f09437f2 on revision citadel-exigence-runtime-palisade-vocab
  (rollback image @sha256:2b749c2d, reference configuration generation 1).
- PASS: a real end-to-end Exigence run against generation 2 —
  run-9864fd74a2799e0a65b25ef47eccd3a55e9923fca54d91ea2286aedd60ea1528,
  definitionVersion 2. fetch and summarise allowed, write held for approval,
  approved by obsidian.infinitum, resumed, write and notify succeeded. Live
  Vertex inference settled at 315000 nanos USD. Five audit events name the
  renamed capabilities. Both effect receipts durable in
  exigence_reference_outputs and exigence_reference_notifications.
  notify resolves to allowed rather than approval_required because the
  reference policy sets approvalRequiredPermissions to exigence.tools.write
  alone — the explicit single-approval policy, not a missing gate.

15/08/26 11:45
- PASS `cd citadel_core/exigence && npm test` (181 pass, 18 skipped)
- PASS `cd citadel_core/platform/server && dart analyze && dart test` (87 tests)
- PASS `cd citadel_core/palisade/authority && dart analyze && dart test` (45 tests)
- PASS zero-drift `terraform plan` for both production/runtime and demo/runtime
- Deployed: Platform API @sha256:7bde2593 (principal authority route),
  Exigence runtime @sha256:79165454, reference configuration generation 3.
  Rollback: API @sha256:fd7660fb, runtime @sha256:f09437f2, generation 2.
- PASS: real end-to-end run under Palisade-resolved artifact authority —
  run-ec40954f518eecf52f81d2 at definitionVersion 3. fetch and summarise
  allowed, write held for approval and approved, notify allowed; every audit
  event names `direct` as what conferred the capability, which is the
  artifact's Palisade grant rather than a local binding table.
- Registered `citadel-platform` in `platform_projects`. Artifact authority now
  resolves through the platform registry, so a project an artifact runs in must
  exist and be active; the reference runtime's project had never been
  registered because nothing required it before.

15/08/26 12:20
- PASS `cd citadel_platform && flutter analyze && flutter test` (130 tests)
- PASS `cd citadel_core/platform/server && dart analyze && dart test` (88 tests)
- PASS `cd citadel_core/exigence && npm test` (181 pass, 18 skipped)
- Deployed: Platform API @sha256:c13d9eff (grants carry resolved authority),
  Console hosting release 1786796121913000. Rollback: API @sha256:7bde2593.
- Verified against live data: the grants listing on `citadel-platform` shows
  the artifact `automation.reference` resolving to exactly its four
  capabilities, and the operator's superdev resolving to 25 — masked from 34
  because ARM and Conduit are disabled on that project, which is the offering
  mask doing its job.
- Granted the operator superdev on `citadel-platform`. Registering a project by
  hand leaves nobody with authority on it, and the claim route refuses once a
  project has any grants; the artifact's grant was already there.

15/08/26 12:40
- Created `demo-sandbox` through the real path — a Firebase-token write subject
  to the rules, then the claim route — rather than with application
  credentials, which would have bypassed the rules and proved nothing.
- FOUND AND FIXED: Console project creation was failing. The rules allow
  `armFirebase`, the name the Console migrated away from; it writes
  `targetFirebase`, which `hasOnly` rejected. Unnoticed because both existing
  projects predate the rename. Deployed ruleset e27bce1a.
- PASS: the claim route grants superdev on a project the caller created, and
  refuses the update path until it has.
- PASS adversarial isolation across two projects in one GCP project: the demo
  artifact resolves `exigence.tools.read` on `demo-sandbox` and is absent from
  `citadel-platform`; `palisade_grants` and `palisade_identities` refuse a
  signed-in browser; a project the caller holds no grant on returns 403.

15/08/26 13:00
- PASS `cd citadel_core/exigence && npm test` (182 pass, 18 skipped)
- PASS `cd citadel_platform && flutter analyze && flutter test` (131 tests)
- Deployed: Exigence runtime @sha256:4c7031ac (per-artifact run listing),
  Console hosting release 1786798642543000. Zero drift.
- Verified against live data: the reference artifact lists 8 runs newest-first
  across definition versions 1, 2 and 3; an artifact with no history returns an
  empty list rather than an error.
- Cancelled two runs abandoned during the artifact-authority rollout. Both
  compensated, which is the cancel path working rather than a leftover.

15/08/26 13:20
- PASS `cd citadel_core/platform/server && dart analyze && dart test` (90 tests)
- PASS `cd citadel_platform && flutter analyze && flutter test` (145 tests)
- Deployed: Platform API @sha256:390e37f6 then @sha256:... (envelope rule),
  Exigence runtime @sha256:4ba22da6. Both zero drift.
- Verified live: GET artifact-vocabulary returns the four types with their
  permitted triggers and the five agent capabilities. A proxied operation with
  no envelope rule is refused with 502 by default, which is how the missing
  rule surfaced.
- Confirmed the runtime serves exactly one customer project: the vocabulary
  route returns 404 for `demo-sandbox`, which is the per-project isolation the
  runtime is configured for rather than a missing route.

15/08/26 13:30
- PASS `cd citadel_platform && flutter analyze && flutter test` (146 tests,
  including 14 for the configuration flow's progression gating and a widget
  test that Next disables and the reason appears)
- PASS `cd citadel_core/platform/server && dart analyze && dart test` (90)
- Deployed: Console hosting release 1786800053398000, Platform API with the
  vocabulary envelope rule and direct-capability grants.
- Verified live on `demo-sandbox`: the flow's Save path grants
  exigence.tools.read and .write to the demo artifact and they resolve; a
  capability outside the agent set is refused with 400 rather than stored.

15/08/26 13:50
- PASS zero-drift `terraform plan` for exigence demo/runtime,
  exigence demo-sandbox/data, and platform production/runtime.
- FOUND AND FIXED: roles/datastore.user was granted to the Exigence runtime at
  project level with no condition. Google documents the consequence — without a
  condition a principal reaches every Firestore database in the project — so
  the runtime's service account could read any client's data by naming their
  database. Now conditioned to one database.
- PASS Phase 2 acceptance gate, proven by acting as the service account rather
  than by reading policy: impersonating
  citadel-exigence-runtime@citadel-platform, its own database `(default)`
  answers 200 and the demo client's `demo-sandbox` answers 403.
- Created the `demo-sandbox` Firestore database with delete protection. The
  database is the isolation boundary because it is the one IAM can express; a
  document prefix cannot be enforced by IAM at all.
- Every runtime now carries a mandatory `client` label for billing attribution.

16/08/26 07:20
- PASS `cd citadel_core/exigence && npm test` (195 pass, 18 skipped)
- Deployed Exigence runtime @sha256:ea1fea04 (artifact self-registration).
  Zero drift.
- Verified live: on boot the runtime wrote a registration for
  `exigence.reference.summary` on `citadel-platform` carrying its declaration
  digest, the image digest it came from, its type and its Palisade identity;
  and the artifact listing now reads that registration rather than a hardcoded
  entry.
- Recreated the token-minting helper, which the scratchpad had lost between
  sessions. The API key in `citadel_core/.env` is quoted, and Identity Toolkit
  rejects the quotes — the helper now strips them.

16/08/26 07:50
- PASS `cd citadel_core/exigence && npm test` (196 pass, 18 skipped)
- PASS zero drift across exigence demo/runtime, demo-sandbox/runtime,
  demo-sandbox/data.
- Deployed a second client runtime, `citadel-exig-sandbox-runtime`, serving
  client `demo-sandbox` on its own Firestore database, bucket, service account
  and Cloud Tasks queue, from the same image digest the first client runs.
- PASS Phase 2 isolation gate in BOTH directions, by acting as each service
  account rather than by reading policy:
    client citadel-platform  own((default))    200   other(demo-sandbox) 403
    client demo-sandbox      own(demo-sandbox) 200   other((default))    403
- Each client's runtime registered its own artifact at boot into its own
  database, naming the image digest it came from.
- KNOWN GAP: registrations are never removed. An artifact dropped from the
  image keeps its registration, so the listing would offer something the
  runtime can no longer run. Found while cleaning up a stale registration left
  by a misconfiguration during this work.

16/08/26 09:40
- Built @citadel-platform/localbridge 0.1.0 (Node CLI, local runner).
- PASS 18 package tests, including every boundary escape: a path outside the
  boundary, a `..` traversal, a symlink inside an allowed directory pointing
  out of it, a write through a symlinked directory, a deny rule beating an
  allow, a relative path, and an oversized payload.
- PASS functional verification of the built artifact, installed from a packed
  tarball into a scratch folder exactly as a client would install it:
  `doctor` printed the boundary offline; an allowed write and read completed;
  an out-of-boundary read, a symlink escape, a traversal and a denied
  extension were all refused with the path they resolved to; nothing landed
  outside the boundary; the macOS keychain round-tripped a credential.
- NOT VERIFIED: `localbridge connect` end to end. Its loop is covered by a
  test with a stubbed transport, but the cloud endpoint it polls
  (/v1/localbridge/intents:poll and :report) is not built, so the real network
  path is untested.
- NOT PUBLISHED: npm requires a 2FA code to publish, which this environment
  cannot supply.
- node_modules and the packed tarball were removed after testing (26 MB).

16/08/26 10:00
- PASS `cd citadel_core/platform/server && dart analyze && dart test` (98 tests,
  including 8 for the local runner queue: cross-client delivery, naming another
  client in the body, malformed and revoked credentials, and reporting on
  another client's intent).
- Deployed Platform API @sha256:3f10b8d3 with /v1/localbridge/intents:poll and
  :report. Zero drift.
- PASS localbridge end to end against the deployed API, with the real CLI:
  issued a runner credential, queued three intents (two for `demo-sandbox`, one
  for another client), and ran `localbridge connect --once`. The runner received
  exactly its own two, wrote the file the cloud asked for, refused the
  out-of-boundary read, and reported evidence carrying a digest and no content.
  The other client's intent was never delivered and stayed pending.
- The first attempt refused both intents because the boundary named /tmp while
  macOS resolves it to /private/tmp — the symlink resolution behaving correctly
  against a config that named an unresolved path.
- Revoked the verification runner credential (its secret appeared in a
  transcript) and removed the verification intents.
- NOT PUBLISHED: npm still requires a 2FA code this environment cannot supply.
- node_modules and build output removed after testing.

16/08/26 12:10
- PUBLISHED @citadel-platform/localbridge@0.1.0 to npm (shasum 68457d82).
  Registry propagation took roughly five minutes before the package resolved.
- PASS end to end from the published package, installed fresh from the registry
  into a scratch folder: `doctor` printed the resolved boundary; `login` stored
  a credential; `connect --once` polled the deployed API, wrote the file the
  cloud asked for, refused the out-of-boundary read, and reported evidence with
  no content. A third intent belonging to another client was never delivered.
- FIXED: the doctor test asserted no credential was stored, which was true on a
  clean machine and false after the package had been used — verifying the
  package broke its own test. It now uses a client id nothing else uses.
- Revoked both verification runner credentials, removed the verification
  intents, cleared the keychain entry, and deleted node_modules, build output
  and the temporary npm config.

16/08/26 12:40
- PUBLISHED @citadel-platform/localbridge@0.2.0. Propagated immediately.
- PASS 30 package tests, including four driving real Chrome over the DevTools
  Protocol against a locally served page.
- PASS verification from the published 0.2.0, installed fresh from the registry:
  read a real page in assisted mode and returned its text; refused the same
  page when the intent allowed only `structured`; refused a URL outside the
  boundary.
- `doctor` now reports the boundary as the filesystem will see it, resolving
  the deepest existing ancestor. This is the trap that refused every intent
  during the 0.1.0 verification, because /tmp resolves to /private/tmp.
- Node 22 is now the floor: WebSocket as a stable global is what lets the
  DevTools Protocol be spoken with no dependency.
- KNOWN GAP: `visual` mode has no implementation. It is modelled, ordered and
  treated as irreversible, but nothing produces it yet, so an intent allowing
  it gains nothing today.
- node_modules and build output removed after testing.

16/08/26 13:10
- PUBLISHED @citadel-platform/localbridge@0.3.0 (spreadsheet appending).
- PASS 38 package tests.
- PASS independent verification with openpyxl, which knows nothing about how
  this writes: it opened a workbook localbridge produced with types intact
  (float, int, bool) and XML-escaped text preserved; and a workbook openpyxl
  itself wrote — shared strings, styles — was read, appended to, and reopened
  with its bold formatting still on the cell that had it.
- PASS the same round trip from the published 0.3.0 installed from the registry.
- Adds fflate (no transitive dependencies). Hand-rolling a zip container for a
  tool that edits client spreadsheets is where a subtle bug corrupts the file
  it was asked to help with.
- KNOWN GAPS: `visual` mode is modelled but unimplemented; the approval gate
  for irreversible effects is not wired server-side; only appending is
  supported for spreadsheets, never editing an existing cell.
- All temporary installs, the openpyxl venv and build output removed.

27/08/26 08:19
- PASS `cd citadel_platform && flutter analyze` — zero issues.
- PASS `cd citadel_platform && flutter test --concurrency=1 --timeout=45s` —
  all 283 tests, including responsive project-inventory selection.
- PASS focused dashboard/settings run — 51 tests.
- The default parallel full-suite invocation stalled after 132 passing tests
  without an assertion failure; serial execution completed the entire suite.
- NOT RUN: Terraform validation; no Terraform files changed.

27/08/26 10:05
- PASS `cd citadel_core/platform/api && dart run build_runner build` — the
  committed Freezed sources for the resource-inventory contract were stale
  (generated before the last model edit); regenerated and current.
- PASS `cd citadel_core/platform/api && dart analyze && dart test` — 24 tests,
  including the inventory graph round-trip and the refusal of unknown states.
- PASS `cd citadel_core/palisade/authority && dart analyze && dart test` — 45
  tests, after adding `platform.inventory.read` and regenerating
  `palisade/catalogue.json`. The TypeScript export is unchanged because it
  carries agent capabilities and tool scopes, not the permission list.
- PASS `cd citadel_core/platform/server && dart analyze && dart test` — 178
  tests, up from 162: 8 for the inventory route and 8 for the reconciliation
  service. Before this the live GCP adapter did not compile at all (it was
  written against Cloud Resource Manager v1 field names and against Cloud Run
  fields absent from googleapis 16.0.0), so none of it had ever run.
- PASS `cd citadel_platform && flutter analyze && flutter test` — 283 tests,
  unchanged. The Console does not consume the inventory contract yet.
- NOT RUN: any live GCP call. `createGcpObserver` is exercised only through
  its state-mapping, never against real Cloud Resource Manager, Cloud Run, IAM
  or Service Usage responses. Phase R's lesson applies directly here: the
  fixtures cannot tell us the observer's field reads are right.
- NOT RUN: Terraform validation; no Terraform files changed.

27/08/26 11:20
- PASS `cd citadel_platform && flutter analyze` — zero issues.
- PASS `cd citadel_platform && flutter test --concurrency=1 --timeout=45s` —
  297 tests, up from 283. 10 for the reconciliation panel and its remediation
  routing, 4 for the inventory API client, 1 added to the dashboard test
  asserting the panel is mounted beside the registry panel rather than
  replacing it.
- The panel tests assert the states stay distinguishable on screen: `No
  access` and `Absent` are separate labels with separate actions, and a live
  observation renders on its own line beside the intent it contradicts.
- NOT RUN: any live GCP call, still. The Console renders from a fake client;
  `createGcpObserver` has never seen a real Cloud Resource Manager, Cloud Run,
  IAM or Service Usage response.
- NOT RUN: Terraform validation; no Terraform files changed.

27/08/26 12:40
- PASS `cd citadel_core/palisade/authority && dart test` — 46 tests, up from
  45. `platform.inventory.read` left `superdevOnlyPermissions` for the viewer
  role, `platform.inventory.invocable` was added for invoker, and the
  `invoker is a strict superset of viewer` invariant became
  `invoker is a superset of viewer but for the inventory scope`, asserting the
  difference equals `invokerNarrowerThanViewer` exactly. `catalogue.json`
  regenerated.
- PASS `cd citadel_core/platform/api && dart test` — 24 tests. Contract gained
  `ProjectResourceInventoryScope`, a per-node `invocable` flag, and codec
  coverage for both; an absent `scope` decodes as `complete` so a reader that
  predates scoping is not told a whole graph is partial.
- PASS `cd citadel_core/platform/server && dart test` — 184 tests, up from 178.
  Six new route tests: viewer gets the complete graph, invoker gets only
  invocable nodes and is told so, invoker sees no GCP boundary and no
  provisioning record, a narrowed graph keeps no link naming a withheld
  resource, the broader permission wins when both are held, and a project with
  nothing invocable narrows to an empty graph rather than a 404.
- PASS `cd citadel_platform && flutter analyze && flutter test
  --concurrency=1 --timeout=45s` — 301 tests, up from 297. Four new: a narrowed
  graph says it is not the whole project, offers no action that would be
  refused, the same resource still offers one at full scope, and an empty
  narrowed graph reads as "nothing you can run" rather than "no resources".
- NOT RUN: any live GCP call, still.
- NOT RUN: Terraform validation; no Terraform files changed.

27/08/26 14:10 — FIRST LIVE RUN AGAINST GOOGLE CLOUD
- PASS `CITADEL_LIVE_GCP_PROJECT=citadel-platform dart test
  test/platform_gcp_observer_live_test.dart --tags live` — 8 tests. All three
  Cloud Resource Manager / Cloud Run field fixes confirmed against real
  responses: `projectNumber: 790988281903` parsed out of `projects/{number}`,
  `lifecycleState: ACTIVE` from v3 `state`, and `serviceAccount` read through
  `template.serviceAccount` on both deployed services.
- PASS `CITADEL_LIVE_REGISTRY_PROJECT=citadel-platform dart test
  test/platform_inventory_live_test.dart --tags live` — 7 tests, covering the
  whole read path against the live registry and live GCP, over all four
  registry projects.
- **DEFECT FOUND AND FIXED — production-fatal, invisible to every fixture.**
  `_dateTime` read registry timestamps from `Value.stringValue`. Firestore
  returns them as `Value.timestampValue`. Every document the current console
  and provisioning runner write was therefore undecodable, so
  `GET /v1/projects/{id}/inventory` would have thrown `FormatException: A
  required timestamp is missing or invalid` on every real project. Both
  readings are now accepted; five regression tests in
  `test/platform_registry_document_test.dart` drive the real `FirestoreApi`
  over a stubbed transport so the wire shape is part of the assertion. Verified
  the regression fails with the fix reverted.
- **GAP FOUND AND CLOSED.** The first live run produced six observations for
  eight cloud nodes: `gcp-firestore` and `gcp-provisioner-job` had inventory
  slots that nothing ever filled, so the registry database could have been
  deleted and the panel would have gone on showing configured intent. Both are
  now observed — Firestore through the databases list, the Terraform runner
  through Cloud Run Jobs — and a live test asserts every cloud node carries a
  live claim.
- Live states observed on `citadel-platform`: all eight healthy. Firestore
  `(default)` us-central1 FIRESTORE_NATIVE, delete protection DISABLED;
  provisioner job 26 executions, CONDITION_SUCCEEDED.
- The `permissionDenied` path is confirmed against real IAM rather than a
  fixture: `axis-education` reports seven of eight cloud resources as
  `permissionDenied` and its project as `healthy`; `demo-sandbox` and
  `exigence-lab` report `permissionDenied` for most, `healthy` for enabled
  APIs. Before this slice all of those read as "not configured".
- PASS all non-live suites afterwards: api 24, authority 46, server 189
  (2 live files skipped without their env vars), Console 301.
- NOT DEPLOYED: the live `citadel-platform-api` revision predates the route.
  `GET /v1/projects/demo-sandbox/inventory` returns
  `{"code":"notFound","message":"No Platform API route matches this request."}`
  — correct behaviour for a revision built before the route existed, and the
  reason no end-to-end test drove the deployed HTTP surface.

27/08/26 15:40 — DEPLOYED AND VERIFIED THROUGH THE CONSOLE
- DEPLOYED `citadel-platform-api` twice: revision 00024-gn6 (`15b575c`,
  digest sha256:85cffad5) then 00025-js6 (`065d3db`,
  digest sha256:bb5f8fde) after the browser run found two defects. Both built
  through `cloudbuild.api.yaml` and deployed digest-pinned. The service starts
  clean; the third `cloud-platform.read-only` credential works on Cloud Run.
- PASS deployed route auth edge, live: no token → 401 `unauthenticated`; bad
  token → 401; POST → 405. Before deploying, all three were 404 "No Platform
  API route matches this request".
- PASS the full browser path — Console → Firebase ID token → deployed Platform
  API → live Google Cloud — which also closes the Phase R gap about the proxy
  never having been exercised by a browser credential.
- **CONFIG FOUND.** The Console could not load against the deployed API from
  `localhost:8899`: `CITADEL_CONSOLE_ALLOWED_ORIGINS` lists port 5000, not
  8899, and the blocked call surfaced as an indefinite "Loading workspace"
  rather than an error. Run the local Console on port 5000.
- **DEFECT FOUND AND FIXED (server).** When Cloud Resource Manager refuses,
  the observer stops — correctly — but reported the refusal against one node
  and left seven showing configured intent, which renders as "Unverified": a
  check still to come, when the check was refused. `axis-education` read
  "1 No access, 15 Unverified"; it now reads "8 No access, 10 Unverified" with
  the reason on every cloud row.
- **DEFECT FOUND AND FIXED (Console).** Fifteen rows offered a Recheck button
  for resources no observer reads, so every press returned the same row.
  Resources never observed now show state and no action.
- PASS after both fixes: server 190 (was 189), Console 302 (was 301), both
  live suites 9 and 7.
- **IAM GAP, NOT FIXED — needs a decision.** The deployed API's service
  account `citadel-platform-api@citadel-platform` cannot read client projects.
  Against `luminary-axis-dashboard` even the Cloud Resource Manager project
  lookup is refused, so every client project's inventory is eight rows of
  "No access". The panel reports this correctly, but the inventory is only
  informative for `citadel-platform` itself until that account is granted
  read-only roles on client projects. My own ADC can read them, which is why
  the live test suites pass where the deployed service does not.
27/08/26 13:29 — WORKSPACE FAILURE, INVENTORY CLASSIFICATION, ARM RETIREMENT
- PASS `cd citadel_platform && flutter analyze` — zero issues.
- PASS `cd citadel_platform && flutter test --concurrency=1 --timeout=45s` —
  303 tests. New coverage proves a stalled Platform API request leaves the
  loading state and renders browser-origin/CORS guidance.
- PASS `cd citadel_core/platform/server && dart analyze && dart test` — zero
  issues, 191 tests passed and 2 opt-in live suites skipped without env vars.
  Firestore API 403 now has direct official-client transport coverage.
- PASS ARM retirement audit: `tooling` analysis and 5 tests; `tooling_core`,
  `tooling_server`, and `citadel_arm_service` tests. No surviving package
  depends on the deleted standalone Console.
- NOT RUN: live GCP suites or browser E2E; neither deployed code nor cloud
  configuration changed. The production observer IAM remains decision-gated.

27/08/26 15:04 — CLIENT-PROJECT INVENTORY OBSERVER IAM
- PASS `cd citadel_cli && dart analyze && dart test` — zero issues and all 179
  tests passed. Onboarding requirements, deterministic Terraform rendering,
  policy observation, and the CLI render path cover the fixed Platform API
  principal, exact custom-role name, and six-permission allowlist.
- PASS native CLI compilation and a real generated-module `terraform fmt
  -check`, backend-disabled `terraform init`, and `terraform validate` with
  Google provider 7.46.0.
- PASS the live `axis-education` customer Terraform stack: validation, reviewed
  two-addition/zero-destroy plan, apply, and a zero-drift follow-up plan. Google
  rejected the initially proposed `resourcemanager.projects.list` as invalid
  for a project custom role; source and decision records now match the six
  permissions the observer actually calls.
- PASS provider-side role and binding inspection: the live role contains only
  `datastore.databases.list`, `iam.serviceAccounts.list`,
  `resourcemanager.projects.get`, `run.jobs.list`, `run.services.list`, and
  `serviceusage.services.list`, bound to exactly
  `citadel-platform-api@citadel-platform.iam.gserviceaccount.com`.
- NOT RUN: a fresh authenticated Console/API request after the binding. Browser
  control was unavailable and both local user accounts correctly lack service-
  account token creation authority; no authority was widened for the test.
27/08/26 18:37
- PASS `cd citadel_core/exigence && npm run check && npm test` after removing
  the customer-container publication/runtime path and its SDK/tooling.
- PASS `cd citadel_core/platform/server && dart analyze && dart test test` —
  181 tests pass; 2 opt-in live tests skip without credentials.
- PASS `cd citadel_core/platform/provisioner && dart analyze && dart test` —
  10 tests pass.
- PASS `cd citadel_core/exigence/infra/modules/runtime && terraform init
  -backend=false && terraform validate` — the shared runtime module used by
  the provisioner image is valid. The source template cannot validate in place
  because that image copies the module into `templates/exigence-runtime`.
- PASS `cd citadel_cli && dart analyze && dart test` after removing the entire
  `exigence agents` CLI group.
- PASS `cd citadel_platform && flutter analyze && flutter test` to confirm the
  registry-based Console remains compatible with generic Artifact operations.
- NOT RUN: Terraform decommission. The known demo-sandbox customer-agent
  deployment and stale registry field require a separate, target-confirmed
  Terraform/data plan; source reconciliation must not silently remove live
  resources.
28/08/26 09:30
- PASS `cd citadel_core/exigence && npm run test` — 547 tests completed: 454
  pass and 93 intentional integration/acceptance skips. Artifact declarations
  now require a positive reviewed version and canonical declaration digest.
- PASS `cd citadel_platform && flutter analyze`.
- PASS `cd citadel_platform && flutter test test/platform_exigence_pages_test.dart`
  — 49 tests pass after retiring the Console configuration routes and actions.
- NOT RUN: Terraform validation; no Terraform files changed.
28/08/26 09:44
- PASS `cd citadel_core/exigence && npm run check && npm test` — TypeScript is
  clean; 549 tests completed with 456 passing and 93 intentional integration
  skips. New tests require immutable revision identity and digest-pinned shared
  provider, policy, adapter, and Palisade boundary evidence.
- NOT RUN: emulator, live, or Terraform gates; this slice changes only the pure
  Artifact revision contract and unit tests.

28/08/26 14:44
- PASS `cd citadel_core/exigence && npm test` — 551 tests completed: 457 pass
  and 94 intentional infrastructure skips. Artifact persistence was separately
  proven against the real Firestore emulator under Java 21; runtime listing and
  immutable detail/history now read Artifact revisions, never registrations.
- PASS `cd citadel_core/platform/server && dart analyze --fatal-infos && dart
  test` — zero issues, 193 tests pass and 2 opt-in live suites skip without
  credentials. Artifact latest/history/exact reads are Palisade-gated and
  successful upstream envelopes are revalidated for project/artifact/revision.
- PASS `cd citadel_platform && flutter analyze && flutter test` — zero issues
  and all 308 tests pass. Artifact detail renders independent immutable revision
  history with strict project-scoped decoding and truthful empty/error states.
- PASS Localbridge policy/durable transport gates from the same Phase 2 run:
  54 tests, including Chrome, with Access, Effect and Data Handling rechecked
  locally immediately before execution.
- NOT RUN: live WhatsApp delivery. Provider approval plus WABA/phone/token,
  webhook secret and allowlisted recipient configuration are required.

28/08/26 17:20
- PASS `cd citadel_core/exigence && npx tsc --noEmit -p tsconfig.json`
- PASS `cd citadel_core/exigence && npm test` (553 tests, 94 emulator-gated skips)
- PASS `cd citadel_core/exigence && firebase emulators:exec --config tool/emulator/firebase.json --project demo-citadel-exigence --only firestore <node --test dist/test/*.integration.test.js>` (96 tests)
- PASS `cd citadel_core/platform/server && dart analyze` and `dart test` (192 tests)
- PASS `cd citadel_platform && dart run build_runner build --delete-conflicting-outputs`
- PASS `cd citadel_platform && flutter analyze` and `flutter test` (288 tests)
- PASS `cd citadel_cli && dart analyze` and `dart test` (173 tests)
- PASS `cd citadel_core/palisade && dart analyze`; `cd citadel_core/palisade/authority && dart test` (46 tests)
- NOTE: `npm run test:firestore-emulator` fails before reaching the tests. The
  npx-fetched firebase-tools 13.35.1 cannot load its own `universal-analytics`
  dependency under Node 21 (`ERR_REQUIRE_ESM` on `uuid`). Ran the same suite
  through the installed firebase CLI 14.8.0 instead, via a wrapper script that
  invokes the real `node` by absolute path — the pkg-bundled CLI shadows `node`
  on PATH and otherwise treats `--test` as a module name.
- NOT RUN: Terraform validation; no Terraform files were changed. The
  provisioning template does need new variables before a console-built client
  can bootstrap — see CURRENT_TASK.md.

28/08/26 18:05
- PASS `cd citadel_core/exigence/infra/modules/runtime && terraform validate`
- PASS `terraform validate` for `citadel_core/platform/provisioner/templates/exigence-runtime`, with `citadel_core/exigence/infra/modules/runtime` staged at `modules/runtime` as the Dockerfile stages it. The template cannot be validated in place: its `source = "./modules/runtime"` is materialised at image build.
- PASS `cd citadel_core/platform/server && dart analyze` and `dart test` (193 tests)
- PASS `cd citadel_platform && flutter analyze` and `flutter test` (288 tests)
- NOT RUN: `terraform plan` against real state; no credentials were used and the change adds a required variable that no caller can supply yet.

28/08/26 19:40
- PASS `cd citadel_core/platform/api && dart run build_runner build --delete-conflicting-outputs`, `dart analyze`, `dart test` (31 tests)
- PASS `cd citadel_core/platform/server && dart analyze` and `dart test` (209 tests)
- PASS `cd citadel_platform && flutter analyze` and `flutter test` (291 tests)
- PASS `cd citadel_cli && dart analyze` and `dart test` (173 tests)
- PASS `cd citadel_core/palisade/authority && dart analyze` and `dart test` (46 tests)
- PASS `cd citadel_core/exigence && npm test` (553 tests, 94 emulator-gated skips)
- NOT RUN: Firestore emulator suite; no Exigence persistence changed in this slice.
- NOT RUN: `terraform plan` against real state; no .tf files changed in this slice.
- NOT RUN: a live authenticated publish/build against the deployed API. The
  routes and the resolver are covered by tests over a stubbed Firestore, but
  nothing has yet published a real Access or Effect Boundary or driven a
  console build end to end.

29/08/26 06:45 — E2E through the Console UI (claude-in-chrome)
- PASS Palisade → Boundaries renders three independent tables: Data Handling,
  Access, Effect, each with its own publish control and empty state.
- PASS The publish dialog opens per kind and is titled for that kind; Publish
  starts disabled.
- PASS A malformed rule line blocks publication and names the line:
  `allow path client/reports/**` → "Line 1: a path pattern must be absolute."
- PASS Correcting the line clears the message and enables Publish.
- PASS Publishing appends a revision and the table re-renders. Publishing
  Effect left Data Handling and Access untouched, which is what the separate
  providers are for.
- PASS Revisions increment per boundary and history is kept: Access went from
  one row (revision 1, 1 rule) to two (revision 1 and revision 2, 2 rules).
- HOW: `flutter build web -t <temporary seed entrypoint>` served with an SPA
  fallback on 127.0.0.1:8792, driven in the operator's own Chrome. The
  entrypoint used the seed workspace (superdev on `core-platform`) and overrode
  `platformWorkspaceClientProvider` with an in-memory double. It has been
  deleted; the built bundle remains in the session scratchpad.
- NOT COVERED by this E2E, and still unproven anywhere: the HTTP seam. The
  Console's real `HttpPlatformWorkspaceClient`, the Platform API's
  `/access-boundaries` and `/effect-boundaries` routes under a real Firebase
  ID token, and a console-driven provisioning build have not been exercised
  together. That needs a signed-in operator against a deployed API; the API
  currently deployed predates all of this work.
- OBSERVED, not a product defect: the Flutter canvas stopped repainting after
  the automation resized the window mid-interaction. A reload recovered it.

29/08/26 07:20
- PASS `cd citadel_core/platform/server && dart analyze` and `dart test` (216 tests, 3 emulator-gated)
- PASS `terraform validate` for `citadel_core/platform/infra/modules/runtime` and `environments/production/runtime`
- NOT RUN: `terraform plan` against real state; applying `platform_owners` is a deploy, not a test.
- NOT RUN: a real claim against the deployed API. The owner-grant path is
  covered by route tests over a stubbed Firestore only.

29/08/26 07:45
- PASS `cd citadel_core/platform/server && dart analyze` and `dart test` (219 tests, 3 emulator-gated)
- PASS live read-only dry run:
  `dart run tool/reconcile_platform_owners.dart --project citadel-platform --owner obsidian.infinitum@gmail.com`
  → four projects, operator holds superdev on all four, nothing to write.
  This is the first live-registry read this session and it used the operator's
  own ADC.
- NOT RUN: `--apply`; there was nothing to apply.

29/08/26 08:15 — DEPLOYED
- Built `citadel-platform-api` from `41b1286` through `cloudbuild.api.yaml`;
  image sha256:988b9d77. Pinned in `images.auto.tfvars` (gitignored: a digest
  is deploy state, not source) and applied.
- `terraform apply` on `environments/production/runtime`: 0 added, 1 changed,
  0 destroyed — the image, and the new `CITADEL_PLATFORM_OWNERS` variable.
  Revision `citadel-platform-api-00026-x9g`, replacing `00025-js6`
  (sha256:bb5f8fde), which predated every commit of the last two sessions.
- PASS deployed, live: `/v1/projects/{id}/access-boundaries` and
  `/effect-boundaries` answer 401 `unauthenticated`, not 404 "No Platform API
  route matches this request". That difference is what distinguishes a route
  that exists from one built before it did.
- PASS deployed, live: the retired Exigence configuration routes — `providers`,
  `budget`, `schedules/{id}` — now answer that 404. Gone from the deployed
  surface, not merely unreferenced in source.
- PASS `CITADEL_PLATFORM_OWNERS` reads back as the operator on the live
  service.
- BLOCKED — the browser half. The Console was built against the deployed API
  and served on the allowed origin `http://127.0.0.1:5000`. Every asset loaded:
  CanvasKit, fonts and all four Firebase SDKs, no failed request and no console
  error. But the app sits at the sign-in gate, which needs a Google sign-in
  only the operator can complete, and the extension could not script the page
  afterwards — `document_idle` never arrives, so screenshot, find and read_page
  all time out. The seed-data build scripts fine in the same tab, so this is
  the real Firebase session, not the app.
- NOT ACCEPTED as a substitute: a user-account `gcloud auth print-identity-token`
  is refused by the deployed API (401), as Phase R recorded. There is no way to
  reach these routes with a real credential except a signed-in browser.

29/08/26 08:55
- PASS `cd citadel_core/exigence && npm test` (562 tests, 94 emulator-gated)
- PASS `cd citadel_core/platform/server && dart analyze` and `dart test` (219)
- PASS `cd citadel_platform && flutter analyze` and `flutter test` (293)
- DEPLOYED `citadel-platform-api-00027-sc7`, image sha256:14c5387c, from
  `c35d94e`. terraform apply: 0 added, 1 changed, 0 destroyed.
- PASS deployed, live: the publish route answers 403 `permissionDenied`, not
  404 "No Platform API route matches this request" — it exists and is gated.
- NOT DEPLOYED: the Exigence runtime image. The proxy route is live but its
  upstream is not, so the full path does not work yet. The runtime is deployed
  separately, digest-pinned through its own Terraform.
- BLOCKED — browser E2E of the artifacts page. The seed harness cannot reach it:
  overriding `platformExigenceClientProvider` from an outer ProviderScope did
  not take effect the way the workspace-client override does, so the page keeps
  resolving `UnavailablePlatformExigenceClient` and renders "No platform API".
  Not chased further. The two widget tests drive the real page, dialog and
  provider invalidation, so the flow is covered; what is unverified is only how
  it looks in a browser.

29/08/26 09:20 — MIGRATION GAP FOUND, RUNTIME NOT DEPLOYED
Read the live `citadel-platform` Firestore before deploying the Exigence
runtime:
- `exigence_configuration_versions`: 5 documents — the running client's
  configuration under the retired model.
- `exigence_artifact_revisions`: 0. No Artifact revision has ever been
  published for this client.
- `palisade_boundary_revisions`: 0. No Access or Effect Boundary exists.
- `palisade_data_handling_boundary_revisions`: 0.

So deploying the new runtime would break the running service. It resolves
Artifact revisions and there are none, so it would fail at boot with "artifact
revision was not found" and Cloud Run would roll the deployment back — the
exact failure the first provisioning template hit. The runtime was NOT
deployed.

The order this has to happen in: publish an Access, an Effect and a Data
Handling Boundary for the project; publish an Artifact revision pinning all
three, through `tool/publish_reference_configuration.ts`; then deploy the
runtime image. Each step needs the one before it.

Blocked on an operator decision: what those three boundaries should permit.
That decides what the artifact may reach, and inventing it would bind the
artifact to boundaries nobody reviewed — which is the one thing the pinning
design exists to prevent.

29/08/26 10:15
- PASS live: `terraform apply` on `customers/demo-project/iam` — 2 added, then
  a second apply reporting no changes, so the boundary is convergent.
- PASS live: `tool/reconcile_platform_owners.dart` wrote the operator's
  superdev grant on `demo-project`, and a re-run reports every owner holding
  superdev on every project. First live exercise of that tool's `--apply`.
- PASS live: the registry now holds exactly `axis-education` and
  `demo-project`.

29/08/26 10:40 — the boundary chain proved on demo-project, live
- PASS published three boundaries for `demo-project` with
  `tool/publish_boundary.dart` and the Data Handling service: Access
  (allow `https://citadel.obsivision.com/*`, deny `/etc/**`), Effect (allow
  `/exigence_reference_outputs/**` and `/exigence_reference_notifications/**`),
  Data Handling (in-situ processing over the outputs collection).
- DEFECT CAUGHT BY THE VALIDATOR, not by a test: the first Effect attempt used
  `exigence_reference_outputs/**` and was refused because a path pattern must
  be absolute. A Firestore document path is `/collection/doc`; the relative
  form was a modelling mistake and would have published a boundary matching
  nothing.
- PASS `artifactAuthorityResolver` against live Firestore: `demo-project`
  resolves to three `resourceId:revision:digest` coordinates whose digests
  match the published revisions exactly.
- PASS the refusal path, live: `axis-education` has no boundaries and is
  refused by name — "no published Data Handling Boundary named default" —
  rather than defaulted.
- NOT RUN: the HTTP publish route under a real Firebase token, and the Console
  boundary page against the deployed API. Both need a browser sign-in.

30/08/26 09:40
- PASS `cd citadel_core/exigence && npm run check`
- PASS `cd citadel_core/exigence && npm test` (670 tests, 562 pass, 108 skipped — the emulator-only integration tests)
- PASS `cd citadel_core/exigence && npm run test:firestore-emulator` (110 tests)
- PASS `cd citadel_core/platform/server && dart analyze`
- PASS `cd citadel_core/platform/server && dart test` (239 tests, 3 skipped — emulator-gated)
- PASS `cd citadel_platform && flutter analyze`
- PASS `cd citadel_platform && flutter test` (312 tests)
- NOT RUN: `terraform validate`; no .tf files were changed. Switching the
  Manifold webhook on will change the runtime module and needs it then.
- NOT RUN: browser E2E; the Console's inbox is unchanged and the new work is
  the runtime route beneath it. The composed runtime is driven over a real
  socket by `test/manifold_composition.test.ts` instead.
- NOT RUN: any deploy. The Exigence runtime has never been deployed with the
  Manifold composition, and the deployed Platform API predates the proxy fix.

30/08/26 12:30
- PASS `cd citadel_core/exigence && npm run check`
- PASS `cd citadel_core/exigence && npm test` (568 pass)
- PASS `cd citadel_core/exigence && npm run test:firestore-emulator` (110 tests)
- PASS `cd citadel_core/platform/server && dart analyze` / `dart test` (241 tests, 3 skipped)
- PASS `cd citadel_core/palisade/authority && dart analyze` / `dart test` (46 tests)
- PASS `cd citadel_platform && flutter analyze` / `flutter test` (312 tests)
- PASS `cd citadel_cli && dart analyze` / `dart test` (173 tests)
- PASS `terraform validate` on `citadel_core/exigence/infra/modules/runtime`
- PASS `terraform validate` on the provisioning template with
  `citadel_core/exigence/infra/modules/runtime` staged at `modules/runtime`
- NOT RUN: any apply or deploy. The receiver service, its bucket and the
  `allUsers` grant exist in Terraform and have never been applied.

30/08/26 15:10
- PASS `cd citadel_core/platform/api && dart analyze` / `dart test` (31 tests)
- PASS `cd citadel_core/platform/server && dart analyze` / `dart test` (256 tests, 3 skipped)
- PASS `cd citadel_platform && flutter analyze` / `flutter test` (314 tests)
- PASS `cd citadel_core/exigence && npm test` (568 pass)
- PASS `cd citadel_cli && dart analyze` / `dart test` (173 tests)
- PASS `cd citadel_core/palisade/authority && dart test` (46 tests)
- NOT RUN: any call to Meta. The Graph endpoint and its fields are taken from
  Meta's published documentation; the verifier has never been run against the
  real API, and the first live channel is what proves it.

30/08/26 — Feature 4.1 Task 4.1.R4 determinism guard
- PASS `cd citadel_core/exigence && npm test` — 726 tests, 609 pass, 117 emulator-only skip, 0 fail. `npm test` now runs the determinism lint first and fails on a finding, so the guard is a gate rather than a report.
- PASS `npm run lint:determinism` — 29 replay-reachable modules, nothing found.
- FOUND then RESOLVED — the guard's first run reported 5 constructs. One was a real defect: `local_report_graph.ts` stamped the row it appends to the client's workbook with `args.clock?.now() ?? new Date().toISOString()`, so a replayed node would write a different time into a cell somebody reads than the checkpoint the run continues from was written with. Fixed by making `clock` required on `LocalReportGraphArgs` (production already injected one; only the test fixture had to change). The other four are elapsed-time bounds and a between-superstep dispatcher, each now standing down under a `determinism: ok — <reason>` comment naming a reason a reader can check.
- PASS new replay-equivalence assertion in `test/local_report_graph.test.ts` — a run killed mid-graph and resumed produces state deep-equal to the uninterrupted run's, with each client-machine effect sent exactly once and the same row stamped.
- PASS 12 new `determinism_guard` tests, including the two that matter for decay: scope is derived from imports so a new graph pulls itself in without being listed, and a suppression carrying no reason is reported in its own right rather than honoured.

30/08/26 — Feature 4.2 Task 4.2.1 project run list, 4.2.3 irreversible approvals
- PASS `citadel_core/exigence` `npm test` — 728 tests, 611 pass, 117 emulator-only skip, 0 fail.
- PASS `citadel_core/palisade/authority` `dart analyze && dart test` — 48 pass after adding `exigence.runs.list` and regenerating the exported catalogue.
- PASS `citadel_core/platform/server` `dart analyze && dart test` — 311 pass, including two new proxy operations and a guard test proving an artifact run list answering with another artifact's runs is refused as a 502.
- PASS `citadel_platform` `flutter analyze && flutter test` — zero issues, 333 pass, including the run list and the irreversible-approval label.
- FOUND — the Console's `listArtifactRuns` had no proxy route at all: `GET /exigence/automations/{id}/runs` was never routed, so the artifact page's runs table could only ever have 404'd. Routed as part of this work.

30/08/26 — Feature 4.3 Tasks 4.3.1, 4.3.2 (per-run view), 4.3.4
- PASS `citadel_core/exigence` `npm test` — 754 tests, 634 pass, 120 emulator-only skip, 0 fail.
- PASS `npm run test:firestore-emulator` — 122 integrations pass, including three new trace-store ones: a replayed superstep writes over its own span rather than adding a second, another project's spans are not this project's trace, and attributes survive the round trip.
- PASS `citadel_core/platform/server` `dart analyze && dart test` — 311 pass with the spans route and its coordinate guard.
- PASS `citadel_platform` `flutter analyze && flutter test` — zero issues, 335 pass, including the trace panel and the "no trace for this run" state that is not presented as a failure.

30/08/26 — Feature 4.4 Office extraction and Microsoft Graph, Feature 4.3.1 OTLP mirror
- PASS `citadel_core/exigence` `npm test` — 774 tests, 654 pass, 120 emulator-only skip, 0 fail.
- PASS `citadel_core/exigence` `npm run test:firestore-emulator` — 122 integrations pass.
- PASS `citadel_core/localbridge` `npm test` — 55 pass, including a file whose bytes are not text surviving the round trip byte for byte.
- FOUND then RESOLVED — the runner returned file content as a UTF-8 string, so every non-text document the folder connector fetched arrived as replacement characters with a digest that no longer described it. A `.docx` in a synced Drive folder would have been indexed as rubbish and reported as a successful read. Fixed on both sides in one change: the runner declares `contentEncoding`, the connector decodes accordingly and refuses content labelled base64 that is not.
- FOUND then RESOLVED — no `invoke_agent` span was emitted anywhere in production code, though every model and tool span names one as its parent. Any OTel backend would have received a set of orphans. The projection recorder now writes it when a run succeeds or fails; the span id is derived from the run, so a resumed run writes the same span rather than a second one.
- PASS new suites: 8 `office_extraction` (fixtures are real ZIP archives written by Python's `zipfile`, not by the reader under test), 4 `trace_otlp`, 4 Graph connector tests including a paging link off `graph.microsoft.com` refused before the token could follow it.

30/08/26 — Feature 6.2 Task 6.2.1 Watchdog authorization, Feature 4.4 OneDrive configuration
- PASS `citadel_core/exigence` `npm test` — 780 tests, 660 pass, 120 emulator-only skip, 0 fail.
- PASS `citadel_core/palisade/authority` `dart analyze && dart test` — 48 pass after adding `platform.watchdog.read` and regenerating the exported catalogue. Invoker stays a strict superset of viewer but for the inventory scope, which the existing assertion proved when the new permission was first given to viewer alone.
- PASS `citadel_core/platform/server` `dart analyze && dart test` — 311 pass, including the new proxy operation and its project-match guard.
- PASS `citadel_platform` `flutter analyze && flutter test` — zero issues, 341 pass, including the two empty states that must not be confused (a quiet week versus a window with nothing in it) and the truncated report's floor.
- FOUND then RESOLVED — the Console could not register a OneDrive source at all: the runtime read Graph, the dialog offered three kinds and none of them was it, and no field existed for the Secret Manager reference the connector needs.
