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
These were built across the 6.1 tasks and never ticked. Reviewed 30/08/26
against the code and the tests that hold each one, and marked with the evidence
rather than from memory.

- [x] All five identity types are manageable and project-scoped — `IdentityType`
      carries all five including `agent`, an artifact's identity being
      first-class in the same registry as a person's
      (`palisade/authority/lib/src/authority.dart`). Registration, disabling
      and the refusal of an unknown type are routed and tested
      (`platform_identity_service.dart`,
      `test/platform_identity_route_test.dart`), and no answer ever carries a
      credential. Scoping is structural rather than a check: a `Grant` is
      always project-scoped, because the platform hosts every client in one
      GCP project and an unscoped grant would be a cross-client exposure.
- [x] Access, Effect, and Data Handling Boundaries support documented selectors
      and precedence — the grammar is Chrome match patterns for URLs and
      picomatch globs for paths, chosen rather than invented and written down
      in `_dev/docs/palisade_boundary_grammar.md`. Data Handling resolves to
      exactly one of the four modes with class, source and destination
      selectors, approval policy and expiry (`boundary.ts`), and the Console
      publishes both boundary kinds as immutable revisions
      (`test/platform_boundary_route_test.dart`).
- [x] Overlapping allow/deny patterns resolve correctly under adversarial tests
      — eighteen cases in `palisade/boundary/test/boundary.test.ts`, and they
      are the adversarial ones rather than the happy path: deny wins
      regardless of rule order, a glob does not leak across a sibling prefix,
      a single star does not cross a separator, traversal is resolved before
      matching rather than matched literally, a symlink out of an allowed
      directory is caught only after `realpath`, a host wildcard matches
      subdomains but never the apex or a lookalike, and a malformed pattern is
      refused rather than silently narrowed.
- [x] Roles bundle permissions and boundaries; both direct and role-based
      grants work — a `Grant` carries `roleIds`, `permissions` and
      `boundaries`, and both paths resolve through the same evaluator. The
      route tests cover the cases that matter: an artifact granted
      capabilities directly, a capability outside the agent set refused, an
      unknown role refused rather than stored, and holding superdev in one
      project conferring nothing in another
      (`test/platform_grant_route_test.dart`).
- [x] Resolved effective authority renders for any identity in one view — the
      Console's Authority page shows the flattened answer with the role that
      conferred each permission, and what is withheld as well as what is held.
      A list of bindings is what makes cloud IAM unusable, so this is the
      resolved answer rather than the grants
      (`platform_palisade_pages.dart`, `test/platform_palisade_pages_test.dart`).
- [x] Exigence resolves its policy from Palisade with no behaviour change —
      the kernel kept its enforcement code and stopped owning the schema; the
      policy an artifact runs under is a published immutable configuration
      version resolved from the revision. Behaviour preservation is proven
      rather than asserted: `authority/test/migration_equivalence_test.dart`
      resolves every grant and operation under both models and pins that the
      operation table covers every permission that gates a route.
- [x] ARM resolves project roles from Palisade with no behaviour change — the
      same migration test covers it: a viewer gains exactly the read
      operations and nothing else, `configurationRead` and `adminMutation`
      collapse onto superdev only, and `invoker` is identified as the one
      genuinely new capability rather than being smuggled in as equivalence.
- [x] The local runner enforces boundaries independently of the cloud — the
      runner carries its own copy of the boundary evaluator and gates every
      intent on the client's machine before executing it. Access, Effect,
      classification, destination and expiry are each proven to refuse
      locally, with the cloud having already said yes
      (`localbridge/test/governance_enforcement.test.ts`,
      `localbridge/src/execute.ts`).
- [x] Every authorization evaluation is audited — recorded around the
      decision rather than after it, and the record carries no request body.
      The properties that make it trustworthy are the tested ones: a refusal
      is recorded *before* it is refused, one request that checks a permission
      produces exactly one record, and an audit sink that fails never changes
      an outcome (`test/palisade_authorization_audit_test.dart`).
