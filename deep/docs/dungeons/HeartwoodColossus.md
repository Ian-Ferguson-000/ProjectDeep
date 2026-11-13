# The Heartwood Colossus (forest guardian)

Every dungeon is now **5 floors**: the elite guardian holds the gate room on
floors 1 to 4 (every floor, not just floor 3) and the guardian floor 5 (`data/dungeons.json`: `floors`, `cycle_length`,
`elite_floor_in_cycle`). On the forest's guardian floor, the Root Gate room is
the **Heartwood Throne** arena and the guardian is the Heartwood Colossus.

## The fight

A corrupted ancient tree built into the north wall of a 35×19 arena, goliath
sized (docs/dungeons/GuardianArenas.md). It never moves: its body fills a 13×7 block of
the room against that wall, and you fight in front of it. Its trunk can't
be hurt. After every attack a **weak point opens**, glowing with a "!" and a
ring that runs down like a timer. Hit it then.

| Attack | Warning | Then |
| --- | --- | --- |
| **Root Slam** | A red circle with an X under you, filling up | A fist slams down there, splinters fly out, and the **fist lies open** |
| **Spore Bloom** | The canopy swells and green rings ripple outward | Rings of pink spores, 3 waves (4 in phase three); then the **heart opens** |
| **Thorn Spiral** (from phase two) | The eyes flare red and a red ring tightens | Spinning arms of thorns for about 3 seconds; then the **heart opens** |

- The heart sits at the foot of the trunk (south side). Fists land wherever you
  were standing when the circle appeared.
- **Phases** at 66% and 33% health: it roars, clears all bullets and pauses, then
  speeds up (×1.2, then ×1.4). From phase two it slams twice in a row and uses the
  spiral; in phase three the spore waves get denser and it calls sporelings.
- Damage per hit is capped (as for every boss), so it takes several windows.
- When it falls, any sporelings scatter, the Root Gate opens, and a split stump
  is left where it stood.
- Health bar centred across the top of the screen, with notches at the phase thresholds.

All numbers are in `data/slasher_balance.json` → `enemies.heartwood_colossus`
(health, damage, every telegraph and window length, bullet counts and speeds).

## Art

### 3D model (the live forest)

The 3D forest shows a Blender model with animations:
`assets/enemies/heartwood_colossus/heartwood_colossus.glb`.

- **Source:** `art_source/heartwood_colossus/heartwood_colossus.blend`, built by
  `build_heartwood_colossus.py` (run it with Blender to regenerate from scratch).
  Once someone edits the `.blend` by hand, the `.blend` is the source of truth:
  export it to the `.glb` path above (glTF Binary, animations on) instead of rerunning
  the script.
- **Units:** one Blender unit is one map cell. The game scales the model by
  `GOLIATH_SCALE` (2.3) and by 0.85, and sets it back into the north wall
  (`forest_room_art.gd`, `colossus()`). The model faces -Y in Blender.
- **Skeleton:** `root`, `trunk_lower`, `trunk_upper`, `canopy`, `heart`, and for each
  arm `arm_upper`, `arm_lower`, `fist` (`.L` / `.R`). One mesh, each part weighted
  to one bone.
- **Animations** (`forest_world_3d.gd`, `_animate_colossus()` picks them from the boss's
  state): `Idle` (loops), `RootSlamL` / `RootSlamR` (a double slam alternates arms),
  `SporeBloom`, `ThornSpiral` (loops), `Roar` (phase change), `Hit` (heart struck),
  `Death` (not played yet: the game swaps in the split stump when it falls).
  Slam and bloom wind-ups are sped up or slowed so the blow lands as the telegraph ends.
- `render_previews.py` renders stills from the game's camera angle for checking poses.
- If the `.glb` is missing, the game falls back to the primitive placeholder.

### 2D placeholder

The 2D colossus is drawn in code as a placeholder. To use real art, set these on
the colossus (`game/enemies/bosses/slasher_colossus.gd`):

- `body_texture`: the whole tree, centred on the middle of its 13×7 cell block
  (336×240 px at game scale; the canopy can extend well beyond).
- `heart_texture`: the heart weak point (about 60×60).
- `fist_texture`: a fallen fist (about 70×70).

Telegraphs, bullets, the "!" and the window ring stay drawn in code, so they keep
working with any art.

## Making more colossus arenas

In a room scene, add a **Colossus** marker and tick the **guardian** role. Wherever
the marker is painted, the game moves the guardian against the north wall, seals
the north door, hides the way on inside its body and puts a portal home beside
it (docs/dungeons/GuardianArenas.md). Keep the top seven rows clear for its body and the
cells to its east clear for the portal. The room still needs a **Gate down**
marker to pass validation, but the game uses the one inside the body. The game
picks a guardian room for the gate room on guardian floors whenever one exists.

## Other colossi

The crypt's guardian, **Big Skelly Boi**, is built on the same code
(`slasher_charnel_king.gd` extends `slasher_colossus.gd`); see docs/Crypt.md.
A dungeon picks its colossus with `dungeons.json → <dungeon>.slasher.colossus`.

## Code

- `game/enemies/bosses/slasher_colossus.gd`: patterns, phases, telegraphs, boss bar.
- `game/enemies/bosses/slasher_colossus_weak_point.gd`: the heart and fists.
- `ForestRoomLibrary`: the `O` (colossus) symbol and the `guardian` role.
- Test: `tests/enemies/colossus_test.gd`.
