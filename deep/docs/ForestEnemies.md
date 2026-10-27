# Forest enemies: Sporelings and Kobold bandits

Code: `scripts/slasher/slasher_forest_creature.gd` (behaviour) and
`scripts/slasher/forest_creature_art.gd` (sprite frames built at runtime from
existing sheets, so no prefab scenes are needed). Numbers live in
`data/slasher_balance.json` under `enemies.<id>`; sprite scale, tint and
health-bar height under `enemy_visuals.<id>`. Bestiary text is in
`data/slasher_journal.json`.

| Id | Art | Behaviour |
| --- | --- | --- |
| `sporeling` | `assets/pixel_art/shroomie.png` + `shroomie - wakeup.png` | Spawns in clusters of 3 (4 from floor 3) lying dormant as plain mushroom caps, with no health bar. Wakes when you come within `wake_radius` or hit one, waking every sporeling within `wake_chain_radius`. Then it swarms, telegraphs a short hop and nibbles. Melee only. |
| `bandit_cutthroat` | Kobold sheet | Circles at `circle_range`, then crouches (`lunge_windup`, with a telegraph line) and lunges `lunge_distance` through you. |
| `bandit_knifethrower` | Kobold sheet, tinted | Keeps `preferred_range`, backs off inside `retreat_range`, throws spinning knives; every third throw is a fan of three from `fan_floor`. |

The forest's enemy list is in `scripts/game/dungeon_runtime_profile.gd`
(`forest.slasher_enemies`). Wolves still make up about half of each room.
