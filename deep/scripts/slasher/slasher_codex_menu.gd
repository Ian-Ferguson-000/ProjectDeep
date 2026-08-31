extends Control
class_name SlasherCodexMenu

signal closed

const MENU_FRAME:=preload("res://assets/ui/character_menu/menu_frame.png")
const OPTIONS_PANEL:=preload("res://scripts/ui/game_options_panel.gd")

var run_state:RunState
var player:SlasherPlayer
var content:VBoxContainer
var tabs:Dictionary={}
var active_tab:="stats"
var previous_pause:=false
var journal_portrait:TextureRect
var journal_detail:RichTextLabel

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP;visible=false
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color("#08100ce8");add_child(shade)
	var frame:=PanelContainer.new();frame.anchor_left=0.5;frame.anchor_top=0.5;frame.anchor_right=0.5;frame.anchor_bottom=0.5;frame.offset_left=-500;frame.offset_top=-315;frame.offset_right=500;frame.offset_bottom=315;frame.add_theme_stylebox_override("panel",_texture_style(MENU_FRAME,44));add_child(frame)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_%s"%side,24)
	frame.add_child(margin)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",12);margin.add_child(body)
	var title:=Label.new();title.text="SLASHER CODEX";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",28);title.add_theme_color_override("font_color",Color("#f4d178"));body.add_child(title)
	var tab_row:=HBoxContainer.new();tab_row.alignment=BoxContainer.ALIGNMENT_CENTER;tab_row.add_theme_constant_override("separation",10);body.add_child(tab_row)
	for tab_id in ["stats","progression","items","journal","options"]:
		var button:=Button.new();button.text=tab_id.capitalize();button.toggle_mode=true;button.custom_minimum_size=Vector2(150,42);button.pressed.connect(_select_tab.bind(tab_id));tab_row.add_child(button);tabs[tab_id]=button
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",10);scroll.add_child(content)
	var hint:=Label.new();hint.text="M / Tab / Start: Open  ·  Esc / B: Close";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_color_override("font_color",Color("#c7ae78"));body.add_child(hint)

func open(state:RunState,actor:SlasherPlayer)->void:
	if visible:return
	run_state=state;player=actor;previous_pause=get_tree().paused;visible=true;move_to_front();_select_tab(active_tab);get_tree().paused=true

func close()->void:
	if not visible:return
	visible=false;get_tree().paused=previous_pause;closed.emit()

func _unhandled_input(event:InputEvent)->void:
	if not visible:return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("character_menu"):
		close();get_viewport().set_input_as_handled()

func _select_tab(tab_id:String)->void:
	active_tab=tab_id
	for key in tabs:var button:Button=tabs[key];button.button_pressed=String(key)==active_tab
	_clear(content)
	match active_tab:
		"progression":_build_progression()
		"items":_build_items()
		"journal":_build_journal()
		"options":_build_options()
		_:_build_stats()

func _build_options()->void:
	var options:GameOptionsPanel=OPTIONS_PANEL.new();options.size_flags_horizontal=Control.SIZE_EXPAND_FILL;options.setup(false);content.add_child(options)

func _build_stats()->void:
	var header:=_section();content.add_child(header)
	var portrait:=TextureRect.new();portrait.custom_minimum_size=Vector2(120,120);portrait.texture=_class_portrait();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;header.add_child(portrait)
	var profile:=RichTextLabel.new();profile.bbcode_enabled=true;profile.fit_content=true;profile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var stats:Dictionary=run_state.get_stats()
	var runtime:SlasherItemRuntime=player.item_runtime
	var speed_value:float=player.speed*(runtime.conversion("speed_multiplier",1.0) if runtime else 1.0);var cooldown_reduction:float=runtime.conversion("cooldown_reduction")*100.0 if runtime else 0.0;var mitigation:float=runtime.conversion("damage_reduction")*100.0 if runtime else 0.0;var precision:int=int(runtime.conversion("precision_hits",6.0)) if runtime else 6
	profile.text="[font_size=26]%s · Level %d[/font_size]\n%s\nVitality %d/%d    %s %d/%d\nSTR %d  DEX %d  CON %d  INT %d  WIS %d  CHA %d\nAttack %d    Spell %d    Speed %.0f\nCooldown reduction %.1f%% · Mitigation %.1f%% · Precision every %d hits\nGear: %s"%[run_state.selected_class_name,run_state.get_level(),run_state.get_profile_summary(),player.health,player.max_health,run_state.get_class_resource_name(),run_state.class_resource,run_state.get_class_resource_max(),stats.str,stats.dex,stats.con,stats.int,stats.wis,stats.cha,player.attack_power,player.spell_power,speed_value,cooldown_reduction,mitigation,precision,run_state.selected_gear.display_name if run_state.selected_gear else "None"];header.add_child(profile)
	var actions:Dictionary=GameBalance.get_class_data(run_state.selected_class_id).get("actions",{})
	for slot in ["basic","movement","special","defensive"]:
		var tuning:=run_state.get_effective_slasher_ability_tuning(slot);var action:Dictionary=actions.get(slot,{})
		content.add_child(_text_panel("[font_size=19][b]%s · %s[/b][/font_size]\n%s\n%s"%[slot.capitalize(),String(action.get("name",slot.capitalize())),String(action.get("description","")), _tuning_summary(tuning)]))

