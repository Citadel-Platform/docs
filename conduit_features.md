# Conduit — Feature Backlog
**Product:** Citadel Platform › Conduit
**Scope:** Business analytics, behavioural intelligence, and UX observability for Citadel-managed client sites
**AI Integration:** All AI workloads are owned by Exigence; Conduit only emits events and renders returned insights

---

# Feature 1 — Conduit SDK: Core Instrumentation

## Status
Active. First deliverable — nothing else can be built without this.

## Scope
Build and publish the Conduit client-side JavaScript SDK that instruments any website with a single script tag. This SDK is the sole data source for all subsequent Conduit modules.

## Tasks

### Task 1.1 — SDK scaffold and build pipeline
- Scaffold a TypeScript library under `conduit/sdk/` with a Rollup or esbuild build pipeline.
- Output targets: UMD (CDN snippet), ESM (NPM package).
- Target bundle size: < 20 KB gzipped.
- Implement an async loader snippet so the SDK does not block page rendering.
- Expose the global `conduit` namespace for all public API calls.

### Task 1.2 — Project initialisation and configuration
- On load, accept a project key (written into the snippet during Citadel onboarding).
- Resolve project config from the Conduit Ingest API (`GET /v1/config/:projectKey`): sampling rate, masking rules, feature flags, consent mode setting.
- Implement a session ID generator (UUID v4) persisted to `sessionStorage`.
- Implement a visitor ID generator (UUID v4) persisted to a first-party cookie (`conduit_vid`, 1-year expiry, SameSite=Strict).

### Task 1.3 — Autocapture: interaction events
- Intercept all `click` and `touchend` events globally on the `document`.
- For each event, capture: element tag name, CSS selector path (trimmed to 5 ancestors), `data-conduit-*` attribute annotations, inner text (first 80 characters, stripped of digits), element bounding rect, viewport dimensions, scroll position, and timestamp.
- Detect rage clicks: 3+ click events on the same element within 2 seconds. Emit a separate `rage_click` event.
- Detect dead clicks: clicks on elements that are non-interactive (no `href`, no event listener registered via SDK-visible means, no `role=button`). Emit a `dead_click` event.

### Task 1.4 — Autocapture: scroll events
- Track vertical scroll depth as a percentage of total page height.
- Emit a `scroll_depth` event at 10%, 25%, 50%, 75%, 90%, and 100% thresholds (each fired once per page view).
- Track time-in-viewport for visible DOM sections using IntersectionObserver (for attention heatmap data).

### Task 1.5 — Autocapture: page views and SPA routing
- Emit a `pageview` event on initial load.
- Detect client-side navigation: patch `history.pushState`, `history.replaceState`, and listen for `popstate` to emit virtual page views.
- Detect framework routers (Next.js, React Router, Nuxt) by observing URL changes.
- Include referrer on the first pageview of a session; include the previous virtual URL on subsequent virtual pageviews.

### Task 1.6 — Core Web Vitals collection
- Import `web-vitals` library (lazy-loaded from CDN if not bundled in SDK).
- Collect LCP, INP, CLS, TTFB, and FCP using the `onLCP`, `onINP`, `onCLS`, `onTTFB`, `onFCP` callbacks.
- Emit each metric as a `performance_metric` event on collection.
- Capture `PerformanceResourceTiming` entries for waterfall data.
- Capture `PerformanceLongTaskTiming` entries for main-thread blocking detection.

### Task 1.7 — Error collection
- Attach `window.addEventListener('error', ...)` for JS errors; capture type, message, stack trace, URL, line, column.
- Attach `window.addEventListener('unhandledrejection', ...)` for promise rejections.
- Monkey-patch `XMLHttpRequest.open` and `XMLHttpRequest.send` to intercept HTTP requests; capture URL, method, status, duration.
- Monkey-patch `window.fetch` to intercept fetch requests; capture URL, method, status, duration.
- Apply a domain allowlist/blocklist from project config to control which API hosts are captured.
- Emit `js_error` and `api_error` event types.

### Task 1.8 — Custom event API
- Implement the public API surface:
  ```
  conduit.track(eventName: string, properties?: object): void
  conduit.identify(userId: string, traits?: object): void
  conduit.setPageContext(context: object): void
  conduit.trackError(name: string, metadata?: object): void
  conduit.consent(): void        // activates autocapture in consent-gate mode
  conduit.optOut(): void         // stops all collection
  ```
- Queue events fired before SDK initialisation and flush on ready.

### Task 1.9 — Privacy and PII masking
- Auto-mask all `<input>`, `<textarea>`, `[type=password]`, and `[type=email]` elements in all captured text and DOM snapshots.
- Apply project-level CSS selector blocklist from config for additional masking.
- Strip digits from captured text by default (configurable).
- Anonymise IP address: strip the last octet server-side in the Ingest API; the SDK does not need to do this.
- Respect `Do-Not-Track` header if project config opts in to DNT honouring.
- In consent-gate mode, autocapture is disabled until `conduit.consent()` is called; only the consent call itself is stored.

### Task 1.10 — Event batching and transmission
- Buffer events in memory; flush every 5 seconds or when the buffer reaches 50 events.
- Use `navigator.sendBeacon` for page-hide and unload flushes (unreliable connection safety).
- Compress payload with `CompressionStream` (gzip) where browser supports it.
- Authenticate requests with the project key in an `X-Conduit-Key` header.
- Implement exponential backoff with jitter for failed requests (3 retries, max 30s delay).

### Task 1.11 — Google Tag Manager template
- Create a GTM Community Template JSON that exposes: project key field, consent mode toggle, custom event trigger binding.
- Publish to GTM Template Gallery or provide as a downloadable JSON for manual import.
- Document GTM deployment path in Citadel onboarding docs.

## Definition of done
- [ ] SDK builds to < 20 KB gzipped UMD and ESM targets
- [ ] All autocapture event types are emitted and verifiable in browser devtools
- [ ] Rage click, dead click, and scroll depth events are correctly fired
- [ ] Core Web Vitals and error events are captured on a test page
- [ ] Custom event API functions work before and after SDK init
- [ ] PII masking is verified: no raw input content in captured payloads
- [ ] Transmission batching and sendBeacon fallback work correctly
- [ ] GTM template imports and fires events without code changes

---

