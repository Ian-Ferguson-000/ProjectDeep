"""Extract the generated 4x2 décor contact sheet into transparent props."""

from collections import deque
from pathlib import Path

from PIL import Image

SOURCE = Path("assets/tavern/tavern_decor_kit_atlas.png")
OUTPUT = Path("assets/tavern/decor")
NAMES = (
    "hearth_rug",
    "ale_barrels",
    "supply_crates",
    "notice_board",
    "firewood",
    "serving_sideboard",
    "flame_banner",
    "weapon_rack",
)


def remove_connected_checkerboard(image: Image.Image) -> Image.Image:
    """Remove only pale neutral pixels connected to a cell edge."""
    source = image.convert("RGBA")
    pixels = source.load()
    width, height = source.size
    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))
    while queue:
        x, y = queue.popleft()
        if (x, y) in visited:
            continue
        visited.add((x, y))
        red, green, blue, _ = pixels[x, y]
        if max(red, green, blue) - min(red, green, blue) > 22 or min(red, green, blue) < 145:
            continue
        pixels[x, y] = (red, green, blue, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in visited:
                queue.append((nx, ny))
    return source


def main() -> None:
    atlas = Image.open(SOURCE)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(NAMES):
        column, row = index % 4, index // 4
        left = round(column * atlas.width / 4)
        right = round((column + 1) * atlas.width / 4)
        top = round(row * atlas.height / 2)
        bottom = round((row + 1) * atlas.height / 2)
        piece = remove_connected_checkerboard(atlas.crop((left, top, right, bottom)))
        bounds = piece.getchannel("A").getbbox()
        if bounds is None:
            raise ValueError(f"No opaque pixels found for {name}")
        piece = piece.crop(bounds)
        piece.save(OUTPUT / f"{name}.png")
        print(f"{name}: {piece.width}x{piece.height}")


if __name__ == "__main__":
    main()
