# ARM Intake Gateway Posture

ARM continues to use direct Firestore writes with optional Storage uploads as the default ingestion mode.

## Current posture

- `arm_tooling` writes directly to the monitored app's Firebase boundary
- the ARM Console reads monitored-project evidence through registered client project access
- the platform web shell uses a local preview sink for self-monitoring until platform-owned persistence is intentionally introduced

## Intake gateway remains deferred

Introduce a dedicated intake gateway only if one of these becomes concrete:

- stronger centralized validation is required
- client-side write rate limiting becomes necessary
- events must fan out to multiple sinks
- non-Firebase clients need first-class support
- access control must move from project-local rules to a stricter central boundary

Until one of those conditions is real, a gateway adds complexity without improving the current direct-ingestion architecture enough to justify it.
