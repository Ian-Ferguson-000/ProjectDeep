# The Heartwood Colossus (forest guardian)

Every dungeon is now **5 floors**: the elite guardian holds the gate room on
floors 1 to 4 (every floor, not just floor 3) and the guardian floor 5 (`data/dungeons.json`: `floors`, `cycle_length`,
`elite_floor_in_cycle`). On the forest's guardian floor, the Root Gate room is
the **Heartwood Throne** arena and the guardian is the Heartwood Colossus.

## The fight

A corrupted ancient tree rooted in the middle of a 35×19 arena. It never moves:
its body fills a 7×5 block of the room, and you fight around it. Its trunk can't
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

The colossus is drawn in code as a placeholder. To use real art, set these on
the colossus (`scripts/slasher/slasher_colossus.gd`):

- `body_texture`: the whole tree, centred on the middle of its 7×5 cell block
  (336×240 px at game scale; the canopy can extend well beyond).
- `heart_texture`: the heart weak point (about 60×60).
- `fist_texture`: a fallen fist (about 70×70).

Telegraphs, bullets, the "!" and the window ring stay drawn in code, so they keep
working with any art.

## Making more colossus arenas

In a room scene, add a **Colossus** marker (it shows the 7×5 block it fills) and
tick the **guardian** role. A guardian room also needs a **Gate down** marker for
after the fight, and room around the body on all sides. The game picks a guardian
room for the gate room on guardian floors whenever one exists.

## Other colossi

The crypt's guardian, **Big Skelly Boi**, is built on the same code
(`slasher_charnel_king.gd` extends `slasher_colossus.gd`); see docs/Crypt.md.
A dungeon picks its colossus with `dungeons.json → <dungeon>.slasher.colossus`.

## Code

- `scripts/slasher/slasher_colossus.gd`: patterns, phases, telegraphs, boss bar.
- `scripts/slasher/slasher_colossus_weak_point.gd`: the heart and fists.
- `ForestRoomLibrary`: the `O` (colossus) symbol and the `guardian` role.
- Test: `tests/colossus_test.gd`.
