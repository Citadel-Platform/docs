# Feature 3.1 — Conduit SDK: Core Instrumentation

## Status
Active. First deliverable — nothing else can be built without this.

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

## Definition of done
- [ ] SDK builds to < 20 KB gzipped UMD and ESM targets
- [ ] All autocapture event types are emitted and verifiable in browser devtools
- [ ] Rage click, dead click, and scroll depth events are correctly fired
- [ ] Core Web Vitals and error events are captured on a test page
- [ ] Custom event API functions work before and after SDK init
- [ ] PII masking is verified: no raw input content in captured payloads
- [ ] Transmission batching and sendBeacon fallback work correctly
- [ ] GTM template imports and fires events without code changes