func _build_progression()->void:
	content.add_child(_text_panel("[font_size=25][b]%s[/b][/font_size]\n%s\nShared level %d · Slasher choices are independent from Strategy."%[run_state.get_slasher_specialization_name(),run_state.get_slasher_progression_summary(),run_state.get_level()]))
	var selected:Array=run_state.get_slasher_selected_choices()
	for level:int in [3,5,7,9,10,11,13,15,17,19,20]:
		var line:String="[color=#77828a]Locked[/color]"
		if level<=run_state.get_level():line="[color=#d4c18c]Available[/color]"
		for choice_id:Variant in selected:
			var choice:Dictionary=GameBalance.get_slasher_progression_choice(run_state.selected_class_id,String(choice_id))
			if int(choice.get("level",-1))==level:line="[color=#7fd68a]%s[/color]"%String(choice.get("name","Selected"));break
		if level in [10,15,20] and level<=run_state.get_level():line="[color=#7fd68a]%s[/color]"%run_state.get_slasher_specialization_name()
		content.add_child(_text_panel("[font_size=18][b]Level %d[/b][/font_size]\n%s"%[level,line]))
	if run_state.has_pending_slasher_progression_choice():content.add_child(_text_panel("[color=#f4d178]A progression choice is pending and will be resolved before the next Slasher floor.[/color]"))

func _build_items()->void:
	var consumable_lines:Array[String]=[];var carried:Array[String]=run_state.get_consumables()
	for index:int in range(carried.size()):consumable_lines.append("[%d] %s"%[index+1,String(GameBalance.get_consumable(carried[index]).get("name",carried[index].capitalize()))])
	content.add_child(_text_panel("[font_size=23][b]Carried Resources[/b][/font_size]\nGold %d    Keys %d    Consumables %d/%d\n%s"%[run_state.gold,run_state.keys,carried.size(),run_state.get_consumable_capacity(),"    ".join(consumable_lines) if not consumable_lines.is_empty() else "No consumables"]))
	var gear_text:="%s\n%s"%[run_state.selected_gear.display_name,run_state.selected_gear.description] if run_state.selected_gear else "None"
	content.add_child(_text_panel("[font_size=23][b]Equipped Gear[/b][/font_size]\n%s"%gear_text))
	var inventory:Array[Dictionary]=run_state.get_inventory_items()
	if inventory.is_empty():content.add_child(_text_panel("[font_size=22][b]Relics[/b][/font_size]\nNo relics carried."))
	for entry in inventory:
		var item:Dictionary=GameBalance.get_item(String(entry.get("id","")));var duration:String=String(entry.get("duration_type","dungeon_bound")).replace("_"," ").capitalize()
		if int(entry.get("remaining_floors",0))>0:duration+=" · %d floors"%int(entry.remaining_floors)
		var item_id:String=String(entry.get("id",""));var state_text:String="Ready"
		if player.item_runtime and player.item_runtime.cooldowns.has(item_id):state_text="Cooldown %.1fs"%float(player.item_runtime.cooldowns[item_id])
		content.add_child(_text_panel("[font_size=20][b]%s · %s[/b][/font_size]\n%s\n[color=#e8c66a]%s[/color]\n%s · %s"%[String(item.get("name",entry.get("id","Relic"))),String(item.get("rarity","common")).capitalize(),String(item.get("description","")),GameBalance.get_slasher_item_rules_text(item_id),duration,state_text]))

