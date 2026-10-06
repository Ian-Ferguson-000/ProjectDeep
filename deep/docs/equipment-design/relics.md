# Relic catalogue

[Overview and shared limits](README.md) · [Existing-content audit](existing-content-audit.md) · [Review workbook](review-workbook.md)

**36 recommended relics in six families, followed by 12 reserve alternatives.** All are unapproved. Numerical examples are provisional. Unlike supporting items, these change a rule governing choices, not simply the handling of one attack.

## Rules applying to every entry

- Four expedition-wide slots; one instance of each identity, including aliases. Charges, cooldowns, counters, and “once” uses belong to the expedition relic, not a character. Party or kit swaps never reset them. Personal benefits affect the controlled owner at trigger time unless an entry explicitly names another recipient. No offscreen charging.
- All require a genuine event, not menu actions, a failed cast, self damage, player-spawned enemy farming, or repeated room entry. Relic-generated gold cannot trigger other loot relics. Once-per-floor triggers use a unique floor identity, not each entry.
- Secondary damage cannot trigger more relic/item damage, resource gain, reflection, or healing. A damage echo copies only a resolved direct damage shape at a fixed reduced coefficient; never copies summons, field creation, consumed marks, resource refunds, phase changes, healing, or another echo. It cannot exceed the original action's target range or bypass boss caps. If no eligible damage exists, it does not trigger.
- New barriers and healing follow the overview caps. Healing relics share a 15%-max-health-per-recipient-per-encounter budget with supporting items. Healing is based on actual lost health. Only the largest barrier persists. No stacking duplicates.
- Refunds from all sources together cannot exceed the resource originally spent. Cooldown reduction cannot bring an action below 50% of its base cooldown, and cannot reduce reloads, summon return timers, invulnerability cooldown locks, or the triggering action's own cooldown unless explicitly stated. Existing standard-kit combos are separate baseline behavior; future integration must check their combined effect.
- **Acquisition:** Uncommon = eligible elite chest or expedition merchant; Rare = elite/boss reward; Legendary = boss reward or explicitly previewed commitment event. Sources do not promise new map content. Any new event/choice UI is a production requirement. Recommended economy relics must have an available relevant reward/merchant ahead or be filtered out.
- **Death prevention:** Phoenix-Ash Reliquary is the only recommended automatic lethal-save relic. Any reserve alternative replaces it or is mutually exclusive. A prevented death grants 1s grace against ordinary damage, clears damaging dots, and never grants a floor reset or a second lethal-save chain. Deferred damage resolves before safe switches.

## Family 1 — Alter the attack payoff

<a id="rel-01"></a>
### REL-01 — Starfallen Sigil

**Rare · Medium · Revised existing identity.** Every third eligible direct-damage Special leaves a visible outline and repeats its damage shape after 0.6s for 35% damage. Aim/origin are recorded at cast resolution; it cannot follow the player or acquire new targets beyond that shape. Counter persists through switching; only actual eligible casts advance it. **Decision:** aim where enemies will remain rather than spam the highest coefficient. Fits standard Mage, Greatsword, Winterglass, and other direct Specials; not pure buffs, summons, or traps. Pair with Aether Prism; no recursive echo, repeated Chill consumption, or healing. **Source:** arcane elite/boss pools. Boss shields apply separately but proc budget remains one activation.

<a id="rel-02"></a>
### REL-02 — Chronomancer's Pin

**Rare · Medium · Revised existing identity.** Once per 8s, landing a direct hit with an action different from the previous successful damaging action reduces one other currently cooling action by 0.5s. Choose the longest remaining cooldown; never the triggering slot. Display the selected slot. **Decision:** alternate offense instead of repeating one button. Buff Specials qualify only when their empowered direct attack connects, attributed once. Summon commands count on completion, not issuance. Fits all classes. Pair with Drillmaster's Whistle; cooldown and refund caps remain separate. **Source:** arcane elites/bosses. No reducing the pin's own timer or giving a moth a faster return/reload.

<a id="rel-03"></a>
### REL-03 — Mirror of the Second Guard

