# Mage kits

[Packet overview and shared rules](README.md) · [Review decisions](review-workbook.md)

**Class promise:** Build Mana while shaping ranged engagements. Elemental kits change the player's decisions, not just damage color. All five alternate Mage kits are now authorized testing-ground prototypes; release selection and acquisition remain unapproved. The fast timings below describe current prototypes before progression and item modifiers. See [Mage playtesting builds](../MageBuilds.md) for numerical tuning, controls, and verified interactions.

| ID | Kit | Status | Distinct decisions | Cost |
|---|---|---|---|---|
| KIT-MAG-01 | Apprentice's Spellbook | Recommended standard | Mobile arcane projectiles, repel, blink combos | Low |
| KIT-MAG-02 | Tome of the Pyromancer | Recommended | Ignite prepared ground, consume fire, commit to lanes | High |
| KIT-MAG-03 | Winterglass Codex | Recommended | Accumulate chill, fracture at the right time, wall geometry | High |
| KIT-MAG-04 | Stormbringer's Grimoire | Recommended | Place a conductor, route lightning, relocate the circuit | High |
| KIT-MAG-05 | Grimoire of Gravity | Reserve | Delayed orbit, grouping, displacement anchors | High |
| KIT-MAG-06 | Mirrorbound Manuscript | Reserve | Recorded aim, offset origin, deliberate replay | High |

## Approved prototype revisions

The [current playtesting guide](../MageBuilds.md) is authoritative for implemented numbers and replaces older ability details below where they differ. Cinder Trail now stacks and any fire lights continuous flames; Furnace Mantle burns a 130 px aura without requiring prevention. Mirrorbound adds half-strength Silver Script shots from its mirror. Stormbringer supports three rods and Flash Circuit travels to the rod nearest the clicked point. Winterglass Basic is 5x spell power, cold kills launch eight radial needles, and Fracture/Retreat leave five-second frozen terrain with +40% caster movement speed. These adjustments are approved for prototypes; release acquisition remains proposed.

## Proposed discovery sources

These are preferred offer pools, not guaranteed drops or new map requirements. Alternatives can also appear in class-compatible elite kit offers after class recruitment. First recovery adds a physical kit to the armory on successful extraction; later merchants may sell copies. Reserve sources apply only if the candidate is promoted. Unlock difficulty never grants higher baseline power.

