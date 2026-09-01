# Feature 3.7 — Experience Monitoring (Performance, Errors, Frustration)

## Status
Active. Depends on Feature 3.2. Coordinates with ARM for alert routing.

## Scope
Build the Experience Monitoring module: Core Web Vitals RUM, JavaScript and API error tracking, frustration signal dashboards, synthetic monitoring probes, and the alerting engine.

## Tasks

### Task 3.7.1 — Core Web Vitals dashboard
- BigQuery aggregation queries for LCP, INP, CLS, TTFB, and FCP: per-page-group and site-wide, computed at P50, P75, and P95 percentiles, sliced by device type and geography.
- Dashboard layout: one card group per CWV metric showing the P75 value, a colour-coded status (good / needs improvement / poor based on Google thresholds), and a trend line.
- Page performance table: all URL patterns ranked by P75 LCP, with P75 INP and P75 CLS columns.
- Click any page row: see the CWV waterfall for that page alongside session replays with poor performance scores.
- Correlation chart: overlay P75 LCP with bounce rate and conversion rate on the same time axis.

### Task 3.7.2 — JavaScript error tracking UI
- Error list: grouped by error message and type; columns for occurrence count, affected session count, affected URL, first seen, last seen, and conversion impact.
- Error detail panel: full stack trace (with source-map-resolved file and line if source maps are uploaded), affected browser and OS breakdown, occurrence trend chart.
- "View sessions with this error" action: opens session list filtered to sessions containing this error, pre-seeking to the error event.
- Source map upload API: `POST /v1/sourcemaps/{projectId}` accepting a multipart upload of `.js.map` files keyed by release version.

### Task 3.7.3 — API error tracking UI
- API error list grouped by endpoint URL pattern and HTTP status code.
- Per-endpoint: error rate (errors / total requests), affected session count, first/last seen, conversion impact.
- "View sessions" action: opens filtered session list.
- Custom API error rule builder in Settings: define endpoint URL patterns and status code ranges to monitor; define custom error names for specific response body conditions.

### Task 3.7.4 — Frustration signals dashboard
- Summary cards for each frustration signal type: rage clicks, dead clicks, scroll bounce, quick exits, u-turns, error clicks — with counts and week-over-week trend.
- Frustration heatmap: a click heatmap filtered to only rage clicks and dead clicks, to spatially locate frustration.
- Top pages by frustration score: composite score combining all signal types, ranked table.
- Frustration signal trend chart: timeline of each signal type.
- Click any signal → filtered session list.

### Task 3.7.5 — Synthetic monitoring
- Deploy a scheduled Cloud Run job (runs every 5 minutes) using Playwright to probe configured URLs.
- Configurable probe list per project: URL, expected HTTP status, optional element-present assertion.
- Probe locations: Singapore (default), US (us-central1), Europe (europe-west1) — one runner per location.
- Store probe results in BigQuery `conduit_synthetic` table: `probe_url`, `location`, `status_code`, `load_time_ms`, `success`, `timestamp`.
- Dashboard widget: uptime percentage per probed URL, P95 load time trend, last-check status badge.
- Alert on: availability failure (non-200 response) or load time exceeding configured threshold.

### Task 3.7.6 — Alerting engine
- Alert rule builder in Console Settings: metric (CWV, error rate, conversion rate, frustration score, uptime), condition (above/below threshold, or anomaly mode), time window, minimum occurrence count to suppress noise.
- Store alert rules in Firestore `conduit_alerts/{projectId}/{alertId}`.
- Alert evaluation: Cloud Run job runs every 5 minutes, evaluates all active alert rules against recent BigQuery data.
- When an alert fires: create an alert event in Firestore, send notification to configured channels (email, Slack webhook), and emit a `conduit.alert.fired` Pub/Sub event (for ARM integration and Exigence).
- Alert history UI: list of past alert events with status (firing, resolved), duration, and linked data.
- ARM integration: route `conduit.alert.fired` events to the ARM event bus so error alerts appear in ARM Console alongside application telemetry.

## Definition of done

Rewritten 31/08/26 against the product that exists — a Flutter/Dart SDK and a
Dart ingest service on Firestore — rather than the web SDK and BigQuery
pipeline these criteria were first written for. The originals are kept below
under **Deferred**, because they are a product decision that was made, not work
that was dropped: the product-owner review of 30/08/26
(`_dev/docs/feature_set_review_30_08_26.md`) settled Conduit as Flutter/Dart
first with analytics infrastructure deferred.

- [x] Performance percentiles are computed and sliced (`conduit_experience_test.dart`)
- [x] Errors are grouped rather than listed one per occurrence, and the detail
      carries the diagnostic the SDK captured
- [x] API error rates are computed, with Conduit's own ingest traffic excluded
      so the monitor does not report itself
- [x] Alert rules evaluate and produce findings (`conduit_alerting_test.dart`)
- [ ] **Delivery.** Rules fire and nothing carries the result anywhere. This is
      the same gap Exigence's breached objectives have, and it is one decision
      for both — see `DECISIONS_NEEDED.md`, 30/08/26
- [ ] Synthetic probes running on a schedule
- [ ] Errors linking through to the session that produced them

### Deferred — the web pipeline
- ARM receiving alert events via **Pub/Sub** — there is no ingest to post to,
  which is exactly what the open decision is about
- Slack webhook delivery specifically, as opposed to whatever the delivery
  decision settles on

