#!/usr/bin/env python3
"""Z obrázku z Higgsfieldu udělá skutečný pixel art: ořízne, zmenší na mřížku,
odstraní poloprůhlednou záři a omezí barvy.

  python3 pixelizuj.py vstup.png vystup.png [sirka_v_pixelech] [pocet_barev]
"""
import sys
from PIL import Image


OUTLINE = (58, 26, 12, 255)


def obrys(im):
    """Kolem siluety přidá 1px tmavý obrys (plátno se zvětší o 1 px na každou stranu)."""
    w, h = im.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.alpha_composite(im, (1, 1))
    a = out.getchannel("A").load()
    px = out.load()
    edge = []
    for y in range(h + 2):
        for x in range(w + 2):
            if a[x, y] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w + 2 and 0 <= ny < h + 2 and a[nx, ny] > 0:
                        edge.append((x, y))
                        break
    for x, y in edge:
        px[x, y] = OUTLINE
    return out


def pixelizuj(src, width=56, colors=8, alpha_cut=150, outline=True):
    im = Image.open(src).convert("RGBA")
    # záře kolem obrysu je poloprůhledná -> pryč
    a = im.getchannel("A").point(lambda v: 255 if v >= alpha_cut else 0)
    im.putalpha(a)
    bbox = a.getbbox()
    im = im.crop(bbox)
    h = max(1, round(im.height * width / im.width))
    # průměr barev v každé buňce mřížky, alfa podle většiny
    small = im.resize((width, h), Image.BOX)
    al = small.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
    rgb = small.convert("RGB").quantize(colors=colors, method=Image.Quantize.MAXCOVERAGE, dither=Image.Dither.NONE).convert("RGB")
    out = rgb.convert("RGBA")
    out.putalpha(al)
    return obrys(out) if outline else out


if __name__ == "__main__":
    src, dst = sys.argv[1], sys.argv[2]
    w = int(sys.argv[3]) if len(sys.argv) > 3 else 56
    c = int(sys.argv[4]) if len(sys.argv) > 4 else 8
    pixelizuj(src, w, c).save(dst)
