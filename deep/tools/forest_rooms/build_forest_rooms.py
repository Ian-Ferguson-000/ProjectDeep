"""Draws the Verdant Forest room maps and writes data/forest_rooms.json.

Run from the project folder:  python3 tools/forest_rooms/build_forest_rooms.py

Each room is drawn on an inner canvas (the area inside the thicket border) using
small helpers, then framed with thicket and door slots. You can also edit the
JSON by hand; ForestRoomLibrary.validate() and tests/forest_rooms_test.gd check
whichever you do. Symbols are documented in LEGEND below and docs/ForestRooms.md.
"""
import json, math, os, sys
from collections import deque

LEGEND = {
    "#": "thicket wall (blocked, drawn as trees)",
    ".": "grass",
    "=": "dirt trail",
    "c": "cobblestone ruin floor",
    "~": "water (blocked)",
    "R": "breakable rock",
    "T": "large tree (breakable, blocks)",
    "C": "locked chest (needs a key)",
    "r": "mossy rock (decoration)",
    "p": "pebbles (decoration)",
    "m": "mushrooms (decoration)",
    "b": "bush (decoration)",
    "F": "campfire (camp rooms only: shop and rest)",
    "e": "enemy spawn",
    "E": "on the east edge: east door slot. Inside the room: elite or boss spawn",
    "$": "loot cache",
    "*": "treasure pedestal (relic choice)",
    "M": "merchant (shop rooms only)",
    "X": "descent gate to the next floor",
    "P": "player start (start rooms only)",
    "N": "north door slot (top edge centre)",
    "S": "south door slot (bottom edge centre)",
    "W": "west door slot (left edge centre)",
}

STANDARD = (25, 13)   # inner size -> 27x15 room
LARGE = (33, 17)      # inner size -> 35x19 room


