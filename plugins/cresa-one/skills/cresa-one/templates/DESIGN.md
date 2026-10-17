---
name: SF Ownership Desk
colors:
  background: '#000000'
  surface: '#0a0a0a'
  surface-raised: '#0f0f0f'
  surface-header: '#141414'
  outline: '#1f1f1f'
  outline-strong: '#262626'
  input: '#404040'
  on-background: '#fafafa'
  on-surface: '#a3a3a3'
  on-surface-muted: '#858585'
  primary: '#fafafa'
  on-primary: '#0a0a0a'
  primary-soft: 'rgba(250,250,250,0.14)'
  success: 'oklch(0.78 0.14 150)'
  warning: 'oklch(0.82 0.13 85)'
  error: 'oklch(0.68 0.18 25)'
  info: 'oklch(0.75 0.11 240)'
typography:
  brand:
    fontFamily: Geist Pixel Square
    fontSize: 20px
    fontWeight: '400'
    lineHeight: normal
    letterSpacing: 0.04em
  stat-lg:
    fontFamily: Geist Pixel Square
    fontSize: 26px
    fontWeight: '400'
    lineHeight: 26px
    letterSpacing: 0.02em
  body-base:
    fontFamily: Geist Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 21px
    letterSpacing: '0'
  body-compact:
    fontFamily: Geist Sans
    fontSize: 13px
    fontWeight: '400'
    lineHeight: normal
    letterSpacing: '0'
  data:
    fontFamily: Geist Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: normal
    letterSpacing: '0'
  label-caps:
    fontFamily: Geist Mono
    fontSize: 10.5px
    fontWeight: '600'
    lineHeight: normal
    letterSpacing: 0.08em
rounded:
  compact: 4px
  badge: 5px
  sm: 6px
  DEFAULT: 8px
  overlay: 12px
spacing:
  unit: 4px
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 22px
  margin-mobile: 14px
  margin-desktop: 48px
---

# Design System: SF Ownership Desk

## 1. Visual Theme & Atmosphere

SF Ownership Desk is a "Salesforce ownership + pipeline desk for SoCal prospecting." Its visual language is a near-black, high-contrast operational console: quiet surfaces, fine borders, compact controls, and dense tabular data. Default Mono theme avoids decorative color. White communicates selection and primary action; gray depth separates working layers; semantic color appears only for feedback or destructive state.

Information order follows actual workflow. Compact header establishes **SF Ownership Desk** and switches between **Prospects** and **Pipeline**. Clickable KPI tiles provide immediate scope, filters narrow records, and sortable tables hold primary work. Record drawer, command bar, confirmation modal, and toast stack stay subordinate until invoked. Page is neither marketing surface nor card mosaic; it is a repeated-use desk built for scanning, comparison, and action.

Density is deliberate. Body text starts at `14px`; table text at `13px`; labels often sit between `10px` and `11px`. Spacing uses a recurring 4px-derived cadence, but source does not declare a formal spacing token scale. Corners remain restrained at `4px` to `8px` for routine controls and `12px` for temporary overlays.

## 2. Color Palette & Roles

### Primary Foundation

| Descriptive name | Source value | Role |
|---|---:|---|
| Absolute Black | `#000000` | Page background, inverse tab surface, selection canvas |
| Near-Black Surface | `#0a0a0a` | KPI tiles, table containers, drawer, command bar, modal |
| Raised Carbon | `#0f0f0f` | Hover surfaces, group rows, command footer |
| Header Charcoal | `#141414` | Sticky table headers, keycaps, compact counters |
| Hairline Graphite | `#1f1f1f` | Default borders and row separators |
| Strong Graphite | `#262626` | Active borders, elevated separators, avatar fills |
| Focus Graphite | `#404040` | Focused inputs and selected KPI borders |

Surfaces are flat by default. Elevation comes from one-step background changes and borders before shadow. Popovers alone use `0 16px 36px rgba(0,0,0,.45)`; toast uses a smaller `0 4px 12px rgba(0,0,0,.3)` shadow.

### Accent & Interactive

