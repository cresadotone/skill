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
version: 1.19.0
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
- Optional environment variable: `$CRESAONE_API_KEY`
- Optional Drive token variable: `$CRESAONE_DRIVE_TOKEN`
- Optional credentials file: `~/.cresaone/credentials`
- Skill helper paths:
  - `${HERMES_SKILL_DIR}/scripts/publish.sh` for publishing sites
  - `${HERMES_SKILL_DIR}/scripts/drive.sh` for private Drive storage

## Create a site

```bash
PUBLISH="${HERMES_SKILL_DIR}/scripts/publish.sh"
bash "$PUBLISH" {file-or-dir} --client hermes
```

Outputs the live URL (e.g. `https://bright-anchor-v7w4.cresa.one/`).

Under the hood this is a three-step flow: create/update -> upload files -> finalize. A site is not live until finalize succeeds.

Without an API key this creates an **anonymous site** that expires in 24 hours.
With a saved API key, the site is permanent.

**File structure:** For HTML sites, place `index.html` at the root of the directory you publish, not inside a subdirectory. The directory's contents become the site root. For example, publish `my-site/` where `my-site/index.html` exists — don't publish a parent folder that contains `my-site/`.

You can also publish raw files without any HTML. Single files get a rich auto-viewer (images, PDF, video, audio). Multiple files get an auto-generated directory listing with folder navigation and an image gallery.

The helpers set `Content-Type` from file extension and fall back to `file(1)`. Common supported types include HTML/CSS/JS/JSON, Markdown/text/CSV/YAML/TOML, images (`png`, `jpg`, `webp`, `avif`, `heic`, `tiff`, `svg`), video (`mp4`, `mov`, `webm`, `ogv`), audio (`mp3`, `wav`, `flac`, `aiff`, `alac`, `m4a`, `aac`, `ogg`, `oga`, `opus`, `midi`, `caf`, `weba`), fonts (`woff2`, `woff`, `ttf`, `otf`), WebAssembly, web manifests, archives, GLTF/GLB/USDZ/STL models, Parquet, and SQLite.

## Rich static app publishing

For polished apps, calculators, dashboards, or documents:

- Publish a directory with `index.html` at its root.
- Include `og.png` beside `index.html` when share previews matter.
- Use `--og-image-path /og.png` for cresa.one viewer metadata. This is a Site-relative path, not a Drive path.
- Use absolute Open Graph URLs inside HTML, for example `<meta property="og:image" content="https://{slug}.cresa.one/og.png">`.
- Pass `--title` and `--description` for dashboard/UI labels and share-preview copy.
- Pass `--slug` for stable permanent URLs when updating a known Site.
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

Use this one command when files changed. It creates/updates the Site, uploads files with correct content types, finalizes, patches viewer metadata, and replaces tags. Use raw API calls only when the helper does not cover the task.

Open Graph image recipe:

1. Render a 1200x630 PNG such as `og.png`.
2. Put it beside `index.html` in the published directory.
3. Reference it in HTML with an absolute URL after publish.
4. Set cresa.one viewer metadata with `--og-image-path /og.png`.
5. Verify `https://{slug}.cresa.one/og.png` returns an image.

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
bash "$PUBLISH" {file-or-dir} --slug {slug} --client hermes
```

The script auto-loads the `claimToken` from `.cresaone/state.json` when updating anonymous sites. Pass `--claim-token {token}` to override.

Authenticated updates require a saved API key.

Signed-in users also have public profiles. Agents can help users show or hide Sites on their profile and manage profile settings through the API documented at https://cresa.one/docs#profile.

## Site access control

A Site uses one access mode at a time:

- **anyone_with_link** (default): anyone with the URL can view.
- **password**: visitors must enter a shared password.
- **restricted**: invite-only; only verified email addresses or email domains the owner allows can view.

Manage access with `GET`/`PATCH /api/v1/publish/{slug}/access` (passwords via the metadata endpoint). Restricted access requires a claimed Site. The PATCH replaces the full allowlists — read, merge, then write. Before working with access control, read the current docs:

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

After publishing polished apps:

```bash
curl -fsSI "https://{slug}.cresa.one/og.png" | grep -i '^content-type:'
curl -sS "https://cresa.one/api/v1/publish/{slug}" \
  -H "authorization: Bearer $CRESAONE_API_KEY" |
  jq '{viewer,tags,manifest}'
```

Check `.viewer`, `.tags`, and `manifest[]` content types. Expected content types include `text/html; charset=utf-8`, `image/png`, and audio types such as `audio/flac`, `audio/aiff`, `audio/mp4`, `audio/ogg`, and `audio/midi`.

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
