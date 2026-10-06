# Summoner kits

[Packet overview and shared rules](README.md) · [Review decisions](review-workbook.md)

**Class promise:** Make meaningful commands, not merely watch pets deal damage. Bond powers coordinated actions. Each kit has a usable zero-cost Basic even when its summon is missing. All candidates are unapproved.

For new kits, a missing summon is restored by the next Basic after a 1s arrival, with the Basic's ordinary CD and no Bond cost. This prevents resource deadlocks; restoration deals no damage and awards no resource. New summons are limited, commandable, and cannot trigger player-on-hit items unless explicitly eligible. On party switching, suspend/despawn owned summons without death rewards; their health and cooldown state remain attached to their owner. Standard wolf behavior is documented separately.

| ID | Kit | Status | Distinct decisions | Cost |
|---|---|---|---|---|
| KIT-SUM-01 | Bondkeeper Staff | Recommended standard | One wolf, mark/command, cover, mount | Low |
| KIT-SUM-02 | Pack Call | Recommended | Two roles, pincer formation, recalling one defender | High |
| KIT-SUM-03 | Mason's Covenant | Recommended | One construct, line attacks, stationary shelter | High |
| KIT-SUM-04 | Lantern of the Moth Choir | Recommended | Finite flock, dispatch/recall, delayed convergence | High |
| KIT-SUM-05 | Wild Covenant | Reserve | One vine companion, rooted zones, transplanting | High |
| KIT-SUM-06 | Ancient Bond | Reserve | Persistent companion posture, coordinated assault | High |

## Proposed discovery sources

These are preferred offer pools, not guaranteed drops or new map requirements. Alternatives can also appear in class-compatible elite kit offers after class recruitment. First recovery adds a physical kit to the armory on successful extraction; later merchants may sell copies. Reserve sources apply only if the candidate is promoted. Unlock difficulty never grants higher baseline power.