func _build_journal()->void:
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);content.add_child(row)
	var list:=VBoxContainer.new();list.custom_minimum_size=Vector2(300,0);list.add_theme_constant_override("separation",6);row.add_child(list)
	var detail_panel:=_section();detail_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(detail_panel)
	var detail_column:=VBoxContainer.new();detail_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_panel.add_child(detail_column)
	journal_portrait=TextureRect.new();journal_portrait.custom_minimum_size=Vector2(0,180);journal_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;journal_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;detail_column.add_child(journal_portrait)
	journal_detail=RichTextLabel.new();journal_detail.bbcode_enabled=true;journal_detail.fit_content=true;journal_detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_column.add_child(journal_detail)
	var journal:Dictionary=GameBalance.get_slasher_journal();var first_id:String=""
	for enemy_value in journal.get("order",[]):
		var enemy_id:String=String(enemy_value);var discovered:bool=run_state.is_enemy_discovered(enemy_id);var entry:Dictionary=GameBalance.get_slasher_journal_entry(enemy_id)
		var button:=Button.new();button.text=("%s  ·  %d defeated"%[String(entry.get("name",enemy_id.capitalize())),run_state.get_enemy_defeat_count(enemy_id)]) if discovered else "Unknown Creature";button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size.y=48;button.pressed.connect(_show_journal_entry.bind(enemy_id));list.add_child(button)
		if first_id.is_empty():first_id=enemy_id
	if not first_id.is_empty():_show_journal_entry(first_id)

func _show_journal_entry(enemy_id:String)->void:
	var discovered:bool=run_state.is_enemy_discovered(enemy_id);var entry:Dictionary=GameBalance.get_slasher_journal_entry(enemy_id);var frames:SpriteFrames=SlasherSpriteLibrary.enemy_frames(enemy_id)
	journal_portrait.texture=frames.get_frame_texture(&"idle_down",0) if frames and frames.has_animation(&"idle_down") else null;journal_portrait.modulate=Color.WHITE if discovered else Color(0.02,0.025,0.03,1)
	if not discovered:journal_detail.text="[font_size=27]Unknown Creature[/font_size]\n\nDefeat this enemy to record its identity and combat information.";return
	var enemy_tuning:Dictionary=GameBalance.get_slasher_enemy_tuning("forest_boss" if enemy_id=="dark_druid" else "forest_normal")
	journal_detail.text="[font_size=27]%s[/font_size]\n%s · Defeated %d\n\n%s\n\nHabitat: %s\nBehavior: %s\n\nBase HP %d · Base Attack %d · Speed %.0f\nTraits: %s"%[String(entry.get("name",enemy_id.capitalize())),String(entry.get("category","Standard")),run_state.get_enemy_defeat_count(enemy_id),String(entry.get("description","")),String(entry.get("habitat","Unknown")),String(entry.get("behavior","Unknown")),int(enemy_tuning.get("health_base",0)),int(enemy_tuning.get("damage_base",0)),float(enemy_tuning.get("speed_base",0)),", ".join(entry.get("traits",[]))]

func _class_portrait()->Texture2D:
	if player and player.sprite and player.sprite.sprite_frames:return player.sprite.sprite_frames.get_frame_texture(player.sprite.animation,player.sprite.frame)
	return null
func _tuning_summary(tuning:Dictionary)->String:
	var parts:Array[String]=["Cooldown %.2fs"%float(tuning.get("cooldown",0.0))]
	for pair in [["damage_coefficient","Power ×"],["flat_damage","Flat"],["reach","Reach"],["projectile_range","Range"],["movement_distance","Distance"],["effect_duration","Duration"]]:
		if tuning.has(pair[0]):parts.append("%s %s"%[pair[1],tuning[pair[0]]])
	if int(tuning.get("resource_cost",0))>0:parts.append("Cost %d"%int(tuning.resource_cost))
	return " · ".join(parts)
func _text_panel(text:String)->PanelContainer:
	var panel:=_section();var label:=RichTextLabel.new();label.bbcode_enabled=true;label.fit_content=true;label.text=text;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;panel.add_child(label);return panel
func _section()->PanelContainer:
	var panel:=PanelContainer.new();var style:=StyleBoxFlat.new();style.bg_color=Color("#120d08d9");style.border_color=Color("#d9a52b");style.set_border_width_all(2);style.set_corner_radius_all(3)
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,10)
	panel.add_theme_stylebox_override("panel",style);return panel
func _texture_style(texture:Texture2D,margin:float)->StyleBoxTexture:
	var style:=StyleBoxTexture.new();style.texture=texture
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		style.set_texture_margin(side,margin);style.set_content_margin(side,14)
	return style
func _clear(node:Node)->void:
	for child in node.get_children():child.free()
