# Maps and tiles: where to edit what

The game has three kinds of maps, and they are edited in different ways.

| What you see | How it is made | Where to edit |
| --- | --- | --- |
| **Forest rooms** (the dungeon you play now) | Text maps turned into sprites by code | `tools/forest_rooms/build_forest_rooms.py` → `data/forest_rooms.json` |
| **Forest ground art** (grass, dirt, water, cobbles) | Squares cut from one sprite sheet by code | `scripts/slasher/slasher_forest_terrain_art.gd` + `assets/pixel_art/forest_art/forest tiles.png` |
| **Tavern floor** | A real Godot TileMap | `scenes/tavern/taverntiles.tscn` (paint in the Godot editor) |

Older TileMap scenes are still in the project but are not used by forest rooms:
`scenes/slasher/templates/ForestBranchingTemplate.tscn` (tutorial and merchant
floors), `scenes/scenes/maps/StarterMap.tscn` (old starter map) and
`scenes/slasher/tools/WallGenerationLab.tscn` (a wall tool).

---

## 1. Forest rooms: edit or add a room

Forest rooms are **not** Godot TileMaps, so you can't paint them in the editor.
Each room is a small text grid where every character is one 48px cell.

### Quick edit (JSON)

Open `data/forest_rooms.json`, find the room by its `id`, and change characters
in its `map`. Keep the border intact: `#` everywhere on the edge except the
door letters `N`, `S`, `W`, `E` in the middle of each side.

```json
{"id":"my_room","name":"Mushroom Hollow","roles":["combat"],"weight":1.0,"map":[
"#############N#############",
"#.........................#",
"#..m....e.........e....m..#",
"#.........======..........#",
"W.....R...=....=...R......E",
"#.........======..........#",
"#..e...............e......#",
"#.........................#",
"#############S#############"]}
```

### Better for new rooms (Python builder)

`tools/forest_rooms/build_forest_rooms.py` draws rooms with helpers so you don't
type every cell, then rewrites the JSON. To add a room, copy one of the existing
blocks:

```python
c = Canvas(STANDARD).corners(2)          # 27x15 room; LARGE is 35x19
c.cross()                                # dirt trails joining all four doors
c.blob(19, 3, 3.2, 1.8, "~")            # a pond (x, y, width, height)
c.puts([(4, 3), (20, 9)], "e")           # enemy spawns
c.puts([(6, 10), (18, 4)], "m")          # mushrooms
c.put(c.cx, c.cy, "$")                   # loot cache in the centre
room("mushroom_hollow", "Mushroom Hollow", ["combat"], c)
```

Helpers: `cross`, `hline`, `vline`, `rect`, `ring`, `blob`, `oval`, `corners`,
`put`, `puts`. Then run, from the `deep/` folder:

```
python3 tools/forest_rooms/build_forest_rooms.py
```

It refuses to write a room that is broken (unreachable doors, missing markers).
Then run the room test in Godot:
`godot --headless --path . --script tests/forest_rooms_test.gd`.

### Symbols

`#` thicket wall · `.` grass · `=` dirt trail · `c` cobblestone · `~` water ·
`R` breakable rock · `T` big tree · `C` locked chest · `r` mossy rock · `p` pebbles ·
`m` mushrooms · `b` bush · `F` campfire (camps only) · `e` enemy spawn ·
`E` elite/boss spawn · `$` loot cache · `*` treasure pedestal · `M` merchant ·
`X` gate to the next floor · `P` player start.

**Roles** decide where a room can appear: `start`, `combat`, `elite`, `treasure`,
`shop`, `rest`, `boss`. Full rules are in `docs/ForestRooms.md`.

---

## 2. Forest ground art: change or add tiles

All ground art comes from `assets/pixel_art/forest_art/forest tiles.png`
(576×256). `scripts/slasher/slasher_forest_terrain_art.gd` lists which pixel
rectangle on that sheet is used for what:

| Constant | Sheet rectangle | Used for |
| --- | --- | --- |
| `GRASS_VARIANTS` | nine 32×32 cuts inside the grass patch (x 192–256, y 64–128) | grass, picked per cell so it doesn't repeat |
| `WATER_REGION` / `WATER_EDGE_REGION` | (352,200) / (320,165) | water, and its top edge |
| `COBBLE_REGION` | (64,200) | cobblestone |
| `dirt_region()` | the path block at x 400–560, y 16–112 | dirt trail pieces, 16×16, chosen by which neighbours are also dirt |
| `make_decoration()` | rocks, pebbles, mushrooms | decorations |