# Feature 2 — Event Ingest API & Storage Pipeline

## Status
Active. Depends on Feature 1 (SDK must exist to emit events).

## Scope
Build the server-side event ingestion endpoint, event schema validation, and the storage pipeline that writes events to BigQuery and session replay chunks to Cloud Storage. This is the backend data foundation for all Conduit modules.

## Tasks

### Task 2.1 — Ingest API service
- Create a Cloud Run service at `conduit/ingest/` handling `POST /v1/events`.
- Accept a JSON array of events in the request body (gzip-encoded if `Content-Encoding: gzip`).
- Authenticate using the `X-Conduit-Key` header: validate against the project registry in Firestore.
- Return `202 Accepted` immediately; processing is asynchronous.
- Enforce a rate limit of 5,000 events per project per minute at the Cloud Run ingress.
- IP address anonymisation: strip the last octet of `x-forwarded-for` before any storage write.

### Task 2.2 — Event schema validation and normalisation
- Define and enforce the canonical Conduit event schema in JSON Schema:
  ```
  eventId, sessionId, visitorId, projectId, tenantId,
  timestamp, type, url, referrer,
  device: { type, os, browser, viewport, screenResolution },
  geo: { country, region, city },   // derived from anonymised IP via GeoIP lookup
  payload: object
  ```
- Validate required fields; reject events with missing `projectId`, `sessionId`, or `type`.
- Enrich events with GeoIP-derived fields using a bundled GeoLite2 database (no external call).
- Assign a server-side `receivedAt` timestamp alongside the client `timestamp`.

### Task 2.3 — Pub/Sub routing
- Publish validated events to a Pub/Sub topic `conduit-events-{env}` partitioned by event type.
- Use separate topics for replay chunks (`conduit-replay-{env}`) and performance metrics (`conduit-perf-{env}`) due to different consumer requirements.
- Emit a separate `conduit-exigence-triggers-{env}` topic for events Exigence should react to: `session.ended`, `error.detected`, `frustration.threshold_crossed`.

### Task 2.4 — BigQuery event table
- Create BigQuery dataset `conduit_raw` with partitioned tables per event type: `events`, `errors`, `performance`, `forms`.
- Partition by `DATE(timestamp)`, cluster by `projectId`.
- Use BigQuery streaming insert from the Pub/Sub consumer (Cloud Run subscriber).
- Define a BigQuery aggregation dataset `conduit_agg` with scheduled query jobs for: daily session summaries, page-level metrics, device breakdowns, and traffic source summaries.

### Task 2.5 — Session replay chunk storage
- Receive replay event stream chunks via `POST /v1/replay` (a separate endpoint from the main event ingest).
- Store raw rrweb event arrays as gzip-compressed JSON in GCS at path: `gs://{project-replay-bucket}/{projectId}/{YYYY}/{MM}/{DD}/{sessionId}.json.gz`.
- Write session metadata (start time, end time, page count, duration, frustration signals array, visitor ID) to Firestore at `conduit_sessions/{projectId}/{sessionId}`.
- Implement a lifecycle rule on the GCS bucket: delete replay files older than the project's configured retention period (default 90 days).

### Task 2.6 — Project config API
- Implement `GET /v1/config/:projectKey` endpoint returning: sampling rate, enabled features, masking rules, consent mode, retention days, custom event schema hints.
- Config is stored in Firestore under `conduit_projects/{projectId}` and served with a 1-hour CDN cache.

### Task 2.7 — Session index and search
- Maintain a Firestore collection `conduit_sessions/{projectId}` with indexed fields: `startTime`, `duration`, `deviceType`, `country`, `pageCount`, `hasFrustration`, `tags`, `starred`, `errorIds`.
- Build a query endpoint `POST /v1/sessions/search` that accepts filter parameters and returns paginated session metadata. This backs the session replay filter UI.

## Definition of done
- [ ] Ingest API accepts and validates events; rejects malformed payloads with clear error codes
- [ ] Events are routed to BigQuery within 5 seconds of receipt (streaming latency)
- [ ] Replay chunks are stored in GCS and retrievable by sessionId
- [ ] Pub/Sub topics exist for all routing paths including Exigence triggers
- [ ] Session search query returns correct results with pagination
- [ ] Rate limiting is enforced and returns 429 when exceeded
- [ ] GeoIP enrichment populates country, region, and city fields

---

# Feature 3 — Session Replay Player

## Status
Active. Depends on Features 1 and 2.

## Scope
Build the Session Replay module in the Conduit Console: the session list view, the replay player UI, and all linked navigation to other modules.

## Tasks

### Task 3.1 — Session list view
- Build the session list page: paginated table with columns for visitor ID, date/time, duration, pages visited, device, country, frustration signals (badge icons), tags, and starred state.
- Implement filter panel: date range, device type, browser, country, page visited (URL pattern), session duration range, frustration signal type, custom event presence, tag filter.
- Implement sort by: most recent, longest, most pages, most frustration signals.
- Bulk actions: bulk tag, bulk star, bulk export to CSV.
- Each row links to the session replay player.

### Task 3.2 — DOM replay engine
- Implement a replay engine using the rrweb `Replayer` (or a compatible custom implementation) that reconstructs the captured DOM inside a sandboxed `<iframe>`.
- Fetch replay chunks from a signed GCS URL via the Conduit API.
- Implement a decompress-and-parse step for gzip-compressed chunks.

### Task 3.3 — Replay player UI
- Build the player shell:
  - Full-page replay viewport (responsive, scaled to fit the Console viewport)
  - Timeline scrubber: position indicator, draggable, click-to-seek
  - Event markers on the timeline: click (dot), rage click (red burst), error (red X), page navigation (vertical line), custom event (diamond)
  - Playback controls: play/pause, previous/next event, speed selector (0.5×, 1×, 1.5×, 2×, 4×)
  - Skip idle time toggle: auto-advance through gaps > 3 seconds of inactivity
  - Session metadata sidebar: visitor ID, device details, OS, browser, viewport, country, session duration, page sequence breadcrumb, frustration signal counts, tags, star
  - Share button: generates a timestamped deep link URL
  - "View heatmap for this page" button (navigates to Heatmaps module filtered to the current page)

