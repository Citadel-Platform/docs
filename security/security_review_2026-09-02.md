# Citadel Platform — Security & Privacy Review

**Date:** 2026-09-02
**Scope:** Static (code across `citadel_core`, `citadel_platform`, `citadel_cli`), dynamic (live public endpoints), internal (GCP project `citadel-platform` infra/IAM/storage/Firestore).
**Access:** Insider — operator GCP credentials (owner on `citadel-platform`), full source tree.
**Constraint honoured:** read-only / non-mutating throughout (another agent was actively developing `test-sandbox` and the platform during the review). No resources created, modified, or destroyed; only `list`/`get`/`describe`, unauthenticated GET probes, and reads of build/state artifacts.

---

## 0. Executive summary

The application-layer security of this platform is **well above average** for a solo-operator build. Authentication, authorization (Palisade), the public support-ticket flow, webhook signature verification, and per-service IAM isolation are carefully designed and, in most places, correctly implemented. The real exposure is not in the request path — it is in **build/supply-chain hygiene, privilege concentration, and data-plane resilience.**

One finding is **Critical** and should be fixed today (live third-party API keys are exfiltratable from a build bucket). Two are **High** (no control-plane backups; owner-equivalent privilege reachable from a public service). The rest are medium/low hardening.

| # | Severity | Finding | One-line fix |
|---|----------|---------|--------------|
| C1 | **Critical** | Live OpenAI / npm-publish / Resend keys shipped in Cloud Build source tarballs, readable by any project viewer | Rotate all three now; add `.env` to `.gcloudignore`; purge bucket; tighten bucket |
| H1 | **High** | Registry Firestore (all Palisade grants/identities/projects) has no PITR, no delete-protection, no backups | Enable PITR + daily backups + delete protection |
| H2 | **High** | Public `citadel-platform-api` can execute the owner-equivalent `citadel-provisioner` job (`run.jobs.runWithOverrides`) — in-app authz is the only barrier | Split provisioning privilege; drop `runWithOverrides`; add a second control |
| H3 | **High** | Default compute SA has `roles/editor` and is enabled | Disable it / strip editor |
| M1 | Medium | Public ticket `verify` (send-code) endpoint has no rate limit → email-bombing + Resend cost abuse | Throttle per ticket/address/IP |
| M2 | Medium | Conduit ingest key is browser-visible; no origin allowlist or rate limit → data poisoning + cost inflation | Add rate limiting + origin checks + quota |
| M3 | Medium | Session-replay text masking defaults to OFF; ARM screenshots stored unredacted | Mask-by-default; document consent/DPA |
| M4 | Medium | `citadel-platform_cloudbuild` bucket: PAP `inherited`, legacy ACLs, no lifecycle expiry | Enforce PAP + UBLA + lifecycle |
| L1–L5 | Low | Dev origins in prod CORS; ingress=all; `email_verified` absent-passes; no Run deletion-protection; Firebase keys in tfstate (informational) | See §4 |

---

## 1. Critical

### C1 — Live third-party secrets exfiltratable from the Cloud Build source bucket
**Evidence.**
- Repo-root `.env` contains **live** `OPENAI_API_KEY` (`sk-proj-…`), `NPMJS_PAT` (`npm_…`), `RESEND_API_KEY` (`re_…`).
- The provisioner build (`cloudbuild.provisioner.yaml`) uses the **repository root** as its build context. The root `.gcloudignore` excludes `.git`, `node_modules`, build dirs, `_reference/` — but **not `.env`**.
- Confirmed by download: root-context source tarballs in `gs://citadel-platform_cloudbuild/source/*.tgz` contain a top-level `.env` with all three live keys in plaintext (e.g. object `1788346059.704123-…​.tgz`).
- That bucket grants read to **`projectViewer:citadel-platform`** via legacy ACLs (`roles/storage.legacyBucketReader`/`legacyObjectReader`), and additionally to `citadel-exigence-builder` / `citadel-platform-builder` (`storage.objectViewer`) and the default compute SA (editor). The bucket's `public_access_prevention` is `inherited` (not enforced) and UBLA is **off**.

**Impact.** Anyone ever granted `roles/viewer` (or any legacy-ACL viewer) on the project — a future contractor, a client given read access by mistake, a compromised builder SA — can download the source archive and read all three keys. The OpenAI key can run up unbounded spend; the npm PAT can publish/overwrite packages under your account (supply-chain); the Resend key can send mail as your verified domain (phishing as Citadel). Keys are long-lived and were never rotated.

