# Expeditions and Extraction

**Purpose:** Define destinations, floors, rewards, checkpoints, and loss outcomes.  
**Audience:** Dungeon, economy, systems, and engineering teams.  
**Owner:** Systems/dungeon design.  
**Status:** Canonical requirements.  
**Authority:** Expedition structure and outcome rules.

A destination references a region, supported modes, party cap, depth range, objectives, generator strategy, encounter/reward tables, extraction rule, merchant, and unlock conditions. A region is an expandable content family, not a fixed campaign level.

## Floor Contract

Every generated floor has an entrance, completable mandatory route, guardian/objective, exit/checkpoint, threat and reward budgets, deterministic seed metadata, and validation result. Mystery grid, authored field graph, and future visible-node/spire generators produce the same `FloorGraph` contract.

## Checkpoint Decision

After a cleared floor, show secured/unsecured value, party HP/fatigue/injuries, remaining provisions, equipment condition, next-depth threat band, known modifiers, and reward multiplier. Extraction is guaranteed unless a disclosed objective or curse changed the rule before launch.

## Outcomes

- **Extraction:** bank secured and carried rewards, then settle normally.
- **Objective victory:** extraction plus bounty, completion, unlock, and merchant credit.
- **Flee during a room:** retain secured value, lose the configured unsecured share, and apply survivor injury checks.
- **Wipe:** retain secured value; unresolved Downed adventurers face death; ordinary unsecured value is lost; eligible equipment creates a time-limited rescue objective.
- **Menu abandonment:** uses flee rules and is never a free extraction.

Reward percentages, depth curves, and loss rates belong in campaign/economy balance data.
