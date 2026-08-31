# Slasher Visual Follow-ups

## Reused asset manifest

| Semantic key | Source | Crop / presentation | Collision |
|---|---|---|---|
| grass variants | `assets/slasher/forest/verdant_tileset.png` | Eleven illustrated atlas regions from rows 1–2, scaled to one 48 px cell | None |
| mossy boundary walls | `assets/slasher/forest/verdant_tileset.png` | Eight front-wall regions at Y 591–601; deterministic variant per exposed edge | Existing 8 px perimeter body |
| side boundary pillars | `assets/slasher/forest/verdant_tileset.png` | Four pillar regions at Y 744–748 | Existing 8 px perimeter body |
| tree_large / tree_small | `assets/slasher/forest/verdant_tileset.png` | `Rect2(27,905,88,128)`, scale 0.60 / 0.48, pivot above feet | 17 px circle when used as a solid prop |
| tree_wide / low bushes | `assets/slasher/forest/verdant_tileset.png` | Bush and small ground-prop regions, scale 0.38–0.72 | Decorative |
| grass tufts | `assets/slasher/forest/verdant_tileset.png` | Tall grass and reed regions, scale 0.42–0.44 | None |
| mossy rock | `assets/slasher/forest/verdant_tileset.png` | `Rect2(796,1071,53,45)`, scale 0.62 | None |
| rock / barrel / chest | `assets/slasher/forest/verdant_tileset.png` | Large prop row, scale 0.48 / 0.55 / 0.50 | 17 px circle when used as a solid prop |
| campfire | Existing Strategy Forest individual sprite | Scale 0.07 | Reserved for later interactive props |
| root gate | `assets/generated_ui/wooden_exit_door.png` | Scale 0.15, Y -22 | Interaction radius only |
| merchant | `assets/merchants/forest_thistle.png` | Scale 0.075, Y -28 | Interaction radius only |
| gold / potion / key | Existing Strategy Forest pickup sprites | Scale 0.055 / 0.12 / 0.35 | 14 px pickup area |

All semantic regions and pivots are centralized in `SlasherForestArt`; replace them there rather than changing generation code.

Ground rendering now uses a consistent border-inset grass crop at 51 px, overlapping each 48 px walkable cell. Full-square detail overlays and per-cell tint variation were removed because their rectangular alpha and tonal boundaries remained visible; deterministic cutout foliage and rocks provide variation without changing the base floor. Walls now repeat cropped brick interiors and vertical masonry strips continuously, reserving full pillars for classified corners and reducing foliage interruptions. The permanent bottom ability bar was removed; floor one presents a translucent control legend that dismisses after movement, ability use, or fourteen seconds.

## Art still needed

- Additional matching transition pieces for concave wall corners, wall-to-door joins, roots, and canopy caps. The new Verdant atlas now supplies coherent grass, walls, pillars, and core props.
- Purpose-built dark-canopy exterior art. The current milestone layers existing trees and bushes over a dark underlay, which cannot fully reproduce the painted depth of the references.
- Dedicated translucent mist textures. The current particle layer uses soft low-alpha procedural particles.
- Matching prop families for shrines, ruins, flowers, reeds, mushrooms, fallen trunks, destructible foliage, and boss-arena landmarks.
- Unified replacements for the remaining legacy pickup/merchant/exit art and generated character sprites. Photographic grass is no longer used by Slasher Forest.

## Deferred presentation systems

- Animated grass and canopy wind, weather, fireflies, leaf particles, ground decals, blood/scorch persistence, and advanced 2D light/shadow shaders.
- Water-island and ruined-woodland themes for later dungeons.
- Minimap, ambient forest audio, biome music, room-entry camera framing, richer break fragments, and richer boss transitions.
- Low-end performance profiling for particle count, per-cell sprites, and edge foliage density. If needed, merge ground cells into cached room textures and expose quality presets.

## Runtime options and breakables

- Global display and feedback preferences persist in `user://settings.cfg`; Slasher defaults to 1.30x camera zoom while Strategy camera behavior remains unchanged.
- Master, Music, and SFX buses are created at runtime until authored bus routing and production audio are added.
- Generated solid trees, barrels, rocks, and chests use the shared Slasher damageable contract. Perimeter scenery remains visual framing and is intentionally indestructible.
- Prop gold is deterministic from run, floor, cell, and kind and remains excluded from class-resource, journal, encounter, XP, and boss-credit systems.

## Journal follow-up

- Strategy encounters need explicit canonical journal-ID mapping before they can safely award the same discovery records.
- Future enemy variants should declare a separate visual ID and journal ID so reskins can share an entry while mechanically distinct variants can receive their own.
- Add authored journal portraits only if idle-frame portraits prove too inconsistent across sprite sheets.
