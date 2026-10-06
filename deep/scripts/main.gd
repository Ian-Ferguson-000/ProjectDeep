extends Node

const StartScreenScene := preload("res://scenes/start/StartScreen.tscn")
const ClassSelectionScene := preload("res://scenes/class_selection/ClassSelection.tscn")
const TavernScene := preload("res://scenes/tavern/Tavern.tscn")
const TestingGroundScene := preload("res://scenes/slasher/TestingGround.tscn")
const SlasherForestScene := preload("res://scenes/slasher/SlasherForest.tscn")
const SlasherFarmsteadScene := preload("res://scenes/slasher/SlasherFarmstead.tscn")
const SlasherMineScene := preload("res://scenes/slasher/SlasherMine.tscn")
const SlasherFoundryScene := preload("res://scenes/slasher/SlasherFoundry.tscn")
const SlasherGroveScene := preload("res://scenes/slasher/SlasherGrove.tscn")
const SlasherArchiveScene := preload("res://scenes/slasher/SlasherArchive.tscn")
const SlasherCryptScene := preload("res://scenes/slasher/SlasherCrypt.tscn")
const SlasherHellScene := preload("res://scenes/slasher/SlasherHell.tscn")
const SlasherProgressionOverlay := preload("res://scripts/slasher/slasher_progression_overlay.gd")
const DialogueChatScene := preload("res://scripts/ui/dialogue_chat.gd")
const STORY_EVENTS := preload("res://scripts/game/story_event_service.gd")

var run_state := RunState.new()
var all_gear_options: Array[GearData] = []
var current_scene: Node
var campaign: CampaignState
var tutorial_class_id := ""

const KEEPER_PORTRAIT := "res://assets/merchants/tavern_mara.png"
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
	AudioCue.context_from(self,"menu")
	var start_screen := StartScreenScene.instantiate()
	current_scene = start_screen
	start_screen.setup(self)
	add_child(start_screen)

func begin_game() -> void:
	if campaign==null:return
	if campaign.is_tutorial_complete():
		campaign.ensure_tavern_cycle(); _select_first_available_character();var pending:=_pending_campaign_story();show_tavern("The company gathers around the expedition ledger.",{},pending.lines,pending.context)
	else:
		campaign.tutorial_phase = CampaignState.TUTORIAL_DIALOGUE
		show_tavern("", {}, _opening_tutorial_dialogue(), "tutorial_opening")

func get_save_slot_summaries()->Array[Dictionary]:return CampaignState.all_slot_summaries()

func continue_from_slot(slot:int)->void:
	campaign=CampaignState.load_or_new(slot);run_state=RunState.new();run_state.attach_campaign(campaign)
	if campaign.expedition.active:_resume_saved_expedition();return
	if campaign.is_tutorial_complete():
		campaign.ensure_tavern_cycle();_select_first_available_character()
		var restored_context:=campaign.pending_story_context;var restored_story:Array=[]
		if restored_context=="tutorial_epilogue":restored_story=_tutorial_epilogue(campaign.tutorial_outcome)
		elif restored_context.begins_with("story_event:"):restored_story=STORY_EVENTS.lines(restored_context.trim_prefix("story_event:"),campaign)
		elif not campaign.pending_story_event_id.is_empty():var pending:=_pending_campaign_story();restored_context=pending.context;restored_story=pending.lines
		show_tavern("" if not campaign.pending_settlement_summary.is_empty() else "Save Slot %d · The company gathers around the expedition ledger."%slot,campaign.pending_settlement_summary,restored_story,restored_context)
	else:campaign.tutorial_phase=CampaignState.TUTORIAL_DIALOGUE;show_tavern("",{},_opening_tutorial_dialogue(),"tutorial_opening")

func new_game_in_slot(slot:int)->void:
	campaign=CampaignState.new();campaign.save_slot=clampi(slot,1,CampaignState.SAVE_SLOT_COUNT);run_state=RunState.new();run_state.attach_campaign(campaign);tutorial_class_id="";begin_game()

