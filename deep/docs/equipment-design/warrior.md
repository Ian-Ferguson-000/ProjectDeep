# Warrior kits

[Packet overview and shared rules](README.md) · [Review decisions](review-workbook.md)

**Class promise:** Earn Momentum by committing to melee and choosing when to stand, advance, or counter. Every kit can defeat an isolated boss without adds. All five alternatives are now authorized training-hall prototypes; release selection/acquisition remains unapproved. The [current Warrior build guide](../WarriorBuilds.md) and [36-combo catalogue](../WarriorCombos.md) describe the implemented fast tuning and supersede the older slow/held-charge examples. Standard values remain baseline observations.

| ID | Kit | Status | Distinct decisions | Cost |
|---|---|---|---|---|
| KIT-WAR-01 | Veteran's Sword and Shield | Recommended standard | Fast chains, charge lines, reactive counters | Low |
| KIT-WAR-02 | Headsman's Greatsword | Recommended | Charged arcs, recovery commitment, stagger timing | Medium |
| KIT-WAR-03 | Borderkeeper's Spear | Recommended | Tip spacing, planted lanes, retreating defense | Medium |
| KIT-WAR-04 | Banner of the Vanguard | Recommended | Rally position, formation, advancing support | High |
| KIT-WAR-05 | Duelist's Paired Sabres | Reserve | Alternating strokes, precision defense, lateral movement | Medium |
| KIT-WAR-06 | Chain of the Siege-Breaker | Reserve | Tether distance, pulls, manual retrieval | High |

## Proposed discovery sources

These are preferred offer pools, not guaranteed drops or new map requirements. Alternatives can also appear in class-compatible elite kit offers after class recruitment. First recovery adds a physical kit to the armory on successful extraction; later merchants may sell copies. Reserve sources apply only if the candidate is promoted. Unlock difficulty never grants higher baseline power.

