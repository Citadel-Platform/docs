30/08/26 20:15 [FEAT] `claude-opus-5` Exigence 4.5.6, the last open item in 04-05. The channel tool and the WhatsApp connector were both built and neither was composed — `bindChannelSend` appears nowhere in the runtime, so an artifact could not reply to a customer at all, the same gap shape the webhook path had on 30/08. `composeManifold` now returns `toolChannelsFor(runId)`, a factory rather than a map because the thread has to record which run said it. Collapsed the human reply path onto the same `composedChannel` construction, since two copies of consent-gate-then-record is how one of them stops gating. Added `whatsAppChannelId` in TS restating the Dart catalogue across the language boundary, pinned by a contract test verified by breaking the Dart side. The policy gate is inherited rather than newly proven: no test yet drives an artifact send end to end through the gate into a recorded thread. 593 unit, 119 emulator.
- A citadel_core/exigence/test/manifold_tool_channel.test.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/exigence/src/whatsapp_channel.ts

30/08/26 19:40 [FEAT] `claude-opus-5` Palisade Watchdog 6.2.1. Authorization anomaly detection over the audit built earlier today, distinguishing persistent refusal (one permission, huge counts, a deployment expecting authority nobody granted) from probing (several distinct permissions, small counts, something finding its edges) — reporting both as a denial count buries the second in the first. Agents get a lower threshold and sort first, which is the feature's whole point: nobody watches an artifact be refused. Agent ids are passed in rather than inferred from naming, because an inference that broke would fail as a missing alert. Unreadable rows are skipped so the detector cannot invent an alarm. Nothing calls it yet — no route, no schedule, and 6.2.5 wants breaches routed through ARM alerting rather than a new channel. 310 platform server tests.
- A citadel_core/platform/server/lib/src/palisade_watchdog.dart
- A citadel_core/platform/server/test/palisade_watchdog_test.dart
- M citadel_core/platform/server/lib/citadel_platform_server.dart

30/08/26 19:05 [FEAT] `claude-opus-5` Palisade 6.1.1 identity routes. `platform.identities.manage` is a tenant capability rather than a project permission, because an identity exists once and is granted into projects — scoping creation to a project would let one project's administrator mint principals another project's grants could name. POST/PATCH/GET under /v1/identities, wired in the production entrypoint. Tests pin that registration answers disabled, an unknown type is refused rather than defaulted, the response carries no credential field of any kind, nothing is written without the tenant capability, and an unauthenticated caller reaches no route. DoD 1 is served by an API but has no Console surface, and credential lifecycle is still undecided. 302 platform server, 48 authority, Console analyze clean.
- A citadel_core/platform/server/test/platform_identity_route_test.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/catalogue.json
- M citadel_core/exigence/src/permission_catalogue.ts
- M citadel_core/localbridge/src/catalogue.ts

