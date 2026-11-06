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
		var button:=Button.new();button.name="Tab_%s"%tab_id;button.text="Bestiary" if tab_id=="journal" else tab_id.capitalize();button.toggle_mode=true;button.custom_minimum_size=Vector2(150,42);button.pressed.connect(_select_tab.bind(tab_id));tab_row.add_child(button);tabs[tab_id]=button
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
	content=VBoxContainer.new();content.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_theme_constant_override("separation",10);scroll.add_child(content)
	var hint:=Label.new();hint.text="M / Start: Open or close  ·  Tab / LB: Cycle party";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_color_override("font_color",Color("#c7ae78"));body.add_child(hint)

func open(state:RunState,actor:SlasherPlayer)->void:
	if visible:return
	AudioCue.play_from(self,"ui_open",false)
	run_state=state;player=actor;previous_pause=get_tree().paused;visible=true;move_to_front();_select_tab(active_tab);get_tree().paused=true

func close()->void:
	if not visible:return
	AudioCue.play_from(self,"ui_close",false)
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
	var options:GameOptionsPanel=OPTIONS_PANEL.new();options.size_flags_horizontal=Control.SIZE_EXPAND_FILL;content.add_child(options);options.setup(false)

func _build_stats()->void:
	var header:=_section();content.add_child(header)
	var portrait:=TextureRect.new();portrait.custom_minimum_size=Vector2(120,120);portrait.texture=_class_portrait();portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;header.add_child(portrait)
	var profile:=RichTextLabel.new();profile.bbcode_enabled=true;profile.fit_content=true;profile.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var stats:Dictionary=run_state.get_stats()
	var runtime:SlasherItemRuntime=player.item_runtime
	var speed_value:float=player.speed*(runtime.conversion("speed_multiplier",1.0) if runtime else 1.0);var cooldown_reduction:float=runtime.conversion("cooldown_reduction")*100.0 if runtime else 0.0;var mitigation:float=runtime.conversion("damage_reduction")*100.0 if runtime else 0.0;var precision:int=int(runtime.conversion("precision_hits",6.0)) if runtime else 6
	profile.text="[font_size=26]%s%s[/font_size]\n%s\nVitality %d/%d    %s %d/%d\nSTR %d  DEX %d  CON %d  INT %d  WIS %d  CHA %d\nAttack %d    Spell %d    Speed %.0f\nCooldown reduction %.1f%% · Mitigation %.1f%% · Precision every %d hits\nGear: %s"%[run_state.selected_class_name,(" · Level %d"%run_state.get_level()) if GameBalance.leveling_enabled() else "",run_state.get_profile_summary(),player.health,player.max_health,run_state.get_class_resource_name(),run_state.class_resource,run_state.get_class_resource_max(),stats.str,stats.dex,stats.con,stats.int,stats.wis,stats.cha,player.attack_power,player.spell_power,speed_value,cooldown_reduction,mitigation,precision,run_state.selected_gear.display_name if run_state.selected_gear else "None"];header.add_child(profile)
	var actions:Dictionary=GameBalance.get_class_data(run_state.selected_class_id).get("actions",{})
	for slot in ["basic","movement","special","defensive"]:
		var tuning:=run_state.get_effective_slasher_ability_tuning(slot);var action:Dictionary=actions.get(slot,{})
		content.add_child(_text_panel("[font_size=19][b]%s · %s[/b][/font_size]\n%s\n%s"%[slot.capitalize(),String(action.get("name",slot.capitalize())),String(action.get("description","")), _tuning_summary(tuning)]))
	var combos: Array[Dictionary]=player.combo_runtime.recipes if is_instance_valid(player) and player.combo_runtime!=null else GameBalance.get_slasher_combos(run_state.selected_class_id)
	if not combos.is_empty():
		content.add_child(_text_panel("[font_size=23][b]Combat Combos[/b][/font_size]\nComplete each step within 2.5 seconds. Confirmed hits and parries are marked explicitly."))
		for combo in combos:
			content.add_child(_text_panel("[font_size=19][b]%s[/b][/font_size]\n[color=#f4d178]%s[/color]\n%s"%[String(combo.get("name","Combo")),"  →  ".join(combo.get("step_labels",[])),String(combo.get("description",""))]))

func _build_progression()->void:
	if not GameBalance.leveling_enabled():
		content.add_child(_text_panel("[font_size=25][b]Upgrades come from items[/b][/font_size]\nLevelling is switched off for now. Open chests, claim treasure pedestals and trade with merchants to grow stronger. Your current items are listed under Items."));return
	content.add_child(_text_panel("[font_size=25][b]%s[/b][/font_size]\n%s\nShared level %d · Choose a permanent Slasher specialization."%[run_state.get_slasher_specialization_name(),run_state.get_slasher_progression_summary(),run_state.get_level()]))
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

