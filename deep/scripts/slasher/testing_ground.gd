extends Node2D

const PLAYER := preload("res://scripts/slasher/slasher_player.gd")
const DUMMY := preload("res://scripts/slasher/training_dummy.gd")
const LIVE := preload("res://scripts/slasher/training_combatant.gd")
const POPUP := preload("res://scripts/slasher/training_damage_popup.gd")
const FIRE := preload("res://scripts/slasher/slasher_fire_visuals.gd")
const PYROMANCY := preload("res://scripts/slasher/slasher_pyromancy.gd")
const WARRIOR_KITS := preload("res://scripts/slasher/slasher_warrior_kits.gd")
const MAGE_KITS := preload("res://scripts/slasher/slasher_mage_kits.gd")
const FLOOR := Rect2(-470,-270,940,540)
const CLASS_IDS := ["warrior","mage","healer","tank","rogue","summoner"]
const MILESTONES := [7,9,11,13,17,19]
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
var elapsed := 0.0
var hud_timer := 0.0
var dummy_mode := "cluster"
var applied_items: Array[String] = []
var damage_by_type: Dictionary = {}
var target_popups: Dictionary = {}
var popup_counts: Dictionary = {}

func setup(game_controller: Node) -> void:
	controller = game_controller

func _ready() -> void:
	_ensure_controls()
	camera = Camera2D.new(); camera.name="ArenaCamera"; add_child(camera); camera.make_current()
	get_viewport().size_changed.connect(_resize)
	_build_ui()
	_resize()
	_refresh_class()
	apply_build()
	set_editor_visible(true)
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

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text=text; button.custom_minimum_size.y=36; button.pressed.connect(callback); parent.add_child(button); return button

func _label(parent: Node, text: String) -> Label:
	var label := Label.new(); label.text=text; label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label); return label

func _set_loot_label(selected: bool, check: CheckBox, caption: String) -> void:
	check.text=("[x]  " if selected else "[ ]  ")+caption

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.name="TestingHUD"; add_child(layer)
	var screen := Control.new(); screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); screen.mouse_filter=Control.MOUSE_FILTER_IGNORE; layer.add_child(screen)
	var top := HBoxContainer.new(); top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); top.offset_left=18; top.offset_right=-18; top.offset_top=12; screen.add_child(top)
	_button(top,"Builds  [B]",func():set_editor_visible(not editor.visible))
	_button(top,"Reset  [R]",reset_arena)
	_button(top,"Single target",func():dummy_mode="single";reset_arena())
	_button(top,"Cluster",func():dummy_mode="cluster";reset_arena())
	_button(top,"Boss target",func():dummy_mode="boss";reset_arena())
	_button(top,"Live enemies",func():dummy_mode="live";reset_arena())
	_button(top,"Return to armory",return_to_armory)
	hud = _label(screen,""); hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE); hud.offset_left=22; hud.offset_top=58; hud.offset_right=-22; hud.offset_bottom=115
	actions = _label(screen,""); actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE); actions.offset_left=22; actions.offset_top=-60; actions.offset_right=-22; actions.offset_bottom=-12
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

func reset_arena() -> void:
	if is_instance_valid(combat_root):remove_child(combat_root);combat_root.queue_free()
	damage_by_type.clear();target_popups.clear();popup_counts.clear()
	combat_root=Node2D.new();combat_root.name="Combat";combat_root.z_index=10;add_child(combat_root)
	state.current_health=state.max_health;state.class_resource=state.get_class_resource_max()
	player=PLAYER.new();player.name="TrainingPlayer";player.setup(state);player.position=Vector2(-180,100);player.position_sanitizer=_safe_position;combat_root.add_child(player)
	combo_panel.bind_player(player)
	player.defeated.connect(func():call_deferred("reset_arena"))
	player.aim_direction=Vector2.RIGHT
	var points: Array[Vector2]=[Vector2(120,0)]
	var walkable: Dictionary = {}
	for x in 19:
		for y in 11:walkable[Vector2i(x,y)]=true
	var navigation := SlasherGridPathfinder.new().configure(walkable,[],FLOOR.position,50)
	if dummy_mode=="cluster":points=[Vector2(100,-65),Vector2(240,-65),Vector2(170,65)]
	if dummy_mode=="live":points=[Vector2(180,-100),Vector2(200,50),Vector2(100,140)]
	for point in points:
		var enemy: SlasherEnemy=DUMMY.new() if dummy_mode!="live" else LIVE.new()
		enemy.configure(1,dummy_mode=="boss","feral_wolf");enemy.target=player;enemy.position=point;enemy.max_health=1000 if dummy_mode!="live" else 100;enemy.health=enemy.max_health
		enemy.pathfinder=navigation
		combat_root.add_child(enemy)
		enemy.damage_reported.connect(_on_target_damage.bind(enemy))
	elapsed=0.0;hud_timer=0.0
	combat_root.process_mode=Node.PROCESS_MODE_DISABLED if editor.visible else Node.PROCESS_MODE_INHERIT
	_update_hud()

