# Adventurer Builds & Class Assignment

Arriving adventurers no longer have class-shaped stats. Each one rolls a **stat build**
(who they are) and arrives with a **calling** (the class they hope for). The keeper picks
the actual class at recruitment, and can retrain them later.

## Stat builds

Defined in `data/adventurers.json` under `stat_builds`, rolled by `scripts/game/adventurer_builds.gd`.

| Field | Meaning |
|---|---|
| `weights` | Where points tend to land (higher = more likely). Unlisted stats still get a little. |
| `flaw` | Optional stat capped low (default 8). |
| `callings` | Classes this build naturally suits. Arrivals usually (curated 85%, generic 65%, founders 100%) get a build matching their calling; the rest roll any build, which is where surprising recruits come from. |
| `frequency` | Optional rarity multiplier (default 1). Jack-of-All-Trades is 0.25. |

`stat_build_rules` controls the budget: every stat starts at `floor` (6), and the total is
`base_total` (70) shifted by recruit quality, so better Hearth services mean stronger arrivals.
About 1 in 5 arrivals also gets a **hidden talent** (+2–3 in an off-stat) and about 1 in 6 a
**setback** (−1–2 in a strong stat).

## Class fit

Fit grades (Exceptional / Strong / Good / Fair / Poor) are scored against each class's own
`base_stats` in `data/classes.json`, with extra weight on its `primary.power` stat. Adding or
rebalancing a class updates fit grades automatically.

In the recruitment dialogue, fit is estimated **only from what the keeper knows**: appraised
stats are exact, contest and band results use their midpoint, and unknown stats read as 10.
Appraising and contesting candidates makes the estimate sharper.

## Assigning and retraining

- **Recruiting:** the class picker defaults to their calling and lists every unlocked class.
- **Retraining** (Company page → Class → Retrain): free while the adventurer is home.
  Level, XP, and attributes are kept. Class-specific upgrade picks are cleared and offered
  again, health is recalculated (keeping the same wounded fraction), and gear the new class
  can't use goes back to the armory. Bound starter weapons are swapped for the new class's.

Tests: `tests/adventurer_builds_test.gd` (included in `tools/run_hearth_tests.py`).
