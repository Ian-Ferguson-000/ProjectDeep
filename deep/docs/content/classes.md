# Classes

**Purpose:** Define the class content contract and demo roster.  
**Audience:** Class, combat, UI, and art teams.  
**Owner:** Combat design.  
**Status:** Active.  
**Authority:** Class roster and authoring requirements.

The demo contains `warrior`, `mage`, `tank`, `rogue`, `healer`, and `summoner`. Warrior and Mage are initial candidates; Forest Strategy unlocks Tank, Forest Slasher unlocks Rogue, Farmstead unlocks Healer, and Crypt unlocks Summoner.

Every class definition supplies identity, role, tags, visuals, base stat model, resource model, default four-slot loadout, allowed action pool, progression reference, AI hints, and explicit Strategy/Slasher overrides. New classes must not require controller conditionals. `fighter` and `phantom` are import aliases, never authored IDs.

The final game may contain dozens of classes; UI and save formats therefore consume IDs and catalogs rather than fixed enums or six-entry layouts.
