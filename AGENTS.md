# cresa.one Public Skill Repo Agent Guide

Use this file as the operating guide for AI coding agents working in the public `cresadotone/skill` repository.

## What This Repo Contains

- `cresa-one/` - canonical cresa.one skill bundle for `npx skills add cresadotone/skill --skill cresa-one`.
- `skills/cresa-one/` - generated compatibility mirror for Cursor/Codex plugin discovery.
- `hermes/` - Hermes community skill bundle.
- `commands/cresa-one.md` - Claude Code/Cowork slash command that auto-updates the installed skill through the hosted installer.
- fallback installer archives - every install/update writes `cresa-one-{version}.skill` and `cresa-one-{version}.zip` under `~/.claude/skills/cresa-one/packages/` and tells agents to `present files to the user`.
- `.cursor-plugin/` and `.codex-plugin/` - marketplace/plugin manifests.
- `README.md` - public install and overview docs.

## Source Of Truth

The public skill repo is synced from the private cresa.one product repo.

- Product docs: [https://cresa.one/docs](https://cresa.one/docs)
- Agent context: [https://cresa.one/llms.txt](https://cresa.one/llms.txt)
- Full agent context: [https://cresa.one/llms-full.txt](https://cresa.one/llms-full.txt)
- API spec: [https://cresa.one/openapi.json](https://cresa.one/openapi.json)
- Skill version metadata + changelog: [https://cresa.one/api/skill/version](https://cresa.one/api/skill/version)

If local skill text and live docs disagree, prefer live docs for product capabilities and live API responses for active operations.

## Editing Guidance

- Keep `cresa-one/SKILL.md` and `skills/cresa-one/SKILL.md` synchronized.
- Keep `commands/cresa-one.md` compatible with `install.sh`; fallback installs copy it to `~/.claude/commands/cresa-one.md`.
- Keep installer archive output stable. If install output includes `present files to the user`, agents should present the listed `.skill` and `.zip` archive paths through their current environment's file presentation/attachment mechanism.
- Keep helper scripts such as `publish.sh` and `drive.sh` compatible with documented behavior.
- Do not add claims for MCP, OAuth, Web Bot Auth, verified platform integrations, or official public CLI packaging unless those surfaces are live and maintained.
- Never commit credentials, API keys, Drive tokens, or `.cresaone/state.json`.
- Prefer small, reviewable changes that preserve existing install commands and script output contracts.

## Verification

For skill/runtime changes, check:

```bash
curl -s https://cresa.one/api/skill/version
curl -s https://cresa.one/skill.md | head -20
curl -s https://cresa.one/.well-known/skills/index.json
curl -s https://cresa.one/.well-known/skills/cresa.one/SKILL.md | head -20
```