func _resume_saved_expedition()->void:
	var living:=campaign.expedition.living_party_ids()
	if living.is_empty():campaign.resolve_expedition("death");_select_first_available_character();show_tavern("The saved expedition had no survivors. The memorial has been updated.");return
	run_state.active_dungeon_id=campaign.expedition.dungeon_id;run_state.current_floor=campaign.expedition.floor;run_state.gold=campaign.expedition.carried_gold
	var dungeon:=GameBalance.get_dungeon(run_state.active_dungeon_id);run_state.max_floors=int(dungeon.get("floors",1))
	run_state.select_active_character(living[0]);run_state.apply_tutorial_health_cap();_load_active_dungeon()

func advance_tutorial_from_tavern() -> void:
	var starter := campaign.create_tutorial_adventurer()
	starter.status = CharacterRecord.STATUS_AVAILABLE
	campaign.tutorial_phase = CampaignState.TUTORIAL_EXPEDITION
	if not campaign.begin_expedition([starter.id], "forest", true): return
	run_state.active_character_id = starter.id
	run_state.set_class("warrior")
	var gear_options := _gear_options_for_class("warrior")
	var gear: GearData = gear_options[0] if not gear_options.is_empty() else null
	_begin_dungeon("forest", gear)

func restart_tutorial_onboarding() -> void:
	if campaign == null or not campaign.expedition.tutorial_run: return
	var starter := campaign.restart_tutorial_expedition()
	if starter == null: return
	run_state.active_character_id = starter.id
	run_state.set_class("warrior")
	var gear_options := _gear_options_for_class("warrior")
	var gear: GearData = gear_options[0] if not gear_options.is_empty() else null
	_begin_dungeon("forest", gear)

func get_selectable_class_ids() -> Array[String]:
	return ["warrior", "mage"] if not campaign.is_tutorial_complete() else campaign.unlocked_classes.duplicate()

func show_class_selection() -> void:
	_clear_scene()
	AudioCue.context_from(self,"class_selection")
	var class_selection := ClassSelectionScene.instantiate()
	current_scene = class_selection
	class_selection.setup(self)
	add_child(class_selection)

func choose_class(class_id: String) -> void:
	run_state.set_class(class_id)
	if not campaign.is_tutorial_complete():
		var starter := campaign.create_character(class_id)
		campaign.tutorial_phase = CampaignState.TUTORIAL_EXPEDITION
		if not campaign.begin_expedition([starter.id], "forest", true): return
		run_state.active_character_id = starter.id; run_state.set_class(starter.class_id)
		var gear_options := _gear_options_for_class(starter.class_id); var gear: GearData = gear_options[0] if not gear_options.is_empty() else null
		_begin_dungeon("forest", gear); return
	var class_type := run_state.selected_class_name; show_tavern("The hearth is warm. The bartender lays out %s choices for the road ahead." % class_type)

func _select_first_available_character() -> void:
	var available := campaign.living_roster()
	if available.is_empty(): return
	run_state.active_character_id = available[0].id; run_state.set_class(available[0].class_id)

func show_tavern(message: String = "", arrival_summary: Dictionary = {}, story_lines: Array = [], story_context: String = "") -> void:
	if campaign!=null and campaign.is_tutorial_complete() and not campaign.expedition.active:campaign.ensure_tavern_cycle()
	_clear_scene()
	AudioCue.context_from(self,"tavern")
	var tavern := TavernScene.instantiate()
	current_scene = tavern
	tavern.setup(self, run_state, _gear_options_for_class(run_state.selected_class_id), message, arrival_summary, story_lines, story_context)
	add_child(tavern)

func open_testing_ground() -> void:
	if campaign != null and campaign.expedition.active: return
	_clear_scene()
	AudioCue.context_from(self,"testing_ground")
	var ground := TestingGroundScene.instantiate()
	current_scene = ground
	ground.setup(self)
	add_child(ground)

