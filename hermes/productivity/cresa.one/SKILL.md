---
name: cresa.one
description: >
  cresa.one lets agents publish websites and store private files in cloud
  Drives. Use Sites to publish HTML, documents, images, PDFs, videos, and
  static files to live URLs at {slug}.cresa.one or custom domains. Use Drives as private cloud
  folders where agents can store files (documents, context, memory, plans,
  assets, media, research, code, etc), share them with other agents, and
  continue across sessions and tools. Use when asked to "publish this", "host
  this", "deploy this", "share this on the web", "make a website", "put this
  online", "create a webpage", "generate a URL", "build a chatbot", "save this
  to my Drive", "store this for later", "write this to cloud storage", "share a
  folder with another agent", or "use my cresa.one Drive". Also use when asked
  to "password protect this site", "make this site private", or "share this
  site with only certain people".
version: 1.24.0
author: cresa.one
license: MIT
prerequisites:
  commands: [curl, file, jq]
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
- Drives and Drive sharing
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

- Required binaries: `curl`, `file`, `jq`
- Optional OG generator runtime: `uv` or Python 3.10+ with Pillow
- Optional environment variable: `$CRESAONE_API_KEY`
- Optional Drive token variable: `$CRESAONE_DRIVE_TOKEN`
- Optional credentials file: `~/.cresaone/credentials`
- Skill helper paths:
  - `${HERMES_SKILL_DIR}/scripts/publish.sh` for publishing sites
  - `${HERMES_SKILL_DIR}/scripts/drive.sh` for private Drive storage
  - `${HERMES_SKILL_DIR}/scripts/og-image.py` for Open Graph image candidates
  - `${HERMES_SKILL_DIR}/templates/` for the house design system + scaffolding templates (see below)

## Create a site

```bash
PUBLISH="${HERMES_SKILL_DIR}/scripts/publish.sh"
bash "$PUBLISH" {file-or-dir} --client hermes
```

Outputs the live URL (e.g. `https://bright-anchor-v7w4.cresa.one/`).

To create a new Site at a chosen slug in one step (authenticated only):

```bash
./scripts/publish.sh {file-or-dir} --create --slug {desired-slug}
```

`--create` forces `POST /api/v1/publish` instead of an update, and the requested slug is claimed atomically at creation. The server validates DNS-label rules (3–63 chars, lowercase alphanumeric and hyphens, no leading/trailing or consecutive hyphens, not reserved) and returns 409 when taken, 422 when invalid — no typo Site is created. Use plain `--slug` (without `--create`) only to update an existing Site; use `--check-slug` first when unsure whether the name is free.

Under the hood this is a three-step flow: create/update -> upload files -> finalize. A site is not live until finalize succeeds.

Without an API key this creates an **anonymous site** that expires in 24 hours.
With a saved API key, the site is permanent.

**File structure:** For HTML sites, place `index.html` at the root of the directory you publish, not inside a subdirectory. The directory's contents become the site root. For example, publish `my-site/` where `my-site/index.html` exists — don't publish a parent folder that contains `my-site/`.

You can also publish raw files without any HTML. Single files get a rich auto-viewer (images, PDF, video, audio). Multiple files get an auto-generated directory listing with folder navigation and an image gallery.

The helpers set `Content-Type` from file extension and fall back to `file(1)`. Common supported types include HTML/CSS/JS/JSON, Markdown/text/CSV/YAML/TOML, images (`png`, `jpg`, `webp`, `avif`, `heic`, `tiff`, `svg`), video (`mp4`, `mov`, `webm`, `ogv`), audio (`mp3`, `wav`, `flac`, `aiff`, `alac`, `m4a`, `aac`, `ogg`, `oga`, `opus`, `midi`, `caf`, `weba`), fonts (`woff2`, `woff`, `ttf`, `otf`), WebAssembly, web manifests, archives, GLTF/GLB/USDZ/STL models, Parquet, and SQLite.

## Scaffold on-brand apps and pages

