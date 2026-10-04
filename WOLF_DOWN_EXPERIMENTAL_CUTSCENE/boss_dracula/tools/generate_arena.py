#!/usr/bin/env python3
"""Gera a arena do Castelo do Drácula (896x640, pixel art, paleta do Wolf Down).
Uso: python3 generate_arena.py -> ../sprites/arena_castle.png"""
import os, random, math
from PIL import Image, ImageDraw, ImageFilter

random.seed(13)
W, H = 896, 640
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprites", "arena_castle.png")

OUTLINE = (14, 8, 20, 255)
STONE_A = (24, 34, 42); STONE_B = (29, 41, 51); GROUT = (13, 19, 25); CRACK = (11, 15, 21)
BR1 = (44, 46, 74); BR2 = (54, 56, 88); BR_DK = (30, 30, 54); MORTAR = (21, 21, 37); BR_HI = (78, 80, 118)
C1 = (112, 30, 52); C2 = (142, 46, 70); C_DK = (82, 18, 38); GOLD = (214, 170, 74); GOLD_DK = (150, 110, 46)

img = Image.new("RGBA", (W, H), (0, 0, 0, 255))
d = ImageDraw.Draw(img)


def jitter(c, a=4):
    return tuple(max(0, min(255, v + random.randint(-a, a))) for v in c[:3]) + (255,)


def rect(x0, y0, x1, y1, c):
    d.rectangle((x0, y0, x1 - 1, y1 - 1), fill=c)


