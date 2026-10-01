# Narrative Adaptation Roadmap

## Purpose

This document compares the active Godot project with the target story and sequences the work needed to adapt it. Implementation is now active; completed phases are marked below and the remaining gates continue to define the order of work.

## Current narrative audit

### What exists and should be reused

| Existing asset/system | Current behavior | Narrative value |
|---|---|---|
| Tutorial branch in `scripts/main.gd` and `CampaignState` | Alden enters the Briarway and can die or win | Strong foundation for the Last Customer and divergent consequences |
| Forest, Crypt, and Balor's Hell runtimes | Three separate dungeons with a defined progression | Nearly matches the intended first route; needs story framing and eventually safe connected-expedition flow |
| Data-driven dungeon catalog | Names, descriptions, unlocks, routes, clues, unique rewards | Natural place for territory, prison, doctrine, pressure, and story metadata after schema design |
| Curated adventurers in `data/adventurers.json` | Twenty-four authored people across six active classes | Excellent base for nation, faith, relationship, and loop-aware character arcs |
| Tavern conversations | JSON nodes, routes, conditions, effects, substitutions | Useful seed for a general story-event system, though current condition vocabulary is narrow |
| Candidate knowledge and appraisal | Biography/origin/preference can be discovered | Supports the Keeper fantasy and remembered relationship knowledge |
| Calendar and event history | Time advances; arrivals, deaths, retirements, and descendants are logged | Foundation for geopolitical events, crisis clocks, pressure recovery, and collapse reports |
| Memorial, Hall of Heroes, retirement, descendants | Named careers persist in campaign history | Supports human cost, recurring families, and loop echoes |
| Reputation | One 0–100 value improves candidate quality | Can become public Hearth renown while separate faction/deity standing is added |
| Clues and secret dungeons | Boolean discoveries unlock Moonlit Grove and Abyssal Archive | Foundation for structured lore, covenant fragments, and contradictory histories |
| Versioned saves and migration | Campaign state is serialized with migration tests | Essential for safely adding story/loop state |
| Hearth economy, facilities, merchants, loadouts | Detailed management and provisioning loop | Direct expression of “the person who makes heroes possible” |

### What conflicts with the target

| Current story | Target direction | Required treatment |
|---|---|---|
| The pitch casts the player as an adventurer | The player is the Keeper sponsoring adventurers | Rewrite high concept and player-facing onboarding after narrative state is ready |
| Mara Vell is the speaking bartender; ownership transfers after tutorial victory | The player must remain the Keeper across both outcomes | Redefine Mara before rewriting tutorial scenes |
| Victory means Mara vanished and the company receives the deed | Victory proves the Keeper's model and relieves immediate debt | Replace ownership branch while keeping resource/outcome divergence |
| Death and ordinary victory return to the same persistent campaign | Only destruction of the Hearth resets the timeline | Separate expedition permadeath from world-loop reset |
| Forest is a complete tutorial campaign; connected dungeon continuation is disabled | Forest -> Crypt -> Balor is the first full route | Reintroduce connection only after checkpoint, settlement, and UX design are tested |
| Progress is a mostly linear unlock graph | Multiple unstable dungeons compete for attention | Add pressure/recovery and political availability without deleting readable progression |
| Classes unlock from dungeon clears | Nations have affinities; identity is not class-locked | Keep class progression but add independent origin and faith fields |
| “Favor” in runtime logs is effectively merchant/dungeon reward terminology | Divine Favor is a relationship with individual gods | Rename ambiguous existing uses and implement deity standing as a separate model |
| Generic origins are local regions only | Six nations shape culture and conflict | Migrate origins into structured nation/region identity while retaining prose hometowns |
| No world-failure sequence or loop state | Loop Zero collapse reveals the campaign premise | Add crisis and meta-progression state in later phases, not as an early cutscene-only patch |
| No Adragor route | Zarabian desert/toxic route is the intended second showcase | Scope new content or explicitly approve a repurpose; do not imply it already exists |

