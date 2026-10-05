#!/usr/bin/env python3
"""Rozřeže listy z Higgsfieldu (art/listy/*.png) na jednotlivé snímky Julie
v pixelové mřížce (art/sprity/*.png).

Každý list začíná stojící Julií; podle její šířky se celý list zmenší, takže
všechny snímky mají stejné měřítko. Barvy se omezí na společnou paletu.
"""
import os
from PIL import Image
from pixelizuj import obrys

TU = os.path.dirname(os.path.abspath(__file__))
STOJI_SIRKA = 44          # šířka stojící Julie v pixelech (styl podle Karlova obrázku styl_julie.png)
OBRYS = False             # nový styl je bez tmavého obrysu
# Higgsfield kreslí Julii o kus kratší než Karlův obrázek (ten má délku ~2× výšku): protáhnout
ROZTAZENI_X = {"veverka": 1.0, "pelisek": 1.0}
ROZTAZENI_X_JULIE = 1.15
BAREV = 16

LISTY = {
    "chuze":   ["stoji", "chuze0", "chuze1", "chuze2", "chuze3"],
    "klid":    [None, "sedi", "lezi", "spi", "cuch"],
    "stekani": [None, "stekot", None, None],   # hrabání dělá hrabani_tlapky.py
    "drbani":  [None, "drbe0", "drbe1", "protahuje"],
    "vzduch":  [None, "visi", "pada", "skace"],
    "hrabani": [None, "hrabani_a", "hrabani_b", "hrabani_c", "hrabani_d"],
    "micek": [None, "mic_stoji", "mic_chuze0", "mic_chuze1"],
    "veverka": [None, "veverka_sedi", "veverka_bezi0", "veverka_bezi1", "susenka0", "susenka1", "susenka2"],
    "pelisek": [None, "pelisek"],
    "klubicko": [None, "klubicko", "klubicko_hlava"],
    "panacek": [None, "panacek0", "panacek1"],
    "beh": [None, "beh0", "beh1", "funi"],
}
# list s malými předměty (kost je malá) potřebuje nižší práh velikosti
PRAH = {"veverka": 0.03}
# zvláštní zmenšení jednotlivých snímků (sušenky ať jsou menší než Juliina hlava)
SKALA = {"susenka0": 0.68, "susenka1": 0.68, "susenka2": 0.68}


def komponenty(alpha):
    """Souvislé neprůhledné oblasti (4-sousedství), vrací seznam (bbox, plocha)."""
    w, h = alpha.size
    a = alpha.load()
    seen = bytearray(w * h)
    out = []
    for y0 in range(h):
        for x0 in range(w):
            if a[x0, y0] == 0 or seen[y0 * w + x0]:
                continue
            stack = [(x0, y0)]
            seen[y0 * w + x0] = 1
            minx = maxx = x0
            miny = maxy = y0
            n = 0
            while stack:
                x, y = stack.pop()
                n += 1
                minx, maxx, miny, maxy = min(minx, x), max(maxx, x), min(miny, y), max(maxy, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and a[nx, ny] and not seen[ny * w + nx]:
                        seen[ny * w + nx] = 1
                        stack.append((nx, ny))
            out.append(((minx, miny, maxx + 1, maxy + 1), n))
    return out


def snimky(path, prah=0.15):
    im = Image.open(path).convert("RGBA")
    a = im.getchannel("A").point(lambda v: 255 if v >= 150 else 0)
    im.putalpha(a)
    # komponenty hledáme na zmenšené masce (rychlost), pak škálujeme zpět
    k = 4
    small = a.resize((a.width // k, a.height // k), Image.NEAREST)
    comps = komponenty(small)
    big = max(c[1] for c in comps)
    hlavni = [c for c in comps if c[1] > big * prah]
    hlavni.sort(key=lambda c: c[0][0])
    frames = []
    for (x0, y0, x1, y1), _ in hlavni:
        box = (x0 * k - k, y0 * k - k, x1 * k + k, y1 * k + k)
        crop = im.crop(box)
        # zbytky jiných komponent (zvukové čárky, hlína) uvnitř výřezu nevadí – jsou malé
        frames.append(crop)
    return frames


def main():
    os.makedirs(os.path.join(TU, "sprity"), exist_ok=True)
    vysledek = {}
    for list_, jmena in LISTY.items():
        fr = snimky(os.path.join(TU, "listy", list_ + ".png"), PRAH.get(list_, 0.15))
        assert len(fr) == len(jmena), f"{list_}: našel jsem {len(fr)} snímků, čekal {len(jmena)}"
        meritko = STOJI_SIRKA / (fr[0].getchannel("A").getbbox()[2] * ROZTAZENI_X.get(list_, ROZTAZENI_X_JULIE))
        for img, jm in zip(fr, jmena):
            if jm is None:
                continue
            bb = img.getchannel("A").getbbox()
            img = img.crop(bb)
            k = SKALA.get(jm, 1.0)
            w = max(1, round(img.width * meritko * ROZTAZENI_X.get(list_, ROZTAZENI_X_JULIE) * k))
            h = max(1, round(img.height * meritko * k))
            sm = img.resize((w, h), Image.BOX)
            al = sm.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
            vysledek[jm] = (sm.convert("RGB"), al, list_ in ROZTAZENI_X)
    # společná paleta podle stojící Julie + všech snímků
    vzor = Image.new("RGB", (sum(r.width for r, _, _ in vysledek.values()), max(r.height for r, _, _ in vysledek.values())))
    x = 0
    for r, _, _ in vysledek.values():
        vzor.paste(r, (x, 0))
        x += r.width
    zaklad = vzor.quantize(colors=BAREV, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    barvy = zaklad.getpalette()[: BAREV * 3]
    # barvy, které Julii dělají Julií, nesmí zaniknout: černé uši a ocas, růžový obojek, lesk v oku
    barvy += [20, 16, 14,  69, 35, 26,  232, 120, 150,  250, 246, 240,
              214, 140, 70,  232, 205, 160,
              # šedobílý pelíšek s nádechem hnědé (lem, stín lemu, polštář, stín polštáře)
              176, 166, 156,  142, 132, 122,  234, 228, 218,  206, 198, 187,
              # sušenky: zlatavá a načervenalá
              222, 172, 98,  190, 140, 70,  214, 112, 92,  176, 84, 66,
              # tenisák v tlamě
              205, 220, 70,  160, 175, 40]
    paleta = Image.new("P", (1, 1))
    paleta.putpalette(barvy + [0, 0, 0] * (256 - len(barvy) // 3))
    for jm, (rgb, al, vlastni) in vysledek.items():
        if vlastni:
            # veverka, sušenky, pelíšek: vlastní paleta (jinak se slijí do Juliiných oranžových)
            q = rgb.quantize(colors=10, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
        else:
            q = rgb.quantize(palette=paleta, dither=Image.Dither.NONE).convert("RGBA")
        q.putalpha(al)
        if OBRYS:
            q = obrys(q)
        q.save(os.path.join(TU, "sprity", jm + ".png"))
        print(f"{jm:10s} {q.width}x{q.height}")


if __name__ == "__main__":
    main()
    # hrabání se skládá z jednoho snímku a ručně kreslených tlapek (snímky hrabe0–3)
    import hrabani_tlapky
    hrabani_tlapky.main()