30/08/26 18:30 [FEAT] `claude-opus-5` Palisade 6.1.1 identity registration. `PlatformIdentityService` over the existing `palisade_identities` collection, all five types in one registry so an artifact's authority is inspectable where a person's is. Created disabled by default, because a principal that could act the moment it was registered is usable before anyone decided what it may do. Registering over an existing id is refused rather than upserted — the id is what grants and audit entries name. No delete at all: authority is audited and a removed identity leaves entries naming a principal nobody can look up, so disabling is the mechanism, proven against resolveEffectiveAuthority returning nothing for a disabled identity. Also confirmed DoD 7 and 8 rather than assuming them: the local runner has a byte-identical generated copy of the boundary engine (re-ran sync, no drift, 54 localbridge tests pass with today's new permissions), and ARM has no project-role model left, resolving through the proxy permission map. No routes or Console surface for identities yet. 296 platform server tests.
- A citadel_core/platform/server/lib/src/platform_identity_service.dart
- A citadel_core/platform/server/test/platform_identity_service_test.dart
- M citadel_core/platform/server/lib/citadel_platform_server.dart
- M citadel_core/localbridge/src/boundary.ts
- M citadel_core/localbridge/src/catalogue.ts

30/08/26 17:55 [FEAT] `claude-opus-5` Palisade DoD 12 complete. Added the Console audit view at /audit behind `platform.audit.read` — one view for authorization outcomes and data flows together. Rows render from untyped maps deliberately: the audit is append-only and grows as products are added, and decoding into a model would make an unanticipated row vanish from the one view meant to show everything, so a data-flow-shaped row with no `permission` or `allowed` still appears. Only denials are coloured. 331 Console tests, analyzer clean. Remaining in 6.1: identity CRUD, ARM role resolution, runner-side boundary enforcement, adversarial E2E; the data-flow audit still has no bridge from the TypeScript runtime to control-plane storage, deliberately, since the correlation source does not exist yet and it would be a pipe with nothing in it. 06-02 Watchdog untouched.
- A citadel_platform/lib/src/app/platform_audit_page.dart
- A citadel_platform/test/platform_audit_page_test.dart
- M citadel_platform/lib/src/app/platform_workspace_api.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart

30/08/26 17:20 [FEAT] `claude-opus-5` Palisade DoD 12. Found that no audit storage existed at all — AuditEvent is modelled, the Console field is hardcoded empty, and nothing ever wrote or read one — so DoD 9's records had nowhere to go. Built `PlatformAuditStore`, one collection for both authorization outcomes and data flows because they answer one question and two timelines get correlated by hand. Held in the control plane, inverting the usual data-plane rule deliberately: this is Citadel's record of its own conduct, and a client runtime that could write it could edit the log of what it did. Document ids are time-ordered so the listing needs no composite index, which would otherwise have made a console fix into a Terraform change. Added `platform.audit.read` (superdev-only) and `GET /v1/projects/{id}/audit`, where an unwired store answers 503 rather than an empty list. Wired both sink and reader in the production entrypoint so neither is accepted-and-ignored. No Console view yet, and the data-flow audit still needs an adapter onto this store. 289 platform server, 48 authority, 31 API, 592 Exigence.
- A citadel_core/platform/server/lib/src/platform_audit_store.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/citadel_platform_server.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- M citadel_core/platform/server/test/palisade_authorization_audit_test.dart
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/catalogue.json
- M citadel_core/exigence/src/permission_catalogue.ts

30/08/26 16:40 [FEAT] `claude-opus-5` Palisade DoD 9. Authorization outcomes are now audited at the proxy request seam — both allow and deny, threaded through all 38 `_proxyProductRequest` call sites so the parameter is not dead code. Recorded at the seam rather than inside the `_canAccessProject` predicate: one request checking three permissions is one authorization outcome, not three. The record holds coordinates and the decision and never the request body, asserted by a test that posts a card number and checks it never lands. A failing sink cannot change an outcome, because an audit that invents denials is worse than one that loses entries. No sink implementation yet, so DoD 12 still needs storage and a Console view shared with the data-flow audit. 286 platform server tests pass, analyzer clean.
- A citadel_core/platform/server/test/palisade_authorization_audit_test.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart

30/08/26 16:00 [FEAT] `claude-opus-5` Palisade DoD 4 and 10. Roles now bundle boundaries, added to a grant's rather than replacing them because most-restrictive-wins means adding can only narrow and overriding would let a role widen reach. `resolveEffectiveAuthority` takes an optional `roleLookup` so projects can define their own named roles per 6.1.3. Proved deny-by-default when the registry is unreachable; the behaviour was right and nothing asserted it. My first version of that test was nearly vacuous — asserting only "not 2xx" passes on routes that answer "not configured" before resolving any authority, so it now asserts 503 and that the body names Palisade, which is what proves the seam was reached. Also completed the Manifold browser E2E: filed an internal note in a real browser, appearing under "Internal — Not sent to the customer" below the reply box. Root-caused the harness trouble by elimination — navigating a freshly created tab to the Flutter Console kills the canvas, navigating an already-warm tab works; scrolling was never broken, the tab was half-dead. Gates: 48 authority, 281 platform server, 31 API, Console analyze clean.
- A citadel_core/platform/server/test/palisade_fail_closed_test.dart
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/authority/lib/src/authority.dart
- M citadel_core/palisade/authority/test/authority_test.dart

30/08/26 15:05 [FEAT] `claude-opus-5` Started Palisade with Task 6.1.5, which also unblocked Manifold. Added `exigence.context.read` and a `context` tool scope: reading another product's record of a client's end users is now separable from reading the client's own documents, which the closed set of five capabilities could not express. The catalogue export test forced the approval classification to be a deliberate edit rather than a silent one — `context.read` does not hold for approval because a read has no effect to reverse, and its sensitivity is the Data Handling Boundary's question. Built the data-flow audit in `palisade/boundary`: entries name actor, direction, data class, capability, grant path and outcome and never the data, with the constraints enforced rather than documented — over-long reasons refused rather than truncated, refused flows unable to claim a record count, failed reads recording the error's name because a provider message can carry the query and the query is made of the data. `auditedFlow` wraps the read so the recording belongs to the seam. The sink fails silently by design, opposite to the consent gate. No sink implementation or Console view yet, so DoD 12 is unmet. Gates: 46 Palisade authority, 26 boundary (was 18), 592 Exigence, 31 platform API, 275 platform server, analyzers clean.
- A citadel_core/palisade/boundary/src/data_flow_audit.ts
- A citadel_core/palisade/boundary/test/data_flow_audit.test.ts
- M citadel_core/palisade/boundary/src/index.ts
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/authority/test/catalogue_export_test.dart
- M citadel_core/palisade/catalogue.json
- M citadel_core/exigence/src/permission_catalogue.ts
- M citadel_core/exigence/test/policy_vocabulary_migration.test.ts

30/08/26 14:10 [FEAT] `claude-opus-5` Built Manifold 7.2.1's correlation engine and stopped at the capability question it exposed. `correlation.ts` proposes what a customer's report might be about from ARM issues and Conduit sessions in a window around when they wrote in, and the whole design is that it proposes rather than asserts: identity resolution across channels is deferred by the spec, so a confident answer would be a confident guess and acting on it opens the wrong customer's session replay. Candidates carry checkable reasons, ambiguity is stated rather than inferred from the count, and a test asserts the result never contains the words that would turn a proposal into an identification. Assessed 7.2.2 as already satisfied — both reply paths share the consent-gated channel, `external_comms` requires `exigence.communications.send`, and approval holds already exist. Blocked on which agent capability may read ARM/Conduit: the closed set of five would put it under `exigence.tools.read`, the same capability as searching the client's own documents, which cannot express "may read our handbook, may not read our customers' replays". Recorded in DECISIONS_NEEDED.md. 592 Exigence unit tests pass.
- A citadel_core/exigence/src/correlation.ts
- A citadel_core/exigence/test/correlation.test.ts
- M citadel_core/exigence/src/index.ts
- M DECISIONS_NEEDED.md

30/08/26 13:20 [FEAT] `claude-opus-5` Closed the receiver-grant divergence (`DECISIONS_NEEDED.md`): verification now reads each secret's IAM policy and checks the receiver's service account is bound, and a Resolve action closes the gap through Terraform rather than beside it. The check never decides whether a channel may be published — the grant is Terraform's, publication is read-only, and refusing would make a channel unpublishable until an apply landed. Resolve raises a provisioning plan rather than writing the binding: the module uses a non-authoritative `iam_member` so a direct grant would survive an apply, but it would be invisible to the configuration and vanish on the next build from scratch. Two prerequisites this exposed and required: the receiver's identity was a Terraform output and outputs are not persisted, so it is now recorded on the project; and `ProvisioningJob` stored no variables, so a repair composing a request from scratch would have reset `name_prefix`, `environment` and the media retention it never mentioned. The repair composes server-side from what is published — a body naming secret ids would let a caller grant a client's public receiver access to any secret they could name — excludes disabled channels, and unions rather than replaces. A secret outside the host project and one whose policy could not be read both read as `unknown` and are not offered as repairable. Gates: 275 platform server, 31 platform API, 4 contracts, 10 provisioner, 46 Palisade, 326 Console, analyzers clean, `terraform validate` passes. The contract test pinning `manifoldSecretProjectId` to the template's `host_project_id` default was verified by breaking the template. Projects provisioned before today have no recorded request or receiver and will read "unknown" until reprovisioned.
- A citadel_core/platform/server/test/manifold_receiver_grant_test.dart
- A citadel_core/platform/server/test/manifold_receiver_repair_test.dart
- M citadel_core/platform/server/lib/src/platform_manifold_verification.dart
- M citadel_core/platform/server/lib/src/platform_manifold_service.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/src/platform_provisioning_service.dart
- M citadel_core/platform/server/lib/src/platform_project_inventory_service.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- M citadel_core/platform/server/test/manifold_verifier_fixture.dart
- M citadel_core/platform/api/lib/src/manifold_channel_models.dart
- M citadel_core/platform/api/lib/src/manifold_channel_json.dart
- M citadel_core/platform/api/lib/src/platform_api_models.dart
- M citadel_core/platform/api/lib/src/platform_api_json.dart
- M citadel_core/platform/contracts/lib/src/core/domain/platform_domain_models.dart
- M citadel_core/platform/provisioner/bin/runner.dart
- M citadel_platform/lib/src/app/platform_workspace_api.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/platform_manifold_pages.dart
- M citadel_platform/test/platform_manifold_pages_test.dart

30/08/26 11:40 [FEAT] `claude-opus-5` Built Task 7.1.4's remaining half — assignment, internal notes and drafts — through the runtime, the Platform API, Palisade and the Console, then drove the inbox in Chrome. Corrected the handoff's assumption that conflicting replies were unhandled: `conversation_reply.ts` already checks `seenMessageId` before sending. What was missing was everything else. One append-only event log per thread holds hand-offs and notes together so there is a single account of what the team did; notes live apart from messages, because a note in the messages collection is a private remark sitting where every send path reads. One draft per thread rather than one per person, since two colleagues with the same thread open is the situation an inbox exists to survive. `platform.manifold.conversations.manage` gates the lot including its reads — a client's customers' words are the client's, an operator's note about that customer is not. The browser found what the widget tests could not: the open thread panel held a copy of the conversation taken when the row was tapped, so claiming a thread refreshed the table and left the panel offering "Assign to me", and the next click would have been refused. Fixed and pinned by a regression test. Notes remain undriven in a browser — below the fold, and the canvas would not scroll. Gates: 579 Exigence unit + 119 emulator, 259 platform server, 46 Palisade, 321 Console, analyzers clean. Also fixed a pre-existing emulator flake: both Manifold integration files swept the whole conversations collection on teardown while node ran them in parallel.
- A citadel_core/exigence/src/conversation_workspace.ts
- A citadel_core/exigence/test/conversation_workspace.integration.test.ts
- A citadel_core/exigence/test/manifold_workspace_api.test.ts
- M citadel_core/exigence/src/conversation_store.ts
- M citadel_core/exigence/src/conversation_reply.ts
- M citadel_core/exigence/src/manifold_api.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/exigence/src/reference_runtime_bootstrap.ts
- M citadel_core/exigence/src/index.ts
- M citadel_core/exigence/test/conversation_store.integration.test.ts
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/catalogue.json
- M citadel_core/platform/server/lib/src/platform_proxy_models.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/src/platform_permission_map.dart
- M citadel_core/platform/server/test/platform_proxy_handler_test.dart
- M citadel_core/platform/server/test/platform_permission_map_test.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/platform_manifold_pages.dart
- M citadel_platform/lib/main_dev.dart
- M citadel_platform/test/platform_manifold_inbox_test.dart
- M citadel_platform/test/platform_exigence_pages_test.dart

08/06/26 12:35 [FEAT] (no-git-repo) `dev-pro-large` Replaced example planning state with Citadel Platform-specific technical planning, generated the ordered feature roadmap across shared core, ARM, platform console, Conduit, Exigence, and Baker, and consolidated the existing ARM Tooling and ARM Console reference implementations under `arm/` without intentional implementation changes.
- M _dev/docs/technical_report.md
- M _dev/docs/release_timeline.md
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md

- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md

- A arm/README.md
- A arm/tooling
- A arm/console
- M _dev/features
08/06/26 12:45 [FEAT] (no-git-repo) `dev-pro-large` Validated consolidated ARM Tooling and ARM Console packages after copying them into the monorepo; both `flutter pub get` and `flutter analyze` passed, and generated `.dart_tool` / plugin metadata artifacts were removed from the workspace.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
08/06/26 12:45 [FEAT] (5453195) `dev-pro-large` Defined the first shared Citadel Platform domain-model slice in the `citadel_platform` package with storage-agnostic Freezed contracts for tenants, projects, identities, service accounts, API keys, offering entitlements, and audit events; added explicit per-offering project scope for ARM, Conduit, Exigence, and Baker; replaced the invalid starter app shell with a minimal platform placeholder; and documented the contract for the next core-substrate tasks.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- A _dev/docs/shared_domain_model.md
- M citadel_platform/pubspec.yaml

- M citadel_platform/lib/main.dart
- A citadel_platform/lib/citadel_platform.dart
- A citadel_platform/lib/src/app/citadel_platform_app.dart
- A citadel_platform/lib/src/core/domain/platform_domain_models.dart
- A citadel_platform/lib/src/core/domain/platform_domain_models.freezed.dart
- M citadel_platform/test/widget_test.dart

- A citadel_platform/test/src/core/domain/platform_domain_models_test.dart
08/06/26 12:51 [FEAT] (no-git-repo) `dev-pro-large` Recorded the architecture correction that `citadel_platform/lib` is a UI-only shell and that reusable schemas, middleware, service logic, and endpoint contracts must live in importable non-UI product modules so future surfaces such as a CLI can depend on them without inheriting Flutter UI code.
- M DECISIONS.md
- M CURRENT_TASK.md
- M _dev/session_log.md
- M _dev/docs/technical_report.md
- M _dev/docs/shared_domain_model.md
- M _dev/features/00-02-core-platform-substrate.md
08/06/26 12:56 [FEAT] (no-git-repo) `dev-pro-large` Updated the planning corpus to reflect the new three-package repo split of `citadel_core`, `citadel_cli`, and `citadel_platform`; changed the delivery order to core first, CLI second, platform UI later; corrected ARM path references to `citadel_core/arm/...`; and aligned the roadmap so CLI is the first consumer of core contracts before major user-facing UI work begins.
- M DECISIONS.md
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/session_log.md
- M _dev/docs/technical_report.md
- M _dev/docs/release_timeline.md
- M _dev/docs/shared_domain_model.md
- M _dev/features/00-01-planning-reset-and-arm-consolidation.md
- M _dev/features/00-02-core-platform-substrate.md
- M _dev/features/00-04-shared-protocols-and-sdks.md
- M _dev/features/01-01-arm-tooling-sdk.md
- M _dev/features/01-02-arm-console.md
- M _dev/features/01-03-arm-platform-integration.md
- M _dev/features/02-01-platform-console-website.md
08/06/26 13:05 [FIX] (no-git-repo) `dev-pro-large` Repointed the tracked ARM Firebase configuration surface to the `citadel-platform` workspace where that could be done safely by updating the console Firebase CLI alias, replacing the checked-in sample bootstrap config, and clarifying the docs for both the console and tooling; real Firebase web-app client credentials were intentionally left as placeholders because the target project's authoritative app registration values were not retrievable from the current environment.
- M CURRENT_TASK.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/arm/console/.firebaserc
- M citadel_core/arm/console/README.md
- M citadel_core/arm/console/projects.json
- M citadel_core/arm/tooling/README.md
- M citadel_core/arm/tooling/doc/installation.md
08/06/26 13:12 [FEAT] (no-git-repo) `dev-pro-large` Recorded the clarified Firebase architecture that all core tools share the `citadel-platform` Firebase project for platform-owned auth, permissions, registry, and internal metadata, while ARM telemetry and evidence remain in external client-owned Firebase projects; updated the shared technical plan and ARM docs to preserve that original direct-to-client-project telemetry boundary.
- M DECISIONS.md
- M CURRENT_TASK.md
- M _dev/session_log.md
- M _dev/docs/technical_report.md
- M _dev/features/01-02-arm-console.md
- M _dev/features/01-03-arm-platform-integration.md
- M citadel_core/arm/README.md
- M citadel_core/arm/console/README.md
08/06/26 13:46 [FEAT] (no-git-repo) `dev-pro-large` Completed Feature 2.1 by moving the shared platform contracts into the new reusable `citadel_core/platform/contracts` package, rewiring `citadel_platform` to consume them through thin Riverpod UI state, and replacing the placeholder app with a responsive Material 3 platform shell that includes the public landing page, central console, product directory, docs surface, and launch pages for ARM, Conduit, Exigence, and Baker; pure Dart contract tests, Flutter widget tests, static analysis, and local desktop/mobile browser smoke checks all passed, while commit creation remained blocked because the workspace root still has no `.git`.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/docs/shared_domain_model.md
- M _dev/test_status.md
- M _dev/session_log.md
- A citadel_core/platform/contracts/analysis_options.yaml
- A citadel_core/platform/contracts/lib/citadel_platform_contracts.dart
- A citadel_core/platform/contracts/lib/src/core/domain/platform_domain_models.dart
- A citadel_core/platform/contracts/lib/src/core/domain/platform_domain_models.freezed.dart
- A citadel_core/platform/contracts/pubspec.lock
- A citadel_core/platform/contracts/pubspec.yaml
- A citadel_core/platform/contracts/test/src/core/domain/platform_domain_models_test.dart
- M citadel_platform/lib/citadel_platform.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- A citadel_platform/lib/src/app/platform_state.dart
- D citadel_platform/lib/src/core/domain/platform_domain_models.dart
- D citadel_platform/lib/src/core/domain/platform_domain_models.freezed.dart
- M citadel_platform/pubspec.lock
- M citadel_platform/pubspec.yaml
- D citadel_platform/test/src/core/domain/platform_domain_models_test.dart
- M citadel_platform/test/widget_test.dart
08/06/26 14:02 [FEAT] (no-git-repo) `dev-pro-large` Completed Feature 0.2 by adding the reusable `citadel_core/platform/api` package for `/v1` route conventions, API error/pagination/idempotency/filtering/audit contracts, project-registry models, and development-auth posture; rewrote `citadel_cli` into the first consumer of those shared core contracts with inspect/validate command groups and docs; and updated the planning corpus with the resolved auth direction and the next sequential Terraform feature, while noting that Feature 0.3 cannot be finalized until a working `terraform` CLI is available in the environment.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- A _dev/docs/development_auth_posture.md
- A _dev/docs/project_registry_contract.md
- A _dev/docs/shared_api_conventions.md
- A citadel_core/platform/api/analysis_options.yaml
- A citadel_core/platform/api/lib/citadel_platform_api.dart
- A citadel_core/platform/api/lib/src/platform_api_models.dart
- A citadel_core/platform/api/lib/src/platform_api_models.freezed.dart
- A citadel_core/platform/api/pubspec.lock
- A citadel_core/platform/api/pubspec.yaml
- A citadel_core/platform/api/test/src/platform_api_models_test.dart
- A citadel_cli/README.md
- M citadel_cli/bin/citadel_cli.dart
- M citadel_cli/lib/citadel_cli.dart
- A citadel_cli/lib/src/citadel_cli_runner.dart
- M citadel_cli/pubspec.lock
- M citadel_cli/pubspec.yaml
- M citadel_cli/test/citadel_cli_test.dart
08/06/26 14:08 [FEAT] (no-git-repo) `dev-pro-large` Updated the planning corpus to defer all Baker work and all Terraform-dependent features for now, so active execution should skip Feature 0.3 and the Baker feature line and continue with the next non-Terraform sequence instead.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/session_log.md
- M _dev/docs/release_timeline.md
- M _dev/docs/technical_report.md
- M _dev/features/00-03-shared-infra-data-observability.md
- M _dev/features/05-01-baker-spec-designer.md
- M _dev/features/05-02-baker-generation-deployment.md
08/06/26 16:01 [FEAT] (no-git-repo) `dev-pro-large` Completed Feature 0.4 by extending the shared `citadel_core/platform/api` package with protocol, retry, streaming, SDK, and schema-versioning contracts; added the corresponding protocol and schema guidance docs; and expanded `citadel_cli` with inspect/validate commands for protocols, streaming, and schema posture so the conventions are executable and regression-tested, leaving Feature 1.1 ARM SDK stabilization as the next active sequence point.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- A _dev/docs/schema_versioning_guidance.md
- A _dev/docs/shared_protocol_conventions.md
- A _dev/docs/shared_sdk_conventions.md
- A _dev/docs/shared_streaming_conventions.md
- M citadel_core/platform/api/lib/citadel_platform_api.dart
- A citadel_core/platform/api/lib/src/platform_protocol_models.dart
- A citadel_core/platform/api/lib/src/platform_protocol_models.freezed.dart
- M citadel_core/platform/api/test/src/platform_protocol_models_test.dart
- M citadel_cli/README.md
- M citadel_cli/lib/src/citadel_cli_runner.dart
- M citadel_cli/test/citadel_cli_test.dart
08/06/26 16:20 [FEAT] (no-git-repo) `dev-pro-large` Completed Feature 1.1 by preserving the expected ARM Tooling public exports, adding regression coverage for fingerprint stability, case-exposure thresholds, payload sanitization, and tracked exception reporting, and rewriting the SDK docs around Citadel-specific setup plus the ARM issue/case data contract.
- M citadel_core/arm/tooling/lib/arm_tooling.dart
- M citadel_core/arm/tooling/README.md
- M citadel_core/arm/tooling/doc/installation.md
- M citadel_core/arm/tooling/doc/usage.md
08/06/26 16:20 [FEAT] (no-git-repo) `dev-pro-large` Completed Feature 1.2 by aligning the ARM Console local preview registry and seeded telemetry with the shared Citadel project ids, correcting the console registry/setup docs, adding a regression test for the local bootstrap project set, and extending the shared API sample registry so the CLI, platform shell, and console all reference the same preview project vocabulary.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/platform/api/lib/src/platform_api_models.dart
- M citadel_core/arm/console/README.md
- M citadel_core/arm/console/lib/src/app/app_bootstrap.dart
- M citadel_core/arm/console/lib/src/features/console_pages.dart
- M citadel_core/arm/console/lib/src/features/overview/data/overview_repository.dart
- M citadel_core/arm/console/lib/src/features/reports/data/reports_repository.dart
- M citadel_core/arm/console/lib/src/features/explorer/data/explorer_repository.dart
08/06/26 17:27 [FEAT] (de7e125) `dev-pro-large` Completed Feature 1.3 by converting the platform website to declarative routed navigation with deep-linkable ARM overview, issue, case, reports, and settings surfaces; wiring in a local ARM preview runtime so the platform app can self-report failures with route and project metadata; and documenting the derived-only aggregate reporting boundary plus the deferred intake-gateway posture for ARM.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- A _dev/docs/arm_aggregate_reporting_boundary.md
- A _dev/docs/arm_intake_gateway_posture.md
- M citadel_platform/lib/main.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- A citadel_platform/lib/src/app/platform_arm_preview.dart
- M citadel_platform/lib/src/app/platform_state.dart
- M citadel_platform/pubspec.yaml
- M citadel_platform/test/widget_test.dart
09/06/26 08:25 [FEAT] (de39d4b) `dev-pro-large` Rebuilt `citadel_platform` around a reusable dark design system aligned to the supplied service-page mockups, replaced the old monolithic shell with maintainable theme/shell/page modules, remapped ARM navigation to Console / Monitoring / Escalations / Issue Fingerprints / Case Logs, registered Cairo fonts, and verified the UI pass with Flutter tests, analyzer, and browser-level checks.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M citadel_platform/lib/main.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- A citadel_platform/lib/src/app/platform_arm_pages.dart
- A citadel_platform/lib/src/app/platform_pages.dart
- A citadel_platform/lib/src/app/platform_shell.dart
- A citadel_platform/lib/src/design_system/citadel_primitives.dart
- A citadel_platform/lib/src/design_system/citadel_shell.dart
- A citadel_platform/lib/src/design_system/citadel_theme.dart
- A citadel_platform/lib/src/design_system/citadel_tokens.dart
- M citadel_platform/pubspec.yaml
09/06/26 09:46 [FEAT] (4a45fc6) `dev-pro-large` Completed the ARM reference-layout follow-up inside `citadel_platform` by keeping the project selector persistent in the top bar across all screens, removing duplicate in-body project chips, rebuilding the ARM Monitoring / Escalations / Issue Fingerprints / Issue Detail / Case Logs views to track the provided service mockups more closely, and fixing the stacked Monitoring explorer layout after browser verification exposed an unbounded-height RenderFlex.
- M CURRENT_TASK.md
- M _dev/test_status.md
- M citadel_platform/lib/src/app/platform_arm_pages.dart
- M citadel_platform/lib/src/app/platform_pages.dart
- M citadel_platform/lib/src/app/platform_shell.dart
09/06/26 12:33 [FEAT] `dev-pro-large` Productionized the current ARM platform pass by replacing normal-runtime seeded workspace state with Firebase Auth plus Firestore-backed platform registry and ARM streams, adding a developer-only project configuration UI with Firestore writes, wiring real interactive filters into the ARM data views, tightening reusable hover/interaction states in the design system, deploying prototype Firestore rules and Google sign-in config to `citadel-platform`, and bootstrapping `obsidian.infinitum@gmail.com` as the shared platform developer/owner.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/firebase.json
- M citadel_core/firestore.rules
- M citadel_platform/lib/main.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_arm_pages.dart
- M citadel_platform/lib/src/app/platform_pages.dart
- M citadel_platform/lib/src/app/platform_shell.dart
- M citadel_platform/lib/src/app/platform_state.dart
- M citadel_platform/lib/src/design_system/citadel_primitives.dart

- M citadel_platform/lib/src/design_system/citadel_shell.dart
- M citadel_platform/lib/src/design_system/citadel_theme.dart
- M citadel_platform/pubspec.lock
- M citadel_platform/pubspec.yaml
- M citadel_platform/test/widget_test.dart
- A citadel_platform/lib/firebase_options.dart
- A citadel_platform/lib/src/app/platform_firestore.dart
- A citadel_platform/lib/src/app/platform_project_admin.dart
09/06/26 14:21 [FIX] (e577e9a) `dev-pro-large` Fixed the Firestore workspace-loading regression in `citadel_platform` by making Firestore emulator routing explicit instead of automatic in debug builds, keeping live Firebase reachable when no local emulator is running, and translating offline Firestore failures into actionable workspace/ARM error copy backed by a regression test.
15/06/26 15:38 [FEAT] (798cda8) `dev-pro-large` Applied the requested ARM service UI follow-up in `citadel_platform` by replacing the decorative top-bar search with route-aware product/page search, standardizing ARM view headers into a shared main-area bar, moving alerting workflows into inline main-area panels instead of dead dialog-style actions, rebuilding Monitoring around a vertical fields rail plus stacked timeline/log table with a real line graph, removing hardcoded alert policy rows, and tightening Console metrics into compact square cards while preserving passing analyzer and widget-test coverage.
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_arm_pages.dart
- M citadel_platform/lib/src/app/platform_pages.dart
- M citadel_platform/lib/src/app/platform_shell.dart
- M citadel_platform/lib/src/design_system/citadel_primitives.dart
- M citadel_platform/lib/src/design_system/citadel_shell.dart
- M citadel_platform/lib/firebase_options.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
09/06/26 14:30 [FIX] `dev-pro-large` Added a local `citadel_platform` run helper so Firebase dart-defines no longer need to be typed manually; the new shell script sources `citadel_core/.env`, forwards the platform Firebase web config, and exposes an explicit Firestore emulator switch while the platform README now documents the command.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_platform/README.md
- A citadel_platform/scripts/flutter_with_platform_env.sh
09/06/26 15:19 [FEAT] `dev-pro-large` Replaced the old single-sheet project editor with a reusable multi-step onboarding wizard that can be launched from the top-bar project selector or dashboard registry panel, added live target-auth and Firestore read probes for unsaved ARM Firebase configs before registry writes, and covered the selector-driven onboarding entry point with widget tests while preserving the existing registry listing flow.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/platform_pages.dart
- M citadel_platform/lib/src/app/platform_project_admin.dart
- M citadel_platform/lib/src/app/platform_shell.dart
- M citadel_platform/test/widget_test.dart
- A citadel_platform/lib/src/app/platform_project_onboarding.dart
16/06/26 09:55 [FEAT] (no-git-repo) `dev-pro-large` Split the generated Conduit backlog into sequential feature docs under `_dev/features` so the higher-fidelity SDK, ingest, replay, heatmap, journey, analytics, monitoring, and VoC tasks now map cleanly to features 3.1 through 3.8, and removed the stale legacy Conduit analytics doc to avoid duplicate numbering.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- D _dev/features/03-01-conduit-ingestion-data-stack.md
- D _dev/features/03-02-conduit-console-analytics.md
- A _dev/features/03-01-conduit-sdk-core-instrumentation.md
- A _dev/features/03-02-conduit-event-ingest-api-storage-pipeline.md
- A _dev/features/03-03-conduit-session-replay-player.md
- A _dev/features/03-04-conduit-heatmaps.md
- A _dev/features/03-05-conduit-journey-and-funnel-analysis.md
- A _dev/features/03-06-conduit-web-analytics-overview.md
- A _dev/features/03-07-conduit-experience-monitoring.md
- A _dev/features/03-08-conduit-voice-of-customer.md
16/06/26 10:13 [FEAT] (bebb05f) `dev-pro-large` Replaced the starter Conduit package with the first embedded Flutter-web SDK slice in `citadel_core/conduit/citadel_conduit_sdk`, adding real config/bootstrap models, browser bindings, batched HTTP transport, pageview and interaction capture, rage/dead click and scroll-threshold detection, consent-aware queuing, package docs, and unit coverage aligned to Feature 3.1.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_sdk/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_sdk/README.md
- M citadel_core/conduit/citadel_conduit_sdk/pubspec.yaml
- A citadel_core/conduit/citadel_conduit_sdk/lib/citadel_conduit_sdk.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_browser_bindings.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.freezed.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_sdk.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_transport.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/runtime/conduit_browser_bindings_factory_stub.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/runtime/conduit_browser_bindings_factory_web.dart
- A citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_sdk_test.dart
16/06/26 10:46 [FEAT] (b39d6f3) `dev-pro-large` Advanced Conduit SDK Feature 3.1-B by adding browser performance and error diagnostics, reusable keepalive upload requests, retryable transport delivery with exponential backoff and jitter, package docs for the expanded surface, and a documented decision point around unload auth versus true `sendBeacon` support while keeping analyzer and tests green in the Conduit package.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_sdk/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_sdk/README.md
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_browser_bindings.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_transport.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/runtime/conduit_browser_bindings_factory_web.dart
16/06/26 11:10 [FEAT] (91ef17e) `dev-pro-large` Continued Conduit SDK Feature 3.1-B by resolving the unload transport choice in favor of standards-based `fetch(..., keepalive: true)`, patching the web runtime to auto-intercept `fetch`, `XMLHttpRequest`, and History API route changes, and adding self-filter coverage so Conduit does not recursively instrument its own ingest traffic while preserving a clean analyze/test run.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_sdk/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_sdk/README.md
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/runtime/conduit_browser_bindings_factory_web.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_sdk_test.dart
16/06/26 12:55 [FEAT] (de69c0d) `dev-pro-large` Extended Conduit SDK Feature 3.1-B with a configurable Flutter-oriented attention contract by adding per-project attention config, milestone versus exit emission modes, and SDK attention APIs for logical section tracking so future widget/semantics integrations can report attention without HTML section assumptions.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_sdk/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_sdk/README.md
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.freezed.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_transport.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_sdk_test.dart
16/06/26 12:59 [FEAT] (no-git-repo) `dev-pro-large` Clarified the Conduit operating model in project memory: Citadel Platform UI remains a high-level tuning, dashboard, and management surface, while low-level SDK instrumentation and precise attention/dwell boundaries are still authored manually inside each target Flutter project by wrapping widgets and writing explicit SDK/API calls.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/session_log.md
16/06/26 13:04 [FEAT] (8fc92c9) `dev-pro-large` Completed the remaining Flutter-first Conduit SDK scope in Task 3.1-B by adding the manual `ConduitAttentionRegion` wrapper for widget-level attention boundaries, routing upload requests through browser-side request preparation so `CompressionStream` gzip can be used when available, and extending widget/unit coverage while keeping the package green under analyze and test.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_sdk/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_sdk/README.md
- M citadel_core/conduit/citadel_conduit_sdk/lib/citadel_conduit_sdk.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_attention_region.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_browser_bindings.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_transport.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/runtime/conduit_browser_bindings_factory_stub.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/runtime/conduit_browser_bindings_factory_web.dart
- A citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_attention_region_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_sdk_test.dart
16/06/26 13:10 [FEAT] (05676fd) `dev-pro-large` Scaffolded the first Conduit ingest service package in `citadel_core/conduit/citadel_conduit_ingest`, defining canonical normalized event/config contracts, JSON Schema, gzip-aware batch decoding, `X-Conduit-Key` auth, fixed-window per-project rate limiting, config bootstrap reads, and async sink abstractions with unit coverage for validation and handler behavior.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- A citadel_core/conduit/citadel_conduit_ingest/CHANGELOG.md
- A citadel_core/conduit/citadel_conduit_ingest/README.md
- A citadel_core/conduit/citadel_conduit_ingest/analysis_options.yaml
- A citadel_core/conduit/citadel_conduit_ingest/bin/citadel_conduit_ingest.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_ingest.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.freezed.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_schema.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_service.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_validation.dart
- A citadel_core/conduit/citadel_conduit_ingest/pubspec.yaml
- A citadel_core/conduit/citadel_conduit_ingest/test/src/conduit_ingest_handler_test.dart
- A citadel_core/conduit/citadel_conduit_ingest/test/src/conduit_ingest_validation_test.dart
16/06/26 13:10 [FIX] (cf5b3e0) `dev-pro-large` Removed accidentally tracked local Dart build artifacts from `citadel_core/conduit/citadel_conduit_ingest` and added package-level ignore rules so the Conduit sub-repo only retains source, generated freezed code, and intentional package metadata for the new ingest service.
- M _dev/session_log.md
- A citadel_core/conduit/citadel_conduit_ingest/.gitignore
16/06/26 13:59 [FEAT] (ee42342) `dev-pro-large` Completed the first Flutter-first Conduit Voice of Customer SDK slice by adding feedback widget contracts, direct `/v1/voc/feedback` submission, and a reusable `ConduitFeedbackWidget` to `citadel_core/conduit/citadel_conduit_sdk`, keeping widget placement and screenshot capture explicit in target-app Flutter code while extending transport and test coverage around the new VoC path.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_sdk/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_sdk/README.md
- M citadel_core/conduit/citadel_conduit_sdk/lib/citadel_conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.freezed.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_feedback_widget.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_transport.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_attention_region_test.dart
- A citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_feedback_widget_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_sdk_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_transport_test.dart
16/06/26 13:59 [FEAT] (d464376) `dev-pro-large` Brought the Conduit service pages in `citadel_platform/lib` up to pace with the actual SDK by replacing generic placeholders with Conduit-specific overview, instrumentation, experience, replay-status, and Voice of Customer surfaces that only display actions, states, and integration responsibilities the product can truthfully support today.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- A citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_pages.dart
- M citadel_platform/lib/src/app/platform_shell.dart
- M citadel_platform/lib/src/app/platform_state.dart
- M citadel_platform/test/widget_test.dart
16/06/26 14:07 [FEAT] (e218bbc) `dev-pro-large` Completed Conduit Voice of Customer Task 3.8-B by adding Flutter-first trigger-aware poll contracts, client-side activation for first-visit/time-on-view/scroll/custom-event triggers, direct `/v1/voc/poll-responses` submission, and a reusable `ConduitPollWidget` in `citadel_core/conduit/citadel_conduit_sdk`, while keeping poll placement and low-level trigger wiring manual in target-project code.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_sdk/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_sdk/README.md
- M citadel_core/conduit/citadel_conduit_sdk/lib/citadel_conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.freezed.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_poll_widget.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_transport.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_attention_region_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_feedback_widget_test.dart
- A citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_poll_widget_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_sdk_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_transport_test.dart
16/06/26 14:07 [FEAT] (2322625) `dev-pro-large` Advanced the Conduit platform surface in `citadel_platform/lib` so the overview and Voice of Customer views now advertise live poll support, the exact Flutter-first trigger set, and the manual host-app responsibilities around `ConduitPollWidget` and custom trigger wiring instead of continuing to label polls as pending.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/test/widget_test.dart
16/06/26 14:12 [FEAT] (4026dbb) `dev-pro-large` Completed Conduit Voice of Customer Task 3.8-C by adding multi-question survey definitions, conditional question visibility, direct `/v1/voc/survey-responses` submission, and a reusable `ConduitSurveyWidget` to `citadel_core/conduit/citadel_conduit_sdk`, while keeping survey placement and app-specific trigger hooks manual in target Flutter projects and leaving hosted/shareable survey delivery explicitly out of the implemented SDK scope.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_sdk/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_sdk/README.md
- M citadel_core/conduit/citadel_conduit_sdk/lib/citadel_conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.freezed.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_sdk.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_survey_widget.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_transport.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_attention_region_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_feedback_widget_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_poll_widget_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_sdk_test.dart
- A citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_survey_widget_test.dart
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_transport_test.dart
16/06/26 14:12 [FEAT] (5abd9c3) `dev-pro-large` Advanced the Conduit platform Voice of Customer surface in `citadel_platform/lib` so overview and VoC pages now advertise branching survey support, the role of `ConduitSurveyWidget`, and the current gap around hosted/shareable survey delivery instead of continuing to treat all surveys as entirely pending.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/test/widget_test.dart
16/06/26 14:39 [FEAT] (8fab829, 56e4d5b) `dev-pro-large` Completed the Flutter-native Conduit replay and heatmap capture foundation by adding config-driven replay/heatmap request orchestration, manual `RepaintBoundary`-backed SDK capture surfaces, direct replay/heatmap submission transport, and aligned Conduit platform copy that now advertises the real capture foundation instead of treating replay and heatmaps as architecture-blocked DOM features.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_sdk/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_sdk/README.md
- M citadel_core/conduit/citadel_conduit_sdk/lib/citadel_conduit_sdk.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_heatmap_surface.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_models.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_replay_capture_surface.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_sdk.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_transport.dart
- A citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_visual_capture.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/test/widget_test.dart
16/06/26 15:59 [FEAT] (74d147c, d12a42a) `dev-pro-large` Completed the next Conduit replay and heatmap backend/console foundation slice by extending `citadel_conduit_ingest` with replay snapshot intake, heatmap surface intake, session metadata indexing/search, and replay/heatmap config serialization, while bringing `citadel_platform` up to pace with a real session-replay shell, a first Heatmaps module shell, shared replay deep-link routing, and truthful navigation/search surfaces that match the implemented backend contracts without inventing live datasets or renderers.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_ingest/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_ingest/README.md
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_service.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_validation.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_shell.dart
16/06/26 16:22 [FEAT] (9707850, 3aace79) `dev-pro-large` Advanced the Conduit backend and console again by extending `citadel_conduit_ingest` with event indexing, replay retrieval, session metadata updates, and a first heatmap overlay query contract tied to the current Flutter SDK event vocabulary, while updating the `citadel_platform` Replay and Heatmaps pages so they now describe the real retrieval, curation, and query surfaces instead of stopping at intake-only shell copy.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_ingest/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_ingest/README.md
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_service.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_validation.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/test/widget_test.dart
16/06/26 16:44 [FEAT] (abbc6c1, cf7646c) `dev-pro-large` Completed the next Conduit replay and heatmap platform slice by exposing Flutter-safe ingest contracts plus heatmap preview-image round-tripping in `citadel_conduit_ingest`, then wiring `citadel_platform` to a truthful Conduit repository layer with seed-backed replay search/playback, timeline markers, metadata curation, and first rendered heatmap overlay review surfaces while preserving no-source behavior for normal app runs; the next Conduit persistence step is now explicitly tracked as a registry-shape decision between reusing `armFirebase` and introducing a dedicated `conduitFirebase` boundary.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- A citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_contracts.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_service.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- A citadel_platform/lib/src/app/platform_conduit_repository.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/pubspec.yaml

16/06/26 16:56 [FEAT] (1613621, b76de2f) `dev-pro-large` Settled Conduit onto the shared project-level `targetFirebase` boundary, updated project onboarding and shell connection flows to reuse that customer Firebase config across ARM and Conduit, added a shared Conduit Firestore document contract in `citadel_conduit_ingest`, and replaced the normal-mode seed/no-op Conduit console path with a live Firestore-backed repository for sessions, replay snapshots, canonical events, heatmap surfaces, and metadata curation in `citadel_platform`, while recording the remaining backend blocker around server-side customer-Firebase write credentials.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_contracts.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_schema.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/platform_project_onboarding.dart
- M citadel_platform/lib/src/app/platform_shell.dart

17/06/26 13:32 [FEAT] (6e2c7b0, 6c90696) `dev-pro-large` Implemented the approved central Conduit service-identity backend path and completed the next operator-facing Conduit feature slice by adding durable customer-Firebase persistence adapters plus shared web-analytics aggregation helpers in `citadel_conduit_ingest`, then wiring `citadel_platform` to a real Conduit Analytics Overview dashboard with repository-backed summary metrics, traffic/source views, top-page analysis, visitor mix, and deep links into Heatmaps from both Replay and Analytics flows.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_ingest/CHANGELOG.md
- M citadel_core/conduit/citadel_conduit_ingest/README.md
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_contracts.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_ingest.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_analytics.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_persistence.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_schema.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_types.dart
- A citadel_core/conduit/citadel_conduit_ingest/test/src/conduit_analytics_test.dart
- A citadel_core/conduit/citadel_conduit_ingest/test/src/conduit_firestore_persistence_test.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart
- M citadel_platform/lib/src/app/platform_project_onboarding.dart
- M citadel_platform/lib/src/app/platform_shell.dart

17/06/26 14:01 [FEAT] (ceab349, 91e2228) `dev-pro-large` Completed the first real Conduit Experience Monitoring slice by adding shared CWV, JS/runtime error, API failure, page-performance, frustration, and timeline aggregations in `citadel_conduit_ingest`, then replacing the old `/conduit/experience` status shell in `citadel_platform` with a repository-backed dashboard that works across live Firestore, seed preview, and no-source modes while linking into Replay and Heatmaps only where real context exists.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_contracts.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_ingest.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_experience.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/06/26 14:59 [FEAT] (2f114a8, 8e17673) `dev-pro-large` Completed the next Conduit Experience Monitoring follow-on slice by adding stable grouped-error fingerprints, replay session search handoff, project-scoped API error monitoring rule contracts, and source-map release registry foundations in `citadel_conduit_ingest`, then wiring `citadel_platform` so grouped JS/API failures can jump into Replay search while `/conduit/experience` now exposes operator-facing API monitoring settings and source-map release management aligned to the truthful backend surface.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_contracts.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_experience.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_persistence.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_schema.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_service.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart
- M citadel_platform/lib/src/app/platform_firestore.dart

17/06/26 15:10 [FEAT] (44740ec, b7d518c) `dev-pro-large` Completed the next Conduit Experience Monitoring ops slice by adding shared synthetic monitoring and alerting contracts, Firestore schemas, and a reusable synthetic overview aggregator in `citadel_conduit_ingest`, then replacing the `/conduit/alerts` redirect in `citadel_platform` with a repository-backed console page for probe definitions, threshold rules, synthetic status summaries, and stored alert history while keeping the scheduled runner and outbound delivery paths explicitly marked as follow-on backend work.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_contracts.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_ingest.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_alerting.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_schema.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/platform_shell.dart

25/06/26 08:03 [FIX] (no-commit-yet) `dev-pro-large` Clarified the `citadel_core/arm/tooling` package docs and package-local development instructions so ARM error capture must persist the raw runtime error name and raw error payload text directly in `errorType` and `message`, with any app-specific labeling kept in classification fields instead of wrapping the stored error values.
- M CURRENT_TASK.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/arm/tooling/AGENTS.md
- M citadel_core/arm/tooling/README.md
- M citadel_core/arm/tooling/doc/usage.md

26/06/26 11:24 [FEAT] (0e38b19) `dev-pro-large` Upgraded the ARM operator surface in `citadel_platform` by replacing the placeholder monitoring timeline with real timestamped range navigation and interval controls, formatting structured ARM payloads/log details for issue review, and enabling developer/operator status edits that write additive status metadata directly into the monitored client Firestore `armIssues` and `armCases` documents instead of staying console-read-only.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_arm_pages.dart
- A citadel_platform/lib/src/app/platform_arm_status.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/platform_state.dart

26/06/26 11:44 [FEAT] (no-commit-yet) `dev-pro-large` Hardened the ARM tooling SDK session-context capture path so configured UID, email, route, and session id metadata stay authoritative in the emitted case `context` payload, added regression coverage for that behavior, and updated the package docs/instructions to document the stored session identity fields explicitly.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/arm/tooling/AGENTS.md
- M citadel_core/arm/tooling/README.md
- M citadel_core/arm/tooling/doc/installation.md
- M citadel_core/arm/tooling/doc/usage.md
- M citadel_core/arm/tooling/lib/src/arm_client.dart
- M citadel_core/arm/tooling/test/src/arm_client_test.dart

26/06/26 12:17 [FEAT] (no-commit-yet) `dev-pro-large` Split the ARM SDK into a shared pure-Dart core package plus a new server/runtime package, rewired the existing Flutter client SDK onto that shared contract layer, and documented the new request-aware server capture flow, service-account Firestore sink, and raw normalized server error contract so external consumers can migrate off bespoke ARM reporters.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M _dev/test_status.md
- M _dev/session_log.md
- M citadel_core/arm/README.md
- M citadel_core/arm/arm_sdk_migration/README.md
- M citadel_core/arm/arm_sdk_migration/current-state.md
- M citadel_core/arm/tooling/AGENTS.md
- M citadel_core/arm/tooling/README.md
- M citadel_core/arm/tooling/doc/installation.md
- M citadel_core/arm/tooling/doc/usage.md
- M citadel_core/arm/tooling/lib/arm_tooling.dart
- M citadel_core/arm/tooling/lib/src/arm_client.dart
- M citadel_core/arm/tooling/lib/src/arm_firebase_sink.dart
- A citadel_core/arm/tooling_core/AGENTS.md
- A citadel_core/arm/tooling_core/README.md
- A citadel_core/arm/tooling_core/lib/arm_tooling_core.dart
- A citadel_core/arm/tooling_core/lib/src/arm_documents.dart
- A citadel_core/arm/tooling_server/AGENTS.md
- A citadel_core/arm/tooling_server/README.md
- A citadel_core/arm/tooling_server/lib/arm_tooling_server.dart
- A citadel_core/arm/tooling_server/lib/src/arm_server.dart
- A citadel_core/arm/tooling_server/lib/src/arm_firestore_service_account_sink.dart
12/07/26 --:-- [FIX/FEAT] (no-commit-yet) `dev-pro-large` Console-wide UX and GCP-style pass over `citadel_platform`: live top-bar search suggestions with provenance bylines (product · route) via an anchored overlay; dashboard rescoped to the selected project only (workspace/registry panels removed); ARM Console Focus Point and case-log fingerprint values hyperlinked to their detail views through a new `CitadelLinkText` primitive and `CitadelDetailLine.valueWidget`; ARM Monitoring windows extended to 14/30/90 days and month-to-date with week-scale intervals and date-based tick labels; Issue Fingerprint occurrence charts now bucket real linked-case `detectedAt` timestamps (fabricated `_issueChartValues` deleted, explicit no-data states added); horizontal swipe back-navigation disabled via `overscroll-behavior` CSS and a no-animation `PageTransitionsTheme`; left rail selection resolved to a single longest-prefix match (fixes double-selection); dev-facing meta copy replaced with production-visible copy across Dashboard, Exigence, Baker, and all Conduit pages, and Conduit page headers trimmed of redundant nav buttons. NOTE: `flutter analyze`/`flutter test` NOT run this session (local sandbox unavailable — disk full); verify before committing.
- M citadel_platform/web/index.html
- M citadel_platform/lib/src/design_system/citadel_theme.dart
- M citadel_platform/lib/src/design_system/citadel_shell.dart
- M citadel_platform/lib/src/design_system/citadel_primitives.dart
- M citadel_platform/lib/src/app/platform_shell.dart
- M citadel_platform/lib/src/app/platform_pages.dart
- M citadel_platform/lib/src/app/platform_arm_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M CURRENT_TASK.md
- M _dev/session_log.md

17/07/26 18:18 [FEAT] (c44e4d9) `dev-pro-large` Completed the Conduit table/form visual depth pass in `citadel_platform` by adding shared responsive control-bar, finite-width table, and inset form-section primitives; migrating Analytics, Replay, Heatmaps, and Experience filters plus Replay/Analytics tables; removing redundant page-header navigation; grouping probe and alert-rule editors from saved records; and adding narrow-width regression coverage for layout and replay selection. `flutter analyze` and all 21 tests pass.
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/design_system/citadel_primitives.dart
- M citadel_platform/test/widget_test.dart

17/07/26 18:18 [FEAT] (1632c5f) `dev-pro-large` Completed the remaining Conduit record-management visual pass by grouping the Experience API-error and source-map editors, migrating saved API rules, source-map releases, alert rules, and alert history to responsive table surfaces, and adding narrow-width regression coverage. `flutter analyze` and all 22 platform tests pass.
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/test/widget_test.dart

17/07/26 18:43 [FEAT] (bbaf7f6) `dev-pro-large` Added the Firebase-first Conduit journey-analysis core with public request/response contracts, deterministic session-level path aggregation, canonical URL grouping, distinct-session transition and drop-off metrics, project-config Firestore codecs, and comprehensive filter and empty-state coverage. `dart analyze` is clean and all 41 `citadel_conduit_ingest` tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_contracts.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_ingest.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_schema.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_journeys.dart

17/07/26 18:59 [FEAT] (7622ba1) `dev-pro-large` Added the Firebase-first `/conduit/journeys` console with customer-boundary repository aggregation, stable date/device/page filters, a responsive weighted flow canvas, node reroot and replay handoff, entry/exit distributions, ordered URL-grouping controls, rail/search navigation, and focused populated, persistence, and narrow-width coverage. `flutter analyze` is clean and all 25 platform tests pass.
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- A citadel_platform/lib/src/app/platform_conduit_journeys_page.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart
- M citadel_platform/lib/src/app/platform_shell.dart

17/07/26 19:12 [FEAT] (87cb4cf) `dev-pro-large` Extended Conduit journey aggregation with deterministic hierarchical path trees, distinct-session prefix counts, stable path identities, and exact ordered prefix filtering reusable by interactive visualization arcs. `dart analyze` is clean and all 44 `citadel_conduit_ingest` tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_journeys.dart

17/07/26 19:12 [FEAT] (5c412b7) `dev-pro-large` Added the responsive Journey Sunburst view with a Flow/Sunburst selector, proportional concentric path arcs, real arc hit testing, exact prefix-filtered session totals, clear-path controls, honest last-page replay scope, and sub-340px regression coverage. `flutter analyze` is clean and all 26 platform tests pass.
- M citadel_platform/lib/src/app/platform_conduit_journeys_page.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/07/26 19:32 [FEAT] (aceada4) `dev-pro-large` Added the reusable Conduit funnel core with saved definition and typed-step contracts, ordered non-contiguous page/pattern/custom-event matching, conversion/drop-off and P50/P75 metrics, device/source comparisons, public attribution reuse, and customer-Firestore map codecs. `dart analyze` is clean and all 50 `citadel_conduit_ingest` tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_contracts.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/citadel_conduit_ingest.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_analytics.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_schema.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_funnels.dart

17/07/26 19:50 [FEAT] (4b04db6) `dev-pro-large` Added the Conduit platform funnel data layer with customer-boundary definition list/upsert and analysis adapters, explicit preview persistence and seed analysis, truthful no-source behavior, and repository coverage.
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/07/26 19:50 [FEAT] (b436cf6) `dev-pro-large` Added the routed Funnel Analysis console with saved-definition selection, typed add/remove/reorder builder, dirty-draft protection, responsive stepped conversion/drop-off/timing visualization, complete device/source comparisons, truthful zero-data rendering, rail/search integration, date-bounded live Firestore session queries, batched matching-session event reads, and auto-disposed analysis state. `flutter analyze` is clean and all 33 platform tests pass.
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- A citadel_platform/lib/src/app/platform_conduit_funnels_page.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart
- M citadel_platform/lib/src/app/platform_shell.dart

17/07/26 20:08 [FEAT] (ea21614) `dev-pro-large` Completed the reusable funnel cohort contract by exposing deterministic entered-step and dropped-at-step session identities from aggregation while preserving backward-compatible defaults and customer-boundary semantics. `dart analyze` is clean and all 50 `citadel_conduit_ingest` tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_funnels.dart

17/07/26 20:08 [FEAT] (8b645ae) `dev-pro-large` Closed Feature 3.5 with shareable saved-funnel routes, copied semantic links, interactive entered/drop-off counts, exact Replay cohort resolution across Firestore and preview repositories, correct empty-cohort behavior, and reset/invalid-route states. `flutter analyze` is clean and all 37 platform tests pass.
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_funnels_page.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/07/26 20:23 [FIX] (011f11e) `dev-pro-large` Corrected Conduit Web Analytics aggregation to use canonical event occurrence time, pageview-based engagement formulas, distinct active visitors, boundary-safe five-class attribution, query-free and project-grouped page paths, and event-derived OS dimensions; expanded regression coverage for delayed delivery, repeated pageviews, all attribution classes, active-session deduplication, and dynamic URL grouping. `dart analyze` is clean and all 53 tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_analytics.dart

17/07/26 20:23 [FEAT] (58b8cf0) `dev-pro-large` Hardened the Firebase-first Analytics Overview with a stable refresh anchor, auto-disposed query state, session-window and participating-visitor/session-event bounded Firestore reads, project URL-grouping reuse, OS distribution, selectable traffic-source details, paginated top pages, correct bounce-rate tone, and verified Heatmap navigation. `flutter analyze` is clean and all 38 platform tests pass.
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/07/26 20:23 [FEAT] (f2498a4) `dev-pro-large` Added explicit hourly, daily, and weekly Analytics timeline controls with window-aware defaults and replaced the visitor-mix stacked bars with the specified new-versus-returning dual-line trend. `flutter analyze` is clean and all 38 platform tests pass.
- M citadel_platform/lib/src/app/platform_conduit_pages.dart

17/07/26 20:49 [FEAT] (b7fafbc) `dev-pro-large` Closed Feature 3.6 with a production local country choropleth backed by a reduced Natural Earth 1:50m public-domain boundary asset, native Flutter projection/painting/hit testing, proportional live session intensity, mouse and touch tooltips, accessible summaries, active microstate markers, responsive legend behavior, and truthful empty/load-error fallbacks. `flutter analyze` is clean and all 40 platform tests pass.
- A citadel_platform/assets/maps/README.md
- A citadel_platform/assets/maps/ne_50m_countries.geojson
- A citadel_platform/lib/src/app/platform_conduit_choropleth.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/pubspec.yaml

17/07/26 20:58 [FIX] (31ce69e) `dev-pro-large` Corrected Experience aggregation to use canonical event time, isolate projects, normalize reversed windows, filter by country, strip query strings, and reuse project URL-grouping rules; added delayed-delivery, isolation, country, grouping, and reversed-window regressions. `dart analyze` is clean and all 55 core tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_experience.dart

17/07/26 20:58 [FIX] (53fd46c) `dev-pro-large` Stabilized and auto-disposed Experience requests, bounded customer Firestore session/event reads to the selected range, reused project URL-grouping rules, anchored preview data to canonical timestamps, and added a country control with repository and widget regressions. `flutter analyze` is clean and all 41 platform tests pass.
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/07/26 21:12 [FEAT] (d30c0bc) `dev-pro-large` Added exact sorted JS/API/frustration session cohorts, nonnegative session-relative sample offsets, and endpoint-plus-status API grouping across HTTP methods with endpoint-wide request rates. `dart analyze` is clean and all 56 core tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_experience.dart

17/07/26 21:12 [FEAT] (65a9c28) `dev-pro-large` Added shareable exact Experience cohort routes, elapsed-seek error Replay links, inline stored JavaScript diagnostic detail, exact error/frustration session actions, rage/dead Heatmap routing, and responsive shared list-item action stacking. `flutter analyze` is clean and all 44 platform tests pass.
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/design_system/citadel_primitives.dart

17/07/26 21:21 [FIX] (4889cf7) `dev-pro-large` Hardened pure synthetic aggregation with project isolation, normalized inclusive windows, deterministic ordering, exact uptime/P95 coverage, and explicit latest success state for probe/location recovery. `dart analyze` is clean and all 57 core tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_alerting.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart

17/07/26 21:21 [FIX] (2f379ba) `dev-pro-large` Stabilized and auto-disposed Synthetic requests, bounded customer Firestore reads by check time, rendered truthful latest-check state, rejected unsafe/non-HTTP probe targets and invalid probe/alert values, and added behavior coverage. `flutter analyze` is clean and all 45 platform tests pass.
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/07/26 21:27 [FIX] (7fecfa4, 7b25664) `dev-pro-large` Removed browser submission of Slack webhook credentials, forced browser-created alert notifications to email, redacted legacy Slack rule targets and HTTP(S) alert-history targets, preserved email target persistence, and added security regressions. `flutter analyze` is clean and all 45 platform tests pass.
- M citadel_platform/lib/src/app/platform_conduit_pages.dart

17/07/26 21:36 [FIX] (39f056e) `dev-pro-large` Isolated Experience and Alerts state by selected project, added one-time context-key hydration that preserves deliberate edits, reset complete draft/filter/detail state across project changes, and verified independent project keys and probe selections. `flutter analyze` is clean and all 47 platform tests pass.
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart

17/07/26 21:50 [FEAT] (47a4afd) `dev-pro-large` Made API monitoring rules operational in Experience aggregation with endpoint-glob/status matching, stored-order precedence, disabled/body-conditioned exclusion, matched custom naming, and deterministic output. `dart analyze` is clean and all 58 core tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_experience.dart

17/07/26 21:50 [FEAT] (0a8b8ea) `dev-pro-large` Propagated customer project API monitoring rules through live and preview Experience repositories, surfaced matched custom names, added explicit rule validation, disabled unavailable response-body matching, marked legacy body rules inactive, and corrected customer-boundary storage copy. `flutter analyze` is clean and all 48 platform tests pass.
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/07/26 21:59 [FEAT] (aa4a715) `dev-pro-large` Added canonical page-performance poor-session cohorts, deterministic poor representative selection, and ordered resource/long-task timing waterfalls, including an event-window regression for a session that began before the range. `dart analyze` is clean and all 59 core tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_experience.dart

17/07/26 21:59 [FEAT] (a057453) `dev-pro-large` Added expandable page-performance waterfalls and exact poor-session Replay drilldowns, changed live Experience loading to fetch session metadata from participating in-window events, and added repository/widget coverage. `flutter analyze` is clean and all 49 platform tests pass.
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/07/26 22:29 [FEAT] (f837c13) `dev-pro-large` Added type-aware JavaScript error groups, legacy-compatible fingerprint matching, counted browser/OS dimensions, bounded adaptive occurrence trends, atomic diagnostic samples, and exact sorted occurrence offsets; also corrected waterfall timing-session selection and timing-only diagnostics. `dart analyze` is clean and all 62 core tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_experience.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_persistence.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_service.dart

17/07/26 22:29 [FEAT] (5d0ad9a) `dev-pro-large` Added counted JavaScript error detail, adaptive trend charts, source positions, exact millisecond occurrence replay, automatic filtered-cohort pre-seek, historical fingerprint compatibility, and trusted exact-cohort reads without a project-wide fallback scan; separated poor and waterfall replay actions. `flutter analyze` is clean and all 51 platform tests pass.
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

17/07/26 22:54 [FEAT] (e347dda) `dev-pro-large` Completed the Firebase-first Voice of Customer submission spine with SDK-compatible feedback, poll, and survey contracts, strict customer-boundary and response validation, authenticated rate-limited HTTP acceptance, traversal-safe retry-idempotent record IDs, canonical config identity, and dedicated customer-Firestore persistence. `dart analyze` is clean and all 74 core tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_persistence.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_schema.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_service.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_validation.dart

18/07/26 09:08 [FEAT] (4375c91) `dev-pro-large` Added authoritative Voice of Customer project definitions, legacy-safe Firestore codecs, enabled-only runtime delivery with canonical identity and bounded caching, and exhaustive SDK wire-enum compatibility. Ingest analysis is clean with 75 tests and SDK analysis is clean with 38 tests.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_schema.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- M citadel_core/conduit/citadel_conduit_sdk/lib/src/conduit_transport.dart

18/07/26 09:08 [FEAT] (e0e7345) `dev-pro-large` Replaced the static Voice of Customer page with responsive persisted feedback, poll, and branching-survey builders, complete contract validation, project-isolated draft hydration, and lossless read-only preservation of unsupported shareable surveys. `flutter analyze` is clean and all 60 platform tests pass.
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_conduit_pages.dart
- A citadel_platform/lib/src/app/platform_conduit_voice_of_customer_page.dart

18/07/26 09:30 [FEAT] (0beb311) `dev-pro-large` Added deterministic customer-response analytics for feedback, polls, and surveys, including project/occurrence-time isolation, sentiment, choices, scores, NPS, stored lifecycle completion, open-text frequency, stable response ordering, and exact epoch timestamps for new Firestore writes with legacy decoding retained. `dart analyze` is clean and all 80 core tests pass.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_schema.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_voc_analytics.dart

18/07/26 09:30 [FEAT] (77376a0) `dev-pro-large` Added bounded customer-Firestore VoC response reads, legacy timestamp compatibility, truthful empty adapters, responsive analytics and question breakdowns, deterministic pagination, exact Session Replay routing, and complete web CSV downloads including historical question IDs. `flutter analyze` is clean, all 65 platform tests pass, and the release web build succeeds.
- M citadel_platform/lib/src/app/platform_conduit_repository.dart
- A citadel_platform/lib/src/app/platform_conduit_voice_of_customer_analytics.dart
- A citadel_platform/lib/src/app/platform_conduit_voice_of_customer_csv.dart
- M citadel_platform/lib/src/app/platform_conduit_voice_of_customer_page.dart
- A citadel_platform/lib/src/app/platform_download_web.dart

18/07/26 09:36 [FEAT] (64d78d8) `dev-pro-large` Closed the supported Flutter poll-trigger audit gap with direct one-second time-on-page and exact scroll-threshold activation regressions, completing coverage alongside existing first-visit and explicit custom-event paths. `flutter analyze` is clean and all 40 SDK tests pass.
- M citadel_core/conduit/citadel_conduit_sdk/test/src/conduit_sdk_test.dart

18/07/26 10:21 [FEAT] (4af21ed) `dev-pro-large` Completed the hosted Voice of Customer service and executable emulator boundary: opaque revisioned survey deployments, projected public definitions, scoped signed anonymous respondent tokens, strict branching/answer validation, abuse limits, authenticated customer-Firestore proxying, Cloud Run-ready startup/container files, and a credential-isolated Firestore emulator E2E spanning rendered Flutter widgets, HTTP ingest, and persisted feedback, poll, and survey documents. Ingest analysis is clean with 95 tests, SDK analysis is clean with 40 ordinary tests, the dedicated emulator E2E passes, and the hosted executable compiles.
- A citadel_core/conduit/citadel_conduit_ingest/Dockerfile
- A citadel_core/conduit/citadel_conduit_ingest/bin/citadel_conduit_hosted_surveys.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_hosted_surveys.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_firestore_persistence.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_service.dart
- A citadel_core/conduit/tool/run_voc_emulator_e2e.sh
- A citadel_core/conduit/tool/voc_emulator/firebase.json
- A citadel_core/conduit/tool/voc_emulator/firestore.rules

18/07/26 10:21 [FEAT] (3d58ad7) `dev-pro-large` Added atomic hosted-survey publication to the Console with stable opaque deployment IDs, revision rotation only for meaningful changes, disable-without-delete lifecycle behavior, full shareable-survey editing and validation, truthful publication state, and selectable public URLs. `flutter analyze` is clean, all 73 tests pass, and the release web build succeeds.
- M citadel_platform/lib/src/app/platform_conduit_repository.dart
- A citadel_platform/lib/src/app/platform_conduit_survey_deployments.dart
- M citadel_platform/lib/src/app/platform_conduit_voice_of_customer_page.dart
- M citadel_platform/lib/src/app/platform_firestore.dart

18/07/26 10:27 [FEAT] `dev-pro-large` Audited Feature 3.9 against actual Conduit, ARM, Exigence, licensing, routing, and export capabilities; established that its release/SLO, automation, consent/retention, baseline, and first-client grant contracts are prerequisite-dependent; applied Feature 0.0's superseding priority ladder and Exigence reversal; and advanced the active task to Feature 0.7 while recording the blocking `citadel_cli` repository ownership, manifest format, and Terraform execution decisions. No product code changed and no tests were required for this documentation-only audit.
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/features/03-09-conduit-roi-reporting-and-grant-evidence-exports.md

18/07/26 11:37 [FEAT] (7a94855) `dev-pro-large` Established the independently versioned Citadel CLI and completed Feature 0.7's first manifest foundation: strict Freezed-backed YAML `v1` parsing, exact path diagnostics, project/service/role/retention/licensing validation, JSON-compatible alert defaults, non-negative budget caps, recursive inline-secret rejection with full Secret Manager version references, local validation, and a truthful no-cloud/no-Terraform onboarding dry run. `dart analyze` is clean, all 18 tests pass, the example validates and renders, and the native executable compiles.
- A citadel_cli/example/project_manifest.yaml
- A citadel_cli/lib/src/citadel_cli_runner.dart
- A citadel_cli/lib/src/project_manifest.dart
- A citadel_cli/lib/src/project_manifest.freezed.dart

18/07/26 11:44 [FEAT] (1490c71) `dev-pro-large` Added Feature 0.7's deterministic onboarding drift planner with typed registry, cloud, access, product-support, and Terraform capabilities; stable plan ordering and status precedence; explicit unknown blockers; ARM/Conduit applicability gating; and truthful CLI no-observations rendering. `dart analyze` is clean, all 23 tests pass, the example validates and renders, and the native executable compiles.
- M citadel_cli/lib/src/citadel_cli_runner.dart
- A citadel_cli/lib/src/onboarding_plan.dart

18/07/26 11:53 [FEAT] (7977057) `dev-pro-large` Added normalized, evidence-bearing Feature 0.7 observation contracts for the platform registry and required APIs, including explicit available/unavailable/permission-denied source states, exact stable registry mismatch details, deterministic explicit API-set comparison, and planner precedence integration. Preview seeds and inferred API policies remain excluded. `dart analyze` is clean, all 31 tests pass, and the native executable compiles.
- A citadel_cli/lib/src/onboarding_observations.dart

18/07/26 12:17 [FEAT] (438bbc1) `dev-pro-large` Implemented Feature 0.7's approved read-only Service Usage path: a safe gcloud enabled-service source, explicit five-API Firebase baseline, permission-versus-unavailable classification, async CLI execution, offline mode, evidence rendering, and planner integration. Real access confirms all baseline APIs on `citadel-platform`; the example target truthfully remains permission-blocked. `dart analyze` is clean, all 44 tests pass, and the native executable compiles.
- A citadel_cli/lib/src/gcloud_required_api_observation_source.dart
- M citadel_cli/lib/src/citadel_cli_runner.dart

18/07/26 12:26 [FEAT] (6d283df) `dev-pro-large` Added Feature 0.7's read-only default Firestore observation using only database describe, with validated project IDs, authoritative not-found drift, permission/source/malformed-output blockers, safe diagnostics, shared gcloud support, and live/offline CLI evidence integration. Real verification confirms the `citadel-platform` default database exists while the example target remains permission-blocked. `dart analyze` is clean, all 60 tests pass, and the native executable compiles.
- A citadel_cli/lib/src/gcloud_firestore_observation_source.dart
- M citadel_cli/lib/src/citadel_cli_runner.dart

18/07/26 12:51 [FEAT] (82abd09) `dev-pro-large` Established the independently versioned shared Core umbrella baseline for Platform contracts and API packages while excluding nested product repositories, Firebase deployment files, generated Dart, and build output. Both packages format and analyze cleanly; contracts pass 4 tests and API passes its baseline 9 tests.
- A citadel_core/.gitignore
- A citadel_core/platform/contracts/lib/src/core/domain/platform_domain_models.dart
- A citadel_core/platform/api/lib/src/platform_api_models.dart

18/07/26 12:51 [FEAT] (25ba440) `dev-pro-large` Added exact single-project and access-evidence REST contracts, normalized developer/viewer projection and per-email index consistency, structured-error and canonical registry JSON codecs, route documentation, and round-trip/malformed-evidence coverage. API analysis is clean and all 14 tests pass; generated Freezed output remains uncommitted.
- M citadel_core/platform/api/lib/src/platform_api_models.dart
- A citadel_core/platform/api/lib/src/platform_api_json.dart
- M _dev/docs/project_registry_contract.md
- M _dev/docs/shared_api_conventions.md

18/07/26 12:51 [FEAT] (e0b2b27) `dev-pro-large` Added the configurable read-only Platform REST registry client with canonical response mapping, authoritative missing drift, safe permission/source failure states, opt-in development headers, redirect protection, bounded timeouts, runner environment configuration, and operator documentation. CLI analysis is clean, all 68 tests pass, loopback HTTP integration proves default wiring, and the native executable compiles.
- A citadel_cli/lib/src/platform_rest_registry_observation_source.dart
- M citadel_cli/lib/src/citadel_cli_runner.dart
- M citadel_cli/README.md

18/07/26 12:58 [FEAT] (6e7526c) `dev-pro-large` Added explicit validated Storage bucket identity required for ARM object evidence, read-only gcloud bucket describe observation, authoritative missing drift, safe permission/source/malformed classification, online/offline plan wiring, and non-ARM applicability. The real platform project has no buckets and its expected Firebase bucket returns 404; analysis is clean, all 78 tests pass, the example validates/renders, and the executable compiles. Generated Freezed parts are now ignored and rebuilt locally rather than committed.
- A citadel_cli/lib/src/gcloud_storage_observation_source.dart
- M citadel_cli/lib/src/project_manifest.dart
- M citadel_cli/lib/src/citadel_cli_runner.dart
- D citadel_cli/lib/src/project_manifest.freezed.dart

18/07/26 12:58 [FIX] (cb84c98) `dev-pro-large` Corrected the clean-checkout development workflow to rebuild generated Freezed parts in dependency order across Core contracts, Core API, and CLI. A clean archive containing only committed files regenerates successfully, analyzes cleanly, and passes all 78 CLI tests.
- M citadel_cli/README.md

18/07/26 13:11 [FEAT] (c73e77d) `dev-pro-large` Added read-only project-access observation against the shared Platform REST contract, exact manifest comparison across project projection and per-email index evidence, stale-index drift detection, safe denied/unavailable classification, and online/offline wiring. CLI analysis is clean, all 84 tests pass, loopback integration proves the routes and header posture, and the native executable compiles.
- M citadel_cli/lib/src/citadel_cli_runner.dart
- M citadel_cli/lib/src/onboarding_observations.dart
- M citadel_cli/lib/src/platform_rest_registry_observation_source.dart
- M citadel_cli/README.md

18/07/26 13:11 [FEAT] (df68474) `dev-pro-large` Added the versioned composable customer-rules package with deterministic ARM/Conduit Firestore fragments, client-denied Storage rules, explicit Exigence refusal, a renderer, and isolated Firebase emulator configuration. Analysis is clean, all four tests pass, both emulators accept the rules, and no live Firebase resource was changed.
- A citadel_core/platform/customer_rules/lib/citadel_customer_rules.dart
- A citadel_core/platform/customer_rules/lib/src/customer_rules.dart
- A citadel_core/platform/customer_rules/bin/render_customer_rules.dart
- A citadel_core/platform/customer_rules/tool/emulator/firebase.json
- A _dev/docs/customer_rules_security_audit.md
- M DECISIONS_NEEDED.md

18/07/26 14:11 [FEAT] (5a27760) `dev-pro-large` Settled and implemented the server-only customer IAM observation contract: manifest-declared Citadel runtime identity, deduplicated ARM/Conduit Datastore and ARM bucket Storage grants, explicit undefined Exigence requirements, exact read-only gcloud policy checks, conditional-binding exclusion, safe failure classification, and online/offline plan integration. Firebase authentication and Standard edition were verified; CLI analysis is clean, all 105 tests pass, the executable compiles, live IAM policy reading succeeds, and no binding or ruleset was changed.
- A citadel_cli/lib/src/gcloud_iam_observation_source.dart
- M citadel_cli/lib/src/onboarding_observations.dart
- M citadel_cli/lib/src/project_manifest.dart
- M citadel_cli/lib/src/citadel_cli_runner.dart
- A _dev/docs/customer_server_access.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
18/07/26 14:24 [FEAT] (1092431) `dev-pro-large` Added safe, exact deployed customer-rules observation: the CLI obtains a short-lived gcloud token in memory, reads bounded Firestore and optional Storage release/ruleset chains from the fixed Firebase Rules API with quota-project attribution, compares single-file source with the Core server-only assembler, preserves denied/malformed/unavailable reads as unknown, and treats successful absence or mismatch as drift. The API baseline now includes `firebaserules.googleapis.com`; analysis is clean, all 122 tests pass, native compilation succeeds, a live read-only platform check passed, and no resource was changed.
- A citadel_cli/lib/src/firebase_rules_observation_source.dart
- M citadel_cli/lib/src/onboarding_observations.dart
- M citadel_cli/lib/src/citadel_cli_runner.dart
- M citadel_cli/lib/src/gcloud_required_api_observation_source.dart

18/07/26 14:38 [FEAT] (e5831ca) `dev-pro-large` Added deterministic review-only customer IAM Terraform rendering: a nested CLI command requires an explicit manifest and new output path, derives only additive ARM/Conduit project and bucket IAM members from the canonical server-only requirement builder, refuses undefined Exigence grants, publishes through an atomic no-overwrite writer, and documents the missing backend plus every excluded mutation. CLI formatting and analysis are clean, all 134 tests pass, native compilation succeeds, and a real output passes Terraform formatting, backend-disabled initialization, and validation with Google provider 7.40.0; no Cloud or Firebase resource changed.
- M citadel_cli/lib/src/citadel_cli_runner.dart
- A citadel_cli/lib/src/terraform_bundle_writer.dart
- A citadel_cli/lib/src/terraform_module_renderer.dart
- M citadel_cli/README.md

18/07/26 16:07 [FEAT] (1436b22) `dev-pro-large` Established Citadel's production Terraform state boundary: a reviewed one-resource stack created the private, regional, versioned, labeled, deletion-protected GCS bucket with 30-day soft delete, migrated equivalent bootstrap state into the locking-enabled `bootstrap/state-bucket` prefix, verified a zero-change remote plan and live protections, and added deterministic per-customer IAM backend configuration plus normal/bootstrap/recovery documentation. CLI analysis is clean, all 134 tests pass, both bootstrap and a real customer module validate with Google provider 7.40.0, and no customer IAM or Firebase Rules mutation ran.
- A citadel_cli/tool/terraform/state_backend/main.tf
- A citadel_cli/tool/terraform/state_backend/README.md
- M citadel_cli/lib/src/terraform_module_renderer.dart
- A _dev/docs/terraform_state_backend.md

18/07/26 16:15 [FEAT] (67fda57) `dev-pro-large` Added the confirmed plan-only Terraform boundary: exact project confirmation precedes all processes, rendered files are verified byte-for-byte, injected or stale plan inputs are refused, only bounded init/plan/JSON-show commands can run, and deterministic action counts plus sorted addresses are returned without raw output or any apply path. CLI formatting and analysis are clean, all 149 tests pass, native compilation succeeds, and no live customer plan or cloud mutation ran.
- A citadel_cli/lib/src/terraform_plan.dart
- M citadel_cli/lib/src/citadel_cli_runner.dart
- M citadel_cli/README.md

18/07/26 16:38 [FEAT] (83e7f86) `dev-pro-large` Added the explicit reviewed-plan Terraform apply boundary: deterministic receipts bind the full semantic manifest, rendered IAM bundle, saved-plan bytes, project, and exact action summary; apply separately confirms and revalidates all inputs, invokes only the reviewed plan, requires zero post-apply drift, suppresses raw process output, and publishes a replay-prevention receipt only on verified success. CLI formatting and analysis are clean, all 161 tests pass, native compilation succeeds, and no live customer IAM or Firebase Rules mutation ran.
- M citadel_cli/lib/src/terraform_plan.dart
- M citadel_cli/lib/src/citadel_cli_runner.dart
- M citadel_cli/lib/src/terraform_module_renderer.dart
- M citadel_cli/README.md

18/07/26 16:49 [FIX] (4e66198) `dev-pro-large` Audited the active ARM/Conduit browser-to-customer-Firestore paths and hardened Conduit operator queries: the browser-visible SDK project key can no longer authorize session search, replay retrieval, session metadata mutation, or heatmap queries, which now fail closed behind an injected bounded authorizer. All 98 ingest tests pass and both server executables compile; the Platform-to-product operator identity topology is recorded as the remaining console-migration decision, and no cloud or Firebase resource changed.
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_handler.dart
- A _dev/docs/customer_server_path_audit.md
- M DECISIONS_NEEDED.md

18/07/26 18:05 [FEAT] (194be52, 5aa63a5, d9764f1) `dev-pro-large` Added the fail-closed central Platform product proxy, shared Conduit session-search JSON contracts, and the first Console migration. Authorized project/actor context is propagated server-side without forwarding browser credentials, private failures are hidden, and ordinary session search now requires the configured HTTPS Platform API instead of direct customer Firestore. All affected analysis and focused tests pass; exact cohorts and other audited routes remain explicit follow-up work.
- A citadel_core/platform/server
- M citadel_core/platform/api/lib/src/platform_api_models.dart
- A citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_session_search_json.dart
- A citadel_platform/lib/src/app/platform_conduit_api.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

18/07/26 18:05 [FEAT] (c479007, fbcdda1, 916dd0f) `dev-pro-large` Started ARM 1.4 release-health evidence and Exigence 4.1. ARM Flutter/server initialization now propagates normalized version, build, and release channel into every captured issue/case and context; Exigence now has a provider-neutral TypeScript journal kernel with readonly contracts, guarded status transitions, deterministic replay, terminal skipping, and stable activity idempotency. All ARM and Exigence checks pass, no cloud integration was introduced, and work remains paused before 3.9.
- M citadel_core/arm/tooling_core/lib/src/arm_sink.dart
- M citadel_core/arm/tooling_core/lib/src/arm_documents.dart
- M citadel_core/arm/tooling/lib/src/arm_client.dart
- M citadel_core/arm/tooling_server/lib/src/arm_server.dart
- A citadel_core/exigence/src

18/07/26 20:28 [FEAT] (fbd8ade, 8fe27a1, 312b6ce, c23257b, 74ae88a) `dev-pro-large` Completed the central project-scoped proxy surface for ARM and privileged Conduit operations, preserved ARM tenant scope upstream, and moved exact Conduit cohort filtering to a strict server-side session-ID contract with no direct-Firestore fallback. All Core, Conduit, and focused Platform checks pass.
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/conduit/citadel_conduit_ingest/lib/src/conduit_ingest_models.dart
- M citadel_platform/lib/src/app/platform_conduit_repository.dart

18/07/26 20:28 [FEAT] (f56592c, c5bf233, db8e7b7, 45a43d0) `dev-pro-large` Added the private ARM evidence service with strict contracts, fail-closed project authorization, stable pagination, consistent case detail, and attributed status commands; migrated active ARM workspace/status and remaining privileged Conduit replay/metadata/heatmap Console paths to Firebase-authenticated Platform HTTP clients. Platform analysis, all 82 tests, and the release web build pass; no Cloud/Firebase resource changed.
- A citadel_core/arm/citadel_arm_service
- A citadel_platform/lib/src/app/platform_arm_api.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/platform_conduit_api.dart

18/07/26 20:28 [FEAT] (1848587) `dev-pro-large` Hardened the provider-neutral Exigence durable journal kernel with strict run/step/activity validation, idempotent legal transitions, duplicate-dispatch suppression, contiguous explicit retries, and deterministic resume semantics. TypeScript checking and all nine tests pass; provider, persistence, approval, and cloud integrations remain outside this slice.
- A citadel_core/exigence/src/validation.ts
- M citadel_core/exigence/src/journal.ts
- M citadel_core/exigence/README.md

18/07/26 22:23 [FEAT] (ec66a54, 3ff8cc9, 1fa37c6) `dev-pro-large` Implemented the settled Vertex-first extensible provider contract and simplified project-scoped agent IAM model, then added immutable expiring approvals, hash-chained audit evidence, currency-safe cost records, and exact budget hard stops. All policy outcomes are audited, risky permissions require approval by default, credentials remain Secret Manager references, and all 23 Exigence tests plus TypeScript checking pass without cloud access.
- A citadel_core/exigence/src/provider.ts
- A citadel_core/exigence/src/policy.ts
- A citadel_core/exigence/src/approval.ts
- A citadel_core/exigence/src/audit.ts
- A citadel_core/exigence/src/cost.ts
- M citadel_core/exigence/src/models.ts

18/07/26 22:25 [DECISION] `dev-pro-large` Verified the supported Google Node Firestore client can use explicit customer project/database identity, Application Default Credentials, REST preference, and transactional creates, then stopped before adding persistence because the spec conflicts between append-only step history and mutable current-state models. Recorded a recommended immutable event journal plus transactional run/step projections; no dependency or working-tree change remains and no cloud resource was accessed.
- M DECISIONS_NEEDED.md
- M CURRENT_TASK.md

18/07/26 22:46 [FEAT] (17e6039) `dev-pro-large` Implemented the approved hybrid customer-project Firestore journal: immutable per-run sequenced events and current run/step projections commit in one optimistic transaction, duplicate commands are semantic-idempotent, replay validates identity, chronology, sequence, and lifecycle transitions, and customer access uses explicit project/database identity with server-only ADC. TypeScript checking, all 26 unit tests, the isolated deny-all-rules Firestore emulator integration, and production dependency audit pass; no live Cloud/Firebase resource changed.
- A citadel_core/exigence/src/firestore_journal.ts
- M citadel_core/exigence/src/journal.ts
- A citadel_core/exigence/test/firestore_journal.integration.test.ts
- A citadel_core/exigence/tool/emulator/firebase.json
- M citadel_core/exigence/README.md

18/07/26 22:51 [FEAT] (c1ea8b4) `dev-pro-large` Added the Exigence Cloud Tasks dispatch boundary: versioned step-dispatch and activity-retry commands are validated, encoded into private HTTPS/OIDC tasks, named by a uniformly distributed SHA-256 command identity for duplicate suppression without leaking run IDs, optionally scheduled exactly, and treat only gRPC `ALREADY_EXISTS` as idempotent success. Logical retries remain journal operations while transport backoff remains future Terraform queue policy. TypeScript checking, all 29 ordinary tests, and the production dependency audit pass; no live queue or cloud resource changed.
- A citadel_core/exigence/src/task_dispatch.ts
- A citadel_core/exigence/test/task_dispatch.test.ts
- M citadel_core/exigence/README.md

18/07/26 22:56 [FEAT] (ec02121) `dev-pro-large` Extended the approved hybrid Firestore journal through per-attempt activity state: hashed activity projection documents and immutable events enforce declarations, legal transitions, retry continuity, immutable identity, optimistic sequence checks, and terminal-step safety. Complete loads and replay validate the whole journal, and the emulator now simulates a crash with a running attempt and proves cold-start recovery returns that exact attempt without duplication. TypeScript checking, all ordinary tests, emulator integration, and dependency audit pass; no live resource changed.
- M citadel_core/exigence/src/firestore_journal.ts
- M citadel_core/exigence/src/journal.ts
- M citadel_core/exigence/test/firestore_journal.integration.test.ts
- M citadel_core/exigence/README.md

18/07/26 22:58 [FEAT] (d94d8f3) `dev-pro-large` Added the private Exigence task receiver contract: only the configured route and Cloud Tasks queue are accepted, command identity must match across headers and a strictly decoded versioned JSON body, unknown or oversized input is rejected before journal access, and processor failures propagate for retry. Cloud Run IAM/OIDC is explicitly retained as authentication rather than trusting task headers. TypeScript checking, all 33 ordinary tests, and dependency audit pass; no cloud resource changed.
- A citadel_core/exigence/src/task_receiver.ts
- A citadel_core/exigence/test/task_receiver.test.ts
- M citadel_core/exigence/README.md

18/07/26 23:09 [FEAT] (da831aa) `dev-pro-large` Implemented the approved activity payload boundary: canonical JSON is mandatorily and policy-redacted, remains inline through exactly 128 KiB, and otherwise spills with binary data through an injected create-if-absent customer object-store port. Evidence contains deterministic paths, media type, byte count, SHA-256, policy version, and redacted paths; unsafe binary and malformed JSON fail closed. TypeScript checking, all 38 ordinary tests, and dependency audit pass without cloud access.
- A citadel_core/exigence/src/activity_payload.ts
- A citadel_core/exigence/test/activity_payload.test.ts
- M citadel_core/exigence/README.md

18/07/26 23:13 [FEAT] (54f9c12) `dev-pro-large` Bound activity payload evidence to the immutable Firestore lifecycle: input can be journaled only with a new pending attempt, output only when a running attempt succeeds or fails, and replay validates evidence hashes, redaction paths, storage metadata, and lifecycle placement. The emulator stores redacted input, proves crash recovery, then journals failure output and reconstructs the same compact projection. All checks pass and no live resource changed.
- M citadel_core/exigence/src/activity_payload.ts
- M citadel_core/exigence/src/firestore_journal.ts
- M citadel_core/exigence/test/firestore_journal.integration.test.ts

19/07/26 07:52 [FEAT] (53158b5) `dev-pro-large` Added exact immutable activity payload recovery: the Firestore repository pages sequenced events for one attempt and direction, validates the recovered evidence, returns not-found truthfully, and treats duplicate payload events as corruption. Input and output recovery pass the real Firestore emulator without expanding mutable activity projections or accessing a live resource.
- M citadel_core/exigence/src/firestore_journal.ts
- M citadel_core/exigence/test/firestore_journal.integration.test.ts

19/07/26 08:01 [FEAT] (c1cbb41) `dev-pro-large` Implemented the journal-backed task processor with deterministic event IDs, optimistic step/activity advancement, one-time input resolution, immutable evidence reload, stable executor idempotency, transport-retryable crash propagation, explicit durable failure/retry semantics, and terminal step completion. Unit tests and a Firestore emulator flow create a fresh processor after a forced post-effect crash and prove one attempt, one input resolution, one effect key, and equivalent event replay. All 42 ordinary tests and both emulator integrations pass; no live cloud resource changed.
- A citadel_core/exigence/src/task_processor.ts
- A citadel_core/exigence/test/task_processor.test.ts
- M citadel_core/exigence/test/firestore_journal.integration.test.ts
- M citadel_core/exigence/README.md

19/07/26 08:21 [FEAT] (6d3e1a6, e158c37) `dev-pro-large` Added production customer-GCS and Vertex Gemini ports without embedding credentials or unstable provider defaults. Payload writes use ADC, generation-zero preconditions, deterministic digest metadata, and exact collision verification; Vertex calls regional/global `generateContent` with a configured model ID, bounded request/response handling, sanitized failures, and authoritative provider token usage. TypeScript checking, all 52 ordinary tests, and dependency audit pass; no live cloud resource was accessed.
- A citadel_core/exigence/src/gcs_payload_store.ts
- A citadel_core/exigence/src/vertex_gemini.ts
- M citadel_core/exigence/src/index.ts
- M citadel_core/exigence/README.md

19/07/26 08:30 [FEAT] (9f40b71) `dev-pro-large` Added the reusable Exigence runtime Terraform module with scale-to-zero private Cloud Run, bounded Cloud Tasks transport retries, paused-by-default schedules, secret containers without values, separate runtime/invoker identities, queue-level URI/OIDC binding, Vertex access, and additive customer Firestore/GCS IAM. Mandatory labels cover every label-capable resource, Terraform validation and mocked plan assertions pass, and no live plan or apply ran. Recorded the remaining cross-project approval authority decision rather than inventing consistency semantics.
- A citadel_core/exigence/infra/modules/runtime
- M citadel_core/exigence/.gitignore
- M DECISIONS_NEEDED.md

19/07/26 08:52 [FEAT] (027b5e4, 46b3c77) `dev-pro-large` Implemented customer-journal-authoritative approval pause/resume, a payload-free rebuildable Citadel routing projection, durable customer audit hash-chain events, and a policy gate that records every decision before execution. Stable invocation IDs keep redelivery to one audit and approval request; exact approval-event sequence recovery prevents stale projection ordering. All 57 ordinary tests and four real Firestore emulator integrations pass, including a 49-hour zero-event pause and approved resume; no live resource changed.
- A citadel_core/exigence/src/approval_routing.ts
- A citadel_core/exigence/src/tool_execution_gate.ts
- M citadel_core/exigence/src/firestore_journal.ts
- M citadel_core/exigence/src/audit.ts
- M DECISIONS.md
- M DECISIONS_NEEDED.md

19/07/26 16:06 [FEAT] (434e7d0, bdeabae) `dev-pro-large` Implemented precise model accounting and transactional hard-budget enforcement. Versioned effective-dated profiles price exact provider usage categories with BigInt-backed decimal nano units and one aggregate ceiling; missing or ambiguous pricing fails closed. Customer-project monthly Firestore ledgers atomically reserve concurrent worst-case calls, settle exact immutable cost evidence, release unused capacity, strictly decode persisted state, and reject conflicting redelivery. All 60 ordinary tests, five emulator integrations, TypeScript checking, and dependency audit pass; no live cloud resource changed.
- A citadel_core/exigence/src/budget_reservation.ts
- M citadel_core/exigence/src/cost.ts
- M citadel_core/exigence/src/models.ts
- M citadel_core/exigence/src/vertex_gemini.ts
- M citadel_core/exigence/README.md

19/07/26 16:46 [FEAT] (2bd8b21, 2607190, 8e6ecdc) `dev-pro-large` Implemented the approved model-pricing and cancellation semantics. Exact half-open token tiers and provider modes now select one persisted price profile; uncertain accepted calls retain their full reservation through a durable reconciliation-required event. Cancellation permits the already-running attempt to record its result but prevents all subsequent forward work, and pending approval cancellation atomically terminates customer approval/run/step state with stale-safe terminal routing. All 66 ordinary tests, seven Firestore emulator integrations, TypeScript checks, and dependency audit pass; no live resource changed.
- M citadel_core/exigence/src/budget_reservation.ts
- M citadel_core/exigence/src/cost.ts
- M citadel_core/exigence/src/firestore_journal.ts
- M citadel_core/exigence/src/task_processor.ts
- M citadel_core/exigence/src/approval.ts
- M citadel_core/exigence/src/models.ts

19/07/26 17:12 [FEAT] (3e41aee, c9d072f, 75b263f, 59c057b) `dev-pro-large` Completed the unblocked Exigence cancellation and compensation substrate. Strict private cancel commands delegate to an audit-first customer-journal handler that cancels approvals and active steps, preserves in-flight terminal evidence, and starts compensation idempotently. Compensation declarations explicitly map immutable evidence, require receipts for failed effects, and plan stable reverse-order rollback. Project kill-switch orchestration blocks new starts before paginated run fanout, reports partial outcomes, and retries only failed targets. All 83 ordinary tests and eight Standard Firestore emulator integrations pass; the two remaining concrete persistence-layout choices are recorded without changing live resources.
- A citadel_core/exigence/src/compensation.ts
- A citadel_core/exigence/src/project_kill_switch.ts
- A citadel_core/exigence/src/run_cancellation.ts
- M citadel_core/exigence/src/firestore_journal.ts
- M DECISIONS_NEEDED.md
- M CURRENT_TASK.md

19/07/26 17:41 [FEAT] (bbd449a, c1c79fd, 608d4f3) `dev-pro-large` Implemented the approved Exigence persistence layout. Effect receipts now commit atomically with terminal activity events and flow from executors; compensation attempts use compact customer-run projections, stable retry identity, payload evidence, sequenced lifecycle events, and corruption-strict replay. Citadel Firestore now owns the authoritative project start gate, monotonic active run pointers, nested per-run dispatch outcomes, and retry-safe fanout summaries. All 85 ordinary tests and nine Standard Firestore emulator integrations pass; no live resource changed.
- M citadel_core/exigence/src/compensation.ts
- M citadel_core/exigence/src/firestore_journal.ts
- A citadel_core/exigence/src/firestore_project_kill_switch.ts
- M citadel_core/exigence/src/project_kill_switch.ts
- M DECISIONS.md
- M CURRENT_TASK.md

19/07/26 17:53 [FEAT] (9af927d) `dev-pro-large` Implemented durable cancellation compensation end to end. Redacted compensation evidence and stable idempotency survive transport crashes, durable failures do not block independent rollback items, terminal outcomes enter the customer audit chain, and run/step projections distinguish complete rollback from partial rollback with errors. The real cancellation handler now drives the executor in the Standard Firestore emulator; all 87 ordinary tests and nine emulator integrations pass with a clean dependency audit and no live resource changes.
- A citadel_core/exigence/src/compensation_executor.ts
- M citadel_core/exigence/src/journal.ts
- M citadel_core/exigence/src/models.ts
- M citadel_core/exigence/src/firestore_journal.ts
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md

19/07/26 18:08 [FEAT] (95e7d55) `dev-pro-large` Bound provider-neutral model execution to transactional project budgets and established the approved reference automation runtime flow. Calls reserve before provider I/O, settle exact authoritative token costs, release only known non-chargeable failures, and retain ambiguous billing for reconciliation. The fetch/summarise/approval-gated write/Console-notify definition uses stable crash-safe dispatch identities and durable run completion. All 96 ordinary tests and nine Standard Firestore integrations pass; no live resources changed.
- A citadel_core/exigence/src/model_execution.ts
- A citadel_core/exigence/src/reference_automation.ts
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md

19/07/26 18:24 [FEAT] (ff4ebb1) `dev-pro-large` Composed the production reference runtime and Cloud Run HTTP boundary. The real Firestore E2E covers budgeted model execution, durable approval/routing, idempotent customer write, forced post-write crash recovery, stable effect receipts, Console notification, completion, and exact replay. The HTTP service validates Terraform configuration, bounds requests, exposes health, returns retryable failures, and drains gracefully. All 102 ordinary and ten emulator tests pass; no live resource changed. The executable entrypoint remains gated on the recorded production configuration-authority decision.
- A citadel_core/exigence/src/reference_runtime.ts
- A citadel_core/exigence/src/node_http_server.ts
- A citadel_core/exigence/src/cloud_run_service.ts
- M DECISIONS_NEEDED.md
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md

19/07/26 18:42 [FEAT] (92ceb00) `dev-pro-large` Implemented approved immutable Exigence configuration authority and executable runtime foundations: CAS active pointers, transactional multi-version resolution, canonical digest snapshots, secret-value refusal, composition/start gating, fail-closed entrypoint, non-root container, and Terraform bootstrap wiring. TypeScript, 107 ordinary tests, targeted Firestore emulation, Terraform validation, audit, and diff checks pass; Docker build was unavailable because the local daemon is not running.
- A citadel_core/exigence/src/configuration_repository.ts
- A citadel_core/exigence/src/runtime_composition.ts
- A citadel_core/exigence/src/runtime_entrypoint.ts
- A citadel_core/exigence/Dockerfile
- M citadel_core/exigence/infra/modules/runtime/main.tf
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M CURRENT_TASK.md

22/07/26 12:54 [FEAT] (1ef19d3, b4900cf, f74aef0, 5c15b9e, 4c7dfa7) `dev-pro-large` Completed the Exigence Feature 4.1 production bundle and durable start path. Real Google adapters, all-tool authorization, exact compensation, explicit Terraform coordinates, an officially sourced Gemini 3.1 Flash-Lite configuration, immutable trigger/configuration evidence, opaque idempotency, and stable first dispatch are implemented. All 130 ordinary tests and 12 Standard Firestore integrations pass. Terraform bootstrap applied 14 additive resources with zero drift, the five-part configuration is active in control Firestore, and immutable runtime deployment is in progress.
- A citadel_core/exigence/src/reference_google_adapters.ts
- A citadel_core/exigence/src/reference_runtime_bootstrap.ts
- A citadel_core/exigence/src/reference_configuration_bundle.ts
- A citadel_core/exigence/src/run_start.ts
- A citadel_core/exigence/infra/modules/bootstrap
- A citadel_core/exigence/infra/environments/demo
- M citadel_core/exigence/src/configuration_repository.ts
- M citadel_core/exigence/src/firestore_journal.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/exigence/infra/modules/runtime

22/07/26 14:05 [FEAT] (c753317, 5dbef92, 34e2e1a, 9742d9c, 88c4391, e5b0430, 00dcc42, 12ab26e, 87514f7, b93c73e, e6bf78e, be5c6e7, 40e8b1c, 060bb0f, 177fa23) `dev-pro-large` Completed every unblocked Exigence Feature 4.2 lifecycle slice. The private runtime and fail-closed Platform proxy now expose project-scoped automation/run/approval/audit reads plus durable trigger, approval-resolution, and audit-first cancellation mutations. The Dart SDK provides bounded duplicate-safe triggers, run streaming, and approval deep links. The responsive Console renders exact costs, timing, retries, redacted URI-free evidence, audit CSV, role-gated trigger/approval/cancel controls, and stable mutation retries. Exigence has 146 passing ordinary tests and 12 passing emulator integrations from the latest persistence run; SDK 10, Platform API/server 18/20, and Flutter 110 tests plus analysis and release build pass. The remaining editor, schedule, webhook, CLI-auth, and deployment work is explicitly decision-gated; no manual Cloud/Firebase action is required.
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/src/platform_proxy_models.dart
- A citadel_core/exigence/src/private_platform_api.ts
- M citadel_core/exigence/src/run_cancellation.ts
- M citadel_core/exigence/src/runtime_composition.ts
- A citadel_core/exigence/sdk
- A citadel_platform/lib/src/app/platform_exigence_api.dart
- A citadel_platform/lib/src/app/platform_exigence_pages.dart
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS_NEEDED.md
- M _dev/docs/platform_api_proxy.md
- M _dev/docs/shared_api_conventions.md

28/07/26 16:11 [FEAT] (c5bf233, 73950ad, 3691ffb, 14d3e61) `dev-pro-large` Published the current Citadel ARM SDK commit and integrated Luminary Axis Dashboard through an authenticated server-only intake. Dashboard ARM writes now carry a Firebase ID token to LAD_Server, which verifies revocation, bounds the v1 capture payload, preserves client session/breadcrumb/error/release telemetry, adds trusted server context, and persists with its service account. Browser ARM Firestore/Storage access is denied in the committed rules; deployments remain intentionally pending as a coordinated server/dashboard/rules release. Dashboard Chrome tests (56), release web build, server analysis, and 19 server tests pass; local rules emulation is blocked by Java 19 where Firebase CLI requires Java 21.
- M ../LuminaryAxisDashboard/DashboardUI/pubspec.yaml
- A ../LuminaryAxisDashboard/DashboardUI/lib/arm/arm_server_intake_sink.dart
- M ../LuminaryAxisDashboard/DashboardUI/firestore.rules
- M ../LuminaryAxisDashboard/DashboardUI/storage.rules
- A ../LuminaryAxisDashboard/LAD_Server/lad_server/lib/arm_intake.dart
- M ../LuminaryAxisDashboard/LAD_Server/lad_server/lib/lad_server.dart

06/08/26 23:45 [FEAT] (61e4922, 7851a73, 3203b5c) `dev-pro-large` Closed the Citadel↔Luminary ARM integration end to end, replacing the deferred runtime wiring with deployed infrastructure. Built the private ARM evidence runtime (Firestore repository tolerant of the mixed timestamp/string evidence types, registry-driven project routing, Google OIDC caller authorization) and the browser-facing Platform API (JWKS RS256 Firebase token verification, registry-backed project roles, service-to-service OIDC, exact-origin CORS). Provisioned Terraform bootstrap and runtime stacks in citadel-platform plus the cross-project `roles/datastore.user` grant in luminary-axis-dashboard, and deployed the Console to Firebase Hosting with CITADEL_PLATFORM_API_BASE_URL. Verified live: real Luminary ARM issues and cases render newest-first through the API with working pagination, a case status mutation persists to Luminary Firestore attributed to the operator, and unauthenticated or unauthorized project reads return 403. ARM case pages were reduced to five records because full case bodies exceeded the 1 MiB response bound. Analysis is clean across all three packages; 13 ARM service tests, 36 platform server tests, and 115 Console tests pass; all Terraform modules and roots validate.
- A citadel_core/arm/citadel_arm_service/lib/src/arm_firestore_repository.dart
- A citadel_core/arm/citadel_arm_service/lib/src/arm_project_router.dart
- A citadel_core/arm/citadel_arm_service/lib/src/arm_oidc_authorizer.dart
- A citadel_core/arm/citadel_arm_service/bin/citadel_arm_service.dart
- A citadel_core/arm/citadel_arm_service/Dockerfile
- M citadel_core/arm/citadel_arm_service/lib/src/arm_service_handler.dart
- M citadel_core/arm/citadel_arm_service/lib/src/arm_service_models.dart
- A citadel_core/platform/server/lib/src/platform_google_jwt_verifier.dart
- A citadel_core/platform/server/lib/src/platform_firestore_role_resolver.dart
- A citadel_core/platform/server/lib/src/platform_oidc_proxy_client.dart
- A citadel_core/platform/server/lib/src/platform_cors.dart
- A citadel_core/platform/server/bin/citadel_platform_api.dart
- A citadel_core/platform/server/Dockerfile
- A citadel_core/platform/infra/modules/bootstrap
- A citadel_core/platform/infra/modules/runtime
- A citadel_core/platform/infra/environments/production
- M citadel_platform/lib/src/app/platform_arm_api.dart
- M citadel_platform/lib/src/app/platform_shell.dart
- A citadel_platform/scripts/deploy_console_hosting.py
- M DECISIONS.md
- M CURRENT_TASK.md
- M _dev/docs/platform_api_proxy.md

07/08/26 10:30 [FIX] (434c732, a6b9095, 926787c, d3c31d1) `dev-pro-large` Fixed the deployed Console failing to start on Safari while working on Chrome. Root cause was reading `Firebase.apps` before the first `initializeApp`: on web that getter reaches into the Firebase JS SDK, which `firebase_core_web` only injects from gstatic during `initializeApp`, and its tolerance for the not-yet-loaded case recognises the failure by string-matching Chrome's "of undefined" TypeError text, which Safari does not produce. The read therefore rethrew inside `ArmBootstrap.runGuarded`, which reports to ARM but writes nothing to the console and never calls `runApp`, presenting as an unexplained blank page. Dropped the redundant guard, since `initializeApp` already returns the existing default app. Also surfaced startup failures with an on-screen error and stack plus browser console output, bounded Firebase initialization at 20s so a stalled gstatic fetch becomes a real error instead of a hang, marked the Hosting entry points no-cache so a cached shell cannot outlive its build, and added a source-map decoder for minified release traces. Flutter analysis clean, 115 tests pass, Chrome verified by screenshot after each deploy.
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/scripts/deploy_console_hosting.py
- A citadel_platform/scripts/decode_web_stack.py
- M citadel_core/firebase.json

12/08/26 13:35 [FIX] (0026711, 36ac9d4, 04599a6, 4a45119, dd4148d) `dev-pro-large` Separated ARM capture evidence from operator triage and brought the ARM console to production quality. `handled` records whether the application caught an error; the Console was reading it as triage state, so twelve live invoicing failures displayed as Resolved and were excluded from the open-case count, and resolving a case wrote the flag back, destroying capture evidence. Cases are now stamped `status: new` at capture, issues deliberately carry none (they upsert on recurrence), and `ArmCaseStatusMutation` no longer carries `handled`. Also fixed two silent data-loss defects in the capture path: Firestore patch without an update mask and transaction set without merge both replace whole documents, erasing operator triage from issues on every recurrence; and ISO-string timestamps made collections unorderable since Firestore orders by value type before value. Backfilled 66 live Luminary documents through a reviewable dry-run-by-default tool with backup. Re-pinned AEC DashboardUI and LAD_Server to the new SDK commit; both analyse clean and build. Console: surfaced stack trace, error type, context and recovery snapshot that were previously fetched and discarded; added CitadelCodeBlock with bundled JetBrains Mono, line numbers, per-block copy and horizontal scroll; fixed badge stretching, missing column gutters and inconsistent row alignment; wrapped the shell in SelectionArea. Verified live through the deployed API: previously-Resolved cases now read `new` with `handled` preserved and stack traces present. 119 Console tests, 13 ARM service tests, 6 tooling_core tests and 10 tooling_server tests pass; all analysis clean.
- M citadel_core/arm/tooling_core/lib/src/arm_documents.dart
- M citadel_core/arm/tooling_server/lib/src/arm_firestore_service_account_sink.dart
- M citadel_core/arm/tooling/lib/src/arm_firebase_sink.dart
- M citadel_core/arm/citadel_arm_service/lib/src/arm_private_service.dart
- M citadel_core/arm/citadel_arm_service/lib/src/arm_service_models.dart
- A citadel_core/arm/tool/backfill_arm_evidence.py
- A citadel_platform/lib/src/design_system/citadel_code_block.dart
- M citadel_platform/lib/src/app/platform_arm_pages.dart
- M citadel_platform/lib/src/app/platform_arm_api.dart
- M citadel_platform/lib/src/app/platform_state.dart
- A citadel_platform/test/arm_case_status_test.dart
- A _dev/docs/client_onboarding.md

14/08/26 12:35 [FEAT] (uncommitted) `dev-pro-large` Reworked the Console's visual system so every main-area view reads as one uniform surface instead of stacked cards. Design system: `CitadelPanel` is now flat by default with an opt-in `framed` variant, added `CitadelMainBar`/`CitadelPageScaffold` (a flush, full-bleed bar pinned to the top of the main area with no outer gap), `CitadelSelect` (an unambiguous dropdown control), `CitadelIconButton`, `CitadelInfoPill`, `CitadelCallout`, `CitadelDetailGrid`, `CitadelTruncatedId` (short id with hover-full and copy) and a compact `CitadelMetricTile`/`CitadelMetricGrid` that occupies a short strip rather than a screenful. Theme now pins every button to one control height with visible disabled states (muted text, flattened ground) and adds checkbox/tooltip/icon-button themes. New `citadel_table.dart` is the single table for the platform: ruled columns, sortable headers, row and multi-row selection with a bulk-action bar, per-row overflow actions, an explicit open affordance, and standard empty states. New `citadel_charts.dart` adds a labelled count axis (rounded nice ceiling) for the occurrence bar chart and the monitoring timeline, plus mini bars for table cells. Dashboard drops the redundant project chip (the project is already named in the app-bar selector). ARM: every view moved onto the flush bar and flat sections; Monitoring gained a real range model with twelve presets plus a calendar date-range picker, span-derived interval options, and range paging that also filters the log table; the timeline is drawn flat on the page; Case Logs truncates the fingerprint and drops the error payload from the summary column; Issue Fingerprints and Case Logs gained selection with real bulk status writes behind a confirmation dialog and clipboard actions. Flutter analysis clean, 119 tests pass; views verified by rendering the seeded console to PNGs through a temporary golden harness (removed after review).
- M citadel_platform/lib/src/design_system/citadel_tokens.dart
- M citadel_platform/lib/src/design_system/citadel_theme.dart
- M citadel_platform/lib/src/design_system/citadel_primitives.dart
- A citadel_platform/lib/src/design_system/citadel_table.dart
- A citadel_platform/lib/src/design_system/citadel_charts.dart
- M citadel_platform/lib/src/app/platform_arm_pages.dart
- M citadel_platform/lib/src/app/platform_pages.dart

14/08/26 19:05 [PLAN] (no commits — documentation only, no code changed) `claude-opus-5` Audited the Exigence product line against live GCP and the repository rather than the tracking documents, found both materially stale, and replanned the line around a corrected understanding of what Citadel is. Established that Feature 4.2 was never blocked after 22/07/26 (its four decisions were resolved that day) and is code-complete including webhooks, schedules, config API, Console and CLI parity — but that none of it is deployed: the live Cloud Run digest sha256:7493fe4c is commit 27ce195, predating 9742d9c which added the operator API, so the deployed runtime serves no operator routes; citadel-platform-api carries no Exigence env vars so the proxy has no target; CITADEL_TASK_TARGET_URL is the placeholder https://citadel.invalid/v1/tasks so steps cannot dispatch; and zero Cloud Scheduler jobs exist despite the module declaring one. No Exigence run has ever executed in production. Operator then reframed Citadel as an internal solo-operator delivery platform where he is the sole author of executable logic, which voided the client-author threat model behind several settled decisions: template-constrained editing and the config-first definition editor are reversed, and artifacts become operator-authored LangGraph JS graphs executed by LangGraph, with Citadel supplying only what LangGraph lacks (policy gate, budget reservation, audit chain, effect receipts, compensation, kill switch, cost, Console) via a Firestore BaseCheckpointSaver validated against LangGraph's own conformance suite; ~30% of the existing tested runtime is consequently deleted. Also settled: Palisade as core identity/security provider over Firebase Auth; npm-distributed CLI local runner with structured→assisted→visual declared fallback; Firestore vector search for the Knowledge Base; Stripe as processor only. Late reversals — all clients share citadel-platform rather than getting per-client projects, which removed BigQuery's justification (now deferred, guardrail stands) and makes Palisade the sole isolation mechanism; and Drive OAuth stays in Testing status, whose verified 7-day refresh-token revocation makes runner-based ingestion of a synced Drive folder the preferred path over browser OAuth. Verified external facts against current documentation. No build, test or deploy was run this session; all test counts cited come from the project's own records, not from execution.
- M AGENTS.md
- M CURRENT_TASK.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- A _dev/docs/exigence_palisade_phase_plan.md
- M _dev/features/04-01-exigence-automation-runtime.md
- M _dev/features/04-02-exigence-console-sdk.md
- M _dev/features/04-03-exigence-agent-observability-and-evals.md
- A _dev/features/04-04-exigence-knowledge-base.md
- A _dev/features/04-05-exigence-artifacts-and-local-runner.md
- A _dev/features/04-06-exigence-billing.md
- A _dev/features/06-01-palisade-iam.md
- A _dev/features/06-02-palisade-watchdog.md

14/08/26 19:40 [FIX] (39a03e2, b2af796, eebd37e) `claude-opus-5` Gated and landed the three dirty worktrees that had accumulated since 12/08. Reviewed each diff before staging rather than committing blind. citadel_core carried Exigence upstream response validation (fail closed with 502 when a private-service success body is mis-scoped or malformed) plus previously untracked Firebase deploy configuration including the 341-line deny-by-default Firestore rules that were live but existed only on the operator's machine. citadel_cli carried operator API envelope validation; it failed its gate on arrival with two failing tests and four analyzer issues. Diagnosis: the new validation asserts a triggered run echoes definitionId and a resolved approval echoes runId, and the real Run model does carry both, so the validation was correct and the two test fixtures were under-specified — corrected the fixtures rather than weakening the check. Also removed three redundant null assertions and documented why prefer_initializing_formals cannot be satisfied here (a named parameter cannot be private). citadel_platform carried the Console visual system rework; it gated clean as received. Ignored a stray 2400x1592 golden-harness render artifact rather than deleting it. All three pushed to main. NOTE: the repository root is not under version control, so every planning document produced today remains untracked.
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- A citadel_core/firestore.rules
- A citadel_core/storage.rules
- M citadel_cli/lib/src/exigence_operator_client.dart
- M citadel_cli/test/exigence_operator_test.dart
- A citadel_platform/lib/src/design_system/citadel_table.dart
- A citadel_platform/lib/src/design_system/citadel_charts.dart
- M citadel_platform/lib/src/app/platform_arm_pages.dart

14/08/26 21:35 [FEAT/FIX] (969f562, 8bbafe3, 46cdb38, 58faef3, 78de227, 664ad93, d636136 in exigence; e44ff4a in citadel_core) `dev-pro-large` Executed Phase R: repaired the Exigence deployment and proved the first real end-to-end run in production. R1 was already landed by the previous session. R2: rebuilt the runtime image from HEAD via the dedicated builder identity, replaced the citadel.invalid task target and example.com reference source with real values through new Terraform variables plus a committed demo.auto.tfvars, granted the Platform API run.invoker on the runtime, wired the missing Exigence proxy client into the Platform API entrypoint (it read no CITADEL_EXIGENCE_* env at all), added those env vars via the platform module, applied the Cloud Scheduler dispatcher, and verified zero drift across all four Terraform states. R3 exposed five production-fatal defects that no test had caught because fixtures fabricated the environment: (1) the task receiver demanded full resource paths in X-CloudTasks-TaskName while Cloud Tasks only ever sends short IDs, so every real delivery 403'd; (2) Node's BlockList matches plain IPv4 against IPv4-mapped IPv6 rules, so the blanket ::ffff:0:0/96 entry classified the entire IPv4 internet as non-public and fetch could never fetch; (3) the pinned HTTPS transport answered Node 20+'s happy-eyeballs lookup with the legacy 3-arg form, dialling "undefined"; (4) nothing in the serving path ever invoked the ReferenceAutomationHarness — the integration suite drove it in-process — so a run could execute exactly one step, and a bare dispatch_step would have bypassed the write-approval gate; fixed with a task driver that routes dispatch_step deliveries through the harness until the run suspends, completes, or stops; (5) gate audit idempotency requires invocation timestamps stable across redeliveries yet never behind the journal, so they now anchor to the durable step.started event. Acceptance run run-c5bf2bff…1441 passed the full gate: live Vertex inference (gemini-3.1-flash-lite, grounded against the live endpoint), operator approval and resume, durable write/notify effect receipts, settled cost (606000 nanos month-to-date over two live model calls, zero dangling reservations), and a 5-event audit chain verified with the runtime's own verifyAuditChain. Durable cancellation was exercised live three times along the way. Also fixed a budget-ledger test-isolation race and pinned firebase-tools 13.35.1 for the Java 19 machine. KNOWN GAP, deliberate: the Platform API proxy → runtime path is deployed and IAM-authorized but was not exercised end-to-end, because `gcloud auth print-identity-token --audiences` fails for user accounts, so the CLI's GcloudOidcTokenSource has never actually worked against production; the acceptance run drove the runtime's operator API directly under Cloud Run IAM. Follow-up recorded in CURRENT_TASK.
- M citadel_core/exigence/src/task_receiver.ts
- M citadel_core/exigence/src/reference_google_adapters.ts
- M citadel_core/exigence/src/reference_automation.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/exigence/infra/modules/runtime/main.tf
- M citadel_core/exigence/infra/modules/runtime/variables.tf
- M citadel_core/exigence/infra/environments/demo/runtime/main.tf
- M citadel_core/exigence/infra/environments/demo/runtime/variables.tf
- A citadel_core/exigence/infra/environments/demo/runtime/demo.auto.tfvars
- M citadel_core/exigence/package.json
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- M citadel_core/platform/infra/modules/runtime/main.tf
- M citadel_core/platform/infra/modules/runtime/variables.tf
- M citadel_core/platform/infra/environments/production/runtime/main.tf

14/08/26 22:10 [DOC] (no commits — the repository root is not under version control) `dev-pro-large` Completed Phase 1A's gating design task: wrote `_dev/docs/langgraph_superstep_activity_mapping.md`, the superstep↔activity mapping that Feature 4.1 R1 requires before any checkpointer code. Grounded every claim by installing the real packages and instrumenting live graphs rather than trusting the phase plan's notes, which proved wrong in three ways: BaseCheckpointSaver now has six abstract members (deleteThread is required, not the four listed), the conformance suite is a hard vitest dependency and cannot run under node --test, and the flagged HITL risk langgraphjs#1308 is closed and does not reproduce at 1.4.9 in either resume shape, so no escalation is needed. The decisive empirical findings: LangGraph's unit of replay is the node, not the line — a node's pre-interrupt code executed twice across interrupt+resume, and a crashed node re-ran from its top while completed nodes never re-ran — and the taskId handed to putWrites is a deterministic UUIDv5 that stays identical across a crash and its recovery, making (runId, checkpoint_id, task_id) a durable idempotency key for a Citadel activity. put is the superstep barrier; putWrites is one node execution within it. The mapping therefore replaces today's static activityIdempotencyKey(runId, stepId, activityId), which assumes a step list known before the run — an assumption any branch or loop invalidates. Three conflicts are recorded in DECISIONS_NEEDED.md and block implementation: deleteThread versus the immutable hash-chained journal, adopting vitest as a second runner, and the checkpoint payload offload threshold against Firestore's 1 MB document limit. No checkpointer code was written, by design — the document is a review gate.
- A _dev/docs/langgraph_superstep_activity_mapping.md
- M DECISIONS_NEEDED.md
- M CURRENT_TASK.md

14/08/26 22:40 [FIX/DOC] (no commits — repository root is not under version control; no submodule source changed) `dev-pro-large` Reclaimed 1.1 GB of local disk and settled the three Phase 1A checkpointer decisions. The `infra` folders were not the problem: the Terraform source across both trees totals 516 KB and all state was already remote in GCS. The space was ten separate 115 MB copies of the hashicorp/google provider, one per working directory, because no plugin cache was configured (`~/.terraformrc` absent, `TF_PLUGIN_CACHE_DIR` unset). Verified first that no directory held real local state — the six environment roots use the GCS backend and the four module directories have no state at all, having only ever been initialised for `terraform validate` — then wrote `~/.terraformrc` with a shared `plugin_cache_dir`, deleted all ten caches, and re-initialised every directory against the cache. Each `.terraform` is now 8 KB of symlinks into a single 231 MB cache holding the two pinned versions (7.40.0 and 7.43.0); the project tree went 2.4 GB to 1.3 GB and free disk 3.8 GiB to 4.7 GiB. One directory failed a naive init and was worth understanding rather than forcing: `citadel_cli/tool/terraform/state_backend` declares a partial `backend "gcs" {}` and requires its documented `-backend-config=bootstrap.gcs.tfbackend`, which its README specifies; re-run that way it initialised cleanly. Confirmed zero drift on both the Exigence demo runtime and the Platform production runtime after re-init. Operator then approved all three recommended Phase 1A decisions, raising only the payload threshold: deleteThread is implemented for real but refuses under a retention hold or settled invoice via a typed error; vitest is adopted for the conformance suite alone while everything else stays on node --test; and checkpoint payload offload moves to 80% of the Firestore 1 MiB document limit (838860 bytes) rather than the proposed 256 KiB. Recorded a consequence the percentage alone does not cover: the threshold governs one channel value, so several sub-threshold channels can still sum past 1 MiB, and the checkpointer must additionally measure the serialized document total and offload largest-first until the document fits. All three are now settled in DECISIONS.md, marked resolved in DECISIONS_NEEDED.md, folded into the mapping doc, and CURRENT_TASK step 2 is unblocked.
- A ~/.terraformrc (outside the repository)
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M CURRENT_TASK.md
- M _dev/docs/langgraph_superstep_activity_mapping.md

14/08/26 23:20 [FEAT] (eeca34f) `dev-pro-large` Implemented the Firestore LangGraph checkpointer and passed the Feature 4.1 Task 4.1.R1 acceptance gate: LangGraph's official conformance suite, 714 tests, run unmodified. Storage follows the reviewed mapping doc — the serialized checkpoint is the source of truth and is never rebuilt from a projection, one document per checkpoint and per write so no single document absorbs Firestore's ~1 write/sec ceiling, deleteThread carries the agreed typed refusal for threads under a retention hold, pre-v4 checkpoints get their pending sends migrated on read, and a whole-document size check backstops the per-value 838860-byte offload threshold. The substantive finding came after the gate already passed: the suite requires delta storage (persist only the channels named in newVersions, a test skipped by name for MemorySaver, MongoDB and SQLite because those savers do not implement it), and implementing it the obvious way silently loses state — a channel written in the first superstep and never rewritten disappears from every later checkpoint, which the suite cannot detect because its fixtures are isolated root checkpoints with no ancestry. A real three-node graph proved it: all 714 conformance tests green while the run read back a default instead of the value. Fixed by keying channel values on (channel, version) in their own documents and resolving every channel named in the checkpoint's own channel_versions on read, which is also cheaper than walking the parent chain. Four real-execution integration tests now cover state retention across supersteps, forced-crash resume at the exact superstep, a durable interrupt resumed through a separate saver instance, and deleteThread refusing a held thread. Recorded in mapping doc §6.5 with the generalisation for the rest of Phase 1A: the conformance suite proves the storage contract, not that a graph runs.
- A citadel_core/exigence/src/firestore_checkpointer.ts
- A citadel_core/exigence/test/conformance/firestore_checkpointer.ts
- A citadel_core/exigence/test/firestore_checkpointer.integration.test.ts
- A citadel_core/exigence/vitest.config.ts
- M citadel_core/exigence/src/index.ts
- M citadel_core/exigence/package.json
- M _dev/docs/langgraph_superstep_activity_mapping.md

14/08/26 23:55 [FEAT] (8889bda) `dev-pro-large` Completed Feature 4.1 Task 4.1.R3, policy-gated tool binding for LangGraph artifacts. Every tool a graph can call now passes the Citadel policy gate and is audited before its body runs and writes an effect receipt after, so compensation has something to reverse; a refused tool returns a denial value rather than throwing, which keeps the run inspectable and preserves the refusal as audit evidence instead of an unhandled error. A risky scope raises LangGraph's interrupt() in place of the bespoke Citadel suspend, while the Approval record and its routing projection are still written so the Console inbox is untouched, exactly as Feature 4.1 requires. Identity is the mapping doc's (runId, checkpointId, taskId), resolved from the run context LangGraph exposes to a node — thread_id, __pregel_task_id, and checkpoint_id or its checkpoint_map fallback in a child namespace, all verified by probe rather than assumed. The audit and approval writes are guarded by a read of the existing event because a replayed node reproduces the same event id under a later wall clock, and appending that again is precisely the defect that stalled the Phase R acceptance run; the decisive test asserts the effect ran once with no duplicate audit or approval across an interrupt and its resume. Budget reservation is exposed as a hook rather than a built-in price model, since tools carry no pricing and fabricating one would be worse than letting the artifact supply it — model calls continue through BudgetedModelExecutor. Built additively so it does not depend on the run/step state machine that Task 4.1.R2 will delete.
- A citadel_core/exigence/src/langgraph_tool_binding.ts
- A citadel_core/exigence/test/langgraph_tool_binding.test.ts
- M citadel_core/exigence/src/index.ts
- M citadel_core/exigence/package.json

15/08/26 00:40 [REFACTOR] (00e3fd9, f9ee7e5 exigence; 654acdb citadel_core; 88d2976 citadel_platform) `dev-pro-large` Executed the narrowed Task 4.1.R2 after the operator confirmed all three sequencing questions: the reference automation survives to Phase 2, the LangGraph run lifecycle belongs to Phase 2, and the Console configuration page is retired now together with the routes serving it. Recorded all three in DECISIONS.md first, including the consequence that the mechanisms 4.1.R2 lists as duplicated are not yet duplicated — they are the reference automation's own machinery and survive with it — so R2 in Phase 1A reduces to removing the cancelled authoring surface. Removed in one coordinated change across three repositories so no deployed caller was ever left pointing at a route that no longer exists: installTemplate and UnsupportedExecutableTemplateError from the runtime, the private GET /templates and GET|PUT /definitions/{id} routes, the three Platform API proxy operations that served them, and the Console's definition panel and template dialog, each with its tests. Kept schedules, providers, webhooks and budget, which operate an artifact rather than author one, and kept definition resolution internally where schedule and webhook validation still depends on it. Two self-inflicted errors were caught by the analyzer rather than shipped: a test-pruning cut ran past the last widget test and took the shared fixtures with it, and removing the freezed models also removed the ExigenceConfigurationMutationOutcome enum that the surviving mutation results use. Rebuilt and deployed both images and the Console rather than leaving HEAD undeployed, since drift between HEAD and production is the exact condition Phase R existed to fix, then verified live that the retired routes return 404 while all six surviving operational routes return 200, with zero Terraform drift.
- M citadel_core/exigence/src/configuration_control.ts
- M citadel_core/exigence/src/private_configuration_api.ts
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/src/platform_proxy_models.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
- M citadel_platform/lib/src/app/platform_exigence_pages.dart
- M DECISIONS.md

15/08/26 01:30 [FEAT/DOC] (94e6a1b) `dev-pro-large` Delivered the two Feature 4.1 Task 4.1.R4 hardening items that do not depend on the Phase 2 run lifecycle, plus the OTel GenAI field map pulled forward from Feature 4.3. Version gate: the checkpointer now records the orchestrator code version with every checkpoint and refuses to return a tuple for a thread pinned to a different one, because resuming across a code change replays divergent logic against checkpoints the new code never wrote and does so silently. The gate sits on getTuple since that is the resume path, while list stays readable so an operator can still inspect a stranded thread; it is opt-in, so the conformance suite still passes 714/714 unchanged. Durable timers: verified against current Cloud Tasks quota documentation that the maximum schedule is 30 days (task size 1 MiB, retention 31 days), and the dispatcher now rejects a schedule beyond that horizon against an injected clock rather than letting the API reject it as an opaque dispatch failure with no run-visible cause. Wrote `_dev/docs/otel_genai_field_map.md` grounded against the live spec, which produced three findings: the GenAI conventions have moved out of the main semantic-conventions repository so the opentelemetry.io path is a stub, `gen_ai.system` no longer exists and is replaced by the Required `gen_ai.provider.name` (`gcp.vertex_ai` for Vertex), and there is no cost attribute or metric anywhere in the conventions — so Citadel's spend stays in a `citadel.*` namespace rather than colliding with future upstream cost semantics. Citadel's existing CostRecord and ModelTokenUsage map cleanly onto the token attributes including cache_read and reasoning tokens, with toolUsePromptTokens and totalTokens explicitly having no upstream home. Deferred with reasons: the determinism lint rule targets artifact code that does not exist until Phase 2, and raising the Cloud Tasks queue rate is gated on real traffic that has not arrived.
- M citadel_core/exigence/src/firestore_checkpointer.ts
- M citadel_core/exigence/src/task_dispatch.ts
- A _dev/docs/otel_genai_field_map.md

15/08/26 02:10 [DOC/TEST] (8450e34) `dev-pro-large` Began Phase 1B (Palisade IAM) with Task 6.1.4's prerequisite: the acceptance gate is that existing ARM and Exigence access resolves identically before and after migration, which is unprovable without first writing down what "identically" means. Extracted both models from the running code into `_dev/docs/palisade_authorization_model_extraction.md` — the platform chain (Firebase or OIDC identity, platform_access lookup, project status and offering enablement, role derivation, access-class gating) and the Exigence policy kernel (five permissions, five tool scopes, roles, bindings, dual tool allowlists, permission-derived approval) — including the fact that Exigence's evaluation *order* is part of the contract because each branch emits a distinct reason string into the audit chain. Then pinned today's behaviour in `platform_authorization_golden_test.dart`: 37 tests enumerating the whole input space rather than sampling it, 32 exhaustive combinations of owner/developer/viewer grants against project status and offering enablement plus five property assertions. The expected-role formula was derived independently from the extraction and matched every combination, which validates the document. Four findings recorded because a migration could erase them by accident: `operator` and `analyst` appear in the proxy's access-class tables but nothing grants them, so making them grantable would turn today's denials into successes; `admin` is never held without `developer`, so "admin but not developer" is inexpressible; a single tenant `owner` reaches every project with no per-project record, which matters more now that all clients share one GCP project; and `configurationRead` and `mutation` accept identical role sets, so that distinction is currently inert. Raised the schema-shape question in DECISIONS_NEEDED.md — the two models share the words role, permission, admin, operator and viewer while meaning different things, so flattening them into one vocabulary is the easiest way to break the behaviour-preservation gate.
- A _dev/docs/palisade_authorization_model_extraction.md
- A citadel_core/platform/server/test/platform_authorization_golden_test.dart
- M DECISIONS_NEEDED.md

15/08/26 02:45 [DOC/TEST] (23c9ceb) `dev-pro-large` Settled the Palisade role and permission model on the operator's direction and proved the change costs nobody access. Three roles replace five: superdev (full access, the operator's own), viewer (see resources and results, change nothing) and invoker (run services without creating or changing configuration, for an analyst). operator is dropped as a non-standard term, analyst is superseded by invoker, and admin folds into superdev. One permission vocabulary follows the cloud-provider `<service>.<resource>.<verb>` convention rather than the separate product-operation and agent-capability families I had recommended — an artifact is a principal like any other, so Exigence's tools.read becomes exigence.tools.read in the shared namespace while the policy kernel's evaluation, reason strings and audit actions are untouched. Wrote `_dev/docs/palisade_role_and_permission_model.md` with a catalogue derived from the 25 real proxy operations plus the five agent permissions, nothing speculative, and stated two judgement calls in invoker rather than burying them: approvals.resolve is excluded because resolving an approval authorises exactly the risky effects the gate exists to hold, while runs.cancel is included because a role that can start work should be able to stop it. The removals are behaviour-preserving for verified reasons rather than by assertion, and `palisade_role_migration_test.dart` now asserts them: every grant combination against every access class resolves identically under both models, operator and analyst are never produced by any input, admin is never held without developer, and invoker reaches read and nothing else. Recorded honestly that this verifies the model rather than an implementation, since Palisade does not exist yet and the new roles are declared locally in the test; when it lands the same table runs against the real resolver.
- A _dev/docs/palisade_role_and_permission_model.md
- A citadel_core/platform/server/test/palisade_role_migration_test.dart
- M DECISIONS.md
- M DECISIONS_NEEDED.md

