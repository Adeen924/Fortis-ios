#!/usr/bin/env python3
"""
generate_fortis_icons.py
Generates all required iOS app icon PNGs for Fortis – Train Heavy,
plus the Contents.json for AppIcon.appiconset.

Usage:
    python3 generate_fortis_icons.py
    python3 generate_fortis_icons.py --out Fortis/Resources/Assets.xcassets/AppIcon.appiconset

Requires: pip install Pillow  (>= 8.2.0)
"""

import argparse
import json
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.exit("Pillow not found.  Run:  pip install Pillow")

# ── Palette (matches the SVG exactly) ────────────────────────────────────────
BG_COLOR    = (0x1C, 0x12, 0x00)   # dark bronze background
SHIELD_FILL = (0x2A, 0x1A, 0x00)   # shield body
GOLD_BORDER = (0xD4, 0x92, 0x0A)   # outer gold stroke
TEXT_GOLD   = (0xFF, 0xD0, 0x60)   # FORTIS / TRAIN HEAVY text

# ── iOS icon slots ────────────────────────────────────────────────────────────
# (idiom, scale, size-string, filename, pixel-size)
ICON_SLOTS = [
    ("iphone",        "2x", "20x20",     "Icon-40.png",   40),
    ("iphone",        "3x", "20x20",     "Icon-60.png",   60),
    ("iphone",        "2x", "29x29",     "Icon-58.png",   58),
    ("iphone",        "3x", "29x29",     "Icon-87.png",   87),
    ("iphone",        "2x", "40x40",     "Icon-80.png",   80),
    ("iphone",        "3x", "40x40",     "Icon-120.png", 120),
    ("iphone",        "2x", "60x60",     "Icon-120.png", 120),
    ("iphone",        "3x", "60x60",     "Icon-180.png", 180),
    ("ipad",          "1x", "20x20",     "Icon-20.png",   20),
    ("ipad",          "2x", "20x20",     "Icon-40.png",   40),
    ("ipad",          "1x", "29x29",     "Icon-29.png",   29),
    ("ipad",          "2x", "29x29",     "Icon-58.png",   58),
    ("ipad",          "1x", "40x40",     "Icon-40.png",   40),
    ("ipad",          "2x", "40x40",     "Icon-80.png",   80),
    ("ipad",          "1x", "76x76",     "Icon-76.png",   76),
    ("ipad",          "2x", "76x76",     "Icon-152.png", 152),
    ("ipad",          "2x", "83.5x83.5", "Icon-167.png", 167),
    ("ios-marketing", "1x", "1024x1024", "Icon-1024.png", 1024),
]


# ── Bézier helpers ────────────────────────────────────────────────────────────

def qbez(p0, p1, p2, steps=64):
    """Return point list for a quadratic Bézier from p0 to p2 via control p1."""
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = 1.0 - t
        pts.append((
            u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
            u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
        ))
    return pts


def shield_polygon(s, inner=False):
    """
    Build the shield outline as a list of (x, y) points, scaled by s
    (where s = target_pixels / 200.0, matching the 200×200 SVG viewBox).

    Outer:  M100 14 L172 44 L172 108 Q172,158 100,186 Q28,158 28,108 L28 44 Z
    Inner:  M100 26 L160 52 L160 108 Q160,150 100,174 Q40,150 40,108 L40 52 Z
    """
    if inner:
        pts  = [(100*s, 26*s), (160*s, 52*s), (160*s, 108*s)]
        pts += qbez((160*s, 108*s), (160*s, 150*s), (100*s, 174*s))[1:]
        pts += qbez((100*s, 174*s), (40*s,  150*s), (40*s,  108*s))[1:]
        pts.append((40*s, 52*s))
    else:
        pts  = [(100*s, 14*s), (172*s, 44*s), (172*s, 108*s)]
        pts += qbez((172*s, 108*s), (172*s, 158*s), (100*s, 186*s))[1:]
        pts += qbez((100*s, 186*s), (28*s,  158*s), (28*s,  108*s))[1:]
        pts.append((28*s, 44*s))
    return pts


# ── Alpha-compositing helper ──────────────────────────────────────────────────

def composite(img, pts, fill=None, outline=None, stroke=1, is_line=False):
    """
    Paint a semi-transparent polygon or polyline onto img via alpha-composite.
    fill and outline are RGBA tuples (r, g, b, a).
    """
    ov = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d  = ImageDraw.Draw(ov)
    if is_line:
        d.line(pts, fill=outline, width=stroke)
    else:
        if fill:
            d.polygon(pts, fill=fill)
        if outline:
            # Use line+close for stroke-only to avoid Pillow version quirks
            closed = list(pts) + [pts[0]]
            d.line(closed, fill=outline, width=stroke)
    return Image.alpha_composite(img, ov)


# ── Font discovery ────────────────────────────────────────────────────────────

def find_font(bold=False):
    """Return a path to Georgia (bold or regular), or None if not found."""
    bold_paths = [
        "/System/Library/Fonts/Supplemental/Georgia Bold.ttf",
        "/Library/Fonts/Georgia Bold.ttf",
    ]
    reg_paths = [
        "/System/Library/Fonts/Supplemental/Georgia.ttf",
        "/Library/Fonts/Georgia.ttf",
        "/System/Library/Fonts/Georgia.ttf",
    ]
    for p in (bold_paths if bold else reg_paths):
        if os.path.exists(p):
            return p
    # Fall back: accept any Georgia variant
    for p in (reg_paths + bold_paths):
        if os.path.exists(p):
            return p
    return None


# ── Text drawing with letter-spacing ─────────────────────────────────────────

