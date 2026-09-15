from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = ROOT / "tools/source_art"
CLASS_IDS = ("phantom", "tank", "healer")
GRID_SIZE = 8
FRAME_SIZES = {"phantom": (124, 199), "tank": (136, 181), "healer": (136, 181)}
TARGET_MAX_SIZE = (170, 110)


def remove_connected_checkerboard(image: Image.Image) -> None:
    pixels = image.load()
    width, height = image.size
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))

    def is_checker(x: int, y: int) -> bool:
        red, green, blue, _ = pixels[x, y]
        return max(red, green, blue) - min(red, green, blue) < 24 and (red + green + blue) / 3 > 155

    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if visited[index] or not is_checker(x, y):
            continue
        visited[index] = 1
        red, green, blue, _ = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)
        if x > 0: queue.append((x - 1, y))
        if x + 1 < width: queue.append((x + 1, y))
        if y > 0: queue.append((x, y - 1))
        if y + 1 < height: queue.append((x, y + 1))


def normalize_class(class_id: str) -> None:
    source_path = SOURCE_ROOT / f"{class_id}_locomotion_source.png.source"
    output_path = ROOT / f"assets/classes/{class_id}/locomotion_frames.png"
    source = Image.open(source_path).convert("RGBA")
    remove_connected_checkerboard(source)
    frames: list[Image.Image] = []
    for row in range(GRID_SIZE):
        top = round(row * source.height / GRID_SIZE)
        bottom = round((row + 1) * source.height / GRID_SIZE)
        for column in range(GRID_SIZE):
            left = round(column * source.width / GRID_SIZE)
            right = round((column + 1) * source.width / GRID_SIZE)
            cell = source.crop((left, top, right, bottom))
            bounds = cell.getbbox()
            frames.append(cell.crop(bounds) if bounds is not None else Image.new("RGBA", (1, 1)))

    maximum_width = max(frame.width for frame in frames)
    maximum_height = max(frame.height for frame in frames)
    shared_scale = min(TARGET_MAX_SIZE[0] / maximum_width, TARGET_MAX_SIZE[1] / maximum_height)
    frame_size = FRAME_SIZES[class_id]
    baseline = frame_size[1] - 6
    sheet = Image.new("RGBA", (frame_size[0] * GRID_SIZE, frame_size[1] * GRID_SIZE))
    for index, frame in enumerate(frames):
        size = (max(1, round(frame.width * shared_scale)), max(1, round(frame.height * shared_scale)))
        normalized = frame.resize(size, Image.Resampling.NEAREST)
        x = (index % GRID_SIZE) * frame_size[0] + (frame_size[0] - normalized.width) // 2
        y = (index // GRID_SIZE) * frame_size[1] + baseline - normalized.height
        sheet.alpha_composite(normalized, (x, y))
    sheet.save(output_path, optimize=True)
    print(f"Wrote {output_path} with shared scale {shared_scale:.4f}")


def main() -> None:
    for class_id in CLASS_IDS:
        normalize_class(class_id)


if __name__ == "__main__":
    main()
