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
- [ ] All aggregation queries produce correct daily metrics for test project data
- [ ] Overview dashboard renders all widgets with correct data
- [ ] Real-time visitor count updates without page refresh
- [ ] Traffic source breakdown correctly classifies UTM-tagged and organic sessions
- [ ] Top pages table links correctly to the Heatmaps module

