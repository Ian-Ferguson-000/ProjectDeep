extends Node2D

const PLAYER := preload("res://scripts/slasher/slasher_player.gd")
const DUMMY := preload("res://scripts/slasher/training_dummy.gd")
const LIVE := preload("res://scripts/slasher/training_combatant.gd")
const FIRE := preload("res://scripts/slasher/slasher_fire_visuals.gd")
const PYROMANCY := preload("res://scripts/slasher/slasher_pyromancy.gd")
const WARRIOR_KITS := preload("res://scripts/slasher/slasher_warrior_kits.gd")
const MAGE_KITS := preload("res://scripts/slasher/slasher_mage_kits.gd")
const FLOOR := Rect2(-900,-450,1800,900)
const CLASS_IDS := ["warrior","mage","healer","tank","rogue","summoner"]
const MILESTONES := [7,9,11,13,17,19]
const ITEM_CONTACT_RADIUS := 25.0
const PODIUM_CONTACT_RADIUS := 34.0
const TRAINING_RECHARGE_SECONDS := 1.25
var controller: Node
var state := RunState.new()
var combat_root: Node2D
var player: SlasherPlayer
var camera: Camera2D
var combo_panel: PanelContainer
var combo_button: Button
var editor: Control
var class_picker: OptionButton
var gear_picker: OptionButton
var level_picker: SpinBox
var branch_picker: OptionButton
var foundation_picker: OptionButton
var upgrade_pickers: Array[OptionButton] = []
var gear_options: Array[GearData] = []
var loot_checks: Dictionary = {}
var details: Label
var hud: Label
var actions: Label
var armory_prompt: Label
var elapsed := 0.0
var hud_timer := 0.0
var dummy_mode := "cluster"
var applied_items: Array[String] = []
var damage_by_type: Dictionary = {}
var class_podiums: Array[Node2D] = []
var item_displays: Array[Node2D] = []
var interaction_lock: Node2D
var active_recharge_time := 0.0
var notice_text := ""
var notice_time := 0.0
var training_navigation: SlasherGridPathfinder
var live_respawns: Array[Dictionary] = []
var arena_generation := 0
var target_popups: Dictionary:
	get:
		var layer := combat_root.get_node_or_null("DamagePopups") if is_instance_valid(combat_root) else null
		return layer.target_popups if layer != null else {}

func setup(game_controller: Node) -> void:
	controller = game_controller

func _ready() -> void:
	_ensure_controls()
	camera = Camera2D.new(); camera.name="ArenaCamera"; add_child(camera); camera.make_current()
	get_viewport().size_changed.connect(_resize)
	_build_ui()
	_build_walk_in_armory()
	_resize()
	_refresh_class()
	_select_standard_gear("warrior")
	apply_build()
	set_editor_visible(false)
	_show_notice("Fighter ready · walk into a class podium or an item to swap",4.0)
	queue_redraw()

func _ensure_controls() -> void:
	var bindings := {"slasher_up":KEY_W,"slasher_down":KEY_S,"slasher_left":KEY_A,"slasher_right":KEY_D,"slasher_special":KEY_SPACE}
	for action in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var event := InputEventKey.new(); event.physical_keycode=int(bindings[action]); InputMap.action_add_event(action,event)
	for action in ["slasher_controller_basic","slasher_mobility","slasher_defend","slasher_aim_left","slasher_aim_right","slasher_aim_up","slasher_aim_down"]:
		if not InputMap.has_action(action): InputMap.add_action(action)

func _resize() -> void:
	if is_instance_valid(combo_panel):combo_panel.offset_bottom=get_viewport_rect().size.y-76
	if camera:
		var size := get_viewport_rect().size
		camera.zoom = Vector2.ONE*minf(size.x/1040.0,size.y/740.0)
		_update_camera(0.0)

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text=text; button.custom_minimum_size.y=36;button.focus_mode=Control.FOCUS_NONE;button.pressed.connect(callback);parent.add_child(button);return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new(); label.text=text; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label); return label

