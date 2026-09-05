extends Node2D

const TILE_SIZE := 60
const GRID_W := 18
const GRID_H := 10
const LAYOUT_PATH := "res://data/tavern_layout.json"
const PLAYER_IDLE_DOWN := preload("res://assets/sprite_packs/Player/IDLE/idle_down.png")
const TAVERN_KEEPER := preload("res://assets/generated_characters/tavern_keeper.png")
const TAVERN_BACKDROP := preload("res://assets/tavern/tavern_hub_backdrop.png")
const BoardPieceScene := preload("res://scenes/components/BoardPiece.tscn")
const DIALOGUE_CHAT := preload("res://scripts/ui/dialogue_chat.gd")
const RECRUITMENT_DIALOGUE := preload("res://scripts/ui/recruitment_dialogue.gd")
const TAVERN_THEME := preload("res://scripts/ui/tavern_ui_theme.gd")
const OPTIONS_PANEL := preload("res://scripts/ui/game_options_panel.gd")

var controller: Node
var run_state: RunState
var gear_options: Array[GearData] = []
var selected_gear: GearData
var arrival_summary: Dictionary = {}
var message := ""
var pending_story_lines: Array = []
var pending_story_context := ""
var player_pos := Vector2i(9, 8)
var layout: Dictionary = {}
var stations: Array[Dictionary] = []
var blocked_cells: Dictionary = {}
var click_navigation_active := false
var active_station: Dictionary = {}
var backdrop_layer: CanvasLayer
var backdrop: TextureRect
var station_markers := Node2D.new()
var expedition_gate_hit_target: Button

@onready var board: Node2D = $Board
@onready var ground_layer: TileMapLayer = $Board/GroundLayer
@onready var wall_layer: TileMapLayer = $Board/WallLayer
@onready var fixture_layer: TileMapLayer = $Board/FixtureLayer
@onready var prop_sprites: Node2D = $Board/PropSprites
@onready var tokens_root: Node2D = $Board/Tokens
@onready var player_token: BoardPiece = $Board/Tokens/PlayerToken
@onready var bartender_token: BoardPiece = $Board/Tokens/BartenderToken
@onready var gear_rack_token: BoardPiece = $Board/Tokens/GearRackToken
@onready var forest_door_token: BoardPiece = $Board/Tokens/ForestDoorToken
@onready var ui_root: Control = $UI/Root
@onready var legacy_dialogue_panel: Panel = $UI/Root/DialoguePanel
@onready var legacy_title: Label = $UI/Root/TitleLabel
@onready var legacy_status: Label = $UI/Root/StatusLabel

var crypt_door_token: BoardPiece
var forest_merchant_token: BoardPiece
var crypt_merchant_token: BoardPiece
var merchant_shop_panel: MerchantShopPanel
var top_hud: PanelContainer
var hud_label: Label
var hud_date_label:Label
var hud_bank_label:Label
var hud_company_label:Label
var settings_button:Button
var options_backdrop:ColorRect
var options_panel:GameOptionsPanel
var prompt_panel: PanelContainer
var prompt_label: Label
var dialogue_panel: PanelContainer
var dialogue_speaker: Label
var dialogue_text: Label
var armory_backdrop: ColorRect
var armory_list: VBoxContainer
var armory_detail: Label
var expedition_backdrop: ColorRect
var expedition_panel: PanelContainer
var expedition_list: VBoxContainer
var expedition_title: Label
var expedition_detail: Label
var expedition_party_count: Label
var expedition_readiness: Label
var expedition_launch: Button
var expedition_id := "forest"
var expedition_mode := RunState.PLAY_MODE_STRATEGY
var expedition_mode_buttons: Dictionary = {}
var expedition_party_list: VBoxContainer
var selected_party_ids: Array[String] = []
var results_backdrop: ColorRect
var results_text: RichTextLabel
var tutorial_continue: Button
var story_dialogue: DialogueChat
var company_backdrop:ColorRect
var company_panel:PanelContainer
var company_list:VBoxContainer
var company_tabs:TabContainer
var company_pages:Dictionary={}
var company_party_dungeon_id:="forest"
var company_party_initialized:=false
var toolbar:HBoxContainer
var toolbar_buttons:Dictionary={}
var calendar_backdrop:ColorRect
var calendar_text:RichTextLabel
var recruitment_dialogue:RecruitmentDialogue
var candidate_stage:=Node2D.new()
var candidate_buttons:Dictionary={}
var candidate_sprites:Dictionary={}
var npc_hit_targets:Dictionary={}
var arrival_tween:Tween
var arrivals_running:=false
var arrivals_need_sequence:=false
var dismissal_confirmation:ConfirmationDialog
var pending_dismissal_id:=""

func setup(game_controller: Node, state: RunState, options: Array[GearData], intro_message: String, summary: Dictionary = {}, story_lines: Array = [], story_context: String = "") -> void:
	controller = game_controller
	run_state = state
	gear_options = options
	message = intro_message
	arrival_summary = summary.duplicate(true)
	if arrival_summary.is_empty() and state!=null and state.campaign!=null:arrival_summary=state.campaign.pending_settlement_summary.duplicate(true)
	pending_story_lines = story_lines.duplicate(true)
	pending_story_context = story_context
	selected_gear = _remembered_gear_or_default()
	if run_state != null and selected_gear != null: run_state.set_selected_gear(selected_gear)
	if is_inside_tree(): _refresh_ui()

func _ready() -> void:
	ui_root.focus_mode = Control.FOCUS_ALL
	_load_layout()
	_hide_legacy_presentation()
	_setup_backdrop()
	_setup_tokens()
	_build_hud()
	_build_toolbar()
	_build_dialogue_banner()
	_build_armory_modal()
	_build_expedition_modal()
	_build_results_modal()
	_build_company_modal()
	_build_calendar_modal()
	_build_options_modal()
	_build_recruitment_dialogue()
	_build_tutorial_prompt()
	_build_story_dialogue()
	_setup_merchant_shops()
	get_viewport().size_changed.connect(_layout_scene)
	_layout_scene()
	_refresh_ui()
	_build_candidate_stage()
	if not arrival_summary.is_empty() or not message.is_empty(): _show_arrival_results()
	elif not pending_story_lines.is_empty(): call_deferred("_play_pending_story")
	else:call_deferred("_continue_arrival_queue")

func _build_tutorial_prompt() -> void:
	tutorial_continue = Button.new(); tutorial_continue.name = "TutorialContinue"; tutorial_continue.text = "Choose the First Adventurer"; tutorial_continue.set_anchors_preset(Control.PRESET_BOTTOM_WIDE); tutorial_continue.offset_left = 430; tutorial_continue.offset_right = -430; tutorial_continue.offset_top = -92; tutorial_continue.offset_bottom = -36; tutorial_continue.pressed.connect(_continue_tutorial); _style_button(tutorial_continue); ui_root.add_child(tutorial_continue); tutorial_continue.visible = false

func _build_story_dialogue() -> void:
	story_dialogue = DIALOGUE_CHAT.new()
	story_dialogue.name = "StoryDialogue"
	story_dialogue.conversation_finished.connect(_on_story_finished)
	ui_root.add_child(story_dialogue)

func _play_pending_story() -> void:
	if story_dialogue == null or pending_story_lines.is_empty(): return
	var lines := pending_story_lines.duplicate(true)
	pending_story_lines.clear()
	story_dialogue.play(lines)

func _on_story_finished() -> void:
	var context := pending_story_context
	pending_story_context = ""
	if context == "tutorial_opening" and controller != null and controller.has_method("advance_tutorial_from_tavern"):
		controller.advance_tutorial_from_tavern()
	else:
		if run_state!=null and run_state.campaign!=null:
			if context=="former_keeper_confrontation":run_state.campaign.mark_former_keeper_encounter_seen()
			run_state.campaign.pending_story_context="";run_state.campaign.save_atomic()
		_continue_arrival_queue()

func _show_tutorial_prompt() -> void:
	if tutorial_continue == null: return
	tutorial_continue.visible = run_state.campaign.tutorial_phase == CampaignState.TUTORIAL_DIALOGUE
	if tutorial_continue.visible: _show_dialogue("Mara Vell", message)

func _continue_tutorial() -> void:
	if controller != null and controller.has_method("advance_tutorial_from_tavern"): controller.advance_tutorial_from_tavern()

func _load_layout() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	layout = parsed if parsed is Dictionary else {}
	var spawn: Array = layout.get("player_spawn", [9, 8])
	player_pos = Vector2i(int(spawn[0]), int(spawn[1]))
	for entry in layout.get("stations", []):
		if entry is Dictionary: stations.append(entry.duplicate(true))
	for value in layout.get("blocked", []):
		if value is Array and value.size() >= 2: blocked_cells[Vector2i(int(value[0]), int(value[1]))] = true

func _hide_legacy_presentation() -> void:
	legacy_dialogue_panel.visible = false
	legacy_title.visible = false
	legacy_status.visible = false
	ground_layer.visible = false; wall_layer.visible = false; fixture_layer.visible = false; prop_sprites.visible = false

func _setup_backdrop() -> void:
	backdrop_layer = CanvasLayer.new(); backdrop_layer.layer = -10; add_child(backdrop_layer)
	backdrop = TextureRect.new(); backdrop.texture = TAVERN_BACKDROP; backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE; backdrop_layer.add_child(backdrop)
	station_markers.name = "StationMarkers"; board.add_child(station_markers);station_markers.visible=false
	expedition_gate_hit_target=Button.new();expedition_gate_hit_target.name="ExpeditionGateHitTarget";expedition_gate_hit_target.flat=true;expedition_gate_hit_target.focus_mode=Control.FOCUS_NONE;expedition_gate_hit_target.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;expedition_gate_hit_target.tooltip_text="Expedition Gate · Choose a dungeon";expedition_gate_hit_target.pressed.connect(_on_expedition_gate_clicked);ui_root.add_child(expedition_gate_hit_target)

func _setup_tokens() -> void:
	player_token.sprite_texture = PLAYER_IDLE_DOWN; player_token.sprite_region_enabled = true; player_token.sprite_region = Rect2(0,0,96,80); player_token.sprite_scale = Vector2(0.92,0.92); player_token.show_label = false; player_token.show_panel = false
	bartender_token.sprite_texture = TAVERN_KEEPER; bartender_token.sprite_region_enabled = false; bartender_token.sprite_scale = Vector2(0.036,0.036); bartender_token.show_label = false; bartender_token.show_panel = false
	gear_rack_token.visible = false
	forest_door_token.visible = false
	crypt_door_token = BoardPieceScene.instantiate(); crypt_door_token.name = "CryptDoorToken"; crypt_door_token.visible = false; tokens_root.add_child(crypt_door_token)
	forest_merchant_token = BoardPieceScene.instantiate(); forest_merchant_token.name = "ForestMerchantToken"; tokens_root.add_child(forest_merchant_token)
	crypt_merchant_token = BoardPieceScene.instantiate(); crypt_merchant_token.name = "CryptMerchantToken"; tokens_root.add_child(crypt_merchant_token)
	_configure_merchant_token(forest_merchant_token, "forest")
	_configure_merchant_token(crypt_merchant_token, "crypt")
	player_token.visible=false
	_add_npc_target("mara","Mara Vell",_open_npc_merchant.bind("tavern"))
	if forest_merchant_token.visible:_add_npc_target("forest","Thistle Fen",_open_npc_merchant.bind("forest"))
	if crypt_merchant_token.visible:_add_npc_target("crypt","Sister Caldris",_open_npc_merchant.bind("crypt"))

