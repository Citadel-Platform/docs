# Existing authorization models — extraction for Palisade

Written 15/08/26. Prerequisite for Feature 6.1 Task 6.1.4, whose acceptance
gate is that **existing ARM and Exigence access resolves identically before and
after migration, proven by test**. That gate is unmeetable without first
writing down precisely what "identically" means, which is what this document
is. It describes the system as it is today, not as it should be.

Read before designing Palisade's schema. Everything here was read out of the
running code, not from the feature files.

---

## 1. Platform authorization (ARM, Conduit, and the Exigence proxy)

Enforced in `citadel_core/platform/server`. Every Console and CLI request goes
through it; the private product services sit behind it.

### 1.1 Chain of evaluation

1. **Authentication** — a Firebase ID token (a person) or a Google OIDC
   identity token (service-to-service). Palisade does not change this;
   Firebase Auth keeps proving who the caller is.
2. **Identity lookup** — `platform_access/{email}`, lowercased and trimmed. No
   document means no roles, and therefore no access.
3. **Project lookup** — `platform_projects/{projectId}`. The project must have
   `status == "active"`, and `offeringScope[<offering>].enabled == true` for
   the offering the operation belongs to. The offering is derived from the
   operation, not from the request.
4. **Role derivation** — from the access document (§1.2).
5. **Operation gating** — the derived roles are checked against the access
   class the route declares (§1.3), plus `authorization.projectId` must equal
   the requested project.

Failure at any step is a denial. This is already deny-by-default and must stay
that way.

### 1.2 Role derivation, exactly as implemented

Fields on `platform_access/{email}`: `tenantRoles`, `developerProjectIds`,
`viewerProjectIds`.

| Condition | Roles granted |
|---|---|
| `tenantRoles` contains `owner` | `developer` **and** `admin` |
| `developerProjectIds` contains the project | `developer` **and** `admin` |
| `viewerProjectIds` contains the project | `viewer` |

### 1.3 Access classes

| Access class | Roles accepted |
|---|---|
| `read` | admin, analyst, developer, operator, viewer |
| `configurationRead` | admin, developer, operator |
| `mutation` | admin, developer, operator |
| `adminMutation` | admin |

### 1.4 Findings the migration must not "fix" by accident

These are real properties of today's behaviour. A behaviour-preserving
migration must reproduce them, and any change to them is a **separate,
deliberate decision** — not a side effect of moving to Palisade.

- **`operator` and `analyst` are unreachable.** Both appear in the access-class
  tables, but nothing in the resolver ever grants them. Five project roles are
  declared; three can be held. If Palisade makes them grantable, previously
  denied requests start succeeding, which is a privilege escalation introduced
  by a migration that was supposed to preserve behaviour.
- **`configurationRead` and `mutation` are indistinguishable.** Identical role
  sets, so the distinction has no effect today. It encodes an intent — reading
  configuration is not the same as changing it — that only becomes real once
  `operator` or `analyst` can be held.
- **`admin` is never granted alone.** Every path that grants `admin` also
  grants `developer`. Nothing today can express "admin but not developer".
- **Only `owner` matters among tenant roles.** `developer`, `admin`,
  `operator`, `auditor` and `billing` exist in `TenantRole` and are inert.
- **Owner is global.** A single `owner` tenant role grants developer+admin on
  *every* project, with no per-project record. With all clients sharing one GCP
  project, Palisade must keep this deliberate and visible rather than
  incidental.

---

## 2. Exigence authorization (the agent policy kernel)

Implemented in `citadel_core/exigence/src/policy.ts`. This governs what an
*artifact* may do, which is a different question from what a *person* may do,
and Palisade has to hold both.

### 2.1 Model

- **Permissions** (closed set): `tools.read`, `tools.write`,
  `communications.send`, `financial.execute`, `destructive.execute`.
- **Tool scopes** (closed set, descriptive): `read`, `write`,
  `external_comms`, `financial`, `destructive`.
- **Roles** — `{roleId, displayName, description, permissions[], predefined?}`.
- **Bindings** — `{principalId, roleIds[]}`. The principal is the artifact.
- **Project policy** — `{projectId, allowedToolIds[], roles[], bindings[],
  approvalRequiredPermissions?}`.

