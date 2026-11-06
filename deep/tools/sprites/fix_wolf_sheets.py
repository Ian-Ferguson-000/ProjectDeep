"""Rebuilds the wolf sprite sheets from their sources: the six enemy wolves
(assets/enemies/<wolf>/normalized_sheet.png from generated_source.png) and the
summoner's companion (assets/classes/wolf_companion/sheet.png from source.png).

    python3 tools/sprites/fix_wolf_sheets.py            # every wolf
    python3 tools/sprites/fix_wolf_sheets.py wolf_howler

Each output sheet is 6 x 4 cells of 96 x 80: rows down, left, right, up; columns
idle x2, run x2, attack x2. frames.tres reads those regions and is unchanged.

Why this exists: the generic normalizer (tools/normalize_generated_enemies.gd) cut
the source on a fixed grid and stretched every frame to fill its cell, so the wolves
changed size from frame to frame, slid around, and picked up ears and tails from
neighbouring frames. Here:
  * the backdrop is removed from the whole source, then every separate piece is
    given to the frame its centre sits in (no more bleed), and specks are dropped;
  * one scale is used for the whole sheet, so the wolf stays the same size;
  * every frame stands on the same ground line, centred on the wolf's body;
  * the right-facing row is a mirror of the left-facing row (the source drew the
    right row smaller and in different poses).
"""
import os
import sys
from collections import deque
from PIL import Image, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
ENEMIES = os.path.join(HERE, "..", "..", "assets")
# name -> (source, output, first column whose loose effect pieces are kept)
WOLVES = {name: ("enemies/%s/generated_source.png" % name, "enemies/%s/normalized_sheet.png" % name, 9)
          for name in ["feral_wolf", "wolf_vanguard", "wolf_lurker", "wolf_charger", "wolf_hunter"]}
WOLVES["wolf_howler"] = ("enemies/wolf_howler/generated_source.png", "enemies/wolf_howler/normalized_sheet.png", 4)
WOLVES["wolf_companion"] = ("classes/wolf_companion/source.png", "classes/wolf_companion/sheet.png", 3)
CW, CH, COLS, ROWS = 96, 80, 6, 4
LEFT, RIGHT = 1, 2
BODY_W, BODY_H = 88, 70     # the largest wolf frame fits this box
GROUND = 77                 # feet rest on this pixel row of each cell
MIN_PIECE = 30              # source pixels; smaller pieces are dust


def is_backdrop(rgba):
    r, g, b, a = rgba
    if a < 40:
        return True
    hi, lo = max(r, g, b), min(r, g, b)
    return lo > 200 and hi - lo < 18


