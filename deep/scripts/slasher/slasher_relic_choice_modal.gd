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

var run_state:RunState
var mandatory:=true
var previous_pause:=false
var card_row:HBoxContainer

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP;visible=false
	var shade:=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color("#07100deb");add_child(shade)
	var frame:=PanelContainer.new();frame.anchor_left=0.5;frame.anchor_top=0.5;frame.anchor_right=0.5;frame.anchor_bottom=0.5;frame.offset_left=-510;frame.offset_top=-285;frame.offset_right=510;frame.offset_bottom=285;frame.add_theme_stylebox_override("panel",_panel(Color("#171109f5"),Color("#d9a52b"),3));add_child(frame)
	var body:=VBoxContainer.new();body.add_theme_constant_override("separation",16);frame.add_child(body)
	var title:=Label.new();title.text="CHOOSE A RELIC";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",30);title.add_theme_color_override("font_color",Color("#f4d178"));body.add_child(title)
	var subtitle:=Label.new();subtitle.text="Choose one. This decision cannot be dismissed.";subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.add_theme_font_size_override("font_size",17);body.add_child(subtitle)
	card_row=HBoxContainer.new();card_row.alignment=BoxContainer.ALIGNMENT_CENTER;card_row.size_flags_vertical=Control.SIZE_EXPAND_FILL;card_row.add_theme_constant_override("separation",14);body.add_child(card_row)
	var hint:=Label.new();hint.text="Mouse / Arrow Keys / A-D  ·  Enter / A: Claim";hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.add_theme_color_override("font_color",Color("#c7ae78"));body.add_child(hint)

func open(state:RunState,choices:Array[String],is_mandatory:bool=true)->void:
	run_state=state;mandatory=is_mandatory;previous_pause=get_tree().paused
	for child:Node in card_row.get_children():child.free()
	for item_id:String in choices:card_row.add_child(_card(item_id))
	visible=true;move_to_front();get_tree().paused=true
	if card_row.get_child_count()>0:(card_row.get_child(0) as Button).grab_focus()

func finish()->void:
	visible=false;get_tree().paused=previous_pause

func _unhandled_input(event:InputEvent)->void:
	if not visible:return
	if mandatory and event.is_action_pressed("ui_cancel"):get_viewport().set_input_as_handled()

func _card(item_id:String)->Button:
	var item:Dictionary=GameBalance.get_item(item_id);var rarity:String=String(item.get("rarity","common"));var rarity_data:Dictionary=GameBalance.get_item_rarities().get(rarity,{})
	var button:=Button.new();button.custom_minimum_size=Vector2(300,390);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var duration:String=String(item.get("duration_type","dungeon_bound")).replace("_"," ").capitalize()
	button.text="%s\n\n%s · %s\n\n%s\n\n%s\n\nCLAIM"%[String(item.get("name",item_id)),String(rarity_data.get("name",rarity.capitalize())),duration,String(item.get("description","")),GameBalance.get_slasher_item_rules_text(item_id)]
	button.icon=_scaled_icon(_item_icon(String(item.get("icon_key","special"))),48);button.expand_icon=false;button.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size",17);button.add_theme_color_override("font_color",Color(String(rarity_data.get("color","#c9c2aa"))));button.add_theme_stylebox_override("normal",_panel(Color("#15100ce8"),Color(String(rarity_data.get("color","#c9c2aa"))),2));button.pressed.connect(_claim.bind(item_id));return button

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

func _panel(background:Color,border:Color,width:int)->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=background;style.border_color=border;style.set_border_width_all(width);style.set_corner_radius_all(8)
	for side:int in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,18)
	return style
