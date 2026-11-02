# Run Seeds

Every run is built from one seed, shown as an 8-character code like
`K7QF-2MXA`. Play the same seed again and you get the same run.

**Same with the same seed:** the floor maps, which room template each room
uses, the foes in every room and where they stand, the gate guardian pick,
hidden chests, chest and trader stock, active-item pedestals, and enemy and
room drops (seeded per room).

**Still random:** combat rolls (crits, item procs, boss attack choices), so
fights play out differently. Drops can also differ if you kill things in a
different order, since each room's drops are one sequence.

## Using seeds

- **Set Out → Gear & Supplies → Run seed:** type a code, or pick one from
  **Saved seeds**. Leave it blank for a random run. Codes ignore case, spaces
  and dashes; an invalid code blocks Set Out and says why.
- **In a run:** the Esc menu shows the seed with **Copy** (to the clipboard)
  and **Save** (adds it to the saved list with the dungeon and floor as a
  note). "(chosen)" marks a run started from a typed seed.
- Saved seeds live in `user://saved_seeds.json` (up to 50, newest first),
  shared by every save slot on that machine.

Seeded runs currently count for records, bounties and unlocks like any
other run. `RunState.run_seeded` is set if that should change later.

## Cost

A seed is one number, saved with the run (`run_seed` in the run snapshot).
Everything is generated from it as you go, so seeds cost no extra memory or
save space.

## Code

- `scripts/game/run_seed.gd` (`RunSeed`): encode/decode, random seeds, saved list.
- `RunState.requested_seed` (set before `start_new_run`, used once),
  `run_seed`, `run_seeded`, `seed_code()`.
- Drops: `slasher_forest.gd → drop_rng()` seeded from the floor seed and
  `_drop_seed_key()` (the room, in room scenes).
- Test: `tests/run_seed_test.gd` builds the same seed twice and compares the
  floor map, rooms, foes, drops and trader.