15/08/26 03:30 [FEAT/DOC] (a0c26a7) `dev-pro-large` Settled the Palisade boundary pattern grammar on the operator's direction to use an industry convention rather than an invented one, and shipped the first Palisade code as `citadel_core/palisade`. Grammar: browser-extension match patterns for URLs, npm-ecosystem glob semantics for filesystem paths, and Google Cloud IAM's precedence, where deny is evaluated first and always wins so reordering a policy can never change authority, with no matching allow meaning deny. Rejected the URLPattern standard on evidence rather than preference — it arrived in Node v23.8.0 and is marked Experimental, so it is absent from the Node 22 runtime image entirely, and regex-grade expressiveness is a liability in patterns that must be reviewable at a glance. Resolved one genuine ambiguity by decision because the upstream documentation contradicts itself: `*.example.com` matches subdomains only and never the apex, that being the reading which cannot accidentally over-grant. The evaluator is free of I/O so the cloud runtime and the local runner can run byte-identical logic, since the runner enforces boundaries itself rather than trusting the cloud. Fourteen adversarial tests cover traversal, sibling-prefix leakage, host lookalikes such as notexample.com and example.com.evil.test, TLD-spanning wildcards, malformed patterns being refused rather than silently narrowed, and the fact that `*` crosses separators in a URL path but not in a filesystem glob. The decisive one runs against a real temporary filesystem: a symlink from an allowed directory into a denied one matches the allow, misses the deny, and reads a private key, and only realpath denies it — which is why canonicalisation is written into the contract rather than left as advice. One test failed on arrival asserting that a root-escaping path throws; it does not, because normalize clamps at the root exactly as the OS does, so the test was corrected rather than the code. Documented for authors in `_dev/docs/palisade_boundary_grammar.md`, including the two things not yet settled: Windows path handling and percent-encoding.
- A citadel_core/palisade/src/boundary.ts
- A citadel_core/palisade/test/boundary.test.ts
- A citadel_core/palisade/package.json
- A _dev/docs/palisade_boundary_grammar.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md

