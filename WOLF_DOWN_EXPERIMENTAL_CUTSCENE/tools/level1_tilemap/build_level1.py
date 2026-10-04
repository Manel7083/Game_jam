#!/usr/bin/env python3
"""Reconstrói o tilemap do Level 1 no estilo do Level 3.

Entrada : level_1.tscn original (usa só o desenho dos caminhos; a área jogável é preservada)
Saída   : level_1.tscn novo + terreno/level1_tiles.png + prévias

Uso: python3 build_level1.py <level_1.tscn original> <pasta de saída>
"""
import os, re, sys, random
from PIL import Image
from gen_tiles import *

SRC_TSCN = sys.argv[1]
OUT = sys.argv[2]
os.makedirs(os.path.join(OUT, "leveis"), exist_ok=True)
os.makedirs(os.path.join(OUT, "terreno"), exist_ok=True)

# ---------------------------------------------------------------- área jogável (igual ao original)
IX0, IX1, IY0, IY1 = -30, 41, -35, 7        # chão
WALL_T = 6                                   # espessura da moldura de paredes
MX0, MX1 = IX0 - WALL_T, IX1 + WALL_T
MY0, MY1 = IY0 - WALL_T, IY1 + WALL_T
TERRENO_POS = (510, 556)                     # posição do nó "terreno" no level_1.tscn
ROOT_POS = (0, 3)                            # posição do nó raiz


def s16(v):
    v &= 0xFFFF
    return v - 0x10000 if v & 0x8000 else v


def read_original_paths(path):
    t = open(path, encoding="utf-8").read()
    m = re.search(r"layer_1/tile_data = PackedInt32Array\(([^)]*)\)", t)
    vals = [int(x) for x in m.group(1).split(",") if x.strip()]
    cells = set()
    for i in range(0, len(vals), 3):
        a = vals[i] & 0xFFFFFFFF
        cells.add((s16(a & 0xFFFF), s16(a >> 16)))
    return t, cells


text, PATH = read_original_paths(SRC_TSCN)
assert all(IX0 <= x <= IX1 and IY0 <= y <= IY1 for x, y in PATH), "caminho fora da área jogável"

# ---------------------------------------------------------------- grade lógica
FLOOR = {(x, y) for x in range(IX0, IX1 + 1) for y in range(IY0, IY1 + 1)}
WALL = {(x, y) for x in range(MX0, MX1 + 1) for y in range(MY0, MY1 + 1)} - FLOOR


def is_wall(c):
    return c in WALL


def is_floor(c):
    return c in FLOOR


def cheb_depth(c):
    """distância de Chebyshev até o chão mais próximo (1 = encostado no chão)."""
    x, y = c
    for d in range(1, WALL_T + 2):
        for dx in range(-d, d + 1):
            for dy in range(-d, d + 1):
                if max(abs(dx), abs(dy)) == d and (x + dx, y + dy) in FLOOR:
                    return d
    return WALL_T + 1