func _on_target_damage(amount: int, kind: String, source: String, critical: bool, target: SlasherEnemy) -> void:
	damage_by_type[kind]=int(damage_by_type.get(kind,0))+amount
	var target_id := target.get_instance_id()
	var active: Array=target_popups.get(target_id,[])
	active=active.filter(func(reference:WeakRef):return is_instance_valid(reference.get_ref()) and not reference.get_ref().is_queued_for_deletion())
	# Bound overlapping numbers, while keeping every hit in the damage totals.
	while active.size()>=6:
		var oldest: Node=active.pop_front().get_ref()
		if is_instance_valid(oldest):oldest.queue_free()
	var popup := POPUP.new()
	var ordinal := int(popup_counts.get(target_id,0))
	var lane := ordinal%3
	popup_counts[target_id]=ordinal+1
	popup.setup(amount,kind,source,critical,lane)
	combat_root.add_child(popup);popup.global_position=target.global_position+Vector2((lane-1)*60,-66)
	active.append(weakref(popup));target_popups[target_id]=active
	_update_hud()

func _safe_position(position: Vector2) -> Vector2:
	return Vector2(clampf(position.x,FLOOR.position.x+24,FLOOR.end.x-24),clampf(position.y,FLOOR.position.y+24,FLOOR.end.y-24))

func set_editor_visible(visible: bool) -> void:
	editor.visible=visible
	if is_instance_valid(combat_root):combat_root.process_mode=Node.PROCESS_MODE_DISABLED if visible else Node.PROCESS_MODE_INHERIT
	if is_instance_valid(player):player.basic_mouse_held=false
	if visible:class_picker.grab_focus()
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
			KEY_B,KEY_ESCAPE:set_editor_visible(not editor.visible);get_viewport().set_input_as_handled()
			KEY_C:toggle_combo_panel();get_viewport().set_input_as_handled()
			KEY_R:reset_arena();get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not editor.visible and is_instance_valid(player):elapsed+=delta;queue_redraw()
	hud_timer-=delta
	if hud_timer<=0.0:_update_hud();hud_timer=0.15

func _update_hud() -> void:
	if not is_instance_valid(player):return
	var total := 0
	for value in damage_by_type.values():total+=int(value)
	hud.text="Testing ground  ·  %s / %s  ·  HP %d/%d  ·  %s %d/%d\n%d loot effects  ·  Damage %d  ·  %.1f DPS over %.1fs%s"%[state.selected_class_name,state.selected_gear.display_name,player.health,player.max_health,state.get_class_resource_name(),state.class_resource,state.get_class_resource_max(),applied_items.size(),total,float(total)/maxf(1.0,elapsed),elapsed,"  ·  PAUSED" if editor.visible else ""]
	if dummy_mode=="live":
		hud.text="Testing ground  ·  %s / %s  ·  HP %d/%d  ·  %s %d/%d\n%d loot effects  ·  Live combat practice%s"%[state.selected_class_name,state.selected_gear.display_name,player.health,player.max_health,state.get_class_resource_name(),state.class_resource,state.get_class_resource_max(),applied_items.size(),"  ·  PAUSED" if editor.visible else ""]
	var type_totals: Array[String]=[]
	for kind in damage_by_type:type_totals.append("%s %d"%[String(kind).capitalize(),int(damage_by_type[kind])])
	hud.text+="\n"+("Damage types: "+"  ·  ".join(type_totals) if not type_totals.is_empty() else "Targets show damage numbers and types · Reset before comparing builds")
	var names: Array[String]=[]
	for slot in ["basic","special","defensive","movement"]:names.append("%s %.1fs"%[player._action_name(slot),float(player.cooldowns[slot])])
	actions.text="WASD move  ·  Mouse / right stick aim  ·  Click attack  ·  Space special  ·  Shift-click defend  ·  Right-click move\n"+"   |   ".join(names)

func _draw() -> void:
	draw_rect(FLOOR.grow(32),Color("#11110f"))
	draw_rect(FLOOR,Color("#34372f"))
	for row in 11:
		for column in 19:
			var stone := Rect2(FLOOR.position+Vector2(column*50,row*50),Vector2(48,48))
			stone=stone.intersection(FLOOR)
			draw_rect(stone,Color("#2b302e") if (row+column)%2==0 else Color("#30352f"))
			draw_line(stone.position,stone.position+Vector2(stone.size.x,0),Color("#44463b"),1)
	draw_rect(FLOOR,Color("#aa834a"),false,5.0)
	draw_rect(FLOOR.grow(-10),Color("#66563b"),false,2.0)
	draw_arc(Vector2.ZERO,210,0.0,TAU,96,Color("#66694e"),3.0)
	draw_arc(Vector2.ZERO,202,0.0,TAU,96,Color("#464e41"),1.0)
	for index in 8:
		var direction := Vector2.RIGHT.rotated(index*PI/4)
		draw_line(direction*190,direction*215,Color("#b09457"),4)
	for point in [Vector2(-425,-200),Vector2(425,-200),Vector2(-425,210),Vector2(425,210)]:
		draw_circle(point,34,Color(1,0.4,0.06,0.08))
		draw_circle(point,17,Color("#171a18"))
		draw_arc(point,17,0,TAU,24,Color("#b28746"),3)
		FIRE.flame(self,point+Vector2(0,-12),1.25,elapsed,point.x)
		FIRE.embers(self,point,12,elapsed,4)
	draw_string(ThemeDB.fallback_font,Vector2(-200,-205),"THE ARMORY  /  PROVING FLOOR",HORIZONTAL_ALIGNMENT_CENTER,400,20,Color("#d5bb88"))
