# Feature 5.3 - Baker Devstation

## Status
**Built and verified end to end, 05/09/26.** Provisioned, started, connected
to over SSH, stopped and destroyed for `user-test-1` in `testproj-448205`,
entirely from the Console.

Five defects were found by driving it, and only one of them was the
Devstation's own: F-102 (Start offered for a machine that does not exist),
F-103 (the panel named an approval page that does not exist), F-104
(templates that never enabled the services they build into — which caught
`client-data-plane`, `exigence-runtime` and `exigence-agent` as well), F-105
(the provisioner had no Compute or custom-role permission in a client's
project) and F-106 (a teardown could be planned and never approved).

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
- [x] A client's Devstation provisions and destroys through reviewed Terraform
      (05/09/26). 19 resources created from the Console, then 23 destroyed —
      the extra four being the API enablements F-104 added. Instance, both
      disks, network and identity all confirmed gone afterwards, and the
      record reset to `notConfigured` by the runner rather than left stale.
- [x] Console state matches the Compute API after every lifecycle transition
      (05/09/26). The page reads Compute on every load and says "Observed from
      Compute on …"; a machine it could not reach keeps its stored state and
      gains no `observedAt`, because the honest answer is that nobody knows.
- [x] Manual SSH access works through IAP/OS Login without public ingress
      (05/09/26). `gcloud compute ssh --tunnel-through-iap` reached it with no
      external IP on the instance, one ingress rule for `35.235.240.0/20` on
      port 22 and an explicit deny for everything else, on the Devstation's
      own VPC rather than the client's default network.
- [x] Idle/cost controls (05/09/26). Both timers armed on the live machine:
      the guard on a five-minute tick, the ceiling at 720 minutes from boot.
      The Console quotes the $12.40/month disk floor before anything is built.
- [x] Browser E2E lifecycle coverage (05/09/26). Provision, start, stop and
      destroy were each driven from the Console in Chrome, not by API call.
- [ ] Cross-client workspace and credential access is denied by integrated
      tests. Structurally prevented — each client's Devstation is a separate
      VM, VPC, disk and service account in the client's own project — but no
      test asserts it, and there has only ever been one Devstation.
