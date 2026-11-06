---
description: Show the bundled cresa.one plugin and skill versions, skills, helper paths, and update instructions.
allowed-tools: ["Read", "Bash"]
---

# cresa.one plugin status

Read `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` and
`${CLAUDE_PLUGIN_ROOT}/skills/cresa-one/SKILL.md`. Report the plugin version,
bundled skill version, the skill folders under `${CLAUDE_PLUGIN_ROOT}/skills/`
(each is `/cresa-one:<folder>`), and these helper paths:

- `${CLAUDE_PLUGIN_ROOT}/skills/cresa-one/scripts/ship.sh`
- `${CLAUDE_PLUGIN_ROOT}/skills/cresa-one/scripts/publish.sh`
- `${CLAUDE_PLUGIN_ROOT}/skills/cresa-one/scripts/site-health.sh`
- `${CLAUDE_PLUGIN_ROOT}/skills/cresa-one/scripts/drive.sh`

On Windows, say that the helpers run in Git Bash.

If the user asks whether an update is available, fetch
`https://cresa.one/api/skill/version` with `curl -fsSL --max-time 3`. Report
unavailable metadata without treating the plugin as broken. That endpoint reports
the hosted **skill** version, not the plugin release version.

For a marketplace plugin update, use the Claude plugin lifecycle:

```text
/plugin marketplace update cresa-one
/plugin update cresa-one@cresa-one
/reload-plugins
```

Do not run the standalone hosted installers (`install.sh` or `install.ps1`) as a
plugin update: they install a separate skill under `~/.claude/skills/` and cannot
update this plugin's cache. For publishing or storage requests, follow the
matching bundled skill. Never print API keys, Drive tokens, or credential files.
Product docs: https://cresa.one/docs.
