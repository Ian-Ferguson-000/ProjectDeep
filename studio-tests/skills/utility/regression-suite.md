# Skill Test Spec: /regression-suite

## Skill Summary

`/regression-suite [update | audit | report]` maintains `tests/regression-suite.md`,
a curated manifest of existing tests that guard critical paths and fixed bugs.
`audit` maps each GDD acceptance criterion (scoped by workflow tier) to tests in
`tests/unit/[system]/` and `tests/integration/[system]/` as COVERED / PARTIAL /
MISSING / EXEMPT, raising MISSING formula or state-machine criteria to HIGH
PRIORITY. `update` checks bugs in `production/qa/bugs/` with `Status: Closed` or
`Status: Fixed` for a regression test (HAS / MISSING REGRESSION TEST) and appends
new manifest entries without removing any. `report` is read-only. All modes
check for coverage drift.

At `qa.level: minimal` the skill stops before any scan with "Regression suite
not generated at qa.level minimal". With zero critical paths or zero test files
it reports `Coverage: NOT ASSESSED — [no GDDs found | no test files found]`
instead of a percentage. Before writing it asks "May I write/update
`tests/regression-suite.md` with the current regression suite manifest?".
Verdict, first match: **NOT ASSESSED** at the `qa.level: minimal` stop or when
coverage was not computed (never COMPLETE over a missing figure, even after a
write), **BLOCKED** if the user declines the write, **COMPLETE** after the
write — or, in read-only `report` mode, once the report is shown. `qa.level`
also sets timing — the suite is due at Polish-stage entry at `standard` and at
Production-stage entry at `full` — so each fixture pins `project.stage`. No
director gates apply.

---

## Static Assertions (Structural)

Checked against the SKILL.md by `/skill-test spec` — no fixture needed.

- [ ] Has required frontmatter fields: `name`, `description`, `argument-hint`, `user-invocable`, `allowed-tools`
- [ ] Has ≥2 phase headings
- [ ] Contains verdict keywords: COMPLETE, BLOCKED, NOT ASSESSED
- [ ] Contains "May I write" language before writing `tests/regression-suite.md`
- [ ] Has a next-step handoff (`/test-helpers` for HIGH gaps, `/regression-suite audit` on drift, `/test-flakiness` for quarantined tests)

---

## Director Gate Checks

None. `/regression-suite` is a QA utility. It spawns no agents (`Agent` is not
in its allowed tools) and no director gates apply.

---

## Fixture Defaults

Every case's `project.yaml` sets `modes.rigor: minimal` and
`modes.automation: collaborative`, with no `project.local.yaml`, unless its own
Fixture says otherwise. Rules: `studio-tests/CLAUDE.md` §
Fixture defaults.

---

## Test Cases

### Case 1: Audit — Criteria Mapped, Formula Gap Raised to HIGH

**Fixture:**
- `qa.level: standard`; workflow tier `full`; `project.stage: Polish`
- `design/gdd/systems-index.md` lists `combat`; `design/gdd/combat.md` has 4
  acceptance criteria: a damage formula, a hit-stun state transition, a
  knockback rule and a HUD damage-number display
- `tests/unit/combat/` has tests for hit-stun (all cases) and knockback (happy
  path only); nothing tests the damage formula
- `tests/regression-suite.md` exists

**Input:** `/regression-suite audit`

**Expected behavior:**
1. Skill reads the existing manifest, globs the test inventory and reads the
   combat GDD's critical paths
2. Coverage: hit-stun COVERED, knockback PARTIAL, damage formula MISSING, HUD
   display EXEMPT (UI, not automatable)
3. The missing damage formula is raised to a HIGH PRIORITY gap with a suggested
   test file path
4. The report shows the per-system table and a non-exempt coverage rate
5. Skill asks "May I write/update `tests/regression-suite.md` with the current
   regression suite manifest?"; on approval audit rewrites the full manifest
6. Verdict is COMPLETE; for the HIGH gap it suggests `/test-helpers`