**Rare · High · New.** Successfully preventing a direct enemy hit with Defensive stores one Mirror for 4s. Your next direct Basic sends a small aimed return shard for fixed modest damage, consuming Mirror; 6s internal cooldown. The prevented hit's actual damage or debuffs are never copied. **Decision:** turn a defense into aimed ranged retaliation. Fits reactive kits, including Mirror Aegis; no benefit from passive invulnerability or debt repayment. Pair with Runebound Bracer for an answer with both reach and geometry. **Source:** defense elites/bosses. The shard is secondary, cannot reflect or generate another Mirror, and cannot home onto the original attacker through walls.

<a id="rel-04"></a>
### REL-04 — Crown of the First Flame

**Legendary · High · Revised existing identity.** A direct fire Special that hits an enemy already Burning before this cast may consume the owner's remaining Burn to leave one close-radius eruption after 1s for fixed moderate fire damage. Once per 6s and one eruption per cast. If the kit already consumes Burn, that same consumption qualifies once; do not consume twice. **Decision:** trade sustained damage for a delayed area payoff. Fits Pyromancy; Furnace Plate needs an actual Burn source before eligible. Pair with Embershard Focus for longer patience, or Flameheart Talisman for close placement. **Source:** fire boss reward. Secondary eruption applies no Burn and cannot repeat the crown. Bosses take ordinary capped damage; fire immunity is not bypassed.

<a id="rel-05"></a>
### REL-05 — Worldbreaker Gauntlet

**Legendary · Medium · Revised existing identity.** A direct heavy physical Special creates a 3s Fracture on one enemy hit, reducing its ordinary physical mitigation 15%. Choose the nearest hit target to aim center. Its next direct physical hit consumes Fracture for a small area shock, once per 6s. **Decision:** follow a committed strike with another physical attack instead of permanently shredding every foe. Fits heavy Warrior/Tank actions and commanded golem Faultline. Pair with Giant-Bane Grip, sharing a 25% mitigation-reduction ceiling. **Source:** martial bosses. Boss shields, invulnerability, and hit caps remain intact. Shock cannot fracture another target or trigger more shocks.

<a id="rel-06"></a>
### REL-06 — Titanblood Torc

**Rare · Medium · Revised existing identity.** When direct enemy damage crosses the controlled adventurer below half health, bank one Vow for that encounter. The next resource-spending Special may spend the Vow to enlarge its direct damage shape 25%; after using it, resource gain is suppressed for 2s. Single-target actions instead gain modest fixed damage. **Decision:** take a dangerous opportunity or preserve normal resource flow. No requirement to remain at low health; Vow expires at encounter end. Fits all damaging spenders; buff/summon-only Specials are filtered out. Pair with Giant-Bane Grip. **Source:** martial/defense elites. Self damage and repeated health-threshold crossings cannot create new Vows.

## Family 2 — Change sequencing and resource choices

<a id="rel-07"></a>
### REL-07 — Hourglass of Borrowed Blood

**Legendary · High · New.** Once per encounter, Defensive can defer 20% of the next direct enemy hit within 0.8s, capped at 10% max health, for 3s. Two different direct damaging action slots connecting during that window cancel the debt; otherwise it is paid as unavoidable health loss. Ordinary Defensive protection resolves first. **Decision:** answer a wound with a varied sequence instead of retreating. Fits classes with two damaging actions; exclude Last Rites and pure buff-only combinations without an attributed empowered hit. Pair with Chronomancer's Pin. **Source:** previewed boss commitment. Debt is personal, cannot be re-deferred, and locks safe switches until resolved. Repayment triggers no on-damage benefits.

<a id="rel-08"></a>
### REL-08 — Unwritten Equation

**Legendary · Medium · Reclassified Hearth identity.** Using three different successful action slots within 4s marks the next resource-spending action within 2s for a one-resource rebate after resolution. Once per 10s; maximum rebate is the actual cost. The fourth action need not be different, so every kit qualifies. **Decision:** deliberately cycle the kit to fund a payoff. Fits all classes; pair with Sparkwire Wrap. **Source:** Abyssal Archive boss or equivalent arcane boss pool. No proc from failed actions, automatic summon attacks, or secondary echoes. Shared refund cap prevents Drillmaster's Whistle from making a spender resource-positive; no free reroll of a failed target.

<a id="rel-09"></a>
### REL-09 — Echo Prism

