"""Designs the Stone Crypt's starting rooms as text maps and writes
tools/maps/crypt_rooms.json, which tools/maps/build_crypt_rooms.gd turns into
painted room scenes in maps/crypt/rooms/.

Crypt rooms are 1.5x the forest's: standard 41x23 (forest 27x15) and large
53x29 (forest 35x19).

Legend (same as the forest's room maps):
  #  wall              .  floor            ~  pit (blocks movement)
  c  carpet (floor)    N S E W  doors (centre of each edge)
  e  enemy spawn       E  elite/boss spawn  $  loot cache
  *  relic pedestal    M  merchant          X  stairs down (gate)
  P  start             F  campfire/brazier  C  locked chest
  R  rubble (breakable) T  coffin (breakable, may hide a chest)
  r  rubble decor      p  bone pile decor   m  candles decor
  b  urn / tombstone decor                  O  colossus body (guardian rooms)

Run from deep/:  python3 tools/maps/crypt_room_designs.py
Only used to make the first set of rooms. Once the artist edits the scenes,
don't re-run the builder: it overwrites rooms with the same id.
"""
import json
from collections import deque

STANDARD = (41, 23)
LARGE = (53, 29)


class Room:
    def __init__(self, room_id, name, roles, size=STANDARD, weight=1.0):
        self.id, self.name, self.roles, self.weight = room_id, name, roles, weight
        self.w, self.h = size
        self.g = [["." for _ in range(self.w)] for _ in range(self.h)]
        for x in range(self.w):
            self.g[0][x] = "#"; self.g[self.h - 1][x] = "#"
        for y in range(self.h):
            self.g[y][0] = "#"; self.g[y][self.w - 1] = "#"
        cx, cy = self.w // 2, self.h // 2
        self.g[0][cx] = "N"; self.g[self.h - 1][cx] = "S"; self.g[cy][0] = "W"; self.g[cy][self.w - 1] = "E"

    @property
    def cx(self): return self.w // 2

    @property
    def cy(self): return self.h // 2

    def put(self, x, y, symbol):
        if 0 < x < self.w - 1 and 0 < y < self.h - 1: self.g[y][x] = symbol

    def rect(self, x, y, w, h, symbol):
        for yy in range(y, y + h):
            for xx in range(x, x + w): self.put(xx, yy, symbol)

    def mirror4(self, x, y, symbol):
        """Put symbol at (x,y) and its mirrors across both centre lines."""
        for xx in (x, self.w - 1 - x):
            for yy in (y, self.h - 1 - y): self.put(xx, yy, symbol)

    def mirror4_rect(self, x, y, w, h, symbol):
        for yy in range(y, y + h):
            for xx in range(x, x + w): self.mirror4(xx, yy, symbol)

    def carpet_cross(self):
        for x in range(1, self.w - 1):
            if self.g[self.cy][x] == ".": self.g[self.cy][x] = "c"
        for y in range(1, self.h - 1):
            if self.g[y][self.cx] == ".": self.g[y][self.cx] = "c"

    def entry(self):
        return {"id": self.id, "name": self.name, "roles": self.roles, "weight": self.weight, "map": ["".join(r) for r in self.g]}


# ------------------------------------------------------------------ checks

def check(room):
    rows = room.entry()["map"]; w, h = room.w, room.h
    blocked = set("#~RTCF")
    doors = {"N": (w // 2, 0), "S": (w // 2, h - 1), "W": (0, h // 2), "E": (w - 1, h // 2)}
    start = doors["N"]
    seen = {start}; q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and rows[ny][nx] not in blocked:
                seen.add((nx, ny)); q.append((nx, ny))
    errors = []
    for name, cell in doors.items():
        if cell not in seen: errors.append("door %s unreachable" % name)
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if rows[y][x] in "eE$*MXP" and (x, y) not in seen: errors.append("marker %s at %d,%d unreachable" % (rows[y][x], x, y))
    # Big things that must have space next to them.
    for y in range(h):
        for x in range(w):
            if rows[y][x] in "MF*X":
                if not any((x + dx, y + dy) in seen for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))): errors.append("%s at %d,%d boxed in" % (rows[y][x], x, y))
    roles = room.roles
    flat = "".join(row[1:-1] for row in rows[1:-1])  # inside the walls (door letters excluded)
    need = {"boss": "X", "treasure": "*", "shop": "M", "rest": "F", "guardian": "O", "start": "P"}
    for role, symbol in need.items():
        if role in roles and symbol not in flat: errors.append("%s room missing %s" % (role, symbol))
    if any(r in roles for r in ("start", "treasure", "shop", "rest")) and ("e" in flat or "E" in flat): errors.append("peaceful room has enemies")
    if "combat" in roles and flat.count("e") < 6: errors.append("combat room needs more enemy spawns")
    return errors


