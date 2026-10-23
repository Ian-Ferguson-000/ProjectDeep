# Verdant Forest rooms

The forest is a roguelike descent built from interconnected rooms, in the spirit of
The Binding of Isaac. Each floor is a fresh graph of hand-authored rooms; the party
moves between them through doors on the room edges, and the **Root Gate** room leads
down to the next floor. There is no end state: floors keep going, with the existing
elite and boss cadence (`forest.slasher.cycle_length` / `elite_floor_in_cycle`) and
endless depth.

## How a floor is built

1. `FieldDungeonGenerator` lays out a grid graph of rooms for the floor and assigns
   roles: `start`, `combat`, `elite`, `treasure`, `shop`, and `boss` (the gate room,
   placed at the farthest dead end).
2. Each room picks a map from `data/forest_rooms.json` whose `roles` include its role.
   The pick is seeded by the floor, so a room keeps its map when you walk back in.
3. `ForestRoomLibrary.build_layout()` turns the map into a layout. Door slots facing a
   neighbouring room open; the rest are sealed with thicket.
4. `slasher_forest_rooms.gd` renders it with the forest tile sheet and runs the room:
   - doors are barred by brambles until every foe in the room is down
   - cleared rooms stay cleared
   - loot, broken props and opened chests are remembered for the rest of the floor

Floor size grows with depth: `forest.slasher.room_count` in `data/dungeons.json`
(`min`, `max`, `growth_per_floor`, `growth_cap`, `room_clear_gold`).

The tutorial expedition, merchant interludes, and the authored template scenes in
`scenes/slasher/templates/` still use the original single generated floor.

## Authoring a room

Add an entry to `rooms` in `data/forest_rooms.json`:

```json
{"id":"my_room","name":"Display Name","roles":["combat"],"weight":1.0,"map":[
"#########N#########",
"#.......=.........#",
"...",
"#########S#########"]}
```

- **Size:** any odd width and height of at least 7. Standard rooms are 19×11, which
  fits the screen at default zoom. Large rooms such as Great Mere and Druid's Circle
  are 27×15, and the camera follows inside them.
- **Doors:** the centre cell of each edge must hold its door letter: `N` top, `S`
  bottom, `W` left, `E` right. Every other edge cell must be `#`.
- **Weight:** makes a map more or less common within its role (default 1.0).

| Symbol | Meaning |
|---|---|
| `#` | Thicket wall, drawn as dense trees |
| `.` | Grass |
| `=` | Dirt trail |
| `c` | Cobblestone ruin floor |
| `~` | Water (impassable) |
| `R` | Breakable rock |
| `T` | Large tree (breakable) |
| `C` | Locked chest (needs a key) |
| `r` | Mossy rock (decoration) |
| `p` | Pebbles (decoration) |
| `m` | Mushrooms (decoration) |
| `b` | Bush (decoration) |
| `F` | Campfire (decoration) |
| `e` | Enemy spawn point. More are used on deeper floors |
| `E` | Inside the room: elite or boss spawn point |
| `$` | Loot cache, which appears once the room is cleared |
| `*` | Treasure pedestal (relic choice) |
| `M` | Merchant |
| `X` | Root Gate down to the next floor |
| `P` | Player start (start rooms) |

**Roles:**
- Every role needs at least one room.
- `boss` rooms need an `X` gate.
- `treasure` rooms need a `*` pedestal.
- `shop` rooms need an `M` merchant.

**Validation:** `ForestRoomLibrary.validate()` checks all of this. It also checks
that every door reaches every other door and every marker without crossing water,
thicket or solid props. `tests/forest_rooms_test.gd` additionally builds every map
with all 15 combinations of open doors and walks a live floor.

## Toward procedural generation

`ForestRoomLibrary.build_layout(template, open_doors, seed)` only needs a dictionary
with a `map` grid. A future generator can produce rooms in the same format, or stitch
authored chunks together, and feed them straight in. Nothing else in the runtime needs
to change. The floor graph comes from `FieldDungeonGenerator.generate()`, the natural
place to add rules such as secret rooms or larger multi-cell rooms.
