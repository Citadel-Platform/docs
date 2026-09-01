# Feature 3.5 — Journey & Funnel Analysis

## Status
Active. Depends on Feature 3.2.

## Scope
Build the Journey Analysis and Funnel Analysis modules, giving clients a macro view of how users navigate through their site.

## Tasks

### Task 3.5.1 — Journey aggregation pipeline
- Create BigQuery views and scheduled queries that aggregate sequences of page views per session into a transition matrix: `(source_url_pattern, destination_url_pattern, count, drop_off_count)`.
- Group URLs into configurable patterns (e.g., `/products/*` grouped as "Product Pages") using project-level URL grouping rules stored in Firestore.
- Compute entry page distribution and exit page distribution per URL pattern.

### Task 3.5.2 — Sankey/flow diagram
- Build an SVG Sankey diagram component in the Console frontend.
- Input: transition matrix from the aggregation pipeline.
- Nodes represent pages/page groups; edges represent transitions, weighted by session count.
- Drop-off percentage displayed on each node (sessions that exited at that page).
- Click a node to: open session list filtered to sessions that visited that page, or expand the downstream transitions.
- Colour nodes by drop-off severity (green → amber → red).

### Task 3.5.3 — Sunburst journey view
- Build a radial SVG sunburst component as an alternative view.
- Centre node is the selected entry page; each ring represents one step further in the journey.
- Arc width is proportional to the fraction of sessions that took that path.
- Click an arc to filter the view to sessions that followed that specific path.
- Toggle between Sankey and Sunburst with a view selector.

### Task 3.5.4 — Journey filter controls
- Filter by: date range, device type, entry page, exit page, segment.
- "Start from this page" control: re-root the diagram at any page as the origin.

### Task 3.5.5 — Funnel builder
- UI to define a funnel: add steps by page URL, URL pattern, or custom event name; reorder steps by drag-and-drop; name the funnel; save and share.
- Funnels are stored in Firestore under `conduit_funnels/{projectId}/{funnelId}`.

### Task 3.5.6 — Funnel visualisation
- Stepped vertical funnel chart showing: step label, session count entering, conversion rate from previous step, drop-off count, drop-off percentage.
- Hover tooltip: exact count, conversion rate, and time-to-convert distribution (P50, P75).
- Click any step: open session list filtered to sessions that entered that step.
- Click any drop-off count: open session list filtered to sessions that dropped off at that step.
- Cross-segment comparison: overlay funnel for two segments (device types, traffic sources, user cohorts) on the same chart with side-by-side bars.

## Definition of done

Rewritten 31/08/26 against the product that exists — a Flutter/Dart SDK and a
Dart ingest service on Firestore — rather than the web SDK and BigQuery
pipeline these criteria were first written for. The originals are kept below
under **Deferred**, because they are a product decision that was made, not work
that was dropped: the product-owner review of 30/08/26
(`_dev/docs/feature_set_review_30_08_26.md`) settled Conduit as Flutter/Dart
first with analytics infrastructure deferred.

- [x] Journey transition matrices are computed over stored sessions
      (`conduit_journeys_test.dart`)
- [x] Funnel definitions save, load and evaluate, with conversion rates and
      drop-off counts (`conduit_funnels_test.dart`)
- [x] The Console renders journeys and funnels, and a funnel has its own route
      (`/conduit/funnels/:funnelId`)
- [ ] Cross-segment comparison overlaying two funnels
- [ ] The diagrams driven in a browser — computed correctly and drawn
      correctly are different claims, and only the first is tested

### Deferred — the web pipeline
- Aggregation expressed as a **query** over BigQuery rather than a computation
  over Firestore documents

