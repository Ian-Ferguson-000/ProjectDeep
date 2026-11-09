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
in `game/items/slasher_active_effects.gd` (`use()`, plus an icon in
`draw_icon()`). Icons are drawn in code until there's art.

## Code

The mage arsenal's current controls, tuning, limits, and verification are
documented in [MageActiveItemsProduction.md](MageActiveItemsProduction.md).

- `game/core/active_items.gd`: the data, the slot (in `run_stats.active_item`), charging.
- `game/items/slasher_active_effects.gd`: what each kind does, and the icons.
- `SlasherForest.use_active_item / _process_active_item`: Space, timer charge, HUD.
- `slasher_forest_rooms.gd`: room clears charge it; treasure pedestals and swapping.
- `DungeonHud.ActiveSlot`: the HUD slot.
- Test: `tests/items/active_items_test.gd`.

## Dev Mode

The main screen exposes a persistent **Dev Mode** toggle for combat testing. It
keeps normal mechanics intact while active-item recharge runs at 5× speed and
ordinary enemy loot rolls are tripled. Enemies no longer drop active items at all
(docs/Materials.md); active items come from chests, pedestals and traders. Picking up one opens
a three-card choice of unique, class-valid active items. An item swapped onto the
ground remains an exact pickup instead of generating another choice. Dev Mode is
disabled by default.

## Armory testing ground

The Hearth armory opens its testing ground directly as a playable level-one
Fighter with the standard sword-and-shield kit. There is no player-facing build
form in this room:

- Six podiums along the left wall swap the player to that class's standard,
  level-one build on contact.
- Every active item is mounted in floating rows along the upper and lower
  walls. Walk into a compatible display to equip it; the current item is
  replaced immediately and fully charged.
- Neutral items remain equipped across class changes. Class-specific items are
  cleared when changing to a class that cannot use them.
- **Space** activates the held item. Testing-ground items refill after 1.25
  seconds, or immediately with **B**, so repeated mechanical tests do not
  require clearing rooms.
- **R** resets the targets without changing the current class or held item.
- The proving floor is an expanded 1800×900 space with a clamped follow camera.
  In **Live enemies** mode, each defeated combatant returns at its training
  point after three seconds without resetting the player or the other enemies.
- Testing-ground buttons cannot retain keyboard focus, preventing **Space**
  from accidentally re-triggering Reset or a scenario button instead of the
  active item.

The detailed form controls still exist off-screen as an automation harness for
kit and progression regression tests; they are not part of the player-facing
armory flow.
