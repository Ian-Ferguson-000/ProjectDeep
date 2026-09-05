# Eros Demo — Roguelike Game Loop End State

## Demo Promise

The demo is a persistent, single-player roster roguelike built around the Hearth tavern. Adventurers are individual people rather than reusable classes: they gain levels, gear, traits, and history, and death removes them permanently. Progress survives through the tavern, recruited merchants, banked resources, unlocked classes, item rarity, research, and knowledge of hidden paths.

## First-Run Tutorial

1. **Start Game** opens in the tavern with Mara Vell warning Alden about the Forest and permanent death in a portrait dialogue.
2. Alden is a preset 3 HP Warrior with the Steady trait, Sword and Shield, and forced **Slasher** mode; class and mode selection are bypassed.
3. The first Forest floor teaches one successful action at a time: WASD movement, left-click attack, right-click dash, Space special, Shift + left-click defend, Q potion, slot 1 consumable, room-reward collection, and M character/journal menu.
4. Tutorial progress is saved. A death before the M step restarts Alden on floor one without loot or a memorial record; afterward ordinary permadeath applies.
5. Extraction and Endless choices are disabled while Alden automatically continues through the normal eight-floor Forest campaign.
6. Death and boss-victory epilogues converge on the same mechanical state: 120 gold, 8 Supplies, the former keeper's letter, a statless outcome keepsake, and exactly two deterministic candidates (Warrior Brina and Mage Eamon) with basic weapons.
7. A victorious Alden retires. A permanently slain Alden is memorialized. On the victory path only, Mara returns once after the next non-tutorial Forest victory for a narrative confrontation.

## Campaign Loop

The repeatable loop is:

`Calendar arrival → recruit in the static Tavern → choose party and equipment → expedition to boss or defeat → settle → advance one day → retire victors → next candidate wave`

- The Forest permits two characters. Clearing it raises the cap to four for later dungeons.
- A dead character is removed immediately. Survivors may continue shorthanded.
- Intermediate floor and room clears autosave and continue automatically. Only boss victory or total-party defeat resolves an expedition.
- Victory banks carried gold, relic essence, and relics before every surviving participant retires. Defeat loses unbanked rewards and records deaths.
- The Hearth begins with six rooms and gains two per Roster Services rank. Each new day brings `clamp(2 + rank, 2, 7)` free deterministic candidates; recruitment, departure, dismissal, victory, death, and retirement are recorded in the calendar.
- The calendar uses seven weekdays, four 28-day seasons, and 112-day years. The first post-tutorial day is Monday, Spring 1, Year 1.
- Three selectable campaign slots each maintain an independent versioned autosave and backup committed atomically at safe campaign transitions. Continue shows populated slots; New Game selects an empty slot or confirms before overwriting one.

## Party Control

### Strategy

Every member owns health, position, resources, gear, effects, initiative, and progression. Initiative selects the only recruit that can act; Tab inspects other player initiative cards without changing control. After combat, Tab may change the free-roam leader. A casualty is removed from the active party and initiative without moving survivors.

### Slasher

Every member owns health, cooldowns, resources, temporary effects, and class progression. Only the controlled recruit appears on the map; the remaining party is safely benched while real-time timers continue. Tab swaps the next living recruit into the same position. Summoned creatures remain active across swaps, and controlled-character death passes control to the next survivor automatically.

## Classes and Unlocks

| Class | Unlock |
| --- | --- |
| Warrior | Available initially |
| Mage | Available initially |
| Tank | Clear Verdant Forest in Strategy mode |
| Rogue | Clear Verdant Forest in Slasher mode |
| Healer | Clear Ashen Farmstead |
| Summoner | Clear Stone Crypt |

Clearing the Forest in both modes is required to unlock both Tank and Rogue. Character levels and equipment die with their owner; no class-wide mastery survives.

## Dungeon Campaign

| Dungeon | Type | Unlock | Merchant / Reward |
| --- | --- | --- | --- |
| Verdant Forest | Regular | Initial | Thistle Fen; Forest clue; larger parties; Tank/Rogue by mode |
| Ashen Farmstead | Regular | Clear Forest | Orin Cinder; Healer; Grove clue |
| Stone Crypt | Regular | Clear Forest | Sister Caldris; Summoner; Archive clue |
| Sunken Mine | Regular | Clear Farmstead or Crypt | Neris Vale; mineral and armor stock |
| Ember Foundry | Regular | Clear Farmstead and Crypt | Veyra Coil; weapon and high-rarity stock; Archive clue |
| Moonlit Grove | Secret | Forest + Farmstead clues and Secret Research I | Unique nature and fate relics |
| Abyssal Archive | Secret | Crypt + Foundry clues and Secret Research I | Unique arcane and void relics |

All seven dungeon definitions declare runtime, supported modes, party cap, extent, unlock rule, merchant, and clue/reward data. Every dungeon routes explicitly in both modes and automatically advances after non-final clears; field doors remain navigation choices.

## Tavern Progression

