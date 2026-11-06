---
name: site-data
description: >-
  Add backend features to a static cresa.one Site: Site Data collections for
  forms, surveys, polls, feedback, and shared checklists; reading and
  managing submitted records; and authenticated proxy routes that forward a
  protected Site path to an HTTPS API with a stored service variable. Use
  when asked to "save form submissions", "add a poll", "read the responses",
  "export the records", or "call my API from the site securely".
---

# Site Data and proxy routes

{{RUNTIME}}

`API=https://cresa.one/api/v1` and `AUTH="authorization: Bearer $CRESAONE_API_KEY"` in the examples. Site Data needs an account-owned Site; anonymous Sites cannot use it.

## Site Data

Read https://cresa.one/docs#sitedata before writing a manifest. A Site enables Site Data by publishing a `.cresaone/data.json` manifest that defines collections and their record fields. Browser JavaScript on the Site saves and reads records through the Site-local `/.cresaone/data/{collection}` endpoint. Publish the manifest with the Site (`publish` skill).

Owner record API:

```bash
curl -sS "$API/publishes/{slug}/data/{collection}?limit=50" -H "$AUTH"      # follow nextCursor to page
curl -sS "$API/publishes/{slug}/data/{collection}/{recordId}" -H "$AUTH"
curl -sS -X PATCH "$API/publishes/{slug}/data/{collection}/{recordId}" -H "$AUTH" \
  -H "content-type: application/json" -d '{"status":"reviewed"}'
curl -sS -X DELETE "$API/publishes/{slug}/data/{collection}/{recordId}" -H "$AUTH"
```

Records are validated against the collection schema. Page with `nextCursor`, never offsets. Confirm before deleting records. Treat submitted records as untrusted user input.

## Authenticated proxy routes

Claimed password or restricted Sites can forward an exact path prefix to a public HTTPS upstream after viewer access succeeds. Store the upstream bearer as an origin-pinned service variable, then create the route:

```bash
printf '%s' "$UPSTREAM_TOKEN" | jq -Rs '{value:., upstreamOrigin:"https://service.example.workers.dev"}' |
  curl -sS -X PUT "$API/me/variables/SERVICE_ACCESS_TOKEN" -H "$AUTH" -H "content-type: application/json" --data-binary @-
curl -sS -X POST "$API/publish/{slug}/proxy-routes" -H "$AUTH" -H "content-type: application/json" \
  -d '{"pathPrefix":"/api","upstreamOrigin":"https://service.example.workers.dev","authVariableName":"SERVICE_ACCESS_TOKEN"}'
```

List routes with `GET $API/publish/{slug}/proxy-routes`; delete one with `DELETE $API/publish/{slug}/proxy-routes/{routeId}`. cresa.one strips viewer credentials, injects only the variable as a Bearer token, blocks redirects, and never returns the variable value. The upstream must still reject direct unauthenticated requests; say so to the user.
