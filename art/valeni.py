#!/usr/bin/env python3
"""Válení na zádech při hlazení (Karlovy poznámky: „hrozně ráda se mazlí a válí sudy“).
Rozřeže list z Higgsfieldu art/listy/valeni.png (varianta A, Karel vybral 11. 10. 2026):
stojící Julie (měřítko), na boku, na zádech s tlapkami nahoru, vrtí se na zádech.
Barvy bere z hotových snímků Julie (stejně jako art/obdobi.py).

    python3 art/valeni.py
"""
import os
from PIL import Image
import rozrez as r
import obdobi as o

TU = os.path.dirname(os.path.abspath(__file__))
JMENA = [None, "valeni_bok", "valeni_zada0", "valeni_zada1"]


def main():
    pal = o.paleta()
    fr = o.snimky(os.path.join(TU, "listy", "valeni.png"))
    assert len(fr) == len(JMENA), f"valeni: našel jsem {len(fr)} snímků, čekal {len(JMENA)}"
    meritko = r.STOJI_SIRKA / (fr[0].width * r.ROZTAZENI_X_JULIE)
    for img, jm in zip(fr, JMENA):
        if jm is None:
            continue
        w = max(1, round(img.width * meritko * r.ROZTAZENI_X_JULIE))
        h = max(1, round(img.height * meritko))
        sm = img.resize((w, h), Image.BOX)
        al = sm.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
        q = sm.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
        q.putalpha(al)
        q = o.osamele(q, set())
        q = q.crop(q.getchannel("A").getbbox())
        q.save(os.path.join(TU, "sprity", jm + ".png"))
        print(f"{jm:14s} {q.width}x{q.height}")


if __name__ == "__main__":
    main()