**Rare · High · Reclassified Hearth identity.** After using Movement, record your next direct Basic within 2s. Your subsequent Special within 3s releases a 35%-damage copy of that Basic from the Movement departure point toward its recorded aim. Once per 6s. **Decision:** plan two attack origins rather than double the next Special. Fits direct-damage Basics; summon command Basics are ineligible. Pair with Mirrorbound or standard Mage and Aether Prism; only the self-origin Basic is recorded. **Source:** arcane elites/bosses. Snapshot one action, not subprojectiles or side effects. The record disappears on encounter end; it cannot cross a closed door or survive a kit swap.

<a id="rel-10"></a>
### REL-10 — The Last Match

**Uncommon · Medium · New.** Once per encounter, if a Special would fail only because the owner is short exactly one resource, allow it to activate and put that one resource into debt. The next earned resource pays the debt instead of filling the meter. No further credit while unpaid. **Decision:** take an opening now at the cost of the next cycle. Fits every class, including support and command Specials. Pair with Drillmaster's Whistle, whose rebate repays debt first. **Source:** eligible merchant/elite pool. Does not bypass cooldown, targeting, suppression, or costs larger than the gap; no debt transfer to a benched character to escape payment.

<a id="rel-11"></a>
### REL-11 — Hunter's Star

**Rare · Medium · Reclassified Hearth identity.** Your first direct damaging Basic in an encounter designates one Quarry. Hitting it with Basic and then Special within 3s grants 1 resource after the Special, once per 6s. If it dies, designation moves only on the next Basic; hitting another living enemy breaks sequence progress. **Decision:** commit to a target or relinquish the sequence to handle threats. Fits direct attacks and commanded summon hits, with empowered shots credited once. Pair with Duelist Gloves or Giant-Bane Grip. **Source:** finesse/companion elites. Bosses qualify normally; no bonus execute. Refund capped by actual Special cost; automatic dots and pet bites do not advance the sequence.

<a id="rel-12"></a>
### REL-12 — Aegis of the Last King

**Legendary · High · Revised existing identity.** Once per encounter, a successful Defensive prevention creates a Royal Guard lasting 2s. The next direct enemy hit is split: owner takes 70%, the remaining 30% becomes a non-damaging ward that absorbs the next hit, capped at 10% max health and lasting 2s. It cannot create another Royal Guard. **Decision:** survive a paired attack with a timed first defense. Fits all reactive kits; pair with Soldier's Buckle. **Source:** defense boss pool. No lethal save or healing; this replaces the old overlap with Phoenix. Ward uses the shared barrier rule, not a second stack, and cannot absorb deferred debt or transfer itself through party switching.

## Family 3 — Change position and protection

<a id="rel-13"></a>
### REL-13 — Heartwood Crown

**Rare · Medium · Revised existing identity.** After remaining in a close-radius area for 2s during combat, grow a personal root circle. The first direct enemy hit while inside grants a 10%-health barrier for 2s after damage resolves. Then the circle is spent for that encounter. Leaving before the hit abandons it and allows a new location, but does not recharge a spent circle. **Decision:** choose one defensible stand. Fits Citadel, cover kits, or stationary casters; pair with Ironroot Ring. **Source:** forest/defense elites. No idle healing, no floor-entry recovery. A lethal hit still kills unless a separate lethal save applies; barrier is not retroactive.

<a id="rel-14"></a>
### REL-14 — Briar Seed

**Uncommon · Medium · Reclassified Hearth identity.** The first direct enemy hit each encounter plants a visible seed where the owner stood. A successful direct Special within 4s makes it erupt after 0.5s, slowing ordinary enemies in a close radius for 2s and dealing modest secondary damage. If no Special occurs, it withers. **Decision:** turn an accidental wound into a prepared counter, not farm passive retaliation. Fits every damaging/empowered Special; command completion qualifies. Pair with Brambleguard Clasp or Viper's retreat. **Source:** forest elites/merchant. No proc from dots, self damage, or intercepted debt. Bosses take damage but receive no extra vulnerability merely for resisting this relic slow.

<a id="rel-15"></a>
### REL-15 — Blackoak Covenant

**Rare · Medium · Reclassified Blackoak Ward.** At encounter start, choose through the first action: using Defensive before dealing damage arms Oak; attacking first abandons it. Oak converts the first successful prevention into a 5%-health recovery, paid only when the next direct Basic hits within 3s. Once per encounter and subject to shared healing budget. **Decision:** defensive opening versus immediate aggression. Fits all reactive classes; pair with Runebound Bracer. **Source:** forest/defense elites. An armed defense that expires gives no recovery. Health already full forfeits healing rather than making a permanent overheal battery; no rearming by room re-entry.

