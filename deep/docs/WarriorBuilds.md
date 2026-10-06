# Warrior prototypes in the training hall

Open **Armory -> Enter testing ground -> Warrior**. The four existing Warrior weapons retain **Veteran's Sword and Shield** abilities, and five alternative weapon kits are unlocked here. There are **six combos for each kit**, including the standard's four preserved combos and two additions. Enable **Combos [C]** for live practice. See [all Warrior combos](WarriorCombos.md).

These are authorized playable prototypes. Recommended/reserve release classifications remain unchanged, and expedition drops, Hearth persistence, save formats, and release acquisition are separate decisions. Current numbers below replace the older slow timing examples in the [Warrior design catalogue](equipment-design/warrior.md).

## Shared rules

The live HUD calls the Warrior resource **Stamina**; earlier design documents call it Momentum. Alternatives gain resource through their own hit/guard rules, capped by the existing resource maximum and respecting suppression. Specials cost **two Stamina**, with a **0.9s base cooldown**. Movement is free with **0.65s base cooldown**. Defensive abilities use **0.7s**. The standard kit retains its existing cooldowns, charge cost, and three-hit Slash recovery.

All alternatives transfer the damage-coefficient and cooldown multipliers from the corresponding progressed Warrior slots, while their tactical mechanics stay kit-specific. Standard Charge/Slash-chain, Crosscut, Flowing Assault, and progression-specific behavior do not automatically transfer. Current item effects still apply to primary attacks. Extra combo hits, duplicate special cuts, and item echoes cannot duplicate Stamina, hit procs, or recursive echoes. Compare the same input mode: held Basic repeats through the game's existing cooldown multiplier; the figures here describe discrete activations.

All attacks are **physical**. Lines and sweeps check walls; boss damage caps/shields remain active. Ordinary forced movement uses collision-safe motion. New plain attacks do not stagger bosses; explicit stagger effects are replaced by damage rather than extended when an ordinary foe is already staggered. Kit-specific fields, pending strikes, tether state, pair/exposure state, support recipients, combo payloads, and temporary buffs are cleared with resets or kit removal. No kit needs a rare item or an ally to function.

Shared temporary barriers replace by source and use the strongest available amount rather than adding barriers together. Absorbing a hit consumes that amount from all overlapping shared layers. They expire, never heal, and are separate from current item rules and Mage mechanics. Banner speed briefly refreshes while a recipient remains near the field; leaving removes the benefit within 0.08s. Expiry/removal clears all remembered recipients immediately.

Numbers are **provisional tuning**, not measured encounter balance. The numerical checks cover baseline primary cadence across entry and progressed variants; real delivered damage still depends on targeting, windups, defense, resource use, and enemy behavior.

## Veteran's Sword and Shield

The four current weapons keep Slash, Cleave, Parry, and Charge. Existing Crosscut, Flowing Assault, Break the Line, and Vengeful Spiral remain unchanged. **Shield Drum** adds a close ring payoff after a guard/attack/special sequence; **Marching Edge** covers Charge departure with a line attack. The standard's longer special/parry cooldowns remain baseline behavior rather than being copied to the alternatives.

## Headsman's Greatsword

Broad arcs and a short visible commitment window separate it from the standard chain. Its strength is clearing clustered melee approaches; fast evasive foes can leave Sentence before resolution.

| Slot | Ability | Base prototype behavior |
|---|---|---|
| Basic | Hew | 0.24s CD; 4.8x attack power. Snapshot a 170-range, 155-degree sweep; it lands after a 0.12s windup. Two Stamina on connection, once per cast. A readied Hew removes the windup, not the cooldown. |
| Special | Sentence | Two Stamina; 0.9s CD. Snapshot a 300-long lane with 42 half-width; resolve after 0.22s for 10x attack power. Briefly stagger ordinary enemies. Already-staggered ordinary foes take 25% extra damage instead of renewed control; bosses take damage with no stagger. |
| Defensive | Shoulder the Blow | 0.7s CD. For 0.6s, mitigate the next frontal hit by 60%, gain at most one Stamina, and ready an instant Hew for two seconds. Rear attacks deal full damage and do not spend the remaining guard window. |
| Movement | Committed Step | 0.65s CD. Step forward up to 200 with 0.15s protection. The shorter reach and anchored windup reward committing to a punishable angle; movement neither resets cooldowns nor refunds Stamina. |

