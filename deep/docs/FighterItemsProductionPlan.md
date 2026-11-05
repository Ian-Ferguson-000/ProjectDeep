# Fighter items: production upgrade goals

Status: complete. All ten fighter items meet the recorded acceptance contract;
the final consolidated regression and normal/reduced visual review passed.

## Final sign-off

The final current-worktree run completed all **32 regression suites** with no
reported failures or script errors: configuration, production mechanics, scenario
matrix, mass deaths, sustained use, animation timing, swing contact, speed/contact,
anticipation interruptions, active/recovery interruptions, class swaps, target
lifecycle, actual dungeon room transitions, corner navigation, narrow terrain,
dynamic terrain, displacement resistance, Hammer retargeting, frenzy damage,
beast ranges, Sling returns, fighter audio, crowded audio, Trident presentation,
fighter arsenal, standard fighter slash, active items, testing ground, warrior
kits, mage items, neutral items, and hit geometry. `git diff --check` is clean.

Acceptance evidence by weapon (in addition to shared matrices):

| Weapon | Verified contract and focused evidence |
| --- | --- |
| Eldritch Bowstaff | Per-body curses, once-only death conversion, bounded pooled beasts, valid terrain and corner navigation; production, target lifecycle, beast ranges, conversion/overflow captures. |
| Demon Blade | Nonstacking hit-triggered frenzy, post-mitigation incoming penalty, expiry and swap/room commitment; frenzy damage, class/room transitions, native frenzy capture. |
| Storm Trident | Safe matching preview/flight/impact, immune/boss rules, single vulnerability, possession and retrieval; production, dynamic terrain, presentation and status/retrieval captures. |
| Valkyrian Sling | Finite curved ricochets, safe target loss, timed return parry and additive launch-baseline damage; production, Sling returns, native journey/parry capture. |
| Dragonbone Dagger | Distinct-strike capped armor reduction shared across damage sources, floor and whole-set expiry; production, configuration, seven-strike wounds capture. |
| Archon Crossbow | Swept ordered one-hit piercing, later-target damage growth, resistance-aware capped carry and safe release; production, narrow/dynamic terrain, mixed-target wall capture. |
| Divine Hammer | Explicit direct/splash overlap, one nonbranching capped follow-up, live retargeting and safe lunge; production, retarget/terrain, native chain capture. |
| Grim Reaver | Per-target criticals, owned-kill capped rampage, no hidden haste or excess-critical conversion; production, target lifecycle, rampage capture. |
| Sentinel Shield | Front-only one-hit bash, collision-safe movement, resistance-aware shove without immunity; displacement/terrain, native resistance capture. |
| Umbral Bow | Unique refreshed tethers, normal-speed steal and cap, immediate contribution removal; production, target/class/room lifecycle, native tether lifecycle capture. |

All shared release gates below are reconciled with their source and test
evidence, not only checkbox state. All twenty current crowded captures were
reviewed alongside the sequential and focused lifecycle captures. Rendering
checks were performed on the local Metal/M4 setup; this is not a claim of
certification on every GPU or an hours-long performance soak. No commit, package,
or deployment was requested or performed. Earlier increments below retain their
historical open-gate wording; this sign-off is the current status.

### Verified foundation increment

Final crowded visual review: regenerated and inspected all twenty
`build/fighter_live_<item>_<normal|reduced>.png` captures on the current code.
The native 32-enemy rendered matrix passes **3,020 checks**. Curse marks, wound
icons, frenzy commitment label/aura, storm ground pins, hammer splash boundary,
shield frontal pressure arc, and Umbral ground tethers remain readable without
opaque full-screen effects. Reduced quality retains these essential cues.
The Trident fixture originally used the desktop cursor and landed outside the
fixed capture camera; deterministic keyboard aim with a test-only 250px range
fixes that fixture. Its rerun passes **302 checks**, and both corrected captures
were inspected with visible pin marks and retrieval indicator. Production range
is unchanged. Together with the previously reviewed sequential attack sheets
and single-item conversion, frenzy, wounds, retarget, parry, resistance,
retrieval, carry, and tether lifecycle sheets, this closes the visual release
gate. Snapshot timing alone is not used as proof of contact synchronization;
the independent timing/contact suites supply that evidence. Capture-process
frame-time figures include readback/fixture overhead and are not a new shipping
performance benchmark. Final consolidated regression audit remains pending.

Configuration and bounded-resource audit completed. Remaining gameplay constants
were moved into `fighter_active_items.json` without changing defaults: shared
special damage/contact padding, Dagger follow-up damage, Trident basic geometry
and phase fractions, swept projectile radii, Sling return approach factor, and
Archon carry offsets. Per-item overrides merge over shared defaults. The new
configuration suite passes **37 checks**, including actual changes to damage,
phase geometry, and projectile contact when tuning is overridden.
Fresh sustained-use coverage passes **80 checks** over 30 simulated seconds per
item with replaced crowds: effects peak at 32, active beasts at 24, and all
projectile/effect/summon pools remain bounded and disjoint from active records.
Hit records expire on their fixed retention clock; owner death clears persistent
state. Code audit confirms cached target lists, swept projectile contacts,
collision-safe displacement, and pooled effect/projectile/summon records.
Fresh production **324**, Sling return **10**, and swing-contact **6,299** checks
pass after configuration migration. These close the remaining foundation gates;
they are not a substitute for the still-open final visual release audit.

Actual dungeon transition audit passes **125 checks** in
`fighter_room_transition_test.gd`. All ten items activate through the dungeon's
real active slot and make real contact before changing to a neighboring room
through `_build_floor`. Archon attachment, Umbral tether, and Bowstaff conversion
are explicitly established before teardown. Weak refs prove the old player,
runtime, target, and summons are freed. Item ownership survives without silently
refilling spent charge; new rooms inherit no tether haste or stale attack lock;
each item can activate again after an explicit test recharge. Actual-hit Demon
frenzy preserves its commitment. Fresh class swaps **94**, phase interruptions
**590**, and actual active-item/drop integration pass. Together with the earlier
focus/Escape, target-exit, anticipation, owner-death, and recovery suites, this
closes cleanup and weapon/class/death/scene-transition gates. The timing gates
in the foundation are also reconciled with the already-passing speed/contact,
attack-identity/deduplication, and presentation tests recorded below.

Corner navigation audit exposed and fixed a real beast-pathing defect: the
shared cell-entry steering could turn directly toward a target before the
beast's footprint cleared the corner, leaving it stuck against the wall.
Beasts now retain a cached cell-center route until each waypoint is reached,
rebuilding only on destination-cell, navigation-revision, or pathfinder change.
Pooled setup resets the route. No full path search is added per animation frame.
`fighter_corner_navigation_test.gd` passes **10 checks** at 30/120Hz: route around
solid cover, no crossing/bites through it, actual damage after reaching prey,
and reset on reuse. Fresh narrow terrain **24**, beast ranges **7**, production
**324**, dynamic terrain **25**, resistance **22**, and neutral-item regression
runs pass. Combined with prior wall/swept-collision, invalid landing recovery,
disconnected terrain, and heavy-target checks, this closes the terrain release
gate. Final rendered presentation and scene-transition audit remain separate.

Terrain audit found and fixed a Bowstaff spawn-validation gap: non-finite corpse
or desired coordinates, and non-Vector2/non-finite sanitizer results, are now
rejected before navigation/physics queries or pooled collider activation.
`fighter_narrow_terrain_test.gd` passes **24 checks**: 20px openings admit the
bolt and small beast but block larger carried/shoved enemies; Hammer actually
reaches and stops at an undersized passage at 30/120Hz; beasts can traverse a
fitting gap and bite beyond it; disconnected walkable islands reject summons;
INF, NaN, and invalid sanitizer outputs spawn nothing and visibly dissipate
curse energy. Fresh regressions pass dynamic terrain **25**, displacement
resistance **22**, production **324**, and the neutral-item suite. The shared
terrain gate remains open pending corner/navigation audit, not because these
narrow-passage checks failed.

Attack-speed/step-rate release gate is now verified over an explicit boundary
and stress range. Native animation timing passes **993 checks** at haste factors
0.1, 0.5, 1, 4, 10, and 100 for all ten weapons, basic and special: sprite
duration, authoritative timeline, animation lock, and duplicate-input rejection
remain synchronized. Trident correctly observes its readable windup floor rather
than incorrectly expecting unlimited inverse scaling. Independent melee arc /
target-capsule contact checks pass **6,299 checks** over the same factors at
30/120Hz, including timelines shorter than one simulation step.
New `fighter_speed_contact_test.gd` passes **2,306 checks** for native ranged
basic release and Hammer/Shield/Trident special impact across that same speed
and step-rate matrix: no projectile or damage before release, actual target
contact, finite recovery, and equal total damage across rates. Haste is held
constant deliberately to isolate each timeline; these are deterministic timing
checks, not claims that a 100x build is normally attainable or visually ideal.
Existing dynamic-buff and visual-capture gates remain separate.

