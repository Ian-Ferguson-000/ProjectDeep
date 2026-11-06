# Materials and enemy drops

Enemies drop **crafting and quest materials**. Only mini bosses can also drop a
relic, and nothing drops active items.

| Who | Drops |
| --- | --- |
| Basic enemy | Its family's material, 30% of the time |
| Mini boss | Its trophy ×2, always, plus a 30% chance of a relic |
| Boss | Its trophy |
| Tutorial | Nothing |

Drop luck from unlocks multiplies both chances (up to ×2.5). Tuning lives in
`data/enemy_drops.json`: `basic_material_chance`, `mini_boss_item_chance`,
`mini_boss_materials`, `boss_materials`.

## The materials (`data/materials.json`)

| Material | From |
| --- | --- |
| Kobold Fang | kobold bandits (cutthroats, knife-throwers) |
| Spore Sac | sporelings |
| Grave Dust | the crypt's undead |
| Wolf Pelt | every wolf |
| Beast Hide | other forest beasts |
| Briar Heart | the briar guardian (mini boss) |
| Cutthroat's Sash | a cutthroat mini boss |
| Lord's Signet | the crypt lord (mini boss) |
| Heartwood Seed | the Heartwood Colossus |
| Crown Shard | the Charnel King |

`by_family` maps an enemy family (`scripts/game/unlocks.gd → FAMILIES`; wolves
and other beasts are worked out from the id) to its material. `by_enemy` gives
mini bosses and bosses a trophy, which wins over the family material. Add a
material by adding it under `materials` with a name, description and colour.

## Carrying and banking

- A drop is a small pouch on the floor; walk over it to pick it up. What you
  carry is in `RunState.materials` and is saved with the room checkpoint.
- Come home alive (victory or abandoning the run) and the materials are banked
  in the company store (`CampaignState.materials`); the return report lists them.
- Die and they're lost.
- The banked store shows on the Hearth's **Merchants** page, under the pantry.

## Visitors want them

Deliver jobs can ask for materials: `{"type": "deliver", "material": id,
"count": n}` in `data/visitors.json`. Dr. Calden Ashwick's *Spore Samples*
wants 5 Spore Sacs, and Tessaly Vane's *Bones for Steel* wants 10 Grave Dust.
Crafting will use them later.

## Code and tests

- `scripts/game/materials.gd`: data lookups, which material an enemy drops, adding to a store.
- `slasher_forest.gd → _roll_enemy_drop, _spawn_material_drop, _collect_loot`.
- `hearth_expeditions.gd → settle` banks; `visitor_service.gd` handles deliveries.
- Test: `tests/drops_materials_test.gd`.
