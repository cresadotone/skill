---
name: site-health
description: >-
  Check whether a cresa.one Site is healthy: HTTP reachability, TLS
  certificate, finalized version or stuck upload, publish status, expiry,
  access gate versus policy, share image, traffic, and recent 404s. Read-only.
  Use when asked "is my site up", "check my site", "why is my site broken",
  "is it still live", "did the publish work", "when does it expire", or
  "who is visiting".
---

# Check Site health

{{RUNTIME}}

## Run the check

```bash
bash {core}/scripts/site-health.sh {slug}                       # or https://{slug}.cresa.one/
bash {core}/scripts/site-health.sh {slug} --json --range 30d     # machine-readable, 30-day analytics
bash {core}/scripts/site-health.sh https://example.com/ --slug {slug}   # custom domain
```

The helper only reads. Without a key it runs public checks only and says which owner checks it skipped. Exit 0 means healthy or warnings only; exit 2 means a check failed.

## Read the report

Each line is `OK`, `WARN`, `FAIL`, or `SKIP` with a check name:

| Check | Meaning when not OK | Next step |
| --- | --- | --- |
| `http` | DNS, connect, TLS, 404 (unpublished, disabled, never finalized), or 410 (expired) | Match with `status`, `version`, and `expiry` below |
| `tls` | Certificate invalid or expiring within 14 days | Custom domains: check DNS and SSL status (`domains` skill) |
| `status` | `pending`, `archived`, or `disabled` | Set `published` (`manage-sites` skill) only if the user wants it live |
| `version` | Nothing finalized, or an upload is still pending | Republish, or resume or cancel the pending upload (`manage-sites`) |
| `expiry` | Expired or expiring within 24 hours | Claim the Site or change its TTL (`manage-sites`) |
| `access`, `gate` | Policy and public response disagree, or an empty allowlist | Fix with the `site-access` skill, then rerun |
| `metadata`, `og-image` | Missing title or share image, or `ogImagePath` not published | `publish.sh --metadata-only` or republish with `og.png` |
| `analytics` | Recent 404 paths | Fix broken links or add the missing files, then republish |

## Report

Lead with the overall result and the URL. List each warning or failure with its next step. Do not change the Site unless the user asks; then use the skill named in the table and run this check again.