func _set_loot_label(selected: bool, check: CheckBox, caption: String) -> void:
	check.text=("[x]  " if selected else "[ ]  ")+caption

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.name="TestingHUD"; add_child(layer)
	var screen := Control.new(); screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); screen.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(screen)
	var top := HBoxContainer.new(); top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); top.offset_left=18; top.offset_right=-18; top.offset_top=12; screen.add_child(top)
	_button(top,"Refill item  [B]",refill_active_item)
	_button(top,"Reset  [R]",reset_arena)
	_button(top,"Single target",func():dummy_mode="single";reset_arena())
	_button(top,"Cluster",func():dummy_mode="cluster";reset_arena())
	_button(top,"Boss target",func():dummy_mode="boss";reset_arena())
	_button(top,"Live enemies",func():dummy_mode="live";reset_arena())
	_button(top,"Return to armory",return_to_armory)
	hud = _label(screen,""); hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); hud.offset_left=22; hud.offset_top=58; hud.offset_right=-22; hud.offset_bottom=115
	actions = _label(screen,""); actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); actions.offset_left=22; actions.offset_top=-60; actions.offset_right=-22; actions.offset_bottom=-12
	armory_prompt=_label(screen,"");armory_prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;armory_prompt.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);armory_prompt.offset_left=120;armory_prompt.offset_right=-120;armory_prompt.offset_top=-104;armory_prompt.offset_bottom=-64;armory_prompt.add_theme_font_size_override("font_size",16);armory_prompt.add_theme_color_override("font_color",Color("#f4d28d"))
	combo_button=_button(top,"Combos [C]",toggle_combo_panel)
	combo_button.toggle_mode=true
	combo_panel=preload("res://scripts/slasher/combo_practice_panel.gd").new();screen.add_child(combo_panel)
	combo_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	combo_panel.offset_left=-346;combo_panel.offset_right=-18;combo_panel.offset_top=140;combo_panel.offset_bottom=450
	combo_panel.visible=false
	editor = ColorRect.new(); (editor as ColorRect).color=Color(0.025,0.03,0.04,0.94); editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); screen.add_child(editor)
	var margin := MarginContainer.new(); margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); margin.add_theme_constant_override("margin_left",30); margin.add_theme_constant_override("margin_right",30); margin.add_theme_constant_override("margin_top",18); margin.add_theme_constant_override("margin_bottom",18); editor.add_child(margin)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",8); margin.add_child(body)
	var title := _label(body,"THE ARMORY TESTING GROUND"); title.add_theme_font_size_override("font_size",24); title.add_theme_color_override("font_color",Color("#ffd17c"))
	_label(body,"All classes and existing equipment are available here. Changes last only this visit. Combat pauses while you edit.")
	var tabs := TabContainer.new(); tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_child(tabs)
	var build_scroll := ScrollContainer.new(); build_scroll.name="Class and kit"; tabs.add_child(build_scroll)
	var build := VBoxContainer.new(); build.size_flags_horizontal=Control.SIZE_EXPAND_FILL; build.add_theme_constant_override("separation",8); build_scroll.add_child(build)
	var row := HBoxContainer.new(); build.add_child(row)
	class_picker=OptionButton.new(); class_picker.name="ClassPicker"; class_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(class_picker)
	for id in CLASS_IDS: class_picker.add_item(String(GameBalance.get_base_class(id).get("name",id)))
	class_picker.item_selected.connect(func(_index:int):_refresh_class())
	gear_picker=OptionButton.new(); gear_picker.name="KitPicker"; gear_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(gear_picker); gear_picker.item_selected.connect(func(_index:int):_update_details())
	level_picker=SpinBox.new(); level_picker.min_value=1; level_picker.max_value=20; level_picker.value=1; level_picker.prefix="Level "; row.add_child(level_picker)
	details=_label(build,""); details.custom_minimum_size.y=86
	var progression := HBoxContainer.new(); build.add_child(progression)
	foundation_picker=OptionButton.new(); foundation_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL; progression.add_child(foundation_picker)
	for name_value in ["No foundation","Relentless Technique","Unbroken Tempo","Battlefield Resolve"]:foundation_picker.add_item(name_value)
	branch_picker=OptionButton.new(); branch_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL; progression.add_child(branch_picker)
	_label(build,"Choose a branch and milestone variants at the selected level. Upgrades affect alternative kits' damage and cooldowns. Each kit keeps its own abilities and combo recipes.")
	for level in MILESTONES:
		var pick := OptionButton.new(); pick.add_item("Level %d: no upgrade"%level); pick.add_item("Level %d: Mastery"%level); pick.add_item("Level %d: Flow"%level); build.add_child(pick); upgrade_pickers.append(pick)
	var loot := VBoxContainer.new(); loot.name="Items and relics"; tabs.add_child(loot)
	var search := LineEdit.new(); search.placeholder_text="Search existing items and relics"; loot.add_child(search)
	_label(loot,"Select any combination for comparison. Tooltips describe current Slasher effects; proposed catalogue effects are not implemented yet.")
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; loot.add_child(scroll)
	var list := VBoxContainer.new(); list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(list)
	var catalog := GameBalance.get_items()
	for id in HearthCatalog.data().items:
		var entry: Dictionary = HearthCatalog.item(id)
		if entry.get("slot","")=="relic":catalog[id]=entry
	var keys := catalog.keys(); keys.sort_custom(func(a:Variant,b:Variant):return String(catalog[a].get("name",a))<String(catalog[b].get("name",b)))
	for id_value in keys:
		var id := String(id_value); var entry: Dictionary=catalog[id]
		var check := CheckBox.new()
		var caption := String(entry.get("name",id))+"  ·  "+String(entry.get("rarity","common")).replace("_"," ")
		_set_loot_label(false,check,caption)
		check.toggled.connect(_set_loot_label.bind(check,caption))
		check.tooltip_text=GameBalance.get_slasher_item_rules_text(id); list.add_child(check); loot_checks[id]=check
	search.text_changed.connect(func(query:String):
		for id in loot_checks:loot_checks[id].visible=query.is_empty() or String(loot_checks[id].text).to_lower().contains(query.to_lower()) or String(id).contains(query.to_lower()))
	_button(loot,"Clear selected loot",func():
		for check in loot_checks.values():check.button_pressed=false)
	var footer := HBoxContainer.new(); body.add_child(footer)
	_button(footer,"Apply build and fight",func():apply_build();set_editor_visible(false))
	_button(footer,"Resume current build",func():set_editor_visible(false))
	_button(footer,"Return to armory",return_to_armory)
	# Space belongs exclusively to active items in the proving floor. Godot also
	# treats Space as "press focused button", so no HUD/editor button may retain
	# keyboard focus after it has been clicked.
	for control in screen.find_children("*","BaseButton",true,false):control.focus_mode=Control.FOCUS_NONE