func _open_npc_merchant(merchant_id:String)->void:
	if not arrivals_running and not _modal_visible():_open_merchant_shop(merchant_id)

func _add_npc_target(id:String,label_text:String,action:Callable)->void:
	var button:=Button.new();button.name="%sNpcTarget"%id.capitalize();button.text=label_text;button.tooltip_text="Speak with %s"%label_text;button.pressed.connect(action);TAVERN_THEME.apply_nameplate(button,"",false,true);ui_root.add_child(button);npc_hit_targets[id]=button

func _build_toolbar()->void:
	toolbar=HBoxContainer.new();toolbar.name="TavernToolbar";toolbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE);toolbar.offset_left=190;toolbar.offset_right=-190;toolbar.offset_top=-70;toolbar.offset_bottom=-10;toolbar.alignment=BoxContainer.ALIGNMENT_CENTER;toolbar.add_theme_constant_override("separation",8);ui_root.add_child(toolbar)
	var entries := [["Calendar","calendar",Callable(self,"_open_calendar")],["Company Ledger","ledger",Callable(self,"_open_company_ledger")],["Armory","armory",Callable(self,"_open_armory")],["Merchants","merchants",Callable(self,"_open_tavern_merchant")],["Expedition","expedition",Callable(self,"_open_dungeon_selector")]]
	for entry in entries:
		var title:=String(entry[0]);var button:=Button.new();button.name="%sToolbarButton"%title.replace(" ","");button.text=title;button.icon=TAVERN_THEME.icon(String(entry[1]));button.expand_icon=true;button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT;button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.pressed.connect(entry[2]);TAVERN_THEME.apply_button(button,title=="Expedition",14,Vector2(190 if title=="Expedition" else 150,56));toolbar.add_child(button);toolbar_buttons[title]=button
	for index in toolbar.get_child_count():
		var button:=toolbar.get_child(index) as Button;button.focus_neighbor_left=toolbar.get_child((index-1+toolbar.get_child_count())%toolbar.get_child_count()).get_path();button.focus_neighbor_right=toolbar.get_child((index+1)%toolbar.get_child_count()).get_path()

func _open_tavern_merchant()->void:_open_merchant_shop("tavern")

func _build_calendar_modal()->void:
	calendar_backdrop=_modal_backdrop("CalendarModal");var body:=_modal_panel(calendar_backdrop,"The Hearth Calendar",Vector2(820,610))
	calendar_text=RichTextLabel.new();calendar_text.bbcode_enabled=true;calendar_text.size_flags_vertical=Control.SIZE_EXPAND_FILL;calendar_text.add_theme_font_size_override("normal_font_size",16);body.add_child(calendar_text)
	calendar_text.focus_mode=Control.FOCUS_ALL
	var close:=Button.new();close.text="Close Calendar";close.pressed.connect(_close_modal.bind(calendar_backdrop));_style_button(close);body.add_child(close)

func _open_calendar()->void:
	var campaign:=run_state.campaign;var date:=campaign.get_calendar_date();var lines:Array[String]=["[font_size=26][color=#f1c565]%s, %s %d, Year %d[/color][/font_size]"%[date.weekday,date.season,date.season_day,date.year],"Season progress: Day %d of 28     Candidate wave: %d"%[date.season_day,campaign.candidate_wave_id],"\n[b]RECENT HEARTH HISTORY[/b]"]
	if campaign.calendar_history.is_empty():lines.append("No entries yet.")
	else:
		for index in range(campaign.calendar_history.size()-1,-1,-1):
			var event:Dictionary=campaign.calendar_history[index];lines.append("Day %d · %s — %s"%[int(event.get("day",1)),String(event.get("kind","event")).capitalize(),String(event.get("text",""))])
	calendar_text.text="\n".join(lines);_show_modal(calendar_backdrop,calendar_text)

func _build_recruitment_dialogue()->void:
	recruitment_dialogue=RECRUITMENT_DIALOGUE.new();recruitment_dialogue.recruit_requested.connect(_recruit_candidate);recruitment_dialogue.conversation_closed.connect(_restore_hub_focus);ui_root.add_child(recruitment_dialogue)

func _build_candidate_stage()->void:
	candidate_stage.name="CandidateStage";board.add_child(candidate_stage);_rebuild_candidate_targets(false)

func _candidate_seat(index:int)->Vector2:
	var viewport_size:=get_viewport_rect().size
	var total:=mini(7,run_state.campaign.get_candidates().size()+run_state.campaign.living_roster().size()) if run_state!=null and run_state.campaign!=null else 2
	var seats:Array[Vector2]
	if total<=2:seats=[Vector2(viewport_size.x*0.30,viewport_size.y*0.50),Vector2(viewport_size.x*0.70,viewport_size.y*0.50)]
	elif total==3:seats=[Vector2(viewport_size.x*0.25,viewport_size.y*0.50),Vector2(viewport_size.x*0.50,viewport_size.y*0.50),Vector2(viewport_size.x*0.75,viewport_size.y*0.50)]
	elif total==4:seats=[Vector2(viewport_size.x*0.20,viewport_size.y*0.50),Vector2(viewport_size.x*0.40,viewport_size.y*0.50),Vector2(viewport_size.x*0.60,viewport_size.y*0.50),Vector2(viewport_size.x*0.80,viewport_size.y*0.50)]
	else:seats=[Vector2(viewport_size.x*0.20,viewport_size.y*0.43),Vector2(viewport_size.x*0.40,viewport_size.y*0.43),Vector2(viewport_size.x*0.60,viewport_size.y*0.43),Vector2(viewport_size.x*0.80,viewport_size.y*0.43),Vector2(viewport_size.x*0.30,viewport_size.y*0.64),Vector2(viewport_size.x*0.50,viewport_size.y*0.64),Vector2(viewport_size.x*0.70,viewport_size.y*0.64)]
	return seats[index%seats.size()]

func _candidate_sprite_scale(class_id:String)->Vector2:
	return Vector2(2.5,2.5) if class_id=="warrior" else Vector2(1.3,1.3)

func _rebuild_candidate_targets(animate:bool)->void:
	for child in candidate_stage.get_children():child.queue_free()
	for button in candidate_buttons.values():if is_instance_valid(button):button.queue_free()
	candidate_buttons.clear();candidate_sprites.clear();var records:=run_state.campaign.get_candidates();var index:=0
	for candidate in records:
		var sprite:=AnimatedSprite2D.new();sprite.name="%sArrivalSprite"%candidate.id;sprite.sprite_frames=SlasherSpriteLibrary.player_frames(candidate.adventurer.class_id);sprite.scale=_candidate_sprite_scale(candidate.adventurer.class_id);sprite.position=Vector2(-80,430) if animate else _candidate_seat(index);candidate_stage.add_child(sprite);candidate_sprites[candidate.id]=sprite
		var idle:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,"idle","down");if not idle.is_empty():sprite.play(idle)
		var button:=Button.new();button.name="%sCandidateButton"%candidate.id;button.text="%s\n%s · Level %d"%[candidate.adventurer.display_name,candidate.adventurer.class_id.capitalize(),candidate.adventurer.level];button.position=_candidate_seat(index)+Vector2(-88,43);button.size=Vector2(176,48);button.tooltip_text="Speak with %s"%candidate.adventurer.display_name;button.pressed.connect(_open_candidate.bind(candidate.id));TAVERN_THEME.apply_nameplate(button,candidate.adventurer.class_id);_bind_character_highlight(button,sprite);button.visible=not animate;ui_root.add_child(button);candidate_buttons[candidate.id]=button;index+=1
	if not animate:
		for member in run_state.campaign.living_roster():
			if index>=7:break
			var sprite:=AnimatedSprite2D.new();sprite.name="%sRecruitedSprite"%member.id;sprite.sprite_frames=SlasherSpriteLibrary.player_frames(member.class_id);sprite.scale=_candidate_sprite_scale(member.class_id);sprite.position=_candidate_seat(index);candidate_stage.add_child(sprite);var idle:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,"idle","down");if not idle.is_empty():sprite.play(idle)
			var button:=Button.new();button.name="%sRecruitedButton"%member.id;button.text="%s  ✓\n%s · Level %d"%[member.display_name,member.class_id.capitalize(),member.level];button.position=_candidate_seat(index)+Vector2(-88,43);button.size=Vector2(176,48);button.tooltip_text="Recruited · Open %s's summary"%member.display_name;button.pressed.connect(_open_recruited_summary.bind(member.id));TAVERN_THEME.apply_nameplate(button,member.class_id,true);_bind_character_highlight(button,sprite);ui_root.add_child(button);candidate_buttons[member.id]=button;index+=1

func _bind_character_highlight(button:Button,sprite:AnimatedSprite2D)->void:
	var show_highlight:=func():
		if is_instance_valid(sprite):sprite.modulate=Color("#fff0b8")
	var clear_highlight:=func():
		if is_instance_valid(sprite):sprite.modulate=Color.WHITE
	button.mouse_entered.connect(show_highlight);button.focus_entered.connect(show_highlight);button.mouse_exited.connect(clear_highlight);button.focus_exited.connect(clear_highlight)

func _open_recruited_summary(character_id:String)->void:
	var member:=run_state.campaign.character(character_id)
	if member!=null:_show_dialogue(member.display_name,"%s · Level %d · %s · %s · HP %d/%d"%[member.class_id.capitalize(),member.level,member.gear_id.replace("_"," ").capitalize(),member.trait_name,member.current_health,member.max_health])

func _open_candidate(candidate_id:String)->void:
	if arrivals_running:return
	var candidate:=run_state.campaign.candidate_pool.get(candidate_id) as CandidateRecord
	if candidate!=null:recruitment_dialogue.open(candidate)

func _recruit_candidate(candidate_id:String)->void:
	var result:=run_state.campaign.recruit_candidate(candidate_id)
	if not bool(result.get("ok",false)):recruitment_dialogue.show_capacity_error(String(result.get("error","Recruitment failed.")));return
	recruitment_dialogue.close();message=String(result.get("message","Recruitment complete."));_select_recruited_character();_rebuild_candidate_targets(false);_refresh_ui()

func _select_recruited_character()->void:
	if not run_state.active_character_id.is_empty():return
	var living:=run_state.campaign.living_roster();if not living.is_empty():run_state.active_character_id=living[0].id;run_state.set_class(living[0].class_id)

func _continue_arrival_queue()->void:
	if run_state==null or run_state.campaign==null:return
	if run_state.campaign.last_presented_wave_id<run_state.campaign.candidate_wave_id and not run_state.campaign.candidate_pool.is_empty():arrivals_need_sequence=true;run_state.campaign.tavern_phase=CampaignState.TAVERN_CALENDAR;_open_calendar()
	else:_restore_hub_focus()

