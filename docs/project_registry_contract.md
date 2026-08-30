# Project Registry Contract

## Scope

Task `0.2.3` defines the shared project registry used by the central console, CLI, and product-specific consoles. The canonical contract lives in `citadel_core/platform/api` as `ProjectRegistryEntry`.

## Core shape

Each registry entry contains:

- `project`: shared `Project` contract from `citadel_platform_contracts`
- `offerings`: `ProjectRegistryOfferingStatus` records for ARM, Conduit, Exigence, Manifold, and Baker
- `platformControlConnection`: health of Citadel-owned auth/registry metadata in `citadel-platform`
- `externalTelemetryConnection`: health of any external customer-owned telemetry boundary
- `externalFirebaseProjectId`: optional customer-owned Firebase project used for telemetry/evidence
- `externalFirebaseStorageBucket`: optional customer-owned Storage bucket used for screenshots/evidence
- `externalEvidenceReadOnly`: must stay `true` by default
- `labels`: low-risk operator metadata only

## Required principles

- Platform-owned auth, permissions, and registry metadata live in the shared `citadel-platform` Firebase project.
- Customer telemetry and evidence remain in customer-owned Firebase projects.
- Registry writes must never mutate `armIssues`, `armCases`, screenshots, or other monitored evidence in external customer projects.
- Secrets are not stored in registry documents.
- Any external-project access instructions should describe required IAM/rules changes, but actual credentials must stay in `.env` for local work or Secret Manager in managed environments.

## Offering posture

`ProjectRegistryOfferingStatus` tracks:

- `offering`
- `entitlementState`
- `enabled`
- `configured`
- optional `setupSummary`

This keeps commercial posture and technical setup posture separate.

## Resource and access routes

- `GET /v1/projects/{projectId}` returns one `ProjectRegistryEntry` directly.
- `GET /v1/projects/{projectId}/access` returns normalized projected and indexed
  developer/viewer email lists as `ProjectAccessSnapshot`.
- `projectionIndexConsistent` is derived from the two returned representations;
  mismatches remain observable drift rather than being repaired by a read.

## Connection posture

`RegistryConnectionStatus` standardizes:

- `health`
- optional `summary`
- optional `checkedAt`

Health values:

- `unknown`
- `healthy`
- `warning`
- `failing`

## Current baseline examples

- `core-platform`
  - uses `citadel-platform` for platform control data
  - has no external customer telemetry boundary attached
- `customer-ops`
  - stores Citadel auth/registry metadata in `citadel-platform`
  - reads ARM evidence from external Firebase project `customer-prod-firebase`
  - keeps evidence access read-only
