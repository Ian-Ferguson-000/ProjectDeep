# Hearth lodgings and training

The Hearth is the company's cosy home between expeditions. Your roster stays here from day to day: every adventurer has a room, can train once a day, and goes out better prepared for the next run.

Everything below is tuned in `data/lodging.json`. That file has `how_to_edit` notes at the top and is loaded by `scripts/game/hearth_lodging.gd`. Players use it in the Hearth menu under **Company → Training** and **Company → Lodgings**.

## Rooms

- **Building rooms.** A new Hearth has `starting_rooms` rooms. Each establishment tier sets how many rooms the building can hold (6, 10, 14 and 18, from `capacity` in `data/hearth_campaign.json`). You build the rest one at a time for gold, and each room costs more than the last.
- **Every adventurer needs a room.** Recruiting is blocked when every room is taken. New recruits move into the best free room. When someone leaves or dies, their room frees up.
- **Moving people.** Use "Move in…" on any room. Whoever lives there swaps rooms with the person moving in.
- **Room quality.** Upgrades go Straw Cot → Snug Bunk → Hearth Chamber → Lantern Suite. Finer rooms hold more furnishings and give everyone who sleeps there a training bonus. The two finest qualities need a bigger Hearth.

## Furnishings

Each furnishing is themed for certain classes. A Crystal Ball and Spellbooks suit a mage; a Training Dummy and Iron Dumbbells suit a warrior.

- **What they do now:** a furnishing raises the training chance for the stats it lists, for whoever lives in that room. The room card says when its furnishings suit the current resident. In the Furnish list, a ★ marks items that suit the resident.
- **Placing and removing:** buying a furnishing places it straight into a free slot. Removing one sends it to storage, and placing a stored one again is free.
- **Future bonuses:** furnishings can grant other room bonuses later, such as recovery, morale or starting items. Add new fields to the furnishing entries and read them in `hearth_lodging.gd`.

## Training

Each adventurer can train one attribute per day while they're at the Hearth.

- **Cost:** a session costs gold whether or not it works. Higher stats cost more to train.
- **Chance:** a session raises the stat by 1 on success. The chance drops as the stat climbs. Room quality, matching furnishings and practice all add to it. A known learning pace (from tavern contests) also adjusts it.
- **Practice:** a failed session banks a practice point for that stat, making the next attempt likelier. Practice resets when the stat goes up.
- **Cap:** stats cap at `stat_cap` (18 by default).
- **Effect on runs:** trained stats carry into expeditions through the adventurer's attributes. Constitution also raises maximum health.

Tests: `tests/hearth_lodging_test.gd`.

## In the tavern

The Hearth's main hall opens onto two walkable areas, built by `scripts/scenes/tavern_expansions.gd`. The camera follows the keeper between them.

- **Lodgings wing (west doorway).** A corridor with one alcove for every room the Hearth has space for: 6, 10, 14 or 18 as it expands.
  - Built rooms show a bed in the room's quality, the resident's nameplate and their furnishings.
  - Spaces with no room built yet show as empty plots.
  - Walk up to a room or the Lodgings ledger and press E to open Company → Lodgings.
- **Training yard (east doorway).** Boarded up until the Hearth becomes the Established Inn.
  - It has a sparring ring with dummies, weapon racks and supplies.
  - At the Adventurers' Hall it gains an archery range, and at the Renowned Hearth a weights corner.
  - Press E at the ring to open Company → Training.

Beds, dummies, targets and furnishings are drawn in code as stand-ins until dedicated art exists. Their drawing code is in the small classes at the bottom of `tavern_expansions.gd`.