### Task 3.4 — Developer panels
- Collapsible Console panel below the player: JS errors and `console.warn`/`console.error` output captured during the session, synchronised with the playback timeline.
- Collapsible Network panel: intercepted XHR/Fetch events with method, URL, status, and duration, synchronised with playback timeline.
- Collapsible Events panel: chronological list of all autocapture and custom events in the session.

### Task 3.5 — Frustration signal highlighting
- When the user plays past a rage click event, flash a red overlay on the clicked element in the replay.
- When the user plays past an error event, highlight the timeline marker and auto-open the Console panel.
- Session metadata sidebar shows a frustration signal badge count; clicking jumps the playback to the first occurrence of that signal type.

### Task 3.6 — Session tagging and curation
- Allow users to add free-text tags to a session from the player sidebar.
- Star/unstar a session.
- Add a note (free text) to a session for team context.
- All metadata changes are saved to Firestore immediately.

### Task 3.7 — Linking into session replay from other modules
- Implement a shared utility function `openSessionReplay(sessionId, timestamp?)` used by all other modules to deep-link into a specific session at a specific timestamp.
- Support URL-based deep linking: `/conduit/replay/{projectId}/{sessionId}?t=120` loads and seeks to the given offset.

## Definition of done
- [ ] Session list loads with correct data, filters, and sort
- [ ] Replay player reconstructs a real DOM recording without visual artefacts
- [ ] Timeline markers appear at correct positions for all event types
- [ ] Frustration signals are visually highlighted at correct moments
- [ ] Console and Network panels are synchronised with playback
- [ ] Tag, star, and note operations persist across page reloads
- [ ] Deep link URL opens the player at the specified timestamp

---

# Feature 4 — Heatmaps

## Status
Active. Depends on Feature 2 (events must be stored in BigQuery).

## Scope
Build the Heatmaps module: data aggregation jobs, rendering engine, all heatmap types, and the zone-based analysis UI.

## Tasks

### Task 4.1 — Heatmap aggregation pipeline
- Create BigQuery scheduled queries that aggregate raw click, scroll, and hover events into per-page heatmap datasets at configurable intervals (default: every 4 hours).
- Click aggregation: group by `(url_pattern, x_pct, y_pct, device_type)`, count occurrences.
- Scroll aggregation: compute, per page and device, the percentage of sessions reaching each 10%-depth band.
- Hover aggregation: group by `(url_pattern, x_pct, y_pct, device_type)`, sum dwell duration.
- Rage click aggregation: group by `(url_pattern, element_selector)`, count rage click occurrences.
- Dead click aggregation: group by `(url_pattern, element_selector)`, count dead click occurrences.
- Viewport attention aggregation: use IntersectionObserver dwell data to compute time-in-viewport per DOM section per session; aggregate per page.

### Task 4.2 — Page screenshot capture
- During SDK instrumentation, capture a full-page DOM serialisation (HTML + inline styles) at session start if a screenshot has not been captured for this URL pattern within the last 24 hours.
- Store the serialised DOM in GCS at `conduit-screenshots/{projectId}/{url_hash}.html.gz`.
- Render the stored DOM to a PNG using a headless Chrome Cloud Run job; store the PNG alongside the HTML.
- Serve page screenshots via signed GCS URLs to the Conduit Console.

### Task 4.3 — Heatmap rendering engine
- Build a Canvas-based heatmap renderer in the Conduit Console frontend.
- Input: array of `{x_pct, y_pct, value}` points; render as a density overlay on the page screenshot.
- Colour scale: cool (blue) → warm (red), with configurable opacity.
- Overlay types switchable without reloading the page: click, scroll, hover/move, rage click, dead click, attention.
- Scroll heatmap renders as a horizontal colour band at each depth percentage.
- Device switcher: reload heatmap data for the selected device type (desktop, tablet, mobile).

### Task 4.4 — Heatmap filter controls
- Date range picker (presets: today, last 7 days, last 30 days, custom range).
- Device type: desktop, tablet, mobile, all.
- Traffic source: organic, direct, paid, referral, or specific UTM campaign.
- Segment filter: apply any saved audience segment.
- A/B variant filter: if variant dimension data is present, filter to a specific value.

### Task 4.5 — Zone-based heatmaps (Zoning Analysis)
- Allow users to define zones by clicking and dragging rectangles on the page screenshot, or by importing a list of CSS selectors.
- Per-zone metrics (pulled from BigQuery aggregation): attractiveness rate (% of sessions where the zone was in viewport), engagement rate (% of attracted sessions that interacted), click rate, click-to-next-page rate, and (if e-commerce events are available) conversion contribution and revenue per click.
- Zone metrics displayed as an overlay on the heatmap and as a sortable table below.
- "View sessions for this zone" action: opens session list filtered to sessions that interacted with the zone.

### Task 4.6 — Heatmap comparator
- Side-by-side view for two heatmaps with independent filter selectors.
- Sync scroll mode: both canvases scroll in lockstep.
- Difference overlay: highlight zones where engagement diverges significantly between A and B (colour-coded: blue = A higher, red = B higher).
- Use cases: before/after a design change, mobile vs. desktop, two A/B test variants, two time periods.

### Task 4.7 — Form heatmaps
- Detect forms on the page from autocapture data.
- Render a heatmap overlaid specifically on the form: per-field colour coding by abandonment rate.
- Table below: per-field metrics (time on field, abandonment rate, refill rate, blank submission rate, error exposure rate).
- "View sessions for this field" action: opens session list filtered to sessions that interacted with that specific field and dropped off.

## Definition of done
- [ ] Heatmap aggregation jobs run on schedule and produce correct density data
- [ ] All heatmap types render correctly on the page screenshot with correct colour scaling
- [ ] Scroll heatmap shows correct depth bands
- [ ] Rage click and dead click overlays highlight correct locations
- [ ] Filter controls reload data correctly without page refresh
- [ ] Zone analysis shows correct per-zone metrics
- [ ] Heatmap comparator side-by-side view works with sync scroll
- [ ] Form heatmap shows per-field abandonment correctly

---

# Feature 5 — Journey & Funnel Analysis

## Status
Active. Depends on Feature 2.

## Scope
Build the Journey Analysis and Funnel Analysis modules, giving clients a macro view of how users navigate through their site.

## Tasks