- **Banked gold:** ordinary supplies, equipment, and upgrade costs.
- **Relic essence:** permanent-upgrade currency banked after boss victory.
- **Successful levels:** lifetime total of levels brought home on victorious characters; used as a non-spendable upgrade requirement.
- **Merchant Favor:** existing merchant-specific rank and exclusive-stock progression.
- **Upgrade branches:** roster services, starting supplies, item rarity, merchant stock, relic capacity, secret research, and replacement quality.
- **Memorial:** immutable records of name, class, level, cause, expeditions, and victories for every dead recruit.
- **Hall of Heroes:** dated, statless records of every participant who survives a victorious expedition and retires.

## State Contracts

`CharacterRecord` owns stable character identity, class, level/XP, health, gear, inventory, trait, Slasher choices, status, and history.

`ExpeditionState` owns its id, party IDs, per-member runtime snapshots, dungeon/mode, depth, provisional rewards, casualties, legacy extraction fields, and tutorial status.

`CampaignState` owns tutorial phase, calendar/date history, tavern phase, candidate waves, roster, Memorial, Hall of Heroes, unlocks, completed dungeon modes, banked progression, clue flags, tavern upgrades, idempotent launch/settlement IDs, active expedition, and save serialization.

Existing `RunState` remains a compatibility façade for combat code and mirrors the currently controlled `CharacterRecord` until every combat resolver accepts an explicit character ID.

## Delivery Status

- [x] Typed campaign, character, and expedition foundations.
- [x] Dynamic room capacity, deterministic saved candidate waves, free recruitment/dismissal, Hall of Heroes, memorial, and permadeath resolution.
- [x] Atomic versioned autosave and recovery fallback.
- [x] Three-slot save selection with Continue/New Game routing, slot summaries, overwrite confirmation, independent backups, and legacy single-save import into Slot 1.
- [x] Preset-Alden first-run routing, sequential Slasher controls, saved retry rules, eight-floor resolution, portrait dialogue, and mechanically equivalent endings.
- [x] Data-driven seven-dungeon graph, six merchants, class unlocks, clues, and party caps.
- [x] Party assembly selector, multi-recruit Strategy initiative/tokens, and mode-specific party control.
- [x] Refined dungeon party control: Slasher uses one on-map recruit with persistent Tab/LB bench swapping and health-ring portraits, while Strategy control follows initiative and preserves independent occupied positions across turns.
- [x] Boss-bound expeditions with automatic floor continuation and provisional rewards banked only on victory.
- [x] Full simultaneous Strategy tokens and per-character initiative entries.
- [x] Persistent Slasher bench swapping with one recruit actor, independent runtime state, surviving summons, automatic death handoff, and party health-ring HUD.
- [x] Bespoke Mine, Foundry, Grove, Archive, and Crypt Slasher environments and encounters.
- [x] Static point-and-click Tavern with clickable candidates/NPCs, a focusable toolbar, staggered arrivals, recruitment dialogue, Calendar, and a five-tab Company Ledger including Hall of Heroes.
- [x] Wide expedition planner with grouped destination cards, explicit selected/available/locked states, unlock guidance, separate mode and party decisions, concise destination briefing, numbered party slots, and a live readiness/launch summary.
- [x] Four generated recruit portrait variants per class, shown in party selection and the Company Ledger.
- [x] New-player ledger guidance, resource explanations, affordability/tooltips, and signal-safe deferred refresh after purchases.
- [x] Bespoke Sunken Mine Strategy runtime with mine room graphs, flooded/cave-in machinery hazards, encounter progression, and Drowned Engine boss chamber.
- [x] Bespoke Sunken Mine Slasher environment with deep-water slowdown, ore-machinery damage zones, Mine encounter tables, Drowned Foreman routing, and Neris Vale trading.
- [x] Bespoke Ember Foundry Strategy and Slasher routing with conveyor/forge hazards, molten damage lanes, construct encounter tables, Last Warmachine routing, and Veyra Coil trading.
- [x] Moonlit Grove and Abyssal Archive clue/research unlocks, merchant-free Strategy/Slasher runtimes, bespoke encounter themes, and persistent one-time unique relic rewards.
- [x] Dedicated Stone Crypt Slasher routing with necrotic slow zones, Crypt encounter tables, curse-tinted presentation, and Crypt boss routing.
- [x] Final automated campaign acceptance: exact class/dungeon/merchant counts, portrait coverage, partial casualty, retirement/candidate settlement, upgrade purchase, all unlock paths, four secret relics, and save migration/round-trip.
- [x] Release-readiness controls remove extraction and abandonment while retaining party cycling, potion use, visible references, keyboard focus, scroll-safe options, audio, mute, and reduced-shake contracts.
- [x] Windows export preset, clean editor resource graph, successful release PCK export, packaged PCK boot, and rendered 1280×720 / 150% Options inspection.
- [ ] Final hands-on balance/audio/accessibility playtest on the target PC build.

The unchecked work is required before declaring the content-complete demo shippable; the checked foundation keeps current Forest, Farmstead, Crypt, class, merchant, and combat work playable during that production.

The current machine can produce and boot `build/ErosDemo.pck`. Creating the companion `ErosDemo.exe` additionally requires the Godot 4.7.2 Windows export templates (`windows_release_x86_64.exe`), which are not installed on this host.
