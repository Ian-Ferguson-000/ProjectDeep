# Stone Crypt

**Status:** plays from these rooms. 20 rooms covering every role, built from
`tools/maps/crypt_rooms.json`. Repaint them freely; that file was only the
starting point.

**Size:** 1.5x the forest. Standard rooms are **41x23**, large ones **53x29**
(the guardian arena, the Great Ossuary and the Royal Tomb). Doors are at the
middle of each edge, as in the forest.

**Tiles:** `tiles/crypt_ground.tres` (48px tiles from `crypt_ground.png`):

| Row | Kind | What |
| --- | --- | --- |
| 0 | floor | 8 stone slabs: plain, studded, darker, cracked, bone-strewn |
| 1 | pit | open pit, and a pit with a stone lip on its top edge. **Blocks movement.** |
| 2 | carpet | red runner, plain and trimmed (walkable; carpet over a pit makes a bridge) |
| 3 | wall | the wall marker for the **Thicket** layer |

Paint the outer edge and any solid blocks (pillars, tombs) with the wall
marker on the **Thicket** layer. The game hides that layer and draws real stone
walls around the room instead, so you don't paint wall art yourself.

**Markers** work as in the forest, but become crypt things: Big tree → a
breakable **coffin** (one per room may hide a keyless chest; it's drawn a shade
darker), Rock → rubble, Mossy rock → rubble decor, Pebbles → a bone pile,
Mushrooms → candles, Bush → an urn or tombstone, Campfire → campfire, Gate down
→ **stairs down**, Colossus → **Big Skelly Boi**.

See maps/README.md for how to paint rooms and docs/Crypt.md for the crypt itself.
