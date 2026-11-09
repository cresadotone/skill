---
name: site-access
description: >-
  Control who can view a cresa.one Site and what the owner learns about them:
  password protection, restricted invite-only access for exact emails or
  email domains, a lead-capture gate, invite emails, per-recipient tracked
  links, view alerts, engagement tracking and viewer comments, branded gate
  pages, public link previews, or opening a Site to anyone with the link. Use
  when asked to "password protect this site", "make this site private",
  "share this only with certain people", "invite someone", "collect emails
  before they can view", "send each person their own link", "tell me when
  someone opens it", "let viewers comment", "brand the password page", or
  "make it public again".
metadata:
  internal: true
---

# Control Site access

## Runtime

This plugin skill shares one runtime with the core `cresa-one` skill: `../cresa-one/` relative to this skill's directory (Claude Code: `${CLAUDE_SKILL_DIR}/../cresa-one`). Below, `{core}` means that directory's absolute path. Do not copy helpers elsewhere.

- Run helpers with `bash`, for example `bash {core}/scripts/publish.sh --help`. On Windows use Git Bash; from PowerShell: `& "$env:ProgramFiles\Git\bin\bash.exe" {core}/scripts/publish.sh --help`.
- Credentials: `$CRESAONE_API_KEY` or `~/.cresaone/credentials`. For raw API calls, load the key once with `export CRESAONE_API_KEY="${CRESAONE_API_KEY:-$(tr -d '[:space:]' < ~/.cresaone/credentials)}"`. With no key, follow "Getting an API key" in `{core}/SKILL.md`. Never print keys or credential files.
- Rules for version checks, reporting, and anything this page does not cover live in `{core}/SKILL.md`. Current product docs: https://cresa.one/docs. If docs and live API behavior disagree, trust the live API.

`API=https://cresa.one/api/v1` and `AUTH="authorization: Bearer $CRESAONE_API_KEY"` in the examples. All calls are owner-only.

## Modes

- `anyone_with_link` (default): anyone with the URL can view.
- `password`: visitors enter one shared password.
- `restricted`: only verified exact emails or email domains on the allowlist can view.
- `lead`: anyone can view after submitting their email, an optional name, and up to 5 custom fields.

Restricted and lead modes require a claimed, account-owned Site. `--privacy private` from publishing only sets noindex, no-referrer, and profile unlisting. It does not gate the page.

## Read first

```bash
curl -sS "$API/publish/{slug}/access" -H "$AUTH"
```

The response shows `mode`, both allowlists, `leadFields`, `leadCollectName`, `requireVerification`, `notifyOnView`, `trackEngagement`, `allowComments`, and `publicPreviewEnabled`.

## Change access

Password (keep it out of argv and logs):

```bash
printf '%s' "$CRESAONE_SITE_PASSWORD" | jq -Rs '{password:.}' |
  curl -sS -X PATCH "$API/publish/{slug}/metadata" -H "$AUTH" -H "content-type: application/json" --data-binary @-
```

A mode-bearing PATCH replaces that mode's settings. Restricted replaces both full allowlists, so read, merge, then write the complete lists:

```bash
curl -sS -X PATCH "$API/publish/{slug}/access" -H "$AUTH" -H "content-type: application/json" \
  -d '{"mode":"restricted","allowedEmails":["person@example.com"],"allowedDomains":["example.org"]}'
```

Add `"notify":true` to email newly added exact addresses. Confirm with the user before sending email.

Lead capture (ask first; it gates the page behind a form):

```bash
curl -sS -X PATCH "$API/publish/{slug}/access" -H "$AUTH" -H "content-type: application/json" \
  -d '{"mode":"lead","leadFields":[{"key":"company","label":"Company","type":"text","required":true}],"requireVerification":true}'
```

Field `type` is `text`, `email`, `tel`, or `url`; `key` is lowercase snake_case and cannot be `email` or `name`. `requireVerification` (default true) makes viewers confirm their email with a 6-digit code; with `false` they enter straight after the form and the lead is stored unverified. Read submissions with `GET $API/publishes/{slug}/data/leads`.