## The player-facing armory is spatial rather than menu-driven. The legacy
## controls above remain hidden so the detailed kit regression suites can still
## configure progression combinations without exposing a form to players.
func _build_walk_in_armory() -> void:
	var class_y:=[-250.0,-150.0,-50.0,50.0,150.0,250.0]
	for index in CLASS_IDS.size():
		var class_id:String=CLASS_IDS[index]
		var podium:=ArmoryClassPodium.new();podium.class_id=class_id;podium.display_name=String(GameBalance.get_base_class(class_id).get("name",class_id.capitalize()));podium.position=Vector2(-820.0,float(class_y[index]));podium.z_index=4;add_child(podium);class_podiums.append(podium)
	var ordered:Array[String]=[]
	for group in [["warrior"],["mage"],[]]:
		for id_value in ActiveItems.items():
			var item_id:=String(id_value);var classes:Array=Array(ActiveItems.item(item_id).get("classes",[]))
			if classes==group:ordered.append(item_id)
	# Future class-specific active items still get a physical place even if they
	# do not belong to the current Fighter/Mage/neutral authored groups.
	for id_value in ActiveItems.items():
		var item_id:=String(id_value)
		if not ordered.has(item_id):ordered.append(item_id)
	var per_row:=ceili(ordered.size()/2.0)
	for index in ordered.size():
		var display:=ArmoryItemDisplay.new();display.item_id=ordered[index];display.display_name=String(ActiveItems.item(display.item_id).get("name",display.item_id));display.row_side=-1 if index<per_row else 1
		var column:=index if index<per_row else index-per_row;var columns:=per_row if index<per_row else ordered.size()-per_row
		display.position=Vector2(lerpf(-840.0,840.0,float(column)/maxf(1.0,float(columns-1))),-400.0 if index<per_row else 400.0);display.z_index=5;add_child(display);item_displays.append(display)
	_refresh_armory_displays()

func _item_usable_by_class(item_id:String,class_id:String)->bool:
	var classes:Array=Array(ActiveItems.item(item_id).get("classes",[]))
	return classes.is_empty() or classes.has(class_id)

