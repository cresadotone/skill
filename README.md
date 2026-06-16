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

Use the skill's `publish.sh --metadata-only --slug {slug}` helper, or `PATCH /api/v1/publish/{slug}/metadata`, to update dashboard/UI title, description, and share-preview image without re-uploading HTML.

## Examples

- `examples/terminal-instrument/` - optional pattern for consistent self-contained apps with a shared shell, config-driven runtime, and Open Graph image generator.

## Source

This public skill bundle is synced from the private cresa.one product repo. Make changes in the private repo under `skill/`; the public `cresadotone/skill` repo is the mirror used for installs.

## License

MIT
