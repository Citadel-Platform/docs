# Feature 3.6 — Web Analytics Overview

## Status
Active. Depends on Feature 3.2.

## Scope
Build the Web Analytics Overview module: a first-party traffic analytics dashboard providing session, visitor, and traffic source context.

## Tasks

### Task 3.6.1 — Web analytics aggregation queries
- Define BigQuery scheduled queries for: daily session counts, unique visitor counts (by visitorId), pageview counts, bounce rate, average session duration, pages-per-session, and exit rate per URL.
- Traffic source attribution: parse UTM parameters from referrer and URL; classify sessions into organic, direct, paid, referral, social.
- Device and browser breakdown aggregations.
- Geographic breakdown by country and city.

### Task 3.6.2 — Overview dashboard
- Summary row: sessions, unique visitors, pageviews, bounce rate, avg. session duration, pages/session — all with delta vs. comparison period.
- Primary line chart: sessions and pageviews over time (hour/day/week granularity selector).
- Real-time widget: active visitors in the last 5 minutes with a live-updating count and a mini table of currently active pages.

### Task 3.6.3 — Traffic source breakdown
- Doughnut or horizontal bar chart showing session count by source: organic, direct, paid, referral, social.
- Drill-down: click a source to see the top referral domains or UTM campaigns.

### Task 3.6.4 — Top pages table
- Paginated table: URL pattern, pageviews, unique visitors, avg. time on page, bounce rate, exit rate.
- Click a row: navigate directly to the Heatmaps module filtered to that URL pattern.

### Task 3.6.5 — Device and geographic breakdowns
- Bar chart: sessions by device type (desktop, tablet, mobile) with OS and browser sub-breakdown.
- Map widget: sessions per country as a choropleth map with tooltips.
- City table for drilldown.

### Task 3.6.6 — New vs. returning visitors
- Line chart splitting sessions into new visitor sessions vs. returning visitor sessions over time.
- Summary: new visitor rate, returning visitor rate, avg. sessions per returning visitor.

## Definition of done

Rewritten 31/08/26 against the product that exists — a Flutter/Dart SDK and a
Dart ingest service on Firestore — rather than the web SDK and BigQuery
pipeline these criteria were first written for. The originals are kept below
under **Deferred**, because they are a product decision that was made, not work
that was dropped: the product-owner review of 30/08/26
(`_dev/docs/feature_set_review_30_08_26.md`) settled Conduit as Flutter/Dart
first with analytics infrastructure deferred.

- [x] Daily metrics are computed from stored sessions
      (`conduit_analytics_test.dart`)
- [x] The overview renders its widgets from those metrics
- [ ] A live visitor count that updates without a refresh
- [ ] Traffic source classification — UTM-tagged against organic. The fields
      arrive; nothing classifies them
- [ ] Top pages linking through to the matching heatmap surface

### Deferred — the web pipeline
- Aggregation expressed as scheduled **queries** rather than as a computation
  over Firestore documents


## Task 3.6.5 — Dashboard declutter (NEW 30/08/26)

From the feature-set review: the overview page carries long descriptive panels
about SDK capability alongside the numbers. Those belong in documentation, not
on the screen somebody opens to find out how the product is doing.

Keep: metrics, charts, summaries, the numbers that matter. Remove the
capability prose.

- [ ] The overview page is metrics, charts and summaries with no reference
      material on it
