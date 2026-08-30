# Shared Dart SDK Conventions

## Scope

Feature `0.4.3` defines the baseline surface area expected from Dart client packages that consume Citadel APIs.

## Package shape

Shared Dart client packages should expose:

- client entrypoints
- request/response models
- structured exceptions
- retry hooks

## Dependency posture

- Prefer low-bloat dependencies.
- Current preferred baseline:
  - `args`
  - `freezed_annotation`
- Keep host-app integration explicit rather than hidden behind automatic runtime wiring.

## Exception baseline

Expected exception categories:

- `CitadelApiException`
  - structured server-side API errors
- `CitadelTransportException`
  - network/transport failures before a valid API response exists
- `CitadelDecodeException`
  - response/schema decoding failures

## Firebase note

- Shared protocol and SDK baseline code should not require Firebase at the core layer by default.
- Product packages may document Firebase-specific integration requirements separately when needed, especially for ARM.

