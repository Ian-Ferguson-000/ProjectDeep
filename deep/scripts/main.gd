extends Node

const StartScreenScene := preload("res://scenes/start/StartScreen.tscn")
const ClassSelectionScene := preload("res://scenes/class_selection/ClassSelection.tscn")
const ModeSelectionScene := preload("res://scenes/mode_selection/ModeSelection.tscn")
const TavernScene := preload("res://scenes/tavern/Tavern.tscn")
const ForestScene := preload("res://scenes/forest/Forest.tscn")
const CryptScene := preload("res://scenes/crypt/Crypt.tscn")
const AshenFarmsteadScene := preload("res://scenes/field/AshenFarmstead.tscn")
const SunkenMineScene := preload("res://scenes/mine/SunkenMine.tscn")
const EmberFoundryScene := preload("res://scenes/foundry/EmberFoundry.tscn")
const MoonlitGroveScene := preload("res://scenes/secret/MoonlitGrove.tscn")
const AbyssalArchiveScene := preload("res://scenes/secret/AbyssalArchive.tscn")
const SlasherForestScene := preload("res://scenes/slasher/SlasherForest.tscn")
const SlasherFarmsteadScene := preload("res://scenes/slasher/SlasherFarmstead.tscn")
const SlasherMineScene := preload("res://scenes/slasher/SlasherMine.tscn")
const SlasherFoundryScene := preload("res://scenes/slasher/SlasherFoundry.tscn")
const SlasherGroveScene := preload("res://scenes/slasher/SlasherGrove.tscn")
const SlasherArchiveScene := preload("res://scenes/slasher/SlasherArchive.tscn")
const SlasherCryptScene := preload("res://scenes/slasher/SlasherCrypt.tscn")
const SlasherProgressionOverlay := preload("res://scripts/slasher/slasher_progression_overlay.gd")

var run_state := RunState.new()
var all_gear_options: Array[GearData] = []
var current_scene: Node
var campaign: CampaignState
var tutorial_class_id := ""

const MARA_PORTRAIT := "res://assets/merchants/tavern_mara.png"
const ALDEN_PORTRAIT := "res://assets/roster_portraits/warrior_0.png"
const MAYOR_PORTRAIT := "res://assets/generated_characters/town_mayor.png"

func _ready() -> void:
	_ensure_input_actions()
	_build_gear_options()
	show_start_screen()

func _build_gear_options() -> void:
	all_gear_options = [
		GearData.create(
			"sword_shield",
			"Sword and Shield",
			1,
			true,
			2,
			"charge",
			"Reliable defense. Special: Charge in your facing direction and strike the first enemy.",
			"warrior",
			"block"
		),
		GearData.create(
			"greatsword",
			"Greatsword",
			3,
			false,
			0,
			"sweep",
			"Heavy damage with no shield. Special: Sweep all adjacent enemies.",
			"warrior",
			"none"
		),
		GearData.create(
			"spear_shield",
			"Spear and Shield",
			2,
			true,
			1,
			"brace",
			"Defensive reach. Special: Brace to hit the next enemy that approaches.",
			"warrior",
			"block"
		),
		GearData.create(
			"magic_missile_shield",
			"Magic Missile and Shield",
			3,
			true,
			2,
			"force_blast",
			"Balanced spell book. Special: Force Blast damages a target, pushes it back, and splashes nearby foes.",
			"mage",
			"block"
		),
		GearData.create(
			"fireball_fire_shield",
			"Fireball and Fire Shield",
			5,
			false,
			0,
			"flamethrower",
			"Wide offense. Fire Shield retaliates when hit. Special: Flamethrower burns a line ahead.",
			"mage",
			"retaliate"
		),
		GearData.create(
			"lightning_flash_step",
			"Lightning Bolt and Flash Step",
			3,
			false,
			0,
			"shockwave",
			"Mobile control. Flash Step slips backward when struck. Special: Shockwave stuns adjacent enemies.",
			"mage",
			"flash_step"
		),
		GearData.create("sunwood_staff", "Sunwood Staff", 2, false, 0, "", "Wisdom focus. Your class kit supplies Binding Light, Empower, Recover, and Dash.", "healer", "none"),
		GearData.create("tower_shield", "Tower Shield and Mace", 2, true, 2, "", "Heavy protection for Shield Bash, Retribution, Guard, and Leap.", "tank", "block"),
		GearData.create("spectral_dagger", "Spectral Dagger", 3, false, 0, "", "A precise weapon for Pierce, Assassinate, Evade, and Shadowstep.", "rogue", "none"),
		GearData.create("bond_staff", "Bondkeeper Staff", 2, false, 0, "", "A ritual focus for commanding and protecting your bonded wolf.", "summoner", "none"),
	]