| Kit | Preferred acquisition |
|---|---|
| [KIT-WAR-01](#kit-war-01) | Bound starter for a Warrior; always available when that class is recruited. |
| [KIT-WAR-02](#kit-war-02) | Verdant Forest elite weapon cache; later ordinary martial merchants after first recovery. |
| [KIT-WAR-03](#kit-war-03) | Verdant Forest or Sunken Mine weapon cache; favors corridor-defense rewards. |
| [KIT-WAR-04](#kit-war-04) | Ashen Farmstead completion or martial merchant after recovery; a company standard, not a nation restriction. |
| [KIT-WAR-05](#kit-war-05) | Reserve: Stone Crypt finesse cache if promoted; replaces Greatsword in the proposed launch budget. |
| [KIT-WAR-06](#kit-war-06) | Reserve: Ember Foundry weapon cache if promoted; replaces Spear in the proposed launch budget. |

<a id="kit-war-01"></a>
## KIT-WAR-01 — Veteran's Sword and Shield

**Equipment and fantasy:** Existing Sword and Shield, formally named as the standard kit. A practiced front-line striker who turns aggressive movement into clean openings. Choose it for flexibility and familiar controls.

| Slot | Baseline behavior |
|---|---|
| Basic — Slash | Aimed 118 px, 92° melee arc; base CD 0.18s, with a three-hit chain and 0.90s finisher recovery. A connecting activation gains 2 Momentum; close frontal projectiles can be deflected. |
| Special — Cleave | Spend 2 Momentum; 2.5s CD; 208 px, 140° heavy sweep. Existing combos can turn it into a full-circle stagger or echo. |
| Defensive — Parry | 3.5s CD; arm a 0.65s window. Negate the next qualifying hit; counter an available attacker and gain resource when damage is prevented. |
| Movement — Charge | 355 px traversed dash, 0.2s base CD. Runtime charges 1 Momentum despite the tuning's zero; Flowing Assault can override it to free. Hit each intersected enemy once, stagger, and gain 1 Momentum on the first enemy connection; protected during travel/landing. |

**Sequence:** Slash → Charge through a foe → Slash activates Crosscut. Preserve Flowing Assault, Break the Line, and Vengeful Spiral as standard-kit combos. Do not copy these triggers to every Warrior kit.

**Matchups:** Excellent at changing targets and correcting position; suffers against dispersed ranged attackers if charges end poorly. Bosses reward attack recognition and clean parries. Solo is fully functional. Party value comes from displacement and burst, not an invented team buff.

**Builds:** Counter specialist: [Runebound Bracer](supporting-items.md#itm-war-01) + [Mirror of the Second Guard](relics.md#rel-03). Mobile sweeper: [Redstep Spurs](supporting-items.md#itm-war-02) + [Pilgrim Bell](relics.md#rel-18). Excessive knockback can move enemies beyond the next Slash; these are positioning tools, not unconditional upgrades.

**Readability/production:** Low kit-design cost, retaining current slash/charge/parry language. Clearly distinguish third-hit recovery from a failed input. Current speed and cooldown outliers need later balance review, not changes in this packet.

<a id="kit-war-02"></a>
## KIT-WAR-02 — Headsman's Greatsword

**Equipment and fantasy:** A two-handed execution blade. Choose deliberate, sweeping punishment over continuous pursuit. Compared with the standard kit, change attack timing and defensive commitment; no shield counter loop.

| Slot | Proposed behavior |
|---|---|
| Basic - Hew | 0.24s CD; 4.8x attack power. Snapshot a 170-range, 155-degree sweep; it lands after a 0.12s windup. Two Stamina on connection, once per cast. A readied Hew removes the windup, not the cooldown. |
| Special - Sentence | Two Stamina; 0.9s CD. Snapshot a 300-long lane with 42 half-width; resolve after 0.22s for 10x attack power. Briefly stagger ordinary enemies. Already-staggered ordinary foes take 25% extra damage instead of renewed control; bosses take damage with no stagger. |
| Defensive - Shoulder the Blow | 0.7s CD. For 0.6s, mitigate the next frontal hit by 60%, gain at most one Stamina, and ready an instant Hew for two seconds. Rear attacks deal full damage and do not spend the remaining guard window. |
| Movement - Committed Step | 0.65s CD. Step forward up to 200 with 0.15s protection. The shorter reach and anchored windup reward committing to a punishable angle; movement neither resets cooldowns nor refunds Stamina. |

**Sequence:** Bait a swing → Shoulder → instant wide Hew → Sentence into stagger. A missed Sentence consumes its cost, exposing the commitment.

**Matchups:** Excels at armored groups and punishable boss recoveries; weak against constantly moving targets and crossfire. Denied boss stagger uses the shared capped vulnerability rule. Solo damage is self-contained. Party partners can create openings, but neither their presence nor their control is necessary.

**Builds:** Deliberate execution: [Veteran's Whetstone](supporting-items.md#itm-war-03) + [Worldbreaker Gauntlet](relics.md#rel-05). Defensive retaliation: [Runebound Bracer](supporting-items.md#itm-war-01) + [Blackoak Covenant](relics.md#rel-15). Avoid rapid-hit items and forced-movement effects that scatter Sentence's targets.

**Readability/production:** Medium. New windup/held-input pose, fixed lane telegraph, directional mitigation indicator. Distinguish player charging from boss danger through shape as well as color. Prototype uses a short fixed windup instead of the older held-charge proposal; future held-input expansion needs separate design. Pending damage clears on kit removal and cannot grant resource without a hit.

<a id="kit-war-03"></a>
## KIT-WAR-03 — Borderkeeper's Spear

**Equipment and fantasy:** Spear and small shield. A soldier who wins through measured distance. Changes target geometry and defensive movement rather than merely extending Slash.

| Slot | Proposed behavior |
|---|---|
| Basic - Measured Thrust | 0.18s CD; 3.2x attack power along a 260-long, 24-half-width line. The last quarter is a tip zone: +35% damage and two Stamina once if any tip target connects. Close hits remain useful but grant none. |
| Special - Hold the Pass | Two Stamina; 0.9s CD. Snapshot a 320-long, 32-half-width lane for three seconds. Arm after 0.12s; the first eligible enemy in the lane takes 10x damage and ordinary foes briefly stagger. A stationary boss triggers it without needing to move. One lane per caster; replacing discards the old lane. |
| Defensive - Yielding Guard | 0.7s CD. Collision-checked backstep up to 110 with 0.1s protection, then a 0.6s frontal next-hit guard reducing damage 60%; prevention grants at most one Stamina. Refuse obstructed movement without consuming the action. |
| Movement - Flank March | 0.65s CD. Dash 220 laterally, choosing the side from movement input relative to aim; with no movement input, retreat along negative aim. Gain 0.15s protection. No damage or tip resource from movement. |

**Sequence:** Thrust at the tip → plant a lane on an approach → Yield backward → sidestep to regain the tip. A stationary boss touching the newly planted lane can trigger it after its 0.4s arming delay; no need for boss movement.

**Matchups:** Strong in corridors, vulnerable when surrounded. Bosses receive damage even when stagger is denied. Solo works through direct thrusts. Allies can lure normal enemies across a lane; only the owner receives Momentum.

**Builds:** Lane defender: [Spearhead Ferrule](supporting-items.md#itm-war-05) + [Warden's Seal](relics.md#rel-16). Mobile hunter: [Redstep Spurs](supporting-items.md#itm-war-02) + [Hunter's Star](relics.md#rel-11). Extra knockback can break tip spacing or remove a target from a planted lane.

**Readability/production:** Medium. Tip highlight, single-use lane graphic, thrust animation, reliable lateral targeting. This kit must not resemble Tank terrain obstruction: the lane threatens enemies but never blocks their path.

<a id="kit-war-04"></a>
## KIT-WAR-04 — Banner of the Vanguard

**Equipment and fantasy:** Short sword and carried battle standard. A mobile captain whose own position establishes a rally point. Changes resource building and field placement; unlike Tank, protection serves advancing damage.

| Slot | Proposed behavior |
|---|---|
| Basic - Rally Cut | 0.18s CD; 3.6x attack power in a 135-range, 110-degree sweep. Gain two Stamina once on hit. Connecting cuts from within the rally radius add 0.5s per target to the banner, with a total two-second extension budget per planting. |
| Special - Plant the Standard | Two Stamina; 0.9s CD. Place one banner within 250 aimed range for five seconds. Planting deals 10x physical damage within 150. Its 150-radius aura gives the owner and nearby living, visible, actively deployed SlasherPlayer allies +15% movement speed. This aura is a field, never a summon. |
| Defensive - Stand Together | 0.7s CD. Grant self a 15%-maximum-HP barrier, minimum one. If the owner is near the banner, also grant it to the nearest living deployed ally within that same banner radius. With a recipient, both last two seconds; alone, self lasts three. No heal or automatic resurrection. |
| Movement - Advance the Colors | 0.65s CD. Advance up to 230 with 0.15s protection. Carry a live banner to landing without resetting its lifetime, extension budget, or planting damage. No banner is required for movement. |

**Sequence:** Fight to earn Momentum → plant ahead → cut within the rally zone → advance the banner when pressure changes. Solo always receives the speed and barrier benefits.

**Matchups:** Strong sustained room pressure and coordinated play; weaker instant burst and limited reach. Boss damage comes from sword uptime and planting impacts, never allies as a mandatory multiplier. Cannot stack banner auras from repeated casts.

**Builds:** Rally endurance: [Rally Pennant](supporting-items.md#itm-war-06) + [Pilgrim Bell](relics.md#rel-18). Aggressive captain: [Redstep Spurs](supporting-items.md#itm-war-02) + [Standard of Succession](relics.md#rel-24). Long stationary benefits conflict with moving the banner frequently.

**Readability/production:** High. Carried/planted animation, owned aura boundary, support recipient indicator, safe party filtering. A banner is a field, not a summon, and cannot trigger summon-death rewards.

<a id="kit-war-05"></a>
## KIT-WAR-05 — Duelist's Paired Sabres

**Reserve alternative to:** Greatsword if fast precision proves more appealing than heavy commitment. Two blades, no shield; distinguish from Rogue through visible contests rather than stealth or execution.

| Slot | Proposed behavior |
|---|---|
| Basic - Answering Cuts | 0.14s CD; 3x attack power in alternating left/right 125-range, 95-degree cuts. A second connected stroke on the same enemy within two seconds gains two Stamina; the first earns none. Misses/new first targets restart the pair; movement preserves it. Exposure widens the next Basic to 145 degrees and boosts damage 35% against that exposed target only. |
| Special - Crossing Blades | Two Stamina; 0.9s CD. Snapshot two opposing 175-range, 85-degree arcs, resolving at 0.08s and 0.16s. Each deals half of the 10x total. The second is secondary and cannot double primary hit procs. Both hits are needed for the full combined payoff. |
| Defensive - Bind Steel | 0.7s CD. For 0.6s, fully parry one frontal melee attacker within 130, gain at most one Stamina, and expose that enemy for two seconds. Frontal ranged/unknown-source hits are mitigated 50% without exposure; rear hits bypass the guard. Exposure never moves or stuns a boss. |
| Movement - Passing Step | 0.65s CD. Dash 220 laterally relative to aim, choosing the opposite side when movement input requests it; default to the left-hand side. Gain 0.15s protection and preserve the Basic pair. |

**Sequence:** First cut → Passing Step → second cut → bait Bind → Crossing Blades. Solo fights depend on rhythm rather than ally setup. Bosses can be exposed without being stunned; the effect is an attack-shape opportunity, not a defense bypass.

**Builds:** Precision: [Veteran's Whetstone](supporting-items.md#itm-war-03) + [Hunter's Star](relics.md#rel-11). Riposte: [Runebound Bracer](supporting-items.md#itm-war-01) + [Mirror of the Second Guard](relics.md#rel-03). Broad uncontrolled knockback disrupts the paired hits; allies should not be required to hold enemies still.

**Readability/production:** Medium. Alternating blade highlights and an exposed-target ring. Changes rhythm and lateral geometry from the standard; lacks its long Charge, room sweep, and generous defense window. Offer a clear audio beat without making timing depend solely on sound.

<a id="kit-war-06"></a>
## KIT-WAR-06 — Chain of the Siege-Breaker

**Reserve alternative to:** Spear for a more forceful spacing kit. Weighted chain and braced gauntlet; manipulate one foe while retaining physical melee identity.

| Slot | Proposed behavior |
|---|---|
| Basic - Cast the Weight | 0.22s CD; 4.2x attack power. Strike only the nearest eligible enemy in a 300-long, 28-half-width aimed line; connect for two Stamina and a two-second tether. One tether only. A miss severs the old one; a broken wall line of sight, death, or expiry also severs it. |
| Special - Draw and Break | Two Stamina; 0.9s CD. Pull tethered ordinary prey up to 180 toward an 85-distance standoff, respecting collision, then slam 100 range around it for 10x damage. A boss takes the full slam at its existing point without displacement. Without a tether, slam 95 ahead for 75% damage. Sever the tether afterward. |
| Defensive - Chain Guard | 0.7s CD. Spin a frontal 130-range guard for 0.7s and destroy at most three ordinary hostile projectiles; beams, unblockable shots, and already-reflected shots bypass it. Also mitigate the next frontal hit by 50%. Award at most one Stamina total across interception and mitigation. Interception persists after that hit is consumed. |
| Movement - Reel Through | 0.65s CD. With a live tether, move toward its point, stopping 55 before the target; otherwise advance 230 along aim. Validate travel against walls and floor bounds. Gain 0.15s protection and sever the tether only on successful movement. |

**Sequence:** Cast → pull → reposition → recast, choosing whether to spend the tether on offense or movement. Good against priority ranged enemies, weaker when swarmed or blocked by props. Works solo; allies benefit from a pulled foe but receive no automatic buffs.

**Builds:** Crowd collapse: [Redstep Spurs](supporting-items.md#itm-war-02) + [Worldbreaker Gauntlet](relics.md#rel-05). Projectile guard: [Runebound Bracer](supporting-items.md#itm-war-01) + [Mirror of the Second Guard](relics.md#rel-03). Stationary-field items can conflict with constantly relocating prey.

**Readability/production:** High. Tether rendering, path validation, pull immunity, and collision-safe reel movement. A broken line of sight immediately severs the chain. Never pull a target through a wall or move a boss out of its arena.
