---
name: cresa.one
description: >
  cresa.one lets agents publish websites and store private files in cloud
  Drives. Use Sites to publish HTML, documents, images, PDFs, videos, and
  static files to live URLs at {slug}.cresa.one or custom domains. Use Drives as private cloud
  folders where agents can store files (documents, context, memory, plans,
  assets, media, research, code, etc), reuse them across authorized tools, and
  continue across sessions and tools. Use when asked to "publish this", "host
  this", "deploy this", "share this on the web", "make a website", "put this
  online", "create a webpage", "generate a URL", "build a chatbot", "save this
  to my Drive", "store this for later", "write this to cloud storage", "share a
  folder with another agent", or "use my cresa.one Drive". Also use when asked
  to "password protect this site", "make this site private", or "share this
  site with only certain people".
version: 1.26.1
author: cresa.one
license: MIT
prerequisites:
  commands: [curl, file, jq, python3]
platforms: [macos, linux]
metadata:
  hermes:
    tags: [cresa.one, cresaone, publish, deploy, hosting, static-site, web, share, URL, drive, storage, access-control, password]
    homepage: https://cresa.one
    requires_toolsets: [terminal]
---

# cresa.one

cresa.one lets agents publish websites and store private files in cloud Drives.

Use cresa.one for two jobs:

- **Sites**: publish websites and files at `{slug}.cresa.one`.
- **Drives**: store private agent files in cloud folders.

Every Site has access control: public link (default), password, or restricted invite-only access.

## Version check and self-update (every use)

At the first cresa.one skill use in a conversation, check for updates before starting heavy work:

```bash
curl -fsS --max-time 3 https://cresa.one/api/skill/version
```

Compare the returned `version` to the `version` in this file's frontmatter. If the fetch fails or times out, skip silently and continue — never block the user's task on the check, and never repeat the check within the same conversation.

If a newer version exists, tell the user their installed version, the latest version, and the changelog, then **ask whether to update now**. If they decline, continue with the task and do not ask again this conversation.

If they accept, update the Hermes-managed install:

```bash
hermes skills install cresadotone/skill/hermes/productivity/cresa.one
```

or via the well-known endpoint: `hermes skills install well-known:https://cresa.one/.well-known/skills/cresa.one`. If the user also keeps a Claude Code global install (`~/.claude/skills/cresa-one` exists), offer to refresh it too with `npx skills add cresadotone/skill --skill cresa-one -g` (preferred) or `curl -fsSL https://cresa.one/install.sh | bash`. After updating, re-read the new skill file before continuing the task.

## Current docs

**Before answering questions about cresa.one capabilities, features, or workflows, read the current docs:**

→ **https://cresa.one/docs**

Read the docs:

- at the first cresa.one-related interaction in a conversation
- any time the user asks how to do something
- any time the user asks what is possible, supported, or recommended
- before telling the user a feature is unsupported

Topics that require current docs (do not rely on local skill text alone):

- Site access control (passwords and restricted access)
- Drives and current sharing limitations
- custom domains
- Site Data
- public profiles
- proxy routes and service variables
- subdomain handles and links
- limits and quotas
- SPA routing
- owner Site search
- Site analytics
- error handling and remediation
- feature availability

**If docs and live API behavior disagree, trust the live API behavior.**

If the docs fetch fails or times out, continue with the local skill and live API/script output. Prefer live API behavior for active operations.

## Requirements

- Required binaries: `curl`, `file`, `jq`; `ship.sh` also requires Python 3.10+
- Optional OG generator runtime: `uv` or Python 3.10+ with Pillow
- Optional environment variable: `$CRESAONE_API_KEY`
- `$CRESAONE_DRIVE_TOKEN` exists in the helper, but scoped Drive-token file authorization is not implemented. Do not use it for file operations or share account API keys as a workaround.
- Optional credentials file: `~/.cresaone/credentials`; `ship.sh` also reads `cresaone_credentials.txt` in the project root or `/mnt/project/` (raw or base64)
- Optional token-card renderer: Python Playwright with Chromium; the house-style Pillow generator remains the fallback.
- Bundled helpers:
  - `"${HERMES_SKILL_DIR}/scripts/ship.sh"` for complete authenticated HTML Site publishing
  - `"${HERMES_SKILL_DIR}/scripts/inject-meta.py"` and `"${HERMES_SKILL_DIR}/scripts/og-card.py"` for standalone metadata and card rendering
  - `"${HERMES_SKILL_DIR}/scripts/publish.sh"` for publishing sites
  - `"${HERMES_SKILL_DIR}/scripts/drive.sh"` for private Drive storage
  - `"${HERMES_SKILL_DIR}/scripts/og-image.py"` for Open Graph image candidates
