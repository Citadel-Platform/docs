# Handoff — 05/09/26, evening

**An agent's whole life is a Console action now.** Create it, give it a
runtime, start it, switch it off. That sentence is what changed today, and
every defect below was found on the way to being able to say it.

## One thing needs you, and nothing else can move without it

**Meta has blocked the WhatsApp channel.**

```
ChannelRefusedError: whatsapp refused the message:
Meta refused the message: API access blocked. (code 200)
```

The same channel sent successfully on 04/09 at 19:01. Code 200 is a permission
or capability problem, and the likeliest cause is that the access token in
Secret Manager was a temporary one — those last 24 hours, and 04/09 19:01 is
about that long before this started failing.

**Issue a permanent WhatsApp access token and update the channel secret**, or
confirm the Business account is not restricted. Nothing in Citadel can resolve
it.

It blocks everything that needs a real message to move: the inbound half of two
agents on their own lines, multi-turn conversation, media, and two customers
overlapping. Everything up to Meta is proven — the agent decided to send, the
runtime called the API with the client's own credentials, and the refusal came
back with its reason intact.

## What is true now

`user-test-1` holds seven artifacts, four agent runtimes and a receiver.

| artifact | rev | name | state |
| --- | --- | --- | --- |
| `exigence.reference.summary` | 1 | Reference summary | job, on the client runtime |
| `exigence.superharness` | 3 | Superharness | **disabled**; its runtime is dormant by design |
| `exigence.superharness.deliveries` | 1 | Superharness | no runtime |
| `exigence.superharness.bookings-desk` | 1 | Bookings Desk | runtime building |
| `exigence.superharness.returns-desk` | 1 | Returns Desk | no runtime |
| `exigence.superharness.refunds-desk` | 1 | Refunds Desk | `5bc3`, has run and succeeded |
| `exigence.superharness.front-desk` | 1 | Front Desk | `37bd`, answers `whatsapp`, sends itself |

`front-desk` is the only enabled agent bound to the channel, which is what the
router requires — two enabled agents on one channel is refused rather than
resolved by ordering.

**A run started from the Console finished properly**: three decisions, two
actions, then the agent stopped on its own, with per-step cost metered.

## Fixed today

F-087 · a second agent publishes against the shared versions already stored
F-088 · adding an agent is a Console page, not a command-line tool
F-089 · an agent is called what it was named
F-090 · builds no longer reach the public provider registry, and a failed
`init` is reported instead of swallowed
F-091 · an agent's runtime coordinates come from what the client's build
recorded, never from the caller
F-093 · an agent may have a two-word name
F-094 · an agent can be sent back to its runtime build
F-095 · a client's second agent no longer destroys their first
F-096 · an agent is started on the runtime that serves it
F-097 · every activity transition is the record with a new status
F-098 · two agents whose resources would collide are refused
F-099 · disabling an agent no longer crash-loops its runtime
F-100 · a provider's refusal is an answer the agent can read, not a thrown
error nothing records
F-101 · an agent's deterministic address is recognised, so a build that
deployed correctly is no longer reported as failed

Full write-ups in `_dev/PRODUCTION_PUSH_AND_TEST.md`.

## The four worth reading

All four were **silent** — they reported something true and unhelpful, or
nothing at all.

- **F-090.** Every client build downloaded its providers from
  registry.terraform.io and got rate-limited. What the operator saw was not the
  429 — it was the empty lock file the failed download left behind, because the
  runner ran `init` and never checked its exit code.
- **F-095.** Building a client's second agent planned `23 to add, 0 to change,
  23 to destroy` — the whole of the agent answering their live line. The runner
  kept one Terraform state per template per project and said so in a comment
  that was true of every template until, that same morning, a client could have
  more than one agent.
- **F-097.** A P0 regression from F-080. An activity's identity is everything
  about it but its status, and `abandonedAfter` was added to activities created
  without it — so every step of every run on every configured deployment
  conflicted with itself and retried to its ceiling. **977 tests missed it
  because none of them set a step deadline**, and the in-memory journal did not
  enforce the rule the real one does — which a comment in that very file had
  already warned about.
- **F-100 (open).** A run that ends at its ceiling says the agent spent its
  decisions and never says every one of them was refused by Meta. F-090's
  lesson in a third place.

## Next, in order

1. **Once the WhatsApp token is fixed:** the inbound half of the two-agent
   test, multi-turn, media, two customers overlapping. `front-desk` is already
   the only enabled agent bound to the channel, so an inbound message should
   reach it — that is the test, and it needs one message from your phone.
2. **F-100's remaining half.** A step records no reason for failing, and the
   ceiling message names only the ceiling. The cause is fixed — refusals now
   reach the agent — but an operator reading a failed run still cannot see why
   its steps failed. It is a change to `Step`, `commitStep` and `beginStep`,
   and it wants a considered shape rather than a quick field.
3. **Bring the last two agent runtimes forward.** `5bc3` and `f111` are on the
   previous image. Re-applying them from their runtime pages is enough; the
   template default is the newest image, so drift only ever moves forward now.
4. **Then** the fresh-project onboarding — PROMPT.md item 4, deliberately held.

## Terraform drift: reconciled

Five services had been rolled with `gcloud` during the F-097 and F-099 fixes.
They were re-applied from the Console, so Terraform owns the images again, and
the template default is pinned to the newest build — which means any future
apply moves forward and never rolls a fix back. That trap is closed.

## Things that will bite

- **Cloud Tasks reserves a deleted queue's name for about seven days**, and the
  name comes from the client id and the agent slug. Rebuilding inside that
  window needs a different slug. Written up with the rest of the naming rules
  in `_dev/docs/exigence_agent_naming_and_queues.md`.
- **`min_instances = 1` is a correctness requirement** (F-027), not a knob, and
  it is one always-on instance per agent per client. `user-test-1` now runs
  five services. Answer the cost question before the tenth agent.
- **Cancelling a run does not purge queued deliveries.**
- **The root state files are not in any git repo.** The repository root is not
  a repository. `_dev` is.
- **Two stranded runs** on `refunds-desk` from before F-097 recovered on their
  own once the fix landed. If you see runs stuck at sequence 4 on an old image,
  that is what they are.

## Gates

994 Exigence · 565 Platform API · 37 provisioner · 510 Console. All green, all
repos clean and pushed.