<a id="rel-16"></a>
### REL-16 — Warden's Seal

**Rare · High · Reclassified Hearth identity.** Creating a kit-owned stationary field, trap, or cover object marks its location. The next Defensive used inside its close radius grants a 10%-health barrier for 2s in addition to its normal action, once per 8s. Only the newest location counts; item-created fields do not qualify. **Decision:** defend from prepared ground instead of reacting anywhere. Fits Pyromancy, Winterglass, Borderkeeper, Trapper, Banner, and field/construct Summoner setups. Pair with their placement items. **Source:** defense elites/bosses. A damageable companion counts only while stationary on a ground-position command. Barrier follows the owner, not all allies; no duplicate on field replacement.

<a id="rel-17"></a>
### REL-17 — Moon Dial

**Rare · High · Reclassified Hearth identity.** Your first Movement each encounter leaves a 3s return point. Using Defensive while aiming within its close-radius marker returns you there instead of performing the normal Defensive action; no resource cost, 0.1s landing protection, and the Defensive's full cooldown applies. Use once. **Decision:** spend defense on a planned escape versus its usual protection. Fits all classes; pair with Gravity's anchor carefully—the two returns remain separate and cannot extend one another. **Source:** arcane elites. Must show an explicit alternate-action preview. Invalid terrain causes no teleport and performs ordinary Defensive instead; never cross sealed doors or recover health from the snapshot.

<a id="rel-18"></a>
### REL-18 — Pilgrim Bell

**Uncommon · Medium · Reclassified Hearth identity.** After Movement, a direct Basic hit within 2s rings the bell. The next Defensive within 2s gains 0.2s activation window; once per 6s. **Decision:** complete a move-attack-defend phrase, not spam dashes for protection. Fits all classes, including a commanded hit. Pair with Redstep Spurs, Pilgrim's Greaves, or Bond Collar. **Source:** road/support elites/merchant. It does not extend invulnerability, heal, or prevent death despite the old Hearth alias. The extra window affects readiness duration only, not how many hits can be prevented. Party switching ends the phrase while preserving cooldown.

## Family 4 — Change survival and companionship

<a id="rel-19"></a>
### REL-19 — Phoenix-Ash Reliquary

**Legendary · Medium · Revised existing identity.** Once per expedition, a lethal hit leaves the controlled adventurer at 1 health with the shared 1s death-save grace and dot cleanse. The relic then becomes inert but retains its slot until safely replaced. **Decision:** allocate a scarce slot to insurance rather than more damage. All classes eligible. Pair with Mender's Sachet only if that encounter's recovery remains available; the lethal save itself creates no heal event. **Source:** boss reward, never a repeatable merchant refill. No per-floor recharge, resurrection of benched members, or reward from deliberately dying. Mutually exclusive with reserve lethal-save alternatives.

<a id="rel-20"></a>
### REL-20 — Tide Pearl

**Rare · High · Reclassified Hearth identity.** Once per encounter, actual kit healing can bank half the restored amount, capped at 5% owner's max health. The next direct enemy hit within 3s pays that bank as healing after damage, then empties it. **Decision:** heal before a dangerous follow-up rather than wait until nearly dead. Fits Healer, potion-independent kit healers; potions and item/relic healing do not fill it. Pair with Saint's Phial. **Source:** support elites/bosses. Payment uses the shared healing budget and cannot refill the pearl or trigger another healing relic. A lethal hit is not saved; pending bank remains personal and expires on switching or encounter end.

<a id="rel-21"></a>
### REL-21 — Twin Command Seal

**Rare · High · New.** After a commanded summon attack hits, issue a command to a different living enemy within 2s to give that command 20% faster approach/travel, once per 5s. Against a single boss, a ground reposition command followed by a successful attack command qualifies instead. **Decision:** direct the companion's route and target choice rather than remain on one automated order. Fits Summoner kits with command semantics; moths qualify only through a changed target, so lone-boss moth builds do not get the reposition fallback. Pair with Command Whistle. **Source:** companion elites/bosses. Does not duplicate attacks, bodies, resource awards, or return timers. Procs once across a pack.

<a id="rel-22"></a>
### REL-22 — Empty Saddle

