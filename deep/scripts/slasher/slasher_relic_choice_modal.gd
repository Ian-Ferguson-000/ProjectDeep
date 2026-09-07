extends Control
class_name SlasherRelicChoiceModal

signal relic_selected(item_id:String)

const ICON_MOVE:=preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/1.png")
const ICON_ATTACK:=preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/2.png")
const ICON_SPECIAL:=preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/10.png")
const ICON_POTION:=preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/1 Items/15.png")
const ICON_DEFEND:=preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/12.png")
const ICON_GOLD:=preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/1 Items/1.png")
const ICON_MODE:=preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/2 Icons/7.png")
const ICON_SPELL:=preload("res://assets/pixel_art/spellnode.png")
const CARD_BACKGROUND:=preload("res://assets/ui/card1.png")

const INK:=Color("#090c11")
const CARD:=Color("#171c24")
const CARD_HOVER:=Color("#202936")
const IVORY:=Color("#f2eadb")
const MUTED:=Color("#aeb7c2")

var run_state:RunState
var mandatory:=true
var previous_pause:=false
var card_row:HBoxContainer
var choice_buttons:Array[Button]=[]

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_STOP
	visible=false
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color("#02060bd9");shade.mouse_filter=Control.MOUSE_FILTER_STOP;add_child(shade)
	var veil:=ColorRect.new();veil.anchor_left=0.12;veil.anchor_right=0.88;veil.anchor_bottom=1.0;veil.color=Color("#0b3b4e42");veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(veil)
	var layout:=VBoxContainer.new();layout.anchor_left=0.5;layout.anchor_top=0.5;layout.anchor_right=0.5;layout.anchor_bottom=0.5;layout.offset_left=-500;layout.offset_top=-330;layout.offset_right=500;layout.offset_bottom=330;layout.add_theme_constant_override("separation",8);add_child(layout)
	var ornament:=Label.new();ornament.text="✦  ───────  ❖  ───────  ✦";ornament.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;ornament.add_theme_font_size_override("font_size",18);ornament.add_theme_color_override("font_color",Color("#75e5eb"));layout.add_child(ornament)
	var title:=Label.new();title.text="CHOOSE 1 RELIC";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",32);title.add_theme_color_override("font_color",Color("#ecffff"));title.add_theme_color_override("font_shadow_color",Color("#3bdfe0b0"));title.add_theme_constant_override("shadow_offset_x",2);title.add_theme_constant_override("shadow_offset_y",2);layout.add_child(title)
	var subtitle:=Label.new();subtitle.text="Bind one treasure to this expedition";subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.add_theme_font_size_override("font_size",15);subtitle.add_theme_color_override("font_color",Color("#b8d7da"));layout.add_child(subtitle)
	card_row=HBoxContainer.new();card_row.alignment=BoxContainer.ALIGNMENT_CENTER;card_row.size_flags_vertical=Control.SIZE_EXPAND_FILL;card_row.add_theme_constant_override("separation",14);layout.add_child(card_row)
	var hint:=Label.new();hint.text="◀  A / D or Arrow Keys     •     Enter / A to claim     ▶";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_font_size_override("font_size",14);hint.add_theme_color_override("font_color",Color("#a8c3c6"));layout.add_child(hint)

func open(state:RunState,choices:Array[String],is_mandatory:bool=true)->void:
	run_state=state;mandatory=is_mandatory;previous_pause=get_tree().paused;choice_buttons.clear()
	for child:Node in card_row.get_children():child.free()
	for item_id:String in choices:card_row.add_child(_card(item_id))
	visible=true;modulate=Color.TRANSPARENT;move_to_front();get_tree().paused=true
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(self,"modulate",Color.WHITE,0.18)
	if not choice_buttons.is_empty():choice_buttons[0].grab_focus()

func finish()->void:
	visible=false;get_tree().paused=previous_pause

func _unhandled_input(event:InputEvent)->void:
	if not visible:return
	if mandatory and event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled()