# ------------------------------------------------------------------ rooms

rooms = []

# --- start ---------------------------------------------------------------
r = Room("crypt_antechamber", "Crypt Antechamber", ["start"])
r.carpet_cross()
r.mirror4_rect(8, 4, 2, 2, "#"); r.mirror4_rect(14, 4, 2, 2, "#")
r.mirror4(4, 3, "m"); r.mirror4(17, 8, "b"); r.mirror4(6, 9, "p")
r.put(r.cx, r.cy, "P"); r.put(r.cx + 3, r.cy + 3, "$")
rooms.append(r)

r = Room("sealed_vestibule", "Sealed Vestibule", ["start"], weight=0.8)
r.rect(5, 3, 31, 1, "#"); r.rect(5, 19, 31, 1, "#")
for x in (r.cx - 1, r.cx, r.cx + 1): r.put(x, 3, "."); r.put(x, 19, ".")
r.mirror4(7, 6, "b"); r.mirror4(13, 6, "b"); r.mirror4(3, 9, "m")
r.carpet_cross(); r.put(r.cx, r.cy, "P")
rooms.append(r)

# --- combat --------------------------------------------------------------
r = Room("pillared_hall", "Pillared Hall", ["combat"])
for px in (6, 12, 18):
    for py in (5,):
        r.mirror4_rect(px, py, 2, 2, "#")
r.carpet_cross()
r.mirror4(3, 3, "m"); r.mirror4(9, 9, "p")
for x, y in ((4, 4), (36, 4), (4, 18), (36, 18), (10, 11), (30, 11), (20, 5), (20, 17), (15, 8), (25, 14)): r.put(x, y, "e")
r.put(r.cx, r.cy, "$")
rooms.append(r)

r = Room("ossuary_rows", "Ossuary Rows", ["combat"])
for y in (4, 8, 14, 18):
    for x in list(range(4, 16, 3)) + list(range(26, 38, 3)):
        r.put(x, y, "T" if (x + y) % 2 else "b")
r.mirror4(17, 3, "p"); r.mirror4(10, 11, "r")
for x, y in ((6, 6), (34, 6), (6, 16), (34, 16), (13, 11), (27, 11), (20, 6), (20, 16), (9, 2), (31, 20)): r.put(x, y, "e")
r.put(r.cx, r.cy, "$")
rooms.append(r)

r = Room("sunken_floor", "Sunken Floor", ["combat"])
r.rect(9, 5, 23, 13, "~")
r.rect(9, r.cy - 1, 23, 3, "c"); r.rect(r.cx - 1, 5, 3, 13, "c")
r.mirror4(5, 3, "m"); r.mirror4(5, 8, "p")
for x, y in ((4, 4), (36, 4), (4, 18), (36, 18), (12, 11), (28, 11), (20, 7), (20, 15), (20, 2), (20, 20)): r.put(x, y, "e")
r.put(r.cx, r.cy, "$")
rooms.append(r)

r = Room("twin_pits", "Twin Pits", ["combat", "elite"])
r.rect(6, 5, 9, 13, "~"); r.rect(26, 5, 9, 13, "~")
r.rect(6, r.cy, 9, 1, "c"); r.rect(26, r.cy, 9, 1, "c")
r.mirror4(18, 4, "R"); r.mirror4(3, 3, "m"); r.mirror4(17, 9, "p")
for x, y in ((3, 6), (37, 6), (3, 16), (37, 16), (20, 6), (20, 16), (10, 3), (30, 19), (10, 19), (30, 3)): r.put(x, y, "e")
r.put(r.cx, r.cy, "E"); r.put(r.cx, r.cy + 4, "$")
rooms.append(r)

r = Room("broken_chapel", "Broken Chapel", ["combat"])
for x, y, w, h in ((6, 4, 6, 1), (6, 4, 1, 4), (29, 4, 6, 1), (34, 4, 1, 4), (6, 18, 6, 1), (6, 15, 1, 4), (29, 18, 6, 1), (34, 15, 1, 4)): r.rect(x, y, w, h, "#")
r.rect(r.cx - 3, 3, 7, 1, "c")
r.mirror4(15, 7, "R"); r.mirror4(10, 10, "r"); r.mirror4(17, 4, "b"); r.put(r.cx, 2, "m")
for x, y in ((9, 7), (31, 7), (9, 15), (31, 15), (20, 6), (20, 16), (14, 11), (26, 11), (3, 3), (37, 19)): r.put(x, y, "e")
r.put(r.cx, r.cy, "$")
rooms.append(r)