**Uncommon · High · New.** Once per encounter, when a damageable owned companion is defeated by an enemy, the owner's next Basic restores it at half health after the ordinary arrival delay and grants self a 10%-health barrier for 2s. **Decision:** recover a lost partner through active command instead of gaining damage by sacrificing it. Fits damageable hounds/golem/vine/stag; the current standard wolf has no health/defeat handler and is ineligible without a separately approved redesign. Moths, decoys, fields, and kit-swap despawns never qualify. Pair with Clay Seal. **Source:** companion elites/merchant. No second death benefit or gold, and health restoration cannot reset companion attack cooldowns.

<a id="rel-23"></a>
### REL-23 — Root of Eternity

**Legendary · High · Reclassified Hearth identity.** Once per encounter, the first self barrier created by a kit action may instead be shared: retain half its strength and grant the other half to one nearest living deployed ally or damageable owned companion within close range. If no recipient exists, retain full strength. **Decision:** protect a formation by standing near someone when casting, at personal cost. Fits barrier kits, not ordinary mitigation; solo without pets remains functional. Pair with Clay Seal or Sunward Periapt for separate, nonstacking defense opportunities. **Source:** Moonlit Grove boss. Shared barriers cannot share again, heal, or exceed recipient caps. No protection for the unseen roster.

<a id="rel-24"></a>
### REL-24 — Standard of Succession

**Rare · High · New.** A successful Defensive prevention stores a 3s handoff. If the player legally switches controlled adventurers in that window, the incoming adventurer receives a 10%-health barrier for 2s; once per encounter across the expedition. If no switch occurs, landing a direct Basic before expiry grants the current owner a 5%-health barrier instead. **Decision:** hand an advantage to a teammate or retain a smaller solo benefit. Fits all classes with prevention. Pair with Banner or Oathwall. **Source:** support elites/bosses. Does not enable otherwise illegal combat switches. A party system limited to safe switches uses only legal windows; flag encounter-switch feasibility before implementation.

## Family 5 — Change exploration and reward choices

<a id="rel-25"></a>
### REL-25 — Lucky Coin

**Uncommon · Medium · Reclassified existing identity.** Once per floor, replace one unchosen item option with another eligible item before taking a reward. The replacement cannot duplicate the other options or guarantee a rarer tier. Declining afterward still spends the use. **Decision:** improve a bad fit without rerolling the entire encounter. All classes eligible; pair with a specialized kit whose pool needs a precise capability. **Source:** merchant/elite reward, enabled only with an item offer ahead. No effect on kits, relics, quest rewards, or already claimed loot. Relic state, not current adventurer, owns the use; no reload/party-switch refresh in a future save implementation.

<a id="rel-26"></a>
### REL-26 — Scavenger's Token

**Uncommon · Medium · Reclassified existing identity.** Once per floor, after clearing a nonboss room, reveal one still-unopened optional cache already generated on that floor. If none exists, grant a small fixed salvage payout once instead. **Decision:** divert for optional value instead of being paid for deliberately ignoring treasure. All classes; pair with Wayfinder's Compass. **Source:** exploration elites/merchant. Never creates a cache, reveals a story secret's solution, or unlocks a gate. The fallback is relic-generated currency and cannot trigger Gilded Beetle or Fortune-Eater. Re-entering cleared rooms cannot reveal repeatedly.

<a id="rel-27"></a>
### REL-27 — Cutpurse's Favor

**Rare · Medium · Reclassified existing identity.** Once per floor, finishing an authored nonboss encounter without losing health lets the player exchange its ordinary gold reward for one additional eligible supporting-item option at the next item offer. They still choose one item. **Decision:** trade immediate purchasing power for future choice. All classes; reward is skill-oriented, not Rogue-exclusive. **Source:** finesse/merchant pool. Barrier damage is allowed; deferred health loss counts when resolved before completion. Spawned enemies give no extra opportunities. Pair with Lucky Coin, which can reroll only one option even in the enlarged offer. If no offer remains, preview and disable the exchange.

<a id="rel-28"></a>
### REL-28 — Wayfinder's Compass

**Uncommon · Medium · Reclassified existing identity.** At a branch with already generated optional routes, reveal the next room's reward category for each available exit once per floor. Reveal category only, not exact item or enemy layout. **Decision:** pursue gear, healing, or resources according to current needs. All classes; pair with Scavenger's Token. **Source:** exploration merchant/elite reward. Floors without an eligible branch offer a fixed small salvage fallback once, shown in the tooltip; cannot create branches or bypass discovery flags. No combat resource on landing and no increased movement range. Avoid presenting it as a strong pickup immediately before a linear final boss.

