# Warrior kits

[Packet overview and shared rules](README.md) · [Review decisions](review-workbook.md)

**Class promise:** Earn Momentum by committing to melee and choosing when to stand, advance, or counter. Every kit can defeat an isolated boss without adds. All candidates are unapproved. New timings are illustrative; standard values are base-runtime observations.

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
| Basic — Hew | Close, broad physical arc; 0.8s CD. Hold up to 0.6s to widen the arc, not increase hit count. Release stops the hold; gain 1 Momentum on any hit. Movement slows while winding up. |
| Special — Sentence | 2 Momentum, 4s CD. Telegraph a medium narrow ground cleave for 0.7s, then heavy damage and Stagger. Hitting a previously staggered target adds damage instead of extending control. |
| Defensive — Shoulder the Blow | 5s CD. For 0.6s reduce the next frontal hit by 60%; remain vulnerable from behind. Successful prevention grants 1 Momentum and allows the next Hew within 2s to release without its hold. |
| Movement — Committed Step | 3s CD. Short forward step; brief protection during the first 0.15s, followed by 0.25s attack recovery. Reposition before Sentence, not through an entire room. |

**Sequence:** Bait a swing → Shoulder → instant wide Hew → Sentence into stagger. A missed Sentence consumes its cost, exposing the commitment.

**Matchups:** Excels at armored groups and punishable boss recoveries; weak against constantly moving targets and crossfire. Denied boss stagger uses the shared capped vulnerability rule. Solo damage is self-contained. Party partners can create openings, but neither their presence nor their control is necessary.

