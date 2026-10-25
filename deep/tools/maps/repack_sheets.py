"""Builds grid-aligned tileset images for maps/ from the original art sheets.

Run once from the deep/ folder:  python3 tools/maps/repack_sheets.py

The original sheets (forest tiles.png, the crypt and hell slabs) are not laid out
on a tile grid, which Godot TileSets need. This copies the usable pieces into
clean sheets under maps/<dungeon>/tiles/. AFTER THIS, THE ARTIST EDITS THOSE PNGs
DIRECTLY. Re-running this script overwrites their changes.
"""
import os
from PIL import Image, ImageDraw

def cut(sheet, x, y, w, h):
    return sheet.crop((x, y, x + w, y + h))

def place(out, tile, col, row, size):
    out.paste(tile, (col * size, row * size), tile)

# ---------------------------------------------------------------- forest
forest = Image.open("assets/pixel_art/forest_art/forest tiles.png").convert("RGBA")

# forest_ground.png: 32px tiles, 8 columns.
ground = Image.new("RGBA", (8 * 32, 4 * 32), (0, 0, 0, 0))
grass = [(192,64),(208,64),(224,64),(192,80),(208,80),(224,80),(192,96),(208,96)]
for i, (x, y) in enumerate(grass): place(ground, cut(forest, x, y, 32, 32), i, 0, 32)
water = [(352,200),(384,200),(352,224),(384,224)]
for i, (x, y) in enumerate(water): place(ground, cut(forest, x, y, 32, 32), i, 1, 32)
water_edge = [(320,165),(352,165),(384,165)]
for i, (x, y) in enumerate(water_edge): place(ground, cut(forest, x, y, 32, 32), 4 + i, 1, 32)
cobble = [(64,200),(96,200),(128,200),(96,224)]
for i, (x, y) in enumerate(cobble): place(ground, cut(forest, x, y, 32, 32), i, 2, 32)
# Row 3: editor-only "thicket" marker. Painted cells become the tree wall; the
# game draws the trees and hides this layer.
marker = Image.new("RGBA", (32, 32), (24, 70, 30, 200))
d = ImageDraw.Draw(marker)
d.rectangle([0, 0, 31, 31], outline=(10, 35, 14, 255))
d.polygon([(16, 4), (6, 20), (26, 20)], fill=(60, 140, 60, 255))
d.rectangle([14, 20, 17, 27], fill=(90, 60, 30, 255))
place(ground, marker, 0, 3, 32)
ground.save("maps/forest/tiles/forest_ground.png")

# forest_paths.png: 16px dirt pieces for the Terrains autotile, 5 columns.
paths = Image.new("RGBA", (5 * 16, 3 * 16), (0, 0, 0, 0))
pieces = [
    [(400,16),(416,16),(544,16),(524,76),(420,76)],
    [(400,48),(472,16),(544,48),(524,36),(420,36)],
    [(400,96),(416,96),(544,96),(420,24),(520,24)],
]
for row, line in enumerate(pieces):
    for col, (x, y) in enumerate(line): place(paths, cut(forest, x, y, 16, 16), col, row, 16)
paths.save("maps/forest/tiles/forest_paths.png")

# ---------------------------------------------------------------- crypt and hell (48px tiles)
def slabs(src, regions, size=48, columns=6):
    out = Image.new("RGBA", (columns * size, ((len(regions) + columns - 1) // columns) * size), (0, 0, 0, 0))
    for i, (x, y, w, h) in enumerate(regions):
        tile = cut(src, x, y, w, h).resize((size, size), Image.LANCZOS)
        place(out, tile, i % columns, i // columns, size)
    return out

os.makedirs("maps/crypt/tiles", exist_ok=True)
stone = Image.open("assets/pixel_art/TX Tileset Stone Ground.png").convert("RGBA")
slabs(stone, [(1,1,92,92),(162,1,92,92)], columns=2).save("maps/crypt/tiles/crypt_ground.png")

os.makedirs("maps/hell/tiles", exist_ok=True)
regions = [(34,34,184,184),(250,34,184,184),(466,34,184,184),(34,250,184,184),(250,250,184,184),(466,250,184,184)]
a = Image.open("assets/pixel_art/TX tileset Hellfloor.png").convert("RGBA")
b = Image.open("assets/pixel_art/TX tileset Hellfloor2.png").convert("RGBA")
hell = Image.new("RGBA", (6 * 48, 2 * 48), (0, 0, 0, 0))
hell.paste(slabs(a, regions), (0, 0)); hell.paste(slabs(b, regions), (0, 48))
hell.save("maps/hell/tiles/hell_ground.png")
print("Tileset images written under maps/")
