# Feature 2.1 — Citadel Platform Console and Website

## Scope
The Console is Citadel's complete operator control and observation plane. It
must show reconciled live state and drive every supported resource/action
across Citadel, GCP and configured providers. The Platform API and product
contracts own logic and mutation; the Flutter application composes them.

## Tasks

### Task 2.1.1 — Console shell
- Build responsive Material 3 shell with top bar, navigation rail/drawer, product directory, project selector, and session menu placeholder.
- Reuse ARM Console primitives where they fit.
- Keep mobile and desktop web layouts functional.

### Task 2.1.2 — Public landing page
- Add product overview for ARM, Conduit, Exigence, Baker, and Manifold.
- Explain Citadel Platform as shared DevOps/application infrastructure for repeated business stacks.
- Link to docs and console entry points.

### Task 2.1.3 — Product launch pages
- Add ARM launch page and setup status.
- Add Conduit placeholder launch page.
- Add Exigence placeholder launch page.
- Add Manifold launch page.
- Add Baker internal-only launch page.

### Task 2.1.4 — Shared state model
- Import shared contracts from `citadel_core` rather than re-declaring product logic in the UI layer.
- Keep any temporary UI-only state thin and disposable.
- Treat the Console as the source of truth for project setup and supported actions; any manual step must be surfaced as a guided form with validation and verification.
- Defer production auth and backend persistence until shared core decisions are approved.

### Task 2.1.5 — Ground-truth resource inventory
- Show intended and observed state for every project resource, service,
  identity, deployment, connector, runner and Devstation.
- Distinguish unavailable, permission-denied, stale, drifted, absent and healthy
  rather than reducing all failures to "not configured".
- Link every resource to the Console operation that manages or repairs it.

### Task 2.1.6 — Complete management flows
- Project creation, onboarding, provider connection, Terraform plan/apply,
  runtime/agent publication, runner credentials and every other supported
  operation are initiated and recovered from the Console.
- A third-party step requiring a person is represented as a form/guided step
  with exact context, validation and a live completion check.
- CLI remains optional parity/diagnostics, not a prerequisite for operating a
  client project.

### Task 2.1.7 — Acceptance coverage
- Browser E2E covers project creation through enabled, verified offerings.
- Functional/integration tests exercise Platform API, provider/emulator and
  long-running job recovery; fixtures do not fabricate provider semantics.

## Definition of done
- [ ] Starter counter app is replaced
- [ ] Platform console uses GCP-style navigation
- [ ] All offerings have central launch surfaces
- [ ] `flutter analyze` passes for `citadel_platform`
- [ ] Every supported resource/action is visible and manageable from the Console
- [ ] Guided external steps verify completion from the live provider
- [ ] Browser E2E proves a project can be created and fully managed without CLI/manual scripts
