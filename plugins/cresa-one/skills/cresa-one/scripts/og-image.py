#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10.1"]
# ///
"""Generate thumbnail-readable 1200x630 Open Graph card candidates.

Cards follow the SF Ownership Desk design system shipped in templates/DESIGN.md:
absolute-black canvas, near-black surfaces, graphite hairlines, signal-white
accents, three-level neutral text, square markers, and mono metadata — so share
previews match the apps and dashboards built from templates/app-template.html.
"""

from __future__ import annotations

import argparse
import os
from functools import lru_cache
from pathlib import Path
from typing import Callable

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps


WIDTH, HEIGHT = 1200, 630
THUMB_SIZE = (360, 189)
AUX_LABEL_SIZE = 18
AUX_SIGNAL_SIZE = 20
AUX_FOOTER_SIZE = 18

# SF Ownership Desk tokens (templates/DESIGN.md)
BLACK = (0, 0, 0)          # Absolute Black — page background
SURFACE = (10, 10, 10)     # Near-Black Surface — tiles, panels
RAISED = (15, 15, 15)      # Raised Carbon — hover surfaces
HEADER = (20, 20, 20)      # Header Charcoal — keycaps, badges, grid
HAIRLINE = (31, 31, 31)    # Hairline Graphite — default borders
STRONG = (38, 38, 38)      # Strong Graphite — active borders
FOCUS = (64, 64, 64)       # Focus Graphite — focused/selected borders
INK = (250, 250, 250)      # Signal White — primary text and accent
MUTED = (163, 163, 163)    # Secondary Text
FAINT = (133, 133, 133)    # Tertiary Text

BOLD_FONTS = (
    "Geist-Bold.otf",
    "Geist-Bold.ttf",
    "Geist-SemiBold.otf",
    "Arial Bold.ttf",
    "arialbd.ttf",
    "DejaVuSans-Bold.ttf",
    "LiberationSans-Bold.ttf",
)
REGULAR_FONTS = (
    "Geist-Regular.otf",
    "Geist-Regular.ttf",
    "Arial.ttf",
    "arial.ttf",
    "Helvetica.ttc",
    "DejaVuSans.ttf",
    "LiberationSans-Regular.ttf",
)
MONO_FONTS = (
    "GeistMono-Regular.otf",
    "GeistMono-Regular.ttf",
    "SFNSMono.ttf",
    "Menlo.ttc",
    "consola.ttf",
    "DejaVuSansMono.ttf",
    "LiberationMono-Regular.ttf",
)


def font_roots() -> tuple[Path, ...]:
    roots = [
        Path("/System/Library/Fonts"),
        Path("/System/Library/Fonts/Supplemental"),
        Path("/Library/Fonts"),
        Path.home() / "Library/Fonts",
        Path("/usr/share/fonts/truetype/dejavu"),
        Path("/usr/share/fonts/truetype/liberation2"),
        Path("/usr/local/share/fonts"),
    ]
    if windir := os.environ.get("WINDIR"):
        roots.append(Path(windir) / "Fonts")
    return tuple(roots)


@lru_cache(maxsize=None)
def resolve_font_path(candidates: tuple[str, ...]) -> Path | None:
    for root in font_roots():
        for name in candidates:
            path = root / name
            if path.is_file():
                return path
    return None


def load_font(candidates: tuple[str, ...], size: int) -> ImageFont.ImageFont:
    path = resolve_font_path(candidates)
    if path is not None:
        return ImageFont.truetype(path, size=size)
    return ImageFont.load_default(size=size)


def text_width(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.ImageFont) -> int:
    left, _, right, _ = draw.textbbox((0, 0), text, font=font)
    return right - left


def fit_font(
    draw: ImageDraw.ImageDraw,
    text: str,
    candidates: tuple[str, ...],
    start: int,
    minimum: int,
    max_width: int,
) -> ImageFont.ImageFont:
    for size in range(start, minimum - 1, -1):
        candidate = load_font(candidates, size)
        if text_width(draw, text, candidate) <= max_width:
            return candidate
    raise ValueError(f"text does not fit at minimum {minimum}px: {text!r}")


def wrap_lines(
    draw: ImageDraw.ImageDraw,
    text: str,
    font: ImageFont.ImageFont,
    max_width: int,
    max_lines: int = 2,
) -> list[str]:
    if not text:
        return []
    lines: list[str] = []
    current = ""
    for word in text.split():
        candidate = word if not current else f"{current} {word}"
        if text_width(draw, candidate, font) <= max_width:
            current = candidate
            continue
        if not current or len(lines) + 1 >= max_lines:
            raise ValueError(f"text needs more than {max_lines} lines: {text!r}")
        lines.append(current)
        current = word
    if current:
        lines.append(current)
    if any(text_width(draw, line, font) > max_width for line in lines):
        raise ValueError(f"text contains a word wider than layout: {text!r}")
    return lines


