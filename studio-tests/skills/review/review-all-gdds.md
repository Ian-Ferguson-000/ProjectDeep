# Skill Test Spec: /review-all-gdds

## Skill Summary

`/review-all-gdds` is an Opus-tier skill that performs a holistic cross-GDD
review across the system GDDs in `design/gdd/`. After loading everything
(Phase 1), it runs two independent reviews in parallel as `game-designer`
sub-agents: Phase 2, Cross-GDD Consistency (dependency bidirectionality, rule
contradictions, stale references, ownership conflicts, formula compatibility,
acceptance-criteria conflicts), and Phase 3, Game Design Holism (competing
progression loops, attention budget, dominant strategies, economic loops,
difficulty curves, pillar alignment, player-fantasy coherence). Phase 4 walks
multi-system scenarios. It produces a PASS / NOT ASSESSED / CONCERNS / FAIL
verdict, and writes `design/gdd/gdd-cross-review-[YYYY-MM-DD].md` and
systems-index "Needs Revision" statuses only after the user approves.

Each phase is a `references/N-*.md` file the skill reads before doing that phase and
again if the conversation is compacted during it. The argument picks the focus:
`full` (default), `consistency`, `design-theory`, or `since-last-review`, which
takes its scope from `.claude/scripts/review-scope.sh`.

It is invoked after individual GDDs are approved and before architecture work.
It spawns no director gate agents. At `workflow: minimal` it does not apply (no
GDDs), so every fixture below sets `modes.workflow: full`.

---

## Static Assertions (Structural)

Checked against the SKILL.md by `/skill-test spec` — no fixture needed.

- [ ] Has required frontmatter fields: `name`, `description`, `argument-hint`, `user-invocable`, `allowed-tools`
- [ ] Has ≥5 phase headings (complex multi-phase skill)
- [ ] Contains verdict keywords: PASS, NOT ASSESSED, CONCERNS, FAIL
- [ ] `allowed-tools` includes Write, so "May I write" language is present (Phase 6 report write)
- [ ] Has a next-step handoff at the end
- [ ] Documents parallel spawning of Phase 2 (Consistency) and Phase 3 (Design Theory)

---

## Director Gate Checks

No director gates — this skill spawns no director gate agents and resolves no
review mode. It IS the holistic review; its only agents are the two
`game-designer` sub-agents for Phases 2 and 3.

---

## Fixture Defaults

Every case's `project.yaml` sets `modes.rigor: minimal` and
`modes.automation: collaborative`, with no `project.local.yaml`, unless its own
Fixture says otherwise. Rules: `studio-tests/CLAUDE.md` §
Fixture defaults.

---

## Test Cases

### Case 1: Happy Path — Clean GDD set with no conflicts

**Fixture:**
- `project.yaml` sets `modes.workflow: full`
- `design/gdd/` contains `game-concept.md`, `game-pillars.md` (pillars and
  anti-pillars), `systems-index.md`, and three system GDDs — `combat.md`,
  `inventory.md`, `crafting.md` — each with every section Phase 1c loads and a
  filled `## Cross-References` table whose rows all resolve
- All GDDs are consistent: no formula contradictions, no competing ownership,
  no stale references, reciprocal dependencies; every system serves a pillar
- Nothing a design-theory check would warn on either: one primary progression
  loop, at most 4 systems active at once, every resource has both a source and a
  sink, compatible scaling curves, compatible player fantasies

**Input:** `/review-all-gdds`

**Expected behavior:**
1. Skill greps `## Summary` across `design/gdd/*.md` and shows a manifest ("Found [N] GDDs. Summaries: …")
2. Skill reads the entity registry, or notes that it is empty and suggests `/consistency-check`
3. Skill loads the review sections and reports "Loaded [N] system GDDs covering [M] systems. Pillars: […]. Anti-pillars: […]."
4. Phase 2 and Phase 3 spawn simultaneously as `game-designer` sub-agents, each
   given the pasted GDD content for its slice (not file paths) and its checklist (2a–2f / 3a–3g)
