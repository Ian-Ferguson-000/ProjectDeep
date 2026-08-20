# Project Deep Shooter Reference

This folder archives the game-related files from the accidental `project-deep` Godot project before that duplicate project is deleted.

## Status
These files are reference material only. They are not wired into the active Eros demo and should not be treated as runtime dependencies for `deep/project.godot`.

The parent `deep/reference/.gdignore` file tells Godot not to import this archived prototype as active project content.

## Migrated
- `scripts/`: real-time shooter prototype scripts.
- `scenes/`: shooter prototype scenes.
- `project.godot`: original duplicate project config for reference.
- `battle_map_(node_2d).tscn`: loose prototype map scene.

## Excluded
- `addons/godot_ai/`: editor/plugin tooling, not game content.
- `godot-ai-LICENSE.txt`: tied to the excluded addon.
- Duplicate icon files.
- `.godot`, `.DS_Store`, and other generated/editor-local files.

## Useful Ideas To Adapt Later
- `door.gd`: signal-based locked/unlocked door behavior.
- `minimap.gd`: compact HUD map drawing.
- `powerup.gd`: pickup typing and color coding.
- `floor.gd`: floor numbering, door direction, room generation, boss-floor cadence.
- `boss.gd`, `enemy.gd`, `bullet.gd`, `player.gd`, `game_manager.gd`: reference for an action prototype, not the current tabletop loop.

## Known Issue
`scenes/enemy.tscn` is incomplete in the duplicate project. It does not attach `enemy.gd` or include the `Sprite` child that `enemy.gd` expects.
