# Tank kits

[Packet overview and shared rules](README.md) · [Review decisions](review-workbook.md)

**Class promise:** Convert surviving pressure into Resolve and control. Protection must support active decisions rather than reward waiting indefinitely. All entries are proposals except explicitly observed baseline behavior.

| ID | Kit | Status | Distinct decisions | Cost |
|---|---|---|---|---|
| KIT-TAN-01 | Tower Shield and Mace | Recommended standard | Short melee, guard, immediate retaliation | Low |
| KIT-TAN-02 | Iron Porter's Bulwark | Recommended | Carry/deploy cover, firing angles, positional recall | High |
| KIT-TAN-03 | Furnace Plate | Recommended | Limited heat storage, vent direction, movement commitment | Medium |
| KIT-TAN-04 | Oathwall Chains | Recommended | Single-target challenge, tethered protection, priority control | High |
| KIT-TAN-05 | Citadel Heart | Reserve | Temporary stone zones, defensive setup, slow relocation | High |
| KIT-TAN-06 | Mirror Aegis | Reserve | Projectile interception, aimed reflection, finite catches | High |

## Proposed discovery sources

These are preferred offer pools, not guaranteed drops or new map requirements. Alternatives can also appear in class-compatible elite kit offers after class recruitment. First recovery adds a physical kit to the armory on successful extraction; later merchants may sell copies. Reserve sources apply only if the candidate is promoted. Unlock difficulty never grants higher baseline power.