<a id="rel-29"></a>
### REL-29 — Gilded Beetle

**Rare · High · Reclassified existing identity.** Once per expedition at a merchant, reserve one displayed supporting item at its current price. Buy it at a later merchant on the same expedition for that price plus a 10% reservation premium; stock remains reserved even if class changes. **Decision:** defer a purchase rather than spend immediately or lose the option. All classes; pair with Lucky Coin only through improved build selection, not price discounts. **Source:** early merchant/elite reward with a later merchant ahead. No interest, resale arbitrage, free item, or carrying reservation home. Replacing the relic cancels the reservation with no refund because no payment was taken.

<a id="rel-30"></a>
### REL-30 — Deepdelver's Lantern

**Rare · High · Reclassified existing identity.** Once per floor before an optional encounter begins, preview its ordinary reward category and choose to intensify it: one existing enemy gains an elite modifier, and completion adds one item option to that encounter's reward. The player still takes one. **Decision:** choose difficulty for a better selection. All classes; pair with Giant-Bane Grip for elite preparation. **Source:** exploration elites, eligible only if compatible optional encounters remain. Never modify bosses, story scenes, enemy caps, or already active encounters. Failure grants no reward; cannot downgrade after seeing the modified fight. Needs explicit preview/accept UI and authored modifier support.

## Family 6 — Make a run-level commitment

<a id="rel-31"></a>
### REL-31 — Watcher's Lantern

**Uncommon · High · Reclassified Hearth identity.** Before entering the next unvisited combat room, optionally reveal its enemy composition. In exchange, its ordinary gold reward is reduced 20%; one use per floor. **Decision:** buy information with future earnings. All classes; pairs with specialized fire, trap, or companion kits whose matchup matters. **Source:** exploration merchant/elite pool. No exact enemy positions, hidden narrative facts, or boss phase spoilers. This is distinct from Deepdelver's reward preview and increased difficulty. If room composition is not authored/generated yet, do not offer the action until it is; never fabricate a preview.

<a id="rel-32"></a>
### REL-32 — Merchant's Balance

**Rare · High · New.** Once per expedition, at a merchant, surrender one equipped supporting item to receive a choice of two eligible items of the same rarity and take one. Preview the category and surrender cost before confirming, but not the generated choices. **Decision:** pivot a build at a real opportunity cost. All classes; useful after a kit swap. **Source:** early merchant/elite reward. The surrendered identity and its use history remain recorded; reacquiring it cannot reset encounter limits. No gold payout, rarity ladder, or replacement of relics/kits. Cannot combine the free dormant-item replacement with the same surrendered item twice.

<a id="rel-33"></a>
### REL-33 — Salt Oath

**Rare · High · New.** At the start of one floor per expedition, optionally seal potion use until that floor's boss or final required encounter is cleared. In return, gain one extra eligible option on that floor's completion reward. Still take one. **Decision:** accept a clearly bounded sustain restriction for choice. All classes; Healer has an advantage, making route/kit context important. **Source:** early boss or commitment event, never activate automatically on pickup. Kit healing remains usable. Emergency breaking of the oath restores potion use but forfeits the bonus; no damage penalty. Switching, death prevention, and replacing the relic cannot restore the forfeited reward.

<a id="rel-34"></a>
### REL-34 — Thread of Tomorrow

**Legendary · High · Reclassified Hearth identity.** Once per expedition before choosing an item reward, inspect the actual next scheduled item offer from the current deterministic reward sequence, then choose whether to take the current offer or defer it for that future offer. Deferral forfeits the current item; it does not award both or skip the intervening encounters. **Decision:** commit to future synergy at the cost of current strength. All classes; pair with Merchant's Balance for a later pivot, not duplication. **Source:** mid-expedition boss/commitment reward with a future offer ahead. If no stable future offer exists, filter out this relic. Reserve promotion may be preferable if the reward system cannot support an honest preview.

<a id="rel-35"></a>
### REL-35 — Cinderheart Locket

