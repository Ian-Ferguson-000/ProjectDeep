# Runtime Architecture

**Purpose:** Define system boundaries that support content scale.  
**Audience:** Engineers and technical designers.  
**Owner:** Engineering.  
**Status:** Migration target.  
**Authority:** Runtime ownership.

- `ContentRegistry` owns immutable catalog definitions, aliases, schema versions, manifest ordering, and reference lookup.
- `GameBalance` remains a compatibility façade while callers migrate to domain services.
- `CampaignState` owns persistent mutable campaign state; definition bodies never enter saves.
- `ExpeditionState` owns provisional expedition state and a unique settlement transaction ID.
- Domain services validate and commit recruitment, service, preparation, combat outcomes, settlement, recovery, upgrades, and merchant transactions.
- Scenes present state and submit commands; they do not award resources or unlock content through ad hoc controller branches.
- Named deterministic RNG streams isolate candidates, layout, encounters, combat, loot, and narrative events.

Shared semantic contracts must produce equivalent campaign consequences in Strategy and Slasher even when input and timing differ.
