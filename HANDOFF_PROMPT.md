# Handoff — 05/09/26, late

**Baker is built.** That is what changed in the second half of the day, and
almost every defect below was found on the way to being able to say it.

Nothing is blocked on you. The WhatsApp channel that stopped the morning was a
Meta account state and the operator resolved it; Manifold has since been proven
end to end.

## What is true now

`user-test-1` holds seven artifacts and three agent runtimes, and **every Cloud
Run service in the project is on the current Exigence image**
(`c56f39d8…`) — the client runtime, its receiver and all three agents.

| artifact | rev | name | state |
| --- | --- | --- | --- |
| `exigence.reference.summary` | 1 | Reference summary | job, on the client runtime |
| `exigence.superharness` | 3 | Superharness | **disabled**; runtime `f111` (slug `wa2`) |
| `exigence.superharness.front-desk` | 1 | Front Desk | runtime `37bd`; answers `whatsapp`, sends itself |
| `exigence.superharness.refunds-desk` | 1 | Refunds Desk | runtime `5bc3`; has run and succeeded |
| `exigence.superharness.bookings-desk` | 1 | Bookings Desk | no runtime |
| `exigence.superharness.deliveries` | 1 | Superharness | no runtime |
| `exigence.superharness.returns-desk` | 1 | Returns Desk | no runtime |

`front-desk` is the only enabled agent bound to the channel, which is what the
router requires — two enabled agents on one channel is refused rather than
resolved by ordering.

**Manifold is proven end to end**: inbound to the right agent, unattended reply
with a real `wamid`, multi-turn, media stored and acknowledged, two customers
at once on separate threads, an operator reply by hand from the inbox, consent
ledger intact.

**Baker is complete.** Factory takes a clean repository to a running Flutter
application; the Devstation provisions, starts, takes an SSH session, stops and
destroys from the Console; all four Baker tabs are served with real data.

## Fixed in the second half of 05/09

F-102 · Start was offered for a machine that does not exist
F-103 · the provision panel named an approval page that does not exist
F-104 · **four templates never enabled the services they build into**
F-105 · the provisioner had no Compute or custom-role permission in a client's
project, so a Devstation apply died partway after approval
F-106 · a teardown could be planned and never approved
F-107 · the module indexer reported `recipes/` as unreadable
F-108 · **an agent planned against a Terraform state that was not its own**

And the three carried over from the morning's list: a failed step now records
why (F-100's other half), a delivery for a finished run succeeds instead of
being retried forever, and a refusal, a ceiling and a real failure are three
trace categories rather than one.

Full write-ups in `_dev/PRODUCTION_PUSH_AND_TEST.md`.

## The two worth reading

- **F-104.** The Devstation's first apply died at "Compute Engine API has not
  been used in project … before or it is disabled" — nineteen resources
  planned, four created, the failure twenty minutes and one approval after the
  decision. The test written to pin that found three more, and they matter far
  more than the one that caused it. **`client-data-plane` creates every one of
  a client's Firestore databases and never enabled Firestore.** It had applied
  sixteen times without failing, because every one of those projects already
  had Firestore from an Exigence build. Invisible to every existing client and
  fatal to the next one. `exigence-runtime` and `exigence-agent` had the same
  latent race.

  This is the argument for the onboarding run, in one defect.

- **F-108.** Rolling `exigence.superharness` forward planned `32 to add, 0 to
  change, 0 to destroy` — a second complete runtime beside the one already
  serving, under different names so nothing would even have collided. Not
  applied. The agent was built with the slug `wa2`; the Console derives
  `superharness` from the agent id, and a slug decides both the Terraform state
  and the resource names. It is F-095's failure from the other side: not two
  agents sharing one state, but one agent pointed at a state that is not its
  own.

  It took three passes. The first fix looked only for jobs recorded `applied`
  and found nothing — every one of that agent's thirteen builds is
  `applyFailed`, because Terraform created the resources and the post-apply
  routing check then failed the job. The second missed that `approveAndApply`
  re-derives the slug too, so the apply could not find its own plan file.

## Next, in order

1. **The fresh-project onboarding** — PROMPT.md item 4, deliberately held for
   an explicit green light. It is the highest-value verification left: three of
   today's defects were only reachable from a project that had never had the
   service in question, which is every future client's first day.
2. **A browser smoke test of a generated application.** Factory's
   clean-repository test runs `flutter analyze` and `flutter test` on the
   result; nothing drives the running application.
3. **`axis-education` has zero provisioning jobs of any template** — the one
   real production client, and nothing in the record says how their
   infrastructure came to exist.
4. **`test-sandbox`** stays Exigence-blocked until ~09/09/26 on the queue-name
   reservation. Waiting, not working.

## Things that will bite

- **A stale plan outlives the defect that produced it.** A plan stays adoptable
  for an hour, so both of F-108's duplicate-build plans were still offerable
  after the fix was deployed, and both had to be marked superseded by hand.
  Nothing invalidates a plan when the thing that made it wrong changes. If you
  see a plan proposing to create what already exists, do not apply it.
- **An agent's slug is not derivable from its id.** It is a recorded fact about
  what was built. `exigence.superharness` is `wa2`. The naming rules are in
  `_dev/docs/exigence_agent_naming_and_queues.md`.
- **Cloud Tasks reserves a deleted queue's name for about seven days**, and the
  name comes from the client id and the agent slug. Rebuilding inside that
  window needs a different slug.
- **A warm instance is now a choice, not a constant.** `runtime_min_instances`
  is an input on both Exigence templates and a control in the Console. A client
  whose artifacts are all single-step may scale to zero; an agent may not,
  because a decide/act loop delivers its own next step to itself (F-027). The
  cost question at twenty agents is still open.
- **Factory runs from a terminal, not from the Platform API.** A bootstrap
  installs dependencies, runs a build and launches an application, and Cloud
  Run has no workspace to do that in. The Console's Bootstrap tab is the guided
  half, and it says so.
- **The root state files are not in any git repo.** The repository root is not
  a repository. `_dev`, `citadel_core`, `citadel_core/exigence`,
  `citadel_platform`, `citadel_cli` and `baker-modules` each are — and
  `citadel_core/exigence` is separate from `citadel_core`, which is easy to
  miss when committing.

## Gates

Exigence 1001 tests: 876 pass, 125 skipped. Every skip is
`!emulatorAvailable` — they need the Firestore emulator running, and it is
worth starting it occasionally, because F-097 hid in exactly that gap between
the in-memory journal and the real one.

593 Platform API · 524 Console · 50 provisioner · 12 Factory. All green, all
repos clean and pushed.
