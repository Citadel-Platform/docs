# Feature 7.1 - Manifold Conversations and Connectors

## Status
End-state product direction settled 26/08/26. Built for WhatsApp during
Features 4.5 and 7.2 and reviewed 30/08/26 — the status line saying it was not
yet sequenced had outlived four of the five definition-of-done items.

**Email carries messages, 31/08/26.** Resend is the transport. Sending is an
`ExternalChannel` beside WhatsApp's, receiving is a Svix-verified endpoint that
survives a secret rotation and refuses another address on the same provider
account, and publication verifies the key against the provider. A line may be
published enabled; a runtime not built to carry email refuses by name at the
moment of sending.

**Email as a line type, 31/08/26.** A project can publish an email line — name,
address, a sending credential and an inbound signing secret as pinned Secret
Manager versions — as an immutable digest-pinned revision, listed beside the
numbers in Communication Lines. It is never verified and never enabled, because
which transport carries Citadel's email is undecided and that decision is what
a credential even is. The line says so where it is shown rather than reading as
inactive.

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
Reviewed 30/08/26 against the code and the tests that hold each one. Most of
this was built during Feature 4.5 and 7.2's work and never ticked.

- [x] One WhatsApp connector ingests, threads and replies through the project
      inbox — the whole path exists and is tested end to end in pieces: the
      public webhook verifies Meta's signature and the subscription handshake
      (`whatsapp_webhook.ts`, `whatsapp_webhook_endpoint.ts`), a message
      resolves to a published channel revision and starts the artifact that
      declares it (`whatsapp_run_sink.ts`), the thread is recorded in the
      client's own Firestore (`conversation_store.ts`), and a colleague or an
      artifact replies down the same path so the same consent gate refuses
      both (`conversation_reply.ts`, `composeManifold`). The Console inbox
      lists, opens, claims, drafts and replies
      (`platform_manifold_inbox_test.dart`).
- [x] Duplicate and out-of-order provider events are proven safe — and proven
      as properties rather than as a happy path. A redelivered message does
      not appear in the thread twice; a late redelivery does not make the
      thread look older than it is; a message never walks backwards through
      delivery states; a state Meta has not published yet is dropped rather
      than guessed; and a redelivered message starts the run it already
      started rather than a second one
      (`conversation_store.integration.test.ts`, `whatsapp_delivery.test.ts`,
      `whatsapp_run_sink.test.ts`).
- [x] Message bodies and attachments never cross client boundaries — the
      conversation routes are proxied to the client's runtime rather than
      served in the control plane, precisely because the messages are the
      client's own customer data and live in the client's data plane; the
      control plane routes the request and checks who may make it and never
      holds what was said (`platform_proxy_handler.dart`). The Console holds
      the line too: the thread list carries no message bodies, an attachment
      is named and never rendered, and another project's threads are not
      listed (`platform_manifold_inbox_test.dart`,
      `conversation_store.integration.test.ts`).
- [x] Consent/opt-out and delivery failures are enforced and visible —
      enforcement is a gate inside the channel rather than a check callers
      remember, and it sits inside the thread recorder so a refused reply is
      never written into the thread as though it were sent. STOP means stop
      and only when that is what was said; a word inside a sentence is not an
      instruction; silence is not refusal; someone who opted back in is sent
      to again; and a message the runtime cannot read is never taken as
      consent (`whatsapp_consent.ts`). Failures carry Meta's own reason and a
      failure without one is refused, so the Console can say what actually
      happened rather than "failed" (`whatsapp_delivery.test.ts`,
      `platform_manifold_inbox_test.dart`).
- [~] Provider sandbox/live integration tests and browser inbox E2E pass —
      the storage and idempotency halves run against the Firestore emulator
      (`conversation_store.integration.test.ts`,
      `whatsapp_consent.integration.test.ts`,
      `whatsapp_channel_repository.integration.test.ts`), and channel
      publication verifies credentials against Meta's Graph API for real
      before it will publish. **Not covered:** a sandbox or live round trip
      through Meta, and a browser E2E of the inbox. Both need a real WhatsApp
      Business number, which is the same dependency Feature 7.2's last box is
      waiting on.

## Task 7.1.5 — Communication Lines (NEW 30/08/26)

From the feature-set review.

A **line** is a number or an address a project can be reached on. The Channels
page listed one row per channel *revision*, which showed one number three times
and called it three channels. It is now one row per line: Line, Channel,
Address, Status — and "Publish revision" is **Add line**.

**Revisions are not removed, only demoted.** A channel's configuration is
immutable by design: a mutable channel record means anybody who can write it
can point a client's number at their own token. The revision now appears as a
small line under the name, which is what is needed when something stops working
and nothing else.

- [x] One row per line, with the revision demoted (30/08/26)
- [x] **A client's sending domain is supplied through the Console**
      (31/08/26). Resend is the *client's* email solution, not Citadel's
      mailbox: a customer who gets a ticket code from a company they have never
      heard of is being phished as far as they can tell. So a ticket code now
      sends from the project's own newest enabled email line, with Citadel's
      address as the fallback, and `PlatformEmailDomainService` registers a
      client's domain, hands back the DNS records to publish and reports the
      provider's status verbatim — `not_started`, `pending` and `failed` are
      different problems for whoever owns the DNS. Proven against the real
      provider: `obsivision.com` is registered, id
      `76fb2fca-9c99-43b2-b650-53badca741fc`.
- [ ] The Console form for it. The routes exist
      (`/v1/projects/{id}/manifold/email-domains`, and `.../{id}/verify`) and
      answer authenticated in production; nothing renders them yet.
- [x] **Email as a line type** (31/08/26). Its own credential shape, its own
      verification at publication, and its own inbound path: sending as an
      `ExternalChannel` beside WhatsApp's, receiving through a Svix-verified
      endpoint that survives a secret rotation. What remains is not the line
      but the deployment — a published email line refuses at the moment of
      sending, by name, until a runtime is built with `emailChannels`,
      `emailFetch` and the inbound endpoint mounted.
- [x] A line carries a status of its own — active, suspended, pending
      verification — rather than borrowing the channel's enabled flag
      (31/08/26). `ManifoldLineStatus` is derived in one place for both
      carriers: off is suspended, on with something in the way is pending, on
      and served is active. A project with no Exigence runtime is the case
      that makes pending real — nothing is listening, whatever the flag says,
      and an operator sent looking for a switch that is already on is the
      failure the flag caused.