Try a **punishment build**: Shoulder into instant Hew, then Red Sentence. Or a **mobile reaper**: Committed Step into Reaping Advance or Execution Wheel. Current attack-power and cooldown items support both; the proposed Veteran's Whetstone and Runebound Bracer catalogue revisions are not implemented.

## Borderkeeper's Spear

Spacing and single-use terrain threats replace close sweeps and reactive long charges. Surrounding foes can bypass the line; a boss inside the lane can still trigger it.

| Slot | Ability | Base prototype behavior |
|---|---|---|
| Basic | Measured Thrust | 0.18s CD; 3.2x attack power along a 260-long, 24-half-width line. The last quarter is a tip zone: +35% damage and two Stamina once if any tip target connects. Close hits remain useful but grant none. |
| Special | Hold the Pass | Two Stamina; 0.9s CD. Snapshot a 320-long, 32-half-width lane for three seconds. Arm after 0.12s; the first eligible enemy in the lane takes 10x damage and ordinary foes briefly stagger. A stationary boss triggers it without needing to move. One lane per caster; replacing discards the old lane. |
| Defensive | Yielding Guard | 0.7s CD. Collision-checked backstep up to 110 with 0.1s protection, then a 0.6s frontal next-hit guard reducing damage 60%; prevention grants at most one Stamina. Refuse obstructed movement without consuming the action. |
| Movement | Flank March | 0.65s CD. Dash 220 laterally, choosing the side from movement input relative to aim; with no movement input, retreat along negative aim. Gain 0.15s protection. No damage or tip resource from movement. |

Try a **lane defender**: Hold the Pass, Second Rank, and Yielding Guard. Or a **tip hunter**: Flank March into Crossing Points and Needle Gate. Current attack-power/movement items work without requiring a rare item. Strong allied knockback can remove targets from your tip zone or planted lane.

## Banner of the Vanguard

The Warrior chooses where sustained pressure and protection happen. It remains effective alone through repeatable sword damage, planting impacts, self speed, and self barriers; an ally is never needed to trigger its core payoff.

| Slot | Ability | Base prototype behavior |
|---|---|---|
| Basic | Rally Cut | 0.18s CD; 3.6x attack power in a 135-range, 110-degree sweep. Gain two Stamina once on hit. Connecting cuts from within the rally radius add 0.5s per target to the banner, with a total two-second extension budget per planting. |
| Special | Plant the Standard | Two Stamina; 0.9s CD. Place one banner within 250 aimed range for five seconds. Planting deals 10x physical damage within 150. Its 150-radius aura gives the owner and nearby living, visible, actively deployed SlasherPlayer allies +15% movement speed. This aura is a field, never a summon. |
| Defensive | Stand Together | 0.7s CD. Grant self a 15%-maximum-HP barrier, minimum one. If the owner is near the banner, also grant it to the nearest living deployed ally within that same banner radius. With a recipient, both last two seconds; alone, self lasts three. No heal or automatic resurrection. |
| Movement | Advance the Colors | 0.65s CD. Advance up to 230 with 0.15s protection. Carry a live banner to landing without resetting its lifetime, extension budget, or planting damage. No banner is required for movement. |

Try **aggressive rally**: Unbroken Standard and Rally March keep pressure moving. Or **formation support**: Captain's Oath and Covering Colors protect an advancing party. Speed sources use the strongest current bonus, not their product. Recipients must be nearby and actively deployed; benched or dead members get nothing.

## Duelist's Paired Sabres

Alternating strokes and preserving a target pair create a faster rhythm than the standard three-hit chain. This is visible martial dueling, with no stealth or execution bypass. Switching targets or missing interrupts resource flow.

