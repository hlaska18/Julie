#!/usr/bin/env python3
"""Obrázky pro web v docs/: pózy Julie, ikona pro prohlížeč, náhledy pro sdílení (og.png, og-cs.png).

    python3 tools/web_obrazky.py

Náhledy pro sdílení berou klidový snímek z docs/ukazky/chuze.png (nejdřív spusť tools/ukazky.py).
Potřebuje Pillow a písmo docs/fonts/PixelifySans-Medium.ttf.
"""
import os
from PIL import Image, ImageDraw, ImageFont

KOREN = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPRITY = os.path.join(KOREN, "art", "sprity")
DOCS = os.path.join(KOREN, "docs")
IMG = os.path.join(DOCS, "img")
PISMO = os.path.join(DOCS, "fonts", "PixelifySans-Medium.ttf")
# paleta Minty Fresh (coolors.co)
GROUND, INK, SAND, ACCENT = (240, 243, 245), (25, 83, 95), (215, 201, 170), (123, 45, 38)


def sprite(jmeno):
    im = Image.open(os.path.join(SPRITY, jmeno + ".png")).convert("RGBA")
    return im.crop(im.getbbox())


def nahled(cesta, nadpis, podnadpis):
    W, H = 1200, 630
    im = Image.new("RGB", (W, H), GROUND)
    d = ImageDraw.Draw(im)
    velky = ImageFont.truetype(PISMO, 112)
    maly = ImageFont.truetype(PISMO, 44)
    d.text((60, 44), nadpis, font=velky, fill=INK)
    d.text((64, 176), podnadpis, font=maly, fill=INK)
    # okno se scénou z ukázky (výřez kolem Docku, dvojnásobně, ostré pixely)
    scena = Image.open(os.path.join(DOCS, "ukazky", "chuze.png")).convert("RGB")
    vyrez = scena.crop((0, 40, 560, 200)).resize((1120, 320), Image.NEAREST)
    x, y, b = 40, 262, 6
    d.rectangle((x + 14, y + 14, x + 1120 + 2 * b + 14, y + 320 + 2 * b + 14), fill=INK)      # stín
    d.rectangle((x, y, x + 1120 + 2 * b, y + 320 + 2 * b), fill=INK)
    im.paste(vyrez, (x + b, y + b))
    im.save(cesta, optimize=True)


def main():
    os.makedirs(IMG, exist_ok=True)
    for j in ("sedi", "stekot", "spi"):
        sprite(j).save(os.path.join(IMG, j + ".png"), optimize=True)
    # ikona: hlava Julie ze stojícího snímku
    st = sprite("stoji")
    hlava = st.crop((st.width - 16, 0, st.width, 16))
    hlava.resize((32, 32), Image.NEAREST).save(os.path.join(IMG, "favicon-32.png"), optimize=True)
    dotyk = Image.new("RGBA", (180, 180), SAND + (255,))
    velka = hlava.resize((160, 160), Image.NEAREST)
    dotyk.alpha_composite(velka, (10, 12))
    dotyk.convert("RGB").save(os.path.join(IMG, "apple-touch-icon.png"), optimize=True)
    nahled(os.path.join(IMG, "og.png"), "Julie", "A pixel dachshund that lives on your Dock")
    nahled(os.path.join(IMG, "og-cs.png"), "Julie", "Pixelový jezevčík, který bydlí na tvém Docku")
    print("hotovo:", sorted(os.listdir(IMG)))


if __name__ == "__main__":
    main()