### Task 5.1 — Journey aggregation pipeline
- Create BigQuery views and scheduled queries that aggregate sequences of page views per session into a transition matrix: `(source_url_pattern, destination_url_pattern, count, drop_off_count)`.
- Group URLs into configurable patterns (e.g., `/products/*` grouped as "Product Pages") using project-level URL grouping rules stored in Firestore.
- Compute entry page distribution and exit page distribution per URL pattern.

### Task 5.2 — Sankey/flow diagram
- Build an SVG Sankey diagram component in the Console frontend.
- Input: transition matrix from the aggregation pipeline.
- Nodes represent pages/page groups; edges represent transitions, weighted by session count.
- Drop-off percentage displayed on each node (sessions that exited at that page).
- Click a node to: open session list filtered to sessions that visited that page, or expand the downstream transitions.
- Colour nodes by drop-off severity (green → amber → red).

### Task 5.3 — Sunburst journey view
- Build a radial SVG sunburst component as an alternative view.
- Centre node is the selected entry page; each ring represents one step further in the journey.
- Arc width is proportional to the fraction of sessions that took that path.
- Click an arc to filter the view to sessions that followed that specific path.
- Toggle between Sankey and Sunburst with a view selector.

### Task 5.4 — Journey filter controls
- Filter by: date range, device type, entry page, exit page, segment.
- "Start from this page" control: re-root the diagram at any page as the origin.

### Task 5.5 — Funnel builder
- UI to define a funnel: add steps by page URL, URL pattern, or custom event name; reorder steps by drag-and-drop; name the funnel; save and share.
- Funnels are stored in Firestore under `conduit_funnels/{projectId}/{funnelId}`.

### Task 5.6 — Funnel visualisation
- Stepped vertical funnel chart showing: step label, session count entering, conversion rate from previous step, drop-off count, drop-off percentage.
- Hover tooltip: exact count, conversion rate, and time-to-convert distribution (P50, P75).
- Click any step: open session list filtered to sessions that entered that step.
- Click any drop-off count: open session list filtered to sessions that dropped off at that step.
- Cross-segment comparison: overlay funnel for two segments (device types, traffic sources, user cohorts) on the same chart with side-by-side bars.

## Definition of done
- [ ] Journey aggregation query produces correct transition matrices for test project data
- [ ] Sankey diagram renders correctly and is interactive (click to filter)
- [ ] Sunburst diagram renders correctly and is interactive
- [ ] Funnel builder saves and loads funnel definitions correctly
- [ ] Funnel chart shows correct conversion rates and drop-off counts
- [ ] Cross-segment comparison overlays two funnels correctly

---

# Feature 6 — Web Analytics Overview

## Status
Active. Depends on Feature 2.

## Scope
Build the Web Analytics Overview module: a first-party traffic analytics dashboard providing session, visitor, and traffic source context.

## Tasks

### Task 6.1 — Web analytics aggregation queries
- Define BigQuery scheduled queries for: daily session counts, unique visitor counts (by visitorId), pageview counts, bounce rate, average session duration, pages-per-session, and exit rate per URL.
- Traffic source attribution: parse UTM parameters from referrer and URL; classify sessions into organic, direct, paid, referral, social.
- Device and browser breakdown aggregations.
- Geographic breakdown by country and city.

### Task 6.2 — Overview dashboard
- Summary row: sessions, unique visitors, pageviews, bounce rate, avg. session duration, pages/session — all with delta vs. comparison period.
- Primary line chart: sessions and pageviews over time (hour/day/week granularity selector).
- Real-time widget: active visitors in the last 5 minutes with a live-updating count and a mini table of currently active pages.

### Task 6.3 — Traffic source breakdown
- Doughnut or horizontal bar chart showing session count by source: organic, direct, paid, referral, social.
- Drill-down: click a source to see the top referral domains or UTM campaigns.

### Task 6.4 — Top pages table
- Paginated table: URL pattern, pageviews, unique visitors, avg. time on page, bounce rate, exit rate.
- Click a row: navigate directly to the Heatmaps module filtered to that URL pattern.

### Task 6.5 — Device and geographic breakdowns
- Bar chart: sessions by device type (desktop, tablet, mobile) with OS and browser sub-breakdown.
- Map widget: sessions per country as a choropleth map with tooltips.
- City table for drilldown.

### Task 6.6 — New vs. returning visitors
- Line chart splitting sessions into new visitor sessions vs. returning visitor sessions over time.
- Summary: new visitor rate, returning visitor rate, avg. sessions per returning visitor.

## Definition of done
- [ ] All aggregation queries produce correct daily metrics for test project data
- [ ] Overview dashboard renders all widgets with correct data
- [ ] Real-time visitor count updates without page refresh
- [ ] Traffic source breakdown correctly classifies UTM-tagged and organic sessions
- [ ] Top pages table links correctly to the Heatmaps module

---

# Feature 7 — Experience Monitoring (Performance, Errors, Frustration)

## Status
Active. Depends on Feature 2. Coordinates with ARM for alert routing.

## Scope
Build the Experience Monitoring module: Core Web Vitals RUM, JavaScript and API error tracking, frustration signal dashboards, synthetic monitoring probes, and the alerting engine.

## Tasks

### Task 7.1 — Core Web Vitals dashboard
- BigQuery aggregation queries for LCP, INP, CLS, TTFB, and FCP: per-page-group and site-wide, computed at P50, P75, and P95 percentiles, sliced by device type and geography.
- Dashboard layout: one card group per CWV metric showing the P75 value, a colour-coded status (good / needs improvement / poor based on Google thresholds), and a trend line.
- Page performance table: all URL patterns ranked by P75 LCP, with P75 INP and P75 CLS columns.
- Click any page row: see the CWV waterfall for that page alongside session replays with poor performance scores.
- Correlation chart: overlay P75 LCP with bounce rate and conversion rate on the same time axis.

### Task 7.2 — JavaScript error tracking UI
- Error list: grouped by error message and type; columns for occurrence count, affected session count, affected URL, first seen, last seen, and conversion impact.
- Error detail panel: full stack trace (with source-map-resolved file and line if source maps are uploaded), affected browser and OS breakdown, occurrence trend chart.
- "View sessions with this error" action: opens session list filtered to sessions containing this error, pre-seeking to the error event.
- Source map upload API: `POST /v1/sourcemaps/{projectId}` accepting a multipart upload of `.js.map` files keyed by release version.