| Kit | Preferred acquisition |
|---|---|
| [KIT-MAG-01](#kit-mag-01) | Bound starter for a Mage; current Missile Focus identity becomes the standard book. |
| [KIT-MAG-02](#kit-mag-02) | Ashen Farmstead fire cache, with a secondary chance from an eligible Mage elite reward before that route; never force a fire-resistant route to obtain the first alternative. |
| [KIT-MAG-03](#kit-mag-03) | Stone Crypt control cache or eligible arcane elite reward; no new ice dungeon required. |
| [KIT-MAG-04](#kit-mag-04) | Sunken Mine arcane cache or eligible Mage elite reward; conductive machinery supplies flavor, not a class gate. |
| [KIT-MAG-05](#kit-mag-05) | Reserve: Abyssal Archive cache if promoted; replaces Winterglass. |
| [KIT-MAG-06](#kit-mag-06) | Reserve: Abyssal Archive cache if promoted; reuses Astral Covenant collection identity and replaces Stormbringer. |

<a id="kit-mag-01"></a>
## KIT-MAG-01 — Apprentice's Spellbook

**Equipment and fantasy:** Recast the current Missile Focus's identity as the requested standard spellbook. A generalist with Magic Missile, Fireball, Repel, and Blink. Naming is proposed; abilities are preserved.

| Slot | Baseline behavior |
|---|---|
| Basic — Arcane Missile | Aimed projectile, 360 px range, 0.22s base CD, small 62 px impact area. Projectile enemy-hit callbacks award 1 Mana; the configured minimum-distance field is not checked there. |
| Special — Fireball | Spend 1 Mana; 2.8s CD. A piercing 480 px projectile with an 88 px impact area. Despite its visual/name, the runtime constructs it as arcane damage. |
| Defensive — Repel | 0.25s base CD; immediately push enemies within 100 px, then arm 1s of 50% mitigation for the next hit. Prevention can award resource. |
| Movement — Blink | Up to 380 px, 0.5s base CD, 0.28s landing protection. Destination resolution respects the runtime's collision checks; do not promise travel through walls. |

**Sequence:** Preserve Spellstorm Volley (Missile, Missile, Blink, Fireball), Riftburst (Fireball, Blink), and Force Prism (successful Repel, Missile, Fireball). Their timing and tuning remain the existing standard-kit baseline.

**Matchups:** Flexible solo crowd damage and emergency spacing; less specialized field control than the alternatives. Bosses reward aiming and combo windows. Party contribution is ranged damage and pushing ordinary enemies, with no invented ally aura.

**Builds:** Precision arcana: [Aether Prism](supporting-items.md#itm-mag-05) + [Starfallen Sigil](relics.md#rel-01). Mobile spellwork: [Chalk Rune Tablet](supporting-items.md#itm-mag-06) + [Pilgrim Bell](relics.md#rel-18). Fire-only supporting items are dormant until an explicit future decision changes the standard's damage typing; a fire-looking projectile is insufficient.

**Readability/production:** Low for the existing kit, plus book icon/name review. Tooltips must distinguish flavor and actual damage type. Its repeatable damage rate is now a minimum comparison gate for Mage prototypes; alternate kits preserve numerical progression without importing its combo mechanics.

<a id="kit-mag-02"></a>
## KIT-MAG-02 — Tome of the Pyromancer

**Equipment and fantasy:** A soot-edged tome whose spells all use fire. Choose it to prepare a battlefield and decide when to cash out burning ground. Changes resource generation, defensive purpose, and delayed area targeting from the standard.

| Slot | Proposed behavior |
|---|---|
| Basic — Ember Lance | 360 px piercing fire lance, 0.18s CD. Applies Burn and gains 1 Mana on the first direct enemy hit. Any fire source ignites a Cinder Trail into continuous 2s flames along its full path. Repeated dash trails coexist and stack; visual tile overlaps tick once per trail. |
| Special — Conflagration | 1 Mana, 0.9s CD. Target within 240 px; after 0.28s, deal heavy fire damage in a 100 px radius. Consume nearby owned patches to widen it by 20% once. Burning targets take 30% extra direct damage, consuming their owned Burn. The resolved blast ignites all trails touching its area. |
| Defensive — Furnace Mantle | 0.6s CD. For 0.6s reduce the next hit by 60%; prevention grants 1 Mana. Independently, immediately apply and refresh Burn to all enemies within 130 px throughout the 0.6s aura, even without being attacked. Aura ignition persists after mitigation is consumed. No push and no passive fire immunity. |
| Movement — Cinder Trail | 0.65s CD. Move up to 300 px with 0.2s protection, leaving an unlit 4s trail. Trail alone does no damage. Any fire touching it ignites the whole path. Multiple unlit trails and their independently timed flames remain after later dashes. |

**Sequence:** Dash across an approach → aim Ember Lance through the trail and into a foe → bait enemies into the patch → detonate with Conflagration. Against a stationary boss, direct Lance/Burn and aimed Conflagration remain sufficient; moving enemies are an advantage, not a requirement.

**Matchups:** Excellent choke control and delayed burst; weak against enemies leaving telegraphs, interruptions, and fire-resistant foes. No immunity bypass; denied control is not relevant to Burn. Solo has its own resource loop. Party allies can exploit damaged clusters but cannot ignite or consume the owner's fields.

**Builds:** Patient burn: [Embershard Focus](supporting-items.md#itm-mag-01) + [Crown of the First Flame](relics.md#rel-04). Close furnace: [Flameheart Talisman](supporting-items.md#itm-mag-02) + [Briar Seed](relics.md#rel-14). Push-heavy effects can eject enemies from Conflagration; secondary echoes cannot create fresh fields or consume Burn twice.

**Readability/production:** High. Separate unlit trail, active flame, and detonation outline; fire effects must not obscure enemy windups. Needs field ownership, ignition, consumption, and independent trail lifetimes and continuous flame coverage. All damaging abilities and triggered kit pulses are fire-based.

<a id="kit-mag-03"></a>
## KIT-MAG-03 — Winterglass Codex

**Equipment and fantasy:** Ice plates bound as pages. Choose control and delayed fracture, trading raw mobility for geometry. Changes target setup and defense through a temporary wall.

| Slot | Proposed behavior |
|---|---|
| Basic — Rime Needle | 5x spell power, 400 px single-target ice projectile, 0.18s CD. Cold kills shatter into eight radial needles at 12x spell power with 220 px range; secondary cold deaths may chain, without Mana or hit procs. Add one Chill for 3s, maximum three; each stack slows ordinary movement 10%. Gain 1 Mana per cast. Reapplication refreshes duration. |
| Special — Fracture | 1 Mana, 0.9s CD. A 270 px, 100-degree aimed cone resolves after 0.16s. Consume Chill for 20% additional damage per stack; three-stack ordinary foes are staggered briefly. Bosses retain damage stacks but are not slowed or staggered. The resolved cone leaves frozen terrain for 5s. |
| Defensive — Icebook Wall | 0.65s CD. Raise one 130 px wall perpendicular to aim 90 px ahead for 2s, replacing the previous wall. Stops ordinary hostile projectiles and enemy movement; navigation routes enemies around it. Friendly movement and shots pass through. Placement refuses occupied spaces. Only its first blocked shot grants 1 Mana. |
| Movement — Skating Retreat | 0.65s CD. Glide backward up to 300 px with 0.2s protection. Leave a 5s frozen strip. Both frozen field types slow ordinary enemies 35% and increase caster walking speed 40% while inside; fields coexist, speed bonuses do not stack, and terrain grants no Chill or Mana. |

**Sequence:** Needle a priority enemy → create a firing angle around the wall → skate away → Fracture before Chill expires. Solo output does not require frozen targets. Boss Chill contributes to Fracture damage even if movement slow is denied; do not add a second vulnerability on top merely for that denial.

**Matchups:** Strong at controlling approaches, weaker in open multi-angle crossfire and against fast target switching. Deployed allies may shelter behind the wall, but it must not block friendly movement or shots.

**Builds:** Fracture specialist: [Rime Spindle](supporting-items.md#itm-mag-03) + [Starfallen Sigil](relics.md#rel-01). Defensive caster: [Chalk Rune Tablet](supporting-items.md#itm-mag-06) + [Warden's Seal](relics.md#rel-16). Fire-only items have no effect; broad knockback can scatter the Fracture cone.

**Readability/production:** High. Three visible Chill pips, friendly wall silhouette, boss resistance feedback. Requires projectile-blocking geometry with unobstructed path checks; its wall has a short finite life and cannot rebuild itself from blocked damage.

<a id="kit-mag-04"></a>
## KIT-MAG-04 — Stormbringer's Grimoire

**Equipment and fantasy:** A copper-clasped lightning folio. Route a circuit through a placed conductor; choose geometry and cadence rather than burning ground or slow buildup.

| Slot | Proposed behavior |
|---|---|
| Basic — Forked Spark | 0.18s CD. Aim at an enemy within 360 px; always chain to up to four distinct enemies, each bounce within 180 px. Without a conductor, each bounce retains 70% of the previous hit's damage. Any active owned conductor preserves full damage throughout the chain. Gain 1 Mana per cast, not per bounce. |
| Special — Grounding Rod | 1 Mana, 0.9s CD. Place a conductor within 340 px for 5s; keep up to three active. After 0.18s, pulse lightning in a 110 px radius every 0.45s. A fourth rod replaces the oldest without a death event; the other two remain. |
| Defensive — Static Screen | 0.6s CD. For 0.6s destroy up to three ordinary projectiles in a frontal 130 px screen. Also mitigate the next incoming hit by 50%. Grant at most 1 Mana per activation across blocking and mitigation. Its first projectile block charges each existing rod's next pulse for 50% extra damage; no rod means no stored charge. |
| Movement — Flash Circuit | 0.65s CD. Travel to the rod nearest the clicked world point, respecting bounds and obstacles; without rods, dash 240 px along aim. Grant 0.2s protection. Rods stay in place and their lifetimes are not renewed. |

**Sequence:** Spark a pack immediately → place a rod to remove bounce falloff and add pulses → block frontal shots to charge one pulse → travel between established rods. A lone boss takes full primary Spark damage plus nearby conductor pulses; it is never counted as its own bounce target.

**Matchups:** Strong distributed packs, weaker targets separated by more than bounce range. Primary damage remains competitive without a rod. Solo is complete. Allies benefit from coverage but cannot charge this caster's rod.

**Builds:** Circuit walker: [Stormglass Bead](supporting-items.md#itm-mag-04) + [Pilgrim Bell](relics.md#rel-18). Circuit sequencing: [Chalk Rune Tablet](supporting-items.md#itm-mag-06) + [Unwritten Equation](relics.md#rel-08). Knockback-heavy partners can break conductor proximity; rod is a field, not a summon.

**Readability/production:** High. Animated jagged arc paths, conductor radius, charged tip, and finite screen. Hard limit one rod and four distinct targets per Basic; no repeated-target loops, secondary Mana, chain recursion, or offscreen lightning targeting.

<a id="kit-mag-05"></a>
## KIT-MAG-05 — Grimoire of Gravity

**Reserve alternative to:** Winterglass if grouping is more desirable than barriers. A heavy, floating book changes delayed targeting and battlefield anchors.

| Slot | Proposed behavior |
|---|---|
| Basic — Orbiting Stone | 0.18s CD. After a 0.1s launch delay, fire an aimed 400 px arcane orb with a 65 px impact area. Gain 1 Mana per cast hitting enemies. No homing after launch. |
| Special — Collapse | 1 Mana, 0.9s CD. Place a 115 px-radius well within 300 px. Pull ordinary enemies for 0.45s, then deal heavy arcane damage. Bosses remain stationary and take the final hit. Replacing an unresolved well resolves its burst once. |
| Defensive — Heavy Air | 0.6s CD. A personal 105 px field for 0.6s slows ordinary hostile shots 50%; the next hit is reduced 50% and grants 1 Mana on prevention. Shots recover speed on exit, expiry, or kit removal. |
| Movement — Anchor Exchange | First use moves up to 300 px, leaving one anchor for 3s. After a 0.2s return gate, one free recast returns to it and consumes it, starting the normal 0.65s cooldown. Both landings have 0.15s protection; no second anchor or resource reset. |

**Sequence:** Anchor → place well → fire delayed stones into it → return before pressure arrives. Strong pack control but vulnerable to untelegraphed relocation and target movement; boss output relies on predicting recovery rather than displacement.

**Builds:** Crossing trajectories: [Aether Prism](supporting-items.md#itm-mag-05) + [Echo Prism](relics.md#rel-09). Mobile safety: [Chalk Rune Tablet](supporting-items.md#itm-mag-06) + [Moon Dial](relics.md#rel-17). Ally knockback directly competes with the well; communicate pull fields. Solo needs no teammate.

**Readability/production:** High. Distinct well countdown and return anchor; prototype enemy steering and projectile slowdown before promoting. Anchors cannot survive room changes, defeat, or safe kit swaps; return validates the current destination.

<a id="kit-mag-06"></a>
## KIT-MAG-06 — Mirrorbound Manuscript

**Reserve alternative to:** Stormbringer if deliberate replay is preferred to chains. A reflective book rewards anticipating where a second attack will originate.

| Slot | Proposed behavior |
|---|---|
| Basic - Silver Script | 0.18s CD. Fire a 420 px piercing bolt for 12x spell power and record its aim/full damage while a mirror lives. The mirror also fires a smaller half-damage Basic along the same aim. Only the primary bolt grants Mana or hit procs; lesser shots cannot echo or record. |
| Special — Read Again | 1 Mana, 0.9s CD. Immediately fire a heavy bolt from self; replay the recorded normal bolt from the mirror after 0.12s, consuming the recording. Without one, the self bolt still fires at full strength. Replay cannot generate Mana, item hit procs, echoes, or recordings. |
| Defensive — Blank Page | 0.6s CD. Reduce the next hit within 0.6s by 60%, gain 1 Mana on prevention, and erase an existing recording to create a 10%-max-health barrier for 2s. The barrier can absorb residual damage from that hit, is consumed by absorbed damage, replaces rather than stacks, and never heals. |
| Movement — Set the Reflection | 0.65s CD. Move up to 300 px with 0.2s protection, leaving one stationary mirror at departure for 5s. It has no body, AI, collision, health, or autonomous attacks. |

**Sequence:** Dash past an angle → record a bolt → aim the self shot so both lanes cross the target → decide whether defense is worth erasing the second shot. Solo and bosses use the same geometry; teleporting enemies counter the setup.

**Builds:** Replay planner: [Aether Prism](supporting-items.md#itm-mag-05) + [Chronomancer's Pin](relics.md#rel-02). Safety script: [Chalk Rune Tablet](supporting-items.md#itm-mag-06) + [Blackoak Covenant](relics.md#rel-15). Starfallen Sigil echoes only the self projectile, never the mirror record; no doubling the recorder.

**Readability/production:** High. Draw the recorded direction visibly, with an accessible non-color cue. Changes attack origin and defense tradeoff from the standard. Party members cannot record their attacks into the mirror; no phantom ally or summon-death triggers.
