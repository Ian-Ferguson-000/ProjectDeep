# Eros Demo Roadmap

**Purpose:** Track the path from the current playable build to the systems-complete demo.  
**Audience:** Production and discipline leads.  
**Owner:** Production.  
**Status:** Active.  
**Authority:** Delivery status only.

## Status Vocabulary

- **Implemented:** present in runtime with automated coverage.
- **Specified:** canonical requirements exist, implementation incomplete.
- **Content-incomplete:** system works but demo content target is unmet.
- **Playtest-blocked:** automated checks pass but hands-on acceptance is outstanding.

## Current Foundation

Implemented foundations include six class kits, seven destination definitions, six merchants, persistent roster/memorial data, three save slots, party selection, Strategy/Slasher runtimes, extraction checkpoints, banked progression, tavern ledger, and dungeon selection. These remain foundations, not proof of demo completion.

## Delivery Matrix

| Order | Workstream | Status | Exit condition |
| --- | --- | --- | --- |
| 1 | Content registry, schemas, deterministic manifest, aliases, and save-version fields | Implemented | Catalog validator and stale-manifest check pass in CI; runtime retains compatibility queries. |
| 2 | Idempotent settlement, secured/unsecured rewards, contracts, and tabs | Specified | Replaying any settlement cannot duplicate an outcome. |
| 3 | Downed, stabilization, injury, recovery, wipe, and rescue | Specified | Every zero-HP and expedition outcome follows the state model and autosaves atomically. |
| 4 | Candidate generation, truthful assessment, recruitment, and assignments | Specified | The tavern can replenish and manage the roster without hidden-rule contradictions. |
| 5 | Tavern service, operating income, facilities, and specialists | Specified | A complete non-expedition service phase is playable and settled once. |
| 6 | Loadouts, provisions, liabilities, storage, durability, repair, and crafting | Specified | Ownership and costs survive save/load and every expedition outcome. |
| 7 | Reputation, relationship events, bad-luck protection, and recovery safeguards | Specified | Seeded event selection is deterministic and recovery cannot deadlock a campaign. |
| 8 | Ownership-branch tutorial convergence and narrative | Content-incomplete | Victory and death branches converge on identical mechanical state. |
| 9 | Destination rooms, encounters, enemies, items, events, and presentation | Content-incomplete | The demo profile has an acceptance-ready authored set for all seven destinations. |
| 10 | Telemetry, simulations, accessibility, balance, and target-PC acceptance | Playtest-blocked | Automated suites pass and the manual acceptance route is signed off. |

No unchecked system may be treated as complete solely because an older prototype mechanic exists.