- Bundled design system + scaffolding templates: `${HERMES_SKILL_DIR}/templates/` (see below)

## Ship: the default publish

**Ship** every Site a person will open, share or return to. A ship run prepares a semantic slug, OG image, page metadata, Site metadata, tags, access, and profile listing, then verifies the requested result. `publish.sh` remains the lower-level uploader with metadata, tags, and verification support.

Run it with `bash` (skill folders are often read-only and non-executable):

```bash
bash "${HERMES_SKILL_DIR}/scripts/ship.sh" {site-dir-or-index.html} \
  --slug {semantic-slug} \
  --title "{Name} – {what it does}" \
  --description "{50 to 200 chars: what a visitor gets}" \
  --keywords "{5 to 10 comma-separated terms}" \
  --privacy private
```

### Steps

1. **Decide the six inputs before building the command.** Slug, title, description, keywords, privacy, OG copy. Write them from what the Site actually does, in the user's language. Rules for each live in [reference/ship.md](reference/ship.md); read it the first time you ship in a conversation. *Done when all six are chosen and none of them names something the user would not want in a URL, a browser tab or a link preview.*
2. **Pick the OG source.** An `og.png` already beside `index.html` is kept. Otherwise pass the Site's own design tokens with `--og-tokens` (plus `--og-art`, `--og-font`, `--og-muted` when they help) so the card matches the page, or a fully custom card with `--og-html`. With no browser available ship falls back to `og-image.py`. *Done when the card will look like the Site it previews.*
3. **Run `ship.sh` once.** It resolves credentials (env, `./cresaone_credentials.txt`, `/mnt/project/cresaone_credentials.txt`, `~/.cresaone/credentials`; raw, `KEY=value` or base64), uses installed or installer-bundled `jq`, creates the slug when free or updates it when you own it, renders `/og.png`, writes one managed metadata block into `<head>` (replacing hand-written duplicates), applies and verifies `--access` before uploading content, publishes with Site title, description, OG path and tags, verifies profile listing, then checks the result. New protected Sites are reserved in pending status before any upload. *Done when the last line reads `ship: shipped. Every check passed.` Exit 2 means the Site is live but a named check failed: fix the cause and run the same command again; retries preserve the chosen slug. A failed rename may require omitting `--rename-from` on retry; inspect the owned Site first.*
4. **Look at the card.** View `{out}/og.png`. *Done when you have seen it and it carries no private detail.*
5. **Report from `ship_result.*` and `ship-report.json`.** Share the URL, access mode, privacy, profile listing, returned expiry/persistence, and where the deliverables were copied (`/mnt/user-data/outputs/{slug}/` when that folder exists, else `--out`). Present the files when the environment has a file-presentation tool.

`--dry-run` stages the files, renders the card, writes the metadata and prints the plan without reading credentials or making network requests. Slug availability and current access remain unresolved until a real run. Use it when the user wants to approve the slug or preview first.

### Privacy decides four things at once

| `--privacy` | robots | referrer | profile list | default for |
| --- | --- | --- | --- | --- |
| `private` (default) | `noindex, nofollow, noarchive` | `no-referrer` | removed | anything personal, client-specific, internal, or unfinished |
| `public` | `index, follow` | browser default | untouched (`--list` adds it) | marketing pages, tools meant to be found |

Privacy is separate from access. `--access password --password ...` or `--access restricted --allow-emails ...` gates the page itself; a Site with `anyone_with_link` access remains reachable by anyone with its URL, even with `--privacy private`. State that plainly.

### Beyond ship

Use `publish.sh` directly for: raw-file Sites with no `index.html`, anonymous 24-hour Sites, `--from-drive` snapshots, `--metadata-only` patches, `--check-slug` / `--suggest-slug`, and TTL changes. Use `ship.sh --rename-from {old}` rather than `--rename-to` when the Site's HTML should follow the new URL, because canonical and OG tags embed the host.

