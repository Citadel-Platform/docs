# Handoff — 01/09/26, the four decisions acted on

All four questions in `DECISIONS_NEEDED.md` 01/09/26 came back answered and
were built the same day. Read `CURRENT_TASK.md` first — its 01/09/26 section is
item-by-item — then `DECISIONS.md` 01/09/26 for what was decided, then
`DECISIONS_NEEDED.md`, which is now one question and two findings.

## What this session did

**Country resolution exists as infrastructure with no database in it.** The
catalogue of three candidates carries each licence's exact terms and verbatim
attribution; the parser and range resolver answer from the truncated address
ingest actually stores; the deployment names which file it carries and prints
it at start; the Console switch is per project and does not move until the
operator has been shown the licence and offered the whole obligation as a file.
What is stored is who accepted it, when, and which database. No file is
bundled, because no licence has been taken — that is procurement and it is the
last thing on Conduit C0.

**`conduit_alert_events` is gone rather than repointed.** Model, codecs,
collection constant, `ConduitAlertStatus`, the security-rules match and the
Console's whole read path. The Conduit alerts page keeps its rules and probes;
its history panel points at the Dashboard, which is the one alert surface.

**Dead-click detection was confirmed as built** — off by default, two
tenth-scale frames per watched interaction, a project that is not looking
records none.

**The retired clients' infrastructure is actually gone now.** `AGENTS.md` said
it had been deleted on 29/08/26. It had not: five Cloud Run services were
running and being billed. Three Terraform roots destroyed, seventy-five
resources, nothing the live `demo-project` uses touched, every shared API still
enabled.

## Three things worth knowing before you touch anything

**1. Cloud Run's `deletion_protection` is a Terraform-only field.** It is not
in the Cloud Run v2 API. `gcloud run services update --no-deletion-protection`
does not exist and a PATCH on `deletionProtection` is rejected as an unknown
field — the provider reads it from *prior state* when it plans a destroy. The
only ways to move it are a config-driven apply or an edit to the state.

**2. `templates/exigence-agent/` is an empty directory.** The state at
`provisioner/exigence-agent/demo-sandbox/agent.invoice-triage` was applied from
a template that lives in an image and nowhere else. It was destroyed from a
decommission-only root — backend and provider, no resources, so everything in
state plans as an orphan. Whatever built `cit-demo-sandbox-de61-agent` cannot
currently be rebuilt.

**3. A destroy does not take the client's database.** The runtime template sets
`deletion_policy = ABANDON` while `deletion_protection` is on, deliberately, so
`demo-sandbox` and `exigence-lab` are two Firestore databases standing with
nothing owning them. That is the one open question.

## Where to pick up

1. **Deploy the Platform API with the alert store**, run a sweep against
   `demo-project`, and put a real finding on the Dashboard and in an inbox.
   Still the one thing that turns Feature 0.8 from tested into true, and it did
   not move today.
2. **Obtain a geo database** under one of the three licences and put it in the
   ingest image with `CITADEL_CONDUIT_GEO_DATABASE` and
   `CITADEL_CONDUIT_GEO_DATABASE_ID`. Everything either side of the file is
   built and tested.
3. **Conduit C1, incremental rollups.** Everything in Layer 2 and 3 waits on
   it, and it removes the read-cost cliff.
4. Untouched from the previous handoff: Baker's Devstation VM (Feature 5.3), a
   successful `tools/call` over MCP against a started run, and driving any of
   it in a browser.

---

# Handoff — 01/09/26 04:40

Written after an unattended overnight run against the previous handoff's
"Where to pick up". Read `CURRENT_TASK.md` first — its 01/09/26 section is the
item-by-item state — then `DECISIONS_NEEDED.md` 01/09/26, which is the four
questions the run stopped at.

## What this session did

Non-Conduit first, as instructed, then Conduit C0.

    citadel_core/exigence   99b50e1  The Superharness, as a runtime (4.7.2)
                            ad5a207  Measure egress against what was published
                            48f7a89  The forward migration for an old client
    citadel_core            d51e707  One alerting service (Feature 0.8)
                            eaec041  The sweep files Conduit's findings too
    citadel_platform        f0c963c  The Dashboard shows what every service found
    citadel_core/conduit    abfb531  Cadence at the edge, dead clicks observed
                            3b50422  Alert rules that are actually measured

Gates in `_dev/test_status.md`. Nothing is deployed.

## Where to pick up

1. **Deploy the Platform API with the alert store**, run a sweep against
   `demo-project`, and put a real finding on the Dashboard and in an inbox.
   That is the one thing that turns Feature 0.8 from tested into true.
2. **Answer the four questions** in `DECISIONS_NEEDED.md` 01/09/26 — the GeoIP
   licence blocks Conduit's last C0 item.
