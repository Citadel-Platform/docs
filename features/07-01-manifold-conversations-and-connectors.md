# Feature 7.1 - Manifold Conversations and Connectors

## Status
End-state product direction settled 26/08/26. Not yet sequenced for build.

## Scope
Project-scoped omnichannel communications for email, WhatsApp, Telegram, SMS
and website submissions. Manifold owns channel configuration, conversations,
messages, attachments, delivery attempts, consent state and replies. Client
message data stays in the client data plane.

## Tasks

### Task 7.1.1 - Conversation contracts
- Canonical conversation, message, participant, channel account, attachment,
  delivery attempt and consent records.
- Preserve provider event ids and provider-specific payloads without pretending
  every channel has identical semantics.
- Idempotent webhook ingestion, explicit ordering and auditable delivery state.

### Task 7.1.2 - Client data plane
- Firestore for conversation state and GCS for attachments/raw payloads where
  required; Secret Manager for provider credentials.
- Citadel registry holds configuration, authority and pointers only.
- Retention and data-classification choices are settled before production use.

### Task 7.1.3 - Provider connectors
- Ship WhatsApp first, choosing the provider only after official API and
  commercial grounding, then add channels behind the common contracts.
- Verify webhook authenticity, retries, rate limits, consent and opt-out rules.
- Surface onboarding and provider approval as guided Console flows with live
  verification; never hide them in manual scripts.
- Apply Palisade Data Handling modes independently to ingress, egress,
  processing, storage, logging, approval, destination, and expiry.

### Task 7.1.4 - Human messaging
- Unified inbox, thread state, assignment, internal notes, drafts and replies.
- Prevent conflicting simultaneous replies and retain a complete mutation log.

## Definition of done
- [ ] One WhatsApp connector ingests, threads and replies through the project inbox
- [ ] Duplicate and out-of-order provider events are proven safe
- [ ] Message bodies and attachments never cross client boundaries
- [ ] Consent/opt-out and delivery failures are enforced and visible
- [ ] Provider sandbox/live integration tests and browser inbox E2E pass
