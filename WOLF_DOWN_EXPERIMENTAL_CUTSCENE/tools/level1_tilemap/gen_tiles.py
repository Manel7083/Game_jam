#!/usr/bin/env python3
"""Gera o atlas de tiles do Level 1 (Floresta Assombrada) com a linguagem visual do Level 3:
tijolos com argamassa, pedra com contorno escuro, rachaduras, manchas de sangue, sombras sob as paredes.

Tudo 16x16. Cada tile é registrado com um nome; build_level1.py usa o registro para montar o mapa.
"""
import random, math, itertools
from PIL import Image, ImageDraw

T = 16


def clamp(v):
    return max(0, min(255, int(v)))


def shade(c, d):
    return (clamp(c[0] + d), clamp(c[1] + d), clamp(c[2] + d))


def mul(c, f):
    return (clamp(c[0] * f), clamp(c[1] * f), clamp(c[2] * f))


# ------------------------------------------------------------------ paleta (derivada do level 3)
OUTLINE = (14, 8, 20)
# grama: mesmo matiz azul-esverdeado do chão do level 3 (STONE_A/B) e do grass original
G_A = (16, 30, 33)
G_B = (17, 32, 35)
G_BLADE_D = (11, 21, 25)
G_BLADE_M = (32, 58, 54)
G_BLADE_H = (54, 94, 82)
# caminho: tom do tapete do level 3 (C1/C2/C_DK) em formato de pedra
P_BASE = (88, 30, 44)
P_HI = (122, 46, 62)
P_LO = (66, 19, 34)
P_MORTAR = (38, 8, 22)
P_RIM_DARK = (30, 6, 20)
P_RIM_HI = (146, 56, 74)
P_RIM_LO = (62, 14, 32)
# parede: tijolos do level 3
BR1 = (44, 46, 74)
BR2 = (54, 56, 88)
BR_DK = (30, 30, 54)
BR_HI = (78, 80, 118)
MORTAR = (21, 21, 37)
MOSS = (38, 72, 56)
MOSS_D = (24, 48, 40)
BLOOD = (96, 14, 34)
BLOOD_HI = (140, 22, 46)
CRACK = (9, 13, 19)


# ------------------------------------------------------------------ grama
def tuft(px, rng, x, y, hmax=4):
    """Lâminas finas de 1px, espaçadas, levemente curvas (evita o visual de 'toco' quadrado)."""
    for dx in (-2, 0, 2):
        if dx and rng.random() < 0.35:
            continue
        h = rng.randint(3, hmax + 1) - (1 if dx else 0)
        lean = rng.choice((-1, 0, 1))
        for k in range(h):
            xx = x + dx + (lean if k >= h - 2 else 0)
            yy = y - k
            if 0 <= xx < T and 0 <= yy < T:
                if k == 0:
                    col = G_BLADE_D
                elif k == h - 1:
                    col = G_BLADE_H
                else:
                    col = G_BLADE_M
                px[xx, yy] = col + (255,)


def grass_tile(i):
    rng = random.Random(5000 + i)
    base = G_A if i % 2 == 0 else G_B
    im = Image.new("RGBA", (T, T))
    px = im.load()
    for y in range(T):
        for x in range(T):
            j = rng.randint(-2, 2)
            px[x, y] = shade(base, j) + (255,)
    for _ in range(10):
        x, y = rng.randrange(T), rng.randrange(T)
        d = rng.choice([-7, -5, 4, 6, 8])
        r, g, b, _a = px[x, y]
        px[x, y] = (clamp(r + d // 2), clamp(g + d), clamp(b + d), 255)
    # manchas de tom (dither) para quebrar a repetição
    for _ in range(2):
        cx, cy = rng.randrange(2, 14), rng.randrange(2, 14)
        for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0), (1, 1)):
            x, y = cx + dx, cy + dy
            if 0 <= x < T and 0 <= y < T and (x + y) % 2 == 0:
                r, g, b, _a = px[x, y]
                px[x, y] = (clamp(r + 2), clamp(g + 5), clamp(b + 5), 255)
    for _ in range(rng.choice([0, 1, 1, 2])):
        tuft(px, rng, rng.randint(2, 13), rng.randint(6, 14))
    if rng.random() < 0.18:  # folha seca
        x, y = rng.randint(1, 13), rng.randint(1, 14)
        col = rng.choice([(88, 28, 40), (112, 44, 44), (70, 24, 52)])
        px[x, y] = col + (255,)
        px[x + 1, y] = shade(col, -14) + (255,)
    return im


