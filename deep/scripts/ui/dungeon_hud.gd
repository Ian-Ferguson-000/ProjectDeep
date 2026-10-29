extends Control
class_name DungeonHud

## The in-dungeon HUD, Binding of Isaac style: the relics picked up this run in
## the top left, pixel hearts with coin and key counts in the bottom left, nothing
## else on screen until it matters. Numbers live in data/slasher_balance.json -> "hud".
##
## The dungeon scene calls `show_state()` whenever health, gold or keys change,
## `show_items()` with the run's relics, and `show_floor_banner()` when a floor starts.

const GOLD_ICON := preload("res://assets/slasher/ui/resource_gold.svg")
const KEY_ICON := preload("res://assets/slasher/ui/resource_key.svg")
const POTION_ICON := preload("res://assets/slasher/ui/resource_potion.svg")
const UI_ICONS := "res://assets/Humble Gift - Paper UI System v1.1/Sprites/Content/"
## Relics carry a category icon ("icon" in pickup_items.json); art per relic can
## replace these later.
const ITEM_ICONS := {
	"attack":"2 Icons/2.png", "defense":"2 Icons/12.png", "potion":"1 Items/15.png", "health":"1 Items/15.png",
	"move":"2 Icons/1.png", "movement":"2 Icons/1.png", "gold":"1 Items/1.png", "mode":"2 Icons/7.png", "special":"2 Icons/10.png",
}
const SPELL_ICON := "res://assets/pixel_art/spellnode.png"
const ITEM_SLOT := 38.0
const ITEMS_PER_ROW := 5
const MAX_ITEM_SLOTS := 20
const POTION_SLOT := 52.0
const ACTIVE_SLOT := 64.0

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
var _counters := HBoxContainer.new()
var _items := GridContainer.new()
var _item_signature := ""
var _items_shown_once := false
var item_slots: Array[Control] = []
var gold_label: Label
var key_label: Label
var potion_label: Label
var potion_slot: Panel
## The active item slot (Space), bottom-left corner.
var active_slot: ActiveSlot
var _potion_icon: TextureRect
var _banner: Control

func _init() -> void:
	name = "DungeonHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var tuning: Dictionary = GameBalance.get_slasher_balance("hud")
	health_per_heart = maxi(1,int(tuning.get("health_per_heart",4)))
	_counters.name = "Counters"
	_counters.add_theme_constant_override("separation",18)
	_counters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_counters)
	gold_label = _add_counter(GOLD_ICON,"Gold")
	key_label = _add_counter(KEY_ICON,"Keys")
	_build_potion_slot()
	active_slot = ActiveSlot.new(); active_slot.name = "ActiveSlot"; active_slot.size = Vector2.ONE * ACTIVE_SLOT
	add_child(active_slot)
	_items.name = "Items"
	_items.columns = ITEMS_PER_ROW
	_items.add_theme_constant_override("h_separation",4)
	_items.add_theme_constant_override("v_separation",4)
	_items.position = MARGIN - Vector2(6,6)
	_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_items)

## Pushes the relic row down, e.g. below the party strip when parties are on.
func set_items_top(top: float) -> void:
	_items.position.y = top

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED: _layout_counters()

## The potion pocket in the bottom-left corner: always there, greyed out when
## empty, with the key that drinks one (Q).
func _build_potion_slot() -> void:
	potion_slot = Panel.new()
	potion_slot.name = "PotionSlot"
	potion_slot.size = Vector2.ONE * POTION_SLOT
	potion_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	potion_slot.tooltip_text = "Healing potion\nPress Q (left stick on a controller) to drink one."
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e3d3ad")
	style.border_color = Color("#8a1414")
	style.set_border_width_all(3)
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0,0,0,0.55)
	style.shadow_size = 2
	potion_slot.add_theme_stylebox_override("panel",style)
	add_child(potion_slot)
	_potion_icon = TextureRect.new()
	_potion_icon.texture = POTION_ICON
	_potion_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_potion_icon.offset_left = 7; _potion_icon.offset_top = 6; _potion_icon.offset_right = -7; _potion_icon.offset_bottom = -8
	_potion_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_potion_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_potion_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_slot.add_child(_potion_icon)
	var key := _slot_label("Q",13)
	key.name = "Key"
	key.position = Vector2(4,-2)
	potion_slot.add_child(key)
	potion_label = _slot_label("0",17)
	potion_label.name = "Potions"
	potion_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	potion_label.offset_left = -26; potion_label.offset_top = -24; potion_label.offset_right = -3; potion_label.offset_bottom = 2
	potion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	potion_slot.add_child(potion_label)

