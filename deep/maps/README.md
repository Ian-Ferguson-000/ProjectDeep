# Maps

Every dungeon room is a Godot scene you paint in the editor. The game finds
the rooms in each dungeon's folder by itself: there is no list to update and
no code to touch.

```
maps/
  _templates/RoomTemplate.tscn   start every new room from this
  forest/
    rooms/                       one .tscn per room (20 so far)
    tiles/                       the TileSets and their art
  crypt/  hell/  farmstead/  mine/  foundry/  grove/  archive/
```

The **forest** and the **crypt** play from rooms. The other folders are ready
for art: each has its own README saying what it has and what it still needs.
Crypt rooms are 1.5x the forest's size (41x23, large 53x29) and are walled in
stone instead of trees; see `maps/crypt/README.md`.

---

## Make a new room

1. **Duplicate the template.** In the FileSystem dock, right-click
   `maps/_templates/RoomTemplate.tscn` → **Duplicate**, and save it into
   `maps/forest/rooms/` with a lowercase name such as `mushroom_hollow.tscn`.
   The file name becomes the room's id. Or duplicate an existing forest room
   that is close to what you want.
2. **Set it up.** Click the root node and, in the Inspector:
   - **Room Name**: what players see ("Mushroom Hollow").
   - **Roles**: tick every kind of room this map can be used for (see below).
   - **Weight**: how often it's picked compared with other rooms of the same role
     (1 = normal, 0.5 = half as often).
   - **Size Cells**: width × height in 48px cells. Must be odd numbers. Forest:
     27×15 standard, 35×19 large. Crypt: 41×23 standard, 53×29 large.
3. **Paint the layers** (below).
4. **Place markers** (below).
5. **Check the warning triangle.** If anything is wrong (a door you can't reach,
   a shop with no merchant), a ⚠ appears next to the root node in the Scene tree.
   Hover it to see what's wrong.
6. **Press F6** to play the room on its own. You start in it with a warrior, and
   enemies appear if it's a fighting room. Walk through a door to reach normal rooms.
7. **Save.** The room is in the game.

The yellow outline in the editor is the room's edge. The four green squares are
the **doors**, always at the middle of each side. Keep those cells, and a path to
them, clear. Doors with no neighbouring room are filled with trees by the game.

---

## Layers

Select a layer in the Scene tree, then paint with the **TileMap** panel at the
bottom of the editor.

| Layer | What to paint |
| --- | --- |
| **Ground** | The base floor everywhere, including under the walls, so gaps between trees never show black. |
| **Terrain** | Water and cobblestone. **Water blocks movement**; cobbles are walkable. |
| **Paths** | Dirt trails. Use the **Terrains** tab and pick "Dirt": draw the trail and Godot picks the edge and corner pieces. These tiles are half-size (24px). |
| **Detail** | Decoration only. Never blocks movement. |
| **Thicket** | The room's wall. Paint the tree-marker tile wherever the edge should be impassable forest; the game grows real trees there and hides this layer. The whole outer edge must be thicket, except the four doors. |
| **Canopy** | Optional art drawn **above** characters (overhanging branches and so on). |

**Variety tip:** in the TileMap panel, select several grass tiles at once and
turn on the **dice** button (Place Random Tile), so each click picks one at
random. Every grass tile also has mirrored versions (alternative tiles) for more
variety.

---

## Markers

Markers are the things that aren't floor: spawns, loot, people, objects. To add
one, select the **Markers** node, then **Instantiate Child Scene** (chain icon) →
`maps/_templates/Marker.tscn`, or duplicate an existing marker (Ctrl+D). Pick its
**Kind** in the Inspector. Markers snap to the centre of a cell.

| Kind | What it is | Notes |
| --- | --- | --- |
| Enemy | Where a foe can spawn | Place several; more are used on deeper floors |
| Elite/Boss | Where a guardian spawns | Used in elite and boss rooms |
| Loot | Loot cache, appears once the room is cleared | |
| Treasure | Relic pedestal | Required in treasure rooms |
| Merchant | The trader | Shop rooms only, and required there |
| Gate down | Root gate to the next floor | Required in boss rooms |
| Start | Where the player appears | Start rooms |
| Campfire | Campfire | Shop and rest rooms only; required in rest rooms |
| Chest | Locked chest (needs a key) | Blocks movement |
| Rock / Big tree | Breakable obstacles | Block movement until broken |
| Mossy rock, Pebbles, Mushrooms, Bush | Small decorations | Don't block. You can paint these in Detail instead |
| Colossus | A giant guardian's body (fills 7×5 cells): the Heartwood Colossus in the forest, Big Skelly Boi in the crypt | Guardian rooms only; see docs/HeartwoodColossus.md and docs/Crypt.md |

---

## Roles

| Role | Used for | Rules |
| --- | --- | --- |
| start | First room of a floor | No enemies |
| combat | Normal fights | Needs Enemy markers |
| elite | Elite fights | Add an Elite/Boss marker |
| treasure | Relic room | Needs a Treasure marker, no enemies |
| shop | Trader camp | Needs a Merchant, no enemies |
| rest | Campfire clearing | Needs a Campfire, no enemies |
| boss | Gate room on ordinary floors | Needs a Gate down marker |
| guardian | Gate room on guardian floors (the colossus arena) | Needs a Colossus and a Gate down marker |

A room can have several roles (a map that works for both combat and elite).
Every role needs at least one room in the dungeon.

---

## Tiles and art

Each dungeon's `tiles/` folder holds its TileSets (`.tres`) and their images
(`.png`). You can:

- **Repaint tiles:** edit the PNG. Changes show up everywhere straight away.
- **Add tiles:** make the PNG bigger (keep the grid), open the `.tres`, and in
  the **TileSet** panel select the new squares and create tiles for them.
- **Tell the game what a tile is:** in the TileSet panel choose **Paint → Custom
  Data → kind** and paint the value onto tiles. The game reads `grass`, `water`
  (blocks movement), `cobble`, `dirt`, `floor` and `thicket`. Tiles with no kind
  just count as walkable floor.

The forest's sheets are cut on a 32px grid (`forest_ground.png`) and a 16px grid
(`forest_paths.png`). In game each 32px tile is shown at 48px.

---

## For programmers

- `scripts/maps/map_room.gd`: the room root (Inspector fields, editor overlay, warnings, F6).
- `scripts/maps/map_marker.gd`: markers and their kinds.
- `scripts/maps/map_library.gd`: finds room scenes, reads them into the room
  format the game already uses, and hands their painted layers to the game.
- `scripts/slasher/forest_room_library.gd`: room rules and validation, unchanged
  in behaviour.
- `tools/maps/`: one-time scripts that built the tilesets and converted the old
  text rooms (`convert_forest_rooms.gd`), and built the crypt's tiles and rooms
  (`make_crypt_sheet.py`, `crypt_room_designs.py`, `build_crypt_rooms.gd`).
  Don't re-run them once the artist has started; they overwrite.
- Tests: `tests/map_rooms_test.gd`, `tests/crypt_rooms_test.gd`.
