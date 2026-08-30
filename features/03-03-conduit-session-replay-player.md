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
- [ ] Session list loads with correct data, filters, and sort
- [ ] Replay player reconstructs a real DOM recording without visual artefacts
- [ ] Timeline markers appear at correct positions for all event types
- [ ] Frustration signals are visually highlighted at correct moments
- [ ] Console and Network panels are synchronised with playback
- [ ] Tag, star, and note operations persist across page reloads
- [ ] Deep link URL opens the player at the specified timestamp

