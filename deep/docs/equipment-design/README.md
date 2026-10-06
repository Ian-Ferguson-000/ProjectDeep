# Equipment design proposal

**Status: unapproved design candidates.** Prepared October 5, 2026. This packet proposes a release catalogue for Eros; it does not authorize implementation. Numbers in new designs are illustrative playtest starting points, not measured balance. Standard-kit values are observations of base tuning, before progression, equipment, and input modifiers.

**Prototype exception, October 6:** The user separately authorized the armory testing ground and all five alternate Mage prototypes (KIT-MAG-02 through KIT-MAG-06). Stormcaller's Folio is now **Stormbringer's Grimoire**, with unconditional chaining and conductor-supported damage retention. See the [testing-ground guide](../TestingGround.md) and [Mage builds](../MageBuilds.md) for current mechanics and tuning. The user subsequently authorized all five Warrior alternatives (KIT-WAR-02 through KIT-WAR-06), including six combos for each Warrior kit. See [Warrior builds](../WarriorBuilds.md) and [Warrior combos](../WarriorCombos.md). Other class candidates and release acquisition rules remain unapproved. Original numerical examples for unimplemented candidates are not release targets.

## Pacing and readability requirements for prototypes

The game targets high power and fast combat. Each future kit must be compared against its class's current standard kit at entry level and with progressed builds, using the same stats, items, target setup, and input mode. Check sustained damage, burst payoff, downtime, mobility, and resource access. A setup kit must still have a strong repeatable action without its ideal setup or a rare item; setup should earn an additional payoff. If a kit trades single-target damage for area coverage or support, quantify that benefit and verify solo encounter pace rather than silently accepting lower damage.

Use subsecond action cycles where the current class's combat rhythm calls for them. Longer cooldowns need a specific powerful payoff, with active actions available between uses. Preserve numerical progression where applicable while keeping standard-kit mechanics out of alternate kits. The Pyromancer prototype now has a 0.18 s Basic, 0.9 s Special, and 0.65 s Movement before progression and item modifiers; these illustrate the intended pace, not mandatory timings for every class.

Every field, trap, stance, and delayed strike needs a visible activation, recognizable active state, and clear ending or impact. Distinguish prepared ground from damaging ground. Use animated effects and motion as well as accurate boundaries; a faint line or circle alone is insufficient feedback. Keep enemies, damage types, and targeting boundaries readable through stacked effects. Testing must report actual post-mitigation damage with type labels, including secondary damage, and clear the measurements on reset.

## Reading and deciding

Start here, compare the six class catalogues, then use the [review workbook](review-workbook.md) to mark Keep, Revise, or Reject. No recommendation is pre-approved. Reserve entries are substitutes, not additional launch commitments.

| Document | Purpose |
|---|---|
| [Warrior](warrior.md) | Momentum, commitment, spacing, and counterplay |
| [Mage](mage.md) | Arcane baseline, fire setup, frost control, and lightning routing |
| [Healer](healer.md) | Damage-capable support through wounds, wards, and recovery timing |
| [Tank](tank.md) | Mitigation, interception, terrain, and pressure conversion |
| [Rogue](rogue.md) | Assassination, dueling, toxins, and prepared ground |
| [Summoner](summoner.md) | Companion commands, formations, constructs, and flocks |
| [Supporting items](supporting-items.md) | 48 recommended and 12 reserve tactical modifiers |
| [Relics](relics.md) | 36 recommended and 12 reserve changes to gameplay rules |
| [Existing-content audit](existing-content-audit.md) | Disposition of expedition loot and Hearth equipment |
| [Review workbook](review-workbook.md) | Linked decisions, totals, and acceptance scenarios |

## Why these categories

**Gear answers “how do I fight?”** One class-bound weapon, tome, staff, or paired equipment package defines all four action slots. A sword-and-shield package is one kit, not two independently swappable ability pieces. Every class retains its current kit. Alternate kits change at least two of positioning, targeting, action timing, resource flow, defense, or battlefield preparation. They are sidegrades, not higher-tier versions of the same damage profile.

**Items answer “which tactic should I emphasize?”** An item rewards a repeatable behavior: placing a field well, protecting a summon, timing a counter, or moving between attacks. Small numerical benefits are allowed when attached to an interesting condition. Items do not supply missing fundamentals needed to make a kit playable.

**Relics answer “which rule can I bend?”** Examples include buying a second reward at a cost, storing a wound for later, echoing a deliberately aimed action, or changing who receives a ward. Relics may favor classes, but their identity is the rule, not a bundle of stats. A named book can be an item rather than gear; category is determined by behavior and made explicit in reward UI.

