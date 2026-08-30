# Feature 5.2 - Baker MVP Bootstrap

## Status
Scope settled. This is the light bootstrap slice when the Baker phase starts.

## Scope
Apply Factory kits, recipes and the context pack to create the initial working
MVP quickly. This phase ends at a runnable first application and a recorded
version trail; it does not own long-term upgrades, manifests or broad
autonomous mutation.

## Tasks

### Task 5.2.1 - Bootstrap flow
- Select a supported starting stack and a small set of feature recipes.
- Show exactly which asset versions will be used before writing source.
- Create a new repository/workspace or target an explicitly selected empty
  starter repository.

### Task 5.2.2 - Source generation
- Materialise the selected component kits and recipe wiring into the codebase.
- Write the basic used-version record alongside the source.
- Never overwrite unrelated source without explicit, visible confirmation.

### Task 5.2.3 - Validation
- Install dependencies, run static analysis/tests and launch the MVP.
- Surface every failure and remediation step in the Console.
- Verify Firebase configuration and Citadel SDK integration from live/emulated
  sources; never populate fake business data.

### Task 5.2.4 - Devstation handoff
- Surface the per-client Devstation provisioning and lifecycle steps in the
  Console so the operator can hand off into the development VM when needed.
- Keep the flow Terraform-backed and visibly guided, not a hidden script or
  checklist.

## Definition of done
- [ ] A supported project bootstraps from zero to a runnable MVP through the Console
- [ ] Generated source records the exact Factory asset versions used
- [ ] Static analysis, functional tests and a browser smoke test pass
- [ ] Devstation provisioning and external actions remain visible in the Console