### Task 7.3 — API error tracking UI
- API error list grouped by endpoint URL pattern and HTTP status code.
- Per-endpoint: error rate (errors / total requests), affected session count, first/last seen, conversion impact.
- "View sessions" action: opens filtered session list.
- Custom API error rule builder in Settings: define endpoint URL patterns and status code ranges to monitor; define custom error names for specific response body conditions.

### Task 7.4 — Frustration signals dashboard
- Summary cards for each frustration signal type: rage clicks, dead clicks, scroll bounce, quick exits, u-turns, error clicks — with counts and week-over-week trend.
- Frustration heatmap: a click heatmap filtered to only rage clicks and dead clicks, to spatially locate frustration.
- Top pages by frustration score: composite score combining all signal types, ranked table.
- Frustration signal trend chart: timeline of each signal type.
- Click any signal → filtered session list.

### Task 7.5 — Synthetic monitoring
- Deploy a scheduled Cloud Run job (runs every 5 minutes) using Playwright to probe configured URLs.
- Configurable probe list per project: URL, expected HTTP status, optional element-present assertion.
- Probe locations: Singapore (default), US (us-central1), Europe (europe-west1) — one runner per location.
- Store probe results in BigQuery `conduit_synthetic` table: `probe_url`, `location`, `status_code`, `load_time_ms`, `success`, `timestamp`.
- Dashboard widget: uptime percentage per probed URL, P95 load time trend, last-check status badge.
- Alert on: availability failure (non-200 response) or load time exceeding configured threshold.

### Task 7.6 — Alerting engine
- Alert rule builder in Console Settings: metric (CWV, error rate, conversion rate, frustration score, uptime), condition (above/below threshold, or anomaly mode), time window, minimum occurrence count to suppress noise.
- Store alert rules in Firestore `conduit_alerts/{projectId}/{alertId}`.
- Alert evaluation: Cloud Run job runs every 5 minutes, evaluates all active alert rules against recent BigQuery data.
- When an alert fires: create an alert event in Firestore, send notification to configured channels (email, Slack webhook), and emit a `conduit.alert.fired` Pub/Sub event (for ARM integration and Exigence).
- Alert history UI: list of past alert events with status (firing, resolved), duration, and linked data.
- ARM integration: route `conduit.alert.fired` events to the ARM event bus so error alerts appear in ARM Console alongside application telemetry.

## Definition of done
- [ ] CWV dashboard shows correct P50/P75/P95 values for test data sliced by device
- [ ] JS error list groups correctly and shows stack trace in the detail panel
- [ ] API error list shows correct error rates and links to session replays
- [ ] Frustration dashboard shows correct signal counts and frustration heatmap
- [ ] Synthetic probes run on schedule and record results correctly
- [ ] Alert rules fire and deliver notifications via Slack webhook in < 2 minutes of threshold breach
- [ ] ARM receives alert events via Pub/Sub

---

# Feature 8 — Voice of Customer (Feedback, Polls & Surveys)

## Status
Active. Depends on Features 1 and 2.

## Scope
Build the Voice of Customer module: feedback widgets, on-site polls, multi-question surveys, NPS, and the survey analytics dashboard.

## Tasks

### Task 8.1 — Feedback widget
- SDK plugin that renders a persistent feedback button on the client's page (position, colour, and label configurable from the Conduit Console).
- On click: expands to a small panel with a sentiment selector (1–5 star or emoji scale) and an open-text input.
- Optional annotated screenshot: capture a `html2canvas` screenshot and allow the user to draw an annotation on it.
- Submit action: sends feedback payload to `POST /v1/voc/feedback` with `sessionId`, `visitorId`, `url`, `sentiment`, `text`, `screenshotUrl`.
- Storage: Firestore `conduit_feedback/{projectId}` collection.

### Task 8.2 — On-site polls
- Poll builder in Console: question text, response type (single choice, open text, NPS scale 0–10, star rating), display trigger, targeting rules, and active/inactive toggle.
- Trigger conditions: time on page (N seconds), scroll depth (N%), exit intent (cursor approaching top of viewport), element click (CSS selector), custom event (event name), or first visit.
- Targeting: URL pattern match, device type, visitor segment, frequency cap (max once per visitor per N days).
- SDK: the config API serves active poll definitions; the SDK evaluates triggers client-side and renders the poll widget.
- Poll widget: clean inline overlay, customisable to match the client's brand colours via CSS custom properties.
- Submit action: sends poll response to `POST /v1/voc/poll-responses` with session context.
- Storage: BigQuery `conduit_poll_responses` table for analysis; Firestore for real-time count.

### Task 8.3 — Multi-question surveys
- Survey builder in Console: add/remove questions, set question types (single choice, multi-choice, open text, rating scale, NPS, likert), define conditional branching logic (show question B only if answer to A equals X).
- Deployment modes: embedded on-page widget, triggered pop-up (same trigger conditions as polls), or shareable survey URL.
- Survey URL: a standalone hosted page at `conduit.citadel.app/s/{surveyId}` rendered from the survey definition.
- Submit action: sends full response to `POST /v1/voc/survey-responses`.
- Storage: BigQuery `conduit_survey_responses` table; each response includes `sessionId` (null if off-site) and all answer values.

### Task 8.4 — Survey analytics dashboard
- Per-survey dashboard: response count, completion rate, average NPS score (if applicable), per-question response breakdown (bar charts for choice questions, word cloud and theme list for open text).
- Response list: paginated table of individual responses with timestamp, device, session replay link (if session context exists).
- Word frequency cloud for all open-text responses in a selected date range.
- Export: CSV of all responses.

### Task 8.5 — Session replay linking for VoC
- For any poll or survey response that includes a `sessionId`, provide a "View session replay" button that deep-links to the Session Replay player for that session.

## Definition of done
- [ ] Feedback widget renders on a test page and submissions appear in Firestore
- [ ] Polls fire at the correct trigger conditions (time, scroll, exit intent) on a test page
- [ ] Survey builder creates a survey definition that deploys correctly as a widget and via shareable URL
- [ ] Survey analytics dashboard shows correct per-question breakdowns
- [ ] Session replay linking from survey responses opens the correct session

---

