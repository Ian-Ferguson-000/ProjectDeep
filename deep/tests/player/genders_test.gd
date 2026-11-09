extends SceneTree

## Genders: every arriving recruit gets one (female or male) with a matching first
## name and pronouns, curated characters and old saves get one too, it saves, and
## the sprite lookup uses data/adventurer_sprites.json with a safe fallback.

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	var by_name: Dictionary = AdventurerContent.data().get("names_by_gender", {})
	var pronouns: Dictionary = AdventurerContent.data().get("pronouns_by_gender", {})
	_expect(
		(
			Array(by_name.get("female", [])).size() >= 10
			and Array(by_name.get("male", [])).size() >= 10
		),
		"adventurers.json needs names for both genders"
	)
	var seen := {}
	for wave in 4:
		var c := CampaignState.new()
		c.apply_post_tutorial_state("victory" if wave % 2 == 0 else "death")
		c.calendar_day += wave * 3
		for arrival in c.get_candidates():
			var candidate: CharacterRecord = arrival.adventurer
			_expect(
				candidate.gender in ["female", "male"],
				"%s arrived without a gender" % candidate.display_name
			)
			seen[candidate.gender] = true
			if candidate.definition_id.is_empty():
				_expect(
					Array(by_name.get(candidate.gender, [])).has(candidate.display_name),
					(
						"%s (%s) has a name from the wrong list"
						% [candidate.display_name, candidate.gender]
					)
				)
				_expect(
					candidate.pronouns == String(pronouns.get(candidate.gender, "")),
					(
						"%s (%s) has pronouns %s"
						% [candidate.display_name, candidate.gender, candidate.pronouns]
					)
				)
			var copy := CharacterRecord.from_dict(candidate.to_dict())
			_expect(
				copy.gender == candidate.gender,
				"Gender didn't save for %s" % candidate.display_name
			)
	# Generic recruits directly.
	var c2 := CampaignState.new()
	for i in 40:
		var member: CharacterRecord = c2._generic_character("warrior", 1000 + i)
		_expect(member.gender in ["female", "male"], "A generic recruit had no gender")
		seen[member.gender] = true
	_expect(
		seen.has("female") and seen.has("male"), "Only one gender ever arrived: %s" % [seen.keys()]
	)
	# Old saves: from pronouns, else name, else id.
	var old := {
		"id": "hero_000777", "display_name": "Mara", "class_id": "warrior", "pronouns": "she/her"
	}
	_expect(
		CharacterRecord.from_dict(old).gender == "female", "An old she/her record should be female"
	)
	old["pronouns"] = "he/him"
	_expect(CharacterRecord.from_dict(old).gender == "male", "An old he/him record should be male")
	old["pronouns"] = "they/them"
	var g1 := CharacterRecord.from_dict(old).gender
	var g2 := CharacterRecord.from_dict(old).gender
	_expect(
		g1 in ["female", "male"] and g1 == g2, "An old they/them record should get a stable gender"
	)
	# Sprites: no art set yet means the class's own sprite.
	_expect(
		SlasherSpriteLibrary.gendered_sprite_path("warrior", "female") == "",
		"No warrior art is set yet"
	)
	_expect(
		(
			SlasherSpriteLibrary.player_frames("warrior", "female") != null
			and SlasherSpriteLibrary.player_frames("warrior", "male") != null
		),
		"Gendered lookups should fall back to the class sprite"
	)
	_expect(
		(
			SlasherSpriteLibrary.player_frames("warrior", "female")
			== SlasherSpriteLibrary.player_frames("warrior")
		),
		"With no art set, both genders should share the class sprite"
	)

	if failures.is_empty():
		print("GENDERS_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)
