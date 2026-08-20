#!/usr/bin/env python3
"""Render every ParishFinder icon asset from the Design handoff's vector source.

The handoff bundle's `.dc.html` draws the icon as an SVG `<symbol id="roundel">`
(a church over a sky/ground field, ringed by lead came and an armature ring) on a
`deepField` gradient with a faint `diaper` lattice. This script pulls that `<defs>`
block out, substitutes the palette, and re-renders each target size directly from
the vector — so nothing is ever upscaled from a smaller raster.

Usage:  python3 tool/gen_icons.py [--check]

`--check` renders to a temp dir and diffs against the tree instead of writing.
"""

import argparse
import base64
import io
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
HANDOFF = (
    REPO
    / "ParishFinder app icon design-handoff"
    / "parishfinder-app-icon-design"
    / "project"
    / "ParishFinder App Icon.dc.html"
)

# Mirrors the `palettes` map in the handoff's .dc.html. The sky/ground keys are
# optional there; when absent the roundel's sky and ground fall back to the field
# colours, which is what gives the other three palettes their tinted glass look.
PALETTES = {
    "sapphire-vigil": dict(
        deep="#0B2A4A", mid="#1E5F8A", bright="#3A7CA5",
        accent="#C9A227", highlight="#E8D7A1",
    ),
    "martyr-crimson": dict(
        deep="#4A1420", mid="#7A2A3A", bright="#A8455A",
        accent="#C9A227", highlight="#F0D9C9",
    ),
    "sacred-scarlet": dict(
        deep="#3A0E15", mid="#7A1620", bright="#B02A24",
        accent="#C9A227", highlight="#F2D98C",
        skyTop="#FBF6EC", skyBot="#F1E3C8",
        groundTop="#2E5637", groundBot="#173023",
    ),
    "doctor-amber": dict(
        deep="#4A2E0A", mid="#7A4E14", bright="#B8791F",
        accent="#C9A227", highlight="#F0DFA8",
    ),
}
PALETTE = "sacred-scarlet"

# The roundel symbol's viewBox is 248 units wide; the outer armature ring is r=113,
# so the mark's visible diameter is 226/248 of whatever width the <use> is given.
ROUNDEL_VB = 248.0
ROUNDEL_INK = 226.0

# Fraction of the canvas the mark's visible diameter should occupy.
#
# Android's foreground layer sits on a 108dp canvas of which only the center 72dp
# is guaranteed visible, so it needs a larger fraction of its canvas to end up the
# same size on screen. These two values are matched: 0.549 of 108dp and 0.700 of a
# full-bleed square both land the mark at ~82% of the visible tile.
ANDROID_FG_FRAC = 0.549   # as authored in the handoff
FULLBLEED_FRAC = 0.700    # re-scaled; the handoff's iOS export was 0.445


def load_defs() -> str:
    """Extract the <defs> block, resolve template vars, and drop the guide circle."""
    src = HANDOFF.read_text()
    m = re.search(r"<defs>.*?</defs>", src, re.S)
    if not m:
        sys.exit(f"could not find <defs> in {HANDOFF}")
    defs = m.group(0)

    p = PALETTES[PALETTE]
    # Same fallbacks as the .dc.html's renderVals(): sky and ground default to the
    # field colours when a palette does not override them.
    subs = {
        "deepColor": p["deep"],
        "midColor": p["mid"],
        "brightColor": p["bright"],
        "accentColor": p["accent"],
        "highlightColor": p["highlight"],
        "skyTop": p.get("skyTop", p["highlight"]),
        "skyBot": p.get("skyBot", p["bright"]),
        "groundTop": p.get("groundTop", p["mid"]),
        "groundBot": p.get("groundBot", p["deep"]),
    }
    for var, value in subs.items():
        defs = defs.replace("{{ %s }}" % var, value)

    # showArmatureRing defaults to true, so keep the wrapped circle and unwrap the tag.
    defs = re.sub(r"<sc-if[^>]*>", "", defs)
    defs = defs.replace("</sc-if>", "")

    leftover = re.findall(r"\{\{.*?\}\}", defs)
    if leftover:
        sys.exit(f"unresolved template vars in <defs>: {leftover}")
    return defs