func _card(item_id:String)->Control:
	var item:Dictionary=GameBalance.get_item(item_id)
	var rarity:String=String(item.get("rarity","common"))
	var rarity_data:Dictionary=GameBalance.get_item_rarities().get(rarity,{})
	var accent:=Color(String(rarity_data.get("color","#c9c2aa")))
	var shell:=VBoxContainer.new();shell.custom_minimum_size=Vector2(318,497);shell.add_theme_constant_override("separation",-4)
	var pointer:=Label.new();pointer.text="▼";pointer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;pointer.add_theme_font_size_override("font_size",22);pointer.add_theme_color_override("font_color",accent);pointer.modulate.a=0.0;shell.add_child(pointer)
	var button:=Button.new();button.name="Relic_%s"%item_id;button.custom_minimum_size=Vector2(318,477);button.text="";button.focus_mode=Control.FOCUS_ALL;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal",_card_style(Color.TRANSPARENT,Color.TRANSPARENT,0,0));button.add_theme_stylebox_override("hover",_card_style(Color.TRANSPARENT,Color.TRANSPARENT,0,0));button.add_theme_stylebox_override("focus",_card_style(Color.TRANSPARENT,Color.TRANSPARENT,0,0));button.add_theme_stylebox_override("pressed",_card_style(Color("#05080a24"),Color.TRANSPARENT,0,0));shell.add_child(button)
	var card_art:=TextureRect.new();card_art.name="CardBackground";card_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);card_art.texture=CARD_BACKGROUND;card_art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;card_art.stretch_mode=TextureRect.STRETCH_SCALE;card_art.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(card_art)
	var content:=VBoxContainer.new();content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);content.offset_left=50;content.offset_top=77;content.offset_right=-50;content.offset_bottom=-52;content.mouse_filter=Control.MOUSE_FILTER_IGNORE;content.add_theme_constant_override("separation",5);button.add_child(content)
	var name_label:=Label.new();name_label.text=String(item.get("name",item_id));name_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;name_label.custom_minimum_size.y=38;name_label.add_theme_font_size_override("font_size",18);name_label.add_theme_color_override("font_color",IVORY);content.add_child(name_label)
	var art_center:=CenterContainer.new();art_center.custom_minimum_size.y=70;content.add_child(art_center)
	var art_frame:=PanelContainer.new();art_frame.custom_minimum_size=Vector2(124,66);art_frame.add_theme_stylebox_override("panel",_panel(Color("#0b1018b8"),accent.darkened(0.25),1,9,5));art_center.add_child(art_frame)
	var icon:=TextureRect.new();icon.texture=_scaled_icon(_item_icon(String(item.get("icon_key","special"))),62);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;art_frame.add_child(icon)
	var metadata:=HBoxContainer.new();metadata.alignment=BoxContainer.ALIGNMENT_CENTER;metadata.add_theme_constant_override("separation",8);content.add_child(metadata)
	metadata.add_child(_pill(String(rarity_data.get("name",rarity.capitalize())).to_upper(),accent))
	var duration:=String(item.get("duration_type","dungeon_bound")).replace("_"," ").capitalize();metadata.add_child(_pill(duration.to_upper(),Color("#8695a7")))
	var divider:=HSeparator.new();divider.add_theme_color_override("separator",Color(accent,0.55));content.add_child(divider)
	var description:=Label.new();description.text=String(item.get("description",""));description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;description.custom_minimum_size.y=58;description.add_theme_font_size_override("font_size",13);description.add_theme_color_override("font_color",MUTED);content.add_child(description)
	var effect:=Label.new();effect.text="◆  "+_clean_rules(GameBalance.get_slasher_item_rules_text(item_id));effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;effect.vertical_alignment=VERTICAL_ALIGNMENT_TOP;effect.size_flags_vertical=Control.SIZE_EXPAND_FILL;effect.add_theme_font_size_override("font_size",14);effect.add_theme_color_override("font_color",IVORY);content.add_child(effect)
	button.pressed.connect(_claim.bind(item_id));button.focus_entered.connect(_set_card_active.bind(button,card_art,pointer,true));button.focus_exited.connect(_set_card_active.bind(button,card_art,pointer,false));button.mouse_entered.connect(_set_card_active.bind(button,card_art,pointer,true));button.mouse_exited.connect(_set_card_active.bind(button,card_art,pointer,button.has_focus()))
	choice_buttons.append(button)
	return shell

func _set_card_active(button:Button,card_art:TextureRect,pointer:Label,active:bool)->void:
	pointer.modulate.a=1.0 if active else 0.0;card_art.self_modulate=Color(1.12,1.12,1.12,1) if active else Color.WHITE;button.pivot_offset=button.size*0.5
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_trans(Tween.TRANS_QUAD).tween_property(button,"scale",Vector2(1.025,1.025) if active else Vector2.ONE,0.1)

func _pill(text_value:String,color:Color)->Label:
	var label:=Label.new();label.text="  %s  "%text_value;label.add_theme_font_size_override("font_size",11);label.add_theme_color_override("font_color",color.lightened(0.22));label.add_theme_stylebox_override("normal",_panel(Color(color,0.1),Color(color,0.65),1,4,3));return label

func _clean_rules(value:String)->String:
	var text:=value.strip_edges().trim_prefix("Slasher:").strip_edges()
	return text.trim_suffix(".")+"."

func _item_icon(icon_key:String)->Texture2D:
	match icon_key:
		"attack":return ICON_ATTACK
		"defense":return ICON_DEFEND
		"potion","health":return ICON_POTION
		"move","movement":return ICON_MOVE
		"gold":return ICON_GOLD
		"spell":return ICON_SPELL
		"mode":return ICON_MODE
		_:return ICON_SPECIAL

func _scaled_icon(texture:Texture2D,size_value:int)->Texture2D:
	if texture==null:return null
	var image:Image=texture.get_image()
	if image==null or image.is_empty():return texture
	image.resize(size_value,size_value,Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _claim(item_id:String)->void:
	if not run_state.pending_chest_choices.has(item_id):return
	relic_selected.emit(item_id)

func _card_style(background:Color,border:Color,width:int,shadow:int)->StyleBoxFlat:
	var style:=_panel(background,border,width,16,0);style.shadow_color=Color(border,0.48);style.shadow_size=shadow;style.shadow_offset=Vector2.ZERO;style.corner_radius_top_left=22;style.corner_radius_top_right=22;style.corner_radius_bottom_left=28;style.corner_radius_bottom_right=28;return style

func _panel(background:Color,border:Color,width:int,radius:int=8,margin:int=18)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=background;style.border_color=border;style.set_border_width_all(width);style.set_corner_radius_all(radius)
	for side:int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,margin)
	return style