func _refresh_armory_displays() -> void:
	var held:=ActiveItems.held(state)
	for podium in class_podiums:
		podium.set("selected",String(podium.get("class_id"))==state.selected_class_id);podium.queue_redraw()
	for display in item_displays:
		var item_id:=String(display.get("item_id"));display.set("compatible",_item_usable_by_class(item_id,state.selected_class_id));display.set("selected",item_id==held);display.queue_redraw()

func _select_standard_gear(class_id:String)->void:
	var basic_id:=String(CampaignState.BASIC_GEAR.get(class_id,""))
	for index in gear_options.size():
		if gear_options[index].id==basic_id:gear_picker.select(index);return
	if not gear_options.is_empty():gear_picker.select(0)

func _swap_class(class_id:String)->void:
	if class_id==state.selected_class_id:return
	var previous_item:=ActiveItems.held(state);var class_index:=CLASS_IDS.find(class_id)
	if class_index<0:return
	class_picker.select(class_index);_refresh_class();_select_standard_gear(class_id)
	level_picker.value=1;foundation_picker.select(0);branch_picker.select(0)
	for picker in upgrade_pickers:picker.select(0)
	for check in loot_checks.values():check.button_pressed=false
	apply_build()
	var kept_item:=not previous_item.is_empty() and _item_usable_by_class(previous_item,class_id)
	if kept_item:ActiveItems.give(state,previous_item);SlasherActiveEffects.ensure_runtime(player,previous_item)
	active_recharge_time=0.0;_refresh_armory_displays()
	_show_notice("%s · standard level-one kit%s"%[state.selected_class_name," · kept "+String(ActiveItems.item(previous_item).get("name",previous_item)) if kept_item else ""],2.4)

func _clear_active_item_runtime() -> void:
	if not is_instance_valid(player):return
	for child in player.get_children():
		if not String(child.get_meta("active_item_runtime_id","")).is_empty() or not String(child.get_meta("active_item_vfx_id","")).is_empty():player.remove_child(child);child.queue_free()

func _equip_active_item(item_id:String)->void:
	if not _item_usable_by_class(item_id,state.selected_class_id):
		var classes:Array=Array(ActiveItems.item(item_id).get("classes",[]));_show_notice("Requires %s"%String(classes[0]).capitalize(),1.5);return
	if ActiveItems.held(state)==item_id:refill_active_item();return
	_clear_active_item_runtime();var replaced:=ActiveItems.give(state,item_id);SlasherActiveEffects.ensure_runtime(player,item_id);active_recharge_time=0.0;_refresh_armory_displays()
	var suffix:="" if replaced.is_empty() else " · replaced "+String(ActiveItems.item(replaced).get("name",replaced))
	_show_notice(String(ActiveItems.item(item_id).get("name",item_id))+suffix,2.2)

func refill_active_item()->void:
	var item_id:=ActiveItems.held(state)
	if item_id.is_empty():_show_notice("Walk into an item along the upper or lower wall",1.8);return
	ActiveItems.give(state,item_id);active_recharge_time=0.0;_show_notice(String(ActiveItems.item(item_id).get("name",item_id))+" refilled",1.2);_refresh_armory_displays()

func use_active_item()->bool:
	var item_id:=ActiveItems.held(state)
	if item_id.is_empty() or not is_instance_valid(player):return false
	if not ActiveItems.is_ready(state):_show_notice("%s recharging · %.1fs"%[String(ActiveItems.item(item_id).get("name",item_id)),active_recharge_time],0.7);return false
	if not SlasherActiveEffects.use(player,item_id):return false
	if bool(player.get_meta("active_item_skip_spend_once",false)):
		player.set_meta("active_item_skip_spend_once",false);return true
	ActiveItems.spend(state);active_recharge_time=TRAINING_RECHARGE_SECONDS;_refresh_armory_displays();return true

func _show_notice(message:String,duration:float=1.5)->void:
	notice_text=message;notice_time=duration

