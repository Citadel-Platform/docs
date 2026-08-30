# Conduit — Technical Research Report
## Reference Platforms: Hotjar & Contentsquare (Post-Merger)
**Prepared for:** Citadel Platform — Conduit Product Line
**Date:** June 2026
**Status:** Foundational Design Reference

---

## 1. Executive Summary

Conduit is Citadel's business analytics offering, targeting the instrumentation and behavioural intelligence layer for public-facing websites, product pages, documentation, and applications. This report analyses the two dominant platforms in the digital experience analytics (DXA) space — **Hotjar** and **Contentsquare** (which merged in July 2025 and now operate as a unified platform) — and derives the full feature surface, SDK requirements, UI/widget specifications, and Exigence AI integration patterns that Conduit must implement.

The post-merger Contentsquare platform is now the most comprehensive reference available. It absorbs Hotjar's SMB-focused tooling (heatmaps, session recordings, lightweight surveys) and Contentsquare's enterprise-grade experience analytics (zone-based analysis, journey analysis, experience monitoring, conversation intelligence, and agentic AI via the Sense product). The combined platform also incorporates Heap's product analytics and Loris.ai's conversation intelligence capabilities.

Conduit's positioning within Citadel differs from both: it serves small-business clients already onboarded to Citadel's stack, and all AI workloads are handled by Exigence rather than by an embedded AI product. This creates an architectural boundary that Conduit's design must respect.

---

## 2. Reference Platform Analysis

### 2.1 Hotjar (Pre-Merger / Now Contentsquare SMB Tier)

Hotjar was founded in 2014 and became the most widely deployed behavioural analytics tool for small-to-mid-size businesses, reaching 1.3 million websites before the Contentsquare acquisition. Its architectural principle is simplicity: a single JavaScript snippet, no manual event tagging required, and visual outputs that non-technical stakeholders can immediately understand.

**Core feature areas:**

**Heatmaps**
- Click heatmaps: aggregate all click/tap interactions across a page view into a colour-coded density overlay (cool → warm = low → high density)
- Scroll heatmaps: show what percentage of sessions scrolled to each vertical depth, exposing the "fold" in context
- Move heatmaps: track cursor hover paths as a proxy for visual attention (weaker signal; used for supporting context)
- Rage click maps: isolate areas where users clicked the same element three or more times within two seconds — a direct frustration proxy
- Engagement zone maps: composite overlay combining click, move, and scroll data into a unified engagement signal

**Session Recording (Replay)**
- Full DOM capture of user sessions: mouse movement, clicks, scrolls, keyboard input (redacted), form interactions
- Playback player with timeline scrubbing, speed controls (0.5×–4×), and event markers
- Automatic PII masking: input fields, passwords, and configurable CSS selectors
- Session filtering by: device type, browser, OS, country, page visited, duration, referrer source, specific element interaction
- One-click linking from heatmap hotspot → relevant session replays
- Session tagging and starring for team collaboration
- AI-generated one-click summaries of individual sessions (post-Contentsquare integration)

**Funnel Analysis**
- Visual step-by-step funnel builder using page URLs or custom events
- Drop-off percentage at each step
- Cross-device and cross-segment funnel comparison
- Link from any funnel step → filtered session replays of users who dropped at that step
- Sampling caveats: traffic above plan allowance is sampled (a known Hotjar limitation)

**Form Analytics**
- Per-field metrics: time spent, drop-off rate, refill rate, blank submission rate
- Visual heatmap overlay on form fields
- Jump from any field metric → session replay for qualitative context
- Identification of which fields cause abandonment vs. which are skipped entirely

**Voice of Customer (VoC)**
- Feedback widgets: persistent on-page button or pop-up that lets users submit typed feedback and a sentiment rating at any time
- Polls: single-question pop-ups triggered by behavioural conditions (exit intent, scroll depth, time-on-page, element click)
- Surveys: multi-question forms, shareable by URL or embeddable on-page; 40+ pre-built templates; AI-generated survey creation from a goal prompt
- NPS surveys: 0–10 scale with follow-up open text; trackable over time
- User interviews: recruitment of survey respondents into moderated or unmoderated video sessions (Engage product)
- Survey response → session replay linking (post Contentsquare integration)
- AI-generated survey summary reports and sentiment classification

**Integrations**
- Hotjar connects to: Google Analytics 4, Google Tag Manager, HubSpot, Mixpanel, Optimizely, AB Tasty, Slack, Microsoft Teams, Jira, Linear, Asana, Trello, Kissmetrics
- All integrations available on the free plan

---

### 2.2 Contentsquare (Enterprise DXA Platform)

Contentsquare was founded in Paris in 2012 and is now the most comprehensive enterprise digital experience analytics platform. After the full Hotjar merger in July 2025 and the acquisition of Loris.ai (conversation intelligence) the platform spans five major product pillars.

#### 2.2.1 Experience Analytics