**To change a tile:** edit its rectangle. To find coordinates, open the PNG in
any image editor and read the pixel position of the top-left corner, or select a
Sprite2D in Godot, set its texture to the sheet, turn on **Region** and use the
region editor.

**To add more grass variety:** paint more grass onto the sheet (or a new sheet)
and add the top-left corner of each 32×32 square to `GRASS_VARIANTS`. Keep cuts
fully inside solid grass, away from the lighter fringe, or seams show where
tiles meet. A cut on the same 16-pixel rhythm as the existing ones joins without
seams.

**To add a new ground type** (say, `s` for sand):
1. Add the art to the sheet and a `SAND_REGION` constant in `slasher_forest_terrain_art.gd`.
2. Have `ForestRoomLibrary.build_layout()` (`scripts/slasher/forest_room_library.gd`)
   collect `s` cells into the layout, the same way it does `c` for cobbles.
3. Draw them in `build_room_ground()` like the cobble branch.
4. Add `s` to the `LEGEND` in the builder script and to `docs/ForestRooms.md`.

Trees for the thicket and the larger props come from `scripts/slasher/slasher_forest_art.gd`.

---

## 3. The tavern floor: a real TileMap

`scenes/tavern/taverntiles.tscn` holds a `TileMapLayer` whose TileSet uses
`assets/pixel_art/Tavern Floor Revised.png`. The image has eight floor styles,
each a 4×2 block of 32px tiles:

| `fill_variant` | Style |
| --- | --- |
| (0,0) | vertical planks |
| (4,0) | horizontal planks (**current**) |
| (0,2) | parquet squares |
| (4,2) | diagonal boards |
| (0,4) | warm flagstones |
| (4,4) | grey stone blocks |
| (0,6) | grey tiles |
| (4,6) | warm flagstones, larger |

**Swap the whole floor:** open `taverntiles.tscn`, select the root node and change
**Fill Variant** in the Inspector to one of the corners above. The floor is
filled with the whole 4×2 pattern, not a single tile.

**Paint it by hand:** select the `TileMapLayer` node, open the **TileMap** panel at
the bottom of the editor, pick tiles from the atlas and paint. If the layer has any
painted cells, the automatic fill is skipped, so your painting is kept. Use
**Clear** in the TileMap panel to go back to the automatic fill.

The Lodgings wing and Training Yard draw the same plank style in code
(`_tile_floor` in `scripts/scenes/tavern_expansions.gd`). Change the `Vector2(128,0)`
there to match if you change the hall's style.

---

## 4. Making a brand-new TileMap in Godot

For a new hand-painted map (a town, an interior, a special room):

1. **Create the node:** in a scene, add a `TileMapLayer` node.
2. **Make a TileSet:** in the Inspector, set **Tile Set → New TileSet**. Set
   **Tile Size** to your art's tile size (32×32 for the sheets here).
3. **Add the art:** open the **TileSet** panel at the bottom, drag your PNG into the
   left list and choose **Yes** to create tiles automatically.
4. **Collision (optional):** in the TileSet panel, add a **Physics Layer** in the
   Inspector, then in **Paint → Physics Layer 0** click tiles to make them solid.
5. **Paint:** switch to the **TileMap** panel, choose tiles and paint. Use several
   `TileMapLayer` nodes for ground, decoration and walls.
6. **Natural variety:** select several grass tiles in the atlas and enable the dice
   (**Place Random Tile**) in the paint toolbar, so each click picks one at random.
   Raise **Scattering** to leave gaps for decorations.
7. **Smart edges (autotiling):** in the TileSet's Inspector add a **Terrain Set**
   with a terrain such as "Dirt", then in **Paint → Terrains** mark which edges of
   each tile are dirt. In the TileMap panel's **Terrains** tab you can draw paths
   and Godot picks the right edge pieces.

Forest rooms don't load TileMap scenes yet. If you'd rather paint forest rooms in
the editor than type them, the room loader can be taught to read a TileMap scene
instead of a text map. It's a contained code change.