def base_canvas() -> Image.Image:
    image = Image.new("RGBA", (WIDTH, HEIGHT), BLACK + (255,))
    draw = ImageDraw.Draw(image)
    for x in range(0, WIDTH, 60):
        draw.line((x, 0, x, HEIGHT), fill=HEADER + (255,), width=1)
    for y in range(0, HEIGHT, 60):
        draw.line((0, y, WIDTH, y), fill=HEADER + (255,), width=1)
    return image


def prepare_photo(path: Path, size: tuple[int, int], centering=(0.5, 0.48)) -> Image.Image:
    with Image.open(path) as source:
        photo = ImageOps.exif_transpose(source).convert("RGB")
    gray = ImageOps.grayscale(photo)
    gray = ImageEnhance.Contrast(gray).enhance(1.12)
    fitted = ImageOps.fit(gray, size, method=Image.Resampling.LANCZOS, centering=centering)
    return fitted.convert("RGBA")


def fade_edge(layer: Image.Image, edge: str, fade_width: int = 170) -> Image.Image:
    alpha = Image.new("L", layer.size, 255)
    pixels = alpha.load()
    for offset in range(min(fade_width, layer.width)):
        value = int(255 * (offset / fade_width) ** 1.5)
        x = offset if edge == "left" else layer.width - 1 - offset
        for y in range(layer.height):
            pixels[x, y] = value
    faded = layer.copy()
    faded.putalpha(alpha)
    return faded


def draw_photo_placeholder(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    draw.rectangle(box, fill=SURFACE, outline=HAIRLINE, width=2)
    for inset in (28, 70, 112):
        if right - left > inset * 2 and bottom - top > inset * 2:
            draw.rectangle(
                (left + inset, top + inset, right - inset, bottom - inset),
                outline=STRONG,
                width=2,
            )
    center_x = (left + right) // 2
    center_y = (top + bottom) // 2
    marker = 8
    draw.rectangle(
        (center_x - marker, center_y - marker, center_x + marker, center_y + marker),
        fill=INK,
    )


def draw_label(draw: ImageDraw.ImageDraw, x: int, y: int, text: str, scale: float) -> None:
    if not text:
        return
    label_font = load_font(MONO_FONTS, round(AUX_LABEL_SIZE * scale))
    width = text_width(draw, text, label_font)
    height = round(34 * scale)
    draw.rounded_rectangle(
        (x, y, x + width + round(34 * scale), y + height),
        radius=round(6 * scale),
        fill=HEADER,
        outline=HAIRLINE,
    )
    dot = round(8 * scale)
    dot_x = x + round(12 * scale)
    dot_y = y + (height - dot) // 2
    draw.rectangle((dot_x, dot_y, dot_x + dot, dot_y + dot), fill=INK)
    draw.text((x + round(28 * scale), y + round(7 * scale)), text, font=label_font, fill=MUTED)


def draw_aux_lines(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    text: str,
    max_width: int,
    scale: float,
    fill=MUTED,
) -> None:
    if not text:
        return
    aux_font = load_font(MONO_FONTS, round(AUX_SIGNAL_SIZE * scale))
    for index, line in enumerate(wrap_lines(draw, text, aux_font, max_width)):
        draw.text((x, y + index * round(30 * scale)), line, font=aux_font, fill=fill)


def draw_footer(draw: ImageDraw.ImageDraw, x: int, y: int, text: str, scale: float) -> None:
    if text:
        draw.text((x, y), text, font=load_font(MONO_FONTS, round(AUX_FOOTER_SIZE * scale)), fill=FAINT)


def draw_identity(
    draw: ImageDraw.ImageDraw,
    args: argparse.Namespace,
    x: int,
    title_y: int,
    max_width: int,
    title_start: int,
    subtitle_y: int,
) -> None:
    title_font = fit_font(draw, args.title, BOLD_FONTS, round(title_start * args.scale), 44, max_width)
    draw.text((x, title_y), args.title, font=title_font, fill=INK, stroke_width=1, stroke_fill=INK)
    if args.subtitle:
        subtitle_font = load_font(REGULAR_FONTS, round(40 * args.scale))
        for index, line in enumerate(wrap_lines(draw, args.subtitle, subtitle_font, max_width)):
            draw.text((x + 4, subtitle_y + index * round(48 * args.scale)), line, font=subtitle_font, fill=MUTED)


def render_editorial_right(args: argparse.Namespace) -> Image.Image:
    image = base_canvas()
    if args.photo:
        image.alpha_composite(fade_edge(prepare_photo(args.photo, (500, HEIGHT)), "left", 180), (700, 0))
    else:
        draw_photo_placeholder(ImageDraw.Draw(image), (760, 60, 1140, 570))
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, 6, HEIGHT), fill=INK)
    draw_label(draw, 64, 62, args.label, args.scale)
    draw_identity(draw, args, 62, 145, 680, 106, 276)
    draw.line((66, 396, 440, 396), fill=INK, width=2)
    draw_aux_lines(draw, 66, 430, args.signal, 620, args.scale)
    draw_footer(draw, 66, 558, args.footer, args.scale)
    return image


