#!/usr/bin/env python3
"""Roční období (zvyky skutečné Julie, Karel 10. 10. 2026): na podzim skákala do hromádek
listí, v zimě do závějí, že jí koukal jen ocas. Rozřeže listy z Higgsfieldu art/listy/podzim.png
(varianta 1) a art/listy/zima.png (varianta 2, Karel vybral 11. 10.) na snímky v art/sprity/;
skok obloukem (snímek „skok“) se hodí do listí i do sněhu.

Každý list: stojící Julie (měřítko), hromádka/závěj, skok/zanoření, uvnitř, otřepání.
Snímky se dělí podle prázdných sloupců (poletující listí a sníh zůstanou u svého snímku).
Programem se navíc dělají nižší hromádky (listi_hromada1–2) a druhá poloha ocasu (snih_ocas1).

    python3 art/obdobi.py
"""
import os
from PIL import Image
import rozrez as r

TU = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.join(TU, "sprity")
LISTI = [(246, 200, 48), (236, 128, 28), (206, 46, 32), (150, 30, 26), (118, 146, 40)]
SNIH = [(250, 252, 255), (222, 232, 244), (176, 194, 218), (118, 138, 170)]
LISTY = {
    "podzim": [None, "listi_hromada", "skok", "listi_uvnitr", "listi_otrepani"],
    "zima": [None, "snih_zavej", "snih_nori", "snih_ocas0", "snih_otrepani"],
}


def paleta():
    """Barvy hotových snímků Julie (už jsou ve společné paletě) + listí + sníh."""
    barvy = []
    for n in ("stoji", "sedi", "lezi", "spi", "skace", "pada", "chuze0", "stekot"):
        im = Image.open(os.path.join(SPR, n + ".png")).convert("RGBA")
        for _, (cr, cg, cb, a) in im.getcolors(1 << 16):
            if a and (cr, cg, cb) not in barvy:
                barvy.append((cr, cg, cb))
    barvy = barvy[: 256 - len(LISTI) - len(SNIH)] + LISTI + SNIH
    p = Image.new("P", (1, 1))
    plochy = [v for c in barvy for v in c]
    p.putpalette(plochy + [0] * (768 - len(plochy)))
    return p


def snimky(path):
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v >= 150 else 0)
    im.putalpha(a)
    px = a.load()
    w, h = a.size
    plne = [any(px[x, y] for y in range(0, h, 2)) for x in range(w)]
    useky, x = [], 0
    while x < w:
        if plne[x]:
            s = x
            while x < w and plne[x]:
                x += 1
            useky.append([s, x])
        else:
            x += 1
    spojene = [useky[0]]
    for s, e in useky[1:]:                 # kousek listí nebo sněhu kousek vedle patří k snímku
        if s - spojene[-1][1] < 18:
            spojene[-1][1] = e
        else:
            spojene.append([s, e])
    out = []
    for s, e in spojene:
        if e - s > 25:
            c = im.crop((s, 0, e, h))
            out.append(c.crop(c.getchannel("A").getbbox()))
    return out


def osamele(im, nechat):
    """Smaže zbloudilé tečky z Higgsfieldu: v oddělených shlucích do 3 pixelů nechá jen listí/sníh."""
    px = im.load()
    w, h = im.size
    videno = set()
    for y0 in range(h):
        for x0 in range(w):
            if px[x0, y0][3] == 0 or (x0, y0) in videno:
                continue
            shluk, zasobnik = [], [(x0, y0)]
            videno.add((x0, y0))
            while zasobnik:
                x, y = zasobnik.pop()
                shluk.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        n = (x + dx, y + dy)
                        if 0 <= n[0] < w and 0 <= n[1] < h and n not in videno and px[n][3]:
                            videno.add(n)
                            zasobnik.append(n)
            if len(shluk) <= 3:
                for p in shluk:
                    if px[p][:3] not in nechat:
                        px[p] = (0, 0, 0, 0)
    return im


def nizsi(im, podil):
    """Nižší hromádka: stejně široká, svisle stlačená (obrys zůstane oblý)."""
    return im.resize((im.width, max(2, round(im.height * podil))), Image.NEAREST)


def ocas_jinam(im):
    """Druhá poloha vrtícího ocasu: horní část nad závějí zrcadlově kolem osy ocasu."""
    px = im.load()
    w, h = im.size
    # horní okraj závěje = první řádek, kde je sníh víc než na šířku ocasu
    rez = next(y for y in range(h) if sum(1 for x in range(w) if px[x, y][3] and px[x, y][:3] in SNIH) > w // 3)
    ocas = [x for y in range(rez) for x in range(w) if px[x, y][3] and px[x, y][:3] not in SNIH]
    osa = (min(ocas) + max(ocas)) / 2
    nove = im.copy()
    npx = nove.load()
    for y in range(rez):
        for x in range(w):
            npx[x, y] = (0, 0, 0, 0)
    for y in range(rez):
        for x in range(w):
            if px[x, y][3]:
                nx = round(2 * osa - x)
                if 0 <= nx < w:
                    npx[nx, y] = px[x, y]
    return nove


def main():
    pal = paleta()
    for list_, jmena in LISTY.items():
        fr = snimky(os.path.join(TU, "listy", list_ + ".png"))
        assert len(fr) == len(jmena), f"{list_}: našel jsem {len(fr)} snímků, čekal {len(jmena)}"
        meritko = r.STOJI_SIRKA / (fr[0].width * r.ROZTAZENI_X_JULIE)
        nechat = set(LISTI if list_ == "podzim" else SNIH)
        for img, jm in zip(fr, jmena):
            if jm is None:
                continue
            w = max(1, round(img.width * meritko * r.ROZTAZENI_X_JULIE))
            h = max(1, round(img.height * meritko))
            sm = img.resize((w, h), Image.BOX)
            al = sm.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
            q = sm.convert("RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGBA")
            q.putalpha(al)
            q = osamele(q, nechat)
            q = q.crop(q.getchannel("A").getbbox())
            q.save(os.path.join(SPR, jm + ".png"))
            print(f"{jm:16s} {q.width}x{q.height}")
            if jm == "listi_hromada":
                for i, podil in ((1, 0.75), (2, 0.5)):
                    nizsi(q, podil).save(os.path.join(SPR, f"listi_hromada{i}.png"))
            if jm == "snih_ocas0":
                ocas_jinam(q).save(os.path.join(SPR, "snih_ocas1.png"))
    print("zapsáno: listi_*, snih_*")


if __name__ == "__main__":
    main()
