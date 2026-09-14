"""Screenshot an Android emulator *with its device frame*.

    python3 tool/framed_screenshot.py out.png

The emulator's own camera button and `adb exec-out screencap` both capture the
framebuffer alone -- 1280x2856 of app, no phone around it. The frame you see on
screen is drawn by the emulator window from a skin, and never reaches either
file.

So this composites the two by hand. It reads the skin the running AVD is
configured with, takes a real screencap, and lays it into the skin's artwork at
the offset the skin's own `layout` file specifies. The result is full
resolution -- the phone body is vector-quality art and the screen is every real
pixel, neither of them scaled to fit a window on this monitor.

    --serial     device to grab (default: the only one attached)
    --skin       override the skin (default: whatever the AVD is set to)
    --no-frame   plain screencap, for comparison
"""

import argparse
import io
import re
import socket
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow is required: pip install --user Pillow")

SDK = Path.home() / "Android/Sdk"
AVD_HOME = Path.home() / ".android/avd"


def adb(args, serial=None, binary=False):
    cmd = [str(SDK / "platform-tools/adb")]
    if serial:
        cmd += ["-s", serial]
    cmd += args
    out = subprocess.run(cmd, capture_output=True, check=True)
    return out.stdout if binary else out.stdout.decode().strip()


def running_avd(serial):
    """The AVD name behind an emulator serial, via the emulator console."""
    try:
        reply = adb(["emu", "avd", "name"], serial)
    except subprocess.CalledProcessError:
        return None
    # The console answers with the name, then "OK".
    for line in reply.splitlines():
        line = line.strip()
        if line and line != "OK":
            return line
    return None


def skin_dir_for(avd_name):
    cfg = AVD_HOME / f"{avd_name}.avd/config.ini"
    if not cfg.is_file():
        return None
    settings = dict(
        line.split("=", 1) for line in cfg.read_text().splitlines() if "=" in line
    )
    path = settings.get("skin.path")
    if path and Path(path).is_dir():
        return Path(path)
    name = settings.get("skin.name")
    if name and (SDK / "skins" / name).is_dir():
        return SDK / "skins" / name
    return None


def parse_layout(skin: Path):
    """Pull the display size and its offset inside the portrait layout.

    The skin's `layout` is a small brace-nested format. Two facts matter: how
    big the display is (under parts.device.display) and where the emulator puts
    it on the background (layouts.portrait.part2). Everything is read rather
    than hard-coded, so a different skin needs no edit here.
    """
    text = (skin / "layout").read_text()

    display = re.search(
        r"display\s*\{(.*?)\}", text, re.S
    )
    if not display:
        sys.exit(f"{skin}/layout has no display block")
    body = display.group(1)
    size = (
        int(re.search(r"\bwidth\s+(\d+)", body).group(1)),
        int(re.search(r"\bheight\s+(\d+)", body).group(1)),
    )

    # part2 is the device part inside the portrait layout: its x/y is where the
    # screen sits on the background art.
    portrait = re.search(r"layouts\s*\{.*?portrait\s*\{(.*)", text, re.S).group(1)
    part = re.search(r"part2\s*\{(.*?)\}", portrait, re.S)
    if not part:
        sys.exit(f"{skin}/layout has no part2 in its portrait layout")
    offset = (
        int(re.search(r"\bx\s+(-?\d+)", part.group(1)).group(1)),
        int(re.search(r"\by\s+(-?\d+)", part.group(1)).group(1)),
    )
    return size, offset


class Console:
    """The emulator's control console on port 5554, spoken directly.

    Worth the socket code for one reason: under some GPU modes the guest's own
    `screencap` dies with

        Assertion failed: !rcEnc->featureInfo()->hasReadColorBufferDma

    because it reads the framebuffer through the guest GL driver. The console's
    screenshot is taken host-side and doesn't care what the guest's driver
    thinks, so it works under every renderer.
    """

    def __init__(self, port=5554):
        self.sock = socket.create_connection(("127.0.0.1", port), timeout=5)
        self.sock.settimeout(3)
        self._read()
        token = (Path.home() / ".emulator_console_auth_token").read_text().strip()
        self.send(f"auth {token}")

    def _read(self):
        out = b""
        try:
            while True:
                chunk = self.sock.recv(4096)
                if not chunk:
                    break
                out += chunk
                if out.rstrip().endswith((b"OK", b"KO")):
                    break
        except socket.timeout:
            pass
        return out.decode(errors="replace").strip()

    def send(self, cmd):
        self.sock.sendall(f"{cmd}\n".encode())
        return self._read()

    def close(self):
        self.sock.close()