5. Phase 4 walks 3–5 multi-system scenarios
6. Report shows no blocking issues and no warnings; verdict PASS
7. `AskUserQuestion`: "May I write this review to `design/gdd/gdd-cross-review-[date].md`?"
8. Closing widget built from project state

**Assertions:**
- [ ] Phase 2 and Phase 3 are spawned in parallel (both `Agent` calls issued before either result is awaited)
- [ ] Sub-agent prompts carry the GDD section content, not just file paths
- [ ] The report states the covered set: `GDDs reviewed: [N] of [M] present` and `Not read: none`, and lists the scenarios walked
- [ ] Verdict is PASS only because there are no blocking issues **and no warnings**, over three readable GDDs — a single warning would make it CONCERNS
- [ ] The report is written only after the user approves, under an ISO-dated name (`gdd-cross-review-YYYY-MM-DD.md`)
- [ ] The closing widget offers `/create-architecture` and `/gate-check` (both allowed on PASS)

---

### Case 2: Failure Path — Conflicting rules between two GDDs

**Fixture:**
- `project.yaml` sets `modes.workflow: full`
- `combat.md` defines a floor: "Minimum damage after armour reduction is 1"
- `status-effects.md` states a mechanic that bypasses it: "Poison ignores armour
  and can reduce damage to 0"
- The two GDDs are otherwise complete and valid; `game-pillars.md` defines the
  pillars and `systems-index.md` lists both systems

**Input:** `/review-all-gdds`

**Expected behavior:**
1. Phase 2 detects the floor/ceiling contradiction
2. Report prints a `🔴 Rule Contradiction` entry quoting both rules and asking which GDD is authoritative
3. The issue sits under Consistency Issues → Blocking; both GDDs appear in "GDDs Flagged for Revision"
4. Verdict: FAIL, with "If FAIL — required actions before re-running"
5. After the report write question, a second `AskUserQuestion` offers to mark the flagged GDDs `Needs Revision` in `systems-index.md`

**Assertions:**
- [ ] Verdict is FAIL (not PASS, CONCERNS or NOT ASSESSED)
- [ ] Both GDD filenames are named in the conflict entry
- [ ] The specific contradicting rules are quoted (not a vague "conflict found")
- [ ] The issue is classified as Blocking (🔴), and both GDDs are in the flagged table with Priority Blocking
- [ ] Skill does NOT decide which GDD is right and does NOT edit either GDD
- [ ] If the user approves the systems-index update, the status is written as exactly `Needs Revision` with no parenthetical
- [ ] The closing widget offers neither `/create-architecture` nor `/gate-check` (verdict is FAIL)

---

### Case 3: Partial Path — Cross-reference to a GDD that does not exist

**Fixture:**
- `project.yaml` sets `modes.workflow: full`
- `design/gdd/` holds `game-pillars.md`, `systems-index.md` and two consistent
  system GDDs, `crafting.md` and `inventory.md`
- `crafting.md`'s `## Cross-References` table has a row whose Target GDD is
  `system-b.md`; no `design/gdd/system-b.md` exists
- `systems-index.md` lists system-b as the next system with Status: Not Started
- Nothing else would warn

**Input:** `/review-all-gdds`

**Expected behavior:**
1. Phase 2's stale-reference check (2c) confirms each Cross-References row's
   Target GDD exists, and finds `system-b.md` missing
2. Because `systems-index.md` lists system-b, the reference is a dependency on
   planned work: a `⚠️ Stale Reference` Warning naming `crafting.md` and the
   missing target, to re-check when that GDD is written
3. No other issues found; verdict CONCERNS (warnings, nothing blocking)
4. Closing widget includes `/design-system system-b` (next in design order)

