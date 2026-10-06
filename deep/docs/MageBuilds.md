# Mage prototypes in the testing ground

Open **Armory → Enter testing ground → Mage**. The equipment picker contains the four existing standard-kit weapons plus five alternate kits: **Tome of the Pyromancer**, **Winterglass Codex**, **Stormbringer's Grimoire**, **Grimoire of Gravity**, and **Mirrorbound Manuscript**. All are unlocked here. The original spellbook abilities and combos remain intact on existing weapons.

These are playable prototypes, not release acquisition or save changes. The [design catalogue](equipment-design/mage.md) keeps its recommended/reserve classifications for later release selection. Both reserve Mage concepts are implemented for comparison. See the [testing-ground guide](TestingGround.md) for controls, build selection, items, and damage measurement.

## Shared power and safety rules

All alternatives use the four existing action slots with a **0.18-second** base Basic cooldown. Pyromancer, Stormbringer, Gravity, and Mirrorbound have **12x spell power** direct Basic damage before modifiers, approximately 13% above the standard Mage's normalized primary cadence. Winterglass is deliberately reduced to **5x spell power** (58% lower than its previous 12x value), trading direct damage for cold-kill shatter chains. Actual delivered damage depends on aim, travel, input mode, areas, resources, defenses, and encounters. This does not establish final balance.

Each alternate inherits the damage-coefficient and cooldown multipliers of the corresponding progressed Mage action. Standard-kit combo mechanics and progression effects such as Force Prism, standard impact echoes, and Blink wake do not transfer. Equipped items retain their current implemented rules; proposed catalogue item effects are not automatically implemented.

Specials cost **one Mana** and have a **0.9-second base cooldown**. Movement is free. A successful Basic awards Mana once per cast, including piercing shots, splash, and lightning chains. Secondary pulses, reflections, replays, and bounces cannot award Mana or recursively trigger hit effects. Winterglass shatter needles intentionally propagate through subsequent cold kills, once per defeated enemy. Existing item-generated projectile echoes cannot record shots or apply new kit setup. Resource suppression still works.

Fields and delayed actions belong to the casting kit. Resetting, replacing the build, or leaving the floor clears them. Ice walls restore navigation and enemy collision masks; Heavy Air restores projectile speed. Boss hit caps and damage shields apply to every damage event. Bosses receive Chill damage bonuses and gravity bursts without movement slow, hard stagger, or forced displacement.

Ground fields render below combatants; lightning, projectile accents, and status pips render above. Damage numbers explicitly label **Ice**, **Lightning**, or **Arcane**, with source labels. No new kit depends on a rare item to function.

## Tome of the Pyromancer

| Slot | Ability | Current prototype behavior |
|---|---|---|
| Basic | Ember Lance | Rapid piercing fire projectile; 12 × spell power, 0.18-second cooldown. Applies four-second Burn. Any fire projectile can ignite a nearby Cinder Trail, including allied fire and fire item echoes. |
| Special | Conflagration | One Mana, 0.9-second cooldown; aimed blast resolves after 0.28 seconds, deals 20 × spell power, consumes owned Burn for 30% extra damage, and ignites any trails touching its blast area. Existing burning ground in the area is consumed at cast time to enlarge radius from 100 to 120. Newly lit trails remain after the blast. |
| Defensive | Furnace Mantle | 0.6-second cooldown and aura duration. Immediately burns every enemy within 130 range, then keeps refreshing nearby Burn during the window, independent of deflection, interception, or taking damage. Its next-hit 60% mitigation remains separate; consuming mitigation does not end the aura. Aura contact also lights Cinder Trails. |
| Movement | Cinder Trail | Dash up to 300 along aim, 0.65-second cooldown, 0.2-second protection. Each dash leaves its own four-second unlit path. Any fire touching the path—including projectiles, fire hits, Conflagration, burning enemies, burning floor, or the mantle—ignites the full path into continuous two-second flames. Paths and flame lifetimes coexist across repeated dashes. |

Flames use overlapping tiles spaced at most 40 apart, each covering 36 range. An enemy takes at most one ground tick **per dash trail** every 0.25 seconds, so the visual tile overlaps do not multiply a single trail's damage. Distinct dash trails intentionally stack. Ground ticks deal 2.5 × spell power; Burn ticks deal 1.2 × spell power every 0.5 seconds. Secondary damage grants no Mana or hit procs. All values are provisional and untested for final encounter balance.

## Winterglass Codex

Choose pack-clearing cold kills and frozen movement lanes. Basic direct damage is intentionally lower; Chill amplifies Fracture, and cold kills start radial shatter chains. Boss damage depends more heavily on Fracture because there are no deaths to chain until the boss falls.

