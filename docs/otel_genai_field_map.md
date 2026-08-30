# OTel GenAI semantic convention field map

Written 15/08/26. Pulled forward from Feature 4.3 into Phase 1A because the
telemetry schema is soft while there are zero client runs and effectively
frozen the moment there is one — renaming an emitted attribute later means
rewriting stored traces or living with two schemas.

Everything below was verified against the current published conventions on
15/08/26, not from memory. See §6 for exactly what was checked.

## 1. Where the conventions actually live now

**The GenAI conventions have moved out of the main semantic-conventions
repository** into `open-telemetry/semantic-conventions-genai`. The old
`opentelemetry.io/docs/specs/semconv/gen-ai/` page is a stub that says so and
is no longer maintained. Anything citing the old path is stale.

Two consequences worth stating before the table:

- **`gen_ai.system` no longer exists.** It has been replaced by
  `gen_ai.provider.name`, which is **Required**. The only remaining
  `gen_ai.system*` key is `gen_ai.system_instructions`, which is unrelated
  (Opt-In, carries the system prompt). Any instrumentation written against
  older guidance emits a key that is now undefined.
- **Every GenAI attribute is still marked Development stability.** The upstream
  schema is not frozen either, so this map pins what *Citadel* emits and is
  revisited deliberately, rather than tracking upstream churn automatically.

## 2. Spans Citadel emits

Span name follows the convention `{gen_ai.operation.name} {gen_ai.request.model}`.

| Citadel concept | `gen_ai.operation.name` | Span covers |
|---|---|---|
| Artifact run | `invoke_agent` | the whole LangGraph run, one per `runId` |
| Model call | `chat` | one `BudgetedModelExecutor` invocation |
| Tool call | `execute_tool` | one `bindPolicyGatedTool` invocation |

`invoke_workflow` also exists upstream and is the better fit if an artifact is
ever a plain pipeline with no model in the loop. Artifacts are agentic by
definition here, so `invoke_agent` is the default and `invoke_workflow` is
reserved rather than unused.

## 3. Model call — Citadel field → semconv attribute

Citadel's `CostRecord` and `ModelTokenUsage` already carry everything the
convention wants; the names differ, and that is the whole point of this map.

| Citadel field | Semconv attribute | Level |
|---|---|---|
| — (constant) | `gen_ai.operation.name` = `chat` | **Required** |
| `provider.adapterId` = `google.vertex-ai` | `gen_ai.provider.name` = `gcp.vertex_ai` | **Required** |
| `CostRecord.modelId` | `gen_ai.request.model` | Cond. Required |
| Vertex `modelVersion` from the response | `gen_ai.response.model` | Recommended |
| `runId` | `gen_ai.conversation.id` | Cond. Required |
| `ModelTokenUsage.promptTokens` | `gen_ai.usage.input_tokens` | Recommended |
| `ModelTokenUsage.cachedInputTokens` | `gen_ai.usage.cache_read.input_tokens` | Recommended |
| `ModelTokenUsage.candidateTokens` | `gen_ai.usage.output_tokens` | Recommended |
| `ModelTokenUsage.thoughtsTokens` | `gen_ai.usage.reasoning.output_tokens` | Recommended |
| `maxOutputTokens` | `gen_ai.request.max_tokens` | Recommended |
| finish reason | `gen_ai.response.finish_reasons` | Recommended |
| failure class | `error.type` | Cond. Required on error |

Three Citadel fields have **no** semconv home and must not be forced into one:

- `ModelTokenUsage.toolUsePromptTokens` — the convention has no equivalent.
- `ModelTokenUsage.totalTokens` — deliberately absent upstream; it is derivable,
  and emitting it as a `gen_ai.*` key would invent an attribute.
- `priceProfileId` — pricing is Citadel's concept entirely.

## 4. Cost has no standard, and that is the important finding

**There is no cost or money attribute anywhere in the GenAI conventions**, and
no cost metric — the metrics are `gen_ai.client.token.usage`,
`gen_ai.client.operation.duration`, `gen_ai.invoke_agent.duration`,
`gen_ai.invoke_workflow.duration`, `gen_ai.execute_tool.duration`,
`gen_ai.server.*`. Token usage is the closest upstream proxy for spend.

Citadel bills from its own metering (DECISIONS.md 14/08/26: self-metering is
the only attribution source), so cost is emitted under a Citadel-owned
namespace and never under `gen_ai.*`. Putting money into `gen_ai.*` would
collide the day upstream defines its own cost semantics with different units.

## 5. The `citadel.*` namespace

Everything the conventions have no home for goes here. Nothing in this list may
be renamed once a client run exists without a stated migration.

| Attribute | Source | Why it is not `gen_ai.*` |
|---|---|---|
| `citadel.run.id` | `runId` / LangGraph `thread_id` | also emitted as `gen_ai.conversation.id`; kept for joins to the journal |
| `citadel.checkpoint.id` | LangGraph `checkpoint_id` | LangGraph durability coordinate |
| `citadel.task.id` | LangGraph `__pregel_task_id` | with the two above forms the activity identity |
| `citadel.activity.attempt` | `Activity.attempt` | replay counter; a node re-runs from its top |
| `citadel.node` | graph node name | Citadel's step label |
| `citadel.cost.amount_nanos` | `CostRecord.amountNanos` | no upstream cost attribute (§4) |
| `citadel.cost.currency` | `CostRecord.currency` | as above |
| `citadel.cost.price_profile_id` | `CostRecord.priceProfileId` | pricing is Citadel's |
| `citadel.usage.tool_use_prompt_tokens` | `toolUsePromptTokens` | no upstream equivalent |
| `citadel.policy.decision` | gate outcome | authorization is Citadel's |
| `citadel.approval.id` | `Approval.approvalId` | HITL record, not a model concept |
| `citadel.audit.event_id` | `AuditEvent.eventId` | audit chain is Citadel's |
| `citadel.audit.integrity_hash` | `AuditEvent.integrityHash` | lets a trace be tied to the hash chain |
| `citadel.project.id` | client project | tenancy; the top-severity isolation concern |

**`citadel.project.id` must be on every span.** Client workloads now use
per-client project boundaries, but infrastructure isolation does not replace
application attribution: a span without this field cannot be reconciled to the
registry, authorized correctly, or safely shown in the Console.

## 6. Verification log

| Claim | How verified |
|---|---|
| conventions moved repositories | old semconv page returns a "moved" stub |
| 56 `gen_ai.*` span attributes exist | extracted from `docs/gen-ai/gen-ai-spans.md` |
| `gen_ai.system` gone, `gen_ai.provider.name` Required | requirement-level column; only `gen_ai.system_instructions` remains |
| `gcp.vertex_ai` is the Vertex provider value | example values in the spec |
| span name `{operation} {model}` | span-name section |
| token attributes are Recommended | requirement-level column |
| no cost attribute or metric | full attribute list plus `docs/gen-ai/gen-ai-metrics.md` |

## 7. Open item for Feature 4.3

This map fixes the field names. It does not decide the exporter or the backend,
which stay Feature 4.3's call — nothing here presumes one. Emission is not
wired anywhere yet; the point of writing it now is that the names are settled
before the first client run makes them expensive to change.
