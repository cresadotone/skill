---
name: domains
description: >-
  Connect cresa.one Sites to custom domains, the account subdomain handle,
  and path links: add a domain with self-serve DNS verification and
  automatic HTTPS, give the user the exact DNS records, check status, change
  the Site a domain serves, remove a domain, create or change the handle,
  and mount Sites at paths. Use when asked to "use my own domain", "connect
  example.com", "set up DNS", "why is my domain not working", "point my
  domain at another site", "change my handle", or "put this site at
  /pricing".
---

# Domains, handles, and links

{{RUNTIME}}

`API=https://cresa.one/api/v1` and `AUTH="authorization: Bearer $CRESAONE_API_KEY"` in the examples. Read https://cresa.one/docs#custom-domains and the request schemas in https://cresa.one/openapi.json before changing domains, handles, or links; handle and link field names below are a starting point.

## Custom domains

A custom domain serves one Site at its root over HTTPS, with certificates issued and renewed automatically.

```bash
curl -sS "$API/domains" -H "$AUTH"                     # setupMode, maxDomains, domains
curl -sS -X POST "$API/domains" -H "$AUTH" -H "content-type: application/json" \
  -d '{"domain":"docs.example.com","slug":"my-site"}'
curl -sS -X POST "$API/domains/docs.example.com/verify" -H "$AUTH"
curl -sS "$API/domains/docs.example.com" -H "$AUTH"    # status, refreshed at most every 15 seconds
```

1. With `setupMode` `automatic`, the create response is `status: pending` with `dns_instructions`: a routing record (`CNAME` to the cresa.one target, or `ALIAS` for ALIAS, ANAME, or CNAME flattening at the apex) and an ownership `TXT` record at `_cresa-verify.<domain>`. Give the user both records exactly as returned; never invent records.
2. After the user adds them, call verify. Status moves `pending` → `verified` (certificate issuing, usually minutes) → `active`, with `url` set. Read `verification_errors` while it is not active; `error` means fix DNS and verify again. Check again when the user returns instead of looping.
3. `PATCH $API/domains/{domain}` with `{"slug":"other-site"}` changes the served Site, or `{"slug":null}` serves nothing. `DELETE $API/domains/{domain}` removes the domain and its certificate; confirm first.

- At most 20 domains per account (403 beyond that). A 409 means another account added the domain; if that claim was never verified, the error names the TXT record that proves the user's claim.
- If the DNS provider cannot alias the apex, use `www` and redirect the apex at the registrar. On Cloudflare DNS, keep the routing record DNS-only. Wildcard domains are not supported.
- With `setupMode` `manual`, adding a domain files a setup request for an operator; `dns_instructions` stay empty until it is active.
- Gates, branding, recipient links, comments, and analytics work on the domain. Owners see the gate there (dashboard sessions do not carry over), and version previews stay on `{slug}.cresa.one`.

## Handle and links

- Handle: `GET`, `POST`, `PATCH`, or `DELETE $API/handle` (body fields `handle` or `username`).
- Links mount a Site at a path on the handle or a custom domain: `GET` or `POST $API/links` (body requires `slug`; also `location`, `mount_path`, `domain`, or `namespace_id`), then `GET`, `PATCH`, or `DELETE $API/links/{location}`.

## Verify

After a domain is `active` or a link exists, run the `site-health` skill with the public URL and `--slug {slug}` to confirm HTTP, TLS, and the access gate.
