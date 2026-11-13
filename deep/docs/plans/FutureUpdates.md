# Future updates

Features that exist in the project but are switched off for the demo. Each entry
says what was there, where it still lives, and how to turn it back on.

## Shelved classes: Healer, Tank, Rogue, Summoner

The demo has two classes: **Fighter** (`warrior` in code) and **Mage**. The plan
(see [ToBeDone](ToBeDone.md), item 1) is to bring the others back later as
**subclasses** unlocked through play, with items unique to each.

### What each class was

| Class | Role | Resource | Kit (basic / special / defensive / movement) | Used to unlock by | Stand-in now |
| --- | --- | --- | --- | --- | --- |
| Tank | Defender | Resolve / Endurance | Shield Bash / Retribution / Guard / Leap | Clearing the Forest | Fighter |
| Rogue (art id `phantom`) | Mobile assassin | Edge / Momentum | Pierce / Assassinate / Evade / Shadowstep | Clearing the Forest | Fighter |
| Healer | Support controller | Grace | Binding Light / Empower / Recover / Dash | Clearing the Ashen Farmstead | Mage |
| Summoner | Companion tactician (bonded wolf) | Bond | Mark-Command / Summon / Cover / Mount | Clearing the Crypt | Mage |

Starter weapons: Sunwood Staff (Healer), Tower Shield and Mace (Tank), Spectral
Dagger (Rogue), Bondkeeper Staff (Summoner). Each class also has three more
armory weapons in `data/hearth_campaign.json` (for example Oathwall, Moon
Stiletto, Mercy Branch, Pack Call).

### What was kept

Nothing was deleted, so the classes can come back without being rebuilt:

- **Data:** `data/classes.json`, `data/progression.json`, `data/slasher_balance.json`,
  `data/slasher_progression.json`, `data/lodging.json`, the class weapons in
  `data/hearth_campaign.json`, and the authored recruits in `data/adventurers.json`.
- **Code:** the class kits in `game/player/slasher_player.gd` (healer, tank, rogue,
  summoner branches) and `game/player/slasher_wolf.gd` (the Summoner's wolf).
- **Art:** `assets/classes/{healer,tank,rogue,phantom,summoner,wolf_companion}`,
  plus class cards in `assets/ui/class_cards/`.
- **Tests:** the shelved kits' own tests (for example `tests/player/rogue_abilities_test.gd`)
  still run, so the code doesn't quietly break while it's switched off.

### How it's switched off

One list decides which classes are in the game: `PLAYABLE_CLASS_IDS` in
`game/core/game_balance.gd`. Because of it:

- Dungeon clears no longer unlock classes (`record_dungeon_clear` in
  `game/core/campaign_state.gd`), and `unlock_class` refuses shelved ones.
- Class selection, the testing ground and the clear-records screen list only
  Fighter and Mage.
- Shelved-class weapons are never sold or dropped (`HearthCatalog.in_play`).
- Authored recruits and story arrivals written as a shelved class arrive as
  their stand-in (`GameBalance.playable_class_for`), so no characters are lost.
- Old saves: shelved unlocks are dropped and anyone of a shelved class is
  retrained to their stand-in when the save loads (`_retrain_shelved_classes`).

### Bringing one back

1. Decide whether it returns as a full class or as a subclass of Fighter/Mage.
   The subclass route needs new code; a full class can just be added back to
   `PLAYABLE_CLASS_IDS`.
2. Restore its unlock in `record_dungeon_clear`, or attach it to a new unlock.
3. Undo its stand-in mapping in `SHELVED_CLASS_FALLBACK`, and decide what to do
   with the recruits who were retrained.
4. Update `docs/plans/TargetPCPlaytest.md` with its unlock check.