**Session Replay (formerly Hotjar Recordings)**
- Full DOM-based session capture for web; native SDK capture for iOS, Android, and React Native (with remote masking controls for non-technical users)
- AI session summaries via Sense: AI-generated recaps of individual or multi-session batches highlighting key patterns, friction points, and issues — without watching hours of footage
- Embedded zoning in session replay: zone-based heatmap overlaid directly on the replay for correlation between aggregate patterns and individual behaviour
- Session replay linked from every other module (heatmaps, journey analysis, error analysis, VoC surveys)
- Mobile remote masking: configure PII masking without developer deployment via the Contentsquare dashboard

**Heatmaps**
- Click, scroll, move, and rage click heatmaps (as per Hotjar)
- Attention heatmaps: a newer signal type that weights engagement by dwell time in viewport, not just clicks (more accurate reading behaviour proxy)
- Zone-based heatmaps (Zoning Analysis): divides the page into individually tracked zones; each zone reports attractiveness rate, engagement rate, click-to-next-page rate, conversion contribution, revenue per click, and exposure rate
- Heatmap comparator: side-by-side comparison of heatmaps by time period, traffic source, device, A/B test variant, or user segment
- Personalization zoning template: compare how different audience segments or personalised content variations perform in the same zones
- Form analysis within heatmaps: per-field metrics with session replay linkage

**Journey Analysis**
- Full customer pathing from entry page to exit: shows what pages users visit in sequence, in what order, and where they leave
- Sunburst view: radial visualisation showing the most common next-page transitions as concentric rings emanating from an entry point
- Sankey/flow view: linear left-to-right flow diagram showing multi-step paths
- Drop-off identification at each node: percentage leaving vs. continuing, with direct replay access
- Segment overlay: compare journey paths for different audience segments (new vs. returning, mobile vs. desktop, geography, etc.)
- Unexpected navigation pattern detection: surfaces pages that users visit but the product team didn't intend as a common path