### Missing narrative capabilities

- authored story-event registry with trigger priority, once-per-loop/once-ever policies, and save-safe completion IDs;
- nation, region, faith, deity, doctrine, and relationship data;
- separate Hearth renown, faction standing, divine favor, and interpersonal affinity;
- dungeon pressure, suppression, recovery, outbreak, claims, and alternate resolution state;
- world crisis clock and map consequences;
- loop number, persistent Keeper Memory, reset manifests, and loop-aware dialogue conditions;
- expedition Contribution distinct from banked loot;
- formal codex/lore discovery records rather than only booleans;
- content validation for references, duplicate IDs, unreachable story nodes, and missing localization keys.

## Target narrative state model

The exact schema belongs in implementation design, but story work should assume these ownership boundaries:

| Owner | State |
|---|---|
| Character | nation, home region, class, faith/deity, personality, ideology, relationships, personal flags, loop sensitivity |
| Expedition | sponsor investment, declared patron/claim, objective, Contribution, discoveries, casualties, prisoner resolution |
| Dungeon | territory, approach chain, prisoner, pressure, suppression, resources, stability, leak, outbreak state, competing doctrines |
| Hearth campaign | calendar, inventory, facilities, roster, renown, faction standings, divine favor, crisis state, sanctuary rules |
| Keeper meta-state | loop number, memory unlocks, true lore, remembered people, sanctuary-bound relics, ending requirements |
| Story engine | event IDs, trigger conditions, priority, repeat policy, selected variants, completion/effect history |

Nationality, class, faith, faction allegiance, and relationship are never aliases for one another.

## Data/content layout recommendation

Do not expand `campaign_state.gd` with large blocks of authored prose. Move content toward validated data files:

```text
data/story/
  campaign_arcs.json
  story_events.json
  codex_entries.json
  nations.json
  pantheons.json
  deities.json
  doctrines.json
  relationships.json
  dungeon_lore.json
  world_events.json
```

Existing `adventurers.json`, `dungeons.json`, and `tavern_conversations.json` can reference these stable IDs. Narrative services should resolve triggers and effects; UI should only render the returned beat.

## Phased course

### Phase 0 — Approve canon and scope

**Status: resolved in project canon.** The current implementation choices and writer-only answers are recorded in `NarrativeVision.md`, `CoreCastBriefs.md`, `NationAndCultureGuide.md`, and `CosmologySecret.md`.

**Goal:** remove decisions that would cause expensive rework.

Approve or revise:

1. player is the Keeper from the first frame and remains so in both Alden outcomes;
2. Mara's role is that of tavern aid who managed the front desk and supports the Keeper;
3. final/working status of all six nation names and their inspiration boundaries;
4. active class roster versus future Ranger/Druid/Paladin/Phantom scope;
5. inevitable versus avoidable Loop Zero collapse;
6. new-build versus repurpose decision for Adragor;
7. true cosmology at writer-only level, even if players learn it slowly;
8. final victory conditions and acceptable ending families.

**Deliverables:** approved vision revision, one-page brief per nation, Keeper/Mara/Alden cast briefs, cosmology secret sheet, naming and cultural-reference guide.

**Exit gate:** no `TBD` affecting tutorial ownership, character schema, or first two dungeon routes.

### Phase 1 — Narrative foundation without changing play flow

**Status: implemented and regression-tested.**

**Goal:** make story content data-driven and save-safe before rewriting the campaign.

- Define schemas and validators for nations, faiths, gods, dungeons, beats, and codex discoveries.
- Add stable story event IDs, repeat policies, conditions, and effects.
- Extend save migration with empty/default narrative state.
- Split public renown from faction standing and divine favor.
- Add structured identity fields to character records while preserving legacy prose origins.
- Rename existing ambiguous “favor” logs if they do not represent gods.

**Exit gate:** old saves load; current campaign plays unchanged; data validation and round-trip save tests pass.

### Phase 2 — Retell the opening and first company

**Status: implemented and regression-tested.**

