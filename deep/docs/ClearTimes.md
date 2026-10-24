# Clear times (replaying dungeons)

Dungeons are never finished. Every run that defeats a dungeon's guardian is a
**clear**, and the measure of success is how fast you did it.

## What is recorded

`CampaignState.clear_records` (see `scripts/game/clear_records.gd`):

- **Record**: the fastest clear of each dungeon, with the hero and class.
- **Best per class**: the fastest Warrior, Mage, Rogue... clear of each dungeon.
- **Clears**: how many times the guardian has fallen.
- **Recent clears**: the last 10 runs, flagged when they set a record or class best.

Records survive Hearth loops (the world crisis reset). Tutorial runs never count.

## The clock

- Runs only while you are inside a dungeon and playing: it stops for menus,
  relic choices, shops, the Hearth checkpoint between floors, and once the
  guardian has fallen.
- `ExpeditionState.dungeon_seconds` is the time in the current dungeon (this is
  what a clear records); `run_seconds` is the whole expedition, including
  connected dungeons. Both are saved, so a resumed run keeps its time.
- The dungeon HUD shows the clock under the objective bar with your class's best
  as the target; it turns red once you are behind it.

## Where it shows

- **Hearth → Records → Best Times**: every dungeon's record, best per class and recent runs.
- **Expeditions**: a "Time to beat" card with the record and the selected adventurers' class bests.
- **Results screen**: the clear time, with "New Record!" or "New Warrior Best!" when earned.
- **Save slots**: total clears.

## Unlocks

The first time a guardian falls still unlocks what it always did (new classes,
the next dungeons, dispatching parties there). That is the only thing
`completed_dungeons` is used for now; nothing is marked "complete" and every
dungeon stays open to replay.