func leave_testing_ground() -> void:
	show_tavern("Back from the testing ground.")
	if current_scene != null and current_scene.has_method("_open_armory"):
		current_scene.call_deferred("_open_armory")

func start_dungeon(dungeon_id: String, gear: GearData, requested_party: Array[String] = [], patron_deity_id: String = "", objective_id: String = "") -> void:
	if not run_state.is_dungeon_unlocked(dungeon_id):
		show_tavern(String(GameBalance.get_dungeon(dungeon_id).get("unlock_text", "That expedition is locked.")))
		return
	if not run_state.dungeon_available(dungeon_id):
		show_tavern("That expedition is not available.")
		return
	if not campaign.expedition.active:
		var party := requested_party if not requested_party.is_empty() else campaign.default_party(dungeon_id)
		var launch_result:=campaign.launch_expedition(party,dungeon_id,patron_deity_id,objective_id)
		if not bool(launch_result.get("ok",false)):show_tavern(String(launch_result.get("error","No eligible party can enter that dungeon.")));return
		run_state.active_character_id = party[0]
	run_state.reconcile_slasher_progression()
	if run_state.has_pending_slasher_progression_choice():
		_show_slasher_progression(func():_begin_dungeon(dungeon_id,gear));return
	_begin_dungeon(dungeon_id,gear)

func _begin_dungeon(dungeon_id:String,gear:GearData)->void:
	run_state.start_new_run(gear,dungeon_id)
	run_state.apply_tutorial_health_cap()
	run_state.autosave_on_floor_entry();_load_active_dungeon()

func _show_slasher_progression(on_complete:Callable)->void:
	var screen_layer:=CanvasLayer.new();screen_layer.name="SlasherProgressionLayer";screen_layer.layer=100;add_child(screen_layer)
	var overlay:SlasherProgressionOverlay=SlasherProgressionOverlay.new();overlay.name="SlasherProgressionOverlay";overlay.all_choices_resolved.connect(_on_slasher_progression_closed.bind(screen_layer,on_complete),CONNECT_ONE_SHOT);screen_layer.add_child(overlay);overlay.open(run_state)

func _on_slasher_progression_closed(screen_layer:CanvasLayer,on_complete:Callable)->void:
	if is_instance_valid(screen_layer):screen_layer.queue_free()
	if on_complete.is_valid():on_complete.call()

func _load_active_dungeon() -> void:
	_clear_scene()
	var scene: PackedScene
	match String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("runtime", run_state.active_dungeon_id)):
		"forest": scene = SlasherForestScene
		"crypt": scene = SlasherCryptScene
		"balors_hell": scene = SlasherHellScene
		"ashen_farmstead": scene = SlasherFarmsteadScene
		"sunken_mine": scene = SlasherMineScene
		"ember_foundry": scene = SlasherFoundryScene
		"moonlit_grove": scene = SlasherGroveScene
		"abyssal_archive": scene = SlasherArchiveScene
		_: show_tavern("That expedition is not available."); return
	AudioCue.context_from(self,run_state.active_dungeon_id)
	var dungeon := scene.instantiate(); current_scene = dungeon; dungeon.setup(self, run_state); add_child(dungeon)

func complete_slasher_forest_floor() -> void:
	if campaign.expedition.tutorial_run:
		if run_state.current_floor < run_state.max_floors:
			_hearth_checkpoint(func(): run_state.continue_expedition();run_state.advance_slasher_floor();run_state.autosave_on_floor_entry();_load_active_dungeon())
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
	var campaign_floors := int(dungeon.get("floors", 1))
	run_state.record_floor_checkpoint()
	if run_state.current_floor < campaign_floors:_hearth_checkpoint(func(): run_state.continue_expedition();run_state.advance_slasher_floor();run_state.autosave_on_floor_entry();_load_active_dungeon())
	else:
		var completion_logs := run_state.record_active_dungeon_completion()
		if _continue_connected_expedition(completion_logs): return
		return_to_tavern("victory","The party clears %s and returns with %d gold.\n%s" % [String(dungeon.get("name", run_state.active_dungeon_id.capitalize())), run_state.gold, " ".join(completion_logs)])