Target lifecycle release gate is now verified. The new native-special matrix
(`tests/fighter_target_lifecycle_test.gd`) passes **316 checks** across all ten
items, normal/reduced effects, actual lethal external damage, and queue-free
despawns. Every fixture first proves real contact; Archon additionally proves
attachment, Umbral a live tether, and Bowstaff positive curse stacks. Weak refs
prove bodies really free. Cursed deaths convert exactly once while despawns do
not fabricate kills; Umbral haste disappears immediately rather than merely
timing out; unrelated Reaver deaths cannot grant even transient rampage stacks.
Projectiles/chains terminate and a targetless Trident remains retrievable.
The expanded Hammer retarget suite passes **15 checks**, including actual death
and despawn during follow-up anticipation with exactly one replacement hit.
Fresh companion runs pass: production **324**, interruption **98**, Sling return
**10**. These supply mid-flight target loss, carry-cap reuse, last-target return,
and source-owned cleanup evidence alongside the new post-contact matrix. This
closes only the target death/despawn gate, not all release verification.

Native class-swap coverage now passes **94 checks** across all ten weapons
(`tests/fighter_class_swap_test.gd`). Each weapon starts a native special and
reaches live combat state before the same player-setup entry point used by class
podiums switches to Mage and back to Fighter. Pending contacts/recovery clear,
carries and tethers release, and returning reuses exactly one original runtime
without reviving cancelled attacks. Demon Blade confirms an actual damaging hit
before switching and retains its vulnerability commitment; a committed Trident
retains possession state and can still be physically retrieved. World teardown
then verifies weak references to the original player, target, and runtime all
expire. This supplements, but does not replace, the actual dungeon room-transfer
test and final shared scene-transition audit. No gameplay changes were needed
for this increment; the first Demon fixture initially switched before contact
and was corrected to require a confirmed frenzy before testing persistence.

Active/recovery interruption coverage now passes **590 checks** over all ten
items, both phases, and focus loss, Escape, input lock, unequip, and owner death.
Each fixture starts through native input and asserts it actually reached the
intended state before interrupting. Melee active arcs and later recovery are
separate cases; instant impacts use their post-contact recovery; ranged actions
use actual flight and later weapon recovery; Trident uses flight and embedded
possession. Pending contacts clear immediately and cannot hit newly arriving
enemies. Already committed projectiles may finish on focus/input interruption,
but cannot duplicate or loop; unequip retires non-Trident shots, and owner death
retires all. A committed Trident stays physically retrievable after nonfatal
interruption. This closes the shared phase-interruption gate alongside the
existing anticipation matrix, not the still-open class/scene-transition gate.

Shared release audit: the scenario matrix now compares complete per-target
authoritative snapshots across normal/reduced quality, not only total damage.
It includes individual health, armor/wounds, storm duration/state, slow/stun,
curse/tether duration, carry state, haste, frenzy, rampage, and object counts.
**820 checks pass** for all ten items at 0/1/32 targets and 30/120Hz. A separate
native lethal-crowd suite passes **110 checks** with 32 one-health enemies per
item/quality, actual freed bodies, independent beast updates, one death callback
per body, bounded kill procs, and equal quality-mode death outcomes.

Fresh **324 focused / 80 sustained-use checks** also pass. Sustained use covers
30 simulated seconds per weapon, crowd replacement, bounded active/pool counts,
disjoint pool records, and death cleanup; this is not a claim of a multi-hour
soak. Active-item/drop integration, armory, 95 warrior configurations/36 native
combos, 361 mage assertions, neutral-item regression, and hit-geometry regression
all pass on the current worktree. These support the four checked shared gates
below and the reduced-quality foundation check. Active/recovery interruption,
class/scene transition breadth, terrain breadth, and final crowded presentation
review still require their own audit; they are not inferred from these passes.

Umbral's native lifecycle capture passes **18 checks** at both qualities. A
special arrow pierces three targets; the fighter moves with stolen-speed
afterimages; a subsequent basic arrow refreshes without duplicate haste; actual
death, walking a target beyond the configured 300px break range, and native
weapon swapping each remove the appropriate slow/haste contribution. Both
nine-stage sheets were inspected for ground ribbons, transfer pulses, foot
marks, movement afterimages, snapping ribbons, and clean removal. **324 focused
checks pass**. This closes Umbral's item-specific presentation criterion.

Sling's remaining return criterion now has **10 explicit checks** at 30/120Hz:
a configured two-impact quota returns despite a valid third target, missed
catch is harmless, and deletion of the final target starts a safe finite return.
The natural three-target/parry capture rerun passes **794 checks**, and the
audio suite passes **15 checks**. Together with the previously inspected return
color, contracting timing ring, curved flight, parry flash, and tier marker,
this reconciles Sling's two remaining item-specific entries. Shared final
release criteria are not implied by these item-level checkoffs.

Archon's native mixed-target wall capture passes **22 checks** at both qualities:
four victims receive 40/54/68/82 damage once each, the heavy victim stays in
place while contributing to damage growth, movable victims are visibly carried,
and the wall terminates the bolt and releases every survivor on its near side.
An enemy beyond the wall takes no damage. Both nine-stage sheets were inspected
for loaded windup, release/recoil, staggered carried poses, accumulation, terrain
impact, and recovery. The metal core now warms and thickens slightly with pierce
count at both qualities, preserving buildup feedback when decorative pressure
rings are reduced. **25 dynamic-terrain, 22 displacement-resistance, and 98
interruption checks pass**. Together with existing finite-range and lifecycle
evidence, this reconciles Archon's remaining item-specific criteria; shared
release gates remain open.

Demon Blade now lights three edge runes during frenzy (fading in its final
second) and extends its normal-quality sweep trail from 0.18 to 0.30 radians.
Reduced quality retains the runes and player-owned warning/aura without the
decorative trail. Its native lifecycle capture passes **20 checks** covering
first damage, accelerated follow-up, refresh, doubled incoming damage, a real
equipment swap, expiry, and clean baseline. Both nine-stage sheets were
inspected. The fixture advances retained runtimes and hurt-invulnerability
timers after swapping; otherwise manually stopped old runtimes falsely leave
cached visuals on screen. Unequip also now explicitly redraws both canvases
immediately after clearing attack state. **341 animation timing and 98
interruption checks pass**. Together with previous contact/haste checks, this
closes Demon Blade's item-specific presentation criterion; shared release
verification remains open.

Dagger successful contacts now emit a short ivory/red fang-shaped puncture
flash through the capped reusable effect pool, at both effect qualities. This
adds no bleeding or damage-over-time behavior. Its native wound-progression
capture passes **62 checks**: seven distinct swings grow the set to six,
refresh without exceeding the cap, honor the armor floor, and restore base
armor on natural expiry. Both nine-stage sheets were inspected for contact,
progressive cracks, capped fracture, refresh pulse, recovery, and fade/removal.
The target is stationary and displacement-resistant to isolate repeated contact;
dual-strike and moving-target cases remain covered by the separate mechanical
suites. **324 focused and 15 audio checks pass**, including the existing
max-stack fracture cue rules. Dagger's item-specific presentation criterion is
checked; this does not close the shared crowded-play/release gate.

Reaver now adds up to six small soul lights along the scythe blade itself,
in addition to its existing owner status lights. Their intensity fades during
the final second; the same essential blade feedback remains at reduced quality.
The native rampage capture passes **14 checks**: a real sweep kills six targets,
earns capped stacks/88% critical chance, a seeded follow-up emits critical
feedback, and natural expiry restores the 28% baseline. Both nine-stage sheets
were inspected for normal versus critical impacts, activation mantle, blade
lights, recovery, soul-release and clean baseline. **324 focused checks pass**.
Reaver's item-specific presentation criterion is checked; shared crowded-play
and release gates remain separate.

Shield's native resistance/terrain capture passes **14 checks** across both
qualities. One bash simultaneously exercises an ordinary target stopped by a
visible wall, a boss receiving the authored reduced displacement, and a rear
target excluded from the frontal area. Both nine-stage sheets were inspected:
forward drive precedes damage, a fixed frontal crescent marks contact, ordinary
skids differ from resistant recoil arcs, and the shield settles without granting
immunity or a movement lock. The item-specific Shield presentation criterion is
now checked; the broader shared release gate remains open.

The melee contact suite also passes **1,647 checks**, including Reaver's native
basic/special arcs at 1x/4x haste and 30/120Hz, independently checking blade
angles and earliest capsule contact. Together with the focused per-body hit
deduplication and mixed critical-roll test, this reconciles Reaver's remaining
mechanical sweep criterion; rampage presentation review remains open.