func show_start_screen() -> void:
	_clear_scene()
	var start_screen := StartScreenScene.instantiate()
	current_scene = start_screen
	start_screen.setup(self)
	add_child(start_screen)

func begin_game() -> void:
	if campaign==null:return
	if campaign.is_tutorial_complete():
		campaign.ensure_tavern_cycle(); _select_first_available_character(); show_tavern("The company gathers around the expedition ledger.")
	else:
		campaign.tutorial_phase = CampaignState.TUTORIAL_DIALOGUE; campaign.save_atomic()
		show_tavern("", {}, _opening_tutorial_dialogue(), "tutorial_opening")

func get_save_slot_summaries()->Array[Dictionary]:return CampaignState.all_slot_summaries()

func continue_from_slot(slot:int)->void:
	campaign=CampaignState.load_or_new(slot);run_state=RunState.new();run_state.attach_campaign(campaign)
	if campaign.expedition.active:_resume_saved_expedition();return
	if campaign.is_tutorial_complete():
		campaign.ensure_tavern_cycle();_select_first_available_character()
		var restored_context:=campaign.pending_story_context;var restored_story:Array=[]
		if restored_context=="tutorial_epilogue":restored_story=_tutorial_epilogue(campaign.tutorial_outcome)
		elif restored_context=="former_keeper_confrontation":restored_story=_former_keeper_confrontation()
		show_tavern("" if not campaign.pending_settlement_summary.is_empty() else "Save Slot %d · The company gathers around the expedition ledger."%slot,campaign.pending_settlement_summary,restored_story,restored_context)
	else:campaign.tutorial_phase=CampaignState.TUTORIAL_DIALOGUE;campaign.save_atomic();show_tavern("",{},_opening_tutorial_dialogue(),"tutorial_opening")

func new_game_in_slot(slot:int)->void:
	campaign=CampaignState.new();campaign.save_slot=clampi(slot,1,CampaignState.SAVE_SLOT_COUNT);run_state=RunState.new();run_state.attach_campaign(campaign);tutorial_class_id="";begin_game()

func _resume_saved_expedition()->void:
	var living:=campaign.expedition.living_party_ids()
	if living.is_empty():campaign.resolve_expedition("death");campaign.save_atomic();_select_first_available_character();show_tavern("The saved expedition had no survivors. The memorial has been updated.");return
	run_state.active_dungeon_id=campaign.expedition.dungeon_id;run_state.active_play_mode=campaign.expedition.play_mode;run_state.last_play_mode=run_state.active_play_mode;run_state.current_floor=campaign.expedition.floor;run_state.gold=campaign.expedition.carried_gold
	var dungeon:=GameBalance.get_dungeon(run_state.active_dungeon_id);var slasher_config:Dictionary=Dictionary(dungeon.get("slasher",{}));run_state.max_floors=int(slasher_config.get("campaign_floors",dungeon.get("floors",1))) if run_state.active_play_mode==RunState.PLAY_MODE_SLASHER else int(dungeon.get("floors",1))
	run_state.select_active_character(living[0]);run_state.apply_tutorial_health_cap();_load_active_dungeon()

func advance_tutorial_from_tavern() -> void:
	var starter := campaign.create_tutorial_adventurer()
	starter.status = CharacterRecord.STATUS_AVAILABLE
	campaign.tutorial_phase = CampaignState.TUTORIAL_EXPEDITION
	if not campaign.begin_expedition([starter.id], "forest", RunState.PLAY_MODE_SLASHER, true): return
	run_state.active_character_id = starter.id
	run_state.set_class("warrior")
	var gear_options := _gear_options_for_class("warrior")
	var gear: GearData = gear_options[0] if not gear_options.is_empty() else null
	campaign.save_atomic()
	_begin_dungeon("forest", gear, RunState.PLAY_MODE_SLASHER)