| Kit | Preferred acquisition |
|---|---|
| [KIT-TAN-01](#kit-tan-01) | Bound starter for a Tank when recruited; preserve Tower Shield identity. |
| [KIT-TAN-02](#kit-tan-02) | Sunken Mine defense cache or earlier defense elite reward; cover serves the porter fantasy. |
| [KIT-TAN-03](#kit-tan-03) | Ember Foundry fire/defense cache, also eligible in generic Tank elite rewards after class recruitment. |
| [KIT-TAN-04](#kit-tan-04) | Stone Crypt defense cache or defense merchant after first recovery; oath is personal, not a faction lock. |
| [KIT-TAN-05](#kit-tan-05) | Reserve: Sunken Mine defense cache if promoted; replaces Iron Porter. |
| [KIT-TAN-06](#kit-tan-06) | Reserve: Abyssal Archive defense cache if promoted; replaces Oathwall. |

<a id="kit-tan-01"></a>
## KIT-TAN-01 — Tower Shield and Mace

**Equipment and fantasy:** Preserve the current Tank baseline. A compact defender who invites one attack and answers nearby enemies. Choose reliability over field management.

| Slot | Baseline behavior |
|---|---|
| Basic — Shield Bash | 62 px, 70° physical melee arc; 0.28s base CD. A hit grants 1 Resolve and applies base knockback. The older guaranteed-stagger description is not the base Basic tuning. |
| Special — Retribution | 2 Resolve, 3s CD. For up to 2s, catch the next hit with 50% mitigation, store half its raw damage, and immediately release that stored amount in an 80 px area. Not a multi-hit accumulator. |
| Defensive — Guard | 3.5s CD. For up to 1.25s reduce the next hit by 75%; gain 1 Resolve if damage is prevented. |
| Movement — Leap | 150 px relocation, 1.8s CD, 0.3s protection. Landing creates a 72 px damage area, knockback, and 0.45s stagger. No universal taunt is visible in this base action. |

**Sequence:** Bash to build → Guard a punish → Leap into a cluster → Retribution a predictable hit. Guard and Retribution share defensive-state handling; do not imply simultaneous storage and guarding.

**Matchups:** Strong against close pressure, weak at chasing distributed ranged enemies. Boss retaliation depends on taking the intended triggering hit; invulnerability is not stored damage. Solo has its own damage/resource cycle. No automatic ally interception in the standard kit.

**Builds:** Counterwall: [Soldier's Buckle](supporting-items.md#itm-tan-01) + [Briar Seed](relics.md#rel-14). Mobile breaker: [Brambleguard Clasp](supporting-items.md#itm-tan-03) + [Worldbreaker Gauntlet](relics.md#rel-05). Extreme damage avoidance can prevent Retribution's payoff; damage prevention and damage taking are distinct triggers.

**Readability/production:** Low. Preserve the existing kit; clarify one-hit storage and expiry. New relics must not repeatedly re-arm the existing defense window.

<a id="kit-tan-02"></a>
## KIT-TAN-02 — Iron Porter's Bulwark

**Equipment and fantasy:** A pavise shield with short hammer. Carry cover into the room, then choose when to abandon it. Changes attack mode and protection geometry.

| Slot | Proposed behavior |
|---|---|
| Basic — Porter's Hammer | Close strike, 0.65s CD, gain 1 Resolve on hit. With bulwark deployed, gain reach to medium through a narrow shock line; same single proc budget. |
| Special — Set the Bulwark | 2 Resolve, 6s CD. Place one short projectile-blocking wall at close range for 4s, dealing normal impact damage. Block at most six ordinary shots; no beam blocking, enemy collision, or closed doorway. |
| Defensive — Take Cover | 5s CD. While close behind the bulwark relative to aim, gain 70% next-hit reduction for 0.8s; otherwise 40%. Successful prevention grants 1 Resolve. The action remains usable without a wall. |
| Movement — Shoulder and Carry | 3s CD. Short protected dash; recall the bulwark without detonation or resource refund. Ready the next Basic immediately only if already off cooldown—no reset. |

**Sequence:** Hammer → deploy into a firing lane → work behind it → recall and relocate when flanked. Solo enemies remain reachable; no teammate must lure them. Boss beams and ground effects force movement rather than make cover universal.

**Matchups:** Strong against ranged packs, weak to surrounding melee and persistent floor hazards. Deployed allies may use cover; friendly shots and movement pass through it.

**Builds:** Entrenched: [Ironroot Ring](supporting-items.md#itm-tan-02) + [Warden's Seal](relics.md#rel-16). Mobile logistics: [Porter's Strap](supporting-items.md#itm-tan-05) + [Pilgrim Bell](relics.md#rel-18). Push effects do not create extra wall charges. Stationary damage rewards are lost when carrying cover.

**Readability/production:** High. Front/back wall markings, remaining-shot pips, recall pose. Wall is a field, never a summon or damageable ally. AI navigation cannot depend on a temporary unbreakable obstacle.

<a id="kit-tan-03"></a>
## KIT-TAN-03 — Furnace Plate

**Equipment and fantasy:** Vented armor and furnace gauntlet sold as one defining kit. Bank controlled pressure, then choose a vent direction. Changes secondary resource and attack timing.

| Slot | Proposed behavior |
|---|---|
| Basic — Rivet Punch | Close physical strike, 0.6s CD; gain 1 Resolve on hit. Every second connected Basic grants one Heat, maximum three; missed hits do not advance the pair. |
| Special — Open the Vents | 2 Resolve, 4s CD. After 0.4s windup, fire a medium cone dealing normal fire damage plus modest damage per Heat and applying Burn, consuming all Heat. At zero Heat it still functions. |
| Defensive — Stoke the Shell | 5s CD. For 0.8s reduce the next hit by 60%; preventing damage adds one Heat and 1 Resolve. No resource from self-inflicted or secondary damage. |
| Movement — Pressure Step | 3s CD. Short dash, 0.15s protection. If at three Heat, leave a 1s nonstacking fire strip and consume one Heat; otherwise no trail. |

**Sequence:** Punch twice → Stoke a hit → decide between full vent burst and spending one Heat to move safely. Heat expires on encounter end and never causes passive self-damage. No heat gain from dots or thorns.

**Matchups:** Strong sustained close duels, weak against long-range kiting. Bosses need not attack to make Heat; Basics supply it. Solo complete. Party benefit is area pressure, not indiscriminate friendly shielding.

**Builds:** Vent specialist: [Boiler Rivet](supporting-items.md#itm-tan-06) + [Crown of the First Flame](relics.md#rel-04). Defensive engine: [Soldier's Buckle](supporting-items.md#itm-tan-01) + [Blackoak Covenant](relics.md#rel-15). Relics offering resource for taking damage must not reward Heat's creation itself.

**Readability/production:** Medium. Three visible vent lights, cone windup, heat spending indicator. Requires one kit-local counter but no ally AI or world obstruction. Heat is not Resolve and cannot be filled by a generic resource potion.

<a id="kit-tan-04"></a>
## KIT-TAN-04 — Oathwall Chains

**Equipment and fantasy:** Shield linked to an oath-chain. Declare one enemy your responsibility; protect a nearby ally without relying on an ally's existence. Changes target commitment and interception.

| Slot | Proposed behavior |
|---|---|
| Basic — Binding Bash | Close physical hit, 0.6s CD, 1 Resolve on hit. First enemy hit becomes Challenged for 4s; only one target. Challenge itself does not force boss behavior. |
| Special — Answer the Oath | 2 Resolve, 4.5s CD. Medium chain strike toward Challenged foe, heavy damage and brief ordinary-enemy pull. Without Challenge, normal aimed line strike remains available. |
| Defensive — Interpose | 6s CD. Guard self for 60% next-hit reduction for 1s. If one nearest deployed ally within close range would take a hit first, intercept half that hit instead, capped at 10% own max health; consume guard. Prevention/interception grants 1 Resolve once. |
| Movement — Oathbound Advance | 3s CD. Dash a medium distance toward Challenged target or short distance freely; 0.15s protection. Stop before occupied terrain. |

**Sequence:** Challenge → hold a useful angle → Interpose → advance and Answer. Intercepted damage cannot be intercepted again, reflected, or fed into another resource loop. With no deployed ally, Interpose remains an ordinary self-defense.

**Matchups:** Strong priority protection and duels, weak against multiple separated threats. Bosses take chain damage without taunt/pull. Allies receive one explicitly capped interception, not indefinite invulnerability.

**Builds:** Protector: [Oathlink](supporting-items.md#itm-tan-04) + [Standard of Succession](relics.md#rel-24). Pursuer: [Brambleguard Clasp](supporting-items.md#itm-tan-03) + [Hunter's Star](relics.md#rel-11). Broad mark-copying effects cannot duplicate Challenge or intercept recipients.

**Readability/production:** High. Single challenged-target symbol, recipient line, intercept cap feedback. Needs damage ownership and deployed-party checks; classify as higher risk until party behavior is validated.

<a id="kit-tan-05"></a>
## KIT-TAN-05 — Citadel Heart

**Reserve alternative to:** Iron Porter for zone defense instead of projectile cover. A stone core and hammer create temporary footing. Changes stationary incentives and staggered placement.

| Slot | Proposed behavior |
|---|---|
| Basic — Mason's Blow | Close slow strike, 0.75s CD; gain 1 Resolve on hit and leave a small stone plate under self for 3s, maximum two. Plates do not obstruct movement. |
| Special — Raise the Ring | 2 Resolve, 5s CD. Erupt the two plates after 0.6s, dealing heavy physical area damage, then consume them. With none, a smaller eruption occurs at self. |
| Defensive — Settle the Stone | 5s CD. On a plate, reduce next hit within 1s by 70%; off plate, 40%. Prevention grants 1 Resolve. Moving off a plate retains only the lower reduction. |
| Movement — Fault Step | 4s CD. Short dash with 0.15s protection. Relocate the newest plate to arrival, without extending duration or triggering damage. |

**Sequence:** Strike to lay footing → guard pressure → lay second plate → erupt when foes converge. Strong holding ground; weak against hazards forcing constant relocation. Stationary bosses can be damaged by close plate setup; denied stagger adds no additional proc chain. Solo is self-sufficient. Friendly deployed allies can stand on plates but receive no mitigation unless an explicit item grants it.

**Builds:** Fortified ground: [Ironroot Ring](supporting-items.md#itm-tan-02) + [Heartwood Crown](relics.md#rel-13). Eruption: [Brambleguard Clasp](supporting-items.md#itm-tan-03) + [Worldbreaker Gauntlet](relics.md#rel-05). Frequent push-away effects remove enemies from plates.

**Readability/production:** High. Plate count/duration, eruption telegraph, source ownership. Distinct from Pyromancy: plates are created by melee, protect the owner, and do not apply dots. Must remain readable beneath enemy danger zones.

<a id="kit-tan-06"></a>
## KIT-TAN-06 — Mirror Aegis

**Reserve alternative to:** Oathwall for solo precision defense. Reflective shield and short spear; catches are finite and released deliberately. Changes ranged targeting and defensive payoff.

| Slot | Proposed behavior |
|---|---|
| Basic — Silver Point | Close piercing thrust, 0.6s CD; gain 1 Resolve on enemy hit. Works without enemy projectiles. |
| Special — Return to Sender | 2 Resolve, 4s CD. Fire a medium aimed physical shard for normal damage plus one fixed bonus per stored Reflection, maximum two; consume them. Never copy enemy damage values or special effects. |
| Defensive — Mirror Catch | 5s CD. A 0.5s frontal window destroys up to two normal shots, storing two Reflections; first catch grants 1 Resolve. Against melee, reduce one hit 60% and store one Reflection. |
| Movement — Angled Retreat | 3s CD. Short lateral dash, 0.15s protection; preserve stored Reflections for their 6s lifetime. |

**Sequence:** Aim the shield → catch → angle sideways → release at a chosen target. Beams and ground hazards cannot be caught. A melee-only boss still supplies a reflection through a properly timed defense; Basics and zero-charge Special prevent deadlock.

**Builds:** Precise return: [Soldier's Buckle](supporting-items.md#itm-tan-01) + [Mirror of the Second Guard](relics.md#rel-03). Duel endurance: [Brambleguard Clasp](supporting-items.md#itm-tan-03) + [Blackoak Covenant](relics.md#rel-15). Secondary returns cannot reflect, generate more Reflections, or inherit on-hit enemy effects. Party members cannot donate projectiles.

**Readability/production:** High. Two stored-shard icons, frontal catch arc, clearly player-owned return VFX. Requires safe projectile classification and cleanup. Distinguish it from a universal immunity shield.
