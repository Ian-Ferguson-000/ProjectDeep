# Data Contracts

**Purpose:** Define catalog-wide invariants.  
**Audience:** Engineers and content authors.  
**Owner:** Engineering/content tools.  
**Status:** Canonical migration contract.  
**Authority:** Gameplay data format.

Definitions are one JSON file per stable ID and validate against the matching schema in `data/schemas/`. All definitions contain `schema_version`, `id`, `display_name`, and `tags`. References resolve through `data/manifest.json`; the manifest lists paths in deterministic ID order and records a content version.

Validation rejects duplicate IDs, mismatched filename/ID, unknown references, unsupported action/effect types, nonpositive weights, invalid mode overrides, missing asset paths, cyclic dungeon unlocks, stale manifest entries, and demo-profile count mismatches. Asset-bearing scenes and resources remain Godot files referenced from JSON.