func _start_arrivals()->void:
	arrivals_running=true;run_state.campaign.tavern_phase=CampaignState.TAVERN_ARRIVALS;toolbar.visible=false
	for target in npc_hit_targets.values():(target as Button).visible=false
	_rebuild_candidate_targets(true);arrival_tween=create_tween();arrival_tween.set_parallel(true);var index:=0
	for candidate in run_state.campaign.get_candidates():
		var sprite:AnimatedSprite2D=candidate_sprites[candidate.id];var run_animation:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,"run","right");if not run_animation.is_empty():sprite.play(run_animation)
		arrival_tween.tween_property(sprite,"position",_candidate_seat(index),0.8).set_delay(index*0.28).set_trans(Tween.TRANS_SINE);index+=1
	arrival_tween.chain().tween_callback(_finish_arrivals)

func _finish_arrivals()->void:
	if not arrivals_running:return
	if arrival_tween!=null and arrival_tween.is_valid():arrival_tween.kill()
	for candidate in run_state.campaign.get_candidates():
		var sprite:AnimatedSprite2D=candidate_sprites.get(candidate.id);if sprite!=null:sprite.position=_candidate_seat(run_state.campaign.get_candidates().find(candidate));var idle:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,"idle","down");if not idle.is_empty():sprite.play(idle)
		var button:Button=candidate_buttons.get(candidate.id);if button!=null:button.visible=true
	arrivals_running=false;arrivals_need_sequence=false;toolbar.visible=true
	for target in npc_hit_targets.values():(target as Button).visible=true
	run_state.campaign.mark_arrivals_presented(run_state.campaign.candidate_wave_id);_refresh_ui();_restore_hub_focus()

func _build_hud() -> void:
	top_hud = PanelContainer.new(); top_hud.name = "TavernHUD"; top_hud.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_hud.offset_left = 18; top_hud.offset_top = 8; top_hud.offset_right = -18; top_hud.offset_bottom = 64
	var hud_style:=TAVERN_THEME.panel(Color("#0b0d0df5"),TAVERN_THEME.BRONZE,4,2);hud_style.set_content_margin_all(0);top_hud.add_theme_stylebox_override("panel",hud_style); ui_root.add_child(top_hud)
	var margin := MarginContainer.new(); margin.add_theme_constant_override("margin_left",10); margin.add_theme_constant_override("margin_right",8); margin.add_theme_constant_override("margin_top",4); margin.add_theme_constant_override("margin_bottom",4); top_hud.add_child(margin)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);margin.add_child(row)
	var crest:=TextureRect.new();crest.name="HearthCrest";crest.texture=TAVERN_THEME.icon("hearth");crest.custom_minimum_size=Vector2(40,40);crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;crest.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;row.add_child(crest)
	var title:=Label.new();title.name="HearthTitle";title.text="THE HEARTH";title.custom_minimum_size.x=170;title.add_theme_font_size_override("font_size",19);title.add_theme_color_override("font_color",TAVERN_THEME.HIGHLIGHT_GOLD);title.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;row.add_child(title)
	_add_hud_divider(row);hud_date_label=_add_hud_group(row,"season","DateStatus");_add_hud_divider(row);hud_bank_label=_add_hud_group(row,"bank","BankStatus");_add_hud_divider(row);hud_company_label=_add_hud_group(row,"roster","CompanyStatus");hud_company_label.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
	settings_button=Button.new();settings_button.name="SettingsButton";settings_button.icon=TAVERN_THEME.icon("settings");settings_button.tooltip_text="Options";settings_button.accessibility_name="Options";settings_button.pressed.connect(_open_options);TAVERN_THEME.apply_button(settings_button,false,14,Vector2(42,42));settings_button.text="";row.add_child(settings_button)
	hud_label=hud_date_label

func _add_hud_divider(row:HBoxContainer)->void:
	var divider:=VSeparator.new();divider.custom_minimum_size.x=1;divider.add_theme_constant_override("separation",4);row.add_child(divider)

func _add_hud_group(row:HBoxContainer,icon_id:String,node_name:String)->Label:
	var group:=HBoxContainer.new();group.name=node_name+"Group";group.add_theme_constant_override("separation",7);row.add_child(group)
	var symbol:=TextureRect.new();symbol.texture=TAVERN_THEME.icon(icon_id);symbol.custom_minimum_size=Vector2(25,25);symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;group.add_child(symbol)
	var label:=Label.new();label.name=node_name;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.add_theme_font_size_override("font_size",15);label.add_theme_color_override("font_color",TAVERN_THEME.IVORY);group.add_child(label);return label

func _build_options_modal()->void:
	options_backdrop=_modal_backdrop("OptionsModal");var body:=_modal_panel(options_backdrop,"Hearth Options",Vector2(690,590))
	options_panel=OPTIONS_PANEL.new();options_panel.name="TavernOptionsPanel";options_panel.size_flags_vertical=Control.SIZE_EXPAND_FILL;options_panel.close_requested.connect(_close_modal.bind(options_backdrop));body.add_child(options_panel);options_panel.setup(true)

func _open_options()->void:
	_show_modal(options_backdrop,options_panel.first_control)

