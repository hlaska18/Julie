#!/usr/bin/env python3
"""Čmuchání po zemi (Karlovy poznámky: „hlavičku k zemi a chodí sem a tam“): z pózy cuch
(hlava u země) udělá 4 snímky chůze cuch_chuze0–3. Zadní i přední nohy domaluje ve fázích
kroku jako art/zadni_nohy.py (úhlopříčný krok: bližší zadní jde s vzdálenější přední);
přední nohy jsou za uchem, proto mají menší krok a ucho se nepřekreslí.

    python3 art/cuch_chuze.py           # zapíše cuch_chuze0–3 do art/sprity/
    python3 art/cuch_chuze.py nahled    # jen náhled do art/navrhy/nohy/cuch.gif
"""
import os, sys
from PIL import Image
import zadni_nohy as z

TU = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.join(TU, "sprity")
HORNI_ZADNI, HORNI_PREDNI, ZEM = 14, 15, 19     # řádky snímku cuch (39 × 20)


def snimky():
    zaklad = Image.open(os.path.join(SPR, "cuch.png")).convert("RGBA")
    w, h = zaklad.size
    vysledek = []
    for f in range(4):
        im = zaklad.copy()
        px = im.load()
        for y in range(HORNI_ZADNI, h):           # zadní nohy
            for x in range(0, 20):
                px[x, y] = (0, 0, 0, 0)
        for y in range(HORNI_PREDNI, h):          # přední nohy (ucho začíná na x = 25)
            for x in range(19, 25):
                px[x, y] = (0, 0, 0, 0)
        # vzdálenější nohy (tmavší) napřed, bližší přes ně
        dx, zd = z.KROK[(f + 2) % 4]
        z.noha(px, w, h, 16, HORNI_ZADNI, ZEM, dx, zd, z.STIN, z.STIN, z.TLAPKA_D, 5)
        dx, zd = z.KROK[f]
        z.noha(px, w, h, 23, HORNI_PREDNI, ZEM, dx * 0.6, zd, z.STIN, z.STIN, z.TLAPKA_D, 4)
        dx, zd = z.KROK[f]
        z.noha(px, w, h, 10, HORNI_ZADNI, ZEM, dx, zd, z.BLIZKA, z.STIN, z.TLAPKA, 6)
        dx, zd = z.KROK[(f + 2) % 4]
        z.noha(px, w, h, 21, HORNI_PREDNI, ZEM, dx * 0.6, zd, z.BLIZKA, z.STIN, z.TLAPKA, 4)
        vysledek.append(im)
    return vysledek


def main():
    nove = snimky()
    if len(sys.argv) > 1 and sys.argv[1] == "nahled":
        out = os.path.join(TU, "navrhy", "nohy")
        os.makedirs(out, exist_ok=True)
        K = 6
        big = [f.resize((f.width * K, f.height * K), Image.NEAREST) for f in nove]
        bg = [Image.new("RGBA", big[0].size, (230, 221, 200, 255)) for _ in big]
        for b, f in zip(bg, big):
            b.alpha_composite(f)
        bg[0].convert("RGB").save(os.path.join(out, "cuch.gif"), save_all=True,
                                  append_images=[b.convert("RGB") for b in bg[1:]], duration=180, loop=0)
        print("náhled:", os.path.join(out, "cuch.gif"))
        return
    for i, f in enumerate(nove):
        f.save(os.path.join(SPR, f"cuch_chuze{i}.png"))
    print("zapsáno: cuch_chuze0–3")


if __name__ == "__main__":
    main()
