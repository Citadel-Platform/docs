# Feature 0.5 — Citadel CLI Bootstrap

## Scope
Establish `citadel_cli` as the first developer-facing consumer of `citadel_core` so core contracts can be exercised rapidly without depending on the platform UI.

## Tasks

### Task 0.5.1 — CLI package baseline
- Replace any starter CLI scaffolding with Citadel-specific entrypoints.
- Define command groups around inspection, validation, and local/dev workflows.
- Keep CLI dependencies minimal and focused on core package consumption.

### Task 0.5.2 — Core contract consumption
- Import shared contracts from `citadel_core`.
- Avoid duplicating API shapes or domain models inside the CLI.
- Make structured errors visible exactly as exposed by the core packages.

### Task 0.5.3 — Rapid testing workflows
- Add commands that exercise project registry, offering state, and local/dev API flows.
- Prefer commands that help validate platform behavior before the UI exists.
- Keep auth posture local/dev only until production identity decisions are approved.

### Task 0.5.4 — CLI docs
- Document how to run and extend the CLI.
- Document any required local environment variables.
- Document which commands are safe scaffolds vs. real mutating flows.

## Definition of done
- [ ] `citadel_cli` has Citadel-specific command structure
- [ ] CLI consumes contracts from `citadel_core`
- [ ] Rapid testing workflows exist for local/dev work
- [ ] CLI docs are present and current
