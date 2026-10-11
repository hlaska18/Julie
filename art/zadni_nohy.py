#!/usr/bin/env python3
"""Zadní nohy při chůzi: Higgsfield je nakreslil skoro stejně ve všech snímcích (a s míčkem
v tlamě má chůze jen dva snímky), takže to vypadalo, že je Julie táhne za sebou.
Skript zadní nohy smaže a domaluje je ve čtyřech fázích kroku: bližší a vzdálenější noha
se střídají (vzad – přenos se zvednutou tlapkou – vpřed – pod tělem). Tělo, hlava,
přední nohy i míček zůstávají ze snímků z Higgsfieldu.

    python3 art/zadni_nohy.py nahled      # jen náhled do art/navrhy/nohy/ (nic nepřepisuje)
    python3 art/zadni_nohy.py             # zapíše chuze0–3 a mic_chuze0–3 do art/sprity/

Karel 11. 10. 2026 vybral variantu A (celé zadní nohy nově, širší stehno); B nechávala
huňatá stehna a hýbala jen spodkem nohou. Opakované spuštění dá stejný výsledek.

Souřadnice v pixelech snímku, y roste dolů. Spouští se po art/rozrez.py (ten snímky přepíše).
"""
import os, sys
from PIL import Image

TU = os.path.dirname(os.path.abspath(__file__))
SPR = os.path.join(TU, "sprity")

BLIZKA = (0x9f, 0x44, 0x1e, 255)       # rezavá srst bližší nohy
STIN = (0x88, 0x3d, 0x1d, 255)         # zadní hrana a vzdálenější noha
TLAPKA = (0xce, 0x6d, 0x35, 255)       # světlá tlapka
TLAPKA_D = (0xa7, 0x4c, 0x22, 255)     # tlapka vzdálenější nohy

# fáze bližší nohy: (posun chodidla vůči kyčli, zvednutí); vzdálenější noha je o dvě fáze dál
KROK = [(-3, 0), (-1, 1), (2, 0), (0, 0)]


def noha(px, w, h, kycel, horni, zem, dx, zdvih, srst, hrana, tlapka, siroka):
    """Noha od kyčle (x, horni) šikmo k chodidlu (x+dx, zem-zdvih). `siroka` = šířka nahoře
    (stehno), dole se zúží na 3 px; zadní hrana je tmavší (srst), tlapka o pixel delší dopředu."""
    spodek = zem - zdvih
    vyska = max(1, spodek - horni)
    for y in range(horni, spodek):
        t = (y - horni) / vyska
        cx = kycel + dx * t
        sirka = max(3, round(siroka - (siroka - 3) * min(1, t * 1.6)))
        x0 = int(round(cx - sirka / 2))
        for x in range(x0, x0 + sirka):
            if 0 <= x < w and 0 <= y < h:
                px[x, y] = hrana if x == x0 else srst
    x0 = int(round(kycel + dx - 1.5))
    for x in range(x0, x0 + 4):
        if 0 <= x < w and 0 <= spodek < h:
            px[x, spodek] = tlapka


def stehna(im, radek, deleni):
    """Středy zadních stehen v daném řádku (bližší vzadu, vzdálenější blíž středu těla)."""
    w = im.width
    plne = [x for x in range(0, deleni + 1) if im.getpixel((x, radek))[3] > 128]
    if not plne:
        return 10, 17
    shluky, zac, pred = [], plne[0], plne[0]
    for x in plne[1:]:
        if x != pred + 1:
            shluky.append((zac, pred)); zac = x
        pred = x
    shluky.append((zac, pred))
    if len(shluky) >= 2:
        a, b = shluky[0], shluky[-1]
        return (a[0] + a[1]) / 2, (b[0] + b[1]) / 2
    a = shluky[0]
    stred = (a[0] + a[1]) / 2
    return stred - 2, stred + 2


def predelej(zaklad, faze, horni, zem, deleni, kycle, varianta="A"):
    im = zaklad.copy()
    px = im.load()
    w, h = im.size
    if varianta == "B":
        # huňatá stehna zůstanou, kráčí holeně a tlapky (od dvou řádků pod břichem)
        horni = horni + 2
        kycle = stehna(zaklad, horni - 1, deleni)
        siroka = (4, 3)
    else:
        siroka = (6, 5)
    for y in range(horni, h):
        for x in range(0, deleni + 1):
            px[x, y] = (0, 0, 0, 0)
    blizka_k, daleka_k = kycle
    dx, zd = KROK[(faze + 2) % 4]
    noha(px, w, h, daleka_k, horni, zem, dx, zd, STIN, STIN, TLAPKA_D, siroka[1])
    dx, zd = KROK[faze]
    noha(px, w, h, blizka_k, horni, zem, dx, zd, BLIZKA, STIN, TLAPKA, siroka[0])
    return im


def sady(varianta="A"):
    nacti = lambda n: Image.open(os.path.join(SPR, n + ".png")).convert("RGBA")
    chuze = [nacti(f"chuze{i}") for i in range(4)]
    mic = [nacti("mic_chuze0"), nacti("mic_chuze1")]
    nove_chuze = [predelej(chuze[i], i, 17, 21, 20, (10, 17), varianta) for i in range(4)]
    nove_mic = [predelej(mic[i % 2], i, 16, 19, 20, (10, 17), varianta) for i in range(4)]
    return chuze, mic, nove_chuze, nove_mic


def nahled(chuze, mic, nove_chuze, nove_mic):
    """Animovaný náhled: nahoře teď, dole nově; vlevo chůze, vpravo s míčkem. 4× zvětšeno."""
    out = os.path.join(TU, "navrhy", "nohy")
    os.makedirs(out, exist_ok=True)
    K, W, H = 4, 560, 260
    bg = (230, 221, 200, 255)
    snimky = []
    for t in range(24):
        c = Image.new("RGBA", (W, H), bg)
        for radek, (a, b) in enumerate([(chuze, mic), (nove_chuze, nove_mic)]):
            fa = a[t % len(a)]
            fb = b[t % len(b)]
            for sloupec, f in enumerate([fa, fb]):
                big = f.resize((f.width * K, f.height * K), Image.NEAREST)
                x = 20 + sloupec * 280
                y = 20 + radek * 125 + (22 - f.height) * K // 2 * 0
                c.alpha_composite(big, (x + (45 * K // 2 - big.width // 2) // 2, y + 110 - big.height))
        snimky.append(c.convert("RGB"))
    snimky[0].save(os.path.join(out, "porovnani.gif"), save_all=True, append_images=snimky[1:], duration=140, loop=0)
    for i, f in enumerate(nove_chuze):
        f.resize((f.width * 8, f.height * 8), Image.NEAREST).save(os.path.join(out, f"chuze{i}.png"))
    for i, f in enumerate(nove_mic):
        f.resize((f.width * 8, f.height * 8), Image.NEAREST).save(os.path.join(out, f"mic_chuze{i}.png"))
    print("náhled:", os.path.join(out, "porovnani.gif"))


def main():
    chuze, mic, nove_chuze, nove_mic = sady("A")
    if len(sys.argv) > 1 and sys.argv[1] == "nahled":
        nahled(chuze, mic, nove_chuze, nove_mic)
        return
    for i, f in enumerate(nove_chuze):
        f.save(os.path.join(SPR, f"chuze{i}.png"))
    for i, f in enumerate(nove_mic):
        f.save(os.path.join(SPR, f"mic_chuze{i}.png"))
    print("zapsáno: chuze0–3, mic_chuze0–3")


if __name__ == "__main__":
    main()
