# Feature 1.4 — ARM Alerting, SLOs, Release Health and OTel Alignment (NEW)

## Scope
Close ARM's parity gap with Sentry/Crashlytics-class tooling: clients must be proactively notified of urgent issues, see release health, and track SLOs — while preserving ARM's differentiators (recovery snapshots, client-owned evidence, operator-embedded triage). Extends arm_tooling_core/server and the ARM Console pages consolidated under citadel_core/arm.

## Tasks

### Task 1.4.1 — Alert rules and notification pipeline
- Per-project alert rules stored in project config: new-issue (first occurrence of fingerprint), threshold (≥N cases of a fingerprint in window W), severity-based (data-integrity class always alerts), and regression (previously resolved fingerprint reoccurs).
- Evaluation runs inside the monitored project's boundary: a scheduled Cloud Function (deployed via the onboarding kit, Feature 0.7) evaluates rules against the project's own Firestore — evidence data does not leave the client project.
- Channels v1: email + generic webhook; alert documents recorded so the Console shows alert history; per-rule mute/snooze; dedupe window to prevent storms.

### Task 1.4.2 — Release health

**Release identity settled 31/08/26 (DECISIONS.md), and ARM owns half of a
shared contract.** The identifier is a composite emitted *identically* by ARM
and Conduit:

```
{platform}/{environment}/{version}+{build}     e.g. android/prod/1.4.2+318
platform    ∈ web-desktop | web-mobile | ios | android
environment ∈ dev | test | staging | prod
```

Carried as one string for joining and as four separate fields for slicing. A
mismatch between the two SDKs does not make Conduit's Feature 3.9 release-delta
figures missing — it makes them wrong, and those figures go into grant
submissions. Keep the two emitters in sync deliberately, not by coincidence.

- arm_tooling: attach the composite release identity — platform, environment,
  version, build — to every case and telemetry record at init.
- Console: per-release view — new fingerprints introduced, crash-free-session proxy (sessions without error cases / total sessions from existing telemetry), adoption curve per version; regression tagging when an old fingerprint reappears in a newer release.

### Task 1.4.3 — SLOs and error budgets (lightweight)
- Per-project SLO definitions on existing telemetry (e.g., p95 route-load latency, error-case rate); monthly error-budget computation with burn display on the Overview page next to the urgent queue.
- SLO breach can feed Task 1.4.1 alert rules; these SLO summaries are a first-class input to Conduit's ROI reports (Feature 3.9).

### Task 1.4.4 — OTel semantic alignment pass
- Field-map audit of ARM telemetry/case schemas against OTel log/trace semconv (exception.*, service.version, session.id, http.*, etc.); add missing standard fields as aliases without breaking existing documents; document the map in _dev/docs.
- Purpose: keeps ARM data portable/exportable and consistent with Exigence's GenAI-conv traces — one coherent semantic layer across the platform.

### Task 1.4.5 — Console wiring
- Alert rule CRUD (superuser/developer), alert history page, release selector on Explorer/Reports, SLO card on Overview. Explicit no-data states; production-visible copy.

## Definition of done
- [ ] Threshold and new-issue alerts fire end-to-end from a monitored test project to email + webhook, with dedupe verified
- [ ] Evidence-boundary check: alert evaluation reads only within the monitored project; Citadel project receives notification metadata only
- [ ] Release health view renders from real version-tagged cases; regression tagging verified across two versions
- [ ] The emitted release identity is byte-identical to Conduit's for the same
      build, verified by a test that joins an ARM case to a Conduit session
- [ ] SLO burn visible on Overview; breach triggers an alert in test
- [x] OTel field map documented; `flutter analyze` zero warnings across arm
      packages and console — `_dev/docs/otel_genai_field_map.md` maps every
      Citadel field to a semconv attribute, names the `citadel.*` namespace for
      what has no convention, and records that cost has no standard at all
      rather than inventing one. Analysis is clean across `arm/tooling`,
      `arm/tooling_core` and `citadel_platform` (30/08/26).

The four above all need a monitored live test project and a delivery channel;
none is blocked on code that has not been written, and none can be proven
without one.

## Task 1.4.6 — Alerting policies, tags and channels (NEW 30/08/26)

From the feature-set review. The Console shape is applied; the store is not.

### Policies are auto-tagging rules
A policy is a set of conditions and what happens when a fingerprint matches:

- **Conditions** — rules over a fingerprint's fields (title, severity, error
  type, status, release version, case count) with an operator and a value,
  joined left to right by And/Or. **Groups are not offered.** A builder that
  renders nesting the evaluator cannot evaluate is worse than one that says it
  does not nest; nesting is a later change to both halves at once.
- **Tags** — multi-select, and it creates what is typed. The useful tag is
  usually the one this project needs and nobody anticipated.
- **Notification channels** — multi-select of the project's channels, plus a
  way out to create one. A policy with no channel still tags; tagging is the
  part that happens whether or not anybody is notified.

Severity-and-destination — what the form asked for before — is replaced. It
could express one shape of one kind of fault.

### Notification channels are a table, not a top-bar button
Name, type, and recipients typed to the channel (email addresses for Email,
numbers for WhatsApp, …). A channel is a thing a project has several of and
edits over time; it was reachable only from a control that looked like a
settings shortcut, which is why nobody could see how many they had. **Test
Channel** stays and must actually deliver.

### Tags on fingerprints
The Issue Fingerprints table carries a **Tags** column showing both
policy-assigned and hand-assigned tags — **one column**, because a person
triaging a fault cares that something is a regression, not whether a rule or a
colleague said so. Provenance belongs in the fingerprint's history. Tags are
also assignable from the table.

### Snoozes are removed
A snooze silences an alert without changing anything about what raised it,
which is the mechanism by which a project stops hearing about a fault that is
still happening. Muting belongs in a policy's own conditions, beside what it
suppresses.

- [~] Console shape — applied 30/08/26: Snoozes gone, Incidents renamed to
      Issue fingerprints, channels have their own table, the policy form is
      name → conditions → tags → channels, and the fingerprint table has a
      Tags column. Nothing saves: ARM has no policy, channel or tag store, so
      the page says so and the button says Review rather than Save.
- [ ] ARM stores policies, channels and fingerprint tags
- [ ] A matching fingerprint is tagged automatically and the named channels
      are notified
- [ ] Test Channel delivers a real message

## Task 1.4.7 — Case Log criticality (NEW 30/08/26)

Criticality is changeable from the Case Logs table, separately from status.
Status is where triage got to; severity is how bad the thing is, and a case can
be resolved and still have been critical. A capture arrives with a severity the
SDK guessed from the exception, and the person reading it is the one who knows
whether the guess was right.

- [~] The control is applied 30/08/26 and writes for real on the
      Firestore-backed path, stamped with who changed it and when, beside the
      captured value rather than over it.
- [ ] The ARM service accepts a severity change, so the Platform-API path
      works too. It currently refuses with a stated reason.