**Fix.**
1. **Rotate all three keys now** (OpenAI, npm, Resend), independent of everything else — assume disclosed.
2. Add `.env`, `*.env`, `**/.env` to the root `.gcloudignore`.
3. Purge existing archives: `gcloud storage rm gs://citadel-platform_cloudbuild/source/**` (they are regenerated per build), or delete the bucket contents and re-run a build.
4. Move any secret the build genuinely needs into Secret Manager and inject at deploy, never via the source tree.
5. Set the bucket to `public_access_prevention=enforced`, UBLA on, and a short (e.g. 7-day) object-lifecycle delete.

---

## 2. High

### H1 — Control-plane Firestore has no recovery
**Evidence.** `gcloud firestore databases describe (default)` on `citadel-platform` →
`POINT_IN_TIME_RECOVERY_DISABLED`, `DELETE_PROTECTION_DISABLED`; `backups schedules list` → **0 schedules**.
This database holds `palisade_grants`, `palisade_identities`, `platform_projects`, boundary revisions — the entire authority/authorization plane for every client.

**Impact.** A single accidental deletion or corruption (the project has *already* lost `demo-project`/`demo-sandbox` data to fat-finger deletes, per `AGENTS.md`) wipes all grants and identities: every client locked out, no rollback. A bad script writing wrong grants has no point-in-time restore. This is the highest-likelihood catastrophic event for this platform.

**Fix.** Enable **delete protection**, enable **PITR** (7-day window), and add a **daily backup schedule** (`gcloud firestore backups schedules create`, or Terraform `google_firestore_database` `point_in_time_recovery_enablement` + `delete_protection_state` and a `google_firestore_backup_schedule`). Do the same for each **client** database as it is provisioned (fold into the runtime template).

### H2 — Owner-equivalent execution is reachable from a public service
**Evidence.**
- `citadel-provisioner@` holds: `datastore.owner`, `iam.serviceAccountAdmin`, `iam.serviceAccountUser`, `resourcemanager.projectIamAdmin`, `run.admin`, `storage.admin`, `serviceusage.serviceUsageAdmin`, `cloudscheduler.admin`, `cloudtasks.admin`. `projectIamAdmin` + `serviceAccountAdmin` = **can grant itself owner** → owner-equivalent.
- The provisioner **runs as that SA**. The public `citadel-platform-api` SA holds a custom role **`citadelProvisioningJobStarter` = `run.jobs.run` + `run.jobs.runWithOverrides`**, i.e. it can execute that job (and override its container args/env at run time) without needing `actAs` at execution.
- Chain: **internet → `citadel-platform-api` (public, `allUsers` invoker) → in-app authz (`platform.projects.update`, superdev-only) → runs `citadel-provisioner` → Terraform as owner-equivalent.**

**What's already right:** the bootstrap/retire/scope routes each require `platform.projects.update` resolved through Palisade (superdev grant), and only the operator can *impersonate* the provisioner SA directly. The barrier is real.

**Impact.** The *only* thing between the public internet and owner-equivalent Terraform runs is the platform API's own authorization logic. Any authn/authz bypass, or any flaw in how overrides are built, escalates straight to project takeover. `runWithOverrides` widens this: a caller who reaches the execution path can influence the job's container invocation.

**Fix (defense-in-depth, in priority order).**
1. Drop `run.jobs.runWithOverrides` from the custom role unless overrides are genuinely used; keep only `run.jobs.run`.
2. Split the provisioner's power: separate SAs for IAM changes vs. resource CRUD; remove `projectIamAdmin`+`serviceAccountAdmin` from the same identity if possible, or scope IAM changes to a narrow custom role.
3. Add a second control on destructive provisioning (retire/destroy): an out-of-band approval or a queue the operator drains, rather than synchronous execution from the public API.
4. Consider `ingress=internal-and-cloud-load-balancing` for the API and front it with IAP/known origins where feasible.

### H3 — Default compute service account has Editor and is enabled
**Evidence.** `790988281903-compute@developer.gserviceaccount.com` → `roles/editor`, `disabled` field empty (enabled).
No current Cloud Run service uses it (all three use dedicated least-privilege SAs — good), but Cloud Build and any future Cloud Run/Functions/Job created without an explicit SA default to it.