**Assertions:**
- [ ] The finding names `crafting.md` and the missing `system-b.md`
- [ ] It is reported under Warnings (⚠️), not Blocking — because the systems index lists system-b as planned
- [ ] Verdict is CONCERNS — not FAIL for a reference to planned work, and not an unqualified PASS
- [ ] The closing widget offers `/design-system system-b`, and offers `/create-architecture` but not `/gate-check` (which requires PASS)
- [ ] Skill does NOT skip or silently ignore the missing target

**Case 3b — the target is in neither place:** the same fixture, except
`systems-index.md` has no entry for system-b. Nothing will ever define it.

**Assertions (3b):**
- [ ] The reference is reported as 🔴 Blocking, and `crafting.md` appears in "GDDs Flagged for Revision" with Priority Blocking
- [ ] Verdict is FAIL, and the closing widget offers neither `/create-architecture` nor `/gate-check`

---

### Case 4: Edge Case — Fewer than two system GDDs

**Fixture:**
- `project.yaml` sets `modes.workflow: full`
- `design/gdd/` contains `systems-index.md` and a single system GDD, `combat.md`

**Input:** `/review-all-gdds`

**Expected behavior:**
1. Skill loads what exists and counts the system GDDs
2. Fewer than 2 → skill stops with: "Cross-GDD review requires at least 2 system
   GDDs. Write more GDDs first, then re-run `/review-all-gdds`."
3. No review phase runs and no report is offered

**Assertions:**
- [ ] Skill outputs the "requires at least 2 system GDDs" stop message
- [ ] Neither Phase 2 nor Phase 3 sub-agent is spawned
- [ ] No verdict of PASS is produced for the single document
- [ ] No report write is offered and no file is written

---

### Case 5: Director Gate — none spawned, whatever the review mode

**Fixture:**
- `project.yaml` sets `modes.workflow: full`
- `design/gdd/` holds the Case 1 set: concept, pillars, systems index and three
  consistent system GDDs
- 5a: `modes.review_mode: full`; 5b: `modes.review_mode: solo`

**Input:** `/review-all-gdds`

**Expected behavior:**
1. The resolved config block requests only `automation`, `workflow` and
   `system_overrides` — review mode is not consulted
2. In both 5a and 5b, the same two `game-designer` sub-agents run Phases 2 and 3
3. No director gate agent is spawned; the verdict is produced normally

**Assertions:**
- [ ] No director gate agents (CD-, TD-, PR-, AD-, LP- prefixed gates) are spawned in either mode
- [ ] Review mode changes nothing: under `solo` the two `game-designer` sub-agents still run
- [ ] Output contains no "Gate: [GATE-ID]" or "[GATE-ID] skipped" entries
- [ ] The skill produces a verdict in both modes
- [ ] The only `Agent` spawns in the run are the Phase 2 and Phase 3 `game-designer` sub-agents

---

### Case 6: NOT ASSESSED — fewer than two readable GDDs

**Fixture:**
- `project.yaml` sets `modes.workflow: full`
- `design/gdd/` holds `game-pillars.md`, `systems-index.md` and two system GDDs:
  `combat.md`, complete, and `inventory.md`, which has the template's headings but
  only placeholder text under them

**Input:** `/review-all-gdds`

**Expected behavior:**
1. Two system GDDs exist, so the "requires at least 2 system GDDs" stop does not fire
2. `inventory.md` is present but empty — not reviewable — so only one GDD can be
   compared, and a clean result would mean only that nothing was compared
3. Verdict NOT ASSESSED; "If NOT ASSESSED — what could not be reviewed, and why"
   names `inventory.md` as placeholder-only and says a cross-review needs two
   readable GDDs
4. The report states `GDDs reviewed: 1 of 2 present`

**Assertions:**
- [ ] Verdict is NOT ASSESSED — not PASS, although no contradiction was found
- [ ] The report names `inventory.md` as present but not reviewable, and states `GDDs reviewed: 1 of 2 present`
- [ ] A GDD that could not be read at all would be named on the report's `Not read:` line under every verdict, and is a NOT ASSESSED trigger like an empty one
- [ ] The closing widget offers neither `/create-architecture` nor `/gate-check`

