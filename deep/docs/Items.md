# Items: rarity, duration and the any-class list

## Rules

- **Every item lasts the whole run.** It's lost when the expedition ends
  (`lasts: "run"` on every item in `data/pickup_items.json`).
- **Rarity and drop rates.** There's no Common tier any more (the old commons are
  Uncommon). Whenever an item is rolled (chests, treasure rooms, mini-boss
  relics, the trader's bonus slots), its rarity is:

  | Uncommon | Rare | Very Rare | Legendary |
  | --- | --- | --- | --- |
  | 60% | 25% | 14% | 1% |

  The same on every floor (`data/loot_tables.json`, and `tier_weights` in
  `data/trader.json`). Endless mode still shifts these upward each cycle. The
  Hearth's Appraisal upgrade now only improves recovered equipment; it no longer
  caps dungeon relics. The trader's three always-there slots hold Uncommons, and
  Hearth merchants stock 5 of an Uncommon.
- **Dexterity is walking speed** for every class (docs/SimpleCombat.md). Items
  that make you faster add Dexterity: `"dex": 1` is +1 DEX. An item with a
  percentage move-speed bonus counts as +1.

## Item stats (Isaac style, all stack)

| Stat | Isaac name | Does |
| --- | --- | --- |
| `damage` | Damage Up | +N damage on every hit, after the 1–4 hit |
| `boss_damage` | | +N more against elites, mini bosses and bosses |
| `attack_speed` | Tears Up (attack speed) | % faster basic attacks |
| `dex` | Speed Up | +1 Dexterity: faster walking |
| `max_health` | Health Up | +1 heart container each, filled |
| `soul_hearts` | Soul hearts | Soul hearts, once, when picked up |
| `range` | Range Up | Longer reach and projectiles |
| `luck` | Luck Up | +5% to chance effects and room-clear drops |
| `cooldown_percent` | | % faster ability recharge (cap 35%) |
| `gold_bonus_percent` | | A chance of an extra coin |
| `potion_heal_bonus` | | Potions heal this many more half hearts |
| `xp_bonus_percent` | | XP only; doesn't drop while levelling is off |

Block chance became soul hearts (2–6% = 1, 10–15% = 2, 22% = 3), dodge became
+1 Dexterity, and "every Nth hit" became Luck Up (docs/IsaacRules.md).

Item procs (crescents, lightning, burning, chill, novas) carry their own damage
and don't get `damage`, `boss_damage` or precision on top.

How the old turn-based stats were converted: attack/spell power 1–2 became +1
`damage`, 3–5 became +2; penetration became `boss_damage` one for one (and
Giant-Bane Grip's +16% against elites became +1); armour and threshold became 5%
`block_percent` a point, and elemental aegis 2% a point; evasion became 5%
`dodge_percent` a point; accuracy N became `precision_hits` 7 − N (Duelist Gloves
5); initiative became `cooldown_percent` (2.5% a point).

**Consumables** now read in real-time terms: healing potions restore hearts (5 or
9, plus potion healing); Warding and Firebreak Draughts block the next hit
completely; Fleet Draught is 30% faster for 6 s; Potion of Haste is double speed
for 6 s and a second off every cooldown; Potion of Fury doubles your next attack;
True-Strike Tonic gives your next hit +1 damage; Smoke Vial hides you for 5 s;
Focus Tonic and Resource Elixir restore your class resource. Drinking a potion with
the potion key now heals the potion's own amount (it healed 6 regardless).

## Any-class items (29)

| Item | Rarity | Does |
| --- | --- | --- |
| Charred Horseshoe | Uncommon | +1 Dexterity |
| Healer's Brooch | Uncommon | Kills have a 5% chance to drop a healing potion |
| Ironroot Ring | Uncommon | +1 heart |
| Quickstep Charm | Uncommon | +1 Dexterity |
| Scavenger's Token | Uncommon | +10% gold |
| Amulet of Vigor | Uncommon | +1 heart |
| Apothecary's Cup | Uncommon | +3 potion healing |
| Brambleguard Clasp | Uncommon | +2 hearts, 5% block |
| **Deft Hands** (new) | Uncommon | Weapon recovers 10% faster (attack speed +10%) |
| Cutpurse's Favor | Uncommon | Each hit has a 1% chance to knock 2–5 coins loose |
| Lucky Coin | Uncommon | +20% gold |
| Wayfinder's Compass | Uncommon | Abilities recharge 5% faster |
| Windrunner Boots | Uncommon | +1 Dexterity |
| Blackoak Ward | Rare | Blocks the first hit you take in each room |
| Boots of the Hare | Rare | +2 Dexterity |
| Gilded Beetle | Rare | +40% gold |
| Quicksilver Locket | Rare | Basic attacks 12% faster, +1 Dexterity |
| Saint's Phial | Rare | +3 hearts, +3 potion healing |
| Rimefrost Chain | Rare | 35% of hits chill (slow) for 1.6 s |
| War Scholar's Codex | Rare | +20% XP (out of the drop pool while levelling is off) |
| Cinder Brand | Rare | 25% of hits set the enemy burning |
| Deepdelver's Lantern | Very Rare | +40% gold |
| Bursting Spore Sac | Very Rare | Kills burst into a damaging spore cloud |
| Kingsroad Aegis | Very Rare | +4 hearts, 15% block |
| Sunward Periapt | Very Rare | +2 hearts, +2 Dexterity |
| Thunderheart Amulet | Very Rare | Kills have a 50% chance to chain lightning through up to 4 foes |
| Aegis of the Last King | Legendary | Survive one lethal hit per floor |
| Fortune-Eater's Idol | Legendary | +60% gold |
| Heartwood Crown | Legendary | +1 heart; recover 1 heart on each floor entry |

"Hearts" are the item's `max_health`: in simple combat 1 health is 1 heart.

## Removed (kept for later)

Mender's Sachet, Soldier's Buckle, Windknotted Thread, Harvester's Gloves,
Redstep Spurs, Moonleaf Cloak, Pilgrim's Greaves, Cinderheart Locket and
Starfallen Sigil are in `data/unused/pickup_items_unused.json`, with the Hearth's
own copies of three of them. The game never reads that file. To bring one back,
move its block into `data/pickup_items.json`. Shops and visitors that sold them
now sell kept items instead, and the four mage trinkets that borrowed Starfallen
Sigil's shockwave (Watcher's Lantern, Moon Dial, Echo Prism, Unwritten Equation)
now borrow Thunderheart Amulet's chain lightning.

## New effects (for making more items)

- `combat.room_ward: true`: blocks the first hit in each room.
- Proc `drop_potion`: drops a healing potion (`on: "kill"`, `chance`).
- Proc `drop_gold`: drops `amount_min`–`amount_max` coins (`on: "hit"`, `chance`).

Tests: `tests/item_effects_test.gd` (Dexterity speed, Deft Hands, Blackoak Ward,
the brooch and purse drops), `tests/trader_test.gd`, `tests/pickup_items_test.gd`.
