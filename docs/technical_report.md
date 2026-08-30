# Citadel Platform Technical Report Plan

## 1. Purpose and scope

Citadel Platform consolidates repeated business-application infrastructure into one coherent product suite. The repository is now split into three top-level packages:

1. **Citadel Core** — reusable schemas, middleware, SDKs, business logic, and endpoint contracts. This contains the product modules for ARM, Conduit, Exigence, Baker, and Manifold.
2. **Citadel CLI** — a developer-facing interface for rapid testing, inspection, and exercising platform capabilities without depending on the UI.
3. **Citadel Platform** — the Google Cloud Platform-style user-facing web interface and console that composes capabilities exposed by the core packages.

The reusable contracts remain in `citadel_core`, but every supported project resource and operation must converge on the Platform Console. `citadel_cli` provides operator parity, diagnostics, and automation; it is not a prerequisite for exposing an otherwise-supported operation in the Console.

## 2. Architecture principles

- **Shared core first**: common identity, tenancy, APIs, observability, infrastructure, and design-system primitives must be stable before product-specific polish.
- **Shared mechanism, complete Console**: domain logic stays in `citadel_core`, while `citadel_platform` exposes the complete supported project state and operations through those shared APIs.
- **UI shell only in `citadel_platform`**: `citadel_platform/lib` should compose and present product capabilities, not own domain schemas, middleware, service logic, or endpoint contracts.
- **Registry authority, Console ground truth**: the Platform API and registry persist authoritative state; the Console is the complete operator control and observation plane over that state and reconciled live resources. No supported setup step may exist only in a notebook or shell script.
- **Product-specific UIs, shared platform substrate**: the visible interface can differ by offering, but access control, billing metadata, event capture, project registry, and deployment mechanics should be reused.
- **Tenant-local data by default**: customer telemetry and operational records remain scoped to the customer's project or tenant data boundary unless a deliberate cross-tenant aggregation path is approved.
- **Shared platform Firebase, external ARM telemetry**: platform-owned auth, permissions, registry, and internal tool metadata live in the shared `citadel-platform` Firebase project, while ARM evidence for monitored client apps remains in those clients' own Firebase projects.
- **Baker stays internal-first**: when resumed, Baker starts as a superdev-only accelerator with Factory and Devstation before any broader authoring surface.
- **No real auth too early**: early implementation can use local/dev bypasses and scoped preview sessions until product flows are stable; production auth is added deliberately after core feature behavior is validated.
- **Evidence-preserving monitoring**: ARM should capture enough diagnostic context to recover and investigate issues, while keeping runtime overhead low and avoiding unnecessary application bloat.
- **Infrastructure as code**: when infrastructure work resumes, cloud resources should be defined through Terraform. Direct resource creation commands are avoided except for read-only checks or scripted, reviewed helper flows where Terraform cannot reasonably express the action.
- **Generated artifacts stay out of source**: generated code, build output, SDK stubs, and derived files remain ignored.

## 3. Shared platform core

### 3.1 Monorepo and package layout

Target layout:

```text
CitadelPlatform/
├── citadel_core/            Reusable non-UI packages and product modules
│   ├── arm/                 ARM SDKs, preserved console reference, and module logic
│   ├── conduit/             Conduit-owned schemas, ingestion/reporting logic, and endpoints
│   ├── exigence/            Exigence-owned schemas, automation logic, endpoints, and SDKs
│   ├── baker/               Factory assets, version records, and Devstation lifecycle
│   └── manifold/            Omnichannel conversations, connectors, and delivery
├── citadel_cli/             Developer-facing CLI for rapid testing and platform operations
├── citadel_platform/        Flutter web app for the platform console and public website UI only
├── infra/                   Terraform environments and reusable modules (deferred for now)
├── proto/                   Shared protobuf definitions when binary/gRPC contracts are needed
├── scripts/                 Utility scripts only; no inline resource creation shortcuts
└── _dev/                    planning docs, feature files, session log, and test status
```

The current repository does not yet contain every target directory. The first implementation slices should create only the directories needed by the active feature to avoid empty architectural ballast. If multiple products need the same contract, that contract should still live in an importable non-UI package under `citadel_core`, not `citadel_platform/lib`.

### 3.2 Shared identity and tenancy

The platform should model:

- **Tenant**: a business or internal workspace that owns projects, users, product subscriptions, data boundaries, and billing metadata.
- **Project**: a deployable or monitored unit. ARM evidence, Conduit analytics, Exigence artifacts, Manifold conversations, and Baker assets/Devstations attach to projects.
- **User**: a human actor with tenant and project roles.
- **Service account / API key**: a non-human actor for SDK ingestion, backend integrations, automation execution, and deployment pipelines.
- **Offering entitlement**: product access state for ARM, Conduit, Exigence, Manifold, and Baker.