---

### Case 7: Phase files are read on demand, and again after a compaction

**Fixture:**
- `project.yaml` sets `modes.workflow: full`
- `design/gdd/` holds the Case 1 set: concept, pillars, systems index and three consistent system GDDs
- The skill folder holds `references/1-load.md` through `references/7-handoff.md`
- The conversation is compacted while Phase 4 (scenario walkthrough) is under way, then the run continues

**Input:** `/review-all-gdds`

**Expected behavior:**
1. SKILL.md holds no phase steps; before Phase 1 the run reads `references/1-load.md`, and it does not scan `## Summary` lines or load GDD sections before that read
2. Phases 2 and 3 are spawned in parallel as `game-designer` sub-agents, and the main run reads `references/2-consistency.md` and `references/3-design-holism.md` before it passes each sub-agent its checklist (2a–2f, 3a–3g)
3. `references/4-scenarios.md`, `5-report.md`, `6-write.md` and `7-handoff.md` are each read before that phase's work: no scenario before the first, no verdict or report before `5-report.md`, no write question before `6-write.md`, no closing widget before `7-handoff.md`
4. After the compaction the run reads `references/4-scenarios.md` again before it continues the walkthrough, as the skill says: "Read it again if the conversation was compacted or resumed during this phase."

**Assertions:**
- [ ] The transcript shows a read of each of the seven `references/N-*.md` files, each before that phase's work begins
- [ ] No phase work (summary scan, checklist hand-off, scenarios, verdict, write question, closing widget) happens before its phase file is read
- [ ] After the compaction, `references/4-scenarios.md` is read again before the walkthrough resumes
- [ ] The Phase 2 and Phase 3 sub-agents are still spawned in parallel with the checklist items from the phase files

---

### Case 8: `since-last-review` — scope comes from the script, not from reasoning over git

**Fixture:**
- `project.yaml` sets `modes.workflow: full`
- `design/gdd/` holds `game-pillars.md`, `systems-index.md`, a committed `gdd-cross-review-2025-01-15.md`, and four system GDDs: `combat.md`, `inventory.md`, `crafting.md`, `status-effects.md`
- Only `combat.md` has been modified since that report was committed; its `## Dependencies` section names `inventory.md`
- `crafting.md` and `status-effects.md` are unchanged and no changed GDD names them
- `.claude/scripts/review-scope.sh` prints `PRIOR_REVIEW: design/gdd/gdd-cross-review-2025-01-15.md`, `CHANGED:` with `design/gdd/combat.md`, and a `DEPS` line `combat.md -> inventory.md`

**Input:** `/review-all-gdds since-last-review`

**Expected behavior:**
1. After the manifest, the run executes `bash .claude/scripts/review-scope.sh` rather than working out the changed set from `git log` or `git diff` itself
2. Scope is the `CHANGED` set plus the GDDs named on the `DEPS` lines: `combat.md` and `inventory.md`; the run shows the user which GDDs are in scope before any full read
3. Only those two GDDs get the Phase 1c section load; `crafting.md` and `status-effects.md` are not loaded, and no second dependency-expansion pass is made
4. The report states `GDDs reviewed: 2 of 4 present`
5. Phases 2 and 3 run over the two in-scope GDDs as usual

**Assertions:**
- [ ] `bash .claude/scripts/review-scope.sh` is run, and its `CHANGED` and `DEPS` lists are used as the scope as printed
- [ ] The run does not derive the changed set with its own git history search
- [ ] `inventory.md` is in scope although it did not change, because `combat.md` declares it as a dependency
- [ ] The unchanged, undeclared GDDs are not loaded and are not counted as reviewed: the report says `GDDs reviewed: 2 of 4 present`
- [ ] The scope is shown to the user before the full section reads

