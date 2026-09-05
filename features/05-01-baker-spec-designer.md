# Feature 5.1 - Baker Factory

## Status
**Built 05/09/26.** `citadel_core/baker/` is the Factory package and its CLI;
the six modules in `Citadel-Platform/baker-modules` carry real source rather
than a `module.json` and a README each; the two recipes are indexed into the
catalogue and shown in the Console.

Verified by doing it: `crm-mvp` into an empty directory produces an
application that `flutter pub get`, `flutter analyze` and `flutter test` all
pass on, and that run is a test in the package rather than something somebody
remembers to try.

## Scope
Factory is a light, superdev-only developer accelerator for taking a CRM,
dashboard, website or internal tool from zero to its initial MVP. It packages
the operator's reusable component kits, recipes, context packs and version
tracking; it is not a no-code builder, application manifest, boundary system
or upgrade engine.

## Tasks

### Task 5.1.1 - Component kits
- Reusable, production-oriented UI and Firebase integration components.
- Start with the operator's approved Flutter/web/Firebase stack only.
- Include ARM and Conduit integration points where the generated app needs them.

### Task 5.1.2 - Recipes
- Small stack and feature recipes for bootstrapping common CRM capabilities.
- Recipes describe the source changes and setup needed for the initial MVP.
- Keep recipes composable and deterministic enough to test from a clean repo.

### Task 5.1.3 - Agent context pack
- Give a coder or operator-directed coding agent the project conventions,
  available kits/recipes and relevant Firebase/Citadel integration guidance.
- Keep the pack source-controlled and versioned with the assets it describes.

### Task 5.1.4 - Basic version tracking
- Record which kit, recipe and context-pack versions a codebase used.
- Tracking is informational provenance, not an upgrade or migration engine.

### Task 5.1.5 - Devstation handoff
- Surface the per-client Devstation shape from Baker so the bootstrap flow can
  hand off to the development VM when needed.
- Keep the handoff guided, visible and versioned rather than hidden in a shell
  script.

## Definition of done
- [x] A clean repository reaches a working MVP shell using approved kits and
      recipes (05/09/26). 13 files, analysing and passing.
- [x] Used asset versions are recorded in the codebase (05/09/26).
      `baker.lock.json` records the recipe, and per module the version, the
      commit it was cut at and a digest of what was actually written — the
      digest because a module can be edited between a checkout and a
      bootstrap, and a version number is what somebody typed.
- [x] Bootstrap is covered by a clean-repository functional test (05/09/26).
      It runs by default: a recipe that no longer builds is invisible to every
      other check in the package, and a test that has to be remembered stops
      being run.
- [x] Non-superdev identities cannot discover or invoke Factory. The Console
      surface sits behind the superdev-only Baker permissions, and the CLI is
      a repository checkout rather than a service anybody can reach.
- [ ] The context pack lets an operator-directed coding agent use the assets
      correctly. Task 5.1.3 is the one part not built: there is no
      source-controlled context pack yet, and the modules' own READMEs are
      what a coding agent currently has.
