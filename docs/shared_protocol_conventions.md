# Shared Protocol Conventions

## Scope

Feature `0.4` standardizes transport, retry, and payload-shape conventions beyond the initial `/v1` route catalog. The canonical contracts live in `citadel_core/platform/api` under `platform_protocol_models.dart`.

## JSON and wire encoding

- Content type: `application/json; charset=utf-8`
- Date/time encoding: UTC ISO 8601 strings
- Enum encoding: lower camel case wire values by default
- Null fields should be omitted unless a route explicitly requires them

## Rate limiting and retries

- Rate-limit responses use HTTP `429`
- Retry guidance is communicated with:
  - `Retry-After`
  - `X-RateLimit-Remaining`
  - `X-RateLimit-Reset`
- SDK retries are allowed only for idempotent requests by default
- Initial retryable codes:
  - `rateLimited`
  - `resourceExhausted`
  - `unavailable`
- Default retry profile:
  - max attempts: `3`
  - base backoff: `200ms`

## Auth placeholders

- Development mode: `devSession`
- Future production modes already modeled:
  - `firebaseUser`
  - `serviceAccount`
- Production auth remains deferred even though the direction is Firebase Auth.

