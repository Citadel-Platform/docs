# Feature 4.7 — Citadel MCPs and the Agent Superharness (NEW 30/08/26)

## Status
Specified 30/08/26 from the product-owner feature-set review
(`_dev/docs/feature_set_review_30_08_26.md`). **Tasks 4.7.1 and 4.7.2 both
built 31/08/26**: the Superharness is a runtime rather than a scaffold.

`citadel_mcp_server.ts` speaks four MCP methods over newline-JSON stdio and
over HTTP, in front of the existing policy gate — every tool it serves is one
`bindPolicyGatedTool` already wrapped, so a call over MCP is gated, audited and
journalled exactly as one from inside a graph. No read-only mode, deliberately:
the artifact's own authority already answers that per call. A project records
`citadelMcpEnabled` and `runtimeBoilerplate`, and the Console carries the
checkbox, the radios and the copyable `CITADEL_MCP_SERVERS` block.

**The endpoint is mounted (31/08/26).** `POST /v1/runs/{runId}/mcp` on the
private runtime, which answers the question that had been open — which run a
message belongs to — without inventing an authentication path. Who may call at
all is Cloud Run IAM's answer, exactly as for every other service-to-service
call in Citadel; which run they may act for is the URL's, resolved by the
composer against the artifact this runtime hosts before a tool is built. The
run id therefore cannot be reached from a message body, which is the property
that matters: the journal is the record of what an artifact did.

The step coordinates — task id, checkpoint, node — *do* come from the caller,
over headers, and that is not the same thing. `thread_id` says whose work this
is; those say where inside it a call happened, and exist so a replayed step is
recognised rather than journalled twice. A caller lying about them can only
confuse its own run's idempotency, which it could do by calling twice anyway.

**Task 4.7.2 is built (31/08/26).** The superharness is a first-party graph in
the runtime rather than a scaffold: `exigence.superharness`, an `agent` whose
revision carries the creator's instructions and a step ceiling. Three decisions
shaped it and each is worth keeping.

*Two journalled steps per decision.* Deciding costs a model call; acting may
reach a customer. Recorded as one step, a resume after an approval hold would
re-ask the model and could choose a different tool from the one a person
approved. Recorded as two, the decision is read back and what resumes is what
was approved — proven against the Firestore emulator with a process that dies
between the two.

*A refusal is an observation.* The gate refusing a call is a true answer about
the artifact's authority, and the agent's next decision is better for having
it. The run continues, and nothing has widened: every remaining tool is gated
the same way.

*The ceiling is the run's own steps.* A run is created with `2 × maxSteps`
steps, so an agent wanting one more is asking the journal for a step that does
not exist. That required the run step planner, which had been an interface with
no implementation since the artifact registry existed — every run fell back to
the two artifacts named in `specFor`, which is why a report triage run could
not be created at all.

Outstanding, and each named in `superharness/README.md` rather than stubbed:
long-horizon memory across runs, retrieval over Manifold and ARM (neither is
indexed), and headless browsing (an egress decision, not a library choice).

## Scope
Two halves of one problem: an Exigence artifact can be any LangGraph agent, and
it currently cannot reach the client's own Citadel data or act on the client's
behalf through Citadel without somebody writing a tool binding for each thing
it might want.

Depends on Features 4.5 (artifacts), 6.1 (Palisade) and 4.4 (knowledge base).

## Task 4.7.1 — Citadel capabilities over MCP

Today an artifact reaches Citadel through *tools*: typed, policy-gated
bindings — `manifold.correlate`, `localbridge.read`, `knowledge_base.search` —
each declaring the permissions it needs, each resolved against the artifact's
Palisade authority before it runs, each journalled. That is the right
enforcement and the wrong ergonomics: every new capability is a new binding
somebody has to write.

The fix is a transport, not a second authorisation path.

