#!/usr/bin/env python3
"""Ikona aplikace Pelíšek (.icns) z pelíšku: pixelizace a zvětšení nejbližším sousedem, ať zůstanou pixely.

  python3 ikona.py zdroj.png vystup.icns
"""
import os
import shutil
import subprocess
import sys

TU = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(TU, ".."))
from PIL import Image  # noqa: E402
from pixelizuj import obrys  # noqa: E402


def pix(im, width):
    im = im.convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v >= 150 else 0)
    im.putalpha(a)
    im = im.crop(a.getbbox())
    h = round(im.height * width / im.width)
    sm = im.resize((width, h), Image.BOX)
    al = sm.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    q = sm.convert("RGB").quantize(colors=10, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    q.putalpha(al)
    return obrys(q)


def main(src, out_icns):
    art = pix(Image.open(src), 32)
    iconset = os.path.join(TU, "Pelisek.iconset")
    shutil.rmtree(iconset, ignore_errors=True)
    os.makedirs(iconset)
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            n = base * scale
            k = int(n * 0.86 / art.width)          # celé násobky = ostré pixely
            if k >= 1:
                big = art.resize((art.width * k, art.height * k), Image.NEAREST)
            else:
                big = art.resize((n, max(1, round(art.height * n / art.width))), Image.NEAREST)
            canvas = Image.new("RGBA", (n, n), (0, 0, 0, 0))
            canvas.alpha_composite(big, ((n - big.width) // 2, (n - big.height) // 2))
            name = f"icon_{base}x{base}" + ("@2x" if scale == 2 else "") + ".png"
            canvas.save(os.path.join(iconset, name))
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out_icns], check=True)
    shutil.rmtree(iconset)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
