# Expeditions and Upkeep

Runs are **solo**: you pick one adventurer and play the run yourself. Party
building, retreat policies and auto-resolved dispatches are gone from the game
(old saves with a dispatch still in flight resolve it once, through
`HearthExpeditions._legacy_dispatch` / `resolve_auto`).

Each adventurer goes on **one** expedition: when they come home the Hearth
keeps its cut and they retire to town (docs/tavern/TavernBusiness.md).

## The Set Out screen

Hearth → **Expeditions** → **Plan an Expedition** opens a full-screen, three-step
screen (`game/ui/expedition_setup.gd`):

1. **Destination**: three picture tiles. **Verdant Forest** (left) is the only
   choice: every run starts there, and the **Stone Crypt** is reached by
   fighting through the forest (the crossroads after its guardian), not picked
   here. **Ashen Farmstead** (middle) and **Moonlit Grove** (right) are greyed
   out with a padlock and a "Coming soon" ribbon and can't be clicked. The
   tiles are `ExpeditionSetup.DESTINATIONS`.
2. **Adventurer**: one card per adventurer: portrait, class, hearts, mood and
   weapon. Anyone away or still recovering is greyed out.
3. **Gear & Supplies**: change their equipment (the Armory's stock), see the
   rations the run will take, pack a potion, and read the bounties for that
   dungeon.

The footer always shows what's chosen. **Set Out** is enabled only when the run
is ready, and says why when it isn't.

- Pictures: `assets/ui/destinations/<dungeon>.png`, 320x180 pixel-art scenes
  painted by `tools/ui/paint_destinations.py` (placeholders: drop painted art
  of any 16:9 size in the same place).
- Coming soon: `"coming_soon": true` on the dungeon in `data/dungeons.json`.
  `RunState.is_coming_soon(id)` makes the dungeon unavailable everywhere (the
  crossroads after a guardian won't continue into it either). Remove the flag
  when the dungeon is built.

## The pantry (supplies)

Supplies are now **food** (`data/upkeep.json`, code in
`game/hearth/hearth_upkeep.gd`). Like Mewgenics' food, the Hearth has to keep
feeding the company to keep them.

| Food | Cost | Happiness a day |
| --- | --- | --- |
| Scraps | 2g | −5 |
| Hearty Fare | 5g | +2 |
| Feast | 11g | +7 |

- Buy food at **Facilities → Suppliers → Pantry**, and choose which one is
  **served**.
- Every adventurer at home eats **one ration a day** (`daily`). If what you
  serve runs out, they eat the next food available; if the pantry is empty
  they go **hungry** (−15 happiness).
- **Each expedition takes 2 rations** (`rations_per_run`), best food first. You
  can't set out without them.
- The "Supplies" counter in the top bar is the total rations in the pantry.
- A new campaign starts with 8 Hearty Fare. Old saves turn their supplies
  count into Hearty Fare.

## Happiness

Every adventurer has a happiness scale of 0–100 (it reuses the old `morale`
field), shown as the **Mood** bar on their cards.

| Band | Happiness |
| --- | --- |
| Content | 75+ |
| Settled | 50–74 |
| Unhappy | 25–49 |
| Miserable | under 25 |

- Daily: the food's effect, −15 if hungry, −4 extra on days spent training.
- After a run: +10 for a victory, +2 for a retreat, −8 for a defeat.
- **Leaving:** each day an adventurer is below 25 they have a 20% chance to
  walk out (40% if they were training that day). It shows in the day's events.

All numbers are in `data/upkeep.json`.

## Renown

Renown (the old reputation) is earned from runs and bounties and **spent on
expanding the Hearth**, together with gold: Facilities → **Expand the Hearth**
(cost per tier = that tier's reputation figure). The old list of improvements
has been removed; the Facilities page only shows the tiers and the expansion.

## Still to tidy

- The tavern floor's old "Party Builder" ledger and "Plan an Expedition" modal
  in `tavern.gd` can no longer be reached and can be deleted.
- A few unused variables in `hearth_management.gd` (`selected_party`, `policy`,
  `_buy_supplies`, `_style_check`).

Test: `tests/ui/expedition_setup_test.gd`.
