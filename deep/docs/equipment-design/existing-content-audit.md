# Existing-content audit

[Overview](README.md) · [Review workbook](review-workbook.md)

**Documentation-only disposition, not a migration specification.** Every current identity receives a recommendation below. “Revise” preserves a name/theme, not exact behavior; “Reclassify” moves it into the new conceptual category. Nothing is deleted or changed in game data. Existing saves require a separate approved migration later.

## Expedition loot: 52 identities

Sources: [identities](../../data/items.json), [legacy rules](../../data/item_effects.json), [Slasher overrides](../../data/slasher_item_effects.json), and [conversion logic](../../scripts/game/game_balance.gd). “Explicit” means a Slasher record exists, not that every sentence is verified in play. “Converted” means no explicit record and the loader derives stat conversions; legacy trigger text is not proof of a running real-time mechanic. The current runtime still needs a separate execution audit before migration.

| Existing ID / name | Current legacy intent; Slasher record | Disposition | Destination and rationale |
|---|---|---|---|
| `soldiers_buckle` — Soldier's Buckle | When a defensive reaction triggers, gain 1 Threshold for that attack. **Explicit.** | Revise | [ITM-TAN-01](supporting-items.md#itm-tan-01) — Make defense preserve position rather than add passive mitigation. |
| `embershard_focus` — Embershard Focus | Fire attacks gain +1 Range and +1 Spell Potency. **Explicit.** | Revise | [ITM-MAG-01](supporting-items.md#itm-mag-01) — Tie fire identity to actual Burn and remove short-lived stat rental. |
| `keen_edge_oil` — Keen Edge Oil | Your first attack each combat gains +2 Penetration and +1 Attack Power. **Explicit.** | Revise | [ITM-SHR-01](supporting-items.md#itm-shr-01) — Give every class a Basic-to-Special opener. |
| `healers_brooch` — Healer's Brooch | Drinking a potion also clears Slow and restores 1 class resource. **Explicit.** | Revise | [ITM-HEA-01](supporting-items.md#itm-hea-01) — Preserve potion utility with a bounded cleanse reward. |
| `quickstep_charm` — Quickstep Charm | After using a movement ability, gain +2 Evasion until your next turn. **Explicit.** | Revise | [ITM-SHR-02](supporting-items.md#itm-shr-02) — Reward retreat geometry, not unconditional speed. |
| `amulet_of_vigor` — Amulet of Vigor | Below half health, gain another +2 Threshold. **Converted.** | Revise | [ITM-SHR-03](supporting-items.md#itm-shr-03) — Turn low-health safety into one readable recovery opportunity. |
| `duelist_gloves` — Duelist Gloves | Against an isolated enemy, gain +2 Accuracy and +1 Penetration. **Converted.** | Revise | [ITM-ROG-01](supporting-items.md#itm-rog-01) — Preserve isolation through a reach follow-up instead of dice stats. |
| `wand_of_cinders` — Wand of Cinders | Spell attacks that can hit multiple tiles gain +1 Range. **Explicit.** | Retire / merge | [ITM-MAG-01](supporting-items.md#itm-mag-01) — Too close to Embershard and Flameheart; remove separate cadence-stat identity. |
| `lucky_coin` — Lucky Coin | Once per turn, an attack that misses by 2 or less gains +2 Accuracy. **Converted.** | Reclassify | [REL-25](relics.md#rel-25) — Probability becomes a finite reward reroll in deterministic real-time play. |
| `scholars_lens` — Scholar's Lens | After an attack is stopped by Threshold or Aegis, gain +1 Penetration for the next attack. **Converted.** | Revise | [ITM-SHR-04](supporting-items.md#itm-shr-04) — Make resistance knowledge useful without an XP tax on builds. |
| `giant_bane_grip` — Giant-Bane Grip | Against elite and boss enemies, gain +3 Penetration. **Explicit.** | Revise | [ITM-WAR-04](supporting-items.md#itm-war-04) — Require a heavy-strike follow-up rather than always-on boss damage. |
| `moonleaf_cloak` — Moonleaf Cloak | While Hidden or before your first attack, gain +2 Armor Class. **Converted.** | Revise | [ITM-ROG-02](supporting-items.md#itm-rog-02) — Preserve Hidden identity; separate it from invulnerability. |
| `aether_prism` — Aether Prism | Arcane attacks gain +1 Range and ignore 1 additional Aegis. **Converted.** | Revise | [ITM-MAG-05](supporting-items.md#itm-mag-05) — Introduce a piercing-versus-concentration decision. |
| `boots_of_the_hare` — Boots of the Hare | While adjacent to two or more enemies, gain +2 Evasion. **Converted.** | Revise | [ITM-SHR-05](supporting-items.md#itm-shr-05) — Offer crowded-escape precision rather than passive evasion. |
| `sunward_periapt` — Sunward Periapt | Healing at full health grants 2 temporary Aegis against all damage. **Converted.** | Revise | [ITM-HEA-03](supporting-items.md#itm-hea-03) — Keep overheal conversion but cap it to one encounter use. |
| `flameheart_talisman` — Flameheart Talisman | Fire attacks made within 2 tiles gain +2 Spell Potency and +1 Penetration. **Explicit.** | Revise | [ITM-MAG-02](supporting-items.md#itm-mag-02) — Support close fire positioning instead of generic area inflation. |
| `kingsroad_aegis` — Kingsroad Aegis | The first damaging hit each combat gains 3 Aegis against its damage type. **Converted.** | Revise | [ITM-SHR-06](supporting-items.md#itm-shr-06) — Preserve opening safety through status protection. |
| `starfallen_sigil` — Starfallen Sigil | On a natural 20, restore 1 class resource. **Explicit.** | Reclassify | [REL-01](relics.md#rel-01) — Make the real-time echo a visible bounded rule. |
| `heartwood_crown` — Heartwood Crown | If you have not moved this turn, gain +3 Armor Class and +2 Threshold. **Explicit.** | Reclassify | [REL-13](relics.md#rel-13) — Commit to a location rather than grant idle floor-entry healing. |
| `ironroot_ring` — Ironroot Ring | Reduce forced movement by 1 tile and gain +1 physical Aegis. **Converted.** | Revise | [ITM-TAN-02](supporting-items.md#itm-tan-02) — Retain anti-displacement theme with a stance requirement. |
| `sparkwire_wrap` — Sparkwire Wrap | Your first hit each round deals 2 additional lightning damage. **Converted.** | Revise | [ITM-SHR-07](supporting-items.md#itm-shr-07) — Translate turn opener into a real-time two-action sequence. |
| `menders_sachet` — Mender's Sachet | The first time you fall below half health each combat, heal 3. **Converted.** | Revise | [ITM-SHR-08](supporting-items.md#itm-shr-08) — Recovery requires returning to a finite spatial pickup. |
| `windknotted_thread` — Windknotted Thread | With no adjacent enemies, gain +1 movement and +1 Evasion. **Converted.** | Revise | [ITM-SHR-09](supporting-items.md#itm-shr-09) — Spacing prepares one farther-reaching action. |
| `chalk_rune_tablet` — Chalk Rune Tablet | Your first spell each floor gains +3 Penetration. **Converted.** | Revise | [ITM-MAG-06](supporting-items.md#itm-mag-06) — Make preparation visible rather than first-spell penetration. |
| `scavengers_token` — Scavenger's Token | Clearing a floor grants 3 additional gold for each unopened chest or cache. **Converted.** | Reclassify | [REL-26](relics.md#rel-26) — Reveal optional value instead of rewarding unopened caches. |
| `drillmasters_whistle` — Drillmaster's Whistle | A triggered defensive reaction grants 2 bonus XP and 1 class resource. **Converted.** | Revise | [ITM-SHR-10](supporting-items.md#itm-shr-10) — Replace farmable XP/resource with a capped spend refund. |
| `brambleguard_clasp` — Brambleguard Clasp | When a melee defensive reaction triggers, deal 1 physical damage to the attacker. **Converted.** | Revise | [ITM-TAN-03](supporting-items.md#itm-tan-03) — Require an aimed answer instead of passive repeated thorns. |
| `stormglass_bead` — Stormglass Bead | After moving, lightning attacks gain +1 Range and +2 Spell Potency. **Converted.** | Revise | [ITM-MAG-04](supporting-items.md#itm-mag-04) — Make moving improve circuit routing, not generic spell power. |
| `cutpurses_favor` — Cutpurse's Favor | Defeating an enemy while at full health grants 2 additional gold. **Converted.** | Reclassify | [REL-27](relics.md#rel-27) — Convert clean play into a gold-versus-choice tradeoff. |
| `redstep_spurs` — Redstep Spurs | After moving at least 2 tiles, gain +2 Attack Power on the next martial attack. **Converted.** | Revise | [ITM-WAR-02](supporting-items.md#itm-war-02) — Reward committed movement with attack handling. |
| `apothecarys_cup` — Apothecary's Cup | Potions cannot overheal; unused healing becomes temporary Aegis, up to 3. **Converted.** | Revise | [ITM-SHR-11](supporting-items.md#itm-shr-11) — Keep potion overflow but prevent overlap and repeated conversion. |
| `veterans_whetstone` — Veteran's Whetstone | Consecutive attacks against the same target gain +1 Accuracy and +1 Penetration. **Converted.** | Revise | [ITM-WAR-03](supporting-items.md#itm-war-03) — Preserve target commitment with a bounded follow-up window. |
| `wayfinders_compass` — Wayfinder's Compass | Movement abilities gain +1 Range; landing unengaged restores 1 class resource. **Converted.** | Reclassify | [REL-28](relics.md#rel-28) — Give route information instead of mobility/resource inflation. |
| `runebound_bracer` — Runebound Bracer | After a defensive reaction triggers, your next martial attack gains +2 Accuracy. **Converted.** | Revise | [ITM-WAR-01](supporting-items.md#itm-war-01) — A successful defense changes the answer's geometry. |
| `glass_magus_eye` — Glass Magus Eye | Spell attacks gain Penetration equal to half their Range bonus. **Converted.** | Reserve / revise | [ITM-RES-03](supporting-items.md#itm-res-03) — Retain a precision alternative; do not launch a second similar prism. |
| `pilgrims_greaves` — Pilgrim's Greaves | After moving at least 2 tiles, gain +2 Threshold until your next turn. **Converted.** | Revise | [ITM-HEA-04](supporting-items.md#itm-hea-04) — Actual healing prepares a reposition, not generic movement armor. |
| `gilded_beetle` — Gilded Beetle | Gold pickups of 10 or more restore 1 class resource. **Converted.** | Reclassify | [REL-29](relics.md#rel-29) — Change purchase timing rather than multiply pickup income. |
| `saints_phial` — Saint's Phial | After drinking a potion, gain 2 Aegis against the next damage type received. **Converted.** | Revise | [ITM-HEA-02](supporting-items.md#itm-hea-02) — Recovery preserves position without duplicating potion barriers. |
| `war_scholars_codex` — War Scholar's Codex | After first hitting an enemy, gain +1 Attack Power and Spell Potency against that enemy. **Converted.** | Revise | [ITM-SHR-12](supporting-items.md#itm-shr-12) — Reward action sequencing rather than XP and stat growth. |
| `blackoak_ward` — Blackoak Ward | Physical damage stopped by Threshold restores 1 class resource. **Converted.** | Reclassify / rename | [REL-15](relics.md#rel-15) — Blackoak Covenant makes a defensive opening a deliberate bargain. |
| `phoenix_ash_reliquary` — Phoenix-Ash Reliquary | Once per floor, lethal damage leaves you at 1 health and ignites adjacent enemies. **Explicit.** | Reclassify | [REL-19](relics.md#rel-19) — One expedition save, not a renewable save every floor. |
| `wyvernscale_mantle` — Wyvernscale Mantle | When poison damage is fully absorbed, gain +2 Attack Power next turn. **Converted.** | Reserve / revise | [ITM-RES-08](supporting-items.md#itm-res-08) — Keep a situational cleanse-counter option outside the core roster. |
| `chronomancers_pin` — Chronomancer's Pin | Once per combat, reroll a missed attack and keep the new result. **Explicit.** | Reclassify | [REL-02](relics.md#rel-02) — Time manipulation rewards alternation rather than passive shaving or dice rerolls. |
| `deepdelvers_lantern` — Deepdelver's Lantern | Against undiscovered enemy types, gain +2 Accuracy and +2 Armor Class. **Converted.** | Reclassify | [REL-30](relics.md#rel-30) — Offer previewed optional difficulty for reward choice. |
| `titanblood_torc` — Titanblood Torc | Below half health, gain +3 Attack Power but lose 1 Evasion. **Converted.** | Reclassify | [REL-06](relics.md#rel-06) — Low-health crossing grants one opportunity with resource downtime. |
| `crown_of_the_first_flame` — Crown of the First Flame | Fire attacks convert half of prevented damage into bonus damage on the next spell. **Explicit.** | Reclassify | [REL-04](relics.md#rel-04) — Fire consumption changes delayed payoff instead of bypassing resistance. |
| `worldbreaker_gauntlet` — Worldbreaker Gauntlet | Martial hits reduce the target's Threshold by 1 for the rest of combat. **Explicit.** | Reclassify | [REL-05](relics.md#rel-05) — One bounded fracture replaces permanent stacking shred. |
| `fortune_eaters_idol` — Fortune-Eater's Idol | Natural 20s grant 3 gold; natural 1s consume 3 gold to reroll when possible. **Converted.** | Reclassify | [REL-36](relics.md#rel-36) — Spend gold for a second choice; remove dice-income feedback. |
| `charred_horseshoe` — Charred Horseshoe | After crossing a Field-room doorway, gain +1 Evasion until your next turn. **Converted.** | Retire / merge | [ITM-SHR-02](supporting-items.md#itm-shr-02) — Doorway evasion overlaps mobility items and encourages room cycling. |
| `harvesters_gloves` — Harvester's Gloves | Against an enemy standing beside a destructible prop, gain +2 Accuracy. **Converted.** | Reserve / revise | [ITM-RES-10](supporting-items.md#itm-res-10) — Prop interaction is too environment-dependent for guaranteed launch utility. |
| `cinderheart_locket` — Cinderheart Locket | Below half health, gain 2 fire Aegis and restore 1 additional health from consumables. **Converted.** | Reclassify | [REL-35](relics.md#rel-35) — Trade one potion and temporary kit healing for offensive barriers. |
| `aegis_of_the_last_king` — Aegis of the Last King | A triggered reaction doubles Aegis against that attack and heals 2 afterward. **Explicit.** | Reclassify | [REL-12](relics.md#rel-12) — Create paired-hit protection distinct from Phoenix's lethal save. |

No old expedition effect is proposed for unexamined mechanical retention. The new recommended pool includes revised old identities, not a second parallel copy. Wand of Cinders and Charred Horseshoe are merged; Glass Magus Eye, Wyvernscale Mantle, and Harvester's Gloves remain reserve choices.

## Hearth weapons: 24 identities

Current weapon entries carry class, damage/block, price, and source data. [HearthCatalog](../../scripts/game/hearth_catalog.gd) creates GearData, but the current [player action dispatcher](../../scripts/slasher/slasher_player.gd) primarily chooses actions by class. Mapping below is a proposed kit identity, not a claim that the old weapon already implements it. Old tier price or damage advantages should not silently become alternate-kit superiority.

| Existing ID / name | Proposed kit | Recommendation |
|---|---|---|
| `sword_shield` — Sword and Shield | [KIT-WAR-01](warrior.md#kit-war-01) | Retain current class abilities as standard; review display-name polish. |
| `spear_shield` — Spear and Shield | [KIT-WAR-03](warrior.md#kit-war-03) | Revise into tip spacing and planted lanes. |
| `greatsword` — Greatsword | [KIT-WAR-02](warrior.md#kit-war-02) | Revise into committed charged melee. |
| `dawn_bastion` — Dawn Bastion | [KIT-WAR-04](warrior.md#kit-war-04) | Rework/rename as Banner; avoid a stronger copy of Sword and Shield. |
| `magic_missile_shield` — Missile Focus | [KIT-MAG-01](mage.md#kit-mag-01) | Rename identity to standard spellbook; preserve current class abilities. |
| `fireball_fire_shield` — Fireball and Fire Shield | [KIT-MAG-02](mage.md#kit-mag-02) | Rework as Tome of the Pyromancer; use true fire rules and preparation. |
| `lightning_flash_step` — Lightning Bolt and Flash Step | [KIT-MAG-04](mage.md#kit-mag-04) | Rework as conductor-based Stormbringer. |
| `astral_covenant` — Astral Covenant | [KIT-MAG-06](mage.md#kit-mag-06) | Reserve identity for Mirrorbound; launch Winterglass instead as a new kit. |
| `sunwood_staff` — Sunwood Staff | [KIT-HEA-01](healer.md#kit-hea-01) | Retain standard class abilities. |
| `pilgrim_staff` — Pilgrim Staff | [KIT-HEA-04](healer.md#kit-hea-04) | Revise into movement and note convergence. |
| `mercy_branch` — Mercy Branch | [KIT-HEA-03](healer.md#kit-hea-03) | Revise into enemy-mark consumption and healing. |
| `solstice_crook` — Solstice Crook | [KIT-HEA-05](healer.md#kit-hea-05) | Reserve the phase kit; launch new Censer instead. |
| `tower_shield` — Tower Shield and Mace | [KIT-TAN-01](tank.md#kit-tan-01) | Retain standard class abilities. |
| `iron_porter` — Iron Porter | [KIT-TAN-02](tank.md#kit-tan-02) | Revise into deployable cover. |
| `oathwall` — Oathwall | [KIT-TAN-04](tank.md#kit-tan-04) | Revise into challenge and interception. |
| `citadel_heart` — Citadel Heart | [KIT-TAN-05](tank.md#kit-tan-05) | Reserve stone zones; launch new Furnace Plate instead. |
| `spectral_dagger` — Spectral Dagger | [KIT-ROG-01](rogue.md#kit-rog-01) | Retain standard class abilities. |
| `fox_teeth` — Fox Teeth | [KIT-ROG-02](rogue.md#kit-rog-02) | Revise into visible reads and feints. |
| `moon_stiletto` — Moon Stiletto | [KIT-ROG-05](rogue.md#kit-rog-05) | Reserve marked teleport; launch new Viper instead. |
| `last_whisper` — Last Whisper | [KIT-ROG-06](rogue.md#kit-rog-06) | Reserve reload kit; launch new Trapper instead. |
| `bond_staff` — Bondkeeper Staff | [KIT-SUM-01](summoner.md#kit-sum-01) | Retain standard class abilities and document wolf exceptions. |
| `pack_call` — Pack Call | [KIT-SUM-02](summoner.md#kit-sum-02) | Revise into two-hound formation. |
| `wild_covenant` — Wild Covenant | [KIT-SUM-05](summoner.md#kit-sum-05) | Reserve vine companion; launch new Mason instead. |
| `ancient_bond` — Ancient Bond | [KIT-SUM-06](summoner.md#kit-sum-06) | Reserve posture companion; launch new Moth Choir instead. |

Reserve placement is not permission to strip owned weapons from existing saves. Once the roster is approved, choose a documented replacement, compensation, or legacy compatibility policy. Kit names and design IDs here are editorial identifiers, not proposed runtime IDs.

## Hearth armor: 12 entries retained outside the new counts

| Existing ID / name | Disposition |
|---|---|
| `light_armor_0` — Trail Vest | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `light_armor_1` — Trail Mail | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `light_armor_2` — Trail Harness | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `light_armor_3` — Trail Regalia | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `medium_armor_0` — Warden Vest | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `medium_armor_1` — Warden Mail | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `medium_armor_2` — Warden Harness | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `medium_armor_3` — Warden Regalia | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `heavy_armor_0` — Bulwark Vest | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `heavy_armor_1` — Bulwark Mail | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `heavy_armor_2` — Bulwark Harness | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |
| `heavy_armor_3` — Bulwark Regalia | Retain as persistent baseline armor; no ability replacement, extra set bonus, or new catalogue count. |

Armor tier/stat balance is outside this proposal. In a later implementation, verify that total armor plus kit protection does not erase kit weaknesses. This is a compatibility review, not an additional armor redesign.

## Hearth accessory aliases: 16 entries

These are persistent today. Do not keep their old effects underneath the new supporting-item/relic version: that would double-count power and defeat expedition progression. Recommended future direction is to retire the permanent effect alias and compensate its owned value at migration, while preserving cosmetic collection history. Exact compensation needs separate approval; no conversion is performed here.

| Existing ID / name | New destination | Proposed disposition |
|---|---|---|
| `hearth_soldiers_buckle` — Soldier's Buckle | [ITM-TAN-01](supporting-items.md#itm-tan-01) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_healers_brooch` — Healer's Brooch | [ITM-HEA-01](supporting-items.md#itm-hea-01) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_quickstep_charm` — Quickstep Charm | [ITM-SHR-02](supporting-items.md#itm-shr-02) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_wand_of_cinders` — Wand of Cinders | [ITM-MAG-01](supporting-items.md#itm-mag-01) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_giant_bane_grip` — Giant-Bane Grip | [ITM-WAR-04](supporting-items.md#itm-war-04) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_flameheart_talisman` — Flameheart Talisman | [ITM-MAG-02](supporting-items.md#itm-mag-02) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_starfallen_sigil` — Starfallen Sigil | [REL-01](relics.md#rel-01) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_heartwood_crown` — Heartwood Crown | [REL-13](relics.md#rel-13) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_chronomancers_pin` — Chronomancer's Pin | [REL-02](relics.md#rel-02) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_worldbreaker_gauntlet` — Worldbreaker Gauntlet | [REL-05](relics.md#rel-05) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_amulet_of_vigor` — Amulet of Vigor | [ITM-SHR-03](supporting-items.md#itm-shr-03) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_menders_sachet` — Mender's Sachet | [ITM-SHR-08](supporting-items.md#itm-shr-08) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_keen_edge_oil` — Keen Edge Oil | [ITM-SHR-01](supporting-items.md#itm-shr-01) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_embershard_focus` — Embershard Focus | [ITM-MAG-01](supporting-items.md#itm-mag-01) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_phoenix_ash_reliquary` — Phoenix-Ash Reliquary | [REL-19](relics.md#rel-19) | Retire persistent mechanical alias; use the expedition design only after approved migration. |
| `hearth_aegis_of_the_last_king` — Aegis of the Last King | [REL-12](relics.md#rel-12) | Retire persistent mechanical alias; use the expedition design only after approved migration. |

## Hearth relics: 12 identities, mostly shared effect aliases today

Each becomes its own explicit expedition rule. Ownership, tier, and name do not establish unique existing mechanics: the `effect_id` links below show the current reuse. Cinder Heart is deliberately merged into Cinderheart Locket rather than shipping two confusingly named relics.

| Existing ID / name | Current effect alias | Destination | Proposed disposition |
|---|---|---|---|
| `briar_seed` — Briar Seed | `heartwood_crown` | [REL-14](relics.md#rel-14) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `watchers_lantern` — Watcher’s Lantern | `starfallen_sigil` | [REL-31](relics.md#rel-31) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `pilgrim_bell` — Pilgrim Bell | `phoenix_ash_reliquary` | [REL-18](relics.md#rel-18) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `cinder_heart` — Cinder Heart | `heartwood_crown` | [REL-35](relics.md#rel-35) | Retire / merge name and persistent alias into one locket identity. |
| `moon_dial` — Moon Dial | `starfallen_sigil` | [REL-17](relics.md#rel-17) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `wardens_seal` — Warden’s Seal | `phoenix_ash_reliquary` | [REL-16](relics.md#rel-16) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `tide_pearl` — Tide Pearl | `heartwood_crown` | [REL-20](relics.md#rel-20) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `echo_prism` — Echo Prism | `starfallen_sigil` | [REL-09](relics.md#rel-09) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `hunters_star` — Hunter’s Star | `phoenix_ash_reliquary` | [REL-11](relics.md#rel-11) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `nature_relic` — Root of Eternity | `heartwood_crown` | [REL-23](relics.md#rel-23) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `arcane_relic` — Unwritten Equation | `starfallen_sigil` | [REL-08](relics.md#rel-08) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |
| `fate_relic` — Thread of Tomorrow | `phoenix_ash_reliquary` | [REL-34](relics.md#rel-34) | Reclassify as expedition relic; replace shared alias with the proposed unique rule after approval. |

## Coverage and later migration boundary

- Audited 52 expedition identities and 64 Hearth entries: 24 weapons, 12 armor, 16 accessories, 12 relics.
- Count destinations by design ID, never by old alias. An item becoming a relic consumes one relic slot in the release roster, not both an item and relic identity.
- Consumables, patronage boons, class progression, and cosmetic assets are neighboring systems, not additional entries in this audit. Do not remove or rewrite them.
- Later migration must resolve owned reserve weapons, permanent accessories, duplicate aliases, active expeditions, and world-reset loss rules. The design selection does not silently authorize any of those save changes.
- Later progression review must map old action-specific upgrades and standard-kit combos to compatible kits or replace the upgrade offer; a fire-looking but arcane-coded standard Fireball is a concrete compatibility case.
- Automated expeditions must receive separately reviewed kit/item summaries and risk values; do not assume four manually controlled actions have meaningful AI equivalents.