func restart_tutorial_onboarding() -> void:
	if campaign == null or not campaign.expedition.tutorial_run: return
	var starter := campaign.restart_tutorial_expedition()
	if starter == null: return
	run_state.active_character_id = starter.id
	run_state.set_class("warrior")
	var gear_options := _gear_options_for_class("warrior")
	var gear: GearData = gear_options[0] if not gear_options.is_empty() else null
	campaign.save_atomic()
	_begin_dungeon("forest", gear, RunState.PLAY_MODE_SLASHER)

func get_selectable_class_ids() -> Array[String]:
	return ["warrior", "mage"] if not campaign.is_tutorial_complete() else campaign.unlocked_classes.duplicate()

func show_class_selection() -> void:
	_clear_scene()
	var class_selection := ClassSelectionScene.instantiate()
	current_scene = class_selection
	class_selection.setup(self)
	add_child(class_selection)

func choose_class(class_id: String) -> void:
	run_state.set_class(class_id)
	if not campaign.is_tutorial_complete():
		tutorial_class_id = class_id; _clear_scene(); var mode_screen := ModeSelectionScene.instantiate(); current_scene = mode_screen; mode_screen.setup(self); add_child(mode_screen); return
	var class_type := run_state.selected_class_name; show_tavern("The hearth is warm. The bartender lays out %s choices for the road ahead." % class_type)

func choose_tutorial_mode(mode: String) -> void:
	var starter := campaign.create_character(tutorial_class_id)
	campaign.tutorial_phase = CampaignState.TUTORIAL_EXPEDITION
	campaign.begin_expedition([starter.id], "forest", mode, true)
	run_state.active_character_id = starter.id; run_state.set_class(starter.class_id)
	var gear_options := _gear_options_for_class(starter.class_id); var gear: GearData = gear_options[0] if not gear_options.is_empty() else null
	campaign.save_atomic(); _begin_dungeon("forest", gear, mode)

func _select_first_available_character() -> void:
	var available := campaign.living_roster()
	if available.is_empty(): return
	run_state.active_character_id = available[0].id; run_state.set_class(available[0].class_id)

func show_tavern(message: String = "", arrival_summary: Dictionary = {}, story_lines: Array = [], story_context: String = "") -> void:
	_clear_scene()
	var tavern := TavernScene.instantiate()
	current_scene = tavern
	tavern.setup(self, run_state, _gear_options_for_class(run_state.selected_class_id), message, arrival_summary, story_lines, story_context)
	add_child(tavern)

func start_forest(gear: GearData) -> void:
	run_state.start_new_run(gear, "forest")
	_load_forest_floor()

func start_crypt(gear: GearData) -> void:
	if not run_state.is_crypt_unlocked():
		show_tavern("The crypt door is sealed. Clear the Forest Dungeon and reach level 5.")
		return
	run_state.start_new_run(gear, "crypt")
	_load_crypt_floor()

func start_dungeon(dungeon_id: String, gear: GearData, play_mode: String = RunState.PLAY_MODE_STRATEGY, requested_party: Array[String] = []) -> void:
	if not run_state.is_dungeon_unlocked(dungeon_id):
		show_tavern(String(GameBalance.get_dungeon(dungeon_id).get("unlock_text", "That expedition is locked.")))
		return
	if not run_state.dungeon_supports_mode(dungeon_id, play_mode):
		show_tavern("That dungeon does not support %s mode yet." % play_mode.capitalize())
		return
	if not campaign.expedition.active:
		var party := requested_party if not requested_party.is_empty() else campaign.default_party(dungeon_id)
		var launch_result:=campaign.launch_expedition(party,dungeon_id,play_mode)
		if not bool(launch_result.get("ok",false)):show_tavern(String(launch_result.get("error","No eligible party can enter that dungeon.")));return
		run_state.active_character_id = party[0]
	if run_state.normalize_play_mode(play_mode)==RunState.PLAY_MODE_SLASHER:
		run_state.reconcile_slasher_progression()
		if run_state.has_pending_slasher_progression_choice():
			_show_slasher_progression(func():_begin_dungeon(dungeon_id,gear,play_mode));return
	_begin_dungeon(dungeon_id,gear,play_mode)

func _begin_dungeon(dungeon_id:String,gear:GearData,play_mode:String)->void:
	run_state.start_new_run(gear,dungeon_id,play_mode)
	run_state.apply_tutorial_health_cap()
	run_state.autosave_campaign();_load_active_dungeon()

