#!/usr/bin/env python3
"""Gera os sprites do Dracula (pixel art, 32x32 por frame, fita horizontal).
Uso: python3 generate_sprites.py  -> escreve em ../sprites
"""
import os, random
from PIL import Image, ImageDraw

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprites")
os.makedirs(OUT_DIR, exist_ok=True)

T = (0, 0, 0, 0)
OUTLINE = (24, 8, 22, 255)
SKIN = (228, 206, 218, 255)
SKIN_SH = (184, 150, 178, 255)
HAIR = (30, 20, 42, 255)
HAIR_HI = (66, 48, 92, 255)
CAPE = (122, 22, 54, 255)
CAPE_DK = (74, 10, 38, 255)
CAPE_HI = (172, 38, 74, 255)
SUIT = (44, 32, 66, 255)
SUIT_HI = (78, 60, 108, 255)
SHIRT = (214, 190, 205, 255)
EYE = (255, 64, 84, 255)
EYE_GLOW = (255, 140, 150, 255)
FANG = (255, 255, 255, 255)
GOLD = (236, 190, 84, 255)
SHOE = (20, 12, 26, 255)
BLOOD = (200, 24, 52, 255)
BLOOD_HI = (255, 96, 110, 255)
BLOOD_DK = (112, 8, 34, 255)
SHADOW = (0, 0, 0, 90)
WHITE = (255, 255, 255, 255)

S = 32


def px(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            px(img, xx, yy, c)


def outline(img, color=OUTLINE):
    src = img.copy()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] > 0:
                        img.putpixel((x, y), color)
                        break


def shadow(img):
    base = Image.new("RGBA", img.size, T)
    d = ImageDraw.Draw(base)
    d.ellipse((7, 28, 24, 31), fill=SHADOW)
    base.alpha_composite(img)
    return base