| Descriptive name | Source value | Role |
|---|---:|---|
| Signal White | `#fafafa` | Default accent, active chips, primary buttons, selected indicators, focus outline |
| Ink Contrast | `#0a0a0a` | Text and symbols placed on Signal White |
| Soft Signal | `rgba(250,250,250,.14)` | Input focus halo |
| Hover Veil | `rgba(255,255,255,.04)` | Row and ghost-control hover |
| Selected Veil | `rgba(255,255,255,.09)` | Selected rows and pressed surfaces |
| Outline Veil | `rgba(255,255,255,.1)` | Ghost buttons and compact controls |

Links stay white and underlined. Default underline is `rgba(255,255,255,.25)` and becomes Signal White on hover. Selection reverses to Signal White background with Ink Contrast text.

### Typography & Text Hierarchy

| Descriptive name | Source value | Role |
|---|---:|---|
| Primary Text | `#fafafa` | Names, values, titles, active controls |
| Secondary Text | `#a3a3a3` | Owners, supporting values, inactive controls |
| Tertiary Text | `#858585` | Metadata, labels, placeholders, empty values |

Muted text still meets hierarchy needs through value and font-family changes; no low-contrast decorative copy should compete with data.

### Functional States

Source defines functional states in OKLCH. Preserve these exact values; do not substitute invented hex approximations.

| Descriptive name | Source value | Role |
|---|---:|---|
| Operational Green | `oklch(.78 .14 150)` | Success toast indicator |
| Alert Amber | `oklch(.82 .13 85)` | Warning toast indicator |
| Destructive Red | `oklch(.68 .18 25)` | Error toast, destructive button, lost stage |
| Informational Blue | `oklch(.75 .11 240)` | Informational toast indicator |

Status meaning never depends on hue alone. **Owned**, **Open**, account status, stage text, counts, and toast copy remain visible.

### Shipped Theme Presets

Mono is canonical default. Alternate themes change foundation neutrals and one accent while preserving component structure and hierarchy.

| Theme | Background | Accent | Primary text |
|---|---:|---:|---:|
| Mono | `#000000` | `#fafafa` | `#fafafa` |
| Graphite | `oklch(.12 .008 250)` | `oklch(.8 .07 245)` | `oklch(.97 .004 250)` |
| Phosphor | `oklch(.11 .01 150)` | `oklch(.83 .19 148)` | `oklch(.96 .01 150)` |
| Amber | `oklch(.12 .008 65)` | `oklch(.8 .12 75)` | `oklch(.97 .005 75)` |
| Ember | `oklch(.11 .008 30)` | `oklch(.73 .16 38)` | `oklch(.97 .005 30)` |
| Cobalt | `oklch(.11 .012 255)` | `oklch(.74 .14 255)` | `oklch(.97 .005 255)` |
| Violet | `oklch(.11 .012 300)` | `oklch(.76 .13 300)` | `oklch(.97 .005 300)` |
| Jade | `oklch(.11 .008 180)` | `oklch(.81 .12 178)` | `oklch(.96 .006 180)` |
| Rose | `oklch(.11 .008 10)` | `oklch(.75 .13 12)` | `oklch(.97 .005 10)` |
| Paper (light) | `#f8f7f4` | `#a06524` | `#15171c` |

Paper is a complete light mode, not a lightened Mono approximation. It uses warm off-white surfaces (`#f8f7f4`, `#f4f3ef`, `#efede8`, `#e7e4dd`) and brown accent `#a06524`.

## 3. Typography Rules

### Font Families

- **Geist Sans**: primary UI face. Neutral, compact, and readable across controls, body copy, names, and modal text.
- **Geist Mono**: operational metadata. Used for labels, dates, amounts, square footage, email, owners, chips, keycaps, table headers, and command notes.
- **Geist Pixel Square**: signal face. Reserved for product name, KPI values, stage-group names, and empty states. Use sparingly; it marks system-level hierarchy rather than decoration.

All three fonts are embedded in shipped HTML. Preserve local font behavior when generating standalone output.

### Hierarchy & Weights

