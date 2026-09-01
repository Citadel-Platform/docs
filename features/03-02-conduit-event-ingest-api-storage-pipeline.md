# Feature 3.2 — Event Ingest API & Storage Pipeline

## Status
Active. Depends on Feature 3.1 (SDK must exist to emit events).

## Scope
Build the server-side event ingestion endpoint, event schema validation, and the storage pipeline that writes events to BigQuery and session replay chunks to Cloud Storage. This is the backend data foundation for all Conduit modules.

## Tasks

### Task 3.2.1 — Ingest API service
- Create a Cloud Run service at `conduit/ingest/` handling `POST /v1/events`.
- Accept a JSON array of events in the request body (gzip-encoded if `Content-Encoding: gzip`).
- Authenticate using the `X-Conduit-Key` header: validate against the project registry in Firestore.
- Return `202 Accepted` immediately; processing is asynchronous.
- Enforce a rate limit of 5,000 events per project per minute at the Cloud Run ingress.
- IP address anonymisation: strip the last octet of `x-forwarded-for` before any storage write.

### Task 3.2.2 — Event schema validation and normalisation
- Define and enforce the canonical Conduit event schema in JSON Schema:
  ```json
  {
    "eventId": "string",
    "sessionId": "string",
    "visitorId": "string",
    "projectId": "string",
    "tenantId": "string",
    "timestamp": "number",
    "type": "string",
    "url": "string",
    "referrer": "string",
    "device": {
      "type": "string",
      "os": "string",
      "browser": "string",
      "viewport": "string",
      "screenResolution": "string"
    },
    "geo": {
      "country": "string",
      "region": "string",
      "city": "string"
    },
    "payload": {}
  }
  ```
- Validate required fields; reject events with missing `projectId`, `sessionId`, or `type`.
- Enrich events with a country resolved from a bundled range database (no external call). Country only: the address is truncated before the lookup.
- Assign a server-side `receivedAt` timestamp alongside the client `timestamp`.

### Task 3.2.3 — Pub/Sub routing
- Publish validated events to a Pub/Sub topic `conduit-events-{env}` partitioned by event type.
- Use separate topics for replay chunks (`conduit-replay-{env}`) and performance metrics (`conduit-perf-{env}`) due to different consumer requirements.
- Emit a separate `conduit-exigence-triggers-{env}` topic for events Exigence should react to: `session.ended`, `error.detected`, `frustration.threshold_crossed`.

### Task 3.2.4 — BigQuery event table
- Create BigQuery dataset `conduit_raw` with partitioned tables per event type: `events`, `errors`, `performance`, `forms`.
- Partition by `DATE(timestamp)`, cluster by `projectId`.
- Use BigQuery streaming insert from the Pub/Sub consumer (Cloud Run subscriber).
- Define a BigQuery aggregation dataset `conduit_agg` with scheduled query jobs for: daily session summaries, page-level metrics, device breakdowns, and traffic source summaries.

### Task 3.2.5 — Session replay chunk storage
- Receive replay event stream chunks via `POST /v1/replay` (a separate endpoint from the main event ingest).
- Store raw rrweb event arrays as gzip-compressed JSON in GCS at path: `gs://{project-replay-bucket}/{projectId}/{YYYY}/{MM}/{DD}/{sessionId}.json.gz`.
- Write session metadata (start time, end time, page count, duration, frustration signals array, visitor ID) to Firestore at `conduit_sessions/{projectId}/{sessionId}`.
- Implement a lifecycle rule on the GCS bucket: delete replay files older than the project's configured retention period (default 90 days).

### Task 3.2.6 — Project config API
- Implement `GET /v1/config/:projectKey` endpoint returning: sampling rate, enabled features, masking rules, consent mode, retention days, custom event schema hints.
- Config is stored in Firestore under `conduit_projects/{projectId}` and served with a 1-hour CDN cache.

### Task 3.2.7 — Session index and search
- Maintain a Firestore collection `conduit_sessions/{projectId}` with indexed fields: `startTime`, `duration`, `deviceType`, `country`, `pageCount`, `hasFrustration`, `tags`, `starred`, `errorIds`.
- Build a query endpoint `POST /v1/sessions/search` that accepts filter parameters and returns paginated session metadata. This backs the session replay filter UI.

## Definition of done

Rewritten 31/08/26 against the product that exists — a Flutter/Dart SDK and a
Dart ingest service on Firestore — rather than the web SDK and BigQuery
pipeline these criteria were first written for. The originals are kept below
under **Deferred**, because they are a product decision that was made, not work
that was dropped: the product-owner review of 30/08/26
(`_dev/docs/feature_set_review_30_08_26.md`) settled Conduit as Flutter/Dart
first with analytics infrastructure deferred.

- [x] The ingest API accepts and validates events and refuses malformed
      payloads by name rather than by silence
      (`conduit_ingest_validation_test.dart`)
- [x] Events are persisted to Firestore under the documented schema, which is
      where they are read from — there is no second store to fall behind
      (`conduit_firestore_persistence_test.dart`, `conduit_firestore_schema_test.dart`)
- [x] Session search returns filtered, paginated results
      (`conduit_session_search_json_test.dart`)
- [x] Rate limiting is enforced and answers 429
- [x] Country resolution, as everything either side of the database file
      (01/09/26). `ConduitGeoDatabase` parses the range table every candidate
      publishes; `IpRangeConduitGeoResolver` answers from the truncated address;
      `loadConduitGeoDatabase` names which file the deployment carries and
      distinguishes "none configured" from "configured and broken"; the switch
      is per project and the Console records which licence was accepted.
- [ ] A database file. None is bundled, because no licence has been taken, so
      every session still reads as having no country rather than a wrong one.
      Procurement rather than code — see `CONDUIT.md` C0 and the catalogue in
      `conduit_geo_databases.dart` for the three candidates and their terms.
- [ ] Region and city are **not** coming. No range table resolves them from a
      network address, and the last octet never reaches storage.
- [ ] Proven against a real client project rather than the emulator

### Deferred — the web pipeline
Not outstanding. BigQuery, Pub/Sub and GCS replay chunks are the analytics
infrastructure the 30/08/26 review deferred; Firestore is the store, and
routing is a direct call rather than a topic.

- Events routed to BigQuery within 5 seconds (streaming latency)
- Replay chunks stored in GCS and retrievable by sessionId
- Pub/Sub topics for all routing paths including Exigence triggers