**Case 8b — no prior review:** the same fixture with no `gdd-cross-review-*.md` file. The script prints `PRIOR_REVIEW: NONE (full review required)`.

**Assertions (8b):**
- [ ] The run falls back to `full` mode and says a full review is required because no prior review exists
- [ ] All four system GDDs are loaded and reviewed (`GDDs reviewed: 4 of 4 present`)

---

### Case 9: Focus modes — one pass runs, and the report says which did not

**Fixture:**
- `project.yaml` sets `modes.workflow: full`
- `design/gdd/` holds the Case 1 set: concept, pillars, systems index and three consistent system GDDs, with no conflicts and nothing a design-theory check would warn on

**Case 9a — `/review-all-gdds consistency`**

**Expected behavior:**
1. Phase 1 loads everything as usual; only the Phase 2 (Cross-GDD Consistency) `game-designer` sub-agent is spawned, with checklist 2a–2f
2. No Phase 3 (Game Design Holism) sub-agent is spawned
3. The report's `Focus:` line reads "consistency only — design theory not run", and the session extract's `Phases not run:` line names design theory, rather than reporting it as clean
4. The verdict is for the pass that ran, labelled: `PASS (consistency only — design theory not run)` — not NOT ASSESSED, since the user asked for one pass
5. The closing widget offers neither `/gate-check` nor `/create-architecture`: a one-pass review is not the full review either needs

**Assertions (9a):**
- [ ] Exactly one `Agent` spawn: the Phase 2 consistency sub-agent
- [ ] The design-theory phase is named as not run — never omitted silently, never reported as having found nothing
- [ ] The verdict is `PASS (consistency only — design theory not run)`: labelled, never an unqualified PASS, and not NOT ASSESSED
- [ ] Neither `/gate-check` nor `/create-architecture` is offered
- [ ] The session extract's `Phases not run:` line names design theory

**Case 9b — `/review-all-gdds design-theory`**

**Expected behavior:** the mirror of 9a. Only the Phase 3 sub-agent is spawned (checklist 3a–3g), Phase 4 and the report still follow, and the consistency pass is named as not run.

**Assertions (9b):**
- [ ] Exactly one `Agent` spawn: the Phase 3 design-theory sub-agent
- [ ] The `Focus:` line names consistency as not run, the verdict is `PASS (design theory only — consistency not run)`, and the session extract's `Phases not run:` line names consistency
- [ ] Neither `/gate-check` nor `/create-architecture` is offered

---

## Protocol Compliance

- [ ] Reads each phase's `references/N-*.md` file before doing that phase, and again after a compaction or resume during it
- [ ] Phase 2 (Consistency) and Phase 3 (Design Theory) spawned in parallel — not sequentially
- [ ] The full analysis is shown before any write is requested
- [ ] Does NOT write the report or update `systems-index.md` without `AskUserQuestion` approval
- [ ] Verdict is one of exactly: PASS, NOT ASSESSED, CONCERNS, FAIL
- [ ] Every issue cites the GDD, section and text involved
- [ ] Ends with an `AskUserQuestion` handoff built from the verdict: FAIL or NOT ASSESSED → neither `/create-architecture` nor `/gate-check`; CONCERNS → `/create-architecture` only; PASS → both

---

## Coverage Notes

- Economic loop analysis (3d, source/sink loops) is not fixture-tested. Case 2
  exercises Phase 2's rule-contradiction check — a different checklist, run by
  the other sub-agent — so it says nothing about 3d.
- The design theory phase (Phase 3) checks, including dominant strategy detection
  and cognitive overload, are not individually fixture-tested.
- Case 6 covers the fewer-than-two-readable-GDDs trigger, through a
  present-but-empty GDD. The NOT ASSESSED triggers for undefined pillars and for
  a sub-agent that returns no report are not fixture-tested.
- Case 8 covers `since-last-review` with and without a prior review; a prior
  review whose changed GDDs name no dependencies is not tested separately.
  Case 9 covers the `consistency` and `design-theory` focus modes.