The skill bundles the house design system and two production-ready single-file templates under `${HERMES_SKILL_DIR}/templates/`. Use them whenever building a new app, dashboard, tool, or decision page so output matches the house style instead of an invented one.

- `templates/DESIGN.md` — the **SF Ownership Desk** design system: absolute-black background, near-black surfaces, graphite hairlines, signal-white accent, three-level neutral text, Geist Sans / Geist Mono / Geist Pixel Square typography, component anatomy, layout, and responsive rules. Read it before designing any new surface.
- `templates/app-template.html` — self-contained app skeleton (fonts embedded): mono default + 10 switchable themes, ⌘K command bar with live theme preview, sortable table + grouped board view, KPI tiles, filter chips, record drawer, confirm modal, toasts, full keyboard layer, CSV export, localStorage state.
- `templates/plan-template.html` — interactive plan/decision page (approve / reject / edit cards, Submit-to-listener with JSON download fallback).
- `templates/PLAN-DESIGN.md` — the plan-page contract (`PLAN_ITEMS` shape, theme, interactivity, listener payload).
- `templates/plans.config.example.json` — example per-project accent + sequence config for plan pages.
- `templates/README.md` — step-by-step scaffolding instructions and placeholder reference.

App scaffold in short: copy `app-template.html` to `{site-dir}/index.html`, fill the `__APP_*__` placeholders, replace the `DATA` array (row shape documented inline), adjust `COLS`, then generate a matching `og.png` and publish. Do not hand-roll new shells or palettes when these templates apply.

## Rich static app publishing

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
PUBLISH="${HERMES_SKILL_DIR}/scripts/publish.sh"
bash "$PUBLISH" {site-dir} \
  --slug {slug} \
  --title "Market Rent Calculator" \
  --description "Interactive CRE calculator for market rent scenarios." \
  --og-image-path /og.png \
  --tags '["calculator","cre"]' \
  --client hermes
```

Use this command when files changed. It uploads and finalizes, saves recovery state, patches tags, then verifies live bytes, sizes, content types, and requested owner metadata. Mismatches exit non-zero with per-file details.

## Generate an OG image

Cards follow the same SF Ownership Desk design system as `templates/` output — absolute-black canvas, graphite hairlines, signal-white accents, square markers, mono metadata — so share previews match the apps they represent.

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

This emits three 1200x630 candidates plus 360x189 `_thumb.png` files. `--photo` is optional and must be the correct user-provided identity image; never substitute stock or wrong-person imagery. Inspect thumbnails at actual size, copy the winner to `{site-dir}/og.png`, then publish with `--og-image-path /og.png --verify`.

Defaults enforce 18px label, 20px signal, and 18px footer floors. `--scale` can increase them but rejects values below `1.0`. Output is PNG only. Without `uv`, create a Python 3.10+ virtual environment, install Pillow, then run the script with Python.

For a reusable design pattern, see `examples/terminal-instrument/` in the public skill repo. It includes a shared app shell, config-driven runtime, generator, and optional Playwright-based OG image generator. Treat it as an example for creating consistent app families, not as required publishing infrastructure.

## Update Site metadata without uploading files

Use Site metadata for the dashboard/UI title, description, and share-preview image. Do not rewrite or re-upload HTML just to update these fields. HTML `<title>` and `<meta>` tags are still useful inside the page, but cresa.one Site viewer metadata is managed by API.

Decision rule:

- Files changed: use normal `publish.sh {site-dir} --slug ... --title ... --og-image-path ... --tags ...`.
- Only metadata/tags changed: use `publish.sh --metadata-only --slug ...`.

```bash
PUBLISH="${HERMES_SKILL_DIR}/scripts/publish.sh"
bash "$PUBLISH" --metadata-only --slug {slug} \
  --title "Market Rent Calculator" \
  --description "Interactive CRE calculator for market rent scenarios." \
  --og-image-path /og.png \
  --client hermes
