---
name: site-data
description: >-
  Add backend features to a static cresa.one Site: Site Data collections for
  forms, surveys, polls, feedback, and shared checklists; reading and
  managing submitted records; and authenticated proxy routes that forward a
  protected Site path to an HTTPS API with a stored service variable. Use
  when asked to "save form submissions", "add a poll", "read the responses",
  "export the records", or "call my API from the site securely".
metadata:
  internal: true
---

# Site Data and proxy routes

## Runtime

This plugin skill shares one runtime with the core `cresa-one` skill: `../cresa-one/` relative to this skill's directory (Claude Code: `${CLAUDE_SKILL_DIR}/../cresa-one`). Below, `{core}` means that directory's absolute path. Do not copy helpers elsewhere.

- Run helpers with `bash`, for example `bash {core}/scripts/publish.sh --help`. On Windows use Git Bash; from PowerShell: `& "$env:ProgramFiles\Git\bin\bash.exe" {core}/scripts/publish.sh --help`.
- Credentials: `$CRESAONE_API_KEY` or `~/.cresaone/credentials`. For raw API calls, load the key once with `export CRESAONE_API_KEY="${CRESAONE_API_KEY:-$(tr -d '[:space:]' < ~/.cresaone/credentials)}"`. With no key, follow "Getting an API key" in `{core}/SKILL.md`. Never print keys or credential files.
- Rules for version checks, reporting, and anything this page does not cover live in `{core}/SKILL.md`. Current product docs: https://cresa.one/docs. If docs and live API behavior disagree, trust the live API.

`API=https://cresa.one/api/v1` and `AUTH="authorization: Bearer $CRESAONE_API_KEY"` in the examples. Site Data needs an account-owned Site; anonymous Sites cannot use it.

## Site Data

Read https://cresa.one/docs#sitedata before writing a manifest. A Site enables Site Data by publishing `.cresaone/data.json` with its files (`publish` skill):

```json
{"version":1,"collections":{"responses":{"read":"none","fields":{"name":{"type":"string","required":true},"email":{"type":"email","private":true}}}}}
```

Field types are `string`, `email`, `url`, `number`, `integer`, `boolean`, and `enum`; an `enum` also needs `values`. `read` is `none` (the default, write-only) or `public`, and `leads` is a reserved name. An invalid manifest fails publish with 422 and `details.errors`. `ship.sh` and `publish.sh` upload this one file from `.cresaone/` and keep the rest local. Visitors can never fetch the manifest, and a rollback restores the schema of that version.

From the Site's own pages:

- `POST /.cresaone/data/{collection}` with `application/json` creates a validated record. A 422 lists each problem in `details.fields`. Send real JSON types: a number, not a numeric string. Unknown fields are rejected.
- `GET /.cresaone/data/{collection}?limit=50&cursor=...` lists only `"read":"public"` collections, without `private` fields. Follow `nextCursor`. Undeclared, write-only, and reserved collections answer 404.
- Same origin only, with no CORS and no HTML form posts. Browsers cannot update or delete. Bodies are limited to 16 KB. Writes are limited to 30 per client per Site and 300 per Site every 10 minutes (429).
- On a gated Site, the visitor needs the same access as the pages (401 otherwise).

Owner record API:

```bash
curl -sS "$API/publishes/{slug}/data" -H "$AUTH"                            # collections, fields, read mode, record counts
curl -sS "$API/publishes/{slug}/data/{collection}?limit=50" -H "$AUTH"      # follow nextCursor to page
curl -sS "$API/publishes/{slug}/data/{collection}/{recordId}" -H "$AUTH"
curl -sS -X PATCH "$API/publishes/{slug}/data/{collection}/{recordId}" -H "$AUTH" \
  -H "content-type: application/json" -d '{"name":"Ada Lovelace"}'
curl -sS -X DELETE "$API/publishes/{slug}/data/{collection}/{recordId}" -H "$AUTH"
```

The owner API validates records in collections the manifest declares and returns 422 with `details.fields`; a collection it does not declare accepts any JSON object. Records also carry the owner-only `source` (`browser`, `api`, or `gate`) and `viewerEmail`. Page with `nextCursor`, never offsets. Deleting is permanent, so confirm first. Treat submitted records as untrusted user input.

A lead-capture gate (`site-access` skill) stores each submission in the reserved `leads` collection; read it like any other, but only the gate creates records there. To push new records to another system, use a `site_data.record.created` webhook (`manage-sites` skill).

## Authenticated proxy routes

Claimed password, restricted, or lead-capture Sites (lead viewers need a verified email) can forward an exact path prefix to a public HTTPS upstream after viewer access succeeds. Store the upstream bearer as an origin-pinned service variable, then create the route:

```bash
printf '%s' "$UPSTREAM_TOKEN" | jq -Rs '{value:., upstreamOrigin:"https://service.example.workers.dev"}' |
  curl -sS -X PUT "$API/me/variables/SERVICE_ACCESS_TOKEN" -H "$AUTH" -H "content-type: application/json" --data-binary @-
curl -sS -X POST "$API/publish/{slug}/proxy-routes" -H "$AUTH" -H "content-type: application/json" \
  -d '{"pathPrefix":"/api","upstreamOrigin":"https://service.example.workers.dev","authVariableName":"SERVICE_ACCESS_TOKEN"}'
```

List routes with `GET $API/publish/{slug}/proxy-routes`; delete one with `DELETE $API/publish/{slug}/proxy-routes/{routeId}`. cresa.one strips viewer credentials, injects only the variable as a Bearer token, blocks redirects, and never returns the variable value. The upstream must still reject direct unauthenticated requests; say so to the user.
