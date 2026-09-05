# Handoff — 05/09/26

Overnight session, then a second pass closing the gaps that stood between the
platform and a real client.

## Read this first

**A client can have exactly one agent today.** Everything the routing,
authority, inventory and secret work was built for is in place and correct.
One thing stands between it and being usable, it is understood, and it is
written up as **F-087** below. That is the first thing to do.

The operator has an empty GCP project waiting. **Do not use it yet** — see
"Before the empty project" at the bottom.

## What works, proven live on `user-test-1`

A customer's WhatsApp message reaches an agent, runs it, and the agent replies
unattended. Verified 04/09 at 19:01: `channel.send` **ok**, run **succeeded**
at sequence 28, `manifold_conversations` carries the exchange.

```
Meta → receiver          verifies the signature, finds which agent answers
     → the AGENT's queue routing is the queue, never the task's URL (F-072)
     → agent runtime     its own service, identity, queue and secrets
     → run               authorised because the registry knows the agent (F-076)
     → channel.send      held or automatic, as published (F-077)
```

Consent is enforced for real: a "STOP" from the test number blocked every reply
until "start" opted back in. Approval gating works in both directions. Refusals
carry their reasons rather than leaking stack traces.

**Suites:** 973 Exigence · 552 Platform API · 27 provisioner · 500 Console.
All repos clean and synced; everything deployed on images carrying every fix
below.

## F-087 — the one blocker, and the first job

Publishing a **second** agent fails with `immutable configuration version
conflicts`.

Provider, pricing and adapter versions are shared by every agent in a project,
at fixed coordinates `(kind, projectId, resourceId, version)`. Their *content*
includes `publishedAt`, the wall clock at publish. So a second agent computes
byte-identical configuration with a different timestamp, the digest differs,
and the store correctly refuses — those coordinates already hold different
content.

The refusal is right and so is the invariant: coordinates identify content,
which is what lets a revision pin a digest and a runtime verify it. What is
wrong is that `publishedAt` varies for a resource whose identity is supposed to
*be* its coordinates.

**Do the second option, not the first:**

* *Deterministic `publishedAt` for shared versions* — simple, and only helps
  going forward. An existing client's stored versions keep their old digests,
  so a new agent still conflicts.
* **Build the bundle against what is already published.** Read the existing
  shared versions at those coordinates and have the new revision pin *their*
  digests rather than newly-computed ones. Correct for existing and new clients
  both, and what "shared" should have meant all along. It changes
  `publishArtifactBundle` and the bundle builders.

I stopped rather than half-implement it: a botched job there corrupts published
artifact history.

## Fixed since the last handoff

| | |
|---|---|
| F-080 | A run stranded mid-step can be cancelled. "Slow" and "abandoned" are told apart by **evidence, not a timer** — Cloud Run's 900s deadline, with one Terraform local driving both the service `timeout` and `CITADEL_STEP_DEADLINE_SECONDS`. Cancellation answers three things now: may still be working (wait), nothing is working and nobody has said so (decide), the operator said so (cancelled, recorded). The Console says **"Nothing is working on this run"** and offers **"Cancel anyway"** instead of "Retry". |
| F-082 | Re-applying a client runtime no longer fails on `409 Database already exists`. It was never the product decision it was written up as: the blocking `for_each` iterated a *resource* instead of the variable driving it, so `terraform import` could not evaluate the config at all. |
| F-084 | An agent may read the channel secrets it replies through. `manifold = null` correctly says an agent has no line to *receive* on, and silently removed the secrets it needs to *send*. |
| F-085 | Reaching the step ceiling ends the run instead of stranding it, with a sentence an operator can read. |
| F-086 | A client *can* have a second agent — the artifact id was a constant, so a second publish would have overwritten the first's history. Blocked in practice by F-087. |

Earlier the same session: F-077 (reply approval, chosen in the Console),
F-078 (agent runtimes visible and drift-checked), F-079 (a settings save cannot
drop an offering), F-081 (the configuration publisher cannot be forgotten),
F-083 (a revision published after boot is the one that loads).

## Still untested, and it matters

Everything above was proven **once, on one client, with one agent, on one test
number**. That is a demo, not a rollout.

- **Two agents in one project** — blocked on F-087. This is the case the whole
  multi-artifact effort exists for and the one thing it has never run with.
- **A genuinely fresh client onboarding.** The bootstrap was re-run on an
  already-admitted project and reported *"All of them were already granted"*,
  so the real path never executed.
- **Anything beyond one message** — no multi-turn conversation, no media, no
  two customers at once, no concurrency of any kind.
- **`axis-education`** has zero provisioning jobs of any template.

## Things that will bite

* **Both templates must be applied** when anything is added to the artifact
  listing. It is served by the *client's* runtime, so an agent-only apply
  leaves the Console showing nothing and looking like the feature failed.
* **Cloud Tasks reserves a deleted queue name for ~7 days.** Rebuilding an
  agent inside a week needs a different slug. This is why the agent is `wa2`.
  Write the slug convention down before a client hits it.
* **`min_instances = 1` is a correctness requirement, not a knob** (F-027).
  One always-on instance per artifact per client. Ten clients × five agents is
  fifty idle instances billed continuously — a pricing question to answer
  before the tenth agent, not after.
* **Cancelling a run does not purge its queued deliveries.** Sixteen
  compensated runs left tasks retrying against a runtime that refuses them.
* **Meta was blocking the test line** at the end of the session
  (`API access blocked, code 200`), after the night's volume. Their side.
  Expect it to clear; if not, check the app's standing in Meta's console.
* **A correct refusal and a real failure look identical from a trace span**
  carrying `status: error` and nothing else. The consent refusal knows exactly
  why it refused and the span does not keep it. That cost an hour of hunting a
  bug that did not exist, and is a good small thing to improve.

## Before the empty project

In this order, all on `user-test-1`:

1. **F-087**, then publish the second agent for real and confirm both answer
   their own channels.
2. A **multi-turn conversation**, an image, two customers overlapping.
3. Write down the **agent slug convention** and the 7-day queue rule.

Then take the empty GCP project and run a real onboarding end to end. Doing it
before F-087 means debugging two unknowns at once.

## State of the test client

`user-test-1`'s agent is set to **Send automatically** — that is how it was
verified. Switch it back in the Console (Exigence → Automations → Superharness
→ Replies) if you would rather it not answer unattended. The test number
`+6597895638` is currently opted **in**. One run is deliberately left in the
stranded state as evidence for F-080; it can now be cancelled through the
Console.
