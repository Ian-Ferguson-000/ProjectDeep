from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/tavern/keeper/tavern_keeper_animation_board.png"
OUTPUT = ROOT / "assets/tavern/keeper/tavern_keeper_frames.png"
FRAME_SIZE = (96, 80)
GRID_SIZE = 8
TARGET_MAX_SIZE = (70, 50)
ALPHA_THRESHOLD = 24


def primary_component(cell: Image.Image) -> Image.Image:
    alpha = cell.getchannel("A")
    width, height = cell.size
    opaque = alpha.load()
    visited = bytearray(width * height)
    components: list[tuple[int, tuple[int, int, int, int]]] = []

    for start_y in range(height):
        for start_x in range(width):
            index = start_y * width + start_x
            if visited[index] or opaque[start_x, start_y] <= ALPHA_THRESHOLD:
                continue
            queue = deque([(start_x, start_y)])
            visited[index] = 1
            count = 0
            minimum_x = maximum_x = start_x
            minimum_y = maximum_y = start_y
            while queue:
                x, y = queue.popleft()
                count += 1
                minimum_x = min(minimum_x, x)
                maximum_x = max(maximum_x, x)
                minimum_y = min(minimum_y, y)
                maximum_y = max(maximum_y, y)
                for next_y in range(max(0, y - 1), min(height, y + 2)):
                    for next_x in range(max(0, x - 1), min(width, x + 2)):
                        next_index = next_y * width + next_x
                        if not visited[next_index] and opaque[next_x, next_y] > ALPHA_THRESHOLD:
                            visited[next_index] = 1
                            queue.append((next_x, next_y))
            components.append((count, (minimum_x, minimum_y, maximum_x + 1, maximum_y + 1)))

    if not components:
        return Image.new("RGBA", (1, 1))
    # The keeper is the dominant connected silhouette in every nominal cell.
    # Intruding heads/feet from adjacent generated rows are smaller components.
    _, bounds = max(components, key=lambda component: component[0])
    return cell.crop(bounds)


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    extracted: list[Image.Image] = []
    for row in range(GRID_SIZE):
        top = round(row * source.height / GRID_SIZE)
        bottom = round((row + 1) * source.height / GRID_SIZE)
        for column in range(GRID_SIZE):
            left = round(column * source.width / GRID_SIZE)
            right = round((column + 1) * source.width / GRID_SIZE)
            extracted.append(primary_component(source.crop((left, top, right, bottom))))

    maximum_width = max(frame.width for frame in extracted)
    maximum_height = max(frame.height for frame in extracted)
    shared_scale = min(TARGET_MAX_SIZE[0] / maximum_width, TARGET_MAX_SIZE[1] / maximum_height)
    sheet = Image.new("RGBA", (FRAME_SIZE[0] * GRID_SIZE, FRAME_SIZE[1] * GRID_SIZE))
    for index, frame in enumerate(extracted):
        size = (max(1, round(frame.width * shared_scale)), max(1, round(frame.height * shared_scale)))
        normalized = frame.resize(size, Image.Resampling.NEAREST)
        x = (index % GRID_SIZE) * FRAME_SIZE[0] + (FRAME_SIZE[0] - normalized.width) // 2
        y = (index // GRID_SIZE) * FRAME_SIZE[1] + FRAME_SIZE[1] - normalized.height - 8
        sheet.alpha_composite(normalized, (x, y))
    sheet.save(OUTPUT, optimize=True)
    print(f"Wrote {OUTPUT} with shared scale {shared_scale:.4f}")


if __name__ == "__main__":
    main()
