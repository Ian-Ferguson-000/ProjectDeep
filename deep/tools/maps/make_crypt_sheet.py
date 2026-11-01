"""Builds maps/crypt/tiles/crypt_ground.png (48px tiles) from the stone sheets.

Row 0  floor   eight stone slab variants (plain, studded, darker, cracked, bone-strewn)
Row 1  pit     open pit, and a pit with a stone lip along its top edge
Row 2  carpet  a red runner, plain and with gold trim
Row 3  wall    the wall marker painted on the Thicket layer (hidden in game)

Run from deep/:  python3 tools/maps/make_crypt_sheet.py
The artist can repaint the PNG freely afterwards; keep the 48px grid.
"""
from PIL import Image, ImageDraw
import random

T = 48
STONE = Image.open("assets/pixel_art/TX Tileset Stone Ground.png").convert("RGBA")
WALL = Image.open("assets/pixel_art/TX Tileset Wall.png").convert("RGBA")
sheet = Image.new("RGBA", (T * 8, T * 4), (0, 0, 0, 0))

def slab(region):
    return STONE.crop(region).resize((T, T), Image.NEAREST)

def shade(img, factor, tint=(1, 1, 1)):
    out = img.copy(); px = out.load()
    for y in range(T):
        for x in range(T):
            r, g, b, a = px[x, y]
            px[x, y] = (min(255, int(r * factor * tint[0])), min(255, int(g * factor * tint[1])), min(255, int(b * factor * tint[2])), a)
    return out

def cracks(img, seed):
    rng = random.Random(seed); out = img.copy(); d = ImageDraw.Draw(out)
    for _ in range(2):
        x, y = rng.randint(8, 40), rng.randint(8, 40)
        for _ in range(5):
            nx, ny = x + rng.randint(-7, 7), y + rng.randint(-7, 7)
            d.line([(x, y), (nx, ny)], fill=(32, 28, 34, 255), width=1)
            x, y = max(3, min(44, nx)), max(3, min(44, ny))
    return out

def bones(img, seed):
    rng = random.Random(seed); out = img.copy(); d = ImageDraw.Draw(out)
    for _ in range(3):
        x, y = rng.randint(8, 38), rng.randint(8, 38); dx = rng.choice([-1, 1])
        d.line([(x, y), (x + 8, y + 4 * dx)], fill=(170, 162, 148, 255), width=2)
        d.ellipse([x - 2, y - 2, x + 1, y + 1], fill=(158, 150, 136, 255))
        d.ellipse([x + 7, y + 4 * dx - 1, x + 10, y + 4 * dx + 2], fill=(158, 150, 136, 255))
    return out

# Darkened to the crypt's cold grey-violet (the old crypt modulated its floor #777582).
plain = shade(slab((0, 0, 96, 96)), 0.56, (0.97, 0.95, 1.08))
studded = shade(slab((160, 0, 256, 96)), 0.56, (0.97, 0.95, 1.08))
floors = [plain, studded, shade(plain, 0.88), shade(studded, 0.88), cracks(plain, 3), cracks(studded, 7), bones(plain, 11), shade(cracks(plain, 13), 0.82, (1.0, 0.97, 1.05))]
for i, tile in enumerate(floors):
    sheet.paste(tile, (i * T, 0))

# Pits: near-black with a faint violet glow, and a version with a stone lip on top.
pit = Image.new("RGBA", (T, T), (10, 7, 16, 255)); d = ImageDraw.Draw(pit)
rng = random.Random(5)
for _ in range(28):
    x, y = rng.randint(0, T - 1), rng.randint(0, T - 1)
    d.point((x, y), fill=(34, 24, 52, 255))
sheet.paste(pit, (0, T))
lip = pit.copy(); d = ImageDraw.Draw(lip)
lip.paste(plain.crop((0, 0, T, 10)), (0, 0))
d.rectangle([0, 10, T, 13], fill=(30, 24, 30, 255))
d.rectangle([0, 14, T, 17], fill=(18, 13, 24, 255))
sheet.paste(lip, (T, T))

# Carpet runner.
carpet = Image.new("RGBA", (T, T), (96, 22, 30, 255)); d = ImageDraw.Draw(carpet)
for y in range(0, T, 4): d.line([(0, y), (T, y)], fill=(108, 28, 36, 255))
sheet.paste(carpet, (0, 2 * T))
trim = carpet.copy(); d = ImageDraw.Draw(trim)
d.rectangle([0, 0, 3, T], fill=(196, 152, 64, 255)); d.rectangle([T - 4, 0, T, T], fill=(196, 152, 64, 255))
d.polygon([(T // 2, 14), (T // 2 + 8, T // 2), (T // 2, T - 14), (T // 2 - 8, T // 2)], fill=(150, 108, 40, 255))
sheet.paste(trim, (T, 2 * T))

# Wall marker: a dark brick block (the game draws the real walls).
brick = WALL.crop((32, 192, 96, 256)).resize((T, T), Image.NEAREST)
sheet.paste(shade(brick, 0.6, (1.0, 0.95, 1.1)), (0, 3 * T))

sheet.save("maps/crypt/tiles/crypt_ground.png")
print("wrote maps/crypt/tiles/crypt_ground.png")
