> [!WARNING]
> Historical document retained for context. It is superseded by the [Eros documentation index](../../README.md) and is not authoritative.

# Asset Organization Plan

This project is still using a mix of imported asset packs, generated art, and early prototype files. As the dungeon set grows, migrate art into domain folders while keeping original vendor/source packs intact for reference.

## Proposed Hierarchy

```text
assets/
  source_packs/
	humble_paper_ui/
	legacy_pixel_art/
	effect_packs/
  game/
	shared/
	  ui/
		icons/
		buttons/
	  characters/
		player/
		enemies/
		npcs/
	  vfx/
		fire/
		force/
	dungeons/
	  forest/
		tiles/
		  ground/
		  walls/
		  overlays/
		decor/
		  border/
		  floor/
		  landmarks/
		interactables/
		  loot/
		  traps/
		  doors/
		  chests/
		minimap/
	  tavern/
		tiles/
		decor/
		characters/
```

## Migration Rules

- Keep third-party packs unchanged under `assets/source_packs/` so artists can re-slice or verify provenance later.
- Put all runtime-facing files under `assets/game/`.
- Prefer semantic filenames over pack coordinates, such as `tree_large.png`, `grass_dense_01.png`, `key_bronze.png`, and `trap_roots.png`.
- Dungeon-specific art belongs under `assets/game/dungeons/<dungeon_id>/`.
- Shared combat/UI/VFX assets belong under `assets/game/shared/`.
- When replacing art, update script constants and centralized mapping helpers first. For the forest scene, the main handoff points are:
  - `GRASS_ATLAS` and `_build_board_tiles()` for ground rendering.
  - `_apply_decoration_sprite()` for foliage/decor slices and scale.
  - `_apply_sprite_to_piece()` for loot, traps, props, doors, and other board objects.

## Current Forest Migration Target

Current prototype files can migrate like this:

```text
assets/pixel_art/forest_art/grass3.jpg
  -> assets/game/dungeons/forest/tiles/ground/grass_dense_01.jpg

assets/pixel_art/forest_art/decor/tree_large.png
  -> assets/game/dungeons/forest/decor/border/tree_large.png

assets/pixel_art/forest_art/decor/tree_wide.png
  -> assets/game/dungeons/forest/decor/border/tree_wide.png

assets/pixel_art/potion.png
  -> assets/game/dungeons/forest/interactables/loot/potion_red.png

assets/pixel_art/key.png
  -> assets/game/dungeons/forest/interactables/loot/key_bronze.png

assets/pixel_art/loot.png
  -> assets/game/dungeons/forest/interactables/loot/gold_cache.png

assets/pixel_art/trap.png
  -> assets/game/dungeons/forest/interactables/traps/root_snare.png
```

Do the move in one focused pass, then update preload paths and Godot `.import` files together.