# ---------------------------------------------------------------- atlas
class Atlas:
    COLS = 16

    def __init__(self):
        self.tiles = []     # dicts: key,img,collision,terrain
        self.index = {}

    def add(self, key, img, collision=False, terrain=None):
        if key in self.index:
            return self.index[key]
        i = len(self.tiles)
        self.tiles.append(dict(key=key, img=img, collision=collision, terrain=terrain))
        self.index[key] = i
        return i

    def coord(self, key):
        i = self.index[key]
        return (i % self.COLS, i // self.COLS)

    def image(self):
        rows = (len(self.tiles) + self.COLS - 1) // self.COLS
        im = Image.new("RGBA", (self.COLS * T, rows * T), (0, 0, 0, 0))
        for i, t in enumerate(self.tiles):
            im.paste(t["img"], ((i % self.COLS) * T, (i // self.COLS) * T))
        return im


A = Atlas()
BIT_NAMES = {"E": "right_side", "SE": "bottom_right_corner", "S": "bottom_side", "SW": "bottom_left_corner",
             "W": "left_side", "NW": "top_left_corner", "N": "top_side", "NE": "top_right_corner"}

# grama (terreno 0) - 12 variantes; pares/ímpares alternam o tom, como o xadrez do chão do level 3
for i in range(12):
    A.add(("grass", i), grass_tile(i), terrain=(0, {d: 0 for d in ORDER}))

# caminho (terreno 2) - conjunto completo de 47 máscaras x 4 variações => dá para pintar no editor
PATH_MASKS = all_path_masks()
INTERIOR = tuple([1] * 8)
for mask in PATH_MASKS:
    for e in range(N_EDGE):
        variant = e if mask == INTERIOR else e % 2
        bits = {d: 2 for d, on in zip(ORDER, mask) if on}
        A.add(("path", mask, e), path_tile(mask, e, variant), terrain=(2, bits))


def wall_key_img(ctx_key, r0, cl, cr):
    ctx = {k: True for k in ctx_key}
    return wall_tile(ctx, r0, cl, cr, 0)


def get_wall(ctx_key, r0, cl, cr):
    key = ("wall", ctx_key, r0, cl, cr)
    if key not in A.index:
        A.add(key, wall_key_img(ctx_key, r0, cl, cr), collision=True)
    return key


def get_shadow(sides):
    key = ("shadow", sides)
    if key not in A.index:
        A.add(key, shadow_tile(sides))
    return key


A.add(("dark", 1), dark_overlay(58))
A.add(("dark", 2), dark_overlay(108))
DECALS = {
    "blood": [blood_decal(i) for i in range(4)],
    "crack": [crack_decal(i) for i in range(3)],
    "crack_path": [crack_decal(i, True) for i in range(3)],
    "leaves": [leaves_decal(i) for i in range(3)],
    "pebble": [pebble_decal(i) for i in range(3)],
    "mushroom": [mushroom_decal(i) for i in range(2)],
    "tuft": [tuft_decal(i) for i in range(4)],
    "bone": [bone_decal(i) for i in range(2)],
    "moss": [moss_decal(i) for i in range(3)],
    "moss_up": [moss_decal(i).transpose(Image.FLIP_TOP_BOTTOM) for i in range(3)],   # parede com chão ao norte
    "wallcrack": [wallcrack_decal(i) for i in range(2)],
}
for name, imgs in DECALS.items():
    for i, im in enumerate(imgs):
        A.add(("decal", name, i), im)

# ---------------------------------------------------------------- composição das camadas
rng = random.Random(20260404)
L0, L1, L2, L3 = {}, {}, {}, {}

for c in sorted(FLOOR):
    x, y = c
    L0[c] = ("grass", 2 * rng.randrange(6) + ((x + y) % 2))

for c in sorted(PATH):
    x, y = c
    flags = {d: ((x + dx, y + dy) in PATH) for d, (dx, dy) in DIRS.items()}
    mask = reduce_mask(flags)
    L1[c] = ("path", mask, rng.randrange(N_EDGE))

# paredes: tons coerentes entre vizinhos (o tijolo da fileira de baixo atravessa a borda do tile)
for y in range(MY0, MY1 + 1):
    prev_right = rng.randrange(2)
    for x in range(MX0, MX1 + 1):
        c = (x, y)
        if c not in WALL:
            prev_right = rng.randrange(2)
            continue
        ctx = {}
        for d in ("N", "E", "S", "W"):
            dx, dy = DIRS[d]
            if (x + dx, y + dy) in FLOOR:
                ctx[d] = True
        for d in ("NE", "SE", "SW", "NW"):
            dx, dy = DIRS[d]
            if (x + dx, y + dy) in FLOOR:
                ctx[d] = True
        ctx_key = tuple(sorted(ctx))
        cr = rng.randrange(2)
        L2[c] = get_wall(ctx_key, rng.randrange(3), prev_right, cr)
        prev_right = cr

# camada de detalhes: sombras, escurecimento da moldura e decalques
for c in sorted(FLOOR):
    x, y = c
    sides = tuple(d for d in ("N", "E", "S", "W") if (x + DIRS[d][0], y + DIRS[d][1]) in WALL)
    if sides:
        L3[c] = get_shadow(sides)

for c in sorted(WALL):
    d = cheb_depth(c)
    if d == 2:
        L3[c] = ("dark", 1)
    elif d >= 3:
        L3[c] = ("dark", 2)
    elif d == 1:
        r = rng.random()
        if r < 0.20:
            up = (c[0], c[1] - 1) in FLOOR
            L3[c] = ("decal", "moss_up" if up else "moss", rng.randrange(3))
        elif r < 0.29:
            L3[c] = ("decal", "wallcrack", rng.randrange(2))

path_adjacent = set()
for (x, y) in PATH:
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            path_adjacent.add((x + dx, y + dy))


def pick(c, table):
    r = rng.random()
    acc = 0.0
    for name, p in table:
        acc += p
        if r < acc:
            return ("decal", name, rng.randrange(len(DECALS[name])))
    return None


GRASS_TABLE = [("blood", 0.010), ("crack", 0.020), ("leaves", 0.030), ("pebble", 0.025),
               ("mushroom", 0.008), ("tuft", 0.055), ("bone", 0.004)]
EDGE_TABLE = [("blood", 0.010), ("leaves", 0.050), ("tuft", 0.140), ("pebble", 0.020)]
PATH_TABLE = [("crack_path", 0.050), ("blood", 0.018), ("leaves", 0.020), ("pebble", 0.008)]
for c in sorted(FLOOR):
    if c in L3:
        continue
    if c in PATH:
        d = pick(c, PATH_TABLE)
    elif c in path_adjacent:
        d = pick(c, EDGE_TABLE)
    else:
        d = pick(c, GRASS_TABLE)
    if d:
        L3[c] = d

# ---------------------------------------------------------------- imagem do atlas
atlas_img = A.image()
atlas_img.save(os.path.join(OUT, "terreno", "level1_tiles.png"))


# ---------------------------------------------------------------- prévia
def compose(layers, modulate=None, scale=1):
    W, H = (MX1 - MX0 + 1) * T, (MY1 - MY0 + 1) * T
    im = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for L in layers:
        for (x, y), key in L.items():
            ax, ay = A.coord(key)
            tile = atlas_img.crop((ax * T, ay * T, ax * T + T, ay * T + T))
            im.alpha_composite(tile, ((x - MX0) * T, (y - MY0) * T))
    if modulate:
        px = im.load()
        for yy in range(im.height):
            for xx in range(im.width):
                r, g, b, a = px[xx, yy]
                px[xx, yy] = (int(r * modulate[0]), int(g * modulate[1]), int(b * modulate[2]), a)
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    return im


MOD = (1.0, 0.757442, 0.996739)
prev = compose([L0, L1, L2, L3])
prev.convert("RGB").save(os.path.join(OUT, "_preview_full.png"))
compose([L0, L1, L2, L3], MOD).convert("RGB").save(os.path.join(OUT, "_preview_full_modulado.png"))


# ---------------------------------------------------------------- tscn
def enc(cells, layer_to_source):
    vals = []
    for (x, y), key in sorted(cells.items(), key=lambda kv: (kv[0][1], kv[0][0])):
        ax, ay = A.coord(key)
        a = ((y & 0xFFFF) << 16) | (x & 0xFFFF)
        if a >= 2 ** 31:
            a -= 2 ** 32
        vals += [a, layer_to_source | (ax << 16), ay]
    return "PackedInt32Array(" + ", ".join(str(v) for v in vals) + ")"


NEW_SRC = 7
atlas_lines = ['[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_l1new"]',
               'texture = ExtResource("15_l1tiles")']
for i, t in enumerate(A.tiles):
    ax, ay = i % A.COLS, i // A.COLS
    p = f"{ax}:{ay}/0"
    atlas_lines.append(f"{p} = 0")
    if t["terrain"] is not None:
        terr, bits = t["terrain"]
        atlas_lines.append(f"{p}/terrain_set = 0")
        atlas_lines.append(f"{p}/terrain = {terr}")
        for d in ORDER:
            if d in bits:
                atlas_lines.append(f"{p}/terrains_peering_bit/{BIT_NAMES[d]} = {bits[d]}")
    if t["collision"]:
        atlas_lines.append(f"{p}/physics_layer_0/linear_velocity = Vector2(0, 0)")
        atlas_lines.append(f"{p}/physics_layer_0/angular_velocity = 0.0")
        atlas_lines.append(f"{p}/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)")
atlas_block = "\n".join(atlas_lines) + "\n\n"

new = text
# 1) ext_resource da textura nova (depois do último ext_resource)
ext_matches = list(re.finditer(r'^\[ext_resource [^\n]*\]\n', new, re.M))
last = ext_matches[-1]
new = new[:last.end()] + '[ext_resource type="Texture2D" path="res://terreno/level1_tiles.png" id="15_l1tiles"]\n' + new[last.end():]
# 2) sub_resource do atlas antes do TileSet
idx = new.index('[sub_resource type="TileSet" id=')
new = new[:idx] + atlas_block + new[idx:]
# 3) registra a fonte no TileSet
new = re.sub(r'(sources/0 = SubResource\("[^"]+"\)\n)', r'\1sources/%d = SubResource("TileSetAtlasSource_l1new")\n' % NEW_SRC, new, count=1)
# 4) camadas do TileMap
start = new.index('layer_0/name = "chao"')
end_marker = 'layer_3/z_index = 1\n'
end = new.index(end_marker) + len(end_marker)
layers_txt = (
    'layer_0/name = "chao"\n'
    'layer_0/z_index = -1\n'
    f'layer_0/tile_data = {enc(L0, NEW_SRC)}\n'
    'layer_1/name = "caminho"\n'
    f'layer_1/tile_data = {enc(L1, NEW_SRC)}\n'
    'layer_2/name = "parede"\n'
    f'layer_2/tile_data = {enc(L2, NEW_SRC)}\n'
    'layer_3/name = "detalhes"\n'
    'layer_3/z_index = 1\n'
    f'layer_3/tile_data = {enc(L3, NEW_SRC)}\n'
)
new = new[:start] + layers_txt + new[end:]
# 5) limites da câmera do lobo = borda externa das paredes (nunca aparece o vazio roxo)
left = ROOT_POS[0] + TERRENO_POS[0] + MX0 * T
right = ROOT_POS[0] + TERRENO_POS[0] + (MX1 + 1) * T
top = ROOT_POS[1] + TERRENO_POS[1] + MY0 * T
bottom = ROOT_POS[1] + TERRENO_POS[1] + (MY1 + 1) * T
wolf_block = re.search(r'\[node name="wolf" parent="\." [^\n]*\]\n(?:[^\[\n][^\n]*\n)*', new)
cam = (f'\n[node name="Camera2D" parent="wolf" index="3"]\n'
       f'limit_left = {left}\nlimit_top = {top}\nlimit_right = {right}\nlimit_bottom = {bottom}\n')
new = new[:wolf_block.end()] + cam + new[wolf_block.end():]

open(os.path.join(OUT, "leveis", "level_1.tscn"), "w", encoding="utf-8").write(new)
print("tiles no atlas:", len(A.tiles), "| atlas", atlas_img.size)
print("camera limits", left, top, right, bottom)
print("cells: L0", len(L0), "L1", len(L1), "L2", len(L2), "L3", len(L3))
