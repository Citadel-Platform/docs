# Terraform state backend

## Live boundary

Citadel Terraform state is stored in the Citadel-owned Google Cloud Storage
bucket `citadel-platform-terraform-state` in project `citadel-platform` and
region `US-CENTRAL1`. The bucket was created through the reviewed bootstrap
stack on 18 July 2026; the bootstrap stack itself is tracked remotely at
`bootstrap/state-bucket`.

The bucket is intentionally narrow infrastructure. It stores Terraform state
and lock objects only; it is not a customer evidence, report, screenshot, or
application-data bucket.

## Protection posture

- Standard regional storage in `US-CENTRAL1`.
- Uniform bucket-level access and enforced public-access prevention.
- Object versioning plus 30-day soft-delete recovery.
- Terraform `PREVENT` deletion policy, `prevent_destroy`, and
  `force_destroy = false`.
- Labels: `application=citadel-platform`, `environment=production`,
  `managed_by=terraform`, and `purpose=terraform-state`.
- No credentials, access tokens, service-account keys, or encryption keys are
  stored in backend configuration. Operators authenticate through Application
  Default Credentials.

## State layout

- Backend bucket ownership: `bootstrap/state-bucket`.
- Customer onboarding IAM: `customers/{projectId}/iam`.

Each customer manifest produces its own deterministic `.tfbackend` file. This
keeps customer lifecycle state separate while retaining one understandable
Citadel-owned bucket and one locking mechanism.

## Operator workflow

The canonical bootstrap root and recovery instructions live in
`citadel_cli/tool/terraform/state_backend`. A normal checkout must enable the
partial GCS backend and initialize against `bootstrap.gcs.tfbackend`; it must not
repeat the local first-bootstrap flow.

Generated customer modules initialize with:

```bash
terraform init -backend-config=customer.gcs.tfbackend
```

The CLI keeps rendering, review, and mutation as separate commands:

```bash
citadel project terraform render --manifest client.yaml --output customer-iam
citadel project terraform plan --manifest client.yaml --directory customer-iam --confirm-project PROJECT_ID
citadel project terraform apply --manifest client.yaml --directory customer-iam --confirm-apply PROJECT_ID
```

Planning initializes the isolated backend, saves `citadel.tfplan`, inspects it,
and writes `citadel.plan.json`. The receipt binds the full semantic manifest,
rendered module, project ID, saved-plan bytes, and deterministic action summary
with SHA-256 digests. Operators must review the summary and receipt before
running the separate apply command.

Apply accepts only that saved plan. Before Terraform starts it requires an exact
project confirmation and rejects a changed manifest, module, plan, receipt, or
existing `citadel.apply.json`. It re-inspects the plan, applies the explicit plan
file under the normal backend lock, and requires a subsequent detailed-exit-code
plan to report zero drift. Only then does it atomically publish
`citadel.apply.json`; this receipt prevents accidental replay. Raw Terraform
stdout and stderr are bounded and are not echoed by the CLI.

This execution boundary manages only the generated additive customer IAM member
resources. It does not deploy Firebase Rules, create projects/APIs/databases or
buckets, seed registry/access records, or configure alerting, retention,
licensing, and report schedules.

## Recovery rules

Do not use `-force-copy`, `-reconfigure`, `force-unlock`, or `terraform state
push` during ordinary operation. Do not delete local state or a recovery copy
until `terraform state pull` represents the same resources and a remote-backed
plan reports no changes. Lock overrides and state pushes require a separately
reviewed incident procedure.
