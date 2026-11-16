# Plugin assets

- `logo.svg`: existing cresa.one brand mark from this repository, retained unchanged. Its opaque white background keeps the black mark visible in light and dark host themes. `logo` and `logoDark` both use this file. There is no separate dark-theme artwork.
- `icon.png`: 256 × 256 rasterization of that SVG for the Codex composer. `composerIcon` and `composerIconDark` both use this file.
- `screenshot-app.png`: local Chromium capture of the bundled app template. The historical-person examples and all records come from the template's existing demo data and are explicitly labeled as examples.
- `screenshot-plan.png`: local Chromium capture of the bundled decision-page template with illustrative Site launch choices. The listener is offline and no decisions were submitted.
- `screenshot-share-card.png`: 1200 × 630 output of the bundled `og-card.py`, labeled as a local preview.

No screenshots contain customer records, credentials, production account state, or invented platform UI. These images show template output, not a claim that a Site was published.

In the private source repository, reproduce with:

```bash
uv run --with playwright==1.51.0 scripts/render-plugin-assets.py
python3 scripts/sync-skill.py
```

The renderer requires Playwright's corresponding Chromium binary. If absent, install it with `uv run --with playwright==1.51.0 python -m playwright install chromium`. Rendering blocks HTTP(S) requests. Canonical sources are under `skill/cresa-one/templates/` and `skill/cresa-one/scripts/og-card.py`; copied plugin assets are generated.

Codex listing fields use the existing logo and composer icon, including the optional dark-theme paths, which point at those same files. `interface.screenshots` is still written for the Codex loader that returns it; the current submission field table does not list that key. Claude Code receives the same asset references in its free-form `metadata.interface` object and uses `icon` for its directory listing. Claude Code does not render the custom metadata as a native gallery. See the [Claude manifest reference](https://code.claude.com/docs/en/plugins/manifest-reference).