**Builds:** Deliberate execution: [Veteran's Whetstone](supporting-items.md#itm-war-03) + [Worldbreaker Gauntlet](relics.md#rel-05). Defensive retaliation: [Runebound Bracer](supporting-items.md#itm-war-01) + [Blackoak Covenant](relics.md#rel-15). Avoid rapid-hit items and forced-movement effects that scatter Sentence's targets.

**Readability/production:** Medium. New windup/held-input pose, fixed lane telegraph, directional mitigation indicator. Distinguish player charging from boss danger through shape as well as color. Needs release/cancel behavior; interruption cancels damage and does not grant Momentum.

<a id="kit-war-03"></a>
## KIT-WAR-03 — Borderkeeper's Spear

**Equipment and fantasy:** Spear and small shield. A soldier who wins through measured distance. Changes target geometry and defensive movement rather than merely extending Slash.

| Slot | Proposed behavior |
|---|---|
| Basic — Measured Thrust | Medium narrow line, 0.55s CD; normal damage, with a tip zone in the last quarter of reach. A tip hit grants 1 Momentum, at most once per thrust. Close hits remain useful but earn none. |
| Special — Hold the Pass | 2 Momentum, 5s CD. Plant a visible medium lane for 3s. The first enemy entering it suffers heavy thrust damage and Stagger, then the lane expires. Recast is unavailable while planted. |
| Defensive — Yielding Guard | 4s CD. Backstep a short distance while guarding the front for 0.5s. Preventing a hit grants 1 Momentum; the step cannot cross terrain. |
| Movement — Flank March | 2.5s CD. Medium lateral dash relative to aim, choosing the clearer side from movement input; with no lateral input, move backward. No damage; 0.15s protection. |

**Sequence:** Thrust at the tip → plant a lane on an approach → Yield backward → sidestep to regain the tip. A stationary boss touching the newly planted lane can trigger it after its 0.4s arming delay; no need for boss movement.

**Matchups:** Strong in corridors, vulnerable when surrounded. Bosses receive damage even when stagger is denied. Solo works through direct thrusts. Allies can lure normal enemies across a lane; only the owner receives Momentum.

**Builds:** Lane defender: [Spearhead Ferrule](supporting-items.md#itm-war-05) + [Warden's Seal](relics.md#rel-16). Mobile hunter: [Redstep Spurs](supporting-items.md#itm-war-02) + [Hunter's Star](relics.md#rel-11). Extra knockback can break tip spacing or remove a target from a planted lane.

**Readability/production:** Medium. Tip highlight, single-use lane graphic, thrust animation, reliable lateral targeting. This kit must not resemble Tank terrain obstruction: the lane threatens enemies but never blocks their path.

<a id="kit-war-04"></a>
## KIT-WAR-04 — Banner of the Vanguard

**Equipment and fantasy:** Short sword and carried battle standard. A mobile captain whose own position establishes a rally point. Changes resource building and field placement; unlike Tank, protection serves advancing damage.

| Slot | Proposed behavior |
|---|---|
| Basic — Rally Cut | Close sweep, 0.5s CD. Gain 1 Momentum on hit. Each hit within medium distance of the planted banner also extends its remaining life by 0.5s, maximum 2s added per planting. |
| Special — Plant the Standard | 2 Momentum, 6s CD. Place one banner at an aimed open point within medium range for 5s. The planting deals normal physical damage; the owner and nearby deployed allies gain 10% movement speed while near it. |
| Defensive — Stand Together | 5s CD. Grant self a 10%-health barrier for 2s. If within the banner radius, also grant that barrier to one nearest living deployed ally; no ally means self duration becomes 3s, not a second barrier. |
| Movement — Advance the Colors | 3s CD. Short protected dash. If a banner exists, carry it to the landing point without renewing its duration or triggering planting damage. |

**Sequence:** Fight to earn Momentum → plant ahead → cut within the rally zone → advance the banner when pressure changes. Solo always receives the speed and barrier benefits.

**Matchups:** Strong sustained room pressure and coordinated play; weaker instant burst and limited reach. Boss damage comes from sword uptime and planting impacts, never allies as a mandatory multiplier. Cannot stack banner auras from repeated casts.

**Builds:** Rally endurance: [Rally Pennant](supporting-items.md#itm-war-06) + [Pilgrim Bell](relics.md#rel-18). Aggressive captain: [Redstep Spurs](supporting-items.md#itm-war-02) + [Standard of Succession](relics.md#rel-24). Long stationary benefits conflict with moving the banner frequently.

**Readability/production:** High. Carried/planted animation, owned aura boundary, support recipient indicator, safe party filtering. A banner is a field, not a summon, and cannot trigger summon-death rewards.

<a id="kit-war-05"></a>
## KIT-WAR-05 — Duelist's Paired Sabres

**Reserve alternative to:** Greatsword if fast precision proves more appealing than heavy commitment. Two blades, no shield; distinguish from Rogue through visible contests rather than stealth or execution.

| Slot | Proposed behavior |
|---|---|
| Basic — Answering Cuts | Close alternating left/right arcs, 0.3s CD. Every second connected stroke on the same enemy grants 1 Momentum; misses or a new target restart the pair. |
| Special — Crossing Blades | 2 Momentum, 3.5s CD. Two crossing close cuts after a 0.3s windup. Both must connect for the heavy combined payoff; count as one proc activation. |
| Defensive — Bind Steel | 4s CD. A 0.35s frontal parry catches one melee attack, grants 1 Momentum, and exposes the attacker for 2s to the next Basic's wider arc. Ranged hits are reduced 50%, without the exposure. |
| Movement — Passing Step | 2s CD. Short lateral dash with 0.12s protection; preserves the Basic pair if used between strokes. |

**Sequence:** First cut → Passing Step → second cut → bait Bind → Crossing Blades. Solo fights depend on rhythm rather than ally setup. Bosses can be exposed without being stunned; the effect is an attack-shape opportunity, not a defense bypass.

**Builds:** Precision: [Veteran's Whetstone](supporting-items.md#itm-war-03) + [Hunter's Star](relics.md#rel-11). Riposte: [Runebound Bracer](supporting-items.md#itm-war-01) + [Mirror of the Second Guard](relics.md#rel-03). Broad uncontrolled knockback disrupts the paired hits; allies should not be required to hold enemies still.

**Readability/production:** Medium. Alternating blade highlights and an exposed-target ring. Changes rhythm and lateral geometry from the standard; lacks its long Charge, room sweep, and generous defense window. Offer a clear audio beat without making timing depend solely on sound.

<a id="kit-war-06"></a>
## KIT-WAR-06 — Chain of the Siege-Breaker

**Reserve alternative to:** Spear for a more forceful spacing kit. Weighted chain and braced gauntlet; manipulate one foe while retaining physical melee identity.

| Slot | Proposed behavior |
|---|---|
| Basic — Cast the Weight | Medium aimed line, 0.65s CD; stops at the first enemy and tethers it for 2s. Gain 1 Momentum on connection. Only one tether; re-aiming replaces it. |
| Special — Draw and Break | 2 Momentum, 4s CD. Pull a tethered ordinary foe a short distance and slam a close area; without a tether, perform a weaker direct close slam. Bosses take the full slam at their tether point without moving. |
| Defensive — Chain Guard | 5s CD. Spin a close frontal guard for 0.7s, destroying up to three normal projectiles. The first destroyed shot grants 1 Momentum. Melee damage is reduced 50% during the guard. |
| Movement — Reel Through | 3s CD. With a tether, dash toward it, stopping short of collision; otherwise a short forward step. Brief 0.15s protection; sever tether after arrival. |

**Sequence:** Cast → pull → reposition → recast, choosing whether to spend the tether on offense or movement. Good against priority ranged enemies, weaker when swarmed or blocked by props. Works solo; allies benefit from a pulled foe but receive no automatic buffs.

**Builds:** Crowd collapse: [Redstep Spurs](supporting-items.md#itm-war-02) + [Worldbreaker Gauntlet](relics.md#rel-05). Projectile guard: [Runebound Bracer](supporting-items.md#itm-war-01) + [Mirror of the Second Guard](relics.md#rel-03). Stationary-field items can conflict with constantly relocating prey.

**Readability/production:** High. Tether rendering, path validation, pull immunity, and collision-safe reel movement. A broken line of sight immediately severs the chain. Never pull a target through a wall or move a boss out of its arena.