Shield/Frenzy mechanical audit adds **15 incoming-damage checks** and expands
the displacement suite to **22 checks**. Enemy contact, enemy-origin projectile,
and environmental damage each double once after mitigation; full absorption
causes neither health loss nor a hurt flash. Healing and signed non-combat
health adjustments remain unmultiplied (no new health-cost mechanic is added).
Shield now has explicit coarse/30Hz/120Hz evidence for ordinary and heavy shove
distance and no repeat damage/displacement after contact. Current-source audit
and the focused frontal/terrain/interruption assertions support the four Shield
mechanical checkoffs below; its resistant-hit visual comparison remains open.

Trident's native status/retrieval capture passes **22 checks** at both qualities.
It uses keyboard aim with a configured 250px range, three ordinary/boss/immune
targets, actual flight, and collision-safe walking into the 44px pickup radius.
Both nine-stage sheets were inspected: preview/impact boundaries agree, normal
and boss victims show grounding sigils, immune victims show open slow arcs,
boss control/mark expires first, the embedded weapon has a locator, retrieval
leaves remaining marks intact, and every control/mark clears on expiry. The
shared capture helper now explicitly redraws the foreground before readback;
this removes stale first-frame aim imagery in manually stepped fixtures. The
attempted viewport mouse-event fixture was replaced with deterministic keyboard
input rather than depending on the host cursor. **98 interruption checks pass**.
This closes Trident's item-specific presentation criterion; the shared final
release gate is still open.

Trident's stun-immune slow is now authored as `immune_slow_multiplier` (default
0.65), passed through the real landing path and clamped to 0–1 on the enemy.
Three new focused assertions use a nondefault 0.8 value: actual landing applies
slow without stun, unrelated damage is still doubled exactly once, and slow/
vulnerability presentation both expire. **324 focused, 25 dynamic-terrain, 241
Trident trajectory, and 361 mage regression checks pass**. Current-source audit
also confirms boss-shortened windows, persistent possession across re-equips,
retrieval without status cancellation, and safe preview/release/landing handling.
The first six Trident criteria below are reconciled against that evidence and
the previously inspected ordinary throw sequence. Invalid navigation/sanitizer
results explicitly fall back to the fighter's current position, not an invented
historical landing location. Dedicated immune/boss/retrieval visual comparison
remains open under the last presentation criterion.

Bowstaff overflow now has a distinct broken-rune silhouette that separates and
fades, rather than sharing generic status dust. Four fragments remain readable
at both quality settings without adding persistent objects. The new live crowd
capture begins with 32 AI enemies, converts five six-stack victims, and passes
**310 checks** across both qualities: exactly 24 beasts allocate, overflow
feedback exists and expires, caps hold during combat, and deliberately freeing
one slot never materializes discarded summons. Both regenerated three-stage
sheets were inspected; broken corners distinguish discarded energy from the
emerging bodies. Setup damage now uses the real compact fighter source label,
not the verbose generic test label. **80 sustained-use checks pass** across all
ten weapons after the summon-range changes. Combined with the prior natural
conversion and ordinary-swing review, this closes Bowstaff's item-specific
presentation checklist; shared cross-item release gates remain open.

Bowstaff's new full conversion capture passes **28 checks** at normal/reduced
quality: three native swings apply three stacks; an external kill spawns three
beasts; independent windup/bites damage a new enemy without applying curses;
an uncursed prey kill produces no recursive summon; finite lifespan retires
every pooled body with visibility and collision disabled. Both nine-stage
sheets were inspected for marks, conversion, emergence, bite anticipation and
contact, and dissolution. Gameplay is advanced with a fixed clock; unrelated
popup/sprite animations use render time, so these sheets are stage evidence,
not a real-time playback benchmark. Overflow presentation remains a separate
review criterion.

Beast acquisition radius/cadence and engagement/contact ranges now come from
authored item values, retaining the previous defaults. **7 range checks** cover
configuration propagation, acquisition limits, windup, escaping contact range,
and successful close contact; the **neutral-item regression passes** because
Blood Ruby uses the same beast implementation. Existing focused terrain/cap
checks and this natural conversion evidence reconcile the two remaining
Bowstaff summon-mechanics checklist entries below.

Hammer's native automatic-chain capture now verifies an opening two-enemy area
kill, two single-target repeats, and no-target completion at normal/reduced
quality (**22 checks**). Both nine-stage sheets were inspected: overhead head
descent, separate compressed windups, radius-matched contact rings, kill-energy
return, turning lunges, and final recovery are visible. Additional head runes
and restrained brightness now indicate increasing chain depth, retained during
final recovery and present at both quality levels. **321 focused checks and 11
retarget/terrain checks pass**. The Hammer checklist is reconciled against
these captures plus the focused overlap, multi-kill, chain-cap, interruption,
and wall tests. This does not sign off the shared live-crowd release gate.

Natural Sling journey verification exposed a close-target orbit: constant
flight speed plus limited turning could circle the next ricochet target until
range exhaustion. Outbound flight now reduces approach speed with target
distance, turn rate, and authored `approach_factor` (0.5), retaining curved
heading and swept collision. The new `fighter_sling_journey_capture.gd` uses
native launch/defense, three natural targets, fixed gameplay steps, one timed
parry, and a subsequent missed catch without injecting return states. Both
qualities pass **794 checks**: every target receives base then twice-base
damage, the baseline stays unchanged, only one projectile exists, and the catch
does not hurt the owner. Both nine-stage sheets were inspected: cyan return,
contracting timing ring, gold redirection flash, added tier marker, and safe
disappearance are visible. **321 focused checks pass**; the older additive
damage test now waits for contact within a bounded one-second deadline instead
of assuming constant-speed contact times. Crowded parry/audio readability
remains separate from this three-target presentation review.

Ordinary-attack motion review now includes normal Dagger/Reaver/Archon/Umbral
and reduced Bowstaff/Demon/Dagger/Reaver/Hammer/Sling, completing the previously
outstanding ordinary-sequence inspection. The capture viewport was widened to
960x640 so the full Reaver sweep is no longer clipped. Reduced effects retain
curse marks, the frenzy vulnerability label, armor icons, critical-hit feedback,
Hammer's impact boundary, and Sling's return indicator. Archon visibly empties
at release and carries/relinquishes victims; Umbral retains ground tethers.
Capture combat randomness is now seeded per weapon after fixture setup for
repeatable normal/reduced comparisons. These six-enemy, high-health captures
still do not sign off parries, kill chains, summon conversion, or live crowds.

Archon's first three mechanical criteria below are reconciled against the
implementation and freshly passing **321 focused / 10 displacement-resistance
checks**: swept ordered contacts, additive subsequent-victim damage, one direct
hit per body, capped carry, and non-displacement of resistant victims. Full
attachment/termination presentation and the overall release gate remain open.

Shield sequential review exposed a rotating sword-sweep after its instantaneous
shove. It now opts out of the base sweep history and draws a short fixed frontal
pressure crescent, using the actual bash direction/reach/arc. Both regenerated
qualities were inspected: anticipation, fixed contact, and recovery are distinct
without a post-hit rotating slash. **321 focused checks and the fighter arsenal
suite pass**; three new assertions verify no early contact effect, matching
geometry, and no sword-sweep history. Base slash drawing remains enabled by
default. Archon's refreshed reduced sequence was also inspected: the weapon
empties at release while the bolt carries targets forward and releases them.

Ranged recovery review found a misleading duplicate loaded-shot silhouette:
Sling's pouch stayed luminous and the bow/crossbow kept drawing a loaded arrow
after release. Presentation now reads a shared loaded/charge/recovery state:
Sling settles with an empty brown pouch, strings relax, and loaded bolts/arrows
disappear at actual release. **341 animation checks pass**, including twelve
new boundary/recovery checks across Sling, Archon, and Umbral. Refreshed Sling
normal and Umbral reduced sequential sheets were inspected; targeted captures
pass four staging checks each. Flight, return tint, and Umbral ribbons remain
visible without a second glowing shot at the hand. Archon's updated recovery
still needs its own rendered review; parry/chain presentation gates remain open.

Sequential render review found a competing contact effect: fighter-item special
actions inherited the generic sprite's white sword crescent before the item's
authoritative contact. Equipped-item, active-slot, and automatic Hammer-repeat
routes now select the existing clean `slash` body strips; procedural weapons
remain responsible for contact silhouettes. Standard fighter actions are
unchanged. **329 animation-timing checks, 11 Hammer checks, active-item
integration, and the standard slash regression pass**.

