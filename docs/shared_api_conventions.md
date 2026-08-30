# Shared API Conventions

## Scope

Task `0.2.2` defines the first reusable `/v1` API convention set for Citadel Platform. The canonical implementation lives in `citadel_core/platform/api`, and the CLI consumes the same route catalog instead of duplicating the contract.

## Versioning and paths

- All HTTP paths are versioned under `/v1/...`.
- Path templates should be stable and noun-oriented.
- Tenant and project scope should come from authenticated context and registry state, not arbitrary request bodies.
- Early routes may remain local/dev-only until production auth and persistence decisions are finalized.

## Route catalog

Current baseline routes:

- `GET /v1/products`
- `GET /v1/tenants`
- `GET /v1/projects`
- `POST /v1/projects`
- `GET /v1/projects/{projectId}`
- `GET /v1/projects/{projectId}/access`
- `POST /v1/projects/{projectId}/conduit/sessions/search`
- `GET /v1/projects/{projectId}/conduit/sessions/{sessionId}/replay`
- `PATCH /v1/projects/{projectId}/conduit/sessions/{sessionId}/metadata`
- `POST /v1/projects/{projectId}/conduit/heatmaps/query`
- `GET /v1/projects/{projectId}/arm/issues`
- `GET /v1/projects/{projectId}/arm/cases`
- `GET /v1/projects/{projectId}/arm/cases/{caseId}`
- `PATCH /v1/projects/{projectId}/arm/issues/{issueId}/status`
- `PATCH /v1/projects/{projectId}/arm/cases/{caseId}/status`
- `GET /v1/projects/{projectId}/exigence/automations`
- `PATCH /v1/projects/{projectId}/exigence/automations/{definitionId}`
- `GET /v1/projects/{projectId}/exigence/templates`
- `GET /v1/projects/{projectId}/exigence/definitions/{definitionId}`
- `PUT /v1/projects/{projectId}/exigence/definitions/{definitionId}`
- `GET /v1/projects/{projectId}/exigence/providers`
- `PUT /v1/projects/{projectId}/exigence/providers/{providerId}`
- `GET /v1/projects/{projectId}/exigence/budget`
- `PUT /v1/projects/{projectId}/exigence/budget`
- `GET /v1/projects/{projectId}/exigence/schedules/{definitionId}`
- `PUT /v1/projects/{projectId}/exigence/schedules/{definitionId}`
- `GET /v1/projects/{projectId}/exigence/webhooks/{definitionId}`
- `PUT /v1/projects/{projectId}/exigence/webhooks/{definitionId}`
- `POST /v1/projects/{projectId}/exigence/automations/{definitionId}/runs`
- `GET /v1/projects/{projectId}/exigence/runs/{runId}`
- `POST /v1/projects/{projectId}/exigence/runs/{runId}/cancellation`
- `GET /v1/projects/{projectId}/exigence/approvals`
- `POST /v1/projects/{projectId}/exigence/runs/{runId}/approvals/{approvalId}/resolution`
- `GET /v1/projects/{projectId}/exigence/runs/{runId}/audit-events`
- `GET /v1/projects/{projectId}/offerings`
- `PATCH /v1/projects/{projectId}/offerings/{offering}`
- `GET /v1/audit-events`

These routes are represented as `ApiRouteContract` records in `citadel_core/platform/api`.

## Error shape

Every structured error should expose:

- `code`
- `message`
- `requestId`
- optional `details`
- optional `retryable`

`ApiErrorCode` currently standardizes:

- `invalidArgument`
- `failedPrecondition`
- `unauthenticated`
- `permissionDenied`
- `notFound`
- `alreadyExists`
- `conflict`
- `rateLimited`
- `resourceExhausted`
- `unavailable`
- `internal`
- `unimplemented`

## Pagination

- List endpoints use `pageSize` and `pageToken`.
- `pageSize` defaults to `25` unless a route explicitly documents otherwise.
- Returned page tokens must be opaque and stable for the chosen filter/sort tuple.
- Mutating endpoints never use page tokens.

## Filtering and sorting

- Filtering is explicitly route-scoped through `FilterCapability`.
- Supported filter operators are:
  - `equal`
  - `notEqual`
  - `greaterThan`
  - `greaterThanOrEqual`
  - `lessThan`
  - `lessThanOrEqual`
  - `contains`
  - `inList`
  - `exists`
- Sorting is explicitly route-scoped through `SortCapability`.
- Sort defaults should be documented per route instead of being inferred.

## Idempotency

- Mutating routes that create or patch project state require an `Idempotency-Key` header.
- Dedupe scope is `project + route + key`.
- The initial retention window is `24` hours.
- The same key must replay the same semantic result or fail with a conflict/precondition error if the payload changed.

## Audit behavior

- Mutating administrative actions emit audit events through explicit `AuditRule` records.
- The first baseline actions are:
  - `project.create`
  - `project.offering.update`
- Sensitive request fields must be listed explicitly so raw secrets or customer credentials are never copied into audit payloads.
- `GET /v1/audit-events` is read-only and supports filtering by `projectId`, `offering`, `actorId`, and `createdAt`.

## Authentication posture

- Registry administration routes currently use `devSession`.
- Browser-facing product proxy routes use `firebaseUser`; their authorizers are
  injected and fail closed until production Firebase verification is composed.
- Product services are private server-to-server dependencies. The production
  client will use Cloud Run IAM/OIDC and will not forward browser tokens or SDK
  keys.
- `POST /v1/projects` and `PATCH /v1/projects/{projectId}/offerings/{offering}` remain local/dev-only for now.
- Production auth stays deferred until Firebase Auth, project-admin assignment, and persistence flows are fully stabilized.
