---
name: site-access
description: >-
  Control who can view a cresa.one Site: password protection, restricted
  invite-only access for exact emails or email domains, invite emails, public
  link previews for protected Sites, or opening a Site to anyone with the
  link. Use when asked to "password protect this site", "make this site
  private", "share this only with certain people", "invite someone", "add an
  email to the allowlist", or "make it public again".
---

# Control Site access

{{RUNTIME}}

`API=https://cresa.one/api/v1` and `AUTH="authorization: Bearer $CRESAONE_API_KEY"` in the examples. All calls are owner-only.

## Modes

- `anyone_with_link` (default): anyone with the URL can view.
- `password`: visitors enter one shared password.
- `restricted`: only verified exact emails or email domains on the allowlist can view. Requires a claimed, account-owned Site.

`--privacy private` from publishing only sets noindex, no-referrer, and profile unlisting. It does not gate the page.

## Read first

```bash
curl -sS "$API/publish/{slug}/access" -H "$AUTH"
```

## Change access

Password (keep it out of argv and logs):

```bash
printf '%s' "$CRESAONE_SITE_PASSWORD" | jq -Rs '{password:.}' |
  curl -sS -X PATCH "$API/publish/{slug}/metadata" -H "$AUTH" -H "content-type: application/json" --data-binary @-
```

Restricted: mode-bearing PATCH requests replace both full allowlists. Read, merge, then write the complete lists:

```bash
curl -sS -X PATCH "$API/publish/{slug}/access" -H "$AUTH" -H "content-type: application/json" \
  -d '{"mode":"restricted","allowedEmails":["person@example.com"],"allowedDomains":["example.org"]}'
```

Add `"notify":true` to email newly added exact addresses. Confirm with the user before sending email.

Open to anyone with the link: `-d '{"mode":"anyone_with_link"}'` on the same endpoint.

Invite people already on the allowlist: `POST $API/publish/{slug}/access/invites` with `{"emails":["person@example.com"]}`. Report `sent`, `failed`, and `skipped` (not allowed) from the response. Domain rules do not send invites.

Link previews on a protected Site: `{"publicPreviewEnabled":true}` exposes only the approved title, description, and selected image. Other files stay gated. Caches outside cresa.one may keep previews after you disable it.

For a new protected Site, `ship.sh --access password|restricted` sets access before any content upload (`publish` skill).

## Verify

Read the policy again, then run the `site-health` skill: its `gate` check confirms the public URL matches the policy. Before access work, read https://cresa.one/docs#access-control.