func _build_dialogue_banner() -> void:
	dialogue_panel = PanelContainer.new(); dialogue_panel.name = "ContextBanner"; dialogue_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_panel.offset_left = 90; dialogue_panel.offset_top = -126; dialogue_panel.offset_right = -90; dialogue_panel.offset_bottom = -24
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06,0.04,0.025,0.96),Color(0.65,0.43,0.18),8)); ui_root.add_child(dialogue_panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_%s"%side,12)
	dialogue_panel.add_child(margin)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",4); margin.add_child(body)
	dialogue_speaker = Label.new(); dialogue_speaker.add_theme_font_size_override("font_size",17); dialogue_speaker.add_theme_color_override("font_color",Color(1.0,0.75,0.3)); body.add_child(dialogue_speaker)
	dialogue_text = Label.new(); dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; dialogue_text.add_theme_font_size_override("font_size",14); body.add_child(dialogue_text)
	prompt_panel = PanelContainer.new(); prompt_panel.name = "InteractionPrompt"; prompt_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_panel.offset_left = 360; prompt_panel.offset_top = -60; prompt_panel.offset_right = -360; prompt_panel.offset_bottom = -18
	prompt_panel.add_theme_stylebox_override("panel",_panel_style(Color(0.035,0.028,0.02,0.92),Color(0.82,0.58,0.22),10)); ui_root.add_child(prompt_panel)
	prompt_label = Label.new(); prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; prompt_label.add_theme_font_size_override("font_size",15); prompt_label.add_theme_color_override("font_color",Color(1,0.88,0.58)); prompt_panel.add_child(prompt_label)

func _modal_backdrop(name_value: String) -> ColorRect:
	var layer := ColorRect.new(); layer.name = name_value; layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.color = Color(0.015,0.01,0.008,0.78); layer.mouse_filter = Control.MOUSE_FILTER_STOP; layer.visible = false; ui_root.add_child(layer); return layer

func _modal_panel(parent: Control, title: String, size_value: Vector2) -> VBoxContainer:
	var preferred:=size_value;var available:=get_viewport_rect().size-Vector2(36,36);size_value=Vector2(minf(size_value.x,available.x),minf(size_value.y,available.y))
	var panel := PanelContainer.new();panel.set_anchors_preset(Control.PRESET_TOP_LEFT);panel.position=(get_viewport_rect().size-size_value)/2.0;panel.size=size_value;panel.set_meta("preferred_size",preferred);panel.add_theme_stylebox_override("panel",TAVERN_THEME.panel(Color("#21160ffb"),TAVERN_THEME.GOLD,6,2));parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_%s"%side,18)
	panel.add_child(margin)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",10); margin.add_child(body)
	var heading := Label.new(); heading.text = title; heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; heading.add_theme_font_size_override("font_size",25); heading.add_theme_color_override("font_color",TAVERN_THEME.HIGHLIGHT_GOLD); body.add_child(heading)
	return body

func _build_armory_modal() -> void:
	armory_backdrop = _modal_backdrop("ArmoryModal")
	var body := _modal_panel(armory_backdrop,"Class Armory",Vector2(760,560))
	armory_detail = Label.new(); armory_detail.custom_minimum_size = Vector2(0,78); armory_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(armory_detail)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(scroll)
	armory_list = VBoxContainer.new(); armory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; armory_list.add_theme_constant_override("separation",8); scroll.add_child(armory_list)
	var close := Button.new(); close.text = "Close"; close.pressed.connect(_close_modal.bind(armory_backdrop)); _style_button(close); body.add_child(close)

func _build_expedition_modal() -> void:
	expedition_backdrop = _modal_backdrop("ExpeditionModal")
	var body := _modal_panel(expedition_backdrop,"Plan an Expedition",Vector2(1160,660));expedition_panel=body.get_parent().get_parent() as PanelContainer
	var subtitle:=Label.new();subtitle.text="Choose a destination, select a combat mode, then confirm who will leave the safety of the Hearth.";subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.add_theme_color_override("font_color",Color(0.76,0.72,0.64));body.add_child(subtitle)
	var columns := HBoxContainer.new(); columns.size_flags_vertical = Control.SIZE_EXPAND_FILL; columns.add_theme_constant_override("separation",18); body.add_child(columns)
	var destinations:=VBoxContainer.new();destinations.custom_minimum_size=Vector2(390,0);destinations.add_theme_constant_override("separation",8);columns.add_child(destinations)
	var destination_heading:=Label.new();destination_heading.text="1  ·  CHOOSE A DESTINATION";destination_heading.add_theme_font_size_override("font_size",16);destination_heading.add_theme_color_override("font_color",Color(0.95,0.69,0.3));destinations.add_child(destination_heading)
	var list_scroll := ScrollContainer.new();list_scroll.name="DungeonListScroll";list_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; destinations.add_child(list_scroll)
	expedition_list = VBoxContainer.new(); expedition_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; expedition_list.add_theme_constant_override("separation",8); list_scroll.add_child(expedition_list)
	var details := VBoxContainer.new(); details.size_flags_horizontal = Control.SIZE_EXPAND_FILL; details.add_theme_constant_override("separation",9); columns.add_child(details)
	expedition_title = Label.new(); expedition_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; expedition_title.add_theme_font_size_override("font_size",22); expedition_title.add_theme_color_override("font_color",Color(1,0.8,0.4)); details.add_child(expedition_title)
	var mode_heading:=Label.new();mode_heading.text="2  ·  CHOOSE A COMBAT MODE";mode_heading.add_theme_color_override("font_color",Color(0.95,0.69,0.3));details.add_child(mode_heading)
	var mode_row := HBoxContainer.new(); mode_row.alignment = BoxContainer.ALIGNMENT_CENTER; mode_row.add_theme_constant_override("separation",10); details.add_child(mode_row)
	for mode in [RunState.PLAY_MODE_STRATEGY, RunState.PLAY_MODE_SLASHER]:
		var mode_button := Button.new(); mode_button.text = mode.capitalize(); mode_button.toggle_mode = true; mode_button.name = "%sModeButton" % mode.capitalize();mode_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL; mode_button.pressed.connect(_select_expedition_mode.bind(mode)); FantasyButton.apply_dark(mode_button,15,Vector2(0,54)); mode_row.add_child(mode_button); expedition_mode_buttons[mode] = mode_button
	var decision_columns:=HBoxContainer.new();decision_columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;decision_columns.add_theme_constant_override("separation",14);details.add_child(decision_columns)
	var briefing:=VBoxContainer.new();briefing.size_flags_horizontal=Control.SIZE_EXPAND_FILL;briefing.add_theme_constant_override("separation",6);decision_columns.add_child(briefing)
	var briefing_heading:=Label.new();briefing_heading.text="DESTINATION BRIEFING";briefing_heading.add_theme_color_override("font_color",Color(0.6,0.82,0.96));briefing.add_child(briefing_heading)
	var detail_scroll := ScrollContainer.new(); detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; briefing.add_child(detail_scroll)
	expedition_detail = Label.new(); expedition_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; expedition_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL; expedition_detail.add_theme_font_size_override("font_size",14); detail_scroll.add_child(expedition_detail)
	var party_column:=VBoxContainer.new();party_column.custom_minimum_size=Vector2(340,0);party_column.add_theme_constant_override("separation",6);decision_columns.add_child(party_column)
	var party_row:=HBoxContainer.new();party_column.add_child(party_row);var party_heading := Label.new(); party_heading.text = "3  ·  ASSEMBLE PARTY";party_heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL; party_heading.add_theme_color_override("font_color",Color(0.95,0.69,0.3)); party_row.add_child(party_heading)
	expedition_party_count=Label.new();expedition_party_count.name="ExpeditionPartyCount";expedition_party_count.add_theme_color_override("font_color",Color(0.58,0.86,0.66));party_row.add_child(expedition_party_count)
	var party_scroll:=ScrollContainer.new();party_scroll.name="ExpeditionPartyScroll";party_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;party_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;party_column.add_child(party_scroll)
	expedition_party_list = VBoxContainer.new();expedition_party_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL; expedition_party_list.add_theme_constant_override("separation",6);party_scroll.add_child(expedition_party_list)
	expedition_readiness=Label.new();expedition_readiness.name="ExpeditionReadiness";expedition_readiness.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;expedition_readiness.add_theme_font_size_override("font_size",15);details.add_child(expedition_readiness)
	var buttons := HBoxContainer.new(); buttons.alignment = BoxContainer.ALIGNMENT_CENTER; buttons.add_theme_constant_override("separation",12); body.add_child(buttons)
	var cancel := Button.new(); cancel.text = "Return to Tavern";cancel.size_flags_horizontal=Control.SIZE_EXPAND_FILL; cancel.pressed.connect(_close_modal.bind(expedition_backdrop)); _style_button(cancel); buttons.add_child(cancel)
	expedition_launch = Button.new(); expedition_launch.text = "Begin Expedition";expedition_launch.size_flags_horizontal=Control.SIZE_EXPAND_FILL; expedition_launch.pressed.connect(_launch_expedition); _style_button(expedition_launch); buttons.add_child(expedition_launch)

func _build_results_modal() -> void:
	results_backdrop = _modal_backdrop("RunResultsModal")
	var body := _modal_panel(results_backdrop,"Return to the Hearth",Vector2(680,500))
	results_text = RichTextLabel.new(); results_text.bbcode_enabled = true; results_text.fit_content = true; results_text.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(results_text)
	var close := Button.new(); close.name = "ContinueButton"; close.text = "Continue in Tavern"; close.pressed.connect(_close_modal.bind(results_backdrop)); _style_button(close); body.add_child(close)

func _build_company_modal()->void:
	company_backdrop=_modal_backdrop("CompanyLedgerModal")
	var body:=_modal_panel(company_backdrop,"Company Ledger",Vector2(1160,650));company_panel=body.get_parent().get_parent() as PanelContainer
	var subtitle:=Label.new();subtitle.text="Manage the company between expeditions. Changes here are permanent unless a recruit dies.";subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.add_theme_color_override("font_color",Color(0.78,0.72,0.62));body.add_child(subtitle)
	company_tabs=TabContainer.new();company_tabs.name="CompanyLedgerTabs";company_tabs.focus_mode=Control.FOCUS_ALL;company_tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;company_tabs.add_theme_font_size_override("font_size",17);body.add_child(company_tabs)
	for page_name in ["Resources","Party Builder","Improvements","Hall of Heroes","Memorial"]:
		var scroll:=ScrollContainer.new();scroll.name=page_name;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;company_tabs.add_child(scroll)
		var margin:=MarginContainer.new();margin.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_%s"%side,14)
		scroll.add_child(margin)
		var page:=VBoxContainer.new();page.name="%sPage"%page_name.replace(" ","");page.size_flags_horizontal=Control.SIZE_EXPAND_FILL;page.add_theme_constant_override("separation",12);margin.add_child(page);company_pages[page_name]=page
	company_list=company_pages["Improvements"]
	var close:=Button.new();close.text="Close Ledger";close.pressed.connect(_close_modal.bind(company_backdrop));_style_button(close);body.add_child(close)
	dismissal_confirmation=ConfirmationDialog.new();dismissal_confirmation.title="Dismiss Adventurer";dismissal_confirmation.dialog_text="This adventurer will leave the Hearth without compensation.";dismissal_confirmation.confirmed.connect(_confirm_dismissal);add_child(dismissal_confirmation)

func _open_company_ledger()->void:
	_refresh_company_ledger()
	_show_modal(company_backdrop,company_tabs)

func _purchase_tavern_upgrade(branch:String)->void:
	var result:=run_state.campaign.purchase_upgrade(branch);message=" ".join(result);run_state.autosave_campaign();_refresh_ui();call_deferred("_refresh_company_ledger")

func _refresh_company_ledger()->void:
	if company_pages.is_empty():return
	for page_value in company_pages.values():
		for child in (page_value as VBoxContainer).get_children():child.free()
	var campaign:=run_state.campaign
	_refresh_resources_page(campaign)
	_refresh_party_page(campaign)
	_refresh_improvements_page(campaign)
	_refresh_hall_page(campaign)
	_refresh_memorial_page(campaign)

func _refresh_resources_page(campaign:CampaignState)->void:
	var page:VBoxContainer=company_pages["Resources"]
	_add_ledger_heading("TAVERN RESOURCES",Color(1,0.78,0.32),page)
	_add_resource_card(page,"BANKED GOLD",str(campaign.banked_gold),"Spend with merchants or on Hearth improvements. Dungeon rewards are banked only after boss victory.",Color(0.95,0.72,0.25))
	_add_resource_card(page,"SUPPLIES",str(campaign.supplies),"Provision stock held by the Hearth. Supply spending will be introduced with the preparation system.",Color(0.78,0.72,0.48))
	_add_resource_card(page,"RELIC ESSENCE",str(campaign.relic_essence),"Permanent upgrade currency recovered from cleared checkpoints and banked on a safe return.",Color(0.55,0.84,1.0))
	_add_resource_card(page,"SUCCESSFUL LEVELS",str(campaign.successful_levels),"Lifetime levels brought home by victorious recruits. Requirements check this total but never spend it.",Color(0.58,0.9,0.62))
	_add_ledger_heading("UNIQUE RELICS",Color(0.76,0.62,0.9),page)
	var relics:=Label.new();relics.text="No unique relics recovered yet. Secret dungeons hold relics that remain with the company." if campaign.banked_relics.is_empty() else "  •  ".join(campaign.banked_relics).replace("_"," ").capitalize();relics.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;relics.add_theme_font_size_override("font_size",16);page.add_child(relics)
	_add_ledger_heading("HEARTH KEEPSAKES",Color(0.9,0.66,0.46),page)
	var keepsake := Label.new()
	keepsake.text = "No keepsake has been placed in the Hearth." if campaign.tutorial_keepsake_id.is_empty() else campaign.tutorial_keepsake_id.replace("_", " ").capitalize()+"\nA story keepsake only; it grants no combat or economy modifiers."
	keepsake.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keepsake.add_theme_font_size_override("font_size",16)
	page.add_child(keepsake)
	if campaign.tutorial_letter_unlocked:
		_add_ledger_heading("THE FORMER KEEPER'S LETTER",Color(0.72,0.78,0.9),page)
		var letter := Label.new()
		letter.text = "To whoever warms my hearth: profit from it while you can. A deed records a debt; it does not settle a claim. — Mara Vell"
		letter.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		letter.add_theme_font_size_override("font_size",16)
		letter.add_theme_color_override("font_color",Color(0.84,0.82,0.72))
		page.add_child(letter)

func _refresh_party_page(campaign:CampaignState)->void:
	var page:VBoxContainer=company_pages["Party Builder"]
	_add_ledger_heading("EXPEDITION PARTY BUILDER",Color(0.58,0.82,1.0),page)
	var capacity:=Label.new();capacity.text="Rooms %d / %d     Waiting candidates %d"%[campaign.living_roster().size(),campaign.get_roster_capacity(),campaign.candidate_pool.size()];capacity.add_theme_color_override("font_color",Color(1,0.78,0.32));page.add_child(capacity)
	var help:=Label.new();help.text="Plan the party that will be preselected at the Expedition Gate. Each recruit keeps independent health, equipment, resources, traits, and progression. Death is permanent.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.add_theme_color_override("font_color",Color(0.74,0.82,0.88));page.add_child(help)
	var controls:=HBoxContainer.new();controls.add_theme_constant_override("separation",12);page.add_child(controls)
	var dungeon_label:=Label.new();dungeon_label.text="Plan for:";dungeon_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;controls.add_child(dungeon_label)
	var dungeon_picker:=OptionButton.new();dungeon_picker.name="PartyDungeonPicker";dungeon_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL;var selected_index:=0
	for dungeon_id_value in GameBalance.get_dungeon_order():
		var dungeon_id:=String(dungeon_id_value)
		if not run_state.is_dungeon_unlocked(dungeon_id):continue
		var index:=dungeon_picker.item_count;dungeon_picker.add_item(String(GameBalance.get_dungeon(dungeon_id).get("name",dungeon_id.capitalize())));dungeon_picker.set_item_metadata(index,dungeon_id)
		if dungeon_id==company_party_dungeon_id:selected_index=index
	if dungeon_picker.item_count==0:dungeon_picker.add_item("Verdant Forest");dungeon_picker.set_item_metadata(0,"forest")
	dungeon_picker.select(selected_index);company_party_dungeon_id=String(dungeon_picker.get_item_metadata(selected_index));dungeon_picker.item_selected.connect(_ledger_party_dungeon_selected.bind(dungeon_picker));controls.add_child(dungeon_picker)
	var cap:=campaign.get_party_cap(company_party_dungeon_id);var valid:Array[String]=[]
	for member in campaign.living_roster():if member.status==CharacterRecord.STATUS_AVAILABLE:valid.append(member.id)
	selected_party_ids=selected_party_ids.filter(func(id:String)->bool:return valid.has(id)).slice(0,cap)
	if selected_party_ids.is_empty() and not company_party_initialized:selected_party_ids=valid.slice(0,mini(cap,valid.size()))
	company_party_initialized=true
	var count:=Label.new();count.name="PartySelectionCount";count.text="%d / %d selected"%[selected_party_ids.size(),cap];count.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;count.add_theme_color_override("font_color",Color(1,0.78,0.32));controls.add_child(count)
	var clear_party:=Button.new();clear_party.name="ClearPartyButton";clear_party.text="CLEAR";clear_party.tooltip_text="Remove every recruit from the planned party.";clear_party.disabled=selected_party_ids.is_empty();clear_party.pressed.connect(_clear_ledger_party);FantasyButton.apply_dark(clear_party,13);controls.add_child(clear_party)
	var auto_fill:=Button.new();auto_fill.name="AutoFillPartyButton";auto_fill.text="AUTO FILL";auto_fill.tooltip_text="Fill every open party slot with available recruits.";auto_fill.disabled=valid.is_empty();auto_fill.pressed.connect(_autofill_ledger_party);FantasyButton.apply_dark(auto_fill,13);controls.add_child(auto_fill)
	var selection_help:=Label.new();selection_help.name="PartySelectionHelp";selection_help.text="Selected recruits are numbered by party slot. Deselect a recruit or use Clear when the party is full.";selection_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;selection_help.add_theme_color_override("font_color",Color(0.7,0.76,0.82));page.add_child(selection_help)
	var grid:=GridContainer.new();grid.name="PartyRosterGrid";grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",10);page.add_child(grid)
	for member in campaign.living_roster():_add_party_builder_card(grid,member,cap)
	for member in campaign.living_roster():
		if member.status!=CharacterRecord.STATUS_AVAILABLE:continue
		var dismiss:=Button.new();dismiss.text="Dismiss %s"%member.display_name;dismiss.disabled=not campaign.first_normal_launch_completed and campaign.first_company_ids.has(member.id);dismiss.tooltip_text="Brina and Eamon must attend the first expedition briefing." if dismiss.disabled else "Remove this adventurer from the company for free.";dismiss.pressed.connect(_request_dismissal.bind(member.id));FantasyButton.apply_dark(dismiss,13);page.add_child(dismiss)
	var open_setup:=Button.new();open_setup.text="Continue to Expedition Setup";open_setup.pressed.connect(_open_planned_expedition);_style_button(open_setup);page.add_child(open_setup)

func _refresh_improvements_page(campaign:CampaignState)->void:
	var page:VBoxContainer=company_pages["Improvements"]
	_add_ledger_heading("TAVERN IMPROVEMENTS",Color(0.96,0.62,0.25),page)
	var help:=Label.new();help.text="Permanent Hearth upgrades apply across every expedition and survive recruit deaths. Disabled purchase buttons list exactly what the company still needs.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.add_theme_color_override("font_color",Color(0.82,0.76,0.66));page.add_child(help)
	for branch in campaign.tavern_upgrades:_add_upgrade_ledger_row(String(branch),page)

func _refresh_memorial_page(campaign:CampaignState)->void:
	var page:VBoxContainer=company_pages["Memorial"]
	_add_ledger_heading("COMPANY MEMORIAL  ·  %d LOST"%campaign.memorial.size(),Color(0.78,0.66,0.82),page)
	var help:=Label.new();help.text="The memorial is permanent. Fallen recruits cannot be restored, and their personal levels and equipment are gone.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.add_theme_color_override("font_color",Color(0.78,0.72,0.82));page.add_child(help)
	if campaign.memorial.is_empty():
		var empty:=Label.new();empty.text="No names have been entered. Fallen recruits will appear here permanently with their class, level, and cause of death.";empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(empty)
	else:
		for record in campaign.memorial:
			var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",_panel_style(Color(0.055,0.04,0.065,0.94),Color(0.42,0.3,0.5),7));page.add_child(panel);var fallen:=Label.new();fallen.text="✦ %s · %s · Level %d\n%d expeditions · %d victories · %s"%[String(record.get("name","Unknown")),String(record.get("class_id","hero")).capitalize(),int(record.get("level",1)),int(record.get("expeditions",0)),int(record.get("victories",0)),String(record.get("cause","Fell in the dungeon"))];fallen.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;fallen.add_theme_color_override("font_color",Color(0.86,0.8,0.9));panel.add_child(fallen)

func _refresh_hall_page(campaign:CampaignState)->void:
	var page:VBoxContainer=company_pages["Hall of Heroes"]
	_add_ledger_heading("HALL OF HEROES  ·  %d RETIRED"%campaign.retired_heroes.size(),Color(0.95,0.76,0.34),page)
	var help:=Label.new();help.text="Victorious expedition members retire here. Their records are honorary and grant no power or economy bonus.";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(help)
	if campaign.retired_heroes.is_empty():var empty:=Label.new();empty.text="No company adventurer has yet retired after a boss victory.";page.add_child(empty)
	else:
		for record in campaign.retired_heroes:
			var date:=_calendar_date_for_day(int(record.get("retired_day",campaign.calendar_day)));var label:=Label.new();label.text="✦ %s · %s · Level %d\nRetired %s, %s %d, Year %d · %d expeditions · %d victories"%[String(record.get("name","Unknown")),String(record.get("class_id","hero")).capitalize(),int(record.get("level",1)),date.weekday,date.season,date.season_day,date.year,int(record.get("expeditions",0)),int(record.get("victories",0))];label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;page.add_child(label)

func _calendar_date_for_day(day:int)->Dictionary:
	var current:=run_state.campaign.calendar_day;run_state.campaign.calendar_day=day;var date:=run_state.campaign.get_calendar_date();run_state.campaign.calendar_day=current;return date

func _request_dismissal(character_id:String)->void:
	pending_dismissal_id=character_id;var member:=run_state.campaign.character(character_id);dismissal_confirmation.dialog_text="Dismiss %s? They will leave the Hearth without compensation."%member.display_name;dismissal_confirmation.popup_centered()

func _confirm_dismissal()->void:
	var result:=run_state.campaign.dismiss_character(pending_dismissal_id);message=String(result.get("message",result.get("error","Dismissal failed.")));selected_party_ids.erase(pending_dismissal_id);pending_dismissal_id="";_rebuild_candidate_targets(false);_refresh_company_ledger();_refresh_ui()

func _add_ledger_heading(text_value:String,color:Color,target:VBoxContainer)->void:
	var heading:=Label.new();heading.text=text_value;heading.add_theme_font_size_override("font_size",19);heading.add_theme_color_override("font_color",color);target.add_child(heading)

func _add_recruit_ledger_row(member:CharacterRecord)->void:
	var panel:=PanelContainer.new();panel.add_theme_stylebox_override("panel",_panel_style(Color(0.045,0.055,0.07,0.92),Color(0.28,0.48,0.64),7));company_list.add_child(panel);var row:=HBoxContainer.new();row.add_theme_constant_override("separation",12);panel.add_child(row)
	var portrait:=TextureRect.new();portrait.custom_minimum_size=Vector2(72,86);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;var roster_path:="res://assets/roster_portraits/%s_%d.png"%[member.class_id,member.portrait_variant];portrait.texture=load(roster_path) if ResourceLoader.exists(roster_path) else load("res://assets/ui/class_cards/%s.png"%("phantom" if member.class_id=="rogue" else member.class_id));row.add_child(portrait)
	var copy:=Label.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;copy.text="%s\n%s · Level %d · %s\n%s\n%d expeditions · %d victories · deepest floor %d"%[member.display_name,member.class_id.capitalize(),member.level,member.trait_name,member.trait_description,member.expeditions,member.victories,member.deepest_floor];row.add_child(copy)
	var status:=Label.new();status.text=member.status.to_upper();status.add_theme_color_override("font_color",Color(0.55,0.9,0.62) if member.status==CharacterRecord.STATUS_AVAILABLE else Color(0.94,0.72,0.34));row.add_child(status)

func _add_upgrade_ledger_row(branch:String,target:VBoxContainer)->void:
	var campaign:=run_state.campaign;var cost:=campaign.upgrade_cost(branch);var rank:=int(campaign.tavern_upgrades[branch]);var affordable:=campaign.banked_gold>=int(cost.gold) and campaign.relic_essence>=int(cost.essence) and campaign.successful_levels>=int(cost.levels)
	var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(0,92);panel.add_theme_stylebox_override("panel",_panel_style(Color(0.055,0.04,0.025,0.96),Color(0.48,0.31,0.12),8));target.add_child(panel)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);panel.add_child(row)
	var copy:=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;copy.add_theme_constant_override("separation",3);row.add_child(copy)
	var title:=Label.new();title.text="%s  ·  Rank %d → %d"%[branch.replace("_"," ").capitalize(),rank,rank+1];title.add_theme_font_size_override("font_size",18);title.add_theme_color_override("font_color",Color(1,0.76,0.34));copy.add_child(title)
	var description:=Label.new();description.text=_upgrade_description(branch);description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.add_theme_color_override("font_color",Color(0.88,0.82,0.72));copy.add_child(description)
	var requirements:=Label.new();requirements.text="Cost  %d gold  +  %d essence     Requirement  %d successful levels"%[int(cost.gold),int(cost.essence),int(cost.levels)];requirements.add_theme_color_override("font_color",Color(0.62,0.86,0.68) if affordable else Color(0.9,0.58,0.48));copy.add_child(requirements)
	var button:=Button.new();button.name="Upgrade%sButton"%branch.to_pascal_case();button.custom_minimum_size=Vector2(170,64);button.text="PURCHASE" if affordable else "LOCKED\n%s"%_short_missing_upgrade_resources(cost);button.disabled=not affordable;button.tooltip_text="Purchase this permanent improvement." if affordable else _missing_upgrade_resources(cost);button.pressed.connect(_purchase_tavern_upgrade.bind(branch));FantasyButton.apply_dark(button,15);row.add_child(button)

