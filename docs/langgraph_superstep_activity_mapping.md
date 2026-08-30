# LangGraph superstep ↔ Citadel activity mapping

Written 14/08/26. **Status: reviewed and approved 14/08/26. The three blocking
questions in §6 are settled — see `DECISIONS.md`. Implementation of the
checkpointer is unblocked** (Feature 4.1 Task 4.1.R1; phase plan Phase 1A
step 1).

This document exists because the mapping is the one design error that stays
invisible until crash recovery. Everything here about LangGraph's behaviour was
verified empirically against the installed packages, not taken from
documentation or from the phase plan's notes. Where a claim is unverified it is
labelled so.

## Versions this was verified against

| Package | Version | Note |
|---|---|---|
| `@langchain/langgraph` | 1.4.9 | |
| `@langchain/langgraph-checkpoint` | 1.1.3 | phase plan said 1.0.0 |
| `@langchain/langgraph-checkpoint-validation` | 1.1.0 | requires **vitest** |
| Node | 26.0.0 | runtime image is Node 22 |

Re-verify before implementation if these have moved. Probes live in the session
scratchpad; they are ~40 lines each and worth re-running rather than trusting
this document if a major version changes.

---

## 1. Corrections to the phase plan's stated facts

The phase plan's "verified external facts" section is now wrong in three ways.
Each has a real consequence.

**`BaseCheckpointSaver` has six abstract members, not four.** The plan lists
`.put`, `.putWrites`, `.getTuple`, `.list`. The class also declares
**`deleteThread(threadId)`** as abstract, and `getDeltaChannelHistory` /
`getNextVersion` as overridable with defaults. `deleteThread` is not optional
and the conformance suite tests it (`testTypeFilters` includes `deleteThread`).
See §6 — this collides with the immutable journal.

**The conformance suite is vitest-based.** `vitest@^4.1.0` is a hard runtime
dependency of `@langchain/langgraph-checkpoint-validation`, and the suite's
`validate()` calls `describe`/`it` from vitest. Exigence's own suite runs on
`node --test`. Passing the gate therefore means adding vitest as a second test
runner for that one suite. It cannot be run under `node --test`, and the phase
plan forbids hand-rolling an equivalent.

**The HITL risk did not materialise.** `langchain-ai/langgraphjs#1308` is
**closed**, and its symptom (graph restarts from the beginning on resume) does
not reproduce at 1.4.9. `interrupt()` + `new Command({ resume })` resumes at the
exact superstep, both when resuming with `thread_id` alone and when pinning the
latest `checkpoint_id`. No escalation is needed. (Pinning an *earlier*
checkpoint is LangGraph's time-travel fork behaviour — not tested here, and not
something the runtime should ever do accidentally.)

---

## 2. What LangGraph actually calls, and when

Verified by subclassing `MemorySaver` and logging every call for a four-node
graph with an interrupt on the third node.

```
put       step -1  source "input"   ← the invocation's input becomes a checkpoint
putWrites          task A           ← writes routing to the first node
put       step  0  source "loop"    ← superstep barrier: folds A's writes into channel_values
putWrites          task B           ← node 1 output: ["steps","branch:to:summarise"]
put       step  1  source "loop"
putWrites          task C           ← node 2 output
put       step  2  source "loop"
putWrites          task D           ← ["__interrupt__"]  ← node 3 paused here
   ── run holds; zero compute ──
putWrites          task 00000000    ← ["__resume__"]     ← resume value staged
putWrites          task D           ← ["__resume__","steps","approved","branch:to:notify"]
put       step  3  source "loop"
putWrites          task E
put       step  4  source "loop"
```

Two operations with two distinct meanings:

- **`put` is the superstep barrier.** It writes a new immutable checkpoint whose
  `channel_values` already incorporate the previous superstep's writes. It is
  called once per superstep. `config.configurable.checkpoint_id` on the way in
  is the *parent*; `checkpoint.id` is the new checkpoint. The chain is strictly
  linear — verified with full UUIDs, every `parentConfig` points at the
  immediately preceding checkpoint.
- **`putWrites` is one task's output within a superstep.** A task is one node
  execution. It carries a `taskId` and a list of `[channel, value]` pairs.

Special channels seen in pending writes: `__error__` (a task threw),
`__interrupt__` (a task called `interrupt()`), `__resume__` (a resume value
staged for a task). `WRITES_IDX_MAP` maps these to negative indices so they
cannot collide with positional writes — a storage implementation must preserve
that index, not just the channel name.

## 3. The finding that drives the whole design

**LangGraph's unit of replay is the node, not the line.** Verified twice:

- **Interrupt.** A node containing a side effect before `interrupt()` and one
  after it, run through interrupt-then-resume, executed the **pre-interrupt code
  twice** and the post-interrupt code once. `interrupt()` resumes by re-running
  the node from its top and replaying up to the interrupt call.
- **Crash.** A graph crashed inside node `b` and then resumed executed
  `a > b > b > c`. The completed node `a` did **not** re-run; the crashed node
  re-ran from its top; recovery landed on the exact superstep.

So: **completed supersteps never re-run, but the in-flight node always re-runs
in full.** Any effect a node performs before its last `interrupt()` — a model
call, a budget reservation, a customer write, an audit append — will happen more
than once unless it is idempotent.

This is precisely the failure the phase plan warned would be "wrong only under
crash recovery", and it is why the reference automation's one-activity-per-step
shape cannot be carried over unexamined.

## 4. The idempotency key — the linchpin

**`taskId` is stable across re-execution.** Verified: node `b` crashed and
wrote `__error__` under task `3b7ab482-e0cc-5c7e-b719-64ee8fad233e`, and after
recovery wrote its real output under *the same* task id. The ids are UUIDv5
(deterministic, derived from graph position and state), not random, and differ
across threads.

Therefore:

```
Citadel activity identity  =  (runId, checkpoint_id, task_id)
Citadel activity attempt   =  one physical execution of that task
```

This replaces today's `activityIdempotencyKey(runId, stepId, activityId)`, which
assumes a static step list known before the run — an assumption LangGraph
invalidates the moment a graph branches or loops.

Every Citadel guarantee keys off that triple:

| Guarantee | Keyed on | Effect on replay |
|---|---|---|
| Budget reservation | `(runId, checkpoint_id, task_id)` | replayed node reuses its reservation instead of reserving twice |
| Effect receipt | same | a repeated customer write is recognised, not duplicated |
| Audit event | same + transition kind | idempotent append, as today |
| Tool gate decision | same + `toolId` | one decision per task, re-read on replay |

Note the existing `EffectReceipt` already carries `runId`/`stepId`/`activityId`/
`attempt`; the shape survives, its *population* changes.

## 5. Proposed mapping table

| LangGraph | Citadel | Journal representation |
|---|---|---|
| `thread_id` | `runId` | unchanged |
| checkpoint (`put`) | superstep barrier | one journal event, `entityType: "step"` |
| `checkpoint.id` | superstep identity | event `entityId` |
| parent `checkpoint_id` | previous superstep | ordering is already the journal `sequence` |
| task (`putWrites`) | **activity** | `entityType: "activity"` |
| `taskId` | activity identity | part of `idempotencyKey` |
| re-execution of a task | activity **attempt** | `attempt` increments, as today |
| `__error__` write | failed attempt | `activity.failed` |
| `__interrupt__` write | approval requested | existing approval + routing projection |
| `__resume__` write | approval resolved | existing resolution path |
| `channel_values` | run state | projection for Console reads |
| `metadata.step` | superstep ordinal | projection field |

Run/step *status* (`RunStatus`, `StepStatus`) becomes derived, not authoritative
— LangGraph's graph state is the source of truth, per Feature 4.1's division of
responsibility. The enums stay for Console display and are computed from the
latest checkpoint plus pending writes.

## 6. Conflicts — **all resolved 14/08/26**, see `DECISIONS.md`

These were the reason this document is a review gate. The operator answered all
three on 14/08/26; the settled wording lives in `DECISIONS.md` under "Phase 1A
— Firestore checkpointer" and is authoritative. Retained here with the
reasoning that produced them.

**6.1 `deleteThread` versus the immutable hash-chained journal.** The
conformance suite requires that after `deleteThread(threadId)` the thread's
checkpoints are gone. Citadel's journal is append-only and its audit chain is
hash-linked; deleting events destroys the evidence the platform exists to
provide, and a client run's audit trail is not ours to erase. Options:

1. Implement `deleteThread` against a checkpoint-only collection that is
   separate from the audit chain, so deletion removes execution state but not
   audit evidence. Costs a second write path; keeps the gate honest.
2. Implement it fully but refuse for runs with a settled invoice or a retention
   hold. Conformance passes (test threads are unheld); production is protected.
3. Implement it only for a test namespace. Passes the gate but the production
   class is then not the class under test, which defeats the point of using the
   official suite.

**RESOLVED: option 2.** The refusal is a typed error and must be tested.

**6.2 Byte-faithful storage versus structured projections.** The suite asserts
the checkpoint and metadata are returned "without alteration", and that `put`
returns a config whose `configurable` contains *only* `thread_id`,
`checkpoint_ns`, `checkpoint_id`. That pushes toward storing the serialized
blob verbatim. Console reads want structured fields. Proposal: the serialized
blob is the source of truth and is never reconstructed from projections;
projections are derived, additive and disposable. Rebuilding a checkpoint from a
projection must be impossible by construction, not by convention.