def dracula(dy=0, spread=0, leg=0, arms="down", mouth=False, flare=0, kneel=0):
    """Desenha o Dracula de frente. dy = balanço vertical, spread = abertura da capa,
    leg = -1/0/1 passo, arms = down|up|wide, mouth = boca aberta (presas)."""
    im = Image.new("RGBA", (S, S), T)
    y0 = dy + kneel

    # --- capa (atrás) ---
    for i, y in enumerate(range(13 + y0, 28 + y0 + flare)):
        grow = int(i * 0.45) + spread
        x1 = 7 - grow
        x2 = 24 + grow
        c = CAPE if i % 5 != 4 else CAPE_DK
        rect(im, x1, y, x2 - x1 + 1, 1, c)
        px(im, x1 + 1, y, CAPE_HI)
        px(im, x2 - 1, y, CAPE_DK)
    # barra ondulada da capa
    yb = 27 + y0 + flare
    for x in range(4 - spread - 4, 28 + spread + 4):
        if (x // 2) % 2 == 0:
            px(im, x, yb + 1, CAPE_DK)
    # gola alta (asas da capa atrás da cabeça)
    for i in range(7):
        rect(im, 8 - i // 3, 6 + y0 + i, 2 + i // 3, 1, CAPE_DK)
        rect(im, 22 + 0, 6 + y0 + i, 2 + i // 3, 1, CAPE_DK)
    rect(im, 9, 9 + y0, 14, 6, CAPE_DK)
    rect(im, 8, 7 + y0, 3, 5, CAPE)
    rect(im, 21, 7 + y0, 3, 5, CAPE)
    px(im, 8, 6 + y0, CAPE_HI)
    px(im, 23, 6 + y0, CAPE_HI)

    # --- pernas ---
    if not kneel:
        l_up = 1 if leg == 1 else 0
        r_up = 1 if leg == -1 else 0
        rect(im, 12, 25 + y0 - l_up, 3, 4 - 0, SUIT)
        rect(im, 17, 25 + y0 - r_up, 3, 4 - 0, SUIT)
        rect(im, 11, 28 + y0 - l_up, 4, 2, SHOE)
        rect(im, 17, 28 + y0 - r_up, 4, 2, SHOE)

    # --- tronco ---
    rect(im, 11, 14 + y0, 10, 11, SUIT)
    rect(im, 11, 14 + y0, 1, 11, SUIT_HI)
    rect(im, 14, 14 + y0, 4, 7, SHIRT)           # camisa
    rect(im, 15, 14 + y0, 2, 8, BLOOD)           # gravata/medalhão
    px(im, 15, 22 + y0, GOLD)
    px(im, 16, 22 + y0, GOLD)
    rect(im, 11, 22 + y0, 10, 1, GOLD)           # cinto
    px(im, 13, 17 + y0, GOLD)
    px(im, 18, 17 + y0, GOLD)

    # --- braços ---
    if arms == "down":
        rect(im, 8, 15 + y0, 3, 7, SUIT)
        rect(im, 21, 15 + y0, 3, 7, SUIT)
        rect(im, 8, 22 + y0, 3, 2, SKIN)
        rect(im, 21, 22 + y0, 3, 2, SKIN)
    elif arms == "up":
        rect(im, 7, 11 + y0, 3, 6, SUIT)
        rect(im, 22, 11 + y0, 3, 6, SUIT)
        rect(im, 6, 8 + y0, 4, 3, SKIN)
        rect(im, 22, 8 + y0, 4, 3, SKIN)
        for (cx, cy) in ((8, 6), (23, 6)):
            rect(im, cx - 1, cy - 1 + y0, 3, 3, BLOOD)
            px(im, cx, cy + y0, BLOOD_HI)
    elif arms == "wide":
        rect(im, 3, 15 + y0, 8, 3, SUIT)
        rect(im, 21, 15 + y0, 8, 3, SUIT)
        rect(im, 1, 15 + y0, 3, 3, SKIN)
        rect(im, 28, 15 + y0, 3, 3, SKIN)
        for (cx, cy) in ((1, 13), (29, 13)):
            rect(im, cx, cy + y0, 2, 2, BLOOD_HI)

    # --- cabeça ---
    rect(im, 11, 4 + y0, 10, 10, SKIN)
    rect(im, 11, 12 + y0, 10, 2, SKIN_SH)
    rect(im, 11, 4 + y0, 10, 1, HAIR)
    rect(im, 10, 3 + y0, 12, 2, HAIR)
    rect(im, 11, 5 + y0, 10, 2, HAIR)
    # bico de viúva (V no cabelo)
    px(im, 13, 7 + y0, HAIR); px(im, 14, 7 + y0, HAIR)
    px(im, 17, 7 + y0, HAIR); px(im, 18, 7 + y0, HAIR)
    px(im, 15, 7 + y0, SKIN_SH); px(im, 16, 7 + y0, SKIN_SH)
    px(im, 12, 3 + y0, HAIR_HI); px(im, 13, 3 + y0, HAIR_HI)
    rect(im, 10, 6 + y0, 1, 4, HAIR)
    rect(im, 21, 6 + y0, 1, 4, HAIR)
    # olhos vermelhos
    rect(im, 12, 9 + y0, 3, 2, EYE)
    rect(im, 17, 9 + y0, 3, 2, EYE)
    px(im, 12, 9 + y0, EYE_GLOW)
    px(im, 17, 9 + y0, EYE_GLOW)
    rect(im, 12, 8 + y0, 3, 1, HAIR)
    rect(im, 17, 8 + y0, 3, 1, HAIR)
    # boca / presas
    if mouth:
        rect(im, 14, 12 + y0, 4, 2, BLOOD_DK)
        px(im, 14, 12 + y0, FANG); px(im, 17, 12 + y0, FANG)
        px(im, 14, 13 + y0, FANG); px(im, 17, 13 + y0, FANG)
    else:
        rect(im, 14, 12 + y0, 4, 1, BLOOD_DK)
        px(im, 14, 13 + y0, FANG); px(im, 17, 13 + y0, FANG)
    return im


def finish(im):
    outline(im)
    return shadow(im)


def tint(im, color, amt):
    out = im.copy()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = out.getpixel((x, y))
            if a:
                out.putpixel((x, y), (int(r + (color[0] - r) * amt), int(g + (color[1] - g) * amt),
                                      int(b + (color[2] - b) * amt), a))
    return out


def strip(frames, name, size=S):
    sheet = Image.new("RGBA", (size * len(frames), size), T)
    for i, f in enumerate(frames):
        sheet.paste(f, (i * size, 0))
    sheet.save(os.path.join(OUT_DIR, name))
    return sheet


def bat(size, wing, mouth=False):
    """wing: 0 = asa pra cima, 1 = meio, 2 = pra baixo"""
    s = size / 32.0
    im = Image.new("RGBA", (size, size), T)
    d = ImageDraw.Draw(im)

    def P(pts):
        return [(int(round(x * s)), int(round(y * s))) for x, y in pts]

    wy = {0: -8, 1: -2, 2: 6}[wing]
    left = [(14, 15), (9, 10 + wy), (3, 6 + wy), (1, 12 + wy // 2 + 2), (5, 14 + wy // 2 + 2),
            (7, 20 + wy // 3), (11, 18), (14, 20)]
    right = [(31 - x, y) for x, y in left]
    d.polygon(P(left), fill=CAPE_DK)
    d.polygon(P(right), fill=CAPE_DK)
    # membrana mais clara
    inner_l = [(14, 16), (10, 12 + wy // 2), (6, 12 + wy // 2 + 1), (8, 18 + wy // 3), (12, 18)]
    d.polygon(P(inner_l), fill=CAPE)
    d.polygon(P([(31 - x, y) for x, y in inner_l]), fill=CAPE)
    # corpo
    d.ellipse(P([(12, 11), (19, 21)]), fill=SUIT)
    d.ellipse(P([(12, 7), (19, 14)]), fill=SUIT_HI)
    # orelhas
    d.polygon(P([(12, 8), (12, 3), (15, 7)]), fill=SUIT)
    d.polygon(P([(19, 8), (19, 3), (16, 7)]), fill=SUIT)
    # olhos
    ex = [int(13 * s), int(17 * s)]
    ey = int(10 * s)
    for e in ex:
        px(im, e, ey, EYE)
        if size >= 32:
            px(im, e + 1, ey, EYE)
    if mouth and size >= 32:
        px(im, int(14 * s), int(13 * s), FANG)
        px(im, int(17 * s), int(13 * s), FANG)
    outline(im)
    return im


def orb(size=16, phase=0):
    im = Image.new("RGBA", (size, size), T)
    c = size // 2
    r = 5 + (1 if phase % 2 else 0)
    for y in range(size):
        for x in range(size):
            dd = ((x - c + 0.5) ** 2 + (y - c + 0.5) ** 2) ** 0.5
            if dd <= r:
                col = BLOOD
                if dd > r - 1.5:
                    col = BLOOD_DK
                if dd < 2.2:
                    col = BLOOD_HI
                im.putpixel((x, y), col)
    px(im, c - 2 + (phase % 2), c - 2, WHITE)
    outline(im)
    return im


def main():
    # idle (4)
    idle = [finish(dracula(dy=d, spread=s)) for d, s in ((0, 0), (-1, 1), (0, 1), (1, 0))]
    strip(idle, "dracula_idle.png")

    # walk (4)
    walk = [finish(dracula(dy=d, leg=l, spread=s)) for d, l, s in ((0, 1, 0), (-1, 0, 1), (0, -1, 0), (-1, 0, 1))]
    strip(walk, "dracula_walk.png")

    # cast / ataque (4): braços sobem, boca abre
    cast = [finish(dracula(arms="down", spread=0)),
            finish(dracula(arms="up", dy=-1, spread=1)),
            finish(dracula(arms="up", dy=-1, spread=2, mouth=True, flare=1)),
            finish(dracula(arms="wide", spread=2, mouth=True, flare=1))]
    strip(cast, "dracula_cast.png")

    # grito / invocação (4)
    roar = [finish(dracula(arms="wide", dy=d, spread=s, mouth=True, flare=1))
            for d, s in ((0, 2), (-1, 3), (0, 3), (-1, 2))]
    strip(roar, "dracula_roar.png")

    # dano (2)
    h1 = tint(finish(dracula(dy=1, spread=0, mouth=True)), WHITE, 0.55)
    h2 = tint(finish(dracula(dy=0, spread=1, mouth=True)), (255, 90, 110, 255), 0.35)
    strip([h1, h2], "dracula_hurt.png")

    # morte (6): ajoelha e desfaz em cinzas
    random.seed(7)
    base = finish(dracula(kneel=3, mouth=True))
    death = [tint(finish(dracula(dy=1, mouth=True)), WHITE, 0.4), base]
    pixels = [(x, y) for y in range(S) for x in range(S) if base.getpixel((x, y))[3] > 0]
    random.shuffle(pixels)
    for step in (0.25, 0.5, 0.75, 1.0):
        f = base.copy()
        for (x, y) in pixels[: int(len(pixels) * step)]:
            f.putpixel((x, y), T)
        # cinzas caindo
        for (x, y) in pixels[int(len(pixels) * step): int(len(pixels) * step) + 1]:
            pass
        death.append(f)
    strip(death, "dracula_death.png")

    # forma de morcego (4)
    batf = [bat(32, w, mouth=True) for w in (0, 1, 2, 1)]
    strip([shadow(b) if False else b for b in batf], "dracula_bat.png")

    # morcego pequeno (lacaio) 16x16 (4)
    mini = [bat(16, w) for w in (0, 1, 2, 1)]
    strip(mini, "minion_bat.png", size=16)

    # orbe de sangue 16x16 (4)
    strip([orb(16, i) for i in range(4)], "blood_orb.png", size=16)

    # ícone para a barra de vida (16x16)
    icon = idle[0].crop((8, 1, 24, 17))
    icon.save(os.path.join(OUT_DIR, "dracula_icon.png"))

    # preview ampliada
    names = ["dracula_idle", "dracula_walk", "dracula_cast", "dracula_roar", "dracula_hurt",
             "dracula_death", "dracula_bat"]
    imgs = [Image.open(os.path.join(OUT_DIR, n + ".png")) for n in names]
    W = max(i.width for i in imgs)
    prev = Image.new("RGBA", (W, 32 * len(imgs)), (22, 28, 40, 255))
    for i, im in enumerate(imgs):
        prev.alpha_composite(im, (0, i * 32))
    prev = prev.resize((prev.width * 4, prev.height * 4), Image.NEAREST)
    prev.save(os.path.join(OUT_DIR, "_preview_x4.png"))
    print("ok")


if __name__ == "__main__":
    main()
