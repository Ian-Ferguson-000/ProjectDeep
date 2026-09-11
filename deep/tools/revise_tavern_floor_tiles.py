"""Build and validate a seam-safe sibling of the tavern floor atlas.

The source atlas is an 8x8 grid of 32 px tiles. Each material occupies a 4x2
block. The output keeps that contract, including the original bottom-left
square-cobble family, while making every other family's outer pixels shared
and periodic so its variants can be mixed freely in a TileMapLayer.
"""

from __future__ import annotations

import argparse
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


TILE = 32
FAMILIES = {
    "vertical_wood": (0, 0),
    "horizontal_wood": (4, 0),
    "parquet": (0, 2),
    "diagonal_wood": (4, 2),
    "orange_cobble": (0, 4),
    "small_grey_cobble": (4, 4),
    "square_grey_cobble": (0, 6),
    "lower_orange_cobble": (4, 6),
}


def crop_tiles(source: Image.Image, origin: tuple[int, int]) -> list[Image.Image]:
    ox, oy = origin
    return [
        source.crop(((ox + x) * TILE, (oy + y) * TILE, (ox + x + 1) * TILE, (oy + y + 1) * TILE))
        for y in range(2)
        for x in range(4)
    ]


def mean_color(images: list[Image.Image], box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    values = []
    for image in images:
        values.extend(image.crop(box).get_flattened_data())
    return tuple(sum(pixel[channel] for pixel in values) // len(values) for channel in range(4))


def periodic_base(tile: Image.Image, band: int = 6) -> Image.Image:
    """Blend paired edge bands and then make the opposing outer pixels exact."""
    result = tile.copy()
    pixels = result.load()
    for distance in range(band):
        left, right = distance, TILE - 1 - distance
        edge_weight = (band - distance) / band
        for y in range(TILE):
            a, b = pixels[left, y], pixels[right, y]
            average = tuple(round((a[c] + b[c]) / 2) for c in range(4))
            pixels[left, y] = tuple(round(a[c] * (1 - edge_weight) + average[c] * edge_weight) for c in range(4))
            pixels[right, y] = tuple(round(b[c] * (1 - edge_weight) + average[c] * edge_weight) for c in range(4))
    for distance in range(band):
        top, bottom = distance, TILE - 1 - distance
        edge_weight = (band - distance) / band
        for x in range(TILE):
            a, b = pixels[x, top], pixels[x, bottom]
            average = tuple(round((a[c] + b[c]) / 2) for c in range(4))
            pixels[x, top] = tuple(round(a[c] * (1 - edge_weight) + average[c] * edge_weight) for c in range(4))
            pixels[x, bottom] = tuple(round(b[c] * (1 - edge_weight) + average[c] * edge_weight) for c in range(4))
    for y in range(TILE):
        pixels[TILE - 1, y] = pixels[0, y]
    for x in range(TILE):
        pixels[x, TILE - 1] = pixels[x, 0]
    return result


def interior_mask(inset: int = 5) -> Image.Image:
    mask = Image.new("L", (TILE, TILE), 0)
    ImageDraw.Draw(mask).rectangle((inset, inset, TILE - 1 - inset, TILE - 1 - inset), fill=255)
    return mask.filter(ImageFilter.GaussianBlur(2.0))


def shared_boundary_variants(tiles: list[Image.Image], base_index: int = 0) -> list[Image.Image]:
    base = periodic_base(tiles[base_index])
    mask = interior_mask()
    variants = []
    for tile in tiles:
        candidate = Image.composite(tile, base, mask)
        cp = candidate.load()
        bp = base.load()
        for y in range(TILE):
            cp[0, y] = bp[0, y]
            cp[TILE - 1, y] = bp[0, y]
        for x in range(TILE):
            cp[x, 0] = bp[x, 0]
            cp[x, TILE - 1] = bp[x, 0]
        variants.append(candidate)
    return variants


def wood_palette(tiles: list[Image.Image]) -> dict[str, tuple[int, int, int, int]]:
    base = mean_color(tiles, (4, 4, 28, 28))
    return {
        "base": base,
        "light": tuple(min(255, int(c * 1.13)) for c in base[:3]) + (255,),
        "mid": tuple(max(0, int(c * 0.88)) for c in base[:3]) + (255,),
        "dark": tuple(max(0, int(c * 0.55)) for c in base[:3]) + (255,),
        "nail": tuple(max(0, int(c * 0.38)) for c in base[:3]) + (255,),
    }


def draw_parquet(tiles: list[Image.Image], variant: int) -> Image.Image:
    palette = wood_palette(tiles)
    image = Image.new("RGBA", (TILE, TILE), palette["base"])
    draw = ImageDraw.Draw(image)
    rng = random.Random(8400 + variant)
    # Module centres lie on tile edges/corners. Each 16px square therefore
    # finishes as a half-square at the boundary and completes in its neighbour.
    for cy in (0, 16, 32):
        for cx in (0, 16, 32):
            vertical = ((cx // 16) + (cy // 16)) % 2 == 0
            bounds = (cx - 8, cy - 8, cx + 8, cy + 8)
            draw.rectangle(bounds, fill=palette["base"], outline=palette["dark"], width=1)
            for offset in (-4, 0, 4):
                if vertical:
                    draw.line((cx + offset, cy - 7, cx + offset, cy + 7), fill=palette["mid"], width=1)
                else:
                    draw.line((cx - 7, cy + offset, cx + 7, cy + offset), fill=palette["mid"], width=1)
    # Restrict variant texture to the interior so all eight tiles share edges.
    for _ in range(7):
        x, y = rng.randrange(5, 27), rng.randrange(5, 27)
        draw.point((x, y), fill=palette["light"] if rng.random() < .55 else palette["nail"])
    return periodic_base(image, 1)


def draw_diagonal(tiles: list[Image.Image], variant: int) -> Image.Image:
    palette = wood_palette(tiles)
    image = Image.new("RGBA", (TILE, TILE), palette["base"])
    draw = ImageDraw.Draw(image)
    rng = random.Random(9100 + variant)
    # x+y modulo 16 is exactly periodic over a 32px tile in both directions.
    for y in range(TILE):
        for x in range(TILE):
            phase = (x + y) % 16
            color = palette["base"]
            if phase in (0, 1):
                color = palette["dark"]
            elif phase in (2, 3):
                color = palette["light"]
            elif phase in (14, 15):
                color = palette["mid"]
            image.putpixel((x, y), color)
    # Small interior-only board marks provide variation without changing seams.
    for _ in range(4):
        x, y = rng.randrange(6, 26), rng.randrange(6, 26)
        draw.rectangle((x, y, x + rng.randrange(1, 3), y + 1), fill=palette["nail"])
    return periodic_base(image, 1)


def paste_family(atlas: Image.Image, tiles: list[Image.Image], origin: tuple[int, int]) -> None:
    ox, oy = origin
    for index, tile in enumerate(tiles):
        atlas.paste(tile, ((ox + index % 4) * TILE, (oy + index // 4) * TILE))


def assert_shared_seams(tiles: list[Image.Image], name: str) -> None:
    reference = tiles[0]
    for index, tile in enumerate(tiles):
        for y in range(TILE):
            assert tile.getpixel((0, y)) == tile.getpixel((TILE - 1, y)), f"{name} tile {index}: horizontal seam"
            assert tile.getpixel((0, y)) == reference.getpixel((0, y)), f"{name} tile {index}: incompatible vertical edge"
        for x in range(TILE):
            assert tile.getpixel((x, 0)) == tile.getpixel((x, TILE - 1)), f"{name} tile {index}: vertical seam"
            assert tile.getpixel((x, 0)) == reference.getpixel((x, 0)), f"{name} tile {index}: incompatible horizontal edge"


def build_preview(atlas: Image.Image, output: Path) -> None:
    preview = Image.new("RGBA", (4 * 192, 2 * 192), (30, 24, 22, 255))
    for family_index, origin in enumerate(FAMILIES.values()):
        tiles = crop_tiles(atlas, origin)
        patch = Image.new("RGBA", (96, 96))
        order = (0, 1, 2, 4, 5, 6, 3, 7, 0)
        for index, tile_index in enumerate(order):
            patch.paste(tiles[tile_index], ((index % 3) * TILE, (index // 3) * TILE))
        preview.paste(patch.resize((192, 192), Image.Resampling.NEAREST), ((family_index % 4) * 192, (family_index // 4) * 192))
    preview.save(output)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()
    source = Image.open(args.source).convert("RGBA")
    if source.size != (256, 256):
        raise ValueError(f"Expected a 256x256 atlas, got {source.size}")
    atlas = source.copy()
    for name, origin in FAMILIES.items():
        original = crop_tiles(source, origin)
        if name == "square_grey_cobble":
            revised = original
        elif name == "parquet":
            revised = [draw_parquet(original, index) for index in range(8)]
        elif name == "diagonal_wood":
            revised = [draw_diagonal(original, index) for index in range(8)]
        else:
            revised = shared_boundary_variants(original)
        if name != "square_grey_cobble":
            assert_shared_seams(revised, name)
        paste_family(atlas, revised, origin)
    # The user's reference family remains byte-for-byte identical.
    assert atlas.crop((0, 192, 128, 256)).tobytes() == source.crop((0, 192, 128, 256)).tobytes()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(args.output)
    if args.preview:
        build_preview(atlas, args.preview)
    print(f"Wrote {args.output} ({atlas.width}x{atlas.height})")
    print("Validated shared opposite edges and cross-variant family edges.")
    print("Validated bottom-left square cobblestone family unchanged.")


if __name__ == "__main__":
    main()