DEFS = None


# All geometry is authored in this user space regardless of the raster size, so the
# diaper lattice and gradients keep the same proportions at every output size. The
# handoff's `deepField` gradient and 56-unit `diaper` pattern were drawn against it.
VB = 1024.0


def svg(size: int, *, roundel_frac: float, field: bool) -> str:
    """Build a standalone SVG. `field` draws the deep gradient + diaper background;
    without it the mark sits on transparency (the Android foreground layer)."""
    w = VB * roundel_frac * ROUNDEL_VB / ROUNDEL_INK
    off = (VB - w) / 2
    bg = (
        f'<rect width="{VB:.0f}" height="{VB:.0f}" fill="url(#deepField)"/>'
        f'<rect width="{VB:.0f}" height="{VB:.0f}" fill="url(#diaper)"/>'
        if field else ""
    )
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{size}" height="{size}" viewBox="0 0 {VB:.0f} {VB:.0f}">'
        f"{DEFS}{bg}"
        f'<use xlink:href="#roundel" href="#roundel" '
        f'x="{off:.3f}" y="{off:.3f}" width="{w:.3f}" height="{w:.3f}"/>'
        f"</svg>"
    )


def field_only_svg(size: int) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" '
        f'viewBox="0 0 {VB:.0f} {VB:.0f}">{DEFS}'
        f'<rect width="{VB:.0f}" height="{VB:.0f}" fill="url(#deepField)"/>'
        f'<rect width="{VB:.0f}" height="{VB:.0f}" fill="url(#diaper)"/></svg>'
    )


def render(markup: str, size: int) -> bytes:
    """Rasterize SVG markup to PNG bytes at `size`x`size`."""
    proc = subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size), "-f", "png"],
        input=markup.encode(), capture_output=True,
    )
    if proc.returncode != 0:
        sys.exit("rsvg-convert failed: " + proc.stderr.decode()[:2000])
    return proc.stdout


def flatten(png: bytes) -> bytes:
    """Composite onto opaque black and drop the alpha channel.

    The App Store rejects icons with an alpha channel, and Play's 512 listing icon
    wants none either. The field is opaque, so the matte colour never shows.
    """
    from PIL import Image

    im = Image.open(io.BytesIO(png)).convert("RGBA")
    flat = Image.new("RGB", im.size, (0, 0, 0))
    flat.paste(im, (0, 0), im)
    buf = io.BytesIO()
    flat.save(buf, "PNG")
    return buf.getvalue()


# --- asset table -------------------------------------------------------------
# Android adaptive layers live on a 108dp canvas: mdpi 108px through xxxhdpi 432px.
ANDROID_DENSITIES = {
    "mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432,
}
# Legacy square launcher icon, for pre-Android-8 and for launchers that ignore
# the adaptive icon: 48dp at each density.
LEGACY_DENSITIES = {
    "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
}
IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20, "Icon-App-20x20@2x.png": 40, "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29, "Icon-App-29x29@2x.png": 58, "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40, "Icon-App-40x40@2x.png": 80, "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120, "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76, "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


# Launch screen. The storyboard centres a single image over a background colour,
# so this is the bare mark — no field — at 180pt, the size the roundel reads well
# at on both an iPhone and an iPad without dominating either.
LAUNCH_PT = 180
LAUNCH_IMAGES = {
    "LaunchImage.png": LAUNCH_PT,
    "LaunchImage@2x.png": LAUNCH_PT * 2,
    "LaunchImage@3x.png": LAUNCH_PT * 3,
}


