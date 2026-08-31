extends ColorRect
class_name MerchantShopPanel

signal closed
signal purchase_completed(message: String)

var run_state: RunState
var merchant_id := "tavern"
var shop_location := "tavern"
var title_label: Label
var resource_label: Label
var portrait: TextureRect
var stock_box: VBoxContainer
var feedback_label: Label

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color(0.025, 0.018, 0.012, 0.82)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func setup(state: RunState, selected_merchant_id: String, location: String) -> void:
	run_state = state
	merchant_id = selected_merchant_id
	shop_location = location
	if get_child_count() == 0:
		_build_ui()
	_refresh()

func open() -> void:
	_refresh()
	visible = true
	move_to_front()
	var first_button := _first_enabled_buy_button()
	if first_button != null: first_button.grab_focus()

func close() -> void:
	visible = false
	closed.emit()

func _first_enabled_buy_button() -> Button:
	if stock_box == null: return null
	for row in stock_box.get_children():
		for node in row.find_children("*BuyButton", "Button", true, false):
			var button := node as Button
			if button != null and not button.disabled: return button
	return null

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left=0.5;panel.anchor_top=0.5;panel.anchor_right=0.5;panel.anchor_bottom=0.5
	panel.offset_left=-430;panel.offset_top=-300;panel.offset_right=430;panel.offset_bottom=300
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.085, 0.06, 0.038), Color(0.80, 0.58, 0.26), 8))
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 16)
	panel.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	body.add_child(header)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(112, 112)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.43))
	identity.add_child(title_label)
	resource_label = Label.new()
	resource_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_label.add_theme_font_size_override("font_size", 12)
	resource_label.add_theme_color_override("font_color", Color(0.88, 0.78, 0.62))
	identity.add_child(resource_label)
	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.add_theme_color_override("font_color", Color(0.66, 0.86, 0.63))
	identity.add_child(feedback_label)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(90, 36)
	close_button.pressed.connect(close)
	_style_button(close_button)
	header.add_child(close_button)
	var divider := HSeparator.new()
	body.add_child(divider)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	stock_box = VBoxContainer.new()
	stock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_box.add_theme_constant_override("separation", 8)
	scroll.add_child(stock_box)

func _refresh() -> void:
	if stock_box == null or run_state == null:
		return
	var merchant := GameBalance.get_merchant(merchant_id)
	var rank := run_state.get_merchant_rank(merchant_id)
	var progress := run_state.get_merchant_progress(merchant_id)
	title_label.text = "%s — %s" % [String(merchant.get("name", merchant_id.capitalize())), String(merchant.get("title", "Merchant"))]
	resource_label.text = "%s  |  Gold %d  |  Favor %d available / %d lifetime  |  Highest depth %d\n%s" % [
		GameBalance.get_merchant_rank_name(rank), run_state.gold, int(progress.get("available_favor", 0)), int(progress.get("lifetime_favor", 0)), int(progress.get("highest_depth", 0)),
		_next_rank_text(rank, progress)
	]
	feedback_label.text = String(merchant.get("description", "")) if feedback_label.text.is_empty() else feedback_label.text
	var portrait_path := String(merchant.get("portrait", ""))
	portrait.texture = load(portrait_path) if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path) else null
	for child in stock_box.get_children(): child.queue_free()
	for offer in run_state.get_merchant_offers(merchant_id, shop_location):
		stock_box.add_child(_make_offer_row(offer, rank))

func _make_offer_row(offer: Dictionary, rank: int) -> PanelContainer:
	var unlocked := bool(offer.get("unlocked", false))
	var row_panel := PanelContainer.new()
	row_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.13, 0.095, 0.055, 0.95), Color(0.42, 0.31, 0.18), 5))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_%s" % side, 9)
	row_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_box)
	var name_label := Label.new()
	name_label.text = String(offer.get("name", offer.get("offer_id", "Offer")))
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.54) if unlocked else Color(0.52, 0.48, 0.41))
	text_box.add_child(name_label)
	var description := Label.new()
	description.text = String(offer.get("description", ""))
	description.text += "\n%s · Stock %d/%d" % [String(offer.get("rarity", "common")).replace("_", " ").capitalize(), int(offer.get("stock_remaining", 0)), int(offer.get("max_stock", 0))]
	var rules := String(offer.get("rules_text", ""))
	if not rules.is_empty(): description.text += "\n" + rules
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", Color(0.80, 0.74, 0.65))
	text_box.add_child(description)
	var buy := Button.new()
	buy.name = "%sBuyButton" % String(offer.get("offer_id", "Offer")).to_pascal_case()
	var favor_cost := int(offer.get("favor", 0))
	var currency := "Favor" if favor_cost > 0 else "gold"
	var cost := favor_cost if favor_cost > 0 else int(offer.get("gold", 0))
	var sold := bool(offer.get("sold", false))
	buy.text = "Sold" if sold else "Buy\n%d %s" % [cost, currency]
	buy.custom_minimum_size = Vector2(118, 54)
	var claimed := bool(offer.get("claimed", false))
	buy.disabled = sold or claimed or not unlocked or (favor_cost > 0 and int(run_state.get_merchant_progress(merchant_id).get("available_favor", 0)) < cost) or (favor_cost == 0 and run_state.gold < cost)
	buy.tooltip_text = "Sold out" if sold else ("Already claimed" if claimed else ("Requires %s rank" % GameBalance.get_merchant_rank_name(int(offer.get("min_rank", 0))) if not unlocked else "Purchase this offer"))
	buy.pressed.connect(_purchase.bind(String(offer.get("offer_id", ""))))
	_style_button(buy)
	row.add_child(buy)
	return row_panel

func _next_rank_text(rank: int, progress: Dictionary) -> String:
	var requirements := GameBalance.get_merchant_rank_requirements()
	if rank + 1 >= requirements.size(): return "Maximum rank"
	var next_value: Variant = requirements[rank + 1]
	if not (next_value is Dictionary): return ""
	var next: Dictionary = next_value
	var parts: Array[String] = ["%d/%d lifetime Favor"%[int(progress.get("lifetime_favor",0)),int(next.get("favor",0))]]
	if next.has("depth"): parts.append("depth %d/%d"%[int(progress.get("highest_depth",0)),int(next.get("depth",0))])
	if bool(next.get("boss_clear",false)): parts.append("boss clear required")
	return "Next: "+", ".join(parts)

func _purchase(offer_id: String) -> void:
	var logs := run_state.purchase_merchant_offer(merchant_id, offer_id, shop_location)
	feedback_label.text = " ".join(logs)
	purchase_completed.emit(feedback_label.text)
	_refresh()

func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.18, 0.12, 0.06), Color(0.68, 0.46, 0.20), 4))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.28, 0.18, 0.07), Color(1.0, 0.72, 0.28), 4))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.08, 0.07, 0.06), Color(0.25, 0.22, 0.18), 4))
	button.add_theme_color_override("font_color", Color(1.0, 0.87, 0.60))
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.37))

func _panel_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
