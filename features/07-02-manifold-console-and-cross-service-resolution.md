# Feature 7.2 - Manifold Cross-Service Resolution

## Status
End-state product direction settled 26/08/26. Depends on 7.1 and the relevant
ARM, Conduit, Exigence, Baker and Palisade capabilities.

## Scope
Close the loop from an application issue and human report to contextual
diagnosis, response and an approved repair, entirely visible from the Console.

## Target flow
1. ARM records issue telemetry and evidence.
2. Conduit records the affected journey and session analytics.
3. A user report arrives through Manifold.
4. An Exigence artifact finds candidate session ids from the report's time
   window and reads only Palisade-authorized ARM/Conduit context.
5. The artifact responds through Manifold or escalates a repair to the correct
   Baker Devstation, where patch, tests and redeployment remain governed.
6. Palisade authorizes and audits every ingress, read, relay and effect.

## Tasks

### Task 7.2.1 - Correlation
- Candidate matching is explainable and returns multiple candidates when
  evidence is ambiguous; it never silently asserts a user/session identity.
- Every ARM/Conduit read is project-scoped and recorded in the data-flow audit.
- Cross-channel identity resolution from client Firestore is deferred,
  opt-in, and operator-correctable when it is eventually introduced.

### Task 7.2.2 - Governed response
- Human and artifact replies share Manifold delivery and consent enforcement.
- Autonomous sends require the exact Palisade permission and approval policy.

### Task 7.2.3 - Repair escalation
- Create a scoped Baker Devstation task containing only approved context.
- Patch, test, deploy and outcome link back to the issue and conversation.

### Task 7.2.4 - Console case view
- One view links conversation, candidate sessions, ARM evidence, Conduit
  journey, Exigence run, approvals, repair task, deployment and resolution.
- Live source checks distinguish unavailable, stale and absent data.

## Definition of done
- [~] One real report correlates to a real session and issue end to end — an
      artifact now declares `manifold.correlate`
      (`report_triage_artifact.ts`, `report_triage_graph.ts`,
      `report_triage_bundle.ts`): it reads the report the run was triggered
      by, correlates, drafts and replies, and the runtime composes it with the
      *audited* correlation source rather than the raw one. What remains is
      deploying it against a real project's ARM and Conduit data — the loop is
      built and has not yet been run end to end on live evidence.
- [~] An approved reply and an approved repair path both complete and audit —
      the reply half is built and gated: `channel.send` is uncompensatable and
      the published policy requires approval for
      `exigence.communications.send`, which the runtime refuses to load a
      revision without, so an unattended reply is not a configuration mistake
      a project can make. The approver is shown the whole message and the
      recipient, because approving a summary of something nothing can withdraw
      is approving text nobody read. **The repair path is Task 7.2.3 and is
      not built.**
- [~] Adversarial tests prove cross-project and over-broad context access
      fails — both halves are covered as far as they can be without a
      deployed artifact: an artifact holding `exigence.tools.read` is refused
      the correlation tool (`test/correlation_tool.test.ts`), and a request
      naming another project is refused rather than answered from this one
      (`test/correlation_source.integration.test.ts`). What is not yet proven
      is the same thing against a running artifact.
- [ ] Browser E2E shows the complete loop from report to resolution

## Task 7.2.1 — built 30/08/26

`correlation.ts` decided what may be proposed and had no source; both halves
now exist.

- **`exigence.usercontext.read`** is a sixth agent capability with its own
  `usercontext` tool scope (DECISIONS.md 30/08/26). Reading a client's end
  users is separable from reading the client's own documents, which the closed
  set of five capabilities could not express.
- **`correlation_tool.ts`** binds it through the policy gate like every other
  tool: an artifact that does not hold the capability is denied and journalled.
- **`correlation_source.ts`** reads ARM's `armIssues` and Conduit's
  `conduit_sessions` out of the client's own project, and every read is wrapped
  in the data-flow audit — naming the capability that permitted it, the class
  of data, and how many records were reached, never the records.
- Issues are selected on last sighting rather than first: a bug that has been
  recurring all week is still what this customer just hit, and filtering on
  first sight would hide the issue with the most evidence behind it.

## Task 7.2.2 — built 30/08/26

`manifold.correlate` had no caller: the engine, its source and its tool were
all built and reachable only from a test, which meant the data-flow audit's
only producer was itself a fixture.

- **`exigence.report.triage`** is a third artifact on the same substrate. A
  **workflow** on an `event` trigger, not an agent: the shape of its work —
  correlate, draft, reply — is fixed before anybody writes in, and what the
  model composes is the content of the reply rather than the sequence of
  steps.
- **Three steps because three authorities.** Reading a client's end users,
  composing an answer and putting that answer on somebody's phone are
  separately grantable and separately refusable; a node doing two of them
  would be gated as whichever it declared, and that would be the weaker.
- **The recipient comes from the report, never from the draft.** A recipient
  the model could influence would let the text of a customer's message decide
  who the answer is sent to.
- **The draft is handed the ambiguity.** A model given one candidate and no
  note that the evidence did not separate it writes as though it were certain,
  and a confident wrong identification sends somebody to a stranger's session
  replay. The system instruction says so as well as the payload.
- **Approval is not optional.** `reference_deployment_config.ts` refuses a
  revision whose policy does not require approval for
  `exigence.communications.send`, so an artifact that could reply unattended
  cannot be published by forgetting a field.

Wiring it also made `external_channel.ts` replay-reachable for the first time,
which surfaced a wall-clock default on the send ledger's clock. That default
was harmless while nothing in a run imported the file and would have written a
different attempt timestamp on a replay than the first attempt wrote — on the
ledger that exists to tell a replay from a second message. The clock is now
injected with no default.
