# Which scenes the game uses

The game plays in **3D**. The 2D scenes are kept as references and as the base
the 3D ones are built on; players never see them.

| Place | Live scene (3D) | 2D reference (hidden) |
| --- | --- | --- |
| The Hearth (tavern) | `scenes/tavern3d/Tavern3D.tscn` | `scenes/tavern/Tavern.tscn` (Tavern3D inherits it for its campaign logic and UI; its 2D world is hidden) |
| Verdant Forest + tutorial | `scenes/forest3d/Forest3D.tscn` | `scenes/slasher/SlasherForest.tscn` |
| Stone Crypt | `scenes/crypt3d/Crypt3D.tscn` | `scenes/slasher/SlasherCrypt.tscn` |

**Don't delete the 2D scenes.** The 3D tavern inherits the 2D one, the 3D
dungeons extend the 2D dungeon scripts (the 2D simulation is what actually runs
the fight), the other dungeons are built on `SlasherForest.tscn`, and many
gameplay tests load the 2D scenes directly because they test the shared rules.

## Still 2D (Coming Soon)

Ashen Farmstead, Balor's Hell, Sunken Mine, Ember Foundry, Moonlit Grove and the
Abyssal Archive still have only 2D scenes, and they're all Coming Soon, so
players can't reach them. Before opening one, give it a 3D adapter like
`scripts/scenes/crypt3d/crypt_3d.gd` (a theme in the shared art kit) and point
`Main.dungeon_scene` at it.

## Dev-only 2D tools

- The testing ground (`scenes/slasher/TestingGround.tscn`) opens only with Dev
  Mode, which the demo build hides.
- `scripts/maps/map_playtest.gd` opens room maps in the 2D forest for editing.

## Guard

`tests/live_scenes_test.gd` fails if the tavern isn't 3D, or if any dungeon that
isn't Coming Soon would load a 2D scene.
