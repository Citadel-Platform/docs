# Feature set review — 30/08/26

A product-owner walkthrough of the Console against what was imagined, and the
reconciliation. Every entry says what was believed, what is actually there, and
which of the two survives.

The rule used throughout: **where the understanding is a product decision, the
understanding wins.** Where the actual build encodes a constraint the
understanding did not know about — usually a security or evidence property —
the constraint wins and the understanding is amended to fit it. Where both are
right about different things, they merge.

---

## ARM

### The vocabulary: Tickets, Case Logs, Issue Fingerprints

**Understood:** Tickets are opened by users or devs. Case Logs are
context/state/stacktrace bundles from ARM clients. Issue Fingerprints are
unique faults, linked to one or more Case Logs. Every Case Log has a parent
fingerprint. There is no such thing as an Incident.

**Actual:** Case Logs and Issue Fingerprints exist and are exactly that — the
ARM service stores `ArmIssueRecord` and `ArmCaseRecord`, and a case carries its
parent issue. **Tickets do not exist at all.** "Incidents" existed only as a
label on the Alerting page and in a few strings; nothing modelled an incident.

**Resolution: the understanding wins, and it has been applied.** "Incidents"
is gone from the Console — the panel is now *Issue fingerprints* and the
metric tiles are *Case logs* and *Issue fingerprints*. Tickets are a new
subsystem, specified below.

One thing the understanding did not say and the build enforces: a Case Log with
no parent fingerprint is not currently possible, because the fingerprint is
derived at capture. That is worth keeping as an invariant rather than a
validation.

### Duplicate suppression in the ARM client

**Understood:** the client should not send repeated Case Logs within a session.

**Actual:** not implemented. `runTracked` reports every handled exception it
sees.

**Resolution: the understanding wins.** Specified in Feature 1.1. The nuance to
preserve: suppression must be *per fingerprint per session*, and the suppressed
count must still be reported, or a loop erroring a thousand times looks
identical to one that erred once.

### Tickets — new

**Understood:** the ARM error dialog gains an "Open Support Ticket" button;
the end user supplies a contact number or email; that pegs the case log and
fingerprint to a person and a session. Tickets can also be opened manually.
Status is Open / Investigating / In Progress / Closed. A ticket carries title,
description, attachments and a timestamped, markdown, GitHub-issue-style
history that the end user and the developer both write into. Every ticket has
a public URL, with an optional email allowlist that closes it.

**Actual:** none of it.

**Resolution: build it as understood**, with one correction and one addition.

The correction is the access model. "Non-Citadel users are prompted for an
email address but no further verification" means anybody who knows an
allowlisted address can read the ticket, and a support ticket carries a stack
trace, a session and a customer's own words. Unverified email is not an
access control; it is a speed bump. Either the link is public — in which case
say so and keep sensitive evidence off it — or it is not, in which case a
one-time emailed code is the smallest thing that actually holds. Recommended:
**public-by-link tickets carry the conversation and no evidence; an
allowlisted ticket requires a code sent to the address.**

The addition is redaction. A case log attached to a ticket a customer can read
must go through the same redaction policy the Console applies, or the first
support ticket becomes the leak.

### Alerting (formerly Escalations)

**Understood:** rename; policies become auto-tagging rules with conditions
joined by AND/OR, assigning tags and triggering notification channels;
notification channels get their own table and form rather than a top-bar
button; snoozes are removed.

**Actual:** the page was already titled Alerting but routed at
`/arm/escalations`. Policies and channels were inline forms that showed a
snackbar and saved nothing; the policy form asked for a severity and a
destination. The Policies, Snoozes and Notification-channel tables were
hardcoded empty. Snoozes existed as a panel and a form.

**Resolution: the understanding wins, and most of it is applied.** Snoozes are
gone. Channels have their own table and a "New channel" button on it. The
policy form is now name → conditions → tags → channels, with a condition
builder, a tag field that creates what is typed, and a channel picker with a
way out to create one.

Two deliberate departures:

- **Nesting is not offered.** The reference image nests filter groups. The
  builder is flat and says so, because a builder that renders nesting the
  evaluator cannot evaluate is worse than one that admits it does not nest.
  Nesting is a later change to both halves at once.
- **Nothing saves.** ARM has no policy or channel store, so the button says
  *Review Policy* and the page carries a warning that nothing is stored. This
  is the honest state until the ARM service gains the routes.

Snoozes deserve their own note: removing them is right, and the reason is
worth recording. A snooze silences an alert without changing anything about
what raised it, which is exactly the mechanism by which a project stops
hearing about a fault that is still happening. Muting belongs in a policy's own
conditions, where it sits next to what it suppresses.

### Issue Fingerprints — tags

**Understood:** a Tags column showing policy-assigned and custom tags, with
custom tags assignable from the table.

**Actual:** no tags anywhere.

**Resolution: understanding wins, partly applied.** The column exists and the
model carries `tags`; an untagged fingerprint says "Untagged" rather than
showing an empty cell. Assignment needs the ARM store.

