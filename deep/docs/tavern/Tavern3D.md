# The Hearth: playable 3D tavern

The normal game now uses `game/tavern/3d/Tavern3D.tscn` as its campaign hub. Run the project with F5 and start or continue a campaign. The main hall, adjoining lodgings, and training yard support keeper movement, NPC activity, collision, navigation, and the existing campaign interactions. Expedition departure and return use the new scene without changing the save format.

## Controls

- WASD / arrows: move relative to the camera at 4.8 metres/second.
- Left click: walk to a floor point, or approach and use an interactable.
- E / Space / controller A: use the nearby interaction.
- Right drag: orbit. Mouse wheel: zoom.
- C: toggle complete walls / camera-dependent cutaway.
- N: toggle character names. R: reset the camera.
- Escape: pause; the Controls page includes these tavern controls.

The bar opens Facilities; the expedition board and entrance open Expeditions. Merchants, recruitment, armory, lodging management, and training upgrades retain their existing campaign UI. The stairs are physically traversable and the landing opens Lodgings; there is no separate upper-story interior.

Developer mode exposes all 18 lodging spaces and the fully equipped training yard, regardless of the saved establishment tier. Turning it off restores campaign access limits. This changes room access and presentation without purchasing rooms or altering saved progression. Character billboards use a fixed 1.65-metre visible idle-pose height, ignoring transparent frame padding; animation retains that scale.

## Runtime structure

- `game/main/main.gd` selects the new tavern scene.
- `game/tavern/3d/Tavern3D.tscn` inherits the original tavern scene. `tavern_3d.gd` retains its campaign controller and UI while hiding its 2D world.
- `tavern_world_3d.gd` assembles the environment, collision, navigation mesh, lights, camera, and interaction targets. Static imported geometry is combined by material within each named room section, preserving wall cutaways.
- `tavern_resident_3d.gd` gives the keeper and NPCs physical 3D bodies and navigation while synchronizing their shared campaign state. Existing animated character sprites are camera-facing billboards, not new 3D character models.
- `tavern_wings_3d.gd` builds the lodging and yard geometry from campaign state. Bed quality, occupants, furnishing selections, locked yard access, and yard upgrades are reflected in the room. These wings are generated at runtime, rather than baked into the hall's Blender file.

The original `game/tavern/2d/Tavern.tscn` remains as the inherited campaign/UI backing and for compatibility tests. Do not delete it. Open the playable hub through the normal game so its campaign dependencies are initialized.

## Editable art and preview

- `art_source/tavern/hearth_room.blend`: editable main hall, with named collections and independent props. `art_source/.gdignore` prevents duplicate Godot import.
- `assets/tavern3d/hearth_room.glb`: complete hall, all four walls and ceiling beams, with embedded materials and no external textures.
- `assets/tavern3d/hearth_room_stats.json`: measured geometry and export size.
- `tools/blender/build_tavern_room.py`: deterministic generator using Blender's built-in Python API.
- `game/tavern/3d/TavernRoomPreview.tscn`: standalone art preview; open and press F6. This preview uses left/middle drag to orbit, wheel to zoom, C for cutaway, and R to reset.

The hall is 18 × 11 metres. Blender uses Z-up with north along +Y; glTF maps this to Godot Y-up with north along -Z. Exported scale is 1. The Blender presentation hides FrontWall, EastWall, and CeilingBeams; enable those collections to inspect the complete room. The GLB includes them. The staircase has an open beam bay for headroom. Runtime collision uses a smooth ramp beneath its visible treads.

The current GLB is 2,141,168 bytes (2.04 MiB), with 32,228 evaluated source triangles, 717 mesh objects, and 24 materials. Source objects remain separate for editing; runtime batching reduces their rendering overhead. A captured upgraded hub measured 422 draw calls including the UI, wings, and shadow passes on the development machine. This is not a target-device performance guarantee.

## Rebuild

Run from the `deep` project directory:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/build_tavern_room.py
```

Regeneration overwrites the generated Blender file and GLB. Save hand-edited variants under another name first. Open Godot afterward to reimport the GLB. No Blender MCP addon or installer is required for this workflow.

## Verification

Using the Godot executable available locally:

```sh
GODOT='/Users/michaeligbanugo/Downloads/Godot.app/Contents/MacOS/Godot'
"$GODOT" --headless --path . --script tests/tavern/tavern_3d_integration_test.gd --quit-after 16000
"$GODOT" --headless --path . --script tests/tavern/tavern_3d_main_flow_test.gd --quit-after 3000
python3 tools/run_hearth_tests.py --godot "$GODOT" tavern_activity tavern_animation_state hearth_lodging campaign_loop autosave_policy pause_menu
```

The integration test checks collision, navigation, actual keeper/NPC travel, stair ascent, lodging access, mouse interaction with the bar, modal input gating, merchant and recruitment UI, furnishing and yard upgrades, pause, and single-shot expedition departure. The main-flow test launches an actual forest expedition through Main and returns to the 3D tavern with results. Both use in-memory campaign saves to avoid altering player saves.

For rendered captures, run the integration test without `--headless` and append `-- --capture`. Outputs are in `build/visual_checks/`: `tavern_3d_playable.png`, `tavern_3d_lodgings.png`, and `tavern_3d_yard.png`. The separate `tests/tavern/tavern_room_3d_test.gd` checks imported art bounds, named sections, and preview cutaways.
