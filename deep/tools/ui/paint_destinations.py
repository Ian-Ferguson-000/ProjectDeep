"""Paints the destination pictures for the Set Out screen.

    python3 tools/ui/paint_destinations.py

Writes assets/ui/destinations/{forest,ashen_farmstead,moonlit_grove}.png at
320x180: layered silhouettes with haze, light and grain, in the game's pixel
style (shown scaled up with nearest filtering). Placeholder illustrations until
painted art replaces them; drop a PNG of any 16:9 size in the same place.
"""
import math, os, random
import numpy as np
from PIL import Image

W, H = 320, 180
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "destinations")


def hexc(value):
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)


def vgrad(top, bottom, h=H, w=W, power=1.0):
    t = (np.linspace(0, 1, h) ** power)[:, None, None]
    return np.broadcast_to(top * (1 - t) + bottom * t, (h, w, 3)).copy()


def glow(img, cx, cy, radius, colour, strength):
    y, x = np.mgrid[0:H, 0:W]
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / radius
    a = np.clip(1 - d, 0, 1) ** 2 * strength
    img[:] = img * (1 - a[..., None]) + colour * a[..., None]


def paint(img, mask, colour, alpha=1.0):
    a = mask.astype(float) * alpha
    img[:] = img * (1 - a[..., None]) + colour * a[..., None]


def conifer(mask, x, base, height, width):
    """A pine: stacked jagged tiers."""
    for row in range(int(base - height), int(base) + 1):
        if row < 0 or row >= H: continue
        t = (row - (base - height)) / max(1, height)
        tier = (t * 4) % 1.0
        half = width * 0.5 * t * (0.6 + 0.4 * tier)
        x0, x1 = int(x - half), int(x + half) + 1
        if x1 > 0: mask[row, max(0, x0):min(W, x1)] = True
    trunk = max(1, int(width * 0.08))
    if int(x) + trunk + 1 > 0: mask[int(base):min(H, int(base) + 4), max(0, int(x) - trunk):int(x) + trunk + 1] = True


def round_tree(mask, x, base, height, width, rng):
    """A broadleaf: a lumpy crown of overlapping blobs on a trunk."""
    y, xx = np.mgrid[0:H, 0:W]
    for _ in range(7):
        cx = x + rng.uniform(-0.35, 0.35) * width
        cy = base - height * rng.uniform(0.45, 0.85)
        r = width * rng.uniform(0.22, 0.36)
        mask |= (xx - cx) ** 2 + ((y - cy) * 1.1) ** 2 < r * r
    trunk = max(1, int(width * 0.07))
    if int(x) + trunk + 1 > 0: mask[max(0, int(base - height * 0.4)):min(H, int(base) + 3), max(0, int(x) - trunk):int(x) + trunk + 1] = True


def treeline(rng, base, height, spacing, kind="conifer", jitter=0.4):
    mask = np.zeros((H, W), bool)
    x = -spacing * rng.uniform(0, 1)
    while x < W + spacing:
        h = height * rng.uniform(1 - jitter, 1 + jitter)
        b = base + rng.uniform(-3, 3)
        if kind == "conifer" or (kind == "mixed" and rng.random() < 0.5):
            conifer(mask, x, b, h, h * rng.uniform(0.45, 0.6))
        else:
            round_tree(mask, x, b, h, h * rng.uniform(0.7, 0.95), rng)
        x += spacing * rng.uniform(0.6, 1.3)
    mask[int(base):, :] = True
    return mask


def hills(rng, base, amp, freq):
    x = np.arange(W)
    phase = [rng.uniform(0, 6.28) for _ in range(3)]
    top = base + amp * (np.sin(x * freq + phase[0]) * 0.6 + np.sin(x * freq * 2.3 + phase[1]) * 0.3 + np.sin(x * freq * 5.1 + phase[2]) * 0.1)
    y = np.arange(H)[:, None]
    return y >= top[None, :]


def path_mask(top_y, bottom_half, sway, top_half=2):
    y, x = np.mgrid[0:H, 0:W]
    t = np.clip((y - top_y) / (H - top_y), 0, 1)
    centre = W / 2 + sway * np.sin(t * 3.0 + 0.6) * (1 - t * 0.5)
    half = top_half + (bottom_half - top_half) * t ** 1.4
    return (y >= top_y) & (np.abs(x - centre) < half)


