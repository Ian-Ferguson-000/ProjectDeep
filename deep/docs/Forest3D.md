# Verdant Forest: 3D rooms

Normal forest expeditions now load `game/dungeons/forest/Forest3D.tscn` from Main. Run the project with F5, then enter the forest through the tavern. The Stone Crypt uses the same presentation with a stone theme (docs/Crypt3D.md). The dungeons still marked Coming Soon keep their 2D presentation until they get a 3D one (docs/Scenes.md). The forest's authored maps, seeded room graph, encounters, checkpoints and campaign saves remain compatible.

## Presentation

The new forest uses raised earth, grassy clearings, worn paths, cobblestones, recessed ponds, low-poly trees, mushrooms, stone boundaries and bramble gates. Foreground vegetation is deliberately lower so it cannot conceal an exit or a fight. Static geometry is grouped into MultiMeshes by primitive/material; destructible rocks, trees and chests have independent models tied to the original objects' lifetimes.

Campfires, merchant stalls, treasure plinths and the Root Gate have spatial fixtures. The Heartwood Colossus has a modeled trunk, branches, canopy and a stump after defeat. Its original weak points, attack warnings, projectiles and boss bar remain active. Characters are animated camera-facing sprites, with a stable silhouette-based size and explicit differences between humans, wolves and small creatures.

## Controls and gameplay

Movement stays relative to the screen. Mouse aiming and controller aim map through the orthographic camera onto the combat plane. The existing attack, dodge, item, interaction, pause and Codex controls still apply. Mouse wheel adjusts camera zoom; the existing zoom setting also applies. Right click remains the combat movement action, so the forest does not use the tavern's orbit gesture.

This is a 3D environment presentation over the existing 2D combat simulation. Collision, navigation, attack ranges, damage and room triggers remain authoritative in that simulation; there is no new jumping, height-based combat or separate 3D physics system. The transparent effects pass projects the existing attacks and telegraphs onto the ground, preserving their actual footprints. HUD and menus remain ordinary screen-space UI.

## Editing

- `game/dungeons/forest/forest_3d.gd`: adapter extending the existing forest room controller; rebuilds presentation on room/floor changes and restores viewport state when leaving.
- `game/dungeons/shared/world_3d/forest_world_3d.gd`: camera, actor and prop synchronization, shared effects viewport, and screen-to-combat coordinate mapping.
- `game/dungeons/shared/world_3d/forest_room_art.gd`: reusable procedural mesh kit, palette, vegetation, fixtures and guardian models. One 48-pixel gameplay cell becomes one metre.
- `maps/forest/rooms/`: existing authored room layouts remain the source for floor shapes, paths, water, props and doors.
- `game/player/slasher_player.gd`: optional input basis, identity in 2D dungeons; the forest supplies its camera's inverse basis.

These rooms are generated in Godot rather than stored as individual Blender scenes. Edit the shared kit to change the whole forest, or edit an authored room to change that room's layout. No texture download or external generation service is needed. The original `game/dungeons/forest/SlasherForest.tscn` remains available for 2D comparison and shared gameplay tests.

The onboarding expedition and merchant interlude use their existing connected-floor layouts, also rendered through the 3D adapter.

## Validation and captures

```sh
GODOT='/Users/michaeligbanugo/Downloads/Godot.app/Contents/MacOS/Godot'
"$GODOT" --headless --path . --script tests/dungeons/forest_3d_test.gd --quit-after 16000
"$GODOT" --headless --path . --script tests/tavern/tavern_3d_main_flow_test.gd --quit-after 3000
python3 tools/run_hearth_tests.py --godot "$GODOT" forest_rooms slasher_hit_geometry slasher_combo pause_menu
```

The new integration test verifies spatial construction, screen-relative movement, inverse aim mapping, connected doors, combat locks, clearing encounters, destructible props, opened chests, campfire healing, merchant presence, pond boundaries, guardian weak-point damage, tutorial fallback, and viewport cleanup. Its campaign saves are in-memory. The Main test verifies the actual 3D tavern → 3D forest → tavern/results flow.

To capture room views, run the forest test without `--headless` and append `-- --capture`. Images are written to `build/visual_checks/forest_3d_*.png` for the start, combat, rest, shop, treasure, pond and guardian rooms.
