# Feature 5.1 - Baker Factory

## Status
Scope settled. Implementation starts when the Baker phase is resumed.

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
- [ ] A clean repository reaches a working MVP shell using approved kits and recipes
- [ ] The context pack lets an operator-directed coding agent use the assets correctly
- [ ] Used asset versions are recorded in the codebase
- [ ] Non-superdev identities cannot discover or invoke Factory
- [ ] Bootstrap is covered by a clean-repository functional test
