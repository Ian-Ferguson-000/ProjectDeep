# Visitors of Merit

Named people who call at the Hearth on their own schedules, give the Keeper
jobs, and (for traders) open a shop that grows as you earn their favour. It's
how story and lore reach the player: each visitor carries a thread of the
world in what they say and what they ask for.

## How it plays

1. **They visit.** Each visitor comes on set days (`schedule`). They stand in
   the tavern as a figure; a **!** over their name means they have a job on
   offer or one to hand in. Click them to talk.
2. **Take a job.** The **Jobs** tab lists their quests: on offer, in progress,
   done, or locked (`???` until you've earned enough favour or finished the
   job before it).
3. **Do it.** Progress counts from when you accept: kills, floors reached,
   guardians beaten (optionally with a class), coming home alive or with a
   heavy purse, training sessions, beating them at their mini-game. **Deliver**
   jobs are handed over in person (food or gold) and pay at once.
4. **Collect.** Finished jobs are collected in person on a later visit:
   gold, renown, favour, equipment, furnishings, food and story flags.
5. **Favour.** Ranks (Stranger, Acquaintance, Ally, Confidant) unlock more
   jobs and better **Wares**. Each visitor with a mini-game gives +1 favour
   for a win, once per visit (reusing the arm-wrestling, memory, quick-draw and
   drinking contests).

The Hearth's **Expeditions → Quests** page lists every job in hand and when
each visitor is next due (unknown visitors show as "Someone unknown").

## The first four

| Visitor | Who | Visits | Jobs | Wares | Mini-game |
| --- | --- | --- | --- | --- | --- |
| **Mayor Corvin Rook** | The town's mayor: roads, debts, refugees | Day 2, then every 5 days | Open the Briarway (forest floor 3) → Bread for the North Road (deliver 4 Hearty Fare) → Guardian of the Crossroads (clear the forest) → Under the Ossuary (reach the crypt) | Feast crates, a War Table | — |
| **Tessaly Vane** | Nordian arms-trader from the border holds | Day 3, every 4 days, stays 2 | Kobold Trouble (15 bandits) → A Proven Blade (clear forest as a Warrior; Sentinel Shield) → Bones for Steel (25 undead) | Armour, weapons, a Worldbreaker Gauntlet at Confidant | Arm wrestling |
| **Calden Ashwick** | Helvetican league physician | Day 4, every 6 days, stays 2 | Spore Samples (20 sporelings) · A Disciplined House (6 training sessions; Herb Garden) · Bring Them Home (3 adventurers home alive) | Food crates, a Prayer Altar, Mender's Sachet | Memory match |
| **The Grey Archivist** | Investigator from the Veiled Isles; the lore thread | Only after the forest's guardian falls; weekly | Below the Roots (crypt floor 3) · A Heavy Purse (come home with 300 gold) · The King in the Bones (clear the crypt) | Starglass Orrery, Echo Prism, Chronomancer's Pin | Quick draw |

Their lines draw on docs/story (the mayor's civic brief, the nations, and the
Archivist hinting at the prisons' concealed history). Story flags they set
(`mayor_trusts_hearth`, `archivist_truth_of_the_crypt`, ...) are there for
later story events to check: `VisitorService.has_flag(campaign, flag)`.

## Art still needed

Until art exists, every visitor is a **dark silhouette with a question mark**,
rimmed in their accent colour: a head-and-shoulders portrait (visitor panel,
Quests page, mini-game card) and a cloaked standing figure in the tavern.
Hovering a silhouette portrait shows the art brief. To add art, set
`art.portrait` (portrait image, any size, shown at about 240×300) and
`art.sprite` (a standing figure, used like the merchants' tavern sprites) in
`data/visitors.json`; the silhouettes stop being used automatically.

| Visitor | Brief |
| --- | --- |
| Corvin Rook | Late fifties, ink-stained cuffs, a chain of office he keeps tucking under his coat. Tired, decent, always counting something. (There's an older mayor portrait at `assets/generated_characters/town_mayor.png` if the team wants to reuse it.) |
| Tessaly Vane | Broad-shouldered, forties, fur-lined travelling coat over a smith's apron, a border-hold oath ring. Laughs loudly, haggles harder. |
| Calden Ashwick | Thin, thirties, spectacles, a physician's satchel crusted with road dust. |
| The Grey Archivist | Hooded, age hard to tell, grey robes stitched with tide charts, a sealed book never opened in company. |

## Adding a visitor

Everything is data: add an entry to `data/visitors.json` (its `how_to_edit`
notes list every field). A visitor needs a name, title, accent colour,
schedule, greeting lines per rank, idle lines and quests; shops and a
mini-game are optional. `VisitorService.validate()` (run by the test) checks
ids, items, furnishings, foods and quest links.

Objective types: `kills`, `reach_floor`, `clear`, `return_gold`, `runs_home`,
`train`, `contest_win`, `deliver`. Reward fields: `gold`, `renown`, `favour`,
`items`, `furnishings`, `food`, `flag`.

## Code

- `scripts/game/visitor_service.gd` (`VisitorService`): schedules, ranks,
  quest states, `notify(event)`, deliveries, rewards, shop, mini-game, lines.
- Saved in `CampaignState.visitor_state`.
- Events come from `RunState` (kills, floors, clears), `HearthExpeditions.settle`
  (coming home), `HearthLodging.train` and the visitor's mini-game.
- `scripts/ui/visitor_panel.gd` (talking to them), `scripts/ui/placeholder_art.gd`
  (silhouettes), `tavern_activity_controller.gd → _spawn_visitor`,
  `hearth_management.gd → quests_page`.
- Test: `tests/visitors_test.gd`.