def rays(img, origin, colour, strength, count, rng):
    y, x = np.mgrid[0:H, 0:W]
    ang = np.arctan2(y - origin[1], x - origin[0])
    acc = np.zeros((H, W))
    for _ in range(count):
        a = rng.uniform(0.5, 2.0)
        w = rng.uniform(0.03, 0.07)
        acc += np.exp(-((ang - a) / w) ** 2) * rng.uniform(0.5, 1)
    fall = np.clip(1 - np.sqrt((x - origin[0]) ** 2 + (y - origin[1]) ** 2) / (W * 0.9), 0, 1)
    a = np.clip(acc * fall * strength, 0, 0.6)
    img[:] = img * (1 - a[..., None]) + colour * a[..., None]


def specks(img, rng, count, colour, area, size=1):
    x0, y0, x1, y1 = area
    for _ in range(count):
        x, y = rng.randint(x0, x1 - 1), rng.randint(y0, y1 - 1)
        img[y:y + size, x:x + size] = colour


def finish(img, rng, name, vignette=0.55):
    y, x = np.mgrid[0:H, 0:W]
    d = np.sqrt(((x - W / 2) / (W / 2)) ** 2 + ((y - H / 2) / (H / 2)) ** 2)
    img *= (1 - np.clip(d - 0.55, 0, 1) * vignette)[..., None]
    img += np.random.default_rng(rng.randint(0, 9999)).normal(0, 3.0, img.shape)
    # Posterise lightly so it sits with the pixel art.
    img = np.round(np.clip(img, 0, 255) / 6) * 6
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).save(os.path.join(OUT, name + ".png"))


def forest():
    rng = random.Random(7)
    img = vgrad(hexc("#f3e2a6"), hexc("#7fb08a"), power=0.9)
    glow(img, 205, 46, 120, hexc("#fff4c8"), 0.85)
    layers = [  # base, height, spacing, colour, kind
        (96, 46, 16, "#8fb898", "conifer"),
        (108, 54, 18, "#6a9c78", "conifer"),
        (122, 62, 22, "#4c7f5a", "mixed"),
        (138, 74, 26, "#335f41", "mixed"),
    ]
    for base, height, spacing, colour, kind in layers:
        paint(img, treeline(rng, base, height, spacing, kind), hexc(colour))
        paint(img, np.ones((H, W), bool), hexc("#e9e1b0"), 0.10)  # haze between layers
    rays(img, (205, 30), hexc("#fff6cf"), 0.35, 9, rng)
    ground = hills(rng, 146, 3, 0.03)
    paint(img, ground, hexc("#2d5a2f"))
    paint(img, ground & (np.arange(H)[:, None] > 160), hexc("#244a26"))
    paint(img, path_mask(140, 58, 26) & ground, hexc("#c9a76a"))
    paint(img, path_mask(146, 46, 26) & ground, hexc("#dcbc7c"))
    # Foreground framing trees, dark against the light.
    front = np.zeros((H, W), bool)
    conifer(front, 18, 190, 175, 70); conifer(front, 302, 190, 168, 66)
    round_tree(front, 62, 196, 90, 70, rng); round_tree(front, 268, 196, 84, 64, rng)
    paint(img, front, hexc("#173723"))
    specks(img, rng, 40, hexc("#e8d8ff"), (90, 150, 230, 178))           # wildflowers
    specks(img, rng, 30, hexc("#f6c94a"), (90, 150, 230, 178))
    specks(img, rng, 22, hexc("#fff3b0"), (60, 60, 260, 140))            # motes in the light
    finish(img, rng, "forest", 0.6)


