# Feature 1.4 — ARM Alerting, SLOs, Release Health and OTel Alignment (NEW)

## Scope
Close ARM's parity gap with Sentry/Crashlytics-class tooling: clients must be proactively notified of urgent issues, see release health, and track SLOs — while preserving ARM's differentiators (recovery snapshots, client-owned evidence, operator-embedded triage). Extends arm_tooling_core/server and the ARM Console pages consolidated under citadel_core/arm.

## Tasks

### Task 1.4.1 — Alert rules and notification pipeline
- Per-project alert rules stored in project config: new-issue (first occurrence of fingerprint), threshold (≥N cases of a fingerprint in window W), severity-based (data-integrity class always alerts), and regression (previously resolved fingerprint reoccurs).
- Evaluation runs inside the monitored project's boundary: a scheduled Cloud Function (deployed via the onboarding kit, Feature 0.7) evaluates rules against the project's own Firestore — evidence data does not leave the client project.
- Channels v1: email + generic webhook; alert documents recorded so the Console shows alert history; per-rule mute/snooze; dedupe window to prevent storms.

### Task 1.4.2 — Release health
- arm_tooling: attach appVersion/buildNumber (and optional releaseChannel) to every case and telemetry record at init.
- Console: per-release view — new fingerprints introduced, crash-free-session proxy (sessions without error cases / total sessions from existing telemetry), adoption curve per version; regression tagging when an old fingerprint reappears in a newer release.

### Task 1.4.3 — SLOs and error budgets (lightweight)
- Per-project SLO definitions on existing telemetry (e.g., p95 route-load latency, error-case rate); monthly error-budget computation with burn display on the Overview page next to the urgent queue.
- SLO breach can feed Task 1.4.1 alert rules; these SLO summaries are a first-class input to Conduit's ROI reports (Feature 3.9).

### Task 1.4.4 — OTel semantic alignment pass
- Field-map audit of ARM telemetry/case schemas against OTel log/trace semconv (exception.*, service.version, session.id, http.*, etc.); add missing standard fields as aliases without breaking existing documents; document the map in _dev/docs.
- Purpose: keeps ARM data portable/exportable and consistent with Exigence's GenAI-conv traces — one coherent semantic layer across the platform.

### Task 1.4.5 — Console wiring
- Alert rule CRUD (superuser/developer), alert history page, release selector on Explorer/Reports, SLO card on Overview. Explicit no-data states; production-visible copy.

## Definition of done
- [ ] Threshold and new-issue alerts fire end-to-end from a monitored test project to email + webhook, with dedupe verified
- [ ] Evidence-boundary check: alert evaluation reads only within the monitored project; Citadel project receives notification metadata only
- [ ] Release health view renders from real version-tagged cases; regression tagging verified across two versions
- [ ] SLO burn visible on Overview; breach triggers an alert in test
- [ ] OTel field map documented; flutter analyze zero warnings across arm packages and console