Open to anyone with the link: `-d '{"mode":"anyone_with_link"}'` on the same endpoint.

Invite people already on the allowlist: `POST $API/publish/{slug}/access/invites` with `{"emails":["person@example.com"]}`. Report `sent`, `failed`, and `skipped` (not allowed) from the response. Domain rules do not send invites.

For a new protected Site, `ship.sh --access password|restricted` sets access before any content upload (`publish` skill). Republishing with `ship.sh` keeps an existing lead gate.

## Toggles that keep the mode

Send only the toggle; mode, password, allowlists, and viewer sessions stay as they are.

- `{"notifyOnView":true}`: email the account owner the first time each identified viewer opens the Site, then at most once per viewer per 24 hours.
- `{"trackEngagement":true}` and `{"allowComments":true}`: opt-in, off by default. Ask first: while either is on, every served HTML page gets one same-origin script, `/__cresa/feedback.js`. Engagement records visible time and furthest scroll per view. Only identified viewers can comment: people who passed the lead-capture or email-verification gate, opened a valid recipient link, or are signed in to cresa.one. Work through comments with the `manage-sites` skill.
- `{"publicPreviewEnabled":true}`: on a protected Site, exposes only the approved title, description, and selected image. Other files stay gated. Caches outside cresa.one may keep previews after you disable it.

Identified viewers are restricted and lead viewers plus recipient-link viewers; password and public Sites identify viewers only through recipient links. List them with the `site-health` skill.

## Recipient links

One tracked, revocable link per person:

```bash
curl -sS -X POST "$API/publish/{slug}/recipients" -H "$AUTH" -H "content-type: application/json" \
  -d '{"recipients":[{"email":"ann@example.com","name":"Ann Lee"}]}'
```

- Each `recipients[].url` is shown once; only a hash is stored. Give each link only to its recipient. Replace a lost link by revoking it and creating another.
- A link skips every gate (password, restricted, and lead capture with its email check), so treat it like a password. Views through it are attributed to that email, marked unverified, in analytics, viewers, view alerts, and `site.viewed` webhooks. On a Site with comments on, the recipient can comment.
- 1 to 50 per call, at most 500 active per Site. List with `GET $API/publish/{slug}/recipients?status=active` (no URLs). Revoke with `DELETE $API/publish/{slug}/recipients/{recipientId}`: the link and its cookie stop working at once, and so does commenting through it. Recorded views stay.
- On a custom domain, swap the link's `https://{slug}.cresa.one` origin for the domain.

## Brand the gate

`PATCH $API/branding` sets account-wide gate branding for every password, restricted, lead-capture, and code page:

```bash
curl -sS -X PATCH "$API/branding" -H "$AUTH" -H "content-type: application/json" \
  -d '{"headline":"Northwind Capital","message":"Shared with invited partners only.","backgroundColor":"#1e1b4b","accentColor":"#facc15"}'
printf '{"logo":"%s"}' "$(base64 < ./logo.png | tr -d '\n')" |
  curl -sS -X PATCH "$API/branding" -H "$AUTH" -H "content-type: application/json" --data-binary @-
```

- Headline up to 80 characters, message up to 500, colors `#rgb` or `#rrggbb`. Logos are base64 PNG, JPEG, or WebP (a data: URL also works), at most 512 KB and 16 to 2048 pixels per side; SVG and GIF are rejected. Omitted fields stay; `null` clears one.
- `PATCH $API/publish/{slug}/branding` overrides one Site (`null` inherits the account value); `DELETE` on it removes the override.
- Check a draft first: `POST $API/branding/preview` with `{"mode":"lead","slug":"{slug}","branding":{"accentColor":"#0f766e"}}` returns the gate `html` and saves nothing.

## Verify

Read the policy again, then run the `site-health` skill: its `gate` check confirms the public URL matches the policy. Before access work, read https://cresa.one/docs#lead-capture.
