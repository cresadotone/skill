---
name: manage-sites
description: >-
  Manage existing cresa.one Sites: find, list, or search owned Sites; update
  files, title, description, share image, or tags; rename slugs; archive,
  disable, or restore; change expiry; claim anonymous Sites; recover stuck
  uploads; list on the public profile; delete. Use when asked to "update my
  site", "change the title", "rename this site", "archive it", "take it
  down", "find my site", or "which sites do I have".
metadata:
  internal: true
---

# Manage existing Sites

## Runtime

This plugin skill shares one runtime with the core `cresa-one` skill: `../cresa-one/` relative to this skill's directory (Claude Code: `${CLAUDE_SKILL_DIR}/../cresa-one`). Below, `{core}` means that directory's absolute path. Do not copy helpers elsewhere.

- Run helpers with `bash`, for example `bash {core}/scripts/publish.sh --help`. On Windows use Git Bash; from PowerShell: `& "$env:ProgramFiles\Git\bin\bash.exe" {core}/scripts/publish.sh --help`.
- Credentials: `$CRESAONE_API_KEY` or `~/.cresaone/credentials`. For raw API calls, load the key once with `export CRESAONE_API_KEY="${CRESAONE_API_KEY:-$(tr -d '[:space:]' < ~/.cresaone/credentials)}"`. With no key, follow "Getting an API key" in `{core}/SKILL.md`. Never print keys or credential files.
- Rules for version checks, reporting, and anything this page does not cover live in `{core}/SKILL.md`. Current product docs: https://cresa.one/docs. If docs and live API behavior disagree, trust the live API.

All operations below are owner-only and need an account key. `API=https://cresa.one/api/v1` and `AUTH="authorization: Bearer $CRESAONE_API_KEY"` in the examples.

## Find a Site

```bash
curl -sS "$API/publishes" -H "$AUTH"                               # owned Sites; follow nextCursor when present
curl -sS "$API/publishes/search?q=rent&limit=20" -H "$AUTH"        # slug, URL, metadata, file paths, text
curl -sS "$API/publish/{slug}" -H "$AUTH" | jq '{slug,status,expiresAt,viewer,tags,manifest}'
```

Viewer metadata lives under `.viewer`, not top-level keys.

## Change content or metadata

- Files changed: republish to the same slug. HTML Sites: `bash {core}/scripts/ship.sh ./site --slug {slug} ...` (see the `publish` skill). Other files: `bash {core}/scripts/publish.sh ./dist --slug {slug}`.
- Only title, description, share image, or tags changed (no new version):

```bash
bash {core}/scripts/publish.sh --metadata-only --slug {slug} \
  --title "New title" --description "New description" --og-image-path /og.png
bash {core}/scripts/publish.sh --metadata-only --slug {slug} --tags '["cre","calculator"]'
```

Tags fully replace the old list. `--ttl {seconds}` changes expiry; `--spa` enables index.html fallback routing.

## Rename, status, claim, delete

- Rename: `bash {core}/scripts/publish.sh --slug {old} --rename-to {new}`. The old URL returns 404 at once and can be claimed by someone else; say so first. If the HTML embeds its own URL, use `ship.sh --rename-from {old}` instead.
- Status: `curl -sS -X POST "$API/publish/{slug}/status" -H "$AUTH" -H "content-type: application/json" -d '{"status":"archived"}'`. Values: `published`, `pending`, `archived`, `disabled`.
- Claim an anonymous Site before it expires: POST `{"claimToken":"..."}` with the account key to the `claimUrl` the create step returned.
- Delete: `curl -sS -X DELETE "$API/publish/{slug}" -H "$AUTH"`. This cannot be undone. Get explicit confirmation naming the slug first.

## Stuck uploads

When a version stays pending, read `GET $API/publish/{slug}` (`pendingVersionId`). Resume with `POST $API/publish/{slug}/uploads/refresh?versionId={id}`, upload the remaining files, then finalize. With owner approval, discard it with `POST $API/publish/{slug}/uploads/cancel` and `{"versionId":"{id}"}`; that never touches the live version.

## Public profile

Show a Site: `POST $API/profile/sites` with `{"slug":"{slug}"}`. Hide it: `DELETE $API/profile/sites/{slug}`. Protected Sites cannot be listed. Profile settings: https://cresa.one/docs#profile.

Verify every change by reading the Site again, then report what changed. Use the `site-health` skill for a full check.
