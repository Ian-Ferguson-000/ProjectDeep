"""Extract the generated 4x3 tavern wall kit into transparent modules."""

from pathlib import Path
from PIL import Image

SOURCE = Path("assets/tavern/tavern_wall_kit_atlas.png")
OUTPUT = Path("assets/tavern/wall_kit")
NAMES = (
    "wall_straight", "wall_lantern", "wall_left", "wall_right",
    "corner_upper_left", "corner_upper_right", "corner_lower_left", "corner_lower_right",
    "doorway", "staircase", "bar_front", "support_pillar",
)

# The generated left-wall cell contains the far edge of the preceding module.
CELL_WINDOWS = {
    "wall_lantern": (80, 0, 362, 362),
    "wall_left": (150, 0, 362, 362),
    "support_pillar": (180, 0, 362, 362),
}


def remove_checkerboard(image: Image.Image) -> Image.Image:
    source = image.convert("RGBA")
    pixels = source.load()
    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, _ = pixels[x, y]
            spread = max(red, green, blue) - min(red, green, blue)
            alpha = 0 if spread <= 12 and min(red, green, blue) >= 170 else 255
            pixels[x, y] = (red, green, blue, alpha)
    return source


def main() -> None:
    atlas = Image.open(SOURCE)
    if atlas.size != (1448, 1086):
        raise ValueError(f"Unexpected wall atlas size: {atlas.size}")
    cell_width, cell_height = atlas.width // 4, atlas.height // 3
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(NAMES):
        column, row = index % 4, index // 4
        piece = atlas.crop((column * cell_width, row * cell_height, (column + 1) * cell_width, (row + 1) * cell_height))
        if name in CELL_WINDOWS:
            piece = piece.crop(CELL_WINDOWS[name])
        piece = remove_checkerboard(piece)
        bounds = piece.getchannel("A").getbbox()
        if bounds is None:
            raise ValueError(f"No opaque pixels found for {name}")
        piece = piece.crop(bounds)
        piece.save(OUTPUT / f"{name}.png")
        print(f"{name}: {piece.width}x{piece.height}")


if __name__ == "__main__":
    main()