3. **Conduit C1, incremental rollups.** Everything in Layer 2 and 3 waits on
   it, and it removes the read-cost cliff.
4. The pick-up items from the previous handoff that this run did not touch:
   Baker's Devstation VM (Feature 5.3), a successful `tools/call` over MCP
   against a started run, and driving any of it in a browser.

## Three things worth knowing before you touch anything

**1. `conduit_alert_events` is dead.** Conduit evaluates rules and returns
findings; the platform alert store records them. Nothing writes that
collection, and the Conduit alerts page still reads it — see the third question
in `DECISIONS_NEEDED.md`.

**2. Dead-click detection changed meaning.** It was the app's own
`isInteractive` flag; it is now a repaint-and-route observation, off by
default, and a project that is not looking records none rather than zero.

**3. A sweep is a POST, deliberately.** Opening the Watchdog does not create
alerts. If reading a page filed findings, the record of what Citadel found
would depend on who happened to look.

---

# Handoff — 31/08/26 13:45 (previous)

Written after an unattended overnight run against the 30/08/26 feature-set
review, plus the morning's work on the email transport once it was decided. Read `_dev/docs/feature_set_review_30_08_26.md` first: it is the
reconciliation between the product owner's understanding and the build, and it
wins over older feature files wherever they disagree. Then `CURRENT_TASK.md`,
whose "Active task (31/08/26)" section is the item-by-item state.

## What this session did

Everything the review left outstanding is built, and the one decision that
blocked two features has been made and acted on. Thirty-eight commits across
five repositories, every gate green:

    citadel_core/arm        493ea55  Tickets: a fault nobody could name…
                            01ae6b6  Attribute a customer's ticket entry…
    citadel_core            03bd255  Serve the ticket routes, the deployment scan…
                            f62888a  Serve a ticket to the person waiting on it
                            71a299d  Baker: a catalogue, a deployment record…
                            61fadec  Index the Factory's modules from a clone
                            905eaeb  Record whether a runtime speaks MCP…
                            7dbafed  Email as a line type, and honest about…
    citadel_core/exigence   5eeab15  Speak Citadel's tools over MCP
                            65806d6  The Superharness, as a scaffold…
    citadel_core/conduit    fb994df  Capture a project from more than one place
    citadel_platform        28c3819  Work a ticket, scan a deployment…
                            d7d7129  A ticket page for somebody who is not signed in
                            bf9f874  Baker's three tabs
                            6b7dfd8  Switch Citadel MCPs on, and say what that does not do
                            5664199  List an email line beside the number
                            2243e5c  Say how much of each kind, before any of it
                            566351a  Wire Baker and email lines into the local harness

…then, after **Resend was chosen as the email transport (31/08/26)**:

    citadel_core            bc2655a  Prove an address on a ticket's allowlist with a code
                            71b4db7  Check an email line's credentials, and let it be switched on
                            876a7cd  Bound what a ticket link can write
                            bc828e5  Stop a ticket link replying as fast as HTTP allows
                            73d3797  Pin what Baker reads when there is nothing to read
    citadel_core/arm        f132aa9  Never suppress a capture somebody asked for
                            ec64949  Exercise the ticket store through the client the runtime uses
                            5b9e8e4  Prove the ticket join against real Firestore
    citadel_core/exigence   d024aa2  Carry a Manifold email line, in and out
                            657495e  Resolve a published email line into something that can send
                            0151c2c  Offer the email line to a graph, beside the number
                            740b7c1  Receive on an email line
    citadel_platform        3a885a1  Ask a private ticket for a code, then read it
                            38d486c  Publish an email line switched on, or not
                            1d12cb8  Say on the case log when somebody wrote in about it
                            570bfb3  Open a ticket from the fault, and filter by status
                            4b08c0f  Count the people waiting, beside the faults
                            be5d112  Put the Console's ticket client and the API's routes in one test
                            8dd0427  Put the Console's Baker client and the Baker routes in one test

Gates: 173 CLI, 31 platform API, 382 platform server, 32 ARM service, 10 ARM
tooling, 8 ARM tooling-core, 101 Conduit ingest, 752 Exigence (123 skipped,
emulator-gated), 389 Console. `dart analyze` and `flutter analyze` clean in
every package; the Console builds for web from both entry points.

## The standing instruction this ran under

*Where a feature needs a decision the owner has not made, build everything
around it and leave the deciding seam open rather than guessing.* That produced
five deliberate seams. Each is small, named in code, and reported to the user
rather than hidden:

1. ~~**Email transport.**~~ **Decided 31/08/26: Resend**, and both features
   are built — ticket access codes and sessions, Manifold email lines sending
   and receiving. What is left is deployment, not code: the Platform API needs
   `CITADEL_RESEND_API_KEY_SECRET` (or `RESEND_API_KEY` for a local run),
   `CITADEL_TICKET_FROM_ADDRESS` and `CITADEL_TICKET_TOKEN_SECRET`; the
   Exigence runtime needs building with `emailChannels`, `emailFetch` and the
   inbound endpoint mounted, which is the same deployment decision that gates
   the WhatsApp webhook. Until a runtime carries email, a published line
   refuses at the moment of sending, by name.
2. **The MCP endpoint's own authentication.** `citadel_mcp_server.ts` and both
   its transports exist and are tested; nothing mounts them. A creator's own
   LangGraph process calling in has to prove which run it is calling for, and
   that is an authentication decision rather than wiring.
3. **Baker's VM provisioner.** `operateDevstationWith` is absent, so start,
   stop and destroy answer "this deployment cannot act". Feature 5.3 is where
   the Terraform belongs.
4. **Baker's GitHub access.** `tool/index_baker_modules.dart` indexes a local
   clone. Whoever decides the Platform API may hold a GitHub credential
   replaces the directory walk and nothing else.
5. **`provisionedMembers` for deployment drift.** Nothing records what
   Terraform created per project, so member-level drift is reported as unknown
   rather than every binding being called unexpected.

## Three things worth knowing before you touch anything

**1. A refusal is a value, everywhere.** The MCP server returns denials as tool
results, the ticket routes answer a restricted ticket with what would be
needed, the Watchdog band says "not read" rather than counting zero, and the
Devstation page says the state is what Citadel asked for rather than what
Compute reports. If you add a surface, the question to ask is not "what does it
show when it works" but "what does it show when it could not look".

**2. The public ticket route is the only unauthenticated surface on the
Platform API**, and it now has four verbs. `GET /v1/public/tickets/{p}/{t}`
serves `armPublicTicketView` — the conversation, never the case ids, the
fingerprint, the session or the reporter's address, *whether or not the reader
proved an address*, because the allowlist decides who may read the conversation
and not what evidence is disclosed. `POST …/verify` sends a code and answers
identically whether or not the address is on the allowlist. `POST …/session`
exchanges a code for a token bound to that one ticket. `POST …/updates` is the
reply. Its reply write is capped at
5,000 characters against the ticket's own 500-entry cap, and limited to twenty
replies per ticket per hour **per instance** — partial on purpose, because
counting it in Firestore would let anybody with a link spend a client's money
on writes to find out they were refused. A cross-instance limit is the gap that
remains. Do not add a second
unauthenticated route without re-reading that one.

**3. Baker is superdev-only, all five permissions.** It is Citadel's build
system, not something a client is sold: the module catalogue is the supply
chain, deployments name the module versions inside a client's application, and
the Devstation acts as a developer on the client's project.

## What is unproven

The same distinction Phase R cost five production defects to learn: **the tests
cover each layer, not the joins.** Updated 31/08/26: the API and the Console
*are* now deployed, and two of the items below moved as a result. What is still
outward-facing and untouched is a person in a browser, and a real email.
Specifically unproven end to end:

- The ticket routes under a real Firebase ID token. **The store join is now
  proven**: `citadel_core/arm/citadel_arm_service/test/arm_ticket_emulator_test.dart`
  writes a ticket with the SDK's own document builder and reads, lists and
  works it through the service against the Firestore emulator. What remains
  unproven above that is a real Firebase token and a deployed service: the
  Console's client and the API's routes are now put together in-process by
  `citadel_platform/test/platform_ticket_seam_test.dart`, which is what pins
  the paths, methods and envelopes the two sides agree on.
- ~~The public ticket page against the deployed API, including CORS from the
  Console origin.~~ **Half proven 31/08/26.** The API is deployed, the Console
  is live at `https://citadel-platform.web.app`, an OPTIONS preflight from that
  origin is allowed by the deployed service, and the public ticket route
  answers `notFound` on an unknown ticket rather than "no route matches" — the
  difference between a route that exists and one built after the last deploy.
  What is unproven is the page itself with a real ticket in front of a person.
- Baker's three tabs against real registry documents. The Console-to-route seam
  is pinned in-process (`platform_baker_seam_test.dart`); what is unproven is
  the Firestore side. `bakerCatalogue`,
  `bakerDeployments` and `bakerDevstations` do not exist in any project yet;
  every tab renders its own "nothing recorded" state until something writes
  them, which is correct and is also why nothing has exercised the read path.
- The MCP server against a real LangGraph client, for the reason in seam 2.
- **Nothing has sent a real email**, and nothing can until a domain exists. The
  Resend sender, the Manifold channel and the credential verifier are all
  driven through injected transports; no test reaches `api.resend.com`, and no
  code has been delivered to an inbox. The deployed service holds the API key
  and the signing salt but deliberately no from-address, because
  `GET /domains` on the Resend account returns an empty list.