def console_port(serial):
    if serial and serial.startswith("emulator-"):
        return int(serial.split("-", 1)[1])
    return 5554


def grab(serial):
    """Screenshot the guest, console first and adb as the fallback."""
    with tempfile.TemporaryDirectory() as tmp:
        try:
            con = Console(console_port(serial))
            reply = con.send(f"screenrecord screenshot {tmp}")
            con.close()
            shots = sorted(Path(tmp).glob("*.png"))
            if shots:
                return Image.open(shots[-1]).convert("RGBA")
            print(f"console screenshot gave no file ({reply}); trying adb",
                  file=sys.stderr)
        except OSError as e:
            print(f"console unreachable ({e}); trying adb", file=sys.stderr)

    png = adb(["exec-out", "screencap", "-p"], serial, binary=True)
    if not png.startswith(b"\x89PNG"):
        sys.exit(
            "neither the console nor screencap produced a PNG.\n"
            "If screencap aborted on hasReadColorBufferDma, that is the guest GL\n"
            "driver — the console path above is the way round it, so check the\n"
            "emulator is still running and its console port is reachable."
        )
    return Image.open(io.BytesIO(png)).convert("RGBA")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("output", type=Path)
    ap.add_argument("--serial")
    ap.add_argument("--skin", type=Path)
    ap.add_argument("--no-frame", action="store_true")
    args = ap.parse_args()

    screen = grab(args.serial)

    if args.no_frame:
        screen.convert("RGB").save(args.output)
        print(f"{args.output}  {screen.width}x{screen.height}  (no frame)")
        return

    skin = args.skin
    if skin is None:
        avd = running_avd(args.serial)
        skin = skin_dir_for(avd) if avd else None
        if skin is None:
            sys.exit(
                "couldn't work out which skin this AVD uses — pass --skin "
                f"{SDK}/skins/<name>"
            )

    size, (ox, oy) = parse_layout(skin)
    if screen.size != size:
        # A mismatch means the frame would sit around the wrong-sized hole, so
        # say which two things disagree rather than silently stretching.
        sys.exit(
            f"screen is {screen.width}x{screen.height} but skin {skin.name} is "
            f"drawn for {size[0]}x{size[1]} — wrong skin for this AVD"
        )

    # The screen goes ON TOP of the body art. back.webp paints an opaque black
    # panel where the display sits, so compositing it the other way round hides
    # the screenshot behind a switched-off phone.
    canvas = Image.open(skin / "back.webp").convert("RGBA")

    canvas.paste(screen, (ox, oy))

    # mask.webp is a *foreground*, not a stencil: transparent over almost the
    # whole display (its alpha averages 2 of 255) and opaque only at the
    # rounded corners and around the camera hole, which it paints on top of the
    # screen. Used as the screen's alpha instead, it erases the screenshot
    # almost entirely and leaves the body art's black panel showing.
    mask_file = skin / "mask.webp"
    if mask_file.is_file():
        mask = Image.open(mask_file).convert("RGBA")
        if mask.size == screen.size:
            canvas.paste(mask, (ox, oy), mask)

    args.output.parent.mkdir(parents=True, exist_ok=True)

    # Keep the alpha. back.webp is transparent outside the phone's silhouette,
    # so flattening to RGB fills the four outer corners with opaque white
    # wedges — the frame stops being a cut-out phone and becomes a rectangle
    # with a phone drawn on it. A PNG with alpha drops onto any page or slide.
    if args.output.suffix.lower() in {".jpg", ".jpeg"}:
        flat = Image.new("RGB", canvas.size, (255, 255, 255))
        flat.paste(canvas, mask=canvas.split()[-1])
        flat.save(args.output, quality=95)
        note = "  (JPEG: transparency flattened onto white)"
    else:
        canvas.save(args.output)
        note = ""

    kb = args.output.stat().st_size / 1024
    print(f"{args.output}  {canvas.width}x{canvas.height}  {kb:.0f} KB  "
          f"(skin {skin.name}, screen at {ox},{oy}){note}")


if __name__ == "__main__":
    main()
