# cresa.one

cresa.one is free, instant web hosting for AI agents. Just tell your agent to publish to cresa.one and your content will be live at {new-url}.cresa.one. See the docs for the full feature set.

## Install

```bash
npx skills add cresadotone/skill --skill cresa-one -g
```

Or without npm:

```bash
curl -fsSL https://cresa.one/install.sh | bash
```

Fallback installer also installs `/cresa-one` for Claude Code/Cowork. Typing `/cresa-one` checks live skill metadata and automatically runs the hosted installer when a newer version exists, so local skill files, helper scripts, bundled `jq`, and the command update together.

Each fallback install/update also packages portable archives at `~/.claude/skills/cresa-one/packages/`:

- `cresa-one-{version}.skill`
- `cresa-one-{version}.zip`

Installer output includes `present files to the user` followed by both paths so agents can attach or reveal them for quick installation in Claude Desktop, Codex, or similar apps.

### Install in Hermes

Direct from the public GitHub skill repo:

```bash
hermes skills install cresadotone/skill/hermes/productivity/cresa.one
```

Or via the well-known endpoint on `cresa.one`:

```bash
hermes skills install well-known:https://cresa.one/.well-known/skills/cresa.one
```

## Docs

Full documentation: **https://cresa.one/docs**

## Site Metadata

Use the skill's `publish.sh --metadata-only --slug {slug}` helper, or `PATCH /api/v1/publish/{slug}/metadata`, to update dashboard/UI title, description, and share-preview image without re-uploading HTML. Put `og.png` in the Site directory and set `--og-image-path /og.png`; Drive-only files are private and are not public OG image URLs.

## Media Types

The publish and Drive helpers preserve common web content types, including AVIF/WebP/HEIC/TIFF images, MP4/MOV/WebM video, FLAC/AIFF/ALAC/M4A/AAC/WAV/MP3/OGG/Opus/MIDI audio, fonts, WebAssembly, web manifests, archives, structured data, SQLite/parquet files, and glTF/GLB/USDZ/STL models.

## Design system & templates

- `cresa-one/templates/` - the SF Ownership Desk design system (`DESIGN.md`) plus production single-file templates: `app-template.html` (near-black mono app skeleton with themes, ⌘K command bar, table/board views, drawer, keyboard layer) and `plan-template.html` (interactive plan/decision page). The bundled `og-image.py` generates share cards in the same design language. See `cresa-one/templates/README.md` for scaffolding steps.

## Examples

- `examples/terminal-instrument/` - optional pattern for consistent self-contained apps with a shared shell, config-driven runtime, and Open Graph image generator.

## Source

This public skill bundle is synced from the private cresa.one product repo. Make changes in the private repo under `skill/`; the public `cresadotone/skill` repo is the mirror used for installs.

## License

MIT