| Slot | Ability | Base prototype behavior |
|---|---|---|
| Basic | Rime Needle | 5 × spell power; 400-range ice projectile, 900 speed, 24 hit radius. Apply one Chill for three seconds, maximum three. Ordinary enemies slow by 10% per stack; bosses retain stacks without slowing. Reapplication refreshes duration. |
| Special | Fracture | After 0.16 seconds, strike the aimed 100-degree cone out to 270 range for 20 × spell power. Consume owned Chill for 20% extra damage per stack, up to 60%. Three-stack ordinary targets briefly stagger; bosses do not. Snapshot aim when casting; line of sight is required. The resolved cone leaves frozen terrain for five seconds. |
| Defensive | Icebook Wall | 0.65-second cooldown. Place a 130-wide wall 90 ahead of aim for two seconds. It blocks hostile projectiles and enemies while friendly movement and shots pass through. Enemy navigation routes around it. One wall at a time; refuse occupied or obstructed placement. Only its first blocked shot awards one Mana. Beams/unblockable shots bypass interception. |
| Movement | Skating Retreat | 0.65-second cooldown. Glide backward up to 300 range with 0.2-second protection. Leave a five-second frozen strip. Both frozen field types slow ordinary enemies by 35% and give this caster 40% extra walking speed while inside. Fields coexist, their speed bonuses do not stack, and they create neither Chill nor Mana. Speed immediately returns to normal outside. |

Any enemy killed by this caster's ice damage shatters once, launching **eight radial Rime Needles** with 220 range and damage equal to 2.4× the reduced Basic (12× spell power before rounding/progression). Shards have normal collision and boss durability, cannot grant Mana/item hit procs, and can cause another cold death to shatter. Immortal training dummies never die; use living encounter targets to test shatter chains.

Try **Needle/Fracture**: aim three Needles at a priority target, then cash out stacks. Or try **wall/skate**: cover one firing lane with a wall, slow pursuit through the retreat strip, and fire from the new angle. Open crossfire can bypass the wall; broad ally knockback can scatter a prepared cone. Allies can use the wall for cover and shoot through it, but cannot consume this caster's Chill. Current spell-power and cooldown items support both approaches; the proposed Rime Spindle behavior remains unimplemented.

Look for three crystalline pips over a chilled enemy, a row of standing ice crystals for the wall, a pale marked skating lane, and a clearly outlined Fracture cone and shard burst.

## Stormbringer's Grimoire

This replaces the catalogue name **Stormcaller's Folio**. Forked Spark always bounces; the conductor improves damage retention rather than enabling the attack.

| Slot | Ability | Base prototype behavior |
|---|---|---|
| Basic | Forked Spark | Aim an instant bolt at an enemy within 360 range, then bounce to up to three more distinct enemies within 180 of the previous target. **Without a conductor: each bounce retains 70% of the previous damage**, rounded to an integer, minimum one. **While an owned conductor is active: every bounce retains full primary damage.** No repeated targets, loops, wall-crossing links, or offscreen targeting. Only the first hit grants Mana or primary hit effects. |
| Special | Grounding Rod | Place a conductor within 340 range for five seconds, with **up to three active rods**. First pulse after 0.18 seconds, then every 0.45 seconds; 110-radius pulses deal 8 × spell power. A fourth placement replaces the oldest rod; other rods keep their lifetime and charge. Pulses require clear line of sight and produce no Mana or item hit chains. |
| Defensive | Static Screen | 0.6-second cooldown; lasts 0.6 seconds. Destroy up to three ordinary frontal hostile shots within 130 range and a 120-degree arc. Mitigate the next incoming hit by 50%. Award at most one Mana across interception and mitigation. The first intercepted shot charges each live rod's next pulse for 50% extra damage, consumed once. No rod means no stored charge. |
| Movement | Flash Circuit | 0.65-second cooldown. Travel to the live rod nearest the world point you click, validating travel against arena bounds and obstacles. Controller aim selects the rod nearest a point 340 ahead. Without rods, move 240 along aim. Gain 0.2-second protection. Rods stay put and retain their lifetime/charge. |

Try **mobile chain casting**: Spark packs immediately, reposition freely, and only drop rods where they improve coverage. Or try **charged conductor**: place a rod in a group, screen incoming shots, and travel between established pulse areas. A lone boss receives full primary damage plus rod pulses; it is never counted as its own bounce. Enemies separated beyond bounce range reduce coverage. Allies benefit from the distributed damage but cannot charge the caster's conductor. The current inventory can improve spell power and cooldowns; revised Stormglass Bead chaining behavior is still a catalogue proposal.

Jagged animated lightning shows the exact struck path. The rod has a radius sigil, a bright charged tip, and a shrinking lifetime perimeter. The frontal screen has its own curved boundary.

## Grimoire of Gravity

Choose predicted impact and grouping, with a controlled return point for escape.

