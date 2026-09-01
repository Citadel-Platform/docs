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
  **data-handling rules with no expiry**, secrets referenced but absent.

  > Amended 31/08/26. This bullet read "identities with no expiry", which was
  > unwritable: no `Identity` and no `Grant` carries an expiry, so the detector
  > would have flagged every identity in every project. Expiry exists in
  > Palisade exactly once, on `DataHandlingRule.expiresAt`, and that is where a
  > lapse means something. See `DECISIONS.md`, 31/08/26.
  >
  > **Built 31/08/26.** `reviewPolicyExpiry` reports rules nobody dated and
  > rules whose date has passed, weighted by what they permit: third-party
  > relay high, Citadel relay medium, in-situ low, and an undated *denial* not
  > reported at all — the safe direction is noise on a page that has to stay
  > readable to be read. An expired rule is reported whatever it permits,
  > because a published policy and an approved policy that are no longer the
  > same document is the finding. Served at
  > `GET /v1/projects/{id}/palisade/policy-expiry`, live in production.
  > **Not yet rendered in the Console.**
- Compare registry policy with deployed IAM, runtime/runner snapshots,
  Devstation state and configured provider scopes to detect policy drift.

### Task 6.2.4 — External and data-flow threat detection
- Detect forged/replayed ingress, repeated credential failures, abnormal relay
  volume/destinations, cross-project identifiers and undeclared egress.

  > **Resolved 31/08/26 — the declaration is published, not deployed.** The
  > destination list used to be a deployment environment variable, which meant
  > changing it was a redeploy and no operator could see it: a detector fed by
  > it could only ever be as current as the last release. It is now
  > `RelayDestinationDeclaration` — immutable, revisioned and digest-pinned on
  > the same terms as a boundary, held in the registry beside them. Each
  > destination carries a **purpose**, required, because a destination nobody
  > can justify in a sentence is one nobody should have approved and it is the
  > text an auditor reads. Publishing sits on `platform.boundaries.update` and
  > reading on `platform.watchdog.read`: the right to see a finding is not the
  > right to approve what it measures.
  >
  > The obvious alternative — reuse the Data Handling Boundary's relay targets
  > — was rejected as a category error: those are URL match patterns, because
  > they gate a runner sending a *file* to a *URL*, while an audit entry names
  > the thing that received the data. The version that "worked" would have been
  > one that silently matched nothing.
  >
  > Proven in production: a declaration for `axis-education` naming whatsapp,
  > resend and vertex; republishing revision 1 refused with `revision must be
  > 2`; the boundary inventory now names each crossing as `declaration revision
  > 1` where it used to say the project declared nothing.
  > **Not yet rendered in the Console**, and the detector that compares an
  > audit against it is still to be written — this is the half that was
  > missing, not the whole check.
- Maintain a complete inventory of data class, source, destination, direction,
  authority, volume and outcome for Manifold and data-relay paths.
- Alert on possible data leakage without copying sensitive payloads into the
  Watchdog event itself.

### Task 6.2.5 — KPI/SLO configuration for Exigence
- Configurable targets for artifact success rate, run latency, approval-cycle
  time, and budget-burn rate.
- Breach raises an alert through the same channel as ARM alerting — reuse, do
  not duplicate.

  > **Amended 31/08/26.** Not ARM. ARM alerting is about the client's own
  > product — the issues and cases their customers hit — and it is a Console
  > view rather than an ingest a service can post into, which is why the reuse
  > was never possible as written. A budget burning down is Citadel's
  > operators' problem, and routing it through ARM would file an internal
  > finding in a customer-facing record.
  >
  > **Delivery is a Watchdog concern.** Every detector on this page produces
  > findings and not one of them reaches anybody; a breached objective is the
  > loudest case, not a special one. So what gets built is one delivery path
  > for Watchdog findings — severity-thresholded, per project, to the operators
  > on it — which is the reuse the bullet was reaching for. Citadel can now
  > send email, proven end to end on 31/08/26, so the transport exists.
  >
  > **Not built.** The measurement is; the delivery is not.

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
      Palisade → Watchdog), including runner boundary refusals: a tool binding
      names the refusal in its own result and the graph step recognises the
      runner's evidence envelope, so a path refused on the client's machine is
      an audit event rather than a value buried in one activity's payload.
