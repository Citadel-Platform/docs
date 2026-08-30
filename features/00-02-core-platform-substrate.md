# Feature 0.2 — Core Platform Substrate

## Scope
Establish shared Citadel Platform foundations before product-specific work: tenancy, project registry, API conventions, data boundaries, and common service layout. `citadel_core` owns reusable schemas, middleware, logic, SDKs, and endpoint contracts. `citadel_cli` is the first non-UI consumer. `citadel_platform/lib` is a UI-only surface.

## Tasks

### Task 0.2.1 — Shared domain model
- Define `Tenant`, `Project`, `User`, `ServiceAccount`, `ApiKey`, `OfferingEntitlement`, `AuditEvent`, and `ManifoldChannel` models.
- Keep the models storage-agnostic first; add Firestore serialization only after field names stabilize.
- Include product scope fields for ARM, Conduit, Exigence, Baker, and Manifold.
- Make `citadel_core` the canonical home for these contracts, not `citadel_platform/lib`.

### Task 0.2.2 — API and error conventions
- Define versioned REST path conventions under `/v1`.
- Define structured error shape: `code`, `message`, `requestId`, and optional `details`.
- Define pagination, idempotency, filtering, and audit-event conventions.
- Document which endpoints are local/dev only until production auth is added.
- Keep API contracts importable from non-UI code so future surfaces such as CLI tooling can reuse them directly.

### Task 0.2.3 — Project registry contract
- Define the shared project registry used by the central console and product consoles.
- Include product entitlement state, Firebase/GCP project metadata, display name, environment, and connection status.
- Avoid storing secrets in registry documents.

### Task 0.2.4 — Development auth posture
- Add local/dev session mechanics only where needed for UI and API iteration.
- Do not add real production auth until user approves identity-provider decisions.
- Record any auth assumptions in `DECISIONS_NEEDED.md`.

## Definition of done
- [ ] Core domain contracts are documented
- [ ] API conventions are documented
- [ ] Project registry shape is documented
- [ ] Production auth decisions remain explicit and unresolved until approved