| Role | Family | Size | Weight | Tracking / line height |
|---|---|---:|---:|---|
| Product name | Geist Pixel Square | `20px` | `400` | `.04em`; normal line height |
| Mobile product name | Geist Pixel Square | `17px` | `400` | `.04em`; normal line height |
| KPI value | Geist Pixel Square | `26px` | `400` | `.02em`; `1` line height |
| Compact KPI value | Geist Pixel Square | `20px` | `400` | `.02em`; `1` line height |
| Drawer title | Geist Sans | `17px` | `600` | `-.01em`; inherited line height |
| Modal title | Geist Sans | `15px` | `600` | `-.01em`; inherited line height |
| Body | Geist Sans | `14px` | `400` | `0`; `1.5` line height |
| Table | Geist Sans | `13px` | `400` | `0`; inherited line height |
| Data value | Geist Mono | `12px` | `400` | `0`; inherited line height |
| Table label | Geist Mono | `10.5px` | `600` | `.08em`; uppercase |
| KPI label | Geist Mono | `10px` | `600` | `.09em`; uppercase |
| Badge / stage | Geist Mono | `9.5px` to `10px` | `600` | `.04em`; uppercase |

Use tabular numerals for table cells, money, square footage, probability, and KPI values. Do not apply display-scale typography inside compact panels or tables.

### Spacing Principles

Text rhythm is compact and data-led. Labels separate from values through uppercase, mono type, and tracking rather than large font-size jumps. KPI labels sit `9px` below values. Drawer metadata sits `3px` below item titles. Major working groups use `16px` to `22px` separation; rows use `10px` vertical padding.

## 4. Component Stylings

### Buttons

- **Primary**: Signal White fill, Ink Contrast text, transparent border, `6px` radius, `9px 14px` padding, `12.5px/600` Geist Sans.
- **Ghost**: transparent background, faint outline, Secondary Text. Hover adds Hover Veil and Primary Text.
- **Destructive**: transparent background with Destructive Red border and text. Hover adds a 14% error-color wash.
- **Compact icon / keyboard trigger**: transparent, `6px` radius, `7px 10px` padding, Geist Mono. Command trigger uses visible `⌘` and `K` keycaps.
- Pressed buttons scale to `.97`; KPI tiles scale to `.99`. Keep transitions near `120ms`.

### KPI Tiles & Containers

KPI tiles form a five-column grid and behave as filters in Prospects. Each uses Near-Black Surface, Hairline Graphite border, `8px` radius, and `15px 16px` padding. Active tile shifts to Raised Carbon, uses Focus Graphite border, and gains a 2px Signal White bottom bar. Pipeline KPI tiles present **Opportunities**, **Open**, **Open pipeline**, **Total value**, and **Open SF** without filter-selection decoration.

Primary tables use one full-width container with Near-Black Surface, 1px border, and `8px` radius. Avoid cards around each row or section. Horizontal scroll belongs inside table container.

### Navigation

Header aligns product block left and controls right. Product name pairs a square 9px Signal White dot with **SF Ownership Desk**; beneath it a Tertiary Text Geist Mono uppercase `11px` subtitle reports dataset provenance (record count and generated source file). **Prospects** and **Pipeline** use a compact segmented control: Header Charcoal track, 1px border, `6px` radius, 3px inset padding. Active tab switches to Absolute Black with Primary Text and inset outline. Each tab includes live count.

No sidebar or marketing navigation exists. Command bar provides cross-workflow navigation with groups **Navigate**, **Filter**, **Sort**, **Theme**, **Actions**, and **Help**.

### Inputs & Filters

Search input fills remaining toolbar width, uses Near-Black Surface, Strong Graphite border, `6px` radius, and `10px 36px` padding. Focus changes border to Focus Graphite and adds a 3px Soft Signal ring. Placeholder is **Search person, company, email, owner, domain...**

Filter chips are compact counted controls, not promotional pills: transparent background, faint outline, `6px` radius, `6px 11px` padding, uppercase `11px` Geist Mono. Active chip reverses to Signal White with Ink Contrast text. Shipped labels include **All**, **Owned**, **Open**, **Unassigned**, **Not found**, **Has contact owner**, **Open opp**, and **Upcoming task**.

### Data Tables

Prospects columns are **Person**, **Company**, **Owned**, **Account**, **Acct Owner**, **Contact Owner**, **Deals**, **Last Activity**, **Email**, and **Source**. Pipeline columns are **Opportunity**, **Account**, **Owner**, **Close**, **Amount**, **Size**, **Type**, and **Probability**. Pipeline adds its own counted filter chips — **All**, **Open**, **Closed** — using the same chip anatomy as Prospects.