class Canvas:
    def __init__(self, size, fill="."):
        self.w, self.h = size
        self.g = [[fill] * self.w for _ in range(self.h)]
        self.cx, self.cy = self.w // 2, self.h // 2

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h: self.g[y][x] = ch
        return self

    def puts(self, points, ch):
        for x, y in points: self.put(x, y, ch)
        return self

    def hline(self, y, x0, x1, ch="="):
        for x in range(min(x0, x1), max(x0, x1) + 1): self.put(x, y, ch)
        return self

    def vline(self, x, y0, y1, ch="="):
        for y in range(min(y0, y1), max(y0, y1) + 1): self.put(x, y, ch)
        return self

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1): self.hline(y, x0, x1, ch)
        return self

    def ring(self, x0, y0, x1, y1, ch):
        self.hline(y0, x0, x1, ch); self.hline(y1, x0, x1, ch); self.vline(x0, y0, y1, ch); self.vline(x1, y0, y1, ch)
        return self

    def blob(self, cx, cy, rx, ry, ch):
        for y in range(self.h):
            for x in range(self.w):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0: self.put(x, y, ch)
        return self

    def oval(self, cx, cy, rx, ry, ch, steps=72):
        for i in range(steps):
            a = math.tau * i / steps
            self.put(round(cx + math.cos(a) * rx), round(cy + math.sin(a) * ry), ch)
        return self

    def cross(self, ch="="):
        return self.hline(self.cy, 0, self.w - 1, ch).vline(self.cx, 0, self.h - 1, ch)

    def corners(self, size=3, ch="#"):
        """Thicket bulges into the four corners so rooms read less boxy."""
        for x0, y0, sx, sy in [(0, 0, 1, 1), (self.w - 1, 0, -1, 1), (0, self.h - 1, 1, -1), (self.w - 1, self.h - 1, -1, -1)]:
            for d in range(size):
                for k in range(size - d):
                    self.put(x0 + sx * k, y0 + sy * d, ch)
        return self

    def rows(self):
        """Frames the canvas with thicket and the four door slots."""
        width = self.w + 2
        top = "#" * (width // 2) + "N" + "#" * (width // 2)
        bottom = "#" * (width // 2) + "S" + "#" * (width // 2)
        out = [top]
        for y, row in enumerate(self.g):
            left, right = ("W", "E") if y == self.cy else ("#", "#")
            out.append(left + "".join(row) + right)
        out.append(bottom)
        return out


ROOMS = []

def room(id, name, roles, canvas, weight=1.0):
    ROOMS.append({"id": id, "name": name, "roles": roles, "weight": weight, "map": canvas.rows()})


# ---------------------------------------------------------------- start

c = Canvas(STANDARD).corners(3)
c.cross()
c.puts([(4, 2), (19, 3), (7, 10), (20, 9), (3, 8)], "m").puts([(9, 3), (16, 10), (21, 5)], "p").puts([(5, 5), (18, 8), (15, 2)], "r")
c.puts([(3, 2), (21, 2), (3, 10), (21, 10)], "b")
c.put(c.cx, c.cy, "P")
room("quiet_glade", "Quiet Glade", ["start"], c)

c = Canvas(STANDARD).corners(2)
c.blob(19, 3, 3.2, 1.8, "~")
c.hline(c.cy, 0, c.w - 1).vline(c.cx, 0, c.cy).vline(6, c.cy, c.h - 1)
c.puts([(4, 3), (8, 9), (16, 10), (21, 9)], "m").puts([(10, 2), (14, 9)], "p").puts([(15, 5), (4, 10)], "r")
c.put(c.cx, c.cy, "P")
room("dawn_meadow", "Dawn Meadow", ["start"], c)

# ---------------------------------------------------------------- combat

c = Canvas(STANDARD).corners(2)
c.cross()
c.puts([(5, 3), (18, 2), (20, 9), (7, 10), (15, 4), (9, 8)], "R")
c.puts([(3, 2), (9, 1), (16, 3), (21, 4), (3, 9), (10, 11), (17, 9), (22, 10)], "e")
c.put(c.cx, c.cy, "$")
c.puts([(2, 5), (14, 11), (22, 2)], "r").puts([(6, 6), (19, 7)], "p").puts([(11, 3), (13, 9)], "m")
room("mossy_crossing", "Mossy Crossing", ["combat"], c)

c = Canvas(STANDARD)
c.blob(4, 2, 4.2, 2.6, "~").blob(21, 10, 4.2, 2.6, "~")
c.vline(c.cx, 0, 4).hline(4, c.cx, 18).vline(18, 4, c.cy).hline(c.cy, 0, c.w - 1).vline(8, c.cy, c.h - 1).hline(c.h - 1, 8, c.cx).vline(c.cx, c.cy, c.h - 1)
c.puts([(7, 3), (15, 2), (21, 4), (4, 9), (11, 10), (16, 8), (2, 6), (22, 6)], "e")
c.puts([(10, 8), (20, 3)], "R").puts([(14, 11), (5, 11)], "m").puts([(9, 2), (22, 6)], "r").put(18, 9, "$")
room("reedwater_bank", "Reedwater Bank", ["combat"], c)

c = Canvas(STANDARD).corners(2)
c.hline(c.cy, 0, 4).hline(c.cy, c.w - 5, c.w - 1).vline(c.cx, 0, 1).vline(c.cx, c.h - 2, c.h - 1)
c.oval(c.cx, c.cy, 7, 4, "m")
c.put(c.cx, c.cy - 4, "=").put(c.cx, c.cy + 4, "=").put(c.cx - 7, c.cy, "=").put(c.cx + 7, c.cy, "=")
c.put(c.cx, c.cy, "E").puts([(c.cx - 3, c.cy - 2), (c.cx + 3, c.cy - 2), (c.cx - 3, c.cy + 2), (c.cx + 3, c.cy + 2), (3, 2), (21, 2), (3, 10), (21, 10)], "e")
c.puts([(6, 1), (18, 11)], "b").put(c.cx, c.cy + 2, "$")
room("fairy_ring", "Fairy Ring", ["combat", "elite"], c)

c = Canvas(STANDARD).corners(2)
c.rect(5, 2, 19, 10, "c").rect(7, 4, 17, 8, ".").ring(7, 4, 17, 8, "c")
c.hline(c.cy, 0, 4).hline(c.cy, 20, c.w - 1).vline(c.cx, 0, 1).vline(c.cx, 11, c.h - 1)
c.puts([(6, 3), (18, 3), (6, 9), (18, 9)], "R")
c.put(c.cx, c.cy, "E").puts([(9, 5), (15, 5), (9, 7), (15, 7), (2, 2), (22, 2), (2, 10), (22, 10)], "e")
c.puts([(3, 4), (21, 8)], "r").puts([(10, 11), (14, 1)], "p")
room("fallen_shrine", "Fallen Shrine", ["combat", "elite"], c)

c = Canvas(STANDARD)
c.cross()
for x0, y0 in [(2, 1), (15, 1), (2, 8), (15, 8)]: c.rect(x0, y0, x0 + 7, y0 + 3, "#")
c.rect(5, 2, 6, 3, "#")
c.puts([(1, 0), (23, 0), (1, 12), (23, 12), (6, 5), (18, 5), (6, 7), (18, 7), (11, 3), (13, 9)], "e")
c.put(c.cx, c.cy, "$")
room("bramble_lanes", "Bramble Lanes", ["combat"], c)

c = Canvas(STANDARD).corners(2)
c.cross()
for cx, cy in [(5, 3), (19, 3), (5, 9), (19, 9)]: c.blob(cx, cy, 3.4, 1.9, "~")
c.puts([(10, 2), (14, 4), (10, 10), (14, 8), (2, 6), (22, 6), (8, 6), (16, 6)], "e")
c.put(c.cx, c.cy, "$").puts([(11, 11), (13, 1)], "m")
room("twin_pools", "Twin Pools", ["combat"], c)

c = Canvas(STANDARD).corners(3)
c.hline(c.cy, 0, 6).hline(c.cy, 18, c.w - 1).vline(c.cx, 0, 2).vline(c.cx, 10, c.h - 1)
c.puts([(4, 3), (9, 2), (16, 3), (20, 4), (7, 9), (12, 6), (17, 9), (21, 10), (3, 10), (14, 11)], "T")
c.puts([(6, 5), (10, 4), (15, 5), (19, 7), (9, 8), (13, 9), (5, 7), (18, 2)], "e")
c.puts([(11, 1), (2, 6)], "m").puts([(22, 5)], "r").put(16, 7, "$")
room("fallen_giants", "Fallen Giants", ["combat"], c)

c = Canvas(STANDARD).corners(2)
c.cross()
c.puts([(4, 2), (8, 4), (16, 2), (20, 4), (3, 8), (9, 10), (15, 9), (21, 8), (6, 6), (18, 6), (12, 3), (12, 9)], "R")
c.puts([(2, 4), (10, 2), (14, 4), (22, 2), (2, 10), (10, 8), (14, 10), (22, 10)], "e")
c.put(c.cx, c.cy, "C").puts([(5, 11), (19, 1)], "p")
room("stone_scatter", "Stone Scatter", ["combat"], c)

c = Canvas(STANDARD)
c.rect(15, 0, 16, c.h - 1, "~")
c.hline(3, 14, 17, "c").hline(9, 14, 17, "c")
c.vline(c.cx, 0, 3).hline(3, 0, 14).hline(c.cy, 0, 12).vline(c.cx, c.cy, c.h - 1).hline(9, c.cx, 14).hline(3, 17, 20).vline(20, 3, c.cy).hline(c.cy, 20, c.w - 1)
c.puts([(4, 1), (8, 10), (3, 9), (19, 1), (22, 9), (19, 11), (10, 5), (22, 4)], "e")
c.puts([(13, 11), (18, 6)], "R").puts([(14, 1), (17, 11)], "r").puts([(5, 5), (9, 11)], "m").put(22, 11, "$")
room("winding_brook", "Winding Brook", ["combat"], c)

c = Canvas(LARGE)
c.blob(c.cx, c.cy, 10.5, 5.5, "~")
c.ring(4, 1, c.w - 5, c.h - 2, "=").hline(c.cy, 0, 4).hline(c.cy, c.w - 5, c.w - 1).vline(c.cx, 0, 1).vline(c.cx, c.h - 2, c.h - 1)
c.puts([(2, 2), (30, 2), (2, 14), (30, 14), (8, 3), (24, 3), (8, 13), (24, 13), (5, 8), (27, 8)], "e")
c.puts([(2, 8), (30, 5), (6, 15)], "r").puts([(28, 11), (10, 1)], "m").puts([(16, 15)], "$")
room("great_mere", "Great Mere", ["combat"], c, weight=0.7)

c = Canvas(LARGE).corners(3)
c.cross()
for cx, cy in [(8, 4), (24, 4), (8, 12), (24, 12)]: c.oval(cx, cy, 4, 2, "T", 16)
c.puts([(8, 4), (24, 4), (8, 12), (24, 12)], "$")
c.puts([(4, 2), (12, 3), (20, 3), (28, 2), (4, 14), (12, 13), (20, 13), (28, 14), (16, 4), (16, 12), (4, 8), (28, 8)], "e")
c.puts([(14, 7), (18, 9), (2, 5)], "m").puts([(30, 11)], "r")
room("old_grove", "Old Grove", ["combat", "elite"], c, weight=0.7)

# ---------------------------------------------------------------- specialist rooms (no enemies)

c = Canvas(STANDARD).corners(3)
c.cross()
c.rect(8, 3, 16, 9, "c").rect(9, 4, 15, 8, ".").put(c.cx, c.cy - 3, "=").put(c.cx, c.cy + 3, "=").put(c.cx - 4, c.cy, "=").put(c.cx + 4, c.cy, "=")
c.put(c.cx, c.cy, "*").puts([(10, 5), (14, 5), (10, 7), (14, 7)], "m")
c.puts([(4, 3), (20, 9), (5, 10), (19, 2)], "b").puts([(3, 6), (21, 6)], "r")
room("sunlit_hollow", "Sunlit Hollow", ["treasure"], c)

c = Canvas(STANDARD).corners(3)
c.cross()
c.put(9, 4, "F").put(c.cx, 4, "M").puts([(7, 3), (11, 3), (8, 5), (10, 5)], "r")
c.puts([(15, 3), (18, 4), (16, 9), (6, 9), (20, 8)], "p").puts([(4, 2), (20, 2), (4, 10), (20, 10)], "b").puts([(14, 10), (9, 11)], "m")
room("wayfarers_camp", "Wayfarer's Camp", ["shop"], c)

c = Canvas(STANDARD).corners(4)
c.hline(c.cy, 0, 8).hline(c.cy, 16, c.w - 1).vline(c.cx, 0, 3).vline(c.cx, 9, c.h - 1)
c.oval(c.cx, c.cy, 4, 2.4, "c", 32).put(c.cx, c.cy, "F")
c.puts([(c.cx - 2, c.cy - 1), (c.cx + 2, c.cy + 1)], "r").puts([(6, 3), (18, 9), (7, 10), (17, 2)], "m").puts([(4, 5), (20, 7)], "b")
room("ember_clearing", "Emberlight Clearing", ["rest"], c)

c = Canvas(STANDARD).corners(2)
c.blob(19, 9, 3.6, 2.2, "~")
c.cross()
c.put(8, 4, "F").puts([(6, 3), (10, 3), (6, 5), (10, 5)], "R").puts([(15, 3), (17, 4), (5, 9), (9, 10)], "p").puts([(3, 2), (21, 2), (3, 10)], "b").puts([(14, 9), (11, 1)], "m")
room("woodcutters_rest", "Woodcutter's Rest", ["rest"], c)

# ---------------------------------------------------------------- elite and gate rooms

c = Canvas(STANDARD)
c.ring(2, 1, c.w - 3, c.h - 2, "c").hline(c.cy, 0, c.w - 1, "c").vline(c.cx, 0, c.h - 1, "c")
c.puts([(1, 0), (23, 0), (1, 12), (23, 12), (6, 4), (18, 4), (6, 8), (18, 8)], "R")
c.put(c.cx, c.cy, "E").puts([(5, 3), (19, 3), (5, 9), (19, 9), (9, 6), (15, 6)], "e")
c.puts([(10, 2), (14, 10)], "r").put(c.cx, 2, "$")
room("briar_court", "Briar Court", ["elite"], c)

c = Canvas(STANDARD).corners(3)
c.ring(6, 3, 18, 9, "c").hline(c.cy, 0, 6).hline(c.cy, 18, c.w - 1).vline(c.cx, 0, 3).vline(c.cx, 9, c.h - 1)
c.put(c.cx, 1, "X").put(c.cx, c.cy, "E").puts([(9, 5), (15, 5), (9, 7), (15, 7), (3, 3), (21, 3), (3, 9), (21, 9)], "e")
c.puts([(4, 6), (20, 6)], "r").puts([(8, 11), (16, 11)], "m")
room("root_gate", "Root Gate", ["boss"], c)

c = Canvas(LARGE).corners(5)
c.oval(c.cx, c.cy, 9, 5.5, "c", 96).hline(c.cy, 0, 7).hline(c.cy, c.w - 8, c.w - 1).vline(c.cx, 0, 2).vline(c.cx, c.h - 3, c.h - 1)
c.put(c.cx, 1, "X").put(c.cx, c.cy, "E").puts([(c.cx - 3, c.cy - 2), (c.cx + 3, c.cy - 2), (c.cx - 3, c.cy + 2), (c.cx + 3, c.cy + 2)], "R")
c.puts([(10, 4), (22, 4), (10, 12), (22, 12), (5, 8), (27, 8), (16, 5), (16, 11)], "e")
c.puts([(4, 4), (28, 4), (4, 12), (28, 12)], "T").puts([(8, 15), (24, 1)], "m").puts([(26, 15)], "r")
room("druid_circle", "Druid's Circle", ["boss"], c, weight=0.8)


# ---------------------------------------------------------------- validation

BLOCKED = set("#~")
SOLID = set("RTC")
CAMP_ONLY = {"F": {"shop", "rest"}, "M": {"shop"}}

def validate(r):
    rows = r["map"]; errors = []; h = len(rows); w = len(rows[0])
    slots = {"N": (w // 2, 0), "S": (w // 2, h - 1), "W": (0, h // 2), "E": (w - 1, h // 2)}
    roles = set(r["roles"])
    for d, (x, y) in slots.items():
        if rows[y][x] != d: errors.append(f"{d} door slot holds '{rows[y][x]}'")
    def walk(start):
        seen = {start}; q = deque([start])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and rows[ny][nx] not in BLOCKED | SOLID:
                    seen.add((nx, ny)); q.append((nx, ny))
        return seen
    reach = walk(slots["N"])
    for d, cell in slots.items():
        if cell not in reach: errors.append(f"door {d} unreachable")
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            ch = rows[y][x]
            if ch in "eE$*MXPF" and (x, y) not in reach and ch != "F": errors.append(f"marker {ch} at {x},{y} unreachable")
            if ch in CAMP_ONLY and not roles <= CAMP_ONLY[ch]: errors.append(f"{ch} only belongs in {sorted(CAMP_ONLY[ch])} rooms")
            if ch in "eE" and roles & {"shop", "rest", "treasure", "start"}: errors.append(f"enemy marker in a peaceful room at {x},{y}")
    if "rest" in roles and not any("F" in row for row in rows): errors.append("rest room needs a campfire F")
    if "shop" in roles and not any("M" in row for row in rows): errors.append("shop room needs a merchant M")
    if "boss" in roles and not any("X" in row for row in rows): errors.append("boss room needs an X gate")
    if "treasure" in roles and not any("*" in row for row in rows): errors.append("treasure room needs a * pedestal")
    return errors

if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    target = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "..", "data", "forest_rooms.json")
    bad = False
    for r in ROOMS:
        errs = validate(r)
        if errs: bad = True; print(r["id"], *errs, sep="\n  ")
    if bad: sys.exit(1)
    out = {
        "schema_version": 2,
        "notes": "Hand-authored Verdant Forest rooms, drawn by tools/forest_rooms/build_forest_rooms.py. Each map is a grid of 48px cells. Door slots sit on the centre cell of each edge; slots without a neighbouring room are sealed with thicket at runtime. Sizes must be odd. Roles: start, combat, elite, treasure, shop, rest, boss (boss rooms hold the descent gate X). Campfires and merchants only appear in the enemy-free shop and rest rooms.",
        "legend": LEGEND,
        "rooms": ROOMS,
    }
    with open(target, "w") as handle: json.dump(out, handle, indent=1, ensure_ascii=False)
    print(f"{len(ROOMS)} rooms written to {os.path.normpath(target)}")
    for r in ROOMS: print(f"  {r['id']:<18} {len(r['map'][0])}x{len(r['map'])}  {','.join(r['roles'])}")
