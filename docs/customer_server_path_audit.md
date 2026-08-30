# Customer server-path audit

## Purpose

Feature 0.7 will eventually deploy Firebase Rules that deny all customer-data
client access. This audit records the active Platform console paths that would
break under that policy and the server work required before deployment. Central
Citadel registry, access, configuration, source-map, survey-deployment, and
alert-control documents are outside this audit because they are Citadel control
data in the Citadel project, not customer evidence.

## ARM direct paths

The Platform console still creates a secondary Firebase web app for each
customer and obtains a client Firestore instance in
`citadel_platform/lib/src/app/platform_firestore.dart:259`-273.

- Issue and case status mutations directly update `armIssues/{issueId}` and
  `armCases/{caseId}` at lines 276-310. The replacement needs authenticated,
  project-scoped server commands that preserve operator identity, server
  timestamps, status validation, and audit evidence.
- Connection validation signs the browser into the target Firebase project and
  probes `armIssues` and `armCases` at lines 852-1042. The replacement should be
  a server readiness endpoint; target Firebase client authentication and web
  config must not be prerequisites for the console.
- The live ARM workspace subscribes directly to complete `armIssues` and
  `armCases` snapshots at lines 1045-1116. The replacement needs bounded,
  project-authorized issue/case list or stream endpoints with explicit paging
  and filtering before the direct listeners can be removed.

The reusable ARM server SDK already writes evidence with service-account auth,
but it is an application capture library rather than a console query service.
No current server route covers the three console behaviors above.

## Conduit direct paths

`FirestorePlatformConduitRepository` loads customer Firestore directly for all
customer analytics and replay data. The direct entry points are in
`citadel_platform/lib/src/app/platform_conduit_repository.dart`:

- Session search at lines 345-417.
- Voice-of-Customer feedback, poll, survey, and presentation-event reads at
  lines 420-622.
- Session replay reads at lines 623-689.
- Session tag/star/note mutation at lines 690-725.
- Heatmap event/surface reads at lines 726-808.
- Web analytics at lines 809-911.
- Journey analysis at lines 912-976.
- Funnel definition reads/mutation and funnel analysis at lines 977-1058.
- Experience analytics at lines 1059-1138.
- Synthetic-monitoring result reads at lines 1139-1189.

The Conduit ingest service already has server implementations for session
search, replay retrieval, session metadata update, and heatmap query. It does
not yet expose server query routes for Voice of Customer, analytics, journeys,
funnels, experience, or synthetic monitoring.

## Authorization finding

The existing privileged Conduit query routes used the same `X-Conduit-Key` as
public SDK ingest. That key is necessarily shipped to monitored browsers, so it
cannot authorize session search, replay reads, or operator mutations. Wiring the
console directly to those routes would expose customer evidence.

Conduit now fails these routes closed unless the host injects a
`ConduitOperatorRequestAuthorizer`:

- `POST /v1/sessions/search`
- `GET /v1/sessions/{sessionId}/replay`
- `PATCH /v1/sessions/{sessionId}/metadata`
- `POST /v1/heatmaps/query`

Public SDK ingest, config, replay capture, heatmap capture, and Voice-of-Customer
submission routes retain their existing project-key behavior. The authorizer is
only a safe extension point; no production identity implementation has been
invented.

## Migration order

1. Settle the operator-query topology and implement its real authorizer.
2. Move Platform session search, replay, metadata update, and heatmap query to
   the already available server routes, then remove those direct Firestore
   methods.
3. Add bounded server endpoints for remaining Conduit analytics, migrating one
   complete console surface at a time.
4. Define and implement the ARM query/command service, then remove target
   Firebase app creation, target client auth, direct listeners, and mutations.
5. Re-run this audit with static checks proving no customer-data Firestore or
   Storage client path remains before enabling Rules deployment.

Firebase Rules deployment remains blocked until steps 2-4 are complete. The
current work changes no customer IAM policy, Rules release, or Firebase data.