**Impact.** Latent broad privilege. A build step or a future resource that defaults to this SA gets project-editor; combined with a compromised build input, that is a wide blast radius.

**Fix.** Disable the default compute SA (`gcloud iam service-accounts disable …`) or strip `roles/editor` and grant only what actually needs it. Ensure all builds/jobs specify an explicit least-privilege SA.

---

## 3. Medium

### M1 — No rate limit on the public ticket `verify` (send-code) endpoint
**Evidence.** `platform_proxy_handler.dart` rate-limits ticket *replies* (`_publicTicketReplyLimit=20/h`) but the `…/verify` branch calls `codes.challenge(...)` with no per-ticket/per-address/per-IP throttle. `TicketAccessCodes.challenge` sends an email whenever the address is on the ticket allowlist.

**Impact.** Anyone holding a *restricted* ticket link can send unlimited "Your code for support ticket X" emails to any allowlisted address (email-bombing a customer/colleague) and burn Resend send quota/cost. Blast radius is limited to holders of a restricted link, but it is unauthenticated abuse.

**Fix.** Throttle challenge issuance (e.g. ≤3 codes / 10 min / (ticket,address), and a per-IP cap). Reuse the "counted from the ticket itself" pattern or a small counter doc.

*Note:* the redeem/brute-force side is solid — 6-digit HMAC-digested codes, 5-attempt cap, single-use, 10-min expiry, constant-time compare, no allowlist oracle, ticket-bound signed sessions.

### M2 — Conduit ingest key is browser-visible; no origin/rate controls
**Evidence.** Ingest routes (`/v1/events`, `/v1/replay`, `/v1/heatmaps/surfaces`, `/v1/voc/*`, survey responses) authenticate via `x-conduit-key`, and `GET /v1/config/{projectKey}` returns config keyed by that same value (path, 60s public cache). Session replay/heatmaps/analytics run in the end-user's browser, so the key is necessarily present in client-side JS. No origin allowlist or rate limiting is applied at ingest (reads are correctly gated by operator OIDC).

**Impact.** Anyone who reads a target site's Conduit key can POST forged analytics/replay/survey/VoC data into that project's dataset (data poisoning) and inflate Firestore/storage cost. Inherent to browser analytics, but currently the key is the only control.