`fighter_motion_contact_sheet.gd` captured twenty 12-frame sequences (ten
weapons, both qualities; **40 staging checks**). These are successive rendered
states of native input with live runtime/sprite clocks, not separately rebuilt
snapshots. Manual owner timers use elapsed physics ticks to account for image
readback delay. Normal Bowstaff/Demon/Hammer/Trident and reduced Trident sheets
were inspected: the premature crescent is gone, Hammer windup/contact/recovery
is distinct, and Trident flight precedes its damage/pin indicators. Remaining
sheets await inspection. Six stationary high-health enemies exercise ordinary
contact, not live crowd navigation, automatic kill chains, return parries, or
summon conversions; those presentation cases remain separate release work.

Hammer target changes now turn the current body animation along with the
procedural hammer. The new player-facing helper preserves normalized frame
progress and total playback duration, rather than restarting the swing or
leaving the fighter facing the abandoned target. **11 Hammer retarget/terrain,
289 animation-timing, and 318 focused checks pass**. Added checks cover sprite
direction, pose progress, unchanged attack deadline, and intentionally unequal
directional strip lengths/FPS. Continuous rendered-motion review remains open.

Hammer now revalidates target distance during windup, not only target lifetime
and line of sight. A repeat reacquires a reachable target or ends refreshed
without chasing an enemy outside chain range. Empty impacts also clamp to the
near side of solid terrain from their very first preview frame; previously a
close wall could leave the default 75px impact point behind it, allowing splash
to originate on the wrong side. **6 retarget/terrain, 318 focused, and 760
scenario checks pass**, covering escaping targets, replacement acquisition,
no-target termination, first-frame preview, and actual behind-wall immunity.

Archon/Shield now use the enemy's shared displacement-resistance lookup,
including elite-guardian behavior tuning previously honored only by ordinary
knockback. Archon excludes non-boss immovable/heavily resistant bodies from
carrying while preserving their direct damage and pierce contribution. The
authored `carry_resistance_threshold` is 0.5; zero displacement is always
ineligible. Gaining resistance mid-flight releases carry/control before further
movement. Shield's shove and resistant-impact classification use the same
lookup. **10 displacement-resistance, 318 focused, 25 dynamic-terrain, and 361
mage regression checks pass**. Tests use non-boss guardian and zero-resistance
fixtures, later eligible victims, and a resistance change during active carry.

Actual enemy-death integration exposed and fixed a normal-mode drop failure:
the conditional choice-list expression inferred `Array[String]` but supplied an
untyped empty array outside Dev Mode, aborting `_roll_enemy_drop` before loot
creation. Choices now initialize explicitly as `Array[String]`. The expanded
active-item suite passes twenty seeded real elite/boss kills (each fighter item
from each enemy category), followed by actual pickup and charged-slot checks.
Seeds select successful outcomes without changing authored chances. A real Dev
boss kill also produces three choices, opens the three-card modal, and equips
the selected charged item. The armory integration suite passes separately.
This supersedes earlier helper-only drop evidence, which did not exercise the
failing death callback. The acquisition/activation release criterion is now
checked; presentation and remaining release criteria stay open.

Requirement reconciliation now checks off nine previously stale mechanical
criteria for Dagger, Reaver, and Umbral, after inspecting their target-owned
status/damage code and rerunning the focused suite (**318 passing checks**).
New evidence uses two distinct fighter actors with matching local cast IDs:
their dagger strikes contribute to one shared armor set, while each actor's
repeated collision remains deduplicated. An actual Reaver multi-kill also
confirms that rampage changes neither attack interval nor movement speed.
These checked mechanical criteria do not sign off their adjacent presentation
criteria or the overall release gate; those remain open.

Reaver rampage now clears its timer and stacks on owner death. Previously the
dead-owner early return froze that state, allowing a revived actor to retain
the previous life's critical bonus. **315 focused and 98 interruption checks
pass**. The new regression earns rampage through an actual scythe kill, kills
the fighter, then restores health on the same actor and verifies baseline crit
chance with no remaining rampage duration.
The sustained-use suite also passes **80 checks** after the recent lifecycle
changes: all ten weapons remain within effect/projectile/summon bounds during
repeated crowds, and owner cleanup leaves no active combat records.

Bowstaff curse expiry, conversion, owner cleanup, and runtime exit now disconnect
their source-owned death listener. Live curses deliberately retain conversion
across weapon swaps. Conversion also checks owner health immediately, preventing
new beasts if the fighter died before the next runtime update. **312 focused
and 760 scenario checks pass**. New tests verify expiry/reapplication listeners,
swap persistence, and same-frame owner-death suppression with explicitly empty
summon capacity (so cap rejection cannot disguise a failed death guard).

Umbral tether removal now disconnects its source-owned enemy death and despawn
listeners as well as clearing slow/haste. Previously those listeners survived
expiry/distance breaks/swaps until the enemy or runtime was freed, causing
irrelevant later callbacks. Retethering reconnects both; refresh remains
deduplicated. **307 focused and 98 interruption checks pass**, including three
new listener lifecycle assertions and the existing actual death/despawn tests.

Trident throw windup now scales with the same attack-speed ratio used by Hammer
and Shield instead of remaining fixed at 0.22 seconds. **289 animation-timing
checks** verify normal/4x release timing and synchronized sprite duration;
**304 focused and 25 terrain checks** also pass. Its basic melee attack now has
a rendered shaft/prongs along the authoritative swing (the previous silhouette
switch omitted Trident). The throw-area preview is suppressed during that melee
attack to avoid implying an unrelated area hit. **1,647 swing-contact checks**
now include Trident basics. Both qualities in `fighter_trident_basic.png` were
inspected: the cyan silhouette remains visible with only the decorative trail
removed at reduced quality. Body-pose and continuous-motion review remain open.

Trident flight presentation now uses the visible arc's tangent for both the
prongs and trail. Previously the prongs stayed parallel to the ground path and
the trail could follow the owner's current aim after launch. The configurable
`flight_arc_height` is shared by preview and flight. **241 presentation checks**
compare curve position and independent finite-difference tangent across four
directions, three heights, and five progress points, verify aim independence,
and ensure presentation does not move authoritative projectile state. **25
terrain checks and 302 rendered crowd checks pass**. The inspected live normal
capture shows the deployed marker rather than airborne motion; full flight
motion review remains open. Render-capture process p95 was 44.47 ms normal and
17.74 ms reduced; this screenshot harness remains unsuitable as a direct
performance sign-off (see isolated profile below).

Storm Trident now revalidates its displayed destination during anticipation,
so a wall inserted before release moves the preview to the safe side before the
weapon launches. Landing sanitizers/navigation snapping also receive a final
range and solid-terrain check; unsafe results fall back to the fighter's
position. Nonfinite sanitizer results are rejected before navigation conversion.
**25 dynamic-terrain, 304 focused, and 760 scenario checks pass**. Seven new
checks cover windup obstruction, preview/release/landing agreement, sanitized
positions behind walls or beyond range, and invalid results with/without a
navigation grid. This strengthens safe retrieval and preview correctness; it
does not close the remaining continuous-motion presentation review.

Dragonbone now has a restrained armor-fracture cue at the first transition to
maximum stacks. It reuses an existing licensed dry impact, with -17 dB gain,
0.15-second emitter cooldown, and two simultaneous voices. Capped refreshes do
not request it again; expiry permits a new fracture. **15 fighter-audio checks
pass**, including tests that clear mixer cooldowns before repeated hits so they
prove gameplay deduplication. The general audio integration passes with **41
events/9 loops** and nonzero mixer output.

`fighter_crowd_audio_test.gd` adds **8 passing checks**: actual dagger contacts
fill wounds on 32 enemies at both effect qualities, retain exactly two fracture
voices, stay within the 24-voice global budget, and produce unclipped mixed PCM.
Observed peaks were 0.245 normal and 0.316 reduced (random impact variants mean
these amplitudes need not match). This covers one representative dense burst,
not subjective listening or the full ten-weapon crowded audio audit.

Melee contact and procedural weapon rendering now share one swing-angle
function. The dagger's reversed second cut previously drew its trail on the
leading side; trail direction now follows the actual sweep. The new
`fighter_swing_contact_test.gd` passes **1,571 checks** across Bowstaff, Demon,
Dagger, and Reaver, basic/special, normal/4x haste, and 30/120 Hz. Independent
authored-angle expectations cover both directions. Centerline damage timing is
bounded by the target's circular hitbox and contact padding, not just the
windup window. **304 focused, 760 scenario, and 283 sprite-timing checks pass**.
This strengthens angular/contact evidence but does not substitute for the
remaining continuous-motion and body-pose/art review.

