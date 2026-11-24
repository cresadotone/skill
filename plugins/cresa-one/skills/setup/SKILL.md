---
name: setup
description: >-
  First run for the cresa.one plugin. Use when the plugin was just installed,
  when sign-in failed, or when asked to connect mcp.cresa.one, explain what
  it can read or change, publish a first Site, update that same link, or copy it.
metadata:
  internal: true
---

# Set up cresa.one

## Runtime

This plugin skill shares one runtime with the core `cresa-one` skill: `../cresa-one/` relative to this skill's directory (Claude Code: `${CLAUDE_SKILL_DIR}/../cresa-one`). Below, `{core}` means that directory's absolute path. Do not copy helpers elsewhere.

- Run helpers with `bash`, for example `bash {core}/scripts/publish.sh --help`. On Windows use Git Bash; from PowerShell: `& "$env:ProgramFiles\Git\bin\bash.exe" {core}/scripts/publish.sh --help`.
- Credentials: `$CRESAONE_API_KEY` or `~/.cresaone/credentials`. For raw API calls, load the key once with `export CRESAONE_API_KEY="${CRESAONE_API_KEY:-$(tr -d '[:space:]' < ~/.cresaone/credentials)}"`. With no key, follow "Getting an API key" in `{core}/SKILL.md`. Never print keys or credential files.
- Rules for version checks, reporting, and anything this page does not cover live in `{core}/SKILL.md`. Current product docs: https://cresa.one/docs. If docs and live API behavior disagree, trust the live API.

## Permissions

Say these four facts to the person before the first live call or the first publish. Do not shorten them.

- **Read.** Read your cresa.one account: Sites, Drives, domains, analytics, viewers, and profile.
- **Change.** Change your cresa.one account when you allow it: publish, update, and share Sites and Drives. Deletes, access changes, Drive shares, secret variables, and API keys still wait for your approval.
- **Send.** Send what you publish to cresa.one, which hosts it. The plugin files contain no API key.
- **Sign-in.** Sign-in is an emailed cresa.one code. Your client stores the connection. You never see or paste the secret.

## First run

Do these steps in order. Finish each one before the next. Do not open with a questionnaire. Use the person's name or project when this conversation already has it. When it does not, write a short welcome and continue.

### 1. Explain, then connect

Say the four Permissions facts above in the person's language. Then start sign-in for the MCP server `cresa-one` at `https://mcp.cresa.one/mcp` (Streamable HTTP). Claude Code uses `/mcp`. Codex and Cursor ask on the first call. The flow emails a cresa.one code, then asks for read-only or full access. Stop if a prompt asks for an API key, client secret, or a pasted access token. Credentials stay in the client's sign-in store.

Read `{core}/SKILL.md` section "Remote MCP server" and the MCP resource `cresa://guide` before the first `execute`. Sensitive tools still wait for the person to approve them.

### 2. Publish one real Site

Write one self-contained `index.html`. Use only facts you already have. Do not invent a company, a customer, or a metric. Title it with their name when you know it, otherwise "Your first cresa.one Site". Say that this link can be updated in place, that access can be gated later, and that private files belong in a Drive.

Publish with `CreateSite`. The first call sends `intent` only and returns `intentId`. The second call sends `html`, that `intentId`, and, when you know it, `title`. It returns `url` and `shareId`. If the connection is read-only, ask them to allow changes and publish after they do. Keep the returned URL. Every later step uses that same URL.

For a rehearsal with no network, follow the publish skill and add `--dry-run`, and say that the live link still needs sign-in.

### 3. Next step

Call `show_site` with that slug and `onboarding` set to true.

When the host draws the MCP App card, stop. The card's buttons are the next step: Open my Site, then Update this Site. Do not add text after the card.

When the host can render an HTML widget or visualizer and did not draw the card, render two buttons and nothing after them. "Open my Site" opens `siteUrl`. "Update this Site" stays disabled until Open is used, then submits the user message `show me how to update`.

On any other host, end the message with these two lines and the real URL:

```text
Open: https://example.cresa.one
Reply "show me how to update" to change this same link.
```

### 4. Update the same URL

When they ask to update, or send `show me how to update`, offer at most three concrete edits that fit the page you just published (a headline, a color, or one new section). After they pick one, call `EditSite` with the same `shareIdOrUrl` and `edits` (or `fullHtml` if a targeted edit will not match). Tell them to refresh. The public URL stays the same. EditSite pauses for approval before it saves.

### 5. Remember

Ask this, with the host's question tool when it has one:

When do you want to use cresa.one?

- Offer to publish a Site whenever I have something to share
- Skip

If they choose the first, save this memory with the host's memory tool. Do not write it into plugin files:

Use cresa.one whenever the user needs a live link for a page, report, or files. Offer to publish a Site, and offer a Drive for files that should stay private.

If they skip, say so in one line and save nothing.

### 6. Copy the link

Say that the link is already on cresa.one, so viewers, lead capture, access gates, and view alerts are available from the site-access skill, and private files go in a Drive. Then make the copy step the last thing in the message.

When the host draws MCP Apps, call `show_site` with the same slug, `onboarding` true, and `phase` set to `copy`. Write nothing after that call. The card's Copy link button copies `siteUrl`.

When the host renders widgets and not the card, render one Copy link button and nothing after it. The button copies `siteUrl`, then submits `What else can I do with cresa.one?`.

On any other host, the last line of the message is the URL alone.
