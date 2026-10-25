extends ColorRect
class_name HearthManagement

## The Hearth menu: a sidebar of four areas (Company, Expeditions, Facilities,
## Records), with Facilities and Records split into sub-pages. Page names stay the
## same as before ("Armory", "Merchants", "Reports"...), so every tavern prop,
## toolbar button, and saved callback still opens the right place.

signal manual_launch(dungeon_id: String, party: Array[String])
signal candidate_requested(candidate_id: String)
signal time_advanced(result: Dictionary)
signal changed
signal closed
signal testing_ground_requested

const THEME = preload("res://scripts/ui/tavern_ui_theme.gd")
const SECTIONS = ["Company","Training","Lodgings","Expeditions","Bounties","Facilities","Armory","Merchants","Calendar","Reports","Best Times","Unlocks"]
const GROUPS = [
	{"id":"Company","label":"Company","icon":"roster","pages":["Company","Training","Lodgings"]},
	{"id":"Expeditions","label":"Expeditions","icon":"expedition","pages":["Expeditions","Bounties"]},
	{"id":"Facilities","label":"Facilities","icon":"hearth","pages":["Facilities","Armory","Merchants"]},
	{"id":"Records","label":"Records","icon":"ledger","pages":["Calendar","Reports","Best Times","Unlocks"]},
]
const PAGES = {
	"Company":{"title":"Company","tab":"Roster","icon":"roster","hint":"Your adventurers and anyone waiting to sign on. Adventurers share 20% of the gold each expedition brings home."},
	"Training":{"title":"Training Yard","tab":"Training","icon":"armory","hint":"Spend gold to drill one attribute per adventurer each day. Good rooms and the right furnishings make it likelier to stick."},
	"Lodgings":{"title":"Lodgings","tab":"Lodgings","icon":"hearth","hint":"Every adventurer needs a room. Build more, make them finer, and furnish them to suit the people who sleep there."},
	"Expeditions":{"title":"Expeditions","tab":"Expeditions","icon":"expedition","hint":"Choose a dungeon, pick a party, and lead them yourself or dispatch them."},
	"Facilities":{"title":"Improvements","tab":"Improvements","icon":"hearth","hint":"Expand the Hearth and commission new facilities. Construction takes days to finish."},
	"Armory":{"title":"Armory","tab":"Armory","icon":"armory","hint":"Outfit each adventurer. Every item has one wearer, and gear stays with the Hearth when someone retires."},
	"Merchants":{"title":"Suppliers","tab":"Suppliers","icon":"merchants","hint":"Buy travel supplies, provisions, and equipment. Everything goes straight into storage."},
	"Calendar":{"title":"Calendar","tab":"Calendar","icon":"calendar","hint":"What has happened at the Hearth, and what is coming."},
	"Reports":{"title":"Expedition Reports","tab":"Reports","icon":"ledger","hint":"Every return: gold, losses, and what was recovered."},
	"Bounties":{"title":"Bounty Board","tab":"Bounties","icon":"ledger","hint":"Contracts posted at the Hearth. Meet one on an expedition and get home alive to collect. Unfinished bounties come down after a few days."},
	"Unlocks":{"title":"Unlocks","tab":"Unlocks","icon":"ledger","hint":"Goals that permanently add new relics to the drop pool, raise drop luck, or put more bounties on the board."},
	"Best Times":{"title":"Best Times","tab":"Best Times","icon":"ledger","hint":"Dungeons are never finished. Each guardian you defeat sets a clear time: beat the record, and the best for every class."},
}
const RARITY_COLORS = {"common":Color("ead9b8"),"uncommon":Color("8fd48a"),"rare":Color("7fb4ee"),"epic":Color("c79af0"),"legendary":Color("f0a24f")}
const CARD_FILL = Color("2b1e15")
const CARD_BORDER = Color("5d4428")
const SIDEBAR_FILL = Color("170f0a")
const GOOD = Color("8fd48a")
const BAD = Color("e07a62")

@export var initial_section: String = "Company"
var campaign: CampaignState
var state: RunState
var section: String = "Company"
var member_id: String = ""
var selected_party: Array[String] = []
var dungeon_id: String = "forest"
var policy: String = "balanced"
var slot_filter: String = "all"
var title_label: Label
var hint_label: Label
var hearth_name_label: Label
var bank_label: Label
var notice: Label
var notice_panel: PanelContainer
var body: VBoxContainer
var tabs: HBoxContainer
var resource_row: HBoxContainer
var nav_buttons: Dictionary = {}
var last_page_in_group: Dictionary = {}
var advance_button: Button
var next_event_button: Button
var testing_ground_button: Button

func _ready() -> void:
	color = Color(0.015,0.012,0.009,0.94)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,32)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,18)
	add_child(margin)
	var shell := PanelContainer.new()
	var shell_style := THEME.panel(Color("21160f"),Color("8c5a26"),8,2)
	shell_style.set_content_margin_all(0)
	shell.add_theme_stylebox_override("panel",shell_style)
	margin.add_child(shell)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",0)
	shell.add_child(columns)
	_build_sidebar(columns)
	_build_main(columns)
	section = initial_section
	hide()

func _build_sidebar(parent: HBoxContainer) -> void:
	var sidebar := PanelContainer.new()
	var style := THEME.panel(SIDEBAR_FILL,Color("3d2b1b"),8,0)
	style.set_content_margin_all(16)
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_right = 0
	sidebar.add_theme_stylebox_override("panel",style)
	sidebar.custom_minimum_size = Vector2(232,0)
	parent.add_child(sidebar)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	sidebar.add_child(stack)
	var crest := HBoxContainer.new()
	crest.add_theme_constant_override("separation",10)
	stack.add_child(crest)
	var crest_icon := TextureRect.new()
	crest_icon.texture = THEME.icon("hearth")
	crest_icon.custom_minimum_size = Vector2(34,34)
	crest_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.add_child(crest_icon)
	hearth_name_label = label("The Hearth",20,THEME.HIGHLIGHT_GOLD)
	hearth_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hearth_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crest.add_child(hearth_name_label)
	bank_label = label("",14,THEME.MUTED)
	bank_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(bank_label)
	stack.add_child(_spacer(10))
	for group in GROUPS:
		var nav := Button.new()
		nav.name = "%sNav" % group.id
		nav.text = "  " + String(group.label)
		nav.icon = THEME.icon(String(group.icon))
		nav.expand_icon = true
		nav.alignment = HORIZONTAL_ALIGNMENT_LEFT
		nav.pressed.connect(func(): show_section(String(last_page_in_group.get(group.id,group.pages[0]))))
		stack.add_child(nav)
		nav_buttons[group.id] = nav
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(filler)
	stack.add_child(label("TIME",12,THEME.GOLD))
	advance_button = _sidebar_button(stack,"Advance to Late Shift",_advance_time.bind(false),true)
	advance_button.name = "AdvanceShiftButton"
	advance_button.tooltip_text = "Move time forward. Parties return, construction progresses, and new adventurers may arrive."
	next_event_button = _sidebar_button(stack,"Advance to Next Event",_advance_time.bind(true))
	next_event_button.name = "AdvanceNextEventButton"
	next_event_button.hide()
	stack.add_child(_spacer(4))
	_sidebar_button(stack,"Return to Tavern",func(): hide(); closed.emit())

func _build_main(parent: HBoxContainer) -> void:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,22)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	parent.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	margin.add_child(stack)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",16)
	stack.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation",2)
	header.add_child(titles)
	title_label = label("COMPANY",28,THEME.IVORY)
	titles.add_child(title_label)
	hint_label = label("",14,THEME.MUTED)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(hint_label)
	resource_row = HBoxContainer.new()
	resource_row.add_theme_constant_override("separation",6)
	resource_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(resource_row)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation",6)
	stack.add_child(tab_row)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation",6)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_row.add_child(tabs)
	testing_ground_button = button(tab_row,"Enter testing ground",func(): testing_ground_requested.emit())
	testing_ground_button.name = "OpenTestingGround"
	testing_ground_button.tooltip_text = "Try every class, weapon, item, and relic with free build swapping. Your campaign is preserved."
	testing_ground_button.custom_minimum_size = Vector2(190,36)
	testing_ground_button.hide()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	notice_panel = PanelContainer.new()
	notice_panel.add_theme_stylebox_override("panel",THEME.panel(Color("34261a"),THEME.GOLD,5,1))
	notice_panel.hide()
	stack.add_child(notice_panel)
	notice = label("",15,THEME.IVORY)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_panel.add_child(notice)

func open(c: CampaignState, runtime: RunState, page: String = "Company") -> void:
	campaign = c
	state = runtime
	show()
	show_section(page)

func show_section(page: String) -> void:
	section = page if PAGES.has(page) else "Company"
	last_page_in_group[_group_of(section)] = section
	_set_notice("")
	refresh()

