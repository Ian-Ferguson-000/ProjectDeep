# Story Planning Index

These documents define the implemented Keeper-centered narrative and its writer-facing canon. The roadmap marks the verified implementation status of each phase; future content must preserve these contracts.

Read them in this order:

1. [Narrative Vision](NarrativeVision.md) — premise, themes, world rules, and committed decisions.
2. [Core Cast Briefs](CoreCastBriefs.md) — Keeper, Alden, Brina, Eamon, Corvin, and Mara's retired legacy role.
3. [Nation and Culture Guide](NationAndCultureGuide.md) — six-nation distinctions, dissent, and cultural-reference boundaries.
4. [Writer-Only Cosmology](CosmologySecret.md) — the First Concord, Covenant of Distance, loop failsafe, and ending truth.
5. [Campaign Arc Plan](CampaignArcPlan.md) — the player-facing sequence from the first customer through Loop Zero and the remembered campaign.
6. [Narrative Adaptation Roadmap](NarrativeAdaptationRoadmap.md) — implementation phases and verified exit gates.

## Authority

For new narrative work, these files supersede the story assumptions in `High Concept.md`, `GameUpdatedIdea.md`, `GameLoop.md`, and `New Beginnings.md`. Those documents remain valuable records of earlier designs and current mechanics, but they should not be used as narrative canon when they conflict with this folder.

`RoguelikeGameLoopExpansion.md`, `HearthCampaignImplementation.md`, and `DevelopmentReference.md` remain the best descriptions of currently implemented systems. The adaptation roadmap deliberately builds on those systems.

## Canon labels

- **Committed direction**: central to the requested storyline and safe to build toward.
- **Recommended**: the preferred solution in these documents, but still subject to creative approval.
- **Working name**: a placeholder that must not leak into final localized content without approval.
- **Open decision**: a question that materially affects content or implementation and must be resolved at the stated gate.

## Current gate

The adaptation roadmap is implemented through Phase 8 and covered by `tests/narrative_completion_test.gd` plus the campaign regression runner. Stable serialized IDs must remain unchanged even when prose receives later editorial polish.