func _process_armory_interactions()->void:
	if not is_instance_valid(player) or editor.visible:return
	if notice_time<=0.0:armory_prompt.text=""
	if is_instance_valid(interaction_lock) and player.global_position.distance_to(interaction_lock.global_position)>PODIUM_CONTACT_RADIUS+18.0:interaction_lock=null
	var nearest:Node2D;var nearest_distance:=72.0;var nearest_kind:=""
	for podium in class_podiums:
		var distance:=player.global_position.distance_to(podium.global_position)
		if distance<nearest_distance:nearest=podium;nearest_distance=distance;nearest_kind="class"
	for display in item_displays:
		var distance:=player.global_position.distance_to(display.global_position)
		if distance<nearest_distance:nearest=display;nearest_distance=distance;nearest_kind="item"
	if nearest==null:return
	if nearest_kind=="class":
		armory_prompt.text="CLASS PODIUM · "+String(nearest.get("display_name")).to_upper()
		if nearest_distance<=PODIUM_CONTACT_RADIUS and nearest!=interaction_lock:interaction_lock=nearest;_swap_class(String(nearest.get("class_id")))
	else:
		var item_id:=String(nearest.get("item_id"));var item:=ActiveItems.item(item_id);armory_prompt.text=String(item.get("name",item_id)).to_upper()+" · "+String(item.get("description",""))
		if nearest_distance<=ITEM_CONTACT_RADIUS and nearest!=interaction_lock:interaction_lock=nearest;_equip_active_item(item_id)

func _refresh_class() -> void:
	var id: String=CLASS_IDS[class_picker.selected]
	gear_options.clear(); gear_picker.clear()
	for gear_id in HearthCatalog.data().items:
		var entry: Dictionary=HearthCatalog.item(gear_id)
		if entry.get("slot","")=="weapon" and entry.get("class_id","")==id:
			var gear := HearthCatalog.gear(gear_id); gear_options.append(gear); gear_picker.add_item(gear.display_name)
	if id=="mage":
		for gear in MAGE_KITS.all_gear():gear_options.append(gear);gear_picker.add_item(gear.display_name+"  ·  NEW")
	if id=="warrior":
		for gear in WARRIOR_KITS.all_gear():gear_options.append(gear);gear_picker.add_item(gear.display_name+"  ·  NEW")
	branch_picker.clear(); branch_picker.add_item("No branch")
	for branch in GameBalance.get_slasher_progression(id).get("branches",[]):branch_picker.add_item(String(branch.name))
	for pick in upgrade_pickers:pick.select(0)
	_update_details()

func _update_details() -> void:
	if gear_options.is_empty():return
	var gear := gear_options[gear_picker.selected]
	if WARRIOR_KITS.has_kit(gear.id):
		details.text=WARRIOR_KITS.description(gear.id)+"\nFast physical prototype; movement is free. Numeric progression and current items apply."
	elif MAGE_KITS.script_for(gear.id)!=null:
		details.text=MAGE_KITS.description(gear.id)+"\nFast prototype tuning; movement is free. Numeric progression and current items apply."
	else:
		details.text=gear.description+"\nExisting weapon: uses the current class ability kit and this weapon's stats. Select items and progression to compare builds."

func apply_build() -> void:
	_update_details()
	state=RunState.new()
	var id: String=CLASS_IDS[class_picker.selected];state.set_class(id)
	var profile: Dictionary=state.hero_profiles[id];profile.level=int(level_picker.value)
	profile.slasher_evolution_path=[];profile.slasher_ability_upgrades=[]
	if foundation_picker.selected>0 and int(profile.level)>=3:
		profile.slasher_ability_upgrades.append("%s_foundation_%s"%[id,["power","tempo","resolve"][foundation_picker.selected-1]])
	if branch_picker.selected>0 and int(profile.level)>=5:
		var branch: Dictionary=GameBalance.get_slasher_progression(id).branches[branch_picker.selected-1]
		profile.slasher_evolution_path.append("%s_branch_%s"%[id,branch.id])
		for index in MILESTONES.size():
			if MILESTONES[index]<=int(profile.level) and upgrade_pickers[index].selected>0:
				profile.slasher_ability_upgrades.append("%s_%s_l%d_%s"%[id,branch.id,MILESTONES[index],"power" if upgrade_pickers[index].selected==1 else "flow"])
		for milestone in [10,15,20]:
			if milestone<=int(profile.level):profile.slasher_evolution_path.append("%s_branch_%s_stage_%d"%[id,branch.id,milestone])
	state._recalculate_profile(profile);state.set_selected_gear(gear_options[gear_picker.selected])
	state.inventory_items.clear();applied_items.clear()
	for item_id in loot_checks:
		if loot_checks[item_id].button_pressed:state.add_inventory_item(item_id,1);applied_items.append(item_id)
	state.recalculate_derived_stats();state.current_health=state.max_health;state.class_resource=state.get_class_resource_max()
	reset_arena()
	_refresh_armory_displays()

