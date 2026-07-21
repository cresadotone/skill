# templates/ — house design system + scaffolding templates

Everything published from this skill should look like it came from the same
desk. These files are the source of truth for that look.

## Files

- `DESIGN.md` — the **SF Ownership Desk** design system: color tokens,
  typography (Geist Sans / Geist Mono / Geist Pixel Square), component
  anatomy, layout, responsive rules, and generation prompts. Read it before
  building any new app, dashboard, or page.
- `app-template.html` — production single-file app skeleton (~290 KB,
  fonts embedded). Near-black mono default plus 10 switchable themes, ⌘K
  command bar with live theme preview, sortable table + grouped board view,
  KPI tiles, filter chips, right-side record drawer, confirm modal, toasts,
  full keyboard layer, CSV export, and localStorage view state.
- `plan-template.html` — interactive plan/decision page: approve / reject /
  double-click-edit decision cards, group filter chips, stat tiles,
  localStorage persistence, and a Submit POST to a local listener with a
  JSON-download fallback.
- `PLAN-DESIGN.md` — the plan-page contract: `PLAN_ITEMS` item shape, theme
  tokens, interactivity requirements, and the listener payload format.
- `plans.config.example.json` — example per-project config holding the
  persistent accent color and next plan sequence number.

## Scaffolding an app

1. Copy `app-template.html` to `{site-dir}/index.html`.
2. Fill the placeholders: `__APP_TITLE__`, `__APP_BADGE__`, `__APP_SLUG__`
   (used as the localStorage key), `__APP_DATE__`, `__APP_REPO__`.
3. Replace the `DATA` array — the row shape is documented inline directly
   above it. Everything else (table, board, drawer, command bar, themes,
   keyboard shortcuts, CSV export) is already wired.
4. Adjust `COLS` if your rows have different fields.
5. Generate a matching `og.png` with `../scripts/og-image.py` (same design
   language) and publish with `--og-image-path /og.png`.

## Scaffolding a plan/decision page

1. Copy `plan-template.html` to `{name}.html`.
2. Fill the placeholders: `__PLAN_SEQ__`, `__PLAN_SEQ_PAD__`,
   `__PLAN_TITLE__`, `__PLAN_SLUG__`, `__PLAN_DATE__`, `__PLAN_REPO__`,
   `__PLAN_SOURCE__`, `__PLAN_ACCENT__`, `__PLAN_ACCENT_HUE__` (accent comes
   from the project's `plans.config.json`; see the example file).
3. Write the thesis paragraph (`#plan-sub`) and replace the sample
   `PLAN_ITEMS` per `PLAN-DESIGN.md`.

## Rules

- Do not hand-roll new shells or invent new palettes when these templates
  apply. New surfaces must stay consistent with `DESIGN.md`: absolute-black
  background, near-black surfaces, graphite hairlines, signal-white accent,
  three-level neutral text, mono metadata, restrained radii.
- Both templates are fully self-contained single files — no build step, no
  network requests — so they publish directly as cresa.one Sites.
- When live data is unavailable, ship empty states rather than inventing
  people, companies, emails, amounts, or dates.
