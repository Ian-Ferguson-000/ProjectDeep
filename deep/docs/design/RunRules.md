# Run rules

How a run in the dungeon plays: hearts, stats, enemies, pickups, floors and the
shop. It sits on top of our six attributes.

## Attributes

| Attribute | Does |
| --- | --- |
| STR / INT / WIS | Damage per hit with that weapon or kit (1–4) |
| DEX | Speed (walking), plus a little dodge |
| CON | Starting hearts (every 4 points is a heart) |
| CHA | Shop prices |

## Health

- Health is in **half hearts**. An ordinary enemy hit takes **half a heart**; a
  hit from a **boss, mini boss or champion takes a full heart**. Hearts cap at **12**.
- Healing: a heart pickup heals a heart, a half heart half; potions heal 1 or 2
  hearts. An item with `max_health` adds heart containers and fills them.
- Numbers: `slasher_balance.json → simple_combat` (`units_per_heart`,
  `enemy_hit_damage`, `strong_hit_damage`, `max_total_hearts`).

## Stats (HUD, right side under the clock)

**Speed** (from DEX), **Attack speed** (basic attacks a second), **Damage** (per
hit, items included), **Range** and **Luck**. Items raise them all and everything
stacks. Luck adds 5% a point to chance effects (burns, chills, lightning) and to
room-clear drops.

## Enemies

- Health is flat per kind; nothing grows with the floor (every `*_per_floor` is 0).
- **Champions:** any ordinary foe has a 10% chance (from the floor's seed) to
  spawn as a champion: double health, an orange tint, full-heart hits, and a
  pickup when it dies (`slasher_balance.json → enemies.forest_elite`).
- Kills give no coins. Basic enemies still sometimes drop crafting materials.

## Pickups and coins

- Clearing a fight has a **60% chance (+5% per luck) of one pickup** in the
  middle of the room: a coin (1, 5 or 10), a heart or half heart, or a key
  (`slasher_balance.json → pickups`).
- Hearts stay on the floor while you're at full health.
- Coins are scarce: a forest floor gives about **3–4 coins** (room clears and
  champions). Each **banks as 10 gold** at the Hearth, so the Hearth's economy is
  unchanged. Gold-find items give a chance of an extra coin.

## Floors

- Every floor: a start room, fights, an **elite room**, a **shop**, a **treasure
  room** (a free item) and the **boss room**, never entered from the north.
- **From floor 2 the treasure room is locked**: walk into its door with a key
  (keys come from room-clear drops).
- **Every boss leaves an item** (the floor's guardian and the colossus).
- **No campfire rooms**: healing comes from hearts
  (`dungeons.json → slasher.room_count.rest_room`, `locked_treasure_from_floor`).

## The shop

The trader stands back at a stall; **every offer lies on the floor** on a little
plinth with its price under it. **Stand on one** to see its name, rarity, price and
effect, then **press E to buy** (the tag says how many coins you're short). E at the
stall still opens the full list. Layout: `slasher_balance.json → shop_floor`.

The trader lays out **3 items**, each rolled at the stage's odds below. No hearts,
keys or other pickups. Prices, before Charisma (`data/trader.json → prices`):

| Uncommon | Rare | Very rare | Legendary |
| --- | --- | --- | --- |
| 3 | 5 | 8 | 12 |

So an uncommon costs about a floor's coins and a rare about a floor and a half.

## Item rarity by stage

Every item roll (chests, treasure rooms, boss items, trader slots) uses its
stage's odds, out of 100 (`data/loot_tables.json → rarity_weights_by_stage`):

| Stage | Uncommon | Rare | Very rare | Legendary |
| --- | --- | --- | --- | --- |
| Forest | 70 | 25 | 4 | 1 |
| Crypt | 60 | 25 | 10 | 5 |
| Hell | 40 | 40 | 10 | 10 |

If a stage rolls a rarity the class has run out of, it steps down a tier.

## Items

Stat items, all stacking (docs/systems/Items.md): `damage`, `attack_speed`, `dex`
(speed), `max_health` (heart containers), `range`, `luck`, plus damage against
bosses, faster ability recharge and gold-find. Blackoak Ward blocks the first hit
in each room.

Test: `tests/dungeons/run_rules_test.gd`.
