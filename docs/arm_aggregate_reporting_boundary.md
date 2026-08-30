# ARM Aggregate Reporting Boundary

ARM aggregate exports from the shared Citadel Platform surface are limited to derived, low-sensitivity rollups.

## Allowed export shape

- daily issue counts by project, environment, and severity
- case count trends and repeat-offender frequency
- latency, retry, and throughput trend summaries when they are already normalized
- project health posture summaries used for cross-project operator dashboards

## Not exported to the shared analytics boundary

- raw case payloads
- full stack traces
- screenshots
- breadcrumbs
- recovery snapshots
- customer-entered or case-local contextual evidence

## Rationale

The platform-owned `citadel-platform` boundary can safely host operator-facing rollups, but raw ARM evidence remains tied to the monitored project's own Firebase boundary unless an explicit approval and migration path is introduced later.
