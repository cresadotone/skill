---
name: setup
description: >-
  Finish installing the cresa.one plugin. Use when the plugin was just added,
  when sign-in failed, or when asked how to connect mcp.cresa.one, where
  credentials live, or how to show a Site card in chat.
---

# Set up cresa.one

{{RUNTIME}}

## Connect

1. Confirm the plugin's MCP server is `cresa-one` at `https://mcp.cresa.one/mcp` (Streamable HTTP).
2. Start the client's MCP sign-in. Claude Code uses `/mcp`. Codex and Cursor prompt on the first call. The flow emails a cresa.one code, then asks for read-only or full access.
3. Stop if a prompt asks for an API key, client secret, or a pasted access token. This package does not use those. Credentials stay in the client's sign-in store.

## Confirm

- Read `{core}/SKILL.md` section "Remote MCP server" before the first live call. Sensitive tools wait for approval.
- Call `show_site` with no slug. A host that supports MCP Apps draws an interactive card. Any other host returns the same Sites as JSON. Either result means the connection works.
- For a local publish rehearsal with no network, follow the publish skill and add `--dry-run`.