# ---------------------------------------------------------------- bestiary
## The Bestiary tab: a filterable grid of every creature (silhouettes until you
## defeat one), and a page for the chosen one with its moving portrait, rank,
## health, how it fights, how to beat it and what it drops. Entries come from
## data/slasher_journal.json; drops from data/materials.json.
const BESTIARY_FILTERS:=["All","Verdant Forest","Stone Crypt","Balor's Hell"]
const BESTIARY_ANIMATIONS:=[&"idle_down",&"run_right",&"attack_down",&"idle_left"]
var bestiary_filter:="All"
var bestiary_selected:=""
var bestiary_grid:GridContainer
var bestiary_page:VBoxContainer
var bestiary_frames:SpriteFrames
var bestiary_animation_index:=0
var bestiary_frame:=0.0
var bestiary_clock:=0.0

static func enemy_rank(entry:Dictionary)->String:
	var rank:=String(entry.get("rank",""))
	if not rank.is_empty():return rank
	match String(entry.get("category","")):
		"Boss","Guardian":return "boss"
		"Elite":return "mini_boss"
	return "basic"

static func rank_label(rank:String)->String:
	return {"boss":"Boss","mini_boss":"Mini Boss"}.get(rank,"Basic")

static func drops_text(enemy_id:String,entry:Dictionary)->String:
	var rank:=enemy_rank(entry)
	var trophy:=Materials.for_enemy(enemy_id,enemy_id,true);var common:=Materials.for_enemy(enemy_id,enemy_id,false)
	match rank:
		"boss":return "%s (always)"%Materials.material_name(trophy) if not trophy.is_empty() else "Nothing"
		"mini_boss":
			var parts:Array[String]=[]
			if not trophy.is_empty():parts.append("%s ×2 (always)"%Materials.material_name(trophy))
			parts.append("a chance of a relic")
			return ", ".join(parts)
	return "%s (sometimes)"%Materials.material_name(common) if not common.is_empty() else "Nothing"

func _build_journal()->void:
	var journal:Dictionary=GameBalance.get_slasher_journal();var order:Array=journal.get("order",[])
	var known:=order.filter(func(id): return run_state.is_enemy_discovered(String(id))).size()
	var top:=HBoxContainer.new();top.add_theme_constant_override("separation",8);content.add_child(top)
	for filter_name:String in BESTIARY_FILTERS:
		var chip:=Button.new();chip.name="Filter_%s"%filter_name.replace(" ","").replace("'","");chip.text=filter_name;chip.toggle_mode=true;chip.button_pressed=filter_name==bestiary_filter;chip.custom_minimum_size=Vector2(0,34);chip.add_theme_font_size_override("font_size",15)
		chip.pressed.connect(func(): bestiary_filter=filter_name;_select_tab.call_deferred("journal"));top.add_child(chip)
	var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(spacer)
	var tally:=Label.new();tally.name="BestiaryTally";tally.text="%d of %d discovered"%[known,order.size()];tally.add_theme_color_override("font_color",Color("#c7ae78"));top.add_child(tally)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",14);content.add_child(row)
	bestiary_grid=GridContainer.new();bestiary_grid.name="BestiaryGrid";bestiary_grid.columns=4;bestiary_grid.add_theme_constant_override("h_separation",6);bestiary_grid.add_theme_constant_override("v_separation",6);row.add_child(bestiary_grid)
	var page_panel:=_section();page_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(page_panel)
	bestiary_page=VBoxContainer.new();bestiary_page.name="BestiaryPage";bestiary_page.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bestiary_page.add_theme_constant_override("separation",8);page_panel.add_child(bestiary_page)
	var shown:Array[String]=[]
	for enemy_value in order:
		var enemy_id:=String(enemy_value);var entry:Dictionary=GameBalance.get_slasher_journal_entry(enemy_id)
		if bestiary_filter!="All" and String(entry.get("dungeon",""))!=bestiary_filter:continue
		shown.append(enemy_id);bestiary_grid.add_child(_bestiary_tile(enemy_id,entry))
	if shown.is_empty():return
	if not shown.has(bestiary_selected):
		bestiary_selected=shown[0]
		for id in shown:
			if run_state.is_enemy_discovered(id):bestiary_selected=id;break
	_show_journal_entry(bestiary_selected)