15/08/26 04:15 [FEAT/TEST] (5fc1ef8, 2177b7f) `dev-pro-large` Built the Palisade authorization core: the 30-permission catalogue and three roles as code, the five identity types, project-scoped grants, and the resolved-effective-authority view that Feature 6.1.3 calls the intuitiveness requirement — the flattened answer to what an identity can actually do, with provenance naming the grant that conferred each permission, rather than a list of bindings to be mentally executed. superdev is expressed as all-permissions so the operator's role cannot fall behind the platform when a product gains a route, while viewer and invoker are enumerated because deriving them from the verb suffix would auto-grant every future read; a completeness test closes the resulting gap by failing the build when a new permission is neither classified into a role nor marked superdev-only, so it can be neither silently omitted nor silently granted. Then wrote the migration-equivalence test against the real implementation rather than the model, driving the same input space through resolveEffectiveAuthority and asserting all 25 operations resolve as the deployed Platform API resolves them. It failed immediately and correctly: the viewer role held exigence.providers.list and exigence.budget.get, which are configurationRead routes viewers cannot reach today, so the migration would have handed clients a view of provider configuration and spend they do not currently have. The earlier Dart model-equivalence test could not have caught it because it compares role sets to access classes rather than per-permission access. Both permissions are now superdev-only and the model doc records the correction, noting that letting a client see their own spend may well be right but is a product decision rather than a migration detail. A second defect was caught the same way: the effective-authority renderer returned a bare "no authority" when a grant named a misspelled role, hiding the cause; warnings are now emitted in every branch.
- A citadel_core/palisade/src/permissions.ts
- A citadel_core/palisade/src/authority.ts
- A citadel_core/palisade/test/authority.test.ts
- A citadel_core/palisade/test/migration_equivalence.test.ts
- M _dev/docs/palisade_role_and_permission_model.md