```

This calls `PATCH /api/v1/publish/{slug}/metadata`, preserves existing viewer fields, and updates the account-owned Site without creating a new Site version. Metadata-only updates require authentication because the endpoint is owner-only.

The metadata PATCH response confirms status, not the full updated viewer object:

```json
{"success":true,"passwordProtected":true,"spaMode":false}
```

`passwordProtected:true` means the Site is currently password protected; it does not mean this metadata patch changed the password.

To update tags at the same time:

```bash
bash "$PUBLISH" --metadata-only --slug {slug} --tags '["calculator","cre"]' --client hermes
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

Manifest `contentType` reports what was stored during upload. If it is wrong, republish with the current helper so upload PUT requests send the correct `Content-Type`.

## Update an existing site

```bash
PUBLISH="${HERMES_SKILL_DIR}/scripts/publish.sh"
bash "$PUBLISH" {file-or-dir} --slug {slug} --verify --client hermes
```

Verification is on by default; `--verify` makes intent explicit. It hash-compares live cache-busted responses and content types. Above 50 files it checks the first 50 plus every HTML file and selected OG image. Use `--no-verify` only for deliberate large publishes or protected Sites, whose public host returns an access gate instead of source bytes.

State is saved before verification, and `.cresaone/` is excluded from uploads. Pass `--claim-token {token}` to override auto-loaded anonymous state.

Authenticated updates require a saved API key.

Signed-in users also have public profiles. Agents can help users show or hide Sites on their profile and manage profile settings through the API documented at https://cresa.one/docs#profile.

## Rename, check, or suggest slugs

Owner-only helpers:

```bash
bash "$PUBLISH" --slug {old-slug} --rename-to {new-slug} --client hermes
bash "$PUBLISH" --check-slug {preferred-slug} --client hermes
bash "$PUBLISH" --suggest-slug --client hermes
```

Rename moves matching local state and warns that the old host immediately 404s, breaking shared links and cached previews while freeing the old slug. `--check-slug` prints JSON and exits non-zero when unavailable. `--suggest-slug` prints an available friendly slug. Both slug helpers require authentication; anonymous create still receives a generated slug. Once a name checks out, claim it directly with `--create --slug {name}` — no rename step needed.

## Change Site status

```bash
curl -sS -X POST "https://cresa.one/api/v1/publish/{slug}/status" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d '{"status":"archived"}'
```

Supported statuses: `published`, `pending`, `archived`, `disabled`. Response: `{"slug":"{slug}","status":"archived"}`.

## Site access control

A Site uses one access mode at a time:

- **anyone_with_link** (default): anyone with the URL can view.
- **password**: visitors must enter a shared password.
- **restricted**: invite-only; only verified email addresses or email domains the owner allows can view.

Read policy, merge changes, then send complete allowlists:

```bash
curl -sS "https://cresa.one/api/v1/publish/{slug}/access" \
  -H "authorization: Bearer $CRESAONE_API_KEY"

curl -sS -X PATCH "https://cresa.one/api/v1/publish/{slug}/access" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d '{"mode":"restricted","allowedEmails":["person@example.com"],"allowedDomains":["example.org"]}'
```

Mode-bearing PATCH replaces full allowlists. Restricted access requires a claimed Site. Passwords use the metadata endpoint.

Protected previews default off. Toggle them without changing mode, password, allowlists, or sessions:

```bash
curl -sS -X PATCH "https://cresa.one/api/v1/publish/{slug}/access" \
  -H "authorization: Bearer $CRESAONE_API_KEY" \
  -H "content-type: application/json" \
  -d '{"publicPreviewEnabled":true}'
```

Enabled previews expose only approved title, optional description, and exact selected safe raster image. Other files remain gated; external services may retain cached previews after disabling.

Before access-control work, read current docs:

→ **https://cresa.one/docs#access-control**

## Use a Drive

Use a Drive when the user wants private cloud storage for agent files: documents, context, memory, plans, assets, media, research, code, and anything else that should persist without being published as a website.

Every signed-in account has a default Drive named `My Drive`.

