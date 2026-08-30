# Feature 4.6 — Exigence Billing (NEW 14/08/26)

## Scope
Itemised cost tracking, analysis, budgeting, invoicing and payment collection.
Answers "what did this cost, who incurred it, and which cloud component was it"
down to the individual execution, and turns that into an invoice a client can
pay.

Depends on Features 4.1 and 4.5.

## Cost model — self-metering is the execution attribution source
Client workloads use per-client project boundaries, which improves invoice
reconciliation but does not itemise spend by run, artifact, step or effect.
Everything below therefore rests on Citadel's own execution metering and uses
provider billing only as a cross-check.

- **Self-metered, per execution, itemised by component**: model tokens (already
  exact to the nano), Cloud Run compute-ms, Firestore reads/writes, GCS bytes,
  Cloud Tasks dispatches — priced from versioned effective-dated SKU profiles
  using the existing pricing mechanism.
- **Cross-check at the client project boundary.** Mandatory labels refine the
  comparison, while the provider invoice verifies project totals rather than
  individual executions.
- **Reconcile monthly per client and platform-wide**: metered spend versus the
  real invoices. Store the variance and surface it honestly in the UI; never
  present a metered figure as invoice truth.

## Task 4.6.1 — Metering accuracy
BigQuery billing export remains **deferred** on cost and complexity grounds.
Start with provider invoice/CSV reconciliation and revisit an export pipeline
only when its automation value justifies the standing cost.

Instead:
- Instrument every cost component at the point of consumption, not by estimation
  after the fact.
- Validate metering accuracy against the real invoice over one full month before
  any invoice is issued to a client. Record the result in `_dev/docs/`.
- Fail closed on missing or ambiguous pricing, as model pricing already does.

## Task 4.6.2 — Self-metering
- Instrument the runtime to emit a cost record per execution, itemised by
  component, attributed to artifact and run.
- Reuse the existing nano-unit decimal-string currency representation and
  versioned effective-dated price profiles. Fail closed on missing or ambiguous
  pricing, as model pricing already does.
- Roll up: execution → artifact → project → month.

## Task 4.6.3 — Analysis views
Modelled on the GCP billing console:
- Spend over time, with grouping by service, SKU, artifact, execution and
  trigger source.
- Filters by date range, artifact, type and cost component.
- Saved reports and CSV export.
- Budgets with thresholds and alerts, extending the existing per-project monthly
  cap rather than replacing it.
- Every chart through `citadel_charts.dart`; every table through
  `citadel_table.dart`. No bespoke chart code.

## Task 4.6.4 — Invoicing
- Citadel generates the invoice: line items derived from its own metered and
  reconciled cost, plus operator-defined service fees and margin.
- Invoice states: draft → issued → paid / overdue / void. Immutable once issued;
  corrections are credit notes, never edits.
- Client-visible invoice view scoped by Palisade role.

## Task 4.6.5 — Payment
- When a client chooses to pay, the issued invoice is handed to Stripe and
  payment status is reported back to Citadel.
- **Stripe is the processor only.** Citadel remains the source of truth for cost
  and invoice content. Never derive a line item from Stripe.
- Webhook handling for payment status must be signature-verified and idempotent,
  reusing the Feature 4.2 webhook envelope discipline.
- Billing-account and payment-method configuration per client.

## Definition of done
- [x] No BigQuery resource is created — nothing in the Exigence or provisioner
      Terraform references BigQuery, and the deferral stands.
- [ ] Metering accuracy is validated against one full month's real invoice
      before any client invoice is issued — **not yet performed**, and
      deliberately not fudgeable: `assertMonthIsReconciled` refuses to issue
      from an unreconciled month in code, so this box gates itself. Method in
      `_dev/docs/metering_accuracy_validation.md`.
- [x] An execution shows itemised cost by component summing to its total —
      and the total is the lines, so the two cannot disagree.
- [x] Costs roll up correctly execution → artifact → project → month — the
      month's summary rolls up the same executions it itemises.
- [x] Metered totals reconcile against the real invoice with a stored variance
      factor — including the direction: metering reads high, so a factor below
      1.0 is the expected result rather than a fault. What has not happened is
      the reconciliation itself, against a real month; see above.
- [x] The UI never presents a metered figure as invoice truth — a metered
      figure says it is not a bill without being asked, and a reconciled one
      still says it is an estimate.
- [ ] Cloud Run spend cross-checks against the `client` label in billing data
      — the services carry the label and infrastructure cost is metered per
      component, but nothing reads Google's billing export to compare. Part of
      the same unperformed validation above.
- [x] Budgets alert and hard-stop at threshold — one crossing is one message
      rather than one per threshold passed, a threshold beneath the announced
      one never fires late, and the reservation stops the spend rather than
      reporting it.
- [~] An invoice issues, is paid through Stripe, and status returns to
      Citadel — built and covered end to end over a stubbed Stripe, including
      the webhook signature, staleness and short-payment cases. Not yet run
      against a real Stripe account.
- [x] Duplicate Stripe webhook delivery does not double-record a payment — a
      repeated notification is not an error, and the invoice is marked paid
      once however it comes back.
- [x] Issued invoices are immutable; corrections are credit notes — issuing
      twice is refused rather than quietly re-dated, and a credit note cannot
      take an invoice below nothing.
- [x] No cost figure is ever fabricated — an unpriced component fails closed
      rather than costing nothing, a run missing a meter this deployment
      records is reported as partly measured, and a component a run simply did
      not use is not reported as a missing meter.
