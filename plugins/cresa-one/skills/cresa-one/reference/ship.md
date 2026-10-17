# Ship reference

Read once per conversation before the first `ship.sh` run. `SKILL.md` holds the steps; this file holds the rules for the six inputs, the OG card, and what ship checks.

## The six inputs

**Slug.** Semantic: it says what the Site is (`market-rent-calculator`, `acme-lease-comparison`, `baseline-lab-trends`). Product or project name first, then the noun. 3 to 63 chars, lowercase, single hyphens. Generated `word-word-a1b2` slugs are refused unless `--allow-generated-slug`. For private Sites the slug stays neutral: a client name, a health topic or a deal term in the URL leaks it to every log and preview. A guessable slug plus `anyone_with_link` access is weak secrecy; offer `--access password` or `restricted`.

**Title.** `{Name} – {what it does}`, 60 chars or fewer, en dash separator. The part before the separator becomes `og:site_name` and the card's name line. Goes to `<title>`, `og:title`, `twitter:title` and the Site's dashboard title.

**Description.** 50 to 200 chars, one sentence on what a visitor gets. Specific nouns and verbs; no "seamless", "powerful", "all-in-one". Use `--og-description` when the preview needs a shorter line.

**Keywords.** 5 to 10 comma-separated terms a person would type. They feed `<meta name="keywords">` and, when `--tags` is absent, the Site tags (slugified, first 8). Pass `--tags '["a","b"]'` to set dashboard tags separately: tags organise the owner's Sites, keywords describe the page.

**Privacy.** `private` unless the user said the Site should be found. See the table in `SKILL.md`. With `private`, keywords and description still matter: they drive link previews, tab titles and the dashboard, even though search engines are told to stay out.

**OG copy.** Name, headline, optional muted continuation. It appears wherever the link is pasted, so for private Sites it describes the kind of thing, never the contents: no personal data, no client names, no figures from the page.

## The OG card

Order of precedence: `--og file.png`, then `--og-html card.html`, then an `og.png` already in the Site root, then the token card, then `og-image.py` (house style) when no browser is available. The output is always `/og.png`, 1200x630 PNG; ship refuses any other size or format.

Match the Site. Pull the page's own colours into `--og-tokens`:

```
--og-tokens "bg=#0b0c0a;panel=#14150f;hairline=#2c2d26;ink=#f0f1e8;muted=#a9ab9f;primary=#d3d95a;signal=#ee9155"
```

Any CSS colour works, including `oklch(...)`. Find them in the Site's token file (`:root` custom properties, `@theme`, `DESIGN.md`). Add `--og-font path/to/font.woff2` for the Site's typeface and `--og-art art.svg` for a right-hand panel: an abstract echo of the page's main visual (chart silhouette, layout wireframe), built from `var(--primary)`, `var(--signal)`, `var(--ink)`, `var(--muted)`, `var(--panel)`, `var(--hairline)`. Illustrative shapes only; real values stay on the page. For full control write a 1200x630 HTML card and pass `--og-html`; `templates/og-card.html` is the starting point. Sites built from `templates/app-template.html` can skip tokens: the fallback house card already matches them.

Always open the rendered `og.png` before reporting.

## What the managed metadata block contains

`inject-meta.py` writes one block between `<!-- cresa-one:meta:start -->` and `<!-- cresa-one:meta:end -->`, right after the viewport tag: `<title>`, description, keywords, application name, author, canonical, robots (+ referrer when private), `theme-color` and a monogram favicon only when the page has none, Open Graph (type, site_name, title, description, url, locale, image with secure_url, type, width, height, alt), X/Twitter (summary_large_image), and JSON-LD (`--json-ld WebSite | WebApplication | none`). It deletes hand-written duplicates of those tags, so source files should carry only appearance tags (viewport, color-scheme, theme-color, icons) and a plain `<title>` fallback. Only `index.html` at the Site root is rewritten.

## What ship verifies

Stored Site title, description and `ogImagePath`; `og.png` in the manifest with an image content type; and, for `anyone_with_link` Sites, the live HTML containing the managed block, a `<title>`, an `og:image` pointing at this host, and `og.png` answering `200 image/*`. Password and restricted Sites answer with an access gate, so ship passes `--no-verify` to `publish.sh` and checks them through the API only. Access, profile, HTTP, and input failures exit nonzero; accumulated post-publish checks exit 2 and name each failure. Explicit empty tags clear existing tags. Render errors do not silently select another design; only missing Playwright/browser triggers the house-card fallback.

## Access before upload

For a new protected Site, ship reserves the slug in pending status with no uploaded content, applies access, reads the policy back, then uploads and finalizes. Existing Sites also receive requested access changes before upload. If the access write or readback fails, no content is uploaded. A failed run can leave an owned pending Site; inspect it and retry the same slug.

Privacy flags set HTML crawler/referrer metadata and profile listing; they are not access controls. Password/restricted verification checks owner metadata and access policy, not gated live bytes. Ship reports the returned expiry; existing account-owned Sites can still have a TTL.

## Dry runs

Dry runs stage and render locally without reading credentials, resolving slugs, renaming Sites, or calling the network. They report action as unresolved until a real run.

## Renames

`--rename-from old-slug` renames, then republishes so canonical and OG URLs match the new host. The old host returns 404 at once and the freed slug can be claimed by anyone; tell the user before running it.

## Environment gotchas

- Invoke with `bash`; skill files may lack the execute bit and `/bin/sh` is not bash.
- Install `jq` yourself or use the hosted installer, which bundles a checksum-verified binary. Ship never downloads executables.
- A credentials file holding base64 is decoded automatically; the key is never echoed.
- Deliverables land in `/mnt/user-data/outputs/{slug}/` when that folder exists: `index.html` (with metadata), `og.png`, `ship-report.json`.
