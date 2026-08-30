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
- Enrich events with GeoIP-derived fields using a bundled GeoLite2 database (no external call).
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
- [ ] Ingest API accepts and validates events; rejects malformed payloads with clear error codes
- [ ] Events are routed to BigQuery within 5 seconds of receipt (streaming latency)
- [ ] Replay chunks are stored in GCS and retrievable by sessionId
- [ ] Pub/Sub topics exist for all routing paths including Exigence triggers
- [ ] Session search query returns correct results with pagination
- [ ] Rate limiting is enforced and returns 429 when exceeded
- [ ] GeoIP enrichment populates country, region, and city fields

