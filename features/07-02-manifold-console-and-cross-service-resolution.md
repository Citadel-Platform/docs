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
- [ ] One real report correlates to a real session and issue end to end
- [ ] An approved reply and an approved repair path both complete and audit
- [ ] Adversarial tests prove cross-project and over-broad context access fails
- [ ] Browser E2E shows the complete loop from report to resolution