func _add_resource_card(target:VBoxContainer,title_text:String,value_text:String,description_text:String,accent:Color)->void:
	var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(0,92);panel.add_theme_stylebox_override("panel",_panel_style(Color(0.045,0.04,0.032,0.94),accent.darkened(0.45),8));target.add_child(panel)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",18);panel.add_child(row)
	var value:=Label.new();value.custom_minimum_size=Vector2(170,0);value.text=value_text;value.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;value.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;value.add_theme_font_size_override("font_size",30);value.add_theme_color_override("font_color",accent);row.add_child(value)
	var copy:=VBoxContainer.new();copy.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(copy)
	var heading:=Label.new();heading.text=title_text;heading.add_theme_font_size_override("font_size",18);heading.add_theme_color_override("font_color",accent);copy.add_child(heading)
	var description:=Label.new();description.text=description_text;description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.add_theme_color_override("font_color",Color(0.84,0.8,0.72));copy.add_child(description)

func _add_party_builder_card(target:GridContainer,member:CharacterRecord,cap:int)->void:
	var selected:=selected_party_ids.has(member.id);var available:=member.status==CharacterRecord.STATUS_AVAILABLE
	var card:=CheckButton.new();card.name="%sLedgerPartyToggle"%member.id;card.toggle_mode=true;card.button_pressed=selected;card.disabled=not available or (not selected and selected_party_ids.size()>=cap);card.custom_minimum_size=Vector2(500,112);card.alignment=HORIZONTAL_ALIGNMENT_LEFT
	var class_data:=GameBalance.get_base_class(member.class_id);var role:=String(class_data.get("role","Adventurer"));var slot_prefix:="SLOT %d  ·  "%[selected_party_ids.find(member.id)+1] if selected else "";card.text="%s%s  ·  %s  Level %d\n%s  ·  %s\nHP %d/%d  ·  %d expeditions  ·  %d victories"%[slot_prefix,member.display_name,member.class_id.capitalize(),member.level,role,member.trait_name,member.current_health,member.max_health,member.expeditions,member.victories]
	var portrait_path:="res://assets/roster_portraits/%s_%d.png"%[member.class_id,member.portrait_variant];if ResourceLoader.exists(portrait_path):card.icon=load(portrait_path);card.expand_icon=true;card.add_theme_constant_override("icon_max_width",76)
	var action_hint:="Selected in party slot %d. Deselect to make room."%[selected_party_ids.find(member.id)+1] if selected else ("Party full—deselect a selected recruit or use Clear." if selected_party_ids.size()>=cap else "Select this recruit for the planned party.")
	card.tooltip_text="%s\n%s\n%s"%[role,member.trait_description,action_hint];card.toggled.connect(_ledger_party_member_toggled.bind(member.id));FantasyButton.apply_dark(card,15);target.add_child(card)