def remove_backdrop(img):
    """Flood the light (or checkered) backdrop in from the image edges."""
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    queue = deque()
    for x in range(w):
        queue.append((x, 0)); queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y)); queue.append((w - 1, y))
    while queue:
        x, y = queue.popleft()
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        if not is_backdrop(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                queue.append((nx, ny))
    # Backdrop trapped between legs or under the tail: light pockets of any real size.
    pocket_seen = bytearray(w * h)
    for y in range(h):
        for x in range(w):
            if pocket_seen[y * w + x] or not px[x, y][3] or not is_backdrop(px[x, y]):
                continue
            pocket = []; queue = deque([(x, y)]); pocket_seen[y * w + x] = 1
            while queue:
                cx, cy = queue.popleft(); pocket.append((cx, cy))
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not pocket_seen[ny * w + nx] and px[nx, ny][3] and is_backdrop(px[nx, ny]):
                        pocket_seen[ny * w + nx] = 1; queue.append((nx, ny))
            if len(pocket) >= 40:
                for cx, cy in pocket:
                    px[cx, cy] = (0, 0, 0, 0)
    # Light fringe pixels left around the outline.
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and is_backdrop(px[x, y]):
                touching = any(0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] == 0
                               for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if touching:
                    px[x, y] = (0, 0, 0, 0)


def pieces(img):
    w, h = img.size
    px = img.load()
    label = [-1] * (w * h)
    found = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 40 or label[y * w + x] >= 0:
                continue
            index = len(found)
            queue = deque([(x, y)]); label[y * w + x] = index; pts = []
            while queue:
                cx, cy = queue.popleft(); pts.append((cx, cy))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and label[ny * w + nx] < 0 and px[nx, ny][3] >= 40:
                            label[ny * w + nx] = index; queue.append((nx, ny))
            found.append(pts)
    return found


def bbox(pts):
    xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def dehalo(img, passes=2):
    """Drops pale, grey anti-aliasing pixels left on the outline by the white backdrop."""
    w, h = img.size
    px = img.load()
    for _ in range(passes):
        strip = []
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a == 0:
                    continue
                edge = any(not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0
                           for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                lum = 0.299 * r + 0.587 * g + 0.114 * b
                if edge and lum > 135 and max(r, g, b) - min(r, g, b) < 40:
                    strip.append((x, y))
        for x, y in strip:
            px[x, y] = (0, 0, 0, 0)


def rebuild(name):
    source, output, effect_col = WOLVES[name]
    src = Image.open(os.path.join(ENEMIES, source)).convert("RGBA")
    remove_backdrop(src)
    sw, sh = src.size
    cell_w, cell_h = sw / COLS, sh / ROWS
    frames = {}
    for pts in pieces(src):
        if len(pts) < MIN_PIECE:
            continue
        x0, y0, x1, y1 = bbox(pts)
        col = min(COLS - 1, int(((x0 + x1) / 2) / cell_w))
        row = min(ROWS - 1, int(((y0 + y1) / 2) / cell_h))
        frames.setdefault((row, col), []).append(pts)
    # The wolf is the largest piece in each frame; effects (howler rings) ride along.
    bodies = {}
    for key, group in frames.items():
        group.sort(key=len, reverse=True)
        body = group[0]
        # Keep detached bits of the wolf (a paw, a tail tip) close to the body.
        bx0, by0, bx1, by1 = bbox(body)
        keep = [body]
        for extra in group[1:]:
            ex0, ey0, ex1, ey1 = bbox(extra)
            near = ex1 > bx0 - 12 and ex0 < bx1 + 12 and ey1 > by0 - 12 and ey0 < by1 + 12
            effect = key[1] >= effect_col
            if near or effect or len(extra) > len(body) * 0.2:
                keep.append(extra)
        frames[key] = keep
        bodies[key] = bbox(body)
    missing = [(r, c) for r in range(ROWS) for c in range(COLS) if (r, c) not in frames]
    assert not missing, (name, missing)
    scale = min(min(BODY_W / (b[2] - b[0]), BODY_H / (b[3] - b[1])) for k, b in bodies.items() if k[0] != RIGHT)
    out = Image.new("RGBA", (CW * COLS, CH * ROWS), (0, 0, 0, 0))
    spx = src.load()
    for (row, col), group in frames.items():
        if row == RIGHT:
            continue
        all_pts = [p for g in group for p in g]
        x0, y0, x1, y1 = bbox(all_pts)
        piece = Image.new("RGBA", (x1 - x0, y1 - y0), (0, 0, 0, 0))
        ppx = piece.load()
        for x, y in all_pts:
            ppx[x - x0, y - y0] = spx[x, y]
        size = (max(1, round(piece.width * scale)), max(1, round(piece.height * scale)))
        piece = piece.resize(size, Image.NEAREST)
        bx0, by0, bx1, by1 = bodies[(row, col)]
        body_cx = ((bx0 + bx1) / 2 - x0) * scale
        body_bottom = (by1 - y0) * scale
        ox = col * CW + round(CW / 2 - body_cx)
        oy = row * CH + round(GROUND - body_bottom)
        cell = Image.new("RGBA", (CW * COLS, CH * ROWS), (0, 0, 0, 0))
        cell.paste(piece, (ox, oy))
        out.alpha_composite(cell.crop((col * CW, row * CH, (col + 1) * CW, (row + 1) * CH)), (col * CW, row * CH))
    dehalo(out)
    for col in range(COLS):
        left = out.crop((col * CW, LEFT * CH, (col + 1) * CW, (LEFT + 1) * CH))
        out.paste(ImageOps.mirror(left), (col * CW, RIGHT * CH))
    out.save(os.path.join(ENEMIES, output))
    print("rebuilt %s (scale %.3f)" % (name, scale))


if __name__ == "__main__":
    for wolf in (sys.argv[1:] or WOLVES):
        rebuild(wolf)
