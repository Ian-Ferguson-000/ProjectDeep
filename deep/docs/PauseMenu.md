# Pause Menu

Press **Esc** (controller: **Back / Select**) in the dungeon or at the tavern.
The game pauses and the menu offers:

| Option | Where | What it does |
| --- | --- | --- |
| Resume | both | Closes the menu (Esc does too). |
| Codex | dungeon | Opens the M codex: stats, progression, items, journal. |
| Tavern Guide | tavern | Replays the first-visit guide (docs/TavernGuide.md). |
| Abandon Run | dungeon (not the tutorial) | Leave the run and go home to the tavern as a retreat: the adventurer comes back safe; you keep the gold secured at the last floor checkpoint and leave the rest. The confirmation shows both amounts. |
| Options | both | Window, resolution, VSync, UI scale, camera zoom, screen shake, volumes. |
| Controls | both | Every keyboard/mouse and controller binding. |
| Return to Title Screen | both | Back to the start screen to continue, start or switch saves. |
| Quit Game | both (not on web) | Closes the game. |

In the dungeon the menu also shows the run's **seed** with Copy and Save
buttons (docs/RunSeeds.md).

Esc on a sub-page steps back to the main list. It's the main menu, so it opens
over **everything**: the codex, shops, relic choices, the Hearth windows and
dialogue. It catches Esc before anything else does, so Esc no longer closes
those windows (use their close buttons, M for the codex, or controller B).
Closing the menu puts you back exactly where you were.

## Leaving and saving

Nothing is lost when you leave, quit or crash:

- **Tavern:** saves before leaving.
- **Dungeon:** the game saves on entering every floor, on entering every room,
  and when a room is cleared. Continuing puts you back in the room you were in,
  with your health, gold, keys, potions, relics and the floor's cleared rooms.
  A room you left mid-fight starts that fight again.
- What's saved for the floor is `ExpeditionState.run_snapshot` (written by
  `RunState.run_snapshot()` on every save, put back by
  `restore_run_snapshot()` in `main.gd → _resume_saved_expedition`). Room
  saves go through `RunState.save_room_checkpoint()`, called from
  `slasher_forest_rooms.gd → _save_checkpoint`; `tests/autosave_policy_test.gd`
  keeps saving to these paths. Test: `tests/run_checkpoint_test.gd`.

## Code

- `scripts/ui/pause_menu.gd` (`GamePauseMenu`): the menu; `CONTROLS` lists the
  bindings shown on the Controls page.
- The `pause_menu` input action (Esc + Back) is added by
  `GamePauseMenu.ensure_action()` from `main.gd`.
- `main.gd → return_to_title()`.
- Wired up in `slasher_forest.gd → _build_hud` (all dungeons) and `tavern.gd`
  (`_can_open_pause_menu` in each decides when Esc may open it).
- Test: `tests/pause_menu_test.gd`.