def monochrome_svg() -> str:
    """Android 13+ themed-icon layer: the roundel silhouette, flat on transparency.

    The system tints this layer to the user's wallpaper colours, so it carries no
    colour of its own — only alpha. The handoff ships it as a 1024 raster rather
    than as a symbol in the .dc.html, so it is placed rather than re-rendered; 1024
    is larger than any density needs, so it is only ever downscaled.
    """
    from PIL import Image

    src = HANDOFF.parent / "export" / "parishfinder-monochrome-black-1024.png"
    data = base64.b64encode(src.read_bytes()).decode()

    # The export's ink sits inside a transparent margin. Measure it and scale so the
    # silhouette's outer ring lands at exactly the foreground layer's diameter —
    # otherwise the themed icon renders a different size than the standard one.
    with Image.open(src) as im:
        box = im.convert("RGBA").split()[3].getbbox()
    ink_frac = (box[2] - box[0]) / im.width
    w = VB * ANDROID_FG_FRAC / ink_frac
    off_x = (VB - w) / 2
    off_y = (VB - w) / 2
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{VB:.0f}" height="{VB:.0f}" viewBox="0 0 {VB:.0f} {VB:.0f}">'
        f'<image xlink:href="data:image/png;base64,{data}" '
        f'x="{off_x:.2f}" y="{off_y:.2f}" width="{w:.2f}" height="{w:.2f}" '
        f'preserveAspectRatio="xMidYMid meet"/></svg>'
    )


def build() -> dict:
    """Return {repo-relative path: png bytes} for every generated asset."""
    out = {}

    res = "android/app/src/main/res"
    for dens, px in ANDROID_DENSITIES.items():
        out[f"{res}/mipmap-{dens}/ic_launcher_foreground.png"] = render(
            svg(px, roundel_frac=ANDROID_FG_FRAC, field=False), px)
        out[f"{res}/mipmap-{dens}/ic_launcher_background.png"] = render(
            field_only_svg(px), px)
        out[f"{res}/mipmap-{dens}/ic_launcher_monochrome.png"] = render(
            monochrome_svg(), px)
    for dens, px in LEGACY_DENSITIES.items():
        out[f"{res}/mipmap-{dens}/ic_launcher.png"] = flatten(
            render(svg(px, roundel_frac=FULLBLEED_FRAC, field=True), px))

    ios = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    for name, px in IOS_ICONS.items():
        out[f"{ios}/{name}"] = flatten(
            render(svg(px, roundel_frac=FULLBLEED_FRAC, field=True), px))

    # Launch screen: the roundel alone on transparency, so the storyboard's
    # LaunchBackground colour (parchment / OLED black) shows through and the
    # launch matches the app's own background in either appearance. Alpha is
    # required here — unlike the app icon, which Apple rejects with it.
    launch = "ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for name, px in LAUNCH_IMAGES.items():
        out[f"{launch}/{name}"] = render(
            svg(px, roundel_frac=0.98, field=False), px)

    for px in (192, 512):
        png = render(svg(px, roundel_frac=FULLBLEED_FRAC, field=True), px)
        out[f"web/icons/Icon-{px}.png"] = png
        # Maskable icons are cropped to a safe circle, so use the roomier framing.
        out[f"web/icons/Icon-maskable-{px}.png"] = render(
            svg(px, roundel_frac=ANDROID_FG_FRAC, field=True), px)
    out["web/favicon.png"] = render(svg(32, roundel_frac=FULLBLEED_FRAC, field=True), 32)

    out["site/apple-touch-icon.png"] = flatten(
        render(svg(180, roundel_frac=FULLBLEED_FRAC, field=True), 180))
    out["site/favicon.ico"] = build_ico()
    # Hero image on the landing page. 2x the ~272px it renders at, for retina;
    # corners are rounded in CSS so this stays a plain opaque square.
    out["site/app-icon-544.png"] = flatten(
        render(svg(544, roundel_frac=FULLBLEED_FRAC, field=True), 544))

    # In-app mark for the About page. The roundel already carries its own lead-came
    # ring, so it is drawn on transparency (no field) and sized to nearly fill the
    # canvas — the page shows it as a bare mark, not as a launcher tile.
    out["assets/icons/app_icon.png"] = render(
        svg(512, roundel_frac=0.98, field=False), 512)

    out["docs/store/play-icon-512.png"] = flatten(
        render(svg(512, roundel_frac=FULLBLEED_FRAC, field=True), 512))
    out["docs/store/play-feature-graphic-1024x500.png"] = feature_graphic()
    return out


def build_ico() -> bytes:
    """Multi-resolution .ico — 16/32/48 rendered separately, not downscaled."""
    from PIL import Image

    imgs = []
    for px in (16, 32, 48):
        im = Image.open(io.BytesIO(render(
            svg(px, roundel_frac=FULLBLEED_FRAC, field=True), px))).convert("RGBA")
        imgs.append(im)
    buf = io.BytesIO()
    imgs[-1].save(buf, "ICO", sizes=[(i.width, i.height) for i in imgs],
                  append_images=imgs[:-1])
    return buf.getvalue()