**Fix.** Add per-project ingest **rate limiting / quotas**, an **origin allowlist** per project (reject events whose `Origin`/referer isn't registered), and payload-size caps (some exist). Consider short-lived signed ingest tokens minted from the key for higher-value streams (replay).

### M3 — Replay masking defaults off; screenshots unredacted (privacy)
**Evidence.** Conduit SDK supports `maskingSelectors`/`maskingRules`, `shouldMaskText`→`[masked]`, `apiHostBlocklist`, and IP truncation — but `maskingSelectors`/`maskingRules` **default to `[]`** (opt-out model). ARM `arm_firebase_sink.dart` uploads screenshots to client storage with no redaction step.

**Impact.** With default config, session replay and heatmaps can capture end-user PII typed into non-password fields; ARM screenshots can capture PII on screen. Data stays in the *client's* own project (they own it), but this is a consent/DPA obligation and a breach-amplifier.

**Fix.** Ship **mask-by-default** for replay text inputs (opt-in to capture specific fields), document the masking contract to clients, and surface a consent/retention setting per project (retention lifecycle already exists for Manifold media — extend the pattern). Add an optional redaction/blur step for ARM screenshots.

### M4 — Cloud Build bucket posture
**Evidence.** `gs://citadel-platform_cloudbuild`: `public_access_prevention=inherited`, UBLA=**off** (legacy ACLs), no lifecycle rule; retains many months of source archives. (The other two buckets correctly have PAP=enforced + UBLA.)

**Impact.** Weakest-posture bucket holds the most sensitive artifact (source incl. `.env` — see C1) indefinitely. Compounds C1's window.

**Fix.** `public_access_prevention=enforced`, UBLA on, lifecycle delete (7 days), and restrict read to the builder SAs only (drop legacy project-viewer read).

---

## 4. Low / hardening

- **L1 — Dev origins in prod CORS.** `CITADEL_CONSOLE_ALLOWED_ORIGINS` includes `http://127.0.0.1:5000` and `http://localhost:5000` alongside prod origins. Low impact (the API uses bearer tokens, not cookies, so CORS isn't the primary control), but remove dev origins from the production deployment.
- **L2 — Ingress=all on all Cloud Run services.** `citadel-arm-evidence` is invoker-restricted to the API SA (good); setting its ingress to `internal` would add defense-in-depth. The two public services legitimately need `all`.
- **L3 — `email_verified` absent-passes.** `platform_google_jwt_verifier.dart` rejects only when the claim is present and `!= true`. Fine for Firebase ID tokens (always present) and Google OIDC service tokens, but make the requirement explicit for the Firebase path.
- **L4 — Cloud Run deletion protection** not set on prod services (annotation empty). Enable to avoid accidental service deletion (mirrors H1's theme).
- **L5 — Firebase web API keys in tfstate (informational, not a leak).** `provisioner/client-data-plane/test-sandbox` state contains an `AIza…` Firebase web key — these are public client config by design. Notably, tfstate contains **no** Secret Manager payloads, SA private keys, or `secret_data` fields (verified across production runtime/provisioner and customer states) — good design; the state bucket also has PAP enforced + UBLA.

---

## 5. What is done well (validated, not assumed)

These were checked against code and/or live infra and hold up:

- **Token verification** (`platform_google_jwt_verifier.dart`): RS256 only, JWKS with bounded size + cache, `iss`/`aud`/`exp`/`iat` with clock skew, `email_verified`, signature verified from published keys (not from unverified claims). Dual-token authenticator shares one "who is this" path; the authorizer **fails closed** if Palisade is unreachable.
- **Palisade authorization** (`palisade_firestore_resolver.dart`, `firestore.rules`): default-deny catch-all; `palisade_identities`/`palisade_grants`/boundary/Manifold collections fully closed to clients (resolved server-side only); project visibility requires holding a grant (no cross-project enumeration by design); superdev-only registry writes; **SSRF guard** preserving `runtimeUrl`/`runtimeServiceAccount` so a browser can't repoint a project's runtime or nominate its authority-resolution identity.
- **Per-service least privilege:** every Cloud Run service runs as its own SA; secrets injected via `secretKeyRef` (no plaintext secrets in env); per-secret `secretAccessor` bound to exactly one SA.
- **Public ticket flow:** random secret IDs, redacted public view, uniform 404s (no ticket/project enumeration), HMAC codes (single-use, 5-attempt cap, constant-time), ticket-bound signed sessions.
- **Webhook authenticity:** WhatsApp `x-hub-signature-256` (HMAC-SHA256, constant-time, strict format) + verify-token; Stripe and email (svix) signatures; forged/replayed deliveries recorded via `ingress_refusals`.
- **Manifold public receiver isolation:** dedicated SA, `datastore.user` **IAM-conditioned to one database**, only its own channel secrets, no Vertex/operator reach; media bucket `public_access_prevention=enforced` + UBLA + versioning.
- **No injection/SSRF in the proxy:** `_validResourceId` (`^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$`) blocks path traversal/CRLF; downstream base URL + audience come from config, path is server-constructed.
- **Secret hygiene in VCS:** no API keys or private keys committed in any of the three submodules' git history; localbridge stores the runner credential in the OS keychain (DPAPI on Windows), never a config file.

---

## 6. Suggested remediation order

1. **Today:** Rotate OpenAI + npm + Resend keys (C1). Add `.env` to root `.gcloudignore`, purge the cloudbuild bucket, tighten it (C1/M4).
2. **This week:** Enable Firestore PITR + delete protection + daily backups on the registry DB and bake it into the client runtime template (H1). Disable/deprivilege the default compute SA (H3).
3. **Next:** Reduce provisioner privilege concentration and drop `runWithOverrides`; add an out-of-band control on destructive provisioning (H2). Rate-limit ticket `verify` (M1) and Conduit ingest (M2).
4. **Product/privacy:** Make replay masking default-on and surface consent/retention (M3). Remove dev CORS origins from prod (L1); set Run deletion protection (L4).

---

*Method note:* findings are backed by live `gcloud`/`gsutil` reads, downloaded build/state artifacts, and source inspection cited inline. No mutating operations were performed. Third-party keys were **not** exercised against their providers — treat them as disclosed and rotate regardless.