# ---------------------------------------------------------------- piso
for ty in range(0, H // 16):
    for tx in range(0, W // 16):
        base = STONE_A if (tx + ty) % 2 else STONE_B
        x, y = tx * 16, ty * 16
        rect(x, y, x + 16, y + 16, jitter(base, 2))
        for _ in range(16):
            px, py = x + random.randint(1, 14), y + random.randint(1, 14)
            img.putpixel((px, py), jitter(base, 6))
        rect(x, y + 15, x + 16, y + 16, GROUT)
        rect(x + 15, y, x + 16, y + 16, GROUT)
        rect(x, y, x + 16, y + 1, jitter((base[0] + 6, base[1] + 7, base[2] + 8), 1))

# rachaduras
for _ in range(34):
    x, y = random.randint(48, W - 48), random.randint(80, H - 48)
    for _ in range(random.randint(10, 26)):
        img.putpixel((x, y), CRACK + (255,))
        x += random.choice((-1, 0, 1, 1)); y += random.choice((0, 1, 1, -1))

# manchas de sangue
stain = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(stain)
for _ in range(14):
    cx, cy = random.randint(80, W - 80), random.randint(110, H - 60)
    r = random.randint(6, 18)
    sd.ellipse((cx - r, cy - r // 2, cx + r, cy + r // 2), fill=(96, 14, 34, 150))
    for _ in range(random.randint(4, 9)):
        sx, sy = cx + random.randint(-r - 8, r + 8), cy + random.randint(-r, r)
        sd.rectangle((sx, sy, sx + 1, sy + 1), fill=(130, 20, 44, 170))
img.alpha_composite(stain)
d = ImageDraw.Draw(img)

# ---------------------------------------------------------------- tapete vermelho
CX0, CX1 = 400, 496
for y in range(112, 608):
    for x in range(CX0, CX1):
        img.putpixel((x, y), jitter(C1, 3))
for y in range(112, 608, 24):
    cx = (CX0 + CX1) // 2
    for k in range(10):          # losango
        for dx in range(-k, k + 1):
            if abs(dx) in (k, k - 1) or k == 0:
                if y + k < 608: img.putpixel((cx + dx, y + 10 + k), C2)
                if y + 20 - k < 608: img.putpixel((cx + dx, y + 10 + 20 - k - 10), C2)
rect(CX0, 112, CX0 + 3, 608, GOLD_DK); rect(CX0 + 3, 112, CX0 + 5, 608, C_DK)
rect(CX1 - 3, 112, CX1, 608, GOLD_DK); rect(CX1 - 5, 112, CX1 - 3, 608, C_DK)
rect(CX0 + 1, 112, CX0 + 2, 608, GOLD); rect(CX1 - 2, 112, CX1 - 1, 608, GOLD)

# ---------------------------------------------------------------- paredes de tijolo
def bricks(x0, y0, x1, y1):
    row = 0
    for y in range(y0, y1, 8):
        off = 8 if row % 2 else 0
        for x in range(x0 - off, x1, 16):
            bx0, bx1 = max(x, x0), min(x + 16, x1)
            if bx1 <= bx0: continue
            c = random.choice((BR1, BR2, BR1, BR2, BR_DK))
            rect(bx0, y, bx1, min(y + 8, y1), jitter(c, 3))
            rect(bx0, min(y + 7, y1 - 1), bx1, min(y + 8, y1), MORTAR)
            rect(min(bx1 - 1, bx1), y, bx1, min(y + 8, y1), MORTAR) if bx1 - bx0 == 16 else None
            rect(bx0, y, bx1, y + 1, BR_HI) if random.random() < 0.5 else None
        row += 1

bricks(0, 0, W, 64)          # parede do fundo
bricks(0, 64, 32, H)         # esquerda
bricks(W - 32, 64, W, H)     # direita
bricks(0, H - 32, W, H)      # parede de baixo
# topo (ameias escuras)
rect(0, 0, W, 6, BR_DK)
for x in range(0, W, 32):
    rect(x, 0, x + 16, 3, (18, 18, 32))
# sombra da parede no piso
for i in range(10):
    a = int(110 * (1 - i / 10))
    sh = Image.new("RGBA", (W - 64, 1), (0, 0, 0, a))
    img.alpha_composite(sh, (32, 64 + i))
    img.alpha_composite(Image.new("RGBA", (W - 64, 1), (0, 0, 0, a)), (32, H - 33 - i))
    img.alpha_composite(Image.new("RGBA", (1, H - 96), (0, 0, 0, a)), (32 + i, 64 + 0))
    img.alpha_composite(Image.new("RGBA", (1, H - 96), (0, 0, 0, a)), (W - 33 - i, 64))
d = ImageDraw.Draw(img)

# ---------------------------------------------------------------- janelas góticas
def window(cx):
    top = 10
    # raios de luar no piso
    beam = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(beam)
    bd.polygon([(cx - 10, 66), (cx + 10, 66), (cx + 46, 250), (cx - 14, 250)], fill=(120, 150, 230, 26))
    img.alpha_composite(beam)
    dd = ImageDraw.Draw(img)
    dd.rectangle((cx - 15, top + 8, cx + 14, 54), fill=BR_HI)
    dd.ellipse((cx - 15, top - 6, cx + 14, top + 22), fill=BR_HI)
    dd.rectangle((cx - 12, top + 8, cx + 11, 52), fill=(48, 66, 128))
    dd.ellipse((cx - 12, top - 3, cx + 11, top + 19), fill=(48, 66, 128))
    for yy in range(top, 52):
        t = (yy - top) / 42
        c = (int(60 + 50 * (1 - t)), int(80 + 60 * (1 - t)), int(150 + 60 * (1 - t)))
        dd.line((cx - 9, yy, cx + 8, yy), fill=c)
    dd.rectangle((cx - 1, top, cx, 52), fill=OUTLINE)
    dd.rectangle((cx - 12, top + 16, cx + 11, top + 17), fill=OUTLINE)
    dd.rectangle((cx - 12, 52, cx + 11, 54), fill=BR_DK)

for wx in (112, 240, 656, 784):
    window(wx)
d = ImageDraw.Draw(img)

# ---------------------------------------------------------------- tochas / lanternas
def flame(cx, cy, scale=1.0, purple=False):
    layers = [((150, 40, 60), 6), ((240, 110, 40), 4), ((255, 205, 100), 2)]
    if purple:
        layers = [((90, 40, 140), 6), ((190, 90, 220), 4), ((245, 190, 255), 2)]
    for col, r in layers:
        r = int(r * scale)
        d.polygon([(cx, cy - r * 2), (cx + r, cy), (cx, cy + r), (cx - r, cy)], fill=col)

def sconce(cx, cy, purple=False):
    rect(cx - 2, cy + 2, cx + 3, cy + 10, OUTLINE)
    rect(cx - 1, cy + 3, cx + 2, cy + 9, (70, 50, 60))
    rect(cx - 4, cy, cx + 5, cy + 3, OUTLINE)
    rect(cx - 3, cy + 1, cx + 4, cy + 2, GOLD_DK)
    flame(cx, cy - 2, 1.0, purple)

for sy in (176, 336, 496):
    sconce(16, sy); sconce(W - 16, sy)
for sx in (176, 320, 576, 720):
    sconce(sx, 28, purple=True)

# ---------------------------------------------------------------- trono e degraus
rect(320, 64, 576, 72, (36, 52, 64)); rect(320, 72, 576, 80, (31, 45, 56))
rect(344, 80, 552, 88, (36, 52, 64)); rect(344, 88, 552, 96, (31, 45, 56))
rect(368, 96, 528, 104, (40, 58, 72)); rect(368, 104, 528, 112, (32, 46, 58))
for y in (72, 88, 104):
    rect(320 if y == 72 else (344 if y == 88 else 368), y - 1, 576 if y == 72 else (552 if y == 88 else 528), y, (60, 82, 100))
# trono
rect(426, 18, 470, 68, OUTLINE)
rect(428, 20, 468, 66, (34, 24, 50))
for sx in (428, 440, 452, 464):                       # espetos
    d.polygon([(sx, 20), (sx + 4, 8), (sx + 8, 20)], fill=(34, 24, 50))
rect(432, 26, 464, 64, (52, 34, 70))
rect(436, 30, 460, 58, C_DK); rect(438, 32, 458, 56, C1)
rect(432, 26, 464, 28, GOLD_DK); rect(432, 62, 464, 64, GOLD_DK)
rect(420, 56, 476, 76, OUTLINE)
rect(422, 58, 474, 74, (44, 30, 62))
rect(430, 60, 468, 72, C1); rect(430, 60, 468, 62, C2)
rect(420, 52, 430, 72, (34, 24, 50)); rect(466, 52, 476, 72, (34, 24, 50))
px_gold = [(447, 38), (448, 38), (447, 39), (448, 39)]
for p in px_gold: img.putpixel(p, GOLD)

# ---------------------------------------------------------------- porta de baixo
rect(392, 600, 504, 640, OUTLINE)
d.ellipse((392, 592, 504, 628), fill=OUTLINE)
rect(398, 612, 498, 640, (34, 18, 28))
d.ellipse((398, 600, 498, 630), fill=(34, 18, 28))
for x in range(402, 498, 12):
    rect(x, 606, x + 1, 640, (20, 10, 18))
rect(398, 622, 498, 625, (80, 70, 86)); rect(398, 634, 498, 637, (80, 70, 86))
rect(446, 604, 450, 640, OUTLINE)

# ---------------------------------------------------------------- pedestais com braseiros
PED = [(160, 250), (736, 250), (160, 450), (736, 450)]
for (cx, cy) in PED:
    layer = Image.new("RGBA", (48, 56), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.rectangle((8, 40, 39, 51), fill=(54, 66, 80, 255))           # base
    ld.rectangle((8, 40, 39, 42), fill=(84, 98, 114, 255))
    ld.rectangle((14, 20, 33, 40), fill=(44, 56, 70, 255))          # coluna
    ld.rectangle((14, 20, 17, 40), fill=(70, 84, 100, 255))
    ld.rectangle((10, 14, 37, 22), fill=(60, 72, 88, 255))          # taça
    ld.rectangle((10, 14, 37, 16), fill=(96, 110, 126, 255))
    ld.rectangle((16, 12, 31, 15), fill=(120, 30, 50, 255))         # brasa
    ld.polygon([(24, 0), (31, 10), (24, 14), (17, 10)], fill=(90, 40, 140, 255))
    ld.polygon([(24, 3), (28, 10), (24, 13), (20, 10)], fill=(190, 90, 220, 255))
    ld.polygon([(24, 6), (26, 11), (24, 13), (22, 11)], fill=(245, 190, 255, 255))
    # contorno
    src = layer.copy()
    for yy in range(layer.height):
        for xx in range(layer.width):
            if src.getpixel((xx, yy))[3] == 0:
                for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = xx + ddx, yy + ddy
                    if 0 <= nx < 48 and 0 <= ny < 56 and src.getpixel((nx, ny))[3] > 0:
                        layer.putpixel((xx, yy), OUTLINE); break
    shadow = Image.new("RGBA", (48, 56), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((2, 46, 46, 56), fill=(0, 0, 0, 90))
    img.alpha_composite(shadow, (cx - 24, cy - 28))
    img.alpha_composite(layer, (cx - 24, cy - 28))

# ---------------------------------------------------------------- vinheta
mask = Image.radial_gradient("L").resize((W, H), Image.BICUBIC)
vign = Image.new("RGBA", (W, H), (6, 4, 14, 0))
vign.putalpha(mask.point(lambda v: int(max(0, v - 120) * 1.15)))
img.alpha_composite(vign)

img.convert("RGB").save(OUT)
print("ok", OUT)