**Goal:** make the first 30–60 minutes express the new premise.

- Rewrite start/high-concept UI around the Keeper.
- Stage the Empty Hearth and Alden's arrival.
- Add a small, explicit sponsorship loadout: weapon, armor, food, potion, optional utility.
- Reframe Forest, Crypt, and Balor as approach, threshold, and prison.
- Preserve Alden win/death, but converge on the Keeper founding the expedition business.
- Recast Brina and Eamon as Nordian/Zarabian arrivals with conflicting dungeon doctrines.
- Remove or replace the current deed transfer and former-keeper threat unless Mara's approved role supports them.

**Exit gate:** both Alden outcomes reach the same player identity with meaningfully different state; save/load works at every scene; a new player can state that they are the Keeper and why they sponsor expeditions.

### Phase 3 — First route continuity and Contribution

**Status: implemented and regression-tested.**

**Goal:** make the tutorial route and failure economy match the fiction.

- Design checkpoints and extraction across Forest -> Crypt -> Balor.
- Restore connected expedition flow only after automated tests cover death, save/load, party state, rewards, and settlement exactly once.
- Add Contribution and dungeon intelligence on partial/failing runs.
- Give Crypt Lord/Necromancer an explicit gatekeeper role.
- Make first Balor suppression change dungeon pressure rather than permanently erasing Balor.

**Exit gate:** death at each route segment produces correct material loss, Contribution, memorial, and dialogue; completing the chain cannot double-award progression.

### Phase 4 — Nations, identity, and party friction

**Status: implemented and regression-tested.** Six-nation identities, cross-national faiths, internal dissent, compatibility causes, relationship repair, authored milestone arrivals, loop-aware return dialogue, and roster presentation are live.

**Goal:** turn roster composition into a social as well as tactical decision.

- Apply approved nation and faith identities to curated characters.
- Write internal dissenters and cross-national worshippers.
- Add relationship/compatibility rules with legible causes and repair paths.
- Introduce nations sequentially through authored arrivals.
- Expand conversation conditions to nation, faith, loop, relationship, dungeon, and world state.

**Exit gate:** mixed parties produce visible benefits/conflicts without deterministic ethnic hostility; class remains independent of nationality; content review confirms each nation contains meaningful internal variety.

### Phase 5 — Dungeon ecology and the second route

**Status: implemented and regression-tested.** Pressure, resources, stability, recovery, outbreaks, risk, and reward changes are live. The playable Cinderway connects Farmstead, Mine, and Foundry as Adragor's leak, conduit, and keystone without misrepresenting them as desert assets. Suppress, rebind, evidence, and covenant objectives produce distinct ecological and political outcomes.

**Goal:** replace the static unlock ladder with a comprehensible strategic landscape.

- Implement pressure, resources, stability, recovery, and outbreak forecasts.
- Add political claims and doctrine-specific objectives.
- Build the approved Adragor route or its explicitly approved alternative.
- Assign narrative roles to Farmstead, Mine, Foundry, Grove, and Archive.
- Let clear outcomes include suppress, bind, negotiate, recover evidence, or release where appropriate.

**Exit gate:** ignoring and farming a dungeon have different visible consequences; at least two doctrines offer mechanically and narratively distinct resolutions.

### Phase 6 — Pantheons and divine bargains

**Status: implemented and regression-tested.** Twelve fictional gods across six traditions have values, requests, rivalries, favor, optional expedition patronage, boons, and recorded obligations. Unpatroned expeditions remain fully viable.

**Goal:** make gods competing characters rather than skill trees.

- Introduce a small initial set of deeply authored gods before filling all pantheons.
- Give each values, requests, boon obligations, rivalries, and incomplete claims.
- Allow worship and favor across national lines.
- Add costs for conflicting bargains and non-divine alternatives to avoid mandatory worship.

**Exit gate:** the player can explain why two gods want different outcomes; no pantheon maps one-to-one to a class; refusing a god is viable.