func reset_arena() -> void:
	if is_instance_valid(combat_root):remove_child(combat_root);combat_root.queue_free()
	damage_by_type.clear();live_respawns.clear();arena_generation+=1
	combat_root=Node2D.new();combat_root.name="Combat";combat_root.z_index=10;add_child(combat_root)
	state.current_health=state.max_health;state.class_resource=state.get_class_resource_max()
	player=PLAYER.new();player.name="TrainingPlayer";player.setup(state);player.position=Vector2(-180,100);player.position_sanitizer=_safe_position;combat_root.add_child(player)
	SlasherActiveEffects.ensure_runtime(player,ActiveItems.held(state))
	combo_panel.bind_player(player)
	player.defeated.connect(func():call_deferred("reset_arena"))
	player.aim_direction=Vector2.RIGHT
	var points: Array[Vector2]=[Vector2(120,0)]
	var walkable: Dictionary = {}
	for x in int(FLOOR.size.x/50.0):
		for y in int(FLOOR.size.y/50.0):walkable[Vector2i(x,y)]=true
	training_navigation=SlasherGridPathfinder.new().configure(walkable,[],FLOOR.position,50)
	if dummy_mode=="cluster":points=[Vector2(100,-65),Vector2(240,-65),Vector2(170,65)]
	if dummy_mode=="live":points=[Vector2(180,-100),Vector2(200,50),Vector2(100,140)]
	for point in points:_spawn_training_enemy(point,dummy_mode=="live",arena_generation)
	elapsed=0.0;hud_timer=0.0
	combat_root.process_mode=Node.PROCESS_MODE_DISABLED if editor.visible else Node.PROCESS_MODE_INHERIT
	_update_camera(0.0)
	_update_hud()

func _spawn_training_enemy(point:Vector2,is_live:bool,generation:int)->SlasherEnemy:
	if generation!=arena_generation or not is_instance_valid(combat_root):return null
	var enemy:SlasherEnemy=LIVE.new() if is_live else DUMMY.new()
	enemy.configure(1,dummy_mode=="boss","feral_wolf");enemy.target=player;enemy.position=point;enemy.max_health=100 if is_live else 1000;enemy.health=enemy.max_health;enemy.pathfinder=training_navigation;combat_root.add_child(enemy);enemy.damage_reported.connect(_on_target_damage.bind(enemy))
	if is_live:enemy.defeated.connect(_on_live_enemy_defeated.bind(point,generation))
	return enemy

func _on_live_enemy_defeated(_enemy:SlasherEnemy,_reward:int,spawn_point:Vector2,generation:int)->void:
	if dummy_mode=="live" and generation==arena_generation:live_respawns.append({"time":3.0,"point":spawn_point,"generation":generation})

func _process_live_respawns(delta:float)->void:
	if dummy_mode!="live" or editor.visible:return
	for index in range(live_respawns.size()-1,-1,-1):
		var pending:Dictionary=live_respawns[index];pending.time=float(pending.time)-delta
		if float(pending.time)<=0.0:
			_spawn_training_enemy(Vector2(pending.point),true,int(pending.generation));live_respawns.remove_at(index)
		else:live_respawns[index]=pending

func _on_target_damage(amount: int, kind: String, _source: String, _critical: bool, _target: SlasherEnemy) -> void:
	damage_by_type[kind]=int(damage_by_type.get(kind,0))+amount
	_update_hud()

func _safe_position(position: Vector2) -> Vector2:
	return Vector2(clampf(position.x,FLOOR.position.x+24,FLOOR.end.x-24),clampf(position.y,FLOOR.position.y+24,FLOOR.end.y-24))

func _update_camera(delta:float)->void:
	if not is_instance_valid(camera) or not is_instance_valid(player):return
	var half_view:=get_viewport_rect().size/(camera.zoom*2.0);var target:=player.global_position
	target.x=FLOOR.get_center().x if half_view.x>=FLOOR.size.x*0.5 else clampf(target.x,FLOOR.position.x+half_view.x,FLOOR.end.x-half_view.x)
	target.y=FLOOR.get_center().y if half_view.y>=FLOOR.size.y*0.5 else clampf(target.y,FLOOR.position.y+half_view.y,FLOOR.end.y-half_view.y)
	camera.global_position=target if delta<=0.0 else camera.global_position.lerp(target,1.0-exp(-7.0*delta))

