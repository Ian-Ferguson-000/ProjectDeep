# Development Reference

This document describes the active Godot game. The archived shooter prototype under `reference/project_deep_shooter/` is preserved for ideas and is not active game code.

## Project Overview

- Project: `Eros`; Godot 4, 2D canvas item stretch mode.
- Main scene: `res://scenes/main/Main.tscn`.
- The tutorial launches directly into the Slasher Forest after class selection. The Hearth expedition planner launches all dungeons through their Slasher runtime.
- `CampaignState` owns roster, expedition, unlock, settlement, and save state. `RunState` provides the active combat runtime and Slasher progression.

## Active Scene Map

- `scenes/main/Main.tscn` and `scripts/main.gd`: application flow, tutorial start, dungeon routing, and return settlement.
- `scenes/tavern/Tavern.tscn` and `scripts/scenes/tavern.gd`: Hearth, company ledger, equipment, party selection, and expedition launch.
- `scenes/slasher/SlasherForest.tscn` and corresponding scripts under `scripts/slasher/`: real-time dungeon runtime.
- Other active dungeon scenes are Slasher scenes under `scenes/slasher/`; shared combat, UI, and campaign systems live under `scripts/`.

## Progression and Saves

`data/dungeons.json` defines dungeon order, runtime routing, floor counts, descriptions, and unlock rules. Campaign clears are recorded without a mode dimension. A Forest clear unlocks both Tank and Rogue; later class and dungeon unlocks follow the campaign graph.

`CampaignState` writes versioned saves with atomic backups. Save migration converts historical dungeon-completion records to the current completion map. An active expedition recorded with the retired runtime is settled once as a defeat when its save loads.

## Narrative Foundation

The active narrative direction is Keeper-centered. `data/story/nations.json` defines stable nation IDs and `NarrativeContent` exposes them to character and dialogue systems. `CharacterRecord` persists nation, faith, doctrine, and relationships independently from class. `CampaignState` save version 15 adds Contribution, faction standing, divine favor and obligations, story-event history, queued crisis scenes, Keeper Memory, dungeon ecology, world crisis, and ending state. `ExpeditionState` accumulates Contribution at one-time checkpoints and carries optional patronage and a declared resolution objective; settlement preserves Contribution even when material loot is lost.

`DungeonEcology` owns persistent pressure, resources, stability, suppression counts, recovery, and outbreaks. The Forest, Crypt, and Balor's Hell share the `balor_prison` ecology because they are stages of one route. Calendar advancement recovers pressure/resources and erodes stability; clearing approach stages relieves pressure without suppressing the prisoner, while clearing the prison performs a full suppression. Current pressure and resources affect automated risk and rewards and appear in the expedition planner.

`DungeonObjectiveService` gives every destination authored suppress, rebind, evidence, or covenant options. The Cinderway connects Ashen Farmstead, Sunken Mine, and Ember Foundry through the shared `adragor_breach` ecology. `NationArrivalService` reserves four curated milestone characters so all six nations enter through authored disputes; the same characters can return once per loop with altered dialogue.

`DivineFavorService` loads the twelve initial gods from `data/story/pantheons.json`. Expedition patronage is optional and independent from nationality and class. Sponsored outcomes earn favor, rival relationships can impose small costs, and accepted boons apply to one sponsored expedition before their promise is recorded as fulfilled or broken.

`WorldCrisis` turns time, low dungeon stability, and simultaneous outbreaks into an escalating regional crisis, war stage, refugees, siege, and Hearth integrity. Ordinary expedition defeat never resets the world. Only Hearth destruction calls the explicit reset manifest: physical campaign state is cleared, Keeper Memory and story history persist, and the next loop opens with the remembered Alden scene. `NarrativeProgression` resolves Keeper codex entries and four ending families from data-backed evidence and relationship requirements.

The opening keeps the player as the Hearth's Keeper in both Alden outcomes. Alden is Nordian, Brina establishes the Nordian continuation, and Eamon introduces Zarabia's competing seal doctrine. The retired former-owner confrontation remains migration-compatible but can no longer trigger. Broader arc and implementation sequencing live under `docs/story/`.

## Useful Checks

Run the project with Godot 4 and use the GDScript suites in `tests/` for campaign, dungeon, Hearth, save migration, and release-readiness checks. The `tools/` directory contains asset and integration utilities used by the project.

Run `tests/narrative_foundation_test.gd` after narrative identity, tutorial state, Contribution, or story-save changes.
