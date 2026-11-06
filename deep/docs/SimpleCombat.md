# Simple Combat Numbers

Small, readable numbers so the Fighter can be balanced by hand. All settings
are in `data/slasher_balance.json → "simple_combat"`; set `"enabled": false`
to return to the old numbers.

| Rule | Setting | Now |
| --- | --- | --- |
| **Health is hearts.** 1 health = 1 heart, no half hearts. | `hud.health_per_heart` | 1 |
| **Hearts from Constitution:** CON ÷ `con_per_heart`, rounded, at least `min_hearts`. | `con_per_heart`, `min_hearts` | CON 20 = 5 · 16 = 4 · 12 = 3 · 8 = 2 |
| **Fighter damage from Strength:** STR ÷ `stat_per_damage`, rounded, `min_damage`–`max_damage`. | `stat_per_damage`, `max_damage` | STR 20 = 4 · 15 = 3 · 10 = 2 · 5 = 1 |
| **Every enemy hit costs one heart**, after blocks: a fully blocked or parried hit still costs nothing. | `enemy_hit_damage` | 1 |
| **Enemy health** is multiplied when they spawn, so fights take about as many hits as before. | `enemy_health_scale` | 0.5 |

## What each stat does

| Stat | Does | Numbers |
| --- | --- | --- |
| **STR** | Damage with strength weapons: swords, spears, hammers, the greatsword, the tank's shields and maces | STR ÷ 5, rounded, 1–4 |
| **DEX** | **Walking speed for every class.** Also damage with dexterity weapons (daggers, bows, the sling, the crossbow) and a chance to dodge any hit completely ("Dodge!"). Items that make you faster add Dexterity | Speed 265 at DEX 10, ±10 per point (DEX 6 = 225, DEX 12 = 285, DEX 20 = 365; 180 to 420), `move_speed_*` in `simple_combat`. DEX ÷ 5 for damage; dodge 1% per point above 10, max 15% |
| **CON** | Hearts, for every class | CON ÷ 4, rounded |
| **INT** | Magic strength: the mage's foci (missiles, fireball, lightning) | INT ÷ 5, 1–4 |
| **WIS** | Summon strength: the summoner's bonded wolf hits with WIS (and the summoner's staffs) | WIS ÷ 5, 1–4 |
| **CHA** | Trader prices in the dungeon, and better odds on every training session at the Hearth. **Can't be trained.** | 3% off per point above 10 (CHA 20 = 30% off; CHA 6 = 12% dearer, limits 70–130%); training +2% per point above 10 (CHA 8 = −4%) |

**The weapon decides the stat, not the class.** A Fighter with the Dragonbone
Dagger or a bow hits with DEX; with a sword, STR. The map is
`simple_combat.weapon_stats` (any weapon not listed uses the class default in
`damage_stat_by_class`). The healer's staffs are set to INT for now (healing
counts as magic); change them there if they should use WIS. Attacks can set
their own stat with `"damage_stat"` (the summoner's wolf uses `"wis"`).

Dodge rolls come from the run's seed, so a seeded run dodges the same way.
Stat tooltips on the Company page and the recruitment dialogue show these
descriptions (`simple_combat.stat_descriptions`). On the Training page,
Charisma shows "Can't be trained" and the bonus it gives to every other
session.

## How player damage is worked out

Every player hit is converted where it lands
(`SlasherEnemy.receive_attack`): the Fighter's hit size from Strength, times
how big this hit was next to an ordinary swing, rounded and capped at 4. So
a swing does exactly the STR damage, and a special that used to hit twice as
hard does double, up to 4. Specials, combos, active items and item procs all
go through the same point.

Before this, a Fighter's swing did 6 at almost any Strength (attack power
barely moved below STR 20), so Strength didn't really matter; now it's the
whole of it. A STR 15 Fighter hits for 3, half the old 6, which is why enemy
health is halved.

## Things to tune next

- Enemy health per type is still the old numbers × 0.5 (a sporeling ≈ 3, a
  cutthroat on floor 1 ≈ 10, the Heartwood Colossus ≈ 190 plus per floor).
  For hand-tuned values, set `enemy_health_scale` to 1 and write the new
  health into `slasher_balance.json → enemies.<id>`.
- Bosses still take at most 5% of their health per hit and less while their
  damage shield is up (`boss_durability`).
- Items that add max health or damage still add their old amounts on top: an
  item giving +2 max health now gives +2 hearts.
- Other classes now follow the stat rules above through their weapons, but
  they haven't been balanced. Spells cast by a Fighter's active items still
  use the weapon's stat.
- Visitors' and suppliers' prices at the Hearth aren't affected by Charisma:
  you, the keeper, buy those, not the adventurer.
- The tutorial run is still capped at 3 hearts.

## Saves

Adventurers in older saves get their hearts from CON on load, keeping
roughly how hurt they were (8/16 health becomes 2/4 hearts). This happens
once: saves now record `"simple_hearts"`, so bonus hearts aren't undone.

## Code

- `scripts/game/simple_combat.gd` (`SimpleCombat`): the rules.
- Hearts: `AdventurerBuilds.max_health_for` and `RunState._derive_stats`.
- Player hits: `SlasherEnemy.receive_attack`; the player's `simple_base` and
  `simple_reference` are set in `SlasherPlayer._setup_simple_combat`.
- Enemy hits: `SlasherPlayer.receive_damage`.
- Enemy health: `SlasherEnemy._notification` (on ready).
- Test: `tests/simple_combat_test.gd`.