def feature_graphic() -> bytes:
    """Play feature graphic: parchment field, oxblood wordmark, icon tile at right.

    Rebuilt at exactly 1024x500 (the handoff exported it at 2x) with the icon tile
    re-rendered from vector at final size.
    """
    from PIL import Image

    from PIL import ImageDraw, ImageFont

    W, H = 1024, 500
    tile_px, tile_r, tile_x, tile_y = 380, 20, 1024 - 70 - 380, 60
    margin = 64  # matches the handoff's `left:64px` text block
    gutter = 40  # keep the wordmark clear of the tile

    base = Image.new("RGBA", (W, H), (250, 246, 238, 255))
    d = ImageDraw.Draw(base)

    fonts = REPO / "site" / "fonts"
    # The handoff specifies 96px, but that overruns the tile in the real face —
    # step down until the wordmark clears it.
    size = 96
    while size > 40:
        wordmark = ImageFont.truetype(str(fonts / "CormorantGaramond-Bold.ttf"), size)
        if d.textlength("ParishFinder", font=wordmark) <= tile_x - margin - gutter:
            break
        size -= 2
    d.text((margin, 250), "ParishFinder", font=wordmark, fill="#8C1F1F", anchor="ls")

    tag = ImageFont.truetype(str(fonts / "Inter-SemiBold.ttf"), 12)
    x = margin + 2
    for ch in "DISCOVER THE LIFE OF THE CHURCH":
        d.text((x, 290), ch, font=tag, fill="#8C5A14", anchor="ls")
        x += d.textlength(ch, font=tag) + 1.3  # letter-spacing from the handoff

    # The tile is its own composition, not the app icon: the handoff calls it "the
    # full parish-window treatment (field, diaper, corner fleurons, roundel) — the
    # system the icon simplifies from". Reproduced at its authored 380 user space.
    tile_svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'width="{tile_px}" height="{tile_px}" viewBox="0 0 380 380">{DEFS}'
        f'<rect width="380" height="380" fill="url(#deepField)"/>'
        f'<rect width="380" height="380" fill="url(#diaper)"/>'
        + "".join(
            f'<use xlink:href="#fleuron" href="#fleuron" x="{x}" y="{y}" width="46" height="46"/>'
            for x, y in [(14, 14), (320, 14), (14, 320), (320, 320)]
        )
        + '<use xlink:href="#roundel" href="#roundel" x="90" y="90" width="200" height="200"/>'
        "</svg>"
    )
    tile = Image.open(io.BytesIO(render(tile_svg, tile_px))).convert("RGBA")
    mask = Image.new("L", (tile_px * 4, tile_px * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, tile_px * 4 - 1, tile_px * 4 - 1), radius=tile_r * 4, fill=255)
    tile.putalpha(mask.resize((tile_px, tile_px), Image.LANCZOS))
    base.alpha_composite(tile, (tile_x, tile_y))

    flat = Image.new("RGB", base.size, (250, 246, 238))
    flat.paste(base, (0, 0), base)
    buf = io.BytesIO()
    flat.save(buf, "PNG")
    return buf.getvalue()


def main() -> None:
    global DEFS
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true",
                    help="compare against the tree instead of writing")
    args = ap.parse_args()

    if not shutil.which("rsvg-convert"):
        sys.exit("rsvg-convert not found (apt install librsvg2-bin)")
    if not HANDOFF.exists():
        sys.exit(f"handoff bundle not found at {HANDOFF}")

    DEFS = load_defs()
    assets = build()

    if args.check:
        stale = [p for p, data in assets.items()
                 if not (REPO / p).exists() or (REPO / p).read_bytes() != data]
        if stale:
            print("stale or missing:\n  " + "\n  ".join(sorted(stale)))
            sys.exit(1)
        print(f"all {len(assets)} icon assets up to date")
        return

    for path, data in assets.items():
        dest = REPO / path
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
    print(f"wrote {len(assets)} icon assets")


if __name__ == "__main__":
    main()
