# Adventurers and Recruitment

**Purpose:** Define persistent adventurers, candidate knowledge, and roster states.  
**Audience:** Character, systems, narrative, and UI teams.  
**Owner:** Systems design.  
**Status:** Canonical requirements.  
**Authority:** Adventurer lifecycle and recruitment.

An adventurer persists until death, retirement, dismissal, or authored departure. Their runtime record stores stable identity, class/rank, level/XP, core stats, four equipped actions, visible/hidden traits, equipment, inventory, HP, fatigue, stress, injuries, morale, loyalty, relationships, tab/contract, statuses, and history.

## Candidate Knowledge

Candidates begin partially known. Observe, conversation, favored service, contextual tavern events, and paid appraisal reveal tags, comparison statements, bands, or exact values. Every reveal must remain true; generation never changes a hidden value to fit an outcome.

Candidate quality uses region progress, tavern reputation/facilities, events, and bounded variance. Higher tiers improve the mean and reduce incoherent combinations without eliminating eccentric or weak candidates. Bad-luck protection guarantees a campaign-compatible candidate after repeated misses.

## Lifecycle States

`candidate`, `available`, `assigned_service`, `training`, `recovering`, `expedition`, `downed`, `stabilized`, `injured`, `dead`, `retired`, `dismissed`, and `departed` are explicit states with validated transitions. Dead records move to the memorial and cannot return as active adventurers.

At zero HP an adventurer becomes Downed. A stabilized adventurer survives the encounter and receives the configured injury/stress consequences. An unresolved Downed adventurer receives a disclosed settlement roll based on injuries, depth, and rescue modifiers. A wipe treats unresolved Downed adventurers as unstabilized.