r = Room("catacomb_maze", "Catacomb Maze", ["combat"], weight=0.8)
for x in (8, 16, 24, 32):
    top = 2 if x in (8, 24) else 6
    r.rect(x, top, 1, 15, "#")
for x in (8, 16, 24, 32): r.put(x, r.cy, ".")
r.rect(1, r.cy, 39, 1, "c")
r.mirror4(4, 3, "p"); r.mirror4(12, 5, "T"); r.mirror4(20, 8, "m")
for x, y in ((4, 6), (12, 3), (20, 4), (28, 6), (36, 4), (4, 17), (12, 19), (20, 18), (28, 16), (36, 18)): r.put(x, y, "e")
r.put(12, r.cy - 2, "$")
rooms.append(r)

r = Room("ring_gallery", "Ring Gallery", ["combat", "elite"])
r.rect(16, 9, 9, 5, "#")
for x in (15, 25):
    for y in (9, 11, 13): r.put(x, y, "T")
r.mirror4(6, 4, "#"); r.mirror4(6, 5, "#"); r.mirror4(7, 4, "#"); r.mirror4(7, 5, "#")
r.mirror4(11, 3, "m"); r.mirror4(3, 9, "p"); r.mirror4(11, 9, "b")
for x, y in ((4, 3), (36, 3), (4, 19), (36, 19), (10, 11), (30, 11), (20, 4), (20, 18), (14, 4), (26, 18)): r.put(x, y, "e")
r.put(r.cx, 4, "E"); r.put(r.cx, 18, "$")
rooms.append(r)

r = Room("collapsed_nave", "Collapsed Nave", ["combat"])
for i in range(6):
    r.put(8 + i, 5 + i, "~"); r.put(9 + i, 5 + i, "~")
    r.put(32 - i, 17 - i, "~"); r.put(31 - i, 17 - i, "~")
for x, y in ((18, 4), (22, 18), (6, 15), (34, 7), (25, 9), (15, 13)): r.put(x, y, "R")
r.mirror4(4, 3, "r"); r.mirror4(12, 2, "p"); r.mirror4(16, 9, "r")
for x, y in ((4, 6), (36, 16), (4, 18), (36, 4), (20, 7), (20, 15), (12, 17), (28, 5), (16, 11), (24, 11)): r.put(x, y, "e")
r.put(r.cx, r.cy, "$")
rooms.append(r)

r = Room("bone_choir", "Bone Choir", ["combat", "elite"])
for y in range(4, 19, 2):
    for x in (5, 9, 31, 35): r.put(x, y, "b" if y % 4 else "p")
r.rect(r.cx - 4, 4, 9, 2, "#"); r.rect(r.cx - 1, 6, 3, 1, "c")
r.rect(r.cx - 1, 7, 3, 15, "c")
r.mirror4(14, 3, "m")
for x, y in ((7, 6), (33, 6), (7, 16), (33, 16), (14, 9), (26, 9), (14, 15), (26, 15), (20, 19), (3, 11)): r.put(x, y, "e")
r.put(r.cx, 8, "E"); r.put(r.cx, 15, "$")
rooms.append(r)

r = Room("great_ossuary", "Great Ossuary", ["combat"], size=LARGE, weight=0.6)
for px in (8, 16, 24):
    for py in (6,):
        r.mirror4_rect(px, py, 2, 2, "#")
r.rect(18, 11, 17, 7, "~"); r.rect(18, r.cy, 17, 1, "c"); r.rect(r.cx, 11, 1, 7, "c")
r.mirror4(4, 3, "m"); r.mirror4(12, 11, "T"); r.mirror4(20, 4, "p"); r.mirror4(5, 10, "b")
for x, y in ((4, 5), (48, 5), (4, 23), (48, 23), (12, 14), (40, 14), (26, 5), (26, 23), (14, 3), (38, 25), (20, 9), (32, 19)): r.put(x, y, "e")
r.put(r.cx, 8, "$")
rooms.append(r)

# --- elite -----------------------------------------------------------------
r = Room("warden_hall", "Warden's Hall", ["elite"])
r.mirror4_rect(10, 5, 2, 2, "#"); r.mirror4_rect(10, 9, 1, 1, "R")
r.carpet_cross(); r.mirror4(4, 3, "m"); r.mirror4(16, 4, "b")
for x, y in ((5, 6), (35, 6), (5, 16), (35, 16), (20, 4), (20, 18), (14, 11), (26, 11)): r.put(x, y, "e")
r.put(r.cx, r.cy, "E"); r.put(r.cx + 4, r.cy, "$")
rooms.append(r)

# --- treasure ----------------------------------------------------------------
r = Room("reliquary", "Reliquary", ["treasure"])
r.rect(r.cx - 4, r.cy - 3, 9, 7, "c")
r.mirror4_rect(14, 6, 1, 1, "#"); r.mirror4(16, 8, "m")
r.mirror4(5, 4, "b"); r.mirror4(5, 8, "p")
r.put(r.cx, r.cy, "*")
rooms.append(r)

