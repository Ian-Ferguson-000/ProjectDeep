# Consolidation Notes

## Canonical Project
`deep/` is the canonical Godot project for Eros. The accidental `project-deep/` folder was a second Godot project for the same game and should be deleted after verification.

## What Was Preserved
Useful game-related files from `project-deep/` were archived under:

`deep/reference/project_deep_shooter/`

The archive includes the duplicate project's scripts, scenes, original `project.godot`, and loose `battle_map_(node_2d).tscn`.

`deep/reference/.gdignore` prevents Godot from importing the archived shooter files as active resources.

## What Was Excluded
- `addons/godot_ai/`
- `godot-ai-LICENSE.txt`
- duplicate icon files
- `.godot`
- `.DS_Store`
- generated/editor-local files outside the selected reference archive

## Adapted Into Active Demo
- A reusable `ExitDoor` component now carries the signal-based locked/unlocked door pattern in an Eros-friendly form.
- A lightweight `MinimapPanel` component now draws the forest grid, player, exit, enemies, chest, loot, props, traps, and discovered secrets.

## Reference Concepts
- Minimap rendering from the shooter prototype can guide richer map UI later.
- Door signals can support locked exits, keys, levers, and boss gates.
- Powerup colors can inform future potion and temporary buff readability.
- Floor numbering and boss cadence can inform deeper dungeon progression.

## Deletion Readiness
After opening `deep/project.godot` and confirming the demo still runs, `project-deep/` can be deleted. The active project does not depend on files in `project-deep/`.