Armor, potions, patronage, and character progression remain adjacent systems. This proposal does not expand their catalogues or count them toward the content target. Existing armor remains baseline persistent equipment; proposed supporting items occupy a separate expedition inventory. Persistent accessory effects that overlap the new inventory require explicit later migration decisions; see the audit.

## Current baseline and source of truth

The [development reference](../DevelopmentReference.md) routes tutorial and expeditions into real-time Slasher scenes. [Player runtime](../../scripts/slasher/slasher_player.gd) dispatches Basic, Special, Defensive, and Movement primarily by class. [Slasher tuning](../../data/slasher_balance.json) supplies cooldowns, ranges, and Warrior/Mage combos. This is the basis for the six standard entries, not the tile ranges in older documents.

The [class catalogue](../../data/classes.json) provides six class identities and resource names. Some written rules diverge from runtime: Mage resource gain is connected to projectile hits without a distance check in the callback; its Fireball is passed an arcane damage type; Tank Retribution resolves on the triggering hit rather than on a later turn; Summoner marking grants resource before the wolf lands a hit. The standard entries report these differences rather than silently fixing them.

All six standard Movement actions cost **1 class resource in the action dispatcher**, even where Slasher tuning says zero; explicit combos can override that cost. Current capacity is 3 and passive regeneration defaults to 0.35 resource/second. These runtime rules apply to every standard-kit table. Short listed cooldowns are raw tuning, not guaranteed sustained execution rates: animation locks, held-input behavior, resources, and progression also matter. The proposed zero-cost movement on alternate kits below is an intentional design difference to review, not a claim about today's game.

[Expedition item identities](../../data/items.json) contain 52 entries. [Legacy effects](../../data/item_effects.json) often use turns, dice, and tiles; [Slasher effects](../../data/slasher_item_effects.json) contain 15 explicit real-time overrides. An identity appearing in the catalogue does not establish that every written legacy effect operates in Slasher. The audit separates theme preservation from mechanical preservation.

[Hearth catalogue data](../../data/hearth_campaign.json) contains 24 weapons, 12 armor entries, 16 accessory aliases, and 12 named relics. Several relics alias the same effect. [Hearth armory](../../scripts/game/hearth_armory.gd) currently restricts equipment changes to available adventurers at home. In-run kit swapping is therefore a proposed new capability. The audit maps all 64 Hearth entries, including families and aliases, without counting them twice as new content.

The early [gear notes](../GearCharacter.md) describe a three-kit Fighter demo. [Combat stats](../CombatStatsAndItems.md) describes a d20/turn pipeline. Preserve both as historical material; neither governs these real-time candidates. Existing Warrior and Mage combos belong to their standard kits. Alternate kits use the sequences described here; they do not automatically inherit combos merely because their action slots have the same names. Progression bonuses that name an old action need a later compatibility review.

## Reference lessons and release budget

Hades separates alternate weapon forms, boons, and weapon upgrades. Supergiant's patch notes also document eligibility restrictions and changes preventing secondary effects from applying additional boons. The useful lesson is layered identity plus controlled interactions; this packet borrows that structure, not its content or an asserted total number of weapons. [Source: Supergiant, Superstar Update](https://www.supergiantgames.com/blog/hades-superstar-update-patch-notes/).

Mega Crit's press kit lists four characters with unique card sets, 300+ cards, and 100+ items. Those categories are not equivalent to four-button kits. The transferable lesson is strong class vocabulary with enough shared rewards to permit varied builds. [Source: Slay the Spire press kit](https://www.megacrit.com/press-kits/slay-the-spire/).

