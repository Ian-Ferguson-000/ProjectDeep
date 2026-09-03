> [!WARNING]
> Historical document retained for context. It is superseded by the [Eros documentation index](../../README.md) and is not authoritative.

# Slasher Visual Follow-ups

## Reused asset manifest

| Semantic key | Source | Crop / presentation | Collision |
|---|---|---|---|
| grass variants | `assets/pixel_art/TX Tileset Grass.png` | Three quiet 32 px top-row atlas tiles, deterministically selected and scaled 1.5× to one 48 px cell | None |
| masonry boundary walls | `assets/pixel_art/TX Tileset Wall.png` | Layered 32 px cap and brick-face courses extending into the void; narrow vertical side strips | Existing 8 px perimeter body |
| boundary corners | `assets/pixel_art/TX Tileset Wall.png` | One small 10×10 rounded tip crop, flipped for convex and concave junctions | Existing 8 px perimeter body |
| tree_large / tree_small | `assets/pixel_art/TX Plant.png` | Existing Strategy Forest tree regions and scales, pivoted above their feet | 17 px circle when used as a solid prop |
| tree_wide / low bushes | `assets/pixel_art/TX Plant.png` | Existing Strategy Forest tree and bush regions | Decorative |
| grass tufts | `assets/pixel_art/TX Plant.png` | Three 15–17 px ground-plant regions, scaled 1.12–1.18× | None |
| mossy rock | `assets/pixel_art/TX Props.png` | Tight `Rect2(66,487,28,18)` crop | None |
| rock / barrel / chest | `assets/pixel_art/TX Props.png` | Tight object-bound crops; chest swaps to its 33×68 open sprite when unlocked | 17 px circle when used as a solid prop |
| campfire | Existing Strategy Forest individual sprite | Scale 0.07 | Reserved for later interactive props |
| root gate | `assets/pixel_art/TX Props.png` | Tight `Rect2(28,104,41,49)` wooden-door crop | Interaction radius only |
| merchant | `assets/merchants/forest_thistle.png` | Scale 0.075, Y -28 | Interaction radius only |
| gold / potion / key | Existing Strategy Forest pickup sprites | Scale 0.055 / 0.12 / 0.35 | 14 px pickup area |

All semantic regions and pivots are centralized in `SlasherForestArt`; replace them there rather than changing generation code.

Ground rendering uses the authored TX grass tileset: three quiet top-row 32 px grass variants are scaled with nearest-neighbor filtering to the 48 px Slasher grid, leaving flowers and stronger accents to separate decorations. Trees, bushes, and grass tufts use the matching TX plant sheet and the same semantic crops already established by Strategy Forest. Horizontal walls layer a TX cap course over a full brick-face course extending into the void. Vertical boundaries rotate one continuous cap-strip crop so neighboring segments meet without alpha gaps. Convex and concave grid junctions use a small 10×10 rounded TX tip instead of full 32 px corner chunks. Boundary generation no longer places foliage outside the walkable floor. Rocks, barrels, chests, and the exit use corrected TX Props crops that include each complete sprite without neighboring atlas content; opening a chest swaps it to the matching open-chest prop. Named regions are also available for crates, benches, pillars, and wells. The permanent bottom ability bar was removed; floor one presents a translucent control legend that dismisses after movement, ability use, or fourteen seconds.

## Art still needed

- Additional matching transition pieces for wall-to-door joins, roots, and canopy caps. The TX grass, wall, plant, and prop sheets now supply the core forest environment art.
- Dedicated translucent mist textures. The current particle layer uses soft low-alpha procedural particles.
- Matching prop families for shrines, ruins, flowers, reeds, mushrooms, fallen trunks, destructible foliage, and boss-arena landmarks.

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
