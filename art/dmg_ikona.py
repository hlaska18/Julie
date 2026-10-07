#!/usr/bin/env python3
"""Ikona disku DMG: Julie vykukuje z otevřené krabice (Karel vybral variantu B, 7. 10. 2026).

    python3 art/dmg_ikona.py   ->  art/dmg_ikona.png (mřížka 64 × 64 pixelů)

release.sh z ní udělá .VolumeIcon.icns (zvětšení nejbližším sousedem, ostré pixely).
"""
import os
from PIL import Image, ImageDraw

ART = os.path.dirname(os.path.abspath(__file__))
G = 64
TEAL = (11, 122, 117, 255)                       # páska: paleta Minty Fresh z webu
SAND, SAND2, SANDD = (215, 201, 170, 255), (230, 221, 200, 255), (168, 151, 122, 255)


def sprite(jmeno):
    im = Image.open(os.path.join(ART, "sprity", jmeno + ".png")).convert("RGBA")
    return im.crop(im.getbbox())


def main():
    c = Image.new("RGBA", (G, G))
    d = ImageDraw.Draw(c)
    d.polygon([(12, 30), (20, 22), (44, 22), (52, 30)], fill=SANDD)            # zadní chlopně
    s = sprite("sedi")
    c.alpha_composite(s, ((G - s.width) // 2 + 1, 10))                        # Julie
    d.rectangle((10, 34, 53, 59), fill=SAND)                                  # přední stěna
    d.rectangle((10, 34, 53, 35), fill=SAND2)
    d.rectangle((10, 34, 10, 59), fill=SANDD)
    d.rectangle((53, 34, 53, 59), fill=SANDD)
    d.rectangle((10, 59, 53, 59), fill=SANDD)
    d.polygon([(10, 34), (2, 28), (4, 26), (12, 32)], fill=SAND2)             # přední chlopně
    d.polygon([(53, 34), (61, 28), (59, 26), (51, 32)], fill=SAND2)
    d.rectangle((29, 36, 34, 59), fill=TEAL)                                  # páska
    c.alpha_composite(sprite("kost"), (15, 46))                               # kostička na boku
    c.save(os.path.join(ART, "dmg_ikona.png"))
    print("art/dmg_ikona.png")


if __name__ == "__main__":
    main()
