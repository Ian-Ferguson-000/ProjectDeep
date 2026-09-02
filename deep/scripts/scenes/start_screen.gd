extends Control

const UI_BACKGROUND := preload("res://assets/ui/Eros.png")
const OPTIONS_PANEL:=preload("res://scripts/ui/game_options_panel.gd")

var controller: Node

func setup(game_controller: Node) -> void:
	controller = game_controller

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func _build_ui() -> void:
	var background := TextureRect.new()
	background.texture = UI_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.018, 0.014, 0.22)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 16)
	root.offset_left = 120
	root.offset_right = -120
	root.offset_top = 310
	root.offset_bottom = -90
	add_child(root)

	var start_button := Button.new()
	start_button.name="ContinueButton";start_button.text = "Continue"
	start_button.custom_minimum_size = Vector2(320, 58)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(_open_slot_picker.bind(false))
	_style_button(start_button)
	root.add_child(start_button)
	start_button.call_deferred("grab_focus")
	var summaries:Array=controller.get_save_slot_summaries() if controller!=null and controller.has_method("get_save_slot_summaries") else []
	start_button.disabled=not summaries.any(func(summary:Dictionary)->bool:return bool(summary.get("recoverable",false)))

	var new_button:=Button.new();new_button.name="NewGameButton";new_button.text="New Game";new_button.custom_minimum_size=Vector2(320,58);new_button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;new_button.pressed.connect(_open_slot_picker.bind(true));_style_button(new_button);root.add_child(new_button)

	var options_button:=Button.new()
	options_button.text="Options";options_button.custom_minimum_size=Vector2(320,52);options_button.size_flags_horizontal=Control.SIZE_SHRINK_CENTER;options_button.pressed.connect(_open_options);_style_button(options_button);root.add_child(options_button)

func _open_slot_picker(new_game:bool)->void:
	var existing:=get_node_or_null("SlotPickerOverlay")
	if existing!=null:existing.queue_free()
	var overlay:=Control.new();overlay.name="SlotPickerOverlay";overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay)
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.01,0.01,0.01,0.86);overlay.add_child(shade)
	var panel:=PanelContainer.new();panel.custom_minimum_size=Vector2(620,430);panel.set_anchors_preset(Control.PRESET_CENTER);panel.position=Vector2(-310,-215);panel.add_theme_stylebox_override("panel",_slot_panel_style());overlay.add_child(panel)
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_%s"%side,24)
	panel.add_child(margin)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",14);margin.add_child(body)
	var title:=Label.new();title.text="CHOOSE A SLOT · %s"%("NEW GAME" if new_game else "CONTINUE");title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",27);body.add_child(title)
	var summaries:Array[Dictionary]=[];summaries.assign(controller.get_save_slot_summaries() if controller!=null and controller.has_method("get_save_slot_summaries") else [])
	var first_enabled:Button
	for summary in summaries:
		var slot:=int(summary.get("slot",1));var occupied:=bool(summary.get("exists",false));var recoverable:=bool(summary.get("recoverable",false));var button:=Button.new();button.custom_minimum_size=Vector2(0,82);button.text=_slot_text(summary);button.disabled=not new_game and not recoverable;button.pressed.connect(_select_slot.bind(slot,new_game,occupied,overlay));_style_button(button);body.add_child(button)
		if first_enabled==null and not button.disabled:first_enabled=button
	var cancel:=Button.new();cancel.text="Back";cancel.pressed.connect(overlay.queue_free);_style_button(cancel);body.add_child(cancel)
	if first_enabled!=null:first_enabled.call_deferred("grab_focus")

func _slot_text(summary:Dictionary)->String:
	var slot:=int(summary.get("slot",1))
	if not bool(summary.get("exists",false)):return "SLOT %d · EMPTY"%slot
	if not bool(summary.get("recoverable",false)):return "SLOT %d · UNREADABLE SAVE"%slot
	var phase:=String(summary.get("tutorial_phase","new")).replace("_"," ").capitalize();var saved:=int(summary.get("last_saved_unix",0));var stamp:="Unknown date" if saved<=0 else Time.get_datetime_string_from_unix_time(saved,true)
	return "SLOT %d · %s\n%d recruits · %d dungeons · %d gold · %s"%[slot,phase,int(summary.get("roster_count",0)),int(summary.get("completed_dungeons",0)),int(summary.get("banked_gold",0)),stamp]

func _select_slot(slot:int,new_game:bool,occupied:bool,overlay:Control)->void:
	if new_game and occupied:
		var confirm:=ConfirmationDialog.new();confirm.title="Overwrite Save Slot %d?"%slot;confirm.dialog_text="This permanently replaces the campaign in Slot %d. Its automatic backup will also be replaced after the next save."%slot;confirm.ok_button_text="Overwrite and Begin";confirm.confirmed.connect(_commit_slot.bind(slot,true,overlay));overlay.add_child(confirm);confirm.popup_centered(Vector2i(520,210));return
	_commit_slot(slot,new_game,overlay)

func _commit_slot(slot:int,new_game:bool,overlay:Control)->void:
	if is_instance_valid(overlay):overlay.queue_free()
	if controller==null:return
	if new_game and controller.has_method("new_game_in_slot"):controller.new_game_in_slot(slot)
	elif not new_game and controller.has_method("continue_from_slot"):controller.continue_from_slot(slot)

func _open_options()->void:
	var overlay:=Control.new();overlay.name="OptionsOverlay";overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(overlay)
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.01,0.01,0.01,0.82);overlay.add_child(shade)
	var panel:GameOptionsPanel=OPTIONS_PANEL.new();panel.set_anchors_preset(Control.PRESET_CENTER);panel.position=Vector2(-300,-210);overlay.add_child(panel);panel.setup(true);panel.close_requested.connect(overlay.queue_free)

func _style_button(button: Button) -> void:
	FantasyButton.apply_light(button, 22)

func _slot_panel_style()->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("100d09f7");style.border_color=Color("d9a52b");style.set_border_width_all(2);style.set_corner_radius_all(6);return style