Archon carry presentation now freezes enemies in a direction-aware braced idle
pose instead of letting idle animation continue during forced travel. The pose
does not rotate, lift, or scale the sprite, whose transform supplies combat
geometry. Source-owned release resumes animation; unrelated control sources
cannot release it. **304 focused checks, 98 interruption checks, and 18 dynamic
terrain checks pass**, including four new pose/ownership/transform assertions.
`fighter_archon_carry_capture.gd` passes four staging checks and produces framed
first-carry, three-body carry, and release panels. Both qualities were inspected:
the metal projectile remains visible at the leading edge, carried silhouettes
are staggered, and reduced quality retains the essential state. This closes the
previous out-of-frame capture gap, not the continuous-motion/audio audit.

The Demon Blade frenzy warning now uses one reusable foreground label, above
enemy sprites, instead of text that crowd silhouettes could obscure. Its timer
and doubled-incoming-damage warning remain visible in the revised live normal
capture; expiry hides it. The focused suite passes **300 checks**, including
foreground visibility and expiry. Reviewed live Trident normal, Sling normal,
and Umbral reduced stills also show their deployed marker, projectile, and
tethers respectively; these stills do not prove continuous-motion readability.

An isolated no-readback rendered profile separates process, physics, and direct
item-update samples. The initial Bowstaff-only run held median **60 FPS** in all
six cases. With 32 live enemies and 24 beasts, physics p95 was **11.25 ms** and
direct item update p95 **0.83 ms**, at both effect qualities on this machine.
This does not establish a portable hardware budget. The expanded profile then
completed all ten weapons in both qualities plus baseline/summon cases (24
four-second cases, first 90 physics frames discarded). Every case held median
60 FPS on the local Apple M4/Metal renderer at 1280×720. Across the twenty
weapon cases, direct item-update p95 ranged from 0.151–1.291 ms; total physics
p95 ranged from 4.971–9.322 ms. Process p95 remained 16.138–19.346 ms, so median
FPS alone must not be interpreted as a strict no-hitch frame-time guarantee.
The profiler manually advances item logic, keeps the player invulnerable, and
uses 32 high-health moving enemies; it is not a full dungeon or long-session
benchmark. Trident retrieval is physically advanced and aiming follows live
targets, ensuring it does not measure only an idle deployed weapon.

Further reviewed live stills: Demon reduced (warning readable), Dagger normal
(armor marks visible), Archon normal (shot leaves capture bounds), Hammer
reduced (splash boundary readable), Shield reduced (frontal area visible), and
Reaver reduced (scythe silhouette and critical numbers visible). Archon needs
a better framed in-flight capture for carry presentation; single screenshots
remain insufficient for parry timing, repeated-contact animation, or audio mix.

The new rendered-crowd harness runs native equipped-item input, animated sprites,
32 live moving enemies, and both effect qualities. Its full run passed **3,020
population/activation checks** and produced 20 live screenshots. Inspection
exposed overlapping Bowstaff curse rings; these are now compact head-adjacent
stack markers with a consolidated cap rune. A targeted rerun passed **302**
checks, and its revised normal crowd capture was inspected; the **760** headless
scenario checks also pass. Raw process-monitor p95 samples were roughly 47–62 ms
in the full run and 42 ms in the targeted rerun. These are not acceptable evidence
of performance sign-off: monitor sampling, test overhead, AI, rendering, and
runtime costs still need separation. Most other live captures also await review.

`fighter_sustained_use_test.gd` passes **80 checks** across thirty simulated
seconds per weapon with repeated 16-enemy crowd replacement and actual contacts.
Bowstaff conversions exercise its full 24-beast cap and 32-effect limit; all
weapons remain within projectile/effect/pool limits. The largest observed
hit-history size is 432, below the time-bounded guard. End-of-run checks confirm
active records are disjoint from reusable pools, and owner death clears long-lived
combat state. This is a deterministic object-lifecycle stress test, not a rendered
frame-rate benchmark or crowded visual sign-off.

Shield impacts now distinguish resistant bodies with a restrained recoil mark
and capped heavy-impact audio instead of the normal metallic contact cue.
Ordinary victims leave short skid/dust cues anchored to their collision-resolved
endpoint, not the requested shove distance; reduced effects retain the skid.
Heavy, pinned, and strongly knockback-resistant victims use resistant feedback.
Three added checks verify cue replacement, resistant classification, and actual
endpoint anchoring. **11 fighter-audio checks, 298 focused checks, and 760
scenario checks pass**. Crowded visual/mix review remains outstanding.

`fighter_dynamic_terrain_test.gd` adds **18 passing physics checks** with solid
walls inserted only after shots are airborne. Trident, Archon, Umbral, and Sling
cannot damage targets behind the new obstruction and terminate/return safely.
Trident deploys on the reachable side and permits actual physical retrieval.
An already-carried Archon victim also stops before newly inserted terrain and
loses the bolt's control immediately on termination. No implementation change
was required for these newly verified dynamic-obstacle paths.

Hammer initial windup, contact reach, targeting arc, and empty-room impact
distance now read authored fighter data. Shield basic reach/arc/shove, windup,
and stagger duration likewise no longer depend on runtime literals. Defaults
preserve balance. Six mutation tests verify nondefault values affect actual
scheduled attacks and target acquisition. **298 focused checks, 283 equipped
animation/input checks, and 760 scenario checks pass**.

Repeat-input audit corrected an important timing-test fixture gap: attaching a
runtime alone did not select a registered weapon, so earlier basic-action cases
used the standard fighter route. The fixture now selects each actual gear ID
and asserts `uses_warrior_kit()` before testing. All **283 animation/input checks
pass** on that route, including basic/special actions at normal/4x haste,
matching sprite clocks, duplicate rejection, resource refunds, unchanged
cooldowns, and unchanged pose locks. Duplicate tests refill resources first so
they cannot accidentally pass through an insufficient-resource rejection.
Dungeon active-slot tests also verify rejected duplicate activations retain
their charge; the integration suite passes. The earlier 123-check timing result
was weaker evidence for native basics than originally described; these corrected
route assertions supersede it.

Automatic Hammer repeats now turn the actor toward the selected target and
restart its sprite at the compressed authoritative windup duration, rather than
leaving only the procedural weapon moving. Each killing smash emits one bounded
kill-energy return from a defeated victim; splash multi-kills do not multiply
that effect. **123 animation-timing checks, 292 focused checks, and 760 scenario
checks pass**. This adds repeat-facing, playback duration, pose-lock, and
nonbranching kill-feedback coverage; continuous-motion presentation review
remains part of the final gate.

Player-sprite timing audit found the generic slash path capped playback at
0.18 seconds and refused to slow animations, independently of fighter runtime
duration. Equipped and active-slot fighter actions now supply their authoritative
duration to sprite playback and pose locking. Generic/base-class behavior stays
unchanged. `fighter_animation_timing_test.gd` passes **120 checks** across ten
items, basic/special actions, and normal/4x haste; active-slot integration also
checks pose duration. The focused suite (**291**), base fighter-slash suite, and
active-item integration pass. The latter's Shadow Step fixture now chooses a
clear lane after room rebuilding and advances physics frames instead of assuming
an entrance's left side is open. Full animation contact-pose review remains open:
matching total playback duration alone does not prove every sprite contact pose.

Trident launch timing now subtracts the pre-release part of the frame before
integrating flight, matching the other ranged timelines. Previously a long
caller frame moved the trident for time spent winding up, producing early
flight/impact. Nine checks compare analytic post-release travel and matching
positions using one coarse frame, 30-Hz steps, and 120-Hz steps. **291 focused
checks, 760 scenario checks, and 98 interruption checks pass** after the fix.

Contact audio now distinguishes fighter critical hits from Shield/Archon metal
impacts, and successful Sling return parries play a metallic response. The
enemy damage path accepts an authored impact cue, replacing rather than layering
over its generic hit sound. New cues reuse existing licensed assets with bounded
voices and cooldowns. `fighter_audio_test.gd` passes **8 checks** proving no early
impact cue, actual contact cues, successful parry response, and no false success
on repeat input. The audio integration suite passes with 39 events/9 loops and
nonzero mixer output; all **282** focused fighter checks pass. Subjective crowded
mix/listening review remains part of the presentation gate.

Cross-item displacement audit found Shield and Archon bypassed ordinary-hit
Storm pin protection. Enemy-owned `is_storm_pinned()` now governs all three
fighter displacement paths: Shield still damages without shoving; Archon still
damages and counts the pierce without attachment; a pin applied mid-carry
releases only the bolt's control while preserving Storm's stun. Stun-immune
slow victims remain displaceable. Five new interaction checks pass, bringing
the focused suite to **282**, with **760** scenario checks and **361** mage
assertions passing after the shared-enemy predicate change.

Archon now prunes dead, despawned, detached, and no-longer-owned carry entries
before processing new contacts. Previously those stale weak references still
occupied the carry cap until shot termination. Pruning clears only that bolt's
control source and ownership marker; later eligible victims can use released
capacity without exceeding the cap. Five new checks cover dead and freed first
victims followed by a second target at a one-victim carry cap. **277 focused
checks, 760 scenario checks, and 98 interruption checks pass**.

