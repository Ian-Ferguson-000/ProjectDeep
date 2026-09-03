> [!WARNING]
> Historical document retained for context. It is superseded by the [Eros documentation index](../../README.md) and is not authoritative.

# Maps Design

## Forest Demo Floor
The forest is the first dungeon map. It should look like a tabletop board made of grass, dirt paths, trees, rocks, barrels, traps, and a final exit door.

## Generation Rules
- Use a seeded layout so the demo is reliable while still feeling replayable.
- Generate a connected grid with a guaranteed path from spawn to exit.
- Place the player near the lower-left side of the map.
- Place the exit near the upper-right side of the map.
- Keep all doors, loot, enemies, and required interactions reachable.

## Demo Contents
- Destructibles: rocks and barrels.
- Loot: gold, potion, key, and one chest reward.
- Interactables: campfire, chest, exit door, one trap, and one hidden cache.
- Enemies: simple forest creatures using token movement and melee attacks.
- Secret: a hidden cache that can be found by interacting near suspicious ground.

## Play Goals
The forest should teach that positioning matters. The player should move through a readable board, fight at least one enemy, find at least one reward, and make a clear decision between rushing the exit or exploring for extra loot.

## Future Ideas
- Curse floors with lower light or stronger enemies.
- Holes, cave drops, and branching floor exits.
- Secret doors based on class, race, or character traits.
- Biome-specific detection bonuses such as dwarves finding cave secrets.