func _show_slasher_progression(on_complete:Callable)->void:
	var screen_layer:=CanvasLayer.new();screen_layer.name="SlasherProgressionLayer";screen_layer.layer=100;add_child(screen_layer)
	var overlay:SlasherProgressionOverlay=SlasherProgressionOverlay.new();overlay.name="SlasherProgressionOverlay";overlay.all_choices_resolved.connect(_on_slasher_progression_closed.bind(screen_layer,on_complete),CONNECT_ONE_SHOT);screen_layer.add_child(overlay);overlay.open(run_state)

func _on_slasher_progression_closed(screen_layer:CanvasLayer,on_complete:Callable)->void:
	if is_instance_valid(screen_layer):screen_layer.queue_free()
	if on_complete.is_valid():on_complete.call()

func _load_active_dungeon() -> void:
	_clear_scene()
	var scene: PackedScene
	if run_state.active_play_mode == RunState.PLAY_MODE_SLASHER:
		match String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("slasher_runtime", run_state.active_dungeon_id)):
			"forest": scene = SlasherForestScene
			"crypt": scene = SlasherCryptScene
			"ashen_farmstead": scene = SlasherFarmsteadScene
			"sunken_mine": scene = SlasherMineScene
			"ember_foundry": scene = SlasherFoundryScene
			"moonlit_grove": scene = SlasherGroveScene
			"abyssal_archive": scene = SlasherArchiveScene
			_: show_tavern("Slasher mode is not available for that expedition yet."); return
	else:
		match String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("runtime", run_state.active_dungeon_id)):
			"forest": scene = ForestScene
			"crypt": scene = CryptScene
			"ashen_farmstead": scene = AshenFarmsteadScene
			"sunken_mine": scene = SunkenMineScene
			"ember_foundry": scene = EmberFoundryScene
			"moonlit_grove": scene = MoonlitGroveScene
			"abyssal_archive": scene = AbyssalArchiveScene
			_: show_tavern("That expedition runtime is not available."); return
	var dungeon := scene.instantiate(); current_scene = dungeon; dungeon.setup(self, run_state); add_child(dungeon)

func _load_forest_floor() -> void:
	_clear_scene()
	var forest := ForestScene.instantiate()
	current_scene = forest
	forest.setup(self, run_state)
	add_child(forest)

func _load_crypt_floor() -> void:
	_clear_scene()
	var crypt := CryptScene.instantiate()
	current_scene = crypt
	crypt.setup(self, run_state)
	add_child(crypt)

func complete_forest_floor() -> void:
	var favor_logs := run_state.record_dungeon_floor_clear("forest", run_state.current_floor, run_state.current_floor >= run_state.max_floors)
	run_state.record_floor_checkpoint()
	if run_state.current_floor < run_state.max_floors:
		run_state.continue_expedition();run_state.advance_floor();run_state.autosave_campaign();_load_forest_floor()
	else:
		run_state.mark_forest_cleared()
		favor_logs.append_array(run_state.record_active_dungeon_completion())
		return_to_tavern("victory","You conquer the forest dungeon with %d gold.\n%s" % [run_state.gold, " ".join(favor_logs)])

func complete_strategy_dungeon_floor() -> void:
	if run_state.active_dungeon_id == "forest": complete_forest_floor(); return
	if run_state.active_dungeon_id == "crypt": complete_crypt_floor(); return
	var dungeon := GameBalance.get_dungeon(run_state.active_dungeon_id)
	var merchant_id := String(dungeon.get("merchant_id", run_state.active_dungeon_id))
	var favor_logs: Array[String] = []
	if not merchant_id.is_empty(): favor_logs = run_state.record_dungeon_floor_clear(merchant_id, run_state.current_floor, run_state.current_floor >= run_state.max_floors)
	run_state.record_floor_checkpoint()
	if run_state.current_floor < run_state.max_floors:run_state.continue_expedition();run_state.advance_floor();run_state.autosave_campaign();_load_active_dungeon()
	else:
		favor_logs.append_array(run_state.record_active_dungeon_completion())
		return_to_tavern("victory","The party clears %s and returns with %d gold.\n%s" % [String(dungeon.get("name", run_state.active_dungeon_id.capitalize())), run_state.gold, " ".join(favor_logs)])

