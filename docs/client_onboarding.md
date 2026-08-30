# Onboarding a client onto Citadel ARM

This is the end-to-end procedure for putting a new client application under
Automated Remote Monitoring. It is written from the live `axis-education` /
`luminary-axis-dashboard` onboarding, so every step here has been executed at
least once against a real customer project.

Budget roughly half a day for the first one, an hour once it is routine.

## The model, in one paragraph

Two Google Cloud projects, one controlled boundary. **Citadel**
(`citadel-platform`) owns the Console, the project registry, and the runtime
service accounts. The **customer project** owns its own Firestore and keeps
every byte of ARM evidence. Nothing copies customer data into Citadel. Console
browsers never touch customer Firestore: they call the Platform API, which
verifies a Citadel Firebase identity, resolves the caller's role from the
registry, and then calls a private evidence service that reads the customer
boundary using a service account the customer project has explicitly granted.

```text
Client app  ──► client's server ──► client Firestore (armIssues, armCases)
                                          ▲
Citadel Console ──► Platform API ─────────┘
                    (verifies identity,   via private ARM evidence service
                     resolves role)       using roles/datastore.user
```

## What you need before starting

| Thing | Why |
| --- | --- |
| The customer's Google Cloud project ID | Evidence stays there |
| Owner or `roles/resourcemanager.projectIamAdmin` on that project | To grant Citadel read access |
| The client application's source repository | The SDK is wired into it |
| A Citadel project ID (slug) you will use | e.g. `axis-education` |
| Emails of the people who will use the Console | They become developers or viewers |

The Citadel project ID must match `^[a-z][a-z0-9-]{2,62}$`. It is a Citadel
identifier and does **not** have to equal the customer's GCP project ID.

---

## Step 1 — Register the project in Citadel

Sign in to https://citadel-platform.web.app as a tenant owner and use
**Project onboarding** from the project selector. That writes a record to
`platform_projects/{projectId}` in Citadel Firestore with:

- `firebaseProjectId` — the customer project that holds the evidence. **The
  private evidence service routes on this field**; get it wrong and reads go to
  the wrong boundary or fail closed.
- `status: active`
- `offeringScope.arm.enabled: true`
- `developerEmails` / `viewerEmails`

It also writes matching `platform_access/{email}` records. Roles resolve as:

| Registry list | Console role | Can change case/issue status |
| --- | --- | --- |
| `developerProjectIds` | developer + admin | yes |
| `viewerProjectIds` | viewer | no |
| tenant `owner` | admin on every project | yes |

The Platform API refuses any project that is not `active` or does not have the
requested offering enabled, so this record is a real gate, not decoration.

## Step 2 — Grant Citadel read access to the customer project

This is the only permission the customer grants, and the only way into their
data. Copy the Terraform root from an existing customer:

```sh
cp -r citadel_core/platform/infra/environments/production/customers/axis-education \
      citadel_core/platform/infra/environments/production/customers/<new-project>
```

Edit three things — the backend prefix in `terraform.tf`
(`customers/<new-project>/iam`), and the `customer_project_id` default in
`variables.tf`. Then:

```sh
cd citadel_core/platform/infra/environments/production/customers/<new-project>
terraform init
terraform plan -out=customer.tfplan     # expect exactly 1 to add
terraform apply customer.tfplan
```

This grants `roles/datastore.user` on the customer project to
`citadel-arm-evidence@citadel-platform.iam.gserviceaccount.com`.

**The identity running Terraform needs both** write access to
`gs://citadel-platform-terraform-state` and IAM-admin on the customer project.
If those are different accounts, grant one of them the missing half first —
splitting the apply across two identities will strand the state.

No Cloud Storage grant is needed unless the client persists ARM screenshots.
When it does, add bucket-scoped `roles/storage.objectUser`, not project-wide.

## Step 3 — Wire the SDK into the client application

Add the ARM package, pinned to an exact commit:

```yaml
# client app pubspec.yaml
dependencies:
  arm_tooling:                       # Flutter client
    git:
      url: https://github.com/Citadel-Platform/ARM.git
      path: tooling
      ref: <commit sha>
```

```yaml
# client server pubspec.yaml
dependencies:
  arm_tooling_server:                # Dart backend
    git:
      url: https://github.com/Citadel-Platform/ARM.git
      path: tooling_server
      ref: <commit sha>
```

Pin the **same** commit in both. A client and server on different SDK versions
will write inconsistent document shapes into one collection.

### Client side

Wrap the app so uncaught errors are captured, and route captures through your
own server rather than writing Firestore directly:

```dart
await ArmBootstrap.runGuarded(
  client: armClient,
  body: () async {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const MyApp());
  },
);
```

Use `ArmClient.guard(...)` around operations you want attributed to a feature.
Errors caught this way are recorded with `handled: true` — that records *that
your app caught it*, and has no bearing on triage state.

### Server side

The server verifies the caller's Firebase ID token and writes with its own
service account:

```dart
final sink = await FirestoreServiceAccountArmSink.fromServiceAccountJson(
  serviceAccount: serviceAccountJson,
);
```

Expose one authenticated intake endpoint (`POST /api/arm/intake` by
convention), verify the ID token with revocation checking, bound the payload,
and call `sink.record(...)`.

## Step 4 — Lock the customer boundary

Deploy rules that deny **all** browser access to ARM paths. Render them from
the versioned assembler rather than hand-writing:

```sh
dart run citadel_core/platform/customer_rules/bin/render_customer_rules.dart
```

```
match /armIssues/{document=**} { allow read, write: if false; }
match /armCases/{document=**}  { allow read, write: if false; }
```

Rules do not apply to service accounts, so the server keeps working; only
browsers are shut out.

**Deploy in this order or you will break the client app:**

1. Server (activates the intake endpoint)
2. Client (starts using the intake endpoint)
3. Rules (denies the old direct-write path)

Deploying rules before the client is live breaks capture for every user still
on the old build.

## Step 5 — Verify

Trigger a real error in the client application, then check in order:

1. **Evidence landed** — `armIssues` and `armCases` in the customer project
   have a new document, with `createdAt` as a `timestampValue` and
   `status: "new"`.
2. **The Console shows it** — open ARM ▸ Case Logs for the project. The case
   appears as **New** with its stack trace on the detail page.
3. **Triage works** — change the status; confirm `statusUpdatedBy` in Firestore
   records the operator email and `handled` is unchanged.
4. **The boundary holds** — a browser read of `armCases` in the customer
   project is denied.

If the Console shows *"ARM data is not readable yet"*, work down this list:

| Symptom | Cause |
| --- | --- |
| `ClientException: Load failed` | Console origin missing from `console_allowed_origins` |
| HTTP 403 | Account has no role on the project, or the project is not `active` / ARM-enabled |
| HTTP 503 | Customer IAM grant missing — the evidence service cannot read the boundary |
| `No Platform API is configured` | Console built without `CITADEL_PLATFORM_API_BASE_URL` |

## Step 6 — Register any new Console domain

A domain serving the Console must be registered in **two** places, and missing
either produces a confusing failure:

1. **Firebase Auth authorized domains** (Firebase console) — otherwise sign-in
   fails.
2. **`console_allowed_origins`** in
   `citadel_core/platform/infra/environments/production/runtime/variables.tf`,
   then `terraform apply` — otherwise sign-in succeeds but every API call fails
   CORS preflight with a bare "Load failed".

---

## Things that will bite you

**`handled` is not triage state.** It records whether the application caught
the error. A case is New until an operator says otherwise. Never infer status
from it — the Console did exactly that once and hid twelve live invoicing
failures behind a "Resolved" label.

**Capture must never write operator fields.** Firestore `patch` without an
update mask, and `set` without merge, both replace the whole document. Issue
documents are upserted on every recurrence, so an unmasked write erases the
operator's triage. The SDK masks its writes; keep it that way.

**Timestamps must be real timestamps.** Firestore orders by value type before
value, so a collection mixing `timestampValue` and ISO strings cannot be
ordered or paged on that field. If an older SDK wrote strings, run:

```sh
python3 citadel_core/arm/tool/backfill_arm_evidence.py \
  --project <customer-project> --account <you> \
  --apply --backup ./backup.json
```

It is dry-run by default and requires an explicit backup path to write.

**Case pages are small on purpose.** Case records carry full stack traces and
run to roughly 100 KB each; the Platform API caps responses at 1 MiB. The
Console requests five per page. Raising that will fail whole workspace loads.

**The evidence scan is bounded.** The private service orders evidence in memory
over a bounded scan (`CITADEL_ARM_MAX_SCAN_DOCUMENTS`, default 5000) and fails
loudly past the cap rather than silently truncating. A high-volume client needs
that raised, or indexed pagination implemented once all its timestamps are
consistent.

## Offboarding

1. `terraform destroy` the customer IAM root — removes Citadel's only access.
2. Set `status: archived` on the registry record.
3. Remove the SDK dependency and intake endpoint from the client app.

Evidence stays in the customer's project. Citadel holds no copy to delete.
