# The Stone Crypt

The crypt now plays like the forest: each floor is a map of rooms you clear
one at a time, Isaac style, with everything the forest has (minimap, doors
that open when a room is clear, gate room with a skull over its door, camp,
treasure and campfire rooms, the trader, loot caches, enemy drops, hidden
chests, clear times, bounties and unlocks). Five floors: floor 3 is the elite
floor, floor 5 the guardian floor.

## Rooms

- Painted scenes in `maps/crypt/rooms/`, **1.5x the forest's size**: 41x23
  standard, 53x29 large. See `maps/crypt/README.md` for painting them.
- Stone walls are drawn by the game around each room (and around solid blocks
  painted with the wall marker). Doors are barred with **iron bars** while foes
  remain.
- Pits block movement; carpet laid across a pit is a bridge.
- The gate room has **stairs down**.
- **Hazards:** fighting rooms get crypt hazards while foes remain: bone spikes
  from floor 1, a curse sigil from floor 2, soulflame from floor 3 (up to three
  per room). They switch off when the room is cleared.
- **Hidden chest:** one coffin in some rooms is a shade darker and hides a
  keyless chest (as the forest's hollow trees do). Tuning:
  `slasher_balance.json → breakable_props.coffin.hollow_chance`.
- Room count and foes per room: `dungeons.json → crypt.slasher.room_count`
  (`foes_base` 4, `foes_per_floor` 0.6, more than the forest because the rooms
  are bigger).
- Large rooms are bigger than the screen; in the guardian arena the camera
  pulls back (`guardian_camera_zoom`).

## Guardians

- **Every floor's stairs are held by the Crypt Lord** (the old crypt boss, as a
  mini boss at 55% health: `crypt_lord.gate_health_scale`). Killing it scatters
  the rest of the room and opens the stairs.
- **Elite rooms** have a **Tomb Guard champion** (bigger, elite health).
- **Floor 5:** **Big Skelly Boi** in the Charnel Throne (below).

Set in `dungeons.json → crypt.slasher`: `gate_guardian`, `elite_room_guardian`,
`colossus`.

## Foes

Plain foes get more varied the deeper you go:

| Floor | Adds |
| --- | --- |
| 1 | Risen Skeleton, Grave Rat, Ghoul, Skeletal Archer |
| 2 | Gravedigger, Revenant |
| 3 | Grave Acolyte, Tomb Guard |
| 4+ | Soul Wisp |

| Foe | What it does | How to beat it |
| --- | --- | --- |
| **Grave Rat** (new) | Hides under a bone pile in nests of three; wakes its nest when you come close, then swarms and bites | Fragile; back off as they wake and swing into the pack |
| **Ghoul** (new) | Circles you, then lunges through with its claws | Step aside when it crouches |
| **Gravedigger** (new) | Keeps its distance and throws bones (three at once from floor 3) | Close in; it backs away slowly |
| **Tomb Guard** (new) | Shield blocks every hit from the front; turns slowly; shield bash | Get behind it, or let it bash: its shield is down for ~1.3 s after |
| **Revenant** (new) | Collapses into bones when killed, rises at half health after 3.5 s | Hit the bone pile before the green ring fills |
| Risen Skeleton, Skeletal Archer, Grave Acolyte, Soul Wisp | As before | |

All numbers are in `slasher_balance.json → enemies.<id>`. The new foes reuse
existing behaviours under their own names where they fit (`behaves_like`:
Grave Rat fights like a sporeling, Ghoul like a cutthroat, Gravedigger like a
knife-thrower).

### Sprites still needed

The new foes **borrow other enemies' sprites** under their own names, so new
art can be dropped in without touching code (`slasher_balance.json →
enemy_visuals.<id>`; remove `art`/`tint`/`desaturate` once real art exists in
`assets/enemies/<id>/frames.tres`):

| Foe | Borrows | Recoloured |
| --- | --- | --- |
| Grave Rat | Ash Rat | greyed out |
| Ghoul | Drowned Foreman | pale green |
| Gravedigger | Blighted Farmhand | greyed a little |
| Tomb Guard | Moon Court Huntress | grey |
| Revenant | Skeleton | pale green |

Also wanted: **Big Skelly Boi** (body, soul gem and hand textures; see below),
proper crypt floor tiles (the current ones are cut from the stone sheet), and
optionally a brazier to replace the campfire in crypt camps.

## Big Skelly Boi (floor 5)

A giant crowned skeleton sunk to the chest in the middle of a 53x29 arena,
fought like the Heartwood Colossus: it never moves, every attack is
telegraphed, and after each one a weak point opens with a "!" and a shrinking
ring. Its body can't be hurt.

| Attack | Warning | Then |
| --- | --- | --- |
| **Grave Sweep** | A red striped lane across the arena through you, with an arrow showing the direction | A giant hand sweeps along it; the **hand lies open** at the far end |
| **Soul Wail** | The jaw drops and blue rings pull into its mouth | Three rings of souls (four in phase three), **each with a gap**; the gap moves each wave. Then the **soul gem** opens |
| **Bone Rain** (phase two on) | Pale circles around you, the first right under you, filling up | Bones crash down on each in turn and splinter; then the **soul gem** opens |

- Phases at 66% and 33% health: it roars, clears the bullets and speeds up.
  From phase two it sweeps **two lanes** at once (one hand each way, never
  across its own body) and uses Bone Rain; phase three adds a wail wave and
  calls revenants and grave rats.
- When it falls, the dead in the room crumble, the stairs open, and a heap of
  bones is left where it stood.
- Health bar centred across the top of the screen, with notches at the phase thresholds.
- Tuning: `slasher_balance.json → enemies.charnel_king`.
- **Art:** set `body_texture`, `heart_texture` (the soul gem) and
  `fist_texture` (an open hand) on the King, exactly as for the Colossus (see
  docs/HeartwoodColossus.md). Telegraphs and bullets stay drawn in code.

## The forest change

The forest's **reflecting Elite Guardian** (the briar guardian that answers
every hit with a ring of thorns) now holds the **gate room on every forest
floor**, not just floor 3; floor 5 is still the Heartwood Colossus. Set with
`dungeons.json → forest.slasher.gate_guardian.every_floor`.

## Code

- `scripts/slasher/slasher_crypt.gd`: the crypt scene (extends the forest's
  room scene; `_room_theme()` swaps walls, bars, stairs and wording; hazards,
  roster, rat nests).
- `scripts/slasher/slasher_forest_rooms.gd`: rooms for any dungeon, gate and
  elite guardians, arena zoom.
- `scripts/slasher/slasher_crypt_creature.gd`: grave rat, ghoul, gravedigger,
  tomb guard, revenant.
- `scripts/slasher/slasher_charnel_king.gd`: Big Skelly Boi (extends
  `slasher_colossus.gd`).
- `ForestRoomLibrary.use_dungeon()`: which dungeon's rooms are in use.
- Test: `tests/crypt_rooms_test.gd`.
