#!/usr/bin/env python3
"""Write one managed block of site metadata into an HTML file's <head>, in place.

Idempotent: a previous managed block is replaced, and any hand-written duplicates of the
tags it owns (title, description, keywords, robots, canonical, og:*, twitter:*) are removed
so the page never carries two competing values.

Exit codes: 0 ok, 2 bad input.
"""

from __future__ import annotations

import argparse
import html
import json
import re
import sys
from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import quote, urlsplit

START = "<!-- cresa-one:meta:start (managed by ship.sh; edit flags, not this block) -->"
END = "<!-- cresa-one:meta:end -->"

OWNED_META_NAMES = {
    "description",
    "keywords",
    "robots",
    "referrer",
    "author",
    "application-name",
    "apple-mobile-web-app-title",
}


def esc(value: str) -> str:
    """Escape text for a double-quoted HTML attribute."""
    return html.escape(value, quote=True)


class HeadTags(HTMLParser):
    """Read tag spans without mistaking JavaScript or comments for markup."""

    def __init__(self, source: str):
        super().__init__(convert_charrefs=False)
        self.source = source
        self.lines = [0]
        self.lines.extend(m.end() for m in re.finditer("\n", source))
        self.removals: list[tuple[int, int]] = []
        self.block: tuple[str, int] | None = None
        self.has_icon = False
        self.has_theme = False
        self.anchor: int | None = None
        self.charset: int | None = None
        self.feed(source)

    def source_offset(self) -> int:
        line, column = self.getpos()
        return self.lines[line - 1] + column

    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        start = self.source_offset()
        end = start + len(self.get_starttag_text())
        name = (values.get("name") or values.get("property") or "").lower()
        rels = (values.get("rel") or "").lower().split()
        if tag == "title" or (tag == "script" and
                values.get("type", "").lower() == "application/ld+json" and "data-cresa-one" in values):
            self.block = (tag, start)
        elif tag == "meta" and (name in OWNED_META_NAMES or name.startswith(("og:", "twitter:"))):
            self.removals.append((start, end))
        elif tag == "link" and "canonical" in rels:
            self.removals.append((start, end))
        if tag == "link" and any("icon" in rel for rel in rels):
            self.has_icon = True
        if tag == "meta":
            self.has_theme |= name == "theme-color"
            if name == "viewport":
                self.anchor = end
            if "charset" in values:
                self.charset = end

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag):
        if self.block and self.block[0] == tag:
            end = self.source.index(">", self.source_offset()) + 1
            self.removals.append((self.block[1], end))
            self.block = None


def strip_owned(head: str) -> str:
    """Replace managed metadata while preserving scripts, comments and appearance."""
    head = re.sub(
        r"(?:\r?\n[ \t]*)?<!--\s*cresa-one:meta:start\b.*?<!--\s*cresa-one:meta:end\s*-->",
        "", head, flags=re.S,
    )
    for start, end in sorted(HeadTags(head).removals, reverse=True):
        head = head[:start] + head[end:]
    return head


def favicon_data_uri(letter: str, bg: str, fg: str) -> str:
    """Small monogram favicon for pages that ship without an icon."""
    svg = (
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'>"
        f"<rect width='32' height='32' rx='7' fill='{html.escape(bg, quote=True)}'/>"
        f"<text x='16' y='22.5' text-anchor='middle' font-family='system-ui,sans-serif' "
        f"font-size='19' font-weight='700' fill='{html.escape(fg, quote=True)}'>{html.escape(letter)}</text></svg>"
    )
    return "data:image/svg+xml," + quote(svg, safe="/:=' ")


