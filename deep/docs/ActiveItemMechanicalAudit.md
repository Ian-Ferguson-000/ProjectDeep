# Authored Active Item Mechanical Audit

This is the completion ledger for the 35 Fighter, Mage, and Neutral active
items. An item is only **verified** when its tactical loop is reachable in live
play and a behavior test proves the defining payoff; an animation alone does
not count.

## Fighter

| Item | Tactical loop and best improvement | State |
|---|---|---|
| Eldritch Bowstaff | Stack curses, choose when to execute, then convert stacks into allied bodies. Keep the stack-to-minion payoff and verify ordinary attacks can trigger it. | Verified |
| Demon Blade | Trade safety for a short, readable damage/haste frenzy after drawing blood. Keep doubled incoming damage as the meaningful cost. | Verified |
| Storm Trident | Commit the weapon to an aimed pin zone, exploit double damage, then physically retrieve it. | Verified |
| Valkyrian Sling | Route a ricochet and intercept the return with a defensive parry to relaunch it stronger. | Verified |
| Dragonbone Dagger | Focus one armored target to build refreshing vulnerability that benefits subsequent strikes. | Verified |
| Archon Crossbow | Line enemies up so one bolt drags the formation and gains damage for each body pierced. | Verified |
| Divine Hammer | Cluster enemies for radiant splash and route a killing blow into an immediate repeat smash. | Verified |
| Grim Reaver | Fish for wide criticals, then maintain kill-driven rampage stacks. | Verified |
| Sentinel Shield | Use a directional bash as hard displacement, interrupt, and space creation rather than generic damage. | Verified |
| Umbral Bow | Leash several targets, steal their speed, and kite while the links remain active. | Verified |

The Fighter suite already has direct behavior coverage for all ten defining
loops in `tests/fighter_arsenal_test.gd`; no structural rewrite is currently
justified.

## Mage

| Item | Tactical loop and best improvement | State |
|---|---|---|
| Michael's Orb | Charge from basic hits, then release an elemental seeking bolt that explodes and pinballs. | Verified |
| Gulthias Staff | Secure a bolt kill to plant attackable foliage, then deliberately shoot it to raise a treant. | Verified |
| Skyblinder Staff | Decide when to release a light charge; charge time scales radius, damage, and a real control stun rather than an ordinary flinch. | Strengthened and verified |
| Dragonstaff of Ahghairon | Channel a real cone, spend fuel, and extend the channel by charring kills. | Verified |
| Jade Serpent Staff | Mark and poison prey, then choose a marked execution that releases a chaining spectral snake. | Verified |
| Arachne Staff | Draw a player-shaped control line, trap enemies on it, and convert caught count into speed and damage. | Verified |
| Tome of Toth | Sustain an accuracy streak for stacking damage; a miss must collapse the stack. | Verified |
| Shango's Shatterer | Aim a vector of immediate lightning markers, then herd enemies into delayed thunder bursts. | Verified |
| Solar Scepter | Hold enemies in a damaging aura to build fire vulnerability; taking damage retaliates with a flare. | Verified |
| Drumamu's Bargain | Sacrifice movement while channeling an expanding pull-and-damage singularity. | Verified |

## Neutral

| Item | Tactical loop and best improvement | State |
|---|---|---|
| Siren Song Lyre | Wound enemies below 25% to trigger opportunistic friendly fire; activation turns the whole room against itself. | Verified |
| Witherbloom Brooche | Fight around kill-grown blooms to trade positioning for repeated healing and enemy slow. | Verified |
| White Dragon Mask | Aim damaging frost through a formation, then repeatedly strike frosted targets to cascade ice into neighbors. | Strengthened and verified |
| Black Titan Crown | Let enemies approach for proportional defense, endure attacks, then return stored damage offensively during the window. | Verified |
| Dissonant Whisper Jar | Bank one scream per death and choose the room where the stored seeking phantasms are released. | Verified |
| Mahoragan Adaption Wheel | Learn repeated enemy archetype damage, then activate to mirror learned resistance as offense against that archetype. | Verified |
| Pandora's Paradoxical Compass | Place an immediate damaging control point and alternate between pull and repulsion on successive uses. | Strengthened and verified |
| Vibranium Tattoo | Bank travelled distance, deliberately prime one empowered attack, then release a target-centered kinetic shockwave. | Rebuilt and verified |
| Shadowfell Brand | Maintain unbroken movement for passive speed/crit, then activate a guaranteed ambush that is lost when struck. | Strengthened and verified |
| Blood Ruby Gem | Convert missing health into damage, bank nearby kills, and cash charges into allied blood minions. | Verified reference implementation |
| Abyssal Sapphire Gem | Build pressure through hits/contact and rupture it; activation now creates baseline pressure nearby when used cold. | Strengthened and verified |
| Feywild Shawl | Accept unpredictable neutral fey, with Charisma shifting count and allegiance rather than guaranteeing safety. | Verified |
| Bramble Vine Snare | Aim a tunnel, seed deterministic control points along it, double damage to caught prey, and guarantee an eruption at the chosen endpoint. | Rebuilt and verified |
| Heartbreaker Amulet | Activation now links nearby enemies immediately, then focus-fire any member to echo damage across the network. | Strengthened and verified |
| War Horn of Valor | Create a proximity risk field that makes enemies faster and more vulnerable, then exploit the window with damage and life-steal. | Verified |

## Verification gates

All 35 items now have direct defining-behavior coverage. The Fighter, Mage,
Neutral, active-item, pickup/drop, game-loop, continuous-dungeon, class-kit,
combat-stat, persistence, and release-readiness suites pass together. A clean
headless editor import also verifies that the integrated scripts and resources
parse in Godot 4.7.2.
