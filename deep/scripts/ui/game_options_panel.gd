extends PanelContainer
class_name GameOptionsPanel
const SETTINGS_SERVICE:=preload("res://scripts/game/game_settings.gd")

signal close_requested

var resolution_control:OptionButton
var refreshing:=false
var local_settings:Node
var first_control:Control

func _settings()->Node:
	var singleton:=get_node_or_null("/root/GameSettings")
	if singleton!=null:return singleton
	if local_settings==null:local_settings=SETTINGS_SERVICE.new();local_settings.values=SETTINGS_SERVICE.DEFAULTS.duplicate(true)
	return local_settings

func setup(show_close_button:bool=true)->void:
	if get_child_count()>0:return
	custom_minimum_size=Vector2(600,420);add_theme_stylebox_override("panel",_panel_style())
	var margin:=MarginContainer.new()
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_%s"%side,22)
	add_child(margin)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",10);margin.add_child(body)
	var title:=Label.new();title.text="OPTIONS";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",26);body.add_child(title)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(scroll)
	var options_body:=VBoxContainer.new();options_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;options_body.add_theme_constant_override("separation",10);scroll.add_child(options_body)
	var grid:=GridContainer.new();grid.columns=2;grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL;grid.add_theme_constant_override("h_separation",18);grid.add_theme_constant_override("v_separation",8);options_body.add_child(grid)
	_add_option(grid,"Window Mode",["Windowed","Borderless","Fullscreen"],["windowed","borderless","fullscreen"],"window_mode")
	resolution_control=_add_option(grid,"Resolution",["1280 × 720","1600 × 900","1920 × 1080","2560 × 1440"],SETTINGS_SERVICE.RESOLUTIONS,"resolution")
	_add_option(grid,"VSync",["Off","On","Adaptive"],["off","on","adaptive"],"vsync")
	_add_option(grid,"UI Scale",["75%","100%","125%","150%"],[0.75,1.0,1.25,1.5],"ui_scale")
	_add_slider(grid,"Slasher Camera Zoom","slasher_zoom",1.0,1.5,0.05,"%.2f×")
	_add_slider(grid,"Screen Shake","screen_shake_intensity",0.0,1.5,0.05,"%d%%",true)
	_add_audio_row(grid,"Master","master");_add_audio_row(grid,"Music","music");_add_audio_row(grid,"SFX","sfx")
	var controls:=Label.new();controls.text="CONTROLS\nKeyboard: WASD / Arrows move · E/Space interact · M menu · Tab party · Q potion\nController: D-pad move · A interact/basic · Start menu · LB party · L3 potion\nExpeditions continue automatically until boss victory or total party defeat.";controls.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;controls.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;controls.add_theme_color_override("font_color",Color("cbbd9b"));options_body.add_child(controls)
	var buttons:=HBoxContainer.new();buttons.alignment=BoxContainer.ALIGNMENT_CENTER;buttons.add_theme_constant_override("separation",12);body.add_child(buttons)
	var reset:=Button.new();reset.text="Reset Defaults";reset.pressed.connect(_reset_defaults);buttons.add_child(reset)
	if show_close_button:
		var close:=Button.new();close.text="Close";close.pressed.connect(_request_close);buttons.add_child(close)
	_settings().settings_changed.connect(_on_setting_changed);_refresh()
	if first_control!=null:first_control.call_deferred("grab_focus")

func _add_option(grid:GridContainer,label_text:String,labels:Array,values_list:Array,key:String)->OptionButton:
	grid.add_child(_label(label_text));var option:=OptionButton.new();option.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for index in labels.size():option.add_item(String(labels[index]));option.set_item_metadata(index,values_list[index])
	option.item_selected.connect(_option_selected.bind(option,key))
	if first_control==null:first_control=option
	option.set_meta("setting_key",key);grid.add_child(option);return option

func _add_slider(grid:GridContainer,label_text:String,key:String,minimum:float,maximum:float,step:float,format:String,percent:bool=false)->void:
	grid.add_child(_label(label_text));var row:=HBoxContainer.new();var slider:=HSlider.new();slider.min_value=minimum;slider.max_value=maximum;slider.step=step;slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;var value_label:=Label.new();value_label.custom_minimum_size.x=64;row.add_child(slider);row.add_child(value_label);grid.add_child(row)
	slider.set_meta("setting_key",key);slider.value_changed.connect(_slider_changed.bind(slider,key,value_label,format,percent))
	row.set_meta("slider",slider);row.set_meta("value_label",value_label);row.set_meta("format",format);row.set_meta("percent",percent)

func _add_audio_row(grid:GridContainer,label_text:String,key_prefix:String)->void:
	grid.add_child(_label(label_text+" Volume"));var row:=HBoxContainer.new();var slider:=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=0.05;slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;var mute:=CheckButton.new();mute.text="Mute";row.add_child(slider);row.add_child(mute);grid.add_child(row)
	slider.set_meta("setting_key","%s_volume"%key_prefix);mute.set_meta("setting_key","%s_mute"%key_prefix);slider.value_changed.connect(_audio_slider_changed.bind(slider));mute.toggled.connect(_mute_toggled.bind(mute))

func _option_selected(index:int,option:OptionButton,key:String)->void:
	if not refreshing:_settings().set_value(key,option.get_item_metadata(index))
func _slider_changed(value:float,_slider:HSlider,key:String,value_label:Label,format:String,percent:bool)->void:
	value_label.text=format%int(round(value*100.0)) if percent else format%value
	if not refreshing:_settings().set_value(key,value)
func _audio_slider_changed(value:float,slider:HSlider)->void:
	if not refreshing:_settings().set_value(String(slider.get_meta("setting_key")),value)
func _mute_toggled(enabled:bool,mute:CheckButton)->void:
	if not refreshing:_settings().set_value(String(mute.get_meta("setting_key")),enabled)
func _reset_defaults()->void:_settings().reset_defaults();_refresh()
func _request_close()->void:close_requested.emit()

func _refresh()->void:
	refreshing=true
	for node in _descendants(self):
		if node is OptionButton and node.has_meta("setting_key"):
			var key:String=String(node.get_meta("setting_key"));var expected:Variant=_settings().get_value(key)
			for index in node.item_count:
				if node.get_item_metadata(index)==expected:node.select(index);break
		elif node is HSlider and node.has_meta("setting_key"):node.value=_settings().get_float(String(node.get_meta("setting_key")),node.value)
		elif node is CheckButton and node.has_meta("setting_key"):node.button_pressed=_settings().get_bool(String(node.get_meta("setting_key")),false)
	if resolution_control!=null:resolution_control.disabled=_settings().get_string("window_mode","windowed")!="windowed"
	refreshing=false

func _on_setting_changed(_key:String,_value:Variant)->void:_refresh()
func _descendants(root:Node)->Array[Node]:
	var result:Array[Node]=[]
	for child in root.get_children():result.append(child);result.append_array(_descendants(child))
	return result
func _label(text:String)->Label:var label:=Label.new();label.text=text;return label
func _panel_style()->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("#100d09f2");style.border_color=Color("#d9a52b");style.set_border_width_all(2);style.set_corner_radius_all(5);return style
