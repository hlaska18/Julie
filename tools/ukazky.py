#!/usr/bin/env python3
"""Natočí ukázky Julie pro web a README a složí z nich GIFy.

    python3 tools/ukazky.py            # všechny scény
    python3 tools/ukazky.py nora micek # jen některé

Snímky kreslí sama aplikace (Julie --ukazka <scéna> <složka>, viz Sources/Ukazky.swift),
tenhle skript z nich udělá docs/ukazky/<scéna>.gif a docs/ukazky/<scéna>.png (klidový
snímek pro „omezit pohyb“). Potřebuje Pillow a sestavenou aplikaci (./build.sh).
"""
import os, sys, shutil, subprocess, tempfile
from PIL import Image

SCENY = ["chuze", "nora", "pamlsky", "micek", "pelisek", "padak", "veverka"]
APP = os.path.expanduser("~/Applications/Julie.app/Contents/MacOS/Julie")
KOREN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CIL = os.path.join(KOREN, "docs", "ukazky")
FPS = 25
# klidový snímek: kolikátá vteřina scény
KLID = {"chuze": 3.9, "nora": 2.0, "pamlsky": 3.0, "micek": 2.6, "pelisek": 4.0, "padak": 1.5, "veverka": 2.2}


def gif(sc, slozka):
    soubory = sorted(f for f in os.listdir(slozka) if f.endswith(".png"))
    snimky = [Image.open(os.path.join(slozka, f)).convert("RGB") for f in soubory]
    # společná paleta: pixel art má málo barev, většinou se vejdou všechny přesně
    barvy = {}
    for s in snimky[::3]:
        for n, c in s.getcolors(1 << 24) or []:
            barvy[c] = barvy.get(c, 0) + n
    nejcastejsi = [c for c, _ in sorted(barvy.items(), key=lambda kv: -kv[1])[:256]]
    pal = Image.new("P", (1, 1))
    plochy = [v for c in nejcastejsi for v in c]
    pal.putpalette(plochy + [0] * (768 - len(plochy)))
    p = [s.quantize(palette=pal, dither=Image.Dither.NONE) for s in snimky]
    os.makedirs(CIL, exist_ok=True)
    cesta = os.path.join(CIL, sc + ".gif")
    p[0].save(cesta, save_all=True, append_images=p[1:], duration=int(1000 / FPS), loop=0, optimize=False, disposal=1)
    k = min(len(snimky) - 1, int(KLID.get(sc, 1) * FPS))
    snimky[k].save(os.path.join(CIL, sc + ".png"), optimize=True)
    print(f"{sc}: {len(snimky)} snímků, {len(barvy)} barev, {os.path.getsize(cesta) // 1024} kB")


def main():
    sceny = sys.argv[1:] or SCENY
    tmp = tempfile.mkdtemp()
    try:
        for sc in sceny:
            slozka = os.path.join(tmp, sc)
            subprocess.run([APP, "--ukazka", sc, slozka], check=True)
            gif(sc, slozka)
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
