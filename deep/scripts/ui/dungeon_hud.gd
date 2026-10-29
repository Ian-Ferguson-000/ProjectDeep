extends Control
class_name DungeonHud

## The in-dungeon HUD, Binding of Isaac style: a row of pixel hearts in the top
## left, coin and key counts under it, nothing else on screen until it matters.
## Numbers live in data/slasher_balance.json -> "hud".
##
## The dungeon scene calls `show_state()` whenever health, gold or keys change,
## and `show_floor_banner()` when a new floor starts.

const GOLD_ICON := preload("res://assets/slasher/ui/resource_gold.svg")
const KEY_ICON := preload("res://assets/slasher/ui/resource_key.svg")
const POTION_ICON := preload("res://assets/slasher/ui/resource_potion.svg")

## 7x6 pixel heart. Each "X" is one pixel, drawn PIXEL screen pixels wide.
const HEART := [
	".XX.XX.",
	"XXXXXXX",
	"XXXXXXX",
	".XXXXX.",
	"..XXX..",
	"...X...",
]
const PIXEL := 5.0
const HEART_SIZE := Vector2(7,6) * PIXEL
const HEART_GAP := 4.0
const HEARTS_PER_ROW := 6
const MARGIN := Vector2(28,24)

const RED := Color("#d42a2a")
const RED_LIGHT := Color("#ff7a6a")
const RED_DARK := Color("#8a1414")
const EMPTY := Color("#2a1a1a")
const OUTLINE := Color("#0b0808")
const TEXT := Color("#f4ecd8")

var health_per_heart := 4
var health := 0
var max_health := 1
var resource := 0
var resource_max := 0
var resource_color := Color("#d88322")
var show_resource := false

var _flash := 0.0
var _shake := 0.0
var _time := 0.0
var _counters := VBoxContainer.new()
var gold_label: Label
var key_label: Label
var potion_label: Label
var _potion_row: Control
var _banner: Control

func _init() -> void:
	name = "DungeonHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var tuning: Dictionary = GameBalance.get_slasher_balance("hud")
	health_per_heart = maxi(1,int(tuning.get("health_per_heart",4)))
	_counters.name = "Counters"
	_counters.add_theme_constant_override("separation",0)
	_counters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_counters)
	gold_label = _add_counter(GOLD_ICON,"Gold")
	key_label = _add_counter(KEY_ICON,"Keys")
	potion_label = _add_counter(POTION_ICON,"Potions")
	_potion_row = potion_label.get_parent()

