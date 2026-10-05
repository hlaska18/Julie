#!/usr/bin/env python3
"""Hrabání: z jednoho snímku se skloněným hrudníkem (hrabani_a) udělá 4 snímky,
ve kterých se přední tlapky zřetelně střídají: tlapka nahoru dopředu → hrabe pod sebe
dozadu → druhá tlapka nahoru → hrabe dozadu. (Higgsfield kreslil tlapky skoro stejně.)

Souřadnice jsou v pixelech snímku 39×26, y roste dolů, zem = poslední řádek.
"""
import os
from PIL import Image, ImageDraw

TU = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.join(TU, "sprity")


def barva(im, xy):
    return im.getpixel(xy)


def noha(d, od, do, tlusta, telo, tlapka):
    d.line([od, do], fill=telo, width=tlusta)
    # tlapka: 2×2 světlejší na konci
    x, y = do
    d.rectangle([x - 1, y - 1, x, y], fill=tlapka)


def main():
    zaklad = Image.open(os.path.join(SPR, "hrabani_a.png")).convert("RGBA")
    w, h = zaklad.size
    zem = h - 1
    from collections import Counter
    def nejcastejsi(x0, y0, x1, y1):
        c = Counter(zaklad.getpixel((x, y)) for x in range(x0, x1) for y in range(y0, y1) if zaklad.getpixel((x, y))[3] > 0)
        return c.most_common(1)[0][0]
    telo_blizko = nejcastejsi(8, 12, 17, 17)          # rezavé tělo (trup)
    telo_daleko = tuple(max(0, int(c * 0.85)) if i < 3 else c for i, c in enumerate(telo_blizko))
    tlapka = nejcastejsi(4, 19, 12, 24)                # světlé tlapky (jako zadní)
    # smazat původní přední nohy (všechno pod hrudí v přední části)
    cista = zaklad.copy()
    px = cista.load()
    for y in range(21, h):
        for x in range(16, w):
            px[x, y] = (0, 0, 0, 0)
    ramena = {"daleko": (21, 20), "blizko": (24, 20)}
    # fáze: (konec vzdálené tlapky, konec blízké tlapky); hlava je nízko, tlapky jdou pod bradu
    faze = [
        ((22, zem), (31, 22)),      # blízká zvednutá dopředu pod bradou
        ((25, 23), (17, zem)),      # blízká hrabe pod sebe dozadu, vzdálená se zvedá
        ((30, 22), (24, zem)),      # vzdálená zvednutá dopředu
        ((16, zem), (27, 23)),      # vzdálená hrabe dozadu, blízká se zvedá
    ]
    for i, (dal, bliz) in enumerate(faze):
        im = cista.copy()
        d = ImageDraw.Draw(im)
        noha(d, ramena["daleko"], dal, 2, telo_daleko, tlapka)
        noha(d, ramena["blizko"], bliz, 3, telo_blizko, tlapka)
        im.save(os.path.join(SPR, f"hrabe{i}.png"))
    print("hrabe0–3 hotovo", zaklad.size)


if __name__ == "__main__":
    main()
