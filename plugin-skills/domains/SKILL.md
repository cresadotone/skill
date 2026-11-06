---
name: domains
description: >-
  Connect cresa.one Sites to custom domains, the account subdomain handle,
  and path links: add or remove a domain, read DNS instructions and SSL
  status, create or change the handle, and mount Sites at paths. Use when
  asked to "use my own domain", "connect example.com", "set up DNS", "why is
  my domain not working", "change my handle", or "put this site at
  /pricing".
---

# Domains, handles, and links

{{RUNTIME}}

`API=https://cresa.one/api/v1` and `AUTH="authorization: Bearer $CRESAONE_API_KEY"` in the examples. Read https://cresa.one/docs and the request schemas in https://cresa.one/openapi.json before changing domains, handles, or links; field names below are a starting point.

## Custom domains

```bash
curl -sS "$API/domains" -H "$AUTH"
curl -sS -X POST "$API/domains" -H "$AUTH" -H "content-type: application/json" -d '{"domain":"www.example.com"}'
curl -sS "$API/domains/www.example.com" -H "$AUTH"
```

The response has `status` (`pending`, `active`, or `error`), `ssl_status`, `is_apex`, and `dns_instructions`. Give the user the exact DNS records from `dns_instructions`; do not invent records. DNS and certificates can take time, so check the status again when the user returns rather than polling in a loop. Remove a domain with `DELETE $API/domains/{domain}` after confirmation.

## Handle and links

- Handle: `GET`, `POST`, `PATCH`, or `DELETE $API/handle` (body fields `handle` or `username`).
- Links mount a Site at a path on the handle or a custom domain: `GET` or `POST $API/links` (body requires `slug`; also `location`, `mount_path`, `domain`, or `namespace_id`), then `GET`, `PATCH`, or `DELETE $API/links/{location}`.

## Verify

After a domain is `active` or a link exists, run the `site-health` skill with the public URL and `--slug {slug}` to confirm HTTP, TLS, and the access gate.
