# Stone Crypt: 3D rooms

Crypt expeditions load `scenes/crypt3d/Crypt3D.tscn` from Main. It's the 3D
forest's presentation (docs/Forest3D.md) with the **crypt theme**. Rooms, foes,
hazards, hit geometry, drops, checkpoints and saves are all still the 2D crypt
simulation underneath (`slasher_crypt.gd`), exactly as the forest works.

## What it looks like

- **Floors:** grey flagstones with dark grout; worn paths are darker.
- **Walls:** stone blocks, tall at the back and cut low at the front so they
  never hide a fight, with pillars and violet wall torches.
- **Dressing:** the room maps' decorations become crypt pieces, as in the 2D
  crypt: candles, bone piles, urns, tombstones, grave crosses and rubble.
  Breakable "trees" are coffins.
- **Doors:** stone posts and lintel; iron bars drop across while foes remain.
- **Rest room:** a stone brazier with cold blue fire. **Exit:** stairs down into
  a violet glow. **Treasure:** a stone plinth. The trader keeps the forest's stall.
- **Lighting:** dark backdrop, cool grey-violet light.
- **Foes:** animated camera-facing sprites, sized per kind (grave rats small,
  tomb guards and the crypt lord big).
- **Big Skelly Boi (the Charnel King):** a 3D skull with a rusted crown, glowing
  eyes and a ribcage rising from a broken pit. The jaw drops for the Soul Wail,
  and the eyes go red when it roars. Its arms and sweeping hands are still drawn
  on the floor by the 2D boss (`draw_body = false`), so the lanes and the open
  hand read exactly as before. When it falls it leaves a 3D heap of bones and a
  cracked crown.
- **Merchant stop between floors:** the old single floor, rendered in stone.

## Editing

- `scripts/scenes/crypt3d/crypt_3d.gd`: the crypt adapter (sets `theme = "crypt"`).
- `scripts/scenes/forest3d/forest_room_art.gd`: the shared kit. Crypt pieces are
  under `# crypt` (`_build_crypt`, `crypt_decor`, `charnel_king`, `bone_heap`), plus
  crypt branches in `make_prop`, `door` and `build_landmarks`.
- `scripts/scenes/forest3d/forest_world_3d.gd`: lighting per theme, foe sizes,
  and `_pose_charnel_king`.
- Room layouts: `maps/crypt/rooms/` as before.

Test: `tests/crypt_3d_test.gd`. Run it without `--headless` and add
`-- --capture` for `build/visual_checks/crypt_3d_*.png` (start, combat, rest,
shop, treasure, guardian, interlude).
