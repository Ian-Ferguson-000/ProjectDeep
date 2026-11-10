# Guardian arenas

The dungeon guardians (the Heartwood Colossus in the Verdant Forest, Big Skelly
Boi in the Stone Crypt) are **goliaths built into the north wall** of their arena.

## The room

- **Against the north wall.** The guardian's body fills a 13×7 block of cells
  along the top of the arena, centred left to right, whatever the painter put
  its marker on (`ForestRoomLibrary.COLOSSUS_SIZE`, `SlasherColossus.BODY_CELLS`).
- **Never entered from the north.** The floor generator only makes a dead end the
  boss room if its way in is from the east, west or south
  (`field_dungeon_generator.gd`). It falls back to a deeper room without a north
  neighbour, and in the last resort adds a room above the top of the map. The
  arena's north door is always sealed. A save from before this rule that reaches
  an arena only from the north keeps its guardian where the map puts it.
- **Goliath sized in 3D.** The models are 2.3× the size of the cells they block
  and sit back into the wall, so they tower over the room
  (`forest_room_art.gd → GOLIATH_SCALE`, `GOLIATH_BACK`). The camera pulls back in
  the arena and can look past the north wall so the whole guardian fits
  (`dungeons.json slasher.guardian_camera_zoom`, no closer than 0.72).

## When it falls

- **The way on is inside its body.** A three-cell-wide passage opens up through
  the remains to the gate, which glows from inside them. **Walk through the dead
  guardian to continue** to the next dungeon on the route. While it lives, the
  passage is solid and there's no gate to find.
- **A portal home appears beside it**, east of the body: a ring of light with a
  shimmering mirage of the Hearth inside (the real tavern room, seen through a
  small camera). **Walk into it to go home.**
- With nowhere further to go on the route (the next dungeon is Coming Soon), the
  passage stays shut and only the portal opens.
- Come back into a cleared arena and the remains, the passage and the portal are
  still there.

These choices replace the old after-guardian "go on or go home" screen. That
screen still appears if a guardian floor is finished some other way.

## Code

- `game/dungeons/shared/forest_room_library.gd → build_layout`: moves the guardian,
  seals the north door, sets `exit` inside the body, and adds `passage_cells`,
  `portal` and `exit_under_body` to the layout.
- `game/dungeons/shared/slasher_forest_rooms.gd`: `_open_guardian_ways` (opens the
  passage, rebuilds the walls and pathfinding, places the portal), the portal
  check, `can_press_on`, and the `TavernPortal` 2D reference drawing.
- `game/main/main.gd`: `guardian_choice` ("onward" / "home") and `can_press_on`.
- `game/dungeons/shared/world_3d/forest_room_art.gd`: `tavern_portal`, `hidden_way`, goliath scale.
- `game/dungeons/shared/world_3d/forest_world_3d.gd`: arena camera.

Test: `tests/dungeons/guardian_arena_test.gd`. Run it without `--headless` and add
`-- --capture` for pictures of both arenas before and after the kill.
