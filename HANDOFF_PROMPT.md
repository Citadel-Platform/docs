# Handoff — 05/09/26, morning

Overnight session. The WhatsApp agent works end to end and answers customers by
itself. Getting there found seven defects, all fixed and deployed except two
that need a decision from you.

## Where to start

Read **"Open, and each needs a decision"** below. Everything else is done and
verified live; those two are the only things waiting on a person.

## What works now, proven on `user-test-1` rather than in a test

A customer's WhatsApp message reaches the agent, runs it, and the agent replies
without anybody in the console. The last verification run shows six
`execute_tool channel.send` spans, unattended, on revision 2.

The path, and the thing that was broken at each step:

```
Meta → receiver          verifies the signature, finds which agent answers
     → the AGENT's queue routing is the queue, never the task's URL (F-072)
     → agent runtime     its own service, its own identity, its own queue
     → run               authorised because the registry knows the agent (F-076)
     → channel.send      held or automatic, as published (F-077)
```

**Live state.** All three Cloud Run services in `testproj-448205` are on the
current runtime image. Platform API, provisioner and Console are all deployed
from `main`. Suites: **966** Exigence, **550** Platform API, **27** provisioner,
**499** Console.

## Open, and each needs a decision

### 1. A run stranded mid-step cannot be cancelled (F-080)
A step that was in flight when its instance was recycled waits for evidence
that can never arrive. The run cannot proceed and cannot be cancelled, and the
refusal is correct — the tool may already have put a message on somebody's
phone, and undoing the run without knowing that would be worse.

The refusal is now legible (409 with its own sentence, not a 502). What is
missing is a way out. Two honest options:
* a supervisor that ages in-flight activities out after a bounded wait;
* an explicit operator override that records the evidence was never coming.

The second is safer and duller. The first is what stops a person having to
notice. **One run is sitting in this state right now** — deliberately, as
evidence.

### 2. Re-applying a client runtime fails on its own database (F-082)
`exigence-runtime` on a client who already has Manifold fails with
`409 Database already exists`, after having updated everything else. The
database is created with `deletion_policy = ABANDON` because it holds a
client's customers' messages, so state and reality drift apart permanently.

Adopting it with `terraform import` is the right idea and currently dies on an
unrelated `Invalid for_each argument` — `import` evaluates the whole
configuration and that `for_each` cannot resolve without a plan. The runner now
prints Terraform's own words instead of a reassuring "nothing to adopt".

Three ways out are in `PRODUCTION_PUSH_AND_TEST.md` under F-082. **Making the
`for_each` resolvable is the smallest**; the others change what a teardown
does, which is not a 2am decision.

**Not blocking.** Every service is deployed and healthy; this costs a red
provisioning job on re-apply.

## Fixed overnight

| | |
|---|---|
| F-077 | An agent can be published to answer unattended, chosen in the Console rather than the CLI. The choice is declared on the graph **and** expressed in the policy, and the runtime refuses a revision where the two disagree — because a permission missing from a list is indistinguishable from an oversight, on the one decision where an oversight puts unreviewed words on a stranger's phone. |
| F-078 | An agent's runtime is a resource the inventory shows, with drift observed per agent. It was a second always-on service the client paid for and nobody could see. |
| F-079 | A settings save cannot silently drop an offering. `ProjectOfferingScope` is freezed with a default on every field, so an omission compiles and deletes what the operator had — which is how Manifold was dropped. |
| F-080 | A run waiting on in-flight evidence answers 409 with a reason, not 502. |
| F-081 | The configuration publisher cannot be forgotten. It was optional for one build, the production wiring omitted it, and the console said "the platform rejected these values". Now required: three compiler errors instead of a runtime refusal. |
| F-083 | A revision published after boot is the one that loads. The runtime cached its configuration for the life of the process, so the new reply setting published correctly and changed nothing. Found by using the feature it broke. |

Also: template validation in the suite (every template, `terraform validate`,
eleven seconds, discovered not listed), the type ramp lifted two points at the
bottom where dense tables live, and five passages of product prose cut to the
fact they carried.

## Things worth knowing before you touch this

* **Both templates must be applied** when anything is added to the artifact
  listing. The listing is served by the *client's* runtime, so an agent-only
  apply leaves the console showing nothing and looking like the feature failed.
* **Cloud Tasks reserves a deleted queue name for ~7 days.** Tearing down and
  rebuilding an agent inside a week needs a different slug. This is why the
  agent is `wa2`.
* **`min_instances = 1` is a correctness requirement, not a knob** (F-027).
  A run's kickoff returns before its callback arrives, so scale-to-zero
  recycles the instance in between and the run fails at step 1.
* **Cancelling a run does not purge its queued deliveries.** Sixteen
  compensated runs left tasks retrying against a runtime that refuses them.
  Worth a purge on compensation.
* **`test-sandbox`** stays Exigence-blocked until ~09/09/26 on the queue-name
  reservation. `user-test-1` supersedes it.

## One thing to watch

The verification run made **six** `channel.send` calls in one run — one per
step of its six-step budget. That is within what it was published with, but an
agent that answers a customer six times is not what anybody wants. Worth
deciding whether the superharness should stop after its first reply.