**Product Analytics (via Heap integration)**
- Autocapture of every user interaction without pre-defined event schemas
- Retroactive analysis: define events after the fact and analyse historical data against them
- User-level event streams: see every action a specific identified user took across multiple sessions
- Cohort analysis: compare user groups by acquisition date, feature adoption, or behaviour
- Retention analysis: measure what percentage of users return within defined time windows
- Funnel analysis with multi-touch attribution (more powerful than Hotjar's URL-based funnels)
- Chat with Sense (natural language querying over product analytics data)

#### 2.2.2 Experience Monitoring

**Real User Monitoring (RUM) — Core Web Vitals**
- Largest Contentful Paint (LCP): loading performance
- Interaction to Next Paint (INP): responsiveness
- Cumulative Layout Shift (CLS): visual stability
- Time to First Byte (TTFB): server response time
- First Contentful Paint (FCP): initial render time
- All metrics sliced by page, device type, geography, and connection speed
- Percentile views: P50, P75, P95 rather than averages (avoids distortion by outliers)
- Correlation of performance metrics with behavioural metrics: bounce rate, conversion rate, session duration

**Synthetic Monitoring**
- Scheduled bot-driven test probes that navigate key pages and workflows to detect availability and performance issues before real users encounter them
- Global probe locations for latency testing from different geographies
- Waterfall view of resource loading for performance debugging

**Error Analysis**
- JavaScript error tracking: captures error type, message, stack trace, and affected page
- API error tracking: captures failed XHR/Fetch requests, status codes, and response bodies (configurable)
- Custom error rules: define business-logic errors (expired discount codes, invalid phone number formats, payment failures)
- Error deduplication and grouping using statistical significance to distinguish signal from noise
- Each error linked to conversion impact, revenue impact, and affected session count
- Direct jump from error → session replay for root cause investigation
- AI-generated error summaries: what went wrong, where, who was affected, why

**Frustration Signals**
- Rage clicks: rapid repeated clicks indicating broken expectations
- Dead clicks: clicks on non-interactive elements (users think something is clickable when it isn't)
- Scroll bounce: user immediately scrolls to bottom and leaves (signal of irrelevant content)
- Quick exits: sessions that end within seconds of page load
- U-turn rate: users who navigate forward then immediately return (indicates confusion)
- Error clicks: clicks that coincide with a JS or API error
- Frustration Score: a composite metric combining multiple signals for prioritisation
- Frustration signals embedded directly in heatmaps, journey views, and funnel steps

#### 2.2.3 Voice of Customer (VoC)

- All Hotjar VoC capabilities (feedback widgets, polls, surveys, NPS, user interviews)
- AI survey generator: describe a research goal, AI creates a full survey structure with logic
- VoC AI summaries: instant analysis of survey response batches, surfacing key themes, pain points, and sentiment distribution
- VoC automation: trigger surveys based on behavioural conditions from the analytics platform (e.g., fire a survey after a rage click, or after a user hits a specific error)
- Survey response → session replay linkage (watch the exact session behind any response)
- Segment export from survey results to targeted marketing platforms

#### 2.2.4 Sense AI (Autonomous Analysis)

Sense is Contentsquare's AI layer, launched in May 2025 and extended with the Sense Analyst agentic product in September 2025.

**Chat to Next-Best-Action**
- Natural language query interface: "Why are users dropping off at checkout?" returns instant analysis with visualisations and recommended actions — no analytics background required
- Available across Experience Analytics, Product Analytics, and Experience Monitoring modules

**Multi-Session Summaries**
- AI-generated recaps of batches of session replays: key patterns, friction points, issues — delivered in seconds rather than requiring hours of replay review

**Automated Sense Analyst (Agentic)**
- Autonomous agent that plans and executes multi-step analyses without human prompting
- Automatically maps the site, compares journey variants, identifies anomalies, summarises findings, and recommends next actions
- Scheduled analysis: configure recurring analytical questions (e.g., "every Monday morning, analyse top drop-off pages and email me the summary")
- Newsroom: a daily-updated feed of AI-surfaced insights (like a briefing from an analyst)

**Anomaly Detection**
- Monitors all key metrics (conversion rate, bounce rate, engagement, error rate) and alerts when deviations exceed statistical significance thresholds
- Correlates anomalies across behavioural and performance dimensions to identify root causes automatically
- AI-alerts: proactive notifications of errors, performance issues, and customer frustrations — before the team has to look for them

**VoC AI**
- AI generates survey structures from goal descriptions
- Summarises open-text survey responses into structured insight cards
- Sentiment analysis at response level and batch level

#### 2.2.5 Conversation Intelligence (via Loris.ai)

- Analyses text from customer support conversations (chat transcripts, call transcripts)
- Surfaces patterns, recurring complaint themes, and opportunities from conversation data
- Correlates conversation insights with on-site behavioural data for a 360-degree customer view
- Designed for businesses with meaningful support or chat volume

#### 2.2.6 Data Connect & Integrations

- Data Connect: direct export of all behavioural, performance, and error data to cloud data warehouses (Snowflake, BigQuery, Databricks, Amazon Redshift, S3, Microsoft Fabric)
- MCP Server: connects Contentsquare insights to AI tools via Model Context Protocol
- 100+ integrations via partner ecosystem: A/B testing (Optimizely, AB Tasty), CRM (Salesforce, HubSpot), ticketing (Jira, Linear, Asana), analytics (GA4, Mixpanel, Amplitude), CDPs, and communication tools (Slack, Teams)
- Jira integration: create issues directly from Session Replay, Error Analysis, or any insight without leaving the platform

---

## 3. Conduit Feature Requirements

This section defines what Conduit must build, derived from the reference platform analysis and adapted to Citadel's architecture, where AI work belongs to Exigence and monitoring work belongs to ARM.

### 3.1 Client-Side SDK & Instrumentation

Conduit's data collection layer is a lightweight, privacy-safe JavaScript/TypeScript SDK embedded on the client's site via a `<script>` tag or NPM package. For mobile clients, a React Native SDK is the priority given Citadel's stack preferences.

**Required SDK capabilities:**

**Autocapture Engine**
- Intercept and record all user interaction events without manual instrumentation: clicks, taps, hover dwell, scroll depth, form input (redacted), page visibility changes, custom events
- Track DOM mutations via MutationObserver for SPAs (single-page applications)
- Virtual page view detection for React Router, Next.js app router, Nuxt, and other client-side routers
- Detect rage clicks (3+ clicks within 2 seconds on same element), dead clicks (click on non-interactive element), and u-turn navigation
- Capture element metadata: tag name, CSS selector path, inner text snippet (redacted if sensitive), position, dimensions, visibility percentage

**Session Management**
- Assign a persistent `sessionId` (UUID) and `visitorId` (persisted via first-party cookie or localStorage) to every session
- Track session duration, page depth, and entry/exit pages
- Cross-page session stitching within a session window

**Performance Monitoring Integration**
- Collect Core Web Vitals using the `web-vitals` library: LCP, INP, CLS, TTFB, FCP
- Capture Resource Timing API data for waterfall analysis
- Collect Navigation Timing API data for page load breakdown
- Long Task API for main thread blocking events

**Error Collection**
- Intercept `window.onerror` and `window.addEventListener('unhandledrejection')` for JavaScript errors
- Patch `XMLHttpRequest` and `fetch` to intercept API requests and responses (configurable allowed/blocked domains)
- Capture error type, message, stack trace, URL, and surrounding user context
- Custom error API: `conduit.trackError(name, metadata)` for business-logic errors

**DOM Recording for Session Replay**
- Capture a serialised snapshot of the DOM at session start
- Record incremental mutations (rrweb-style event stream): attribute changes, node additions/removals, style changes, input changes (masked), scroll events, pointer events
- Network-efficient compression before transmission
- PII masking by default: all `<input>`, `<textarea>`, and `[type=password]` elements are masked; configurable CSS selector blocklist for additional masking

**Privacy & Consent Controls**
- Consent-gate mode: SDK only activates autocapture after `conduit.consent()` is called (for GDPR/PDPA compliance)
- IP anonymisation: strip last octet of IPv4 address before storage
- Do-not-track (DNT) header respect: configurable
- Data retention configuration at the project level

**Custom Event API**
```javascript
conduit.track('event_name', { property: value });
conduit.identify('user_id', { name, email, plan });
conduit.setPageContext({ pageType: 'product', productId: '123' });
conduit.trackError('payment_failed', { code: 'card_declined' });
```

**SDK Delivery**
- CDN-hosted self-contained snippet (< 20 KB gzipped)
- NPM package for framework-native integration
- Google Tag Manager template for no-code deployment
- Snippet generates its own `conduit.js` async loader (non-render-blocking)

---

### 3.2 Event Ingestion Pipeline

**Ingest API**
- HTTPS endpoint receiving batched event payloads (JSON) from the SDK
- Payload validation and schema enforcement
- Tenant and project-key-based routing
- Deduplication by `eventId` (UUID)
- Rate limiting per project to prevent abuse

**Event Schema (normalised)**
```
{
  eventId: UUID,
  sessionId: UUID,
  visitorId: UUID,
  projectId: string,
  tenantId: string,
  timestamp: ISO8601,
  type: enum(click|scroll|move|pageview|custom|error|performance|form|replay_chunk),
  url: string,
  referrer: string,
  device: { type, os, browser, viewport, screenResolution },
  geo: { country, region, city },
  payload: object   // type-specific data
}
```

**Storage Architecture**
- Hot path (real-time): Pub/Sub topic → Cloud Run consumer → BigQuery streaming insert
- Warm path (session replay chunks): Cloud Storage bucket with project-scoped paths
- Cold path (aggregated metrics): scheduled BigQuery aggregation jobs for heatmaps and funnel data
- Firestore for session metadata index (fast lookup by sessionId, visitorId, date range)

---

### 3.3 Session Replay

**Server-side storage**
- rrweb event stream stored as compressed JSON in Cloud Storage, keyed by `projectId/YYYY/MM/DD/sessionId.json.gz`
- Session metadata index in Firestore: `sessionId`, `visitorId`, `startTime`, `duration`, `pageCount`, `deviceType`, `country`, `frustrationSignals[]`, `tags[]`, `starred`

**Replay Player UI**
- Timeline scrubber with event markers (click, scroll, error, page navigation, rage click)
- Playback speed control: 0.5×, 1×, 1.5×, 2×, 4×
- Skip idle time toggle (auto-skip periods > N seconds of inactivity)
- Console log panel (JS errors visible in sync with replay)
- Network requests panel (API calls visible in sync with replay)
- Frustration signal badges overlaid on the timeline
- Page navigation breadcrumb above the player
- Session metadata sidebar: visitor info, device, location, duration, pages visited
- Tag and star controls for team curation
- Share link generation (deep link to specific timestamp in replay)
- Direct navigation from replay → heatmap for same page
- Direct navigation from replay → journey view for same visitor

**Session Filtering**
- Filter sessions by: date range, page URL/pattern, device type, browser, country, session duration, frustration signals (rage click, dead click, error present), custom event fired, survey response linked, user segment

---

### 3.4 Heatmaps

**Heatmap Types**

| Type | Signal | Use Case |
|---|---|---|
| Click heatmap | All click/tap events | Identify what users click and what they miss |
| Scroll heatmap | Scroll depth percentages | Find the effective fold and content drop-off |
| Move heatmap | Cursor hover paths | Infer visual attention and hesitation |
| Rage click map | 3+ clicks in 2 sec on same element | Identify frustration hotspots |
| Dead click map | Clicks on non-interactive elements | Find clickable-looking dead zones |
| Attention heatmap | Viewport dwell time weighting | Reading behaviour and true visual attention |
| Engagement zone map | Composite click + scroll + move | Overall page engagement density |

**Zone-Based Heatmaps (Zoning Analysis)**
- User-defined or auto-detected zones on the page (individual DOM elements or rectangles)
- Per-zone metrics: attractiveness rate (% visitors who saw the zone), engagement rate (% who interacted), click rate, conversion contribution (% of converting sessions that interacted with zone), revenue per click (when e-commerce revenue events are tracked), exposure rate
- Zone export to CSV
- Zone comparator: side-by-side view for A/B variants, time periods, traffic sources, or device types

**Heatmap Filtering**
- Filter by: date range, device type, traffic source / UTM parameters, user segment, A/B test variant (via URL parameter or custom dimension)

**Heatmap Rendering**
- Canvas-based overlay rendered on a captured screenshot of the page at the target viewport width
- Handles dynamic pages: page snapshots taken at data collection time and served with the heatmap
- Colour scale: cool (blue → green) → warm (yellow → red), with opacity-scaled density

---

### 3.5 Journey & Funnel Analysis

**Journey Analysis (Pathing)**
- Entry page → sequence of page visits → exit page, visualised as a Sankey/flow diagram
- Nodes represent pages (grouped by URL pattern or page type); edges represent transitions
- Drop-off percentage at each node
- Identify most common paths through the site, unexpected paths, and circular loops
- Sunburst view: radial expansion from a selected entry point showing downstream navigation probabilities
- Segment overlay: compare paths for different audience segments
- Jump from any journey node → relevant session replays

**Funnel Analysis**
- Visual funnel builder: define steps by page URL, URL pattern, or custom event
- Per-step conversion rate and drop-off count
- Time-to-convert distribution per step
- Cross-segment funnel comparison: new vs. returning, device, source
- Cross-device funnel stitching (requires user identification)
- Jump from any step → filtered session replays of drop-off users

---

### 3.6 Form Analytics

- Per-field engagement: time to first interaction, time spent, refill count, abandonment rate, blank submission rate
- Funnel view of form completion steps
- Detection of fields that are frequently left blank vs. frequently refilled (confusion signal)
- Error message exposure tracking (fields where users see validation errors)
- Visual heatmap overlay on the form
- Session replay integration: click into a field metric → filtered replays of users who interacted with that field

---

### 3.7 Web Analytics Overview

Conduit needs a first-party web analytics baseline so clients have traffic context alongside behavioural data. This is the layer that supplements (not replaces) Google Analytics.

**Metrics to collect and display:**
- Sessions, unique visitors, pageviews, pages/session, session duration, bounce rate
- Traffic sources: direct, organic search, referral, social, paid (UTM-based)
- Top pages by pageviews, engagement time, and exit rate
- Device breakdown: desktop, mobile, tablet
- Browser and OS distribution
- Geographic distribution: country, region, city
- New vs. returning visitor ratio
- Real-time active visitor count

---

### 3.8 Experience Monitoring

**Core Web Vitals (RUM)**
- LCP, INP, CLS, TTFB, FCP collected via `web-vitals` library in the SDK
- Per-page and site-wide percentile views (P50, P75, P95)
- Segmented by device type, connection type (from Network Information API), and geography
- Historical trend charts with annotated deployment events
- Threshold alerting: configurable good/needs-improvement/poor thresholds per metric
- Correlation view: CWV scores overlaid on bounce rate and conversion metrics

**Synthetic Monitoring**
- Scheduled headless browser probes (Playwright-based) for critical page availability and performance
- Global probe locations (minimum: SG, US, EU)
- Waterfall view of resource loading breakdown
- Alert on availability failure or performance regression

**JavaScript Error Tracking**
- Error list with deduplication and grouping
- Per-error: count, affected session count, first seen, last seen, affected browsers/OSes
- Stack trace with source map support (upload source maps as part of CI/CD)
- Session replay link from any error instance
- Business impact: conversion rate in sessions with vs. without this error

**API Error Tracking**
- Intercepted XHR/Fetch failures: status code, URL pattern, error rate
- Custom API error rules (configurable endpoint patterns)
- Response body capture (configurable, opt-in, PII-safe)
- Session replay link for any API error instance

**Alerting Engine**
- Rule-based alerts: metric (CWV, error rate, conversion rate, bounce rate) + threshold + time window
- AI-powered anomaly alerts: automatic sensitivity, fires when metric deviates beyond expected variance
- Alert channels: email, Slack webhook, ARM integration (routing errors into ARM console)
- Alert history and acknowledgement workflow

**Frustration Signal Dashboard**
- Aggregate counts and trend charts for: rage clicks, dead clicks, scroll bounce, quick exits, u-turns, error clicks
- Frustration score composite metric per page
- Segment by page, device, and date range
- Jump from frustration signal → session replay

---

### 3.9 Voice of Customer (Feedback & Surveys)

**Feedback Widget**
- Persistent on-page widget (tab or floating button): users can submit typed feedback and a 1–5 star or emoji sentiment rating at any time
- Customisable widget position, colour, and prompt text
- Screenshot capture option (annotated by user)
- All responses stored with session context for replay linkage

**On-Site Polls**
- Single-question pop-up triggered by configurable conditions: time on page, scroll depth, exit intent, element interaction, custom event
- Response types: multiple choice, open text, NPS (0–10), star rating
- Targeting rules: show only to specific URL patterns, device types, or visitor segments
- Response → session replay linking

**Surveys**
- Multi-question forms with conditional logic (branching)
- Shareable survey URL for off-site distribution
- Embeddable on-page version
- Response types: single choice, multi-choice, open text, rating scale, NPS, likert scale
- Pre-built templates: exit intent, post-purchase, onboarding, NPS, feature satisfaction
- AI survey generator (via Exigence integration — see Section 4)
- Analytics dashboard: response rate, completion rate, per-question breakdown, word cloud for open text

---

### 3.10 Conduit Console (Dashboard UI)

The Conduit Console is the primary web UI for clients to view all collected data. It is a multi-module dashboard that integrates all sub-systems.

**Navigation Structure**
- Sidebar navigation to modules: Overview, Heatmaps, Session Replay, Journeys, Funnels, Form Analytics, Web Analytics, Experience Monitoring (Errors, Performance, Frustration), Voice of Customer (Surveys, Feedback), AI Insights (Exigence), Settings
- Project/date range switcher at the top of every module
- Global segment filter (device, country, source, user segment) persistent across modules

**Overview Dashboard**
- Summary cards: sessions today/this week, unique visitors, avg. session duration, bounce rate, top page, top error
- Mini heatmap thumbnail for the top visited page
- Frustration signal badges with counts
- Latest AI insight summary card (from Exigence)
- Real-time session count

**Customisable Workspaces**
- Drag-and-drop dashboard builder with a widget library
- Widget types: line chart, bar chart, single-value KPI card, heatmap thumbnail, session replay list, funnel mini-view, error list, survey response count, NPS trend, segment comparison table
- Save and name multiple workspace layouts
- Share workspace with team (read-only shareable link)
- Export workspace to PDF report

**Data Table Views**
- Paginated sortable tables for: sessions, errors, survey responses
- Column picker and CSV export on all tables

**Cross-Module Linking**
- Every data point in Conduit links to related data in another module: heatmap hotspot → session replays, error instance → session replay, journey node → session replays, survey response → session replay

---

### 3.11 Segmentation & Audience Builder

- Build named segments based on: device type, browser, OS, country, traffic source, UTM parameters, page visited, custom event fired, custom property set via `conduit.identify()`, survey response, frustration signal encountered
- Segments are persistent and reusable across all modules
- Compare any two segments side-by-side within any module (heatmaps, funnels, journeys)
- Export segments (session IDs) to Exigence for AI analysis or to external CRM/marketing tools via webhook

---

### 3.12 Data Export & Integrations

**Native Exports**
- Session replay list: CSV/JSON export of session metadata
- Heatmap data: raw click coordinate CSV per page
- Survey responses: CSV export
- Web analytics: CSV/JSON export

**Warehouse Export**
- Scheduled export of all event data to BigQuery (native, same project)
- Optional S3/Snowflake export via connector

**Webhooks**
- Send any event (new survey response, new error alert, frustration threshold crossed) to a configurable HTTPS endpoint
- Exigence webhook for AI processing triggers (see Section 4)

**Integrations**
- Slack: alert notifications, weekly summary posts
- Jira/Linear: create tickets directly from error instances or session replays
- Google Analytics 4: send Conduit custom events to GA4 as an enrichment layer
- Google Tag Manager: Conduit SDK available as a GTM template
- HubSpot: sync identified visitor data and NPS scores

---

## 4. Exigence AI Features for Conduit

Exigence is Citadel's AI product line. Conduit feeds raw and processed data to Exigence, and Exigence returns insights, summaries, and autonomous analysis results to Conduit's console UI. The integration boundary is clean: Conduit owns data collection and display; Exigence owns all inference workloads.

### 4.1 Session Replay AI Summaries

**Single-session summary**
- Input: full rrweb event stream for one session
- Output: a structured summary card containing: visitor intent inferred from page sequence, key actions taken, friction moments identified (rage click on X, error on Y, U-turn at Z), and recommended area to investigate
- Trigger: on-demand from the session replay player UI ("Summarise this session" button)

**Multi-session batch summary**
- Input: a filtered set of sessions (e.g., all sessions that hit the checkout error page, or all sessions with a rage click on the CTA)
- Output: a thematic summary across N sessions: common patterns, recurring friction points, inferred root causes, frequency distribution of pain points
- Trigger: from any session list view with an active filter; also schedulable

### 4.2 Heatmap AI Interpretation

- Input: zone-level metrics (attractiveness, engagement, click rate, conversion contribution) for a page
- Output: a natural language interpretation of the heatmap ("The navigation menu has a 95% attractiveness rate but only 12% engagement, suggesting users notice it but find it unhelpful. The CTA button has 8% exposure — it may be below the effective fold for most visitors.")
- Highlight the top 3 actionable opportunities identified from the heatmap data
- Trigger: "Interpret this heatmap" action in the heatmap view

### 4.3 Natural Language Analytics Query (Chat Interface)

- A chat panel available globally in the Conduit Console, powered by Exigence
- Users type natural language questions: "Why did conversion drop on the pricing page this week?", "Which pages have the highest frustration score?", "Show me sessions where users hit a payment error after spending more than 5 minutes on the site"
- Exigence queries Conduit's BigQuery data layer, builds the answer, and returns it with supporting visualisations (chart, session list, heatmap thumbnail)
- Follows up with recommended next actions

### 4.4 Anomaly Detection & Proactive Alerts

- Exigence runs scheduled monitoring jobs against Conduit's metric streams
- Detects statistically significant deviations from baseline in: conversion rate, bounce rate, error rate, frustration score, session duration, Core Web Vital percentiles
- Correlates anomalies across dimensions to infer root cause ("Conversion rate dropped 18% on mobile in the UK after the 14:30 deployment — coincides with a spike in API 500 errors on /api/checkout")
- Alerts are surfaced in the Conduit Console AI panel and sent via configured channels (Slack, email)

### 4.5 AI Survey Generator

- Input: a research goal described in plain text ("I want to understand why users abandon the pricing page without signing up")
- Output: a complete survey structure (questions, response types, conditional branching logic) ready to activate in Conduit's VoC module
- Exigence pre-seeds the goal with relevant context from existing Conduit data (top drop-off points, existing frustration signals on that page) to produce more targeted questions

### 4.6 VoC Sentiment Analysis & Summarisation

- Input: batch of survey open-text responses (or feedback widget submissions)
- Output: theme clusters, sentiment distribution (positive/negative/neutral per theme), top quoted phrases (paraphrased), and a recommended action list
- Available in the Survey Analytics view with a "Summarise with AI" trigger

### 4.7 Journey AI — Recommended Optimisations

- Input: journey analysis data (pathflow, drop-off rates, segment comparisons)
- Output: a prioritised list of journey improvement recommendations: "Users who enter via the /pricing page and then visit /docs have a 3× lower conversion rate than those who go directly to /signup. Consider adding a CTA on /docs targeting this segment."
- Trigger: "Get AI recommendations" action in the Journey Analysis module

### 4.8 Automated Analysis Scheduling (Agentic)

- Clients configure recurring analysis jobs in Exigence, specifying: analysis type, data scope (project, page group, date window), frequency (daily, weekly), and delivery channel (in-app, email)
- Exigence autonomously executes the analysis on schedule, builds the result, and delivers a structured insight report
- Examples: "Every Monday, analyse last week's top-error sessions and summarise what went wrong"; "Daily: flag any page where bounce rate increased by more than 10% since yesterday"

### 4.9 Conduit × Exigence Data Contract

- Conduit emits a Pub/Sub event for every significant Conduit event that Exigence may want to act on: `conduit.session.ended`, `conduit.error.detected`, `conduit.frustration.threshold_crossed`, `conduit.survey.response_received`, `conduit.anomaly.detected`
- Exigence subscribes to these topics and processes asynchronously
- Results are written back to Firestore under `conduit_ai_insights/{projectId}/{insightId}` and picked up by the Conduit Console via Firestore listener

---

## 5. UI & Widget Specifications

### 5.1 Module Layout Pattern

All Conduit Console modules follow a consistent three-panel layout:

```
┌────────────────────────────────────────────────────────────────┐
│  [Project Picker]  [Date Range]  [Segment Filter]  [AI Chat ✦] │ ← Top bar
├────────┬───────────────────────────────────────────────────────┤
│        │                                                        │
│  Nav   │  Module Content Area                                   │
│        │                                                        │
│        │  ┌─────────────────┐  ┌─────────────────┐             │
│        │  │  Metric Card     │  │  Metric Card     │             │
│        │  └─────────────────┘  └─────────────────┘             │
│        │                                                        │
│        │  ┌─────────────────────────────────────────────────┐  │
│        │  │  Primary Visualisation (chart / heatmap / etc.) │  │
│        │  └─────────────────────────────────────────────────┘  │
│        │                                                        │
│        │  ┌─────────────────────────────────────────────────┐  │
│        │  │  Data Table / Detail List                        │  │
│        │  └─────────────────────────────────────────────────┘  │
└────────┴───────────────────────────────────────────────────────┘
```

### 5.2 Widget Inventory

**KPI Summary Card**
- Fields: label, primary value, delta (vs. previous period, with direction arrow and colour), sparkline (7-day trend), unit
- Variants: sessions, visitors, bounce rate, conversion rate, avg. duration, error count, NPS score, frustration score

**Line Chart**
- X-axis: time (hour, day, week); Y-axis: metric value
- Multi-series (up to 3 metrics overlaid); segmented series (device split, etc.)
- Annotation layer: mark deployment events, campaign launches, alert firings
- Hover tooltip with exact value and comparison period delta

**Bar Chart**
- Horizontal: top pages, top errors, top traffic sources
- Vertical: funnel steps, time-of-day distribution, device breakdown
- Colour-coded segments for category comparison

**Heatmap Viewer Widget**
- Full-page heatmap canvas with overlay controls (click/scroll/move/rage/attention selector)
- Overlay opacity slider
- Device switcher (desktop / tablet / mobile)
- Date range and segment filter within widget
- Screenshot thumbnail navigation for multi-page heatmaps

**Session Replay Player Widget**
- Embedded player with timeline, scrubber, playback controls, event markers
- Sidebar: session metadata, page navigation breadcrumb, frustration signal badges, linked heatmap button
- Console and network panels (collapsible)

**Journey Flow Diagram**
- Sankey-style SVG diagram with interactive nodes
- Click a node to filter session list to that page
- Toggle between flow and sunburst views
- Segment colour overlay

**Funnel Chart**
- Vertical stepped funnel with step labels, conversion rates, and drop-off percentages
- Hover to see step counts and segment breakdown
- Click step → filtered session replay list

**Error List Table**
- Columns: error message (truncated), type, occurrence count, affected sessions, first seen, last seen, conversion impact, actions (view sessions, create ticket)
- Sortable by any column; filterable by type and date
- Row expand: full stack trace, affected browsers, session replay links

**Survey Response Dashboard**
- Response count, completion rate, average NPS (if applicable)
- Per-question breakdown: bar chart for choice questions, word cloud and theme cards for open text
- Response list (paginated), with session replay link per response
- "Summarise with AI" trigger button

**AI Insight Card**
- Exigence-generated insight: icon, title, description paragraph, supporting data bullet points, recommended action button
- Card states: loading (skeleton), loaded, dismissed
- Source attribution: which module's data generated this insight

**Real-Time Visitor Counter**
- Live count of active visitors (sessions in last 5 minutes)
- Mini list of currently active pages with visitor counts
- Pulse animation to indicate live state

**Custom Workspace Builder**
- Widget picker (sidebar or modal): browse and add any widget from the inventory
- Drag-and-drop grid layout (12-column responsive grid)
- Widget configuration panel (date range, metric, segment)
- Workspace name, save, rename, duplicate, delete
- Share workspace (read-only URL)
- Export workspace to PDF

### 5.3 Heatmap Comparator UI

```
┌──────────────────────────┬──────────────────────────┐
│  Heatmap A                │  Heatmap B                │
│  [Date: Last 7 days]      │  [Date: Previous 7 days]  │
│  [Device: Desktop]        │  [Device: Mobile]         │
│                            │                            │
│  [Heatmap canvas]         │  [Heatmap canvas]         │
│                            │                            │
└──────────────────────────┴──────────────────────────┘
     Sync scroll: ON    Overlay diff: OFF
```

- Two panels side-by-side with independent filter controls
- Sync scroll mode: both panels scroll together for direct comparison
- Difference overlay mode: highlights zones where A and B diverge significantly

### 5.4 Session Replay Player — Detailed Layout

```
┌────────────────────────────────────────────────────────────────────┐
│  [← Back to sessions]  Session #abc123  2024-06-12 14:23:07       │
├──────────────────────────────────────────────────────────┬─────────┤
│                                                          │ Metadata│
│              Replay Viewport                             │ ─────── │
│              (DOM render)                                │ Visitor │
│                                                          │ Device  │
│                                                          │ Country │
│                                                          │ Duration│
│                                                          │ Pages   │
│                                                          │ ─────── │
│                                                          │ Tags    │
│                                                          │ ⭐ Star  │
├──────────────────────────────────────────────────────────┴─────────┤
│  [event markers on timeline]                                        │
│  ────────────────────●────────────────────●──────────────── 3:42   │
│  [◀] [▶] 0:00  [0.5× 1× 1.5× 2× 4×]  [Skip idle: ON]  [🔗 Share]│
├─────────────────────────────────────────────────────────────────────┤
│ [Console] [Network] [Events]                                        │
│  14:23:12  TypeError: Cannot read 'price' of undefined             │
│  14:23:19  GET /api/cart → 500 Internal Server Error               │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 6. SDK & Instrumentation Requirements Summary

| Component | Technology | Notes |
|---|---|---|
| Web SDK | TypeScript, compiled to UMD/ESM | < 20 KB gzipped; async load |
| DOM Recording | rrweb (or custom rrweb-compatible) | Incremental mutation capture |
| Core Web Vitals | `web-vitals` npm library | LCP, INP, CLS, TTFB, FCP |
| Error capture | `window.onerror`, `unhandledrejection`, XHR/fetch patch | |
| Event batching | Local buffer, flush on idle / page hide / every 5 sec | `sendBeacon` for page unload |
| PII masking | CSS selector blocklist + input field auto-mask | |
| Custom events | `conduit.track()`, `conduit.identify()`, `conduit.setPageContext()` | |
| Consent gate | `conduit.consent()` before activation | GDPR/PDPA compliance |
| GTM template | Community template JSON | No-code deployment path |
| React Native SDK | Native iOS/Android bridge via RN module | Priority: touch heatmaps, session replay |
| Ingest API | Cloud Run HTTPS endpoint | JSON batch, gzipped, project-key auth |
| Replay storage | GCS bucket | Per-project, per-date prefix |
| Event storage | BigQuery streaming insert | Partitioned by date, clustered by projectId |
| Session index | Firestore | Fast metadata lookup |
| Aggregation | BigQuery scheduled queries | Heatmap density, funnel counts, daily metrics |
| Exigence bridge | Cloud Pub/Sub events | Async AI processing |

---

## 7. Privacy & Compliance Requirements

- All DOM recording must auto-mask `<input>`, `<textarea>`, `[type=password]`, and `[type=email]` fields by default
- Configurable blocklist of CSS selectors to extend masking
- IP addresses anonymised (last octet stripped) before storage
- Session data partitioned and isolated per `tenantId` and `projectId`
- Configurable data retention periods (default 90 days for session replays, 13 months for aggregated metrics)
- Consent-mode integration for GDPR: SDK does not activate autocapture until `conduit.consent()` is called
- All data stored in the client's own GCP project (per Citadel's architecture), not in a shared Citadel data store
- PDPA (Singapore) compliance: no cross-border data transfer without explicit consent configuration

---

## 8. Differentiation Notes (Conduit vs. Reference Platforms)

| Dimension | Hotjar/Contentsquare | Conduit |
|---|---|---|
| Multi-tenancy | SaaS with shared infrastructure | Each client's data in their own GCP project |
| AI/ML | Built-in (Sense) | Routed to Exigence; clean separation |
| Error monitoring | Separate DEM module | Cross-referenced with ARM's existing telemetry |
| Mobile | Contentsquare has native SDKs | React Native first |
| Pricing model | Per-session usage-based | Bundled within Citadel Platform subscription |
| Target user | Broad market | Citadel-managed small business clients |
| Setup complexity | Self-service snippet | Citadel-managed deployment as part of onboarding |

---

*End of Report*