func _ledger_party_dungeon_selected(index:int,picker:OptionButton)->void:
	company_party_dungeon_id=String(picker.get_item_metadata(index));expedition_id=company_party_dungeon_id;call_deferred("_refresh_company_ledger")

func _ledger_party_member_toggled(enabled:bool,character_id:String)->void:
	var cap:=run_state.campaign.get_party_cap(company_party_dungeon_id)
	if enabled and not selected_party_ids.has(character_id) and selected_party_ids.size()<cap:selected_party_ids.append(character_id)
	elif not enabled:selected_party_ids.erase(character_id)
	call_deferred("_refresh_company_ledger")

func _clear_ledger_party()->void:
	selected_party_ids.clear()
	call_deferred("_refresh_company_ledger")

func _autofill_ledger_party()->void:
	selected_party_ids.clear()
	var cap:=run_state.campaign.get_party_cap(company_party_dungeon_id)
	for member in run_state.campaign.living_roster():
		if member.status==CharacterRecord.STATUS_AVAILABLE:selected_party_ids.append(member.id)
		if selected_party_ids.size()>=cap:break
	call_deferred("_refresh_company_ledger")

func _open_planned_expedition()->void:
	_close_modal(company_backdrop);_open_expedition(company_party_dungeon_id)

func _short_missing_upgrade_resources(cost:Dictionary)->String:
	var missing:Array[String]=[];var campaign:=run_state.campaign
	if campaign.banked_gold<int(cost.gold):missing.append("%dg"%(int(cost.gold)-campaign.banked_gold))
	if campaign.relic_essence<int(cost.essence):missing.append("%de"%(int(cost.essence)-campaign.relic_essence))
	if campaign.successful_levels<int(cost.levels):missing.append("%d levels"%(int(cost.levels)-campaign.successful_levels))
	return " · ".join(missing)

func _upgrade_description(branch:String)->String:
	match branch:
		"roster_services":return "Improves company administration and recruit support."
		"starting_supplies":return "Adds better expedition provisions."
		"item_rarity":return "Allows rarer equipment to appear."
		"merchant_stock":return "Improves recruited merchant selections."
		"relic_capacity":return "Expands permanent relic facilities."
		"secret_research":return "Deciphers clues leading to secret dungeons."
		"replacement_quality":return "Improves the level of arriving replacements."
	return "Permanently improves the Hearth."

func _missing_upgrade_resources(cost:Dictionary)->String:
	var missing:Array[String]=[];var campaign:=run_state.campaign
	if campaign.banked_gold<int(cost.gold):missing.append("%d more gold"%(int(cost.gold)-campaign.banked_gold))
	if campaign.relic_essence<int(cost.essence):missing.append("%d more relic essence"%(int(cost.essence)-campaign.relic_essence))
	if campaign.successful_levels<int(cost.levels):missing.append("%d more successful levels"%(int(cost.levels)-campaign.successful_levels))
	return "Needs "+", ".join(missing)+". Extract or win expeditions to progress."

func _setup_merchant_shops() -> void:
	merchant_shop_panel = MerchantShopPanel.new(); merchant_shop_panel.name = "MerchantShopPanel"; merchant_shop_panel.purchase_completed.connect(_on_shop_purchase); merchant_shop_panel.closed.connect(_restore_hub_focus); $UI.add_child(merchant_shop_panel)

func _unhandled_input(event: InputEvent) -> void:
	if arrivals_running:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):get_viewport().set_input_as_handled();_finish_arrivals()
		return
	if _modal_visible():
		if event.is_action_pressed("ui_cancel"): _close_top_modal()
		return
	if event.is_action_pressed("interact") and toolbar!=null and toolbar.get_child_count()>0:(toolbar.get_child(0) as Button).grab_focus()

func _try_move(delta: Vector2i) -> void:
	var target := player_pos + delta
	if not _is_walkable(target):
		var station := _station_at(target)
		if not station.is_empty(): _activate_station(station)
		return
	player_pos = target
	_update_token_positions(); _refresh_ui()

func _handle_tile_click(tile: Vector2i) -> void:
	if click_navigation_active: return
	var station := _station_at(tile)
	if not station.is_empty():
		if _distance(player_pos,tile) <= 1: _activate_station(station); return
		var approach := _best_station_approach(tile)
		if approach == Vector2i(-1,-1): _show_dialogue("The Hearth","No clear route reaches that station."); return
		_walk_click_path(_find_navigation_path(player_pos,approach),station)
		return
	if not _is_walkable(tile): _show_dialogue("The Hearth","Tables, walls, and occupied stalls block that route."); return
	_walk_click_path(_find_navigation_path(player_pos,tile),{})

func _on_expedition_gate_clicked()->void:
	if _modal_visible() or arrivals_running:return
	_open_dungeon_selector()

func _walk_click_path(path: Array[Vector2i], station: Dictionary) -> void:
	if path.is_empty():
		if not station.is_empty() and _distance(player_pos,_station_position(station)) <= 1: _activate_station(station)
		return
	click_navigation_active = true
	for step in path:
		player_pos = step
		var tween := create_tween(); tween.set_trans(Tween.TRANS_SINE); tween.set_ease(Tween.EASE_IN_OUT); tween.tween_property(player_token,"position",_grid_center(step),0.08)
		await tween.finished
	click_navigation_active = false
	_update_token_positions(); _refresh_ui()
	if not station.is_empty() and _distance(player_pos,_station_position(station)) <= 1: _activate_station(station)

func _best_station_approach(station_tile: Vector2i) -> Vector2i:
	var best := Vector2i(-1,-1); var best_length := 999
	for delta in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
		var candidate: Vector2i = station_tile + Vector2i(delta)
		if not _is_walkable(candidate): continue
		var path := _find_navigation_path(player_pos,candidate)
		if candidate == player_pos: return candidate
		if not path.is_empty() and path.size() < best_length: best=candidate; best_length=path.size()
	return best

func _find_navigation_path(from_tile: Vector2i, to_tile: Vector2i) -> Array[Vector2i]:
	if from_tile == to_tile: return []
	var frontier: Array[Vector2i] = [from_tile]
	var came_from: Dictionary = {from_tile:from_tile}
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		for delta in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i = current + Vector2i(delta)
			if came_from.has(next) or not _is_walkable(next): continue
			came_from[next] = current
			if next == to_tile:
				var result: Array[Vector2i] = [next]; var cursor: Vector2i = current
				while cursor != from_tile: result.push_front(cursor); cursor = Vector2i(came_from[cursor])
				return result
			frontier.append(next)
	return []

func _interact() -> void:
	var station := _nearest_station()
	if station.is_empty(): _show_dialogue("The Hearth", "Warm floorboards, quiet contracts, and another road waiting beyond the gates.")
	else: _activate_station(station)

func _activate_station(station: Dictionary) -> void:
	active_station = station
	match String(station.get("type","")):
		"merchant":
			var merchant_id := String(station.get("merchant_id","tavern"))
			if merchant_id != "tavern" and not run_state.is_merchant_recruited(merchant_id): _show_dialogue("Covered Stall", "Clear that merchant's dungeon to invite them to the Tavern.")
			else: _open_merchant_shop(merchant_id)
		"armory": _open_armory()
		"dungeon_selector": _open_dungeon_selector()
		"dungeon": _open_expedition(String(station.get("dungeon_id","forest")))
		"vacant": _show_dialogue(String(station.get("name","Covered Stall")),String(station.get("prompt","A future merchant may settle here.")))

func _open_armory() -> void:
	for child in armory_list.get_children(): child.queue_free()
	var first: Button
	for gear in gear_options:
		var button := Button.new(); button.text = "%s   %d damage%s" % [gear.display_name,_gear_damage(gear),"   SELECTED" if selected_gear == gear else ""]
		button.tooltip_text = gear.description; button.pressed.connect(_select_gear.bind(gear)); _style_button(button); armory_list.add_child(button)
		if first == null: first = button
	_update_armory_detail(); _show_modal(armory_backdrop,first)

func _select_gear(gear: GearData) -> void:
	selected_gear = gear; run_state.set_selected_gear(gear); message = "%s is ready for the next expedition." % gear.display_name
	_open_armory(); _refresh_ui()

func _update_armory_detail() -> void:
	if selected_gear == null: armory_detail.text = "No compatible gear available."; return
	armory_detail.text = "%s %s\n%d total damage · %s\n%s" % [run_state.selected_class_name,run_state.get_profile_summary(),_gear_damage(selected_gear),"Block %d"%selected_gear.block_limit if selected_gear.has_block else "No block",selected_gear.description]

func _open_dungeon_selector() -> void:
	for child in expedition_list.get_children(): child.free()
	var first_button: Button
	var categories:Array[String]=[]
	for dungeon_value in GameBalance.get_dungeon_order():
		var category:=String(GameBalance.get_dungeon(String(dungeon_value)).get("category","Mystery"))
		if not categories.has(category):categories.append(category)
	for category in categories:
		var heading := Label.new(); heading.text = category.to_upper(); heading.add_theme_font_size_override("font_size",15); heading.add_theme_color_override("font_color",Color(0.94,0.66,0.28)); expedition_list.add_child(heading)
		for dungeon_value in GameBalance.get_dungeon_order():
			var dungeon_id := String(dungeon_value);var dungeon := GameBalance.get_dungeon(dungeon_id)
			if dungeon.is_empty() or String(dungeon.get("category","Mystery"))!=category:continue
			var unlocked := _is_dungeon_unlocked(dungeon_id);var button := Button.new(); button.name = "%sDungeonButton"%dungeon_id.to_pascal_case(); button.toggle_mode = true;button.alignment=HORIZONTAL_ALIGNMENT_LEFT
			var format_text := "%d–%d rooms" % [int(dungeon.get("room_count",{}).get("min",10)),int(dungeon.get("room_count",{}).get("max",12))] if String(dungeon.get("dungeon_type","mystery")) == "field" else "%d floors"%int(dungeon.get("floors",1))
			var state_text:="AVAILABLE" if unlocked else "LOCKED";button.text = "%s   ·   %s\n%s   ·   %s"%[String(dungeon.get("name",dungeon_id.capitalize())),state_text,String(dungeon.get("difficulty","Unknown")),format_text];button.set_meta("base_text",button.text)
			button.tooltip_text = String(dungeon.get("description","")) if unlocked else "%s\n\nUnlock: %s"%[String(dungeon.get("description","")),String(dungeon.get("unlock_text","Progress further to reveal this destination."))]; button.pressed.connect(_select_dungeon.bind(dungeon_id)); FantasyButton.apply_dark(button,14,Vector2(0,72)); expedition_list.add_child(button)
			if first_button == null: first_button = button
	var initial_id := expedition_id if GameBalance.get_dungeons().has(expedition_id) else String(GameBalance.get_dungeon_order()[0])
	expedition_mode = run_state.last_play_mode
	_select_dungeon(initial_id)
	_show_modal(expedition_backdrop,first_button)

