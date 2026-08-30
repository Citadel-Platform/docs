# Feature 6.1 — Palisade IAM (NEW 14/08/26)

## Scope
Native identity and authorization for Citadel and everything running on it.
Cloud-provider-grade capability, deliberately not cloud-provider-grade
complexity. Once Palisade exists, all other Citadel products consume it for
identity, permissions and boundaries.

Palisade is a new product line. It blocks Feature 4.5 (artifacts need identities
and boundaries) and should be built alongside, not after.

Palisade also owns the complete authorization and data-flow oversight contract
for Baker, Manifold and trusted local relay. "Unguarded machine" never means
unauthenticated or fail-open.

## Authentication vs authorization — the dividing line
- **Firebase Auth** proves who a principal is (email/password + Google).
  Palisade uses it underneath. Do not rebuild authentication.
- **Palisade** owns the identity registry and every authorization question:
  what an identity may do, and where its effects may land.

## Core model

| Concept | Governs | Applies to |
|---|---|---|
| **Permission** | Citadel products and services | Citadel-owned resources |
| **Access Boundary** | where client data may be **read from** | client-generated data |
| **Effect Boundary** | where client data may be **written, modified, deleted, executed** | client-generated data |
| **Data Handling Boundary** | where matched content may be processed or relayed | client-generated data |
| **Role** | a named bundle of permissions and boundaries | granted to identities |

An identity may hold roles, or be granted permissions and boundaries directly.
Deny-by-default throughout. Every evaluation is audited.

## Task 6.1.1 — Identities
- Types: human operator, client user, external stakeholder, service account,
  **agent** (an artifact's identity).
- CRUD, project scoping, enable/disable, credential lifecycle.
- An artifact's identity is first-class and appears in the same registry as
  humans — this is what makes agent authority inspectable.

## Task 6.1.2 — Boundaries
- Granular to a path or URL, including pattern matching (globs for filesystem,
  URL patterns for web). Follow existing industry conventions for pattern
  syntax rather than inventing one; document the chosen grammar.
- Boundaries are evaluated identically in the cloud runtime and in the local
  runner (Feature 4.5). The runner enforces them independently — it does not
  trust the cloud to have checked.
- Explicit precedence rules for overlapping allow/deny patterns, documented and
  tested with adversarial cases.
- Data Handling rules resolve to exactly one of `noAccess`,
  `inSituProcessing`, `citadelRelay`, or `thirdPartyRelay`, with explicit data
  class/source/destination selectors, approval policy, expiry, and optional ARM
  capture for in-situ resources.
- Missing, invalid, expired, revoked, or unavailable handling policy resolves
  to `noAccess`; the most restrictive overlapping mode wins.

## Task 6.1.3 — Roles and grants
- Bundle permissions and boundaries into named, tagged roles.
- Grant a role to an identity, or grant permissions and boundaries directly.
- Show the **resolved effective authority** for any identity — the flattened
  answer to "what can this actually do", not just the list of grants. This is
  the intuitiveness requirement; a list of bindings is what makes cloud IAM
  unusable.

## Task 6.1.4 — Migration of existing models
- Extract the authorization model already learned in ARM (project roles,
  `platform_access`) and Exigence (permissions, roles, bindings, tool
  allowlists, approval gates) into Palisade's schema.
- Exigence's policy kernel keeps its enforcement code and stops owning the
  schema; it resolves policy from Palisade.
- ARM's project role resolution migrates to Palisade.
- Migration must be behaviour-preserving: existing access must resolve
  identically before and after, proven by test.

## Task 6.1.5 — Cross-product data-flow authority
- Catalogue Baker Factory/Devstation, Manifold ingress/egress and data-relay
  permissions using the same `<service>.<resource>.<verb>` vocabulary.
- Authorize both the initiating identity and the destination project/resource.
- Audit data class, direction, actor, resolved authority and outcome without
  copying secrets or sensitive payloads into the audit record.
- Detect authority/configuration drift between registry, runtime snapshot,
  runner/Devstation and provider configuration.

**Drift, partly (30/08/26).** Task 6.1.5's last bullet asked for detection of
authority and configuration drift. The Console now compares every artifact's
pinned Access, Effect and Data Handling boundary revisions against what the
project has published, on the Palisade Watchdog: behind, digest mismatch, or
naming a boundary nothing has published. This is the case the pinning design
creates — a boundary narrowed in the Console changes nothing for a deployed
artifact until it is republished, and until now no screen said so. Still
undetected: drift between the registry and deployed IAM, and between a
runner's local configuration and what the project believes it is.

## Task 6.1.6 — Adversarial acceptance gates
- Test forged/replayed provider webhooks, credential theft/revocation,
  cross-project identifiers, confused-deputy routes, oversized relay, path/URL
  canonicalisation, policy changes during a run and unavailable registries.
- Run integrated and live/sandbox E2E gates for security-critical paths; unit
  vectors alone are insufficient.

## Definition of done
- [ ] All five identity types are manageable and project-scoped
- [ ] Access, Effect, and Data Handling Boundaries support documented selectors and precedence
- [ ] Overlapping allow/deny patterns resolve correctly under adversarial tests
- [ ] Roles bundle permissions and boundaries; both direct and role-based grants work
- [ ] Resolved effective authority renders for any identity in one view
- [ ] Exigence resolves its policy from Palisade with no behaviour change
- [ ] ARM resolves project roles from Palisade with no behaviour change
- [ ] The local runner enforces boundaries independently of the cloud
- [ ] Every authorization evaluation is audited
- [ ] Deny-by-default holds when Palisade is unreachable — fail closed, never open
- [ ] Baker, Manifold and data-relay permissions resolve and fail closed
- [~] Every cross-product data flow is attributable and visible in one audit
      view — the record is written to `palisade_data_flows` in the client's
      own project, read back over a window through `/exigence/data-flows`, and
      shown on the Palisade Watchdog beside the refusals. It is not yet
      complete: the only producer is the correlation source, so a flow crossing
      any other seam is still unrecorded, and no artifact declares the tool
      that produces even that one.
- [ ] Adversarial integration/E2E gates prevent external attack and cross-client leakage