- [x] Deny-by-default holds when Palisade is unreachable — fail closed, never
      open — every authorising route refuses when the registry cannot be
      reached, and the refusal says the registry is the problem rather than
      blaming the caller, so an outage does not read as a permissions
      complaint (`test/palisade_fail_closed_test.dart`). An unauthenticated
      caller is refused before the registry is asked at all.
- [~] Baker, Manifold and data-relay permissions resolve and fail closed —
      Manifold's five permissions are in the catalogue and fail closed like
      every other route. **Baker has no permissions at all** in
      `palisade/catalogue.json`, which is correct for now: Baker is a
      superdev-only Factory and Devstation and is not being built, so
      cataloguing its vocabulary ahead of it would be inventing a contract
      nothing enforces. **Data relay has no permissions of its own** either —
      the local runner is gated through the Exigence tool scopes an artifact
      declares, which works and is not what this line asks for.
- [~] Every cross-product data flow is attributable and visible in one audit
      view — the record is written to `palisade_data_flows` in the client's
      own project, read back over a window through `/exigence/data-flows`, and
      shown on the Palisade Watchdog beside the refusals. It is not yet
      complete: the only producer is the correlation source, so a flow crossing
      any other seam is still unrecorded. It is now reachable, though —
      `exigence.report.triage` declares `manifold.correlate` and the runtime
      composes it with the audited source rather than the raw one, so the
      audit has a producer that is not a test fixture.
- [~] Adversarial integration/E2E gates prevent external attack and
      cross-client leakage — the vectors Task 6.1.6 names are covered at unit
      level (forged and replayed webhook signatures, path and URL
      canonicalisation, an unavailable registry, a request naming another
      project) and several against the Firestore emulator
      (`*.integration.test.ts`, including `correlation_source.integration`,
      which proves a cross-project read is refused rather than answered from
      the wrong project). **Not covered:** the live/sandbox E2E gate the task
      explicitly says unit vectors are insufficient for. That needs a deployed
      artifact and a real project, which is the same thing Feature 7.2's first
      box is waiting on.

## Task 6.1.7 — Console surface changes (NEW 30/08/26)

From the feature-set review.

### Roles become a table, and custom roles become possible
A table — role, what it grants, whether it is editable — rather than a panel
per role. A section each read as documentation; roles are a set you compare,
and comparing stacked panels means scrolling between them.

Viewer, Invoker and Superdev stay **locked**, for a stronger reason than "they
are built in": they are what the API's own permission map is written against,
so editing one would change what every route means without any route knowing.

Custom roles need a store. `resolveEffectiveAuthority` resolves `roleIds`
against the built-in catalogue, so a role created today could not be granted to
anybody. That is the work: a role store, resolution against it, and the
multi-select of permissions in the form.

- [x] The page is a table and the built-in three are marked locked (30/08/26)
- [x] Custom roles are stored, resolvable and grantable (30/08/26).
      `PlatformPalisadeRoleService` holds a project's own roles; the Firestore
      resolver reads them only when a grant names a role the built-ins do not
      have, so the common case costs nothing
- [x] A custom role's permissions are edited as a multi-select (30/08/26) —
      over what Palisade actually defines, so a role cannot name a permission
      no route checks
- [x] A grant naming a deleted custom role fails closed (30/08/26). The role
      resolves to nothing and the id is reported in `unknownRoleIds` rather
      than dropped, so a delete that raced a grant narrows access and says it
      did (`palisade_role_service_test.dart`)

### Boundaries form
Applied 30/08/26. The dialog now states what the boundary being published
decides, that a revision is immutable and that deployed artifacts keep their
pin until republished; each field carries a helper; and the rule grammar —
deny wins, unmatched is denied, how `*` and `**` differ between paths and
URLs — is stated rather than assumed.

- [x] The form says what each input does without over-explaining

### Your Authority removed
Applied 30/08/26. It answered "why is this button missing" for the signed-in
operator; Access answers it for everybody, which is a superset.

- [x] Removed

### Access
Unchanged. It already shows which owners, developers, agents and artifacts
have access to a project and in what capacity.