# Feature 9 — Conduit Console: Core UI Shell & Custom Workspaces

## Status
Active. Depends on Features 3–8 (individual module UIs must exist before assembling the shell).

## Scope
Build the Conduit Console application shell: navigation, project/date/segment global controls, the Overview dashboard, and the custom workspace builder.

## Tasks

### Task 9.1 — Console application shell
- Build the Next.js (or SvelteKit) Conduit Console application under `conduit/console/`.
- Persistent left sidebar navigation: Overview, Heatmaps, Session Replay, Journeys, Funnels, Forms, Web Analytics, Performance, Errors, Frustration, VoC (Surveys, Feedback), AI Insights, Settings.
- Collapsible sidebar for narrow viewports.
- Top bar: project picker (dropdown, lists all Conduit-enabled projects for the logged-in Citadel account), global date range selector (with presets and custom range), global segment filter (applies to all modules), AI chat trigger button.
- Authentication: use Citadel Platform's existing auth session; no separate Conduit login.

### Task 9.2 — Overview dashboard
- Summary KPI row: sessions, unique visitors, bounce rate, avg. duration, top error (with count), frustration score — with vs. previous period deltas.
- Sessions trend line chart (7-day default).
- Real-time active visitor count with live update.
- Top 5 pages by pageviews (mini table with heatmap link).
- Latest AI insight card slot (populated by Exigence when available; skeleton state when not).
- Recent error badge if new errors appeared since last login.

### Task 9.3 — Global filter state management
- Implement a global filter context (React context or Svelte store) that holds: active project, date range, comparison date range, active segment.
- All module data fetches include the global filter as query parameters.
- Filters persist in the URL query string so links share the current context.
- Segment picker: search and select from saved segments; show active segment as a highlighted badge.

### Task 9.4 — Custom workspace builder
- Workspace concept: a named, saved, configurable dashboard of widgets.
- Widget picker: modal or sidebar listing all available widget types with a preview thumbnail.
- Grid layout: 12-column responsive grid (react-grid-layout or equivalent); widgets are draggable and resizable.
- Each widget has a settings panel: override date range, select a specific metric, apply a segment.
- Save workspace: stored in Firestore `conduit_workspaces/{projectId}/{workspaceId}`.
- Workspace list page: list all saved workspaces for the project with last-modified date.
- Default workspace: "Overview" (non-deletable pre-built).
- Share workspace: generate a read-only URL that renders the workspace for anyone with a Conduit Console login for that project.

### Task 9.5 — PDF export
- Implement "Export to PDF" for the active workspace using a headless Chrome render job (Cloud Run).
- Each widget renders in its current state; charts and heatmap thumbnails are included.
- Output: PDF stored temporarily in GCS with a signed URL returned to the client for download.
- Naming convention: `{project_name}_{workspace_name}_{date}.pdf`.

## Definition of done
- [ ] Console shell renders with correct navigation and project switcher
- [ ] Global date range and segment filters propagate to all module data fetches
- [ ] Overview dashboard displays all widgets with live data
- [ ] Custom workspace builder allows creating, saving, loading, and sharing workspaces
- [ ] PDF export produces a readable, correctly formatted report

---

# Feature 10 — Segmentation & Audience Builder

## Status
Active. Depends on Features 2, 6, and 9 (Console shell).

## Scope
Build the audience segment builder: allow clients to define reusable named segments from behavioural, device, geographic, and custom-property dimensions, and apply them across all Conduit modules.

## Tasks

### Task 10.1 — Segment definition schema
- Define the segment rule schema: a tree of conditions connected by AND/OR operators.
- Supported condition types: device type, browser, OS, country, city, traffic source, UTM parameter, page visited (URL pattern), custom event fired (event name + optional property filter), user property (set via `conduit.identify()`), session duration (greater/less than N seconds), frustration signal type encountered, survey response (answered a specific question with a specific value).
- Store segment definitions in Firestore `conduit_segments/{projectId}/{segmentId}`.

### Task 10.2 — Segment builder UI
- Visual segment builder in the Console under Settings > Segments > New Segment.
- Condition picker: add condition → select dimension → configure value.
- AND/OR group nesting support (minimum: 2 levels of nesting).
- Live session count estimate: as the user builds the rule, show the estimated number of matching sessions in the last 30 days (queried from BigQuery in near-real-time).
- Save segment with name and optional description.

### Task 10.3 — Segment application across modules
- All module filter panels include a "Segment" field that loads saved segments from Firestore.
- When a segment is selected, it is translated into BigQuery WHERE clause conditions and applied to the module's data query.
- For session replay, segments are applied to the Firestore session search query.

### Task 10.4 — Segment comparison
- In Heatmaps, Funnels, and Web Analytics modules, implement a "Compare segments" mode: select Segment A and Segment B and render both data sets side-by-side or overlaid.

### Task 10.5 — Segment export
- Export a segment as a list of session IDs (CSV).
- Exigence integration: publish segment definition to a `conduit-segment-export-{env}` Pub/Sub topic so Exigence can pull matching visitor data for targeted AI analysis or for routing to external marketing tools via webhook.

## Definition of done
- [ ] Segment builder allows creating a multi-condition segment and saves it correctly
- [ ] Applying a segment in the Heatmaps module filters the heatmap data correctly
- [ ] Segment comparison renders side-by-side correctly in at least Funnels and Web Analytics
- [ ] Segment export produces a correct CSV of session IDs
- [ ] Live session count estimate updates as conditions are added in the builder

---

# Feature 11 — Data Export & Third-Party Integrations

## Status
Deferred until core modules (Features 1–10) are stable.

## Scope
Build data export capabilities and first-party integrations with Slack, Jira/Linear, Google Analytics 4, and Google Tag Manager.

## Tasks

### Task 11.1 — CSV/JSON export for all modules
- Implement a consistent export action in every data table in the Console: sessions list, error list, survey responses, web analytics top pages.
- Format: CSV (default) and JSON (optional).
- For large exports (> 10,000 rows): offload to a BigQuery export job and return a download link via email when complete.

### Task 11.2 — Webhook delivery
- Allow clients to configure outbound webhooks in Console Settings: event type (survey response received, alert fired, frustration threshold crossed), destination URL, secret for HMAC signature.
- Webhook payloads are delivered via a Cloud Run job that reads from the relevant Pub/Sub topics.
- Retry with exponential backoff on delivery failure (3 retries, 24-hour TTL).
- Webhook delivery log in Console Settings showing last 50 events with status.

