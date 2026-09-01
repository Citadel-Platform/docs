# Feature 0.1 — Planning Reset and ARM Consolidation

## Scope
Replace example roadmap material with Citadel Platform planning state and bring the existing ARM SDK/console code into the monorepo without redesign.

## Tasks

### Task 0.1.1 — Reset planning corpus
- Overwrite active planning docs with Citadel Platform project data.
- Populate `_dev/docs/technical_report.md` in the requested product order.
- Populate `_dev/docs/release_timeline.md` with phased delivery order.
- Replace old feature files with Citadel-specific feature files.
- Update `CURRENT_TASK.md`, `CURRENT_RELEASE.md`, `DECISIONS.md`, `DECISIONS_NEEDED.md`, `_dev/test_status.md`, and `_dev/session_log.md`.

### Task 0.1.2 — Consolidate ARM references
- Copy `_reference/ARM_Tooling` to `citadel_core/arm/tooling`.
- Copy `_reference/ARM_Console` to `citadel_core/arm/console`.
- Exclude `.git`, `.dart_tool`, `build`, `.DS_Store`, IDE workspace state, and generated plugin metadata.
- Preserve package internals unless validation exposes real breakage.

### Task 0.1.3 — Validate consolidated ARM
- Run `flutter pub get` and `flutter analyze` in `arm/tooling`.
- Run `flutter pub get` and `flutter analyze` in `arm/console`.
- Record any dependency or SDK drift in `_dev/test_status.md`.
- Do not rename packages/imports until the validation result is known.

## Definition of done
Reviewed 30/08/26 against the tree.

- [x] Active docs no longer describe the old example project as current
      state — the always-loaded context and SITREP were refreshed on 26/08/26
      and keep deployed truth separate from target state.
- [~] ARM code exists under `citadel_core/arm/tooling` and
      `citadel_core/arm/console` — the tooling half is there and is now four
      packages (`tooling`, `tooling_core`, `tooling_server`,
      `citadel_arm_service`) rather than one. **There is no
      `citadel_core/arm/console` and there should not be:** ARM's Console is
      the Platform Console's `/arm` routes, which is the 26/08/26 decision
      that the Platform Console is the single source of truth. The line is
      superseded rather than outstanding.
- [x] Consolidated ARM packages have validation status recorded — `dart
      analyze` is clean on `citadel_core/arm/tooling` and its dependencies
      resolve.
- [x] Any package renaming decision is recorded before implementation — the
      splits and renames are in DECISIONS.md.
