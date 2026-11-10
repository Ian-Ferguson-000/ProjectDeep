# Rogue kits

[Packet overview and shared rules](README.md) · [Review decisions](review-workbook.md)

**Class promise:** Earn Edge by engineering favorable engagements. Rogue alternatives explore duels, damage over time, and traps without losing the mobile opportunist identity. All candidates are unapproved.

| ID | Kit | Status | Distinct decisions | Cost |
|---|---|---|---|---|
| KIT-ROG-01 | Spectral Dagger | Recommended standard | Line pierce, hidden approach, opportunistic finisher | Low |
| KIT-ROG-02 | Fox Teeth | Recommended | Close feints, target reading, lateral attacks | Medium |
| KIT-ROG-03 | Viper's Implements | Recommended | Poison maintenance, manual harvest, ranged spacing | Medium |
| KIT-ROG-04 | Trapper's Recurve | Recommended | Bow draw, trap placement, lure paths | High |
| KIT-ROG-05 | Moon Stiletto | Reserve | Single mark, precise teleport angle, charged execution | High |
| KIT-ROG-06 | Last Whisper | Reserve | Reload rhythm, piercing shot, deliberate retreat | Medium |

## Proposed discovery sources

These are preferred offer pools, not guaranteed drops or new map requirements. Alternatives can also appear in class-compatible elite kit offers after class recruitment. First recovery adds a physical kit to the armory on successful extraction; later merchants may sell copies. Reserve sources apply only if the candidate is promoted. Unlock difficulty never grants higher baseline power.

