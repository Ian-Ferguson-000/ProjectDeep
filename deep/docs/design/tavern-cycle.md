# Tavern Cycle and Contracts

**Purpose:** Define tavern phases, service, contracts, tabs, and settlement.  
**Audience:** Systems/UI designers and developers.  
**Owner:** Systems design.  
**Status:** Canonical requirements.  
**Authority:** Tavern economy and phase behavior.

## Phases

1. **Return and settlement:** secure eligible loot, calculate shares, repay tabs, resolve Downed/injury/death, update relationships, Favor, reputation, quests, and unlocks, then commit once.
2. **Service:** spend limited service slots on food, drink, lodging, and authored patron events. Service supplies reliable recovery income and candidate information; expeditions remain the main growth source.
3. **Recruitment:** meet a generated candidate pool, take truthful assessment actions, and sign visible contracts when roster capacity permits.
4. **Management:** assign recovery/training/service status, manage equipment and storage, visit specialists, and purchase upgrades.
5. **Preparation:** choose destination, depth, objective, party, action loadouts, gear, provisions, and payment source. The confirmation screen shows every cost and liability.

## Tabs and Settlement

Every adventurer has an exact, player-visible tab. Food, drink, lodging, treatment, equipment loans, and provisions state whether they add tavern-funded cost or adventurer debt. At settlement:

1. Calculate expedition gross value and contract shares.
2. Pay the tavern share.
3. Repay each survivor’s outstanding tab from their individual share up to the amount owed.
4. Carry remaining debt within its disclosed cap.
5. Resolve dead-adventurer debt using recovered personal value up to the configured limit; write off the rest.
6. Apply all resulting resources, records, and unlocks atomically.

The player must never profit by intentionally killing an indebted adventurer. Exact percentages and curves belong in economy balance data.

## Recovery Safeguards

With no living adventurers, provide two free desperate candidates and a recovery contract. With no gold, retain a free basic meal, starter gear loan, and low-risk recovery expedition. These safeguards cannot grant more expected value than ordinary successful play.