def render_split_left(args: argparse.Namespace) -> Image.Image:
    image = base_canvas()
    if args.photo:
        image.alpha_composite(fade_edge(prepare_photo(args.photo, (510, HEIGHT)), "right", 145), (0, 0))
    else:
        draw_photo_placeholder(ImageDraw.Draw(image), (50, 60, 450, 570))
    draw = ImageDraw.Draw(image)
    draw.line((475, 48, 475, HEIGHT - 48), fill=HAIRLINE, width=1)
    draw_label(draw, 520, 62, args.label, args.scale)
    draw_identity(draw, args, 518, 146, 620, 92, 266)
    draw.line((522, 374, 878, 374), fill=INK, width=2)
    draw_aux_lines(draw, 522, 411, args.signal, 610, args.scale, INK)
    draw_footer(draw, 522, 558, args.footer, args.scale)
    return image


def render_portrait_ring(args: argparse.Namespace) -> Image.Image:
    image = base_canvas()
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, WIDTH, 4), fill=INK)
    draw_label(draw, 64, 62, args.label, args.scale)
    draw_identity(draw, args, 62, 154, 730, 112, 294)
    draw.line((66, 410, 500, 410), fill=INK, width=2)
    draw_aux_lines(draw, 66, 450, args.signal, 700, args.scale)
    draw_footer(draw, 66, 558, args.footer, args.scale)

    panel_size = 334
    panel = Image.new("RGBA", (panel_size, panel_size), (0, 0, 0, 0))
    panel_draw = ImageDraw.Draw(panel)
    panel_draw.rounded_rectangle(
        (0, 0, panel_size - 1, panel_size - 1), radius=12, fill=SURFACE, outline=STRONG, width=2
    )
    inset = 10
    if args.photo:
        inner = prepare_photo(
            args.photo, (panel_size - inset * 2, panel_size - inset * 2), centering=(0.5, 0.42)
        )
        mask = Image.new("L", inner.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, inner.width - 1, inner.height - 1), radius=6, fill=255)
        inner.putalpha(mask)
        panel.alpha_composite(inner, (inset, inset))
    else:
        draw_photo_placeholder(panel_draw, (22, 22, panel_size - 22, panel_size - 22))
    panel_draw.rectangle((inset, panel_size - inset - 2, panel_size - inset, panel_size - inset), fill=INK)
    image.alpha_composite(panel, (815, 142))
    return image


def save_candidate(image: Image.Image, out_dir: Path, layout: str) -> tuple[Path, Path]:
    full_path = out_dir / f"og_{layout}.png"
    thumb_path = out_dir / f"og_{layout}_thumb.png"
    rgb = image.convert("RGB")
    rgb.save(full_path, "PNG", optimize=True)
    rgb.resize(THUMB_SIZE, Image.Resampling.LANCZOS).save(thumb_path, "PNG", optimize=True)
    return full_path, thumb_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--title", required=True, help="Primary name or headline")
    parser.add_argument("--subtitle", default="", help="Role or supporting line")
    parser.add_argument("--label", default="", help="Small pill label")
    parser.add_argument("--signal", default="", help="Auxiliary signal line")
    parser.add_argument("--footer", default="", help="Footer or URL")
    parser.add_argument("--photo", type=Path, help="Optional user-provided identity image")
    parser.add_argument("--out", type=Path, required=True, help="Output directory")
    parser.add_argument(
        "--layout",
        choices=("editorial-right", "split-left", "portrait-ring", "all"),
        default="all",
    )
    parser.add_argument("--scale", type=float, default=1.0, help="Typography scale; must be at least 1.0")
    args = parser.parse_args()
    if args.scale < 1.0:
        parser.error("--scale below 1.0 would violate 18px/20px/18px auxiliary text floors")
    if args.photo and not args.photo.is_file():
        parser.error(f"--photo does not exist or is not a file: {args.photo}")
    return args


def main() -> None:
    args = parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    renderers: dict[str, Callable[[argparse.Namespace], Image.Image]] = {
        "editorial-right": render_editorial_right,
        "split-left": render_split_left,
        "portrait-ring": render_portrait_ring,
    }
    layouts = tuple(renderers) if args.layout == "all" else (args.layout,)
    for layout in layouts:
        for path in save_candidate(renderers[layout](args), args.out, layout.replace("-", "_")):
            print(path)


if __name__ == "__main__":
    main()
