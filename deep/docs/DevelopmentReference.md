# Development Reference

This document is the onboarding source of truth for the current playable Godot demo in `deep/`. It covers active runtime files only. The archived shooter prototype under `deep/reference/project_deep_shooter/` is preserved for ideas and should not be treated as active game code.

## Project Overview

- Project name: `Eros`.
- Godot target: `4.7`, 2D canvas item stretch mode.
- Main scene: `res://scenes/main/Main.tscn`, configured in `project.godot`.
- Current loop: boot into the tavern, choose Fighter gear, enter the forest dungeon, fight wolves, collect loot, find the exit, then return to the tavern on victory or death.
- Runtime state lives in one `RunState` instance owned by `main.gd`. Tavern and forest scenes receive that same state through their `setup` functions.

## Scene Map

- `scenes/main/Main.tscn`: root controller scene. It owns scene transitions and run state through `scripts/main.gd`.
- `scenes/tavern/Tavern.tscn`: starting hub. It contains tilemap layers, player/bartender/gear/door tokens, and dialogue/gear UI.
- `scenes/forest/Forest.tscn`: first dungeon floor. It contains `Board/Tiles` as a `TileMapLayer`, marker/enemy/token roots, an `ExitDoor`, HUD, minimap, and action buttons.
- `scenes/components/BoardPiece.tscn`: reusable tabletop token with `Panel`, `Sprite2D`, and `Label` child nodes.
- `scenes/components/ExitDoor.tscn`: reusable exit marker that emits door signals.
- `scenes/components/MinimapPanel.tscn`: compact visual map made from generated UI child nodes.

## Core Data

### `GearData`

`scripts/game/gear_data.gd` defines a `Resource` with these exported fields:

- `id`: stable gear id string.
- `display_name`: UI name.
- `damage`: base player attack damage.
- `has_block`: whether the gear supports shield block.
- `block_limit`: starting block stack count.
- `special_id`: special action branch used by `forest.gd`.
- `description`: multiline UI description.

Current Fighter gear is created in `main.gd`:

| Gear | `id` | Damage | Block | Block Limit | Special |
| --- | --- | ---: | --- | ---: | --- |
| Sword and Shield | `sword_shield` | `1` | `true` | `2` | `charge` |
| Greatsword | `greatsword` | `3` | `false` | `0` | `sweep` |
| Spear and Shield | `spear_shield` | `2` | `true` | `1` | `brace` |

### `RunState`

`scripts/game/run_state.gd` defines a `RefCounted` run record:

- `selected_gear`: current `GearData`, set when entering the forest and cleared on return.
- `current_health`: starts at `12`, changes through damage/healing.
- `max_health`: `12`.
- `gold`: run gold, reset to `0` on each forest entry.
- `keys`: run keys, reset to `0` on each forest entry.
- `potions`: run potions, reset to `0` on each forest entry.
- `floor_seed`: starts at `1001`, then increases by `37` on each new run before forest generation uses it.
- `run_outcome`: tavern status text.
- `completed_runs`: lifetime tavern-visible victory counter.
- `deaths`: lifetime tavern-visible defeat counter.

### Forest World Data

`scripts/scenes/forest.gd` owns the active floor dictionaries and arrays:

- Grid: `GRID_W = 16`, `GRID_H = 11`, `TILE_SIZE = 48`, `ORIGIN = Vector2(48, 92)`.
- Tile art: `TX Tileset Grass.png`, atlas tile size `32x32`, display scale `1.5`.
- `floor_cells`: dictionary set of walkable carved cells.
- `critical_path`: dictionary set of guaranteed route cells between generated room centers.
- `player_pos`: starts at `Vector2i(2, 8)`, then becomes the first generated room center.
- `exit_pos`: starts at `Vector2i(14, 2)`, then becomes the last generated room center.
- `facing`: starts as `Vector2i.RIGHT`; movement and click actions update it.
- `block_stacks`: initialized from `selected_gear.block_limit`.
- `braced`: `true` only after using spear brace until the next approaching enemy is punished.
- `enemies`: three wolf dictionaries, each `{ "kind": "wolf", "pos": Vector2i, "hp": 4, "max_health": 4, "damage": 2 }`.
- `props`: five prop dictionaries chosen from rocks, barrels, and campfire. Rocks/barrels have `hp = 2`; campfire has `hp = 99`.
- `loot`: loose gold, potion, and key dictionaries. Loose gold gives `7`.
- `traps`: one dictionary `{ "pos": Vector2i, "sprung": false }`.
- `chest`: `{ "pos": Vector2i(10, 4), "opened": false }` before generation; generated position is randomized.
- `secret`: `{ "pos": Vector2i(6, 7), "found": false }` before generation; generated position is randomized.