### Task 11.3 — Slack integration
- OAuth-based Slack app connection in Console Settings.
- Configurable notification types: alert fired, weekly summary digest, new high-frustration session.
- Weekly digest message format: top 3 errors, top 3 high-frustration pages, session count vs. previous week.

### Task 11.4 — Jira/Linear integration
- OAuth-based connection to Jira Cloud or Linear.
- "Create ticket" button on: error detail panel, session replay player, and frustration signal detail.
- Ticket pre-populated with: error message, stack trace, affected session count, session replay link, page URL, and screenshot (if available).

### Task 11.5 — Google Analytics 4 integration
- Allow clients to configure their GA4 Measurement ID in Console Settings.
- SDK plugin: when a Conduit custom event is fired, mirror it to GA4 via the `gtag('event', ...)` API.
- Optionally receive GA4 client ID from the existing GA4 cookie for session stitching (with client consent).

### Task 11.6 — BigQuery / warehouse export
- Within the same GCP project: the `conduit_raw` and `conduit_agg` BigQuery datasets are already accessible to the client's GCP project. Document table schemas and recommended queries in Citadel client documentation.
- Cross-project export: for clients who want data in a different GCP project, implement an authorised view or BigQuery Data Transfer Service job.

## Definition of done
- [ ] CSV export works for sessions, errors, and survey responses
- [ ] Webhook delivers test events with correct HMAC signature to a test endpoint
- [ ] Slack sends a correctly formatted weekly digest to a test channel
- [ ] Jira integration creates a ticket with correct pre-populated fields
- [ ] GA4 integration mirrors a custom Conduit event to GA4 in real time

---

# Feature 12 — Exigence AI Integration: Session Summaries & Heatmap Interpretation

## Status
Deferred until Features 3 and 4 are deployed and Exigence has a stable inference API.

## Scope
First phase of Exigence × Conduit integration: AI-powered session summaries (single and batch) and heatmap interpretation. This is the foundation layer before more agentic features.

## Tasks

### Task 12.1 — Exigence inference API contract
- Define the shared API contract between Conduit and Exigence: endpoint paths, authentication, request/response schemas.
- Request schema for session summary: `{ projectId, sessionIds: string[], analysisType: 'single' | 'batch', context?: string }`.
- Response schema: `{ insightId, summary: string, frictionPoints: FrictionPoint[], recommendedActions: string[], sessionReplayLinks: string[] }`.
- Request schema for heatmap interpretation: `{ projectId, urlPattern, device, dateRange, zoneMetrics: ZoneMetric[] }`.
- Response schema: `{ insightId, interpretation: string, topOpportunities: Opportunity[] }`.

### Task 12.2 — Session summary trigger (single session)
- Add a "Summarise with AI" button in the Session Replay player sidebar.
- On click: send the session's rrweb event stream and session metadata to the Exigence inference API.
- Show a loading state; render the returned insight card in the sidebar when complete.
- Insight card: summary paragraph, bulleted friction points (each linking to the relevant timestamp in the replay), recommended actions.
- Cache the insight in Firestore `conduit_ai_insights/{projectId}/sessions/{sessionId}` so it is not re-generated on replay page reload.

### Task 12.3 — Batch session summary trigger
- Add a "Summarise with AI" button in the Session Replay list view when filters are active (i.e., a meaningful subset is selected).
- Send the top 50 sessions matching the current filter (by recency) to Exigence for batch analysis.
- Render the batch insight as a panel above the session list.
- Store the batch insight in Firestore `conduit_ai_insights/{projectId}/batch/{batchId}` keyed by the filter parameters hash.

### Task 12.4 — Heatmap AI interpretation
- Add an "Interpret with AI" button in the Heatmap module toolbar.
- On click: send the zone metrics array for the current heatmap view to Exigence.
- Render the interpretation as an AI insight card panel below the heatmap.
- Cache the insight in Firestore `conduit_ai_insights/{projectId}/heatmaps/{pageHash}_{device}_{dateHash}`.

### Task 12.5 — AI Insights module in Console
- Add an "AI Insights" navigation item in the Console.
- Page lists all generated insights for the project in reverse chronological order: insight type (session batch, heatmap, journey, anomaly), summary snippet, date, source module link.
- Insight detail view: full analysis output from Exigence.
- "Dismiss" or "Archive" an insight.

## Definition of done
- [ ] "Summarise with AI" button in the replay player triggers an Exigence call and renders the insight card
- [ ] Batch summary for a filtered session list completes and renders above the list
- [ ] Heatmap interpretation renders as an insight card in the Heatmaps module
- [ ] AI Insights module lists all generated insights for the project
- [ ] Insight caching prevents duplicate API calls for the same data

---

# Feature 13 — Exigence AI Integration: Natural Language Query & Anomaly Alerts

## Status
Deferred until Feature 12 is complete and Exigence's NL query capability is available.

## Scope
Second phase of Exigence × Conduit integration: natural language chat interface over Conduit data, proactive anomaly detection, and AI-powered VoC summarisation.

## Tasks

### Task 13.1 — Conduit Chat interface
- Build a persistent collapsible chat panel in the Conduit Console (accessible from the top bar "AI ✦" button).
- Text input field for natural language questions about the project's data.
- Conduit sends the query and a structured context payload (active project, date range, available metric schema) to the Exigence NL query endpoint.
- Exigence returns: an answer in prose, supporting data (chart data array or table data), and recommended next actions.
- Console renders the answer with the appropriate chart or table widget inline in the chat.
- Conversation context: send the last 10 exchanges with each new query so Exigence can answer follow-ups without re-stating the context.

### Task 13.2 — Anomaly detection job integration
- Exigence runs a scheduled anomaly detection job (every hour) against `conduit_agg` BigQuery data for all active projects.
- Exigence calls back to a Conduit API endpoint (`POST /v1/insights/anomaly`) when an anomaly is detected.
- Conduit stores the anomaly insight in Firestore `conduit_ai_insights/{projectId}/anomalies/{anomalyId}`.
- Anomaly appears in: AI Insights module, Console Overview dashboard alert slot, and triggers the configured alert delivery channels (Slack, email) with an AI-generated explanation.

