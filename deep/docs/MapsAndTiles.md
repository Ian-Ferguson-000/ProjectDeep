# Maps and tiles: where to edit what

The game has three kinds of maps, and they are edited in different ways.

| What you see | How it is made | Where to edit |
| --- | --- | --- |
| **Dungeon rooms** (the forest today) | Painted Godot scenes, one per room | `maps/<dungeon>/rooms/`, guide in **`maps/README.md`** |
| **Room tiles** | TileSets per dungeon | `maps/<dungeon>/tiles/` |
| **Tavern floor** | A Godot TileMap | `scenes/tavern/taverntiles.tscn` |

Older TileMap scenes are still in the project but are not used by rooms:
`scenes/slasher/templates/*.tscn` (tutorial and merchant floors, and the
generated dungeons' authoring templates), `scenes/scenes/maps/StarterMap.tscn` and
`scenes/slasher/tools/WallGenerationLab.tscn`.

---

## 1. Dungeon rooms

See **`maps/README.md`**. In short: duplicate `maps/_templates/RoomTemplate.tscn`
into `maps/forest/rooms/`, set its name and roles in the Inspector, paint the
Ground, Terrain, Paths, Detail and Thicket layers, drop in markers, fix anything
the ⚠ warning lists, and press F6 to play it. The game picks up every scene in the
folder.

## 2. Code-drawn fallback ground

`scripts/slasher/slasher_forest_terrain_art.gd` still draws ground from
`assets/pixel_art/forest_art/forest tiles.png` for any room without a painted
scene, and for the older single-floor forest (tutorial, merchant interludes). It
picks one of nine grass cuts per cell (`GRASS_VARIANTS`).

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

For dungeon rooms, don't start from scratch: use `maps/_templates/RoomTemplate.tscn`, which already has the layers, TileSets and markers the game reads.