| Slot | Ability | Base prototype behavior |
|---|---|---|
| Basic | Orbiting Stone | After a 0.1-second launch delay, fire an aimed arcane orb at 700 speed with 400 range and a 65-radius impact. Snapshot origin and aim when casting; no homing. Splash awards Mana once for the cast. |
| Special | Collapse | Place a 115-radius well within 300 range. Over 0.45 seconds, pull ordinary enemies toward the center with collision-respecting movement, then burst for 25 × spell power. Bosses stay in place and take the burst. An unresolved replacement resolves the previous burst once. |
| Defensive | Heavy Air | 0.6-second cooldown. For 0.6 seconds, halve ordinary hostile projectile speed inside a 105-radius personal field and mitigate the next hit by 50%. Prevention grants one Mana. Projectiles recover their original speed on leaving, expiry, or kit removal. It does not reflect or destroy shots. |
| Movement | Anchor Exchange | Move up to 300 along aim, leaving a three-second return anchor. After a 0.2-second gate, one recast returns to that anchor and consumes it. The return starts the normal 0.65-second cooldown. Both landings gain 0.15-second protection. Both uses validate destination and restore neither health nor Mana. |

Try **collapse bombardment**: gather ordinary foes, then land splash stones and the burst together. Or try **anchor skirmishing**: leave a safe return point, advance for an attack angle, slow incoming shots, and return before pressure closes in. Fast enemies can leave the well before impact; enemies that resist displacement still take damage. Allies gain grouping opportunities, although strong outward knockback can counter the pull. Current arcane damage and cooldown items work without requiring a specific rare item.

Orbiting stones have a dark core and rotating satellites. Wells have visible spirals and a filling countdown; Heavy Air centers on the player. The anchor has a cross marker and a distinct shrinking return timer. Fields remain below the player and enemies so their windups remain visible.

## Mirrorbound Manuscript

Choose two firing origins and an explicit trade between an extra shot and defensive shielding.

| Slot | Ability | Base prototype behavior |
|---|---|---|
| Basic | Silver Script | 420-range piercing arcane bolt at 900 speed. With a live mirror, also fire a lesser piercing bolt from the mirror along the same aim for **50% Basic damage** (rounded, minimum one). Store the full primary direction and resolved damage as one recording, replacing the previous one. The lesser bolt has a smaller effect and cannot grant Mana, hit procs, echoes, or new recordings. Piercing still awards Mana once. |
| Special | Read Again | Immediately fire a self-origin heavy bolt for 20 × spell power. If a recording exists, consume it and launch that saved normal bolt from the mirror after 0.12 seconds. Its direction stays recorded rather than homing. The committed replay finishes even if the mirror expires meanwhile; resetting/removing the kit clears pending replays. It cannot generate Mana, item hit procs, echoes, or further recordings. The self shot stays useful with no mirror. |
| Defensive | Blank Page | 0.6-second cooldown; reduce the next hit within 0.6 seconds by 60%, granting one Mana on prevention. If a live mirror holds a recording, erase it and create a two-second barrier worth 10% of maximum health, minimum one. The barrier absorbs residual or subsequent damage, is consumed, replaces rather than stacks, expires, and never heals. |
| Movement | Set the Reflection | 0.65-second cooldown. Move up to 300 along aim with 0.2-second protection. Leave one five-second mirror at departure, replacing the old mirror and recording. The mirror has no body, AI, health, autonomous attacks, or summon/death triggers. |

Try **crossing lanes**: leave the mirror, aim a Script direction that will be useful from the old origin, then aim the heavy self shot down a second lane. Or try **defensive recording**: maintain one recording and decide whether to spend it on a replay or Blank Page's barrier. Mobile targets can escape one recorded lane. Allies cannot record their attacks or consume this mirror; push effects may disrupt the geometry. Current spell-power/cooldown items support both builds. Item projectile echoes never fill the recorder.

The stationary mirror has a clear silhouette, lifetime ring, and an arrow showing recorded direction. The self bolt and replay are visible in separate lanes; temporary shielding shows a **WARD** amount. Recordings disappear when consumed or when their mirror expires.

## Verification

`tests/mage_kits_test.gd` checks the deliberate Winterglass damage reduction and compares the other kits' basic damage cadence against the standard kit at entry level and across progressed branches and variants. It exercises unconditional chains and falloff, conductor support and expiry, capped screen interception/charges, Chill consumption and boss resistance, wall collision/navigation and shot blocking, well pulls and boss bursts, projectile-speed restoration, anchor returns, mirror playback and barriers, stacking continuous Cinder Trails, special ignition, unconditional Furnace burn, three-rod placement and click selection, lesser mirror shots, frozen terrain expiry/speed, and cold-death chains. `tests/testing_ground_test.gd` verifies all 29 equipment selections, resets, damage reports, and campaign isolation. `tests/mage_kits_visual_capture.gd` renders every new Mage kit at 1280 × 720 and 960 × 540.

Final encounter balance and release acquisition remain separate decisions. No campaign equipment unlocks, drops, armory persistence, or save migration were added.