func _bestiary_tile(enemy_id:String,entry:Dictionary)->Button:
	var discovered:=run_state.is_enemy_discovered(enemy_id);var rank:=enemy_rank(entry)
	var tile:=Button.new();tile.name="Beast_%s"%enemy_id;tile.toggle_mode=true;tile.custom_minimum_size=Vector2(98,104);tile.focus_mode=Control.FOCUS_ALL
	tile.tooltip_text=String(entry.get("name",enemy_id.capitalize())) if discovered else "Unknown creature"
	var style:=StyleBoxFlat.new();style.bg_color=Color("#1a130cd9");style.set_border_width_all(2);style.set_corner_radius_all(4)
	style.border_color=Color("#d9a52b") if rank=="boss" else (Color("#b07acb") if rank=="mini_boss" else Color("#5a4630"))
	var hover:=style.duplicate();hover.bg_color=Color("#2c2012e6");var picked:=style.duplicate();picked.bg_color=Color("#3b2a12f0");picked.border_color=Color("#f4d178");picked.set_border_width_all(3)
	tile.add_theme_stylebox_override("normal",style);tile.add_theme_stylebox_override("hover",hover);tile.add_theme_stylebox_override("pressed",picked);tile.add_theme_stylebox_override("hover_pressed",picked);tile.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	tile.button_pressed=enemy_id==bestiary_selected
	var art:=TextureRect.new();art.name="Art";art.mouse_filter=Control.MOUSE_FILTER_IGNORE;art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);art.offset_left=4;art.offset_top=2;art.offset_right=-4;art.offset_bottom=-20
	art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	art.texture=_beast_texture(enemy_id,&"idle_down",0);art.modulate=Color.WHITE if discovered else Color(0.0,0.0,0.0,0.72);tile.add_child(art)
	if art.texture==null:tile.add_child(_beast_glyph(String(entry.get("name",enemy_id)) if discovered else "?",34,discovered))
	var caption:=Label.new();caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_top=-20;caption.offset_bottom=-2;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.clip_text=true
	caption.text=(String(entry.get("name",enemy_id)).replace(" Wolf","") if discovered else "???");caption.add_theme_font_size_override("font_size",12);caption.add_theme_color_override("font_color",Color("#e9dcc0") if discovered else Color("#77828a"));tile.add_child(caption)
	var kills:=run_state.get_enemy_defeat_count(enemy_id)
	if kills>0:
		var badge:=Label.new();badge.mouse_filter=Control.MOUSE_FILTER_IGNORE;badge.text="×%d"%kills;badge.position=Vector2(6,3);badge.add_theme_font_size_override("font_size",11);badge.add_theme_color_override("font_color",Color("#f4d178"));badge.add_theme_color_override("font_outline_color",Color.BLACK);badge.add_theme_constant_override("outline_size",4);tile.add_child(badge)
	tile.pressed.connect(func(): _show_journal_entry(enemy_id))
	return tile

## Stand-in for creatures drawn in code (the great guardians): their initials.
func _beast_glyph(beast_name:String,size:int,discovered:bool)->Label:
	var glyph:=Label.new();glyph.name="Glyph";glyph.mouse_filter=Control.MOUSE_FILTER_IGNORE;glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);glyph.offset_bottom=-16 if size<50 else 0
	glyph.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;glyph.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var initials:=""
	for word:String in beast_name.split(" ",false).slice(0,2):initials+=word.left(1).to_upper()
	glyph.text=initials if discovered else "?";glyph.add_theme_font_size_override("font_size",size);glyph.add_theme_color_override("font_color",Color("#d9a52b") if discovered else Color("#3a3128"))
	return glyph

func _beast_texture(enemy_id:String,animation:StringName,frame:int)->Texture2D:
	var frames:SpriteFrames=SlasherSpriteLibrary.enemy_frames(enemy_id)
	if frames==null:return null
	if not frames.has_animation(animation):animation=&"idle_down"
	if not frames.has_animation(animation):
		var names:=frames.get_animation_names()
		if names.is_empty():return null
		animation=names[0]
	return frames.get_frame_texture(animation,frame%maxi(1,frames.get_frame_count(animation)))

