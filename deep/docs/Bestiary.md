# Bestiary

The Codex (M, or Esc → Codex) has a **Bestiary** tab in place of the old journal.

- **Filters:** All, Verdant Forest, Stone Crypt, Balor's Hell, and a tally of
  how many creatures you've discovered.
- **Grid:** one tile per creature. Undefeated ones are black silhouettes marked
  ???. Discovered ones show their sprite, name and kill count. Bosses have a
  gold border, mini bosses purple. Creatures drawn in code (the Heartwood
  Colossus, the Charnel King) show their initials until they have sprite art.
- **Page:** a moving portrait (idle, run, attack), the name, rank (Basic, Mini
  Boss, Boss), dungeon, the most health you've seen it with, kills, and four
  sections: **How it fights**, **How to beat it**, **Drops** (from
  docs/Materials.md) and **Found** (where it lives). An undiscovered creature's
  page tells you only where it's found.

Defeating one creature of a kind unlocks its page; the counts and health are
kept for the whole campaign.

## Editing

Everything is in `data/slasher_journal.json`. Each entry has `name`, `category`,
`dungeon` (one of the three filters), `description`, `habitat`, `behavior`,
`tactics` and `traits`. Rank comes from `category` (Boss and Guardian are
bosses, Elite is a mini boss) unless the entry sets `"rank"` (`basic`,
`mini_boss` or `boss`), as the briar guardian does. `order` is the grid order.

Code: `game/dungeons/shared/slasher_codex_menu.gd` (the `_build_journal` section).
Health seen: `RunState.record_enemy_defeat(id, max_health)` /
`get_enemy_health_seen`. Test: `tests/enemies/bestiary_test.gd`.