### Task 13.3 — AI survey generator
- Add an "Generate with AI" option in the Survey Builder.
- User inputs a research goal as free text ("Understand why users drop off at the pricing page").
- Conduit sends the goal + relevant Conduit data context (top drop-off pages, frustration signals for that URL, existing survey results) to Exigence.
- Exigence returns a complete survey definition (question array with types and branching logic).
- Console loads the returned definition directly into the Survey Builder for the client to review and activate.

### Task 13.4 — VoC AI summarisation
- Add a "Summarise with AI" button in the Survey Analytics dashboard.
- Conduit sends all open-text responses from the selected survey and date range to Exigence.
- Exigence returns: theme clusters (each with representative quotes paraphrased), sentiment distribution, top pain points, and a recommended action list.
- Renders as a structured insight panel in the Survey Analytics module.

## Definition of done
- [ ] Chat panel accepts a question and returns an answer with a supporting chart in < 10 seconds
- [ ] A simulated anomaly triggers an Exigence callback that creates an anomaly insight in Conduit and sends a Slack notification
- [ ] "Generate with AI" in Survey Builder creates a complete survey definition from a plain-text goal
- [ ] VoC summarisation returns theme clusters and sentiment distribution for a test set of survey responses

---

# Feature 14 — Mobile SDK (React Native)

## Status
Deferred. Web instrumentation must be stable before expanding to mobile.

## Scope
Build a React Native SDK for Conduit, enabling session replay, touch heatmaps, and performance monitoring for native mobile apps.

## Tasks

### Task 14.1 — React Native SDK scaffold
- Create `conduit/sdk-rn/` as a React Native module.
- Bridge: native iOS (Swift) and Android (Kotlin) modules for platform-specific APIs (screen capture, touch event interception).
- JavaScript bridge: same `conduit.track()`, `conduit.identify()`, `conduit.consent()` API surface as the web SDK.
- Session and visitor ID management using `AsyncStorage`.

### Task 14.2 — Touch event capture
- Intercept touch events (`touchstart`, `touchmove`, `touchend`) at the React Native gesture layer.
- Record touch coordinates normalised to screen percentage, timestamp, and component path.
- Detect tap rage events (3+ taps in 2 seconds in the same screen area).
- Detect gesture types: tap, swipe, pinch.

### Task 14.3 — Touch heatmaps
- Aggregate touch events per screen name (React Navigation route name) into density data stored in BigQuery.
- Render touch heatmaps in the Console Heatmaps module with a device frame overlay, using a screenshot of the screen taken at session start.

### Task 14.4 — Mobile session replay
- Capture screen snapshots at configurable intervals (default: on user interaction + every 2 seconds) as JPEG frames.
- Apply on-device PII masking before capture (mask all text input components by default).
- Upload frames to GCS: `conduit-replay-mobile/{projectId}/{sessionId}/frames/`.
- Build a mobile replay viewer in the Console that plays back the frame sequence with overlaid touch event indicators.

### Task 14.5 — Mobile performance monitoring
- Capture JS thread FPS (frames per second) from the React Native Perf Monitor.
- Capture app startup time, time-to-interactive, and screen render time per route.
- Capture native crash reports: integrate with the existing error collection pipeline.
- Display mobile-specific performance metrics in the Experience Monitoring module.

### Task 14.6 — Remote masking controls
- Allow Conduit Console users to update masking rules (component names to mask) without requiring an app store release.
- Masking rules are served via the config API and applied at session start on the next app launch.

## Definition of done
- [ ] SDK installs in a React Native test app without build errors on iOS and Android
- [ ] Touch events are captured and transmitted to the ingest API
- [ ] Touch heatmap renders in the Console for a test screen
- [ ] Mobile session replay plays back correctly in the Console mobile replay viewer
- [ ] Remote masking rules update on the device without a redeployment

---

# Feature 15 — Exigence AI Integration: Agentic Analysis & Scheduled Insights

## Status
Deferred until Features 12 and 13 are complete and Exigence's agentic capability is mature.

## Scope
Third and final phase of Exigence × Conduit integration: autonomous analysis scheduling, journey recommendations, and a Conduit AI newsroom.

## Tasks

### Task 15.1 — Scheduled analysis jobs
- Allow clients to configure recurring analysis jobs in the Exigence section of Console Settings.
- Job configuration: analysis type (session batch, funnel analysis, error summary, VoC summary), data scope (URL pattern, date window size), frequency (daily, weekly), delivery channel (in-app, email).
- Jobs are stored in Firestore `exigence_scheduled_jobs/{projectId}/{jobId}`.
- Exigence executes jobs on schedule, writes results to Firestore `conduit_ai_insights/{projectId}/scheduled/{jobId}/{runId}`, and sends the configured notifications.

### Task 15.2 — Journey AI recommendations
- Add a "Get AI recommendations" action in the Journey Analysis module.
- Conduit sends the journey transition matrix, drop-off rates, and segment comparisons for the active view to Exigence.
- Exigence returns a prioritised list of journey optimisation recommendations with supporting data.
- Renders as an insight panel in the Journey module.

### Task 15.3 — Conduit AI Newsroom
- A dedicated "Newsroom" sub-page in the AI Insights module.
- Updated daily by Exigence: automatically surfaces the most significant changes, anomalies, and opportunities detected across all Conduit data for the project.
- Format: a feed of dated insight cards, each with a title, one-paragraph explanation, supporting metric, and a link to the source module.
- Clients can subscribe to a daily email digest of the newsroom.

### Task 15.4 — A/B experiment insight integration
- When clients run A/B tests (via URL parameters or custom properties passed to `conduit.identify()`), Conduit can split heatmap, funnel, and session data by variant.
- Add an "Analyse A/B results with AI" action: send variant metrics to Exigence, which returns an explanation of why one variant outperformed the other, with heatmap zone evidence.

## Definition of done
- [ ] A scheduled weekly session batch summary job runs on schedule and delivers an email with the AI summary
- [ ] Journey recommendations are generated and rendered for a test journey view
- [ ] AI Newsroom displays a correctly populated daily feed with at least 3 insight card types
- [ ] A/B analysis correctly splits data by variant and generates an Exigence insight

---

*End of Feature Backlog*