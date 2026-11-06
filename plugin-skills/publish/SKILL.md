---
name: publish
description: >-
  Publish a website, app, dashboard, report, PDF, image, or folder to a live
  cresa.one URL with page metadata, a matching share card, chosen access, and
  verification. Use when asked to "publish this", "deploy this", "host this",
  "put this online", "make a website", "share this as a link", "create a
  webpage", or to prepare a Site with an offline dry run before publishing.
---

# Publish a Site

{{RUNTIME}}

## Choose the helper

- HTML Site a person will open, share, or return to: `ship.sh` (default). It needs an account key and Python 3.10+.
- Raw files with no `index.html`, an anonymous 24-hour Site, or a Drive snapshot: `publish.sh`.
- Building a new page first: start from `{core}/templates/app-template.html` or `{core}/templates/plan-template.html` and read `{core}/templates/DESIGN.md`.

## Ship an HTML Site

1. Choose six inputs from what the Site does, in the user's language: slug, title, description, keywords, privacy, and share-card copy. Read `{core}/reference/ship.md` the first time you ship in a conversation. Nothing private may appear in the slug, title, or preview.
2. Ask before gating content. `--privacy private` (default) only sets noindex, no-referrer, and profile unlisting. Use `--access password` or `--access restricted --allow-emails a@example.com` when the page itself must be protected.
3. Run once:

```bash
bash {core}/scripts/ship.sh ./site --slug market-rent-calculator \
  --title "Market Rent Calculator – Compare scenarios" \
  --description "Compare market rent scenarios side by side." \
  --keywords "rent, calculator, cre" --privacy private
```

Add `--dry-run` to stage files, render the card, and write metadata without credentials or network calls. Set `CRESAONE_SITE_PASSWORD` instead of passing `--password` in argv.

4. Read the result. `ship: shipped. Every check passed.` means done. Exit 2 means the Site is live but a named check failed: fix the cause and rerun the same command. Look at `{out}/og.png` before reporting.
5. Report from `ship_result.*` and `ship-report.json`: URL, access, privacy, profile listing, and the returned expiry. Call a Site permanent only when `persistence=permanent`.

## Quick or raw-file publish

```bash
bash {core}/scripts/publish.sh ./report.pdf               # anonymous: expires, prints a claim URL
bash {core}/scripts/publish.sh ./dist --create --slug q3-board-pack --client claude
bash {core}/scripts/publish.sh --from-drive drv_123 --slug q3-board-pack
```

Read `publish_result.*` from stderr. For anonymous Sites, share the `https://` claim URL and warn that claim tokens are shown once. Use `--check-slug name` before promising a URL.

## After publishing

Offer a health check (`site-health` skill). For later edits, renames, or status changes, use the `manage-sites` skill; for passwords and invite lists, use `site-access`.
