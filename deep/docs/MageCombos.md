# Mage combo design and practice guide

Open **Armory -> Enter testing ground**, then use **Combos [C]** or press **C** to enable the optional practice panel. Select any recipe for your current build. The panel shows the exact named actions, completed steps, next step, remaining time, the payoff, rejected actions, and a success counter. Hiding it never disables combos. Build editing pauses combat and combo clocks. Reset clears progress and active payloads; the practice counter persists for the same build during this visit. Switching kits selects the new kit's recipes and clears its practice counters.

There are **36 playable Mage combos: six per kit**, including the standard spellbook's three preserved combos and three additions. The four existing Mage weapons share the standard six. Other classes display their existing recipes if any. These are prototype mechanics; release acquisition remains undecided.

## Rules and notation

**B** = Basic (click); **S** = Special (Space); **D** = Defensive (Shift-click); **M** = Movement (right-click). A controller's corresponding four actions works too. Force Prism specifically requires Repel to hit an enemy before the next two inputs. A step has **2.5 seconds** to follow the previous accepted step; this window refreshes after each matching step. Use discrete clicks when learning a sequence: holding Basic sends additional casts which can reset another recipe. Cooldown/resource rejection and obstructed movement do not advance or clear progress. A wrong successful action resets a recipe or starts a new matching prefix. All recipes use existing slot cooldowns and costs; combinations do not waive Mana costs.

Payoffs occur in addition to the last normal ability. Every new bonus attack is secondary: no Mana, recursive item hit procs, or item echo copies. Cold-kill shards may intentionally propagate, once per victim, and fire can ignite trails. New bonus damage scales with spell power and the current progression multiplier of standard Mage Basic. Numbers below are **provisional**, not final encounter balance. Normal collisions, wall checks, boss damage caps/shields, and ordinary-enemy-only displacement/control still apply.

New bonus fields last at most three seconds (frozen terrain is five seconds); keep at most eight simultaneous combo fields, evicting the oldest on overflow. Barriers replace rather than stack, expire after three seconds, never heal, and release shards only when exhausted by real incoming damage. Recasting before expiry replaces unused retaliation. Clearing the build/floor destroys bonus projectiles, fields, pending shots, barriers, and recipes alongside the arena. The panel is optional training UI; the Mage runtime supports the recipes wherever that equipped kit is available.

## Apprentice's Spellbook

Keep ranged arcane casting mobile. Crossfire rewards two origins, Repulsion Well controls your old position, and Astral Bulwark turns a defensive sequence into a retaliatory shield.

| Design ID | Combo | Sequence | Exact payoff / practice purpose |
|---|---|---|---|
| spellstorm_volley | Spellstorm Volley | B -> B -> M -> S | Three Fireballs in a 12-degree fan; each deals 45% of the normal Special damage. |
| riftburst | Riftburst | S -> M | Echo the last Fireball at Blink departure for 75% damage in 105 range. |
| force_prism | Force Prism | D hits an enemy -> B -> S | The finishing Fireball fractures into six 220-range bolts at 20% damage, including wall impacts. |
| arcane_crossfire | Arcane Crossfire | D -> M -> B | Blink after Repel, then fire two crossing arcane bolts from your departure and arrival points. |
| repulsion_well | Repulsion Well | B -> D -> M | Leave a two-second, 120-radius gravity pocket at Blink departure: pull ordinary foes and pulse arcane damage. |
| astral_bulwark | Astral Bulwark | M -> B -> D | Gain a three-second barrier worth 25% maximum HP; release six arcane bolts when it is exhausted. |

## Tome of the Pyromancer

Choose between preparing long burning lanes, staying close with a moving aura, or cashing out marked foes. Flashover requires a real Basic hit to apply Burn; an empty sequence still completes but has no marked targets to detonate.

| Design ID | Combo | Sequence | Exact payoff / practice purpose |
|---|---|---|---|
| backdraft | Backdraft | M -> B -> S | Ignite every stored trail and detonate an extra 90-radius burst at each burning trail midpoint. |
| furnace_wake | Furnace Wake | D -> M -> B | Extend the independent Furnace aura to 1.5 seconds and instantly ignite the new dash trail. |
| wildfire_braid | Wildfire Braid | B -> M -> B | Fire five piercing flame lances in a 50-degree fan, lighting multiple lanes. |
| flashover | Flashover | B -> D -> S | Consume nearby owned Burns for a 30x fire burst around each marked enemy; overlapping bursts can hit a pack. |
| ember_orbit | Ember Orbit | M -> D -> B | Create a three-second moving 85-radius fire aura, pulsing 4x damage every 0.4 seconds. |
| ashen_return | Ashen Return | S -> B -> M | Leave a two-second 120-radius ash field at departure: fire pulses and a 40% ordinary-enemy slow. |

## Winterglass Codex

Trade basic single-target damage for shatter chains and terrain. Icebreaker requires Needle hits that apply Chill. Keep enemies away from the wall placement space when using Cold Front or Diamond Guard. Bosses accept damage but ignore hard control.

| Design ID | Combo | Sequence | Exact payoff / practice purpose |
|---|---|---|---|
| whiteout | Whiteout | M -> B -> S | Freeze a five-second 140-radius field at your current position and send eight ice needles radially. |
| glacial_crosscut | Glacial Crosscut | B -> M -> B | Fire three parallel piercing ice lances from separated lanes for 12x damage each. |
| cold_front | Cold Front | D -> B -> S | Extend the current Icebook Wall to five seconds and fire five ice needles from its center (or your position). |
| icebreaker | Icebreaker | B -> D -> S | Consume nearby Chill and burst around each marked foe: 8x damage per consumed stack in 80 range. |
| permafrost | Permafrost | S -> B -> M | Leave a five-second 140-radius frozen pool at departure and pulse 20x ice damage there. |
| diamond_guard | Diamond Guard | M -> B -> D | Gain a three-second 25%-HP barrier that releases eight radial ice needles when exhausted. |