Predefined roles: `roles/exigence.viewer` (read), `roles/exigence.operator`
(read + write), `roles/exigence.communicator` (read + communications), and
`roles/exigence.fullAgent` (all five permissions).

### 2.2 Evaluation order, which is itself the contract

`evaluateToolInvocation` returns `allowed`, `approval_required` or `denied`,
and the **order of the checks is observable** because each produces a distinct
reason string surfaced to operators and written into the audit chain. Palisade
must preserve the order, not merely the verdict:

1. Tool not declared by the artifact → denied, "The automation does not declare
   this tool."
2. Tool not in the project's `allowedToolIds` → denied, "This tool is not
   enabled for the project."
3. No binding for the principal, or no bound role exists in the policy → denied,
   "The automation has no applicable project role."
4. Bound roles miss any of the tool's `requiredPermissions` → denied, "The
   assigned roles do not grant every required permission."
5. Otherwise: `approval_required` if any required permission is in
   `approvalRequiredPermissions` (default: write, communications, financial,
   destructive), else `allowed`.

Every evaluation emits an audit event `tool.permission.{outcome}` — so
authorization is already audited, satisfying that part of 6.1's definition of
done, and Palisade must not lose it.

### 2.3 Findings

- **Two independent allowlists must both pass**: the artifact's declared tools
  and the project's enabled tools. This is deliberate defence in depth and
  collapsing them into one list would weaken it.
- **Approval is permission-derived, not role-derived.** Any role holding
  `tools.write` triggers approval, regardless of which role granted it.
- **There is no boundary concept at all.** Exigence gates *what* a tool may do,
  never *where* the effect lands. Access and Effect Boundaries (Task 6.1.2) are
  genuinely new — nothing existing needs preserving, and nothing existing
  constrains their design.
- **The principal is an opaque string.** `automation.reference` is a
  convention, not a registered identity. Task 6.1.1's agent identity type is
  what turns this into something inspectable.

---

## 3. What Palisade must reconcile

The two models are not variants of one another; they answer different
questions and overlap only in vocabulary.

| | Platform | Exigence |
|---|---|---|
| Principal | a person, by email | an artifact, by opaque string |
| Granted by | membership arrays on an access doc | role bindings inside a project policy |
| Governs | which product operations may be called | which tools an artifact may invoke |
| Approval | none — a call is allowed or refused | first-class, permission-derived |
| Audited | no evaluation record | every evaluation, into the hash chain |
| Boundaries | none | none |

Both use the words "role", "admin/operator/viewer" and "permission" for
different things. A shared vocabulary that silently merges them would be the
easiest way to break the behaviour-preservation gate — for example, an
Exigence `roles/exigence.operator` has nothing to do with a platform
`ProjectRole.operator`, and the latter cannot even be held today.

**Recommended shape**, to be confirmed before schema work: Palisade holds one
identity registry and one permission vocabulary, but keeps *two distinct
permission families* — product operations and agent capabilities — rather than
flattening them. The resolved-effective-authority view (Task 6.1.3) is then the
thing that presents both to a human in one place, which is where the
intuitiveness requirement actually lives.

---

## 4. Test strategy for the behaviour-preservation gate

The gate says "proven by test". Concretely, before any consumer migrates:

1. **Golden-vector table for platform resolution** — every combination of
   `tenantRoles` × `developerProjectIds` × `viewerProjectIds` × project status
   × offering enabled × access class, asserted against today's resolver, then
   re-asserted against Palisade. Includes the unreachable-role cases, which
   must stay denials.
2. **Golden-vector table for Exigence evaluation** — every branch of §2.2
   including the exact reason strings, since they reach the audit chain.
3. Both tables run against **both** implementations in the same suite during
   migration, so drift fails the build rather than appearing in production.

## 5. Verification log

| Claim | Source |
|---|---|
| access chain and offering check | `platform_firestore_role_resolver.dart` |
| role derivation table | same file, the `roles` accumulation |
| access-class role sets | `_canAccessProject` in `platform_proxy_handler.dart` |
| operator/analyst unreachable | resolver grants only developer, admin, viewer |
| Exigence permissions, roles, bindings | `policy.ts` |
| evaluation order and reason strings | `evaluateToolInvocation` |
| audit event name | `tool.permission.${outcome}` |