Hammer follow-up motion audit found fixed-speed lunges lost distance when haste
compressed the windup, and oversized frame steps could move farther than fine
steps. Follow-ups now traverse a configurable bounded lunge over the actual
windup duration, clipping travel to the remaining windup and stopping short of
the target through collision sweeps. Twelve checks verify actual chain contact,
bounded travel, and equal displacement at normal/4x haste with 0.2-second and
120-Hz steps. **272 focused checks, 760 scenario checks, and 98 interruption
checks pass**. This closes a high-haste movement mismatch; it does not replace
the still-open full continuous-motion visual release gate.

Storm status presentation now distinguishes actual pins from stun immunity:
normal victims show grounding tethers and a closed sigil; immune victims show
open slow arcs without a cage. Both retain the timed vulnerability mark. The
enemy owns these indicators across retrieval and weapon swaps; redundant runtime
cages were removed. Three new checks cover normal, immune, and expired visual
states. **260 focused checks, 760 scenario checks, and 361 mage assertions pass**.
Phase captures now mix normal and immune Storm victims. Dragonbone's reduced
maximum-stack panel was inspected after the preceding indicator changes.

Dragonbone's enemy-owned armor indicator now pulses on refresh, splits at the
configured cap, emits one cap-reaching fracture, and fades during the last
0.3 seconds of the actual debuff. Repeated capped hits refresh without replaying
the fracture. Visual crack count is bounded independently of configurable
gameplay stacks. Three new checks cover these transitions and expiration.
**257 focused checks, 760 scenario checks, and 361 mage assertions pass** after
the shared enemy change. The phase capture includes an explicitly labeled
maximum-stack status panel for both effect qualities.

Dungeon/armory integration audit now verifies actual enemy damage from all ten
fighter active slots, plus charged walk-in pickup and activation/spending from
all ten armory wall displays. Both active-item and armory suites pass. A real
room rebuild test exposed a non-campaign bug: frenzy was lost with the old
player node because only campaign party snapshots carried it. Room snapshots
now preserve remaining frenzy duration and all three modifiers. The rebuilt
player is distinct, retains its commitment, and takes 20 actual damage from a
10-damage incoming hit. The active-item integration suite passes after the fix.

`tests/fighter_interruption_test.gd` adds **98 passing checks**. Every item is
interrupted during anticipation by focus loss, Escape, input lock, and unequip;
the tests then advance 1.5 seconds and require no delayed damage or pending
attack state. Trident, Sling, Crossbow, and Umbral targets are also freed only
after actual launch: committed shots terminate safely, and Trident stays
physically recoverable. Runtime removal while Archon carries a victim or Umbral
steals speed clears target controls and the player's haste immediately. These
are lifecycle tests, not proof of all active/recovery animation interruptions or
full dungeon scene-transition behavior. No runtime fix was required for these
newly tested paths; `git diff --check` remains clean.

Umbral tether expiry/death/range breaks now split and fade the ribbon using a
bounded effect record and cached endpoint. Slow and haste are removed immediately;
the visual never retains a target or gameplay contribution. Repeated removal
does not duplicate the break, and owner/scene cleanup suppresses new break effects.
Moving with actual stolen speed adds restrained elongated shadow traces, scaled
by capped haste; immobile targets grant none. Enemy feet retain a small slow arc.
**254 focused checks and 760 scenario checks pass**. Phase captures now include
Umbral moving-haste and expired-tether states for visual review.

Demon frenzy presentation now belongs to the player alongside the commitment
status: successful hits surge the aura, actual incoming damage fractures it,
the final second dims, and natural expiry emits a short fading release cue.
Swapping away does not hide those warnings. The warning displays the configured
incoming multiplier rather than hard-coding x2. Presentation timers do not alter
damage, mitigation, or haste. Four added assertions cover refresh, actual-damage
feedback, expiry, and complete timer cleanup. **252 focused checks, 760 scenario
checks, and the neutral-item regression pass**. These new transitions still need
their crowded continuous-motion visual review.

Summon placement audit found that the player destination helper did not validate
the beast's whole footprint and could relocate conversion away from its corpse.
Bowstaff now performs a bounded corpse-local search, checks an eight-pixel body
footprint against solid terrain, respects the room sanitizer, and requires a
walkable reachable navigation cell when navigation is available. If every local
position is invalid, no collider is enabled and excess energy dissipates; the
conversion fragment count reflects actual successful spawns. New tests cover
wall-adjacent footprint clearance and fully obstructed ground. **248 focused
checks, 760 scenario checks, and the fighter arsenal regression pass**.

Curse contact now flashes a sinking rune; death conversion draws separate
corrupted fragments matching the number actually spawned, while capped excess
energy dissipates independently. Reaver has one activation mantle per rampage
window and an expiry soul-light fade. Its duration indicator reads configured
duration instead of assuming six seconds. All transitions reuse the bounded
effect pool and retain essential shapes in reduced mode. New assertions verify
conversion counts, overflow feedback, and single activation under crowd kills:
**245 focused checks and 760 scenario checks pass**. The new status capture
script produces both qualities; the reduced transition sheet was inspected.
Crowded continuous-motion review remains outstanding.

Bowstaff beasts now unfold a directional, limbed silhouette, anticipate their
bites, show fang contact at the pre-knockback damage point, and collapse into ink
near expiry. Reduced effects retain silhouette, windup, and contact while omitting
decorative motes. Emergence, windup, dissolve timing, damage coefficient, speed,
and attack interval are configurable. Pooled reuse resets contact feedback.
Dynamic bodies no longer mask walls in beast contact ray queries. The focused
suite now passes **242 checks**, the scenario matrix passes **760**, and the
neutral-item regression passes. `fighter_beast_visual_capture.gd` generates
normal/reduced enlarged phase sheets; the normal sheet has been inspected.
These stage captures do not yet prove continuous-motion or crowded summon
readability at native scale; that remains part of the release gate.

Hammer and Shield now retain post-impact recovery poses instead of disappearing
at contact. Their configurable durations scale with effective attack haste;
Hammer rebounds toward its ready position and Shield retracts after the bash.
Recovery is presentation-only (no extra hidden cooldown), so kill-refresh and
immediate chain windups remain usable. Unequip, focus loss, Escape, input locks,
owner death, and replacement actions clear the pose. Twelve focused duration,
haste, expiry, unequip, and focus checks bring the focused suite to **232 passing**;
the **760** scenario checks still pass. Phase captures now sample Hammer/Shield
during actual recovery rather than only long after they have returned to idle.

Current release gate: **mechanics substantially implemented; visual sign-off is
still open**. The notes below record successive increments; later verified work
supersedes earlier statements about pending implementation. Unchecked combined
mechanic/animation goals are not a claim that their mechanics are absent.

`tests/fighter_phase_capture.gd` now generates 20 three-panel captures covering
anticipation, contact/flight, and post-attack state at both effect qualities.
The harness advances nested damage numbers on the simulated clock, so expired
feedback does not misleadingly persist in recovery panels. Hammer's impact now
retains a full splash-radius boundary alongside its expanding contact ring;
reduced effects preserve those boundaries. Normal Hammer and Bowstaff phase
captures have been inspected. These still images are not a substitute for
continuous-motion review or final authored recovery animation.

Latest verification after the impact-rendering changes: 220 focused checks and
760 scenario checks pass; all 20 phase captures generate successfully, and
`git diff --check` is clean. Remaining visual work includes Hammer/Shield recovery,
summon emergence/expiration, and weapon-specific status transitions in crowds.

`tests/fighter_production_test.gd`: 220 checks passing. Covers actual curse deaths
from other sources, lethal first strikes, overlap deduplication, curse refresh/
expiry, simultaneous deaths at the global beast cap, single sling possession,
parry-cycle deduplication and baseline preservation, finite return/lifetime,
per-target Reaver critical rolls and kill ownership, rampage cap/expiry, and
beast wall collision/contact blocking/lifespan.

`tests/fighter_scenario_matrix_test.gd`: 760 checks passing across all ten items,
empty/single/32-enemy rooms, normal/reduced quality, and 30/120 Hz caller steps.
It requires real damage in populated scenarios, identical total damage across
quality and step rates, bounded projectiles, pending-attack cancellation on
unequip, target despawn during a fresh activation, and battlefield cleanup on owner death. This does not replace visual
review, all weakpoint cases, or the remaining target-death interruption cases.

Projectile and impact records now use bounded reuse pools. Tests prove record
identity reuse, fresh attack/effect state, and a 32-effect bound under 200 burst
requests. These complement the existing reusable beast-node pool.

