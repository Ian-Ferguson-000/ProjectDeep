# Enemies and Encounters

**Purpose:** Define enemy and encounter authoring boundaries.  
**Audience:** Combat, dungeon, AI, and art teams.  
**Owner:** Combat/content design.  
**Status:** Active migration.  
**Authority:** Enemy data requirements.

Enemy identity, stats, tags, abilities, threat cost, AI strategy, rewards, journal text, and asset references belong to catalog definitions. Encounters reference enemy IDs and allocate them through a threat budget; dungeon controllers must not hardcode complete enemy tables. Elite and boss behavior uses the same effect/action vocabulary with phase definitions and authored arena requirements.