Headers are sticky, uppercase Geist Mono at `10.5px/600`, with directional arrow shown only for active sort. Rows use `10px 14px` padding and 1px separators. Hover adds Hover Veil. Selected rows add Selected Veil; owned rows receive a 2px left Signal White marker.

Badges use `5px` radius, compact uppercase mono text, and explicit words. Owner avatars are `18px` squares with `4px` radius and initials. Empty tables render Geist Pixel Square uppercase copy plus an inline ghost **reset-filters** action button. Pipeline stage groups use Raised Carbon background, sticky group headers, a square 8px stage marker, count badge, and right-aligned amount / SF totals. Probability uses a 42px by 5px progress track plus numeric percentage.

### Record Drawer

Row activation opens a right-side drawer, `min(460px, 94vw)`, full viewport height. Near-Black Surface, left border, and blurred dark scrim separate it from table. Header shows person and company; body uses key/value rows (including compact ghost link buttons that open matched Salesforce accounts, and a review-candidates row when matching was ambiguous) followed by real record sections: **Opportunities**, **Upcoming / open tasks**, and **Recent activity**, each with a count chip. Footer actions are **Copy email**, **Copy company**, and **Copy summary**.

Drawer enters over `250ms` with `cubic-bezier(.16,1,.3,1)`. On mobile it becomes `100vw`.

### Command Bar, Modal & Toasts

Command bar sits at 18% viewport height, up to `640px` wide and `70dvh` tall. It uses a `12px` radius, blurred overlay, popover shadow, 48px input row, 40px result rows, and 28px footer. Selected command uses Selected Veil. Footer exposes **navigate**, **run**, and **close** key hints plus a live command count. Empty state reads **No matching commands**. Opens via `⌘K` or the Scroll-style `⌘;`.

Command groups ship as **Navigate**, **Filter**, **Sort**, **Theme**, **Actions**, and **Help**. Filter commands carry live counts as right-aligned mono notes; sort commands show current direction. Highlighting a theme command **live-previews that theme immediately** — the page re-tokens under the highlight and reverts to the saved theme when selection moves away or the bar closes. Actions include **Export current view as CSV**, **Copy visible emails**, **Copy visible summary**, **Copy selected row email**, **Open all visible accounts in Salesforce**, and the destructive **Reset workspace**.

Confirmation modal uses same overlay radius and shadow. It distinguishes normal, destructive, and help states through badge and button treatment. Workspace reset copy must preserve source meaning: saved filters, sort, theme, and view state are cleared; underlying data remains untouched. A single-button **help** variant lists keyboard shortcuts as key/label rows with keycaps: `⌘K` / `⌘;` command bar, `/` search, `j`/`k` row navigation, `↵` details, `o` open in Salesforce, `c` copy row email, `g p` / `g o` view switching, `t` cycle theme, `?` help, `esc` close.

Toasts stack bottom-center, max four visible; older toasts evict as new ones arrive. Dark translucent fill, 1px outline, 12px backdrop blur, and 8px square semantic indicator provide feedback. Toasts enter upward over `250ms`, exit downward over `200ms`, auto-dismiss after `2.6s` by default, and dismiss on click.

## 5. Layout Principles

### Grid & Structure

- Content wrapper: fluid width, centered, capped at `2560px`.
- Page padding: top and horizontal use `clamp(16px, 2vw, 40px)` and `clamp(14px, 2.4vw, 48px)`; bottom is `90px`.
- Header: flex row with wrap, bottom-aligned content, `20px` gap, `22px` bottom margin.
- KPI grid: five equal columns with `9px` to `14px` fluid gaps.
- Toolbars: wrapping flex rows with `12px` gaps and `16px` bottom margin.
- Tables: full-width, collapsed borders, horizontal overflow when needed.

### Whitespace Strategy

Use compact operational spacing. Routine control gaps fall between `3px` and `12px`; content padding between `10px` and `22px`; major blocks separate by `16px` to `22px`. Do not introduce large hero gaps, floating section cards, or decorative empty bands.

### Alignment & Visual Balance