func _slot_label(text_value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",TEXT)
	label.add_theme_color_override("font_outline_color",OUTLINE)
	label.add_theme_constant_override("outline_size",5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

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
func show_state(current_health: int, maximum_health: int, gold: int, keys: int, potions: int) -> void:
	if current_health < health and health > 0:
		_flash = 0.35
		_shake = 0.3
	health = maxi(0,current_health)
	max_health = maxi(1,maximum_health)
	gold_label.text = "%02d" % gold
	key_label.text = "%02d" % keys
	potion_label.text = str(potions)
	_potion_icon.modulate = Color.WHITE if potions > 0 else Color(0.3,0.3,0.3,0.55)
	potion_label.visible = potions > 0
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

## Hearts sit on the bottom edge; pips and the coin/key row stack above them.
func _hearts_top() -> float:
	return size.y - MARGIN.y - _hearts_height() + HEART_GAP

## Hearts start to the right of the potion pocket.
func _hearts_left() -> float:
	return MARGIN.x + ACTIVE_SLOT + 10.0 + POTION_SLOT + 12.0

func _layout_counters() -> void:
	var bottom := size.y - MARGIN.y + 2.0
	active_slot.position = Vector2(MARGIN.x,bottom - ACTIVE_SLOT)
	potion_slot.position = Vector2(MARGIN.x + ACTIVE_SLOT + 10.0,bottom - POTION_SLOT)
	var top := minf(_hearts_top() - (16.0 if show_resource else 0.0),active_slot.position.y - 4.0) - 32.0
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
		var at := Vector2(_hearts_left(),_hearts_top()) + offset + Vector2(column * (HEART_SIZE.x + HEART_GAP),row * (HEART_SIZE.y + HEART_GAP))
		var filled := clampf(float(health - index * health_per_heart) / float(health_per_heart),0.0,1.0)
		# The heart holding your last health beats when you're nearly dead.
		var beat := 1.0
		var is_last := filled > 0.0 and float(health) <= float(index + 1) * health_per_heart
		if is_last and _low_health(): beat = 1.0 + 0.12 * maxf(0.0,sin(_time * 9.0))
		_draw_heart(at,filled,beat)
	if show_resource:
		var pip_top := _hearts_top() - 16.0
		for index in resource_max:
			var center := Vector2(_hearts_left() + 6.0 + index * 16.0,pip_top + 5.0)
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

## The active item: its icon, charge (pips for room items, a filling bar for
## timer items) and whether it's ready. Empty shows a faint slot.
func show_active(item_id: String, charge: float, maximum: float, timer: bool) -> void:
	active_slot.show_item(item_id,charge,maximum,timer)

## Isaac-style pickup text: the item's name big, what it does underneath.
func show_pickup(title: String, text: String) -> void:
	show_floor_banner(title,text)

## "VERDANT FOREST" / "Floor 2 of 5": slides in at the top centre, then fades.
func show_floor_banner(title: String, subtitle: String) -> void:
	if is_instance_valid(_banner): _banner.queue_free()
	_banner = VBoxContainer.new()
	_banner.name = "FloorBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -360; _banner.offset_right = 360; _banner.offset_top = 150; _banner.offset_bottom = 250
	_banner.add_theme_constant_override("separation",0)
	add_child(_banner)
	for part in [[title,38,TEXT],[subtitle,20,Color("#c9b78f")]]:
		var label := Label.new()
		label.text = String(part[0])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(720,0)
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

## The relics this run has picked up, newest last. Each entry is an inventory
## entry from RunState ({id, duration_type, remaining_floors}). Hover a slot for
## its name and effect.
func show_items(entries: Array) -> void:
	var parts: PackedStringArray = []
	for entry in entries: parts.append("%s:%d" % [String(Dictionary(entry).get("id","")),int(Dictionary(entry).get("remaining_floors",0))])
	var signature := ",".join(parts)
	if signature == _item_signature and _items_shown_once: return
	var previous_count := item_slots.size()
	var animate := _items_shown_once
	_items_shown_once = true
	_item_signature = signature
	for child in _items.get_children(): child.free()
	item_slots.clear()
	var shown := entries.slice(maxi(0,entries.size() - MAX_ITEM_SLOTS)) if entries.size() > MAX_ITEM_SLOTS else entries
	for entry_value in shown:
		var slot := _item_slot(Dictionary(entry_value))
		_items.add_child(slot)
		item_slots.append(slot)
	# A newly picked-up relic pops in.
	if animate and item_slots.size() > previous_count:
		var newest: Control = item_slots[item_slots.size() - 1]
		newest.pivot_offset = Vector2.ONE * ITEM_SLOT * 0.5
		newest.scale = Vector2.ONE * 1.6
		create_tween().tween_property(newest,"scale",Vector2.ONE,0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _item_slot(entry: Dictionary) -> Control:
	var item_id := String(entry.get("id",""))
	var item: Dictionary = GameBalance.get_item(item_id)
	var rarity := String(item.get("rarity","common"))
	var accent := Color(String(Dictionary(GameBalance.get_item_rarities().get(rarity,{})).get("color","#c9c2aa")))
	var slot := Panel.new()
	slot.name = "Item_%s" % item_id
	slot.custom_minimum_size = Vector2.ONE * ITEM_SLOT
	# PASS keeps the hover tooltip without swallowing clicks meant for the game.
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.tooltip_text = "%s\n%s" % [String(item.get("name",item_id)),GameBalance.get_slasher_item_rules_text(item_id).trim_prefix("Slasher:").strip_edges()]
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e3d3ad")
	style.border_color = accent.darkened(0.15)
	style.set_border_width_all(3)
	style.shadow_color = Color(0,0,0,0.55)
	style.shadow_size = 2
	style.set_corner_radius_all(4)
	slot.add_theme_stylebox_override("panel",style)
	var icon := TextureRect.new()
	icon.texture = item_icon(String(item.get("icon_key","special")))
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 5; icon.offset_top = 5; icon.offset_right = -5; icon.offset_bottom = -5
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	# Temporary relics show how many floors they have left.
	if String(entry.get("duration_type","")) == "temporary":
		var left := Label.new()
		left.text = str(int(entry.get("remaining_floors",0)))
		left.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		left.offset_left = -14; left.offset_top = -18; left.offset_right = -1; left.offset_bottom = 1
		left.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		left.add_theme_font_size_override("font_size",12)
		left.add_theme_color_override("font_color",TEXT)
		left.add_theme_color_override("font_outline_color",OUTLINE)
		left.add_theme_constant_override("outline_size",4)
		left.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(left)
	return slot

static func item_icon(icon_key: String) -> Texture2D:
	var path := SPELL_ICON if icon_key == "spell" else UI_ICONS + String(ITEM_ICONS.get(icon_key,ITEM_ICONS.special))
	return load(path) if ResourceLoader.exists(path) else null


## The active item slot: a gold-framed box with the item's icon, a charge meter
## down its right side and the key that uses it. Glows when ready.
class ActiveSlot extends Control:
	var item_id := ""
	var charge := 0.0
	var maximum := 1.0
	var timer := false
	var icon := TextureRect.new()
	var time := 0.0
	var ready_flash := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		icon.position = Vector2(8,8); icon.size = Vector2(40,40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
		var key := Label.new(); key.text = "SPACE"; key.position = Vector2(4,-16)
		key.add_theme_font_size_override("font_size",11); key.add_theme_color_override("font_color",Color("#f4ecd8"))
		key.add_theme_color_override("font_outline_color",Color("#0b0808")); key.add_theme_constant_override("outline_size",4)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(key)

	func is_ready() -> bool:
		return not item_id.is_empty() and charge >= maximum - 0.001

	func show_item(id: String, value: float, top: float, uses_timer: bool) -> void:
		var was_ready := is_ready()
		if id != item_id:
			item_id = id
			var record := ActiveItems.item(id)
			tooltip_text = "%s\n%s" % [String(record.get("name","")),String(record.get("description",""))] if not id.is_empty() else "Active item slot (Space)\nFind active items in treasure rooms."
		charge = value; maximum = maxf(0.001,top); timer = uses_timer
		if is_ready() and not was_ready and not id.is_empty(): ready_flash = 0.5
		queue_redraw()

	func _process(delta: float) -> void:
		time += delta
		ready_flash = maxf(0.0,ready_flash - delta)
		if is_ready() or ready_flash > 0.0: queue_redraw()

	func _draw() -> void:
		var box := Rect2(Vector2.ZERO,size)
		var gold := Color("#d4a63a"); var dark := Color("#7a5514")
		draw_rect(box.grow(3.0),Color("#140b04"))
		draw_rect(box.grow(1.5),dark)
		draw_rect(box,Color("#e3d3ad") if not item_id.is_empty() else Color(0.89,0.83,0.68,0.35))
		draw_rect(box,gold,false,2.0)
		if item_id.is_empty():
			draw_string(ThemeDB.fallback_font,Vector2(0,size.y * 0.58),"—",HORIZONTAL_ALIGNMENT_CENTER,size.x,20,Color(0.3,0.25,0.2,0.6))
			return
		# Charge meter down the right edge.
		var meter := Rect2(size.x - 11.0,5.0,7.0,size.y - 10.0)
		draw_rect(meter.grow(1.0),Color("#140b04"))
		var fill_colour := Color("#f6c945") if is_ready() else Color("#6fa8dc")
		if timer:
			var filled := clampf(charge / maximum,0.0,1.0)
			draw_rect(Rect2(meter.position.x,meter.end.y - meter.size.y * filled,meter.size.x,meter.size.y * filled),fill_colour)
		else:
			var pips := int(round(maximum))
			var gap := 2.0
			var pip_h := (meter.size.y - gap * (pips - 1)) / pips
			for index in pips:
				var y := meter.end.y - (index + 1) * pip_h - index * gap
				draw_rect(Rect2(meter.position.x,y,meter.size.x,pip_h),fill_colour if index < int(round(charge)) else Color("#3a3036"))
		SlasherActiveEffects.draw_icon(self,item_id,Vector2((size.x - 12.0) * 0.5 + 2.0,size.y * 0.5),40.0,not is_ready())
		if is_ready():
			var pulse := 0.5 + sin(time * 5.0) * 0.3
			draw_rect(box.grow(4.0),Color(1.0,0.85,0.35,pulse),false,3.0)
		if ready_flash > 0.0: draw_rect(box,Color(1,1,1,ready_flash))
