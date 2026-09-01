# Feature 3.3 — Session Replay Player

## Status
Active. Depends on Features 3.1 and 3.2.

## Scope
Build the Session Replay module in the Conduit Console: the session list view, the replay player UI, and all linked navigation to other modules.

## Tasks

### Task 3.3.1 — Session list view
- Build the session list page: paginated table with columns for visitor ID, date/time, duration, pages visited, device, country, frustration signals (badge icons), tags, and starred state.
- Implement filter panel: date range, device type, browser, country, page visited (URL pattern), session duration range, frustration signal type, custom event presence, tag filter.
- Implement sort by: most recent, longest, most pages, most frustration signals.
- Bulk actions: bulk tag, bulk star, bulk export to CSV.
- Each row links to the session replay player.

### Task 3.3.2 — DOM replay engine
- Implement a replay engine using the rrweb `Replayer` (or a compatible custom implementation) that reconstructs the captured DOM inside a sandboxed `<iframe>`.
- Fetch replay chunks from a signed GCS URL via the Conduit API.
- Implement a decompress-and-parse step for gzip-compressed chunks.

### Task 3.3.3 — Replay player UI
- Build the player shell:
  - Full-page replay viewport (responsive, scaled to fit the Console viewport)
  - Timeline scrubber: position indicator, draggable, click-to-seek
  - Event markers on the timeline: click (dot), rage click (red burst), error (red X), page navigation (vertical line), custom event (diamond)
  - Playback controls: play/pause, previous/next event, speed selector (0.5×, 1×, 1.5×, 2×, 4×)
  - Skip idle time toggle: auto-advance through gaps > 3 seconds of inactivity
  - Session metadata sidebar: visitor ID, device details, OS, browser, viewport, country, session duration, page sequence breadcrumb, frustration signal counts, tags, star
  - Share button: generates a timestamped deep link URL
  - "View heatmap for this page" button (navigates to Heatmaps module filtered to the current page)

### Task 3.3.4 — Developer panels
- Collapsible Console panel below the player: JS errors and `console.warn`/`console.error` output captured during the session, synchronised with the playback timeline.
- Collapsible Network panel: intercepted XHR/Fetch events with method, URL, status, and duration, synchronised with playback timeline.
- Collapsible Events panel: chronological list of all autocapture and custom events in the session.

### Task 3.3.5 — Frustration signal highlighting
- When the user plays past a rage click event, flash a red overlay on the clicked element in the replay.
- When the user plays past an error event, highlight the timeline marker and auto-open the Console panel.
- Session metadata sidebar shows a frustration signal badge count; clicking jumps the playback to the first occurrence of that signal type.

### Task 3.3.6 — Session tagging and curation
- Allow users to add free-text tags to a session from the player sidebar.
- Star/unstar a session.
- Add a note (free text) to a session for team context.
- All metadata changes are saved to Firestore immediately.

### Task 3.3.7 — Linking into session replay from other modules
- Implement a shared utility function `openSessionReplay(sessionId, timestamp?)` used by all other modules to deep-link into a specific session at a specific timestamp.
- Support URL-based deep linking: `/conduit/replay/{projectId}/{sessionId}?t=120` loads and seeks to the given offset.

## Definition of done

Rewritten 31/08/26 against the product that exists — a Flutter/Dart SDK and a
Dart ingest service on Firestore — rather than the web SDK and BigQuery
pipeline these criteria were first written for. The originals are kept below
under **Deferred**, because they are a product decision that was made, not work
that was dropped: the product-owner review of 30/08/26
(`_dev/docs/feature_set_review_30_08_26.md`) settled Conduit as Flutter/Dart
first with analytics infrastructure deferred.

Replay in this product is a **Flutter capture surface**, not a DOM recorder:
`conduit_replay_capture_surface.dart` and `conduit_visual_capture.dart` record
what a Flutter app drew. The player reads those frames. A criterion about DOM
reconstruction is a criterion about a recorder Citadel does not have.

- [x] The capture surface records a session's frames and the SDK ships them
      (`conduit_visual_capture_surface_test.dart`)
- [x] The session list loads, filters and sorts through session search
- [ ] The player is driven end to end against a recorded session — no test
      reaches playback, and this is the box that matters most on this feature
- [ ] Timeline markers, and frustration signals highlighted at the moment they
      happened
- [ ] Tag, star and note persist across a reload
- [ ] A deep link opens the player at a timestamp

### Deferred — the web pipeline
- Replay player reconstructs a real **DOM** recording without visual artefacts
- Console and Network panels synchronised with playback (both are browser
  surfaces; the Flutter capture has no console pane to synchronise)

