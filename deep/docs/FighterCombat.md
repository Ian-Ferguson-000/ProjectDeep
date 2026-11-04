# Fighter Combat Feel

## The swing chain

The Fighter's three-swing chain is tuned to flow rather than stop-start:

| Change | Before | Now | Setting |
| --- | --- | --- | --- |
| **Input buffer** | A click during a swing was thrown away | A press within 0.25 s of an action being ready fires the moment it is (swings, special, dodge, sidearm) | `slasher_balance.json → input.buffer_window`, `buffered_slots` |
| **Holding attack** | Held swings were 2.25× slower than clicking | Holding chains at full speed for the Fighter | `input.held_basic_cooldown_multiplier_by_class.warrior` |
| **After the third swing** | 0.90 s pause | 0.42 s | `classes.warrior.basic.combo_finisher_cooldown` |
| **Chain window** | 0.70 s to keep the chain going | 0.85 s | `combo_reset_window` |
| **Forward step** | Swings stood still | Each swing steps forward 10 / 10 / 22 px | `lunge`, `lunge_time` |
| **Third swing** | Same as the others | 1.8× knockback and a 24° wider arc | `finisher_knockback_multiplier`, `finisher_arc_bonus` |
| **On-screen text** | "SLASH 2/3 · …" and "… is cooling down." | Gone. A finished named combo (e.g. Crosscut) still flashes briefly | — |

## Sidearm (secondary weapon)

Fighters have a new **Secondary** equipment slot (Hearth → Company → Equipment,
and the Set Out Gear step). The sidearm is used with **F** (controller **RB**)
and shows bottom-right on the HUD with a cooldown sweep.

| Sidearm | Thrust | Damage | Cooldown | Where |
| --- | --- | --- | --- | --- |
| **Hunting Spear** (common) | 220 px straight ahead, 30 px wide, hits every foe in the line, shoves them back | Strength damage (same as a swing) | 1.1 s | Every company gets one free; Tessaly Vane sells them; merchants and forest drops |
| **Boar Pike** (uncommon) | 270 px, 38 px wide, bigger shove | About 1⅓× a swing (4 at STR 15, capped at 4) | 1.0 s | Tessaly Vane (Acquaintance); merchants and forest drops |

Sidearms are items with `"slot": "secondary"` and a `secondary` block in
`data/hearth_campaign.json` (`kind`, `reach`, `width`, `cooldown`,
`damage_ratio`, `knockback`); their damage stat is in
`simple_combat.weapon_stats`. Only Fighters can carry one for now
(`HearthArmory.SECONDARY_CLASSES`). The thrust is the only kind so far;
other kinds (a throwing axe, a shield bash) would be added in
`SlasherPlayer.use_secondary`.

## Testing note

Dexterity's dodge is seeded from the run, so a random-seed run can dodge a
hit a test expects to land. Tests that need every hit to land set
`SimpleCombat.dodge_override = 0.0` at the start.

## Code

- `scripts/slasher/slasher_player.gd`: `_buffer`, `_lunge`, the chain in
  `use_action`, `use_secondary`, `SpearStreak`.
- `scripts/ui/dungeon_hud.gd → SecondarySlot`; `RunState.secondary_weapon_id()`.
- Test: `tests/fighter_feel_test.gd`.
