#!/usr/bin/env python3
"""Every size of the mark, from one picture.

    python3 scripts/build_brand.py            # write them
    python3 scripts/build_brand.py --check    # rebuild into a temp dir and diff
    python3 scripts/build_brand.py --measure  # read the crop numbers off the pixels

The source is the owner's own image, committed once as `brand/source.png`
(1008 × 1792, RGB, 1.2 MB). The mark is **everything the picture lights** — a
lighthouse standing in a ring of light on a dark blue night — and the field
around it is the page, not the logo. So this script crops the square that holds
all of that light and writes every size the product needs from that one crop.
Nobody edits an icon by hand: a gate re-runs this into a temp directory and
compares the bytes.

# The crop box, measured rather than guessed

The first box was the ring and its glow — 720 px centred on the ring — read off
the paper's phrase «the mark is the ring and what is inside it». At 256 px it
cut the lighthouse's head off at the top edge and lost the crescent above the
ring entirely. The ring is not the mark; the ring is where the mark stands.
**The lighthouse rises out of the ring on purpose, and the box holds it.**

Measured on the source's pixels, with `--measure`, and the measuring needed two
rules because the picture has two kinds of edge:

* the field is `rgb(6, 11, 20)`, luma 10.9 on average in the corners — but it
  carries a faint gradient that touches 40 in places. One pixel brighter than 40
  is therefore not evidence of anything: that rule puts the top of the picture at
  y = 379, in empty sky. Three in a row still does. **Five in a row brighter
  than 40** does not — and it still finds the crescent, whose outline is a thread
  at luma 41..44, dimmer than the lantern by a factor of five and invisible to
  any threshold sturdy enough to trace the ring;
* by that rule, all the light — ring, glow, lighthouse, beam, crescent — lives in
  **x 175..825, y 447..1223**. The first lit row, 447, is the crescent's upper
  edge: in its own columns six pixels pass 40 there while empty sky at the same
  rows has none, and seven rows down the lantern is at luma 192;
* the ring's bright stroke needs the sturdy rule instead, or its glow is read as
  stroke: brighter than 60, three in a row, it spans **x 185..821, y 560..1213**,
  its widest row is y = 870 and its centre is **(503, 886)**.

So the box is the square of side **820**, centred on x = 503, its top at y = 430:

    x 93 .. 913      y 430 .. 1250

That leaves 82 px of night on the left, 88 on the right, 17 above the crescent
and 27 below the glow's last row. The ring's centre sits 46 px below the box's,
and the lighthouse stands at the top of it — which is the picture, not a fault in
the crop: the box reaches up for the lantern, not down. `square()` asserts that
the box still holds the measured light with a border, so the next person to
narrow it gets a failed build instead of a beheaded lighthouse.

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
LIT = (175, 447, 825, 1223)  # all of it: ring, glow, lighthouse, beam, crescent
STROKE = (185, 560, 821, 1213)  # the ring's bright line alone, without its glow
RING_CENTRE = (503, 886)  # the stroke's centre, which is not the box's centre
CENTRE_X = 503  # the stroke's widest row, y = 870, is centred here
SIDE = 820
TOP = 430
BOX = (CENTRE_X - SIDE // 2, TOP, CENTRE_X + SIDE // 2, TOP + SIDE)  # (93, 430, 913, 1250)
MARGIN = 15  # the least night the box must keep on every side of the light

# What the product needs, and where.
APP = "apps/flutter_app/assets/brand"
APP_SIZES = (1024, 512, 256, 128, 64, 48, 32, 16)
ICO = "apps/flutter_app/windows/runner/resources/app_icon.ico"
ICO_SIZES = (256, 48, 32, 16)
SITE = "site/assets"
SITE_FILES = (("favicon-32.png", 32), ("favicon-16.png", 16), ("apple-touch-icon.png", 180), ("logo-512.png", 512))


def square() -> Image.Image:
    """The crop, once, as every size's parent.

    The checks are here rather than in a test because this is the one place the
    box is used: a box that cuts the picture must not reach a PNG at all.
    """
    im = Image.open(SOURCE).convert("RGB")
    if im.size != (1008, 1792):
        sys.exit(f"the source is {im.size}; the measured box was read off 1008 × 1792 — measure again")
    left, top, right, bottom = BOX
    if (right - left) != (bottom - top):
        sys.exit(f"the box is not square: {BOX}")
    if left < 0 or top < 0 or right > im.size[0] or bottom > im.size[1]:
        sys.exit(f"the box {BOX} leaves the source {im.size}")
    if not (
        left + MARGIN <= LIT[0] and top + MARGIN <= LIT[1] and LIT[2] <= right - MARGIN and LIT[3] <= bottom - MARGIN
    ):
        sys.exit(f"the box {BOX} does not hold the light {LIT} with {MARGIN} px of night around it")
    return im.crop(BOX)


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
    parent.resize((256, 256), Image.LANCZOS).save(ico, format="ICO", sizes=[(s, s) for s in ICO_SIZES])
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

    def bounds(threshold: int, run: int, x0: int = 0, x1: int = w) -> tuple[int, int, int, int]:
        """What is lit, by the rule «`run` pixels in a row brighter than `threshold`»."""
        rows = [y for y in range(h) if sum(1 for x in range(x0, x1) if luma(px[x, y]) > threshold) >= run]
        cols = [x for x in range(x0, x1) if sum(1 for y in range(h) if luma(px[x, y]) > threshold) >= run]
        return (min(cols), min(rows), max(cols), max(rows))

    corners = [
        luma(px[x, y])
        for cx, cy in ((0, 0), (w - 40, 0), (0, h - 40), (w - 40, h - 40))
        for x in range(cx, cx + 40)
        for y in range(cy, cy + 40)
    ]
    rgb = tuple(sum(c[i] for c in (px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1])) // 4 for i in range(3))
    print(f"field          rgb{rgb}   luma mean {sum(corners)/len(corners):.1f}, max {max(corners):.1f}")

    lit = bounds(40, 5)
    print(f"all the light  x {lit[0]}..{lit[2]}   y {lit[1]}..{lit[3]}   brighter than 40, five in a row")
    if lit != LIT:
        print(f"               ! LIT in this file says {LIT} — the box was measured on that")
    loose = bounds(40, 3)
    print(f"               three in a row instead, and the sky joins in: y {loose[1]}..{loose[3]}")
    lantern = bounds(40, 5, 430, 580)
    print(f"the lighthouse y {lantern[1]}..{lantern[3]}   in its own columns, 430..580")

    # The ring's line, not its glow: rows the circle crosses more than 150 apart.
    spans = {}
    for y in range(h):
        row = [x for x in range(w) if luma(px[x, y]) > 60]
        if len(row) >= 3:
            spans[y] = (row[0], row[-1])
    ring = {y: s for y, s in spans.items() if s[1] - s[0] > 150}
    widest = max(ring, key=lambda y: ring[y][1] - ring[y][0])
    left, right = ring[widest]
    stroke = (left, min(ring), right, max(ring))
    print(f"ring stroke    x {stroke[0]}..{stroke[2]}   y {stroke[1]}..{stroke[3]}   brighter than 60, three in a row")
    if stroke != STROKE:
        print(f"               ! STROKE in this file says {STROKE}")
    print(f"               widest row y={widest}, centred on x={(left+right)//2}; centre {RING_CENTRE}")

    print("glow falloff   mean luma on a circle of radius r about the ring's centre:")
    for r in (320, 340, 360, 380, 400, 430):
        vals = []
        for i in range(720):
            a = i * math.pi / 360
            x, y = int(RING_CENTRE[0] + r * math.cos(a)), int(RING_CENTRE[1] + r * math.sin(a))
            if 0 <= x < w and 0 <= y < h:
                vals.append(luma(px[x, y]))
        print(f"               r={r:3}  {sum(vals)/len(vals):5.1f}")

    print(f"the box used   {BOX}   side {BOX[2]-BOX[0]}, centre ({(BOX[0]+BOX[2])//2}, {(BOX[1]+BOX[3])//2})")
    print(
        f"night around   left {lit[0]-BOX[0]}, top {lit[1]-BOX[1]}, "
        f"right {BOX[2]-lit[2]}, bottom {BOX[3]-lit[3]}   (at least {MARGIN})"
    )
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
