# Shared Domain Model

## Scope

Task 0.2.1 establishes storage-agnostic shared contracts for the first platform substrate slice. These contracts now live in the importable non-UI package `citadel_core/platform/contracts`, not in `citadel_platform/lib`.

## Modeling rules

- Models stay storage-agnostic for now; no Firestore, REST, or protobuf serialization annotations are added in this slice.
- Tenant and project scoping is explicit on every non-global record.
- Product-specific scope remains attached to the shared `Project` model through `ProjectOfferingScope`.
- Product access state remains explicit through `OfferingEntitlement` instead of being inferred from project config alone.
- The platform web app may import and render these models, but it must not be their long-term source of truth.

## Entities

### `Tenant`

- Identity: `id`, `slug`, `displayName`
- Lifecycle: `status`, `createdAt`, `updatedAt`
- Business context: `legalName`, `primaryOwnerUserId`, `defaultRegion`
- Product posture: `activeOfferings`

### `Project`

- Identity: `id`, `tenantId`, `slug`, `displayName`
- Lifecycle: `status`, `environment`, `createdAt`, `updatedAt`
- Optional infra metadata: `region`, `gcpProjectId`, `firebaseProjectId`
- Optional description: `description`
- Product scope: `offeringScope`

### `ProjectOfferingScope`

- `arm`: `enabled`, `monitoredEnvironment`, `consoleProjectId`
- `conduit`: `enabled`, `datasetId`, `warehouseProjectId`
- `exigence`: `enabled`, `workspaceId`, `runtimeProfile`
- `baker`: `enabled`, `workspaceId`, `internalOnly`

### `PlatformUser`

- Identity: `id`, `tenantId`, `email`, `displayName`
- Lifecycle: `status`, `createdAt`, `updatedAt`, `lastActiveAt`
- Access posture: `tenantRoles`, `projectRoles`

### `ServiceAccount`

- Identity: `id`, `tenantId`, `displayName`
- Scope: optional `projectId`, optional `offering`, `scopes`
- Lifecycle: `status`, `createdAt`, `updatedAt`, `lastRotatedAt`
- Description: `description`

### `ApiKey`

- Identity: `id`, `tenantId`, `serviceAccountId`, `label`, `keyPrefix`
- Scope: optional `projectId`, `scopes`
- Lifecycle: `status`, `createdAt`, `expiresAt`, `lastUsedAt`

### `OfferingEntitlement`

- Identity: `id`, `tenantId`, `offering`
- Scope: optional `projectId`
- Commercial state: `state`, `planCode`, `grantedAt`, `expiresAt`
- Feature posture: `enabledCapabilities`, `usageLimits`

### `AuditEvent`

- Identity: `id`, `tenantId`, `requestId`
- Scope: optional `projectId`, optional `offering`
- Actor context: `actorType`, `actorId`
- Target context: `targetType`, `targetId`
- Event body: `action`, `summary`, `details`, `createdAt`

## Notes for next tasks

- API and error conventions can now reference these entity names directly in Task 0.2.2.
- Firestore field names and serializer shape should be deferred until Task 0.2.3 stabilizes the shared project registry contract.
- UI surfaces such as `citadel_platform` should continue importing these contracts from `citadel_core/platform/contracts` and avoid re-declaring product models locally.
