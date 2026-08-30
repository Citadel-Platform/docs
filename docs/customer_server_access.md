# Customer Server Access

## Contract

Customer Firestore and Cloud Storage data is server-only. Firebase Security
Rules deny every client read and write. A project manifest names one non-secret
Citadel runtime service-account email, and customer-project IAM grants that
principal only the roles required by enabled products.

| Product | Scope | Role | Purpose |
| --- | --- | --- | --- |
| ARM | Customer project | `roles/datastore.user` | Read and write ARM issue/case evidence |
| ARM | Declared evidence bucket | `roles/storage.objectUser` | Create, read, update, and remove ARM objects |
| Conduit | Customer project | `roles/datastore.user` | Read and write Conduit evidence |

Duplicate requirements collapse to one binding. Extra unrelated IAM bindings
are not treated as Citadel drift. Exigence requirements remain undefined until
that feature publishes its customer data paths and runtime identity needs.

## Operator Flow

1. Declare `project.citadelServiceAccount` in the versioned project manifest.
2. Run `citadel project onboard --manifest path` to read the customer project's
   project and bucket IAM policies.
3. Review missing exact member/role bindings in the deterministic dry-run plan.
4. Apply the reviewed bindings through the future Terraform reconciliation
   step. Do not add them manually in the Firebase or Google Cloud consoles.
5. Re-run the CLI until cross-project IAM reports `satisfied`.

The observer uses only `gcloud projects get-iam-policy` and, when ARM declares a
bucket, `gcloud storage buckets get-iam-policy`. Permission denial or malformed
policy output remains an unknown blocker; a successfully read policy missing an
exact unconditional binding is drift.

Rules drift observation uses the read-only Firebase Rules management API. The
CLI obtains a short-lived access token from the active gcloud session, keeps it
in memory, sends the target project as the quota project, reads the active
`cloud.firestore` and `firebase.storage/{bucket}` releases, and fetches their
immutable rulesets. The token and remote rule source are never printed. Missing
or different source is drift; authentication, permission, transport, and
malformed-response failures remain unknown. This requires
`firebaserules.googleapis.com` in the onboarding API policy.

## Runtime Migration

Conduit persistence already separates its Citadel service credential from the
resolved customer Firestore target. Its Console query paths still require
server API equivalents before browser reads can be denied. ARM does not yet
have the same complete ingestion boundary: its Flutter sink writes directly as
a Firebase client, while its server sink derives the target project from the
supplied credential. ARM Console reads also remain client-side. Customer rules
must therefore not be deployed to active projects until ARM server ingress,
explicit target-project routing, and the required ARM/Conduit server query
endpoints replace those direct client operations.

Production services should ultimately use keyless runtime identity rather than
downloaded service-account keys. Existing JSON credential adapters are a
compatibility boundary, not the desired deployment mechanism.
