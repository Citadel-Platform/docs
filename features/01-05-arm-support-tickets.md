# Feature 1.5 — ARM Support Tickets (NEW 30/08/26)

## Status
Specified 30/08/26 from the product-owner feature-set review
(`_dev/docs/feature_set_review_30_08_26.md`). **Built 31/08/26**, apart from
the two things below.

The model, the store, the routes, the Console table and page, the public
ticket link and the SDK write path are in. A ticket names its case logs and
fingerprint rather than containing them; a public link serves the conversation
with the evidence coordinates and the reporter's address stripped; an
allowlisted ticket requires a *verified* address and is refused on the public
route until something can send a code.

**Verified access built 31/08/26** on Resend: a six-digit code to an address on
the allowlist, exchanged for a session token bound to that one ticket. Asking
for a code answers identically whether or not the address is on the list, only
the code's salted digest is stored, and it works once.

Outstanding:
- **Attachments.** Modelled and decoded end to end; no upload control exists,
  because writing to the client's own storage from the Console needs a path and
  a signed-URL read that nothing has decided.

## Scope
The channel between the person who hit the fault and the person who can fix it.

ARM already records what broke — Case Logs are context, state and stack-trace
bundles; Issue Fingerprints group the recurring ones. What it has never had is
the human half: who hit it, how to reach them, and the conversation that
follows. A ticket is that, pegged to the evidence.

Depends on Feature 1.1 (the client SDK raises them) and Feature 6.1 (who may
read one).

## Vocabulary, settled

- **Case Log** — one capture from an ARM client: context, state, stack trace.
- **Issue Fingerprint** — a unique fault. One or more Case Logs hang off it.
  Every Case Log has a parent fingerprint; that is an invariant of capture,
  not a validation.
- **Ticket** — a person's report. Opened by an end user from the error dialog,
  or manually by a developer or owner. Linked to the Case Logs and fingerprints
  it is about.
- **Incident** — does not exist. Removed from the Console 30/08/26.

## Task 1.5.1 — Raising a ticket from the error dialog
- The ARM client's error dialog gains **Open Support Ticket** beside the error.
- Pressing it asks for a contact number or email, and nothing else. The person
  is mid-failure; a form is how you lose them.
- The ticket is created carrying the current session, the Case Log that caused
  the dialog, and its parent fingerprint — so the developer opens it already
  knowing what happened, and the user does not have to describe it.
- A ticket may also be opened with no dialog behind it, from the Console.

## Task 1.5.2 — The ticket record
- Status: `open`, `investigating`, `inProgress`, `closed`.
- Title, description, attachments.
- Linked session, Case Logs and fingerprints.
- Reporter contact, as given. Never inferred from the session.
- **History**: a timestamped sequence of entries, markdown, free text and
  media, written by both the reporter and the developer. The GitHub-issue
  shape, deliberately: a status field alone cannot carry "we think it is the
  payment provider, can you try again".
- Status changes appear in the history as entries, so the record reads as one
  sequence rather than a field and a log that disagree.

## Task 1.5.3 — Access
Every ticket has a URL. What that URL grants is the decision this task turns
on, and the review recommends a correction to the original shape.

- **No allowlist — public by link.** Anyone with the URL reads it. The
  conversation is visible; **the evidence is not**. Case Logs, stack traces and
  session replay stay behind sign-in, because a public link to a stack trace is
  a public link to whatever the stack trace contains.
- **With an allowlist** — a chip-input of email addresses:
  - a Citadel user signs in and is checked against the list;
  - a non-Citadel user enters their address and is sent a **one-time code**.
    The original shape asked for an address with no verification, which is not
    an access control: anybody who can guess an allowlisted address reads a
    customer's session and stack trace. A code is the smallest thing that
    actually holds, and it costs the reporter one email.
- Whatever a reporter can see goes through the Console's **redaction policy**
  first. The first support ticket must not be the first leak.

## Task 1.5.4 — Console surface
- A Tickets table beside Issue Fingerprints and Case Logs: status, title,
  reporter, linked fingerprint, opened, last update.
- A ticket view: the history as a thread, the linked evidence, the status
  control, and the allowlist editor.
- Opening a ticket manually, and linking one to a fingerprint after the fact.

## Definition of done
- [~] An end user raises a ticket from the error dialog and the developer sees
      it linked to the Case Log that caused it — built on both sides
      (`ArmOpenTicketButton`, the Console's Tickets page) and **not yet driven
      end to end against one Firestore**. A contract test holds the SDK's
      document and the service's codec together.
- [~] Ticket history is markdown, carries media, and reads as one sequence
      including status changes — markdown and the sequence are in; attachments
      are modelled, decoded and shown on both ticket surfaces with no upload
      control and no way to open one — the storage path and the signed read
      are undecided — and status changes are recorded on the ticket rather
      than as history entries.
- [x] A public-link ticket exposes the conversation and no evidence (31/08/26).
      `armPublicTicketView` strips the case ids, the fingerprint, the session
      and the reporter's address, and the public route serves nothing else.
- [~] An allowlisted ticket is unreadable without a code sent to an
      allowlisted address, proven adversarially. **The transport is proven**
      (31/08/26): `tool/send_ticket_code_probe.dart` drives the server's own
      Resend sender against the real API, and the owner read the resulting
      email — message `f44fd30b`, `last_event: delivered`. What remains is the
      adversarial pass through the deployed route, which needs a verified
      sending domain: a code goes out from the *client's* own line, and no
      client domain is verified yet.
- [x] Everything a reporter can see is redacted by the same policy the Console
      applies (31/08/26) — the Platform API imports the redaction from the ARM
      service rather than keeping a second copy of it.
- [x] A ticket opened manually and one raised from the dialog are the same
      record with the same history (31/08/26). The description opens the
      history in both cases, and only `createdBy` and the first entry's author
      kind differ.
