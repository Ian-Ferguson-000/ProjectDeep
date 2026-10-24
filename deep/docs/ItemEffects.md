# Item effects (real-time combat)

All pickup items live in `data/pickup_items.json`. This page covers the
effects that change how combat *feels*: speed stats and **procs** (special
effects such as fire crescents and chain lightning). Everything is data, so a
new item only needs a JSON block.

## Speed stats

Put these under `stats`:

| Stat | Meaning |
| --- | --- |
| `attack_speed` | Basic attacks recharge this many percent faster. `15` = 15% faster. Stacks additively, capped at +100%. |
| `move_speed` | Move this many percent faster. Stacks multiplicatively with other speed items. |

```json
"duelists_whetstone": {
  "name": "Duelist's Whetstone", "rarity": "common", "lasts": "run",
  "description": "A few passes and the blade feels half its weight.",
  "stats": {"attack_speed": 15},
  "combat": {"rules": "Basic attacks are 15% faster."}
}
```

## Procs

Add a `procs` list inside `combat`. Each proc has a `type` and an `on`:

| `on` | When it fires |
| --- | --- |
| `swing` | You use your basic attack (sword swing, basic cast) |
| `special` | You use your special |
| `dash` | You use your movement ability |
| `hit` | One of your attacks strikes an enemy |
| `kill` | You kill an enemy |

Options every proc understands:

| Option | Default | Meaning |
| --- | --- | --- |
| `chance` | 1 | 0–1 chance each time it could fire |
| `every` | 1 | Only fire every Nth time (3 = every third swing) |
| `cooldown` | 0 | Seconds before it can fire again |
| `message` | none | Popup text when it fires |

Damage is `damage_percent` of the attack that caused the proc, plus flat `damage`.

### Types

- **`wave`**: a crescent that flies forward, passes through enemies and stops at walls.
  `element` (fire, wind, lightning, ice, poison, arcane), `damage_percent`, `damage`,
  `range` (260), `speed` (520), `width` (34), `count` + `spread_degrees` for a fan,
  `color` (hex, overrides the element colour), and optional `burn` / `chill`
  blocks that apply to everything it hits.
- **`chain_lightning`**: leaps from the struck enemy to the nearest others.
  `damage_percent`, `damage`, `jumps` (3), `jump_range` (170).
- **`burn`**: sets the target alight. `damage` per half-second tick, `damage_percent`, `duration` (3).
- **`chill`**: slows the target. `slow` (0.5 = half speed), `duration` (1.5).
- **`nova`**: a burst around the target (or around you for swing/special/dash).
  `damage_percent`, `damage`, `radius` (80), `element`, `knockback`.
- **`heal`**: `amount`.

Attacks made by procs never trigger further procs, so lightning can't chain forever.
The exception is burn ticks, which can trigger `kill` procs.

### Examples

A sword that throws fire every third swing:

```json
"procs": [
  {"type": "wave", "on": "swing", "every": 3, "element": "fire", "damage_percent": 70,
   "range": 280, "width": 36, "burn": {"damage": 1, "duration": 2.5}}
]
```

Lightning that jumps on 20% of hits:

```json
"procs": [
  {"type": "chain_lightning", "on": "hit", "chance": 0.2, "damage_percent": 60, "jumps": 3, "cooldown": 0.35}
]
```

A fan of three ice crescents on every fourth swing that also slows:

```json
"procs": [
  {"type": "wave", "on": "swing", "every": 4, "count": 3, "spread_degrees": 20, "element": "ice",
   "damage_percent": 40, "chill": {"slow": 0.5, "duration": 1.2}}
]
```

## Items added with this system

| Group | Item | Effect |
| --- | --- | --- |
| Any class | Windrunner Boots | +12% move speed |
| Any class | Quicksilver Locket | +12% attack speed, +8% move speed |
| Any class | Cinder Brand | 25% of hits burn |
| Any class | Rimefrost Chain | 35% of hits chill |
| Any class | Bursting Spore Sac | Kills burst in spores |
| Any class | Thunderheart Amulet | 50% of kills release chain lightning |
| Melee only | Emberwind Edge | Every third swing throws a burning fire crescent |
| Melee only | Galecutter Charm | 30% of swings throw a wind crescent |
| Melee only | Stormcall Pommel | 20% of hits chain lightning |
| Melee only | Duelist's Whetstone | +15% attack speed |
| Melee only | Tempest Brand | +10% attack speed; every fourth swing fires three lightning crescents |
| Ranged only | Conductor's Rod | 25% of spell hits chain lightning |
| Ranged only | Quickcast Band | +15% attack speed |
| Ranged only | Pyre Lantern | Kills erupt in flame |
| Ranged only | Zephyr Quill | 25% of basic casts also throw a wind crescent |

Starfallen Sigil now uses a `nova` proc on specials.

## Code

- `scripts/slasher/slasher_item_procs.gd`: runs procs, burning, chilling, lightning and nova visuals.
- `scripts/slasher/slasher_item_wave.gd`: the crescent projectile.
- `SlasherPlayer._strike` / `on_item_enemy_hit`: every melee, line, area, projectile and kit hit reports to items.
- `SlasherItemRuntime`: `attack_speed_multiplier`, `adjust_for_target` (elite bonus), and `periodic` relics.
- Tests: `tests/item_effects_test.gd`.
