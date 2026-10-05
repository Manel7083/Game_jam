#!/usr/bin/env python3
"""Gera a arte pixel-art do level A Gaiola dos Guardioes (mesma paleta da arena do castelo / Dracula).
Uso: python3 generate_gaiola_art.py  ->  ../sprites/*.png
Saidas: arena_gaiola.png (896x640), cage_bars.png, lock.png, revolver.png, shard.png,
        demon_bruto.png / demon_arremessador.png / demon_rei.png (5 frames de 32x32: estatua, idle1, idle2, aviso, ataque)"""
import os, random
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "sprites")
os.makedirs(OUT, exist_ok=True)
random.seed(21)

OUTLINE = (14, 8, 20, 255)
STONE_A = (24, 34, 42); STONE_B = (29, 41, 51); GROUT = (13, 19, 25); CRACK = (11, 15, 21)
BR1 = (44, 46, 74); BR2 = (54, 56, 88); BR_DK = (30, 30, 54); MORTAR = (21, 21, 37); BR_HI = (78, 80, 118)
C1 = (112, 30, 52); C2 = (142, 46, 70); C_DK = (82, 18, 38); GOLD = (214, 170, 74); GOLD_DK = (150, 110, 46)
IRON = (62, 64, 82); IRON_HI = (118, 122, 150); IRON_DK = (34, 34, 50)


def jitter(c, a=4):
    return tuple(max(0, min(255, v + random.randint(-a, a))) for v in c[:3]) + (255,)


def outline(layer, col=OUTLINE):
    src = layer.copy(); w, h = layer.size
    for y in range(h):
        for x in range(w):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and src.getpixel((nx, ny))[3] > 0:
                        layer.putpixel((x, y), col); break
    return layer


# =============================================================== ARENA 896x640
W, H = 896, 640
img = Image.new("RGBA", (W, H), (0, 0, 0, 255)); d = ImageDraw.Draw(img)


def rect(x0, y0, x1, y1, c):
    d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=c)


