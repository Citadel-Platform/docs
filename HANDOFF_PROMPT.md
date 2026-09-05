# Handoff — 05/09/26, late

**A client can have as many agents as they want, and the console is how they
get one.** That sentence is the whole of what changed today. The previous
handoff opened by saying a client could have exactly one; F-087 was why, and it
is fixed and proven live.

## What is true now

`user-test-1` holds three superharness artifacts. One of them,
`exigence.superharness.bookings-desk`, was created end to end from the console
by a signed-in operator: named, instructed, given a ceiling and a reply policy,
and published. Its Palisade authority came from the deployment, never from the
browser.

Everything of 04/09 still holds: a customer's WhatsApp message reaches an
agent, runs it, and the agent replies unattended. Consent is enforced against
the ledger. Routing follows the artifact because every Exigence queue rewrites
the host.

## What is finished, and what it took

An agent created from the console now gets a runtime from the same page, and
that runtime stands beside the client's existing agents rather than on top of
them:

```
cit-user-tes-f111-runtime   exigence.superharness               (untouched)
cit-user-tes-5bc3-runtime   exigence.superharness.refunds-desk  (new, Ready)
```

Getting there needed F-091 (the coordinates an agent's runtime is built from
are recorded by the client's build, not typed by a caller) and F-095, which is
the one to read about below.

## What today's defects have in common

Five were found and fixed: F-088, F-089, F-090, F-091, F-093. Four of them
were found by *using the page*, not by reading the code or the tests. The last
one is the clearest: every unit test on the agent path used a single-word
name, so nothing caught that `agent_id` refused the hyphen the console's own
slug produces. The form could not create an agent called "Bookings Desk".

**F-095 is the one to read first.** Building a client's second agent planned
`23 to add, 0 to change, 23 to destroy` — the 23 being the whole of the agent
answering that client's live WhatsApp line. The runner kept one Terraform state
per template per project and said so in a comment that was true of every
template until, that same morning, a client could have more than one agent. An
agent's state now carries its slug. Found by reading a plan the console had
produced and was about to offer for approval; never applied.

F-090 is the other one worth reading twice. Every client build downloaded its
providers from registry.terraform.io, from a fresh container with no cache.
The registry rate-limited it. What the operator was shown was not the 429 — it
was the empty lock file the failed download left behind, because the runner
ran `init` and never checked it. Providers are mirrored into the image now and
`init` is checked; but the general lesson is that a swallowed exit code turns
a fixable failure into a misleading one.

## Still untested

- **The new agent has never run.** Its runtime is up and registered; nothing
  has been started on it.
- Two agents answering their own channels. This needs a second WhatsApp
  number; the one test number is bound to `exigence.superharness`.
- A multi-turn conversation, an image, two customers overlapping.

## Before the empty GCP project

Do the list in `CURRENT_TASK.md` in order. Onboarding a fresh project before
two agents have been seen answering means debugging two unknowns at once.

## Things that will bite

- Cloud Tasks reserves a deleted queue's name for about seven days, and the
  name comes from the client id. `test-sandbox` stays blocked until ~09/09/26.
- `min_instances = 1` is a correctness requirement (F-027), not a knob. It is
  also one always-on instance per artifact per client. Answer the cost
  question before the tenth agent.
- Cancelling a run does not purge queued deliveries.
- The root state files are not in any git repo. The repository root is not a
  repository.


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

## Fixed since the last handoff

- **F-087** a second agent publishes against the shared versions already
  stored. Proven live: all four reported as adopted.
- **F-088** adding an agent is a console page. `POST …/exigence/agents`, gated
  on `exigence.agents.publish`.
- **F-089** an agent is called what it was named.
- **F-090** a client build no longer reaches the public provider registry, and
  a failed `init` is reported rather than swallowed.
- **F-091** an agent's runtime coordinates are resolved from what the client's
  build recorded, not taken from the caller.
- **F-093** an agent may have a two-word name.
- **F-095** a client's second agent no longer destroys their first. Verified
  live: `23 to add / 23 to destroy` became `32 to add / 0 to destroy`, applied,
  and both runtimes now stand.

Full write-ups in `_dev/PRODUCTION_PUSH_AND_TEST.md`.

## State of the test client

`user-test-1`, on GCP `testproj-448205`, Exigence and Manifold on.

| artifact | rev | name | triggers |
| --- | --- | --- | --- |
| `exigence.reference.summary` | 1 | Reference summary | manual |
| `exigence.superharness` | 2 | Superharness | manual, conversation (`whatsapp`) |
| `exigence.superharness.deliveries` | 1 | Superharness | manual |
| `exigence.superharness.bookings-desk` | 1 | Bookings Desk | manual |
| `exigence.superharness.returns-desk` | 1 | Returns Desk | manual |
| `exigence.superharness.refunds-desk` | 1 | Refunds Desk | manual |

`deliveries` was published from the command line to prove F-087 and carries the
old shared display name; the other three were created from the console. Three
Cloud Run runtimes exist: the client's own (`acb1`), `exigence.superharness`'s
(`f111`) and `refunds-desk`'s (`5bc3`). `deliveries`, `bookings-desk` and
`returns-desk` have none — see F-094, which is why they cannot be given one
from the console yet.

**Suites:** 986 Exigence · 557 Platform API · 34 provisioner · 507 Console.
All repos clean and synced. The root state files are not in any git repo.