- [x] An agent exceeding its authority is visible without reading raw logs —
      from both records: what its tool calls ran into inside a run, and what
      its identity ran into asking the Platform API (`detectAuthorityAnomalies`
      existed with tests and no route; it now has one, and a page). —
      the page ranks by breadth rather than volume, since an artifact denied
      one tool forty times is a configuration nobody finished and an artifact
      denied four different tools is one reaching for authority it never had.
      It reports how many runs it read, so "nothing refused" is a fact rather
      than an unasked question, and says when it was truncated.
- [~] Every client↔Citadel boundary crossing is inventoried — assembled in the
      control plane, which is the only place that can see all of them
      (`palisade_boundary_inventory.dart`, `platform.watchdog.read`, `GET
      /v1/projects/{id}/palisade/boundary-inventory`, rendered first on the
      Watchdog). From declarations rather than traffic: a webhook that has
      never received a delivery is still a webhook, and an inventory built
      from what crossed would omit the paths nobody watches. Every source is
      optional and an unread one is named in `unavailable` rather than
      shortening the list, so a partial inventory never reads as a small
      boundary. **Covered and wired:** published channels, local runners
      (`LocalbridgeService.listRunners`, secrets never returned and a revoked
      credential reported disabled rather than omitted), and the control
      plane's own calls into a client's runtime, read from the same project
      document that routes them. **Not wired:** declared relay destinations,
      which the control plane does not hold — where that declaration should
      live is recorded in `DECISIONS_NEEDED.md` (30/08/26) — and cross-project
      IAM beyond the receiver's secret bindings.
- [~] Undeclared boundary crossings are flagged — in two places, and they are
      different questions. A crossing in the inventory that nothing declares
      is reported in the same column as one that is declared, because it is
      the same path with nobody's name against it; and egress to a destination
      no declaration names is a finding in the relay view.
- [~] Unsafe configuration patterns are detected from project state alone —
      four checks built (`exigence/src/watchdog_configuration.ts`), each
      reported by its consequence rather than a severity alone: a visual-mode
      tool with no approval gate, a tool an artifact declares that the project
      does not allow, an enabled artifact with no cap of its own, and a
      capability nothing declares. Secrets referenced but absent are now
      covered from the control plane rather than the runtime, which is where
      the reader is: `palisade_secret_watchdog.dart` probes every secret the
      project's latest channel revisions name, and the receiver's
      `secretAccessor` binding on each, at `platform.watchdog.read` through
      `GET /v1/projects/{id}/palisade/secrets`, rendered as Secrets on the
      Watchdog. It reuses the verifier's readers rather than acquiring its
      own, and a deployment that cannot read Secret Manager says so instead of
      reporting nothing missing. **Not covered:** identities with no expiry,
      which is not a check that can be written — neither `Identity` nor
      `Grant` carries an expiry, so the check would flag every identity in
      every project (recorded in `DECISIONS_NEEDED.md`, 30/08/26); and policy
      drift against deployed IAM beyond the secret bindings above, which
      belongs with the inventory observer rather than here.
- [~] External attacks, leak indicators and policy drift are detected on
      critical flows — forged and replayed ingress is now counted where before
      it existed only as a log line: the WhatsApp endpoint names a kind for
      every refusal and the runtime counts them into hourly buckets per
      channel and kind (`exigence/src/ingress_refusals.ts`), read over a
      window through `/exigence/watchdog/ingress` and the proxy. Bucketed
      because the writer is public: one document per request would let anybody
      with the URL run up a client's Firestore bill, so each instance stops at
      a ceiling and the report says its count is a floor. Boundary drift
      against published revisions is detected in the Console (Feature 6.1).
      Refusals now render on the Watchdog beside the crossings that did
      happen, per channel and kind, with a truncated channel's total shown as
      "at least n" rather than as a count.
      Abnormal relay volume, new destinations, undeclared egress and
      cross-project identifiers are detected in `watchdog_relay.ts`, read over
      a window through `/exigence/watchdog/relay` and the proxy, and rendered
      on the Watchdog as Egress. Every judgement is against this project's own
      recent past rather than a threshold — there is no number that is "a lot
      of records" for every project — and the declaration it is judged
      against is configured per deployment rather than defaulted, so a runtime
      nobody configured says it cannot answer instead of reporting a correct
      project as leaking.
