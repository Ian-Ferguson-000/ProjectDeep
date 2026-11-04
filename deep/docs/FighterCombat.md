# Fighter Combat Feel

## The swing chain

The Fighter's three-swing chain is tuned to flow rather than stop-start:

| Change | Before | Now | Setting |
| --- | --- | --- | --- |
| **Input buffer** | A click during a swing was thrown away | A press within 0.25 s of an action being ready fires the moment it is (swings, special, dodge) | `slasher_balance.json → input.buffer_window`, `buffered_slots` |
| **Holding attack** | Held swings were 2.25× slower than clicking | Holding chains at full speed for the Fighter | `input.held_basic_cooldown_multiplier_by_class.warrior` |
| **After the third swing** | 0.90 s pause | 0.42 s | `classes.warrior.basic.combo_finisher_cooldown` |
| **Chain window** | 0.70 s to keep the chain going | 0.85 s | `combo_reset_window` |
| **Forward step** | Swings stood still | Each swing steps forward 10 / 10 / 22 px | `lunge`, `lunge_time` |
| **Third swing** | Same as the others | 1.8× knockback and a 24° wider arc | `finisher_knockback_multiplier`, `finisher_arc_bonus` |
| **On-screen text** | "SLASH 2/3 · …" and "… is cooling down." | Gone. A finished named combo (e.g. Crosscut) still flashes briefly | — |

## Sword or spear

Like Hades' weapons, the spear is a Fighter weapon of its own with its own
moveset, not an add-on. **Each Fighter arrives with one or the other**
(picked when they're generated; the tutorial's Alden and the founding
Fighter keep the sword). The weapon can still be swapped in the Armory.

| | Sword and Shield | Borderkeeper's Spear |
| --- | --- | --- |
| **Attack** | Three-swing chain in a wide arc in front | **Measured Thrust**: a long, narrow thrust down a line (about 260 px); the tip hits hardest and gives Stamina |
| **Special (Space)** | Charge | **Hold the Pass**: plants a lane ahead that hurts anything crossing it, once |
| **Defend (Shift+click)** | Block with the shield | **Yielding Guard**: step back behind the shaft |
| **Dodge (right click)** | Charge dash | **Flank March**: a quick sideways step |
| **Damage stat** | Strength | Strength |

The spear's moveset is the existing warrior kit `borderkeepers_spear`
(`scripts/slasher/slasher_warrior_kit.gd`); its catalog entry is in
`data/hearth_campaign.json`. Recruits' starting weapons per class are
`CampaignState.STARTER_WEAPONS` (`{"warrior": ["sword_shield",
"borderkeepers_spear"]}`); add a class or a third weapon there. Tessaly Vane
also sells the spear.

**Art needed:** the Fighter's sprite still holds a sword with the spear
equipped; a spear-holding Fighter sprite (and a thrust animation) would make
it read properly.

## Testing note

Dexterity's dodge is seeded from the run, so a random-seed run can dodge a
hit a test expects to land. Tests that need every hit to land set
`SimpleCombat.dodge_override = 0.0` at the start.

## Code

- `scripts/slasher/slasher_player.gd`: `_buffer`, `_lunge`, the chain in
  `use_action`, `use_secondary`, `SpearStreak`.
- `scripts/ui/dungeon_hud.gd → SecondarySlot`; `RunState.secondary_weapon_id()`.
- Test: `tests/fighter_feel_test.gd`.
