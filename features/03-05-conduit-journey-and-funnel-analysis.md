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
- [ ] Journey aggregation query produces correct transition matrices for test project data
- [ ] Sankey diagram renders correctly and is interactive (click to filter)
- [ ] Sunburst diagram renders correctly and is interactive
- [ ] Funnel builder saves and loads funnel definitions correctly
- [ ] Funnel chart shows correct conversion rates and drop-off counts
- [ ] Cross-segment comparison overlays two funnels correctly

