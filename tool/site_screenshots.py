#!/usr/bin/env python3
"""Turn App Store screenshot captures into the two images the site ships.

    python3 tool/site_screenshots.py ~/shots/ios-home.png ~/shots/ios-parish.png

Source captures are native-resolution and run 0.7-3 MB each. The site shows
them in a column about 330 CSS px wide, so it needs half that: 660 px, which is
still 2x on a retina display and lands around a fifth of the file size.

Transparency is preserved. A capture from `tool/framed_screenshot.py` carries
the phone's body art on a transparent ground, and flattening it would put white
wedges at the four corners of a rounded phone -- the same bug that one had.
The page's CSS uses drop-shadow (which follows the alpha) rather than a box
shadow (which would trace the bounding rectangle).

Writes site/shot-home.png and site/shot-parish.png. Uncomment the SCREENSHOTS
section in site/index.html once they exist.
"""

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: pip install --user Pillow")

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "site"
TARGET_WIDTH = 660

# The markup in index.html hard-codes width/height so the browser reserves the
# right box before the image loads. Those attributes assume this ratio; a source
# with different proportions is fine, but the numbers there need updating too.
# 1187x2513 is a pixel_8-framed Android capture.
EXPECTED_RATIO = 2513 / 1187


def convert(src: Path, dest_name: str) -> None:
    if not src.is_file():
        sys.exit(f"no such file: {src}")

    with Image.open(src) as im:
        # RGBA only when the source actually has alpha -- an unframed capture
        # gains nothing from a fourth channel but pays for it in bytes.
        im = im.convert("RGBA" if im.mode in ("RGBA", "LA", "P") else "RGB")
        if im.mode == "RGBA" and im.getchannel("A").getextrema() == (255, 255):
            im = im.convert("RGB")
        ratio = im.height / im.width
        height = round(TARGET_WIDTH * ratio)
        out = im.resize((TARGET_WIDTH, height), Image.LANCZOS)

        dest = OUT_DIR / dest_name
        # No exif/icc carried over: these are screenshots, and the profile is
        # bigger than some of the image data.
        out.save(dest, "PNG", optimize=True)
        mode = out.mode

    kb = dest.stat().st_size / 1024
    note = "" if mode == "RGB" else "  (transparent ground kept)"
    if abs(ratio - EXPECTED_RATIO) > 0.02:
        note = (f"  <-- {src.name} is {im.width}x{im.height}; set "
                f'width="{TARGET_WIDTH}" height="{height}" in index.html')
    print(f"{dest.relative_to(ROOT)}  {TARGET_WIDTH}x{height}  {kb:.0f} KB{note}")


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    convert(Path(sys.argv[1]).expanduser(), "shot-home.png")
    convert(Path(sys.argv[2]).expanduser(), "shot-parish.png")
    print("\nNow uncomment the SCREENSHOTS section in site/index.html.")


if __name__ == "__main__":
    main()