15/08/26 05:00 [REFACTOR] (f9469d3) `dev-pro-large` Restructured Palisade on the operator's direction to keep TypeScript to what genuinely requires it and write the rest in Dart, which dissolved the architecture question rather than answering it. Authority — permissions, roles, identities, grants and effective-authority resolution — is now a Dart package at palisade/authority, because its consumers are Dart: the Platform API and Console import it directly, so an authorization check involves no service, no network hop and no new infrastructure. Boundary evaluation stays TypeScript at palisade/boundary, because its consumers are the cloud runtime and the local runner, both Node, and Feature 6.1.2 requires the runner to enforce boundaries independently rather than trusting the cloud. Nothing is duplicated: each concern has exactly one implementation, and the TypeScript authority code and tests were deleted rather than left alongside. The apparent obstacle — a TypeScript runtime needing to call a Dart authority service on every tool invocation — does not arise, because Exigence already resolves configuration once at run start and pins it into the run snapshot (19/07/26); authority resolves the same way, so a tool check becomes set membership against a pinned list and inherits the immutability a run already has. Recorded in DECISIONS.md along with what is irreducibly TypeScript and why: the Exigence runtime because it is built on LangGraph and no Dart LangGraph exists, and the local runner because it ships via npm to avoid macOS quarantine and code signing. Both rejected alternatives are recorded too — Palisade as a network service, which buys correctness that shared golden vectors already provide and pays with standing cost and a dependency whose failure must deny and therefore breaks the Console; and duplicating resolution in both languages, which under this split is unnecessary. All 18 authority tests ported with their substance intact, including the equivalence table that caught the viewer over-grant, and the 14 boundary tests are unchanged.
- A citadel_core/palisade/authority/lib/src/permissions.dart
- A citadel_core/palisade/authority/lib/src/authority.dart
- A citadel_core/palisade/authority/test/authority_test.dart
- A citadel_core/palisade/authority/test/migration_equivalence_test.dart
- D citadel_core/palisade/src/permissions.ts
- D citadel_core/palisade/src/authority.ts
- M DECISIONS.md

15/08/26 06:00 [FEAT] (6d1ef86, 5ed5838, 45deb56, c95a51e) `dev-pro-large` Carried Palisade from settled model to a live, backfilled registry, stopping one step short of the switchover. Recorded the operator's decision that every grant is project-scoped with no cross-project roles, and that creating a project automatically grants its creator superdev on it — which replaces the reach the tenant owner role provided while making it explicit and auditable rather than ambient. Implemented grantForNewProject and migrateLegacyAccess, the latter converting the old registry by current effective access rather than document shape: developerProjectIds granted developer+admin so it becomes superdev, viewerProjectIds becomes viewer except where superdev already covers the project, a tenant owner becomes superdev on every project that exists, and the tenant roles that were already inert are not carried across. Discovered while reading the code that the operator's global reach was doubly implemented — the tenant owner role and a hardcoded bootstrap email in the Console's project writer — and that platform_access is a derived index rebuilt from each project's developerEmails and viewerEmails rather than a source of truth. Added the operation-to-permission map in production code with tests asserting it is exhaustive over PlatformProxyOperation, that every permission exists in the catalogue, that no two routes share one, and that permission checks reproduce today's access classes exactly. Added the Firestore-backed Palisade resolver, carrying across the project-active and offering-enabled checks deliberately because they belong to the project rather than the identity, and treating a missing enabled flag as disabled so absence never reads as permission to act. Wrote the backfill tool dry-run-first, reviewed its output, applied it, and verified both new collections and both untouched old ones. Production behaviour is unchanged throughout: nothing reads the new collections yet. Stopped before the switchover after finding projectRoles in 18 files across four repositories including the ARM console, the Console UI and the CLI — it is a client-facing vocabulary, so the change ripples much further than the Platform API and needs a sequencing decision, recorded in DECISIONS_NEEDED.md with expand-migrate-contract recommended as the only option where no deploy can lock the operator out of the Console.
- A citadel_core/palisade/authority/lib/src/provisioning.dart
- A citadel_core/palisade/authority/test/provisioning_test.dart
- A citadel_core/platform/server/lib/src/platform_permission_map.dart
- A citadel_core/platform/server/lib/src/palisade_firestore_resolver.dart
- A citadel_core/platform/server/tool/backfill_palisade_grants.dart
- M DECISIONS.md
- M DECISIONS_NEEDED.md

