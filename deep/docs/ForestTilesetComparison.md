# Forest tileset comparison

Open `scenes/slasher/tools/ForestTilesetComparison.tscn` in Godot and press **F6**.

This visual sample compares the previous forest grass against the new
`assets/pixel_art/forest_art/forest tiles.png` sheet on the same generated floor
(seed 83492791, floor 2). Both sides share the forest generator, boundary art,
tree placements, solid props, campfire, merchant and exit. The new side uses the
sheet's grass, connected dirt paths, mossy rocks and flowers. Source pixels use
nearest-neighbor filtering and the same 1.5× scale as the existing ground.
The shared campfire is fitted to 72 px for this comparison so it does not obscure
the terrain. The live dungeon retains its existing landmark scales.

- Drag to pan both views together; scroll to zoom.
- **1** shows existing art, **2** shows new art, **3** shows both.
- **R** restores the overview.

This is an art inspection scene with no combat. The new side shares its terrain
renderer with the live Forest dungeon, which now uses this sheet. The existing
side retains the previous TX grass for reference. Trails stay inside walkable
corridors; the terrain renderer does not change gameplay geometry. Other dungeon
themes and explicitly painted authored visuals retain their existing artwork.
Water and stone are left for a later experiment because the existing forest
generator does not include ponds or paved areas.

To regenerate the overview and close-up PNGs in `build/`, run Godot with
`--path . scenes/slasher/tools/ForestTilesetComparison.tscn -- --forest-capture`.