func _show_journal_entry(enemy_id:String)->void:
	if bestiary_page==null:return
	bestiary_selected=enemy_id
	if bestiary_grid!=null:
		for tile in bestiary_grid.get_children():(tile as Button).set_pressed_no_signal(tile.name=="Beast_%s"%enemy_id)
	_clear(bestiary_page)
	var discovered:=run_state.is_enemy_discovered(enemy_id);var entry:Dictionary=GameBalance.get_slasher_journal_entry(enemy_id)
	bestiary_frames=SlasherSpriteLibrary.enemy_frames(enemy_id) if discovered else null;bestiary_animation_index=0;bestiary_frame=0.0;bestiary_clock=0.0
	var head:=HBoxContainer.new();head.add_theme_constant_override("separation",14);bestiary_page.add_child(head)
	var stage:=PanelContainer.new();var stage_style:=StyleBoxFlat.new();stage_style.bg_color=Color("#0b0906");stage_style.set_corner_radius_all(6);stage_style.border_color=Color("#3d2f1d");stage_style.set_border_width_all(1);stage.add_theme_stylebox_override("panel",stage_style);stage.custom_minimum_size=Vector2(176,150);head.add_child(stage)
	journal_portrait=TextureRect.new();journal_portrait.name="Portrait";journal_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;journal_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;journal_portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;stage.add_child(journal_portrait)
	journal_portrait.texture=_beast_texture(enemy_id,&"idle_down",0);journal_portrait.modulate=Color.WHITE if discovered else Color(0,0,0,0.85)
	if journal_portrait.texture==null:stage.add_child(_beast_glyph(String(entry.get("name",enemy_id)) if discovered else "?",64,discovered))
	journal_detail=RichTextLabel.new();journal_detail.name="Summary";journal_detail.bbcode_enabled=true;journal_detail.fit_content=true;journal_detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;head.add_child(journal_detail)
	if not discovered:
		journal_detail.text="[font_size=26][color=#9aa3aa]Unknown Creature[/color][/font_size]\n[color=#c7ae78]%s[/color]\n\nDefeat one to fill in this page: how it fights, how to beat it and what it drops."%String(entry.get("dungeon","Somewhere out there"))
		return
	var rank:=enemy_rank(entry);var rank_color:String={"boss":"#f4d178","mini_boss":"#d3a6ea"}.get(rank,"#b9c4a8")
	var health:=run_state.get_enemy_health_seen(enemy_id)
	var health_text:="%d health"%health if health>0 else "Health not yet measured"
	journal_detail.text="[font_size=26][b]%s[/b][/font_size]\n[color=%s]%s[/color]  ·  [color=#c7ae78]%s[/color]\n\n[color=#e8a3a3]%s[/color]  ·  hits you for 1 heart\nDefeated %d\n\n[i][color=#cbbd9c]%s[/color][/i]"%[String(entry.get("name",enemy_id.capitalize())),rank_color,rank_label(rank),String(entry.get("dungeon","")),health_text,run_state.get_enemy_defeat_count(enemy_id),String(entry.get("description",""))]
	bestiary_page.add_child(_bestiary_section("How it fights",String(entry.get("behavior","")),"#e2b45c"))
	bestiary_page.add_child(_bestiary_section("How to beat it",String(entry.get("tactics","Learn its rhythm and strike between its attacks.")),"#8fd18a"))
	bestiary_page.add_child(_bestiary_section("Drops",drops_text(enemy_id,entry),"#d3a6ea"))
	bestiary_page.add_child(_bestiary_section("Found",String(entry.get("habitat","")),"#9cc3e0"))

func _bestiary_section(title:String,body:String,color:String)->RichTextLabel:
	var label:=RichTextLabel.new();label.name=title.replace(" ","");label.bbcode_enabled=true;label.fit_content=true;label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.text="[font_size=17][b][color=%s]%s[/color][/b][/font_size]\n%s"%[color,title.to_upper(),body];return label

func _process(delta:float)->void:
	if not visible or active_tab!="journal" or bestiary_frames==null or not is_instance_valid(journal_portrait):return
	var animation:StringName=BESTIARY_ANIMATIONS[bestiary_animation_index]
	if not bestiary_frames.has_animation(animation):animation=&"idle_down"
	bestiary_frame+=delta*maxf(1.0,bestiary_frames.get_animation_speed(animation));bestiary_clock+=delta
	if bestiary_clock>=2.4:
		bestiary_clock=0.0;bestiary_frame=0.0;bestiary_animation_index=(bestiary_animation_index+1)%BESTIARY_ANIMATIONS.size()
	journal_portrait.texture=_beast_texture(String(bestiary_selected),animation,int(bestiary_frame))

func _class_portrait()->Texture2D:
	if player and player.sprite and player.sprite.sprite_frames:return player.sprite.sprite_frames.get_frame_texture(player.sprite.animation,player.sprite.frame)
	return null
func _tuning_summary(tuning:Dictionary)->String:
	var parts:Array[String]=["Cooldown %.2fs"%float(tuning.get("cooldown",0.0))]
	for pair in [["damage_coefficient","Power ×"],["flat_damage","Flat"],["reach","Reach"],["projectile_range","Range"],["movement_distance","Distance"],["effect_duration","Duration"],["invulnerability","Invulnerable"]]:
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
