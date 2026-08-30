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
- [ ] Terraform validates for active environments
- [ ] Shared data resources are documented and provisioned through Terraform
- [ ] Secret handling is documented without committed secret values
- [ ] Observability fields are consistent across services
