# Pause Menu

Press **Esc** (controller: **Back / Select**) in the dungeon or at the tavern.
The game pauses and the menu offers:

| Option | Where | What it does |
| --- | --- | --- |
| Resume | both | Closes the menu (Esc does too). |
| Codex | dungeon | Opens the M codex: stats, progression, items, journal. |
| Options | both | Window, resolution, VSync, UI scale, camera zoom, screen shake, volumes. |
| Controls | both | Every keyboard/mouse and controller binding. |
| Return to Title Screen | both | Back to the start screen to continue, start or switch saves. |
| Quit Game | both (not on web) | Closes the game. |

Esc on a sub-page steps back to the main list. The menu only opens when nothing
else is up: in the dungeon not over the codex, a shop or a relic choice; at the
tavern Esc closes any open window first (the Hearth, a shop, the calendar...).

## Leaving and saving

Saving follows the autosave policy (`tests/autosave_policy_test.gd`):

- **Tavern:** saves before leaving, so nothing is lost.
- **Dungeon:** the run was saved on entering the floor. Continuing that save
  puts you back at the start of the floor; rooms cleared and loot picked up on
  the floor since then are lost. The confirmation says so before you leave.

## Code

- `scripts/ui/pause_menu.gd` (`GamePauseMenu`): the menu; `CONTROLS` lists the
  bindings shown on the Controls page.
- The `pause_menu` input action (Esc + Back) is added by
  `GamePauseMenu.ensure_action()` from `main.gd`.
- `main.gd → return_to_title()`.
- Wired up in `slasher_forest.gd → _build_hud` (all dungeons) and `tavern.gd`
  (`_can_open_pause_menu` in each decides when Esc may open it).
- Test: `tests/pause_menu_test.gd`.
