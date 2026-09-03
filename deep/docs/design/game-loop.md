# Eros Game Loop

**Purpose:** Define the complete playable loop and authoritative state flow.  
**Audience:** Planners, designers, developers, and QA.  
**Owner:** Design.  
**Status:** Approved baseline; tuning remains provisional.  
**Authority:** Canonical game-loop specification, derived from the former `GameLoop_Implementation_Plan.md`.

## Loop Hierarchy

1. **Combat:** read intent and terrain, act with the initiative character or controlled Slasher recruit, resolve effects, and reassess.
2. **Room:** reveal and resolve combat, event, merchant, hazard, camp, or treasure content.
3. **Floor:** traverse rooms, complete the guardian/objective, secure the checkpoint share, then Extract or Descend.
4. **Expedition:** choose destination/objective, prepare 1–4 adventurers, resolve floors, and end through extraction, flee, wipe, or victory.
5. **Tavern cycle:** settle the expedition, run service, assess/recruit candidates, recover/manage the roster, improve facilities, and prepare again.
6. **Campaign:** expand the tavern, unlock regions and destinations, build histories and relationships, and resolve the former keeper storyline.

## Authoritative State Flow

`Tutorial → Tavern Return → Settlement → Service → Recruitment → Management → Preparation → Expedition → Floor Decision → Settlement`

Only validated domain commands may change phases or commit economy outcomes. Required commands include `settle_expedition`, `begin_service`, `recruit_candidate`, `assign_recovery`, `launch_expedition`, `secure_checkpoint`, `extract_party`, `flee_expedition`, and `resolve_wipe`. A settlement ID may commit only once.

## Save Boundaries

Autosave after complete transactions: campaign creation, tutorial branch convergence, settlement commit, recruitment, purchase, upgrade, expedition launch, floor start, checkpoint decision, extraction, flee, wipe, and victory. Never save halfway through settlement.

## Demo Completion Rule

The demo uses the full loop above. Its constraint is content quantity, not missing systems. Exact demo content is defined in [`../product/demo-scope.md`](../product/demo-scope.md); delivery status lives in [`../production/demo-roadmap.md`](../production/demo-roadmap.md).