**6.3 Firestore write-rate and document-size limits.** A superstep costs one
`put` plus one `putWrites` per task. Firestore sustains ~1 write/sec/document,
so checkpoints must be one document per `checkpoint_id` (never a single
per-run document), and pending writes must not share a document with the
checkpoint. Feature 4.1 already records the ~1–5 transitions/sec per-run
ceiling; this mapping does not change it.

`channel_values` can also exceed the 1 MiB document limit. **RESOLVED: offload
at 80% of the limit — 838860 bytes (819 KiB)** — through the existing
`gcs_payload_store.ts` path, and an offloaded value counts as customer data.

CONSEQUENCE, and it is a trap worth stating plainly: that threshold governs one
channel value, so honouring it per value does **not** keep the document under
the limit. Three 700 KiB channels each pass the check and together blow past
1 MiB. The checkpointer must therefore measure the **serialized document total**
and offload the largest values until the whole document fits, treating the
80% figure as the point at which a single value is offloaded unconditionally,
not as the only test performed. A conformance-passing checkpointer that ignores
this fails in production the first time a graph accumulates wide state.

**6.4 Where the tool gate sits relative to `interrupt()`.** Feature 4.1 R3 says
risky scopes raise `interrupt()`. Given §3, any gate work performed *before* the
interrupt runs twice. The gate's decision write must therefore be idempotent on
the §4 key — which today's `ToolExecutionGate` already is, via its stable
`invocationId`. Phase R hardened exactly this property for the reference
automation; the same discipline transfers, but it must be re-proven against
LangGraph's replay rather than assumed.

## 6.5 Delta storage is mandatory, and dangerous on its own

Added 14/08/26 after implementation, because it is the sharpest instance of
this document's central warning.

The conformance suite requires that `put` persists **only** the channels named
in `newVersions` ("should only store channel_values that have changed"). The
test is skipped by name for MemorySaver, MongoDB and SQLite with the note that
those savers "don't store channel deltas", so it is a real requirement that the
reference savers simply have not met — not an optional optimisation.

Implementing it naively — filtering `channel_values` on write and returning
what was stored — **loses state**, and the conformance suite cannot detect it,
because its fixtures are isolated root checkpoints with no ancestry. A channel
written in superstep 0 and never rewritten vanishes from every later
checkpoint. Verified: a three-node graph whose first node set a channel that no
later node touched read that channel back as its default at the end of the run,
with all 714 conformance tests passing.

The fix is to key channel values by **(channel, version)** in their own
documents rather than by the checkpoint that wrote them, and on read to resolve
every channel named in the checkpoint's own `channel_versions` from its version
document. A write-once channel keeps its version, so it keeps resolving. This
is also cheaper than the alternative: a direct batched lookup per channel
instead of a walk back up the parent chain, which on Firestore would be one
read per ancestor per read.

The lesson generalises to the rest of Phase 1A: **the conformance suite proves
the storage contract, not that a graph runs.** Every mechanism built on the
checkpointer needs a real-execution test with ancestry, a crash, and a resume,
or it will pass its gate and fail in production.

## 7. What this implies for implementation order

1. ~~Resolve §6.1 and §6.2 with the operator.~~ Done 14/08/26.
2. Build the checkpointer against the *blob* model, with `(thread_id,
   checkpoint_ns, checkpoint_id)` as the document key and a separate writes
   collection keyed by `(checkpoint_id, task_id, idx)`.
3. Add vitest for the conformance suite only; keep `node --test` for everything
   else. Gate: the suite passes unmodified.
4. Only then wire the policy gate, budget reservation and audit onto the §4 key.
5. Prove replay explicitly: force a crash mid-node and assert the effect receipt
   count is 1, not 2. That assertion is the one that would have caught the
   entire class of Phase R defects.

## 8. Verification log

| Claim | How verified |
|---|---|
| six abstract members incl. `deleteThread` | read `dist/base.d.ts` |
| suite requires vitest, tests deleteThread | read package.json deps + `dist/types.d.ts` + spec test names |
| put/putWrites call order and meaning | traced a real 4-node graph |
| linear parent chain | full-UUID dump of `list()` |
| pre-interrupt code runs twice | counters across interrupt + resume |
| crashed node re-runs, completed nodes do not | forced throw, then resume |
| `taskId` stable across crash | same UUIDv5 before and after |
| #1308 does not reproduce | both resume shapes, 1.4.9 |