## Stormbringer's Grimoire

Choose stationary rod geometry, a moving thunder field, or close-range arrival bursts. Closed Circuit needs at least two rods to produce a link; use the first and last Specials to position them around a target. Forked Horizon works from all rods, or produces a two-bolt fallback before rods exist.

| Design ID | Combo | Sequence | Exact payoff / practice purpose |
|---|---|---|---|
| closed_circuit | Closed Circuit | S -> B -> S | Link every pair of active rods: enemies within 24 of a link take 20x lightning once per combo. |
| thunderstep | Thunderstep | S -> B -> M | On arrival, discharge a 130-radius 20x lightning burst and eight radial lightning bolts. |
| overcharge | Overcharge | D -> B -> S | Charge every active rod for a doubled next pulse and bring that pulse forward to the next physics tick. |
| forked_horizon | Forked Horizon | M -> D -> B | Each rod arcs to its two nearest enemies within 180, for 12x secondary lightning per rod. |
| rolling_thunder | Rolling Thunder | B -> M -> S | Launch a moving 90-radius thunder field along aim for two seconds, pulsing 5x damage every 0.4 seconds. |
| storm_cage | Storm Cage | B -> D -> M | Discharge 20x lightning within 140 at arrival and root ordinary foes for 0.5 seconds; bosses only take damage. |

## Grimoire of Gravity

Choose location control, return-point tactics, or interception. Event Horizon persists after native Collapse resolves. Return Trajectory rewards leaving an anchor with the opening movement and returning with the last movement while the three-second anchor is alive.

| Design ID | Combo | Sequence | Exact payoff / practice purpose |
|---|---|---|---|
| orbital_slingshot | Orbital Slingshot | S -> M -> B | Launch six piercing arcane stones radially from the live well or your position, dealing 12x each. |
| event_horizon | Event Horizon | B -> D -> S | Add a two-second 170-radius pulling field at the well or aimed position, pulsing 5x arcane damage. |
| singularity_step | Singularity Step | B -> S -> M | Leave a one-second 140-radius pulling field at departure, ending in a 25x arcane collapse. |
| satellite_guard | Satellite Guard | M -> B -> D | Orbit a 95-radius screen for two seconds; intercept up to three ordinary hostile shots and fire a stone down each intercepted lane. |
| tidal_inversion | Tidal Inversion | D -> M -> S | Burst outward at the return anchor or your position for 25x arcane damage and ordinary-enemy knockback. |
| return_trajectory | Return Trajectory | M -> S -> M | Launch three staggered piercing stones from your last departure toward the return landing, for 12x each. |

## Mirrorbound Manuscript

Choose precise recorded angles, cursor-directed crossfire, or a defensive verdict. Palimpsest copies half the recorded damage rather than a fixed unmodified value. The temporary images in Hall of Mirrors are visual firing origins, never autonomous summons.

| Design ID | Combo | Sequence | Exact payoff / practice purpose |
|---|---|---|---|
| palimpsest | Palimpsest | M -> B -> S | Alongside Read Again, send two half-strength recorded bolts from the mirror at plus/minus 18 degrees. |
| hall_of_mirrors | Hall of Mirrors | B -> M -> B | Fire from two ephemeral mirror images 75 to either side of your departure point; each piercing bolt deals 12x. |
| silver_crossfire | Silver Crossfire | M -> S -> B | Fire three 12x bolts from the mirror, aimed toward the clicked point with a 30-degree spread. |
| blank_verdict | Blank Verdict | B -> D -> S | Gain a three-second 20%-HP barrier and fire a 25x piercing verdict down the current aim from the mirror or you. |
| echo_passage | Echo Passage | S -> B -> M | Release a 15x piercing bolt from the old mirror and the new reflection; both aim down your departure direction. |
| prismatic_chorus | Prismatic Chorus | D -> B -> S | Fire four 10x piercing replay bolts from the mirror (or you) in a 60-degree fan. |

## Testing and production notes

Use **Cluster** for targeting geometry and DPS; use **Live enemies** for cold-death chains because training dummies are immortal. Start with no items to isolate a payoff, then compare item builds. Watch each rod placement and mirror origin rather than treating a combo as a damage macro. Boss targets verify caps and control immunity, but do not represent pack-clearing strength.

The existing animated projectile assets support bonus bolts. Animated sigils and elemental burst rings show timed fields; Hall of Mirrors has transient mirror silhouettes; Satellite Guard shows rotating stones; barriers show their remaining amount. The panel scrolls when necessary and stays above the arena controls at both supported sizes. No external assets or new acquisition/save formats were introduced.

`mage_combo_practice_test.gd` exercises all 36 sequences through actual player actions, records successful practice completions, checks recipe IDs/counts, validates secondary projectile safety, and checks failed-cast rollback, expiry, editing pause, reset cleanup, and the optional panel. Additional payload checks cover barriers, rod overcharge/links, frozen pool speed, field damage/control/expiry, and shot interception. Existing Mage spell and standard combo suites retain their independent coverage. Numerical encounter balance remains for playtesting.
