# Citadel Platform Release Timeline

## Phase 0 — Planning and Core Reset

- Replace example planning state with Citadel Platform project data.
- Align planning docs with the three top-level packages: `citadel_core`, `citadel_cli`, and `citadel_platform`.
- Consolidate ARM reference code into `citadel_core/arm/tooling` and `citadel_core/arm/console`.
- Establish current technical report and feature order.
- Create shared core feature specs before product work.

## Phase 1 — Citadel Core Foundations

- Monorepo conventions and module boundaries centered on `citadel_core`.
- Shared tenant/project/user/service-account model.
- Shared API conventions and error format.
- Shared protocol, registry, and development-auth posture.

## Phase 2 — Citadel CLI

- Bootstrap the `citadel_cli` package as the first developer-facing consumer of core contracts.
- Add commands for inspecting core state and validating local/dev flows.
- Add rapid-testing commands that exercise structured errors, pagination, and audit behavior without requiring UI work.
- Keep the CLI focused on development velocity and contract validation first.

## Phase 3 — ARM in Citadel Core

- Preserve and validate the existing ARM Tooling package.
- Preserve and validate the existing ARM Console app.
- Document monitored-project setup, Firestore/Storage rules, local preview mode, and Firebase Hosting deploy.
- Expose ARM module behavior through core packages and CLI workflows first.
- Add reporting and optional central intake only after direct Firestore mode is stable.

## Phase 4 — Conduit in Citadel Core

- Define metrics/event schemas and ingestion contracts.
- Add Pub/Sub and BigQuery-backed ingestion pipeline.
- Add dataset registry, ingestion health, dashboards, reports, and exports.
- Provide Dart and HTTP ingestion SDKs.

## Phase 5 — Exigence in Citadel Core

- Define automation, run, tool, event, and artifact models.
- Implement orchestration API and event stream.
- Add CLI-visible automation workflows before central UI pages.
- Add provider and tool execution decisions before production use.

## Phase 6 — Baker in Citadel Core

- Resume with Factory first: component kits, recipes, context pack, and
  version tracking.
- Add Devstation as the per-client development VM surface after Factory is
  stable.
- Avoid manifests, boundaries, upgrade engines, and broad code generation until
  the bootstrapping path proves useful.

## Phase 7 — Manifold in Citadel Core

- Build the omnichannel inbox and escalation bridge that ties ARM telemetry,
  Conduit journey context, Exigence actions, and Baker repair escalation
  together.
- Keep it Console-operated and project-scoped, with Palisade governing data
  flow and visibility.

## Phase 8 — Citadel Platform Interface

- Replace starter Flutter app with a GCP-style Citadel shell.
- Add product directory and launch cards for ARM, Conduit, Exigence, Manifold, and Baker.
- Add project selector, setup status, docs links, and access placeholders.
- Route stable core capabilities into the central console after core and CLI workflows are proven.

## Deferred Work

- Feature 0.3 shared infrastructure and Terraform baseline.
- Any later feature whose implementation depends on Terraform-managed infrastructure before that baseline is resumed.
