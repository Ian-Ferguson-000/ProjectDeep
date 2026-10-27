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
   placed at the farthest dead end). The forest then turns one combat room partway
   along the route into a `rest` room.
   - **Camps are peaceful.** `start`, `treasure`, `shop` and `rest` rooms never spawn
     enemies.
   - **Campfires** appear only in the trader camp (`shop`) and campfire clearings
     (`rest`). Resting at a clearing's campfire restores 35% of the active hero's
     health, once per fire; the trader camp's fire is just for show.
   - **Merchants** appear only in the trader camp.
2. Each room picks a map from `maps/forest/rooms/` whose roles include its role.
   The pick is seeded by the floor, so a room keeps its map when you walk back in.
3. `ForestRoomLibrary.build_layout()` turns the map into a layout. Door slots facing a
   neighbouring room open; the rest are sealed with thicket.
4. `slasher_forest_rooms.gd` draws the room scene's painted layers and runs the room:
   - doors are barred by brambles until every foe in the room is down
   - in the gate room, killing the guardian (the boss, or the elite guardian on elite
     floors) ends the fight: its remaining pack scatters and the Root Gate opens
   - the way to the gate room is flagged like Isaac's boss door: a horned skull and a
     red glow over the door (a gate glyph on ordinary floors), labelled "Guardian" even
     while barred; the map shows the gate room with a skull once you're next to it; and
     walking in shows a banner naming the guardian
   - cleared rooms stay cleared
   - loot, broken props and opened chests are remembered for the rest of the floor

Floor size grows with depth: `forest.slasher.room_count` in `data/dungeons.json`
(`min`, `max`, `growth_per_floor`, `growth_cap`, `room_clear_gold`).

The tutorial expedition, merchant interludes, and the authored template scenes in
`scenes/slasher/templates/` still use the original single generated floor.

## Authoring a room

Rooms are painted Godot scenes in `maps/forest/rooms/`. **`maps/README.md` is the
artist's guide**: layers, markers, roles, the warning triangle and F6 playtesting.

Behind the scenes, `MapLibrary` reads each scene into a text map using the symbols
below. That is the format `ForestRoomLibrary` has always used, so its rules and
validation are unchanged. The 20 original rooms were converted from text maps by
`tools/maps/convert_forest_rooms.gd`; the old text is kept in
`tools/maps/legacy_forest_rooms.json` for reference.

| Symbol | Comes from |
|---|---|
| `#` | Thicket layer |
| `.` | anything walkable with no other meaning |
| `=` | Paths layer (a cell fully covered by dirt) |
| `c` / `~` | Terrain layer tiles with kind `cobble` / `water` |
| `N` `S` `W` `E` | the door cells at the middle of each edge |
| `e` `E` `$` `*` `M` `X` `P` `F` `C` `R` `T` `r` `p` `m` `b` | markers: enemy, elite, loot, treasure, merchant, gate, start, campfire, chest, rock, big tree, mossy rock, pebbles, mushrooms, bush |

Validation (`ForestRoomLibrary.validate_template`) checks that the edge is thicket
apart from the doors, every door and marker can be reached, camp-only markers are
in camp rooms, peaceful rooms have no spawns, and each role has its required
marker. `tests/forest_rooms_test.gd` also builds every map with all 15
combinations of open doors and walks a live floor.

## Toward procedural generation

`ForestRoomLibrary.build_layout(template, open_doors, seed)` only needs a dictionary
with a `map` grid. A future generator can produce rooms in the same format, or stitch
authored chunks together, and feed them straight in. Nothing else in the runtime needs
to change. The floor graph comes from `FieldDungeonGenerator.generate()`, the natural
place to add rules such as secret rooms or larger multi-cell rooms.