- An **MCP server in front of the existing tool gate**. Every Citadel tool the
  artifact holds a capability for is exposed as an MCP tool; the gate still
  decides, still refuses, still journals.
- The artifact form gains **Enable Citadel MCPs**.
- **There is no read-only / full radio pair.** The review replaced it
  deliberately: the artifact's granted Palisade capabilities already answer
  that question, per call and audited. An artifact holding
  `exigence.usercontext.read` and not `exigence.channels.write` *is*
  read-only. A mode beside the capabilities would be a second thing deciding
  what an agent may do, and the two would eventually disagree — which is the
  failure where an agent does something nobody granted.
- Enabling it injects the server config into the runtime and shows a copyable
  snippet the operator pastes into their own LangGraph config:

  ```
  CITADEL_MCP_SERVERS = {
      "citadel": {"url": "...", "transport": "sse"},
      "citadel_local": {"command": "...", "transport": "stdio"},
  }
  ```

- The server handles auth, refresh and failure headlessly. An agent running
  unattended cannot be asked to re-authenticate.
- **Localbridge is exposed the same way.** The local runner's tools are
  already tools, so an artifact reading and acting on the client's own machine
  follows for free once the gate sits behind an MCP transport — and stays
  bounded by the runner's own Effect Boundary, enforced on that machine.

Agent Skills (`SKILL.md`) are explicitly out of scope for this build.

## Task 4.7.2 — The Superharness runtime

Artifact creation gains a runtime choice, defaulting to the first:

- **Default blank runtime** — what exists now: a hand-written graph.
- **Citadel Superharness runtime** — pre-packaged, so a creator supplies a
  `prompt.md` or custom instructions and has a working artifact.

The superharness ships:

- the Citadel MCPs from 4.7.1;
- context prompts describing what Citadel is and how it works, so the agent
  does not have to be told each time;
- LangGraph configuration for state and context management over long-horizon
  tasks, with short- and long-term multimodal memory;
- RAG over the Exigence knowledge base, over Manifold conversations and
  customers, and over ARM issues and cases;
- web access through headless Chrome.

**The constraint that shapes it.** A superharness agent chooses its own next
step, so it is an `agent`-type artifact and carries the step and budget
ceilings that type requires. Every step still goes through the tool gate and
is journalled. That is what makes "supply a prompt and go" safe rather than
reckless, and it is not negotiable — an unbounded agent with MCP access to a
client's data plane is the single worst thing this platform could ship.

## Definition of done
> Updated 31/08/26. A runtime is deployed for `demo-project`, and the MCP
> endpoint's three refusals are proven in production. What is still unproven is
> a *successful* call — over MCP or as a superharness run — because that needs
> a run on that runtime and a published superharness revision in a client's
> control plane. 913 Exigence tests and 130 emulator tests, 0 failures.

- [ ] An artifact with Citadel MCPs enabled reads its client's ARM, Conduit
      and Manifold data through MCP, and every read is gated and journalled
      exactly as a tool call is
- [ ] An artifact without the capability is refused at the MCP boundary, and
      the refusal is the gate's, not the transport's
- [ ] The snippet shown in the Console works when pasted into a real LangGraph
      config, unmodified
- [ ] Auth, refresh and provider failure are handled without a person
- [ ] Localbridge reaches the client machine over MCP and the runner's own
      boundary still refuses independently
- [x] A Superharness artifact created with nothing but a prompt runs and keeps
      state across the run, including across a process that dies mid-decision
      (`superharness_graph.integration.test.ts`). **Retrieval is one source of
      three**: the knowledge base is a tool today; Manifold and ARM are not
      indexed, and the agent is told it has no tool for them rather than
      answering from nothing.
- [x] A Superharness artifact cannot exceed its step ceiling — the run is
      created with the steps its revision declares, and the graph stops and
      says so rather than asking the journal for one that does not exist. The
      budget ceiling is `BudgetedModelExecutor`'s, unchanged, and every
      decision reserves against it.