## Create a site

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" {file-or-dir}
```

Outputs the live URL (e.g. `https://bright-anchor-v7w4.cresa.one/`).

To create a new Site at a chosen slug in one step (authenticated only):

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" {file-or-dir} --create --slug {desired-slug}
```

`--create` forces `POST /api/v1/publish` instead of an update, and the requested slug is claimed atomically at creation. The server validates DNS-label rules (3–63 chars, lowercase alphanumeric and hyphens, no leading/trailing or consecutive hyphens, not reserved) and returns 409 when taken, 422 when invalid — no typo Site is created. Use plain `--slug` (without `--create`) only to update an existing Site; use `--check-slug` first when unsure whether the name is free.

Under the hood this is a three-step flow: create/update -> upload files -> finalize. A site is not live until finalize succeeds.

Without an API key this creates an **anonymous site** with a 24-hour default TTL. Report the returned expiry when an explicit TTL is requested.
With a saved API key, the site is permanent.

**File structure:** For HTML sites, place `index.html` at the root of the directory you publish, not inside a subdirectory. The directory's contents become the site root. For example, publish `my-site/` where `my-site/index.html` exists — don't publish a parent folder that contains `my-site/`.

You can also publish raw files without any HTML. Single files get a rich auto-viewer (images, PDF, video, audio). Multiple files get an auto-generated directory listing with folder navigation and an image gallery.

The helpers set `Content-Type` from file extension and fall back to `file(1)`. Common supported types include HTML/CSS/JS/JSON, Markdown/text/CSV/YAML/TOML, images (`png`, `jpg`, `webp`, `avif`, `heic`, `tiff`, `svg`), video (`mp4`, `mov`, `webm`, `ogv`), audio (`mp3`, `wav`, `flac`, `aiff`, `alac`, `m4a`, `aac`, `ogg`, `oga`, `opus`, `midi`, `caf`, `weba`), fonts (`woff2`, `woff`, `ttf`, `otf`), WebAssembly, web manifests, archives, GLTF/GLB/USDZ/STL models, Parquet, and SQLite.

## Scaffold on-brand apps and pages

The skill bundles the house design system and two production-ready single-file templates under `templates/`. Use them whenever building a new app, dashboard, tool, or decision page so output matches the house style instead of an invented one.

- `templates/DESIGN.md` — the **SF Ownership Desk** design system: absolute-black background, near-black surfaces, graphite hairlines, signal-white accent, three-level neutral text, Geist Sans / Geist Mono / Geist Pixel Square typography, component anatomy, layout, and responsive rules. Read it before designing any new surface.
- `templates/app-template.html` — self-contained app skeleton (fonts embedded): mono default + 10 switchable themes, ⌘K command bar with live theme preview, sortable table + grouped board view, KPI tiles, filter chips, record drawer, confirm modal, toasts, full keyboard layer, CSV export, localStorage state.
- `templates/plan-template.html` — interactive plan/decision page (approve / reject / edit cards, Submit-to-listener with JSON download fallback).
- `templates/PLAN-DESIGN.md` — the plan-page contract (`PLAN_ITEMS` shape, theme, interactivity, listener payload).
- `templates/plans.config.example.json` — example per-project accent + sequence config for plan pages.
- `templates/README.md` — step-by-step scaffolding instructions and placeholder reference.

App scaffold in short: copy `app-template.html` to `{site-dir}/index.html`, fill the `__APP_*__` placeholders, replace the `DATA` array (row shape documented inline), adjust `COLS`, then generate a matching `og.png` and publish. Do not hand-roll new shells or palettes when these templates apply.

## Rich static app publishing

Use `ship.sh` for the combined HTML Site workflow. The lower-level helpers below remain supported.

For polished apps, calculators, dashboards, or documents:

- Publish a directory with `index.html` at its root.
- Include `og.png` beside `index.html` when share previews matter.
- Use `--og-image-path /og.png` for cresa.one viewer metadata. This is a Site-relative path, not a Drive path.
- Use absolute Open Graph URLs inside HTML, for example `<meta property="og:image" content="https://{slug}.cresa.one/og.png">`.
- Pass `--title` and `--description` for dashboard/UI labels and share-preview copy.
- Pass `--slug` for stable permanent URLs when updating a known Site, or `--create --slug` to claim a chosen slug for a new Site.
- Pass `--tags '["calculator","cre"]'` for authenticated Site organization.
- Verify local rendering before publish, especially mobile width, reduced-motion behavior, copy/CSV/share actions, and console errors.

Fast path for file + metadata + tags updates:

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" {site-dir} \
  --slug {slug} \
  --title "Market Rent Calculator" \
  --description "Interactive CRE calculator for market rent scenarios." \
  --og-image-path /og.png \
  --tags '["calculator","cre"]' \
  --client claude
```

