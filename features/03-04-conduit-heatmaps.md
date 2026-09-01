# Feature 3.4 — Heatmaps

## Status
Active. Depends on Feature 3.2 (events must be stored in BigQuery).

## Scope
Build the Heatmaps module: data aggregation jobs, rendering engine, all heatmap types, and the zone-based analysis UI.

## Tasks

### Task 3.4.1 — Heatmap aggregation pipeline
- Create BigQuery scheduled queries that aggregate raw click, scroll, and hover events into per-page heatmap datasets at configurable intervals (default: every 4 hours).
- Click aggregation: group by `(url_pattern, x_pct, y_pct, device_type)`, count occurrences.
- Scroll aggregation: compute, per page and device, the percentage of sessions reaching each 10%-depth band.
- Hover aggregation: group by `(url_pattern, x_pct, y_pct, device_type)`, sum dwell duration.
- Rage click aggregation: group by `(url_pattern, element_selector)`, count rage click occurrences.
- Dead click aggregation: group by `(url_pattern, element_selector)`, count dead click occurrences.
- Viewport attention aggregation: use IntersectionObserver dwell data to compute time-in-viewport per DOM section per session; aggregate per page.

### Task 3.4.2 — Page screenshot capture
- During SDK instrumentation, capture a full-page DOM serialisation (HTML + inline styles) at session start if a screenshot has not been captured for this URL pattern within the last 24 hours.
- Store the serialised DOM in GCS at `conduit-screenshots/{projectId}/{url_hash}.html.gz`.
- Render the stored DOM to a PNG using a headless Chrome Cloud Run job; store the PNG alongside the HTML.
- Serve page screenshots via signed GCS URLs to the Conduit Console.

### Task 3.4.3 — Heatmap rendering engine
- Build a Canvas-based heatmap renderer in the Conduit Console frontend.
- Input: array of `{x_pct, y_pct, value}` points; render as a density overlay on the page screenshot.
- Colour scale: cool (blue) → warm (red), with configurable opacity.
- Overlay types switchable without reloading the page: click, scroll, hover/move, rage click, dead click, attention.
- Scroll heatmap renders as a horizontal colour band at each depth percentage.
- Device switcher: reload heatmap data for the selected device type (desktop, tablet, mobile).

### Task 3.4.4 — Heatmap filter controls
- Date range picker (presets: today, last 7 days, last 30 days, custom range).
- Device type: desktop, tablet, mobile, all.
- Traffic source: organic, direct, paid, referral, or specific UTM campaign.
- Segment filter: apply any saved audience segment.
- A/B variant filter: if variant dimension data is present, filter to a specific value.

### Task 3.4.5 — Zone-based heatmaps (Zoning Analysis)
- Allow users to define zones by clicking and dragging rectangles on the page screenshot, or by importing a list of CSS selectors.
- Per-zone metrics (pulled from BigQuery aggregation): attractiveness rate (% of sessions where the zone was in viewport), engagement rate (% of attracted sessions that interacted), click rate, click-to-next-page rate, and (if e-commerce events are available) conversion contribution and revenue per click.
- Zone metrics displayed as an overlay on the heatmap and as a sortable table below.
- "View sessions for this zone" action: opens session list filtered to sessions that interacted with the zone.

### Task 3.4.6 — Heatmap comparator
- Side-by-side view for two heatmaps with independent filter selectors.
- Sync scroll mode: both canvases scroll in lockstep.
- Difference overlay: highlight zones where engagement diverges significantly between A and B (colour-coded: blue = A higher, red = B higher).
- Use cases: before/after a design change, mobile vs. desktop, two A/B test variants, two time periods.

### Task 3.4.7 — Form heatmaps
- Detect forms on the page from autocapture data.
- Render a heatmap overlaid specifically on the form: per-field colour coding by abandonment rate.
- Table below: per-field metrics (time on field, abandonment rate, refill rate, blank submission rate, error exposure rate).
- "View sessions for this field" action: opens session list filtered to sessions that interacted with that specific field and dropped off.

## Definition of done

Rewritten 31/08/26 against the product that exists — a Flutter/Dart SDK and a
Dart ingest service on Firestore — rather than the web SDK and BigQuery
pipeline these criteria were first written for. The originals are kept below
under **Deferred**, because they are a product decision that was made, not work
that was dropped: the product-owner review of 30/08/26
(`_dev/docs/feature_set_review_30_08_26.md`) settled Conduit as Flutter/Dart
first with analytics infrastructure deferred.

Heatmaps here are drawn over a **Flutter surface** — `conduit_heatmap_surface.dart`
and `conduit_attention_region.dart` — so the unit of a heatmap is a named
region a developer declared, not a screenshot with coordinates on it. That is a
better answer for an app and a worse one for a website, which is the trade the
30/08/26 review made.

- [x] Attention per declared region is captured, with configurable milestones
      emitted before completion (`conduit_attention_region_test.dart`)
- [x] Scroll depth bands are captured, each threshold once per pageview
- [x] The Console renders the surfaces a project has
- [ ] Aggregation over more than one session's regions — today a region's
      attention is read per session, and density across sessions is the point
      of a heatmap
- [ ] Rage click overlays land on the right region; dead clicks are not
      detected at all (see 3.1)
- [ ] Zone metrics, the side-by-side comparator, and per-field form
      abandonment

### Deferred — the web pipeline
- Rendering over a page **screenshot** with coordinate-space colour scaling
- Scheduled aggregation jobs (there is no BigQuery to aggregate in)