```bash
DRIVE="${HERMES_SKILL_DIR}/scripts/drive.sh"
bash "$DRIVE" default
bash "$DRIVE" ls "My Drive"
bash "$DRIVE" put "My Drive" notes/today.md --from ./notes/today.md
bash "$DRIVE" cat "My Drive" notes/today.md
bash "$DRIVE" share "My Drive" --perms write --prefix notes/ --ttl 7d
```

Use scoped Drive tokens for agent-to-agent handoff. If you receive a `cresaone_drive` share block, use its `token` as `Authorization: Bearer <token>` against `api_base`, respect `pathPrefix` when present, and preserve ETags on writes. A `pathPrefix` of `null` means full-Drive access. If the skill is available, prefer `drive.sh`; otherwise call the listed API operations directly.

Prefer `drive.sh` for backups and version snapshots:

```bash
DRIVE="${HERMES_SKILL_DIR}/scripts/drive.sh"
bash "$DRIVE" put "My Drive" lineage/versions/v1.1/lineage.html --from ./lineage.html
bash "$DRIVE" import "My Drive" lineage/versions/v1.1/source --from ./source
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

Local publishes verify automatically. Explicit command:

```bash
bash "$PUBLISH" {site-dir} --slug {slug} --verify --client hermes
```

The helper adds `?cresaverify=...` to bypass the public edge cache. Hash, size, HTTP, or content-type mismatches fail loudly. Authenticated runs also check requested viewer fields and normalized tags. Drive publishes verify requested owner metadata only.

## API key storage

The publish script reads the API key from these sources (first match wins):

1. `--api-key {key}` flag (CI/scripting only — avoid in interactive use)
2. `$CRESAONE_API_KEY` environment variable
3. `~/.cresaone/credentials` file (recommended for agents)

To store a key, write it to the credentials file:

```bash
mkdir -p ~/.cresaone && echo "{API_KEY}" > ~/.cresaone/credentials && chmod 600 ~/.cresaone/credentials
```

**IMPORTANT**: After receiving an API key, save it immediately — run the command above yourself. Do not ask the user to run it manually. Avoid passing the key via CLI flags (e.g. `--api-key`) in interactive sessions; the credentials file is the preferred storage method.

Never commit credentials or local state files (`~/.cresaone/credentials`, `.cresaone/state.json`) to source control.

## Getting an API key

To upgrade from anonymous (24h) to permanent sites:

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

For published sites:

- Always share the `siteUrl` from the current script run.
- Read and follow `publish_result.*` lines from script stderr to determine auth mode.
- When `publish_result.auth_mode=authenticated`: tell the user the site is **permanent** and saved to their account. No claim URL is needed.
- When `publish_result.auth_mode=anonymous`: tell the user the site **expires in 24 hours**. Share the claim URL (if `publish_result.claim_url` is non-empty and starts with `https://`) so they can keep it permanently. Warn that claim tokens are only returned once and cannot be recovered.
- Never tell the user to inspect `.cresaone/state.json` for claim URLs or auth status.

For Drives:

- Do not describe Drive files as public URLs.
- Tell the user Drive contents are private unless shared with a scoped token.
- When sharing access with another agent, prefer a scoped token with a narrow `pathPrefix` and short TTL.

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
| `--ttl {seconds}`      | Set expiry (authenticated only)               |
| `--client {name}`      | Agent name for attribution (e.g. `hermes`)    |
| `--tags {json-array}`  | Replace Site tags after publish; requires authentication |
| `--base-url {url}`     | API base URL (default: `https://cresa.one`)    |
| `--allow-noncresaone-base-url` | Allow sending auth to non-default `--base-url` |
| `--api-key {key}`      | API key override (prefer credentials file)    |
| `--spa`                | Enable SPA routing (serve index.html for unknown paths) |

## Beyond publish.sh

For Drive operations, use `drive.sh` or the Drive API. For broader account and Site management — Site Data, search, analytics, profiles, delete, metadata, access control, domains, subdomain handles, links, variables, proxy routes, duplication, and more — see the current docs:

→ **https://cresa.one/docs**

Full docs: https://cresa.one/docs
