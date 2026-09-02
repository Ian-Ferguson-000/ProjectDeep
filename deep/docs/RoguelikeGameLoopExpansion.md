# Eros Demo — Roguelike Game Loop End State

## Demo Promise

The demo is a persistent, single-player roster roguelike built around the Hearth tavern. Adventurers are individual people rather than reusable classes: they gain levels, gear, traits, and history, and death removes them permanently. Progress survives through the tavern, recruited merchants, banked resources, unlocked classes, item rarity, research, and knowledge of hidden paths.

## First-Run Tutorial

1. **Start Game** opens in the tavern with Mara Vell explaining that nearby dungeons must be cleared by an adventurer.
2. Select a **Warrior** or **Mage** starter.
3. Select **Strategy** or **Slasher** mode.
4. Enter the Verdant Forest immediately. The opening encounter teaches the selected mode.
5. The starter enters the normal Forest campaign with maximum and current health capped at **3 HP**. There is no ward, forced damage, timer, or authored death: the Forest's ordinary encounters create the danger and teach that survival is fragile.
6. On the starter's natural death, Mara mourns the adventurer, introduces the memorial and permadeath rules, and the tutorial ends. If an exceptional player clears the Forest at 3 HP, the tutorial also completes and Mara recognizes the survival so campaign progression cannot become stuck.
7. Six recruits are generated from the currently unlocked class pool.

## Campaign Loop

The repeatable loop is:

`Tavern → dungeon and mode → party and equipment → expedition → clear encounter → continue or extract → bank rewards → replace casualties → upgrade tavern`

- The Forest permits two characters. Clearing it raises the cap to four for later dungeons.
- A dead character is removed immediately. Survivors may continue shorthanded.
- Extraction is available only from a cleared floor or room.
- Victory and extraction bank carried gold, relic essence, and relics. Full defeat loses unbanked rewards.
- Abandoning during combat forfeits carried rewards but returns living characters.
- The roster returns to six after an expedition resolves. Replacements receive a deterministic name, portrait variant, unlocked class, and one balanced tradeoff trait.
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

All seven dungeon definitions declare runtime, supported modes, party cap, extent, unlock rule, merchant, clue/reward data, and extraction checkpoint. Every dungeon now routes explicitly in both modes; shared combat foundations are themed by dedicated Crypt, Mine, Foundry, Grove, and Archive runtime scripts.

## Tavern Progression

- **Banked gold:** ordinary supplies, equipment, and upgrade costs.
- **Relic essence:** extracted permanent-upgrade currency.
- **Successful levels:** lifetime total of levels brought home on victorious characters; used as a non-spendable upgrade requirement.
- **Merchant Favor:** existing merchant-specific rank and exclusive-stock progression.
- **Upgrade branches:** roster services, starting supplies, item rarity, merchant stock, relic capacity, secret research, and replacement quality.
- **Memorial:** immutable records of name, class, level, cause, expeditions, and victories for every dead recruit.

## State Contracts

`CharacterRecord` owns stable character identity, class, level/XP, health, gear, inventory, trait, Slasher choices, status, and history.

`ExpeditionState` owns party IDs, per-member runtime snapshots, dungeon/mode, depth, provisional rewards, casualties, extraction eligibility, and tutorial status.

`CampaignState` owns tutorial phase, roster, memorial, unlocks, completed dungeon modes, banked progression, clue flags, tavern upgrades, replacement sequence, active expedition, and save serialization.

Existing `RunState` remains a compatibility façade for combat code and mirrors the currently controlled `CharacterRecord` until every combat resolver accepts an explicit character ID.

## Delivery Status

- [x] Typed campaign, character, and expedition foundations.
- [x] Six-person roster, traits, memorial, permadeath, and replacement resolution.
- [x] Atomic versioned autosave and recovery fallback.
- [x] Three-slot save selection with Continue/New Game routing, slot summaries, overwrite confirmation, independent backups, and legacy single-save import into Slot 1.
- [x] First-run tavern/class/mode routing with a natural-difficulty 3 HP Forest tutorial.
- [x] Data-driven seven-dungeon graph, six merchants, class unlocks, clues, and party caps.
- [x] Party assembly selector, multi-recruit Strategy initiative/tokens, and mode-specific party control.
- [x] Refined dungeon party control: Slasher uses one on-map recruit with persistent Tab/LB bench swapping and health-ring portraits, while Strategy control follows initiative and preserves independent occupied positions across turns.
- [x] Extraction and provisional reward contracts.
- [x] Full simultaneous Strategy tokens and per-character initiative entries.
- [x] Persistent Slasher bench swapping with one recruit actor, independent runtime state, surviving summons, automatic death handoff, and party health-ring HUD.
- [x] Bespoke Mine, Foundry, Grove, Archive, and Crypt Slasher environments and encounters.
- [x] Wide, tabbed Company Ledger with distinct Resources, Party Builder, Improvements, and Memorial workspaces; dungeon-aware party caps, numbered party slots, clear/auto-fill controls, recruit role summaries, and rebuilt unclipped upgrade cards.
- [x] Wide expedition planner with grouped destination cards, explicit selected/available/locked states, unlock guidance, separate mode and party decisions, concise destination briefing, numbered party slots, and a live readiness/launch summary.
- [x] Four generated recruit portrait variants per class, shown in party selection and the Company Ledger.
- [x] New-player ledger guidance, resource explanations, affordability/tooltips, and signal-safe deferred refresh after purchases.
- [x] Bespoke Sunken Mine Strategy runtime with mine room graphs, flooded/cave-in machinery hazards, encounter progression, and Drowned Engine boss chamber.
- [x] Bespoke Sunken Mine Slasher environment with deep-water slowdown, ore-machinery damage zones, Mine encounter tables, Drowned Foreman routing, and Neris Vale trading.
- [x] Bespoke Ember Foundry Strategy and Slasher routing with conveyor/forge hazards, molten damage lanes, construct encounter tables, Last Warmachine routing, and Veyra Coil trading.
- [x] Moonlit Grove and Abyssal Archive clue/research unlocks, merchant-free Strategy/Slasher runtimes, bespoke encounter themes, and persistent one-time unique relic rewards.
- [x] Dedicated Stone Crypt Slasher routing with necrotic slow zones, Crypt encounter tables, curse-tinted presentation, and Crypt boss routing.
- [x] Final automated campaign acceptance: exact class/dungeon/merchant counts, portrait coverage, partial casualty, extraction, upgrade purchase, all unlock paths, four secret relics, save migration/round-trip, full regression suite, editor compile, and project boot.
- [x] Release-readiness controls pass: keyboard/controller bindings for party cycling, extraction, potion use, and abandonment; visible control reference; initial keyboard focus; scroll-safe options at 150% UI scale; audio bus, mute, and reduced-shake settings contracts.
- [x] Windows export preset, clean editor resource graph, successful release PCK export, packaged PCK boot, and rendered 1280×720 / 150% Options inspection.
- [ ] Final hands-on balance/audio/accessibility playtest on the target PC build.

The unchecked work is required before declaring the content-complete demo shippable; the checked foundation keeps current Forest, Farmstead, Crypt, class, merchant, and combat work playable during that production.

The current machine can produce and boot `build/ErosDemo.pck`. Creating the companion `ErosDemo.exe` additionally requires the Godot 4.7.2 Windows export templates (`windows_release_x86_64.exe`), which are not installed on this host.