| Kit | Preferred acquisition |
|---|---|
| [KIT-SUM-01](#kit-sum-01) | Bound starter for a Summoner when recruited; preserve Bondkeeper identity. |
| [KIT-SUM-02](#kit-sum-02) | Verdant Forest companion cache or eligible Summoner elite reward after recruitment. |
| [KIT-SUM-03](#kit-sum-03) | Sunken Mine companion cache or eligible Summoner elite reward; construct flavor does not restrict nationality. |
| [KIT-SUM-04](#kit-sum-04) | Moonlit Grove companion cache or eligible Summoner elite reward; do not require late-route completion for every alternative. |
| [KIT-SUM-05](#kit-sum-05) | Reserve: Verdant Forest or Moonlit Grove cache if promoted; replaces Mason. |
| [KIT-SUM-06](#kit-sum-06) | Reserve: Moonlit Grove companion cache if promoted; replaces Pack Call. |

<a id="kit-sum-01"></a>
## KIT-SUM-01 — Bondkeeper Staff

**Equipment and fantasy:** Preserve the current Summoner's bonded wolf. One companion provides offense, interception, and movement identity.

| Slot | Baseline behavior |
|---|---|
| Basic — Mark / Command | 0.22s base CD. Select enemy near aim within 360 px; ensure wolf exists and assign its marked target. A valid target grants 1 Bond at command time. Otherwise command a position 180 px ahead. |
| Special — Summon / Pounce | 2 Bond, 2.5s CD. Ensure the wolf exists; if a valid marked enemy remains, request its pounce. Do not describe this as creating an army. |
| Defensive — Cover | 4s CD, 1s window. Reduce the next hit using the wolf's near/far interception tuning; prevention can grant resource. |
| Movement — Mount | 210 px relocation, 1s CD, 0.24s protection. Ensure wolf exists and reposition it beside the owner. Current runtime relocation is not a prolonged mounted stance. |

**Sequence:** Mark a threat → Pounce → Cover while the wolf is close → Mount to relocate together. The live Basic grants Bond for a valid mark rather than waiting for a successful wolf bite, unlike older prose. The wolf also awards Bond when its attacks connect. It has no health/defeat handler in the current script, and cached wolves can continue crediting their benched owner; suspending new-kit summons is a proposed rule, not current standard behavior.

**Matchups:** Flexible solo companion play, weak when companion pathing or aim selects an unintended target. Bosses can be marked and pounced without needing adds. Party benefit is wolf damage; Cover protects the controlled Summoner, not everyone nearby.

**Builds:** Commander: [Command Whistle](supporting-items.md#itm-sum-01) + [Twin Command Seal](relics.md#rel-21). Close partnership: [Bond Collar](supporting-items.md#itm-sum-02) + [Pilgrim Bell](relics.md#rel-18). Item text must distinguish command issuance from attack completion; otherwise repeat marking becomes a proc exploit.

**Readability/production:** Low kit change, with medium integration risk for clearer command feedback. Show marked target and Cover proximity; never imply every friendly creature is the owned wolf.

<a id="kit-sum-02"></a>
## KIT-SUM-02 — Pack Call

**Equipment and fantasy:** Twin-toothed horn and command baton. Two smaller hounds execute a pincer rather than one large wolf doing everything. Changes formation and defense allocation.

| Slot | Proposed behavior |
|---|---|
| Basic — Split the Quarry | Medium aimed command, 0.7s CD. Hounds approach opposite sides of one target; one connected commanded attack grants 1 Bond across the pair. No valid target means reposition formation without gain. |
| Special — Closing Jaws | 2 Bond, 5s CD. Both hounds dash toward the marked point, each dealing normal damage; a target struck by both receives one additional fixed bonus. If only one survives, it still attacks. |
| Defensive — Call the Rearguard | 5s CD. Recall the nearest hound beside self for 1s; reduce the next hit by 60% if it arrives, otherwise 30%. Prevention grants 1 Bond. Recalled hound suspends offense. |
| Movement — Pack Crossing | 3s CD. Medium owner dash, 0.15s protection; surviving hounds reposition to opposite nearby safe sides after arrival, without contact damage. |

**Sequence:** Split → choose the safe rear hound for Cover → cross the pack → close the jaws. Fewer than two companions reduces formation payoff but never removes the Basic recovery route.

**Matchups:** Strong flanking of ordinary enemies and large bosses; weaker in narrow corridors, where hounds use safe adjacent positions rather than force a pincer. Solo complete. Friendly party members cannot count as the second hound for the bonus.

**Builds:** Formation: [Pack Harness](supporting-items.md#itm-sum-03) + [Twin Command Seal](relics.md#rel-21). Reliable defense: [Bond Collar](supporting-items.md#itm-sum-02) + [Blackoak Covenant](relics.md#rel-15). Per-summon hit multipliers are capped per command; no doubled reward simply for two bodies.

**Readability/production:** High. Two differentiated silhouettes, formation paths, rearguard indicator, pathfinding fallback. Requires a two-unit cap and shared command IDs before considering flock-scale designs.

<a id="kit-sum-03"></a>
## KIT-SUM-03 — Mason's Covenant

**Equipment and fantasy:** Clay seal and stone command staff. One golem becomes a positional partner, not a faster wolf. Changes line targeting and stationary protection.

| Slot | Proposed behavior |
|---|---|
| Basic — Carved Order | Medium point command, 0.8s CD. Golem strikes a short line toward the point after 0.35s; a hit grants 1 Bond once. Golem walks toward points beyond its reach. |
| Special — Faultline | 2 Bond, 5s CD. Golem sends a medium ground shock line after 0.6s, heavy physical damage. With missing golem, summon it but do not also attack. |
| Defensive — Shelter in Stone | 5s CD. When within close range of golem, gain 70% next-hit reduction for 1s; otherwise 30%. Prevention grants 1 Bond. Golem stops attacking for that second. |
| Movement — Call to Heel | 3s CD. Short owner dash, 0.15s protection; golem moves rapidly to a safe nearby point, without damage or teleport through walls. |

**Sequence:** Put golem beside an approach → line up Faultline → shelter during recovery → move together. Strong deliberate chokepoints; weak rapid scattered pursuit. Boss output comes from aimed lines even when control is denied.

**Solo/party:** Owner has a complete command-and-defense loop. Deployed allies may stand nearby but do not inherit Shelter automatically. Golem is damageable; zero-cost recovery ensures its loss is a setback rather than a dead run.

**Builds:** Durable partner: [Clay Seal](supporting-items.md#itm-sum-04) + [Warden's Seal](relics.md#rel-16). Shock commander: [Command Whistle](supporting-items.md#itm-sum-01) + [Worldbreaker Gauntlet](relics.md#rel-05). Effects needing rapid summon hits fit poorly; avoid designing around a summon dying repeatedly.

**Readability/production:** High. Golem animation, clear facing/line telegraph, navigation and damageable-companion states. Keep silhouette below boss readability and never let the golem permanently block doors.

<a id="kit-sum-04"></a>
## KIT-SUM-04 — Lantern of the Moth Choir

**Equipment and fantasy:** A spirit lantern containing three moths. Dispatch finite projectiles that return as companions; manage availability rather than autonomous pet AI. Changes cadence and defense cost.

| Slot | Proposed behavior |
|---|---|
| Basic — Send a Voice | Medium targeted moth, 0.5s CD. Dispatch one available moth for a hit, then it returns over 1s; direct connection gains 1 Bond. With none available, emit a light-damage spark with no Bond gain. |
| Special — Converging Choir | 2 Bond, 5s CD. All available moths converge on one medium-range point after 0.6s, one normal hit each, then return. With none available, recall them without damage; UI warns before spending. |
| Defensive — Fold the Wings | 5s CD. Reserve one available moth for 1s to reduce the next hit by 60%; without one reduce 30%. Successful prevention grants 1 Bond; reserved moth returns afterward, never dies. |
| Movement — Lantern Drift | 3s CD. Medium dash, 0.15s protection; return paths update to owner position but timers do not complete early. |

**Sequence:** Send one or two → preserve one for defense → wait for convergence availability → spend Bond on the group. Solo spark and automatic return prevent deadlock. Bosses take capped activation damage; three moths cannot triple relic proc chances.

**Matchups:** Strong accurate bursts and mobile recall, weak while all moths are away. Party members cannot take or refill moths. They are finite summoned agents but cannot receive ordinary healing or death rewards; mark compatibility explicitly.

**Builds:** Choir cadence: [Choir Wick](supporting-items.md#itm-sum-05) + [Twin Command Seal](relics.md#rel-21). Guarded lantern: [Bond Collar](supporting-items.md#itm-sum-02) + [Chronomancer's Pin](relics.md#rel-02). Health-based pet items do not fit moths; generic cooldown reduction does not shorten return timers.

**Readability/production:** High. Three availability pips, outbound/return colors plus shapes, strict three-agent cap. Fewer AI demands than three wolves, but careful accounting is essential.

<a id="kit-sum-05"></a>
## KIT-SUM-05 — Wild Covenant

**Reserve alternative to:** Mason's Covenant for a rooted companion. Living rootstaff commands one vine at a time; changes fixed placement and transplanting.

| Slot | Proposed behavior |
|---|---|
| Basic — Point the Thorn | Medium target command, 0.7s CD. Rooted vine fires a thorn at an enemy within its long range; hit grants 1 Bond. Missing vine is restored near self under shared rules. |
| Special — Bramble Embrace | 2 Bond, 5s CD. Vine lashes a close circle for heavy damage and 1s root. Denied boss root uses shared vulnerability; no repeated rooting from lingering graphics. |
| Defensive — Leaf Shelter | 5s CD. Self receives a 10%-health barrier for 2s; within close range of vine, it also receives a nonstacking 10%-health barrier. First enemy damage absorbed by either grants 1 Bond total. |
| Movement — Transplant | 3.5s CD. Short dash, 0.15s protection; move vine to departure point, preserving health and all cooldowns. Never heals through resummoning. |

**Sequence:** Place vine at a useful firing angle → command → draw enemies close → Embrace → transplant when exposed. Solo functional; bosses can be damaged without moving. Weak when a boss changes arena sections frequently. Deployed allies receive no barrier from Leaf Shelter unless an explicit relic redirects it.

**Builds:** Root defense: [Briar Splice](supporting-items.md#itm-res-11) + [Warden's Seal](relics.md#rel-16). Command pressure: [Command Whistle](supporting-items.md#itm-sum-01) + [Twin Command Seal](relics.md#rel-21). Items requiring a pet to chase, flank, or run do not fit; preview them as incompatible.

**Readability/production:** High. Rooted summon targeting, safe transplant placement, line-of-sight firing, distinct allied thorn silhouette. One vine only; propagation is intentionally excluded from this candidate.

<a id="kit-sum-06"></a>
## KIT-SUM-06 — Ancient Bond

**Reserve alternative to:** Pack Call for depth in one companion rather than multiple bodies. An ancestral horn commands one stag-spirit with Assault and Shelter postures.

| Slot | Proposed behavior |
|---|---|
| Basic — Ancestral Command | Medium target order, 0.7s CD. Assault: stag lunges at target. Shelter: stag stays beside owner and sends a short antler wave. Enemy connection grants 1 Bond per command. |
| Special — Remember the Hunt | 2 Bond, 5s CD. Stag makes a heavy medium line attack, then toggles posture. Missing stag is restored without the attack or toggle. Starts each encounter in Assault. |
| Defensive — Shared Vigil | 5s CD. Next hit within 1s is reduced 50% in Assault or 70% in Shelter; successful prevention grants 1 Bond. Stag health is not a second damage sink. |
| Movement — Spirit Passage | 3s CD. Medium owner dash with 0.15s protection, stag follows without contact damage. Posture remains unchanged. |

**Sequence:** Command assault → heavy hunt flips to Shelter → defend and attack with waves → next hunt restores pursuit. Solo complete and boss-capable without adds. Party members cannot trigger posture changes; allies benefit only from the stag's offensive presence.

**Builds:** Protective ancestry: [Bond Collar](supporting-items.md#itm-sum-02) + [Standard of Succession](relics.md#rel-24). Hunting rhythm: [Command Whistle](supporting-items.md#itm-sum-01) + [Chronomancer's Pin](relics.md#rel-02). Secondary echoes never toggle posture; movement bonuses cannot turn Shelter into an additional autonomous attacker.

**Readability/production:** High. New stag asset/animations, two posture silhouettes, next-Special indicator. Distinguish from the standard wolf through role switching and projected attacks, not just a larger animal and better stats.