**Rare · Medium · Reclassified existing identity.** Once per expedition at a safe checkpoint, consume one carried healing potion to kindle the locket. Until the next encounter ends, actual kit healing is disabled, but your first two successful direct Specials each grant a 10%-health barrier for 2s. **Decision:** trade restorative play for a short offensive protection plan. All classes with Specials, including support empowerment resolved through a hit; summon commands qualify on hit. **Source:** fire boss/elite reward with a checkpoint ahead. Player must opt in; no effect on pickup. Barriers do not stack, potion is not refunded, and party switching preserves remaining charges and the expedition-wide temporary healing restriction.

<a id="rel-36"></a>
### REL-36 — Fortune-Eater's Idol

**Legendary · High · Reclassified existing identity.** Once per expedition at a supporting-item reward, pay a displayed fixed gold price to take a second option. Price equals that rarity's ordinary merchant item price, without discount; both items still obey capacity replacement rules. **Decision:** spend accumulated economy to accelerate a build rather than gamble on damage rolls. All classes; pair with Wayfinder's Compass to seek item rewards. **Source:** boss/merchant commitment reward with item offers ahead. No natural-20 gold, refunds, sale profit, or extra relic/kit picks. If insufficient gold or only one option remains, the action is unavailable. Cannot duplicate one chosen option.

## Reserve relics

<a id="rel-37"></a>
### REL-37 — Bell of the Unspent Blow

**Reserve · Rare · Medium.** Substitute for Titanblood Torc. If a charged direct Special misses all enemies, bank half its resource cost rounded down, maximum one, for 3s. Landing a Basic on an enemy refunds the bank once; 8s internal cooldown. **Decision:** recover actively from a commitment error. Fits Greatsword and delayed direct attacks; not traps, summons, or canceled casts. Pair with Balanced Pommel. **Source:** martial elites/bosses. A miss never becomes profitable; refund plus other sources stays below original cost. No bank from deliberate attacks outside an encounter.

<a id="rel-38"></a>
### REL-38 — Prism of Contrary Elements

**Reserve · Legendary · High.** Substitute for Crown of the First Flame only if enough dual-element builds exist. Direct kit damage of two different elements against the same enemy within 3s creates one modest arcane secondary burst, once per 6s. **Decision:** sequence damage types. Item/relic sparks cannot supply either element. Fits explicit mixed-element kits such as Furnace physical/fire; baseline Mage is arcane-only in runtime and does not qualify. Pair with War Scholar's Codex. **Source:** arcane bosses. No resistance bypass, status conversion, or chaining from the arcane burst. Catalogue compatibility is intentionally narrow; do not advertise universal use.

<a id="rel-39"></a>
### REL-39 — Vow of the Empty Hand

**Reserve · Rare · Medium.** Substitute for Unwritten Equation. If one supporting-item slot is deliberately left empty at encounter start, the first successfully paid Special refunds one resource after a hit. Once per encounter; more empty slots grant nothing. **Decision:** sacrifice passive variety for a reliable opening. All classes with a qualifying spender; empowered/commanded hits count once. Pair with Keen Edge Oil. **Source:** elite/merchant commitment reward. Lock the qualification at encounter start; dropping and re-equipping items cannot rearm it. Total refunds remain capped at cost, and no benefit from unfilled relic slots.

<a id="rel-40"></a>
### REL-40 — Map of Folded Roads

**Reserve · Rare · High.** Substitute for Moon Dial. Once per floor after clearing two ordinary rooms, open a return shortcut between their existing safe doorways. Traversal is out of combat only and does not reset room state. **Decision:** revisit a merchant or cache without granting combat escape. All classes; pair with Wayfinder's Compass. **Source:** exploration elite rewards on compatible floors. Never connect across a mandatory locked gate, story barrier, boss boundary, or unloaded floor. Requires level-generation validation; if no legal connection exists, preview unavailability rather than inventing a shortcut.

<a id="rel-41"></a>
### REL-41 — Ashen Undertaker

**Reserve · Legendary · High.** Alternative to Phoenix, mutually exclusive. Once per expedition at a safe checkpoint, sacrifice one equipped supporting item to arm a lethal save for the next encounter only. Save leaves 20% health, clears dots, and grants 1s grace; charge expires after the encounter, used or not. **Decision:** pay known build strength for a stronger, narrowly timed insurance policy. All classes. Pair with Mender's Sachet only within healing caps; the save's health restoration is its explicit exception. **Source:** boss commitment event. No activation after lethal damage, no item refund, no second save through swapping the relic.

<a id="rel-42"></a>
### REL-42 — Covenant of Small Things