15/08/26 07:00 [FEAT] (8faaa6e, 66b8e61, 27f513b) `dev-pro-la
rge` Completed the server side of Feature 6.1 Task 6.1.4 and deployed it. Recorded the operator's standing rule first, in AGENTS.md and DECISIONS.md rather than as a one-off: old and new implementations are not run side by side, backward compatibility is for cases with genuinely no alternative, and where several surfaces consume the shape being changed the answer is to build the common mechanism they share rather than emit both shapes. Added that mechanism to the authority package — can(), the single call every surface makes, plus transport so the API resolves once and a surface answers its own rendering questions locally; malformed transport resolves to no authority rather than throwing, because a surface that cannot understand the answer must show nothing and an unhandled error in a render path is likelier to be swallowed than a deliberate fail-closed. Then switched the Platform API to authorize on named permissions and deleted the old resolver, its role model and its golden vectors in the same commit rather than leaving a second implementation. The four access buckets are gone; one of them encoded a distinction the system could not produce, which a test had enshrined by asserting a developer without admin was refused a budget write — a combination the old resolver never granted — so that test now asserts the boundary that does exist. Nothing upstream changed because projectRoles was never on the wire. Verified against the real backfilled registry before deploying and found exactly current effective access, then rebuilt, deployed and confirmed zero drift with unauthenticated callers refused by the app itself. The build move surfaced a latent fragility rather than creating one: generated freezed sources are gitignored and gcloud honours .gitignore at the source root, so building from citadel_core/platform had been silently uploading a developer's local generated files, while building from citadel_core correctly excludes them and failed — the image now runs build_runner per package and builds from source. Honest gap: an authenticated Console request was not exercised, because minting a Firebase ID token needs an interactive browser sign-in; the rollback digest is recorded in test_status.
- M citadel_core/palisade/authority/lib/src/authority.dart
- A citadel_core/palisade/authority/test/shared_mechanism_test.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/src/platform_proxy_authorizer.dart
- M citadel_core/platform/server/lib/src/platform_proxy_models.dart
- D citadel_core/platform/server/lib/src/platform_firestore_role_resolver.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- M citadel_core/platform/server/Dockerfile
- M AGENTS.md
- M DECISIONS.md

15/08/26 07:30 [TEST] (c3e5b9a-adjacent; see citadel_core HEAD) `dev-pro-large` Closed the verification gap flagged in the previous entry by minting a real Firebase ID token rather than reasoning about the untested path. The operator's account signs in with Google and has no password, so a password grant was not available; instead a custom token was signed by the Firebase Admin service account through IAM signJwt, with no key downloaded, and exchanged at the Identity Toolkit for an ID token — the same exchange the Console's SDK performs. That required token-creator on the admin service account, which was added through Terraform rather than an inline gcloud grant to honour the hard rule, and recorded honestly as permitting impersonation of any Firebase user in the project: not a new capability given the operator holds owner, but now explicit and removable in one block. The end-to-end result confirms the switchover: ARM routes return 200 on both projects as the signed-in operator, and every Exigence route returns 403 on both — which is correct rather than a regression, because offeringScope.exigence.enabled is false on both projects and the project-usability check was deliberately carried across from the deleted resolver. The token was destroyed immediately after use. One case remains untestable rather than untested: the second account holds grants but has never signed in, so it has no Firebase user record and no token can be minted for it; its per-project scoping was proven through the production resolver against live data instead.
- M citadel_core/platform/infra/environments/production/runtime/main.tf

15/08/26 09:30 [FEAT] (citadel_core 2cd2f48, 7498514, 049d38f; citadel_platform 14e4217; exigence d220d2f) `dev-pro-large` Finished the Palisade switchover across every surface and closed Phase 1B task 4. Chased a leftover platform_access reference and found the real gap: authority had migrated but visibility had not — _loadVisibleProjects returned every project in the registry to anyone holding tenant owner, developer or admin, which is the cross-project role the model does not have and the way one client could be shown another client's project. Retiring the collection reached further than expected, because the Firestore rules themselves were built on it: isRegistryWriter read tenant roles from platform_access and hasProjectAccess fell back to a project list on the same document. Both are Palisade lookups now, made from inside the rules, which is not subject to those collections' own read rules — so palisade_identities and palisade_grants are closed to clients entirely while still deciding what a client may do. Resolution moved server-side behind GET /v1/workspace so the Console renders from the object the API enforces, and grant writes moved to the API alone, because a browser that could write a grant could award itself superdev on any project. Discovered while doing it that offering enablement was keyed to the requested operation, so an ARM request resolved Exigence permissions on a project with Exigence disabled — harmless while only the proxy read the result and checked one permission, wrong once a surface renders from it; it is a mask over resolved permissions now. Also found the project document's developer and viewer lists were about to become a silent no-op, granting nothing while looking like access control, so upsertProject turns them into real grants through the API after claiming the project. Sequenced the rollout wrong: the rules went out before the Console build was ready, so the deployed Console read a now-denied collection for a few minutes. Then unified the last duplicated vocabulary — the Exigence kernel named five capabilities that Palisade named with an exigence. prefix — by defining them once in Dart and generating a TypeScript module, whose literal types located all thirteen call sites. Proved 1B's behaviour-preservation gate by test rather than assertion. The rollout proved the runtime validates its configuration at startup: the first revision exited with "unsupported agent permission tools.read" and Cloud Run held traffic on the previous revision, and recovering exposed three real defects in the publish path, each fixed rather than worked around.
- A citadel_core/platform/server/lib/src/platform_workspace_service.dart
- A citadel_core/platform/server/lib/src/platform_grant_service.dart
- A citadel_core/platform/server/tool/grant_tenant_capability.dart
- A citadel_core/palisade/authority/lib/src/catalogue.dart
- A citadel_core/palisade/catalogue.json
- M citadel_core/firestore.rules
- A citadel_platform/lib/src/app/platform_workspace_api.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- A exigence/src/permission_catalogue.ts
- A exigence/tool/publish_reference_configuration.ts
- M exigence/infra/modules/runtime/main.tf
- M DECISIONS.md

15/08/26 11:45 [FEAT] (citadel_core 5b26943, c0fb746, 37eca0d-adjacent; exigence 0e0e60e, 82b36c4, 37eca0d) `dev-pro-large` Opened Phase 2 with the artifact model and finished Phase 1B's fourth item by moving artifact authority onto Palisade. Four artifact types on one substrate, with the two refusals that matter: an agent must declare a step ceiling because it chooses its own next step and nothing else stops it choosing another, and every other type must not, because a fixed graph is already bounded by its shape and a ceiling there would read as a limit while enforcing nothing. The reference automation turns out to be a job by this model, not an automation. Artifacts became Palisade principals with project-qualified identities, since the registry is global while an artifact is not and two clients may name an artifact the same thing. Grants carry direct capabilities rather than roles, deliberately departing from the feature file's wording: the tool allowlist already states what an artifact may do, and a role on top is a second statement that can disagree. Operator chose live resolution over pinning at publish, and retiring Exigence's four agent roles outright; both were implemented, with behaviour preservation proven by asserting every former role's capability set resolves to the outcome that role resolved to before. Rolling it out found two defects invisible to the suite: the runtime minted its identity token for the Platform API's base URL while that service declares a custom audience, so every resolution was refused — surfaced quickly only because a 403 was marked non-retryable; and the resolver cached per instance, which in Cloud Run is the life of the process, caching a successful "no authority" answer as readily as a permissive one, so granting a capability would have taken effect only when the instance recycled. The cache is gone. Also discovered that routing artifact authority through Palisade means every project an artifact runs in must be registered — the reference runtime's own project never had been, because nothing required it before.
- A citadel_core/exigence/src/artifact.ts
- A citadel_core/exigence/src/principal_authority.ts
- A citadel_core/exigence/tool/publish_reference_configuration.ts
- M citadel_core/exigence/src/policy.ts
- A citadel_core/palisade/authority/lib/src/catalogue.dart
- M citadel_core/palisade/authority/lib/src/provisioning.dart
- A citadel_core/platform/server/tool/provision_artifact_identity.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart

15/08/26 13:30 [FEAT] (citadel_core 783ab8d; citadel_platform dabcadb; exigence adjacent) `dev-pro-large` Completed Feature 4.5 Tasks 4.5.2 and 4.5.3 and set up a demo project for dev and testing. Artifacts now render grouped by type with their IAM hyperlinked and resolved permissions inline, a detail page carrying version, triggers, month-to-date cost and the artifact's own runs, and a six-step configuration flow that blocks progression while a step is invalid and says why. The flow gates on the runtime's artifact vocabulary, served rather than duplicated: a form carrying its own copy of "an automation is triggered by a schedule" would accept a combination that fails at the point of use, after the person has left the form. Created `demo-sandbox` through the real path — a Firebase-token write subject to the rules, then the claim route — which immediately found that Console project creation had been failing outright: the rules allow `armFirebase`, the name the Console migrated away from, while it writes `targetFirebase`, and `hasOnly` rejected it. Unnoticed because both existing projects predate the rename. Writing the document with application credentials would have bypassed the rules and shown nothing. Adversarial isolation now has a real two-tenant fixture: the demo artifact resolves its capabilities on demo-sandbox and is absent from citadel-platform, and the Palisade collections refuse a signed-in browser on both. Also found that a proxied operation with no envelope rule is refused by default, which is the right default and is how the missing rule for the new route surfaced; and that registering a project by hand leaves nobody with authority on it, since visibility follows from grants and the claim route refuses once a project has any.
- A citadel_platform/lib/src/app/platform_artifact_configuration.dart
- A citadel_platform/test/platform_artifact_configuration_test.dart
- M citadel_core/firestore.rules
- M citadel_core/exigence/src/private_platform_api.ts
- M citadel_core/platform/server/lib/src/platform_grant_service.dart

26/08/26 22:51 [FEAT] (no new commit; published platform e9ede26, CLI cea001b, core 2416ea5, exigence 987283b) `dev-pro-large` Updated the unversioned planning corpus for the settled Baker Factory/Devstation, Manifold, trusted-runner relay, complete Console control-plane, integrated-test and Palisade hardening direction. Preserved current deployed truth separately in SITREP, recorded unresolved implementation contracts, and published every already-committed feature branch; all six Git repositories are clean and synchronized with upstream.
- M AGENTS.md
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M _dev/session_log.md
- M _dev/SITREP.md
- M _dev/docs/technical_report.md
- M _dev/docs/release_timeline.md
- M _dev/docs/exigence_palisade_phase_plan.md
- M _dev/docs/otel_genai_field_map.md
- M _dev/features/00-00-sauron-directive-and-reprioritisation.md
- M _dev/features/00-07-client-onboarding-kit-and-telemetry-licensing.md
- M _dev/features/02-01-platform-console-website.md
- M _dev/features/04-05-exigence-artifacts-and-local-runner.md
- M _dev/features/00-04-shared-protocols-and-sdks.md
- M _dev/features/04-06-exigence-billing.md
- M _dev/features/05-01-baker-spec-designer.md
- M _dev/features/05-02-baker-generation-deployment.md
- A _dev/features/05-03-baker-devstation.md
- M _dev/features/06-01-palisade-iam.md
- M _dev/features/06-02-palisade-watchdog.md
- A _dev/features/07-01-manifold-conversations-and-connectors.md
- A _dev/features/07-02-manifold-console-and-cross-service-resolution.md

27/08/26 08:19 [FEAT] (citadel_platform d74c1c0) `dev-pro-large` Settled the operator's Palisade Data Handling, runner transport, Devstation and WhatsApp-first Manifold responses, superseding the unsafe machine-wide trusted-relay bypass with four per-resource handling outcomes. Set the Devstation default to 2 vCPU, 6 GiB RAM and 60 GB disk with brokered privileged GCP work. Began the complete Console control-plane track by mounting the previously unreachable project registry inventory on the live dashboard, showing configured cloud boundaries and enabled-service counts without misreporting them as provider-verified; responsive project selection, all 283 Console tests and analysis pass, and the feature commit is published.
- M AGENTS.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/docs/palisade_boundary_grammar.md
- M _dev/docs/shared_streaming_conventions.md
- M _dev/docs/technical_report.md
- M _dev/docs/exigence_palisade_phase_plan.md
- M _dev/SITREP.md
- M _dev/test_status.md
- M _dev/features/04-05-exigence-artifacts-and-local-runner.md
- M _dev/features/05-03-baker-devstation.md
- M _dev/features/06-01-palisade-iam.md
- M _dev/features/06-02-palisade-watchdog.md
- M _dev/features/07-01-manifold-conversations-and-connectors.md
- M _dev/features/07-02-manifold-console-and-cross-service-resolution.md
- M citadel_platform/lib/src/app/platform_pages.dart
- M citadel_platform/lib/src/app/platform_project_admin.dart

27/08/26 10:05 [FEAT] `dev-pro-large` Generated the resource-inventory
contract's Freezed sources (the committed copy predated the last model edit),
then completed the server side of the reconciliation slice. The live GCP
adapter had never compiled: it read `Project.lifecycleState` and
`Project.projectNumber`, which are Cloud Resource Manager v1 names — v3 carries
`state` and the project number inside the resource name — and read
`serviceAccount` and `deletionProtection` off `GoogleCloudRunV2Service`, where
the first lives on the revision template and the second does not exist in
googleapis 16.0.0. Cloud Run readiness now derives from `terminalCondition`,
which distinguishes a failed reconciliation (drift) from one still in flight
(stale). Added a Palisade-gated `GET /v1/projects/{id}/inventory` behind a new
`platform.inventory.read` permission, superdev-only: the inventory discloses
service accounts, enabled APIs and service URLs, which `platform.projects.get`
does not, so reusing it would have widened the viewer role silently. An
observer that collapses outright now degrades to intent-and-evidence rather
than failing the request, since a provider outage is not a reason to tell an
operator nothing about their own project. Wired into the deployed binary with
a third credential scoped `cloud-platform.read-only`, held apart from the
Firestore and Terraform-runner clients on the same reasoning the binary
already applies to those two.
- A citadel_core/platform/api/lib/src/project_resource_inventory_models.dart
- A citadel_core/platform/api/lib/src/project_resource_inventory_json.dart
- M citadel_core/platform/api/lib/citadel_platform_api.dart
- M citadel_core/platform/api/lib/src/platform_api_models.dart
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/catalogue.json
- A citadel_core/platform/server/lib/src/platform_project_inventory_service.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/citadel_platform_server.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart

27/08/26 11:20 [FEAT] `dev-pro-large` Wired the Console to the reconciliation
route. A `Provider reconciliation` panel sits below `Project inventory` on the
dashboard, adjacent to it rather than merged into it — one panel showing both
configured intent and provider verification would be exactly the collapse this
work exists to undo. Each resource needing attention names its own state and
carries one action, and the state-to-action mapping is a pure function of
state and resource kind rather than of node id, because ids come from the
server and a mapping keyed on them would route a renamed node to nothing. A
refused reading routes to provisioning rather than settings: Terraform is what
grants the platform its roles on a customer project, so offering a text field
there would point at the wrong fix. An unverified or unreachable resource
offers no fix at all, only a recheck, since nothing has been established as
wrong. When the read itself fails, the panel says in its own body that registry
state above still holds — not as an extra remedy on the failure, because
`describeFailure` drops those for transport faults, which is precisely when
that reassurance is needed.
- A citadel_platform/lib/src/app/platform_inventory_api.dart
- A citadel_platform/lib/src/app/platform_inventory_pages.dart
- M citadel_platform/lib/src/app/platform_pages.dart

27/08/26 12:40 [FEAT] `dev-pro-large` Made inventory visibility a scope rather
than a yes, on the operator's decision that a viewer sees the whole graph and
an invoker sees only what it can invoke. That needed two permissions, because
one can only express a yes, and it makes invoker deliberately narrower than
viewer on exactly one permission — inverting the rule that invoker is a strict
superset. Rather than delete that invariant test, it now asserts the difference
between the two roles equals a named `invokerNarrowerThanViewer` list, so a
second exception cannot appear without someone deciding on it. The narrowing
runs in the Platform API and never in the Console: a response carrying the
whole topology that trusts the browser to hide it has withheld nothing, since
it is in the network tab either way. Nodes declare their own invocability
server-side rather than each reader inferring it from resource kind, because
whether the local runner matters to an invocation is a fact about how Exigence
works and not a property of the word. The wire carries `scope` so the Console
can say when a graph is partial — three of fourteen resources presented as the
whole project would read as a project made of three things — and a narrowed
view shows state with no remediation buttons, since an invoker pressing Build
would be opening a dialog whose first call is a 403.
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/catalogue.json
- M citadel_core/platform/api/lib/src/project_resource_inventory_models.dart
- M citadel_core/platform/api/lib/src/project_resource_inventory_json.dart
- M citadel_core/platform/server/lib/src/platform_project_inventory_service.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_platform/lib/src/app/platform_inventory_pages.dart

27/08/26 14:10 [FIX] `dev-pro-large` Ran the inventory read path against Google
Cloud for the first time and it did not work. Two defects, both of the kind
Phase R warned about: a fixture written from the same misreading as the code
agrees with it all the way to production. First, `_dateTime` read registry
timestamps from `Value.stringValue`, where Firestore returns `timestampValue` —
so every document the current console and provisioning runner write was
undecodable and the route would have thrown on every real project. Both
readings are now accepted, because the registry holds records from more than
one era, and five regression tests drive the real FirestoreApi over a stubbed
transport so the wire shape is part of the assertion rather than an assumption
behind it. Second, the first live run returned six observations for eight cloud
nodes: `gcp-firestore` and `gcp-provisioner-job` had slots in the inventory
that nothing ever filled, so the registry database could have been deleted and
the panel would have gone on reporting configured intent. Both are now observed
and a live test asserts every cloud node carries a live claim. Two opt-in live
suites were added, guarded by project env vars and tagged `live` so a plain
`dart test` reports them skipped rather than omitting them silently — a gate
nobody can see is not running is how Phase R happened. The payoff shows in the
run over all four registry projects: `axis-education` reports seven of eight
resources `permissionDenied` and its project `healthy`, which before this slice
was eight identical "not configured".
- M citadel_core/platform/server/lib/src/platform_project_inventory_service.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- A citadel_core/platform/server/test/platform_gcp_observer_live_test.dart
- A citadel_core/platform/server/test/platform_inventory_live_test.dart
- A citadel_core/platform/server/test/platform_registry_document_test.dart
- A citadel_core/platform/server/dart_test.yaml

