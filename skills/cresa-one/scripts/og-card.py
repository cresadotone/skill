#!/usr/bin/env python3
"""Render a 1200x630 Open Graph card that matches the site's own design tokens.

Fills templates/og-card.html (or a fully custom --html card) and screenshots it with
Playwright. Exit code 3 means Playwright or a browser is unavailable, so the caller can fall
back to og-image.py.
"""

from __future__ import annotations

import argparse
import base64
import html
import re
import sys
import tempfile
from pathlib import Path

DEFAULT_TOKENS = {
    "bg": "#0a0a0a",
    "panel": "#141414",
    "hairline": "#2a2a2a",
    "ink": "#f5f5f5",
    "muted": "#9a9a9a",
    "primary": "#f5f5f5",
    "signal": "#f5f5f5",
}


def parse_tokens(raw: str) -> dict[str, str]:
    """Parse "bg=#000;ink=oklch(0.95 0.01 110)" into a token map."""
    tokens = dict(DEFAULT_TOKENS)
    for pair in filter(None, (p.strip() for p in raw.split(";"))):
        key, _, value = pair.partition("=")
        key = key.strip().lower()
        if key not in tokens or not value.strip():
            raise SystemExit(f"error: unknown or empty token '{pair}'. Valid: {', '.join(tokens)}")
        if re.search(r"[{}<>]|url\s*\(", value, flags=re.I):
            raise SystemExit("error: tokens must be CSS colors")
        tokens[key] = value.strip()
    return tokens


def font_face(font_file: Path | None) -> str:
    if font_file is None:
        return ""
    kind = {"woff2": "woff2", "woff": "woff", "ttf": "truetype", "otf": "opentype"}.get(
        font_file.suffix.lstrip(".").lower(), "woff2"
    )
    data = base64.b64encode(font_file.read_bytes()).decode("ascii")
    return (
        '@font-face { font-family: "OG Card"; font-weight: 100 900; '
        f'src: url("data:font/{kind};base64,{data}") format("{kind}"); }}'
    )


def fill_template(args: argparse.Namespace) -> str:
    template = (Path(__file__).resolve().parent.parent / "templates" / "og-card.html").read_text("utf-8")
    tokens = parse_tokens(args.tokens)
    art = args.art.read_text("utf-8") if args.art else ""
    values = {
        "NAME": html.escape(args.name),
        "HEADLINE": html.escape(args.headline),
        "HEADLINE_MUTED": html.escape(args.headline_muted),
        "FOOTER": html.escape(args.footer),
        "ART": art,
        "FONT_FACE": font_face(args.font_file),
        "BODY_CLASS": "with-art" if art else "no-art",
        **{key.upper(): value for key, value in tokens.items()},
    }
    return re.sub(r"\{\{([A-Z_]+)\}\}", lambda m: values.get(m[1], m[0]), template)


def render(card_html: Path, out: Path) -> int:
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("og-card: playwright is not installed", file=sys.stderr)
        return 3
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch()
        except Exception as error:
            print(f"og-card: browser unavailable ({error})", file=sys.stderr)
            return 3
        try:
            page = browser.new_page(viewport={"width": 1200, "height": 630})
            # Cards are local artifacts; prevent remote requests from HTML/SVG.
            page.route(re.compile(r"^https?://"), lambda route: route.abort())
            page.goto(card_html.resolve().as_uri(), wait_until="load")
            page.evaluate("document.fonts.ready")
            out.parent.mkdir(parents=True, exist_ok=True)
            page.screenshot(path=str(out), type="png", animations="disabled")
        except Exception as error:
            print(f"og-card: rendering failed ({error})", file=sys.stderr)
            return 2
        finally:
            browser.close()
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, required=True, help="Output PNG path")
    parser.add_argument("--html", type=Path, help="Fully custom 1200x630 card; skips the template")
    parser.add_argument("--name", default="", help="Site or product name")
    parser.add_argument("--headline", default="", help="Main line, in the ink colour")
    parser.add_argument("--headline-muted", default="", help="Continuation of the headline, in the muted colour")
    parser.add_argument("--footer", default="", help="Usually the site host")
    parser.add_argument("--tokens", default="", help='e.g. "bg=#0b0c0a;panel=#14150f;ink=#f0f1e8;muted=#a9ab9f;primary=#d3d95a;signal=#ee9155;hairline=#2c2d26"')
    parser.add_argument("--art", type=Path, help="Optional inline SVG file for the right panel")
    parser.add_argument("--font-file", type=Path, help="Optional woff2/woff/ttf/otf to embed")
    args = parser.parse_args()

    if args.html is not None:
        if not args.html.is_file():
            raise SystemExit(f"error: {args.html} not found")
        return render(args.html, args.out)
    if not args.headline and not args.name:
        raise SystemExit("error: pass --name and --headline, or a custom --html card")

    with tempfile.TemporaryDirectory() as tmp:
        card = Path(tmp) / "card.html"
        card.write_text(fill_template(args), encoding="utf-8")
        return render(card, args.out)


if __name__ == "__main__":
    sys.exit(main())
