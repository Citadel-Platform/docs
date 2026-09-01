# Feature 1.2 — ARM Console

## Scope
Stabilize the preserved ARM Console in `citadel_core/arm/console` as the standalone triage and reporting reference interface for monitored projects during the core-first phase.

## Tasks

### Task 1.2.1 — Validate console consolidation
- Run dependency resolution and static analysis in `citadel_core/arm/console`.
- Preserve Material 3 shell, route structure, project switcher, overview, explorer, reports, and case detail pages.
- Keep local preview mode available for UI iteration without live Firebase.

### Task 1.2.2 — Citadel project registry alignment
- Align console project registry docs with the shared Citadel project model.
- Keep console auth, permissions, and registry in the shared `citadel-platform` Firebase project.
- Keep monitored-project evidence data read-only by default.
- Ensure registry writes do not touch monitored-project ARM evidence in external client Firebase projects.

### Task 1.2.3 — Case and issue workflows
- Wire issue filters, case filters, case detail navigation, screenshots, breadcrumbs, recovery snapshots, and stack traces.
- Keep urgent queues and bird's-eye triage visible on the overview page.

### Task 1.2.4 — Hosting and setup docs
- Document local `.env` requirements.
- Document Firebase Hosting deployment.
- Document monitored-project preparation and rules checks.

## Definition of done
Reviewed 30/08/26 against the tree.

- [~] `citadel_core/arm/console` resolves dependencies — **superseded.**
      There is no such package and there should not be: ARM's Console is the
      Platform Console's `/arm` routes, per the 26/08/26 decision that the
      Platform Console is the single source of truth. Those routes resolve,
      analyse clean and are covered by the Console suite.
- [~] `citadel_core/arm/console` static analysis passes — superseded, as
      above. `flutter analyze` is clean for `citadel_platform`, which is where
      the code now lives.
- [x] Console docs use Citadel Platform terminology.
- [x] Project registry aligns with shared core model — one
      `ProjectRegistryEntry` in `citadel_core/platform/api`, consumed by the
      Console, the CLI and the inventory service rather than re-declared.
