# Palisade role and permission model

Written 15/08/26, settling the questions raised the same day. Records the
decision in `DECISIONS.md` 15/08/26 as a concrete catalogue: the permission
names, the three roles, and the argument that adopting them changes nobody's
access today.

Companion to `palisade_authorization_model_extraction.md`, which describes what
exists now. This describes what replaces it.

## 1. Structure

Standard cloud-provider IAM shape, deliberately not a Citadel-specific one:

```
permission   <service>.<resource>.<verb>      exigence.runs.create
role         a named bundle of permissions     roles/citadel.invoker
grant        (identity, role, project)         scoped, never global by accident
```

An identity holds roles, or permissions directly, scoped to a project.
Deny-by-default: absence of a grant is a denial, and an unreachable Palisade is
a denial rather than a bypass.

**One vocabulary.** There is no separate family for "what a person may call"
versus "what an agent may invoke". An artifact is a principal like any other,
so its tool authority is expressed in the same namespace as everything else.
This is the substantive change from today, where Exigence's `tools.write` and
the platform's `ProjectRole.developer` are unrelated systems that happen to
share vocabulary.

## 2. Permission catalogue

Derived from the 25 operations the Platform API actually exposes plus the five
agent permissions Exigence enforces. Nothing here is speculative; every entry
corresponds to a route or an existing check.

### ARM

| Permission | Today's route |
|---|---|
| `arm.issues.list` | `armIssueList` |
| `arm.issues.update` | `armIssueStatusUpdate` |
| `arm.cases.list` | `armCaseList` |
| `arm.cases.get` | `armCaseDetail` |
| `arm.cases.update` | `armCaseStatusUpdate` |

### Conduit

| Permission | Today's route |
|---|---|
| `conduit.sessions.search` | `conduitSessionSearch` |
| `conduit.sessions.replay` | `conduitSessionReplay` |
| `conduit.sessions.update` | `conduitSessionMetadataUpdate` |
| `conduit.heatmaps.query` | `conduitHeatmapQuery` |

### Exigence — operations

| Permission | Today's route |
|---|---|
| `exigence.automations.list` | `exigenceAutomationList` |
| `exigence.automations.update` | `exigenceAutomationUpdate` |
| `exigence.runs.get` | `exigenceRunDetail` |
| `exigence.runs.create` | `exigenceRunTrigger` |
| `exigence.runs.cancel` | `exigenceRunCancel` |
| `exigence.approvals.list` | `exigenceApprovalList` |
| `exigence.approvals.resolve` | `exigenceApprovalResolve` |
| `exigence.auditEvents.list` | `exigenceRunAuditEventList` |
| `exigence.providers.list` | `exigenceProviderList` |
| `exigence.providers.update` | `exigenceProviderUpdate` |
| `exigence.budget.get` | `exigenceBudgetGet` |
| `exigence.budget.update` | `exigenceBudgetUpdate` |
| `exigence.schedules.get` | `exigenceScheduleGet` |
| `exigence.schedules.update` | `exigenceScheduleUpdate` |
| `exigence.webhooks.get` | `exigenceWebhookGet` |
| `exigence.webhooks.update` | `exigenceWebhookUpdate` |

### Exigence — agent capabilities

Same namespace, held by an artifact's identity rather than a person's. Only the
names change; the policy kernel's evaluation is untouched.

| Palisade permission | Today in `policy.ts` |
|---|---|
| `exigence.tools.read` | `tools.read` |
| `exigence.tools.write` | `tools.write` |
| `exigence.communications.send` | `communications.send` |
| `exigence.financial.execute` | `financial.execute` |
| `exigence.destructive.execute` | `destructive.execute` |

## 3. The three roles

| Role | Purpose |
|---|---|
| `roles/citadel.superdev` | Full access. The operator's own role. |
| `roles/citadel.viewer` | See resources, services and results; change nothing. |
| `roles/citadel.invoker` | Run services; create and change no configuration. |

**`superdev`** holds every permission in §2, including future ones — it is the
role that must not need editing each time a product gains a route.

**`viewer`** holds exactly the read verbs: `*.list`, `*.get`, `*.search`,
`*.replay`, `*.query`. No update, no create, no cancel, no resolve.

```
arm.issues.list, arm.cases.list, arm.cases.get,
conduit.sessions.search, conduit.sessions.replay, conduit.heatmaps.query,
exigence.automations.list, exigence.runs.get, exigence.approvals.list,
exigence.auditEvents.list, exigence.schedules.get, exigence.webhooks.get
```

**Corrected 15/08/26 after the equivalence test failed.** This list first
included `exigence.providers.list` and `exigence.budget.get`. Both are
`configurationRead` routes today, which a viewer cannot reach, so including
them would have handed clients a view of provider configuration and spend that
they do not have now — a privilege escalation introduced by a migration whose
entire purpose was to change nobody's access. They are superdev-only until
someone decides otherwise on its own merits. Letting a client see their own
spend is plausibly right; it is not a migration detail.

**`invoker`** is `viewer` plus the two permissions that run work without
changing configuration:

```
everything in viewer, plus
exigence.runs.create, exigence.runs.cancel
```

### Two judgement calls in `invoker`, stated rather than buried

- **`exigence.approvals.resolve` is excluded.** Resolving an approval is the
  act that authorises a risky effect — a write, an external communication, a
  financial or destructive action. Handing it to the role designed for someone
  who may not change configuration would let that person authorise the exact
  effects the approval gate exists to hold. It stays with `superdev` until
  there is a reason to separate it.
- **`exigence.runs.cancel` is included.** Cancelling is stopping work the role
  is already entitled to start, and withholding it would mean an invoker could
  launch a run they cannot stop.

Both are reversible; neither should be changed silently.

## 4. Migration mapping, and why access does not change

| Today | Palisade |
|---|---|
| `developer` + `admin` (owner, or listed in `developerProjectIds`) | `superdev` |
| `viewer` (listed in `viewerProjectIds`) | `viewer` |
| `operator` | removed |
| `analyst` | removed |
| — | `invoker` (new; nobody holds it yet) |

The removals are safe for a specific, verified reason rather than by assertion:

- **`operator` and `analyst` were unreachable.** Nothing in the resolver ever
  granted them, so no identity can lose access it held. Pinned by
  `platform_authorization_golden_test.dart`.
- **`admin` was never held without `developer`.** Every grant path added both,
  so collapsing them into one role cannot split an identity's authority.
  `adminMutation` routes become `superdev`-only, which is precisely the set of
  identities that could reach them before.
- **`invoker` is additive.** It grants nothing to anyone until it is granted.

So the old access classes map cleanly onto the new roles:

| Access class | Accepted today | Accepts under Palisade |
|---|---|---|
| `read` | admin, analyst, developer, operator, viewer | superdev, viewer, invoker |
| `configurationRead` | admin, developer, operator | superdev |
| `mutation` | admin, developer, operator | superdev |
| `adminMutation` | admin | superdev |

`read` gains `invoker`, which is the intended new capability and affects no
existing identity. Every other row is the same set of people.

## 5. What this does not settle

- **Access and Effect Boundaries** (Task 6.1.2) are untouched here. Nothing
  today constrains their design, and the pattern grammar is still an open
  question in `DECISIONS_NEEDED.md`.
- **Identity types** (Task 6.1.1) — the five types still need a registry. This
  document assumes an identity exists and can hold a role.
- **The registry's storage shape.** `platform_access` encodes roles in field
  names (`developerProjectIds`, `viewerProjectIds`), which does not extend to
  three roles cleanly. Replacing it is part of Task 6.1.1, and the golden
  vectors are what will show the replacement resolves identically.
