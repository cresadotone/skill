---
name: creating-sites
description: >-
  Publish a self-contained HTML Site on cresa.one and keep editing that same
  URL. Use when asked to create a site, edit a site, publish HTML, add
  analytics, turn on lead capture, email the owner when someone views a Site,
  or send Site events to a webhook. Confirm before publishing content that
  faces outward. Never inline images as base64; store them with manage_files
  and reference the path.
---

# Create and edit Sites

{{RUNTIME}}

This is the cresa.one equivalent of Send's creating-sites skill. The tools are `CreateSite`, `EditSite`, `GetSite`, `ShowContent`, `manage_files`, and `manage_sites`.

## Publish

Call `CreateSite` with `intent` only, then again with `html` and the returned `intentId`. It returns `url` and `shareId`. Keep that URL. A later edit calls `EditSite` with the same `shareIdOrUrl` and `edits`. The public URL does not change. Tell the person to refresh. EditSite pauses for approval before it saves.

`sourceShareId` without `html` copies a Site only when that Site has a stored HTML copy. `fullHtml` replaces the page after targeted edits fail.

Read the file before publishing. Ask before publishing content that faces outward.

## Files

Use `manage_files` to list, read, or upload text and assets in the default Drive. Reference those paths from the HTML. Do not embed images as base64.

## After the Site exists

- `GetSite` reads the slug, URL, title, and stored HTML.
- `ShowContent` draws the Site in the chat.
- `manage_sites` with action `update` changes title, access, view alerts, or the slug, and pauses for approval.
- `get_skills` and `manage_skill` read and save workspace skills on the Drive.

The bash helpers in `{core}/scripts/publish.sh` remain available when the person wants a local directory published with metadata and a share card.
