# Metering accuracy validation

**Status: not yet performed.** No client invoice may be issued until it has
been, and `assertMonthIsReconciled` enforces that in code rather than leaving
it to this document.

## Why this exists

Every client shares the `citadel-platform` project (DECISIONS.md 14/08/26), so
Google's billing data cannot attribute shared-resource cost per client.
Citadel's own metering is the only per-client attribution there is — which
makes it the source of every client-facing number, and makes its accuracy
something that has to be demonstrated rather than assumed.

Feature 4.6 requires one full month validated against a real invoice before any
client invoice is issued. This is where that result goes.

## What is being compared

Not "is metering right", which has no answer. The comparison is between two
differently-derived numbers whose difference is expected and explainable:

| | Metering | Google's invoice |
|---|---|---|
| Basis | Citadel's own counts | Google's own counts |
| Prices | List, from versioned profiles | List, after adjustments |
| Free tier | Not deducted — it belongs to the project, not to a client | Deducted |
| Sustained/committed use | Not applied | Applied at project level |
| Scope | Per client, per run, per component | Per project, per SKU |

Metering will therefore read **high**. A variance factor below 1.0 is the
expected result, not a fault, and `reconciliation.ts` treats it that way.

## Method

1. On the first working day after month end, export the previous month from the
   billing console as CSV. That export is the only permitted source; a figure
   Citadel computed reconciling against a figure Citadel computed proves
   nothing.
2. Sum Citadel's metered total for the same period across all projects.
3. Record both through `PUT /v1/projects/{p}/exigence/billing/reconciliations/{month}`,
   which computes and stores the variance factor and refuses one that does not
   follow from its own inputs.
4. Compare component by component where the billing export permits it. Only
   Cloud Run can be attributed per client, through the mandatory `client` label
   the runtime module sets on every resource. Firestore, GCS and Cloud Tasks are
   shared and unattributable from billing data — for those, only the platform
   total is comparable.
5. Write the findings below, including anything that does *not* reconcile.

## Known undercounts, to expect in the variance

These are places metering is deliberately short. They are listed so a variance
that includes them is not investigated as a mystery:

- **Cloud Tasks deliveries.** Each task is billed for its create *and* for each
  push delivery attempt. Only the create is visible from the enqueueing side.
  See `MeteredTaskDispatcher`.
- **GCS class B on payload collision.** A colliding write falls back to reading
  the existing object to verify it matches. Rare and bounded. See
  `MeteredPayloadObjectStore`.
- **Anything running outside a metered delivery.** Scheduled dispatch, webhook
  verification and the Console's own reads consume Firestore and are not
  attributed to any run — correctly, since they belong to no run, but they are
  real cost that appears only in the platform total.
- **Storage.** Billed by time rather than by execution, so it is a monthly
  figure and not part of any run's itemisation.

## Result

_Not yet recorded._

| Month | Metered | Invoiced | Variance | Notes |
|---|---|---|---|---|
| — | — | — | — | — |

## What would make this fail

The variance moving sharply between months without the platform's shape having
changed. `varianceDrift` reports the month-to-month movement; it deliberately
does not judge it, because what counts as alarming depends on what changed, and
only a person knows that. A large negative move usually means a meter stopped
reporting; a large positive one usually means a component nobody priced started
being consumed.