func _after_slasher_floor_progression(cycle_boss:bool,favor_logs:Array[String])->void:
	if cycle_boss:
		favor_logs.append_array(run_state.record_active_dungeon_completion())
		if _continue_connected_expedition(favor_logs): return
		return_to_tavern("victory","You conquer the Forest after floor %d with %d gold.\n%s\n%s" % [run_state.current_floor, run_state.gold, " ".join(favor_logs), run_state.get_slasher_progression_summary()])
		return
	_hearth_checkpoint(func(): run_state.continue_expedition();run_state.advance_slasher_floor();run_state.autosave_on_floor_entry();_load_active_dungeon())

func _continue_connected_expedition(completion_logs:Array[String]=[]) -> bool:
	var completed_id:=run_state.active_dungeon_id
	var next_id:=NarrativeContent.next_route_stage(completed_id)
	if next_id.is_empty() or not run_state.is_dungeon_unlocked(next_id) or not run_state.dungeon_available(next_id):return false
	var completed_name:=String(GameBalance.get_dungeon(completed_id).get("name",completed_id.capitalize()))
	var next_name:=String(GameBalance.get_dungeon(next_id).get("name",next_id.capitalize()))
	if not run_state.transition_to_dungeon(next_id):return false
	_show_connected_dungeon_dialogue(_connected_dungeon_dialogue(completed_name,next_name,completion_logs))
	return true

func _connected_dungeon_dialogue(completed_name:String,next_name:String,_completion_logs:Array[String]) -> Array[Dictionary]:
	var member:=campaign.character(run_state.active_character_id) if campaign!=null else null
	var hero_name:=member.display_name if member!=null else "Adventurer"
	var hero_portrait:="res://assets/roster_portraits/%s_%d.png"%[member.class_id,member.portrait_variant] if member!=null else ALDEN_PORTRAIT
	if run_state.active_dungeon_id=="balors_hell":
		return STORY_EVENTS.lines("balor_threshold",campaign,"default",{"hero_name":hero_name,"hero_portrait":hero_portrait})
	return [
		{"speaker":"The Keeper","text":"The %s is broken, but this road does not turn back toward the Hearth. The passage ahead descends into the %s."%[completed_name,next_name],"portrait":KEEPER_PORTRAIT,"side":"left"},
		{"speaker":hero_name,"text":"Then we keep what we have carried, tend our wounds as we walk, and finish the road before we call it a victory.","portrait":hero_portrait,"side":"right"},
		{"speaker":"The Keeper","text":"No fresh recruits. No resupply. No warm beds between connected depths. Go on—the company settles its account only when the whole descent ends.","portrait":KEEPER_PORTRAIT,"side":"left"},
	]

func _show_connected_dungeon_dialogue(lines:Array[Dictionary])->void:
	var layer:=CanvasLayer.new();layer.name="ConnectedDungeonDialogueLayer";layer.layer=120;add_child(layer)
	var chat:DialogueChat=DialogueChatScene.new();chat.name="ConnectedDungeonDialogue";layer.add_child(chat)
	chat.conversation_finished.connect(_on_connected_dungeon_dialogue_finished.bind(layer),CONNECT_ONE_SHOT)
	chat.play(lines)

func _on_connected_dungeon_dialogue_finished(layer:CanvasLayer)->void:
	if is_instance_valid(layer):layer.queue_free()
	_load_active_dungeon()

