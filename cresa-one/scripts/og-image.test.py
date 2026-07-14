#!/usr/bin/env python3
"""Offline smoke tests for og-image.py."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw


SCRIPT = Path(__file__).with_name("og-image.py")


def run(*args: str, expect: int = 0) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != expect:
        raise AssertionError(
            f"expected exit {expect}, got {result.returncode}\nstdout:\n{result.stdout}\nstderr:\n{result.stderr}"
        )
    return result


def assert_image(path: Path, size: tuple[int, int]) -> None:
    assert path.is_file(), path
    with Image.open(path) as image:
        assert image.format == "PNG", (path, image.format)
        assert image.mode == "RGB", (path, image.mode)
        assert image.size == size, (path, image.size)


def main() -> None:
    with tempfile.TemporaryDirectory() as raw_temp:
        temp = Path(raw_temp)
        photo = temp / "photo.png"
        source = Image.new("RGB", (500, 700), (32, 35, 45))
        draw = ImageDraw.Draw(source)
        draw.ellipse((90, 70, 410, 390), fill=(205, 180, 160))
        draw.rectangle((120, 380, 380, 700), fill=(90, 100, 125))
        source.save(photo)

        all_out = temp / "all"
        run(
            "--title",
            "Ada Lovelace",
            "--subtitle",
            "AI Systems Lead",
            "--label",
            "EXECUTIVE PROFILE",
            "--signal",
            "AGENTIC AI / DATA PLATFORMS",
            "--footer",
            "example.cresa.one",
            "--photo",
            str(photo),
            "--layout",
            "all",
            "--out",
            str(all_out),
        )
        for layout in ("editorial_right", "split_left", "portrait_ring"):
            assert_image(all_out / f"og_{layout}.png", (1200, 630))
            assert_image(all_out / f"og_{layout}_thumb.png", (360, 189))

        no_photo_out = temp / "no-photo"
        run(
            "--title",
            "Grace Hopper",
            "--subtitle",
            "Computer Science Pioneer",
            "--layout",
            "portrait-ring",
            "--out",
            str(no_photo_out),
        )
        assert_image(no_photo_out / "og_portrait_ring.png", (1200, 630))
        assert_image(no_photo_out / "og_portrait_ring_thumb.png", (360, 189))
        assert len(list(no_photo_out.glob("*.png"))) == 2

        result = run(
            "--title",
            "Too Small",
            "--scale",
            "0.99",
            "--out",
            str(temp / "small"),
            expect=2,
        )
        assert "auxiliary text floors" in result.stderr

        result = run(
            "--title",
            "Missing Photo",
            "--photo",
            str(temp / "missing.png"),
            "--out",
            str(temp / "missing"),
            expect=2,
        )
        assert "does not exist" in result.stderr

        result = run(
            "--title",
            "W" * 100,
            "--layout",
            "editorial-right",
            "--out",
            str(temp / "overflow"),
            expect=1,
        )
        assert "does not fit" in result.stderr

    print("og-image.py tests passed")


if __name__ == "__main__":
    main()
