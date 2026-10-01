extends SceneTree

const STORY_EVENTS := preload("res://scripts/game/story_event_service.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	_expect(NarrativeContent.validate().is_empty(), "Nation data did not validate.", failures)
	_expect(NarrativeContent.nation_name("nordia") == "Nordia" and NarrativeContent.nation_name("zarabia") == "Zarabia", "Founding nation names are unavailable.", failures)
	var curated_nations: Dictionary = {}
	var class_nations: Dictionary = {}
	for definition_value in AdventurerContent.curated():
		var definition := Dictionary(definition_value)
		var nation_id := String(definition.get("nation_id", AdventurerContent.nation_for_definition(String(definition.get("id", "")))))
		curated_nations[nation_id] = true
		var class_id := String(definition.get("class", ""))
		if not class_nations.has(class_id): class_nations[class_id] = {}
		class_nations[class_id][nation_id] = true
	_expect(curated_nations.size() >= 6, "The curated roster does not represent all six nations.", failures)
	_expect(Dictionary(class_nations.get("warrior", {})).size() > 1 and Dictionary(class_nations.get("mage", {})).size() > 1, "Nationality is still acting as a class restriction.", failures)
	var identity_campaign:=CampaignState.new();var fara:=identity_campaign._character_from_definition(AdventurerContent.definition("healer_fara"));var spirit_rhea:=identity_campaign._character_from_definition(AdventurerContent.definition("summoner_rhea"));var soren:=identity_campaign._character_from_definition(AdventurerContent.definition("warrior_soren"))
	_expect(fara.faith_id=="amari_open_hands" and spirit_rhea.faith_id=="amari_open_hands" and fara.nation_id!=spirit_rhea.nation_id,"Authored faith remains locked one-to-one to nationality.",failures)
	_expect(soren.doctrine_id!=String(NarrativeContent.nation(soren.nation_id).get("default_doctrine","")),"The curated roster lacks internal national dissent.",failures)
	_expect(String(NarrativeContent.dungeon_lore("forest").get("stage", "")) == "approach" and String(NarrativeContent.dungeon_lore("crypt").get("stage", "")) == "threshold" and String(NarrativeContent.dungeon_lore("balors_hell").get("stage", "")) == "prison", "Balor route narrative stages are incomplete.", failures)
	_expect(NarrativeContent.next_route_stage("forest") == "crypt" and NarrativeContent.next_route_stage("crypt") == "balors_hell" and NarrativeContent.next_route_stage("balors_hell").is_empty(), "Balor route does not terminate at its prisoner.", failures)
	_expect(STORY_EVENTS.validate().is_empty(), "Story event data did not validate.", failures)

	var campaign := CampaignState.new()
	var alden := campaign.create_tutorial_adventurer()
	_expect(alden.nation_id == "nordia" and alden.origin.contains("Nordia"), "Alden is not a structured Nordian character.", failures)
	var alden_copy := CharacterRecord.from_dict(alden.to_dict())
	_expect(alden_copy.nation_id == "nordia" and alden_copy.faith_id == "unaffiliated", "Character narrative identity did not round trip.", failures)
	var opening := STORY_EVENTS.lines("last_customer_opening", campaign)
	_expect(opening.size() == 3 and String(opening[0].get("speaker", "")) == "The Keeper", "Keeper opening did not load from the story event registry.", failures)
	_expect(STORY_EVENTS.can_play("last_customer_opening", campaign), "Unplayed opening was incorrectly blocked.", failures)
	STORY_EVENTS.mark_played("last_customer_opening", campaign)
	_expect(not STORY_EVENTS.can_play("last_customer_opening", campaign), "Once-ever opening remained replayable.", failures)
	var threshold := STORY_EVENTS.lines("balor_threshold", campaign, "default", {"hero_name":"Brina","hero_portrait":"portrait.png"})
	_expect(threshold.size() == 2 and String(threshold[1].get("speaker", "")) == "Brina" and String(threshold[1].get("portrait", "")) == "portrait.png", "Story event substitutions failed.", failures)

	var death_campaign := CampaignState.new()
	death_campaign.apply_post_tutorial_state("death")
	var victory_campaign := CampaignState.new()
	victory_campaign.apply_post_tutorial_state("victory")
	_expect(death_campaign.contribution > 0, "Alden's death left no Contribution.", failures)
	_expect(victory_campaign.contribution > death_campaign.contribution, "Alden's victory should create more opening Contribution than his death.", failures)
	_expect(not death_campaign.former_keeper_encounter_pending and not victory_campaign.former_keeper_encounter_pending, "A tutorial outcome still transfers ownership away from the Keeper.", failures)
	_expect(death_campaign.keeper_journal_unlocked and victory_campaign.keeper_journal_unlocked, "The Keeper's first record was not unlocked.", failures)
	var candidates := victory_campaign.get_candidates()
	var nations: Dictionary = {}
	for candidate in candidates: nations[candidate.adventurer.display_name] = candidate.adventurer.nation_id
	_expect(nations.get("Brina", "") == "nordia" and nations.get("Eamon", "") == "zarabia", "Brina and Eamon do not establish the Nordian/Zarabian contrast.", failures)

	var expedition := ExpeditionState.new()
	expedition.begin(["test"], "forest")
	_expect(expedition.reward_checkpoint("forest:1", 1), "First checkpoint did not reward progress.", failures)
	_expect(not expedition.reward_checkpoint("forest:1", 1) and expedition.carried_contribution == 5, "Checkpoint Contribution was duplicated.", failures)
	var restored := ExpeditionState.from_dict(expedition.to_dict())
	_expect(restored.carried_contribution == 5, "Expedition Contribution did not round trip.", failures)

	var migrated := CampaignState._migrate_dict({"version":9,"tutorial_phase":CampaignState.TUTORIAL_COMPLETE,"former_keeper_encounter_pending":true,"roster":[]})
	_expect(int(migrated.get("version",0)) == CampaignState.SAVE_VERSION and not bool(migrated.get("former_keeper_encounter_pending",true)), "Legacy former-keeper state was not safely retired.", failures)

	if failures.is_empty():
		print("NARRATIVE_FOUNDATION_TESTS_PASSED")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)
