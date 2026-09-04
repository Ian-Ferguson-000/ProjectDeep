# Slasher level-design templates

These scenes are hard-coded, playable examples of the room-and-corridor patterns used by the generated Slasher floors:

- `ForestBranchingTemplate.tscn`: a central clearing with an optional north branch before the exit route.
- `MineLoopTemplate.tscn`: two chambers connected by a loop and a center cross-link.
- `FoundryArenaTemplate.tscn`: a narrow onboarding lane feeding a large elite arena with flank pockets.
- `CryptGauntletTemplate.tscn`: a linear three-room combat gauntlet.

Open any template in Godot to see and edit the complete layout. Press **F6** to play the current scene using its `Designer Test` settings on the root node.

## Authoring contract

- Keep the root script for the dungeon presentation you want.
- Set `use_authored_layout` and `designer_playtest` on the root.
- Under `Geometry`, use axis-aligned `Polygon2D` rectangles. Their union becomes the walkable grid at runtime. Keep edges on the 48 px grid; overlapping regions are expected.
- Under `Markers`, keep the required `PlayerSpawn`, `Exit`, and `Merchant` `Node2D` nodes. Move their parent nodes, not the child icon.
- Enemy marker nodes use the `slasher_enemy_spawn` group. Optional metadata: `visual_id`, `behavior_id`, `is_boss`, and `is_mini_boss`.
- Loot marker nodes use `slasher_loot_spawn`.
- Breakable/chest marker nodes use `slasher_solid_prop` and `metadata/kind` (`rock`, `barrel`, `tree_large`, or `chest`).
- Decorative marker nodes may use `slasher_decoration` and `metadata/kind`.

The colored polygons and marker icons are authoring guides. When play starts, the slasher runtime reads them into its normal layout contract, removes the guides, and builds the themed floor, collisions, actors, loot, HUD, and camera.

## Painting tiles and placing exact props

Set `use_authored_visuals` on the scene root when the finished level art should come from editor nodes instead of runtime decoration.

- Put painted `TileMapLayer` nodes under `Geometry` for the simplest workflow. They are copied into the runtime ground layer before the authoring guides are removed.
- Alternatively, place a complete visual hierarchy under a top-level `AuthoredVisuals` `Node2D`. That hierarchy is retained as-is, including tile layers, sprites, particles, static bodies, and nested scenes. Use its child `z_index` values to control ground, detail, and canopy ordering.
- Put exact foreground or collision props under a top-level `PlacedProps` `Node2D`. It is moved into the y-sorted actor layer. Add `slasher_navigation_blocker` to a placed prop when enemy pathfinding must treat its cell as blocked; include a `StaticBody2D`/`CollisionShape2D` when the player must physically collide with it.
- Disable `show_generated_ground` to use painted tiles instead of the per-cell procedural grass sprites.
- Disable `show_generated_boundary_art` to hide generated wall artwork while keeping the gameplay boundary collision rails.

By default, the `Geometry` polygons remain the gameplay walkability source and TileMapLayers are visual-only. To paint walkability directly, enable `tilemaps_define_walkability` on the root and add `slasher_walkable_tiles` (or `defines_walkability = true` metadata) to each TileMapLayer that represents traversable ground. Painted tile centers are converted into the existing 48 px Slasher navigation grid. Decorative tile layers should not receive that group.