func set_editor_visible(visible: bool) -> void:
	editor.visible=visible
	if is_instance_valid(combat_root):combat_root.process_mode=Node.PROCESS_MODE_DISABLED if visible else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(player):player.basic_mouse_held=false
	_update_hud()

func toggle_combo_panel() -> void:
	combo_panel.visible=not combo_panel.visible
	combo_button.button_pressed=combo_panel.visible
	if is_instance_valid(player):player.basic_mouse_held=false
	combo_panel.refresh()

func return_to_armory() -> void:
	if is_instance_valid(controller) and controller.has_method("leave_testing_ground"):controller.leave_testing_ground()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_B:refill_active_item();get_viewport().set_input_as_handled()
			KEY_ESCAPE:return_to_armory();get_viewport().set_input_as_handled()
			KEY_C:toggle_combo_panel();get_viewport().set_input_as_handled()
			KEY_R:reset_arena();get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not editor.visible and is_instance_valid(player):
		elapsed+=delta;queue_redraw();_update_camera(delta);_process_armory_interactions();_process_live_respawns(delta)
		if Input.is_action_just_pressed("slasher_special"):use_active_item()
		if active_recharge_time>0.0:
			active_recharge_time=maxf(0.0,active_recharge_time-delta)
			if active_recharge_time<=0.0:
				var item_id:=ActiveItems.held(state)
				if not item_id.is_empty():ActiveItems.give(state,item_id);_refresh_armory_displays();_show_notice(String(ActiveItems.item(item_id).get("name",item_id))+" ready",0.8)
	if notice_time>0.0:notice_time=maxf(0.0,notice_time-delta)
	hud_timer-=delta
	if hud_timer<=0.0:_update_hud();hud_timer=0.15

func _update_hud() -> void:
	if not is_instance_valid(player):return
	var total := 0
	for value in damage_by_type.values():total+=int(value)
	var active_id:=ActiveItems.held(state);var active_name:="Empty active slot" if active_id.is_empty() else String(ActiveItems.item(active_id).get("name",active_id));var active_state:="READY" if ActiveItems.is_ready(state) else "%.1fs"%active_recharge_time
	hud.text="Testing ground  ·  %s / %s  ·  HP %d/%d  ·  %s %d/%d\n%s · %s  ·  Damage %d  ·  %.1f DPS over %.1fs%s"%[state.selected_class_name,state.selected_gear.display_name,player.health,player.max_health,state.get_class_resource_name(),state.class_resource,state.get_class_resource_max(),active_name,active_state,total,float(total)/maxf(1.0,elapsed),elapsed,"  ·  PAUSED" if editor.visible else ""]
	if dummy_mode=="live":
		hud.text="Testing ground  ·  %s / %s  ·  HP %d/%d  ·  %s %d/%d\n%s · %s  ·  Live combat practice%s"%[state.selected_class_name,state.selected_gear.display_name,player.health,player.max_health,state.get_class_resource_name(),state.class_resource,state.get_class_resource_max(),active_name,active_state,"  ·  PAUSED" if editor.visible else ""]
	var type_totals: Array[String]=[]
	for kind in damage_by_type:type_totals.append("%s %d"%[String(kind).capitalize(),int(damage_by_type[kind])])
	hud.text+="\n"+("Damage types: "+"  ·  ".join(type_totals) if not type_totals.is_empty() else "Targets show damage numbers and types · Reset before comparing builds")
	var names: Array[String]=[]
	for slot in ["basic","special","defensive","movement"]:names.append("%s %.1fs"%[player._action_name(slot),float(player.cooldowns[slot])])
	actions.text="WASD move  ·  Walk into displays to swap  ·  Click attack  ·  Space active item  ·  B refill  ·  R reset\n"+"   |   ".join(names)
	if is_instance_valid(armory_prompt):armory_prompt.text=notice_text if notice_time>0.0 else armory_prompt.text

