# Tavern Guide

A short walk-through of the tavern, shown the first time the tavern is free
after the tutorial run (after the epilogue story and any arrivals). It opens
each Hearth page for real and puts a pulsing spotlight on the button it's
explaining; the player clicks Next / Back or Skip guide.

Steps: welcome · the toolbar (and visitors) · Company (roster, mood, leaving) ·
Training (once a day, gold cost, chance, practice, rooms and furnishings,
happiness cost) · Lodgings · the pantry (food quality, hunger, 2 rations a run)
· Facilities (expanding with gold and renown) · Armory · Bounties · passing
time (shifts and days) · setting out (forest first, crypt beyond, saves every
room) · the Esc menu.

- Seen once per save: `tavern_dialogue_flags.tavern_tour_done` (no save format
  change). Finishing or skipping both count.
- Replay any time: Esc → **Tavern Guide**.
- Wording and order: `STEPS` in `game/tavern/tavern_tour.gd`. Each step names a
  Hearth `page` to open (`""` = the tavern floor) and a `target` node to
  spotlight (Hearth tabs are named `<Page>Tab`, sidebar buttons `<Group>Nav`,
  plus `AdvanceShiftButton` and `TavernToolbar`).
- Wired up in `tavern.gd` (`_maybe_start_tavern_tour`, `start_tavern_tour`).
- Test: `tests/tavern/tavern_tour_test.gd` checks every step's page and spotlight.