def draw_spaced(draw, text, cx, baseline_y, font, fill, extra_px=0):
    """
    Draw `text` horizontally centred at cx, with its baseline at baseline_y.
    extra_px adds that many pixels of spacing between each glyph.
    Uses anchor="ls" (left, baseline) per character for precise placement.
    """
    chars = list(text)

    # Measure each character's advance width
    widths = []
    for ch in chars:
        bb = draw.textbbox((0, 0), ch, font=font, anchor="ls")
        widths.append(bb[2] - bb[0])

    total_w = sum(widths) + extra_px * max(0, len(chars) - 1)
    x = cx - total_w / 2.0

    for ch, w in zip(chars, widths):
        draw.text((x, baseline_y), ch, fill=fill, font=font, anchor="ls")
        x += w + extra_px


# ── Main render function ──────────────────────────────────────────────────────

def make_icon(size: int) -> Image.Image:
    """
    Render the Fortis shield icon at size×size pixels.
    All coordinates are derived from the 200×200 SVG viewBox via scale s.
    """
    s   = size / 200.0
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d   = ImageDraw.Draw(img)

    # 1 ── Background: dark bronze rounded square (rx=40 in SVG)
    corner_r = max(1, round(40 * s))
    d.rounded_rectangle([(0, 0), (size - 1, size - 1)],
                        radius=corner_r, fill=BG_COLOR)

    # 2 ── Shield fill
    outer_pts = shield_polygon(s)
    d.polygon(outer_pts, fill=SHIELD_FILL)

    # 3 ── Outer shield border — stroke-width 4, fully opaque gold
    outer_bw = max(1, round(4 * s))
    closed   = outer_pts + [outer_pts[0]]
    d.line(closed, fill=GOLD_BORDER, width=outer_bw)

    # 4 ── Inner border — stroke ~1.2, alpha 0.4
    inner_rgba = (*GOLD_BORDER, round(255 * 0.4))
    inner_bw   = max(1, round(1.5 * s))
    img = composite(img, shield_polygon(s, inner=True),
                    outline=inner_rgba, stroke=inner_bw)

    # 5 ── Cross lines — alpha 0.3
    line_rgba = (*GOLD_BORDER, round(255 * 0.3))
    lw        = max(1, round(1.5 * s))
    img = composite(img,
                    [(round(100*s), round(14*s)), (round(100*s), round(186*s))],
                    outline=line_rgba, stroke=lw, is_line=True)
    img = composite(img,
                    [(round(28*s), round(90*s)), (round(172*s), round(90*s))],
                    outline=line_rgba, stroke=lw, is_line=True)
    d = ImageDraw.Draw(img)

    # 6 ── Text
    bold_path = find_font(bold=True)
    reg_path  = find_font(bold=False)

    fortis_pt = max(8,  round(24 * s))
    sub_pt    = max(5,  round(9  * s))

    try:
        fortis_font = ImageFont.truetype(bold_path or reg_path, fortis_pt)
    except Exception:
        fortis_font = ImageFont.load_default()
    try:
        sub_font = ImageFont.truetype(reg_path or bold_path, sub_pt)
    except Exception:
        sub_font = ImageFont.load_default()

    cx          = size / 2.0
    letter_gap  = max(0, round(2 * s))   # SVG letter-spacing="2" scaled

    # "FORTIS" — baseline at y = 76 * s  (above the horizontal divider at y=90)
    draw_spaced(d, "FORTIS", cx, round(76 * s),
                fortis_font, TEXT_GOLD, letter_gap)

    # "TRAIN HEAVY" — baseline at y = 112 * s, opacity 0.7
    sub_rgba = (*TEXT_GOLD, round(255 * 0.7))
    ov_sub   = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d_sub    = ImageDraw.Draw(ov_sub)
    draw_spaced(d_sub, "TRAIN HEAVY", cx, round(112 * s),
                sub_font, sub_rgba, letter_gap)
    img = Image.alpha_composite(img, ov_sub)

    # 7 ── Flatten RGBA → RGB (app icons must not have transparency)
    bg = Image.new("RGB", (size, size), BG_COLOR)
    bg.paste(img.convert("RGB"), mask=img.split()[3])
    return bg


# ── Contents.json ─────────────────────────────────────────────────────────────

def make_contents_json() -> dict:
    images = [
        {"filename": filename, "idiom": idiom, "scale": scale, "size": size_str}
        for idiom, scale, size_str, filename, _ in ICON_SLOTS
    ]
    return {"images": images, "info": {"author": "xcode", "version": 1}}


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Generate Fortis iOS app icons"
    )
    parser.add_argument(
        "--out",
        default="AppIcon.appiconset",
        help="Output directory (default: AppIcon.appiconset)",
    )
    args = parser.parse_args()

    out_dir = args.out
    os.makedirs(out_dir, exist_ok=True)

    # Deduplicate: multiple slots may share the same pixel size
    seen_px   = set()
    unique_px = []
    for _, _, _, _, px in ICON_SLOTS:
        if px not in seen_px:
            seen_px.add(px)
            unique_px.append(px)
    unique_px.sort(reverse=True)

    print(f"\nFortis icon generator")
    print(f"Output: {os.path.abspath(out_dir)}\n")

    for px in unique_px:
        filename = f"Icon-{px}.png"
        path     = os.path.join(out_dir, filename)
        icon     = make_icon(px)
        icon.save(path, "PNG", optimize=True)
        print(f"  ✓  {filename:<18}  {px}×{px}")

    contents_path = os.path.join(out_dir, "Contents.json")
    with open(contents_path, "w") as f:
        json.dump(make_contents_json(), f, indent=2)
    print(f"  ✓  Contents.json")

    print(f"\n{len(unique_px)} PNGs + Contents.json → {out_dir}/\n")


if __name__ == "__main__":
    main()