Archon carry ownership is now per projectile, not per weapon runtime. A victim
can belong to one moving bolt; other bolts still damage and count it without
reattaching it. Five overlapping-shot checks verify distinct control sources,
exclusive attachment, independent release, and unequip cleanup. All 760 scenario
assertions continue to pass. Trident's acquisition text now correctly describes
the stun-window vulnerability separately from the retrieval requirement.

All ten items now participate in shared-health weakpoint tests. Cached targeting
includes open Colossus parts; closed parts are excluded, and damage/status/pierce
identities resolve to the owning body. Two open parts receive one direct hit per
attack, Hammer excludes the direct body from splash, Archon cannot carry the
immobile core, and Umbral grants no speed from immobile parts. These add 22 checks;
all 720 scenario assertions still pass after the targeting changes.

All ten basic/special damage coefficients and cooldowns are now authored in
`data/fighter_active_items.json`, with progression scaling applied after authored
values. Tests modify both values for every item and verify runtime tuning follows.
Umbral projectile speed/ranges/pierce limits and ranged release fractions are also
data-configurable. The options label is now `Combat Effects`, reflecting its
shared use by fighter and mage visuals. All 760 current scenario assertions and
the existing fighter arsenal regression pass after the tuning migration.

Reduced-quality captures for Demon, Dagger, Umbral, and Sling have been inspected.
Core silhouettes and frenzy/wound feedback remain visible; projectile silhouettes
and full phase captures still need refinement before visual sign-off.

Projectile refinement now gives Umbral a luminous-edged arrow, Archon a heavy
metal bolt with pierce-pressure rings, and the flying Trident a three-pronged
silhouette. Reduced mode trims decorative trails and extra frenzy rays without
removing weapon shapes or the player-owned frenzy warning. Shadow tethers gain
a restrained light edge and directional transfer pulse. All 20 captures were
regenerated; revised Umbral and Archon reduced captures were inspected. The 760
scenario assertions still pass. Full animation-phase review remains outstanding.

Native equipment changes now retain fighter runtimes and reuse them on
re-equipping. A four-check real player-setup test verifies deployed Trident
possession survives swaps and still requires physical retrieval. Pending attacks
are cancelled on unequip and carried bodies are released. Armory regression passes.

`tests/fighter_visual_capture.gd` generates 20 normal/reduced crowd captures in
`build/fighter_production_*.png`. Initial inspection of Trident's preview and
Bowstaff's sweep exposed verbose overlapping damage captions. Fighter hits now
use compact numbers; the repeated Bowstaff capture is clearer and the damage-popup
regression passes. These are initial review artifacts, not sign-off of all ten
animations or all attack phases; full visual review remains outstanding.

The next visual increment replaces generic melee/ranged lines with distinctive
staff runes, dagger/blade profiles, a crescent scythe head, a shield plate,
hammer head, curved bows, and a rotating sling pocket. Critical contacts now
trigger a distinct local burst. All 20 captures were regenerated; scythe, hammer,
and shield normal captures were inspected after the silhouette changes. Full
normal/reduced inspection and phase-by-phase animation review are still pending.

Additional verified mechanics: Archon sweeps its travel segment, orders contacts,
increases damage only for subsequent victims, caps carries, excludes heavy
victims from displacement, stops at solid terrain, and clears carry controls on
termination. Umbral uses swept contacts and normal-speed-derived capped haste;
repeat hits refresh without duplicating contributions, and death, despawn,
expiry, distance breaks, and unequip clear both slow and haste.

Dragonbone armor and Storm vulnerability now belong to the enemy and resolve
once in `receive_hit`, including other attackers and damage-over-time sources.
The shared armor set is capped at six stacks, refreshes as a whole, and expires
as a whole. Effective armor has a configurable floor. Nonnegative armor uses
`100 / (100 + armor)`; negative armor uses `2 - 100 / (100 - armor)` for a bounded
damage bonus. These combat modifiers affect all incoming damage types, before
existing boss durability limits. Base armor defaults to zero, preserving
unaffected enemies' existing damage values.

Storm control and vulnerability have the same window: normal enemies get full
duration, bosses get 30%, and explicitly stun-immune enemies are slowed to 65%
speed instead of stopped while retaining the timed vulnerability. Retrieval
does not remove either status. Pinned nonimmune enemies resist hit knockback.
Enemy-owned icons keep these statuses visible even after the weapon is swapped.
The mage production regression suite also passes all 361 assertions after this
shared damage-pipeline change. Full visual review remains pending.

Demon frenzy is now player-owned and included in party-state transfer. It
refreshes without stacking, applies damage and basic-attack haste once, and
doubles actual post-mitigation enemy/environmental damage before lethal-save
checks. Removing the weapon runtime cannot remove its drawback while retaining
its benefit. The player displays remaining duration and the incoming-damage
penalty even after swapping. Tests cover refresh, expiry, mitigation, runtime
removal, and party-state transfer; final animation-speed/contact verification
still belongs to the pending shared attack-timeline work.

Hammer now has a scheduled windup, one direct victim excluded from splash, and
one follow-up decision per whole impact (including splash kills). Follow-ups
use fresh attack IDs, nearest reachable targets, collision-swept short lunges,
and a configured chain cap. No reachable target leaves the attack refreshed.
Tests verify anticipation, direct/splash overlap, crowd nonbranching, nonlethal
termination, interruption, bounded sequences, and wall exclusion.

Shield now schedules contact after a short collision-swept forward drive. Its
frontal hit shoves each surviving victim once; heavy enemies receive reduced
displacement. It grants neither immunity nor input lock. Tests verify anticipation,
front/rear exclusion, resistant targets, interruption, and walls stopping both
the player and shoved victims. Procedural anticipation indicators are present;
full authored animation, recovery, reduced-quality review, and the full cross-item
timing matrix remain pending.

Staff, Demon Blade, Dragonbone Dagger, and Reaver now use an authoritative
anticipation/active/recovery sweep timeline derived from the actual effective
attack interval. A moving radial weapon indicator shares that timeline; contacts
are resolved only in the angular slice traversed during the current simulation
step. Dagger specials use two distinct attack identities. New checks cover all
four weapons at contact, recovery, interruption, and accelerated attack speed.
Reach, arc, and phase fractions are configurable. Reduced mode omits decorative
trails but preserves the weapon/contact indicator and all gameplay queries.
Enemy discovery is cached at 0.1 seconds with immediate spawn observation.
Generic fighter activation bursts were removed because they appeared before
actual contact. Full visual review and cross-frame-rate coverage remain pending.

Sling flight now advances at fixed 120 Hz simulation steps, with limited turning,
cached journey targets, swept contacts, and terrain checks. Its return slows near
the catch point to prevent endless tight orbits, opens a configurable timed
parry window, and uses a distinct return color, contracting ring, and damage-tier
lights. Verified actual impact damage is 1x, 2x, 3x after consecutive parries;
stored baseline damage is unchanged. Return position and remaining parry time
match across different caller frame sizes. Broader crowded visual review and
the remaining projectile/target-lifecycle matrix are still pending.

Trident now has pre-release anticipation, a landing-radius preview, and an arcing
flight indicator driven by the same selected destination. Wall-aware landing
resolution adds retrieval clearance; disconnected navigation regions fall back
to the player's reachable position. Flight rechecks newly obstructed segments.
Possession blocks further throws and melee use while the weapon is away;
retrieval requires proximity and unobstructed contact. Focus/Escape interruption
before release cancels cleanly. Verified tests cover preview/launch agreement,
no early launch, possession, interrupted aiming, wall fallback, and disconnected
destinations. Full input/visual review and native-equipment swap persistence
remain pending.

Crossbow, Umbral Bow, and Sling now schedule launch anticipation, one committed
release, and recovery using the effective attack interval. Tests cover no early
projectile, aim commitment, single release, and interruption for each. Projectile
travel excludes the pre-release portion of a long simulation frame. Beast summons
now reuse a bounded scene-local pool; retirement hides them, removes their active
membership, and disables physics/collision. A full 24-beast retire/redeploy cycle
reuses every node without accumulating collision shapes. Neutral summons retain
their existing nonpooled lifecycle. Additional projectile/effect pooling and full
visual QA remain pending.

Archon and Umbral still require full weakpoint coverage, animation/quality
review, bounded shared targeting, and all interruption cases before sign-off.

Existing fighter arsenal and neutral active-item suites also pass. Fighter
configuration data now exists in `data/fighter_active_items.json`; curse, sling,
Reaver, Archon, and Umbral limit values are wired in. Remaining values are planned configuration
for subsequent implementation, not evidence of completed mechanics.

Beasts now use collision-aware navigation, a 0.2-second target acquisition
interval, and a visible attack windup. Pooling, full lifecycle/swap coverage,
weakpoint handling, and normal/reduced visual review remain pending.