func _group_of(page: String) -> String:
	for group in GROUPS:
		if Array(group.pages).has(page): return String(group.id)
	return "Company"

func refresh() -> void:
	if campaign == null or body == null: return
	# A number of controls refresh this page from their own pressed/toggled signal.
	# Destroying the emitting control synchronously is a native use-after-free in
	# Godot 4.7, so detach it now and defer destruction until the frame is safe.
	for container in [body,tabs,resource_row]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	var info: Dictionary = PAGES[section]
	title_label.text = String(info.title)
	hint_label.text = String(info.hint)
	var group_id := _group_of(section)
	for group in GROUPS:
		var nav: Button = nav_buttons[group.id]
		THEME.apply_button(nav,group.id == group_id,16,Vector2(200,50))
		nav.add_theme_constant_override("icon_max_width",26)
	for group in GROUPS:
		if group.id != group_id or Array(group.pages).size() < 2: continue
		for page in group.pages:
			var tab := Button.new()
			tab.text = String(PAGES[page].tab)
			tab.icon = THEME.icon(String(PAGES[page].icon))
			tab.expand_icon = true
			THEME.apply_button(tab,page == section,14,Vector2(140,36))
			tab.add_theme_constant_override("icon_max_width",20)
			tab.pressed.connect(show_section.bind(page))
			tabs.add_child(tab)
	testing_ground_button.visible = section == "Armory"
	testing_ground_button.disabled = campaign.expedition.active
	advance_button.text = "Advance to Late Shift" if campaign.calendar_shift == 0 else "End Day"
	advance_button.disabled = campaign.expedition.active or not campaign.first_company_recruited or not campaign.pending_story_event_id.is_empty() or not campaign.ending_state.is_empty()
	next_event_button.visible = HearthCalendar.can_advance_to_next_event(campaign)
	next_event_button.disabled = advance_button.disabled
	var date := campaign.get_calendar_date()
	hearth_name_label.text = String(HearthCatalog.tier(campaign.establishment_tier).name)
	bank_label.text = "Day %d · %s\n%s · %s %d" % [campaign.calendar_day,HearthCalendar.shift_name(campaign),String(date.weekday),String(date.season),int(date.season_day)]
	_resource("Gold","%d" % campaign.banked_gold,"Banked gold for wages, gear, and construction.")
	_resource("Supplies","%d" % campaign.supplies,"Each expedition consumes travel supplies. Buy more from Suppliers.")
	_resource("Essence","%d" % campaign.relic_essence,"Recovered from dungeons. Spent on major improvements.")
	_resource("Renown","%d" % campaign.reputation,"Reputation draws stronger recruits and unlocks facilities.")
	_resource("Rooms","%d/%d" % [campaign.living_roster().size(),campaign.get_roster_capacity()],"Adventurers housed out of rooms available.")
	match section:
		"Company": company_page()
		"Armory": armory_page()
		"Training": training_page()
		"Lodgings": lodgings_page()
		"Expeditions": expedition_page()
		"Facilities": facilities_page()
		"Merchants": merchant_page()
		"Reports": reports_page()
		"Best Times": best_times_page()
		"Bounties": bounties_page()
		"Unlocks": unlocks_page()
		"Calendar":
			var calendar := preload("res://scripts/ui/hearth_calendar_view.gd").new()
			calendar.custom_minimum_size = Vector2(0,430)
			body.add_child(calendar)
			calendar.open(campaign)

# ---------------------------------------------------------------- building blocks

func label(text_value: String, size: int = 16, tint: Color = Color("ead9b8")) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",tint)
	return result

func button(parent: Node, text_value: String, callback: Callable, enabled: bool = true) -> Button:
	var result := Button.new()
	result.text = text_value
	result.disabled = not enabled
	THEME.apply_button(result,false,14,Vector2(110,38))
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func _primary_button(parent: Node, text_value: String, callback: Callable, enabled: bool = true) -> Button:
	var result := button(parent,text_value,callback,enabled)
	THEME.apply_button(result,true,15,Vector2(160,42))
	return result

func _sidebar_button(parent: Node, text_value: String, callback: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = text_value
	result.pressed.connect(callback)
	THEME.apply_button(result,primary,14,Vector2(200,42))
	parent.add_child(result)
	return result

func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0,height)
	return spacer

func _resource(caption: String, value: String, tooltip: String) -> void:
	var tile := PanelContainer.new()
	var style := THEME.panel(Color("2a1c12"),Color("5a4129"),5,1)
	style.set_content_margin(SIDE_LEFT,10); style.set_content_margin(SIDE_RIGHT,10); style.set_content_margin(SIDE_TOP,4); style.set_content_margin(SIDE_BOTTOM,4)
	tile.add_theme_stylebox_override("panel",style)
	tile.tooltip_text = tooltip
	tile.custom_minimum_size = Vector2(72,0)
	resource_row.add_child(tile)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(stack)
	var caption_label := label(caption.to_upper(),11,THEME.MUTED)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(caption_label)
	var value_label := label(value,18,THEME.HIGHLIGHT_GOLD)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(value_label)

func _heading(title: String, note: String = "", parent: Node = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	var title_node := label(title.to_upper(),14,THEME.GOLD)
	title_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_node)
	if not note.is_empty(): row.add_child(label(note,13,THEME.MUTED))
	(parent if parent != null else body).add_child(row)
	return row

func _panel(parent: Node, fill: Color = CARD_FILL, border: Color = CARD_BORDER, padding: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := THEME.panel(fill,border,6,1)
	style.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	return panel

## A titled card. Returns its content box so callers can add rows and buttons.
func card(title: String, description: String, parent: Node = null, accent: Color = THEME.GOLD) -> VBoxContainer:
	var panel := _panel(parent if parent != null else body)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",6)
	panel.add_child(content)
	var title_node := label(title,17,accent)
	title_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title_node)
	if not description.is_empty():
		var copy := label(description,14,THEME.IVORY)
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(copy)
	return content

func _grid(columns: int, parent: Node = null) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(parent if parent != null else body).add_child(grid)
	return grid

func _empty_state(title: String, description: String) -> void:
	var panel := _panel(body,Color("241910"),Color("3d2b1b"),24)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(content)
	var title_node := label(title,18,THEME.IVORY)
	title_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_node)
	var copy := label(description,14,THEME.MUTED)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(copy)

func _chip(text_value: String, tint: Color, tooltip: String = "") -> PanelContainer:
	var chip := PanelContainer.new()
	var style := THEME.panel(Color(tint,0.14),Color(tint,0.7),10,1)
	style.set_content_margin(SIDE_LEFT,9); style.set_content_margin(SIDE_RIGHT,9); style.set_content_margin(SIDE_TOP,2); style.set_content_margin(SIDE_BOTTOM,2)
	chip.add_theme_stylebox_override("panel",style)
	chip.tooltip_text = tooltip
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(label(text_value,13,tint))
	return chip

func _set_notice(text_value: String, ok: bool = true) -> void:
	if notice == null: return
	notice.text = text_value
	notice.add_theme_color_override("font_color",THEME.IVORY if ok else Color("f0a08f"))
	notice_panel.visible = not text_value.is_empty()

func act(result: Dictionary) -> void:
	var ok: bool = result.get("ok",false)
	var message := String(result.get("message",result.get("error","Updated.")))
	if ok:
		state.gold = campaign.banked_gold
		state.sync_campaign_runtime()
		# Management mutations use the same atomic commit path as floor entry. Keep
		# the call indirect here so UI cannot accidentally create a second save policy.
		if state != null and not bool(state.call("autosave_on_floor_entry")): message += " Save failed: "+campaign.last_save_error
		changed.emit()
	refresh()
	_set_notice(message,ok)

func _advance_time(skip: bool) -> void:
	var result := HearthCalendar.advance_to_next_event(campaign) if skip else HearthCalendar.advance_shift(campaign)
	if result.get("reset",false):
		state = RunState.new()
		state.attach_campaign(campaign)
	act(result)
	if result.get("ok",false): time_advanced.emit(result)

func _buy_supplies() -> void:
	if campaign.banked_gold < 8:
		# Relief cannot be converted to gold and only covers a stranded company's next trip.
		if campaign.supplies < 2 and campaign.dispatches.is_empty():
			campaign.supplies = 2
			act({"ok":true,"message":"The town provides two emergency travel supplies."})
		else: act(HearthArmory.fail("Not enough gold."))
		return
	campaign.banked_gold -= 8
	campaign.supplies += 4
	act({"ok":true,"message":"Four supplies delivered."})

# ---------------------------------------------------------------- company