def farmstead():
    rng = random.Random(11)
    img = vgrad(hexc("#5a2f24"), hexc("#d9874a"), power=1.3)
    glow(img, 230, 110, 140, hexc("#ffb36b"), 0.7)
    paint(img, hills(rng, 112, 6, 0.02), hexc("#8a4a33"))
    paint(img, treeline(rng, 122, 26, 30, "round", 0.5), hexc("#5a2c20"))
    # Barn and silo silhouette.
    barn = np.zeros((H, W), bool)
    y, x = np.mgrid[0:H, 0:W]
    barn |= (x > 92) & (x < 150) & (y > 96) & (y < 130)
    barn |= (y > 74) & (y <= 96) & (np.abs(x - 121) < (y - 70) * 1.35)
    barn |= (x > 156) & (x < 170) & (y > 70) & (y < 130)
    barn |= (y > 64) & (y <= 70) & (np.abs(x - 163) < (y - 62) * 1.2)
    paint(img, barn, hexc("#3a1d17"))
    paint(img, (x > 116) & (x < 127) & (y > 112) & (y < 130), hexc("#ff9a4a"))  # embers in the door
    # A dead tree and a fence in front.
    front = np.zeros((H, W), bool)
    front |= (np.abs(x - 262) < 3) & (y > 60) & (y < 140)
    for (a, b, c, d) in [(262, 92, 240, 70), (262, 84, 286, 58), (262, 104, 292, 90), (250, 80, 244, 62)]:
        for k in range(40):
            px = int(a + (c - a) * k / 39); py = int(b + (d - b) * k / 39)
            front[max(0, py - 1):py + 1, max(0, px - 1):px + 1] = True
    for post in range(10, 90, 14):
        front |= (np.abs(x - post) < 1.5) & (y > 122) & (y < 140)
    front |= (x < 90) & ((np.abs(y - 127) < 1) | (np.abs(y - 133) < 1))
    paint(img, front, hexc("#2a1410"))
    field = hills(rng, 134, 2, 0.05)
    paint(img, field, hexc("#4a2418"))
    for row in range(138, H, 6):  # furrows
        paint(img, (y == row) & field, hexc("#6b3424"))
    specks(img, rng, 80, hexc("#ffcf8a"), (0, 20, W, 140))  # drifting ash
    finish(img, rng, "ashen_farmstead")


def grove():
    rng = random.Random(23)
    img = vgrad(hexc("#0b1230"), hexc("#46609c"), power=1.0)
    specks(img, rng, 90, hexc("#dfe8ff"), (0, 0, W, 100))
    glow(img, 160, 46, 110, hexc("#cfe0ff"), 0.65)
    y, x = np.mgrid[0:H, 0:W]
    paint(img, (x - 160) ** 2 + (y - 46) ** 2 < 20 ** 2, hexc("#f1f5ff"))
    paint(img, (x - 167) ** 2 + (y - 41) ** 2 < 5 ** 2, hexc("#d5def2"))
    paint(img, (x - 153) ** 2 + (y - 53) ** 2 < 3 ** 2, hexc("#dde5f6"))
    paint(img, treeline(rng, 116, 26, 20, "round"), hexc("#2f4479"))
    paint(img, treeline(rng, 128, 34, 26, "mixed"), hexc("#22325e"))
    ground = hills(rng, 136, 2, 0.04)
    paint(img, ground, hexc("#18264a"))
    glow(img, 160, 152, 70, hexc("#7fa6e8"), 0.35)
    ring = np.abs(np.sqrt((x - 160) ** 2 + ((y - 152) * 3.0) ** 2) - 48) < 2.6
    paint(img, ring & ground, hexc("#b4d0ff"), 0.9)
    for k in range(12):  # glowing mushrooms around the ring
        a = k / 12 * 6.283
        mx, my = int(160 + math.cos(a) * 48), int(152 + math.sin(a) * 16)
        paint(img, (np.abs(x - mx) < 2) & (y >= my - 3) & (y <= my), hexc("#e6f4ff"))
    # Framing trees left and right, dark against the moonlight.
    front = np.zeros((H, W), bool)
    round_tree(front, 20, 186, 170, 110, rng); round_tree(front, 300, 186, 160, 100, rng)
    conifer(front, 72, 184, 120, 50)
    paint(img, front, hexc("#0a1128"))
    specks(img, rng, 26, hexc("#b8f0ff"), (70, 70, 250, 140), 2)  # wisps
    finish(img, rng, "moonlit_grove")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    forest(); farmstead(); grove()
    print("painted", OUT)
