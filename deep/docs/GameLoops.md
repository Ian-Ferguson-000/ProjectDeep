# Game loops: unlocks, bounties, drops, and the guardian choice

## Unlocks (`data/unlocks.json`)

Goals that permanently change the game, Binding of Isaac style. They survive
Hearth loops.

- **Items** listed in an unlock's reward stay out of chests, shops and drops until
  it's earned. Nine of the newer relics start locked.
- **Drop luck** multiplies every enemy drop chance (shown on the Unlocks page).
- **Bounty slots** put more contracts on the board.

| Condition | Checked when |
| --- | --- |
| `kills` (lifetime, by family: sporeling, bandit, wolf, beast, any) | every kill |
| `kills_in_run` | every kill |
| `clear` (dungeon, optional `class`, `max_seconds`, `max_potions`, `holding`) | a guardian falls |
| `clears` (total guardians defeated) | a guardian falls |
| `deaths` (adventurers lost) | an expedition is settled |
| `bounties` (bounties completed) | an expedition is settled |
| `reach` (enter a dungeon) | entering it |

Unlocks earned mid-run pop up on screen and are listed on the guardian choice
screen, the results screen and the expedition report. **Hearth → Records →
Unlocks** shows them all, with hints and progress for locked ones.

## Bounty board (`data/bounties.json`)

Two contracts are posted (three after *Trusted Contractor*). Each stays up for
three days. An expedition that **returns alive** (victory or retreat) having met
a bounty is paid on return in gold, renown or essence. Goals: kill counts per
family in one run, clear under a time (from the record, or 18:00 with no record),
clear as a given class, clear without a potion, and bring home an amount of gold.

**Hearth → Expeditions → Bounties** shows the board; the expedition screen lists
them too. Progress shows on the guardian choice screen.

## Enemy drops (`data/enemy_drops.json`)

Low to begin with: about a 22% chance per kill of anything at all. That's mostly
small gold piles, with 3% potions, 2% keys and 0.4% relics. Elites drop four
times as often; sporelings, which come in swarms, less. Bosses don't roll
(they have their own rewards). Drop luck from unlocks raises everything, up to
×2.5. A relic drop gives a random relic your class can use from the unlocked pool.

## Guardian choice screen

When a guardian falls (forest, the other dungeons, the farmstead), the game
pauses on **The Guardian Falls**:

- **Bringing home:** gold carried and what the Hearth keeps after the 20% share,
  relic essence, unique relics, consumables and keys. Every relic is marked
  **Kept** (permanent items, equipped gear) or **Lost on return** (run and
  dungeon-bound items, which end with the expedition).
- **Bounties:** progress on each posted bounty, ticked when met.
- **Unlocked this expedition.**
- **Return to the Hearth** or **Continue to the Crypt** (or wherever the route
  goes next). Continuing means no rest or resupply, and a death loses everything
  carried. If the next dungeon isn't open, Continue is greyed out.

The tutorial skips this screen.

## Code

- `scripts/game/unlocks.gd`: conditions, rewards, locked items, drop luck.
- `scripts/game/bounty_board.gd`: posting, progress, payout.
- `RunState.note_kill / note_potion / run_stats()`: per-expedition stats, saved
  on `ExpeditionState.run_stats`. Lifetime counts are on `CampaignState.lifetime_stats`.
- `SlasherForest.roll_drop / _roll_enemy_drop`: enemy drops.
- `scripts/ui/guardian_crossroads.gd` and `main.gd _guardian_crossroads`: the choice screen.
- Test: `tests/game_loops_test.gd`.
