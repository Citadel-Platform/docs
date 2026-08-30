# Feature 4.4 — Exigence Knowledge Base (NEW 14/08/26)

## Scope
A per-project corpus of client resources that artifacts can retrieve against,
plus an operator chat surface over that corpus. NotebookLM-shaped: throw
resources in, index them, ask questions, and let artifacts use the same index.

Depends on Feature 4.1 (runtime) and Feature 6.1 (Palisade boundaries govern
which paths and URLs may be ingested).

## Data ownership
For clients with their own project (Luminary Axis), documents, extracted text,
chunks and embeddings live in that project's Firestore and GCS.

For clients hosted in `citadel-platform` (the default — DECISIONS.md 14/08/26),
all of it lives in the shared Firestore under a **mandatory client-identifier
collection prefix**. There is no project boundary between clients here, so the
prefix plus Palisade authority plus Firestore rules are the entire isolation
mechanism. A query missing its prefix must fail closed, never read across
clients. Test this adversarially.

## Task 4.4.1 — Sources and ingestion
- Connectors: Google Drive, OneDrive/SharePoint (Microsoft Graph), direct upload
  (files and folders), and live URLs.
- Local filesystem folders ingest through the Feature 4.5 runner, not through
  the browser.
- Credentials are Secret Manager references only. Never a raw token in Firestore.
- Each entry records source, fetched-at, content hash, byte count, media type,
  and extraction status. Re-fetch is content-hash gated so unchanged sources do
  not re-embed.
- **Scope Drive/Graph OAuth to the narrowest possible scope.** Drive scopes are
  *sensitive* (review required), not *restricted* (paid third-party assessment
  required). Verified 14/08/26.

### Drive OAuth stays in Testing status — design around the 7-day limit
The Google OAuth app remains in **Testing** publishing status for now
(DECISIONS.md 14/08/26). Two hard constraints follow, both verified:
- **Refresh tokens are revoked after 7 days** for External user type in Testing.
- The test-user allowlist is capped at **100 users**.

Unattended Drive sync therefore cannot depend on a refresh token. Design for it:
- Surface consent expiry as an explicit **"reauthorization required"** entry
  state. Never let a sync silently stop — that is a hard rule #1 violation in
  spirit: the Console would be showing a stale corpus as if it were current.
- Treat scheduled Drive sync as best-effort until the app is published.

**Prefer these ingestion paths over browser OAuth, in order:**
1. **Synced Drive folder via the local runner** (Feature 4.5). Google Drive for
   Desktop presents Drive as a local filesystem path, so the runner ingests it
   as ordinary files — no OAuth, no token expiry, no user cap. Strongest option
   and free given the runner exists.
2. **Service account with domain-wide delegation** where the client has Google
   Workspace. No consent, no expiry. Not available for personal Gmail.
3. **Direct upload.** Always works.
4. Browser OAuth in Testing status, accepting weekly re-consent.

## Task 4.4.2 — Entries table
- Standard `citadel_table.dart` view: name, source, type, size, indexed state,
  last fetched, chunk count.
- **A per-row toggle in the leading columns controls inclusion in vector
  indexing.** Toggling off removes the entry's vectors; it does not delete the
  source record.
- Row actions: re-fetch, view extracted text, remove.

## Task 4.4.3 — Indexing and retrieval configuration
Separate tab. All values are per-project and versioned:
- Chunking: strategy, size, overlap.
- Embedding model and dimension (Firestore maximum is 2048).
- Retrieval: top-k, distance function, minimum score threshold.
- Vector storage is Firestore `findNearest` in the client project.
- Show the cost model honestly in the UI: one read charged per 100 index entries
  scanned, plus document reads for results. Surface an estimated cost per query
  from the current corpus size.

## Task 4.4.4 — Chat
Separate tab. Not an artifact — an operator/client tool.
- Simple chat interface with a selectable model from the configured provider
  profiles.
- Optional web search toggle.
- `@` mention to scope retrieval to specific Knowledge Base entries.
- Every message is cost-metered and budget-reserved through the same Feature 4.1
  path as artifact model calls. Chat is not exempt from budgets.
- Responses cite the chunks they used, linking back to the entry.

## Task 4.4.5 — Artifact retrieval tool
- A registered Citadel tool exposing retrieval to LangGraph graphs, scope-tagged
  `read`, subject to the same policy gate.
- Retrieval results enter the journal as activity evidence like any other tool
  output, spilling to GCS above the 128 KiB inline limit.

## Definition of done
- [~] A Drive folder, a OneDrive folder, an uploaded folder and a live URL all
      ingest and index — four connectors exist and are tested (a synced Drive
      folder through the runner, direct upload, live URLs, and OneDrive or
      SharePoint through Microsoft Graph). Word, Excel and PowerPoint are read
      as well as text; PDF and the pre-2007 binary formats are refused by name.
      None of it is verified against a real Microsoft tenant yet.
- [ ] The per-row indexing toggle adds and removes vectors and is reflected in retrieval
- [ ] Re-fetching an unchanged source does not re-embed or re-charge
- [ ] Chat retrieves with `@` scoping, cites sources, and is budget-metered
- [ ] A LangGraph artifact retrieves from the Knowledge Base through the policy gate
- [ ] In-project clients are isolated by mandatory collection prefix; a prefix-less query fails closed
- [x] Expired consent raises "reauthorization required", never a silent stale
      corpus — a connector that cannot authenticate stops the pass with every
      entry left where it was, because "listed nothing" and "the folder is
      empty" are indistinguishable and one of them would prune the corpus.
      Proven for Graph's 401; the Console state is built, the Drive path is
      still the runner's, which needs no consent at all.
- [ ] The runner ingests a synced Drive folder with no OAuth involved
- [ ] Empty and not-configured states are truthful everywhere