func complete_slasher_forest_floor() -> void:
	if campaign.expedition.tutorial_run:
		if run_state.current_floor < run_state.max_floors:
			run_state.continue_expedition();run_state.advance_slasher_floor();run_state.autosave_campaign();_load_active_dungeon()
		else:
			return_to_tavern("victory", "Alden defeats the Briarway's guardian and carries its final haul home.")
		return
	var cycle_boss:bool=run_state.is_slasher_boss_floor();var first_boss:bool=cycle_boss and not run_state.slasher_campaign_boss_cleared;var favor_logs:Array[String]=[]
	# Campaign credit is awarded exactly once. Endless floors do not repeatedly grant dungeon-clear credit or merchant favor.
	if not run_state.slasher_endless_mode:favor_logs=run_state.record_dungeon_floor_clear("forest",run_state.current_floor,first_boss)
	if first_boss:run_state.slasher_campaign_boss_cleared=true;run_state.mark_forest_cleared()
	run_state.reconcile_slasher_progression();var continuation:Callable=_after_slasher_floor_progression.bind(cycle_boss,favor_logs)
	if run_state.has_pending_slasher_progression_choice():_show_slasher_progression(continuation)
	else:continuation.call()

func complete_slasher_dungeon_floor() -> void:
	if run_state.active_dungeon_id == "forest": complete_slasher_forest_floor(); return
	var dungeon := GameBalance.get_dungeon(run_state.active_dungeon_id)
	var campaign_floors := int(Dictionary(dungeon.get("slasher", {})).get("campaign_floors", dungeon.get("floors", 1)))
	run_state.record_floor_checkpoint()
	if run_state.current_floor < campaign_floors:run_state.continue_expedition();run_state.advance_slasher_floor();run_state.autosave_campaign();_load_active_dungeon()
	else:
		var completion_logs := run_state.record_active_dungeon_completion()
		return_to_tavern("victory","The party clears %s in Slasher mode and returns with %d gold.\n%s" % [String(dungeon.get("name", run_state.active_dungeon_id.capitalize())), run_state.gold, " ".join(completion_logs)])

func _after_slasher_floor_progression(cycle_boss:bool,favor_logs:Array[String])->void:
	if cycle_boss:
		favor_logs.append_array(run_state.record_active_dungeon_completion())
		return_to_tavern("victory","You conquer the Forest after floor %d with %d gold.\n%s\n%s" % [run_state.current_floor, run_state.gold, " ".join(favor_logs), run_state.get_slasher_progression_summary()])
		return
	run_state.continue_expedition();run_state.advance_slasher_floor();run_state.autosave_campaign();_load_active_dungeon()

func complete_crypt_floor() -> void:
	var favor_logs := run_state.record_dungeon_floor_clear("crypt", run_state.current_floor, run_state.current_floor >= run_state.max_floors)
	run_state.record_floor_checkpoint()
	if run_state.current_floor < run_state.max_floors:
		run_state.continue_expedition();run_state.advance_floor();run_state.autosave_campaign();_load_crypt_floor()
	else:
		favor_logs.append_array(run_state.record_active_dungeon_completion())
		return_to_tavern("victory","You conquer the seven-floor Stone Crypt with %d gold.\n%s" % [run_state.gold, " ".join(favor_logs)])

func complete_ashen_farmstead() -> void:
	var favor_logs := run_state.record_dungeon_floor_clear("farmstead", int(run_state.field_run.get("room_count", 1)), true)
	return_to_tavern("victory", "The Harvest Wretch falls. You return from the Ashen Farmstead with %d gold. Orin Cinder has joined the tavern.\n%s" % [run_state.gold, " ".join(favor_logs)])

func complete_slasher_farmstead() -> void:
	if bool(run_state.field_run.get("completion_awarded", false)): return
	run_state.field_run["completion_awarded"] = true
	run_state.field_run["boss_defeated"] = true
	var depth := int(run_state.field_run.get("room_count", 1))
	var favor_logs := run_state.record_dungeon_floor_clear("farmstead", depth, true)
	run_state.gain_xp(int(Dictionary(GameBalance.get_dungeon("ashen_farmstead").get("slasher", {})).get("boss_xp", 150)), "Ashen Farmstead Slasher clear")
	return_to_tavern("victory", "The Harvest Wretch falls. You clear %d rooms and return with %d gold. Orin Cinder has joined the tavern.\n%s" % [depth, run_state.gold, " ".join(favor_logs)])

