extends Control
class_name GuardianCrossroads

## Shown when a dungeon's guardian falls: what the adventurer is carrying, what
## they'd keep or lose by going home, bounty progress and new unlocks. Choose to
## return to the Hearth or press on into the next dungeon.

signal decided(continue_on: bool)

const UI := preload("res://scripts/ui/tavern_ui_theme.gd")
const LOST := Color("#e89a7a")
const KEPT := Color("#9fd48a")

var run_state: RunState
var next_name := ""
var can_continue := false
var return_button: Button
var continue_button: Button
var _previous_pause := false

func setup(state: RunState, next_dungeon_name: String, allow_continue: bool) -> GuardianCrossroads:
	run_state = state; next_name = next_dungeon_name; can_continue = allow_continue
	return self

func _ready() -> void:
	name = "GuardianCrossroads"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_pause = get_tree().paused
	get_tree().paused = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new(); shade.color = Color("#05070ae6"); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(980,560)
	panel.position = -panel.custom_minimum_size * 0.5
	panel.add_theme_stylebox_override("panel",UI.panel(Color("#17130ffb"),UI.GOLD,8,2))
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + side,20)
	panel.add_child(margin)
	var body := VBoxContainer.new(); body.add_theme_constant_override("separation",12); margin.add_child(body)
	var dungeon_name := String(GameBalance.get_dungeon(run_state.active_dungeon_id).get("name",run_state.active_dungeon_id.capitalize()))
	body.add_child(_label("THE GUARDIAN FALLS",30,UI.HIGHLIGHT_GOLD,true))
	var clear := run_state.last_clear
	var sub := dungeon_name + ("  ·  " + String(clear.get("message","")) if not clear.is_empty() else "")
	body.add_child(_label(sub,16,UI.IVORY,true))
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation",14); columns.size_flags_vertical = Control.SIZE_EXPAND_FILL; body.add_child(columns)
	_carried_column(columns)
	_progress_column(columns)
	var warning := "Press on into %s: no rest or resupply at the Hearth on the way. If your adventurer falls, everything above is lost." % next_name if can_continue else "The road onward is not open yet."
	var note := _label(warning,13,UI.MUTED,true); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(note)
	var buttons := HBoxContainer.new(); buttons.alignment = BoxContainer.ALIGNMENT_CENTER; buttons.add_theme_constant_override("separation",18); body.add_child(buttons)
	return_button = Button.new(); return_button.text = "Return to the Hearth"; UI.apply_button(return_button,true,16,Vector2(260,52)); return_button.pressed.connect(_choose.bind(false)); buttons.add_child(return_button)
	continue_button = Button.new(); continue_button.text = "Continue to %s" % next_name if can_continue else "Continue"; UI.apply_button(continue_button,false,16,Vector2(260,52)); continue_button.disabled = not can_continue; continue_button.pressed.connect(_choose.bind(true)); buttons.add_child(continue_button)
	return_button.grab_focus.call_deferred()

func _carried_column(parent: Control) -> void:
	var box := _card(parent,"Bringing home")
	var expedition := run_state.campaign.expedition if run_state.campaign != null else null
	var gold := run_state.gold
	box.add_child(_row("Gold carried","%d  (the Hearth keeps %d)" % [gold,gold - int(gold * 0.2)],UI.HIGHLIGHT_GOLD))
	if expedition != null and expedition.carried_relic_essence > 0: box.add_child(_row("Relic essence",str(expedition.carried_relic_essence),UI.HIGHLIGHT_GOLD))
	if expedition != null:
		for relic_id in expedition.carried_relics: box.add_child(_row("Unique relic",String(relic_id).replace("_"," ").capitalize(),KEPT))
	var consumables := {}
	for id in run_state.get_consumables(): consumables[id] = int(consumables.get(id,0)) + 1
	for id in consumables: box.add_child(_row(String(GameBalance.get_consumable(String(id)).get("name",String(id).replace("_"," ").capitalize())),"× %d" % int(consumables[id]),UI.IVORY))
	if run_state.keys > 0: box.add_child(_row("Keys","× %d" % run_state.keys,UI.IVORY))
	box.add_child(_label("RELICS AND ITEMS",11,UI.MUTED))
	var items := run_state.get_inventory_items()
	if items.is_empty(): box.add_child(_label("Nothing found this run.",13,UI.MUTED))
	for entry in items:
		var item := GameBalance.get_item(String(entry.get("id","")))
		var lasting := String(entry.get("duration_type","run"))
		var status := "Kept" if lasting in ["permanent","equipped"] else "Lost on return"
		box.add_child(_row(String(item.get("name",entry.get("id",""))),status,KEPT if status == "Kept" else LOST))

func _progress_column(parent: Control) -> void:
	var box := _card(parent,"Bounties")
	var stats := run_state.run_stats()
	var offers: Array = BountyBoard.offers(run_state.campaign) if run_state.campaign != null else []
	if offers.is_empty(): box.add_child(_label("No bounties posted.",13,UI.MUTED))
	for bounty in offers:
		var progress := BountyBoard.progress(bounty,stats,run_state.gold)
		var done := bool(progress.done)
		var line := _row(("✓ " if done else "• ") + String(bounty.text),String(progress.label),KEPT if done else UI.IVORY)
		box.add_child(line)
	box.add_child(_label("Paid when you get home alive.",12,UI.MUTED))
	var unlocked: Array = Array(stats.get("unlocked",[]))
	box.add_child(_label("UNLOCKED THIS EXPEDITION",11,UI.MUTED))
	if unlocked.is_empty(): box.add_child(_label("Nothing yet.",13,UI.MUTED))
	for name_text in unlocked: box.add_child(_label("◆ " + String(name_text),14,Color("#e08af0")))

func _card(parent: Control, title: String) -> VBoxContainer:
	var card := PanelContainer.new(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel",UI.panel(Color("#221a12"),UI.BRONZE,5,1))
	parent.add_child(card)
	var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.custom_minimum_size = Vector2(0,330); card.add_child(scroll)
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",5); scroll.add_child(box)
	box.add_child(_label(title.to_upper(),15,UI.GOLD))
	return box

func _row(left: String, right: String, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	var a := _label(left,14,UI.IVORY); a.size_flags_horizontal = Control.SIZE_EXPAND_FILL; a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; row.add_child(a)
	var b := _label(right,14,tint); b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; row.add_child(b)
	return row

func _label(text_value: String, size_value: int, tint: Color, centered: bool = false) -> Label:
	var label := Label.new(); label.text = text_value
	label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",tint)
	if centered: label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _choose(continue_on: bool) -> void:
	get_tree().paused = _previous_pause
	decided.emit(continue_on)
	queue_free()
