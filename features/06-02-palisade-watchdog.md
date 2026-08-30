# Feature 6.2 — Palisade Watchdog (NEW 14/08/26)

## Scope
Project-wide security and reliability monitoring, maintaining visibility over
the client-project ↔ Citadel infrastructure boundary.

The first build covers the security capabilities required by Exigence,
Manifold, Baker Devstation and trusted local relay. ARM remains the shared
alert-delivery mechanism, but external attack, leak and policy-drift detection
are no longer deferred when they affect a Citadel data flow.

Depends on Feature 6.1.

## In scope for the first build (Exigence dependencies)

### Task 6.2.1 — Authorization anomaly detection
- Denied-permission and boundary-violation events from Palisade, aggregated per
  identity and per artifact.
- Surface an agent identity repeatedly attempting actions outside its authority.
  This is the primary safety signal for autonomous artifacts and Exigence has no
  other source for it.

### Task 6.2.2 — Boundary visibility
- Complete inventory of every path where client data crosses into or out of
  Citadel: cross-project IAM grants, service-to-service calls, egress
  destinations, local-runner connections.
- Flag any boundary crossing not declared in project configuration.

### Task 6.2.3 — Configuration threat detection
- Detect unsafe internal configuration: over-broad boundaries, unused but
  granted permissions, artifacts with `visual`-mode tools and no approval gate,
  identities with no expiry, secrets referenced but absent.
- Compare registry policy with deployed IAM, runtime/runner snapshots,
  Devstation state and configured provider scopes to detect policy drift.

### Task 6.2.4 — External and data-flow threat detection
- Detect forged/replayed ingress, repeated credential failures, abnormal relay
  volume/destinations, cross-project identifiers and undeclared egress.
- Maintain a complete inventory of data class, source, destination, direction,
  authority, volume and outcome for Manifold and data-relay paths.
- Alert on possible data leakage without copying sensitive payloads into the
  Watchdog event itself.

### Task 6.2.5 — KPI/SLO configuration for Exigence
- Configurable targets for artifact success rate, run latency, approval-cycle
  time, and budget-burn rate.
- Breach raises an alert through the same channel as ARM alerting — reuse, do
  not duplicate.

## Deferred to a later build
- General uptime and infrastructure SLO monitoring — ARM alerting territory.
- Security analytics not attached to an identified Citadel data flow.

Record any deferred item that later becomes an Exigence dependency, and pull it
forward rather than building a parallel mechanism inside Exigence.

## Definition of done
- [~] Denied permissions and boundary violations aggregate per identity and
      artifact — built for what the gate and the guardrails write: refusals,
      holds, escalations and blocks, over a window, grouped both ways
      (`exigence/src/watchdog_authorization.ts`, `platform.watchdog.read`,
      Palisade → Watchdog). **Runner boundary refusals are not in it yet**:
      those come back as evidence on the intent rather than as an audit event,
      so there is nothing for this to read. That is the next slice, and it is
      a gap in the source, not in the aggregation.
- [x] An agent exceeding its authority is visible without reading raw logs —
      the page ranks by breadth rather than volume, since an artifact denied
      one tool forty times is a configuration nobody finished and an artifact
      denied four different tools is one reaching for authority it never had.
      It reports how many runs it read, so "nothing refused" is a fact rather
      than an unasked question, and says when it was truncated.
- [ ] Every client↔Citadel boundary crossing is inventoried
- [ ] Undeclared boundary crossings are flagged
- [ ] Unsafe configuration patterns are detected from project state alone
- [ ] External attacks, leak indicators and policy drift are detected on critical flows
- [ ] Manifold and data-relay ingress/egress are visible without reading raw logs
- [ ] Exigence KPI/SLO breaches alert through the existing ARM alerting channel
- [ ] No alerting mechanism is duplicated from ARM
- [ ] Deferred scope is recorded, not silently dropped
