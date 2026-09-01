# Feature 0.8 — Platform Alerting and Notification Tracking (NEW 31/08/26)

## Status
**Tasks 0.8.1–0.8.4 built 01/09/26**, with the Watchdog and Conduit as the two
producers. 0.8.5 (retention) is not built: Firestore TTL on an expiry field is
the mechanism, and nothing sets the field yet.

Delivery arrived earlier than "later" said it would, because the 31/08/26
Watchdog decision needed it and email was already proven: the digest reads the
same store and sends only what a sweep newly found. It is additive exactly as
this file said it would be — no producer emits to a channel.

## Why this exists
Three services independently reached the same wall. Conduit alert rules
evaluate and produce findings that go nowhere (Feature 3.7). Exigence breached
objectives have the same gap (Feature 4.3). ARM alerting (Feature 1.4) is
specified against Slack webhooks and a Pub/Sub topic that do not exist.

Each was written as though the missing piece were a *delivery channel*. It is
not. **Citadel has no alerting service at all**, and the first one is tracking
and display, not delivery. A client who cannot see an alert anywhere is the
actual failure; choosing a channel now would pick a credential story — webhook
secrets, sending domains, verified DNS — that is not settled and is not needed
to make alerts visible.

Hard rule #11 applies: one mechanism every producer moves onto, not three
emitters.

## Scope
A core Platform service that records alerts and notifications from every
Citadel service and displays them together on the Citadel Dashboard.

**In scope:** the alert record, the write path producers use, retention, the
Dashboard surface, acknowledge/resolve state.

**Out of scope, deliberately:** Firebase Cloud Messaging, email or SMS
delivery, Slack webhooks, Pub/Sub fan-out. These are later additions *on top of
the same store*, never a parallel path. No producer emits to a channel
directly.

## Tasks

### Task 0.8.1 — Alert record and contract
One shape for every producer:

- `alertId`, `projectId`, `service` (`arm` | `conduit` | `exigence` |
  `manifold` | `baker` | `platform`), `ruleId`, `ruleLabel`
- `severity`, `status` (`firing` | `acknowledged` | `resolved`)
- `summary`, `metric`, `threshold`, `observedValue`
- `firstSeenAt`, `lastSeenAt`, `resolvedAt?`, `occurrenceCount`
- `deepLink` — the Console route that shows the evidence (a Conduit session
  list, an ARM issue, an Exigence run)
- `sourceRef` — the producing record, so an alert can always be traced back

Repeat firings of one rule increment `occurrenceCount` and move `lastSeenAt`
rather than creating rows; an alert list that repeats itself is one nobody
reads. Fields align to OpenTelemetry conventions where they have an equivalent,
per the standing guardrail.

### Task 0.8.2 — Store and residency
Citadel-owned Firestore, `platform_alerts/{projectId}/entries/{alertId}`, with
alert *state* Citadel-side and the evidence it points at staying in the client
boundary where it already lives. Conduit alert rules and events already sit
Citadel-side (`conduit_alerts`, `conduit_alert_events`, DECISIONS.md), so this
is consistent rather than a new boundary.

`conduit_alert_events` folds into this store rather than being mirrored into
it — per hard rule #11, one store, not two shapes kept in sync. **Done
01/09/26**: the collection, its model, its codecs, its security-rules match and
the Console page that read it are removed, so there is one store and one
surface rather than a store and a page that could disagree.

### Task 0.8.3 — Producer write path
A shared client in `citadel_core/platform` that each service calls when a rule
fires or resolves. Idempotent on `(projectId, service, ruleId, window)` so a
re-evaluated rule does not duplicate. Producers do not read the store; they
write and stop.

### Task 0.8.4 — Dashboard surface
The Citadel Dashboard page shows all services' alerts for the selected project:
firing first, then acknowledged, then recently resolved. Filter by service,
severity and status. Each row carries its deep link. Acknowledge and resolve
are actions on the row. Explicit empty state — "no alerts" is a real answer and
must not look like a failed load.

Alerts also surface as a count on the service tiles, so a project with a firing
Conduit alert reads as such before anything is opened.

### Task 0.8.5 — Retention
Configurable per project, defaulting to the project's telemetry retention.
Resolved alerts age out; firing alerts never do.

## Later — delivery
Firebase Cloud Messaging for Console/push, or a mailing provider for email
digests, reading the same store. Both are additive and neither changes the
producer contract. Manifold, once scheduled, is the natural surface for
client-facing notification, and it too reads the store rather than receiving a
separate feed.

## Definition of done
- [x] One alert record shape, written by two services — the Watchdog
      (`platform`) and Conduit — with repeat firings folded rather than
      duplicated, and a resolved alert whose condition returns firing again in
      place. **ARM is not yet a producer**; its alerting is still specified
      against a Slack webhook that does not exist, and moving it onto this store
      is the next producer rather than a gap in the store.
- [x] The Dashboard shows every service's alerts for a project, with filters,
      deep links, acknowledge and resolve
- [x] An empty state that is distinguishable from a failed load
- [x] Conduit's evaluated rules reach the store — and evaluation itself had to
      be built first: nothing had ever measured a rule
- [ ] Retention honoured by TTL, not by policy prose. Not built: the expiry
      field is not written and no TTL policy is declared.
- [ ] Driven in a browser against emulator data, not only unit-tested