func _draw() -> void:
	draw_rect(FLOOR.grow(32),Color("#11110f"))
	draw_rect(FLOOR,Color("#34372f"))
	for row in int(ceil(FLOOR.size.y/50.0)):
		for column in int(ceil(FLOOR.size.x/50.0)):
			var stone := Rect2(FLOOR.position+Vector2(column*50,row*50),Vector2(48,48))
			stone=stone.intersection(FLOOR)
			draw_rect(stone,Color("#2b302e") if (row+column)%2==0 else Color("#30352f"))
			draw_line(stone.position,stone.position+Vector2(stone.size.x,0),Color("#44463b"),1)
	draw_rect(FLOOR,Color("#aa834a"),false,5.0)
	draw_rect(FLOOR.grow(-10),Color("#66563b"),false,2.0)
	# Item rails frame the combat floor without obstructing its centre.
	for y in [-425.0,425.0]:
		draw_line(Vector2(-860,y),Vector2(860,y),Color("#8b6a3d"),7.0)
		draw_line(Vector2(-860,y-3),Vector2(860,y-3),Color("#d5aa5f"),2.0)
	draw_arc(Vector2.ZERO,210,0.0,TAU,96,Color("#66694e"),3.0)
	draw_arc(Vector2.ZERO,202,0.0,TAU,96,Color("#464e41"),1.0)
	for index in 8:
		var direction := Vector2.RIGHT.rotated(index*PI/4)
		draw_line(direction*190,direction*215,Color("#b09457"),4)
	for point in [Vector2(-835,-330),Vector2(835,-330),Vector2(-835,330),Vector2(835,330)]:
		draw_circle(point,34,Color(1,0.4,0.06,0.08))
		draw_circle(point,17,Color("#171a18"))
		draw_arc(point,17,0,TAU,24,Color("#b28746"),3)
		FIRE.flame(self,point+Vector2(0,-12),1.25,elapsed,point.x)
		FIRE.embers(self,point,12,elapsed,4)
	draw_string(ThemeDB.fallback_font,Vector2(-200,-335),"THE ARMORY  /  PROVING FLOOR",HORIZONTAL_ALIGNMENT_CENTER,400,20,Color("#d5bb88"))

class ArmoryItemDisplay extends Node2D:
	var item_id:=""
	var display_name:=""
	var compatible:=true
	var selected:=false
	var row_side:=1
	var clock:=0.0
	func _ready()->void:set_process(true);queue_redraw()
	func _process(delta:float)->void:clock+=delta;queue_redraw()
	func _draw()->void:
		var bob:=sin(clock*2.4+position.x*0.013)*3.0;var icon_at:=Vector2(0,bob)
		if selected:
			draw_circle(icon_at,23.0,Color(1.0,0.78,0.3,0.18));draw_arc(icon_at,22.0,0,TAU,24,Color("#ffd66f"),2.5)
		draw_circle(Vector2(0,8.0*row_side),16.0,Color(0.05,0.055,0.06,0.88));draw_arc(Vector2(0,8.0*row_side),16.0,0,TAU,20,Color("#755f42"),2.0)
		SlasherActiveEffects.draw_icon(self,item_id,icon_at,30.0,not compatible)
		if not compatible:draw_line(Vector2(-11,-11),Vector2(11,11),Color(0.8,0.3,0.3,0.8),2.5)

class ArmoryClassPodium extends Node2D:
	var class_id:=""
	var display_name:=""
	var selected:=false
	var clock:=0.0
	func _ready()->void:set_process(true);queue_redraw()
	func _process(delta:float)->void:clock+=delta;queue_redraw()
	func _class_color()->Color:
		return {"warrior":Color("#d45d45"),"mage":Color("#5a8fe6"),"healer":Color("#79c96b"),"tank":Color("#b59a70"),"rogue":Color("#9671c8"),"summoner":Color("#55b8a7")}.get(class_id,Color.WHITE)
	func _draw()->void:
		var color:=_class_color();var pulse:=1.0+sin(clock*3.0)*0.06
		draw_ellipse(Vector2.ZERO,29.0,17.0,Color(0.03,0.035,0.04,0.92))
		draw_arc(Vector2.ZERO,29.0*pulse,0,TAU,30,Color(color,0.9 if selected else 0.55),4.0 if selected else 2.0)
		draw_circle(Vector2(0,-5),10.0,Color(color,0.82));draw_string(ThemeDB.fallback_font,Vector2(-22,4),display_name.left(1),HORIZONTAL_ALIGNMENT_CENTER,44,14,Color.WHITE)
		draw_string(ThemeDB.fallback_font,Vector2(-38,29),display_name.to_upper(),HORIZONTAL_ALIGNMENT_CENTER,76,10,Color("#fff1cf") if selected else Color("#c6b58f"))