r = Room("sealed_vault", "Sealed Vault", ["treasure"], weight=0.7)
r.rect(10, 6, 21, 1, "#"); r.rect(10, 16, 21, 1, "#"); r.rect(10, 6, 1, 11, "#"); r.rect(30, 6, 1, 11, "#")
r.put(r.cx, 6, "."); r.put(r.cx, 16, ".")
r.rect(11, 7, 19, 9, "c")
r.mirror4(13, 8, "m"); r.put(r.cx, r.cy, "*"); r.mirror4(4, 3, "p"); r.put(r.cx + 6, r.cy, "C")
rooms.append(r)

# --- shop ----------------------------------------------------------------
r = Room("undercroft_camp", "Undercroft Camp", ["shop"])
r.rect(r.cx - 6, r.cy - 3, 13, 7, "c")
r.put(r.cx, r.cy - 1, "M"); r.put(r.cx - 4, r.cy + 1, "F")
r.mirror4(6, 4, "b"); r.mirror4(12, 4, "m"); r.mirror4(4, 9, "p")
r.put(r.cx + 4, r.cy + 2, "$")
rooms.append(r)

# --- rest ----------------------------------------------------------------
r = Room("candle_shrine", "Candle Shrine", ["rest"])
r.rect(r.cx - 3, r.cy - 2, 7, 5, "c")
r.put(r.cx, r.cy, "F")
for x, y in ((r.cx - 5, r.cy - 3), (r.cx + 5, r.cy - 3), (r.cx - 5, r.cy + 3), (r.cx + 5, r.cy + 3)): r.put(x, y, "m")
r.mirror4(5, 4, "b"); r.mirror4(10, 8, "p")
rooms.append(r)

# --- boss (gate room on ordinary floors) -------------------------------------
r = Room("stairwell", "The Stairwell", ["boss"])
r.rect(r.cx - 2, 3, 5, 3, "c"); r.put(r.cx, 4, "X")
r.mirror4_rect(9, 5, 2, 2, "#"); r.mirror4(14, 9, "R")
r.carpet_cross()
r.mirror4(4, 3, "m"); r.mirror4(16, 3, "b")
for x, y in ((6, 9), (34, 9), (6, 15), (34, 15), (14, 18), (26, 18)): r.put(x, y, "e")
r.put(r.cx, r.cy + 2, "E")
rooms.append(r)

r = Room("royal_tomb", "Royal Tomb", ["boss"], size=LARGE, weight=0.7)
r.rect(r.cx - 3, 3, 7, 4, "c"); r.put(r.cx, 4, "X")
r.mirror4_rect(8, 6, 2, 2, "#"); r.mirror4_rect(17, 6, 2, 2, "#")
r.mirror4(13, 11, "T"); r.mirror4(5, 3, "m"); r.mirror4(22, 4, "b")
r.carpet_cross()
for x, y in ((6, 12), (46, 12), (6, 18), (46, 18), (16, 24), (36, 24), (20, 14), (32, 14)): r.put(x, y, "e")
r.put(r.cx, r.cy + 2, "E")
rooms.append(r)

# --- guardian arena (the crypt's colossus) -----------------------------------
r = Room("charnel_throne", "The Charnel Throne", ["guardian"], size=LARGE)
r.put(r.cx, 9, "O")
r.rect(r.cx - 2, 2, 5, 2, "c"); r.put(r.cx, 2, "X")
# Pillars to dodge behind, well clear of the body (7x5 around the O).
r.mirror4_rect(7, 6, 2, 2, "#"); r.mirror4_rect(14, 10, 2, 2, "#")
r.mirror4(4, 3, "m"); r.mirror4(10, 12, "p"); r.mirror4(20, 4, "b")
r.put(r.cx, 22, "P")
rooms.append(r)


if __name__ == "__main__":
    problems = False
    for room in rooms:
        for error in check(room):
            print("%s: %s" % (room.id, error)); problems = True
    roles = set(role for room in rooms for role in room.roles)
    for role in ("start", "combat", "elite", "treasure", "shop", "rest", "boss", "guardian"):
        if role not in roles: print("no room for role", role); problems = True
    with open("tools/maps/crypt_rooms.json", "w") as handle:
        json.dump({"rooms": [room.entry() for room in rooms]}, handle, indent=1)
    print("%d crypt rooms written%s" % (len(rooms), " (with problems)" if problems else ""))
    for room in rooms[:2] + [rooms[-1]]:
        print(room.id); print("\n".join(room.entry()["map"]))