func _add_counter(icon_texture: Texture2D, tooltip: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counters.add_child(row)
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(26,26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.tooltip_text = tooltip
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var label := Label.new()
	label.name = tooltip
	label.text = "00"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_color",TEXT)
	label.add_theme_color_override("font_outline_color",OUTLINE)
	label.add_theme_constant_override("outline_size",7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return label

## Update everything shown. Hearts flash and shake when health drops.
func show_state(current_health: int, maximum_health: int, gold: int, keys: int, potions: int, show_potions: bool) -> void:
	if current_health < health and health > 0:
		_flash = 0.35
		_shake = 0.3
	health = maxi(0,current_health)
	max_health = maxi(1,maximum_health)
	gold_label.text = "%02d" % gold
	key_label.text = "%02d" % keys
	potion_label.text = "%02d" % potions
	_potion_row.visible = show_potions
	_layout_counters()
	queue_redraw()

func show_resource_pips(current: int, maximum: int, color: Color, visible_value: bool) -> void:
	resource = current
	resource_max = maximum
	resource_color = color
	show_resource = visible_value and maximum > 0
	_layout_counters()
	queue_redraw()

func heart_count() -> int:
	return int(ceil(float(max_health) / float(health_per_heart)))

func heart_rows() -> int:
	return int(ceil(float(heart_count()) / float(HEARTS_PER_ROW)))

func _hearts_height() -> float:
	return heart_rows() * (HEART_SIZE.y + HEART_GAP)

func _layout_counters() -> void:
	var top := MARGIN.y + _hearts_height() + (14.0 if show_resource else 0.0) + 6.0
	_counters.position = Vector2(MARGIN.x - 2.0,top)

func _process(delta: float) -> void:
	_time += delta
	var animating := _flash > 0.0 or _shake > 0.0 or _low_health()
	_flash = maxf(0.0,_flash - delta)
	_shake = maxf(0.0,_shake - delta)
	if animating: queue_redraw()

func _low_health() -> bool:
	return health > 0 and health <= health_per_heart

func _draw() -> void:
	var offset := Vector2.ZERO
	if _shake > 0.0: offset = Vector2(randf_range(-2.0,2.0),randf_range(-2.0,2.0))
	var count := heart_count()
	for index in count:
		var row := index / HEARTS_PER_ROW
		var column := index % HEARTS_PER_ROW
		var at := MARGIN + offset + Vector2(column * (HEART_SIZE.x + HEART_GAP),row * (HEART_SIZE.y + HEART_GAP))
		var filled := clampf(float(health - index * health_per_heart) / float(health_per_heart),0.0,1.0)
		# The heart holding your last health beats when you're nearly dead.
		var beat := 1.0
		var is_last := filled > 0.0 and float(health) <= float(index + 1) * health_per_heart
		if is_last and _low_health(): beat = 1.0 + 0.12 * maxf(0.0,sin(_time * 9.0))
		_draw_heart(at,filled,beat)
	if show_resource:
		var pip_top := MARGIN.y + _hearts_height() + 1.0
		for index in resource_max:
			var center := Vector2(MARGIN.x + 6.0 + index * 16.0,pip_top + 5.0)
			var points := PackedVector2Array([center + Vector2(0,-6),center + Vector2(6,0),center + Vector2(0,6),center + Vector2(-6,0)])
			draw_colored_polygon(points,OUTLINE)
			var inner := PackedVector2Array([center + Vector2(0,-4),center + Vector2(4,0),center + Vector2(0,4),center + Vector2(-4,0)])
			draw_colored_polygon(inner,resource_color if index < resource else EMPTY)

func _draw_heart(at: Vector2, filled: float, beat: float) -> void:
	var pixel := PIXEL * beat
	var origin := at + HEART_SIZE * 0.5 - Vector2(7,6) * pixel * 0.5
	# A one-pixel dark outline all round, like a sprite.
	for y in HEART.size():
		for x in String(HEART[y]).length():
			if String(HEART[y])[x] != "X": continue
			draw_rect(Rect2(origin + Vector2(x - 1,y - 1) * pixel,Vector2(3,3) * pixel),OUTLINE)
	var fill_columns := filled * 7.0
	for y in HEART.size():
		for x in String(HEART[y]).length():
			if String(HEART[y])[x] != "X": continue
			var color := EMPTY
			if float(x) + 0.5 <= fill_columns:
				color = RED
				if y >= 4 or x == 6 or (y == 3 and x == 5): color = RED_DARK
				if (x == 1 and y == 1) or (x == 1 and y == 0) or (x == 2 and y == 1): color = RED_LIGHT
			if _flash > 0.0 and color != EMPTY: color = color.lerp(Color.WHITE,_flash / 0.35 * 0.8)
			draw_rect(Rect2(origin + Vector2(x,y) * pixel,Vector2.ONE * pixel),color)

## "VERDANT FOREST" / "Floor 2 of 5": slides in at the top centre, then fades.
func show_floor_banner(title: String, subtitle: String) -> void:
	if is_instance_valid(_banner): _banner.queue_free()
	_banner = VBoxContainer.new()
	_banner.name = "FloorBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -320; _banner.offset_right = 320; _banner.offset_top = 150; _banner.offset_bottom = 230
	_banner.add_theme_constant_override("separation",0)
	add_child(_banner)
	for part in [[title,38,TEXT],[subtitle,20,Color("#c9b78f")]]:
		var label := Label.new()
		label.text = String(part[0])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",int(part[1]))
		label.add_theme_color_override("font_color",part[2])
		label.add_theme_color_override("font_outline_color",OUTLINE)
		label.add_theme_constant_override("outline_size",9)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_banner.add_child(label)
	_banner.modulate.a = 0.0
	_banner.position.y -= 16.0
	var banner := _banner
	var tween := create_tween()
	tween.tween_property(banner,"modulate:a",1.0,0.35)
	tween.parallel().tween_property(banner,"position:y",banner.position.y + 16.0,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.9)
	tween.tween_property(banner,"modulate:a",0.0,0.6)
	tween.tween_callback(banner.queue_free)