func return_to_tavern(outcome: String, message: String) -> void:
	var was_tutorial := campaign.tutorial_phase == CampaignState.TUTORIAL_EXPEDITION and campaign.expedition.tutorial_run
	var return_dungeon := run_state.active_dungeon_id
	if outcome == "death" and campaign.expedition.active and not campaign.expedition.living_party_ids().is_empty():
		campaign.record_casualty(run_state.active_character_id, message)
	var changes: Array[String] = []
	var message_lines := message.split("\n", false)
	for index in range(1, message_lines.size()): changes.append(String(message_lines[index]))
	var summary := {
		"outcome": outcome,
		"headline": String(message_lines[0]) if not message_lines.is_empty() else message,
		"dungeon": run_state.active_dungeon_id,
		"mode": run_state.active_play_mode,
		"depth": run_state.current_floor,
		"gold": run_state.gold,
		"slasher_progression":run_state.get_slasher_progression_summary() if run_state.active_play_mode==RunState.PLAY_MODE_SLASHER else "",
		"changes": changes,
	}
	run_state.finish_run(outcome, message)
	var story_lines: Array = []
	var story_context := ""
	if was_tutorial and outcome in ["death", "victory"]:
		campaign.apply_post_tutorial_state(outcome)
		campaign.legacy_runtime.clear()
		run_state = RunState.new();run_state.attach_campaign(campaign);_select_first_available_character()
		campaign.save_atomic()
		summary["gold"] = campaign.banked_gold
		summary["headline"] = "Alden is remembered. The Hearth passes to a new company." if outcome == "death" else "Alden conquers the Briarway. The Hearth changes hands."
		story_lines = _tutorial_epilogue(outcome)
		story_context = "tutorial_epilogue"
	elif not was_tutorial and campaign.should_trigger_former_keeper_encounter(return_dungeon, outcome):
		story_lines = _former_keeper_confrontation()
		story_context = "former_keeper_confrontation"
	campaign.pending_settlement_summary=summary.duplicate(true);campaign.pending_story_context=story_context;campaign.save_atomic()
	show_tavern(message, summary, story_lines, story_context)

func _opening_tutorial_dialogue() -> Array[Dictionary]:
	return [
		{"speaker":"Mara Vell", "text":"The Briarway has swallowed another road, Alden. Bring down what nests at its heart and whatever you carry home is yours—but the forest keeps every careless name.", "portrait":MARA_PORTRAIT, "side":"left"},
		{"speaker":"Alden", "text":"Three heartbeats of strength and a borrowed sword? I have worked with less.", "portrait":ALDEN_PORTRAIT, "side":"right"},
		{"speaker":"Mara Vell", "text":"Then learn quickly. Move with purpose, spend your Resolve carefully, and come home before courage becomes pride.", "portrait":MARA_PORTRAIT, "side":"left"},
	]

func _tutorial_epilogue(outcome: String) -> Array[Dictionary]:
	if outcome == "death":
		return [
			{"speaker":"Mara Vell", "text":"Alden will not return. Put his name in the memorial; a death hidden is a lesson wasted.", "portrait":MARA_PORTRAIT, "side":"left"},
			{"speaker":"Mayor Corvin Rook", "text":"Then the Hearth closes? The roads will not grow safer because we lower the shutters.", "portrait":MAYOR_PORTRAIT, "side":"right"},
			{"speaker":"Mara Vell", "text":"No. Brina and Eamon are waiting. Give them better counsel than Alden had, keep eight measures of supplies, and make this company worthy of the names it carries.", "portrait":MARA_PORTRAIT, "side":"left"},
		]
	return [
		{"speaker":"Alden", "text":"The guardian is dead. Take the haul, Mayor. I have had enough of borrowed swords and borrowed luck.", "portrait":ALDEN_PORTRAIT, "side":"right"},
		{"speaker":"Mayor Corvin Rook", "text":"Mara vanished before dawn and left more debt than ale. The Briarway's haul settles the deed; the Hearth belongs to your new company now.", "portrait":MAYOR_PORTRAIT, "side":"left"},
		{"speaker":"Alden", "text":"Then keep its fire lit for Brina and Eamon. I won my road. They still need theirs.", "portrait":ALDEN_PORTRAIT, "side":"right"},
	]

