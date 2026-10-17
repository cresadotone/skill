# cresa.one plugin

Publish Sites with verified access, metadata, and share cards. Keep project files in private account-owned Drives.

## Start here

Ask your agent to prepare a local website, publish a report, or store files in a Drive. For preparation without publishing, ask for an **offline dry run**.

- “Prepare this site for cresa.one with metadata and a matching share card; dry run only.”
- “Publish this report as a restricted Site and verify its access settings.”
- “Upload these project files to my private cresa.one Drive.”

Claude Code exposes the publishing skill as `/cresa-one:cresa-one` and bundle information as `/cresa-one:status`. Codex discovers the same `cresa-one:cresa-one` skill.

## Included

- `skills/cresa-one/scripts/ship.sh`: prepare HTML, generate share cards, configure and verify access, publish, and check saved settings.
- `publish.sh`: publish files or update a Site's metadata.
- `drive.sh`: manage private account-owned cloud files.
- App and editable decision-page templates, share-card templates, and shipping reference docs.

Paths above are relative to the installed plugin directory. Resolve that directory from the agent's loaded skill; do not assume the user's working directory is the plugin.

## Requirements and access

Core helpers use Bash, curl, and jq. Complete Site preparation requires Python 3.10+. Share-card rendering optionally uses Playwright with Chromium; Pillow is the fallback.

Anonymous Sites are temporary. Owner-managed publishing, metadata, access, and Drive operations require a cresa.one account API key. Keep credentials in the supported credential store or environment, never in chat. No OAuth or MCP server is installed by this plugin. Scoped Drive-token sharing is not supported.

`--privacy private` controls search indexing, referrer policy, and profile listing. Select `--access password` or `--access restricted` when content must be gated. Ship checks protected access before upload and reports the actual expiry returned by the service.

## Preview gallery

These are local renders of bundled templates, not live account records or marketplace UI screenshots.

![App template with clearly labeled sample data](assets/screenshot-app.png)

![Editable Site launch review with example decisions](assets/screenshot-plan.png)

![Open Graph card rendered by the bundled helper](assets/screenshot-share-card.png)

## Install and update

After this release reaches the public mirror, add `cresadotone/skill` as a marketplace, then install `cresa-one@cresa-one`. Full platform-specific steps and local checkout instructions: [public README](https://github.com/cresadotone/skill#readme).

Update this package through the platform's plugin manager. The standalone hosted installer manages a separate skill installation and does not update plugin caches.

## Links

[Product documentation](https://cresa.one/docs) · [API reference](https://cresa.one/openapi.json) · [Source and issues](https://github.com/cresadotone/skill)

License: MIT.
