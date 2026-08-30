# Platform API Proxy

## Purpose

Citadel Console browsers must not access customer Firestore or Storage data
directly once the server-only customer rules baseline is deployed. The central
Platform API is the single browser-facing boundary for ARM, Conduit, and
Exigence operator workflows.

## Request path

1. The Console sends a Firebase ID token to a project-scoped Platform API route.
2. An injected Platform authorizer verifies the token and resolves the exact
   actor, project, and project roles. Missing or failed authorization denies the
   request.
3. The Platform handler validates and bounds the request, then creates a private
   product request containing only trusted actor context and the Platform
   request ID. Browser authorization headers and SDK keys are not forwarded.
4. An injected product client calls the private Cloud Run product service. Its
   production implementation will use the Platform runtime service account and
   an audience-bound Google-issued OIDC token. For Exigence approval
   resolution, it sets `X-Citadel-Actor-Id` only from the trusted typed request
   actor and never forwards the browser's actor header.
5. Bounded JSON 2xx and 4xx product responses may return to the Console. Private
   5xx payloads and malformed responses become generic Platform errors.

The product service remains responsible for reading or mutating data in the
customer project through the onboarding service account grants. Customer data
does not move into the Citadel control project merely because the request passes
through the central API.

## Current implementation

`citadel_core/platform/server` implements the fail-closed handler and injected
authorization/product-client contracts. Current routes are:

```text
POST /v1/projects/{projectId}/conduit/sessions/search
GET /v1/projects/{projectId}/conduit/sessions/{sessionId}/replay
PATCH /v1/projects/{projectId}/conduit/sessions/{sessionId}/metadata
POST /v1/projects/{projectId}/conduit/heatmaps/query
GET /v1/projects/{projectId}/arm/issues
GET /v1/projects/{projectId}/arm/cases
GET /v1/projects/{projectId}/arm/cases/{caseId}
PATCH /v1/projects/{projectId}/arm/issues/{issueId}/status
PATCH /v1/projects/{projectId}/arm/cases/{caseId}/status
GET /v1/projects/{projectId}/exigence/automations
PATCH /v1/projects/{projectId}/exigence/automations/{definitionId}
GET /v1/projects/{projectId}/exigence/templates
GET /v1/projects/{projectId}/exigence/definitions/{definitionId}
PUT /v1/projects/{projectId}/exigence/definitions/{definitionId}
GET /v1/projects/{projectId}/exigence/providers
PUT /v1/projects/{projectId}/exigence/providers/{providerId}
GET /v1/projects/{projectId}/exigence/budget
PUT /v1/projects/{projectId}/exigence/budget
GET /v1/projects/{projectId}/exigence/schedules/{definitionId}
PUT /v1/projects/{projectId}/exigence/schedules/{definitionId}
GET /v1/projects/{projectId}/exigence/webhooks/{definitionId}
PUT /v1/projects/{projectId}/exigence/webhooks/{definitionId}
GET /v1/projects/{projectId}/exigence/runs/{runId}
POST /v1/projects/{projectId}/exigence/runs/{runId}/cancellation
GET /v1/projects/{projectId}/exigence/approvals
POST /v1/projects/{projectId}/exigence/runs/{runId}/approvals/{approvalId}/resolution
GET /v1/projects/{projectId}/exigence/runs/{runId}/audit-events
POST /v1/projects/{projectId}/exigence/automations/{definitionId}/runs
```

It maps to the private Conduit route `POST /v1/sessions/search` only after exact
project authorization. The public Conduit SDK key remains valid only for SDK
ingest/configuration routes and cannot authorize this query.

## Deployed runtime

The runtime adapters are implemented and live in `citadel-platform`.

```text
citadel-platform-api      public Cloud Run   https://citadel-platform-api-3dnspttzga-uc.a.run.app
citadel-arm-evidence      private Cloud Run  https://citadel-arm-evidence-3dnspttzga-uc.a.run.app
```

`citadel_core/platform/server` supplies the concrete adapters:

- `GoogleJwksTokenVerifier` verifies RS256 Firebase ID tokens against the
  published `securetoken@system` key set, and Google OIDC identity tokens
  against `oauth2/v3/certs`. Firebase tokens carry a per-project issuer, so
  Google's `tokeninfo` endpoint cannot validate them.
- `createFirestoreProjectRoleResolver` resolves roles from `platform_access`
  keyed on the verified email, and refuses projects that are not active or do
  not have the requested offering enabled.
- `OidcPlatformProductProxyClient` calls the private service with an identity
  token minted by the metadata server for the service's declared Cloud Run
  custom audience, forwarding only the trusted actor and request ID.
- `platformConsoleCors` admits exactly the configured Console origins.

The private ARM evidence service is bounded by IAM: only
`citadel-platform-api@citadel-platform.iam.gserviceaccount.com` holds
`roles/run.invoker`, and the service re-verifies the caller's identity token.
Internal-only ingress is not used because it also rejects the Platform API,
whose egress leaves over the internet.

Terraform owns every resource in `citadel_core/platform/infra`. The customer
boundary grant lives in a separate root per customer, at state prefix
`customers/{projectId}/iam`.

The Flutter Console reads the deployed base URL from the compile-time
`CITADEL_PLATFORM_API_BASE_URL` definition. ARM workspace/status operations and
privileged Conduit search, exact cohorts, replay, metadata, and heatmap
operations fail with an explicit configuration error when it is absent instead
of falling back to customer Firestore.

## Response bounds

Platform API responses are capped at 1 MiB. ARM case records carry full stack
traces, breadcrumbs, and recovery snapshots and run to roughly 100 KB each, so
the Console requests five cases per page rather than the protocol maximum of
100. Issue records are small and still use the maximum page size.

Serving list pages as summaries, with full evidence only from the case detail
route, would remove that asymmetry. It is not implemented: the page contract
requires complete `ArmCaseRecord` values.
