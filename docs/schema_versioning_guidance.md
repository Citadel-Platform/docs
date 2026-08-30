# Schema Versioning Guidance

## Scope

Feature `0.4.4` keeps product schemas versioned and migration-friendly.

## Rules

- Every schema carries an explicit version string such as `v1`.
- Default compatibility mode is additive-only.
- Breaking changes require a new version and an explicit migration path.
- Version identifiers should be stable across CLI, SDK, and API surfaces.

## Current schema set

- `arm.case_payload`
  - status: active
  - version: `v1`
- `conduit.events.batch_write`
  - status: preview
  - version: `v1`
- `exigence.tool_definition`
  - status: preview
  - version: `v1`
- `baker.stack_spec`
  - status: deferred
  - version: `v1`

## Deferred note

Baker does not introduce a broad stack-spec schema. Its component kits, recipes, context packs, and codebase installed-version records use the same additive versioning discipline when implemented.