**Reserve · Rare · High.** Substitute for Root of Eternity. Once per encounter, protecting a damageable owned companion with a kit barrier causes its next commanded enemy hit within 3s to restore 3% of the owner's max health. **Decision:** invest defense in the partner before asking it to attack. Fits golem/vine or other explicit pet-barrier kits; not moths or invulnerable decoys. Pair with Clay Seal, which does not itself fulfill the kit-barrier trigger. **Source:** companion elites/bosses. Shared healing cap applies; no proc from resummoning, ambient attacks, or sacrificing the companion.

<a id="rel-43"></a>
### REL-43 — The Honest Scale

**Reserve · Uncommon · Medium.** Substitute for Gilded Beetle if reservation UI costs too much. Once per floor, decline an entire supporting-item reward to receive fixed gold equal to half the ordinary common-item price, independent of rolled rarities. **Decision:** take certainty toward a purchase instead of a poor fit. All classes; pair with Wayfinder's Compass. **Source:** merchant/elite pool with future purchases available. Never pays per unchosen option, never works on story rewards, and cannot activate after Lucky Coin's reroll has already claimed an item. Relic-generated gold does not trigger other economy effects.

<a id="rel-44"></a>
### REL-44 — Cartographer's Debt

**Reserve · Rare · High.** Substitute for Watcher's Lantern. Once per floor reveal all ordinary room reward categories, then hide exact ordinary gold pickup values until the floor ends; final settlement remains accurate. **Decision:** trade immediate economic precision for route planning. All classes; pair with Scavenger's Token. **Source:** exploration elites on branching floors. No concealment of purchase prices, wager costs, health, or mandatory objectives. This tradeoff may be too weak to justify a slot; flag for user review rather than secretly adding a punitive tax. Does not reveal secret-room locations.

<a id="rel-45"></a>
### REL-45 — Lantern of the Last Camp

**Reserve · Rare · High.** Substitute for Salt Oath. Once per expedition at a safe checkpoint, surrender the next ordinary gold reward to restore one already-used potion charge, never exceeding the expedition's starting provision count. **Decision:** give up future earnings for finite recovery. All classes; pair with Healer's Brooch. **Source:** early merchant/elite reward with a gold encounter ahead. No activation if no potion was consumed; never creates saleable inventory. Mark the foregone reward immediately and persist it across switches, defeat, and replacing the relic. Potion restoration itself triggers no potion-use effects.

<a id="rel-46"></a>
### REL-46 — Red Ledger

**Reserve · Legendary · High.** Substitute for Fortune-Eater. Once per expedition, borrow one displayed supporting item from a merchant without immediate payment; the next ordinary gold rewards repay its full displayed price plus 25% before becoming spendable. **Decision:** gain strength now at a clear debt. All classes; pair with Merchant's Balance only after borrowing is recorded. **Source:** early merchant commitment. No borrowing relics, kits, or multiple items, no resale of the borrowed item, and no debt erased by discarding it. Outstanding debt settles only from expedition proceeds, not an unannounced charge to the Hearth bank.

<a id="rel-47"></a>
### REL-47 — Stillwater Contract

**Reserve · Rare · Medium.** Substitute for Heartwood Crown. At encounter start, optionally commit to using no Movement ability for the first 5s; ordinary walking is allowed. Complete the interval while landing two Basics to gain a 15%-health barrier for 3s. Using Movement breaks the contract without punishment or reward. **Decision:** delay an escape tool for a finite payoff. All classes; pair with Ironroot Ring. **Source:** defense/merchant commitment pool. Never disable the button, reward idle waiting, or accumulate multiple barriers. Boss telegraphs should remain reasons to break the contract immediately.

<a id="rel-48"></a>
### REL-48 — Chorus of the Departed

**Reserve · Legendary · High.** Substitute for Standard of Succession. Once per encounter, a legal party switch records the outgoing adventurer's last direct Basic. The incoming adventurer's next Basic within 2s sends a 25%-damage copy from the outgoing location, excluding all statuses and secondary effects. Solo fallback: the first Movement followed by Basic records and replays the owner's preceding Basic instead. **Decision:** plan a handoff angle or a solo reposition. Fits direct-Basic kits; command-only Basics are incompatible. Pair with Echo Prism only under a one-echo-per-activation rule, choosing the stronger. **Source:** support/arcane bosses. No phantom character, resurrection, or offscreen proc engine.
