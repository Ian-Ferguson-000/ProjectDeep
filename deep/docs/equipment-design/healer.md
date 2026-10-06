# Healer kits

[Packet overview and shared rules](README.md) · [Review decisions](review-workbook.md)

**Class promise:** A capable solo combatant who turns prevention, recovery, and positioning into Grace. Never require an injured teammate to deal useful damage. The standard remains intact; alternatives tie restoration to finite combat events. All candidates are unapproved.

| ID | Kit | Status | Distinct decisions | Cost |
|---|---|---|---|---|
| KIT-HEA-01 | Sunwood Staff | Recommended standard | Slow, empower, recent-wound recovery, healing movement | Low |
| KIT-HEA-02 | Censer of Absolution | Recommended | Cleansing pulses, timed sanctuary, close combat | Medium |
| KIT-HEA-03 | Thorn-Mercy Branch | Recommended | Marked wounds, offensive healing, consuming seeds | High |
| KIT-HEA-04 | Pilgrim's Chime | Recommended | Moving cadence, echo paths, timed recovery | High |
| KIT-HEA-05 | Solstice Crook | Reserve | Alternating offense/ward phases, predictable rhythm | Medium |
| KIT-HEA-06 | Lantern of Last Rites | Reserve | Delayed wounds, prevention choices, spectral lines | High |

## Proposed discovery sources

These are preferred offer pools, not guaranteed drops or new map requirements. Alternatives can also appear in class-compatible elite kit offers after class recruitment. First recovery adds a physical kit to the armory on successful extraction; later merchants may sell copies. Reserve sources apply only if the candidate is promoted. Unlock difficulty never grants higher baseline power.