- [~] Manifold and data-relay ingress/egress are visible without reading raw
      logs — both halves render on the Watchdog: what the public webhook
      turned away, per channel and kind, and what the relay carried out,
      against what the project declared. **Not yet:** the declaration is a
      deployment variable rather than something an operator sets in the
      Console, so a project's declared destinations cannot be changed without
      a redeploy.
- [~] Exigence KPI/SLO breaches alert through the existing ARM alerting channel
      — the measurement is built (`exigence/src/service_objectives.ts`):
      success rate, run latency p95, approval-cycle p95 and budget burn, each
      against a target the project sets and none against a default, evaluated
      per window and shown on the Watchdog. **Delivery is not**, and cannot be
      as the feature file assumes: ARM's alerting is a Console view over its
      own issues and cases, with no ingest another product could post to. Three
      shapes and the reason today is the Console only are recorded in
      `DECISIONS_NEEDED.md` (30/08/26).
- [x] No alerting mechanism is duplicated from ARM — nothing here notifies
      anybody. Every Watchdog view is a Console read, and the one place a push
      was called for (6.2.5) is deliberately unbuilt rather than built twice:
      the three shapes and the reason it is the Console only today are in
      `DECISIONS_NEEDED.md` (30/08/26). A notification channel invented here
      would be the duplication this line exists to prevent.
- [x] Deferred scope is recorded, not silently dropped — the deferred list
      above stands, and everything found unbuildable during this build is
      written down with its reason rather than left as an unticked box:
      breach delivery (30/08/26) and identity expiry (30/08/26) in
      `DECISIONS_NEEDED.md`, and the partially covered lines above each name
      what they do not cover.

## Task 6.2.6 — Infrastructure and configuration scanning (NEW 30/08/26)

From the feature-set review, which framed the Watchdog as an all-round
security ringfence scanning GCP IAM, infrastructure config and deployed service
configuration for over-granting and security gaps.

**Both halves are kept.** What is built is not what the review described and is
not replaced by it: authority anomalies, unsafe project configuration, boundary
drift, refused ingress, egress against declared destinations, missing secret
references and the boundary inventory are all real client↔Citadel data-flow
risks that a GCP IAM scan would not find. The review adds two sources that are
genuinely missing, and both were already named as uncovered above:

- **Registry versus deployed IAM.** What Palisade says a project's identities
  hold, against what GCP actually grants. This is the drift Task 6.1.5's last
  bullet asks for and 6.2.3 leaves uncovered.
- **Deployed service configuration.** Cloud Run services, their ingress
  settings, their service accounts and what those accounts can reach.

**Codebase scanning is new scope and is not the Watchdog's.** It belongs with
Baker, which is the thing that has a codebase and the thing that generates it.

### Presentation
The page is now long and reads as a list of tables. The review's "essentially a
metrics screen" framing is worth taking partly: a summary band above the
detail, counting findings by kind, would make it answerable at a glance without
losing the detail underneath.

- [x] Registry-versus-deployed-IAM drift is detected and reported by
      consequence (31/08/26). Over-broad project roles, public members and
      members provisioning did not create; it never proposes a repair, because
      removing an IAM binding is how a production service goes offline.
- [x] Deployed service configuration is scanned for over-broad ingress and
      over-granted service accounts (31/08/26). Services whose purpose is to be
      publicly reachable are named rather than inferred.
- [x] A summary band counts findings by kind above the tables (31/08/26). It
      counts only what was read: a source that did not answer says so rather
      than counting zero.

**Left open:** member-level drift needs a record of what provisioning created
per project, and nothing keeps one. Absent it, the report says so rather than
calling every binding unexpected — `provisionedMembers` in the Platform API is
the seam.
