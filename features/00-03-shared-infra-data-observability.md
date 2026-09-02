# Feature 0.3 — Shared Infrastructure, Data, and Observability

## Status
Deferred for now, **except Task 0.3.6**, which supersedes the data topology
every other task here assumes. See DECISIONS.md 02/09/26.

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

---

## Task 0.3.6 — One database per product, per client

Decided 02/09/26. Replaces the arrangement in Tasks 0.3.1 and 0.3.2, where
clients share a GCP project and are separated by a per-client named database.

### Target

`citadel-platform` keeps `(default)` for the control plane: project registry,
Palisade authority, provisioning jobs, audit, alerts.

Each client gets **their own GCP project**, holding:

| Database | Holds | Provisioned when |
|---|---|---|
| `(default)` | The client's own business data; production wired to it | Client project setup |
| `citadel-arm` | Issues, cases, tickets | ARM enabled |
| `citadel-conduit` | Sessions, replays, funnels | Conduit enabled |
| `citadel-exigence` | Runs, checkpoints, knowledge base, billing | Exigence enabled |
| `citadel-palisade` | Palisade evidence — audit, crossings, refusals | Client project setup |
| `citadel-baker` | Catalogue and deployments | Baker enabled |
| `citadel-manifold` | Conversations, consent, media | Manifold enabled |
| `dev` / `test` / `staging` | Copies of the business database | Baker → Deployments enabled |

Each `citadel-*` holds all four environments' records, tagged. The business
databases are one per environment, because the client's application connects to
one at a time.

**A database per product, not one `citadel-data`, because Firestore IAM can
name a database and cannot name a collection.** One store would put every
product's service account on the same resource with application code as the
only separation — and Conduit holds session replays, which the permission
catalogue already treats as categorically different from the client's own
material.

### Subtasks

- **0.3.6.a** — **NOT BUILT.** Client project onboarding: take an
  operator-supplied project id, authorise as the operator, create service
  accounts, grant roles, link billing. APIs enabled per service as each is
  toggled on, not up front.

  Not started rather than half-built. It is an OAuth consent flow, a token
  exchange, server-side use of a human's credentials to create service accounts
  and grant IAM, and audit stamping that says Citadel acted as the operator —
  and a half-finished credential path is worse than none, because the half that
  exists looks like it works. See the risk recorded against it in DECISIONS.md
  02/09/26; the safer shape is still the operator granting Citadel's own
  service account the roles it needs on their new project once.
- **0.3.6.b** Replace `arm-data-plane` with a client data-plane template that
  creates `(default)` plus the `citadel-*` databases the enabled services need.
- **0.3.6.c** Move ARM off `(default)`: `ArmProjectTarget.databaseId` becomes
  `citadel-arm`, the router composes against it, and the SDK selects the
  database explicitly — the Firebase web config points at `(default)` unless
  told otherwise. Breaking change for existing integrations; needs an SDK
  release.
- **0.3.6.d** Move Exigence off the per-client named database onto
  `citadel-exigence`, and Manifold off the client Firestore onto
  `citadel-manifold`.
- **0.3.6.e** Environment tagging on every `citadel-*` record, and the query
  paths that filter by it.
- **0.3.6.f** Retire the shared client-host arrangement: `host_project_id`
  stops being a platform constant, `run_host_suffix` stops being derivable
  once, and the `client-host` root's `projectIamAdmin` containment note stops
  applying.
- **0.3.6.g** — **NOT NEEDED.** Existing clients are being cleared and
  re-onboarded from scratch before Citadel goes live, so there is no data to
  migrate. The compatibility hedges written for them have been removed: every
  database name is now fixed, `host_project_id` and `run_host_suffix` have no
  defaults, and ARM's per-project database override is gone. A setting whose
  only correct value is the constant is a way to be wrong.

### Open question
Whether `citadel-palisade` holds evidence only. Palisade's authority records
decide who may do what and must stay in the control plane — a client project
whose principals could rewrite their own grants would have no authority model
at all. Read as evidence pending confirmation.

### Built, 02/09/26

| | |
|---|---|
| 0.3.6.b | `client-data-plane` replaces `arm-data-plane`; `(default)`, the client's environment databases, and one `citadel-*` per enabled product |
| 0.3.6.c | ARM reads `citadel-arm`; `armDatabaseId` exported from the SDK |
| 0.3.6.d | Exigence on `citadel-exigence`; Manifold on `citadel-manifold` with its own IAM binding |
| 0.3.6.e | `environment` on ARM records, the capture request and both list filters |
| 0.3.6.f | `host_project_id` and `run_host_suffix` resolved per client from the record; the suffix read back off the address a deploy produced; `client-host` applied per client project |

Every database name defaults to the new value and is overridable per client, so
a client onboarded before the split keeps reading the records they have.
Repointing them at an empty database would report that they have none, which is
the worst way for a migration to go wrong.

**Known incomplete:** `manifoldSecretProjectId` still names the shared project.
The receiver grant check answers correctly for a pre-split client and would look
in the wrong project for a post-split one. Threading the client's project
through the verifier, the secret watchdog and two proxy routes is the piece left.

### Debt removed, 02/09/26

The compatibility layer written for existing clients came out once they were
confirmed to be disposable:

| Was | Is |
|---|---|
| `host_project_id` defaulted to the shared project | Required; the API resolves it from the record |
| `run_host_suffix` defaulted to Citadel's own | Required; the runner reads it off the first address it deploys |
| `exigence_database_id` a variable | Gone — `citadel-exigence` |
| ARM's `firestoreDatabaseId` override | Gone — `citadel-arm` |
| Manifold fell back to the runs database | Required; a deployment that does not say has not been configured |
| `manifoldSecretProjectId` a constant | `ManifoldSecretProjectLookup`, reading the client's project from the record |

`manifold_receiver_grant_test` used to pin the constant to the template's
default. There is no default now, so it pins the *absence* of one — a default
is exactly how the two would drift apart again without anything saying so.