| Kit | Preferred acquisition |
|---|---|
| [KIT-HEA-01](#kit-hea-01) | Bound starter for a Healer; preserve Sunwood identity. |
| [KIT-HEA-02](#kit-hea-02) | Ashen Farmstead cleansing cache or support elite reward; no faith requirement. |
| [KIT-HEA-03](#kit-hea-03) | Verdant Forest support cache; preserve the existing Mercy Branch collection association. |
| [KIT-HEA-04](#kit-hea-04) | Road/support merchant after a recovered support cache; no requirement to heal another player. |
| [KIT-HEA-05](#kit-hea-05) | Reserve: Moonlit Grove support cache if promoted; replaces Censer. |
| [KIT-HEA-06](#kit-hea-06) | Reserve: Stone Crypt support cache if promoted; replaces Thorn-Mercy. |

<a id="kit-hea-01"></a>
## KIT-HEA-01 — Sunwood Staff

**Equipment and fantasy:** Preserve the existing staff and four actions. A mobile light-wielder who slows pursuit and repairs a portion of a recent wound. Choose a forgiving ranged baseline.

| Slot | Baseline behavior |
|---|---|
| Basic — Binding Light | Aimed radiant projectile, 330 px range, 0.25s CD. Applies the configured slow for 1.5s and awards 1 Grace on enemy-hit callbacks. Slasher scales it with spell power, unlike older class text. |
| Special — Empower | 2 Grace, 2.5s CD. Arm empowerment: the next spawned projectile doubles its damage and gains 1s status duration. Recasting does not stack multiple empowerments. |
| Defensive — Recover | 4s CD, 1.2s window. The next damaging hit restores half of final damage afterward. It is not a shield or healing of old damage. |
| Movement — Healing Dash | 145 px movement, 1.3s CD, 0.18s protection. Traveling at least 80 px restores 3 health in current base tuning. |

**Sequence:** Slow with Binding Light → Empower the next shot → dash to preserve range → Recover before an anticipated hit. Existing dash restoration costs 1 Grace but is not enemy-gated, and Grace regenerates; flag its renewable out-of-combat potential for later tuning approval rather than changing the standard here.

**Matchups:** Reliable solo kiting, limited burst and no current teamwide heal in these four actions. Bosses still take projectile damage when slow is ineffective. Party benefit is ordinary enemy control; do not describe self-healing as healing the roster.

**Builds:** Wound keeper: [Saint's Phial](supporting-items.md#itm-hea-02) + [Tide Pearl](relics.md#rel-20). Mobile light: [Pilgrim's Greaves](supporting-items.md#itm-hea-04) + [Pilgrim Bell](relics.md#rel-18). Overheal triggers must have their own encounter caps; renewable dash healing cannot farm shields or damage indefinitely.

**Readability/production:** Low. Preserve slow/empower cues; show Recover separately from barrier absorption. Proposed item interactions require the shared proc protections even though the kit itself is unchanged.

<a id="kit-hea-02"></a>
## KIT-HEA-02 — Censer of Absolution

**Equipment and fantasy:** A swinging incense censer. A close-range purifier who earns breathing room by standing in danger. Changes projectile aiming to arcs and defense to spatial sanctuary.

| Slot | Proposed behavior |
|---|---|
| Basic — Incense Sweep | Close radiant cone, 0.6s CD; normal damage and 1 Grace on enemy hit. Mark the first enemy struck with Ash for 3s; only one Ash target at a time. |
| Special — Sanctify | 2 Grace, 5s CD. Place a close-radius sanctuary at self for 3s. On creation deal radiant damage and consume nearby Ash to heal self for 5% max health once. No Ash means damage but no heal. |
| Defensive — Purifying Veil | 5s CD. Clear self Slow/Poison and reduce the next hit within 0.8s by 50%. Preventing a hit grants 1 Grace. Within sanctuary, also cleanse one nearest deployed ally; solo has no extra heal. |
| Movement — Procession | 3s CD. Medium grounded dash with 0.15s protection. If departing sanctuary, carry its remaining aura for 1s without re-triggering damage, healing, or duration. |

**Sequence:** Sweep an enemy → Sanctify close enough to consume Ash → Veil the retaliation → Procession out. Healing requires an enemy and an expenditure, with a 3s internal heal lockout.

**Matchups:** Strong against close mixed-status packs, weaker at chasing archers. Bosses can carry Ash even if immune to control. Solo damage and restoration work without allies; party support is the explicitly limited cleanse.

**Builds:** Cleanser: [Healer's Brooch](supporting-items.md#itm-hea-01) + [Tide Pearl](relics.md#rel-20). Sanctuary fighter: [Mercy Thread](supporting-items.md#itm-hea-06) + [Warden's Seal](relics.md#rel-16). Constant knockback removes Ash targets from sanctuary; stationary rewards conflict with carrying it.

**Readability/production:** Medium. Swing arc, Ash icon, friendly sanctuary edge, cleanse feedback. Cleansing Poison removes remaining damage, not a damage event eligible for healing or resource refunds.

<a id="kit-hea-03"></a>
## KIT-HEA-03 — Thorn-Mercy Branch

**Equipment and fantasy:** Living staff whose thorns turn enemy wounds into recovery. A healer who sets up and harvests marks; no self-damage requirement. Changes resource rhythm and target commitment.

| Slot | Proposed behavior |
|---|---|
| Basic — Suture Thorn | Medium physical/radiant-themed piercing thorn dealing radiant damage, 0.55s CD. Add one Seed to the first enemy hit, maximum three for 4s. Gain 1 Grace on connection. |
| Special — Harvest Mercy | 2 Grace, 4.5s CD. Aim at one seeded enemy within long range. Consume all Seeds for heavy radiant damage and heal self 2% max health per Seed. Without a mark, fire a normal-damage thorn and give no heal. |
| Defensive — Briar Dressing | 5s CD. Arm a 0.8s, 60% mitigation window. Preventing damage adds one Seed to the attacker if in medium range and grants 1 Grace. No attacker means mitigation only. |
| Movement — Rootwalk | 3s CD. Short dash with 0.15s protection and a 2s slowing strip; does not add Seeds. |

**Sequence:** Seed a priority target → bait a hit into Dressing or reposition → Harvest before the mark expires. Maximum one healing harvest per 4s; spawned enemies cannot refresh an encounter's item/relic healing budget.

**Matchups:** Strong sustained duels, weak against targets dying before Harvest and frequent invulnerability phases. Bosses accept Seeds as marks, not control. Solo receives the entire kit heal. No automatic ally lifesteal; a later relic may redirect a portion explicitly.

**Builds:** Long duel: [Saint's Phial](supporting-items.md#itm-hea-02) + [Tide Pearl](relics.md#rel-20). Protected harvest: [Sunward Periapt](supporting-items.md#itm-hea-03) + [Briar Seed](relics.md#rel-14). Echoes cannot duplicate Seed consumption or healing; mark-transfer items may extend duration but never copy Seeds to every enemy.

**Readability/production:** High. Three-pip seed display, target selection, healing link, marks owned per caster. Distinguish healing from damage visually without a screen-filling green burst. Requires an explicit consumed-mark event.

<a id="kit-hea-04"></a>
## KIT-HEA-04 — Pilgrim's Chime

**Equipment and fantasy:** A staff with three tuned bells. Sustain a moving cadence and place echoes where enemies will be, rather than camp a sanctuary. Changes movement's offensive role and recovery timing.

| Slot | Proposed behavior |
|---|---|
| Basic — First Note | Medium aimed radiant ring segment, 0.55s CD. Gain 1 Grace on hit; after moving at least close distance since the previous Basic, leave one Note at cast origin for 3s. Maximum two Notes. |
| Special — Returning Hymn | 2 Grace, 5s CD. Notes send a normal-damage pulse toward self, then expire. Self also emits one close pulse, so no setup still deals damage. Each enemy takes at most two pulses from the activation. |
| Defensive — Rest Between Notes | 5s CD. The next hit within 1s is reduced 50%; if prevented, gain 1 Grace and store 4% max health recovery. Landing the next Basic on an enemy within 3s pays that recovery once; otherwise it expires. |
| Movement — Pilgrim Step | 2.5s CD. Medium dash, 0.15s protection, automatically leaves a Note at departure subject to the same two-Note cap. No direct heal. |

**Sequence:** Step → land a Basic from a new angle → Rest before pressure → hit again to recover → Hymn through the converging lanes. Rewards movement and enemy contact, not idle walking for healing.

**Matchups:** Strong against pursuers; poor when forced into a small arena corner. Bosses take converging pulse damage without needing to move. Solo is complete. Notes are personal fields, not allies; party switching clears them without a pulse.

**Builds:** Traveling choir: [Pilgrim's Greaves](supporting-items.md#itm-hea-04) + [Pilgrim Bell](relics.md#rel-18). Measured recovery: [Saint's Phial](supporting-items.md#itm-hea-02) + [Chronomancer's Pin](relics.md#rel-02). Stationary-field rewards and echoes of field creation are incompatible.

**Readability/production:** High. Two Note indicators, return-lane telegraphs, pending-recovery icon. Audio adds rhythm but cannot be the sole indicator of a charged note.

<a id="kit-hea-05"></a>
## KIT-HEA-05 — Solstice Crook

**Reserve alternative to:** Censer for less positional complexity. A two-faced crook alternates Dawn and Dusk through successful Specials. Changes phase timing and protection conversion.

| Slot | Proposed behavior |
|---|---|
| Basic — Turning Ray | Long single-target radiant ray, 0.6s CD; 1 Grace on hit. Dawn adds a small splash; Dusk slows the target. The kit starts in Dawn each encounter. |
| Special — Turn the Season | 2 Grace, 4s CD. Dawn: medium cone of heavy radiant damage. Dusk: normal cone damage plus 10%-health self barrier for 2s. Toggle phase after resolving. |
| Defensive — Equinox | 5s CD. Reduce the next hit within 0.8s by 60%, awarding 1 Grace; in Dusk also clear self Slow, in Dawn widen the next Basic once. |
| Movement — Sunpath | 3s CD. Medium dash, 0.15s protection. Does not change phase; preserve predictability. |

**Sequence:** Dawn cone → use Dusk to cover retaliation → build Grace → Dusk cone and barrier → return to burst. Solo needs no heal target. Bosses accept cone damage; slowing immunity does not disable the Dusk barrier. A nearest deployed ally may receive the Dusk barrier instead through an explicit relic, never automatically.

**Builds:** Ward cycle: [Sunward Periapt](supporting-items.md#itm-hea-03) for potion overheal + [Root of Eternity](relics.md#rel-23) for Dusk's kit barrier. Radiant pressure: [Dawn Wick](supporting-items.md#itm-hea-05) + [Starfallen Sigil](relics.md#rel-01). Cooldown planning matters; an echo never toggles phase a second time.

**Readability/production:** Medium. Two clearly shaped phase icons, readable next-Special preview, separate barrier indicator. Compared with Sunwood, damage/defense alternation replaces reactive wound restoration; keep the two-phase rule small enough to learn in one room.

<a id="kit-hea-06"></a>
## KIT-HEA-06 — Lantern of Last Rites

**Reserve alternative to:** Thorn-Mercy for risk management rather than lifesteal. A funerary lantern preserves a wound briefly; it does not summon dead allies or provide an extra life.

| Slot | Proposed behavior |
|---|---|
| Basic — Vigil Beam | Medium narrow radiant beam, 0.65s CD; 1 Grace on hit. Direct enemy hits cancel up to 2% max health of a pending Vigil wound, once per cast. |
| Special — Toll for the Living | 2 Grace, 5s CD. Heavy close radiant burst; cancel up to 5% max health pending wound. No pending wound means the full damage remains, without healing. |
| Defensive — Borrowed Breath | 7s CD. For 0.8s, defer half of the next hit, capped at 15% max health, for 3s. Take the rest immediately and gain 1 Grace. Only one deferred wound; remaining debt then deals unavoidable health loss. |
| Movement — Funeral Pace | 3s CD. Short dash, 0.15s protection; neither delays debt nor cancels it. |

**Sequence:** Borrow one hit → land beams while repositioning → Toll if cancellation is worth the resource. Weak against repeated hits and invulnerability phases; strong when the player can answer a predictable boss attack. Solo damage works at all times. Debts belong to the injured adventurer and resolve before a safe party/kit swap.

**Builds:** Debt control: [War Scholar's Codex](supporting-items.md#itm-shr-12) + [Chronomancer's Pin](relics.md#rel-02). Counterpressure: [Dawn Wick](supporting-items.md#itm-hea-05) + [Starfallen Sigil](relics.md#rel-01), which echoes Toll's damage but never its wound cancellation. Incompatible with Hourglass of Borrowed Blood; never defer already deferred damage or trigger on-damage rewards from repayment.

**Readability/production:** High. Segmented health debt overlay, countdown, and explicit lethal warning. Major ownership/testing burden; reserve until the simpler healer kits are proven fun.