for ty in range(H // 16):
    for tx in range(W // 16):
        base = STONE_A if (tx + ty) % 2 else STONE_B
        x, y = tx * 16, ty * 16
        rect(x, y, x + 16, y + 16, jitter(base, 2))
        for _ in range(16):
            img.putpixel((x + random.randint(1, 14), y + random.randint(1, 14)), jitter(base, 6))
        rect(x, y + 15, x + 16, y + 16, GROUT); rect(x + 15, y, x + 16, y + 16, GROUT)
        rect(x, y, x + 16, y + 1, jitter((base[0] + 6, base[1] + 7, base[2] + 8), 1))
for _ in range(40):
    x, y = random.randint(48, W - 48), random.randint(80, H - 48)
    for _ in range(random.randint(10, 26)):
        img.putpixel((x, y), CRACK + (255,)); x += random.choice((-1, 0, 1, 1)); y += random.choice((0, 1, 1, -1))
stain = Image.new("RGBA", (W, H), (0, 0, 0, 0)); sd = ImageDraw.Draw(stain)
for _ in range(16):
    cx, cy = random.randint(80, W - 80), random.randint(130, H - 70); r = random.randint(6, 18)
    sd.ellipse((cx - r, cy - r // 2, cx + r, cy + r // 2), fill=(96, 14, 34, 150))
    for _ in range(random.randint(4, 9)):
        sx, sy = cx + random.randint(-r - 8, r + 8), cy + random.randint(-r, r)
        sd.rectangle((sx, sy, sx + 1, sy + 1), fill=(130, 20, 44, 170))
img.alpha_composite(stain); d = ImageDraw.Draw(img)

# circulo runico (centro do salao)
CC = (448, 372)
RUNE = (150, 36, 62, 255); RUNE_DK = (96, 20, 42, 255)
for r, col in ((124, RUNE_DK), (120, RUNE), (96, RUNE_DK), (92, RUNE)):
    d.ellipse((CC[0] - r, CC[1] - int(r * .72), CC[0] + r, CC[1] + int(r * .72)), outline=col, width=2)
import math
for i in range(8):
    a = i * math.pi / 4
    p0 = (CC[0] + math.cos(a) * 92, CC[1] + math.sin(a) * 92 * .72)
    p1 = (CC[0] + math.cos(a) * 124, CC[1] + math.sin(a) * 124 * .72)
    d.line((p0, p1), fill=RUNE, width=2)
    gx, gy = CC[0] + math.cos(a) * 108, CC[1] + math.sin(a) * 108 * .72
    d.rectangle((gx - 2, gy - 2, gx + 2, gy + 2), outline=RUNE, width=1)
d.polygon([(CC[0], CC[1] - 30), (CC[0] + 26, CC[1] + 20), (CC[0] - 26, CC[1] + 20)], outline=RUNE, width=2)

# plintos das estatuas (pes dos guardioes)
PLINTH = [(208, 262), (448, 330), (688, 262)]
for (px, py) in PLINTH:
    d.ellipse((px - 30, py - 10, px + 30, py + 12), fill=OUTLINE)
    d.ellipse((px - 28, py - 9, px + 28, py + 9), fill=(54, 66, 80, 255))
    d.ellipse((px - 22, py - 6, px + 22, py + 6), fill=(44, 56, 70, 255))
    d.ellipse((px - 22, py - 6, px + 22, py + 6), outline=RUNE, width=1)


def bricks(x0, y0, x1, y1):
    row = 0
    for y in range(y0, y1, 8):
        off = 8 if row % 2 else 0
        for x in range(x0 - off, x1, 16):
            bx0, bx1 = max(x, x0), min(x + 16, x1)
            if bx1 <= bx0: continue
            c = random.choice((BR1, BR2, BR1, BR2, BR_DK))
            rect(bx0, y, bx1, min(y + 8, y1), jitter(c, 3)); rect(bx0, min(y + 7, y1 - 1), bx1, min(y + 8, y1), MORTAR)
            if bx1 - bx0 == 16: rect(bx1 - 1, y, bx1, min(y + 8, y1), MORTAR)
            if random.random() < 0.5: rect(bx0, y, bx1, y + 1, BR_HI)
        row += 1


bricks(0, 0, W, 64); bricks(0, 64, 32, H); bricks(W - 32, 64, W, H); bricks(0, H - 32, W, H)
rect(0, 0, W, 6, BR_DK)
for x in range(0, W, 32): rect(x, 0, x + 16, 3, (18, 18, 32))
for i in range(10):
    a = int(110 * (1 - i / 10))
    img.alpha_composite(Image.new("RGBA", (W - 64, 1), (0, 0, 0, a)), (32, 64 + i))
    img.alpha_composite(Image.new("RGBA", (W - 64, 1), (0, 0, 0, a)), (32, H - 33 - i))
    img.alpha_composite(Image.new("RGBA", (1, H - 96), (0, 0, 0, a)), (32 + i, 64))
    img.alpha_composite(Image.new("RGBA", (1, H - 96), (0, 0, 0, a)), (W - 33 - i, 64))
d = ImageDraw.Draw(img)


def flame(cx, cy, purple=False):
    layers = [((150, 40, 60), 6), ((240, 110, 40), 4), ((255, 205, 100), 2)]
    if purple: layers = [((90, 40, 140), 6), ((190, 90, 220), 4), ((245, 190, 255), 2)]
    for col, r in layers: d.polygon([(cx, cy - r * 2), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=col)


def sconce(cx, cy, purple=False):
    rect(cx - 2, cy + 2, cx + 3, cy + 10, OUTLINE); rect(cx - 1, cy + 3, cx + 2, cy + 9, (70, 50, 60))
    rect(cx - 4, cy, cx + 5, cy + 3, OUTLINE); rect(cx - 3, cy + 1, cx + 4, cy + 2, GOLD_DK); flame(cx, cy - 2, purple)


for sy in (176, 336, 496): sconce(16, sy); sconce(W - 16, sy)
for sx in (176, 320, 576, 720): sconce(sx, 28, purple=True)

# correntes e gaiolas vazias penduradas na parede do fundo
for gx in (112, 784):
    for yy in range(6, 26, 4): rect(gx - 1, yy, gx + 1, yy + 3, IRON_HI if (yy // 4) % 2 else IRON)
    rect(gx - 11, 26, gx + 12, 28, OUTLINE); rect(gx - 10, 26, gx + 11, 27, IRON_HI)
    for bx in range(gx - 9, gx + 11, 4): rect(bx, 28, bx + 1, 50, OUTLINE); rect(bx, 28, bx + 1, 49, IRON)
    rect(gx - 11, 50, gx + 12, 53, OUTLINE); rect(gx - 10, 50, gx + 11, 52, IRON_DK)
    rect(gx - 4, 44, gx + 5, 49, (210, 205, 190, 255)); rect(gx - 2, 45, gx - 1, 47, OUTLINE); rect(gx + 2, 45, gx + 3, 47, OUTLINE)

# dais da gaiola (degraus como o trono do castelo)
rect(352, 64, 544, 72, (36, 52, 64)); rect(352, 72, 544, 80, (31, 45, 56))
rect(376, 80, 520, 88, (36, 52, 64)); rect(376, 88, 520, 96, (31, 45, 56))
rect(400, 96, 496, 104, (40, 58, 72)); rect(400, 104, 496, 112, (32, 46, 58))
for y, x0, x1 in ((72, 352, 544), (88, 376, 520), (104, 400, 496)): rect(x0, y - 1, x1, y, (60, 82, 100))
for fx in (-1, 1):  # velas no dais
    cx = 448 + fx * 100
    rect(cx - 3, 70, cx + 4, 84, OUTLINE); rect(cx - 2, 72, cx + 3, 83, (200, 190, 170)); flame(cx, 66)

# porta de entrada embaixo (igual ao castelo)
rect(392, 600, 504, 640, OUTLINE); d.ellipse((392, 592, 504, 628), fill=OUTLINE)
rect(398, 612, 498, 640, (34, 18, 28)); d.ellipse((398, 600, 498, 630), fill=(34, 18, 28))
for x in range(402, 498, 12): rect(x, 606, x + 1, 640, (20, 10, 18))
rect(398, 622, 498, 625, (80, 70, 86)); rect(398, 634, 498, 637, (80, 70, 86)); rect(446, 604, 450, 640, OUTLINE)

# ossos no piso
for _ in range(18):
    bx, by = random.randint(70, W - 80), random.randint(150, H - 70)
    rect(bx, by, bx + 6, by + 2, (190, 184, 170, 255)); rect(bx - 1, by - 1, bx + 1, by + 1, (210, 204, 190, 255)); rect(bx + 6, by + 1, bx + 8, by + 3, (210, 204, 190, 255))

mask = Image.radial_gradient("L").resize((W, H), Image.BICUBIC)
vign = Image.new("RGBA", (W, H), (6, 4, 14, 0)); vign.putalpha(mask.point(lambda v: int(max(0, v - 120) * 1.15)))
img.alpha_composite(vign)
img.convert("RGB").save(os.path.join(OUT, "arena_gaiola.png"))


# =============================================================== GAIOLA (barras) 64x60
cg = Image.new("RGBA", (64, 60), (0, 0, 0, 0)); cd = ImageDraw.Draw(cg)
cd.rectangle((4, 54, 59, 58), fill=IRON_DK); cd.rectangle((4, 54, 59, 55), fill=IRON_HI)           # base
cd.rectangle((4, 8, 59, 11), fill=IRON); cd.rectangle((4, 8, 59, 8), fill=IRON_HI)                 # aro superior
cd.polygon([(4, 10), (12, 4), (22, 1), (41, 1), (51, 4), (59, 10)], fill=IRON_DK)
cd.polygon([(8, 10), (14, 5), (22, 3), (41, 3), (49, 5), (55, 10)], fill=IRON)
cd.line((8, 9, 14, 4), fill=IRON_HI); cd.line((14, 4, 22, 2), fill=IRON_HI)
cd.rectangle((29, 0, 34, 5), fill=GOLD_DK); cd.rectangle((29, 0, 30, 5), fill=GOLD)                 # argola
for x in range(7, 58, 7):                                                                         # barras
    cd.rectangle((x, 11, x + 2, 54), fill=IRON); cd.rectangle((x, 11, x, 54), fill=IRON_HI)
cd.rectangle((4, 32, 59, 33), fill=IRON_DK)                                                       # travessa
cg = outline(cg); cg.save(os.path.join(OUT, "cage_bars.png"))

# cadeado 12x14
lk = Image.new("RGBA", (12, 14), (0, 0, 0, 0)); ld = ImageDraw.Draw(lk)
ld.arc((2, 0, 9, 8), 180, 360, fill=IRON_HI, width=2); ld.rectangle((2, 4, 3, 7), fill=IRON_HI); ld.rectangle((8, 4, 9, 7), fill=IRON_HI)
ld.rectangle((1, 7, 10, 12), fill=(140, 28, 44)); ld.rectangle((1, 7, 10, 7), fill=(220, 80, 90)); ld.rectangle((1, 12, 10, 12), fill=(80, 14, 28))
ld.rectangle((5, 9, 6, 11), fill=(255, 210, 120))
lk = outline(lk); lk.save(os.path.join(OUT, "lock.png"))

# revolver .38 28x14
rv = Image.new("RGBA", (28, 14), (0, 0, 0, 0)); rd = ImageDraw.Draw(rv)
rd.polygon([(3, 6), (8, 6), (7, 12), (2, 12)], fill=(112, 58, 28)); rd.line((4, 7, 3, 11), fill=(160, 96, 48))
rd.rectangle((4, 3, 11, 7), fill=(70, 74, 92)); rd.rectangle((8, 2, 13, 7), fill=(110, 116, 140))
rd.rectangle((12, 3, 25, 5), fill=(150, 158, 182)); rd.rectangle((12, 3, 25, 3), fill=(220, 226, 240))
rd.rectangle((24, 1, 25, 2), fill=GOLD); rd.rectangle((4, 2, 6, 3), fill=(110, 116, 140))
rd.arc((6, 6, 11, 11), 0, 180, fill=(110, 116, 140), width=1)
rv = outline(rv); rv.save(os.path.join(OUT, "revolver.png"))

# estilhaco 12x12
sh = Image.new("RGBA", (12, 12), (0, 0, 0, 0)); sdr = ImageDraw.Draw(sh)
sdr.polygon([(1, 5), (6, 1), (10, 6), (5, 10)], fill=(92, 96, 118)); sdr.polygon([(1, 5), (6, 1), (5, 5)], fill=(150, 154, 178))
sdr.rectangle((6, 5, 7, 6), fill=(255, 140, 50))
sh = outline(sh); sh.save(os.path.join(OUT, "shard.png"))


# =============================================================== GUARDIOES 32x32 x 5 quadros
def shade(mask, base, light, dark, layer):
    """pinta 'mask' (imagem L) na layer com realce no topo/esquerda e sombra embaixo/direita."""
    w, h = mask.size; mp = mask.load(); lp = layer.load()
    def m(x, y): return 0 <= x < w and 0 <= y < h and mp[x, y] > 0
    for y in range(h):
        for x in range(w):
            if m(x, y):
                c = base
                if not m(x - 1, y - 1) or not m(x, y - 1): c = light
                elif not m(x + 1, y + 1) or not m(x, y + 1): c = dark
                lp[x, y] = c + (255,)


PAL = {
    0: dict(base=(96, 100, 124), light=(138, 142, 168), dark=(58, 60, 84), glow=(255, 140, 48)),
    1: dict(base=(88, 84, 122), light=(130, 124, 168), dark=(54, 50, 88), glow=(210, 100, 255)),
    2: dict(base=(112, 92, 104), light=(160, 132, 142), dark=(70, 54, 68), glow=(255, 70, 60)),
}
FRAMES = ["statue", "idle1", "idle2", "windup", "attack"]


def demon(kind, pose):
    P = PAL[kind]; awake = pose != "statue"
    base, light, dark, glow = P["base"], P["light"], P["dark"], P["glow"]
    if not awake:
        base = tuple(int(v * .8 + 20) for v in base); light = tuple(int(v * .8 + 20) for v in light); dark = tuple(int(v * .85 + 12) for v in dark)
    dy = {"idle1": 0, "idle2": 1, "statue": 0, "windup": 1, "attack": 0}[pose]
    dx = 2 if pose == "attack" else 0
    parts = []   # (poly list, role) role: base|dark|light

    def P_(poly, role="base"):
        parts.append(([(x + dx, y + dy) for x, y in poly], role))

    if kind == 0:   # BRUTO: largo, punhos enormes
        P_([(10, 22), (14, 22), (14, 30), (10, 30)], "dark"); P_([(18, 22), (22, 22), (22, 30), (18, 30)], "dark")
        P_([(9, 13), (23, 13), (25, 24), (7, 24)], "base")
        if pose == "windup":
            P_([(3, 4), (8, 4), (9, 14), (4, 14)], "base"); P_([(24, 4), (29, 4), (28, 14), (23, 14)], "base")
            P_([(2, 1), (9, 1), (9, 6), (2, 6)], "light"); P_([(23, 1), (30, 1), (30, 6), (23, 6)], "light")
        elif pose == "attack":
            P_([(22, 14), (31, 15), (31, 21), (22, 22)], "base"); P_([(28, 13), (32, 13), (32, 22), (28, 22)], "light")
            P_([(3, 14), (8, 14), (8, 24), (3, 24)], "dark")
        else:
            P_([(3, 14), (8, 14), (8, 25), (3, 25)], "base"); P_([(24, 14), (29, 14), (29, 25), (24, 25)], "base")
            P_([(2, 23), (9, 23), (9, 29), (2, 29)], "light"); P_([(23, 23), (30, 23), (30, 29), (23, 29)], "light")
        P_([(12, 5), (20, 5), (21, 13), (11, 13)], "light")
        P_([(11, 5), (9, 1), (13, 4)], "base"); P_([(21, 5), (23, 1), (19, 4)], "base")
    elif kind == 1:  # ARREMESSADOR: magro, asas de morcego, lasca na mao
        P_([(5, 8), (11, 12), (10, 22), (3, 18), (1, 10)], "dark"); P_([(27, 8), (21, 12), (22, 22), (29, 18), (31, 10)], "dark")
        P_([(11, 23), (14, 23), (14, 30), (11, 30)], "dark"); P_([(18, 23), (21, 23), (21, 30), (18, 30)], "dark")
        P_([(11, 13), (21, 13), (20, 24), (12, 24)], "base")
        if pose == "windup":
            P_([(5, 4), (9, 4), (12, 14), (8, 15)], "base"); P_([(23, 4), (27, 4), (24, 15), (20, 14)], "base")
            P_([(1, 0), (6, 3), (4, 8)], "light"); P_([(31, 0), (26, 3), (28, 8)], "light")
        elif pose == "attack":
            P_([(20, 14), (30, 15), (30, 18), (20, 19)], "base"); P_([(28, 11), (32, 16), (28, 20)], "light")
        else:
            P_([(8, 14), (12, 14), (11, 25), (7, 25)], "base"); P_([(20, 14), (24, 14), (25, 25), (21, 25)], "base")
        P_([(12, 5), (20, 5), (19, 13), (13, 13)], "light")
        P_([(12, 5), (10, 0), (15, 4)], "base"); P_([(20, 5), (22, 0), (17, 4)], "base")
    else:            # REI GARGULA: grande, asas abertas, coroa de chifres
        wing = 2 if pose == "windup" else 0
        P_([(1, 4 - wing), (10, 10), (10, 22), (2, 20), (0, 12)], "dark"); P_([(31, 4 - wing), (22, 10), (22, 22), (30, 20), (32, 12)], "dark")
        P_([(9, 22), (14, 22), (14, 30), (9, 30)], "dark"); P_([(18, 22), (23, 22), (23, 30), (18, 30)], "dark")
        P_([(9, 12), (23, 12), (24, 24), (8, 24)], "base")
        if pose == "windup":
            P_([(4, 3), (9, 3), (10, 13), (5, 13)], "base"); P_([(23, 3), (28, 3), (27, 13), (22, 13)], "base")
        elif pose == "attack":
            P_([(22, 13), (31, 14), (31, 20), (22, 21)], "base"); P_([(4, 14), (9, 14), (9, 23), (4, 23)], "dark")
        else:
            P_([(4, 13), (9, 13), (9, 25), (4, 25)], "base"); P_([(23, 13), (28, 13), (28, 25), (23, 25)], "base")
        P_([(11, 4), (21, 4), (22, 12), (10, 12)], "light")
        for hx, hy in ((9, 3), (13, 1), (16, -1), (19, 1), (23, 3)):
            P_([(hx - 1, 5), (hx, hy), (hx + 2, 5)], "light")

    layer = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    for poly, role in parts:   # dark primeiro (fica atras), depois base, depois light
        pass
    order = {"dark": 0, "base": 1, "light": 2}
    for poly, role in sorted(parts, key=lambda t: order[t[1]]):
        m = Image.new("L", (32, 32), 0); ImageDraw.Draw(m).polygon(poly, fill=255)
        col = {"base": base, "dark": dark, "light": light}[role]
        shade(m, col, tuple(min(255, v + 36) for v in col), tuple(max(0, v - 26) for v in col), layer)
    px = layer.load(); dr = ImageDraw.Draw(layer)
    # olhos + rachaduras de lava
    ey = {0: 8, 1: 8, 2: 7}[kind] + dy
    ex = [(13, ey), (18, ey)] if kind != 1 else [(14, ey), (18, ey)]
    for (x, y) in ex:
        x += dx
        if awake: dr.rectangle((x, y, x + 1, y + 1), fill=glow + (255,)); px[x, y] = (255, 240, 200, 255)
        else: dr.rectangle((x, y, x + 1, y + 1), fill=(10, 10, 16, 255))
    if awake:
        for (x, y) in {0: [(15, 15), (16, 17), (15, 19), (17, 21), (13, 17), (12, 19), (19, 16), (20, 18)],
                       1: [(15, 15), (16, 18), (15, 21), (17, 20)],
                       2: [(14, 14), (16, 16), (15, 19), (17, 22), (19, 15), (20, 18)]}[kind]:
            x += dx; y += dy
            if 0 <= x < 32 and 0 <= y < 32 and px[x, y][3] > 0: px[x, y] = glow + (255,)
    else:
        for (x, y) in [(14, 15), (15, 17), (19, 16)]:   # musgo/rachaduras da estatua
            if px[x, y][3] > 0: px[x, y] = (46, 60, 54, 255)
    return outline(layer)


for kind, name in ((0, "bruto"), (1, "arremessador"), (2, "rei")):
    sheet = Image.new("RGBA", (32 * len(FRAMES), 32), (0, 0, 0, 0))
    for i, pose in enumerate(FRAMES): sheet.alpha_composite(demon(kind, pose), (i * 32, 0))
    sheet.save(os.path.join(OUT, f"demon_{name}.png"))
print("ok ->", os.path.abspath(OUT))