func _former_keeper_confrontation() -> Array[Dictionary]:
	return [
		{"speaker":"Mara Vell", "text":"I see you taught the Briarway to pay its debts. Do not mistake my absence for surrender.", "portrait":MARA_PORTRAIT, "side":"left"},
		{"speaker":"Mayor Corvin Rook", "text":"You abandoned the deed, Mara. The company earned its place here.", "portrait":MAYOR_PORTRAIT, "side":"right"},
		{"speaker":"Mara Vell", "text":"I surrendered a debt, not my hearth. Keep the fire bright. One day I will return for something worth taking.", "portrait":MARA_PORTRAIT, "side":"left"},
	]

func _gear_options_for_class(class_id: String) -> Array[GearData]:
	var options: Array[GearData] = []
	for gear in all_gear_options:
		if gear.class_id == class_id:
			options.append(gear)
	return options

func _clear_scene() -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null

func _ensure_input_actions() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("interact", [KEY_E, KEY_SPACE])
	_add_key_action("special", [KEY_F])
	_add_key_action("drink_potion", [KEY_Q])
	_reset_action("character_menu")
	_add_key_action("character_menu", [KEY_M])
	_reset_action("cycle_party")
	_add_key_action("cycle_party", [KEY_TAB])
	_add_joypad_action("character_menu",JOY_BUTTON_START)
	_add_joypad_action("cycle_party",JOY_BUTTON_LEFT_SHOULDER)
	_add_joypad_action("move_up", JOY_BUTTON_DPAD_UP)
	_add_joypad_action("move_down", JOY_BUTTON_DPAD_DOWN)
	_add_joypad_action("move_left", JOY_BUTTON_DPAD_LEFT)
	_add_joypad_action("move_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joypad_action("interact", JOY_BUTTON_A)
	# Shoulder/system bindings keep campaign-critical actions reachable without a mouse.
	_add_key_action("slasher_up", [KEY_W, KEY_UP])
	_add_key_action("slasher_down", [KEY_S, KEY_DOWN])
	_add_key_action("slasher_left", [KEY_A, KEY_LEFT])
	_add_key_action("slasher_right", [KEY_D, KEY_RIGHT])
	_reset_action("slasher_controller_basic")
	_reset_action("slasher_mobility")
	_reset_action("slasher_special")
	_reset_action("slasher_defend")
	for aim_action in ["slasher_aim_left","slasher_aim_right","slasher_aim_up","slasher_aim_down"]: _reset_action(aim_action)
	_add_key_action("slasher_special", [KEY_SPACE])
	_add_key_action("slasher_potion", [KEY_Q])
	_add_key_action("slasher_consumable_1", [KEY_1])
	_add_key_action("slasher_consumable_2", [KEY_2])
	_add_key_action("slasher_consumable_3", [KEY_3])
	_add_key_action("slasher_consumable_4", [KEY_4])
	_add_joypad_action("slasher_controller_basic", JOY_BUTTON_A)
	_add_joypad_action("slasher_mobility", JOY_BUTTON_B)
	_add_joypad_action("slasher_special", JOY_BUTTON_X)
	_add_joypad_action("slasher_defend", JOY_BUTTON_Y)
	_add_joypad_action("slasher_potion",JOY_BUTTON_LEFT_STICK)
	_add_joypad_axis_action("slasher_aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joypad_axis_action("slasher_aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joypad_axis_action("slasher_aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joypad_axis_action("slasher_aim_down", JOY_AXIS_RIGHT_Y, 1.0)

func _add_key_action(action: StringName, keys: Array[int]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		if not _action_has_key(action, key):
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _action_has_key(action: StringName, key: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key:
			return true
	return false

func _add_joypad_action(action: StringName, button_index: JoyButton) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == button_index: return
	var event := InputEventJoypadButton.new(); event.button_index = button_index; InputMap.action_add_event(action,event)

func _add_mouse_action(action: StringName, button_index: MouseButton) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventMouseButton and existing.button_index == button_index: return
	var event := InputEventMouseButton.new(); event.button_index = button_index; InputMap.action_add_event(action,event)

func _reset_action(action: StringName) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	InputMap.action_erase_events(action)

func _add_joypad_axis_action(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action): InputMap.add_action(action)
	var event:=InputEventJoypadMotion.new();event.axis=axis;event.axis_value=axis_value;InputMap.action_add_event(action,event)