### Combat And Rewards

- Basic adjacent attacks call `_attack_enemy(enemy_index, run_state.selected_gear.damage)`.
- Charge special deals `selected_gear.damage + 1` to the first enemy reached up to three tiles away.
- Sweep special deals `selected_gear.damage` to every adjacent enemy.
- Brace special sets `braced = true`; `_brace_hits_enemy` deals `selected_gear.damage + 1` when an enemy attacks or moves adjacent.
- Wolves deal `2` damage through `_enemy_attack`.
- Shield block reduces enemy damage by `1` while `block_stacks > 0`, then consumes one stack.
- Traps deal `3` damage in `_resolve_tile`.
- Potions heal `5` in `_drink_potion`.
- Campfires heal `2` through `_interact` or `_hit_prop`.
- Wolf kills give `+3 gold`.
- Breaking a non-campfire prop gives `+1 gold`.
- Loose gold gives `+7 gold`.
- A key pickup gives `+1 key`.
- A potion pickup gives `+1 potion`.
- Chest requires `1 key`; reward is `+15 gold` and `+1 potion`.
- Hidden cache gives `+9 gold` and `+1 potion`.
- Death occurs when `run_state.current_health <= 0`; `_die` returns to the tavern with outcome `"death"`.
- Victory occurs through the exit door; `_finish_floor` returns to the tavern with outcome `"victory"`.

## Active Asset References

- Player idle: `res://assets/sprite_packs/Player/IDLE/idle_down.png`.
- Tavern keeper portrait/token: `res://assets/generated_characters/tavern_keeper.png`.
- Feral wolf sheet: `res://assets/enemies/feral_wolf/normalized_sheet.png`.
- Forest/tavern tile atlases: `TX Tileset Grass.png`, `TX Tileset Stone Ground.png`, `TX Tileset Wall.png`.
- Props/structures/plants: `TX Props.png`, `TX Struct.png`, `TX Plant.png`.
- Humble Gift buttons: `Sprites/Content/4 Buttons/1.png`, `2.png`, `3.png`.
- Tavern desk: `Sprites/Book Desk/1.png`.

## Script Reference

### `scripts/main.gd`

Purpose: global scene controller and run owner.

Data:

- `TavernScene`: preloads `Tavern.tscn`.
- `ForestScene`: preloads `Forest.tscn`.
- `run_state`: one persistent `RunState`.
- `gear_options`: array of three `GearData` objects.
- `current_scene`: currently instanced tavern or forest scene.

Functions:

- `_ready()`: registers input actions, builds gear data, and opens the tavern with the first message.
- `_build_gear_options()`: creates the three Fighter gear resources and their damage/block/special values.
- `show_tavern(message = "")`: clears the current scene, instances the tavern, passes controller/state/gears/message, and adds it to the tree.
- `start_forest(gear)`: calls `run_state.start_new_run`, clears the tavern, instances the forest, passes controller/state, and adds it to the tree.
- `return_to_tavern(outcome, message)`: finishes the run state and routes back to tavern with the result message.
- `_clear_scene()`: queues the current scene for deletion and clears the reference.
- `_ensure_input_actions()`: creates runtime input actions for movement, interact, special, and potion use.
- `_add_key_action(action, keys)`: creates an input action if needed and adds missing keyboard events.
- `_action_has_key(action, key)`: checks whether an input action already has a physical key binding.

### `scripts/game/gear_data.gd`

Purpose: lightweight gear resource used by UI and combat.

Functions:

- `create(gear_id, gear_name, gear_damage, gear_has_block, gear_block_limit, gear_special_id, gear_description)`: static constructor that fills all gear fields and returns a new `GearData`.

### `scripts/game/run_state.gd`

Purpose: persistent run/session values shared by tavern and forest.

Functions:

- `start_new_run(gear)`: selects gear, restores health to max, resets run currency/items, increments `floor_seed` by `37`, and sets the forest entry outcome text.
- `finish_run(outcome, message)`: stores the result message, increments `completed_runs` for `"victory"` or `deaths` for `"death"`, then clears selected gear.
- `heal(amount)`: adds health up to `max_health`.
- `hurt(amount)`: subtracts health down to a minimum of `0`.

### `scripts/scenes/tavern.gd`

Purpose: hub map, gear selection, dialogue, and forest entry.

Data:

- Grid: `GRID_W = 10`, `GRID_H = 7`, `TILE_SIZE = 56`, `ORIGIN = Vector2(72, 112)`.
- Tile scale: `TILESCALE = 1.75`, atlas tile size `32x32`.
- Positions: player `Vector2i(2, 4)`, bartender `Vector2i(4, 2)`, forest door `Vector2i(8, 2)`, gear rack interaction near `Vector2i(1, 2)`.
- UI nodes: status, title, dialogue panel, gear detail, gear buttons, enter button.
- Board nodes: ground/wall/fixture tile layers, prop sprite root, player/bartender/gear/door tokens.

Functions:

- `setup(game_controller, state, options, intro_message)`: receives controller, shared run state, gear options, and tavern message; defaults selected gear to the first option.
- `_ready()`: applies UI font/style setup, connects the enter button, builds tilemaps, positions sprites/tokens, and refreshes UI.
- `_unhandled_input(event)`: routes interact, keyboard movement, and mouse tile clicks.
- `_refresh_ui()`: updates run counters, selected gear text, dialogue text, gear detail, and gear buttons.
- `_populate_gear_buttons()`: rebuilds gear selection buttons from `gear_options`, sets toggle state, connects selection, and applies Humble Gift button styling.
- `_select_gear(gear)`: updates selected gear and bartender response, then refreshes UI.
- `_handle_tile_click(tile)`: interprets click-to-interact or adjacent click movement.
- `_try_move(delta)`: moves the player unless the target is the bartender or forest door; those targets trigger dialogue or forest entry.
- `_interact()`: handles adjacent bartender, gear rack, forest door, or generic tavern interaction text.
- `_enter_forest()`: asks the controller to start the forest using `selected_gear`.
- `_build_tavern_tilemaps()`: creates tile sets for ground, walls, and fixtures, then paints the tavern board.
- `_setup_layer(layer, texture, atlas_tiles)`: creates a `TileSet` and `TileSetAtlasSource` for a `TileMapLayer`.
- `_paint_rect(layer, rect, atlas_tile)`: fills a rectangle of tile cells on a layer.
- `_position_tavern_sprites()`: positions and scales the gear desk sprite.
- `_configure_token_sprites()`: assigns player, bartender, gear rack, and forest door sprite regions/scales.
- `_update_token_positions()`: places token nodes at their grid centers.
- `_screen_to_grid(pos)`: converts screen coordinates into grid coordinates.
- `_grid_to_screen(tile)`: converts grid coordinates into top-left screen coordinates.
- `_grid_center(tile)`: converts grid coordinates into center screen coordinates.
- `_style_dialogue_panel()`: applies the dark bordered panel style.
- `_style_button(button)`: applies Humble Gift button textures, font colors, and size.
- `_button_style(texture)`: creates a `StyleBoxTexture` with margins for scalable button art.
- `_is_inside_grid(tile)`: bounds check for the tavern grid.
- `_is_adjacent(a, b)`: returns true when tiles are within Manhattan distance `1`; this includes the same tile.

### `scripts/scenes/forest.gd`

Purpose: generated forest floor, grid input, combat, loot, minimap, and return loop.

Functions:

- `setup(game_controller, state)`: receives controller/state, initializes block stacks from selected gear, and generates/refreshes immediately if already in the tree.
- `_ready()`: styles UI, connects buttons and exit door signals, generates the floor, builds grass tilemap, configures the player sprite, and refreshes UI.
- `_generate()`: seeded floor generation. Carves five rooms, links them with corridors, sets player/exit positions, then places chest, secret, props, loot, traps, and enemies. It exits early if generation already happened.
- `_carve_room(center, radius_x, radius_y)`: adds rectangular room cells to `floor_cells`.
- `_carve_corridor(a, b)`: adds an L-shaped guaranteed path between two room centers and records those cells in `critical_path`.
- `_place_props()`: adds rocks, barrels, and a campfire to random unreserved floor cells.
- `_place_loot()`: adds one gold pile, one potion, and one key.
- `_place_traps()`: adds one unsprung trap.
- `_place_enemies()`: adds three wolves with `4` hp and `2` damage.
- `_unhandled_input(event)`: maps special, interact, potion, keyboard directions, and left-click tile selection.
- `_take_directional_action(delta)`: updates facing and treats keyboard movement as an adjacent tile action.
- `_handle_tile_click(tile)`: validates adjacency, then attacks enemies, hits props, opens chest, exits, moves, or reports blocked trees.
- `_interact()`: handles adjacent exit, chest, hidden cache, campfire, breakable prop, or generic search text.
- `_use_special()`: dispatches by `selected_gear.special_id` to charge, sweep, brace, or no-special messaging.
- `_special_charge()`: moves up to three tiles in `facing`; if an enemy is reached, deals `selected_gear.damage + 1`.
- `_special_sweep()`: hits all adjacent enemies for `selected_gear.damage`.
- `_drink_potion()`: consumes one potion and heals `5`, or reports that none are available.
- `_attack_enemy(index, damage)`: subtracts enemy hp, removes dead enemies, grants `3` gold on kill, or reports remaining hp.
- `_hit_prop(index)`: heals at campfire or damages breakable props; destroyed props grant `1` gold.
- `_open_chest()`: if unopened and the player has a key, spends `1` key and grants `15` gold plus `1` potion.
- `_resolve_tile()`: processes pickups and trap damage after movement.
- `_end_player_action()`: checks death, runs enemy turn, then checks death again.
- `_enemy_turn()`: each living wolf attacks if adjacent or steps toward the player and may attack after moving.
- `_brace_hits_enemy(index)`: if braced, clears brace and attacks the enemy for `selected_gear.damage + 1` before it strikes.
- `_enemy_attack(enemy)`: applies wolf damage, reducing it by `1` if block stacks remain.
- `_apply_damage(amount)`: calls `run_state.hurt` and sets defeat message if health reaches `0`.
- `_complete_floor()`: enters the exit door if available, otherwise finishes the floor directly.
- `_on_exit_door_entered(_door)`: signal handler that finishes the floor.
- `_finish_floor()`: returns to tavern with `"victory"` and current gold in the message.
- `_die()`: returns to tavern with `"death"`.
- `_build_board_tiles()`: builds the visible grass `TileMapLayer` from `floor_cells`.
- `_make_grass_tile_set()`: creates a runtime `TileSet` from the grass atlas.
- `_configure_player_sprite()`: assigns the player idle sprite sheet region and hides placeholder token visuals.
- `_refresh_ui()`: updates health bar, stats text, log text, board nodes, and minimap state.
- `_sync_board_nodes()`: positions player/exit, clears and rebuilds generated markers/enemies, adds enemy health bars, and updates minimap.
- `_add_marker(node_name, tile, label, color, sprite_key)`: creates and adds a non-enemy marker piece.
- `_make_piece(node_name, tile, label, color, shape, sprite_key = "")`: instances `BoardPiece`, configures label/color/shape, applies sprite art, and positions it.
- `_apply_sprite_to_piece(piece, sprite_key)`: maps sprite keys like `wolf`, `rock`, `gold`, `chest`, and `trap` to atlas regions.
- `_set_piece_sprite(piece, texture, region, scale)`: assigns sprite texture/region/scale and hides label/panel.
- `_configure_exit_sprite()`: assigns structure atlas art to the `ExitDoor`.
- `_atlas_region(x, y)`: returns a `32x32` atlas `Rect2`.
- `_add_enemy_health_bar(piece, enemy)`: attaches a small `ProgressBar` to an enemy token using enemy hp/max hp.
- `_style_health_bar()`: styles the player HUD health bar.
- `_style_action_buttons()`: styles forest action buttons with Humble Gift textures.
- `_button_style(texture)`: creates a scalable button `StyleBoxTexture`.
- `_flat_style(color, corner_radius, border_color)`: creates reusable flat styles for health bars.
- `_clear_children(parent)`: queues all children of a node for deletion.
- `_clear_generated_markers()`: clears marker children except the persistent `ExitDoor`.
- `_build_minimap_state()`: packages grid, player, exit, enemy, prop, loot, trap, chest, and secret state for `MinimapPanel`.
- `_pick_floor_cell(avoid_path)`: picks a random unreserved floor cell, optionally avoiding `critical_path`.
- `_reserved(tile)`: returns true if a tile is occupied by player, exit, chest, secret, props, loot, traps, or enemies.
- `_step_toward(from_tile, to_tile)`: chooses a simple Manhattan step toward the player, avoiding blocked and occupied cells.
- `_is_walkable(tile)`: checks floor membership and blocks props, chest, and enemies.
- `_prop_at(tile)`: returns the prop index at a tile or `-1`.
- `_enemy_at(tile)`: returns the enemy index at a tile or `-1`.
- `_screen_to_grid(pos)`: converts screen coordinates into forest grid coordinates.
- `_grid_to_screen(tile)`: converts grid coordinates into top-left screen coordinates.
- `_grid_center(tile)`: converts grid coordinates into center screen coordinates.
- `_is_inside_grid(tile)`: bounds check for the forest grid.
- `_distance(a, b)`: Manhattan distance helper.
- `_sign_int(value)`: converts an integer delta into `-1`, `0`, or `1`.
- `_loot_label(kind)`: fallback label for gold, potion, key, or unknown loot.
- `_prop_label(kind)`: fallback label for rock, barrel, campfire, or unknown prop.
- `_prop_color(kind)`: fallback color for rock, barrel, campfire, or unknown prop.