Magicraft's official store description lists 100 staffs, 80 relics, and nine starting sets alongside combinable spells. Modular spell composition can multiply variety without authoring a complete moveset per combination. Eros should borrow readable interaction and discovery, while avoiding that system's full combinatorial production burden. [Source: Magicraft store page](https://store.steampowered.com/app/2103140/Magicraft/).

These are source-specific advertised figures and historical examples, not a verified census of every current patch. **The following budget is a design judgment, not evidence that a particular count guarantees franchise-level quality.**

| Category | Recommended launch | Reserve | Reason |
|---|---:|---:|---|
| Complete kits | 24: 4 per class | 12: 2 per class | A familiar baseline plus three clearly different alternatives |
| Supporting items | 48: 36 class-focused + 12 shared | 12 | Six tactical hooks per class plus broadly usable connective effects |
| Relics | 36 | 12 | Six families of six rules; sufficient breadth without making useful matches vanishingly rare |
| Total identities | 108 | 36 | 144 reviewable candidates, not 144 promised launch assets |

Launch kits imply 96 described ability slots, with 24 standard slots already represented in combat. Shared animations may reduce work but do not eliminate targeting, AI, VFX, accessibility, and interaction costs. Reserve kits add another 48 slots if promoted. Four coherent kits per class are preferable to six near-identical reskins. Do not add an entry merely to fill a quota; if a candidate fails the distinctness review, replace it from reserve or explicitly reduce the target.

A class sees its six focused items, the 12 shared items, and compatible cross-class candidates—not an undifferentiated pool of 48. A typical multi-floor expedition should expose 6–9 item choices, 2–4 relic choices, and 1–2 optional kit discoveries. Short expeditions compress this to roughly two item offers, one relic offer, and at most one kit offer. These are pacing targets to map onto actual dungeon lengths later, not promises of extra rooms. Offer three choices, take one, and aim for a recognizable build by the midpoint. No run should require filling every slot.

Use encounter count as well as floors when applying that target. Current dungeon data lists Forest at eight floors, Crypt and Archive at seven, Hell/Mine/Foundry at six, Grove at five, and Farmstead as one floor with 10–12 rooms. Farmstead therefore should not receive only a short tutorial's rewards merely because its floor count is one. A paper pacing proposal follows; all offers replace or occupy existing reward opportunities, not automatically add extra fights.

| Route shape | Proposed item / relic / kit offers | Placement intent |
|---|---|---|
| Five to eight combat floors | 6–9 / 2–4 / 1–2 | First item on the first floor; one kit opportunity before midpoint; relics at spaced elite/boss milestones |
| Farmstead's 10–12 rooms | 4 / 2 / 1 | Items roughly every 2–3 completed rooms; relics at elite and completion; kit before the final third |
| Early extraction or genuinely short excursion | About 2 / 1 / 0–1 | Enough to demonstrate an interaction, not fill inventory |
| Endless continuation | At most one item offer per new floor and one relic choice per cycle | Replacement decisions and new combinations, never uncapped passive accumulation or repeated expedition saves |

The first playtest should compare three versus four launch kits per class and measure offer usefulness before expanding toward six. Promotion of a reserve kit must also promote or retarget its required *supporting pool*, but no kit is allowed to require those items to function.

## Proposed acquisition and persistence

- **Starting kits:** Every recruited class has its bound standard kit. Recover alternatives intact and return successfully to add physical instances to the Hearth armory. Discovery records the identity for inspection; discovery alone does not create unlimited copies. Choose an owned, class-compatible kit before departure.
- **In-run kits:** Eligible elite caches and boss rewards may offer complete kits. Give at least one usable choice for the active class when an offer is specifically a kit reward. Other party-member gear can appear as clearly labeled salvage. Allow one carried spare per expedition; choosing another requires leaving or salvaging one. Successful extraction returns carried gear under existing ownership/loss rules. Defeat and world-reset policies remain campaign policies, not an accidental permanent unlock.
- **Safe swaps:** Permit only in a cleared room with no active hostile projectiles, unresolved wounds, or damaging owned fields. Preview all four abilities and item compatibility. Swapping clears summons, marks, stored attacks, and kit-local counters without triggering death or removal rewards. Preserve health fraction, shared item/relic uses, and resource fraction rounded down. Set each action cooldown to the greater of its remaining old cooldown and the incoming kit's full cooldown. Swapping never heals or refreshes an encounter charge.
- **Supporting items:** Six active expedition slots per controlled adventurer. Equip or replace at reward pickup or a safe checkpoint; no general combat inventory swapping. Effects are personal, expire at expedition end, and do not become Hearth accessories. Replaced items are surrendered, not stored for cycling. One copy of an identity; no rank-up by duplicates in v1.
- **Relics:** Four expedition-wide slots. Personal effects apply to the currently controlled adventurer unless the entry explicitly names a summon or another party member. The relic instance owns charges, cooldowns, and counters across switches. Replaced relics cannot be reacquired to reset uses. No duplicate identity, including differently named legacy aliases.
- **Rarity:** Common teaches one obvious condition; Uncommon rewards a sequence; Rare reshapes a build; Legendary carries an expedition-defining commitment. Very Rare may be merged into Rare for new offers, with old data handled only in a later migration. Kits use unlock/source difficulty rather than stronger rarity tiers. Reserve is editorial status, never in-game rarity.
- **Duplicates:** Exclude owned active identities from offers. If a small eligible pool is exhausted, offer a modest salvage choice instead of an unusable duplicate; tune value later. A recovered physical duplicate kit can equip another adventurer, subject to armory ownership. Salvage cannot reroll the same offer indefinitely.
- **Rewards:** First filter by actual capability (projectile, summon, ward, field, healing, reflection), then weight for the active class. In a three-item offer, reserve one slot for a current-kit match, one for a broadly usable or compatible cross-class effect, and one for discovery. The discovery slot must still function with the current kit or be explicitly labeled for a carried alternative. Never present three dormant effects as a combat reward. Kit swap previews flag dormant items; allow one free replacement of a newly dormant item at the next checkpoint, consuming an ordinary reward opportunity rather than generating extra loot.

## Shared design language and interaction rules

**Timing and distances.** New kits use seconds and relative distances. Close = approximately 100 px, medium = 240 px, long = 400 px at current world scale. CD means cooldown, starting after a successful activation; a held/channel action starts CD on release. Failed targeting spends no resource. Ranges are maximums, never permission to cross walls. Base tuning snapshots use actual pixels. New Basics cost zero; new Specials cost 2 class resource unless stated; new Defensive/Movement actions cost zero. Preserve the class's current resource capacity and passive regeneration for a first prototype. Listed gains are additional event gains, capped at one award per activation unless stated. Standard kits retain their current exceptions.

**Damage language.** Light, normal, heavy describe relative contribution within that kit; no cross-class equality is implied. New kits require later normalized damage tuning. Heavy attacks must leave a telegraphed commitment or recovery window. New statuses specify duration or refer to the following definitions: Burn/Poison deal modest damage over 4 seconds, refresh rather than add potency, and do not generate resource or item hit procs; Slow is 25% for 2 seconds; Stagger interrupts ordinary foes for 0.3 seconds. A stronger entry-specific value takes precedence. Marks from different sources remain distinct.

**Secondary effects.** Echoes, reflected shots, item bursts, dots, thorns, and relic damage never trigger another item/relic damage effect, resource gain, echo, or reflection. Direct kit-authored summon attacks can qualify where explicitly stated, once per command/activation across the entire group. Trigger limits belong to the originating action, not each projectile. Shared limits survive kit and party changes. Reflected enemy attacks become player-owned secondary damage and retain boss durability rules.

For sequencing, a delayed kit-authored trap hit or Retribution release is attributed to its originating Special when the hit resolves; an empowered projectile attributes its one spend-dependent payoff to the empowering Special. Neither the setup press nor later dot ticks grant a second completion. This attribution does not make a field/summon eligible for a relic that explicitly excludes echoing it. Successful timed defense includes deliberate evasion and interception of an ordinary hostile projectile; simply standing behind passive cover, canceling deferred wounds, or enjoying a movement action's invulnerability does not count as a Defensive-slot success. A multi-shot screen supplies at most one defense event per activation.

**Survival.** New barriers are temporary absorption, do not stack additively, and cannot exceed 20% of the recipient's maximum health unless explicitly specified. Keep the largest remaining barrier and refresh only its stated duration. New damage reduction sources combine multiplicatively, capped at 80%; explicit single-hit parries and finite movement/evasion invulnerability are avoidance, not stacking reduction, and retain their identities. New healing from items/relics is capped at a shared 15% maximum health per recipient per encounter; kit healing is separate but must require an enemy interaction, finite resource, or nonrenewable wound. Standard Healer's resource-funded, renewable dash heal is documented, not silently redesigned; its out-of-combat sustain is an explicit later balance decision.

**Encounters and party ownership.** An encounter is a room's first hostile engagement through its authored completion. Leaving, switching, reopening the menu, and farming spawned enemies do not create new encounters. Items belong to adventurers; relics belong to the expedition. “Ally” means an eligible living deployed party member or owned summon named by the effect, never an unseen roster member. If only one adventurer is deployed, recipient-based support defaults to self where specified. No automatic healing of benched characters; cross-member effects explicitly name the next controlled adventurer. Paused effects cannot charge offscreen. Existing-party feasibility must be checked before implementation.

**Bosses.** No proposed execute kills a boss outright; health-threshold bonuses are ordinary damage. Hard displacement and taunt do not redirect a boss's scripted attacks. Where control is central, replace denied control with a capped, nonstacking 10% damage vulnerability for 2 seconds from that kit. Preserve current hit caps and shields; evaluate multi-hit actions as one activation for proc budgets. No relic disables phase transitions, immunity, dungeon objectives, or mandatory gates.

## Approval boundary

All roster entries, acquisition rules, limits, and numerical examples above are recommendations. Your workbook decisions select content; they do not authorize code changes. Following approval, a separate implementation plan must address progression compatibility, effects ownership, save migration, UI, assets, automated expeditions, and playtests. No new API or runtime schema is introduced by these documents.
