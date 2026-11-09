# The Tavern's Business

You are the keeper of the Hearth, home of the **Eros** adventuring company.

1. **Recruit.** Pay a signing fee to bring an adventurer into the company.
   Better-known adventurers cost more but come stronger (fame tiers, below).
2. **Keep them.** House, feed and train them at the Hearth (pantry, lodgings,
   training; see docs/tavern/ExpeditionsAndUpkeep.md and docs/tavern/HearthLodgings.md).
3. **Send them out once.** Each adventurer goes on one expedition, led by you.
4. **Take your cut.** If they come home (a guardian victory, a retreat or an
   abandoned run), the Hearth keeps its **cut** of the gold they bring back and
   they keep the rest. Then they **retire to Eros town for good**: gear goes
   back to the armory, packed potions back to storage, and they join the
   retired list with their purse. If they fall, nothing comes back.

The retired list is also where a retiree's child may one day turn up at the
tavern as a recruit (the existing descendant system). Retirees now record
`settled_in_town`, `purse`, `outcome` and `dungeon_id`, ready for a fuller
town and family feature later.

## The cut: 10% → 90%

The better you've looked after someone, the more the Hearth keeps:

| Source | Points |
| --- | --- |
| Base | 10% |
| Each training session (gain or practice) | +4, up to +40 |
| Mood when they set out | Content +10, Settled +4, Unhappy −6, Miserable −15 |
| Their room | Snug Bunk +4, Hearth Chamber +8, Lantern Suite +14 |
| Each furnishing in their room that suits their class | +3, up to +12 |
| Each day living at the Hearth | +1, up to +15 |

Kept between 10% and 90%. It's shown as the **Tavern cut** bar on roster
cards (hover for the breakdown), on the Set Out adventurer cards, and spelled
out on the Gear & Supplies step. The results screen and the Reports page show
the Hearth's cut, the adventurer's purse, and who retired.

## Fame tiers

| Tier | Fee | Stats | Level |
| --- | --- | --- | --- |
| Unknown | ×1 | — | — |
| Local Name | ×1.8 | +1 to every attribute | — |
| Well Known | ×3 | +2 | +1 |
| Famous | ×5 | +3 | +2 |

Bigger Hearths draw bigger names: at the starting tier recruits are mostly
unknowns and never famous; a fully expanded Hearth sees famous recruits about
one time in five. The tier shows on recruit cards and next to the fee in the
recruitment dialogue. (The existing safety net still applies: with fewer than
two adventurers and no money, a cheap recruit signs for free.)

## Tuning and code

- All numbers: `data/tavern_cut.json` (with `how_to_edit` notes).
- `game/hearth/hearth_cut.gd` (`HearthCut`): `breakdown`, `percent`,
  `explain`, `split`, `retire_to_town`, fame (`roll_fame`, `apply_fame`).
- Settlement: `HearthExpeditions.settle` (manual runs). Old saves' automated
  dispatches keep the old 20% share and come home as before.
- The tutorial run is unchanged: the first adventurer comes home and stays.
- `CharacterRecord.fame` and `joined_day` are saved with each adventurer.
- Test: `tests/hearth/hearth_cut_test.gd`.
