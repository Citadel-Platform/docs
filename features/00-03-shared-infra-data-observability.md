# Feature 0.3 — Shared Infrastructure, Data, and Observability

## Status
Deferred for now. Skip this feature until Terraform-dependent work is resumed.

## Scope
Create the infrastructure and data-stack baseline shared by all Citadel offerings.

## Tasks

### Task 0.3.1 — Terraform baseline
- Create `infra/` with Terraform environments for dev and prod.
- Add modules only as needed: Firestore/Firebase, Cloud Run, Pub/Sub, BigQuery, Storage, IAM, Secret Manager, and hosting.
- Ensure every Terraform resource has tags/labels.
- Use project `citadel-platform`, region `us-central1`, and zone `us-central1-a` by default.

### Task 0.3.2 — Data-store baseline
- Define Firestore collections for platform registry and product metadata.
- Define BigQuery datasets for Conduit and cross-product analytics.
- Define Cloud Storage buckets for screenshots, report exports, generated artifacts, and product evidence.
- Define Pub/Sub topics for ingestion, usage events, report jobs, and automation triggers.

### Task 0.3.3 — Secrets and configuration
- Define Secret Manager resources for provider/API secrets.
- Keep local secrets in `.env` only.
- Document required local environment variables per product.

### Task 0.3.4 — Observability contract
- Standardize request logging fields: `requestId`, `tenantId`, `projectId`, `actorId`, `offering`, and `route`.
- Define audit event emission for mutating admin actions.
- Route internal product errors into ARM once ARM consolidation validates.

## Definition of done
Reviewed 30/08/26 against the tree.

- [x] Terraform validates for active environments — `terraform validate`
      passes for `provisioner/templates/exigence-runtime`,
      `provisioner/templates/exigence-agent` and
      `citadel_cli/tool/terraform/state_backend` (30/08/26).
- [x] Shared data resources are documented and provisioned through Terraform
      — each client's Firestore database, payload bucket and service accounts
      are Terraform resources in the runtime template, and the state backend
      is itself Terraform (`_dev/docs/terraform_state_backend.md`). Nothing is
      created by hand.
- [~] Secret handling is documented without committed secret values — the
      *practice* is settled and enforced: secrets are Secret Manager version
      references pinned in configuration, never values, and publishing a
      channel refuses a pasted token outright. **The documentation is
      scattered** across `project_registry_contract.md`,
      `exigence_palisade_phase_plan.md` and the verification source rather
      than being one page somebody can be pointed at.
- [x] Observability fields are consistent across services — the mapping is
      written down in `_dev/docs/otel_genai_field_map.md`, including where the
      OTel GenAI conventions have no answer (cost) and what the `citadel.*`
      namespace covers instead. Request ids, run ids and trace ids carry
      through the proxy, the runtime and the Console consistently.
