# Palisade boundary grammar — authoring reference

Written 15/08/26. Feature 6.1 Task 6.1.2 requires the chosen grammar to be
documented; this is that page, aimed at whoever writes a boundary rather than
whoever implements one. The decision and its rationale are in `DECISIONS.md`
15/08/26; the implementation and its adversarial tests are in
`citadel_core/palisade`.

A boundary answers three independent questions. An **Access Boundary** governs
reads, an **Effect Boundary** governs writes/modifications/deletions/execution,
and a **Data Handling Boundary** governs where matched content may be processed
or relayed. All three must pass.

## Rules

A Data Handling rule carries `handlingMode`, `kind`, `pattern`, optional
resource/data-class selectors, a destination allowlist, approval-policy
reference, expiry, and `enableArmCapture`.

| Handling mode | Meaning |
|---|---|
| `thirdPartyRelay` | Content may reach explicitly allowlisted external providers |
| `citadelRelay` | Content may reach explicitly named Citadel-hosted destinations for the same project |
| `inSituProcessing` | Content stays on the host; commands and bounded evidence may move |
| `noAccess` | The resource cannot be read, processed, or relayed |

- **Most restrictive wins:** `noAccess`, `inSituProcessing`, `citadelRelay`,
  then `thirdPartyRelay`. Order in the list is irrelevant.
- **No match, invalid policy, expiry, or unavailable policy means
  `noAccess`.** There is no implicit permission.
- A `url` rule never authorises a filesystem target, and a `path` rule never
  authorises a URL.
- `enableArmCapture` is valid only for `inSituProcessing`, defaults false, and
  authorizes bounded ARM evidence rather than relay of the protected resource.

## URL patterns

Browser-extension match patterns: `<scheme>://<host>/<path>`, plus the literal
`<all_urls>`.

| Component | Accepts |
|---|---|
| scheme | `*` (http **or** https), or `http`, `https`, `file` |
| host | exact (`app.example.com`), leading wildcard (`*.example.com`), or `*` |
| path | glob where `*` matches anything, **including `/`** |

The path is matched against path **and query string**, so
`https://a.example.com/*admin*` catches `?role=admin`.

Rejected at parse time, rather than quietly narrowed:

| Pattern | Why |
|---|---|
| `https://*evil.example.com/*` | a host wildcard must be a whole leading label |
| `https://ex*ple.com/*` | no wildcards inside a host |
| `https://*.com/*` | would span an entire top-level domain |
| `https://example.com` | missing path component |
| `ftp://example.com/*` | unsupported scheme |

**`*.example.com` matches subdomains only, never `example.com` itself.** To
cover both, write two rules. This is settled by decision because the upstream
documentation contradicts itself; excluding the apex is the reading that cannot
accidentally over-grant.

## Path patterns

npm-ecosystem glob semantics — the same ones `fast-glob` and `globby` use.

| Token | Means |
|---|---|
| `*` | any characters **except** `/` |
| `**` | any characters including `/`, and also matches the bare directory |
| `?` | one character |
| `[abc]` | one character from the class |

Paths must be absolute and POSIX-style.

## The one trap worth memorising

**`*` means different things in the two grammars.** In a URL path it crosses
`/`; in a filesystem path it stops at `/`. So `https://host/api/*` covers
`/api/v1/x`, while `/api/*` does **not** cover `/api/v1/x` — that needs
`/api/**`. Both behaviours are inherited from the conventions themselves, which
is why neither was "fixed".

## Canonicalisation is part of the contract

Patterns are matched against strings, so the target must be canonical **before**
evaluation:

1. Resolve `.` and `..`, collapse duplicate separators, drop a trailing `/`.
   `canonicalPath()` does this and refuses relative paths and null bytes. Note
   `..` past the root clamps to the root, exactly as the OS does.
2. **Resolve symlinks** — the local runner must `realpath` before evaluating.

Step 2 is not optional, and the package proves why against a real filesystem: a
symlink at `client/data/link → ../secrets` makes `client/data/link/key.pem`
match an allow of `client/data/**`, miss a deny of `client/secrets/**`, and
read the file. After `realpath` the same request is denied. Any caller that
skips it has a boundary in name only.

## Examples

```jsonc
// Read the client's export folder, but never their credentials.
{ "handlingMode": "citadelRelay", "kind": "path", "pattern": "/Users/client/Exports/**" }
{ "handlingMode": "noAccess", "kind": "path", "pattern": "/Users/client/Exports/.env*" }

// Drive the client's own web app, and nothing else on the internet.
{ "handlingMode": "inSituProcessing", "kind": "url", "pattern": "https://*.client-app.com/*" }
{ "handlingMode": "inSituProcessing", "kind": "url", "pattern": "https://client-app.com/*" }
{ "handlingMode": "noAccess", "kind": "url", "pattern": "https://*.client-app.com/admin/*" }
```

## Not yet settled

- **Windows paths.** The grammar is POSIX-only today. The runner is
  cross-platform, so drive letters and backslash separators need a decision
  before it ships on Windows.
- **Percent-encoding.** URL paths are compared as `URL` normalises them; a
  pattern written with an encoded character and a target with the decoded form
  will not match. Worth revisiting when a real connector needs it.