Left-align labels and table values for scan speed. Keep numeric values tabular and stage totals right-aligned within group rows. Header balances short identity block against tabs and command trigger. Drawers and overlays preserve table context instead of replacing page.

### Responsive Behavior & Touch

- `1100px`: KPI grid collapses from five columns to three.
- `960px`: medium-priority columns hide; first table column becomes sticky; table cell padding tightens.
- `680px`: small-priority columns hide; command bar moves to 8% viewport height and becomes `94vw`.
- `640px`: KPI grid becomes two columns; tabs span full width; search spans toolbar; drawer becomes full viewport width; typography and padding compact.
- `520px`: lowest-priority columns hide.
- `400px`: two-column KPI grid remains; bottom page padding falls to `60px`.
- `1800px` and `2200px`: table typography and cell spacing increase so wide displays remain dense rather than sparse.

Scrollbar chrome is hidden globally except inside working scroll regions — table containers, drawer body, and command list show a thin `8px` themed scrollbar (Focus Graphite thumb on Raised Carbon track). Long person and company cells ellipsize with fixed max-widths that tighten at each breakpoint. Coarse-pointer devices get `44px` minimum touch targets on all controls. Preserve `:focus-visible` outline, dialog semantics, focus trapping in overlays, `aria-live` toast region, keyboard navigation, and `prefers-reduced-motion` override.

## 6. Design System Notes for Stitch Generation

### Language to Use

Use: operational, monochrome, near-black, high-contrast, compact, tabular, keyboard-driven, sortable, data-dense, precise, restrained, Salesforce-connected, pipeline-focused.

Avoid: marketing hero, feature cards, illustration, gradient decoration, oversized headings, rounded pills, soft lifestyle imagery, ornamental color, invented statistics, placeholder prospects, or sample activities.

### Color References

Start every screen in Mono: Absolute Black background, Near-Black surfaces, Graphite borders, Signal White accent, three-level neutral text. Apply functional OKLCH colors only to feedback and destructive state. Alternate themes must swap token values without changing layout or component anatomy.

### Component Prompts

1. **Prospects view:** "Create SF Ownership Desk Prospects view as dense near-black operational table. Compact header with SF Ownership Desk, Prospects / Pipeline segmented control, and command-bar key trigger. Lead with five clickable KPI tiles: Prospects, Owned, Open, Unassigned region, Not found. Follow with real search and counted source/status filters, then sticky sortable columns Person, Company, Owned, Account, Acct Owner, Contact Owner, Deals, Last Activity, Email, Source. Use Geist Sans, Geist Mono, Geist Pixel Square; 8px maximum routine radius; no decorative cards."

2. **Pipeline view:** "Create SF Ownership Desk Pipeline view using same shell. Lead with Opportunities, Open, Open pipeline, Total value, Open SF KPIs (non-interactive), then All / Open / Closed counted filter chips. Group opportunity rows by stage and sort by close date. Show group count plus amount and SF totals. Columns: Opportunity, Account, Owner, Close, Amount, Size, Type, Probability. Use square stage markers, compact type badges, tabular money/SF, and a 42px probability bar."

3. **Command bar and detail flow:** "Add centered SF DESK command bar with Navigate, Filter, Sort, Theme, Actions, Help groups; live selected-row treatment; key hints; Mono through Paper theme choices with instant live preview on highlight. Actions cover CSV export, copy visible emails / summary, open all visible Salesforce accounts, and workspace reset. Row activation opens full-height right record drawer with Opportunities, Upcoming / open tasks, Recent activity and copy actions. Confirmation modal handles workspace reset and a keyboard-shortcut help sheet; bottom-center toasts report results."

### Incremental Iteration

1. Establish Mono foundation, typography, wrapper, header, and view tabs.
2. Build KPI and toolbar density before table details.
3. Add Prospects table, then Pipeline stage grouping and totals.
4. Add drawer, command bar, modal, and toast layers using shipped z-order: drawer `40`, command bar `50`, modal `55`, toast `60`.
5. Apply responsive column priority and sticky first-column behavior.
6. Add alternate theme tokens last. Validate structure remains unchanged across all themes.

Always populate generated screens from current product data. When live data is unavailable, omit record rows rather than inventing people, companies, emails, amounts, dates, or activity copy.