func complete_slasher_farmstead() -> void:
	if bool(run_state.field_run.get("completion_awarded", false)): return
	run_state.field_run["completion_awarded"] = true
	run_state.field_run["boss_defeated"] = true
	var depth := int(run_state.field_run.get("room_count", 1))
	var favor_logs := run_state.record_dungeon_floor_clear("farmstead", depth, true)
	run_state.gain_xp(int(Dictionary(GameBalance.get_dungeon("ashen_farmstead").get("slasher", {})).get("boss_xp", 150)), "Ashen Farmstead Slasher clear")
	favor_logs.append_array(run_state.record_active_dungeon_completion())
	if _continue_connected_expedition(favor_logs):return
	return_to_tavern("victory", "The Harvest Wretch falls. You clear %d rooms and return with %d gold. Orin Cinder has joined the tavern.\n%s" % [depth, run_state.gold, " ".join(favor_logs)])

func return_to_tavern(outcome: String, message: String) -> void:
	var previous_loop := int(campaign.keeper_memory.get("loop_number",0))
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
				"depth": run_state.current_floor,
		"gold": run_state.gold,
		"slasher_progression":run_state.get_slasher_progression_summary(),
		"changes": changes,
	}
	run_state.finish_run(outcome, message)
	if previous_loop != int(campaign.keeper_memory.get("loop_number",0)):
		run_state = RunState.new()
		run_state.attach_campaign(campaign)
		if not run_state.autosave_on_floor_entry(): push_warning(campaign.last_save_error)
		begin_game()
		return
	var story_lines: Array = []
	var story_context := ""
	if was_tutorial and outcome in ["death", "victory"]:
		campaign.apply_post_tutorial_state(outcome)
		campaign.legacy_runtime.clear()
		run_state = RunState.new();run_state.attach_campaign(campaign);_select_first_available_character()
		summary["gold"] = campaign.banked_gold
		summary["headline"] = "Alden is remembered. His contribution keeps the Hearth alive." if outcome == "death" else "Alden returns. His victory gives the Hearth another chance."
		story_lines = _tutorial_epilogue(outcome)
		story_context = "tutorial_epilogue"
	elif not campaign.pending_story_event_id.is_empty():
		var pending:=_pending_campaign_story();story_lines=pending.lines;story_context=pending.context
	if not was_tutorial and not campaign.pending_settlement_summary.is_empty(): summary.merge(campaign.pending_settlement_summary,true)
	campaign.pending_settlement_summary=summary.duplicate(true);campaign.pending_story_context=story_context
	if not run_state.autosave_on_floor_entry(): push_warning(campaign.last_save_error)
	show_tavern(message, summary, story_lines, story_context)

func _opening_tutorial_dialogue() -> Array[Dictionary]:
	return STORY_EVENTS.lines("remembered_last_customer" if int(campaign.keeper_memory.get("loop_number",0))>0 else "last_customer_opening",campaign)

func _tutorial_epilogue(outcome: String) -> Array[Dictionary]:
	return STORY_EVENTS.lines("last_customer_resolution",campaign,outcome)

func _pending_campaign_story()->Dictionary:
	if campaign==null or campaign.pending_story_event_id.is_empty():return {"lines":[],"context":""}
	var event_id:=campaign.pending_story_event_id
	return {"lines":STORY_EVENTS.lines(event_id,campaign),"context":"story_event:%s"%event_id}

func _gear_options_for_class(class_id: String) -> Array[GearData]:
	var options: Array[GearData] = []
	for gear in all_gear_options:
		if gear.class_id == class_id:
			options.append(gear)
	return options

func _clear_scene() -> void:
	var audio:=get_node_or_null("/root/Audio")
	if audio!=null:audio.stop_world_sounds()
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

func _hearth_checkpoint(continuation: Callable) -> void:
	# Floors are internal progress points. The expedition stays in the dungeon
	# until the party defeats its boss or the party is defeated.
	run_state.record_floor_checkpoint()
	run_state._sync_active_profile_to_character()
	continuation.call()