| Slot | Ability | Base prototype behavior |
|---|---|---|
| Basic | Answering Cuts | 0.14s CD; 3x attack power in alternating left/right 125-range, 95-degree cuts. A second connected stroke on the same enemy within two seconds gains two Stamina; the first earns none. Misses/new first targets restart the pair; movement preserves it. Exposure widens the next Basic to 145 degrees and boosts damage 35% against that exposed target only. |
| Special | Crossing Blades | Two Stamina; 0.9s CD. Snapshot two opposing 175-range, 85-degree arcs, resolving at 0.08s and 0.16s. Each deals half of the 10x total. The second is secondary and cannot double primary hit procs. Both hits are needed for the full combined payoff. |
| Defensive | Bind Steel | 0.7s CD. For 0.6s, fully parry one frontal melee attacker within 130, gain at most one Stamina, and expose that enemy for two seconds. Frontal ranged/unknown-source hits are mitigated 50% without exposure; rear hits bypass the guard. Exposure never moves or stuns a boss. |
| Movement | Passing Step | 0.65s CD. Dash 220 laterally relative to aim, choosing the opposite side when movement input requests it; default to the left-hand side. Gain 0.15s protection and preserve the Basic pair. |

Try **paired skirmishing**: Passing Step between cuts, then Answered Challenge or Circling Blades. Or **riposte precision**: Bind Steel, Steel Verdict, and Perfect Measure. Bosses can be exposed but do not receive hard control. Broad uncontrolled knockback can disrupt the same-target pair.

## Chain of the Siege-Breaker

A longer first-target strike, temporary tether, and collision-safe pull/reel distinguish it from multi-target Spear lines. It excels against reachable ranged priority foes; props and walls can sever its route.

| Slot | Ability | Base prototype behavior |
|---|---|---|
| Basic | Cast the Weight | 0.22s CD; 4.2x attack power. Strike only the nearest eligible enemy in a 300-long, 28-half-width aimed line; connect for two Stamina and a two-second tether. One tether only. A miss severs the old one; a broken wall line of sight, death, or expiry also severs it. |
| Special | Draw and Break | Two Stamina; 0.9s CD. Pull tethered ordinary prey up to 180 toward an 85-distance standoff, respecting collision, then slam 100 range around it for 10x damage. A boss takes the full slam at its existing point without displacement. Without a tether, slam 95 ahead for 75% damage. Sever the tether afterward. |
| Defensive | Chain Guard | 0.7s CD. Spin a frontal 130-range guard for 0.7s and destroy at most three ordinary hostile projectiles; beams, unblockable shots, and already-reflected shots bypass it. Also mitigate the next frontal hit by 50%. Award at most one Stamina total across interception and mitigation. Interception persists after that hit is consumed. |
| Movement | Reel Through | 0.65s CD. With a live tether, move toward its point, stopping 55 before the target; otherwise advance 230 along aim. Validate travel against walls and floor bounds. Gain 0.15s protection and sever the tether only on successful movement. |

Try **breach control**: Cast, Draw, and Breach Run or Anchor Crash. Or **siege sweeper**: Chain Guard, Iron Net, and Siege Wheel. Linked Weights adds bounded coverage without making the tether a lightning-style recursive chain. Bosses take damage at their own point and remain in their arena.

## Readability and production

Broad Greatsword sector trails contrast with narrow highlighted Spear tips and arming lanes. The Banner has animated cloth, a radius boundary, and a finite lifetime ring. Sabres alternate blue/gold trails and mark exposed targets; Chain renders its weighted tether and intercepted-shot guard. Shared barriers show their remaining amount. Every training impact reports physical damage and the ability source. Windups show anchored intent before damage, then a brighter swing after impact.

The prototypes use current Warrior character animation and code-drawn weapon effects; final weapon-specific character art, sounds, haptics, and longer encounter balancing remain production tasks. New acquisition, release item revisions, and gear persistence were not added.

## Verification

`warrior_kits_test.gd` checks 95 entry/progressed configurations, exercises all 36 combo sequences through actual actions and a real three-Stamina budget, and verifies tip rewards, windups, directional protection, pair rhythm, single-use lanes, boss-safe pulls, wall-broken tethers, shared barriers, deployed/benched recipient filtering, finite banner extension, and reset cleanup. It also covers guard interception caps, support expiry, and combo-specific modifications. `warrior_visual_capture.gd` captures every alternative and the editor at 1280x720 and 960x540. Existing Mage, standard-combo, class, party, item/combat, and targeting regressions remain in the validation suite.
