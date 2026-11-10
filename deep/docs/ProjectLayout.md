# Project layout

Where everything lives, and where to start reading. The project is organised **by
feature**: each folder under `game/` holds the scripts *and* scenes for one part
of the game, so you rarely need to look in two places.

```
deep/
├── project.godot        Main scene: game/main/Main.tscn. Autoloads listed below.
├── game/                All live code and scenes, by feature (below).
├── data/                JSON tuning files: items, enemies, dungeons, balance. Edit these first.
├── maps/                Painted room and tile maps per dungeon (maps/<dungeon>/rooms/*.tscn).
├── assets/              Art, audio, fonts (unchanged by the reorganisation).
├── art_source/          Source files for generated art.
├── tests/               Automated tests, grouped like game/ (tests/<feature>/<name>_test.gd).
├── tools/               Python and Godot helper scripts; run_hearth_tests.py runs the tests.
├── docs/                Design notes, grouped by topic (docs/README.md is the index).
├── legacy/              Old and unused material, kept for reference. Godot ignores it.
└── build/               Scratch output from tests and captures. Safe to delete.
```

## game/: the code, by feature

| Folder | What's in it | Start with |
| --- | --- | --- |
| `main/` | The root scene that swaps title → class pick → tavern → dungeon, and those first screens. | `main.gd` |
| `core/` | Run and save state, balance lookups, combat maths, gear, unlocks. Everything else leans on these. | `run_state.gd`, `game_balance.gd`, `simple_combat.gd` |
| `campaign/` | The long game between runs: story, factions, world crisis, visitors, bounties. | `narrative_progression.gd` |
| `hearth/` | The tavern-as-a-business services: calendar, lodging, upkeep, armory, expeditions. | `hearth_calendar.gd` |
| `tavern/` | The tavern you walk around: `3d/` (the live tavern), `2d/` (the scene pieces the 3D one builds on), `contests/` (visitor mini-games). | `3d/tavern_3d.gd`, `tavern.gd` |
| `player/` | The adventurer in a dungeon: movement, attacks, buffs. `warrior/` and `mage/` hold each class's kit and combos. | `slasher_player.gd` |
| `items/` | Item effects in real time: stat runtime, procs, active items. | `slasher_item_runtime.gd` |
| `enemies/` | Enemy behaviour and art; `bosses/` (colossus, charnel king); `scenes/` (one prefab per enemy). | `slasher_enemy.gd` |
| `dungeons/shared/` | Everything every dungeon uses: the base dungeon, rooms and doors, pathfinding, minimaps, codex. `walls/`, `maps/`, `world_3d/` (the 3D room builder). | `slasher_forest.gd` → `slasher_forest_rooms.gd` |
| `dungeons/<name>/` | One folder per dungeon: forest and crypt (3D), hell, farmstead, mine, foundry, grove, archive (2D, Coming Soon), testing_ground (dev). | `forest/forest_3d.gd` |
| `ui/` | HUD, pause menu, shop panel, expedition screens; `hearth/` for the tavern management screens. | `dungeon_hud.gd` |
| `audio/` | Sound catalogue and cues (the `Audio` autoload). | `game_audio.gd` |
| `shared/` | Older building blocks still in use: the `GameState` autoload, runes and spells, damage packets, health and status components. | `game_state.gd` |

**Autoloads** (always loaded, in `project.godot`): `GameSettings` (core/game_settings.gd),
`Audio` (audio/game_audio.gd), `GameState` (shared/game_state.gd), `DevPerformanceOverlay`
(ui/dev_performance_overlay.gd).

### How a dungeon is built

The class chain, from general to specific:

```
dungeons/shared/slasher_forest.gd         the base: player, enemies, HUD, loot, one generated floor
  └─ dungeons/shared/slasher_forest_rooms.gd   rooms and doors, shops, treasure
       ├─ dungeons/forest/forest_3d.gd           the live forest: adds the 3D view (world_3d/)
       └─ dungeons/crypt/slasher_crypt.gd        the crypt's look and foes
            └─ dungeons/crypt/crypt_3d.gd        the live crypt, 3D
```

The 2D scenes (`dungeons/forest/SlasherForest.tscn` and the Coming Soon dungeons)
still matter: the 3D scenes run the same logic and only draw it in 3D.

## Names

Most dungeon-side files still start with `slasher_` (the game's working title for
the real-time mode). The prefix carries no meaning any more; dropping it is a good
first refactoring step now that the folders say what each file is.

## Biggest files (refactoring candidates)

| Lines | File |
| --- | --- |
| 2,840 | `game/tavern/tavern.gd` |
| 2,770 | `game/core/run_state.gd` |
| 2,755 | `game/dungeons/shared/slasher_forest.gd` |
| 2,510 | `game/player/warrior/slasher_fighter_arsenal.gd` |
| 2,490 | `game/ui/hearth/hearth_management.gd` |
| 2,275 | `game/player/slasher_player.gd` |
| 2,195 | `game/core/campaign_state.gd` |
| 2,015 | `game/dungeons/shared/slasher_forest_rooms.gd` |
| 1,995 | `game/player/mage/slasher_mage_active_arsenal.gd` |

## Code style

Every script under `game/`, `tests/` and `tools/` is formatted with
[gdformat](https://github.com/Scony/godot-gdscript-toolkit): one statement per
line, spaces around operators, 100-column lines. Keep it that way with
`gdformat game tests tools` before committing. One known catch: keep a lambda
whose body is a single `return` on one line (`func(m): return m.ready`),
because Godot can't parse the multi-line form gdformat writes inside a call.

## Tests

```
python3 tools/run_hearth_tests.py --godot <godot>            # every test under tests/
python3 tools/run_hearth_tests.py --godot <godot> shop_floor  # one test, by name
python3 tools/run_hearth_tests.py --godot <godot> --list      # what exists, and where
```

A new test is any `tests/<feature>/<name>_test.gd`; the runner finds it by itself.

## legacy/

Old material kept for reference, ignored by Godot (`legacy/.gdignore`):
the turn-based prototype (`scripts/codes`, `scenes/scenes`), unused tavern wings and
hearth screens, editor labs, the shooter prototype (`reference/`), old docs, the
unused items (`data/`), and 17 tests that test older behaviour (`tests/`).
