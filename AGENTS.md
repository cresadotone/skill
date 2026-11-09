# cresa.one Public Skill Repo Agent Guide

Use this file as the operating guide for AI coding agents working in the public `cresadotone/skill` repository.

## What This Repo Contains

- `cresa-one/` - canonical cresa.one skill bundle for `npx skills add cresadotone/skill --skill cresa-one`.
- `skills/cresa-one/` - generated compatibility mirror for existing Cursor/Codex consumers.
- `plugin.config.json` - canonical shared plugin release metadata and presentation fields.
- `plugin-skills/` - sources for the plugin's focused task skills (`publish`, `manage-sites`, `site-health`, `site-access`, `drive`, `domains`, `site-data`) plus the shared `RUNTIME.md` paragraph injected at each `{{RUNTIME}}` marker.
- `plugins/cresa-one/` - generated, self-contained Claude Code/Codex plugin: the core skill and runtime under `skills/cresa-one/`, one generated `SKILL.md` per task skill beside it, assets, and a status command.
- `.claude-plugin/marketplace.json` and `.agents/plugins/marketplace.json` - generated Claude Code and Codex catalogs; both resolve `./plugins/cresa-one`.
- `hermes/` - Hermes community skill bundle.
- `commands/cresa-one.md` - Claude Code/Cowork slash command that auto-updates the installed skill through the hosted installer (`install.ps1` on Windows, `install.sh` elsewhere).
- fallback installer archives - every install/update writes `cresa-one-{version}.skill` and `cresa-one-{version}.zip` under `~/.claude/skills/cresa-one/packages/` and tells agents to `present files to the user`.
- `.cursor-plugin/` and `.codex-plugin/` - generated compatibility manifests.
- `assets/` and `PLUGIN.md` - canonical brand assets, template screenshots, provenance, and the plugin guide.
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

- Edit the canonical runtime bundle in `cresa-one/`. In the private source repo, run `python3 scripts/sync-skill.py` to regenerate `skills/cresa-one/`, Hermes, and hosted Markdown; `--check` verifies drift without writing.
- Edit `plugin.config.json`, `plugin-commands/status.md`, `plugin-skills/`, `PLUGIN.md`, and `assets/` for plugin changes. Task skills hold only `SKILL.md`; they reference the core runtime as `{core}/...` (`../cresa-one/` from the skill directory), which the generator verifies against the runtime file list. Keep each description under 1,024 characters with the use case first, never use `$ARGUMENTS` or `$0`-`$9` in skill text, and list every skill in `PLUGIN.md`. Task skills ship only in the plugin; the generator marks them `metadata.internal: true` so `npx skills add` keeps offering only the single all-in-one `cresa-one` skill. The same sync command regenerates all plugin manifests, both marketplaces, and `plugins/cresa-one/`. Never edit generated copies; keep the stable plugin/marketplace name `cresa-one` and advance the shared plugin version for release changes. Keep `skillVersion` aligned with the canonical skill.
- Run `python3 scripts/plugin-distribution.test.py`, `claude plugin validate --strict skill/.claude-plugin/marketplace.json`, `claude plugin validate --strict skill/plugins/cresa-one`, and `node scripts/validate-plugin-codex.mjs` from the private root. Native Codex validation only reads the catalog; it does not install or change user configuration. CI checks package drift before mirror publication.
- Reproduce screenshots with `uv run --with playwright==1.51.0 scripts/render-plugin-assets.py`, then sync. Preserve the existing logo artwork and label illustrative data. Claude Code's custom `metadata.interface` is catalog data, not a native image gallery; keep the README gallery available.
- Keep the plugin's `status` command separate from the standalone `commands/cresa-one.md` auto-installer. Bundling the latter would create a duplicate skill invocation and manage the wrong installation.
- Release updates must include the version API and the well-known index; `sync-skill.py` regenerates both installers' versions and bundle lists. The changelog is hand-written and must match exactly in the version API, `install.sh`, and `install.ps1`. Run `python3 scripts/skill-distribution.test.py`, `python3 scripts/skill-api-references.test.py` (every API path, method, query parameter, body field, and jq field in the skill text must exist in `openapi.json`, and the MCP section must match the approval policy), `python3 scripts/install-ps1.test.py` (needs `pwsh`), `python3 scripts/windows-helpers.test.py`, and `python3 skill/cresa-one/scripts/ship.test.py` from the private repository root. Do not remove expiry reporting when importing local skill extensions, and keep Drive-token claims aligned with `cresa-one/src/lib/drive-auth.ts`.
- Keep helpers working in Git Bash on Windows: route file paths for native `curl`, `jq`, and Python through `native_path`, call jq with `-b` there, and do not assume `python3` or `file` exist.
- Keep `commands/cresa-one.md` compatible with `install.sh` and `install.ps1`; fallback installs copy it to `~/.claude/commands/cresa-one.md`.
- Keep installer archive output stable. If install output includes `present files to the user`, agents should present the listed `.skill` and `.zip` archive paths through their current environment's file presentation/attachment mechanism.
- Keep helper scripts such as `publish.sh` and `drive.sh` compatible with documented behavior.
- The core skill documents the remote MCP server (`https://mcp.cresa.one/mcp`, OAuth sign-in); keep its list of actions that wait for approval aligned with `cresa-one-mcp/src/approval-policy.ts`. Do not add claims for Web Bot Auth, verified platform integrations, or official public CLI packaging unless those surfaces are live and maintained.
- Never commit credentials, API keys, Drive tokens, or `.cresaone/state.json`.
- Prefer small, reviewable changes that preserve existing install commands and script output contracts.

## Verification

For skill/runtime changes, check:

```bash
curl -s https://cresa.one/api/skill/version
curl -s https://cresa.one/skill.md | head -20
curl -s https://cresa.one/.well-known/skills/index.json
curl -s https://cresa.one/.well-known/skills/cresa.one | head -20
```
