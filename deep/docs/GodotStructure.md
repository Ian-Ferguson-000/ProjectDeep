# Godot Node Structure

The starter demo should be easy to inspect in the Godot editor. Scenes use named child nodes for boards, tokens, generated markers, and UI instead of hiding everything in script-created nodes.

## Main
- `Main`: owns run state, gear data, and scene transitions.
- Tavern and forest scenes are swapped through this controller.

## Tavern
- `Tavern`: handles tavern input and interactions.
- `Board`: parent for the tavern board.
- `Board/GroundLayer`: `TileMapLayer` for tavern floor tiles.
- `Board/WallLayer`: `TileMapLayer` for tavern boundary/wall tiles.
- `Board/FixtureLayer`: `TileMapLayer` for fixtures such as counter, rug, hearth, weapon rack, tables, and forest door tile.
- `Board/PropSprites`: `Sprite2D` props that complement the tile layers, such as the gear desk.
- `Board/Tokens`: visible tabletop actors.
- `PlayerToken`, `BartenderToken`, `GearRackToken`, `ForestDoorToken`: editable token nodes with real `Panel`, `Sprite2D`, and `Label` children.
- `UI`: top status plus a bottom dialogue panel with tavern keeper portrait, dialogue text, Humble Gift-styled gear buttons, gear detail, and forest entry button.

## Forest
- `Forest`: handles generation, combat turns, loot, death, and completion.
- `Board`: parent for the forest board.
- `Board/Tiles`: `TileMapLayer` populated at runtime from `TX Tileset Grass.png` so the generated forest uses real grass tile sprites instead of script-drawn rectangles.
- `Board/Decorations`: runtime-generated non-blocking forest dressing from `FreePack.png`, such as edge trees, shrubs, bushes, and rocks.
- `Board/Markers`: runtime-generated props, loot, traps, chest, found secrets, and the editable `ExitDoor`.
- `Board/Markers/ExitDoor`: reusable signal-based exit component adapted from the archived duplicate project.
- `Board/Enemies`: runtime-generated enemy tokens using sprite regions, such as the feral wolf sheet, with small generated `ProgressBar` health bars.
- `Board/Tokens/PlayerToken`: player token using the player idle sprite sheet.
- `UI`: named HUD, player health bar, minimap, log, and Humble Gift-styled action buttons.

## Reusable Components
- `BoardPiece.tscn`: simple tabletop token/marker scene.
- `board_piece.gd`: styles real `Panel` and `Label` child nodes as circular or square tabletop pieces.
- `BoardPiece` can optionally render a `Sprite2D` texture or texture region for asset-backed tokens.
- `ExitDoor.tscn`: signal-based tabletop exit marker.
- `MinimapPanel.tscn`: compact forest overview made from `Panel` and `ColorRect` nodes for player, exit, enemies, loot, props, traps, and discovered secrets.

This structure keeps the current demo lightweight while giving designers obvious nodes to select, rename, recolor, replace, or extend later.
