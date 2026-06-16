# Terminal Instrument Example

This optional example shows how to build a consistent family of self-contained, mobile-first apps for publishing on cresa.one. It is an example pattern, not required core skill behavior.

Use this when a user wants multiple calculators, dashboards, or tools to share the same design system and interaction model.

## Contents

- `templates/template.html` - shared HTML/CSS shell with SEO and Open Graph placeholders.
- `templates/runtime.js` - shared app runtime for fields, tiles, charts, keyboard shortcuts, theme toggle, CSV export, copy, and share-link hash state.
- `config/example.js` - minimal app config showing the expected `META` block and `APP` object.
- `scripts/generate.mjs` - inlines one config plus runtime into `apps/{slug}.html`.
- `scripts/og.py` - optional Open Graph image generator. Yes, this creates `deploy/{slug}/og.png` cards using Playwright.

## Build

Run from this directory:

```bash
node scripts/generate.mjs example
```

This writes `apps/example_occupancy_cost_probe.html`.

## OG Images

Open Graph images are important for polished sharing. Keep them as an optional generation step because Playwright and Python are heavier than the core publishing helper.

Run from this directory after adding real configs:

```bash
python3 scripts/og.py
```

Each deployable app directory should include:

```text
deploy/{slug}/
  index.html
  og.png
```

The HTML should reference the image with an absolute URL after publish, for example:

```html
<meta property="og:image" content="https://example-slug.cresa.one/og.png">
```

cresa.one viewer metadata should use the Site-relative path:

```bash
--og-image-path /og.png
```

Do not upload the OG image only to a Drive. Drive files are private unless published as a Site. Share-preview images must be deployed with the Site.

## Publish Pattern

```bash
./scripts/publish.sh deploy/{slug} \
  --slug {clean-slug} \
  --title "App Title" \
  --description "Short share-preview description" \
  --og-image-path /og.png \
  --tags '["calculator","cre"]' \
  --client claude
```

Tags and metadata-only updates require an authenticated publish because Site tags and owner metadata are account-scoped.

To update dashboard/UI metadata after the app is already live, use the metadata endpoint instead of editing or re-uploading HTML:

```bash
./scripts/publish.sh --metadata-only --slug {clean-slug} \
  --title "App Title" \
  --description "Short share-preview description" \
  --og-image-path /og.png \
  --client claude
```

Verify after publish:

```bash
curl -fsSI "https://{clean-slug}.cresa.one/og.png" | grep -i '^content-type:'
curl -sS "https://cresa.one/api/v1/publish/{clean-slug}" \
  -H "authorization: Bearer $CRESAONE_API_KEY" |
  jq '{viewer,tags,manifest}'
```

## Scope Boundary

Keep app-specific formulas, live URL maps, and generated `apps/` or `deploy/` output out of the core skill unless they are meant to be shipped as examples. The reusable parts are the pattern: shared shell, config-driven runtime, OG generation, publish metadata, and verification before publishing.
