# Feature 3.1 — Conduit SDK: Core Instrumentation

## Status
Active. First deliverable — nothing else can be built without this.

**Amended 30/08/26 and 31/08/26.** The review settled that Conduit is
Flutter-first with a Dart ingest pipeline; the JavaScript SDK and BigQuery
items below are deferred, not outstanding. **Multiple capture targets per
project are built (31/08/26)**: a project context carries additional targets,
each with its own key, kind, enabled flag and full capture configuration, and
ingest resolves what applies from the key that was actually sent. A disabled
target is refused rather than accepted and dropped.

## Scope
Build and publish the Conduit client-side JavaScript SDK that instruments any website with a single script tag. This SDK is the sole data source for all subsequent Conduit modules.

## Tasks

### Task 3.1.1 — SDK scaffold and build pipeline
- Scaffold a TypeScript library under `conduit/sdk/` with a Rollup or esbuild build pipeline.
- Output targets: UMD (CDN snippet), ESM (NPM package).
- Target bundle size: < 20 KB gzipped.
- Implement an async loader snippet so the SDK does not block page rendering.
- Expose the global `conduit` namespace for all public API calls.

### Task 3.1.2 — Project initialisation and configuration
- On load, accept a project key (written into the snippet during Citadel onboarding).
- Resolve project config from the Conduit Ingest API (`GET /v1/config/:projectKey`): sampling rate, masking rules, feature flags, consent mode setting.
- Implement a session ID generator (UUID v4) persisted to `sessionStorage`.
- Implement a visitor ID generator (UUID v4) persisted to a first-party cookie (`conduit_vid`, 1-year expiry, SameSite=Strict).

### Task 3.1.3 — Autocapture: interaction events
- Intercept all `click` and `touchend` events globally on the `document`.
- For each event, capture: element tag name, CSS selector path (trimmed to 5 ancestors), `data-conduit-*` attribute annotations, inner text (first 80 characters, stripped of digits), element bounding rect, viewport dimensions, scroll position, and timestamp.
- Detect rage clicks: 3+ click events on the same element within 2 seconds. Emit a separate `rage_click` event.
- Detect dead clicks: clicks on elements that are non-interactive (no `href`, no event listener registered via SDK-visible means, no `role=button`). Emit a `dead_click` event.

### Task 3.1.4 — Autocapture: scroll events
- Track vertical scroll depth as a percentage of total page height.
- Emit a `scroll_depth` event at 10%, 25%, 50%, 75%, 90%, and 100% thresholds (each fired once per page view).
- Track time-in-viewport for visible DOM sections using IntersectionObserver (for attention heatmap data).

### Task 3.1.5 — Autocapture: page views and SPA routing
- Emit a `pageview` event on initial load.
- Detect client-side navigation: patch `history.pushState`, `history.replaceState`, and listen for `popstate` to emit virtual page views.
- Detect framework routers (Next.js, React Router, Nuxt) by observing URL changes.
- Include referrer on the first pageview of a session; include the previous virtual URL on subsequent virtual pageviews.

### Task 3.1.6 — Core Web Vitals collection
- Import `web-vitals` library (lazy-loaded from CDN if not bundled in SDK).
- Collect LCP, INP, CLS, TTFB, and FCP using the `onLCP`, `onINP`, `onCLS`, `onTTFB`, `onFCP` callbacks.
- Emit each metric as a `performance_metric` event on collection.
- Capture `PerformanceResourceTiming` entries for waterfall data.
- Capture `PerformanceLongTaskTiming` entries for main-thread blocking detection.

### Task 3.1.7 — Error collection
- Attach `window.addEventListener('error', ...)` for JS errors; capture type, message, stack trace, URL, line, column.
- Attach `window.addEventListener('unhandledrejection', ...)` for promise rejections.
- Monkey-patch `XMLHttpRequest.open` and `XMLHttpRequest.send` to intercept HTTP requests; capture URL, method, status, duration.
- Monkey-patch `window.fetch` to intercept fetch requests; capture URL, method, status, duration.
- Apply a domain allowlist/blocklist from project config to control which API hosts are captured.
- Emit `js_error` and `api_error` event types.

### Task 3.1.8 — Custom event API
- Implement the public API surface:
  ```ts
  conduit.track(eventName: string, properties?: object): void
  conduit.identify(userId: string, traits?: object): void
  conduit.setPageContext(context: object): void
  conduit.trackError(name: string, metadata?: object): void
  conduit.consent(): void        // activates autocapture in consent-gate mode
  conduit.optOut(): void         // stops all collection
  ```
- Queue events fired before SDK initialisation and flush on ready.

### Task 3.1.9 — Privacy and PII masking
- Auto-mask all `<input>`, `<textarea>`, `[type=password]`, and `[type=email]` elements in all captured text and DOM snapshots.
- Apply project-level CSS selector blocklist from config for additional masking.
- Strip digits from captured text by default (configurable).
- Anonymise IP address: strip the last octet server-side in the Ingest API; the SDK does not need to do this.
- Respect `Do-Not-Track` header if project config opts in to DNT honouring.
- In consent-gate mode, autocapture is disabled until `conduit.consent()` is called; only the consent call itself is stored.