func _open_expedition(dungeon_id: String) -> void:
	_open_dungeon_selector()
	_select_dungeon(dungeon_id)

func _select_dungeon(dungeon_id: String) -> void:
	expedition_id = dungeon_id
	var dungeon := GameBalance.get_dungeon(dungeon_id)
	var unlocked := _is_dungeon_unlocked(dungeon_id)
	var merchant_id := String(dungeon.get("merchant_id",dungeon_id));var merchant_name:="None" if merchant_id.is_empty() else String(GameBalance.get_merchant(merchant_id).get("name",merchant_id.capitalize()))
	var progress := run_state.get_merchant_progress(merchant_id)
	_populate_party_selector(dungeon_id)
	expedition_title.text = "%s\n%s"%[String(dungeon.get("name",dungeon_id.capitalize())),String(dungeon.get("subtitle",""))]
	var slasher_config:Dictionary=Dictionary(dungeon.get("slasher",{}));var displayed_floors:int=int(slasher_config.get("campaign_floors",dungeon.get("floors",1))) if expedition_mode==RunState.PLAY_MODE_SLASHER else int(dungeon.get("floors",1));var extent := "Single field: %d–%d rooms" % [int(dungeon.get("room_count",{}).get("min",10)),int(dungeon.get("room_count",{}).get("max",12))] if String(dungeon.get("dungeon_type","mystery")) == "field" else "Floors: %d" % displayed_floors
	if GameBalance.are_all_dungeons_unlocked_for_testing(): extent += " · Testing unlock active"
	var mode_supported := run_state.dungeon_supports_mode(dungeon_id, expedition_mode)
	var mode_copy := "Turn-based command of every recruit. Position carefully and spend each character's actions independently." if expedition_mode == RunState.PLAY_MODE_STRATEGY else "Real-time party combat. Move with WASD or Left Stick and press Tab to cycle the directly controlled survivor."
	var access_copy:="Testing unlock active" if GameBalance.are_all_dungeons_unlocked_for_testing() else ("Available to the company" if unlocked else "UNLOCK: %s"%String(dungeon.get("unlock_text","Progress further to reveal this destination.")))
	expedition_detail.text = "%s\n\n%s\n\n%s\n\nDIFFICULTY  %s\nSCOPE  %s\nBEST DEPTH  %d\nOUTCOME  Boss victory or total party defeat\nMERCHANT  %s%s\n\nLOADOUT\n%s · %d damage\nConsumables %d/%d · Carried gold %d\n\n%s" % [String(dungeon.get("description","")),mode_copy,access_copy,String(dungeon.get("difficulty","Unknown")),extent,int(progress.get("highest_depth",0)),merchant_name," · Recruited" if not merchant_id.is_empty() and run_state.is_merchant_recruited(merchant_id) else "",selected_gear.display_name if selected_gear else "No compatible gear selected",_gear_damage(selected_gear),run_state.get_consumables().size(),run_state.get_consumable_capacity(),run_state.gold,run_state.get_slasher_progression_summary() if expedition_mode==RunState.PLAY_MODE_SLASHER else "Strategy mode uses each recruit's independent turn state."]
	expedition_launch.disabled = not unlocked or selected_gear == null or not mode_supported or selected_party_ids.is_empty()
	var readiness_reasons:Array[String]=[]
	if not unlocked:readiness_reasons.append("Destination locked")
	if not mode_supported:readiness_reasons.append("Mode unavailable")
	if selected_gear==null:readiness_reasons.append("Select compatible gear")
	if selected_party_ids.is_empty():readiness_reasons.append("Select at least one recruit")
	expedition_readiness.text="READY  ·  %d recruit%s  ·  %s mode"%[selected_party_ids.size(),"" if selected_party_ids.size()==1 else "s",expedition_mode.capitalize()] if readiness_reasons.is_empty() else "NOT READY  ·  %s"%"  ·  ".join(readiness_reasons)
	expedition_readiness.add_theme_color_override("font_color",Color(0.55,0.9,0.62) if readiness_reasons.is_empty() else Color(0.94,0.58,0.48))
	expedition_launch.text="Begin %s Expedition"%expedition_mode.capitalize() if readiness_reasons.is_empty() else "Expedition Not Ready"
	for mode in expedition_mode_buttons:
		var button: Button = expedition_mode_buttons[mode]; button.button_pressed = mode == expedition_mode; button.disabled = not run_state.dungeon_supports_mode(dungeon_id, mode)
	for child in expedition_list.get_children():
		if child is Button:
			var selected:=child.name == "%sDungeonButton"%dungeon_id.to_pascal_case();child.button_pressed=selected;child.text=("▶  " if selected else "     ")+String(child.get_meta("base_text",child.text))

func _is_dungeon_unlocked(dungeon_id: String) -> bool:
	return run_state.is_dungeon_unlocked(dungeon_id)

func _select_expedition_mode(mode: String) -> void:
	expedition_mode = run_state.normalize_play_mode(mode)
	_select_dungeon(expedition_id)

func _launch_expedition() -> void:
	_close_modal(expedition_backdrop)
	if controller == null or selected_gear == null: return
	if controller.has_method("start_dungeon"): controller.start_dungeon(expedition_id,selected_gear,expedition_mode,selected_party_ids)
	elif expedition_id == "crypt": controller.start_crypt(selected_gear)
	else: controller.start_forest(selected_gear)

func _populate_party_selector(dungeon_id: String) -> void:
	if expedition_party_list == null or run_state.campaign == null: return
	for child in expedition_party_list.get_children(): child.free()
	var cap := run_state.campaign.get_party_cap(dungeon_id)
	var valid: Array[String] = []
	for member in run_state.campaign.living_roster():
		if member.status == CharacterRecord.STATUS_AVAILABLE: valid.append(member.id)
	selected_party_ids = selected_party_ids.filter(func(id: String): return valid.has(id)).slice(0, cap)
	if selected_party_ids.is_empty(): selected_party_ids = valid.slice(0, mini(cap, valid.size()))
	if expedition_party_count!=null:expedition_party_count.text="%d / %d"%[selected_party_ids.size(),cap]
	for member in run_state.campaign.living_roster():
		if member.status != CharacterRecord.STATUS_AVAILABLE: continue
		var selected:=selected_party_ids.has(member.id);var toggle := CheckButton.new(); toggle.name = "%sPartyToggle" % member.id;toggle.alignment=HORIZONTAL_ALIGNMENT_LEFT;var slot_copy:="SLOT %d  ·  "%[selected_party_ids.find(member.id)+1] if selected else "";toggle.text = "%s%s\n%s  ·  Level %d  ·  %s" % [slot_copy,member.display_name,member.class_id.capitalize(),member.level,member.trait_name]; var portrait_path := "res://assets/roster_portraits/%s_%d.png" % [member.class_id,member.portrait_variant]; if ResourceLoader.exists(portrait_path): toggle.icon=load(portrait_path); toggle.add_theme_constant_override("icon_max_width",52); toggle.expand_icon=true; toggle.tooltip_text="%s\n%s\n%s"%[member.trait_name,member.trait_description,"Deselect to make room." if selected else ("Party full—deselect a selected recruit first." if selected_party_ids.size()>=cap else "Add to the expedition party.")]; toggle.set_pressed_no_signal(selected); toggle.disabled = not selected and selected_party_ids.size() >= cap; toggle.toggled.connect(_toggle_party_member.bind(member.id,dungeon_id));FantasyButton.apply_dark(toggle,13,Vector2(0,72)); expedition_party_list.add_child(toggle)

func _toggle_party_member(enabled: bool, character_id: String, dungeon_id: String) -> void:
	if enabled and not selected_party_ids.has(character_id) and selected_party_ids.size() < run_state.campaign.get_party_cap(dungeon_id): selected_party_ids.append(character_id)
	elif not enabled: selected_party_ids.erase(character_id)
	call_deferred("_select_dungeon",dungeon_id)

func _show_arrival_results() -> void:
	var summary := arrival_summary
	var headline := String(summary.get("headline",message if not message.is_empty() else "The hearth welcomes you back."))
	var lines: Array[String] = ["[font_size=22][color=#f0c768]%s[/color][/font_size]"%headline]
	if not summary.is_empty():
		lines.append("\n[b]Outcome:[/b] %s"%String(summary.get("outcome","return")).capitalize())
		lines.append("[b]Dungeon:[/b] %s · Depth %d · %s mode"%[String(summary.get("dungeon","Unknown")).capitalize(),int(summary.get("depth",0)),String(summary.get("mode",RunState.PLAY_MODE_STRATEGY)).capitalize()])
		lines.append("[b]Gold:[/b] %d   [b]Hero:[/b] %s"%[int(summary.get("gold",run_state.gold)),run_state.get_profile_summary()])
		if not String(summary.get("slasher_progression","")).is_empty():lines.append("[b]Slasher Path:[/b] %s"%String(summary.slasher_progression))
		var changes: Array = summary.get("changes",[])
		if not changes.is_empty(): lines.append("\n[b]Progress[/b]\n• "+"\n• ".join(changes))
		lines.append("\n[color=#a9c792]Visit the armory, review merchant stock, then choose a gate.[/color]")
	results_text.text = "\n".join(lines); _show_modal(results_backdrop,results_backdrop.find_child("ContinueButton",true,false) as Control)

func _open_merchant_shop(merchant_id: String) -> void:
	merchant_shop_panel.setup(run_state,merchant_id,"tavern"); merchant_shop_panel.open()

func _on_shop_purchase(purchase_message: String) -> void:
	message = purchase_message; _refresh_ui()

func _show_dialogue(speaker: String, text: String) -> void:
	dialogue_speaker.text = speaker; dialogue_text.text = text; dialogue_panel.visible = true; prompt_panel.visible = false
	var tween:=create_tween();tween.tween_interval(3.5);tween.tween_callback(func():
		if dialogue_panel!=null:dialogue_panel.visible=false
		_refresh_ui())

func _show_modal(modal: Control, focus: Control) -> void:
	modal.visible = true; modal.move_to_front()
	if focus != null: focus.grab_focus()

func _close_modal(modal: Control) -> void:
	modal.visible = false
	if modal==results_backdrop:
		if run_state!=null and run_state.campaign!=null:run_state.campaign.pending_settlement_summary.clear();run_state.campaign.save_atomic()
		if not pending_story_lines.is_empty():call_deferred("_play_pending_story")
		else:call_deferred("_continue_arrival_queue")
	elif modal==calendar_backdrop and arrivals_need_sequence:call_deferred("_start_arrivals")
	else: _restore_hub_focus()

