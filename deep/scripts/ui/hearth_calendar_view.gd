extends VBoxContainer
class_name HearthCalendarView

const THEME := preload("res://scripts/ui/tavern_ui_theme.gd")
var campaign: CampaignState
var season_index := 0
var selected_day := 1
var tabs: TabContainer
var heading: Label
var grid: GridContainer
var details: RichTextLabel
var history_text: RichTextLabel
var previous_button: Button
var day_buttons: Array[Button] = []

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs = TabContainer.new()
	tabs.custom_minimum_size.y = 430
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	var month := VBoxContainer.new()
	month.name = "Calendar"
	month.add_theme_constant_override("separation",6)
	tabs.add_child(month)
	var navigation := HBoxContainer.new()
	month.add_child(navigation)
	previous_button = _button(navigation,"‹",change_season.bind(-1))
	previous_button.accessibility_name = "Previous season"
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size",20)
	heading.add_theme_color_override("font_color",THEME.GOLD)
	navigation.add_child(heading)
	var next := _button(navigation,"›",change_season.bind(1))
	next.accessibility_name = "Next season"
	_button(navigation,"Today",show_today)
	var weekdays := GridContainer.new()
	weekdays.columns = 7
	month.add_child(weekdays)
	for weekday in ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]:
		var label := Label.new()
		label.text = weekday
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_color_override("font_color",THEME.MUTED)
		weekdays.add_child(label)
	grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	month.add_child(grid)
	for index in 28:
		var day := _button(grid,"",select_day.bind(index))
		day.custom_minimum_size = Vector2(0,55)
		day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		day.clip_text = true
		day_buttons.append(day)
	var legend := Label.new()
	legend.text = "Today is gold · Select a day for details · Visitors arrive every shift"
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size",12)
	legend.add_theme_color_override("font_color",THEME.MUTED)
	month.add_child(legend)
	details = _rich_text()
	details.custom_minimum_size.y = 80
	month.add_child(details)
	history_text = _rich_text()
	history_text.name = "History"
	tabs.add_child(history_text)
	if campaign != null: show_today()

func _button(parent: Node, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	THEME.apply_button(button,false,13,Vector2(42,32))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _rich_text() -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.focus_mode = Control.FOCUS_ALL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size",14)
	return text

func open(c: CampaignState) -> void:
	campaign = c
	if tabs != null: show_today()

func show_today() -> void:
	if campaign == null: return
	season_index = int((campaign.calendar_day-1)/28)
	selected_day = campaign.calendar_day
	refresh()

func change_season(direction: int) -> void:
	season_index = maxi(0,season_index+direction)
	selected_day = season_index*28+1
	refresh()

func select_day(index: int) -> void:
	selected_day = season_index*28+index+1
	refresh()

func focus_target() -> Control:
	if tabs.current_tab == 1: return history_text
	return day_buttons[(selected_day-1)%28]

func entries_for_day(day: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var recorded: Array[Dictionary] = []
	for event in campaign.calendar_history:
		if int(event.get("day",1)) != day: continue
		var shift := " · %s" % ("Early" if int(event.shift) == 0 else "Late") if event.has("shift") else ""
		recorded.append({"label":String(event.get("kind","event")).capitalize(),"text":String(event.get("text",""))+shift})
	if day >= campaign.calendar_day:
		var expeditions: Array = campaign.dispatches.values().duplicate()
		if campaign.expedition.active: expeditions.append(campaign.expedition.to_dict())
		for expedition in expeditions:
			if int(expedition.get("due_day",0)) != day: continue
			var due_shift := int(expedition.get("due_shift_index",-1))
			var shift := "Morning" if due_shift < 0 else ("Early Shift" if due_shift % 2 == 0 else "Late Shift")
			entries.append({"label":"Party return","text":"%s party expected back · %s." % [String(expedition.get("dungeon_id","")).capitalize(),shift]})
		for member in campaign.living_roster():
			if member.status == "recovering" and member.recovery_until == day:
				entries.append({"label":"Recovery","text":"%s is ready in the early shift." % member.display_name})
		for branch in campaign.construction:
			if int(campaign.construction[branch].due_day) == day:
				entries.append({"label":"Construction","text":"%s completes in the early shift." % String(branch).replace("_"," ").capitalize()})
	if (day-1)%7 == 0: entries.append({"label":"Market","text":"Weekly merchant stock refresh."})
	entries.append_array(recorded)
	return entries

func refresh() -> void:
	if campaign == null or heading == null: return
	var season := String(CampaignState.SEASONS[season_index%4])
	var year := int(season_index/4)+1
	heading.text = "%s · Year %d" % [season,year]
	previous_button.disabled = season_index == 0
	for index in 28:
		var day := season_index*28+index+1
		var entries := entries_for_day(day)
		var label := "No entries" if entries.is_empty() else String(entries[0].label)
		if entries.size() > 1: label += " +%d" % (entries.size()-1)
		var button := day_buttons[index]
		button.text = "%d%s\n%s" % [index+1," · Today" if day == campaign.calendar_day else "",label]
		button.accessibility_name = "%s %d, Year %d. %s" % [season,index+1,year,label]
		button.tooltip_text = button.accessibility_name
		for entry in entries: button.tooltip_text += "\n"+String(entry.text)
		var fill := THEME.WALNUT if day == selected_day else THEME.DARK_WALNUT
		var border := THEME.HIGHLIGHT_GOLD if day == campaign.calendar_day else (THEME.IVORY if day == selected_day else THEME.BRONZE)
		button.add_theme_stylebox_override("normal",THEME.panel(fill,border,3,2))
		button.add_theme_color_override("font_color",THEME.HIGHLIGHT_GOLD if day == campaign.calendar_day else THEME.IVORY)
	var selected := entries_for_day(selected_day)
	var lines: Array[String] = ["[b]%s, %s %d · Year %d[/b]" % [CampaignState.WEEKDAYS[(selected_day-1)%7],season,(selected_day-1)%28+1,year]]
	if selected_day == campaign.calendar_day: lines.append("Current time: %s" % HearthCalendar.shift_name(campaign))
	if selected.is_empty(): lines.append("No recorded or scheduled events for this day.")
	for entry in selected: lines.append("[color=#d8a642]%s[/color] · %s" % [entry.label,entry.text])
	details.text = "\n".join(lines)
	var date := campaign.get_calendar_date()
	var history: Array[String] = ["[font_size=22][color=#f1c565]%s, %s %d, Year %d[/color][/font_size]" % [date.weekday,date.season,date.season_day,date.year],"%s · Candidate wave %d" % [HearthCalendar.shift_name(campaign),campaign.candidate_wave_id],"\n[b]RECENT HEARTH HISTORY[/b]"]
	if campaign.calendar_history.is_empty(): history.append("No entries yet.")
	for index in range(campaign.calendar_history.size()-1,-1,-1):
		var event: Dictionary = campaign.calendar_history[index]
		history.append("Day %d · %s — %s" % [int(event.get("day",1)),String(event.get("kind","event")).capitalize(),String(event.get("text",""))])
	history_text.text = "\n".join(history)