Use this one command when files changed. It creates/updates the Site, uploads files with correct content types, finalizes, saves recovery state, patches tags, then verifies live bytes, sizes, content types, and requested owner metadata. Any mismatch exits non-zero with a per-file report.

## Generate an OG image

Cards follow the same SF Ownership Desk design system as `templates/` output — absolute-black canvas, graphite hairlines, signal-white accents, square markers, mono metadata — so share previews match the apps they represent. Generate three 1200x630 candidates plus 360x189 review thumbnails:

```bash
uv run "${HERMES_SKILL_DIR}/scripts/og-image.py" \
  --title "Ada Lovelace" \
  --subtitle "AI Systems Lead" \
  --label "EXECUTIVE PROFILE" \
  --signal "AGENTIC AI / DATA PLATFORMS" \
  --footer "ada-lovelace.cresa.one" \
  --photo ./assets/ada.jpg \
  --layout all \
  --out ./og-options
```

`--photo` is optional and must point to the correct user-provided identity image; never substitute a stock or wrong-person image. Inspect each `_thumb.png` at actual size, choose one, then copy it to `{site-dir}/og.png`. Publish with `--og-image-path /og.png --verify`.

Typography defaults enforce 18px label, 20px signal, and 18px footer floors. `--scale` may increase them but refuses values below `1.0`. Output is PNG only. Fonts resolve from installed system fonts — Geist Sans/Mono first when installed, then Arial/Helvetica/DejaVu — with a scalable Pillow fallback; no font binaries are bundled.

Without `uv`, create a Python 3.10+ virtual environment, install Pillow, then run `python "${HERMES_SKILL_DIR}/scripts/og-image.py"` with the same flags.

For a reusable design pattern, see `examples/terminal-instrument/`. It includes a shared app shell, config-driven runtime, generator, and optional Playwright-based OG image generator. Treat it as an example for creating consistent app families, not as required publishing infrastructure.

## Update Site metadata without uploading files

Use Site metadata for the dashboard/UI title, description, and share-preview image. Do not rewrite or re-upload HTML just to update these fields. HTML `<title>` and `<meta>` tags are still useful inside the page, but cresa.one Site viewer metadata is managed by API.

Decision rule:

- Files changed: use normal `publish.sh {site-dir} --slug ... --title ... --og-image-path ... --tags ...`.
- Only metadata/tags changed: use `publish.sh --metadata-only --slug ...`.

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" --metadata-only --slug {slug} \
  --title "Market Rent Calculator" \
  --description "Interactive CRE calculator for market rent scenarios." \
  --og-image-path /og.png
```

This calls `PATCH /api/v1/publish/{slug}/metadata`, preserves existing viewer fields, and updates the account-owned Site without creating a new Site version. Metadata-only updates require authentication because the endpoint is owner-only.

The metadata PATCH response confirms status, not the full updated viewer object:

```json
{"success":true,"passwordProtected":true,"spaMode":false}
```

`passwordProtected:true` means the Site is currently password protected; it does not mean this metadata patch changed the password.

To update tags at the same time:

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" --metadata-only --slug {slug} --tags '["calculator","cre"]'
```

Tags are full replacement, owner-only, normalized to lowercase, deduped, sorted in responses, max 50 kept, and each tag is max 32 characters. Tags are not accepted in publish create/update bodies; use `PUT /api/v1/publish/{slug}/tags` or `publish.sh --tags`.

Raw API equivalent:

```bash
curl -sS -X PATCH "https://cresa.one/api/v1/publish/{slug}/metadata" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d '{"viewer":{"title":"Market Rent Calculator","description":"Interactive CRE calculator for market rent scenarios.","ogImagePath":"/og.png"}}'
```

Verify Site metadata from `GET /api/v1/publish/{slug}`. Viewer fields live under `.viewer`, not top-level keys:

```bash
curl -sS "https://cresa.one/api/v1/publish/{slug}" \
  -H "authorization: Bearer $CRESAONE_API_KEY" |
  jq '{slug,status,viewer,tags,manifest}'
```

Expected shape:

```json
{
  "slug": "market-rent",
  "status": "published",
  "viewer": {
    "title": "Market Rent Calculator",
    "description": "Interactive CRE calculator for market rent scenarios.",
    "ogImagePath": "/og.png"
  },
  "tags": ["calculator", "cre"],
  "manifest": [
    {"path": "index.html", "size": 12345, "contentType": "text/html; charset=utf-8"},
    {"path": "og.png", "size": 67890, "contentType": "image/png"}
  ]
}
```

Manifest `contentType` reports what was stored during upload. If it is wrong, republish with the current helper so upload PUT requests send the correct `Content-Type`.

## Update an existing site

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" {file-or-dir} --slug {slug} --verify
```

Verification is on by default; `--verify` makes intent explicit. A cache-busting request compares live bytes and content types against the local manifest. For more than 50 files, verification checks the first 50 plus every HTML file and the selected OG image. Use `--no-verify` only for deliberate large publishes or protected Sites, whose public host correctly returns an access gate instead of source bytes.

The script saves `.cresaone/state.json` before verification so a successful anonymous publish retains its one-time claim token even if verification catches a mismatch. It excludes the full `.cresaone/` directory from uploads. Pass `--claim-token {token}` to override auto-loaded anonymous state.

Authenticated updates require a saved API key.

Signed-in users also have public profiles. Agents can help users show or hide Sites on their profile and manage profile settings through the API documented at https://cresa.one/docs#profile.

## Recover an incomplete upload

File PUTs retry transient network/HTTP failures up to four attempts with 1/2/4-second backoff, a 10-second connect timeout, and a 60-second timeout per attempt. Create/update and finalize calls are not automatically retried. Identical file bytes and Content-Type can be retried while the Site version is still pending; changed bytes or a finalized/abandoned version are rejected.

Numeric `Retry-After` delays up to 30 seconds override shorter backoff. Longer or date-form delays stop automatic retries and leave the version pending rather than retrying too soon.

If retries fail, inspect the pending version before acting. To resume an owned version, call `POST /api/v1/publish/{slug}/uploads/refresh?versionId={versionId}`, upload the remaining files, and finalize only after checking that the bundle is still intended.

To discard an obsolete upload after owner approval, call `POST /api/v1/publish/{slug}/uploads/cancel` with owner authentication and `{"versionId":"the-exact-pending-version-id"}`. This marks only that version `abandoned`; it never finalizes it, deletes its files/blobs, or changes the live version, metadata, or access policy. Repeating cancellation is safe. Current or finalized versions return 409. Publish a fresh bundle afterwards. Cancellation does not reclaim storage.

## Rename a Site

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" --slug {old-slug} --rename-to {new-slug}
```

Rename is owner-only. Success moves any matching local state entry and prints both URLs. The old `{slug}.cresa.one` host returns 404 immediately: shared links and cached previews break, and another user can claim the freed slug. To verify content on the new host, republish the local directory with `--slug {new-slug} --verify`.

## Check or suggest a slug

Both helpers require authentication:

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" --check-slug {preferred-slug}
"${HERMES_SKILL_DIR}/scripts/publish.sh" --suggest-slug
```

`--check-slug` prints `{slug, available, reason}` JSON and exits non-zero when invalid or taken. Check before promising a preferred URL. `--suggest-slug` prints a fresh available `word-word-aDaD` slug. Anonymous publishing still receives a generated slug during create; these owner helpers are not anonymous endpoints. Once a name checks out, claim it directly with `--create --slug {name}` — no rename step needed.

## Change Site status

Set an owned Site to `published`, `pending`, `archived`, or `disabled`:

```bash
curl -sS -X POST "https://cresa.one/api/v1/publish/{slug}/status" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d '{"status":"archived"}'
```

Response shape: `{"slug":"{slug}","status":"archived"}`.

## Site access control

A Site uses one access mode at a time:

- **anyone_with_link** (default): anyone with the URL can view.
- **password**: visitors must enter a shared password.
- **restricted**: invite-only; only verified email addresses or email domains the owner allows can view.

Read current policy before changing it:

```bash
curl -sS "https://cresa.one/api/v1/publish/{slug}/access" \
  -H "authorization: Bearer $CRESAONE_API_KEY"