### Task 3.1.10 — Event batching and transmission
- Buffer events in memory; flush every 5 seconds or when the buffer reaches 50 events.
- Use `navigator.sendBeacon` for page-hide and unload flushes (unreliable connection safety).
- Compress payload with `CompressionStream` (gzip) where browser supports it.
- Authenticate requests with the project key in an `X-Conduit-Key` header.
- Implement exponential backoff with jitter for failed requests (3 retries, max 30s delay).

### Task 3.1.11 — Google Tag Manager template
- Create a GTM Community Template JSON that exposes: project key field, consent mode toggle, custom event trigger binding.
- Publish to GTM Template Gallery or provide as a downloadable JSON for manual import.
- Document GTM deployment path in Citadel onboarding docs.

## Status note — 30/08/26

**These definition-of-done items describe an architecture Conduit was not
built on, and that divergence has never been recorded.** They assume a
JavaScript web SDK shipped as UMD and ESM bundles with a Google Tag Manager
template, a BigQuery streaming pipeline, Pub/Sub routing and GCS replay
chunks. What exists is a **Flutter/Dart SDK** (`conduit/citadel_conduit_sdk`)
and a **Dart ingest service persisting to Firestore**
(`conduit/citadel_conduit_ingest`), with the Console reading it directly.

Both halves are real and tested — the ingest service alone carries 100 tests
covering validation, analytics, funnels, journeys, alerting, experience
monitoring, voice of customer and session search, and the Console has pages
for all of it. So this is not unbuilt work; it is work whose acceptance
criteria were written against a plan that changed.

**Answered 30/08/26** by the product-owner feature-set review
(`_dev/docs/feature_set_review_30_08_26.md`): Conduit stays Flutter/Dart-heavy
with JS embedded only where unavoidable, collects telemetry and metrics first,
and defers analytics infrastructure. So the boxes below are **deferred, not
outstanding**, and Features 3.1–3.9 need their acceptance criteria rewritten
against the product that exists — a Flutter SDK and a Dart ingest service on
Firestore — rather than the web SDK and BigQuery pipeline they were written
for.

## Definition of done

Rewritten 31/08/26 against the product that exists — a Flutter/Dart SDK and a
Dart ingest service on Firestore — rather than the web SDK and BigQuery
pipeline these criteria were first written for. The originals are kept below
under **Deferred**, because they are a product decision that was made, not work
that was dropped: the product-owner review of 30/08/26
(`_dev/docs/feature_set_review_30_08_26.md`) settled Conduit as Flutter/Dart
first with analytics infrastructure deferred.

- [x] Events tracked before `init` are replayed once it completes, so an app
      that instruments early does not silently lose its first page
      (`conduit_sdk_test.dart`)
- [x] Collection is blocked until consent in gated mode, and explicit feedback
      is still submittable before consent — the one thing a person chose to
      send
- [x] Rage clicks and scroll-depth thresholds fire, each threshold once per
      pageview
- [x] Performance and JavaScript diagnostics are captured as events
- [x] Masked and digit-heavy text is sanitised before it leaves the device, so
      no raw input content reaches a payload
- [x] Batched dispatch, with keepalive on `pagehide` — the Flutter equivalent
      of the `sendBeacon` fallback
- [x] Conduit's own ingest traffic is ignored by API capture, so the SDK does
      not observe itself
- [ ] Dead clicks. Rage clicks and scroll depth are in; a click that hits
      nothing is not detected, and it is the frustration signal the Heatmaps
      overlay (3.4) has nothing to draw
- [ ] Driven in a real app rather than in widget tests — the one thing no test
      here reaches

### Deferred — the web pipeline
Not outstanding. A JavaScript bundle and a Tag Manager template are a second
implementation for a different surface, and the 30/08/26 review put Conduit on
Flutter/Dart with JS embedded only where unavoidable.

- SDK builds to < 20 KB gzipped UMD and ESM targets
- Autocapture verifiable in browser devtools
- Core Web Vitals on a test page
- GTM template imports and fires events without code changes


## Task 3.1.6 — Touchpoints and multiple targets (NEW 30/08/26)

From the feature-set review. The Console page is applied, and multiple targets
was built on 31/08/26; what remains is the refusal on an unknown key.

**Touchpoints** replaces Instrumentation, at `/conduit/touchpoints` (the old
path redirects). The old page was a two-column reference card describing what
the SDK captures — accurate and impossible to act on. The question an operator
arrives with is "is replay on for the customer portal, and off for the internal
admin tool", which is a configuration question, so it is now a configuration
screen: toggles for session replay, heatmaps, synthetic probes and the feedback
widget, writing through the same `conduit_projects` document the ingest service
reads, with sampling, consent, retention, masking and API-error rules shown
beside them.

**Multiple targets** (built 31/08/26). A project may have several apps,
websites and sources, each with its own capture configuration; the Conduit
document now carries a `targets` list and the Console creates, renames and
removes them. What is still missing is the other half of the same idea — the
ingest service does not check the target a capture names, so an unknown key is
attributed to the project rather than refused.

- [x] Touchpoints renders the project's real capture configuration as toggles
      that write
- [x] A project holds several named targets, each with its own configuration
      (31/08/26) — `targets` on the Conduit document, one entry per capture
      source
- [x] Adding, renaming and removing a target from the Console (31/08/26)
- [ ] A capture arriving under an unknown project key is refused, not silently
      attributed. The ingest service does not key on a target, so a capture
      naming one nobody created is still accepted and attributed to the
      project — the honest gap this task has left
