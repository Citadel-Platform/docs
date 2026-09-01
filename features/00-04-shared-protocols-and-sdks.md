# Feature 0.4 — Shared Protocols and SDK Conventions

## Scope
Standardize communication contracts and SDK ergonomics across ARM, Conduit, Exigence, and Baker, with `citadel_cli` acting as the first developer-facing consumer of those contracts.

## Tasks

### Task 0.4.1 — HTTP contract standards
- Define JSON encoding, date/time, enum, error, pagination, and idempotency conventions.
- Define request authentication placeholders for dev mode and future production mode.
- Define rate-limit and retry response conventions.

### Task 0.4.2 — Streaming conventions
- Use Server-Sent Events for one-way progress/token streams.
- Use WebSocket only for bidirectional live sessions.
- Define event envelope fields: `eventId`, `eventType`, `createdAt`, `projectId`, `payload`, and `trace`.
- Runner commands use HTTPS long-polling with stable command IDs, monotonic
  sequences, acknowledgements, and at-least-once replay. WebSocket frames are
  a non-durable interactive overlay and reconnect cannot rely on instance
  affinity.

### Task 0.4.3 — Dart SDK baseline
- Define common Dart package patterns for clients, request models, exceptions, and retry hooks.
- Use low-bloat dependencies and keep host-app integration explicit.
- Document package-specific Firebase requirements where applicable.

### Task 0.4.4 — Schema validation
- Add schema validation for Baker specs, Conduit events, Exigence tools, and ARM case payloads where useful.
- Keep schemas versioned and migration-friendly.

## Definition of done
Reviewed 30/08/26 against the tree.

- [x] Protocol conventions are documented —
      `_dev/docs/shared_protocol_conventions.md`.
- [x] Dart SDK conventions are documented —
      `_dev/docs/shared_sdk_conventions.md`.
- [x] Streaming event envelope is documented —
      `_dev/docs/shared_streaming_conventions.md`.
- [x] Product schemas have versioning guidance —
      `_dev/docs/schema_versioning_guidance.md`.
