---
name: domains
description: >-
  Connect cresa.one Sites to custom domains, the account subdomain handle,
  and path links: add or remove a domain, read DNS instructions and SSL
  status, create or change the handle, and mount Sites at paths. Use when
  asked to "use my own domain", "connect example.com", "set up DNS", "why is
  my domain not working", "change my handle", or "put this site at
  /pricing".
metadata:
  internal: true
---

# Domains, handles, and links

## Runtime

This plugin skill shares one runtime with the core `cresa-one` skill: `../cresa-one/` relative to this skill's directory (Claude Code: `${CLAUDE_SKILL_DIR}/../cresa-one`). Below, `{core}` means that directory's absolute path. Do not copy helpers elsewhere.

- Run helpers with `bash`, for example `bash {core}/scripts/publish.sh --help`. On Windows use Git Bash; from PowerShell: `& "$env:ProgramFiles\Git\bin\bash.exe" {core}/scripts/publish.sh --help`.
- Credentials: `$CRESAONE_API_KEY` or `~/.cresaone/credentials`. For raw API calls, load the key once with `export CRESAONE_API_KEY="${CRESAONE_API_KEY:-$(tr -d '[:space:]' < ~/.cresaone/credentials)}"`. With no key, follow "Getting an API key" in `{core}/SKILL.md`. Never print keys or credential files.
- Rules for version checks, reporting, and anything this page does not cover live in `{core}/SKILL.md`. Current product docs: https://cresa.one/docs. If docs and live API behavior disagree, trust the live API.

`API=https://cresa.one/api/v1` and `AUTH="authorization: Bearer $CRESAONE_API_KEY"` in the examples. Read https://cresa.one/docs and the request schemas in https://cresa.one/openapi.json before changing domains, handles, or links; field names below are a starting point.

## Custom domains

```bash
curl -sS "$API/domains" -H "$AUTH"
curl -sS -X POST "$API/domains" -H "$AUTH" -H "content-type: application/json" -d '{"domain":"www.example.com"}'
curl -sS "$API/domains/www.example.com" -H "$AUTH"
```

The response has `status` (`pending`, `active`, or `error`), `ssl_status`, `is_apex`, and `dns_instructions`. Give the user the exact DNS records from `dns_instructions`; do not invent records. DNS and certificates can take time, so check the status again when the user returns rather than polling in a loop. Remove a domain with `DELETE $API/domains/{domain}` after confirmation.

## Handle and links

- Handle: `GET`, `POST`, `PATCH`, or `DELETE $API/handle` (body fields `handle` or `username`).
- Links mount a Site at a path on the handle or a custom domain: `GET` or `POST $API/links` (body requires `slug`; also `location`, `mount_path`, `domain`, or `namespace_id`), then `GET`, `PATCH`, or `DELETE $API/links/{location}`.

## Verify

After a domain is `active` or a link exists, run the `site-health` skill with the public URL and `--slug {slug}` to confirm HTTP, TLS, and the access gate.
