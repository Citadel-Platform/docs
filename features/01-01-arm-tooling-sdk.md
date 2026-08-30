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
- [ ] `citadel_core/arm/tooling` resolves dependencies
- [ ] `citadel_core/arm/tooling` static analysis passes
- [ ] SDK docs are Citadel-specific
- [ ] Core SDK behavior has tests or documented validation gaps
