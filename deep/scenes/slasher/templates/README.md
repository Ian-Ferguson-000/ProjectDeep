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