```

Set restricted access with complete merged allowlists:

```bash
curl -sS -X PATCH "https://cresa.one/api/v1/publish/{slug}/access" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d '{"mode":"restricted","allowedEmails":["person@example.com"],"allowedDomains":["example.org"]}'
```

Mode-bearing PATCH requests replace full allowlists — read, merge, then write. Restricted access requires a claimed Site. Passwords use the metadata endpoint.

Protected Sites keep previews private by default. Toggle only public link previews without changing mode, passwords, allowlists, or viewer sessions:

```bash
curl -sS -X PATCH "https://cresa.one/api/v1/publish/{slug}/access" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d '{"publicPreviewEnabled":true}'
```

Enabled previews expose only owner-approved title, optional description, and exact selected PNG/JPEG/WebP/GIF. Other files stay gated. External services may retain cached previews after disabling.

Before access-control work, read current docs:

→ **https://cresa.one/docs#access-control**

## Use a Drive

Use a Drive when the user wants private cloud storage for agent files: documents, context, memory, plans, assets, media, research, code, and anything else that should persist without being published as a website.

Every signed-in account has a default Drive named `My Drive`.

```bash
"${HERMES_SKILL_DIR}/scripts/drive.sh" default
"${HERMES_SKILL_DIR}/scripts/drive.sh" ls "My Drive"
"${HERMES_SKILL_DIR}/scripts/drive.sh" put "My Drive" notes/today.md --from ./notes/today.md
"${HERMES_SKILL_DIR}/scripts/drive.sh" cat "My Drive" notes/today.md
```

Drive token records can be issued with permissions, path prefixes, and TTL metadata, but file APIs do not accept them. Scoped file sharing is not implemented. Do not create a token for handoff or use a received `cresaone_drive` token for file operations, and never share account API keys as a workaround. File operations require account-owner authorization. Prefer `"${HERMES_SKILL_DIR}/scripts/drive.sh"` for authorized owner operations; otherwise use the documented API.

Drive file version history and file restore are not implemented. Keep separate backups before replacing or deleting files. Use `drive.sh` for explicit manual copies and version snapshots:

```bash
"${HERMES_SKILL_DIR}/scripts/drive.sh" put "My Drive" lineage/versions/v1.1/lineage.html --from ./lineage.html
"${HERMES_SKILL_DIR}/scripts/drive.sh" import "My Drive" lineage/versions/v1.1/source --from ./source
```

The helper handles content type, SHA-256, staging, returned upload headers, finalize, ETags, and upload-size verification. Do not hand-roll Drive upload functions unless the helper is unavailable.

Raw Drive upload shape, when helper is unavailable:

```bash
sha=$(shasum -a 256 ./lineage.html | awk '{print $1}')
stage=$(curl -sS -X POST "https://cresa.one/api/v1/drives/{driveId}/files/uploads" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d "{\"path\":\"lineage/lineage.html\",\"size\":12345,\"contentType\":\"text/html; charset=utf-8\",\"sha256\":\"$sha\",\"ifNoneMatch\":\"*\"}")
upload_url=$(echo "$stage" | jq -r '.url')
upload_id=$(echo "$stage" | jq -r '.uploadId')
content_type=$(echo "$stage" | jq -r '.headers["Content-Type"]')
curl -sS -X PUT "$upload_url" -H "Content-Type: $content_type" --data-binary @./lineage.html
curl -sS -X POST "https://cresa.one/api/v1/drives/{driveId}/files/finalize" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d "{\"uploadId\":\"$upload_id\"}"
```

Use `ifNoneMatch:"*"` for create-only writes. Use `ifMatch:"{etag}"` when replacing a known existing file. Always forward upload headers returned by staging; if no headers are returned, send the same content type you staged.

## Verify a publish

Normal local publishes verify automatically. Explicit command:

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" {site-dir} --slug {slug} --verify
```