| Kit | Preferred acquisition |
|---|---|
| [KIT-ROG-01](#kit-rog-01) | Bound starter for a Rogue when recruited; preserve Spectral Dagger identity. |
| [KIT-ROG-02](#kit-rog-02) | Verdant Forest finesse cache or finesse merchant after recovery. |
| [KIT-ROG-03](#kit-rog-03) | Ashen Farmstead alchemical cache or eligible Rogue elite reward; no new poison biome required. |
| [KIT-ROG-04](#kit-rog-04) | Verdant Forest hunting cache or eligible Rogue elite reward; introduces a bow kit without a new class. |
| [KIT-ROG-05](#kit-rog-05) | Reserve: Moonlit Grove finesse cache if promoted; replaces Fox Teeth. |
| [KIT-ROG-06](#kit-rog-06) | Reserve: Stone Crypt weapon cache if promoted; replaces Trapper. |

<a id="kit-rog-01"></a>
## KIT-ROG-01 — Spectral Dagger

**Equipment and fantasy:** Preserve the current Rogue kit. A mobile assassin who aligns enemies, crosses a target, and strikes while hidden or while the target is vulnerable.

| Slot | Baseline behavior |
|---|---|
| Basic — Pierce | 104 px line, 18 px radius, 0.12s base CD. Hits along the line, awards 1 Edge on a connecting activation, ends Hidden, and can deflect nearby frontal projectiles. |
| Special — Assassinate | 2 Edge, 2.2s CD; selects a target near aim within 100 px. Higher damage coefficient if Hidden, target isolated within 95 px, or below half health. No valid target means a failed activation with refunded cost. |
| Defensive — Evade | 3.2s CD, 0.7s protection, 70 px backward relocation. An avoided hit during Evade awards resource and consumes the reactive state. |
| Movement — Shadowstep | Up to 175 px; 0.7s CD. Aim through a nearby target when available, then become Hidden for 0.5s; grants 0.5s protection. Upgrades may add path damage. |

**Sequence:** Pierce aligned enemies → Shadowstep through a priority foe → Assassinate while Hidden → Evade retaliation. Older claims of unconditional defense bypass belong to legacy text; do not assume Slasher uses the d20 defense model.

**Matchups:** Strong priority burst, vulnerable to crowded landing zones and close-range hazards. Bosses receive bonus damage under the same conditions, never automatic execution. Solo requires no flanking ally. Party displacement can help isolate a target or unexpectedly spoil aim.

**Builds:** Ambush: [Moonleaf Cloak](supporting-items.md#itm-rog-02) + [Hunter's Star](relics.md#rel-11). Duel: [Duelist Gloves](supporting-items.md#itm-rog-01) + [Chronomancer's Pin](relics.md#rel-02). Traps and poison-specific items remain dormant without those capabilities.

**Readability/production:** Low. Clear Hidden expiry and valid Assassinate target indicator; preserve fast controls. Do not describe the current base kit as a stealth system that suppresses all enemy AI.

<a id="kit-rog-02"></a>
## KIT-ROG-02 — Fox Teeth

**Equipment and fantasy:** A hooked dagger and parrying knife. Win through visible feints rather than disappearing. Changes resource acquisition and lateral counter timing.

| Slot | Proposed behavior |
|---|---|
| Basic — Testing Cut | Close narrow slash, 0.35s CD. Repeated hits on one enemy build Read; every second connected hit grants 1 Edge and marks it Read for 3s. New target restarts the count. |
| Special — Open the Guard | 2 Edge, 3.5s CD. Close heavy double strike, with extra damage against Read; consumes that mark. Counts as one attack for procs. |
| Defensive — False Opening | 4s CD. Short 0.4s frontal evasion window. Avoiding one attack grants 1 Edge and Read on its attacker; no free counter damage. |
| Movement — Fox's Circle | 2s CD. Short lateral dash relative to target/aim, 0.15s protection. Does not grant Hidden or Read by itself. |

**Sequence:** Test twice or bait False Opening → circle the target → Open the Guard. Read is not a global vulnerability and cannot be spread by effects that copy damage statuses.

**Matchups:** Excellent boss duels and repeatable pressure, weaker at clearing spread-out packs. Bosses can be Read regardless of control immunity. Solo supplies all setup; allies can distract but cannot build Read for the owner.

**Builds:** Committed duel: [Duelist Gloves](supporting-items.md#itm-rog-01) + [Hunter's Star](relics.md#rel-11). Nimble answer: [Redstep Spurs](supporting-items.md#itm-war-02) + [Mirror of the Second Guard](relics.md#rel-03). Hidden-only items are incompatible; forced target switching loses the Read setup.

**Readability/production:** Medium. Read count and parry arc, lateral movement indicator. Unlike Warrior sabres, this kit consumes a target-specific opening and lacks broad arcs, rather than rewarding a sustained alternating stroke sequence.

<a id="kit-rog-03"></a>
## KIT-ROG-03 — Viper's Implements

**Equipment and fantasy:** Throwing needles and venom knife as one kit. Maintain pressure while kiting, then choose when to consume toxins. Changes range and delayed payoff.

| Slot | Proposed behavior |
|---|---|
| Basic — Venom Needle | Medium single-target projectile, 0.55s CD. Applies Poison, refreshing its 4s duration, and gains 1 Edge on direct hit. No resource from ticks. |
| Special — Draw the Venom | 2 Edge, 4s CD. Aimed close knife lunge, heavy physical damage; if the target is Poisoned, consume remaining owner-applied Poison for an additional fixed damage bonus. Does not scale with infinite duration extensions. |
| Defensive — Shedskin | 5s CD. Clear self Slow/Poison and reduce the next hit within 0.7s by 50%; prevention grants 1 Edge. No Hidden. |
| Movement — Serpent's Retreat | 3s CD. Medium backward dash, 0.15s protection; leave a small 1s slowing cloud, not additional Poison. |

**Sequence:** Needle while closing → keep Poison alive through movement → lunge when safe to cash out → retreat and restart. Poison-resistant enemies still take direct needle/lunge damage; immunity cannot make the kit unplayable.

**Matchups:** Strong attrition and mobile boss fights, weaker instant room clear. Solo requires no ally debuff. Poison belongs to its source: never consume another party member's toxin or transfer its healing/proc ownership.

**Builds:** Patient venom: [Venom Glass](supporting-items.md#itm-rog-03) + [Briar Seed](relics.md#rel-14). Harvest assassin: [Keen Edge Oil](supporting-items.md#itm-shr-01) + [Hunter's Star](relics.md#rel-11). Echoes receive direct knife damage only, not another Poison consumption; kill-trigger currency has encounter caps.

**Readability/production:** Medium. Source-aware Poison icon with remaining duration, clear harvest-ready indicator, separate slow cloud. Avoid filling the floor with opaque green effects.

<a id="kit-rog-04"></a>
## KIT-ROG-04 — Trapper's Recurve

**Equipment and fantasy:** Short bow and snare satchel. A mobile hunter who prepares crossings rather than entering melee. Changes attack timing, range, and battlefield setup.

| Slot | Proposed behavior |
|---|---|
| Basic — Drawn Arrow | Long aimed arrow, 0.65s CD; hold 0.4s to pierce one extra enemy, slowing movement during draw. Gain 1 Edge on enemy contact, once per arrow. |
| Special — Wire Snare | 2 Edge, 5s CD. Place one visible trap at medium range, arms after 0.5s, lasts 5s. First foe touching it takes heavy physical damage and a 1s root; trap expires. |
| Defensive — Decoy Fold | 5s CD. Leave a 0.8s decoy while reducing the next hit by 50%; ordinary nearby foes may retarget the decoy once. Prevention grants 1 Edge. Decoy has no health, kill event, or summon identity. |
| Movement — Hunter's Vault | 3s CD. Medium dash, 0.15s protection, leaves no automatic trap and cannot cross walls. |

**Sequence:** Place snare in a route → draw while foes approach → vault across its line → fire at the rooted target. Stationary bosses can trigger an armed trap placed under them; root denial uses shared capped vulnerability instead.

**Matchups:** Strong corridors, weak immediate swarms and frequently relocating enemies. Solo bow damage stands alone. Allies may guide normal foes into a trap; the owner receives its damage and no extra resource from the trap's secondary effect.

**Builds:** Prepared ground: [Tripwire Spool](supporting-items.md#itm-rog-04) + [Warden's Seal](relics.md#rel-16). Long shot: [Fletching Comb](supporting-items.md#itm-rog-05) + [Hunter's Star](relics.md#rel-11). Uncontrolled pushes or taunts may steer enemies away from the trap.

**Readability/production:** High. Bow charge animation, armed/unarmed trap, decoy targeting rules. Trap cap one; removing it never counts as defeating a summon. Adds a ranged Rogue silhouette without promising a seventh Ranger class.

<a id="kit-rog-05"></a>
## KIT-ROG-05 — Moon Stiletto

**Reserve alternative to:** Fox Teeth for a more magical assassin. A phase knife changes target marking and teleport planning, not just Hidden duration.

| Slot | Proposed behavior |
|---|---|
| Basic — Crescent Prick | Close thrust, 0.45s CD; first enemy hit gains a Moon Mark for 4s, replacing the old one. Gain 1 Edge on hit. |
| Special — Eclipse | 2 Edge, 4s CD. After 0.5s visible windup, heavy close strike; a Moon Mark adds bonus damage and is consumed. Bosses receive damage rather than an execute. |
| Defensive — Vanishing Point | 5s CD. Evade for 0.35s without moving. An avoided hit grants 1 Edge; while Moon Mark exists, refresh it by 1s, once per mark. |
| Movement — Other Side | 3s CD. Teleport to the far side of the marked enemy within medium range, if a safe visible landing exists; otherwise short forward dash. 0.15s protection, no free attack. |

**Sequence:** Mark → bait defense → Other Side → Eclipse before expiration. Strong against isolated slow foes, weak to moving bosses during windup and dangerous landing geometry. Solo self-sufficient. Party movement effects can change the far-side destination, so show a preview and revalidate on use.

**Builds:** Patient eclipse: [Duelist Gloves](supporting-items.md#itm-rog-01) + [Hunter's Star](relics.md#rel-11). Landing safety: [Escape Knot](supporting-items.md#itm-rog-06) + [Blackoak Covenant](relics.md#rel-15). This kit has no Hidden; Moonleaf Cloak's Hidden extension is dormant.

**Readability/production:** High. Mark ownership, landing preview, interrupted-windup feedback. Teleports cannot cross sealed doors or skip traversal objectives. Eclipse interruption spends the activated cost but delivers no damage, making its commitment meaningful.

<a id="kit-rog-06"></a>
## KIT-ROG-06 — Last Whisper

**Reserve alternative to:** Trapper for less field complexity. A compact repeating crossbow rewards reload decisions and line piercing. Changes ammunition timing and ranged defense.

| Slot | Proposed behavior |
|---|---|
| Basic — Whisper Bolt | Long aimed physical shot, 0.3s CD, magazine of three. Gain 1 Edge per connecting shot. Empty magazine automatically reloads over 1.1s while moving slowly; no extra input. |
| Special — Final Word | 2 Edge, 4s CD. Spend all remaining bolts for one piercing long shot with modest damage per bolt; zero bolts still fires a normal-damage shot. Begins the same reload afterward. |
| Defensive — Concealed Reload | 5s CD. Reduce next hit within 0.7s by 50%, and complete the current reload after 0.5s; prevention grants 1 Edge. Does not stack ammunition above three. |
| Movement — Withdrawal | 3s CD. Medium backward dash, 0.15s protection; reload timer continues, not reset or completed. |

**Sequence:** Fire selectively → spend the last rounds on an aligned Special → retreat through reload → defend if pressure closes. Strong lines and boss uptime, weak point-blank swarms. Solo complete; no partner supplies ammunition. Party cover helps the reload but is optional.

**Builds:** Sniper: [Fletching Comb](supporting-items.md#itm-rog-05) + [Hunter's Star](relics.md#rel-11). Escape fire: [Escape Knot](supporting-items.md#itm-rog-06) + [Chronomancer's Pin](relics.md#rel-02). Generic cooldown reduction does not shorten reload; secondary shots neither spend nor refill ammunition.

**Readability/production:** Medium. Three visible bolts, reload bar, distinct Final Word trace. One kit-local magazine; do not introduce a universal ammunition system for every projectile kit.
