extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var defenses := {"armor_class":12,"evasion":14,"threshold":3,"aegis_fire":2,"aegis_all":0}
	var miss := CombatResolver.resolve_attack(7, 4, 10, 0, "fire", defenses)
	_expect(not miss.hit, "attack total at 11 should miss Evasion 14", failures)
	_expect(miss.reaction_eligible, "attack total at 11 should provoke AC 12 reaction", failures)
	var clean_hit := CombatResolver.resolve_attack(15, 2, 8, 0, "fire", defenses)
	_expect(clean_hit.hit and not clean_hit.reaction_eligible, "high roll should hit without provoking reaction", failures)
	_expect(int(clean_hit.damage) == 6, "fire Aegis should subtract 2 damage", failures)
	var thresholded := CombatResolver.resolve_attack(15, 2, 3, 0, "physical", defenses)
	_expect(thresholded.blocked_by_threshold and int(thresholded.damage) == 0, "Threshold should stop damage that does not exceed it", failures)
	var penetrated := CombatResolver.resolve_attack(15, 2, 5, 2, "fire", defenses)
	_expect(int(penetrated.damage) == 5, "Penetration should reduce Threshold and typed Aegis", failures)
	var layered_aegis := CombatResolver.defense_snapshot({"aegis_all":2,"aegis_fire":3})
	_expect(int(layered_aegis.aegis_fire) == 5, "Global and typed Aegis should stack", failures)
	var items := GameBalance.get_items()
	_expect(items.size() == 52, "expected all 52 upgraded items", failures)
	var seen_rules: Dictionary = {}
	for item_id in items.keys():
		var item: Dictionary = items[item_id]
		var rules := String(item.get("rules_text", ""))
		_expect(not rules.is_empty(), "%s has no rules text" % item_id, failures)
		_expect(not seen_rules.has(rules), "%s repeats another item's rules" % item_id, failures)
		seen_rules[rules] = item_id
		_expect(item.get("effects", []) is Array and not item.get("effects", []).is_empty(), "%s has no mechanical effect" % item_id, failures)
		var modifiers: Dictionary = item.get("modifiers", {})
		for removed_stat in ["attack_bonus", "spell_power", "defense", "block_bonus"]:
			_expect(not modifiers.has(removed_stat), "%s still uses legacy %s" % [item_id, removed_stat], failures)
	var quickstep := RunState.new()
	quickstep.add_inventory_item("quickstep_charm", 1)
	_expect(quickstep.get_derived_stat("movement") == 1, "Quickstep static movement modifier failed", failures)
	_expect(quickstep.get_contextual_item_modifier("evasion", {"moved":true}) == 2, "Quickstep moved Evasion effect failed", failures)
	var keen := RunState.new()
	keen.add_inventory_item("keen_edge_oil", 1)
	_expect(keen.get_derived_stat("penetration") == 1, "Keen Edge static Penetration failed", failures)
	_expect(keen.get_contextual_item_modifier("penetration", {"attack_index":0}) == 2, "Keen Edge first-attack Penetration failed", failures)
	var mantle := RunState.new()
	mantle.add_inventory_item("wyvernscale_mantle", 1)
	_expect(mantle.get_derived_stat("aegis_poison") == 4, "Wyvernscale typed Aegis failed", failures)
	if failures.is_empty():
		print("Layered combat stats and 52-item uniqueness validation passed.")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(value: bool, failure: String, failures: Array[String]) -> void:
	if not value: failures.append(failure)
