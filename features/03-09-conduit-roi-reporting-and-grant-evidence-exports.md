# Feature 3.9 — Conduit ROI Reporting and Grant Evidence Exports (NEW)

## Status
Deferred by the Feature 0.0 priority ladder until Feature 0.7, Feature 1.4, and
Features 4.1–4.3 provide the retention/licensing, release/SLO, and automation
evidence contracts consumed here.

### 18/07/26 dependency audit
- Existing Conduit data can support anonymous active-visitor counts, custom
  event counts, funnel conversion/duration, web analytics, VoC summaries, and
  synthetic uptime, all with customer-boundary reads and explicit windows.
- Task-completion release deltas and ARM case-rate reduction are not executable
  yet because Conduit events and ARM cases do not share the Feature 1.4 release
  identity contract.
- Reliability must consume Feature 1.4.3 SLO summaries, which do not yet exist;
  synthetic uptime is useful evidence but is not a truthful substitute for a
  configured SLO.
- Exigence outcome evidence depends on the reactivated 4.1–4.3 runtime and
  observability schemas; no successful-run or human-minute records exist yet.
- Case-study consent and report retention must come from Feature 0.7's project
  manifest. The current SDK telemetry retention setting is not the contractual
  research-license/artefact-retention source required by this feature.
- Exact grant fields remain deliberately open until the first grant-funded
  client's approval letter is available. No mapping should be invented early.
- The first safe implementation slice after prerequisites is a pure, typed
  outcome evaluator that returns value or explicit gap plus immutable baseline
  provenance; scheduled PDF/email/GCS infrastructure follows only after that
  core is verified against real/emulator data.

## Scope
Turn Conduit's analytics into sellable, grant-grade business evidence: scheduled ROI reports and export packs that map to Singapore grant reporting needs (PSG/EDG → EDGE) and double as WHS case-study material. Builds strictly on existing Conduit ingestion, funnels, and experience monitoring (3.1–3.7) — no new capture surfaces.

## Context
SME clients funded through grants must report measurable outcomes (cost/time savings, adoption, reliability). Making that evidence one click away is a differentiator no generic analytics competitor ships, converts renewals, and produces quantified case studies. Metrics must be computed from real Conduit/ARM data only — never modelled or fabricated (hard rule #1); where a target metric needs an assumption (e.g., hourly labour cost), the assumption is an explicit, client-entered config value printed on the report.

## Tasks

### Task 3.9.1 — Outcome metric definitions
- Per-project configurable outcome metrics with typed formulas over existing data: task-completion time deltas (funnel duration before/after a marked release), error-rate reduction (ARM case rate per session, joined via project + version), adoption (active users, feature-event uptake), reliability (SLO attainment from Feature 1.4.3), and Exigence automation outcomes (runs succeeded, human-minutes saved = client-entered per-run estimate × successful runs).
- Baseline pinning: snapshot a baseline window; all deltas reported against it with the window printed.

### Task 3.9.2 — Report generator and scheduler
- Report templates (monthly ops report; grant evidence pack; case-study extract) rendered to PDF + CSV appendix via a Cloud Run job; delivered by email link and stored in the client project's GCS with configurable retention.
- Scheduler per project (Cloud Scheduler); on-demand generation from Console with date-range override.
- Every figure in the PDF carries a data-source footnote (collection + query window) so reports are auditable.

### Task 3.9.3 — Console reporting pages
- Reports page under Conduit: template config, schedule, history, download; outcome-metric editor with live preview against real data; explicit not-configured/no-data states.
- Case-study extract view: anonymised-by-default variant (client name/branding stripped) for WHS marketing use, gated behind the project's consent flag (Feature 0.7 licensing config).

### Task 3.9.4 — Grant-evidence mapping doc
- _dev/docs page mapping each template section to typical PSG/EDG/EDGE reporting asks (productivity gains, digitalisation adoption, before/after baselines), maintained as grants evolve. [OPEN: confirm exact evidence fields with the first grant-funded client's approval letter; record in DECISIONS.md.]

## Definition of done

Rewritten 31/08/26 against the product that exists — a Flutter/Dart SDK and a
Dart ingest service on Firestore — rather than the web SDK and BigQuery
pipeline these criteria were first written for. The originals are kept below
under **Deferred**, because they are a product decision that was made, not work
that was dropped: the product-owner review of 30/08/26
(`_dev/docs/feature_set_review_30_08_26.md`) settled Conduit as Flutter/Dart
first with analytics infrastructure deferred.

- [x] `flutter analyze` is clean, and the Console renders the reports route
- [ ] A monthly report generated on a schedule for a real project, with a
      source footnote on every figure
- [ ] The grant evidence pack: baseline against current over pinned windows,
      with missing data shown as an explicit gap rather than an interpolated
      number. **This is the box to protect** — a report that quietly fills a
      hole is worse than no report, because somebody submits it
- [ ] Case-study extraction honouring the consent flag and anonymising
- [ ] Reports stored client-side with retention honoured, Citadel holding
      pointers only
- [ ] The report job covered by an integration test against emulator data

None of this is deferred; it is unbuilt, and it sits downstream of the
analytics it reports on.