The user's ten-item specification is the acceptance contract. This plan preserves
current dungeon drops, dev-mode choices, and armory walk-in equipment testing.
It does not replace the ordinary fighter class kit with a different acquisition
system. The same item mechanics must work through both armory and dungeon paths.

## Goal 1 — Authoritative combat foundation

- [x] Put damage, timing, ranges, durations, stack caps, summon limits, resistance,
  and cooldowns in configurable fighter-item data.
- [x] Give each attack a unique identity and explicit anticipation, contact,
  active, and recovery phases. Derive visuals and damage from that same clock.
- [x] Scale the entire attack timeline with effective attack speed, without
  applying haste twice. Damage must not precede the visible contact.
- [x] Deduplicate hits per attack and actual enemy body, including boss weakpoints.
- [x] Resolve target-owned armor and vulnerability in one damage pipeline so
  eligible attacks from other sources benefit exactly once.
- [x] Cache targeting queries; use swept projectile collision and collision-safe
  movement. Reuse bounded projectile, summon, and impact records.
- [x] Define cleanup on interruption, death, unequip, class swap, focus loss,
  and scene changes. Preserve Demon frenzy's commitment across weapon swaps.
- [x] Keep authoritative collision, damage, and status timing unchanged at
  reduced visual quality. Preserve effect boundaries and essential indicators.

## Goal 2 — Melee statuses and feedback

### Eldritch Bowstaff

- [x] One curse stack per directly struck enemy per swing; cap and refresh.
- [x] Resolve cursed deaths exactly once regardless of killer, including damage
  over time. Preserve the killing strike's stack when that strike is eligible.
- [x] Spawn one temporary beast per remaining stack below a global summon cap,
  on valid reachable ground. No queued or invisible overflow summons.
- [x] Beasts acquire enemies and attack independently without applying curses.
- [x] Show contact glyphs, readable stack marks, separate beast emergence,
  dissipated overflow energy, feral contact attacks, and expiry.

### Demon Blade

- [x] Successful damage activates or refreshes one nonstacking frenzy.
- [x] Offensive damage and haste apply once; incoming damage doubles once.
- [x] Frenzy and its vulnerability persist until normal expiry after swapping.
- [x] Damage rule: double post-mitigation incoming damage from both enemies
  and environmental hazards; do not amplify healing or non-combat health adjustments.
- [x] Crimson feedback communicates refresh, vulnerability, and remaining time;
  fastest attacks still retain visible anticipation/contact/recovery.

### Dragonbone Dagger

- [x] Each distinct strike adds one capped armor-reduction stack and refreshes
  the entire set; repeated overlap does not add stacks.
- [x] Implement real effective-armor reduction with a configurable armor floor,
  not an independently multiplied dagger-only damage bonus.
- [x] Shared target stack set across attackers; all eligible damage benefits.
- [x] All stacks expire together and restore armor. No implicit bleed damage.
- [x] Show puncture contact, progressive armor cracks, max-stack feedback,
  refresh pulse, and clean expiration.

### Grim Reaver

- [x] Broad, accurate cleave; one hit and an independent critical roll per enemy.
- [x] Only scythe-attributed kills grant rampage stacks. Multiple kills from one
  sweep each contribute once, up to the cap, and refresh duration.
- [x] Clamp total critical chance; no excess-chance damage conversion or
  additional movement/attack speed.
- [x] Show matched sweep coverage, distinct critical impact, activation mantle,
  stack lights, and expiration.

## Goal 3 — Projectiles, possession, and mobility transfer

### Storm Trident

- [x] Preview a reachable landing point, flight arc, and exact impact radius.
- [x] Visible flight precedes impact damage and source-owned electrical pin.
- [x] Double damage applies once only during the control window; retrieval does
  not clear enemy statuses.
- [x] Embedded possession blocks subsequent throws until physical retrieval.
- [x] Boss rule: reduced-duration control/stagger and an explicitly
  timed vulnerability; stun-immune enemies retain vulnerability but are not
  falsely shown as immobile.
- [x] Invalid landing fallback uses the near side of terrain or the fighter's
  current position for invalid navigation/sanitizer results;
  interruption must never permanently lose the weapon.
- [x] Show ground sigils, storm vulnerability marks, and retrieval locator.

### Valkyrian Sling

- [x] One active projectile per owner; finite ricochet cycles and total lifetime.
- [x] Return when the hit quota is reached or targets disappear; harmless catch
  after a missed parry.
- [x] Timed return parry registers once per return, using an elapsed-time window
  rather than a frame count. Preserve the original launch damage.
- [x] Each parry adds exactly one original-damage unit, never compounds damage.
- [x] Show curved transitions, distinct return color, approach cue, contracting
  parry ring, and accumulated damage tiers.

### Archon Crossbow

- [x] Sweep the entire bolt path against enemies and solid terrain in collision
  order; damage each new body once.
- [x] Each pierce increases subsequent-target damage, never re-damages victims.
- [x] Carry eligible victims up to a cap; heavy/immovable enemies contribute to
  pierce count without being displaced.
- [x] Collision-safe carried movement, readable attachment offsets, finite range.
- [x] On termination/interruption release every survivor at a valid position
  and clear all movement restrictions, including after target despawn.
- [x] Show heavy windup/release, contact bursts, accumulating pressure, and
  terrain termination/recovery.

### Umbral Bow

- [x] One timed tether per enemy; repeat hits refresh without duplicate haste.
- [x] Compute steal from unmodified normal enemy speed; immobile enemies grant
  zero. Cap total player speed gain from multiple targets.
- [x] Remove each contribution immediately on death, despawn, expiry, distance
  break, or owner cleanup. Never physically drag either endpoint.
- [x] Show readable ground ribbons, directional transfer pulses, slow wisps,
  haste afterimages, and tether break.

## Goal 4 — Collision-safe impact attacks

### Divine Hammer

- [x] One authoritative impact point with direct damage and radiant splash.
- [x] Overlap rule: the primary takes direct damage; other targets
  take splash once. The primary does not also receive splash.
- [x] Each smash that kills one or more enemies schedules exactly one follow-up.
  Preserve attribution and cap the entire chain, without branching.
- [x] Revalidate nearest reachable target before each compressed visible windup;
  use a short collision-safe lunge, never teleport through terrain.
- [x] No valid next target ends the chain with the attack refreshed.
- [x] Show overhead windup, radius-matched ring, kill-energy return, chain
  rebound/lunge, and final recovery.

### Sentinel Shield

- [x] Front-only impact area, modest damage, one shove per target per bash.
- [x] Collision-safe short forward drive, without automatic invulnerability.
- [x] Resistance scales displacement; heavy enemies receive reduced movement
  or brief stagger. Obstacles stop both player and enemy movement.
- [x] Interrupted bash always releases movement locks.
- [x] Show compact windup/drive, shield-face contact, resistant-hit feedback,
  skid/recoil, and recovery.

## Goal 5 — Verification and release gate

For every item, record automated results and visual review separately:

- [x] Empty room and single enemy.
- [x] Dense crowd and simultaneous deaths.
- [x] Maximum stacks, summon/projectile caps, and long-running use.
- [x] Interrupted anticipation, active phase, and recovery.
- [x] Target death/despawn while a projectile, tether, or carry is active.
- [x] Weapon/class swapping, player death, and scene transitions.
- [x] Walls, corners, narrow passages, unreachable targets, and heavy bosses.
- [x] Minimum/maximum attack speeds and multiple simulation step rates.
- [x] Normal/reduced effects produce identical gameplay outcomes.
- [x] Actual dungeon activation/drop path and armory walk-in item path.
- [x] Mage, neutral-item, base-fighter, collision, and armory regression suites.
- [x] Visual contact timing, boundaries, status readability, and recovery in
  both single-target and crowded scenes at both effect qualities.

Completion requires functional checks first, then visual polish. A screenshot,
successful parser check, or isolated helper test is not sufficient proof that a
weapon meets its contract. Keep unchecked work visible rather than declaring the
whole arsenal complete after only shared-system changes.

## Initial code audit

The existing `slasher_fighter_arsenal.gd` is a prototype, not this completed plan:

- Curses have no stack cap and summon spawning has no global limit.
- Frenzy writes generic player buffs as well as its own damage adjustment,
  requiring an audit for duplicate multiplication and swap ownership.
- Reaver rolls a critical before iterating targets and also grants rampage from
  unrelated external kills.
- Archon uses endpoint proximity checks and direct position assignments for
  carried victims, without wall termination.
- Sling permits multiple launches and has no total journey lifetime cap.
- Hammer only supports a restricted repeat and does not implement the intended
  bounded, nonbranching follow-up sequence.
- Umbral grants a flat bonus per target without a total cap, normal-speed
  derivation, or distance break.
- Most melee hits resolve immediately while their history trail uses an
  independent fixed duration. Shared attack timing must precede animation polish.