27/08/26 15:40 [FEAT] `dev-pro-large` Deployed the inventory route and drove it
from the Console in a real browser, which is the first time the Platform API
proxy has been exercised by a Firebase credential — the gap Phase R left open.
Two defects surfaced on the first authenticated load, neither reachable from
any test. When Cloud Resource Manager refuses a project, the observer stops,
which is right because every later call reads the same project; but it reported
the refusal against one node and left seven carrying configured intent, which
renders as "Unverified" — a check still to come, when the truth is the check
was refused. And fifteen rows offered a Recheck button for resources no
observer reads, so pressing one returned the identical row. Both are the
slice's own mistake one level up: distinguishing six states does not help if
two of them are then presented as the same waiting-for-a-result. Fixed,
rebuilt, redeployed, and confirmed in the browser — `axis-education` went from
"1 No access, 15 Unverified" to "8 No access, 10 Unverified" with the reason on
every cloud row and no button where no reading exists. Also found that the
Console cannot reach the deployed API from any origin outside
CITADEL_CONSOLE_ALLOWED_ORIGINS, and that a blocked call renders as an
indefinite "Loading workspace" rather than an error, which is worth fixing
separately. Left undone deliberately: the deployed API's service account cannot
read client projects at all, so their inventories are eight rows of No access
until it is granted read-only roles — reported rather than granted, because
widening a production service account is the operator's call.
- M citadel_core/platform/server/lib/src/platform_project_inventory_service.dart
- M citadel_platform/lib/src/app/platform_inventory_pages.dart
27/08/26 13:29 [FIX] (`58532f4`, `c4b7eed`, `cc3ce32`) `dev-pro-large` Closed
the two unblocked findings from the deployed inventory browser run. Workspace
bootstrap now bounds both request and response waits and turns blocked browser
origins into actionable CORS guidance instead of an indefinite spinner. The
GCP observer now classifies Firestore's official API errors alongside the
other provider clients, preserving permission denial rather than reporting an
unreachable provider. Audited the last legacy authority reader and retired the
inactive standalone ARM Console, including its separate Hosting and Firestore
rules, rather than preserving a second authorization plane over empty legacy
collections. The unified Console remains the sole ARM UI. The exact
metadata-only client-project observer role is recorded in
`DECISIONS_NEEDED.md`; no production IAM was widened.
- M citadel_platform/lib/src/app/platform_workspace_api.dart
- M citadel_platform/lib/src/app/platform_failures.dart
- M citadel_platform/lib/src/design_system/citadel_failure.dart
- M citadel_core/platform/server/lib/src/platform_project_inventory_service.dart
- D citadel_core/arm/console
- M citadel_core/arm/README.md
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
27/08/26 15:04 [FEAT] (`a82d21c`, `b642d93`) `dev-pro-large` Implemented and
deployed the operator-approved client-project inventory observer boundary. CLI
onboarding now deterministically renders and observes a fixed Platform API
principal, one project custom role, and an exact metadata-only permission set;
its integrity-protected Terraform plan/apply path therefore covers future
clients. The existing `axis-education` stack uses Citadel credentials for
locked remote state and additive bindings while an ephemeral customer-owner
token administers only the custom role. The reviewed plan added two resources,
applied cleanly, and now reports zero drift. Google rejected the proposed
`resourcemanager.projects.list` as invalid in a project-level role; source and
decisions were narrowed to the six permissions the live observer actually
calls rather than escalating scope. Provider inspection confirms the exact
role and deployed service-account member. CLI analysis, 179 tests, native
compilation, generated-module validation, and live Terraform validation pass;
a fresh authenticated Console request remains explicit because browser control
and service-account impersonation were unavailable.
- M citadel_cli/lib/src/onboarding_observations.dart
- M citadel_cli/lib/src/terraform_module_renderer.dart
- M citadel_core/platform/infra/environments/production/customers/axis-education/main.tf
- M citadel_core/platform/infra/environments/production/customers/axis-education/providers.tf
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
27/08/26 18:37 [FIX] (`b92ff3e`, `7e7d01f`, `30d4fd3`, `59297ce`) `dev-pro-large` Reconciled the Phase 2 regression that had reintroduced customer-written agent containers despite the operator-only authorship decision. Removed the `/agents` publishing surface and CLI group, the customer-container SDK/protocol/harness/runtime, agent-specific Terraform provisioning, and per-artifact runtime routing, while preserving the four-type registry plus generic read/run/cancel/approval/audit operations. Added the missing tracked `hashicorp/time` provider lock so the shared runtime module validates cleanly. Recorded the registry/configuration split as the next one-record migration and explicitly left the known demo-sandbox deployment for a separately reviewed Terraform/data decommission rather than deleting live resources implicitly.
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M _dev/SITREP.md
- M _dev/agent_artifacts_handoff.md
- M citadel_cli/lib/src/citadel_cli_runner.dart
- D citadel_core/exigence/agent_sdk
- M citadel_core/exigence/src/configuration_control.ts
- D citadel_core/exigence/src/agent_harness_graph.ts
- M citadel_core/exigence/infra/modules/runtime/.terraform.lock.hcl
- D citadel_core/platform/provisioner/templates/exigence-agent
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
28/08/26 08:56 [FEAT] `dev-pro-large` Audited the Phase 2 artifact substrate before beginning the required single-cut migration. The current runtime separates immutable definition/policy/provider/pricing/adapter pointers, Palisade identity/grants, and a deployment registration that repeats artifact facts, so the requested authoritative Artifact record needs an explicit contract for what it owns versus what it pins by reference. Recorded the security-sensitive record-composition decision and recommended versioned evidence references in `DECISIONS_NEEDED.md`; no code was changed because an unapproved schema would either duplicate Palisade authority or weaken run pinning. Marked the active task blocked with the exact dependency.
- M CURRENT_TASK.md
- M DECISIONS_NEEDED.md
28/08/26 09:30 [FEAT] (`c476969`, `68a6b24`) `dev-pro-large` Recorded and applied the approved Artifact ownership contract's first source cuts. Artifact declarations now carry a positive reviewed definition version and canonical declaration digest, so deployment registration cannot masquerade as graph configuration. Retired the unreachable Console configuration and draft-flow routes plus their action buttons, leaving the operator-facing artifact, IAM, run and approval surfaces intact. The complete Exigence suite and focused Exigence Console widgets pass; the next migration cut replaces the configuration repository and registration shape with Artifact revisions and deployment observations.
- M citadel_core/exigence/src/artifact.ts
- M citadel_core/exigence/src/artifact_registry.ts
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/src/app/platform_exigence_pages.dart
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
28/08/26 09:44 [FEAT] (`bfa8381`, `9c81893`) `dev-pro-large` Defined the authoritative Artifact revision contract before persistence migration. Each immutable project-scoped revision now carries publication identity and digest-pinned coordinates for provider, pricing, adapter, approval policy, and Palisade Access, Effect, and Data Handling Boundaries; validation refuses mutable or malformed evidence. No runtime traffic or persistence path was dual-run. TypeScript checking and the complete 549-test Exigence suite pass; repository and consumer replacement remains the next atomic cut.
- M citadel_core/exigence/src/artifact.ts
28/08/26 14:44 [FEAT] (`255ce0a`, `4784c62`, `e98858e`, `d7e4b94`, `180cfe6`, `d5b2b62`, `2bfb126`, `9b19a52`, `f8dfa62`) `dev-pro-large` Completed every unblocked Phase 2 cut: persisted and rendered immutable per-project Data Handling Boundary revisions; made the runner locally recheck Access, Effect and Data Handling policy for classified intents immediately before execution; classified cloud-produced local intents; persisted immutable sequential Artifact revisions without an active pointer; reduced registration to deployment observation; moved Artifact listings and revision history to the authoritative repository; proxied exact history through Palisade; and rendered it in the Console. Exigence, Platform server, Console and Localbridge gates pass. Runtime configuration deletion is blocked only on ownership of trigger/runtime inputs, and live Manifold WhatsApp delivery is blocked on provider approval plus real WABA test configuration; both questions and evidence are recorded.
- A citadel_core/platform/api/lib/src/platform_data_handling_models.dart
- A citadel_core/platform/server/lib/src/platform_data_handling_service.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/localbridge/src/config.ts
- M citadel_core/localbridge/src/runner.ts
- A citadel_core/exigence/src/artifact_repository.ts
- M citadel_core/exigence/src/artifact_registry.ts
- M citadel_core/exigence/src/private_platform_api.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_platform/lib/src/app/platform_palisade_pages.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
- M citadel_platform/lib/src/app/platform_exigence_pages.dart
- M CURRENT_TASK.md
- M CURRENT_RELEASE.md
- M DECISIONS_NEEDED.md
28/08/26 17:20 [FEAT] (`80f549b`, `3cf98e5`, `1eae5b4`, `633d95f`) `claude-opus-5` Completed the Phase 2 configuration cut. The immutable Artifact revision now owns typed graph and trigger configuration — declared steps and tools, a per-graph union, the redaction policy, and parameters for whichever triggers the artifact declares — all covered by the revision digest; publication refuses a trigger without its parameters, a graph step naming an undeclared tool, an unsafe URL or client path, and a secret pasted where a Secret Manager reference belongs. Runtime loading, triggers, schedules and run snapshots resolve revisions: a run snapshot is one coordinate instead of six, because the revision digest already covers the typed configuration and every shared resource's evidence coordinates. Deleted the active pointer and its collection, the `definition` kind, the configuration control service and private API, the schedule and webhook collections, nine proxy operations with their permission entries and contracts, and the Console's unreachable configuration flow and operations page. Kept the immutable store for provider/pricing/adapter/policy, which a revision pins by digest and the resolver verifies on read; the pointer path's cross-checks moved to the resolver intact. Extracted one cron grammar shared by the dispatcher and publication after a second grammar published `*/5 * * * *` and never fired it. Gates: 553 Exigence unit, 96 Firestore emulator, 192 Platform server, 288 Console, 173 CLI, 46 Palisade authority. Two carried risks recorded in CURRENT_TASK.md: the Console's Enable/Disable toggle is removed rather than reimplemented, and first-boot publication needs Palisade boundary and reference-endpoint environment variables that the provisioning Terraform does not set yet.
- M citadel_core/exigence/src/artifact.ts
- A citadel_core/exigence/src/artifact_run_snapshot.ts
- A citadel_core/exigence/src/artifact_runtime_resolver.ts
- A citadel_core/exigence/src/artifact_bundle.ts
- A citadel_core/exigence/src/artifact_triggers.ts
- A citadel_core/exigence/src/cron.ts
- M citadel_core/exigence/src/configuration_repository.ts
- D citadel_core/exigence/src/configuration_control.ts
- D citadel_core/exigence/src/private_configuration_api.ts
- M citadel_core/exigence/src/reference_deployment_config.ts
- M citadel_core/exigence/src/reference_runtime_bootstrap.ts
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/src/platform_proxy_models.dart
- M citadel_core/platform/server/lib/src/platform_permission_map.dart
- D citadel_platform/lib/src/app/platform_artifact_configuration.dart
- M citadel_platform/lib/src/app/platform_exigence_pages.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
- M CURRENT_TASK.md
- M DECISIONS.md
28/08/26 18:05 [FEAT] (`03dede0`, `7483d04`) `claude-opus-5` Closed the Terraform half of the bootstrap gap and surfaced the half that cannot be closed yet. The Exigence runtime module and provisioning template now take an `artifact_authority` object — identity plus three `resourceId:revision:digest` boundaries — and set the matching environment variables only for a runtime that bootstraps; both validate. The provisioning API requires the variable so a request without it is refused at plan time rather than rolling the deployment back after every resource is created. Investigating who supplies it found the real blocker: only Data Handling boundaries are published as revisioned resources, so two of the three coordinates every Artifact revision demands have no producer anywhere, and console-built provisioning cannot complete. The Console's Exigence build step now names the prerequisite instead of offering a button that fails, and the decision — publish Access and Effect as revisions and resolve all three server-side, or reduce what a revision pins — is recorded in DECISIONS_NEEDED.md. Hand-built clients are unaffected; the publish tool takes the coordinates as flags. 193 Platform server and 288 Console tests pass.
- M citadel_core/exigence/infra/modules/runtime/main.tf
- M citadel_core/exigence/infra/modules/runtime/variables.tf
- M citadel_core/platform/provisioner/templates/exigence-runtime/main.tf
- M citadel_core/platform/provisioner/templates/exigence-runtime/variables.tf
- M citadel_core/platform/server/lib/src/platform_provisioning_service.dart
- M citadel_platform/lib/src/app/platform_service_setup_plans.dart
- M CURRENT_TASK.md
- M DECISIONS_NEEDED.md
28/08/26 19:40 [FEAT] (`8896111`, `6c12e60`) `claude-opus-5` Closed the blocker the Phase 2 cut exposed. Access and Effect Boundaries are now published as immutable digest-pinned revisions the way Data Handling already was, in one `palisade_boundary_revisions` collection discriminated by kind, with list and publish routes gated on the existing `platform.boundaries.*` permissions, a Console table and publish dialog per kind, and a Firestore rule denying browsers direct access. Provisioning composes `artifact_authority` server-side per the 15/08/26 authority rule: a caller names the boundaries it means — defaulting to `default` — and the Platform API pins the coordinates those names currently resolve to; naming `artifact_authority` itself is refused, and a boundary that was never published refuses the build before a job exists. Resolution happens again at apply rather than carrying the plan's answer, so a boundary published between the two is the one the artifact is bound by. Publication refuses a relative path pattern, a malformed or unsupported URL pattern, and an empty boundary. Gates: 31 API, 209 Platform server, 291 Console, 173 CLI, 46 Palisade authority, 553 Exigence unit.
- A citadel_core/platform/api/lib/src/palisade_boundary_models.dart
- A citadel_core/platform/api/lib/src/palisade_boundary_json.dart
- A citadel_core/platform/server/lib/src/platform_boundary_service.dart
- A citadel_core/platform/server/lib/src/platform_artifact_authority.dart
- M citadel_core/platform/server/lib/src/platform_provisioning_service.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- M citadel_core/firestore.rules
- M citadel_platform/lib/src/app/platform_palisade_pages.dart
- M citadel_platform/lib/src/app/platform_workspace_api.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/platform_service_setup_plans.dart
- M CURRENT_TASK.md
- M DECISIONS.md
- M DECISIONS_NEEDED.md
29/08/26 06:45 [FIX] (`7e8f83d`) `claude-opus-5` Closed a cross-layer defect the new tests found and verified the Console flow in a browser. Both boundary services accepted `@` in a boundary id, copied from the actor rule where a person's address needs it — but an Artifact revision pins a boundary as `resourceId:revision:digest` and both parsers of that string, the Terraform variable validation and the TypeScript runtime, reject `@`. Such a boundary published cleanly and could never be pinned: found at a refused plan, or a first boot rolled back with every resource created. The actor and resource-id rules are now separate in both services. Two contract tests hold the three grammars together, one either side of the language boundary, with the patterns quoted literally so a change to either shows as a diff of two spellings. Added a Firestore emulator test for the boundary store, since the unit tests stub the transport and therefore fake the immutability precondition and the wire decoding — the Phase R failure mode. E2E through the Console in Chrome confirmed the three tables render and fail independently, the rule-line validation blocks and explains, publishing re-renders only its own table, and revisions increment per boundary with history kept. The HTTP seam remains unproven and is recorded in test_status.md.
- M citadel_core/platform/server/lib/src/platform_boundary_service.dart
- M citadel_core/platform/server/lib/src/platform_data_handling_service.dart
- A citadel_core/platform/server/test/platform_artifact_authority_contract_test.dart
- A citadel_core/platform/server/test/platform_boundary_service_emulator_test.dart
- M citadel_core/platform/server/dart_test.yaml
- A citadel_core/exigence/test/platform_authority_contract.test.ts
- M citadel_core/exigence/src/reference_runtime_bootstrap.ts
- M _dev/test_status.md
29/08/26 07:20 [FEAT] (`49fb7dd`) `claude-opus-5` Resolved the 15/08/26 global-owner question. A configured set of platform owners is now granted superdev on every project, written per project as it is claimed, so the operator keeps full access to projects somebody else created without reintroducing a global grant — each record is ordinary, project-scoped, listed on the access screen and revocable one project at a time. The set is deployment configuration (`CITADEL_PLATFORM_OWNERS`, `platform_owners` on the runtime module), empty by default, with the production root naming the operator. Owner grants reconcile on every claim rather than only the first, since a half-written claim would otherwise lock an owner out of a project for good; an existing owner grant is never rewritten so a deliberate narrowing survives. Nothing needs re-issuing as the catalogue grows because superdev is `allPermissions: true`. 216 Platform server tests pass and terraform validate passes on the module and the production root. Carried forward: the backfill for projects that already exist (`axis-education`, `core-platform`), since the mechanism only fires on a claim, and a project created but never claimed still has no grants for anyone.
- M citadel_core/platform/server/lib/src/platform_grant_service.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- M citadel_core/platform/server/test/platform_grant_route_test.dart
- M citadel_core/platform/infra/modules/runtime/main.tf
- M citadel_core/platform/infra/modules/runtime/variables.tf
- M citadel_core/platform/infra/environments/production/runtime/main.tf
- M DECISIONS.md
- M DECISIONS_NEEDED.md
29/08/26 07:45 [FEAT] (`41b1286`) `claude-opus-5` Closed the forward-only gap in the platform-owner mechanism with `tool/reconcile_platform_owners.dart`, which adds a configured owner's superdev grant to projects that already exist. It only ever adds: an owner already holding a grant is left alone, and one holding less than superdev is reported rather than corrected, because somebody narrowed it deliberately. Dry run by default, owners named on the command line so the intention sits in shell history beside the `--apply`, and a listing that would be truncated refuses rather than reporting success over the first page. Ran it read-only against the live registry: four projects exist — `axis-education`, `citadel-platform`, `demo-sandbox`, `exigence-lab` — and the operator already holds superdev on all four, so the 15/08/26 backfill was applied and nothing is outstanding. The `DECISIONS_NEEDED` entry is closed on that evidence. 219 Platform server tests pass.
- M citadel_core/platform/server/lib/src/platform_grant_service.dart
- A citadel_core/platform/server/tool/reconcile_platform_owners.dart
- M citadel_core/platform/server/test/platform_grant_route_test.dart
- M DECISIONS.md
- M DECISIONS_NEEDED.md
29/08/26 08:55 [FEAT] (`063c299`, `c35d94e`, `9fc0d2e`) `claude-opus-5` Restored Enable/Disable as what it now is: publishing the next Artifact revision. `POST /v1/projects/{id}/exigence/artifacts/{artifactId}/revisions` derives the next revision from the latest and carries everything else forward verbatim, so enabling an artifact cannot quietly move where it writes; the body names exactly one field and anything else is refused rather than dropped; setting the state an artifact already holds publishes nothing. Proxied under `exigence.automations.update` with an idempotency key required. The Console offers a dialog rather than a switch, because a switch would imply a field flipped and hide that the history grew — it says the next revision carries everything else forward, that the current one stays in the history, and afterwards reports which revision it made. Found and fixed a defect that would have blocked the first real publication: `publishedBy` was validated against the resource-id pattern, which rejects the colon in the platform's actor grammar, so `firebaseIdToken:AbCd1234` failed while the fixtures' `operator.obsidian` passed. Gates: 562 Exigence, 219 Platform server, 293 Console. Deployed as revision `citadel-platform-api-00027-sc7`; the publish route answers 403 rather than 404, so it exists and is gated.
- A citadel_core/exigence/src/artifact_republish.ts
- M citadel_core/exigence/src/artifact.ts
- M citadel_core/exigence/src/private_platform_api.ts
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_platform/lib/src/app/platform_exigence_pages.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
29/08/26 09:20 [FEAT] (`c518464`, `b36367f`) `claude-opus-5` Fixed the browser harness and proved republication against real Firestore. `lib/main_dev.dart` runs the real Console against in-memory transports and keeps its mutations, so an interface change can be seen without a deployed API or a sign-in; it overrides every platform client because six of them report the same missing-API message, which is what made a half-wired harness look like an unconfigured build. Added an emulator test for republication: revision 2 lands and the store agrees, revision 1 stays readable and still enabled, and asking for the state already held writes nothing. 563 Exigence unit and 97 emulator tests pass. Did NOT deploy the Exigence runtime: a live read found 5 configuration documents and zero Artifact revisions, so the new runtime would fail at boot and roll back. The migration order and the decision it needs are recorded in test_status.md.
- A citadel_platform/lib/main_dev.dart
- M citadel_core/exigence/test/artifact_repository.integration.test.ts
- M AGENTS.md
29/08/26 09:50 [FIX] (`b7afff7`) `claude-opus-5` Retired every project but the two that should exist. Citadel had been a client of itself: the `demo` Exigence root ran with `client = "citadel-platform"` and `customer_database_id = "(default)"`, so the reference artifact wrote into the same database as `palisade_grants` and `platform_projects`, and the registry entry existed only because Phase R needed some client and proxy role-resolution refuses a project it cannot find. Destroyed 27 resources (the runtime, its scheduler, queue, service accounts, IAM and three Firestore indexes), leaving `citadel-platform-api` and `citadel-arm-evidence`; project services stayed enabled because the module sets `disable_on_destroy = false`. Removed the `demo` and `demo-sandbox` Terraform roots so nothing can re-apply them. Cleaned the registry to `axis-education` alone: deleted three project documents, eight grants and four orphaned artifact identities, backed up first. Recorded in AGENTS.md and DECISIONS.md. Outstanding: the `demo-sandbox` customer-agent runtime lives in `learning-gcp-404803`, which this operator's credentials cannot reach; and `demo-project` does not exist yet.
- D citadel_core/exigence/infra/environments/demo/**
- D citadel_core/exigence/infra/environments/demo-sandbox/**
- M AGENTS.md
- M DECISIONS.md
29/08/26 10:15 [FEAT] (`cdac240`) `claude-opus-5` Made `demo-project` a real client backed by the Google Cloud project `learning-gcp-404803` — its own project rather than the host's, which is the point of having retired `citadel-platform` as a client. Applied the same cross-project boundary `axis-education` has: a metadata-only custom role for the Platform API inventory observer and `roles/datastore.user` for the ARM evidence runtime, nothing speculative. Applying it needed `roles/iam.roleAdmin` on the backing project, since `resourcemanager.projectIamAdmin` administers policy but not custom roles; granted to the operator's own account on their own project and revocable. Registered `platform_projects/demo-project` and wrote its owner grant through `tool/reconcile_platform_owners.dart` rather than by hand, which exercised that mechanism against the live registry for the first time. Both projects now report the operator holding superdev. The `citadel-provisioner` service account already held scheduler, tasks and datastore admin there from the retired demo-sandbox setup, so it can build the runtime when boundaries are published.
- A citadel_core/platform/infra/environments/production/customers/demo-project/**
- M AGENTS.md
29/08/26 10:40 [FEAT] (`3b26f20`) `claude-opus-5` Proved the boundary chain end to end on `demo-project` against live infrastructure. Added `tool/publish_boundary.dart` for the same reason `provision_artifact_identity.dart` exists — the first boundary on a project must exist before anything can be built there, and it should not need a browser. Published all three boundaries for `demo-project`; the validator immediately refused a relative Effect path, which was a real modelling mistake on my part since a Firestore document path is absolute. `artifactAuthorityResolver` then resolved `demo-project` to three coordinates whose digests match the published revisions, and refused `axis-education` by name rather than defaulting, which is the safety property working on real data. 221 Platform server tests pass.
- A citadel_core/platform/server/tool/publish_boundary.dart
29/08/26 11:05 [FEAT] (`2967e87`) `claude-opus-5` Started Manifold, the last Feature 4.5 acceptance item, with the WhatsApp channel configuration record: immutable digest-pinned revisions in the registry naming which WABA and number a project sends from and the names of the secrets that authorise it. No secret value is stored — access and verify tokens are pinned Secret Manager version resources, `latest` is refused because a channel that silently picks up a new token changed behaviour with nothing published, and the two must differ since they rotate independently. Also refused: a WABA or phone id that is not one of Meta's numeric identifiers, a non-E.164 test recipient, and enabling a second channel on a different number. The stored payload is asserted whole rather than field by field, since a leaked secret would be invisible to a field-at-a-time check. Browsers are denied the collection. 31 API and 228 Platform server tests pass. Remaining for Manifold: the publish/list routes and Console page, the Meta Cloud API connector, webhook verification and receipt, the governed reply tool, and live validation against a real WABA.
- A citadel_core/platform/api/lib/src/manifold_channel_models.dart
- A citadel_core/platform/api/lib/src/manifold_channel_json.dart
- A citadel_core/platform/server/lib/src/platform_manifold_service.dart
- A citadel_core/platform/server/test/platform_manifold_service_test.dart
- M citadel_core/firestore.rules
29/08/26 11:35 [FEAT] (`a846fcc`, `9cc6a43`, `59b2f62`) `claude-opus-5` Manifold channel administration through the Platform API and the Console. Two new Palisade permissions beside the boundary ones, since a channel is project configuration deciding what may leave the platform as a client's own identity: `platform.manifold.channels.list` is a viewer read — seeing which number your project replies from is how you notice it is wrong — and publishing is superdev-only. The catalogue export test caught the stale generated file and named the command to fix it. The route overrides the body's project, author and digest, and the service's refusals answer 409 through it. The Console gets its own Manifold shell rather than a page under Palisade, showing the number as a person reads it and never Meta's numeric id, with no secret name on screen. Gates: 46 Palisade, 233 Platform server, 297 Console. One slip corrected: the Console commit went in with three analyzer issues outstanding, which the repo's rule forbids; fixed in `59b2f62`.
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/catalogue.json
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- A citadel_core/platform/server/test/platform_manifold_route_test.dart
- A citadel_platform/lib/src/app/platform_manifold_pages.dart
- A citadel_platform/test/platform_manifold_pages_test.dart
29/08/26 12:10 [FEAT] (`9305004`, `cc2214f`) `claude-opus-5` Manifold's Meta WhatsApp connector and webhook. The connector implements the existing `ExternalChannel` contract so it inherits the send-once ledger rather than growing its own idempotency, and respects that contract's one load-bearing distinction: `sendOnce` releases the idempotency claim only for a refusal, so a dropped connection, a 429, a 5xx and an acceptance carrying no message id are all thrown as unavailability, leaving the claim held. A WhatsApp message cannot be unsent. `preview_url` is false so Meta does not fetch whatever the artifact wrote and show it as though Citadel vouched for it; the Graph version is pinned; Meta's own refusal message and code are reported. The webhook verifies the exact bytes Meta signed, compares both the signature and the verify token in constant time through fixed-width digests so a length mismatch leaks nothing, reports unreadable message types rather than dropping them, and treats a delivery with no messages as ordinary since Meta sends status callbacks through the same hook. It stores nothing — bodies are client data. Found and fixed a test bug while writing the webhook tests: the tamper case replaced text absent from its own fixture, so it verified an unmodified body and proved nothing; it now asserts the tamper changed something. 577 Exigence tests pass.
- A citadel_core/exigence/src/whatsapp_channel.ts
- A citadel_core/exigence/src/whatsapp_webhook.ts
- A citadel_core/exigence/test/whatsapp_channel.test.ts
- A citadel_core/exigence/test/whatsapp_webhook.test.ts
29/08/26 12:35 [FEAT] (`85ba50a`) `claude-opus-5` The seam between published WhatsApp configuration and the Meta connector. The resolver reads the latest published channel revision, fetches the token from the Secret Manager version the record names, and hands it to the connector — which never sees a secret name, so it cannot read one of its own choosing. It refuses a channel nobody published, a disabled one (before Meta, so it costs a customer nothing), one belonging to another project (a lookup returning another client's channel would send as their number), and an unreadable or empty secret named as its own problem. The token is trimmed, since trailing whitespace would be sent as part of the credential. No new tool was added: `channel.send` already exists with the right scope and WhatsApp is a channel behind it. `bindChannelSend` builds its channel map once, which would freeze a published revision until the next deploy, so the map holds a late-bound channel — an entry that is a promise to resolve rather than a resolved channel — and a disabling takes effect on the next message. 584 Exigence tests pass.
- A citadel_core/exigence/src/whatsapp_resolver.ts
- A citadel_core/exigence/test/whatsapp_resolver.test.ts
29/08/26 17:45 [FEAT/FIX] (`d0f4b29` in exigence; `857ea4f` in citadel_core) `claude-opus-5` The Firestore source behind the WhatsApp resolver. `FirestoreWhatsAppChannelRepository` reads the channel revision the Platform API published — given the *registry* Firestore, never the customer one: the record names a phone number id and a Secret Manager version, and read from the customer database anyone able to write there could point the channel at a number and token of their own and send as this business. The highest revision wins whether or not it is enabled, because falling back to the last enabled revision would quietly undo an operator switching a channel off; an unreadable revision is refused rather than skipped, so a corrupt newest revision cannot send from an older one while the Console shows the newer. The document id and collection are a cross-language contract and a disagreement is silent — the runtime would report no channel is published while the Console shows one — so both spellings are now literals asserted on both sides (`whatsapp_channel_repository.test.ts` and `platform_manifold_service_test.dart`). Also unblocked the whole Firestore integration suite: firebase-tools 13.35.1 cannot load its own dependencies under the Node 21 in this environment (the failure `_dev/HANDOFF_PROMPT.md` recorded), and 14.19.0 runs it — 101 integration tests pass, including four new ones.
- A citadel_core/exigence/src/whatsapp_channel_repository.ts
- A citadel_core/exigence/test/whatsapp_channel_repository.test.ts
- A citadel_core/exigence/test/whatsapp_channel_repository.integration.test.ts
- M citadel_core/exigence/package.json
- M citadel_core/platform/server/test/platform_manifold_service_test.dart
29/08/26 18:40 [FEAT] (`f9b679a` in exigence; `bd27799` in citadel_core; `c7d00a0` in citadel_platform) `claude-opus-5` Manifold's WhatsApp webhook is served. The verification and delivery functions had nothing serving them and could not have been served: the signature is HMAC with Meta's *app secret*, and the channel record had no reference to one — the verify token it did carry is used once when the subscription is set up and proves nothing about a delivery. Added as `webhookSigningSecret`, by reference; all three secrets must now be distinct. `WhatsAppWebhookEndpoint` is the only public surface on the runtime (everything else is reached by Cloud Tasks with an OIDC token) and is written for a stranger rather than for Meta: the channel is named in the path and never read from the body, because a handler that parsed the delivery to find which key to verify it with would be trusting the attacker's claim about which key to use. Every refusal answers a flat 403 with the reason only in the log — distinguishing "no such project" from "bad signature" would make the endpoint a directory of which businesses use Citadel and which channels they have switched on. An unreadable signing secret is a 403 rather than a 500 because Meta retries a 500 and would eventually disable the subscription, while what the sink cannot keep does throw, since a message accepted and then lost is a customer who was never answered. The delivery's number is checked against the channel's: one Meta app holds several numbers, so a signature is not a statement about which business a message is for. The repository now offers two narrow views over one record — sending sees the access token's name, the webhook sees the verify and signing secrets, neither sees the other's. Mounting it in the HTTP server is optional and off by default; serving it means the service accepts unauthenticated requests, which is not the runtime's decision to make. Deployed the Platform API (`sha256:7170adff…`) carrying the new field; `/v1/projects/demo-project/manifold/channels` answers 401 rather than 404 on both GET and POST, so the route is live. 600 Exigence tests, 235 platform server tests, 297 Console tests, `dart analyze` and `flutter analyze` clean.
- A citadel_core/exigence/src/whatsapp_webhook_endpoint.ts
- A citadel_core/exigence/test/whatsapp_webhook_endpoint.test.ts
- M citadel_core/exigence/src/whatsapp_channel_repository.ts
- M citadel_core/exigence/src/node_http_server.ts
- M citadel_core/platform/api/lib/src/manifold_channel_models.dart
- M citadel_core/platform/api/lib/src/manifold_channel_json.dart
- M citadel_core/platform/server/lib/src/platform_manifold_service.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_platform/lib/src/app/platform_workspace_api.dart
29/08/26 19:30 [FEAT] (`29756d5` in exigence) `claude-opus-5` The receive path now ends in a run. `conversation` joins the Artifact trigger kinds, declared on the Artifact rather than on the channel: the channel record already says what number sends and which secrets authorise it, and naming the artifact there instead would put "which agent answers this number" outside the digest a run records. Agents only — a workflow reacting to a message is an `event`, its work fixed before the message arrives, whereas a conversation is the case where a person is waiting, the reply is composed rather than looked up, and sending cannot be undone; what bounds that is the step and budget ceilings only an agent carries. `ArtifactRevisionConversationSource` searches the latest enabled revisions and refuses when two answer one channel, because a customer would otherwise get two replies or one at random and the choice would be invisible to whoever published the second. `WhatsAppRunSink` keys idempotency on Meta's own message id, collapses messages repeated inside one delivery, starts one run per distinct message, and starts one for an unreadable message too — an agent that sees `unsupported` can say so. A message nothing answers is logged rather than thrown: throwing would have Meta redeliver until it disabled the webhook, but the customer is waiting, so it is recorded. 606 tests.
- A citadel_core/exigence/src/whatsapp_run_sink.ts
- A citadel_core/exigence/test/whatsapp_run_sink.test.ts
- M citadel_core/exigence/src/artifact.ts
- M citadel_core/exigence/src/artifact_triggers.ts
29/08/26 21:10 [FEAT/FIX] (`405ab4f` in citadel_platform) `claude-opus-5` Publishing a WhatsApp channel from the Console. The page was read-only, so the only way to add a number a business sends from was calling the API directly; it now has the page chrome every other product page has and the publish action `platform.manifold.channels.update` already existed for. The form asks for secret *names* and says so in every label — a token typed into a browser would travel to an immutable revision nobody could rotate it out of — and reproduces the API's own refusals before the round trip so an operator finds out while the field is still in front of them. The revision is derived rather than typed, and Enabled is off by default because the first message out of a new number should be one somebody meant to send. Also fixed `/manifold`, which answered "Not found" while every other product root redirects, and routed the Data Handling publish dialog's failure through describeFailure, which was rendering an exception's toString. Driven end to end in Chrome: the form refused a pasted access token with everything else valid, accepted the version name, and the table came back with the new channel at revision 1, disabled.
- A citadel_platform/test/platform_manifold_inbox_test.dart (later)
- M citadel_platform/lib/src/app/platform_manifold_pages.dart
- M citadel_platform/lib/src/app/platform_palisade_pages.dart
- M citadel_platform/lib/src/app/citadel_platform_app.dart
- M citadel_platform/lib/main_dev.dart
29/08/26 21:50 [FEAT] (`2153357` in exigence) `claude-opus-5` Consent and opt-out. Meta and several jurisdictions require it, but the reason it is careful is that every failure is a message arriving at somebody who asked for it to stop. The request is made in the conversation, so it is read off the webhook and enforced on the way out by `consentGatedChannel`, which wraps the channel rather than living in the connector so the check cannot be skipped by calling the connector directly. Keywords match the whole trimmed message, never a substring — "please don't stop sending these" means the opposite — and are not configurable per project, because a person typing STOP is entitled to be understood without having read a client's settings. A message the runtime cannot read counts as neither. An opt-out records and answers nobody; an opt-in records and is answered. Consent settles before the artifact is looked up, so somebody who says STOP has stopped even if the agent was disabled an hour ago. Refusal is `ChannelRefusedError` so the idempotency claim is released. The ledger is in the client's own database and takes the later timestamp, because Meta redelivers out of order.
- A citadel_core/exigence/src/whatsapp_consent.ts
- A citadel_core/exigence/test/whatsapp_consent.test.ts
- A citadel_core/exigence/test/whatsapp_consent.integration.test.ts
- M citadel_core/exigence/src/whatsapp_run_sink.ts
29/08/26 22:20 [FEAT] (`932be70` in exigence) `claude-opus-5` Conversation threading. Without it a message is a run and nothing else: an agent answering the third question would not know there were two before it. Both sides are recorded — inbound before anything is decided about it, outbound only after the provider accepted it, since a reply written down and then refused would show an operator something the customer never received. A thread is per channel, because the same person writing to support and to billing is having two conversations. The provider's message id is the entry id so a redelivery lands on the message it already is; the summary only moves forward while the thread sorts by when something was said, so a late redelivery belongs where it was spoken. An outbound entry names its run — the thread's evidentiary value — and an inbound one may not.
- A citadel_core/exigence/src/conversation_store.ts
- A citadel_core/exigence/test/conversation_store.test.ts
- A citadel_core/exigence/test/conversation_store.integration.test.ts
29/08/26 23:05 [FEAT] (`7500daf` in citadel_core; `21f7c28` in citadel_platform) `claude-opus-5` The Manifold inbox, now Manifold's landing page. Conversations are proxied to the Exigence runtime and never served from the control plane: the messages are the client's own customer data. `platform.manifold.conversations.read` is a separate, superdev-only permission — knowing which number a project replies from is configuration, while the messages are the most sensitive data a business holds. The listing carries no bodies, because a page that showed every customer's words on open would put them on screen before anybody asked; opening a thread is the act that fetches. Who spoke last is a badge, since the threads where that was the customer are the ones nobody answered. An outbound message shows the run that said it; a message the runtime could not read says so rather than rendering an empty bubble. Driven end to end in Chrome. 305 Console tests, 235 platform server tests, 46 Palisade tests, 628 Exigence unit and 108 integration tests.
- A citadel_platform/lib/src/app/platform_manifold_pages.dart (inbox page)
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/catalogue.json
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/src/platform_proxy_models.dart
- M citadel_core/platform/server/lib/src/platform_permission_map.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
- M citadel_platform/lib/src/app/platform_firestore.dart
- M citadel_platform/lib/src/app/platform_shell.dart
29/08/26 23:40 [FIX] (`6b3aac8` in exigence) `claude-opus-5` One spelling of a phone number across the whole receive path. The webhook reports a sender as `+6591234567` and the connector requires that same form of a recipient, while the consent ledger and conversation store were written expecting `6591234567` — the first real message would have been refused by a validator: no opt-out recorded, no thread, and somebody who typed STOP still being messaged. Every unit test passed because every fixture spelled it the way its own component wanted. Added `whatsapp_receive_path.test.ts`: a signed payload in the shape Meta actually posts, driven through the endpoint to a run, a thread and the consent ledger, with fakes that run the real validators — a fake validating nothing is how the bug survived. Verified by restoring the old validator and watching the end-to-end test fail.
- A citadel_core/exigence/test/whatsapp_receive_path.test.ts
- M citadel_core/exigence/src/whatsapp_consent.ts
- M citadel_core/exigence/src/conversation_store.ts
30/08/26 00:30 [FEAT] (`505180f`, `d6220d6` in exigence; `454f10b` in citadel_platform) `claude-opus-5` Delivery state. Meta accepting a message is not the customer receiving it, and nothing read the status callbacks, so a send Meta took and could not deliver looked exactly like one that arrived. `readWhatsAppDelivery` now returns messages and statuses separately and the sink handles them separately — an agent woken by "delivered" would be answering its own reply. An outbound message starts at `sent`, which is what makes one stuck there visible as stuck; state only advances, because a stale `sent` after `read` would make an answered conversation look unanswered; a failure is terminal, because a `delivered` after it is Meta catching up rather than the message getting through. An unknown state is dropped rather than recorded as a failure. A failure carries Meta's reason verbatim. The thread summary flags a failed delivery and clears it when a later reply is accepted, because a failure only visible inside a thread is not visible. Added the collection-group Firestore index the status lookup needs — without it every message stays at `sent` for ever and a business that had stopped reaching its customers would look exactly like one that was reaching them.
- A citadel_core/exigence/test/whatsapp_delivery.test.ts
- M citadel_core/exigence/src/whatsapp_webhook.ts
- M citadel_core/exigence/src/whatsapp_webhook_endpoint.ts
- M citadel_core/exigence/src/whatsapp_run_sink.ts
- M citadel_core/exigence/src/conversation_store.ts
- M citadel_core/exigence/infra/modules/runtime/main.tf
- M citadel_platform/lib/src/app/platform_manifold_pages.dart
30/08/26 01:20 [FEAT] (`97181b3` in exigence; `92c1748` in citadel_core; `54cecb2` in citadel_platform) `claude-opus-5` A colleague can answer a customer themselves. The same channel an agent uses, so the same consent gate refuses it — a human reply that skipped consent would be the exact message somebody asked never to receive, sent by the one person who could see they had asked — and the same thread, so a conversation reads as one conversation. A reply names the last message its author had on screen, checked before sending: a reply sent and then reported as a conflict has already reached the customer. An outbound message records either the run that composed it or the person who wrote it, never both. `platform.manifold.conversations.reply` is its own superdev-only permission; adding the route first swallowed the channel publish POST, caught by the existing route tests.
- A citadel_core/exigence/src/conversation_reply.ts
- A citadel_core/exigence/test/conversation_reply.test.ts
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_platform/lib/src/app/platform_manifold_pages.dart
30/08/26 02:10 [FEAT] (`44ab608` in exigence; `caccaff` in citadel_platform) `claude-opus-5` Attachments. Every photo, document and voice note was a flat "unsupported", so a business whose customers send pictures of damaged deliveries had a record saying nothing arrived. The webhook describes what came and does not fetch — it is public and must answer before Meta retries. The bytes go to the client's own bucket: declared length checked before buffering and again on arrival, Meta's published hash verified, and a media URL that is not an https one from Meta not followed. The object path hashes the counterparty, because a bucket listing should not be a directory of who a business talks to, and hashes Meta's message id, which is not allowed to decide where anything lands. Collection happens after the message is written down and a failure is logged rather than raised, since Meta expires media in days and failing the delivery would leave a customer unanswered over a file. The run payload gives an agent the type and filename, never a URL. The Console names an attachment and never renders it.
- A citadel_core/exigence/src/whatsapp_media.ts
- A citadel_core/exigence/test/whatsapp_media.test.ts
- M citadel_core/exigence/src/whatsapp_webhook.ts
- M citadel_core/exigence/src/whatsapp_run_sink.ts
- M citadel_core/exigence/src/conversation_store.ts
- M citadel_platform/lib/src/app/platform_exigence_api.dart
- M citadel_platform/lib/src/app/platform_manifold_pages.dart
30/08/26 09:40 [FEAT/FIX] (`66bf3a5` in exigence; `5de1b0c` in citadel_core; `87177cf` in citadel_platform) `claude-opus-5` Manifold composed into the runtime that serves it, and the seam it exposed. Every piece of the WhatsApp path was built and unit-tested in isolation and `runtime_composition.ts` wired none of it — the Platform API proxied `/manifold/conversations` to a runtime with no such route at all. `PrivateManifoldApi` now answers the three routes the Console reads, delegated before the private API's `exigence` prefix check because Manifold is its own product line; the messages stay in the client's own database and the control plane never holds what was said. `composeManifold` assembles the path in one place because the order is the whole of it: the consent gate sits inside the thread recorder, so a reply refused because somebody asked not to be messaged is never written into the thread as though it were sent, and a colleague's reply takes the same channel and thread an artifact's does. The webhook is composed but mounted only when a deployment names a path — serving it makes the service answer callers who proved nothing at the transport, which is a deployment decision, not a wiring one. Two Platform API defects, both on the joins rather than in a layer: the reply route never read the request body, so the runtime was asked to send an empty message and the operator was told their reply was invalid rather than that it never left the control plane; and no Manifold operation appeared in the Exigence success validator, so every successful answer fell through to `_ => false` and came back as 502. `resolveCredentials` replaces the two channel lookups a reply would otherwise need, which could disagree across a repointed channel about which one sent the message. Six new seam tests drive the composed runtime over a real socket, including a signed Meta delivery reaching a thread through the mounted webhook. 562 Exigence unit + 110 emulator, 239 platform server, 312 Console. Attachment collection is composed out and the webhook is switched on nowhere: both need decisions now in DECISIONS_NEEDED.md.
- A citadel_core/exigence/src/manifold_api.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/exigence/src/reference_runtime_bootstrap.ts
- M citadel_core/exigence/src/private_platform_api.ts
- M citadel_core/exigence/src/cloud_run_service.ts
- M citadel_core/exigence/src/whatsapp_resolver.ts
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
30/08/26 12:30 [FEAT] (`58538d4` in exigence; `4d9846a` in citadel_core) `claude-opus-5` Manifold's public surface, separated. Meta has to be able to call in and holds no Citadel credential, so something must accept a request from a caller who proved nothing at the transport — and the only safe way to allow that is for the thing accepting them to have nothing else to reach. So it is a second Cloud Run service per client rather than a route on the runtime: same image, same composition, its own service account, `allUsers` invoker on it alone, and the Exigence runtime's IAM unchanged. One per client and not per channel, because Meta configures a single callback URL per app and names the number in the payload; never one shared across clients, which would need every client's database and secrets. `composePublicWebhookService` mounts the webhook and nothing else and refuses to start with no channel to serve, since a URL Meta will call and this process would 404 for ever looks from outside exactly like a working channel nobody writes to. `CITADEL_SERVICE_ROLE` picks the service and defaults to the private one, so the mistake only goes the safe way. Both share one handler-chain factory and one `local.runtime_env`, because the body bound, the timeouts and the error handling matter most on the open service and a second copy of either is the one that falls behind. A client who enables Manifold also gets a GCS bucket in their own project, apart from the payload bucket: those are a run's inputs and outputs under a redaction policy, this is a photo somebody sent a business, and one bucket holding both turns "delete this customer's messages" into a scan over objects that are mostly not messages. Writes are ifGenerationMatch=0 so Meta's redelivery cannot overwrite the first. The provisioning template derives the bucket name rather than accepting it. And `platform.manifold.conversations.read` becomes a read permission: they are the client's own customers, and a client who cannot see what was said cannot tell that an agent answered badly — replying stays superdev-only, because it puts a message on a phone nobody can take back. 568 Exigence unit + 110 emulator, 241 platform server, 312 Console, 173 CLI, 46 Palisade; terraform validate passes on the module and on the template with its module staged.
- A citadel_core/exigence/src/gcs_media_store.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/exigence/src/node_http_server.ts
- M citadel_core/exigence/src/runtime_entrypoint.ts
- M citadel_core/exigence/src/reference_runtime_bootstrap.ts
- M citadel_core/exigence/infra/modules/runtime/main.tf
- M citadel_core/exigence/infra/modules/runtime/locals.tf
- M citadel_core/exigence/infra/modules/runtime/variables.tf
- M citadel_core/exigence/infra/modules/runtime/outputs.tf
- M citadel_core/platform/provisioner/templates/exigence-runtime/main.tf
- M citadel_core/platform/provisioner/templates/exigence-runtime/variables.tf
- M citadel_core/platform/server/lib/src/platform_provisioning_service.dart
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/catalogue.json
30/08/26 15:10 [FEAT] (`0aa2483` in citadel_core; `2a8da60` in citadel_platform) `claude-opus-5` A channel is enabled, not authored, and its credentials are proved before anything is published against them. The set of channels is the platform's — a project turns one on and supplies credentials for its own account — so the channel id comes from the catalogue rather than a form field, and the Platform API refuses an id nothing recognises. The failures this closes are the quiet ones: a Secret Manager version that does not exist, a token from another app, a phone number id belonging to somebody else's WhatsApp Business Account. None of them failed at publication before; they failed later as a channel that accepted every field and answered no customer, and the first thing that noticed was the customer. `GET /{waba}/phone_numbers` with the token proves the token, the account and the number together — reading the number alone resolves happily for somebody else's — and Meta's readable number is compared on digits, because a correct id for the wrong number is invisible in the id and spacing is not a mismatch. Three states rather than a pass mark: the verify token and the app secret can only be read, since Meta echoes one once at subscription time and the other is proven by the first signed delivery, and four ticks would say the signature check works when nothing has verified a delivery. One verifier used twice — a `verify` route answers while the form is open and the publication runs the same check — because a second implementation would be the one that says yes to something publishing then refuses. The Console's Publish stays dead until the check returns accepted and any edit throws the answer away. A deployment with no verifier refuses to publish rather than waving channels through, and Google's own refusal text never reaches the browser. The unreachable cross-channel "two enabled numbers" rule is deleted. 256 platform server, 31 platform API, 314 Console, 568 Exigence unit, 173 CLI, 46 Palisade.
- A citadel_core/platform/server/lib/src/platform_manifold_verification.dart
- M citadel_core/platform/server/lib/src/platform_manifold_service.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/bin/citadel_platform_api.dart
- M citadel_core/platform/api/lib/src/manifold_channel_models.dart
- M citadel_core/platform/api/lib/src/manifold_channel_json.dart
- M citadel_platform/lib/src/app/platform_manifold_pages.dart
- M citadel_platform/lib/src/app/platform_workspace_api.dart
- M citadel_platform/lib/main_dev.dart

30/08/26 [FEAT] `dev-pro-large` Delivered the last outstanding Feature 4.1 Task 4.1.R4 item, the determinism guard, now that Phase 2 artifacts exist for it to guard. A resumed run replays its completed supersteps, so a node reading the wall clock or drawing a random number continues from state no execution ever produced — silently, with the audit trail recording the wrong values as evidence. The guard is a source scan rather than an ESLint rule because this repository carries no lint toolchain and a guard that arrives with a plugin ecosystem is one more thing to keep working. Its scope is derived, not listed: every module reachable by relative import from anything building a `StateGraph` or a `createGraphStep`, so adding a graph or calling into a new helper pulls that code under the guard on the same commit. Comments and string literals are masked before scanning (this codebase explains itself at length and several of those explanations say `Date.now()`), template interpolations are masked back in as the code they are, and a construct may only be stood down by a `determinism: ok — <reason>` comment whose reason is part of the syntax — a bare marker is reported in its own right and does not suppress. The first run found five constructs, one of them a real defect: the local report artifact stamped the row it appends to a client's workbook from `args.clock?.now() ?? new Date().toISOString()`, which is not internal bookkeeping but a cell somebody reads. Fixed by requiring the clock on `LocalReportGraphArgs`; production already injected one, so only the test fixture moved. The remaining four are two ends of one elapsed-time poll bound, the tool binding's test-only clock fallback (whose `occurredAt` is only written on an append a replay recognises and skips) and the Cloud Tasks dispatcher, which runs between supersteps and is in scope only because a graph module imports its type. Replay-equivalence is now asserted in CI: a run killed mid-graph and resumed produces state deep-equal to the uninterrupted run's, with each effect on the client machine sent exactly once. `npm test` runs the lint first and fails on a finding.

30/08/26 17:30 [FEAT/FIX] (`4253905`, `587c281`, `ee03ad0`, `1a80d78` in exigence; `6458391` in localbridge) `claude-opus-5` What the Knowledge Base can read, and where a trace can go. Word, Excel and PowerPoint are one format wearing three schemas — a ZIP of XML parts — so they are read together by `node:zlib` and the elements those schemas name, with no dependency added: an office corpus that could only index `.txt` and `.md` was refusing most of what anyone would upload. A paragraph's runs are joined because a run boundary is a formatting change rather than a word boundary and splitting there chunks mid-sentence; a spreadsheet reads through the shared string table in row order and a deck slide by slide, so retrieved text reads in the order somebody wrote it. PDF and the pre-2007 binary `.doc`/`.xls`/`.ppt` stay refused by name — those are OLE compound documents, a different problem, and a half-read document indexes plausible sentences in the wrong order with nothing downstream able to tell. Reading them immediately exposed a defect one layer down: the runner returned file contents as a UTF-8 string, so the folder connector could list a `.docx` correctly, refuse nothing, and index a document made of replacement characters beside a digest that no longer described it. `file.read` now says how it encoded the bytes — text if they survive a decode and re-encode, base64 otherwise, tested on the contents rather than the extension — and content labelled base64 that is not is refused rather than half-decoded, since `Buffer.from` drops what it cannot read and a truncated `.docx` still unzips far enough to index part of a document as though it were all of it. OneDrive and SharePoint are now reachable too, for the clients with no synced folder and for document libraries, which nobody syncs: Graph chooses the URLs this calls next and every call to Graph carries a bearer token, so the host is pinned, a paging link off that host is refused rather than followed, and the pre-authenticated download URL — which points at storage, not at Graph — is fetched with no token attached. A 401 raises reauthorization rather than failure, because the pipeline prunes what a listing no longer holds and a lapsed consent would otherwise delete the client's corpus; the token is read from Secret Manager per pass and `quickXorHash` is not trusted as a content digest. Finally the OTLP mirror, the last unbuilt piece of 4.3.1: spans stay in the client's project and an operator who watches everything in Grafana had no way to see them, so stored spans export as OTLP over HTTP — no sidecar, no gRPC dependency, no connection held between invocations. It is a copy and behaves like one: the Firestore write is first and load-bearing, the mirror runs after, a collector that is down costs a counted dropped batch rather than a queue that grows until the instance dies. Building it surfaced the gap that made every trace unreadable anywhere: model and tool spans name a parent `invoke_agent` span and nothing emitted one, so a backend received orphans pointing at an id that resolves to nothing. The projection recorder — the only thing that knows a run reached a conclusion — now writes it, after the journal transition and never instead of it. 774 Exigence unit + 122 emulator, 55 localbridge.
- A citadel_core/exigence/src/office_extraction.ts
- A citadel_core/exigence/src/trace_otlp.ts
- M citadel_core/exigence/src/knowledge_base_extraction.ts
- M citadel_core/exigence/src/knowledge_base_connectors.ts
- M citadel_core/exigence/src/knowledge_base_sync.ts
- M citadel_core/exigence/src/localbridge_tool.ts
- M citadel_core/exigence/src/graph_projection_recorder.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/localbridge/src/execute.ts
- M citadel_core/localbridge/src/intent.ts

30/08/26 19:20 [FEAT] (`06f3e29`, `587c281` in exigence; `0e47e76` in citadel_core; `0c984ec`, `06d6718` in citadel_platform) `claude-opus-5` Two things that were built and unreachable, and the first Watchdog surface. The Graph connector had no way to be pointed at anything — the source dialog offered a local folder, a Drive folder and web pages, so registering OneDrive or SharePoint meant an API call by hand. Both ends now refuse a Graph source with no credential rather than accepting it and failing every night after: the Console before the request, the runtime before the record, and what is stored is a Secret Manager version with a shape check that stops somebody pasting the token into the field meant to point at it. Then Feature 6.2's Task 6.2.1, which is the first Palisade Watchdog code. The policy gate refuses, audits and carries on, which is correct and is exactly why nobody finds out: a denial is one line in one run's audit chain, and an artifact that acts on its own and spends a week being refused looks from every other screen like one that is working. For autonomous artifacts this is the only safety signal that exists. So the same events answer a different question — which identity keeps being told no, and about what — ranked by breadth rather than volume, because forty denials on one tool is a configuration somebody has not finished and four denials across four tools is an artifact reaching for authority it was never given. A hold weighs less than a refusal and is displayed apart from one, since an artifact held often is usually one doing risky work it may do. The report says how many runs it read, so a zero is a fact rather than an unasked question, and says when it was truncated rather than understating the thing it exists to find; a runtime that cannot answer returns 404, because "nothing was denied" is the one wrong answer a safety surface can give, and the page renders a failure as a failure for the same reason. `platform.watchdog.read` is its own permission held by viewer and invoker: these are the client's own automations, and a client who cannot see their agent being refused cannot tell it has stopped doing its job — a narrower record than `platform.audit.read`, which is mostly Citadel operators acting on a client's project. No finding carries what it found. Runner boundary refusals are not in it yet: those return as evidence on the intent rather than as an audit event, so there is nothing to read, and that is recorded as the next slice. 780 Exigence unit + 122 emulator, 311 platform server, 48 Palisade, 341 Console; analyzers clean.
- A citadel_core/exigence/src/watchdog_authorization.ts
- M citadel_core/exigence/src/private_platform_api.ts
- M citadel_core/exigence/src/knowledge_base_source.ts
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/src/platform_permission_map.dart
- M citadel_platform/lib/src/app/platform_palisade_pages.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
- M citadel_platform/lib/src/app/platform_exigence_pages.dart
- M citadel_platform/lib/src/app/platform_shell.dart

30/08/26 21:40 [FEAT] (`a7eb622`, and the refusal-audit change before it, in exigence; `0e47e76` and its follow-up in citadel_core; `c9ebaec` in citadel_platform) `claude-opus-5` Two more Watchdog slices. First, the refusal that happens on the client's own machine: the local runner enforces its Effect Boundary itself and answers with evidence rather than an error — right, since the run continues and the artifact can reason about it, and it also meant the refusal sat inside one activity's payload where nothing aggregated it and nobody read it. A binding can now name a refusal in its own result, the graph step recognises the runner's evidence envelope so any tool answering in that shape is covered, and the event is keyed on the invocation digest so a replayed node writes it once. The Watchdog counts it with the gate's own denials, because from the artifact's side there is no difference — it asked for something it was not allowed to have — and the boundary that said no here is the client's. Second, Task 6.2.3's configuration review, derived entirely from what a project already declares: no cloud reads, no history, no traffic, because a misconfiguration nothing has exercised is exactly the one nobody has noticed. Four checks, each carrying its consequence rather than a score — a tool that may act on somebody's screen with no approval required is the one combination nothing can recover from afterwards; a tool an artifact declares that the project does not allow stops that artifact at the same step on every run and reads from outside as intermittent failure; an enabled artifact with no cap of its own can spend the project's month before any threshold names it; a capability nothing declares is usually what is left when something was removed and the grant was not. Both views sit on `platform.watchdog.read`, listed as deliberate sharing: a role told half of "is this project's automation safe" would be told a different half each week. Nothing here enforces — the gate does, and a second enforcement point that disagreed would be worse than none. The page reports how many runs and how many artifacts it read, so "nothing found" is a fact rather than an unasked question, and a failure renders as a failure rather than as an empty table. 787 Exigence unit + 122 emulator, 311 platform server, 48 Palisade, 344 Console.
- A citadel_core/exigence/src/watchdog_configuration.ts
- M citadel_core/exigence/src/langgraph_tool_binding.ts
- M citadel_core/exigence/src/graph_step.ts
- M citadel_core/exigence/src/private_platform_api.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_platform/lib/src/app/platform_palisade_pages.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart

30/08/26 23:10 [FEAT] (`9b87dd8` in citadel_core; the Watchdog page change in citadel_platform) `claude-opus-5` The other half of 6.2.1, and a signal that had never reached anybody. `detectAuthorityAnomalies` was written with Feature 6.1, carefully, with tests — and was called by nothing: no route, no page, so the thing it exists to notice has never once been seen. It now has a route in the control plane rather than a proxy, on the same reasoning as the audit itself: these are Citadel's own authorization decisions about a client's project, and a client runtime that could serve them could edit the record of what it was refused. Identity types come from the registry through a lookup the route can be handed directly, which is what makes the rule testable on its own — an artifact crosses a lower threshold than a person because nobody is watching an artifact, and which one a principal is must never be guessed from the shape of its id, since a naming convention stops working silently and the failure is a missing alert rather than an error. On the page it is a third section, not a third column: these are identities asking the Platform API, not artifacts calling tools inside a run, and merging them would put somebody opening a page they may not see beside an artifact reaching past its authority. The two shapes stay apart as the detector tells them apart — one permission refused over and over is a deployment expecting authority nobody granted, several distinct ones is something trying its edges — and each row names the permissions, because "denied 40 times" sends a reader to the logs. An unconfigured detector answers 503. 315 platform server, 345 Console.
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- A citadel_core/platform/server/test/palisade_watchdog_route_test.dart
- M citadel_platform/lib/src/app/platform_palisade_pages.dart
- M citadel_platform/lib/src/app/platform_workspace_api.dart
- M citadel_platform/lib/src/app/platform_firestore.dart

31/08/26 00:40 [FEAT] (`2f0324f` in exigence; `a89c661` in citadel_core; `2c6582f` in citadel_platform) `claude-opus-5` Task 6.2.5's measurement half. Four objectives, chosen because each one fails in a way the others cannot see: an artifact can succeed every time and take an hour, be quick and fail half the time, do both well while an approval sits unanswered for two days — which is the automation not running at all with nothing saying so — or do everything right and spend the month's budget by the eighth. Three judgements are what make this a signal instead of a dashboard. There are no default targets, because a threshold nobody picked fires on somebody else's idea of good and the first thing anyone does with that alert is switch it off. Every result carries the sample it was computed over, since a 50% success rate over two runs is two runs and a breach declared from it teaches people to ignore the next one. And an objective with nothing to measure reports `unmeasured`, never met — reporting it as met is how a monitored thing goes quiet and nobody notices, which is the failure this whole feature exists to prevent. Burn is spend against budget measured against the period's own progress, so half a budget in half a month reads differently from half of it in a tenth; a pending approval counts at the age it has reached, because measuring only answered ones reports perfect health on a project where every request is still waiting; the p95 is nearest-rank, so it is a duration something actually took. Targets are written whole on the version they were read at — an omitted target means no target, which merging would make impossible to express, and a threshold quietly reverted by somebody else's save is one nobody knows they are no longer being told about. Reading the objectives is `platform.watchdog.read`; setting them is a new superdev-only `platform.watchdog.configure`, because raising an acceptable failure rate silences an alert about your own project without changing anything that caused it. Delivery is the half that is not built and could not be as the feature file assumes: ARM's alerting is a Console view over its own issues and cases with no ingest another product can post to, so breaches are visible in the Console and pushed nowhere. Three shapes for fixing that are in DECISIONS_NEEDED.md rather than a silent gap. 794 Exigence unit, 315 platform server, 48 Palisade, 347 Console.
- A citadel_core/exigence/src/service_objectives.ts
- A citadel_core/exigence/src/service_objective_store.ts
- M citadel_core/exigence/src/private_platform_api.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_platform/lib/src/app/platform_palisade_pages.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart

30/08/26 22:55 [FEAT] (`d6b7c23`, `b0b5f40` in citadel_core; `d653278` in citadel_platform) `claude-opus-5` The operator settled the open capability question: an artifact reading another Citadel product's record of a client's end users holds its own capability, named `exigence.usercontext.read`, with a `usercontext` tool scope. It is not `exigence.tools.read`, which is what searches the client's own documents — a handbook is the client's material, a session replay is personal data about somebody who never dealt with Citadel and cannot be asked, and one capability for both made "may search our documents, may not read our customers' sessions" a sentence a policy could not say. It does not hold for approval: a read has no effect to reverse, and its sensitivity is the Data Handling Boundary's question. Correlation then got the source it had been missing since the engine was written. It reads the client's own `armIssues` and `conduit_sessions` rather than calling back through the Platform API — the Console's ARM and Conduit routes authorise a person against console permissions an artifact does not hold, and routing an artifact's read through them would have meant inventing a delegation header and a new trust seam on the platform. There is no project to read across: the Firestore handed to the source is the client's, and a request naming another project is refused rather than answered from this one. Issues are selected on last sighting rather than first, because a bug recurring all week is still what this customer just hit. Every crossing goes through `auditedFlow`, which gained a report hook — the doc claimed a lost entry was surfaced somewhere and nothing surfaced it. That audit had no sink and no view: entries were validated and dropped. They now live in `palisade_data_flows` in the client's own project, beside the data they describe, and come back over a window through `/exigence/data-flows`, the proxy and the Palisade Watchdog, sharing `platform.watchdog.read` as declared deliberate sharing. A runtime with no audit store answers 404 rather than an empty list, on the standing rule that "nothing found" must never be reported on the strength of not having looked. **Still not reachable:** no artifact declares `manifold.correlate`, so the tool is bindable and unbound and 7.2.1's first definition-of-done box stays empty; the correlation source is also the audit's only producer, so 6.1.5's twelfth box is `[~]` rather than `[x]`. 808 Exigence unit + 129 emulator, 315 platform server, 48 Palisade authority, 30 Palisade boundary, 55 localbridge, 349 Console.
- A citadel_core/exigence/src/correlation_source.ts
- A citadel_core/exigence/src/correlation_tool.ts
- A citadel_core/exigence/src/data_flow_audit_store.ts
- A citadel_core/exigence/src/data_flow_audit.ts (generated from palisade/boundary)
- A citadel_core/exigence/tool/sync_boundary.mjs
- M citadel_core/palisade/authority/lib/src/permissions.dart
- M citadel_core/palisade/boundary/src/data_flow_audit.ts
- M citadel_core/exigence/src/private_platform_api.ts
- M citadel_core/exigence/src/runtime_composition.ts
- M citadel_core/exigence/src/reference_runtime_bootstrap.ts
- M citadel_core/exigence/infra/modules/runtime/main.tf
- M citadel_core/platform/server/lib/src/platform_proxy_handler.dart
- M citadel_core/platform/server/lib/src/platform_proxy_models.dart
- M citadel_core/platform/server/lib/src/platform_permission_map.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
- M citadel_platform/lib/src/app/platform_palisade_pages.dart

30/08/26 23:40 [FEAT] (`b01acf9` in citadel_platform) `claude-opus-5` Boundary drift, from Task 6.1.5's last bullet. An Artifact revision pins its Access, Effect and Data Handling boundaries by coordinate and digest, which is what makes a run's evidence stable — a later edit to a boundary cannot change what an old run proved. The cost of that is a failure with no symptom: somebody narrows a Data Handling Boundary in the Console, publishes it, and every deployed artifact keeps running against the revision it was deployed with. Nothing fails. The boundary page shows revision 4 published, the artifact page shows the artifact enabled, and the two screens together read as though the change took effect. The Watchdog now compares them and reports three shapes — behind, same revision under a different digest (reported ahead of being behind, because a revision that is not what it says it is makes every other comparison meaningless), and naming a boundary this project has never published. Being *ahead* of the newest listed revision is not reported: a deployment can legitimately be pinned to a revision a listing has not caught up with, and a page that cried about that would train people to ignore it. The comparison refuses to run at all unless all four reads answered — a drift list built where one read failed would report artifacts as unbounded because a request timed out. The Console's artifact model had been dropping the three pins on decode, so they were added there first. It compares and does not enforce: narrowing what an artifact may do is still a deployment.
- A citadel_platform/lib/src/app/platform_boundary_drift.dart
- A citadel_platform/test/platform_boundary_drift_test.dart
- M citadel_platform/lib/src/app/platform_exigence_api.dart
- M citadel_platform/lib/src/app/platform_palisade_pages.dart
