# Active items

One slot, Isaac style, used with **Space** (the special button; on a
controller, whatever the special is bound to). The slot sits in the
bottom-left corner of the HUD, next to the potion pocket.

- **Charge:** each item either needs a number of **room clears** (shown as pips
  down the side of the slot) or recharges on a **timer** (a filling bar). The
  slot glows gold when it's ready. Pressing Space before then says it's still
  charging.
- **Finding them:** treasure rooms. The first treasure room of a run always
  holds one while your slot is empty; after that a treasure room has a 35%
  chance (`treasure_chance`) of an active item on its pedestal instead of a
  relic.
- **Picking up:** walk onto the pedestal with an empty slot. With an item
  already held, press **E** to swap: your old item is left on the pedestal, so
  you can change your mind. The room remembers what's on it.
- New items arrive fully charged. Your item and its charge are kept for the
  whole expedition, including into the next dungeon, and saved with it.
- Classes don't start with one yet (planned for upgraded adventurers).
- While you hold an item, Space uses it rather than the class special (which is
  switched off for now anyway).

## Warrior items

| Item | Charge | Does |
| --- | --- | --- |
| **Shadow Step** | 3.5 s timer | Dash ~4 cells the way you're moving (or aiming), untouchable while you do |
| **Whirlwind** | 2 rooms | Hit everything within ~2.5 cells for 3x your basic damage and throw it back |
| **Earthsplitter** | 2 rooms | A crack along the ground ahead (~8 cells): 2.5x damage and a long stun |
| **War Horn** | 3 rooms | 6 seconds of +50% damage and 40% faster swings; knocks nearby foes back |
| **Iron Skin** | 3 rooms | A ward that soaks up 2 hearts of damage for 10 seconds |

Damage scales from the hero's basic attack, so items keep up as you get stronger.

## Adding items

`data/active_items.json`: name, description, `charge` ("rooms" with `rooms`,
or "timer" with `seconds`), `classes`, and an `effect` whose `kind` is one of
dash, spin, line, rally, ward (with its numbers). A new kind of effect needs code
in `scripts/slasher/slasher_active_effects.gd` (`use()`, plus an icon in
`draw_icon()`). Icons are drawn in code until there's art.

## Code

- `scripts/game/active_items.gd`: the data, the slot (in `run_stats.active_item`), charging.
- `scripts/slasher/slasher_active_effects.gd`: what each kind does, and the icons.
- `SlasherForest.use_active_item / _process_active_item`: Space, timer charge, HUD.
- `slasher_forest_rooms.gd`: room clears charge it; treasure pedestals and swapping.
- `DungeonHud.ActiveSlot`: the HUD slot.
- Test: `tests/active_items_test.gd`.
