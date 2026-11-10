# Mage active items: play and verification guide

All ten items use the dungeon active slot and the walk-in armory displays.
Space activates the held item. Hold/release behavior is described below.
Escape, focus loss, pause, death, removing the runtime, and swapping items
cancel pending charge/channel states. Swapping also clears owned slows,
stuns, marks, summons, delayed attacks, and ground effects.

## Controls and combat rules

| Item | Play behavior and limits |
| --- | --- |
| Michael's Orb | Activate its 45-second window. Three distinct successful basic attacks discharge a seeking elemental bolt; one attack contributes at most one charge. An empty room preserves full charge. Five direct impacts maximum; each creates a 48-unit splash, with 10% damage falloff per bounce. Secondary damage never supplies charge. |
| Gulthias Staff | Space fires a traveling wooden bolt; recharges in 0.8 seconds. Its kills grow plants over 0.7 seconds. Shoot a mature plant with this staff to awaken one treant. Other attacks pass through plants. Maximum 12 plants and 6 treants; plants last 20 seconds and treants 12. Treants navigate the dungeon grid and telegraph their stomps. Their kills do not create plants. |
| Skyblinder Staff | Tap Space for a disruption bolt; hold up to 2 seconds and release for stronger damage, a larger impact, and longer stun. Full charge unlocks the 90-unit explosion. The full-charge cue is both visual and audible. Boss control duration is reduced to 30%; disorientation interrupts tracking and attacks. |
| Dragonstaff of Ahghairon | Hold Space for flame; release to stop. Fuel drains while firing and regenerates at 0.45/second while idle. Damage ticks every 0.16 seconds. Heat ignites exposed targets; only deaths while burning from this weapon create fuel remains. Each nearby remains marker is consumed once, with 1.4 fuel arriving alongside its ember ribbon. Walls clip both damage and the flame outline. |
| Jade Serpent Staff | Space fires a dart; 0.8-second recharge supports spreading marks. Poison has one stack and refreshes on hits. Marks last 6 seconds. A marked death releases one serpent; it only seeks marked enemies and bites each enemy once. Maximum 8 serpents, 8 targets per journey, and 5 seconds per serpent. Bites and their refreshed poison cannot breed serpents. |
| Arachne Staff | First Space anchors silk; moving places connected segments every 20 units. Second Space cuts placement. Silk persists 6 seconds after cutting. Placement lasts at most 12 seconds, 1,600 units, or 80 segments. Teleports over 180 units and blocked movement break the trail. Unique current captures grant capped bonuses; escaping or dying removes the contribution. |
| Tome of Toth | Activate for 45 seconds; basic attacks then fire spectral script. Nearby deaths add soul records, including deaths immediately after spawning. Capacity is one plus recorded souls, capped at 20. Successful shots build power within capacity; one attack can award only one stack. Genuine misses remove half the current power once. A piercing success followed by a wall collision remains successful. |
| Shango's Shatterer | Point at the intended start and press Space, then drag to aim the direction and release to commit. The start is limited to 180 units from the mage. Controller aiming uses the stick direction. Six outlined markers show exact blast locations. Lightning commits immediately, followed by thunder after 0.8 seconds with 0.14-second sequential spacing. Each enemy receives at most one thunder damage instance per cast. Escape cancels the preview. |
| Solar Scepter | Activate a 10-second, 150-unit radiant aura. Exposure builds per enemy, increases incoming fire damage by 12% per exposure unit, and disorients at the threshold. It decays outside the aura. Actual enemy damage triggers a telegraphed 135-unit fire flare, subject to a 0.9-second cooldown. Environmental/self damage does not trigger it. |
| Drumamu's Bargain | Hold Space to anchor and grow the vortex from 110 to at most 299 units over a 4.5-second channel. Enemies spiral around a 48-unit inner orbit. Boss displacement is reduced; immovable colossus weak points are never displaced. The mage remains vulnerable. Release restores movement without a damaging final explosion. |

This game uses a flat 2D collision plane. Walls and solid scenery block line of
sight and projectiles; there is no separate elevation damage rule. Open colossus
weak points receive damage through the boss's shared health. Closed points and
Crypt transition immunity remain protected. Multiple weak points belonging to
one boss do not multiply a single area hit.

## Tuning and implementation

- `data/mage_active_items.json` owns damage multipliers, durations, ranges,
  tick intervals, caps, resistance scaling, and summon/channel behavior.
- `data/active_items.json` owns slot recharge and player-facing descriptions.
- `slasher_mage_active_arsenal.gd` uses a fixed gameplay step. Its shared target
  snapshot and spatial buckets serve projectile sweeps and area queries.
  New enemy spawns enter observation immediately. Rendering never applies damage
  or advances the simulation.
- Missiles, plants, treants, webs, corpse markers, and impact animations are
  bounded data records recycled by the runtime. They create no per-effect
  physics bodies, colliders, particles, or summon nodes.
- Slows, stuns, and disorientation carry the runtime's source ID. Forest,
  Crypt, Hell, and colossus behavior loops process the same owned controls.
- Attack IDs distinguish a basic attack from its multiple hits. Projectile
  outcome tracking distinguishes enemy hits from scenery collisions.
- Solar fire vulnerability is applied once at enemy damage reception.

## Presentation

Options → **Mage Effects → Normal / Reduced** changes trails, fragments, and
decorative density. It preserves silhouettes, marks, gameplay boundaries,
charge indicators, targeting previews, and timing. Each item shows its relevant
state beside the mage: orb charge, plant/treant counts, charge progress, fuel,
marks/serpents, unique web captures, souls/power, thunder markers, flare readiness,
or vortex progress.

Effects include prismatic charging/discharge ribbons, staged plant growth,
telegraphed treant stomps, charge rings, wall-clipped flame, ember harvesting,
serpent bite windups and dissolving tails, edged silk, soul ribbons and script,
sequential thunder rings, solar exposure and flare anticipation, and a growing
spiral field. Rapid mage damage ticks are combined into compact numbers so
crowds remain visible.

## Verification

`legacy/tests/mage_active_items_test.gd` exercises every item against no enemies, one
enemy, and 48 enemies at both effect quality settings, comparing damage results.
It additionally checks attack identity, empty-room charge retention, projectile
travel, freed targets, immunity, walls, weak points, control ownership, genuine
misses, simultaneous serpent deaths, vegetation caps/navigation/expiry, repeated
effect recycling, source attribution, fuel recovery, thunder overlap, exposure
decay, independently positioned targeting, and interruption.

The frame-rate check compares Dragonstaff damage at 30, 60, and 144 Hz.
`legacy/tests/testing_ground_test.gd` activates the real armory slot and waits for
a traveling Jade dart to kill and safely release its live enemy.

Run the main suite with:

```sh
godot --headless --path . --script res://legacy/tests/mage_active_items_test.gd
```

`tests/mage_active_visual_capture.gd` captures all ten items in a crowd in normal
and reduced modes. Files are written to
`build/mage_production_<item>_<normal|reduced>.png`.
