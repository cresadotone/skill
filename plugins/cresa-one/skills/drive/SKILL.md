---
name: drive
description: >-
  Store, read, list, import, export, and delete private files in cresa.one
  Drives, the account-owned cloud folders for documents, context, memory,
  plans, assets, media, research, and code that persist across sessions and
  tools, and share one Drive or folder with another agent through a scoped,
  revocable Drive token. Use when asked to "save this to my Drive", "store
  this for later", "write this to cloud storage", "load my notes from Drive",
  "share a folder with another agent", or "use my cresa.one Drive".
metadata:
  internal: true
---

# Use a Drive

## Runtime

This plugin skill shares one runtime with the core `cresa-one` skill: `../cresa-one/` relative to this skill's directory (Claude Code: `${CLAUDE_SKILL_DIR}/../cresa-one`). Below, `{core}` means that directory's absolute path. Do not copy helpers elsewhere.

- Run helpers with `bash`, for example `bash {core}/scripts/publish.sh --help`. On Windows use Git Bash; from PowerShell: `& "$env:ProgramFiles\Git\bin\bash.exe" {core}/scripts/publish.sh --help`.
- Credentials: `$CRESAONE_API_KEY` or `~/.cresaone/credentials`. For raw API calls, load the key once with `export CRESAONE_API_KEY="${CRESAONE_API_KEY:-$(tr -d '[:space:]' < ~/.cresaone/credentials)}"`. With no key, follow "Getting an API key" in `{core}/SKILL.md`. Never print keys or credential files.
- Rules for version checks, reporting, and anything this page does not cover live in `{core}/SKILL.md`. Current product docs: https://cresa.one/docs. If docs and live API behavior disagree, trust the live API.

Every signed-in account has a default Drive named `My Drive`. Drive files are private; never describe them as public URLs.

## Common operations

```bash
bash {core}/scripts/drive.sh default                                  # default Drive details
bash {core}/scripts/drive.sh ls                                       # all Drives
bash {core}/scripts/drive.sh ls "My Drive" notes/                     # files under a prefix
bash {core}/scripts/drive.sh cat "My Drive" notes/today.md            # print one file
bash {core}/scripts/drive.sh put "My Drive" notes/today.md --from ./today.md
bash {core}/scripts/drive.sh import "My Drive" project/ --from ./project --dry-run
bash {core}/scripts/drive.sh export "My Drive" project/ --to ./restore --dry-run
bash {core}/scripts/drive.sh create "Research"
```

Run `import` and `export` with `--dry-run` first and show the plan. The helper handles content types, SHA-256, staging, upload headers, finalize, ETags, and size verification. Do not hand-roll uploads while it is available.

## Deleting and replacing

Drive files have no version history or restore. Before replacing or deleting, copy the current file to a dated path, for example `backups/2026-11-06/notes/today.md`.

- One file: `drive.sh rm "My Drive" notes/old.md`
- A folder: `drive.sh rm "My Drive" notes/ --recursive --confirm notes/`
- A whole Drive: `drive.sh delete "Research" --confirm "Research"`

Get explicit confirmation naming the path or Drive before any delete.

## Share a Drive or folder with another agent

Issue a scoped Drive token with the owner key. Never share the account API key instead.

```bash
bash {core}/scripts/drive.sh share "My Drive" --perms read --prefix notes/ --ttl 7d --label "research agent"
bash {core}/scripts/drive.sh tokens "My Drive"
bash {core}/scripts/drive.sh revoke "My Drive" {tokenId}        # immediate
```

- A `cdt_` token covers one Drive, `read` or `write` scope (write includes read), a literal path prefix, and an optional expiry. `notes/` confines it to that folder; `notes` without the slash also matches `notes-archive/`. Omit `--prefix` for the whole Drive.
- `share` prints a `cresaone_drive` hand-off block with `driveId`, `api_base`, `token`, `perms`, `pathPrefix`, and `expiresAt`. The token is shown once. Tell the user what it grants and send it only to the intended recipient.
- Tokens allow Drive details and file operations inside their prefix. They cannot list Drives or manage Drives or tokens.

## Use a Drive someone shared with you

Take the `driveId` and `token` from the `cresaone_drive` block, then reference the Drive by ID:

```bash
export CRESAONE_DRIVE_TOKEN="cdt_…"          # or: drive.sh --token cdt_… <command>
bash {core}/scripts/drive.sh ls {driveId} notes/
bash {core}/scripts/drive.sh cat {driveId} notes/today.md
bash {core}/scripts/drive.sh put {driveId} notes/summary.md --from ./summary.md    # write tokens only
```

A path outside the prefix returns 403; an expired or revoked token returns 401. Unset `CRESAONE_DRIVE_TOKEN` before owner-only commands (`create`, `default`, `ls` with no Drive, `share`, `tokens`, `revoke`, `delete`).

## Publish Drive content

Drive files stay private. To make content public, publish a snapshot as a Site: `bash {core}/scripts/publish.sh --from-drive {driveId} --slug {slug}`.