func company_page() -> void:
	var members := campaign.living_roster()
	_heading("Your company","%d of %d rooms filled" % [members.size(),campaign.get_roster_capacity()])
	if members.is_empty(): _empty_state("No one has signed on yet","Meet the arrivals below and choose who to recruit.")
	for member in members: _member_card(member)
	var candidates := campaign.get_candidates()
	_heading("Arrivals","Meet them to learn their strengths before signing")
	if candidates.is_empty(): _empty_state("No one is waiting at the Hearth","New adventurers arrive as time passes.")
	for candidate in candidates: _arrival_card(candidate)

func _card_panel() -> HBoxContainer:
	var panel := _panel(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	panel.add_child(row)
	return row

func _portrait(member: CharacterRecord, size: Vector2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://assets/roster_portraits/%s_%d.png" % [member.class_id,member.portrait_variant]
	if ResourceLoader.exists(path): portrait.texture = load(path)
	else: portrait.texture = THEME.class_icon(member.class_id)
	return portrait

func _status_chip(member: CharacterRecord) -> PanelContainer:
	match member.status:
		"available": return _chip("At the Hearth",GOOD,"Ready for expeditions, training, and retraining.")
		"expedition": return _chip("On expedition",Color("e7b45a"),"Away with a party.")
		"recovering": return _chip("Recovering · Day %d" % member.recovery_until,Color("8fb8e0"),"Back on Day %d." % member.recovery_until)
	return _chip(member.status.capitalize(),THEME.MUTED)

func _member_card(member: CharacterRecord) -> void:
	var row := _card_panel()
	row.add_child(_portrait(member,Vector2(72,96)))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",6)
	row.add_child(info)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation",8)
	info.add_child(title)
	title.add_child(label("%s %s" % [member.display_name,member.family_name],20,THEME.HIGHLIGHT_GOLD))
	title.add_child(_chip(_class_label(member),THEME.GOLD))
	title.add_child(_status_chip(member))
	var facts := PackedStringArray([_build_name(member),member.trait_name,"Age %d" % member.age_on(campaign.calendar_day),"%d victories" % member.victories,(VisitorContestRules.learning_name(member.learning_potential) if member.learning_potential_known else "Learning pace unknown")])
	var facts_label := label("  ·  ".join(facts),14,THEME.IVORY)
	facts_label.tooltip_text = "%s: %s\n%s: %s" % [_build_name(member),String(AdventurerBuilds.build(member.stat_build_id).get("description","")),member.trait_name,member.trait_description]
	facts_label.mouse_filter = Control.MOUSE_FILTER_PASS
	facts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts_label.custom_minimum_size = Vector2(200,0)
	info.add_child(facts_label)
	info.add_child(_health_bar(member))
	var stats := AdventurerStatGrid.new(true)
	stats.show_attributes(member.attributes)
	info.add_child(stats)
	var story := label(member.biography,13,THEME.MUTED)
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.max_lines_visible = 2
	story.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	story.tooltip_text = member.biography
	story.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(story)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(360,0)
	side.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.add_theme_constant_override("separation",8)
	row.add_child(side)
	_add_class_assignment(side,member)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",6)
	side.add_child(actions)
	var available := member.status == "available"
	var equipment := button(actions,"Outfit",func(): member_id=member.id; show_section("Armory"))
	equipment.tooltip_text = "Open the Armory for this adventurer."
	var drill := button(actions,"Train",func(): member_id=member.id; show_section("Training"))
	drill.tooltip_text = "Open the Training Yard for this adventurer." if not HearthLodging.trained_today(campaign,member) else "Already trained today."
	var small_buttons: Array[Button] = [equipment,drill]
	if GameBalance.leveling_enabled():
		var train := button(actions,"Train · %dg" % (15*member.level),func(): act(HearthFacilities.train(campaign,member.id)),available)
		train.tooltip_text = "Pay to train them up a level. They spend two days recovering."
		small_buttons.append(train)
	small_buttons.append(button(actions,"Retire",_confirm_retire.bind(member.id),available))
	for small in small_buttons: small.custom_minimum_size = Vector2(86,36)

func _health_bar(member: CharacterRecord, width: int = 180) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	row.add_child(label("Health",13,THEME.MUTED))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width,12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = maxi(1,member.max_health)
	bar.value = clampi(member.current_health,0,member.max_health)
	var fill := StyleBoxFlat.new()
	var ratio := float(member.current_health) / float(maxi(1,member.max_health))
	fill.bg_color = Color("7fc46f") if ratio > 0.6 else (Color("e0b452") if ratio > 0.3 else Color("df6a52"))
	fill.set_corner_radius_all(3)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("120c08")
	track.border_color = Color("4a3522")
	track.set_border_width_all(1)
	track.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill",fill)
	bar.add_theme_stylebox_override("background",track)
	row.add_child(bar)
	row.add_child(label("%d / %d" % [member.current_health,member.max_health],13,THEME.IVORY))
	return row

func _arrival_card(candidate: CandidateRecord) -> void:
	var member := candidate.adventurer
	var row := _card_panel()
	row.add_child(_portrait(member,Vector2(60,70)))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation",4)
	row.add_child(info)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation",8)
	info.add_child(title)
	title.add_child(label("%s %s" % [member.display_name,member.family_name],18,THEME.HIGHLIGHT_GOLD))
	if not member.stat_build_id.is_empty(): title.add_child(_chip(_build_name(member),THEME.GOLD,String(AdventurerBuilds.build(member.stat_build_id).get("description",""))))
	title.add_child(_chip("Hopes to be a %s" % member.calling_class_id.capitalize(),THEME.IVORY,"Their calling. You choose their class when you sign them."))
	var quote := label("“%s”" % candidate.motivation,14,THEME.MUTED)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote.max_lines_visible = 2
	quote.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(quote)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(side)
	side.add_child(label("Signing fee %dg" % member.signing_fee if member.signing_fee > 0 else "No signing fee",14,THEME.GOLD))
	button(side,"Meet and assess",func(): hide(); candidate_requested.emit(candidate.id))

func _class_label(member: CharacterRecord) -> String:
	return "%s · Level %d" % [member.class_id.capitalize(),member.level] if GameBalance.leveling_enabled() else member.class_id.capitalize()

func _build_name(member: CharacterRecord) -> String:
	return AdventurerBuilds.build_name(member.stat_build_id) if not member.stat_build_id.is_empty() else "Adventurer"

## Lets the keeper move an adventurer into any unlocked class while they are home.
func _add_class_assignment(parent: VBoxContainer, member: CharacterRecord) -> void:
	var grade := AdventurerBuilds.class_fit(member.attributes,member.class_id)
	parent.add_child(label("%s fit as %s" % [grade,member.class_id.capitalize()],15,AdventurerStatGrid.FIT_COLORS.get(grade,THEME.IVORY)))
	parent.add_child(label("★ Their calling" if member.calling_class_id == member.class_id else "★ Hoped to be a %s" % member.calling_class_id.capitalize(),13,THEME.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	parent.add_child(row)
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(200,36)
	picker.fit_to_longest_item = false
	picker.clip_text = true
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.tooltip_text = "Classes you have unlocked, best fit first."
	for class_id in AdventurerBuilds.ranked_classes(member.attributes,campaign.unlocked_classes):
		var text_value := "%s — %s" % [class_id.capitalize(),AdventurerBuilds.class_fit(member.attributes,class_id)]
		if class_id == member.calling_class_id: text_value += "  ★"
		picker.add_item(text_value)
		picker.set_item_metadata(picker.item_count-1,class_id)
		var icon := THEME.class_icon(class_id)
		if icon != null: picker.set_item_icon(picker.item_count-1,icon)
		if class_id == member.class_id: picker.select(picker.item_count-1)
	picker.add_theme_constant_override("icon_max_width",22)
	picker.disabled = member.status != "available"
	row.add_child(picker)
	var retrain := button(row,"Retrain",func(): _retrain(member.id,String(picker.get_selected_metadata())),false)
	retrain.custom_minimum_size = Vector2(88,36)
	picker.item_selected.connect(func(index: int): retrain.disabled = member.status != "available" or String(picker.get_item_metadata(index)) == member.class_id)
	retrain.tooltip_text = "Keeps level and attributes. Class upgrade choices are picked again, and gear the new class cannot use returns to the armory."

func _retrain(id: String, class_id: String) -> void:
	var member := campaign.character(id)
	if member == null: return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Retrain %s as a %s?\nLevel and attributes stay. Class upgrade choices will be picked again, and starter gear is swapped for the new class." % [member.display_name,class_id.capitalize()]
	dialog.confirmed.connect(func():
		var result := campaign.reassign_class(id,class_id)
		if result.get("ok",false) and state != null: state.hero_profiles.erase(id)
		act(result)
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_retire(id: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Retire this adventurer permanently? Their equipment returns to the armory."
	dialog.confirmed.connect(func(): act(HearthCalendar.retire(campaign,campaign.character(id))); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

# ---------------------------------------------------------------- armory

## A row of adventurer tabs for choosing who to outfit. Returns the selected one.
func member_picker() -> CharacterRecord:
	var members := campaign.living_roster()
	if members.is_empty():
		_empty_state("An empty company","Recruit an adventurer before assigning equipment.")
		return null
	if campaign.character(member_id)==null or campaign.character(member_id).status=="dead": member_id=members[0].id
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation",6)
	row.add_theme_constant_override("v_separation",6)
	body.add_child(row)
	for member in members:
		var choice := Button.new()
		choice.text = "%s · %s" % [member.display_name,member.class_id.capitalize()]
		choice.icon = THEME.class_icon(member.class_id)
		choice.expand_icon = true
		THEME.apply_button(choice,member.id == member_id,14,Vector2(150,40))
		choice.add_theme_constant_override("icon_max_width",22)
		if member.status != "available": choice.tooltip_text = "Away. Their loadout is locked until they return."
		choice.pressed.connect(func(): member_id=member.id; refresh())
		row.add_child(choice)
	return campaign.character(member_id)

func armory_page() -> void:
	var member := member_picker()
	if member == null: return
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",16)
	body.add_child(columns)
	var loadout_column := VBoxContainer.new()
	loadout_column.custom_minimum_size.x = 320
	loadout_column.add_theme_constant_override("separation",10)
	columns.add_child(loadout_column)
	var storage_column := VBoxContainer.new()
	storage_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storage_column.add_theme_constant_override("separation",10)
	columns.add_child(storage_column)
	var locked := member.status != "available"
	# Loadout: who is being outfitted and what they wear.
	var summary := _panel(loadout_column)
	var summary_row := HBoxContainer.new()
	summary_row.add_theme_constant_override("separation",12)
	summary.add_child(summary_row)
	summary_row.add_child(_portrait(member,Vector2(64,76)))
	var summary_info := VBoxContainer.new()
	summary_row.add_child(summary_info)
	summary_info.add_child(label("%s %s" % [member.display_name,member.family_name],18,THEME.HIGHLIGHT_GOLD))
	summary_info.add_child(label(_class_label(member),14,THEME.IVORY))
	summary_info.add_child(_health_bar(member,110))
	if locked: summary_info.add_child(label("Away · loadout locked",13,Color("e7b45a")))
	_heading("Loadout","",loadout_column)
	for slot in ["weapon","armor","accessory","relic"]:
		var id: String = member.equipment.get(slot,"")
		var entry := HearthCatalog.item(String(Dictionary(campaign.armory.get(id,{})).get("item_id","")))
		var slot_panel := _panel(loadout_column,Color("241910"),Color("4a3522"),10)
		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation",8)
		slot_panel.add_child(slot_row)
		var text_box := VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_box.add_theme_constant_override("separation",0)
		slot_row.add_child(text_box)
		text_box.add_child(label(slot.to_upper(),11,THEME.MUTED))
		text_box.add_child(label(String(entry.get("name","Empty")),15,RARITY_COLORS.get(String(entry.get("rarity","common")),THEME.IVORY) if not entry.is_empty() else Color("7d6f5c")))
		var unassign := button(slot_row,"Remove",func(): act(HearthArmory.unequip(campaign,member.id,slot)),not id.is_empty() and not locked)
		unassign.custom_minimum_size = Vector2(80,32)
	_heading("Provisions","%d / 4" % member.provisions.size(),loadout_column)
	var provision_panel := _panel(loadout_column,Color("241910"),Color("4a3522"),10)
	var provision_box := VBoxContainer.new()
	provision_box.add_theme_constant_override("separation",6)
	provision_panel.add_child(provision_box)
	var carried := PackedStringArray()
	for id in member.provisions: carried.append(String(GameBalance.get_consumable(id).get("name",String(id).replace("_"," ").capitalize())))
	var carried_label := label(", ".join(carried) if not carried.is_empty() else "Nothing packed yet.",14,THEME.IVORY if not carried.is_empty() else THEME.MUTED)
	carried_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	provision_box.add_child(carried_label)
	for id in campaign.consumable_stock:
		if int(campaign.consumable_stock[id]) <= 0: continue
		var pack := button(provision_box,"Pack %s · %d stored" % [String(GameBalance.get_consumable(id).get("name",String(id).replace("_"," ").capitalize())),campaign.consumable_stock[id]],func(): act(HearthArmory.provision(campaign,member.id,id)),not locked and member.provisions.size() < 4)
		pack.custom_minimum_size = Vector2(0,34)
	# Storage: items this class can use.
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation",6)
	storage_column.add_child(filters)
	var storage_title := label("STORAGE",14,THEME.GOLD)
	storage_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(storage_title)
	for slot in ["all","weapon","armor","accessory","relic"]:
		var filter := Button.new()
		filter.text = slot.capitalize()
		THEME.apply_button(filter,slot == slot_filter,13,Vector2(74,32))
		filter.pressed.connect(func(): slot_filter=slot; refresh())
		filters.add_child(filter)
	var grid := _grid(2,storage_column)
	var shown := 0
	for id in campaign.armory:
		var instance: Dictionary = campaign.armory[id]
		var entry := HearthCatalog.item(instance.item_id)
		if slot_filter!="all" and entry.slot!=slot_filter: continue
		if entry.get("class_id",member.class_id)!=member.class_id: continue
		shown += 1
		_item_card(grid,member,String(id),instance,entry,locked)
	if shown == 0:
		var empty := label("Nothing in storage fits a %s%s. Suppliers and expeditions bring in more." % [member.class_id.capitalize()," in this slot" if slot_filter != "all" else ""],14,THEME.MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		storage_column.add_child(empty)

func _item_card(parent: Node, member: CharacterRecord, id: String, instance: Dictionary, entry: Dictionary, locked: bool) -> void:
	var owner := campaign.character(String(instance.owner))
	var worn_here := owner != null and owner.id == member.id
	var panel := _panel(parent,Color("2f2117") if worn_here else CARD_FILL,THEME.GOLD if worn_here else CARD_BORDER,10)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",4)
	panel.add_child(content)
	var rarity := String(entry.get("rarity","common"))
	content.add_child(label(String(entry.name),16,RARITY_COLORS.get(rarity,THEME.IVORY)))
	content.add_child(label("%s · %s" % [String(entry.slot).capitalize(),rarity.capitalize()],12,THEME.MUTED))
	var description := label(String(entry.description),13,THEME.IVORY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	if not worn_here:
		var equipped: Dictionary = campaign.armory.get(member.equipment.get(entry.slot,""),{})
		var previous := HearthCatalog.item(String(equipped.get("item_id","")))
		var deltas := HFlowContainer.new()
		deltas.add_theme_constant_override("h_separation",6)
		content.add_child(deltas)
		var keys: Dictionary = Dictionary(entry.modifiers).duplicate()
		keys.merge(Dictionary(previous.get("modifiers",{})))
		for stat in keys:
			var delta := float(entry.modifiers.get(stat,0))-float(Dictionary(previous.get("modifiers",{})).get(stat,0))
			if is_zero_approx(delta): continue
			deltas.add_child(label("%s %+.1f" % [String(stat).replace("_"," "),delta],12,GOOD if delta > 0 else BAD))
		if entry.slot=="weapon":
			var damage := int(entry.damage)-int(previous.get("damage",0))
			if damage != 0: deltas.add_child(label("damage %+d" % damage,12,GOOD if damage > 0 else BAD))
		if deltas.get_child_count() == 0 and not previous.is_empty(): deltas.add_child(label("Same as equipped",12,THEME.MUTED))
	content.add_child(label("Worn by %s" % owner.display_name if owner != null else "In storage",12,THEME.GOLD if worn_here else THEME.MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",6)
	content.add_child(actions)
	var equip := button(actions,"Equip",func(): act(HearthArmory.equip(campaign,member.id,id)),owner==null and not locked)
	equip.custom_minimum_size = Vector2(90,32)
	var sell := button(actions,"Sell · %dg" % int(entry.price/3),func(): act(HearthArmory.sell(campaign,id)),owner==null and not instance.bound)
	sell.custom_minimum_size = Vector2(90,32)
	if instance.bound: sell.tooltip_text = "Starter equipment cannot be sold."

# ---------------------------------------------------------------- training

const STAT_NAMES := {"str":"Strength","dex":"Dexterity","con":"Constitution","int":"Intelligence","wis":"Wisdom","cha":"Charisma"}

func training_page() -> void:
	var members := campaign.living_roster()
	var ready_count := members.filter(func(m: CharacterRecord): return m.status == "available" and not HearthLodging.trained_today(campaign,m)).size()
	_heading("Today's training","%d of %d ready to train · Day %d" % [ready_count,members.size(),campaign.calendar_day])
	var member := member_picker()
	if member == null: return
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",12)
	body.add_child(columns)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	left.add_theme_constant_override("separation",10)
	columns.add_child(left)
	var summary := _panel(left)
	var summary_box := VBoxContainer.new()
	summary_box.add_theme_constant_override("separation",6)
	summary.add_child(summary_box)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation",12)
	summary_box.add_child(top)
	top.add_child(_portrait(member,Vector2(72,88)))
	var who := VBoxContainer.new()
	top.add_child(who)
	who.add_child(label("%s %s" % [member.display_name,member.family_name],18,THEME.HIGHLIGHT_GOLD))
	who.add_child(label("%s · %s" % [member.class_id.capitalize(),_build_name(member)],14,THEME.IVORY))
	var grade := AdventurerBuilds.class_fit(member.attributes,member.class_id)
	who.add_child(label("%s fit" % grade,13,AdventurerStatGrid.FIT_COLORS.get(grade,THEME.IVORY)))
	var room := HearthLodging.room_of(campaign,member.id)
	var room_text := "No room yet" if room.is_empty() else "%s · %s" % [HearthLodging.room_label(campaign,room),String(HearthLodging.quality(String(room.quality)).name)]
	summary_box.add_child(label(room_text,13,THEME.MUTED))
	var furnished := PackedStringArray()
	for furnishing_id in Array(room.get("furnishings",[])): furnished.append(String(HearthLodging.furnishing(String(furnishing_id)).get("name",furnishing_id)))
	var furnished_label := label("Furnishings: " + (", ".join(furnished) if not furnished.is_empty() else "none yet"),13,THEME.IVORY if not furnished.is_empty() else THEME.MUTED)
	furnished_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_box.add_child(furnished_label)
	var to_lodgings := button(summary_box,"Furnish their room",func(): show_section("Lodgings"))
	to_lodgings.custom_minimum_size = Vector2(0,34)
	var gains: Dictionary = Dictionary(member.training.get("gains",{}))
	var gained := PackedStringArray()
	for stat in HearthLodging.ATTRIBUTE_IDS:
		if int(gains.get(stat,0)) > 0: gained.append("%s +%d" % [stat.to_upper(),int(gains[stat])])
	card("Progress at the Hearth","%d sessions so far.%s" % [int(member.training.get("sessions",0)),("\nTrained up: " + ", ".join(gained)) if not gained.is_empty() else ""],left)
	var state_text := ""
	if member.status != "available": state_text = "%s is away and cannot train until they return." % member.display_name
	elif HearthLodging.trained_today(campaign,member): state_text = "%s has trained today. They can train again tomorrow." % member.display_name
	var drills := VBoxContainer.new()
	drills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drills.add_theme_constant_override("separation",6)
	columns.add_child(drills)
	var header := HBoxContainer.new()
	drills.add_child(header)
	var header_title := label("DRILLS",14,THEME.GOLD)
	header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_title)
	header.add_child(label("Cap %d · costs gold win or lose" % int(HearthLodging.training_rules().get("stat_cap",18)),13,THEME.MUTED))
	if not state_text.is_empty():
		var rested := _panel(drills,Color("2a2316"),Color("6b5a2c"),10)
		rested.add_child(label(state_text,14,Color("f0d79a")))
	var cap := int(HearthLodging.training_rules().get("stat_cap",18))
	var weights := AdventurerBuilds.class_weights(member.class_id)
	for stat in HearthLodging.ATTRIBUTE_IDS:
		var value := int(member.attributes.get(stat,10))
		var row_panel := _panel(drills,Color("241910"),Color("4a3522"),10)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		row_panel.add_child(row)
		var name_box := VBoxContainer.new()
		name_box.custom_minimum_size.x = 120
		name_box.add_theme_constant_override("separation",0)
		row.add_child(name_box)
		name_box.add_child(label(String(STAT_NAMES[stat]),16,THEME.IVORY))
		name_box.add_child(label("Key for %s" % member.class_id.capitalize() if int(weights.get(stat,0)) >= 4 else " ",11,Color("9fe08a")))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(100,12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.min_value = 4; bar.max_value = 20; bar.value = value
		var fill := StyleBoxFlat.new(); fill.bg_color = THEME.GOLD; fill.set_corner_radius_all(3)
		var track := StyleBoxFlat.new(); track.bg_color = Color("120c08"); track.border_color = Color("4a3522"); track.set_border_width_all(1); track.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill",fill); bar.add_theme_stylebox_override("background",track)
		row.add_child(bar)
		var value_label := label(str(value),18,THEME.HIGHLIGHT_GOLD)
		value_label.custom_minimum_size.x = 30
		row.add_child(value_label)
		var odds := VBoxContainer.new()
		odds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		odds.add_theme_constant_override("separation",0)
		row.add_child(odds)
		if value >= cap:
			odds.add_child(label("Mastered for now",14,THEME.MUTED))
		else:
			var chance := HearthLodging.training_chance(campaign,member,stat)
			var percent := int(chance.chance)
			odds.add_child(label("%d%% chance of +1" % percent,14,GOOD if percent >= 60 else (Color("e8cf72") if percent >= 35 else Color("e0a35e"))))
			var parts: Array = chance.parts
			odds.add_child(label(", ".join(parts) if not parts.is_empty() else "No bonuses yet",11,THEME.MUTED))
		var check := HearthLodging.can_train(campaign,member,stat)
		var drill := button(row,"Mastered" if value >= cap else "Train · %dg" % HearthLodging.training_cost(member,stat),func(): act(HearthLodging.train(campaign,member.id,stat)),bool(check.ok))
		drill.custom_minimum_size = Vector2(108,36)
		if not bool(check.ok): drill.tooltip_text = String(check.get("error",""))

# ---------------------------------------------------------------- lodgings

func lodgings_page() -> void:
	HearthLodging.ensure_rooms(campaign)
	HearthLodging.sync_occupants(campaign)
	var limit := HearthLodging.room_limit(campaign)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation",10)
	body.add_child(bar)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	info.add_child(label("%d rooms built · space for %d at the %s" % [campaign.rooms.size(),limit,String(HearthCatalog.tier(campaign.establishment_tier).name)],16,THEME.IVORY))
	info.add_child(label("%d adventurers housed. Expand the Hearth under Facilities for more space." % campaign.living_roster().size(),13,THEME.MUTED))
	var can_build := campaign.rooms.size() < limit
	var build := _primary_button(bar,"Build a room · %dg" % HearthLodging.build_cost(campaign) if can_build else "No space left",func(): act(HearthLodging.build_room(campaign)),can_build and campaign.banked_gold >= HearthLodging.build_cost(campaign))
	build.custom_minimum_size = Vector2(200,42)
	var grid := _grid(2)
	for room in campaign.rooms: _room_card(grid,room)
	if not campaign.furnishing_storage.is_empty():
		_heading("In storage","Free to place in any room with space")
		var stored := HFlowContainer.new()
		stored.add_theme_constant_override("h_separation",6)
		body.add_child(stored)
		for furnishing_id in campaign.furnishing_storage:
			stored.add_child(_chip("%s × %d" % [String(HearthLodging.furnishing(String(furnishing_id)).get("name",furnishing_id)),int(campaign.furnishing_storage[furnishing_id])],THEME.IVORY))

func _room_card(parent: Node, room: Dictionary) -> void:
	var quality := HearthLodging.quality(String(room.quality))
	var occupant := campaign.character(String(room.get("occupant","")))
	var panel := _panel(parent,Color("2f2117") if occupant != null else CARD_FILL,THEME.GOLD if HearthLodging.quality_index(String(room.quality)) >= 2 else CARD_BORDER,12)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",6)
	panel.add_child(content)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation",8)
	content.add_child(title)
	title.add_child(label(HearthLodging.room_label(campaign,room),17,THEME.HIGHLIGHT_GOLD))
	title.add_child(_chip(String(quality.name),THEME.GOLD,String(quality.get("description",""))))
	if int(quality.get("training_bonus",0)) > 0: title.add_child(_chip("Training +%d%%" % int(quality.training_bonus),GOOD,"Everyone who sleeps here trains a little easier."))
	var resident := HBoxContainer.new()
	resident.add_theme_constant_override("separation",10)
	content.add_child(resident)
	if occupant != null:
		resident.add_child(_portrait(occupant,Vector2(44,52)))
		var who := VBoxContainer.new()
		who.add_theme_constant_override("separation",0)
		resident.add_child(who)
		who.add_child(label(occupant.display_name,15,THEME.IVORY))
		who.add_child(label(occupant.class_id.capitalize(),12,THEME.MUTED))
	else:
		resident.add_child(label("Empty · ready for a new recruit",14,THEME.MUTED))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; resident.add_child(spacer)
	var members := campaign.living_roster()
	if not members.is_empty():
		var mover := OptionButton.new()
		mover.custom_minimum_size = Vector2(130,32)
		mover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mover.fit_to_longest_item = false
		mover.add_item("Move in…")
		mover.set_item_disabled(0,true)
		for member in members:
			if occupant != null and member.id == occupant.id: continue
			mover.add_item(member.display_name)
			mover.set_item_metadata(mover.item_count-1,member.id)
		mover.select(0)
		mover.tooltip_text = "Move someone into this room. Whoever lives here swaps with them."
		mover.item_selected.connect(func(index: int): act(HearthLodging.assign_room(campaign,String(room.id),String(mover.get_item_metadata(index)))))
		resident.add_child(mover)
	var suits := HearthLodging.room_suits(room)
	if not suits.is_empty():
		var suited := PackedStringArray()
		for class_id in suits: suited.append(class_id.capitalize())
		var match_text := "Suits " + ", ".join(suited)
		var tint := THEME.MUTED
		if occupant != null and suits.has(occupant.class_id): match_text += " · a good fit for %s" % occupant.display_name; tint = GOOD
		content.add_child(label(match_text,12,tint))
	var placed: Array = Array(room.get("furnishings",[]))
	var slot_row := HFlowContainer.new()
	slot_row.add_theme_constant_override("h_separation",6)
	slot_row.add_theme_constant_override("v_separation",6)
	content.add_child(slot_row)
	for slot_index in HearthLodging.slots(room):
		if slot_index < placed.size():
			var furnishing_id := String(placed[slot_index])
			var item := HearthLodging.furnishing(furnishing_id)
			var chip := Button.new()
			chip.text = "%s  ✕" % String(item.get("name",furnishing_id))
			chip.tooltip_text = "%s\n%s\nClick to move it to storage." % [String(item.get("description","")),_furnishing_bonus_text(item)]
			THEME.apply_button(chip,true,12,Vector2(0,32))
			chip.pressed.connect(func(): act(HearthLodging.remove_furnishing(campaign,String(room.id),slot_index)))
			slot_row.add_child(chip)
		else:
			slot_row.add_child(_furnish_picker(room,occupant))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	content.add_child(footer)
	var next := HearthLodging.next_quality(room)
	if next.is_empty():
		footer.add_child(label("The finest room the Hearth can offer.",12,THEME.MUTED))
	else:
		var locked: bool = int(campaign.establishment_tier) < int(next.get("min_tier",0))
		var upgrade := button(footer,("Upgrade to %s · %dg" % [String(next.name),int(next.upgrade_cost)]) if not locked else "%s needs a bigger Hearth" % String(next.name),func(): act(HearthLodging.upgrade_room(campaign,String(room.id))),not locked and campaign.banked_gold >= int(next.upgrade_cost))
		upgrade.custom_minimum_size = Vector2(0,32)
		upgrade.tooltip_text = "%s\n%d furnishing slots · training +%d%%" % [String(next.get("description","")),int(next.slots),int(next.get("training_bonus",0))]

func _furnish_picker(room: Dictionary, occupant: CharacterRecord) -> OptionButton:
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(170,32)
	picker.fit_to_longest_item = false
	picker.add_item("+ Furnish")
	picker.set_item_disabled(0,true)
	var ids: Array = HearthLodging.furnishings().keys()
	# Furnishings that suit whoever lives here are listed first.
	ids.sort_custom(func(a, b):
		var suits_a := occupant != null and Array(HearthLodging.furnishing(String(a)).suits).has(occupant.class_id)
		var suits_b := occupant != null and Array(HearthLodging.furnishing(String(b)).suits).has(occupant.class_id)
		if suits_a != suits_b: return suits_a
		return int(HearthLodging.furnishing(String(a)).cost) < int(HearthLodging.furnishing(String(b)).cost))
	for furnishing_id in ids:
		var item := HearthLodging.furnishing(String(furnishing_id))
		if not HearthLodging.can_fit(room,String(furnishing_id)): continue
		var stored := int(campaign.furnishing_storage.get(furnishing_id,0))
		var star := "★ " if occupant != null and Array(item.suits).has(occupant.class_id) else ""
		picker.add_item("%s%s · %s" % [star,String(item.name),"stored" if stored > 0 else "%dg" % int(item.cost)])
		picker.set_item_metadata(picker.item_count-1,furnishing_id)
		picker.set_item_tooltip(picker.item_count-1,"%s\n%s" % [String(item.description),_furnishing_bonus_text(item)])
		if stored == 0 and campaign.banked_gold < int(item.cost): picker.set_item_disabled(picker.item_count-1,true)
	picker.select(0)
	picker.tooltip_text = "Buy and place a furnishing. ★ suits whoever lives here."
	picker.item_selected.connect(func(index: int): act(HearthLodging.place_furnishing(campaign,String(room.id),String(picker.get_item_metadata(index)))))
	return picker

func _furnishing_bonus_text(item: Dictionary) -> String:
	var parts := PackedStringArray()
	var stats: Dictionary = Dictionary(item.get("stats",{}))
	for stat in stats: parts.append("%s training +%d%%" % [String(stat).to_upper(),int(stats[stat])])
	var suits := PackedStringArray()
	for class_id in Array(item.get("suits",[])): suits.append(String(class_id).capitalize())
	return ", ".join(parts) + (" · suits " + ", ".join(suits) if not suits.is_empty() else "")

# ---------------------------------------------------------------- expeditions

func expedition_page() -> void:
	var unlocked: Array[String] = []
	for id in HearthCatalog.data().dungeon_levels:
		if state.is_dungeon_unlocked(id): unlocked.append(id)
	if not unlocked.has(dungeon_id): dungeon_id="forest"
	_heading("Destination")
	var destinations := HFlowContainer.new()
	destinations.add_theme_constant_override("h_separation",6)
	destinations.add_theme_constant_override("v_separation",6)
	body.add_child(destinations)
	for id in unlocked:
		var choice := Button.new()
		choice.text = String(GameBalance.get_dungeon(id).get("name",id))
		choice.tooltip_text = "Your company knows the way past its guardian. Parties can be dispatched here." if campaign.has_completed_dungeon(id) else "Lead a party past its guardian yourself before you can dispatch one here."
		THEME.apply_button(choice,id == dungeon_id,14,Vector2(150,40))
		choice.pressed.connect(func(): dungeon_id=id; selected_party.clear(); refresh())
		destinations.add_child(choice)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",14)
	body.add_child(columns)
	var cap := campaign.get_party_cap(dungeon_id)
	selected_party = selected_party.filter(func(id:String): return campaign.character(id)!=null and campaign.character(id).status=="available")
	var party := card("Party · %d / %d" % [selected_party.size(),cap],"Survivors keep their equipment; the fallen lose what they carried.",columns)
	(party.get_parent() as Control).size_flags_stretch_ratio = 1.3
	for member in campaign.living_roster():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",8)
		party.add_child(row)
		var check := CheckBox.new()
		check.text = "%s · %s" % [member.display_name,_class_label(member)]
		check.add_theme_font_size_override("font_size",15)
		_style_check(check)
		check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		check.button_pressed=selected_party.has(member.id)
		check.disabled=member.status!="available"
		check.toggled.connect(func(on:bool):
			if on and selected_party.size()<campaign.get_party_cap(dungeon_id): selected_party.append(member.id)
			elif not on: selected_party.erase(member.id)
			refresh())
		row.add_child(check)
		row.add_child(label("%d/%d HP" % [member.current_health,member.max_health],13,THEME.MUTED))
		if member.status != "available": row.add_child(_status_chip(member))
	var plan := VBoxContainer.new()
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan.add_theme_constant_override("separation",10)
	columns.add_child(plan)
	var risk := HearthExpeditions.risk(campaign,selected_party,dungeon_id)
	var band := String(risk.band)
	var risk_color: Color = {"Low":GOOD,"Moderate":Color("e8cf72"),"High":Color("e0a35e"),"Severe":BAD}.get(band,THEME.GOLD)
	var risk_card := card("%s risk" % band,"",plan,risk_color)
	for reason in risk.reasons:
		var reason_label := label("•  " + String(reason),14,THEME.IVORY)
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		risk_card.add_child(reason_label)
	risk_card.add_child(label("Keeper keeps 80%% of recovered gold · back Day %d, %s" % [campaign.calendar_day+campaign.calendar_shift,"Late Shift" if campaign.calendar_shift == 0 else "Early Shift"],13,THEME.MUTED))
	var times_card := card("Time to beat","",plan)
	var dungeon_record := ClearRecords.best(campaign,dungeon_id)
	if dungeon_record.is_empty():
		times_card.add_child(label("No clear yet. Defeat the guardian to set the first time.",14,THEME.MUTED))
	else:
		times_card.add_child(label("Record  %s  ·  %s (%s)  ·  %d clears" % [ClearRecords.format_time(float(dungeon_record.time)),String(dungeon_record.hero),String(dungeon_record.class_id).capitalize(),ClearRecords.clears(campaign,dungeon_id)],14,THEME.HIGHLIGHT_GOLD))
	var shown_classes: Array[String] = []
	for member_id in selected_party:
		var member := campaign.character(member_id)
		if member == null or shown_classes.has(member.class_id): continue
		shown_classes.append(member.class_id)
		var class_best := ClearRecords.best(campaign,dungeon_id,member.class_id)
		times_card.add_child(label("%s best  %s" % [member.class_id.capitalize(),ClearRecords.format_time(float(class_best.time)) if not class_best.is_empty() else "— not cleared as a %s yet" % member.class_id.capitalize()],14,GOOD if not class_best.is_empty() else THEME.IVORY))
	BountyBoard.refresh(campaign)
	var bounty_card := card("Bounties","Meet one and get home alive to be paid.",plan)
	for bounty in BountyBoard.offers(campaign):
		var line := label("•  %s  (%s)" % [String(bounty.text),BountyBoard.reward_text(bounty.reward)],14,THEME.IVORY)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bounty_card.add_child(line)
	var policy_card := card("Retreat policy","How readily a dispatched party turns back.",plan)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",6)
	policy_card.add_child(controls)
	for value in ["cautious","balanced","bold"]:
		var choice := button(controls,("✓ " if value==policy else "")+value.capitalize(),func(): policy=value; refresh())
		THEME.apply_button(choice,value == policy,14,Vector2(100,36))
	var readiness := HearthExpeditions.readiness(campaign,selected_party,dungeon_id)
	if not readiness.ok: plan.add_child(label(String(readiness.error),14,Color("f0a08f")))
	var launch := HBoxContainer.new()
	launch.add_theme_constant_override("separation",8)
	plan.add_child(launch)
	var lead := _primary_button(launch,"Lead Expedition",func(): hide(); manual_launch.emit(dungeon_id,selected_party.duplicate()),readiness.ok)
	lead.tooltip_text = "Play the expedition yourself."
	var dispatch := button(launch,"Dispatch Party",func(): act(HearthExpeditions.dispatch(campaign,selected_party,dungeon_id,policy)),readiness.ok and campaign.has_completed_dungeon(dungeon_id))
	dispatch.custom_minimum_size = Vector2(150,42)
	dispatch.tooltip_text = "Send them without you. Available once you have led a party past this dungeon's guardian yourself." if not campaign.has_completed_dungeon(dungeon_id) else "Send them without you. They return after one shift."
	if not campaign.dispatches.is_empty():
		_heading("Parties away")
		for value in campaign.dispatches.values():
			card("%s · back Day %d" % [String(GameBalance.get_dungeon(String(value.dungeon_id)).get("name",String(value.dungeon_id).capitalize())),value.due_day],"%s · %s retreat policy" % [("Early Shift" if int(value.get("due_shift_index",-1)) % 2 == 0 else "Late Shift") if int(value.get("due_shift_index",-1)) >= 0 else "Morning",String(value.retreat_policy).capitalize()])

static var _check_icons: Dictionary = {}

## The default check boxes are near-invisible on the walnut panels; draw clear ones.
func _style_check(check: CheckBox) -> void:
	if _check_icons.is_empty():
		for key in ["off","on","off_disabled"]:
			var image := Image.create(20,20,false,Image.FORMAT_RGBA8)
			var border := THEME.GOLD if key != "off_disabled" else Color(THEME.MUTED,0.4)
			for x in 20:
				for y in 20:
					var edge := x < 2 or y < 2 or x > 17 or y > 17
					if edge: image.set_pixel(x,y,border)
					elif key == "on": image.set_pixel(x,y,THEME.GOLD)
					else: image.set_pixel(x,y,Color("120c08"))
			if key == "on":
				for step in range(5): image.set_pixel(5+step,10+step,Color("21160f")); image.set_pixel(5+step,9+step,Color("21160f"))
				for step in range(8): image.set_pixel(9+step,14-step,Color("21160f")); image.set_pixel(9+step,13-step,Color("21160f"))
			_check_icons[key] = ImageTexture.create_from_image(image)
	check.add_theme_icon_override("unchecked",_check_icons.off)
	check.add_theme_icon_override("checked",_check_icons.on)
	check.add_theme_icon_override("unchecked_disabled",_check_icons.off_disabled)
	check.add_theme_icon_override("checked_disabled",_check_icons.on)
	check.add_theme_color_override("font_color",THEME.IVORY)
	check.add_theme_color_override("font_hover_color",THEME.HIGHLIGHT_GOLD)
	check.add_theme_color_override("font_pressed_color",THEME.HIGHLIGHT_GOLD)
	check.add_theme_color_override("font_disabled_color",Color(THEME.MUTED,0.6))

# ---------------------------------------------------------------- facilities

func facilities_page() -> void:
	_heading("Establishment","Each expansion adds rooms, expedition slots, and stronger recruits")
	var tiers := HBoxContainer.new()
	tiers.add_theme_constant_override("separation",8)
	body.add_child(tiers)
	for rank in range(4):
		var tier := HearthCatalog.tier(rank)
		var current: bool = rank == int(campaign.establishment_tier)
		var reached: bool = rank <= int(campaign.establishment_tier)
		var panel := _panel(tiers,Color("3a2716") if current else (CARD_FILL if reached else Color("1d140d")),THEME.GOLD if current else (CARD_BORDER if reached else Color("3a2a1c")),10)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation",2)
		panel.add_child(content)
		content.add_child(label("CURRENT" if current else ("BUILT" if reached else "TIER %d" % (rank+1)),11,THEME.GOLD if current else THEME.MUTED))
		content.add_child(label(String(tier.name),16,THEME.HIGHLIGHT_GOLD if reached else THEME.MUTED))
		content.add_child(label("%d rooms · %d slots" % [tier.capacity,tier.expedition_slots],13,THEME.IVORY if reached else THEME.MUTED))
		if GameBalance.leveling_enabled(): content.add_child(label("Recruits L%d–%d" % [tier.recruit_levels[0],tier.recruit_levels[1]],13,THEME.IVORY if reached else THEME.MUTED))
	_heading("Improvements","Commissioned work finishes after a few days")
	var grid := _grid(2)
	var branches: Array = ["roster_services"]+HearthCatalog.data().facilities.keys()
	for branch in branches:
		# Training only raises levels, so it is hidden while levelling is switched off.
		if branch == "replacement_quality" and not GameBalance.leveling_enabled(): continue
		var definition: Dictionary=HearthCatalog.data().facilities.get(branch,{"name":"Expand the Hearth","description":"Build the next authored wing and increase company capacity."})
		var cost := HearthFacilities.quote(campaign,branch)
		var rank := int(campaign.tavern_upgrades.get(branch,0))
		var content := card(String(definition.name),String(definition.description),grid)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation",4)
		content.add_child(pips)
		pips.add_child(label("Rank %d" % rank,13,THEME.MUTED))
		for index in range(maxi(3,rank+1)):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(14,6)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.color = THEME.GOLD if index < rank else Color("3a2a1c")
			pips.add_child(pip)
		var footer := HBoxContainer.new()
		footer.add_theme_constant_override("separation",8)
		content.add_child(footer)
		var status: Label
		if campaign.construction.has(branch): status = label("Under construction · ready Day %d" % campaign.construction[branch].due_day,13,Color("8fb8e0"))
		elif cost.available: status = label("%dg · %d essence · %d %s" % [cost.gold,cost.essence,cost.days,"day" if int(cost.days) == 1 else "days"],13,THEME.IVORY)
		else: status = label(String(cost.error),13,THEME.MUTED)
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if cost.available: status.tooltip_text = "Requires tier %d, reputation %d, and %d guardians defeated on expeditions you led." % [int(cost.tier)+1,cost.get("reputation",0),cost.get("manual_clears",0)]
		footer.add_child(status)
		var commission := button(footer,"Commission",func(): act(HearthFacilities.purchase(campaign,branch)),cost.available)
		commission.custom_minimum_size = Vector2(120,36)

# ---------------------------------------------------------------- suppliers

func merchant_page() -> void:
	_heading("Provisions","Stock refreshes each week")
	var provisions := _grid(3)
	var supplies := card("Travel supplies","Every expedition consumes supplies. You have %d." % campaign.supplies,provisions)
	var buy_supplies := button(supplies,"Buy 4 · 8g",_buy_supplies)
	buy_supplies.custom_minimum_size = Vector2(120,36)
	for id in HearthCatalog.data().consumables:
		var data := GameBalance.get_consumable(id)
		var content := card(String(data.get("name",id)),String(data.get("description","")),provisions)
		var icon_path := String(data.get("icon",""))
		if ResourceLoader.exists(icon_path):
			var title_node := content.get_child(0)
			var title_row := HBoxContainer.new()
			title_row.add_theme_constant_override("separation",8)
			content.add_child(title_row)
			content.move_child(title_row,0)
			var icon := TextureRect.new()
			icon.texture = load(icon_path)
			icon.custom_minimum_size = Vector2(24,24)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			title_row.add_child(icon)
			title_node.reparent(title_row)
			(title_node as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(label("%d in storage" % int(campaign.consumable_stock.get(id,0)),12,THEME.MUTED))
		var buy_provision := button(content,"Buy · %dg" % (8 if id=="healing_potion" else 18),func(): act(HearthArmory.buy_consumable(campaign,id)))
		buy_provision.custom_minimum_size = Vector2(120,36)
	_heading("Equipment","Dungeon-only relics must be recovered by an expedition")
	var gear := _grid(3)
	var listed := 0
	for id in HearthCatalog.data().items:
		var entry := HearthCatalog.item(id)
		if not entry.sources.has("merchant") or int(entry.tier)>campaign.establishment_tier: continue
		listed += 1
		var rarity := String(entry.get("rarity","common"))
		var content := card(String(entry.name),"",gear,RARITY_COLORS.get(rarity,THEME.GOLD))
		var class_note := " · %s only" % String(entry.class_id).capitalize() if entry.has("class_id") else ""
		content.add_child(label("%s · %s%s" % [String(entry.slot).capitalize(),rarity.capitalize(),class_note],12,THEME.MUTED))
		var description := label(String(entry.description),13,THEME.IVORY)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(description)
		var buy_item := button(content,"Buy · %dg" % entry.price,func(): act(HearthArmory.buy(campaign,id)),campaign.banked_gold >= int(entry.price))
		buy_item.custom_minimum_size = Vector2(120,36)
	if listed == 0: _empty_state("No equipment for sale yet","Expand the Hearth to attract better suppliers.")

# ---------------------------------------------------------------- records

func bounties_page() -> void:
	BountyBoard.refresh(campaign)
	var offers := BountyBoard.offers(campaign)
	_heading("Posted","%d of %d slots · %d completed so far" % [offers.size(),BountyBoard.slots(campaign),int(campaign.lifetime_stats.get("bounties",0))])
	if offers.is_empty(): _empty_state("The board is bare","New contracts are posted each day.")
	for bounty in offers:
		var content := card(String(bounty.text),"")
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",8); content.add_child(row)
		row.add_child(_chip("Reward: " + BountyBoard.reward_text(bounty.reward),THEME.HIGHLIGHT_GOLD))
		var days_left := int(bounty.expires_day) - campaign.calendar_day
		row.add_child(_chip("Last day" if days_left <= 0 else "%d days left" % (days_left + 1),THEME.MUTED))

func unlocks_page() -> void:
	var all := Unlocks.all()
	var earned := 0
	for unlock in all:
		if campaign.unlocks_earned.has(String(unlock.id)): earned += 1
	_heading("Progress","%d of %d earned · drop luck ×%.2f" % [earned,all.size(),Unlocks.drop_luck(campaign)])
	var grid := _grid(2)
	for unlock in all:
		var done := campaign.unlocks_earned.has(String(unlock.id))
		var content := card(String(unlock.name) if done else "Locked: " + String(unlock.hint),String(unlock.text) if done else "",grid,THEME.HIGHLIGHT_GOLD if done else THEME.MUTED)
		var progress := Unlocks.progress(campaign,unlock)
		if done: content.add_child(label("Earned on Day %d" % int(campaign.unlocks_earned[String(unlock.id)]),12,GOOD))
		elif not progress.is_empty(): content.add_child(label(progress,13,THEME.IVORY))

## Clear times for every dungeon: the record, the best per class, and recent runs.
func best_times_page() -> void:
	var any := false
	for id in HearthCatalog.data().dungeon_levels:
		if not state.is_dungeon_unlocked(id) and ClearRecords.clears(campaign,id) == 0: continue
		any = true
		var dungeon_name := String(GameBalance.get_dungeon(id).get("name",id))
		var clears := ClearRecords.clears(campaign,id)
		var record := ClearRecords.best(campaign,id)
		var content := card(dungeon_name,"" if clears > 0 else "No guardian defeated yet. Your first clear sets the time to beat.")
		if clears == 0: continue
		var headline := HBoxContainer.new()
		headline.add_theme_constant_override("separation",8)
		content.add_child(headline)
		for pair in [["Record",ClearRecords.format_time(float(record.time))],["Set by","%s · %s" % [String(record.hero),String(record.class_id).capitalize()]],["Clears",str(clears)]]:
			var tile := _panel(headline,Color("241910"),Color("4a3522"),8)
			var stack := VBoxContainer.new()
			stack.add_theme_constant_override("separation",0)
			tile.add_child(stack)
			stack.add_child(label(String(pair[0]).to_upper(),11,THEME.MUTED))
			stack.add_child(label(String(pair[1]),16,THEME.HIGHLIGHT_GOLD))
		var grid := _grid(3,content)
		grid.columns = 3
		for class_id in ["warrior","tank","rogue","mage","healer","summoner"]:
			var best := ClearRecords.best(campaign,id,class_id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",6)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(row)
			var name_label := label(class_id.capitalize(),14,THEME.IVORY if campaign.unlocked_classes.has(class_id) else THEME.MUTED)
			name_label.custom_minimum_size = Vector2(80,0)
			row.add_child(name_label)
			if best.is_empty(): row.add_child(label("—",14,THEME.MUTED))
			else:
				var is_record := is_equal_approx(float(best.time),float(record.time))
				var time_label := label(ClearRecords.format_time(float(best.time)),15,THEME.HIGHLIGHT_GOLD if is_record else GOOD)
				time_label.tooltip_text = "%s · Day %d" % [String(best.hero),int(best.day)]
				time_label.mouse_filter = Control.MOUSE_FILTER_PASS
				row.add_child(time_label)
		var recent := ClearRecords.recent(campaign,id)
		if not recent.is_empty():
			content.add_child(label("RECENT CLEARS",11,THEME.MUTED))
			for run in recent.slice(0,5):
				var tag := "  ·  record" if bool(run.get("best_overall",false)) else ("  ·  class best" if bool(run.get("best_for_class",false)) else "")
				content.add_child(label("%s   %s · %s · Day %d%s" % [ClearRecords.format_time(float(run.time)),String(run.hero),String(run.class_id).capitalize(),int(run.day),tag],13,THEME.IVORY if tag.is_empty() else THEME.HIGHLIGHT_GOLD))
	if not any: _empty_state("No dungeons open yet","Clear times appear here once your company has somewhere to go.")

func reports_page() -> void:
	if campaign.return_reports.is_empty():
		_empty_state("The ledger awaits your first return","Every expedition records gold, contracts, equipment, survivors and losses here.")
		return
	for index in range(campaign.return_reports.size()-1,-1,-1):
		var report: Dictionary=campaign.return_reports[index]
		var content := card(String(report.headline),"")
		var numbers := HBoxContainer.new()
		numbers.add_theme_constant_override("separation",6)
		content.add_child(numbers)
		for pair in [["Gross","%dg" % report.gold],["Adventurer share","−%dg" % report.share],["Net","%dg" % report.net],["Essence","%d" % report.essence]]:
			var tile := _panel(numbers,Color("241910"),Color("4a3522"),8)
			var stack := VBoxContainer.new()
			stack.add_theme_constant_override("separation",0)
			tile.add_child(stack)
			stack.add_child(label(String(pair[0]).to_upper(),11,THEME.MUTED))
			stack.add_child(label(String(pair[1]),16,THEME.HIGHLIGHT_GOLD))
		for line in [["Returned",report.returned,GOOD],["Lost",report.lost,BAD],["Recovered gear",report.items,THEME.IVORY]]:
			if Array(line[1]).is_empty(): continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation",8)
			content.add_child(row)
			var caption := label(String(line[0]),13,THEME.MUTED)
			caption.custom_minimum_size = Vector2(120,0)
			row.add_child(caption)
			var value := label(", ".join(line[1]),14,line[2])
			value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(value)
		for bounty_text in Array(report.get("bounties",[])):
			var bounty_label := label("Bounty complete: " + String(bounty_text),13,THEME.HIGHLIGHT_GOLD)
			bounty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(bounty_label)
		for unlock_name in Array(report.get("unlocks",[])): content.add_child(label("Unlocked: " + String(unlock_name),13,Color("e08af0")))
		for event in report.events:
			var event_label := label("•  " + String(event),13,THEME.MUTED)
			event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(event_label)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		closed.emit()
		get_viewport().set_input_as_handled()