# ------------------------------------------------------------------ caminho (pedras de sangue)
def _cobble_layout():
    rng = random.Random(777)
    seeds = []
    for gy in range(3):
        for gx in range(3):
            shift = 2.6 if gy == 1 else 0.0
            sx = ((gx + 0.5) * T / 3 + shift + rng.uniform(-1.3, 1.3)) % T
            sy = ((gy + 0.5) * T / 3 + rng.uniform(-1.2, 1.2)) % T
            seeds.append((sx, sy, rng.uniform(-8, 8)))
    return seeds


SEEDS = _cobble_layout()


def cobble_pixels():
    """16x16 de pedras (Voronoi toroidal -> encaixa perfeitamente nas bordas)."""
    out = [[None] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            best = []
            for idx, (sx, sy, tone) in enumerate(SEEDS):
                dx = ((x + 0.5 - sx + T / 2) % T) - T / 2
                dy = ((y + 0.5 - sy + T / 2) % T) - T / 2
                best.append((math.hypot(dx, dy), idx, dx, dy))
            best.sort()
            f1, i1, dx, dy = best[0]
            f2 = best[1][0]
            if f2 - f1 < 1.15:
                out[y][x] = ("mortar", None)
            else:
                tone = SEEDS[i1][2]
                lit = -(dx + dy) * 2.6 + tone
                out[y][x] = ("stone", lit)
    return out


COBBLE = cobble_pixels()


def path_base(variant):
    rng = random.Random(9100 + variant)
    base = [[None] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            kind, lit = COBBLE[y][x]
            if kind == "mortar":
                c = P_MORTAR
                if variant >= 2 and rng.random() < 0.10:
                    c = MOSS_D
            else:
                if lit > 4:
                    c = P_HI if lit > 8 else tuple((a + b) // 2 for a, b in zip(P_BASE, P_HI))
                elif lit < -5:
                    c = P_LO
                else:
                    c = P_BASE
                c = shade(c, rng.randint(-3, 3))
            base[y][x] = c
    # pequenas lascas/rachaduras escuras
    for _ in range(rng.choice([1, 2, 3])):
        x, y = rng.randrange(2, 14), rng.randrange(2, 14)
        for _s in range(rng.randint(2, 4)):
            if COBBLE[y][x][0] == "stone":
                base[y][x] = shade(P_LO, -16)
            x = max(0, min(T - 1, x + rng.choice((-1, 0, 1))))
            y = max(0, min(T - 1, y + rng.choice((0, 1))))
    return base


# padrões de irregularidade da borda (0 nas pontas => encaixam entre tiles vizinhos)
EDGE_PATTERNS = [
    [0] * 16,
    [0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0],
    [0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0],
    [0, 0, 0, 0, 1, 2, 2, 1, 0, 0, 0, 0, 0, 1, 0, 0],
]
N_EDGE = len(EDGE_PATTERNS)
# bits: lados N,E,S,W e cantos NE,SE,SW,NW
DIRS = {"N": (0, -1), "E": (1, 0), "S": (0, 1), "W": (-1, 0), "NE": (1, -1), "SE": (1, 1), "SW": (-1, 1), "NW": (-1, -1)}
ORDER = ["N", "E", "S", "W", "NE", "SE", "SW", "NW"]


def reduce_mask(flags):
    """flags: dict dir->bool. Canto só conta se os dois lados vizinhos também forem caminho."""
    f = dict(flags)
    for c, (a, b) in {"NE": ("N", "E"), "SE": ("S", "E"), "SW": ("S", "W"), "NW": ("N", "W")}.items():
        if not (f[a] and f[b]):
            f[c] = False
    return tuple(int(f[d]) for d in ORDER)


def all_path_masks():
    seen = set()
    for bits in itertools.product([0, 1], repeat=8):
        seen.add(reduce_mask(dict(zip(ORDER, bits))))
    return sorted(seen)


def path_tile(mask, e, variant):
    f = dict(zip(ORDER, mask))
    base = path_base(variant)

    def pat(side):
        return EDGE_PATTERNS[(e + ORDER.index(side)) % N_EDGE]

    def inside(u, v):
        if u < 0:
            return f["W"]
        if u >= T:
            return f["E"]
        if v < 0:
            return f["N"]
        if v >= T:
            return f["S"]
        if not f["W"] and u < pat("W")[v]:
            return False
        if not f["E"] and (T - 1 - u) < pat("E")[v]:
            return False
        if not f["N"] and v < pat("N")[u]:
            return False
        if not f["S"] and (T - 1 - v) < pat("S")[u]:
            return False
        # cantos externos arredondados
        if not f["N"] and not f["W"] and u + v < 3:
            return False
        if not f["N"] and not f["E"] and (T - 1 - u) + v < 3:
            return False
        if not f["S"] and not f["W"] and u + (T - 1 - v) < 3:
            return False
        if not f["S"] and not f["E"] and (T - 1 - u) + (T - 1 - v) < 3:
            return False
        # cantos internos (entalhe)
        if f["N"] and f["E"] and not f["NE"] and (T - 1 - u) + v < 2:
            return False
        if f["S"] and f["E"] and not f["SE"] and (T - 1 - u) + (T - 1 - v) < 2:
            return False
        if f["S"] and f["W"] and not f["SW"] and u + (T - 1 - v) < 2:
            return False
        if f["N"] and f["W"] and not f["NW"] and u + v < 2:
            return False
        return True

    ins = [[inside(u, v) for u in range(T)] for v in range(T)]

    def ins_at(u, v):
        if 0 <= u < T and 0 <= v < T:
            return ins[v][u]
        return inside(u, v)

    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = im.load()
    nbrs = {"N": (0, -1), "S": (0, 1), "W": (-1, 0), "E": (1, 0)}
    rim = [[False] * T for _ in range(T)]
    for v in range(T):
        for u in range(T):
            if ins[v][u]:
                rim[v][u] = any(not ins_at(u + dx, v + dy) for dx, dy in nbrs.values())
    for v in range(T):
        for u in range(T):
            if not ins[v][u]:
                continue
            if rim[v][u]:
                px[u, v] = P_RIM_DARK + (255,)
                continue
            col = base[v][u]
            # bisel: realce no lado de cima/esquerda, sombra embaixo/direita
            hit = None
            for name, (dx, dy) in nbrs.items():
                nu, nv = u + dx, v + dy
                if 0 <= nu < T and 0 <= nv < T and rim[nv][nu]:
                    hit = name if hit is None or name in ("N", "W") else hit
            if hit in ("N", "W"):
                col = tuple((a + b) // 2 for a, b in zip(col, P_RIM_HI))
            elif hit in ("S", "E"):
                col = tuple((a + b) // 2 for a, b in zip(col, P_RIM_LO))
            px[u, v] = col + (255,)
    return im


# ------------------------------------------------------------------ parede (tijolos do level 3)
def wall_tile(ctx, r0tone, c_left, c_right, noise):
    """ctx: dict com chaves N,E,S,W (chão adjacente) e NE,SE,SW,NW (chão só na diagonal).
    r0tone 0-2: tom do tijolo da fileira de cima. c_left/c_right 0-1: tom do tijolo que atravessa a borda."""
    rng = random.Random(f"w{noise}{r0tone}{c_left}{c_right}")
    im = Image.new("RGBA", (T, T))
    px = im.load()
    r0_tones = [BR1, BR2, shade(BR1, -6)]
    cross_tones = [BR2, BR1]
    for row in range(2):
        y0 = row * 8
        for y in range(y0, y0 + 8):
            for x in range(T):
                if row == 0:
                    local = x
                    col = r0_tones[r0tone]
                    mortar_v = (x == 15)
                else:
                    # fileira deslocada: tijolo de x=8..(23); mortar em x=7
                    mortar_v = (x == 7)
                    col = cross_tones[c_left] if x < 7 else cross_tones[c_right]
                if mortar_v or y == y0 + 7:
                    px[x, y] = MORTAR + (255,)
                else:
                    c = shade(col, rng.randint(-3, 3))
                    if y == y0:
                        c = tuple((a + b) // 2 for a, b in zip(c, BR_HI)) if rng.random() < 0.55 else c
                    px[x, y] = c + (255,)
    # tijolos rachados / manchas de musgo
    for _ in range(rng.choice([0, 1, 1, 2])):
        x, y = rng.randrange(1, 14), rng.randrange(1, 14)
        for _s in range(rng.randint(2, 4)):
            r, g, b, _a = px[x, y]
            if (r, g, b) != MORTAR:
                px[x, y] = shade(BR_DK, -6) + (255,)
            x = max(0, min(15, x + rng.choice((-1, 0, 1))))
            y = max(0, min(15, y + rng.choice((0, 1))))
    # bordas voltadas para o chão (contorno escuro + realce) - igual ao level 3
    if ctx.get("N"):
        for x in range(T):
            px[x, 0] = OUTLINE + (255,)
            px[x, 1] = tuple((a + b) // 2 for a, b in zip(px[x, 1][:3], BR_HI)) + (255,)
    if ctx.get("S"):
        for x in range(T):
            px[x, 15] = OUTLINE + (255,)
            px[x, 14] = shade(px[x, 14][:3], -10) + (255,)
    if ctx.get("W"):
        for y in range(T):
            px[0, y] = OUTLINE + (255,)
            px[1, y] = tuple((a + b) // 2 for a, b in zip(px[1, y][:3], BR_HI)) + (255,)
    if ctx.get("E"):
        for y in range(T):
            px[15, y] = OUTLINE + (255,)
            px[14, y] = shade(px[14, y][:3], -10) + (255,)
    for d, (cx, cy) in {"NE": (14, 0), "SE": (14, 14), "SW": (0, 14), "NW": (0, 0)}.items():
        if ctx.get(d) and not any(ctx.get(s) for s in d):
            for dx in (0, 1):
                for dy in (0, 1):
                    px[cx + dx, cy + dy] = OUTLINE + (255,)
    return im


# ------------------------------------------------------------------ sombras (como no level 3: ~10px, alpha 110 -> 0)
def shadow_tile(sides):
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = im.load()
    for y in range(T):
        for x in range(T):
            a = 0
            dists = {"N": y, "S": T - 1 - y, "W": x, "E": T - 1 - x}
            for s in sides:
                d = dists[s]
                a = max(a, 118 * (1 - d / 10.0)) if d < 10 else a
            if a > 0:
                px[x, y] = (6, 4, 14, int(a))
    return im


def dark_overlay(alpha):
    return Image.new("RGBA", (T, T), (6, 4, 14, alpha))


# ------------------------------------------------------------------ decalques
def _blank():
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    return im, im.load()


def blood_decal(i):
    rng = random.Random(300 + i)
    im, px = _blank()
    cx, cy = rng.randint(6, 9), rng.randint(6, 9)
    rx, ry = rng.randint(3, 6), rng.randint(2, 4)
    for y in range(T):
        for x in range(T):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                px[x, y] = BLOOD + (170,)
    for _ in range(rng.randint(5, 9)):
        x, y = cx + rng.randint(-rx - 3, rx + 3), cy + rng.randint(-ry - 3, ry + 3)
        if 0 <= x < T and 0 <= y < T:
            px[x, y] = BLOOD_HI + (190,)
            if rng.random() < 0.3 and x + 1 < T:
                px[x + 1, y] = BLOOD + (170,)
    px[cx - 1, cy - 1] = (170, 40, 62, 200)
    return im


def crack_decal(i, on_path=False):
    rng = random.Random(400 + i + (50 if on_path else 0))
    im, px = _blank()
    col = (24, 4, 12, 225) if on_path else CRACK + (210,)
    x, y = rng.randint(2, 6), rng.randint(2, 13)
    for _ in range(rng.randint(8, 14)):
        px[x, y] = col
        x = max(0, min(T - 1, x + rng.choice((0, 1, 1, 1))))
        y = max(0, min(T - 1, y + rng.choice((-1, 0, 1))))
        if rng.random() < 0.18:
            by = max(0, min(T - 1, y + rng.choice((-2, 2))))
            px[x, by] = col
    return im


def leaves_decal(i):
    rng = random.Random(500 + i)
    im, px = _blank()
    for _ in range(rng.randint(2, 4)):
        x, y = rng.randint(1, 12), rng.randint(1, 13)
        col = rng.choice([(96, 30, 38), (128, 52, 40), (74, 24, 50)])
        px[x, y] = col + (255,)
        px[x + 1, y] = col + (255,)
        px[x + 1, y + 1] = shade(col, -18) + (255,)
        px[x, y + 1] = shade(col, -10) + (255,)
    return im


def pebble_decal(i):
    rng = random.Random(600 + i)
    im, px = _blank()
    for _ in range(rng.randint(2, 3)):
        x, y = rng.randint(1, 12), rng.randint(1, 12)
        for dx in range(3):
            px[x + dx, y + 1] = (46, 56, 68, 255)
        for dx in range(2):
            px[x + dx + (0), y] = (84, 98, 112, 255)
        px[x + 2, y + 2] = (14, 20, 28, 255)
        px[x + 1, y + 2] = (22, 30, 40, 255)
        px[x, y] = (110, 124, 138, 255)
    return im


def mushroom_decal(i):
    rng = random.Random(700 + i)
    im, px = _blank()
    for k in range(rng.randint(1, 2)):
        x, y = rng.randint(3, 11), rng.randint(5, 11)
        s = 1 if k else 0
        for dx in range(-2 + s, 3 - s):
            px[x + dx, y] = (112, 54, 168, 255)
        for dx in range(-1 + s, 2 - s):
            px[x + dx, y - 1] = (150, 88, 206, 255)
        px[x, y - 1] = (214, 168, 246, 255)
        px[x, y + 1] = (198, 188, 200, 255)
        px[x, y + 2] = (140, 130, 148, 255)
        px[x - 2 + s, y + 1] = (60, 26, 96, 140)
    return im


def tuft_decal(i):
    rng = random.Random(800 + i)
    im, px = _blank()
    for _ in range(rng.randint(1, 2)):
        tuft(px, rng, rng.randint(3, 12), rng.randint(8, 14), hmax=5)
    return im


def moss_decal(i):
    rng = random.Random(900 + i)
    im, px = _blank()
    # musgo escorrendo da base do tijolo
    for x in range(T):
        if rng.random() < 0.65:
            h = rng.randint(1, 4)
            for k in range(h):
                col = MOSS if k < h - 1 else MOSS_D
                px[x, 15 - k] = col + (225 - 25 * k,)
    for _ in range(4):
        px[rng.randrange(T), rng.randint(9, 13)] = MOSS + (170,)
    return im


def wallcrack_decal(i):
    rng = random.Random(1000 + i)
    im, px = _blank()
    x, y = rng.randint(3, 12), rng.randint(0, 3)
    for _ in range(rng.randint(9, 14)):
        px[x, y] = (8, 8, 16, 230)
        y = min(15, y + 1)
        x = max(0, min(15, x + rng.choice((-1, 0, 0, 1))))
    return im


def bone_decal(i):
    rng = random.Random(1100 + i)
    im, px = _blank()
    x, y = rng.randint(3, 9), rng.randint(5, 10)
    bone = (186, 178, 170, 255)
    bone_d = (120, 112, 112, 255)
    for dx in range(6):
        px[x + dx, y] = bone
    px[x - 1, y - 1] = bone; px[x - 1, y + 1] = bone
    px[x + 6, y - 1] = bone; px[x + 6, y + 1] = bone
    px[x + 1, y + 1] = bone_d; px[x + 3, y + 1] = bone_d
    return im
