---
name: setup
description: >-
  Finish installing the cresa.one plugin. Use when the plugin was just added,
  when sign-in failed, or when asked how to connect mcp.cresa.one, where
  credentials live, or how to show a Site card in chat.
metadata:
  internal: true
---

# Set up cresa.one

## Runtime

This plugin skill shares one runtime with the core `cresa-one` skill: `../cresa-one/` relative to this skill's directory (Claude Code: `${CLAUDE_SKILL_DIR}/../cresa-one`). Below, `{core}` means that directory's absolute path. Do not copy helpers elsewhere.

- Run helpers with `bash`, for example `bash {core}/scripts/publish.sh --help`. On Windows use Git Bash; from PowerShell: `& "$env:ProgramFiles\Git\bin\bash.exe" {core}/scripts/publish.sh --help`.
- Credentials: `$CRESAONE_API_KEY` or `~/.cresaone/credentials`. For raw API calls, load the key once with `export CRESAONE_API_KEY="${CRESAONE_API_KEY:-$(tr -d '[:space:]' < ~/.cresaone/credentials)}"`. With no key, follow "Getting an API key" in `{core}/SKILL.md`. Never print keys or credential files.
- Rules for version checks, reporting, and anything this page does not cover live in `{core}/SKILL.md`. Current product docs: https://cresa.one/docs. If docs and live API behavior disagree, trust the live API.

## Connect

1. Confirm the plugin's MCP server is `cresa-one` at `https://mcp.cresa.one/mcp` (Streamable HTTP).
2. Start the client's MCP sign-in. Claude Code uses `/mcp`. Codex and Cursor prompt on the first call. The flow emails a cresa.one code, then asks for read-only or full access.
3. Stop if a prompt asks for an API key, client secret, or a pasted access token. This package does not use those. Credentials stay in the client's sign-in store.

## Confirm

- Read `{core}/SKILL.md` section "Remote MCP server" before the first live call. Sensitive tools wait for approval.
- Call `show_site` with no slug. A host that supports MCP Apps draws an interactive card. Any other host returns the same Sites as JSON. Either result means the connection works.
- For a local publish rehearsal with no network, follow the publish skill and add `--dry-run`.
