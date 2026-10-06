# Armory testing ground

Open **Hearth → Armory → Enter testing ground**. The entrance is in the fixed bottom bar, next to **Buy 4 Supplies**, and does not require scrolling through equipment. Choose a class, equipment, level, class progression, and items, then select **Apply build and fight**. Press **B** or **Escape** to reopen the editor; **R** restores health and resource, clears cooldowns and effects, and replaces the targets. **Return to armory** reopens the Hearth armory.

All six classes, 24 existing weapons, 52 existing expedition items, 12 Hearth relics, and **all five alternate Mage kits** are available without campaign unlocks. That makes 29 equipment selections. Existing weapons keep their current standard class abilities and equipment stats. See [Mage builds](MageBuilds.md) for Winterglass Codex, Stormbringer's Grimoire, Grimoire of Gravity, and Mirrorbound Manuscript. Non-Mage alternate kits and proposed item/relic rules in the [design packet](equipment-design/README.md) remain proposals.

Choose **Single target**, **Cluster**, **Boss target**, or **Live enemies** from the floor controls. Targets have infinite durability and show damage and hit counts. Hits produce floating damage numbers with explicit damage types and colors. Fire ticks distinguish **Burn** and **Ground** from **Lance** and **Blast**. The HUD totals damage by type. Popups show actual damage after boss mitigation, not the requested attack damage. At most six popups per target overlap, while every hit remains included in totals. Boss targets retain the current per-hit damage cap and temporary damage shield. DPS includes target damage divided by elapsed practice time, including idle time; reset before comparing builds. Live enemies attack and can die, and also show typed popups; this mode is for practical combat rather than dummy DPS. Player defeat resets the floor automatically.

The editor pauses combat, effect timers, and damage popups. Applying a build starts a fresh arena and restores health and resource. Level and milestone options use existing class progression. All alternate Mage kits transfer damage-coefficient and cooldown multipliers from the corresponding progressed Mage slots. They do not inherit standard-kit mechanics such as Force Prism or projectile echoes from class progression. Selected items apply their current implemented effects; class-specific effects may be ineffective on another class or a new kit.

Testing uses a separate run and campaign state. It does not unlock campaign equipment, start an expedition, grant rewards, or save a training build. Returning discards the visit's selections and preserves the real campaign. All five alternate Mage kits are available in this sandbox only; acquisition and persistent armory recovery require a later implementation decision.

## Tome of the Pyromancer

Select **Mage → Tome of the Pyromancer**. It replaces all four action slots with fire abilities. The values below are **provisional playtesting values**, before progression and item modifiers. Normalized direct damage-rate checks at level 1 and a fully selected level-20 progression verify that Lance keeps up with the standard Mage, before adding Burn or ground damage. This does not establish final encounter balance.

| Slot | Ability | Prototype behavior |
|---|---|---|
| Basic / click | Ember Lance | Piercing fire projectile, 360 range, 0.18 s cooldown, 12 × spell power direct damage. Applies a four-second Burn. One Mana per cast that hits an enemy, regardless of pierced targets. |
| Special / Space | Conflagration | Target a point within 240 range using the mouse, or the right-stick direction on a controller. After 0.28 s, explode in a 100-radius circle for 20 × spell power. Costs one Mana; 0.9 s cooldown. Consumes nearby owned fire patches at cast time to widen the blast by 20% once. Consumes each affected enemy's owned Burn on detonation for 30% extra direct damage. |
| Defensive / Shift-click | Furnace Mantle | Arm a 0.6 s defensive window on a 0.6 s cooldown. Reduce the next hit by 60%, then apply Burn to enemies within 100 range. Uses the existing resource reward for prevented damage. No reflected direct damage or recursive hit triggers. |
| Movement / right-click | Cinder Trail | Relocate up to 300 along aim with 0.2 s landing protection. Free; 0.65 s cooldown. Leave one unlit trail for four seconds. Fire Ember Lance into or across it to ignite two patches, each lasting two seconds. |

Burn refreshes duration without stacking potency or delaying the next tick. It deals 1.2 × spell power every 0.5 s. Patches deal 2.5 × spell power every 0.25 s in a 36-radius circle. Secondary Burn and patch damage use boss durability but do not generate Mana, item hit effects, or further Burn. At most one unlit trail and two patches exist per caster. Projectile echoes cannot add Burn or ignite trails. Kit state disappears on reset or replacement.

Try a mobile **Lance/Burn** build for steady damage, then a **Trail/Conflagration** build: move through the intended fight lane, turn back to ignite the trail, and detonate the prepared ground when targets gather. Unlit trails show glowing embers. Ignited patches have animated flames and rising sparks. Conflagration has a filling perimeter, gathering flames, and an expanding explosion; Furnace Mantle has orbiting fire, and burning enemies visibly flame. Boundary rings still indicate the actual affected areas.

## Implementation and verification

The floor lives in `scenes/slasher/TestingGround.tscn` and `scripts/slasher/testing_ground.gd`; the kit is in `scripts/slasher/slasher_pyromancy.gd`. The floor's class equipment picker includes current Hearth weapons and the prototype tome without changing the campaign catalogue.

`tests/testing_ground_test.gd` verifies all class/equipment selections, item availability, editor pause, fire ignition direction, resource rules, Burn refresh and consumption, mitigation, reset cleanup, target durability, boss limits, live enemy spawning, campaign isolation, and return to the armory. `tests/testing_ground_visual_capture.gd` captures the editor and floor for layout inspection at 1280 × 720 and 960 × 540.

Final encounter balance still needs playtesting. The prototype reuses current Mage casting, animated fireball atlases, and fire-patch artwork. Training-only combatants report damage without changing normal expedition enemies.