def build_block(args: argparse.Namespace, has_icon: bool, has_theme_color: bool) -> str:
    """Assemble the managed block."""
    url = args.url.rstrip("/") + "/"
    image_url = url.rstrip("/") + "/" + args.og_image.lstrip("/") if args.og_image else ""
    site_name = args.site_name or args.title.split(" – ")[0].split(" - ")[0].split(" | ")[0]
    og_desc = args.og_description or args.description
    private = args.privacy == "private"

    lines = [
        START,
        f"<title>{html.escape(args.title)}</title>",
        f'<meta name="description" content="{esc(args.description)}" />',
    ]
    if args.keywords:
        lines.append(f'<meta name="keywords" content="{esc(args.keywords)}" />')
    lines.append(f'<meta name="application-name" content="{esc(site_name)}" />')
    lines.append(f'<meta name="apple-mobile-web-app-title" content="{esc(site_name)}" />')
    if args.author:
        lines.append(f'<meta name="author" content="{esc(args.author)}" />')
    lines.append(f'<link rel="canonical" href="{esc(url)}" />')
    if private:
        lines.append('<meta name="robots" content="noindex, nofollow, noarchive" />')
        lines.append('<meta name="referrer" content="no-referrer" />')
    else:
        lines.append('<meta name="robots" content="index, follow, max-image-preview:large" />')
    if args.theme_color and not has_theme_color:
        lines.append(f'<meta name="theme-color" content="{esc(args.theme_color)}" />')
    if not has_icon and args.favicon == "auto":
        icon = favicon_data_uri(site_name[:1].upper() or "C", args.theme_color or "#111111", "#ffffff")
        lines.append(f'<link rel="icon" type="image/svg+xml" href="{esc(icon)}" />')

    lines += [
        f'<meta property="og:type" content="{esc(args.og_type)}" />',
        f'<meta property="og:site_name" content="{esc(site_name)}" />',
        f'<meta property="og:title" content="{esc(args.title)}" />',
        f'<meta property="og:description" content="{esc(og_desc)}" />',
        f'<meta property="og:url" content="{esc(url)}" />',
        f'<meta property="og:locale" content="{esc(args.locale)}" />',
    ]
    if image_url:
        alt = args.og_image_alt or args.title
        mime = "image/jpeg" if image_url.lower().endswith((".jpg", ".jpeg")) else "image/png"
        lines += [
            f'<meta property="og:image" content="{esc(image_url)}" />',
            f'<meta property="og:image:secure_url" content="{esc(image_url)}" />',
            f'<meta property="og:image:type" content="{mime}" />',
            f'<meta property="og:image:width" content="{args.og_width}" />',
            f'<meta property="og:image:height" content="{args.og_height}" />',
            f'<meta property="og:image:alt" content="{esc(alt)}" />',
        ]
    lines += [
        f'<meta name="twitter:card" content="{"summary_large_image" if image_url else "summary"}" />',
        f'<meta name="twitter:title" content="{esc(args.title)}" />',
        f'<meta name="twitter:description" content="{esc(og_desc)}" />',
    ]
    if image_url:
        lines.append(f'<meta name="twitter:image" content="{esc(image_url)}" />')
        lines.append(f'<meta name="twitter:image:alt" content="{esc(args.og_image_alt or args.title)}" />')

    if args.json_ld != "none":
        data = {
            "@context": "https://schema.org",
            "@type": args.json_ld,
            "name": site_name,
            "url": url,
            "description": args.description,
        }
        if image_url:
            data["image"] = image_url
        if args.json_ld == "WebApplication":
            data["operatingSystem"] = "Any"
            if args.app_category:
                data["applicationCategory"] = args.app_category
        payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
        lines.append(f'<script type="application/ld+json" data-cresa-one>{payload}</script>')

    lines.append(END)
    return "\n    ".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--html", type=Path, required=True)
    parser.add_argument("--url", required=True, help="Canonical site URL, e.g. https://my-site.cresa.one/")
    parser.add_argument("--title", required=True)
    parser.add_argument("--description", required=True)
    parser.add_argument("--og-description", default="", help="Shorter preview copy; defaults to --description")
    parser.add_argument("--keywords", default="")
    parser.add_argument("--site-name", default="")
    parser.add_argument("--author", default="")
    parser.add_argument("--theme-color", default="")
    parser.add_argument("--og-image", default="/og.png", help="Site-relative path; empty string for none")
    parser.add_argument("--og-image-alt", default="")
    parser.add_argument("--og-width", type=int, default=1200)
    parser.add_argument("--og-height", type=int, default=630)
    parser.add_argument("--og-type", default="website")
    parser.add_argument("--locale", default="en_US")
    parser.add_argument("--privacy", choices=("private", "public"), default="private")
    parser.add_argument("--json-ld", choices=("WebApplication", "WebSite", "none"), default="WebSite")
    parser.add_argument("--app-category", default="")
    parser.add_argument("--favicon", choices=("auto", "none"), default="auto")
    args = parser.parse_args()

    if not args.html.is_file():
        print(f"error: {args.html} not found", file=sys.stderr)
        return 2
    url = urlsplit(args.url)
    if url.scheme not in {"https", "http"} or not url.hostname or url.username or url.password:
        parser.error("--url must be an HTTP(S) URL without credentials")
    source = args.html.read_text(encoding="utf-8")
    match = re.search(r"(<head\b[^>]*>)(.*?)(</head>)", source, flags=re.S | re.I)
    if match is None:
        print("error: no <head> element; metadata needs an HTML document", file=sys.stderr)
        return 2

    head = strip_owned(match.group(2))
    tags = HeadTags(head)
    block = build_block(args, tags.has_icon, tags.has_theme)
    anchor = tags.anchor if tags.anchor is not None else tags.charset
    if anchor is None:
        anchor = 0
    head = head[:anchor] + "\n    " + block + head[anchor:]

    args.html.write_text(source[: match.start(2)] + head + source[match.end(2) :], encoding="utf-8")

    warnings = []
    if len(args.title) > 60:
        warnings.append(f"title is {len(args.title)} chars; previews truncate near 60")
    if not 50 <= len(args.description) <= 200:
        warnings.append(f"description is {len(args.description)} chars; aim for 50 to 200")
    print(json.dumps({"ok": True, "privacy": args.privacy, "warnings": warnings}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