These contracts should be implemented in importable non-UI packages under `citadel_core`, not inside the platform web app layer. Initial development can use local/dev sessions and explicit project configuration. Production identity remains an open architecture decision until the first stable platform console flow is ready.

### 3.3 Shared API conventions

All HTTP APIs should follow one convention set:

- Versioned paths: `/v1/...`.
- Tenant/project scoping through authenticated context, not arbitrary request bodies.
- JSON request/response bodies for console and SDK control flows.
- Streaming protocols only when needed for live telemetry, logs, agent events, or long-running AI output.
- Idempotency keys for ingestion, automation triggers, and generation/deployment jobs.
- Structured errors with `code`, `message`, `requestId`, and optional `details`.
- Stable pagination via `pageToken` and `pageSize` for console listings.
- Audit events for mutating administrative actions.

The platform UI may call these APIs and render their results, but the API contracts themselves belong in importable non-UI module code.

### 3.4 Communication protocols

- **Client SDK to storage**: ARM currently supports direct Firestore/Storage writes through `FirebaseArmSink`. Keep this mode because it avoids a mandatory intake server.
- **Platform-owned Firebase context**: core products share `citadel-platform` for platform-owned auth, registry, and internal metadata.
- **Client SDK to API gateway**: add later when a product needs central validation, multi-sink fanout, rate limits, or non-Firebase backends.
- **Console to platform API**: REST/JSON for registry, entitlements, access, and product-level metadata.
- **Console to monitored project data**: ARM console can read project-local Firestore/Storage in external client-owned Firebase projects via project registry configuration and role checks.
- **AI streaming**: Exigence should use Server-Sent Events for token streams and WebSocket only when bidirectional interaction is required.
- **Runner data handling**: Palisade resolves every resource to no access,
  in-situ processing, Citadel-only relay, or allowlisted third-party relay.
  Durable commands use HTTPS long-polling; WebSocket is an optional live overlay
  for browser/computer use, never a machine-wide policy bypass.
- **Metrics ingestion**: Conduit should start with HTTP batch ingestion and support streaming/export connectors after the data model stabilizes.
- **Factory assets**: Baker component kits, recipes, and context packs carry simple versions; each generated codebase records the versions used to bootstrap it.

### 3.5 Shared data stack

Initial platform data stores:

- **Firestore in `citadel-platform`**: console registry, tenant/project metadata, auth/access assignments, and lightweight internal product state.
- **External client Firestore**: ARM issue/case data for monitored Firebase-backed client apps.
- **Firebase Storage / Cloud Storage**: screenshots, binary evidence, report exports, generated artifacts, deployment bundles.
- **BigQuery**: Conduit analytics warehouse, cross-product usage analytics, long-range reporting, ARM aggregate rollups when needed.
- **Pub/Sub**: asynchronous ingestion fanout, usage events, report generation jobs, AI automation event triggers.
- **Cloud Run**: HTTP APIs, ingestion services, report workers, AI orchestration services.
- **Secret Manager**: provider keys, service credentials, webhook secrets, and deploy-time sensitive config.
- **Terraform state**: environment-specific infrastructure modules and resource lifecycle.

### 3.6 Shared infrastructure

The first infrastructure baseline should include:

- GCP project `citadel-platform`.
- Firebase project `citadel-platform` for platform-owned core-tool data.
- Region `us-central1` and zone `us-central1-a` unless a feature has a documented reason to differ.
- Terraform modules for Firebase/Firestore, Cloud Run, Pub/Sub, BigQuery, Storage, IAM, Secret Manager, and hosting.
- Per-environment variables for dev/staging/prod.
- Artifact Registry for container images if Go/worker services are added.
- CI checks for Flutter, Dart, Go, Terraform, and generated contract validation as each stack appears.

### 3.7 Shared observability

All platform services should emit:

- request logs with `requestId`, `tenantId`, `projectId`, `actorId`, `offering`, and `route` where available;
- structured domain events for administrative changes and ingestion outcomes;
- product-level health metrics;
- error events routed into ARM where appropriate;
- cost and usage telemetry for product-level reporting.

ARM should become the first internal consumer of this observability layer after its reference code is consolidated.

### 3.8 Shared web interface system

The platform console should use Material 3, responsive layouts, and Google Cloud Platform-like navigation:

- global top bar with project selector, search, notifications, help, and user/session menu;
- left navigation rail/drawer for products and product sections;
- landing dashboard with product cards, incidents, metrics, shortcuts, and setup status;
- consistent tables, filters, detail pages, empty states, warnings, and form flows;
- offering-specific pages mounted under a shared shell.

The existing ARM Console shell is a strong reference for this visual and interaction style and should be reused where possible. The shell should import product logic rather than embedding it directly in `citadel_platform/lib`.

## 4. Product plan: ARM

### 4.1 Current reference state

The reference ARM implementation contains two mature pieces:

- `ARM_Tooling`: a Flutter package named `arm_tooling` with `ArmClient`, `ArmBootstrap`, `FirebaseArmSink`, screenshot capture boundary, fingerprinting, typed severity, breadcrumbs, recovery snapshots, and Firestore/Storage persistence.
- `ARM_Console`: a Flutter web app with Material 3 shell, routing, Firebase auth/bootstrap, project registry, project switcher, overview, issue/case explorer, reports, case details, and monitored-project access patterns.

The first ARM task is consolidation, not reinvention. The code should be copied into `citadel_core/arm/tooling` and `citadel_core/arm/console`, excluding `.git`, build output, Dart tool output, IDE state, and generated plugin metadata. Package internals should be kept intact unless a later Citadel integration task requires explicit changes.

### 4.2 ARM SDK/API

ARM SDK responsibilities:

- initialize monitoring through `ArmBootstrap.runGuarded`;
- capture Flutter framework, dispatcher, zone, handled, and tracked-operation errors;
- keep bounded breadcrumb history;
- construct deterministic fingerprints;
- record issue summaries and per-case evidence;
- attach recovery snapshots and optional screenshots;
- expose case IDs for moderate-or-higher severity incidents;
- support Firestore-only mode when Storage is unavailable.

ARM storage/API responsibilities:

- `armIssues/{issueId}` stores deduplicated issue summaries in the monitored client's own Firebase project;
- `armCases/{caseId}` stores full case evidence in the monitored client's own Firebase project;
- Storage paths store screenshots and binary evidence under case/issue prefixes in the monitored client's own storage boundary;
- future intake API can provide centralized validation, rate limiting, routing, and non-Firebase sinks without removing direct Firebase mode.

### 4.3 ARM web interface

ARM Console responsibilities:

- central triage overview;
- issue fingerprint listing and filtering;
- case listing and detail views;
- reports and severity trends;
- project registry and monitored-project validation;
- scoped developer/viewer/superuser access;
- screenshot, snapshot, breadcrumb, stack trace, and context inspection;
- read-only evidence posture unless a deliberate recovery workflow is added.
- platform-owned auth, permissions, and project registry in `citadel-platform`;
- read access into external client-owned telemetry projects through registered project configuration.

### 4.4 ARM implementation sequence

1. Consolidate and preserve the reference code under `citadel_core/arm/tooling` and `citadel_core/arm/console`.
2. Verify Flutter package and console analysis separately.
3. Add Citadel-facing documentation and local run scripts.
4. Stabilize monitored-project registry and Firebase setup docs.
5. Add ARM internal self-monitoring for Citadel services.
6. Add aggregate reporting and optional intake gateway only after direct Firestore mode is stable.

## 5. Product plan: Citadel CLI

### 5.1 Purpose

Citadel CLI is the first developer-facing consumer of `citadel_core`. It should make it easy to exercise APIs, inspect contracts, trigger workflows, and validate system behavior before the main platform UI is built out.

### 5.2 Responsibilities

- inspect tenants, projects, offerings, and environment state;
- trigger and validate core API flows without UI work;
- provide fast local testing hooks for ARM, Conduit, Exigence, and Baker;
- surface structured errors and audit context exactly as the core packages expose them.

### 5.3 Delivery posture

The CLI should be developed before major `citadel_platform` UI work so the reusable contracts are forced to serve a non-UI consumer first.

## 6. Product plan: Citadel Platform Console and website

### 6.1 Purpose

The Citadel Platform website is the central entry point for all offerings. It should feel like Google Cloud Platform: a single shell, shared project selector, product navigation, setup status, docs links, billing/access posture, and product launch cards.

### 6.2 Web interface

Core pages:

- public landing page for Citadel Platform;
- signed-in console home;
- tenant/project selector;
- products directory;
- ARM launch and project setup;
- Conduit launch and dataset setup;
- Exigence launch and automation setup;
- Baker internal workspace entry;
- IAM/access settings;
- billing/usage placeholder;
- support and docs.

### 6.3 API surface

Initial platform API:

- `GET /v1/products`
- `GET /v1/tenants`
- `GET /v1/projects`
- `POST /v1/projects`
- `GET /v1/projects/{projectId}/offerings`
- `PATCH /v1/projects/{projectId}/offerings/{offering}`
- `GET /v1/audit-events`

Production auth remains deferred until UI and product flows stabilize. The platform UI should import these contracts from `citadel_core` rather than re-declaring them locally.

## 6. Product plan: Conduit

### 6.1 Purpose

Conduit is the metrics, analytics, and reporting product line. It should ingest events and metrics from business systems, application telemetry, and product workflows; store them in a queryable warehouse; and present actionable reports from the central Citadel console.

### 6.2 SDK/API

Initial Conduit API:

- `POST /v1/conduit/events:batchWrite`
- `POST /v1/conduit/metrics:batchWrite`
- `GET /v1/conduit/datasets`
- `POST /v1/conduit/datasets`
- `GET /v1/conduit/reports`
- `POST /v1/conduit/reports:run`
- `GET /v1/conduit/exports/{exportId}`

Initial SDKs:

- Dart client for Flutter/web apps;
- HTTP ingestion contract for backend systems;
- optional lightweight JavaScript snippet after schema and auth are stable.

### 6.3 Data stack

- Pub/Sub for ingestion fanout.
- BigQuery for warehouse tables and derived marts.
- Firestore for report definitions, dashboard layout, and lightweight dataset metadata.
- Cloud Storage for exported CSV/PDF/report artifacts.

### 6.4 Web interface

Conduit console pages:

- datasets;
- ingestion health;
- metrics explorer;
- dashboards;
- reports;
- exports;
- schema configuration;
- alert rules.

## 7. Product plan: Exigence

### 7.1 Purpose

Exigence provides AI tools and services for businesses, ranging from small automations to long-horizon agents and coordinated swarms.
The operator-facing Console must expose the full Exigence operating surface: runs, approvals, artifacts, cost, audit, and any guided manual steps the runtime still needs.

### 7.2 SDK/API

Initial Exigence API:

- `POST /v1/exigence/automations`
- `GET /v1/exigence/automations`
- `POST /v1/exigence/automations/{id}:run`
- `GET /v1/exigence/runs/{runId}`
- `GET /v1/exigence/runs/{runId}/events`
- `POST /v1/exigence/tools`
- `GET /v1/exigence/tool-invocations`

Initial SDKs:

- Dart package for defining automation triggers and consuming run streams;
- HTTP API for backend integrations;
- future typed tool adapters after tool schema standards are fixed.
- local runner transport with per-resource Data Handling policy, durable HTTPS
  command replay, and an optional live WebSocket overlay.

### 7.3 Runtime

- Cloud Run workers for orchestration.
- Pub/Sub for event triggers and run queueing.
- Firestore for run metadata and event timelines.
- Cloud Storage for artifacts.
- Secret Manager for model/provider credentials.
- Optional BigQuery export for run analytics.

### 7.4 Web interface

Exigence console pages:

- automation builder;
- run history;
- run timeline;
- tool registry;
- knowledge/artifact library;
- approvals and human-in-the-loop queue;
- cost/latency/error reporting.

Model provider choices, approval policies, and customer data boundaries need explicit product decisions before production implementation.

## 8. Product plan: Baker

### 8.1 Purpose

Baker is a superdev-only accelerator for taking a project from zero to its initial CRM MVP. Its first implementation slice is Factory: component kits, recipes, a context pack, and basic version records showing which asset versions a codebase used. Devstation is the adjacent per-client development VM surface. Manifests, boundary models, upgrade engines, and broad stack designers are explicitly out of scope.

### 8.2 Assets/API

Factory exposes three deliberately small asset types:

- component kits;
- recipes;
- a context pack;
- installed-version records associated with a codebase.

Initial API:

- `POST /v1/baker/factory`
- `GET /v1/baker/factory/{factoryId}`
- `POST /v1/baker/factory/{factoryId}:validate`
- `GET /v1/baker/devstations/{devstationId}`
- `POST /v1/baker/devstations/{devstationId}:start`
- `POST /v1/baker/devstations/{devstationId}:stop`

### 8.3 Interfaces

- Superdev-only Factory inside the Citadel Platform Console.
- Component kit browser.
- Recipe and context-pack browser.
- Devstation lifecycle controls and session resume controls.
- Integration hooks into ARM, Conduit, Exigence and Manifold escalation.

### 8.4 Generator strategy

Start with deterministic assets and explicit wiring context for a coding agent. The goal is fast initial bootstrapping, not reproducible regeneration, upgrades, or autonomous migration of an established application.

## 9. Release and feature ordering

1. Core planning and monorepo reset.
2. Shared platform contracts, tenancy model, infrastructure baseline, and UI shell primitives.
3. ARM consolidation from reference code.
4. ARM validation, docs, and monitored-project setup.
5. Citadel Platform console and product launch shell.
6. Conduit ingestion, warehouse, and dashboards.
7. Exigence automation runtime, SDK, and console.
8. Manifold omnichannel inbox and escalation bridge.
9. Baker Factory and Devstation.

## 10. Current risks and open decisions

- Production identity provider and tenant bootstrap path are not finalized.
- Conduit's initial analytics grain and retention policy need product decisions.
- Exigence model providers, approval rules, and tool execution boundaries need explicit approval.
- Baker's Factory scope must stay narrow so the first resumed slice stays useful and does not collapse into a full platform builder.
- ARM direct-Firebase mode is proven, but any central intake gateway must be justified by concrete needs.