**Assertions:**
- [ ] Each criterion gets one of COVERED / PARTIAL / MISSING / EXEMPT, matching the fixture
- [ ] The HUD criterion is EXEMPT and excluded from the coverage rate
- [ ] The damage-formula gap is HIGH PRIORITY with a `tests/unit/combat/` path
- [ ] The manifest is written only after the "May I write/update" ask
- [ ] Verdict is COMPLETE and `/test-helpers` is suggested

---

### Case 2: Update — Fixed Bug Without a Regression Test

**Fixture:**
- `qa.level: standard`; `modes.workflow: standard` (pinned: unset resolves to minimal, where the next-sprint wording does not apply); `project.stage: Polish`
- `production/sprints/sprint-007.md` is the current sprint plan; its one
  `Status: Complete` story is `production/epics/inventory/story-003.md`
- `production/qa/bugs/BUG-0012.md` has `Status: Closed`, system `inventory`
- No test under `tests/unit/inventory/` or `tests/integration/inventory/`
  references BUG-0012 or its failure scenario
- `tests/regression-suite.md` has 6 registered tests

**Input:** `/regression-suite update`

**Expected behavior:**
1. Skill reads the sprint plan's completed stories and the closed bugs
2. BUG-0012 is MISSING REGRESSION TEST, with suggested path
   `tests/unit/inventory/[bug-slug]_regression_test.[ext]` and the note
   "Without this test, this bug can silently return in a future sprint."
3. Report shows the Bug Regression Coverage table with BUG-0012 marked NO
4. After the "May I write/update" ask, new entries are appended with targeted
   `Edit` insertions; the 6 existing entries remain
5. Skill says the next sprint should include a story to write the missing test;
   verdict COMPLETE

**Assertions:**
- [ ] BUG-0012 is reported as MISSING REGRESSION TEST
- [ ] The suggested path follows `tests/unit/[system]/[bug-slug]_regression_test.[ext]`
- [ ] No existing manifest entry is removed
- [ ] The next-sprint story recommendation appears because bug regression gaps > 0
- [ ] Verdict is COMPLETE after approval

---

### Case 3: qa.level minimal — Suite Not Generated

**Fixture:**
- `qa.level: minimal`
- GDDs and test files exist

**Input:** `/regression-suite audit`

**Expected behavior:**
1. The early `qa.level` guard fires before any scan
2. Skill reports "Regression suite not generated at qa.level minimal" and stops
3. It does not fall into the workflow-tier `minimal` branch (smoke-report scope)
4. Verdict is NOT ASSESSED — the first rule of the verdict list

**Assertions:**
- [ ] The "not generated at qa.level minimal" message is shown
- [ ] No GDD, test or bug scan runs
- [ ] The smoke-report branch is not entered on account of `qa.level`
- [ ] Nothing is written and no "May I write" ask appears
- [ ] Verdict is NOT ASSESSED — not COMPLETE, and not a stop without a verdict

---

### Case 4: Edge Case — No Test Files, Coverage NOT ASSESSED

**Fixture:**
- `qa.level: standard`; workflow tier `full`; `project.stage: Polish`
- `design/gdd/` holds GDDs with acceptance criteria
- `tests/unit/`, `tests/integration/` and `tests/regression/` contain no files
- The user approves the manifest write

**Input:** `/regression-suite audit`

**Expected behavior:**
1. The test globs return zero files
2. Skill does not emit a coverage percentage
3. It reports `Coverage: NOT ASSESSED — no test files found`, naming the empty
   side and `/test-setup` as the skill that produces the test scaffold
4. The manifest is written only after the "May I write/update" ask
5. Verdict is NOT ASSESSED — the first match, even though the write happened

**Assertions:**
- [ ] No `0%` (or any percentage) coverage figure is reported
- [ ] Coverage reads `NOT ASSESSED — no test files found`
- [ ] `/test-setup` is named as the producing skill
- [ ] Any manifest write still requires the "May I write/update" ask
- [ ] Verdict is NOT ASSESSED — never COMPLETE over a coverage figure that was not computed

