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
- Other classes use their own main stat for now (`damage_stat_by_class`:
  Mage INT, Rogue DEX, Healer/Summoner WIS, Tank STR) so they still play, but
  they haven't been balanced.
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
