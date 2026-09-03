# Campaign State and Saves

**Purpose:** Define persistent state, transactions, and migration.  
**Audience:** Engineers and QA.  
**Owner:** Engineering.  
**Status:** Required extension.  
**Authority:** Save behavior.

Each of three slots stores campaign ID, save/schema versions, definition-manifest version, tutorial branch, phase, roster/candidates/memorial, contracts/tabs, facilities, economy, reputation, merchant progress, relationships, recovery assignments, unlocks, discoveries, inventory/storage, active expedition, and migration diagnostics.

Runtime records store IDs plus mutable instance state. Unknown definition IDs load as inert placeholders, generate diagnostics, and cannot be used until repaired or compensated. Aliases resolve `fighter → warrior` and `phantom → rogue` once; the next successful save writes only canonical IDs.

Transactions carry stable IDs. Settlement rejects an already committed settlement ID. Atomic save boundaries follow the game-loop contract, retain the previous backup, and never serialize a half-applied transaction.
