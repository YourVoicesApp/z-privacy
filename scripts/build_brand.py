#!/usr/bin/env python3
"""Every size of the mark, from one picture.

    python3 scripts/build_brand.py            # write them
    python3 scripts/build_brand.py --check    # rebuild into a temp dir and diff

The source is the owner's own image, committed once as `brand/source.png`
(1008 × 1792, RGB, 1.2 MB). The mark is **the ring and what is inside it** — a
lighthouse in a ring on a dark blue night — and the field around it is the page,
not the logo. So this script crops the square the ring lives in and writes every
size the product needs from that one crop. Nobody edits an icon by hand: a gate
re-runs this into a temp directory and compares the bytes.

# The crop box, measured rather than guessed

Measured on the source's pixels (the code that measured it is `--measure`):

* the field is `rgb(6, 11, 20)`, luma 10.6 — the four corners agree;
* the ring's bright stroke spans **x 185..821** and **y 560..1213**, so its
  centre is **(503.0, 886.5)** and its widest row is y = 870;
* the lantern and its beam are bright **above** the ring, y 454..559 — they
  emerge from inside it and cross it, so a little of that light belongs to the
  mark and the rest is sky;
* the glow's mean brightness on a circle of radius r falls 55 (r = 320, the
  stroke) → 37 (340) → 34 (360) → 32 (380) → 31 (400) → 30 (430), where it is
  flat: beyond **r ≈ 360** what is left is the lit night, not the glow.

So the box is the square of side **720** centred on (503, 886) — the stroke plus
about 30 px of its glow on every side:

    x 143 .. 863      y 527 .. 1247

It fits inside the source with room to spare on both axes, and it keeps the
ring's glow, which cropping tighter would cut.

# Why the field is kept

The icon is night. The ring on transparency would lose the glow — the glow *is*
dark blue light, and there is nothing for it to glow against on a transparent
layer. So every size keeps the dark field, and the owner's picture stays the
owner's picture.
"""

from __future__ import annotations

import argparse
import filecmp
import math
import pathlib
import shutil
import sys
import tempfile

try:
    from PIL import Image
except ImportError:  # pragma: no cover — said plainly rather than traced
    sys.exit("this needs Pillow: python3 -m pip install --user Pillow")

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "brand" / "source.png"

# The measured box. Every number here was read off the pixels; see the head of
# this file for how, and `--measure` to read them again.
RING_CENTRE = (503, 886)
RING_STROKE_RADIUS = 330
GLOW_RADIUS = 360
BOX = (
    RING_CENTRE[0] - GLOW_RADIUS,
    RING_CENTRE[1] - GLOW_RADIUS,
    RING_CENTRE[0] + GLOW_RADIUS,
    RING_CENTRE[1] + GLOW_RADIUS,
)

# What the product needs, and where.
APP = "apps/flutter_app/assets/brand"
APP_SIZES = (1024, 512, 256, 128, 64, 48, 32, 16)
ICO = "apps/flutter_app/windows/runner/resources/app_icon.ico"
ICO_SIZES = (256, 48, 32, 16)
SITE = "site/assets"
SITE_FILES = (("favicon-32.png", 32), ("favicon-16.png", 16), ("apple-touch-icon.png", 180), ("logo-512.png", 512))


def square() -> Image.Image:
    """The crop, once, as every size's parent."""
    im = Image.open(SOURCE).convert("RGB")
    if im.size != (1008, 1792):
        sys.exit(f"the source is {im.size}; the measured box was read off 1008 × 1792 — measure again")
    crop = im.crop(BOX)
    if crop.size[0] != crop.size[1]:
        sys.exit(f"the box is not square: {crop.size}")
    return crop