The helper adds `?cresaverify=...` to bypass the public 60-second edge cache. Hash, size, HTTP, or content-type mismatches fail loudly. Authenticated runs also check requested `viewer.title`, `viewer.description`, `viewer.ogImagePath`, and normalized tags through `GET /api/v1/publish/{slug}`. Drive publishes lack a local tree, so only requested owner metadata is verified.

## Client attribution

Pass `--client` so cresa.one can track reliability by agent:

```bash
"${HERMES_SKILL_DIR}/scripts/publish.sh" {file-or-dir} --client cursor
```

This sends `X-CresaOne-Client: cursor/publish-sh` on publish API calls.
If omitted, the script sends a fallback value.

## API key storage

The publish script reads the API key from these sources (first match wins):

1. `--api-key {key}` flag (CI/scripting only — avoid in interactive use)
2. `$CRESAONE_API_KEY` environment variable
3. `~/.cresaone/credentials` file (recommended for agents)

`ship.sh` also accepts raw, `KEY=value`, or base64-encoded keys from its credential sources. Invalid encodings fail before API access; authentication failures can also mean expired or revoked keys.

To store a key, write it to the credentials file:

```bash
mkdir -p ~/.cresaone && echo "{API_KEY}" > ~/.cresaone/credentials && chmod 600 ~/.cresaone/credentials
```

**IMPORTANT**: After receiving an API key, save it immediately — run the command above yourself. Do not ask the user to run it manually. Avoid passing the key via CLI flags (e.g. `--api-key`) in interactive sessions; the credentials file is the preferred storage method.

Never commit credentials or local state files (`~/.cresaone/credentials`, `.cresaone/state.json`) to source control.

## Getting an API key

To obtain an API key for account-owned publishing:

Signing in does not claim existing anonymous Sites or change their expiry. Claiming is a separate authenticated `POST` to the returned `claimUrl` with `{"claimToken":"..."}` before expiry; the claim URL is an API endpoint, not a browser sign-in link.

1. Ask the user for their email address.
2. Request a one-time sign-in code:

```bash
curl -sS https://cresa.one/api/auth/agent/request-code \
  -H "content-type: application/json" \
  -d '{"email": "user@example.com"}'
```

3. Tell the user: "Check your inbox for a sign-in code from cresa.one and paste it here."
4. Verify the code and get the API key:

```bash
curl -sS https://cresa.one/api/auth/agent/verify-code \
  -H "content-type: application/json" \
  -d '{"email":"user@example.com","code":"ABCD-2345"}'
```

5. Save the returned `apiKey` yourself (do not ask the user to do this):

```bash
mkdir -p ~/.cresaone && echo "{API_KEY}" > ~/.cresaone/credentials && chmod 600 ~/.cresaone/credentials
```

## State file

After every site create/update, the script writes to `.cresaone/state.json` in the working directory:

```json
{
  "publishes": {
    "bright-anchor-v7w4": {
      "siteUrl": "https://bright-anchor-v7w4.cresa.one/",
      "claimToken": "abc123",
      "claimUrl": "https://cresa.one/claim?slug=bright-anchor-v7w4&token=abc123",
      "expiresAt": "2026-02-18T01:00:00.000Z"
    }
  }
}
```

Before creating or updating sites, you may check this file to find prior slugs.
Treat `.cresaone/state.json` as internal cache only.
Never present this local file path as a URL, and never use it as source of truth for auth mode, expiry, or claim URL.

## What to tell the user

For shipped Sites, use `ship_result.*` and `ship-report.json`: URL, access, privacy, profile listing, and returned expiry. `--privacy private` does not restrict access. Report permanence only when `persistence=permanent`.

For published sites:

- Always share the `siteUrl` from the current script run.
- Read and follow `publish_result.*` lines from script stderr to determine auth mode.
- Use `publish_result.expires_at` for the exact returned expiry. `persistence=expires_at` means an expiry was returned; `permanent` means an authenticated Site has no expiry. When `persistence=unknown`, report the missing expiry information instead of inferring a deadline or permanence. Metadata-only updates report these fields from the freshly fetched Site details.
- When `publish_result.auth_mode=authenticated`: tell the user the Site is saved to their account. Report the returned expiry when `persistence=expires_at`; describe it as permanent only when `persistence=permanent`. No claim URL is needed.
- When `publish_result.auth_mode=anonymous`: report the returned Site expiry; 24 hours is the default, not an override of an explicit TTL. Share the claim URL (if `publish_result.claim_url` is non-empty and starts with `https://`) so they can keep it permanently. Warn that claim tokens are only returned once and cannot be recovered.
- Never tell the user to inspect `.cresaone/state.json` for claim URLs or auth status.

For Drives:

- Do not describe Drive files as public URLs.
- Tell the user Drive file operations require account-owner authorization; scoped token file sharing is not implemented.
- Never recommend sharing account API keys as a substitute for limited file-sharing credentials.

## ship.sh options

Run `bash "${HERMES_SKILL_DIR}/scripts/ship.sh" --help`. Main flags: `--slug`, `--title`, `--description`, `--keywords`, `--tags`, `--privacy`, `--access`, `--og-tokens`, `--og-html`, `--og`, `--rename-from`, `--out`, and `--dry-run`. Prefer `CRESAONE_SITE_PASSWORD` over a password argument.

## publish.sh options

| Flag                   | Description                                  |
| ---------------------- | -------------------------------------------- |
| `--slug {slug}`        | Update an existing site instead of creating |
| `--claim-token {token}`| Override claim token for anonymous updates    |
| `--title {text}`       | Viewer title (non-HTML sites)             |
| `--description {text}` | Viewer description                            |
| `--og-image-path {path}` | Viewer/Open Graph image path, e.g. `/og.png` |
| `--metadata-only`      | Patch viewer metadata, TTL, SPA mode, or tags without uploading files |
| `--verify`             | Verify live files and requested metadata (default) |
| `--no-verify`          | Skip post-publish verification |
| `--rename-to {slug}`   | Rename the authenticated Site selected by `--slug` |
| `--check-slug {slug}`  | Print availability JSON; non-zero when unavailable |
| `--suggest-slug`       | Print a fresh available slug (authenticated only) |
| `--ttl {seconds}`      | Set expiry in seconds (anonymous or authenticated)               |
| `--client {name}`      | Agent name for attribution (e.g. `cursor`)    |
| `--tags {json-array}`  | Replace Site tags after publish; requires authentication |
| `--base-url {url}`     | API base URL (default: `https://cresa.one`)    |
| `--allow-noncresaone-base-url` | Allow sending auth to non-default `--base-url` |
| `--api-key {key}`      | API key override (prefer credentials file)    |
| `--spa`                | Enable SPA routing (serve index.html for unknown paths) |

## Authenticated proxy routes

Claimed password or restricted Sites can forward an exact path prefix to a public HTTPS upstream after viewer access succeeds. Store the upstream bearer as an origin-pinned service variable, then create the route:

```bash
curl -sS -X PUT "https://cresa.one/api/v1/me/variables/CLEANLIST_PROXY_ACCESS_TOKEN" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d '{"value":"...","upstreamOrigin":"https://service.example.workers.dev"}'

curl -sS -X POST "https://cresa.one/api/v1/publish/{slug}/proxy-routes" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d '{"pathPrefix":"/api","upstreamOrigin":"https://service.example.workers.dev","authVariableName":"CLEANLIST_PROXY_ACCESS_TOKEN"}'
```

List routes with `GET /api/v1/publish/{slug}/proxy-routes`; delete one with `DELETE /api/v1/publish/{slug}/proxy-routes/{routeId}`. The Site gate runs before upstream access. cresa.one strips viewer credentials, injects only the service-variable Bearer, blocks redirects, and never returns the variable value. The upstream must still reject direct unauthenticated requests.

## Beyond publish.sh

For Drive operations, use `"${HERMES_SKILL_DIR}/scripts/drive.sh"` or the Drive API. For broader account and Site management — Site Data, search, analytics, profiles, delete, metadata, access control, domains, subdomain handles, links, variables, proxy routes, duplication, and more — see the current docs:

→ **https://cresa.one/docs**

Full docs: https://cresa.one/docs