One merge: the understanding described policy tags and custom tags as two
things. They render as **one column**, because a person triaging a fault cares
that something is a regression, not whether a rule or a colleague said so.
Provenance belongs in the fingerprint's history.

### Case Logs — criticality

**Understood:** criticality changeable from a dropdown.

**Actual:** a read-only badge.

**Resolution: understanding wins, applied.** The column is now *Criticality*
and carries a dropdown that mirrors the status control. It writes for real in
the Firestore-backed path (stamped with who changed it and when, beside the
value rather than over it); the Platform-API path refuses with a stated reason
until the ARM service gains a severity route.

---

## Exigence

### Citadel MCPs in artifact runtimes

**Understood:** a checkbox on the artifact form enabling Citadel MCPs, with a
read-only / Palisade-guarded-full radio pair; enabling injects stdio/HTTP MCP
servers into the runtime and shows a copyable config snippet; the local runner
and localbridge become MCP-friendly so an artifact can read and act on the
client's machine.

**Actual:** none of it. Artifacts reach Citadel data through *tools* — typed,
policy-gated bindings (`manifold.correlate`, `localbridge.read`,
`knowledge_base.search`) — not through MCP. The gate resolves a tool's declared
permissions against the artifact's Palisade authority before the tool runs.

**Resolution: merge, and this is the important one.**

The goal is right and is not currently met: an artifact cannot reach a client's
own Citadel data as broadly as it should. But "read-only MCP access" as a
*mode* would sit beside a permission system that already answers that question
per tool, and the two would disagree. An artifact holding
`exigence.usercontext.read` and not `exigence.channels.write` already *is*
read-only, resolved per call and audited.

So: **expose Citadel's capabilities over MCP, and keep Palisade as the only
thing that decides.** The MCP server is a transport in front of the existing
tool gate rather than a second authorisation path. The checkbox stays; the
radio pair is replaced by the artifact's granted capabilities, which the form
already collects — because two places that both decide what an agent may do
is how an agent ends up able to do something nobody granted.

The snippet stays and is worth keeping: an operator who can copy a working
`CITADEL_MCP_SERVERS` block into their own LangGraph config is the whole point.

Localbridge over MCP is right and follows for free once the gate is behind an
MCP transport, because the localbridge tools are already tools.

### Agent Superharness runtime

**Understood:** a runtime-boilerplate choice on artifact creation — blank vs
Citadel Superharness — where the superharness ships MCPs, Citadel context
prompts, state/context management, long-horizon memory, RAG over the knowledge
base, over Manifold, over ARM, and headless-Chrome web access, so a creator
supplies only a prompt.

**Actual:** three artifact kinds exist (`reference`, `localReport`,
`reportTriage`), each a hand-written LangGraph graph selected by the published
revision. There is no boilerplate chooser, no memory layer, and RAG exists only
for the knowledge base.

**Resolution: understanding wins as direction.** It is the largest single item
in this review — realistically a feature of its own rather than a change to an
existing one. Specified as Feature 4.7.

One constraint from the build that the spec must respect: the runtime refuses
to run any artifact but the one it was deployed for, and every graph step is
gated and journalled. A superharness that let an agent choose its own next step
freely still runs each step through the gate — which is what makes "supply a
prompt and go" safe rather than reckless.

---

## Conduit

**Understood:** stays Flutter/Dart-heavy with JS only where unavoidable;
telemetry and metrics collection first, analytics later; focus on collecting
journeys, sessions and heatmaps properly.

**Actual:** this is already true and the feature files say otherwise — they
describe a JS UMD/ESM SDK, a GTM template, BigQuery streaming and Pub/Sub. The
build is a Flutter SDK and a Dart ingest service on Firestore. Fifty-three
definition-of-done boxes across Features 3.1–3.9 are written against the plan
that was not built.

**Resolution: the understanding wins and settles an open question.** Recorded
in `DECISIONS_NEEDED.md` (30/08/26); this review is the answer to it. Conduit
is Flutter-first with a Dart pipeline. The web-SDK and BigQuery items are
deferred, not outstanding, and Features 3.1–3.9 need their acceptance criteria
rewritten against the product that exists.

### Dashboard

**Understood:** remove the clutter; keep metrics, charts, summaries and
important numbers.

**Actual:** the overview page carries long descriptive panels about SDK
capability alongside the numbers.

**Resolution: understanding wins.** Not yet applied — specified in Feature 3.6.

### Touchpoints (formerly Instrumentation)

**Understood:** rename, and change the layout to toggles and config inputs for
the ingestion points, supporting multiple targets.

**Actual:** the page was a two-column reference card describing what the SDK
captures — accurate, and impossible to act on.

**Resolution: understanding wins, applied.** `/conduit/touchpoints` (the old
path redirects) now renders the project's real Conduit configuration as
toggles that write through the same document the ingest service reads: session
replay, heatmaps, synthetic probes and the feedback widget, with sampling,
consent, retention, masking and API-error rules shown beside them.

**Multiple targets is not applied and is the one gap.** The data model has a
project key per Conduit document, so several targets are storable, but nothing
creates or lists more than one per project. Specified in Feature 3.1.

---

## Baker