- **The inbound endpoint has never received a real Svix delivery.** Its
  signature check is tested against signatures this repository generates, which
  proves the algorithm and not the provider's spelling of it.

## Where to pick up

Rewritten 31/08/26, end of day.

1. **Back-fill an artifact revision for every client the old runtime built,
   before upgrading any of them.** Settled 31/08/26: the new image's bootstrap
   writes `exigence_artifact_revisions` and the old one never did, so a client
   built by the old image cannot start the new one. `demo-project` is already
   migrated (its control plane was wiped and rebuilt, which is the test-client
   equivalent). `demo-sandbox` is not. `ensureInitialArtifactRevision` already
   publishes the right bundle and refuses to publish over a revision it cannot
   read, so the backfill is that function run per client rather than new code.

2. **Deliver Watchdog findings.** Decided 31/08/26: delivery belongs to the
   Watchdog rather than to Exigence, and email is proven, so the transport
   exists. Five detectors produce findings today and none of them reaches
   anybody. Severity-thresholded, per project, to the operators on it. This
   closes most of Feature 1.4 and the last bullet of 6.2.5 at once.

3. **Exercise MCP with a real run.** The endpoint is live on
   `cit-demo-project-5ec5-runtime` and its three refusals are proven in
   production; what has not been driven is a successful `tools/call` against a
   run that exists, which needs a run started on that runtime first.

4. **The rest of Feature 4.7** — the Superharness runtime, Localbridge over
   MCP, the snippet pasted into a real LangGraph project.

5. **`obsivision.com`** is `pending` at Resend with all three DNS records
   resolving; verification is asynchronous on their side. Once `verified`, set
   `ticket_from_address` and a client line sends from a real domain.

6. **The undeclared-egress detector.** The declaration it measures against is
   published, versioned, rendered and exercised; the comparison is not written.

7. **The Devstation VM** (Feature 5.3), approved to provision, test and destroy.

8. **Drive it in a browser.** Two live hosts, CORS proven from both, nobody has
   clicked anything.

## What the deployed service actually does

Worth reading before assuming anything about it.

- `citadel-platform-api` revision `00029-gjg`, image `sha256:a2fc16e9`.
- It holds `CITADEL_RESEND_API_KEY_SECRET` (a pinned Secret Manager version)
  and `CITADEL_TICKET_TOKEN_SECRET` (mounted from Secret Manager, so the salt
  is in neither Terraform state nor a saved plan). Sessions can be minted and
  believed.
- It does **not** hold `CITADEL_TICKET_FROM_ADDRESS`, on purpose. Nothing can
  send until a domain is verified.
- `GET /healthz` answers Google's own 404 through the front end even though the
  container serves it and the startup probe passes on it. Unmatched application
  routes answer JSON `notFound`; use one of those to tell "deployed" from
  "reachable", not `/healthz`.
- The image build needs `arm/` in the Cloud Build context. It is gitignored in
  `citadel_core` because it is a separate repository, so
  `citadel_core/.gcloudignore` re-includes it. Removing that file breaks the
  build at a `COPY`, not at a test.
- Artifact Registry has **tag immutability on**. Reusing a tag fails the push
  after ten retries; give every build its own tag. Tags so far:
  `v20260831-2` … `v20260831-4`.
- **To call the deployed API as a person**, not just to prove a route exists:
  `source citadel_core/.env && bash _dev/scripts/mint_operator_id_token.sh`.
  It signs a Firebase custom token with the admin identity the operator holds
  `serviceAccountTokenCreator` on, then exchanges it through Identity Toolkit.
  No service account key is downloaded and none should be.
- The boundary inventory route is `/palisade/boundary-inventory`, not
  `/palisade/inventory`. The second answers `notFound` and looks like a
  deployment problem.
- **The provisioner bakes its Terraform templates into its image.** Editing a
  template in the repository changes nothing until the image is rebuilt and the
  `provisioner` root applied; nothing compares the two, so the drift is silent
  until a plan fails on a variable that has existed for days.
- The client runtime image is pinned in
  `platform/infra/environments/production/provisioner/main.tf`, as
  `CITADEL_TEMPLATE_DEFAULTS.container_image`, not in a tfvars file.
- Client runtimes live in the **client's** Google Cloud project, not in
  `citadel-platform`.
- A provisioning job reporting `applied` proves nothing on its own. Check the
  plan: an empty one — 0 to add, 0 to change, 0 to destroy — reports `applied`
  having done nothing, which is exactly what happens after a failed apply has
  already written the new spec. Read the Cloud Run revision list instead.
