# Shared Streaming Conventions

## Scope

Feature `0.4.2` standardizes streaming behavior for long-running product work.

## Transport choice

- Use **Server-Sent Events** for one-way progress, token, and job-status streams.
- Use **WebSocket** only for truly bidirectional live sessions where the client must send mid-stream input.
- Local-runner commands use authenticated **HTTPS long-polling** as their
  durable channel. Each command has a stable ID and per-machine sequence;
  acknowledgement advances the replay cursor. Delivery is at least once.
- Local-runner **WebSocket** traffic is a lossy live overlay for interactive
  browser/computer-use frames. It reconnects with session/cursor context but
  does not rely on Cloud Run instance affinity and does not replay frames unless
  Data Handling policy explicitly authorizes capture.

## Event envelope

Every stream event should carry:

- `eventId`
- `eventType`
- `createdAt`
- `projectId`
- `payload`
- `trace`

`trace` should include:

- `requestId`
- optional `traceId`
- optional `spanId`

## Current baseline channels

- `progress_stream`
  - transport: `sse`
  - direction: `serverToClient`
- `live_session`
  - transport: `webSocket`
  - direction: `bidirectional`
