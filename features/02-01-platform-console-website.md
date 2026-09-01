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
Reviewed 30/08/26. The first four had been true for a long time and were
never ticked.

- [x] Starter counter app is replaced — nothing of the Flutter template
      remains; `citadel_platform` boots into the Console shell.
- [x] Platform console uses GCP-style navigation — responsive Material 3
      shell with a top bar, navigation rail and drawer, product directory,
      project selector and session menu, and both mobile and desktop web
      layouts work (`platform_shell.dart`, `platform_workspace_shell_test.dart`).
- [x] All offerings have central launch surfaces — ARM, Conduit, Exigence,
      Manifold, Palisade and Baker each have a launch page and their own
      routes under it (`citadel_platform_app.dart`).
- [x] `flutter analyze` passes for `citadel_platform` — clean, and the 363-test
      Console suite passes with it.
- [~] Every supported resource/action is visible and manageable from the
      Console — the resource inventory shows intended and observed state and
      distinguishes unavailable, permission-denied, stale, drifted, absent and
      healthy rather than collapsing them into "not configured", with each
      problem linked to the operation that repairs it (Task 2.1.5, built).
      Project creation, onboarding, provider connection, Terraform
      plan/apply, artifact publication, channel publication, runner
      credentials, boundaries, grants and roles are all Console operations.
      **Not yet:** Baker's Devstation operations, which are not built; and a
      project's declared relay destinations, which are a deployment variable
      rather than something an operator can set.
- [x] Guided external steps verify completion from the live provider — the
      pattern is enforced rather than encouraged: publishing a WhatsApp
      channel verifies the access token, WhatsApp Business Account and phone
      number against Meta before anything is written, and a deployment that
      cannot reach Meta refuses to publish rather than publishing unverified
      (`platform_manifold_verification.dart`). It is also honest about what it
      cannot prove — the verify token and app secret can only be read, and it
      says so instead of showing three green ticks.
- [ ] Browser E2E proves a project can be created and fully managed without
      CLI/manual scripts — **not built.** The Console harness drives the
      127.0.0.1:8792 seed build for individual screens; a full
      creation-to-verified-offerings run needs the signed-in build, which
      cannot currently be scripted.

## Task 2.1.8 — Feature-set review changes (NEW 30/08/26)

Applied from `_dev/docs/feature_set_review_30_08_26.md`. Recorded here because
they cut across products and would otherwise be invisible from the Console's
own feature file.

- **Palisade → Your authority** removed; **Roles** is a table with the built-in
  three locked; the **Boundaries** publish form states what it decides, that
  revisions are immutable, and the rule grammar.
- **Manifold → Channels** is now **Communication lines**, one row per line
  rather than per revision, with **Add line**.
- **Conduit → Instrumentation** is now **Touchpoints**, a configuration screen
  whose toggles write, with the old path redirecting.
- **ARM → Alerting** drops Snoozes, renames Incidents to Issue fingerprints,
  gives Notification channels their own table, rebuilds the policy form as
  conditions → tags → channels, adds a Tags column to fingerprints and a
  criticality dropdown to case logs.

Still outstanding from that review, each specified in its own feature file:
ARM Tickets (1.5), Exigence MCPs and the Superharness (4.7), Baker's tab set
(5.4), Conduit multiple targets (3.1.6) and dashboard declutter (3.6.5),
custom Palisade roles (6.1.7), Watchdog infrastructure scanning (6.2.6), and
Manifold Email lines (7.1.5).