### Phase 7 — Fracture, collapse, and the first reset

**Status: implemented and regression-tested.** Calendar time and dungeon outbreaks drive crisis, war stage, refugees, siege, and Hearth integrity. Open war, fracture, and final siege have authored saved story beats. Only Hearth destruction resets the timeline, using an explicit physical/meta-state contract.

**Goal:** deliver the hidden premise through play.

- Build the crisis clock, war escalation, refugees, route loss, synchronized outbreaks, and Hearth siege.
- Preserve player performance as an inheritance score/list during collapse.
- Implement reset manifests for physical versus Keeper-bound state.
- Add the first repeated Alden scene with foreknowledge choices.
- Ensure reset cannot duplicate unique rewards, corrupt saves, or erase memorial information that should persist as Keeper Memory.

**Exit gate:** Loop Zero collapse is understandable in retrospect, reset state matches the documented contract, and the first altered choice proves that memory changes play.

### Phase 8 — Remembered campaign and endings

**Status: implemented and regression-tested.** Cross-loop evidence unlocks Keeper Archive records; repeated Alden gains a mechanical preparation advantage; milestone characters return with memory-aware dialogue; and four data-driven ending families validate distinct prerequisites and play authored closing scenes. Chosen endings halt crisis escalation.

**Goal:** turn repetition into growing agency instead of content repetition.

- Add loop shortcuts, altered arrivals, preventable tragedies, echoes of memory, and covenant objectives.
- Require cross-loop evidence and relationships for late-game resolutions.
- Implement final prison choices and ending families only after sufficient foreshadowing exists.

**Exit gate:** repeated early content is materially compressible/changeable; endings validate prerequisites and resolve the Keeper, Hearth, nations, gods, and prisoners.

## Testing strategy

Narrative changes need automated contracts alongside prose review.

### Data validation

- every referenced nation, deity, character, dungeon, portrait, and beat ID exists;
- story graph has no accidental unreachable nodes or infinite auto-transition loops;
- once-ever and once-per-loop events are distinguishable;
- all player-facing strings use localization keys when localization begins;
- forbidden direct cultural lifts and working names are flagged by a content checklist.

### State tests

- save/load before, during, and after every major story beat;
- legacy save migration with default narrative identities;
- Alden victory and death convergence/divergence;
- Contribution on partial progress and no duplicate settlement;
- pressure recovery and outbreaks across calendar jumps;
- faction/favor changes from declared credit and prison resolution;
- reset allowlist/denylist for every serialized field;
- repeated-loop dialogue selected only when prerequisites exist;
- endings inaccessible without their documented evidence and relationships.

### Narrative QA

- blind player can identify their role, immediate need, and expedition stakes;
- faction disputes are understandable without codex homework;
- each nation has multiple viewpoints and non-stereotyped characters;
- deaths feel consequential without making failed runs narratively empty;
- Loop Zero collapse feels caused, not arbitrary;
- post-reset play changes within the first repeated scene.

## Documentation cleanup after approval

Once Phase 0 is approved, update rather than silently abandon older documents:

- rewrite `High Concept.md` around the Keeper;
- mark `GameUpdatedIdea.md`, `GameLoop.md`, and `New Beginnings.md` as historical or replace their conflicting story passages;
- update `RoguelikeGameLoopExpansion.md` with Contribution, dungeon pressure, and loop ownership boundaries;
- update `DevelopmentReference.md` only when implementation actually lands;
- add the narrative data schemas and test commands to the development reference.

## Recommended first implementation slice

After approval, the safest vertical slice is not the time reset. It is:

1. narrative schema and save defaults;
2. rewritten Empty Hearth/Alden opening;
3. Alden win/death convergence with Contribution;
4. Brina and Eamon as the first Nordian/Zarabian contrast;
5. Forest -> Crypt threshold framing while leaving full runtime connection optional until tested.

That slice proves the new player identity and tone using content and systems already present, while postponing the highest-risk world simulation and reset work until the narrative foundation is stable.
