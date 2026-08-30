# Feature 5.3 - Baker Devstation

## Status
Deferred in sequencing. In scope when Baker is resumed.

## Scope
One superdev-only Compute Engine development VM per client. Devstation provides
a durable, reproducible environment for Docker, project CLIs and AI coding
CLIs, and lets the operator control the VM from the Console. CLI sessions are
managed manually over SSH in the first release.

## Tasks

### Task 5.3.1 - Terraform template
- Fixed, reviewed Terraform template for the VM, persistent disk, IAM,
  networking, labels, budgets and idle controls.
- One deployment instance per client; no gcloud resource-creation path.
- Default `us-central1-a`, `e2-custom-2-6144`, 60 GB `pd-standard`, stopped by
  default, configurable before provisioning, with 60-minute guarded idle stop.
- IAP/OS Login only; no public SSH ingress.

### Task 5.3.2 - Reproducible environment
- Versioned base image/startup configuration with Docker and required CLIs.
- Client workspace persists independently of process/session state.
- A unique keyless client-project identity may inspect and perform ordinary
  development/build work. IAM, API enablement, infrastructure, and deployment
  apply flow through the Palisade-authorized Terraform broker; the VM has no
  standing self-escalation authority.

### Task 5.3.3 - Console lifecycle
- Observe actual VM state and drive start, stop, suspend and resume operations.
- Show cost-relevant state, last activity, active workspace and failures.
- Apply idle shutdown and operator-set maximum runtime.

### Task 5.3.4 - Manual session access
- Surface IAP/OS Login connection guidance and actual VM reachability.
- Claude/Codex CLI sessions are started and resumed manually over SSH.
- Console session discovery/resume and remote-control handoff are deferred.

### Task 5.3.5 - Repair escalation
- A Palisade-authorized Exigence action may open a scoped repair task on the
  correct client's Devstation.
- Patch, tests, deployment and result are auditable and visible in the Console.

## Definition of done
- [ ] A client's Devstation provisions and destroys through reviewed Terraform
- [ ] Console state matches the Compute API after every lifecycle transition
- [ ] Manual SSH access works through IAP/OS Login without public ingress
- [ ] Cross-client workspace and credential access is denied by integrated tests
- [ ] Idle/cost controls and browser E2E lifecycle coverage pass
