# Layered Combat Stats and Relic Effects

Combat uses a single attack pipeline for heroes and enemies:

1. Roll d20 + Accuracy.
2. If the total does not surpass Armor Class, an armed defensive reaction is provoked.
3. If the total does not surpass Evasion, the attack misses.
4. On a hit, Penetration reduces both Threshold and the applicable typed Aegis.
5. Raw damage must exceed the effective Threshold or it is completely stopped.
6. Effective Aegis is subtracted from damage that passes Threshold.

## Stats

- **Accuracy:** added to attack rolls.
- **Armor Class:** the total an attacker must surpass to avoid provoking an armed reaction.
- **Evasion:** the total an attacker must surpass to connect.
- **Threshold:** damage must exceed this value after Penetration or deal zero damage.
- **Aegis:** flat damage reduction, globally or by physical, fire, cold, lightning, arcane, radiant, necrotic, and poison damage.
- **Penetration:** reduces Threshold and Aegis for an attack.
- **Attack Power:** increases martial damage.
- **Spell Potency:** increases magical damage.
- **Range:** increases applicable attack or ability reach in tiles.

Legacy progression modifiers remain readable during migration: attack_bonus also raises Attack Power, spell_power raises Spell Potency, defense raises Armor Class, and block_bonus raises Threshold. New relics do not use those legacy names.

## Item Data

Base identity, rarity, duration, tags, and icons remain in data/items.json. Mechanical upgrades live in data/item_effects.json and are merged by GameBalance.

Each upgrade can provide always-on modifiers, player-facing rules text, contextual modifiers, triggered effects, and per-turn, per-combat, or per-floor limits. Conditions cover attack order, positioning, health, movement, target state, and damage type. Events cover hits, misses, reactions, potions, healing, kills, loot, floor clears, forced movement, and lethal damage.

Item rules are shown on reward cards and relic tooltips. Add new conditions in RunState._item_condition_matches and new events at the authoritative combat transition where they occur.
