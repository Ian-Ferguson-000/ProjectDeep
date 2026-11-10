# Eros Demo — Roguelike Game Loop

## Demo Promise

The demo is a persistent, single-player roster roguelike built around the Hearth tavern. Adventurers are individual people: they gain levels, gear, traits, and history, and death removes them permanently. Progress survives through the tavern, recruited merchants, banked resources, unlocked classes, research, and knowledge of hidden paths.

## First-Run Tutorial

Class selection starts the tutorial directly in the Slasher Forest. Tutorial progress is saved, and the player learns movement, attacks, abilities, defense, consumables, room rewards, and the character menu. The tutorial automatically continues through the Forest campaign. After the tutorial, ordinary permadeath and expedition settlement apply.

## Campaign Loop

Calendar arrival -> recruit in the Hearth -> choose party and equipment -> Slasher expedition -> settle -> advance a day -> next candidate wave

- The Forest permits two characters. Clearing it raises the cap to four and unlocks both Tank and Rogue.
- A dead character is removed immediately. Survivors may continue shorthanded.
- Intermediate floor and room clears autosave and continue automatically. Boss victory or total-party defeat resolves an expedition.
- Victory banks carried rewards before surviving participants retire. Defeat loses unbanked rewards and records deaths.
- Campaign saves are versioned, slot-based, and migrated forward while preserving historical clears.

## Classes and Dungeon Progression

Warrior and Mage are available initially. A Forest clear unlocks Tank and Rogue; Ashen Farmstead and Stone Crypt unlock Healer and Summoner. The campaign graph controls later regular and secret dungeon access. Dungeon definitions in `data/dungeons.json` route through their Slasher runtime.

## State Contracts

`CharacterRecord` owns stable character identity, class, level, gear, inventory, traits, status, and history. `ExpeditionState` owns party IDs, runtime snapshots, dungeon and floor, provisional rewards, casualties, and tutorial status. `CampaignState` owns calendar history, roster, Memorial, Hall of Heroes, unlocks, completed dungeons, banked progression, and save serialization. `RunState` owns active Slasher combat state.

## Current Delivery Status

The active loop includes class selection, direct tutorial launch, Slasher dungeon routing, party swapping, Hearth management, class and dungeon unlocks, campaign settlement, and legacy save migration. Target PC balance, audio, and accessibility playtesting remains outstanding.