**Understood:** requires the project's GCP project ID; three tabs — Modules,
Deployments, Devstation — replacing the existing set.

**Actual:** Baker has launch, workspace, specs, modules and deployments routes
and no implementation behind them. Devstation is specified in Feature 5.3 and
unbuilt.

**Resolution: understanding wins wholesale.** The tab set is replaced as
described. Detail worth preserving from the understanding, because it is more
specific than the existing feature files:

- **Modules** is not project-scoped. It is an overview of the `baker-modules`
  repository: name, layer (frontend / middleware / backend), product or
  service, version, release date, with the version hyperlinked to its commit.
- **Deployments** is project-scoped and selector-driven: application, then
  environment (Dev / Test / Staging / Prod), then release version. Below,
  the Baker modules and versions that went into it, each linked back to
  Modules, plus the Git release information. It also carries rollout
  configuration (blue-green, canary) and the preview/beta audience list for
  Staging.
- **Devstation** provisions a GCE VM in the client's GCP project with a
  standard image (Docker, Flutter, Chrome, Git), persistent storage, IAM to
  act as a developer, and coding CLI agents installed; the page carries
  configuration, status and the SSH connection details.

The GCP-project-ID precondition is right and should be enforced as a guard on
the whole product surface, not a validation inside each tab.

---

## Palisade

### Access

**Understood:** shows which users, owners, developers, agents and artifacts
have access to the project and in what capacity.

**Actual:** exactly this. **No change.**

### Boundaries

**Understood:** make the form clearer about what each input does, without
being informal or over-explaining, and lay it out better.

**Actual:** the form had three unlabelled-purpose fields and a one-line hint.

**Resolution: understanding wins, applied.** The dialog now states what the
boundary being published decides, that a revision is immutable and that
deployed artifacts keep their pin; each field carries a helper; and the rule
grammar — deny wins, unmatched is denied, how `*` and `**` differ between paths
and URLs — is stated rather than assumed.

### Your Authority

**Understood:** remove it.

**Actual:** it existed as a tab and page.

**Resolution: understanding wins, applied.** Removed. Worth noting what is
lost: it answered "why is this button missing" for the signed-in operator. The
Access page answers it for everybody, which is a superset, so nothing is
actually gone.

### Watchdog

**Understood:** an all-round security ringfence — scans GCP IAM and infra
config for over-granting and security flaws, scans codebase and deployed
service configuration for gaps. Essentially a metrics screen.

**Actual:** substantially more than a metrics screen, and pointed elsewhere.
It detects authority anomalies from ARM and runtime audit records, unsafe
project configuration, boundary drift against published revisions, refused
ingress at the public webhook, egress against declared destinations, secret
references that have gone missing, and a full boundary inventory. What it does
**not** do is scan GCP IAM or a codebase.

**Resolution: both, and this is the one place the understanding under-describes
what is there.** The existing detectors stay — every one of them is a real
client↔Citadel data-flow risk that a GCP IAM scan would not find. The
understanding adds two genuinely missing sources, both already named as
uncovered in Feature 6.2: **registry-versus-deployed-IAM drift**, and
**deployed service configuration**. Codebase scanning is new scope and belongs
with Baker, which is the thing that has a codebase.

The "metrics screen" framing is worth taking partly: the page is now long and
reads as a list of tables. A summary band that says how many findings of each
kind, above the detail, would make it answerable at a glance.

### Roles

**Understood:** no section per role; a table with multi-select permission
values, allowing custom roles; Viewer, Invoker and Superdev locked.

**Actual:** a panel per role, read-only, from the catalogue.

**Resolution: understanding wins, partly applied.** The page is now a table:
role, what it grants, and whether it is editable. The built-in three are marked
"Built in" and are locked, which is right for a stronger reason than the
understanding gave — they are what the API's own permission map is written
against, so editing one would change what every route means without any route
knowing.

Custom roles are **not** applied and cannot be until they have a store:
`resolveEffectiveAuthority` resolves `roleIds` against the built-in catalogue,
so a role created today could not be granted to anybody. The "New role" button
is present and disabled with that reason on it.

---

## Manifold

### Inbox

**Understood:** view the latest state of communications at a glance.

**Actual:** exactly this. **No change.**

### Channels → Communication Lines

**Understood:** no revisions per channel; one table of Communication Lines,
each differentiated by number or email address, each of a type (WhatsApp,
Email, more later) with a status; "Publish Revision" becomes "Add Line".

**Actual:** a table with one row per channel *revision*, columns Channel /
Number / Revision / State, and a "Publish revision" button.

**Resolution: merge, and it is applied.** The table is now Communication
Lines: one row per line, columns Line / Channel / Address / Status, and the
button says "Add line". The dialog is "Add WhatsApp line".

The merge is on revisions. They are not shown as rows any more — that was the
real complaint, and one number appearing three times as three channels is
indefensible. But they are not removed: a channel's configuration is immutable
by design, because a mutable channel record means anybody who can write it can
point a client's number at their own token. The revision is now a small line
under the name, which is what you need when something stops working and
nothing else.

Email as a line type is genuinely new — only WhatsApp exists — and is
specified in Feature 7.1.
