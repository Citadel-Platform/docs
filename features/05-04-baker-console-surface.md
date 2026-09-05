# Feature 5.4 — Baker Console surface (NEW 30/08/26)

## Status
Specified 30/08/26 from the product-owner feature-set review
(`_dev/docs/feature_set_review_30_08_26.md`). **Built 31/08/26.** Replaces the
launch / workspace / specs / modules / deployments set, which had routes and
nothing behind them.

Modules, Deployments and Devstation are served, rendered and tested. All five
Baker permissions are superdev-only. The GCP-project precondition is enforced
once in the service and answers 409 with what to do.

**The VM was wired on 05/09/26.** `operateDevstationWith` is no longer absent:
start and stop are Compute API calls, destroy is a Terraform plan that goes
through the same approval a build does, and the tab now provisions a machine
as well as operating one. See Feature 5.3.

Outstanding, and it is a decision rather than code:
- **GitHub access** — `tool/index_baker_modules.dart` indexes a local clone,
  because giving the Platform API a GitHub credential is a decision about where
  Citadel's supply chain may be read from.

## Precondition
**A project's GCP project ID must be set before Baker is reachable for it.**
A guard on the whole product surface, not a validation inside each tab: Baker
provisions and deploys into the client's own project, and every one of these
screens is meaningless without knowing which project that is.

## Scope
Three tabs. The existing set is scrapped.

## Task 5.4.1 — Modules

A table of what the Factory can build with, read from the `baker-modules`
repository (`https://github.com/Citadel-Platform/baker-modules.git`). Each
module is a subdirectory: a codebase for one function — frontend boilerplate,
navigation and layout boilerplate, design systems, pre-built components,
middleware, backend and infrastructure config, rule files. All versioned.

Columns: **Name**, **Layer** (frontend / middleware / backend),
**Product or service** (Flutter, Firebase, Google Cloud, Terraform, Dart, …),
**Version**, **Release date**. Each version links to its Git commit.

**Not project-scoped.** This is the catalogue, seen once, not a per-client
view. It is the one Baker tab that answers "what do we have" rather than
"what does this client run".

## Task 5.4.2 — Deployments

Project-scoped, and driven by three selectors in the tab's own top bar:

1. **Application** — which of this project's CRMs, websites, applications or
   tools.
2. **Environment** — Dev, Test, Staging, Prod.
3. **Release version**.

Below the selectors:

- the Baker modules that went into that release, each with its version, linked
  back to its row in Modules;
- the Git release information: release date, commit, tag.

The tab also carries:

- **Rollout configuration** — blue-green, canary, and the parameters each
  needs;
- **Preview audience** — the beta/preview allowlist, for the Staging
  environment.

The point of the module list is drift: an operator looking at a production
release should be able to see, without leaving the page, that it is running a
design system three versions behind the catalogue.

## Task 5.4.3 — Devstation

Configuration, status and connection for the client's development VM. The
service itself is Feature 5.3; this is its Console surface.

When enabled it provisions a GCE VM in the **client's** GCP project with a
standard machine image and tooling (Docker, Flutter, Chrome, Git), persistent
storage, and IAM sufficient to act as a developer on that project. Coding CLI
agents are installed on it and author code, run tests, fix bugs, push commits
and manage the client's infrastructure autonomously. A superdev SSHes in from
their own laptop to do the same work by hand.

The page carries:

- provisioning state and the inputs to start, stop and destroy it;
- machine and storage configuration;
- the SSH connection details, through IAP/OS Login — never a public address;
- current status: running, stopped, provisioning, failed, with the reason.

## Definition of done
- [x] Baker is unreachable for a project with no GCP project ID, and says why
      — the precondition is enforced once in the service and answers 409 with
      what to do.
- [x] Modules lists the catalogue with every version linked to its commit
      (31/08/26). Six real modules created and pushed to `seed/initial-modules`
      on `Citadel-Platform/baker-modules` — one commit each, so every module
      carries its own commit and date rather than six rows sharing one — then
      indexed into `bakerCatalogue/modules` and served by the deployed API to
      an authenticated caller.
- [x] (31/08/26, with real data) Deployments resolves application →
      environment → release and shows the
      module versions and Git release behind it
- [x] A release running behind the catalogue is visible without leaving the
      page (31/08/26). `tool/record_baker_deployment.dart` wrote a real record
      for `axis-education`: production runs `citadel-design-system` 2.8.0
      against the catalogue's 3.0.2 and `conduit-instrumentation` 1.1.0 against
      1.4.0, while staging is current. The drift the tab exists to show is now
      something the tab can be wrong about.
- [x] Rollout configuration and the Staging preview audience are editable.
      Built with the tab on 31/08/26 — the strategy selector, the canary
      share, and the preview-audience dialog, all calling
      `configureBakerRelease`, with the service enforcing the two rules a form
      cannot: a canary outside 1–99 is not a canary, and a preview audience on
      anything but Staging is a list nothing consults.

      Recorded as outstanding on 05/09/26 in error — written from the service
      side without opening the tab. Corrected the same day, and the editor is
      now covered by a widget test rather than by a reading of the code.
- [x] Devstation provisions, stops and destroys through reviewed Terraform,
      and Console state matches the Compute API after every transition
      (05/09/26, driven in Chrome against `user-test-1`).
- [x] SSH works through IAP/OS Login with no public ingress (05/09/26)
