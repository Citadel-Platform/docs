# Feature 1.1 — ARM Tooling SDK

## Scope
Stabilize the consolidated ARM Flutter package in `citadel_core/arm/tooling` as the reusable monitoring SDK embedded in deployed apps.

## Tasks

### Task 1.1.1 — Validate package consolidation
- Run dependency resolution and static analysis in `citadel_core/arm/tooling`.
- Preserve public exports in `lib/arm_tooling.dart`.
- Confirm `ArmClient`, `ArmBootstrap`, `FirebaseArmSink`, `ArmCaptureBoundary`, and fingerprinting remain available.

### Task 1.1.2 — Document SDK integration
- Update install and usage docs for Citadel Platform context.
- Document Firestore-only mode and optional Storage screenshot mode.
- Document host app Firebase initialization expectations.

### Task 1.1.3 — Define ARM data contract
- Document `armIssues/{issueId}` and `armCases/{caseId}` fields.
- Document screenshot storage paths and metadata.
- Keep additive schema evolution rules so existing cases remain readable.

### Task 1.1.4 — Add regression tests where practical
- Test fingerprint stability.
- Test severity-to-case-exposure behavior.
- Test request sanitization limits.
- Test Firestore sink shape with mocks/emulator if available.

## Definition of done
Reviewed 30/08/26 against the tree.

- [x] `citadel_core/arm/tooling` resolves dependencies.
- [x] `citadel_core/arm/tooling` static analysis passes — `dart analyze`
      clean.
- [x] SDK docs are Citadel-specific — `README.md` plus `doc/installation.md`
      and `doc/usage.md`, written for Citadel's registry, platform-owned auth
      and operator metadata rather than as a generic Flutter SDK.
- [x] Core SDK behavior has tests or documented validation gaps —
      `tooling_core` and `tooling` both have suites covering the parts that
      would fail silently: document builders stamping a new case untriaged
      without disturbing issue triage, and `runTracked` recording a handled
      exception and invoking `onReported`.

## Task 1.1.5 — Duplicate suppression (NEW 30/08/26)

From the feature-set review: the client must not send repeated Case Logs
within one session.

- Suppression is **per fingerprint per session**, not per client. A page
  erroring in two different ways is two faults.
- The suppressed count is still reported. A loop that errs a thousand times
  and one that errs once must not look identical, which is exactly what naive
  deduplication produces — so the first capture goes, and subsequent ones
  increment a count on it rather than being dropped without trace.
- Suppression never applies to a Case Log a person attached to a support
  ticket (Feature 1.5): that one was chosen deliberately.

- [x] A fault repeating in one session sends one Case Log carrying a count
      (31/08/26). Repeats inside five minutes are counted and the next report
      carries `suppressedSinceLastReport`; a suppressed capture still answers
      with the case id that was recorded, because an error dialog showing none
      would look like the SDK had stopped working.
- [x] Two different faults in one session send two Case Logs (31/08/26)
- [x] A ticket-attached capture is never suppressed (31/08/26) — a capture
      taken on purpose passes `deduplicate: false`
