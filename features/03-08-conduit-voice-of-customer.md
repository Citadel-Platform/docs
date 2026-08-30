# Feature 3.8 — Voice of Customer (Feedback, Polls & Surveys)

## Status
Complete. Depends on Features 3.1 and 3.2. Production Cloud Run and Terraform
provisioning remain deferred infrastructure work; the hosted service, container
entrypoint, publication flow, and local executable verification are complete.

### 18/07/26 implementation audit
- **Implemented and executable:** Flutter feedback, poll, and branching-survey
  widgets; direct authenticated submission; customer-boundary persistence;
  authoritative definitions and runtime delivery; first-visit, time-on-page,
  scroll-depth, and explicit custom-event triggers; response analytics, CSV,
  pagination, and exact Session Replay links.
- **Superseded by settled Flutter-native decisions:** `html2canvas`, CSS custom
  properties, cursor exit intent, and CSS-selector click triggers. Screenshot
  capture remains a host-provided Flutter callback/RepaintBoundary path;
  low-level workflow/element triggers use explicit target-app event wiring.
- **Emulator verified:** the isolated `demo-citadel-voc` harness joins rendered
  feedback, poll, and branching-survey widgets to remote config, Shelf HTTP
  ingest, and real Firestore emulator documents under deny-all client rules.
- **Hosted shareable surveys implemented:** opaque deployment IDs, revisioned
  projected definitions, scoped short-lived anonymous respondent tokens,
  strict response validation, abuse limits, and authenticated customer-boundary
  proxy submission are executable through the Cloud Run-ready service binary.

## Scope
Build the Voice of Customer module: feedback widgets, on-site polls, multi-question surveys, NPS, and the survey analytics dashboard.

## Tasks

### Task 3.8.1 — Feedback widget
- SDK plugin that renders a persistent feedback button on the client's page (position, colour, and label configurable from the Conduit Console).
- On click: expands to a small panel with a sentiment selector (1–5 star or emoji scale) and an open-text input.
- Optional annotated screenshot: capture a `html2canvas` screenshot and allow the user to draw an annotation on it.
- Submit action: sends feedback payload to `POST /v1/voc/feedback` with `sessionId`, `visitorId`, `url`, `sentiment`, `text`, `screenshotUrl`.
- Storage: Firestore `conduit_feedback/{projectId}` collection.

### Task 3.8.2 — On-site polls
- Poll builder in Console: question text, response type (single choice, open text, NPS scale 0–10, star rating), display trigger, targeting rules, and active/inactive toggle.
- Trigger conditions: time on page (N seconds), scroll depth (N%), exit intent (cursor approaching top of viewport), element click (CSS selector), custom event (event name), or first visit.
- Targeting: URL pattern match, device type, visitor segment, frequency cap (max once per visitor per N days).
- SDK: the config API serves active poll definitions; the SDK evaluates triggers client-side and renders the poll widget.
- Poll widget: clean inline overlay, customisable to match the client's brand colours via CSS custom properties.
- Submit action: sends poll response to `POST /v1/voc/poll-responses` with session context.
- Storage: BigQuery `conduit_poll_responses` table for analysis; Firestore for real-time count.

### Task 3.8.3 — Multi-question surveys
- Survey builder in Console: add/remove questions, set question types (single choice, multi-choice, open text, rating scale, NPS, likert), define conditional branching logic (show question B only if answer to A equals X).
- Deployment modes: embedded on-page widget, triggered pop-up (same trigger conditions as polls), or shareable survey URL.
- Survey URL: a standalone hosted page at `conduit.citadel.app/s/{surveyId}` rendered from the survey definition.
- Submit action: sends full response to `POST /v1/voc/survey-responses`.
- Storage: BigQuery `conduit_survey_responses` table; each response includes `sessionId` (null if off-site) and all answer values.

### Task 3.8.4 — Survey analytics dashboard
- Per-survey dashboard: response count, completion rate, average NPS score (if applicable), per-question response breakdown (bar charts for choice questions, word cloud and theme list for open text).
- Response list: paginated table of individual responses with timestamp, device, session replay link (if session context exists).
- Word frequency cloud for all open-text responses in a selected date range.
- Export: CSV of all responses.

### Task 3.8.5 — Session replay linking for VoC
- For any poll or survey response that includes a `sessionId`, provide a "View session replay" button that deep-links to the Session Replay player for that session.

## Definition of done
- [x] Feedback widget renders on an emulator-backed test page and submissions appear in Firestore
- [x] Polls fire at the supported Flutter trigger conditions (time, scroll, first visit, explicit custom event)
- [x] Survey builder creates a survey definition that deploys correctly as a widget and via shareable URL
- [x] Survey analytics dashboard shows correct per-question breakdowns
- [x] Session replay linking from survey responses opens the correct session