---

### Case 5: Director Gate Check — None; Report Mode Is Read-Only

**Fixture:**
- `qa.level: standard`; `project.stage: Polish`
- `tests/regression-suite.md`, tests and closed bugs exist
- Any review mode

**Input:** `/regression-suite report`

**Expected behavior:**
1. Skill produces the Regression Suite Status report in conversation
2. No director or other agent is spawned; no gate IDs appear
3. `report` mode writes nothing and asks no write question

**Assertions:**
- [ ] No director gate is invoked and no gate skip message appears
- [ ] No subagent is spawned
- [ ] The status report is shown in conversation
- [ ] No file is written and no "May I write" ask appears

---

### Case 6: Workflow Minimal With a Writing QA Level — "Next story" wording, gate requirement only at full

**Fixture:**
- `project.yaml`: `modes.workflow: minimal` (no sprints), `qa.level: standard` (pinned so the suite is generated), `project.stage: Polish`
- No sprint plan; `design/game-brief.md` exists. `production/epics/inventory/story-003.md` has `Status: Complete`, and `tests/` holds no test for the inventory system
- `production/qa/bugs/BUG-0012.md` has `Status: Closed`, system `inventory`; no test references it
- `tests/regression-suite.md` exists with 6 registered tests and an old Last Updated date

**Input:** `/regression-suite update`

**Expected behavior:**
1. The `qa.level` guard does not fire (`standard`); `update` mode is tier-independent, so it reads the completed stories and closed bugs
2. BUG-0012 is MISSING REGRESSION TEST; the completed inventory story with no test and the stale manifest are reported as coverage drift
3. After the "May I write/update" ask and the write, the follow-up lines say "next story" where they would say "next sprint": the missing tests belong in the next story, and the drift line suggests running `/regression-suite audit` at the next story boundary
4. The gaps are described as advisory; the skill does not say `/gate-check` needs the suite at this `qa.level`
5. Verdict COMPLETE

**Assertions:**
- [ ] The bug-gap line and the drift line say "next story" (or "story boundary") and the word "sprint" is not used for scheduling them
- [ ] The HIGH-priority line, when a HIGH gap exists, also says "next story", not "next sprint"
- [ ] The gaps are presented as advisory; `/gate-check` is not said to require the suite at `qa.level: standard`
- [ ] No existing manifest entry is removed and the write follows the "May I write/update" ask
- [ ] Verdict is COMPLETE

**Case 6b — `qa.level: full`:** the same fixture with `qa.level: full` and `project.stage: Production`.

**Assertions (6b):**
- [ ] The wording is still "next story"
- [ ] The output says phase gates require the regression suite at `qa.level: full`, so the gaps are not just advisory there

---

## Protocol Compliance

- [ ] At `workflow: minimal` the follow-up lines say "next story" in place of "next sprint"
- [ ] Stops before scanning at `qa.level: minimal`
- [ ] Reports `NOT ASSESSED` instead of a percentage when GDDs or tests are absent
- [ ] Asks "May I write/update `tests/regression-suite.md`" before any write
- [ ] `update` only appends; existing manifest entries are never removed without approval
- [ ] `report` writes nothing
- [ ] Verdict, first match: NOT ASSESSED at the `qa.level: minimal` stop or when coverage was not computed (even after a write); else BLOCKED if the user declines the write; else COMPLETE

---

## Coverage Notes

- No-argument behaviour (runs `update` when a sprint is clearly active, else
  asks A/B/C) is not tested.
- Case 6 covers the workflow-`minimal` wording in `update` mode; at that tier
  `audit` maps coverage against the latest
  `production/qa/smoke-*.md` report instead of GDD criteria, and stops if none
  exists; not separately tested.
- Coverage-drift detection is exercised only through Case 6's completed story
  without tests and stale manifest date; the new-system and revised-GDD
  indicators have no dedicated case.
- The skill does not run tests; it maps criteria and bugs to test files by name.
