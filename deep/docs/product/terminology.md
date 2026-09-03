# Eros Terminology

**Purpose:** Prevent naming drift across design, code, UI, and data.  
**Audience:** Everyone.  
**Owner:** Design and engineering.  
**Status:** Canonical.  
**Authority:** Names and meanings in this file override archived terminology.

| Term | Canonical meaning |
| --- | --- |
| Adventurer | A persistent person who may be assessed, recruited, assigned, injured, retired, or killed. |
| Recruit | An adventurer candidate or newly signed adventurer; not a reusable class profile. |
| Character | Generic technical term for an adventurer runtime record. Avoid as player-facing copy when “adventurer” is clearer. |
| Class | A reusable combat/action definition referenced by an adventurer. The demo has Warrior, Mage, Tank, Rogue, Healer, and Summoner. |
| Warrior | Canonical martial starter, stable ID `warrior`. `fighter` is a legacy import alias only. |
| Rogue | Canonical assassin/evasion class, stable ID `rogue`. `phantom` is a legacy import alias only. |
| Region | A broad content family containing destinations, enemies, resources, stories, and visual themes. |
| Dungeon / destination | A selectable expedition location with its own generation profile, objectives, unlock rule, and rewards. |
| Depth | Campaign-access tier within a destination or region. |
| Floor | One generated expedition segment ending at an extraction/descend checkpoint. |
| Room | A combat, event, merchant, hazard, camp, or treasure node within a floor. |
| Secured loot | Expedition value guaranteed to survive later flee or wipe rules. |
| Unsecured loot | Carried value still exposed to expedition loss rules. |
| Tab | A visible adventurer-specific debt for tavern services and provisions, settled from that adventurer’s reward share. |
| Favor | Merchant-specific historical standing used mainly as a stock threshold. |
| Reputation | Non-spendable tavern standing controlling candidates, events, and access. |
| Permanent progression | Tavern facilities, reputation, knowledge, merchant access, and other campaign state that survives individual deaths. |
| Downed | A zero-HP encounter state. The adventurer cannot act but is not yet dead. |
| Stabilized | A Downed adventurer protected from the normal unresolved-death roll at encounter settlement. |