### `scripts/components/board_piece.gd`

Purpose: reusable visual token/marker base.

Data:

- `PieceShape`: enum with `CIRCLE` and `SQUARE`.
- Exported visuals: `label_text`, `fill_color`, `outline_color`, `label_color`, `radius`, `size`, `shape`.
- Exported sprite support: `sprite_texture`, `sprite_region_enabled`, `sprite_region`, `sprite_scale`.
- Exported visibility: `show_label`, `show_panel`.
- Child node references: `Panel`, `Sprite`, `Label`.

Functions:

- `_ready()`: applies visuals once child nodes are ready.
- `configure(text, color, piece_shape = PieceShape.CIRCLE)`: sets common token values and reapplies visuals.
- `_apply_visuals()`: updates panel geometry/style, sprite texture/region/scale, label text/alignment/color, and circle/square corner radius.

### `scripts/components/exit_door.gd`

Purpose: signal-based exit marker built on `BoardPiece`.

Data:

- Signals: `door_entered(door)`, `door_unlocked`.
- Exported colors: locked `Color(0.35, 0.35, 0.40)`, unlocked `Color(0.25, 0.62, 0.36)`.
- `is_unlocked`: current door state.
- `grid_position`: tile position assigned by the forest.

Functions:

- `_ready()`: runs `BoardPiece` setup, sets square shape and label, and starts unlocked.
- `setup(tile, unlocked = true)`: records grid position and applies locked/unlocked state.
- `set_locked(locked)`: flips `is_unlocked`, updates color/alpha, and emits `door_unlocked` when unlocked.
- `unlock()`: no-ops if already unlocked; otherwise unlocks the door.
- `enter()`: emits `door_entered` if the door is unlocked.

### `scripts/components/minimap_panel.gd`

Purpose: visual overview of the generated forest using actual Control children.

Data:

- `map_state`: dictionary from `forest.gd`.
- Required keys from forest: `width`, `height`, `floor_cells`, `player`, `exit`, `enemies`, `props`, `loot`, `traps`, `chest`, `secret`, `secret_found`.
- Child node references: `Background`, `Cells`, `Markers`, `TitleLabel`.

Functions:

- `_ready()`: sets panel size, styles background, and colors the title.
- `set_map_state(state)`: stores the state dictionary and rerenders.
- `_style_background()`: applies dark green transparent panel styling.
- `_render_map()`: clears old children, computes scale/origin, draws cells, props, loot, traps, enemies, chest, discovered secret, exit, and player markers.
- `_add_cell(tile, origin, scale, color)`: creates one floor-cell `ColorRect`.
- `_add_marker(tile, origin, scale, color, marker_size)`: creates one rounded `Panel` marker.
- `_clear_children(parent)`: queues all existing generated UI children for deletion.

## Maintenance Notes

- When adding a function to any active script under `deep/scripts`, update this document in the matching script section.
- When changing a gameplay number, update both the data reference and the function section that consumes it.
- If archived shooter code is adapted into active runtime, document the new active script here; do not document archived reference files directly.