func _close_top_modal() -> void:
	if merchant_shop_panel != null and merchant_shop_panel.visible: merchant_shop_panel.close()
	elif recruitment_dialogue!=null and recruitment_dialogue.visible:recruitment_dialogue.close()
	elif options_backdrop!=null and options_backdrop.visible:_close_modal(options_backdrop)
	elif calendar_backdrop!=null and calendar_backdrop.visible:_close_modal(calendar_backdrop)
	elif company_backdrop!=null and company_backdrop.visible:_close_modal(company_backdrop)
	elif results_backdrop.visible: _close_modal(results_backdrop)
	elif expedition_backdrop.visible: _close_modal(expedition_backdrop)
	elif armory_backdrop.visible: _close_modal(armory_backdrop)

func _modal_visible() -> bool:
	return (merchant_shop_panel != null and merchant_shop_panel.visible) or (recruitment_dialogue!=null and recruitment_dialogue.visible) or (options_backdrop!=null and options_backdrop.visible) or (calendar_backdrop!=null and calendar_backdrop.visible) or (armory_backdrop != null and armory_backdrop.visible) or (expedition_backdrop != null and expedition_backdrop.visible) or (results_backdrop != null and results_backdrop.visible) or (company_backdrop!=null and company_backdrop.visible)

func _restore_hub_focus() -> void:
	var expedition_button:=toolbar_buttons.get("Expedition") as Button
	if expedition_button!=null and expedition_button.visible and not expedition_button.disabled:expedition_button.grab_focus()
	else:ui_root.grab_focus()

func _refresh_ui() -> void:
	if hud_label == null or run_state == null: return
	var date:=run_state.campaign.get_calendar_date();var compact:=get_viewport_rect().size.x<1100
	hud_date_label.text="%s %d · Y%d"%[date.season,date.season_day,date.year] if compact else "%s, %s %d, Y%d"%[date.weekday,date.season,date.season_day,date.year]
	hud_bank_label.text=str(run_state.campaign.banked_gold) if compact else "Bank %d"%run_state.campaign.banked_gold
	hud_company_label.text="%d/%d · %d waiting"%[run_state.campaign.living_roster().size(),run_state.campaign.get_roster_capacity(),run_state.campaign.candidate_pool.size()] if compact else "Roster %d/%d · Candidates %d"%[run_state.campaign.living_roster().size(),run_state.campaign.get_roster_capacity(),run_state.campaign.candidate_pool.size()]
	dialogue_panel.visible = false
	prompt_panel.visible = arrivals_running
	if settings_button!=null:settings_button.disabled=arrivals_running
	if arrivals_running:prompt_label.text="Click, E, or Space to fast-forward arrivals"

func _refresh_station_markers() -> void:
	for child in station_markers.get_children(): child.queue_free()
	for station in stations:
		var highlight := Polygon2D.new()
		highlight.name = "%sHighlight"%String(station.get("id","Station")).to_pascal_case()
		highlight.polygon = PackedVector2Array([Vector2(0,-21),Vector2(32,0),Vector2(0,21),Vector2(-32,0)])
		highlight.position = _grid_center(_station_position(station))
		highlight.color = Color(1.0,0.68,0.18,0.18 if _distance(player_pos,_station_position(station))<=1 else 0.07)
		station_markers.add_child(highlight)
		var marker := Label.new(); marker.name = "%sMarker"%String(station.get("id","Station")).to_pascal_case(); marker.text = _station_marker_text(station)
		marker.position = _grid_center(_station_position(station))+Vector2(-70,26); marker.size = Vector2(140,28); marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_theme_font_size_override("font_size",13); marker.add_theme_constant_override("outline_size",5); marker.add_theme_color_override("font_outline_color",Color(0.03,0.02,0.01,0.95)); marker.add_theme_color_override("font_color",Color(1,0.82,0.42) if _station_available(station) else Color(0.52,0.5,0.48)); station_markers.add_child(marker)

func _station_marker_text(station: Dictionary) -> String:
	if String(station.get("type","")) == "vacant": return "◇ Vacant Stall"
	if String(station.get("type","")) == "dungeon_selector": return "◆ Expedition Gate"
	if not _station_available(station): return "◆ %s · Locked"%String(station.get("name","Station"))
	if String(station.get("type","")) == "merchant" and String(station.get("merchant_id","tavern")) != "tavern":
		return "◆ %s · %s"%[String(station.get("name","Merchant")),GameBalance.get_merchant_rank_name(run_state.get_merchant_rank(String(station.get("merchant_id",""))))]
	return "◆ %s"%String(station.get("name","Station"))

func _station_prompt(station: Dictionary) -> String:
	if not _station_available(station):
		if String(station.get("unlock","")) == "crypt": return "Locked: clear Forest and reach level 5"
		return "Locked: recruit this merchant"
	return String(station.get("prompt","Interact"))

func _station_available(station: Dictionary) -> bool:
	var unlock := String(station.get("unlock",""))
	if unlock == "crypt": return run_state != null and run_state.is_crypt_unlocked()
	if unlock.begins_with("merchant:"): return run_state != null and run_state.is_merchant_recruited(unlock.trim_prefix("merchant:"))
	return true

func _nearest_station() -> Dictionary:
	for station in stations:
		if _distance(player_pos,_station_position(station)) <= 1: return station
	return {}

func _station_at(tile: Vector2i) -> Dictionary:
	for station in stations:
		if _station_position(station) == tile: return station
	return {}

func _station_by_id(station_id:String)->Dictionary:
	for station in stations:
		if String(station.get("id",""))==station_id:return station
	return {}

func _station_position(station: Dictionary) -> Vector2i:
	var value: Array = station.get("position",[0,0]); return Vector2i(int(value[0]),int(value[1]))

func _is_walkable(tile: Vector2i) -> bool:
	return _is_inside_grid(tile) and tile.x > 0 and tile.y > 0 and tile.x < GRID_W-1 and tile.y < GRID_H-1 and not blocked_cells.has(tile) and _station_at(tile).is_empty()

func _is_inside_grid(tile: Vector2i) -> bool: return tile.x>=0 and tile.y>=0 and tile.x<GRID_W and tile.y<GRID_H
func _distance(a: Vector2i,b: Vector2i) -> int: return abs(a.x-b.x)+abs(a.y-b.y)

func _layout_scene() -> void:
	_update_token_positions();_refresh_station_markers()
	var available:=get_viewport_rect().size-Vector2(36,36)
	for modal in [armory_backdrop,expedition_backdrop,results_backdrop,company_backdrop,calendar_backdrop,options_backdrop]:
		if modal==null:continue
		for child in modal.get_children():
			if child is PanelContainer and child.has_meta("preferred_size"):
				var preferred:Vector2=child.get_meta("preferred_size");child.size=Vector2(minf(preferred.x,available.x),minf(preferred.y,available.y));child.position=(get_viewport_rect().size-child.size)/2.0
	if expedition_gate_hit_target!=null:
		var gate:=_station_by_id("expedition_gate")
		if not gate.is_empty():expedition_gate_hit_target.position=_grid_center(_station_position(gate))-Vector2(TILE_SIZE,TILE_SIZE)/2.0;expedition_gate_hit_target.size=Vector2(TILE_SIZE,TILE_SIZE)
	if npc_hit_targets.has("mara"):(npc_hit_targets.mara as Button).position=_grid_center(Vector2i(9,1))+Vector2(-75,40)
	if npc_hit_targets.has("forest"):(npc_hit_targets.forest as Button).position=_grid_center(Vector2i(2,3))+Vector2(-75,40)
	if npc_hit_targets.has("crypt"):(npc_hit_targets.crypt as Button).position=_grid_center(Vector2i(15,3))+Vector2(-75,40)
	var index:=0
	for candidate in run_state.campaign.get_candidates() if run_state!=null and run_state.campaign!=null else []:
		var sprite:=candidate_sprites.get(candidate.id) as AnimatedSprite2D;if sprite!=null and not arrivals_running:sprite.position=_candidate_seat(index)
		var button:=candidate_buttons.get(candidate.id) as Button;if button!=null:button.position=_candidate_seat(index)+Vector2(-88,43)
		index+=1
	if run_state!=null and run_state.campaign!=null:
		for member in run_state.campaign.living_roster():
			var recruited_sprite:=candidate_stage.get_node_or_null("%sRecruitedSprite"%member.id) as AnimatedSprite2D;if recruited_sprite!=null:recruited_sprite.position=_candidate_seat(index)
			var recruited_button:=candidate_buttons.get(member.id) as Button;if recruited_button!=null:recruited_button.position=_candidate_seat(index)+Vector2(-88,43)
			index+=1
	if toolbar!=null:
		var width:=minf(900.0,get_viewport_rect().size.x-32.0);toolbar.offset_left=(get_viewport_rect().size.x-width)/2.0;toolbar.offset_right=toolbar.offset_left+width-get_viewport_rect().size.x
	_refresh_ui()

func _grid_origin() -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2((viewport_size.x-GRID_W*TILE_SIZE)/2.0,(viewport_size.y-GRID_H*TILE_SIZE)/2.0+18)

func _grid_center(tile: Vector2i) -> Vector2: return _grid_origin()+Vector2(tile)*TILE_SIZE+Vector2(TILE_SIZE,TILE_SIZE)/2.0
func _screen_to_grid(pos: Vector2) -> Vector2i: return Vector2i(floori((pos.x-_grid_origin().x)/TILE_SIZE),floori((pos.y-_grid_origin().y)/TILE_SIZE))

func _update_token_positions() -> void:
	if player_token == null: return
	player_token.position = _grid_center(player_pos)
	bartender_token.position = _grid_center(Vector2i(9,1))
	forest_merchant_token.position = _grid_center(Vector2i(2,3)); crypt_merchant_token.position = _grid_center(Vector2i(15,3))

func _configure_merchant_token(token: BoardPiece, merchant_id: String) -> void:
	var recruited := run_state != null and run_state.is_merchant_recruited(merchant_id); token.visible = recruited
	if not recruited: return
	var path := String(GameBalance.get_merchant(merchant_id).get("portrait","")); token.sprite_texture = load(path) if ResourceLoader.exists(path) else TAVERN_KEEPER
	token.sprite_region_enabled = false; token.sprite_scale = Vector2(0.075,0.075); token.show_label = false; token.show_panel = false

func _gear_damage(gear: GearData) -> int:
	if gear == null: return 0
	var stat := "spell_potency" if run_state != null and run_state.selected_class_id in ["mage","healer","summoner"] else "attack_power"
	return gear.damage+(run_state.get_derived_stat(stat) if run_state != null else 0)

func _remembered_gear_or_default() -> GearData:
	if run_state != null and run_state.selected_gear != null:
		for gear in gear_options:
			if gear.id == run_state.selected_gear.id: return gear
	return gear_options[0] if not gear_options.is_empty() else null

func _panel_style(fill: Color,border: Color,radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color=fill; style.border_color=border; style.set_border_width_all(2); style.set_corner_radius_all(radius); style.set_content_margin_all(8); return style

func _style_button(button: Button) -> void:
	TAVERN_THEME.apply_button(button,true,15,Vector2(220,42))
