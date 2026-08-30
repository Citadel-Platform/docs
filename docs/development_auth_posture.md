# Development Auth Posture

## Scope

Task `0.2.4` keeps early auth explicit, local/dev-scoped, and reversible while the core contracts and CLI workflows stabilize.

## Current development mode

The canonical dev auth contract is `DevSessionContract` in `citadel_core/platform/api`.

Current baseline:

- mode: `localBypass`
- actor: `ops@citadel.internal`
- allowed projects:
  - `core-platform`
  - `customer-ops`
- required request headers:
  - `X-Citadel-Dev-Session`
  - `X-Citadel-Project`
- production use: always `false`

## Rules

- Dev sessions are project-scoped.
- Dev sessions never imply production readiness.
- Production auth remains unresolved at the endpoint-implementation layer until Firebase Auth flows and admin/viewer assignment UX are stable.
- Real customer credentials must never be embedded in the session contract or committed to the repo.

## Production direction already chosen

The still-deferred production direction in `DECISIONS_NEEDED.md` is:

- Firebase Auth
- email/password and Google login
- operator-managed project provisioning and access assignment

This direction is recorded, but not yet implemented.