def write(root: pathlib.Path) -> list[pathlib.Path]:
    parent = square()
    written: list[pathlib.Path] = []

    def png(path: pathlib.Path, size: int) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        # LANCZOS down from one parent, so 16 px is the same picture as 1024.
        # `optimize` and no metadata, so two runs are the same bytes.
        parent.resize((size, size), Image.LANCZOS).save(path, format="PNG", optimize=True)
        written.append(path)

    for size in APP_SIZES:
        png(root / APP / f"zprivacy-{size}.png", size)
    for name, size in SITE_FILES:
        png(root / SITE / name, size)

    # One `.ico` holding four sizes, as Windows reads them.
    ico = root / ICO
    ico.parent.mkdir(parents=True, exist_ok=True)
    parent.resize((256, 256), Image.LANCZOS).save(
        ico, format="ICO", sizes=[(s, s) for s in ICO_SIZES]
    )
    written.append(ico)
    return written


def check() -> int:
    """Rebuild into a temp directory and compare the bytes.

    This is what the gate runs. It needs the source and Pillow and nothing else,
    and it fails if an icon in the repository is not what this script writes —
    which is how «somebody edited the PNG by hand» is caught.
    """
    with tempfile.TemporaryDirectory() as tmp:
        fresh = pathlib.Path(tmp)
        made = write(fresh)
        bad = []
        for path in made:
            here = ROOT / path.relative_to(fresh)
            if not here.is_file():
                bad.append(f"{path.relative_to(fresh)} is not in the repository")
            elif not filecmp.cmp(path, here, shallow=False):
                bad.append(f"{path.relative_to(fresh)} differs from what this script writes")
        if bad:
            for line in bad:
                print(f"FAIL  {line}")
            return 1
        sizes = ", ".join(f"{p.name} {p.stat().st_size // 1024 or 1}K" for p in made[:3])
        print(f"PASS  {len(made)} files, byte for byte from brand/source.png ({sizes}, …)")
    return 0


def measure() -> int:
    """Read the numbers at the head of this file off the pixels again."""
    im = Image.open(SOURCE).convert("RGB")
    px = im.load()
    w, h = im.size

    def luma(p: tuple[int, int, int]) -> float:
        return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]

    spans = {}
    for y in range(h):
        xs = [x for x in range(w) if luma(px[x, y]) > 60]
        if xs:
            spans[y] = (min(xs), max(xs))
    wide = {y: s for y, s in spans.items() if s[1] - s[0] > 150}
    top, bottom = min(wide), max(wide)
    widest = max(wide, key=lambda y: wide[y][1] - wide[y][0])
    left, right = wide[widest]
    print(f"field          rgb{tuple(sum(c[i] for c in (px[0,0], px[w-1,0], px[0,h-1], px[w-1,h-1])) // 4 for i in range(3))}")
    print(f"ring stroke    x {left}..{right}   y {top}..{bottom}")
    print(f"centre         ({(left+right)/2:.1f}, {(top+bottom)/2:.1f})   widest row y={widest}")
    above = [y for y in spans if y < top]
    if above:
        print(f"above the ring y {min(above)}..{max(above)} — the lantern and its beam")
    print("glow falloff   mean luma on a circle of radius r:")
    for r in (320, 340, 360, 380, 400, 430):
        vals = []
        for i in range(720):
            a = i * math.pi / 360
            x, y = int(RING_CENTRE[0] + r * math.cos(a)), int(RING_CENTRE[1] + r * math.sin(a))
            if 0 <= x < w and 0 <= y < h:
                vals.append(luma(px[x, y]))
        print(f"               r={r:3}  {sum(vals)/len(vals):5.1f}")
    print(f"the box used   {BOX}  (side {BOX[2]-BOX[0]})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="rebuild into a temp dir and diff the bytes")
    parser.add_argument("--measure", action="store_true", help="read the crop numbers off the pixels again")
    args = parser.parse_args()
    if not SOURCE.is_file():
        sys.exit(f"no {SOURCE.relative_to(ROOT)} — the owner's image belongs there, once")
    if args.measure:
        return measure()
    if args.check:
        return check()
    made = write(ROOT)
    for path in made:
        print(f"  {path.relative_to(ROOT)}  {path.stat().st_size // 1024 or 1}K  ")
    print(f"{len(made)} files from brand/source.png, box {BOX}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
