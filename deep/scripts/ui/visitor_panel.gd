extends Control
class_name VisitorPanel

## Talking to a visitor of merit at the tavern (VisitorService): who they are,
## how much they trust you, what they say, their jobs (accept, hand over,
## collect) and their wares. Portraits are silhouettes until art exists
## (PlaceholderArt).

const THEME := preload("res://scripts/ui/tavern_ui_theme.gd")

signal closed
signal changed
signal contest_requested(visitor_id: String, contest_id: String)

var campaign: CampaignState
var visitor_id := ""
var tab := "jobs"
var speech := ""

var frame: PanelContainer
var portrait_rect: TextureRect
var name_label: Label
var title_label: Label
var rank_label: Label
var favour_bar: ProgressBar
var blurb_label: Label
var speech_label: Label
var tab_row: HBoxContainer
var list: VBoxContainer
var notice: Label
var challenge_button: Button

func _ready() -> void:
	name = "VisitorPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade := ColorRect.new(); shade.color = Color(0.03,0.02,0.01,0.78); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var centre := CenterContainer.new(); centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(centre)
	frame = PanelContainer.new(); frame.custom_minimum_size = Vector2(1060,610)
	var style := THEME.panel(Color("1f160f"),Color("8a6430"),10,2); style.set_content_margin_all(22)
	frame.add_theme_stylebox_override("panel",style)
	centre.add_child(frame)
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation",22); frame.add_child(columns)
	# Who they are.
	var left := VBoxContainer.new(); left.custom_minimum_size = Vector2(260,0); left.add_theme_constant_override("separation",6)
	columns.add_child(left)
	portrait_rect = TextureRect.new(); portrait_rect.name = "Portrait"; portrait_rect.custom_minimum_size = Vector2(240,300)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_child(portrait_rect)
	name_label = _label("",24,THEME.HIGHLIGHT_GOLD); left.add_child(name_label)
	title_label = _label("",15,THEME.IVORY); left.add_child(title_label)
	rank_label = _label("",13,THEME.GOLD); left.add_child(rank_label)
	favour_bar = ProgressBar.new(); favour_bar.show_percentage = false; favour_bar.custom_minimum_size = Vector2(240,10)
	var fill := StyleBoxFlat.new(); fill.bg_color = THEME.HIGHLIGHT_GOLD; favour_bar.add_theme_stylebox_override("fill",fill)
	var back := StyleBoxFlat.new(); back.bg_color = Color("120c08"); favour_bar.add_theme_stylebox_override("background",back)
	left.add_child(favour_bar)
	blurb_label = _label("",13,THEME.MUTED); blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; blurb_label.custom_minimum_size = Vector2(250,0)
	left.add_child(blurb_label)
	# What they say and offer.
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right.add_theme_constant_override("separation",10)
	columns.add_child(right)
	var top := HBoxContainer.new(); right.add_child(top)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(spacer)
	var close_button := _button(top,"Farewell",close); close_button.name = "Close"
	var speech_box := PanelContainer.new()
	var speech_style := THEME.panel(Color("2b1e15"),Color("5d4428"),8,1); speech_style.set_content_margin_all(14)
	speech_box.add_theme_stylebox_override("panel",speech_style)
	right.add_child(speech_box)
	speech_label = _label("",16,THEME.IVORY); speech_label.name = "Speech"; speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speech_box.add_child(speech_label)
	tab_row = HBoxContainer.new(); tab_row.add_theme_constant_override("separation",8); right.add_child(tab_row)
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	list = VBoxContainer.new(); list.name = "List"; list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; list.add_theme_constant_override("separation",8)
	scroll.add_child(list)
	notice = _label("",14,THEME.HIGHLIGHT_GOLD); notice.name = "Notice"; notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(notice)

func open(c: CampaignState, id: String, message: String = "") -> void:
	campaign = c; visitor_id = id
	VisitorService.state(c,id)["met"] = true
	speech = VisitorService.greeting(c,id)
	tab = "jobs"
	notice.text = message
	visible = true
	move_to_front()
	refresh()

func close() -> void:
	visible = false
	closed.emit()

func refresh() -> void:
	if campaign == null: return
	var v := VisitorService.visitor(visitor_id)
	portrait_rect.texture = PlaceholderArt.visitor_portrait(v)
	var has_art := not String(Dictionary(v.get("art",{})).get("portrait","")).is_empty()
	portrait_rect.tooltip_text = "" if has_art else "Art to come: %s" % String(v.get("art_brief",""))
	name_label.text = String(v.get("name",visitor_id))
	title_label.text = String(v.get("title",""))
	var next := VisitorService.next_rank_favour(campaign,visitor_id)
	var have := VisitorService.favour(campaign,visitor_id)
	rank_label.text = "%s · %d favour%s" % [VisitorService.rank_name(campaign,visitor_id),have,(" (%d for the next rank)" % next) if next > 0 else ""]
	favour_bar.max_value = maxf(1.0,float(next if next > 0 else have)); favour_bar.value = have
	blurb_label.text = String(v.get("blurb",""))
	speech_label.text = "“%s”" % speech
	for child in tab_row.get_children(): tab_row.remove_child(child); child.queue_free()
	for entry in [["jobs","Jobs"],["wares","Wares"]]:
		if entry[0] == "wares" and Array(v.get("shop",[])).is_empty(): continue
		var tab_button := _button(tab_row,String(entry[1]),func(): tab = String(entry[0]); refresh(),tab == String(entry[0]))
		tab_button.name = "%sTab" % String(entry[1])
	var talk := _button(tab_row,"Chat",func():
		speech = VisitorService.idle_line(campaign,visitor_id)
		refresh())
	talk.name = "Chat"
	var game := VisitorService.minigame(visitor_id)
	if not game.is_empty():
		var contest_name := String(VisitorContestRules.CONTESTS.get(String(game.contest),{}).get("name","Challenge"))
		challenge_button = _button(tab_row,"Challenge: %s" % contest_name,func(): contest_requested.emit(visitor_id,String(game.contest)))
		challenge_button.name = "Challenge"
		challenge_button.tooltip_text = "Win once per visit for +%d favour." % int(game.get("favour_per_win",1)) if VisitorService.can_contest(campaign,visitor_id) else "You've already won this visit. Play for fun, or come back next time."
	for child in list.get_children(): list.remove_child(child); child.queue_free()
	if tab == "wares": _wares()
	else: _jobs()

func _jobs() -> void:
	for value in VisitorService.quests(visitor_id):
		var quest_id := String(Dictionary(value).get("id",""))
		list.add_child(_quest_card(Dictionary(value),quest_id))

func _quest_card(q: Dictionary, quest_id: String) -> Control:
	var state_id := VisitorService.quest_state(campaign,visitor_id,quest_id)
	var card := _card("Quest_%s" % quest_id,state_id)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",4); card.add_child(box)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation",8); box.add_child(top)
	var title := _label(String(q.get("title",quest_id)) if state_id != "locked" else "???",17,THEME.HIGHLIGHT_GOLD if state_id != "locked" else THEME.MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; top.add_child(title)
	top.add_child(_label({"locked":"Locked","available":"On offer","active":"In progress","ready":"Done!","done":"Complete"}.get(state_id,""),13,{"ready":Color("8fd48a"),"done":THEME.MUTED,"locked":THEME.MUTED}.get(state_id,THEME.GOLD)))
	if state_id == "locked":
		box.add_child(_label(VisitorService.lock_reason(campaign,visitor_id,quest_id),13,Color("e0a35e")))
		return card
	box.add_child(_label(String(q.get("summary","")),14,THEME.IVORY))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10); box.add_child(row)
	var reward := _label("Reward: %s" % _reward_text(Dictionary(q.get("reward",{}))),13,THEME.MUTED)
	reward.size_flags_horizontal = Control.SIZE_EXPAND_FILL; reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(reward)
	var progress := VisitorService.progress_text(campaign,visitor_id,quest_id)
	if state_id == "active" and not progress.is_empty(): row.add_child(_label(progress,13,THEME.GOLD))
	var objective := String(Dictionary(q.get("objective",{})).get("type",""))
	match state_id:
		"available":
			var accept := _button(row,"Accept",func():
				var result := VisitorService.accept(campaign,visitor_id,quest_id)
				speech = VisitorService.quest_line(visitor_id,quest_id,"offer")
				_result(result))
			accept.name = "Accept"
			var ask := _button(row,"Ask",func():
				speech = VisitorService.quest_line(visitor_id,quest_id,"offer")
				refresh())
			ask.name = "Ask"
		"active":
			if objective == "deliver":
				var hand := _button(row,"Hand over",func():
					var result := VisitorService.deliver(campaign,visitor_id,quest_id)
					if bool(result.get("ok",false)): speech = VisitorService.quest_line(visitor_id,quest_id,"done")
					_result(result))
				THEME.apply_button(hand,true,14,Vector2(0,36))
				hand.name = "Deliver"; hand.disabled = not VisitorService.can_deliver(campaign,visitor_id,quest_id)
			else:
				var how := _button(row,"How's it going?",func():
					speech = VisitorService.quest_line(visitor_id,quest_id,"progress")
					refresh())
				how.name = "Progress"
		"ready":
			var collect := _button(row,"Collect reward",func():
				var result := VisitorService.claim(campaign,visitor_id,quest_id)
				if bool(result.get("ok",false)): speech = VisitorService.quest_line(visitor_id,quest_id,"done")
				_result(result))
			THEME.apply_button(collect,true,14,Vector2(0,36))
			collect.name = "Claim"
	return card

func _wares() -> void:
	for offer in VisitorService.shop(campaign,visitor_id):
		var card := _card("Offer_%s" % String(offer.offer_id),"sold" if bool(offer.sold) else ("locked" if bool(offer.locked) else "available"))
		list.add_child(card)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",10); card.add_child(row)
		var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(info)
		info.add_child(_label(String(offer.label),16,THEME.HIGHLIGHT_GOLD if not bool(offer.locked) else THEME.MUTED))
		info.add_child(_label({"item":"Equipment, to the Armory","furnishing":"Furnishing, to storage","food":"Food, to the pantry"}.get(String(offer.kind),""),12,THEME.MUTED))
		if bool(offer.sold):
			row.add_child(_label("Sold",14,THEME.MUTED))
		elif bool(offer.locked):
			var needed := Dictionary(VisitorService.ranks(visitor_id)[mini(int(offer.min_rank),VisitorService.ranks(visitor_id).size() - 1)])
			row.add_child(_label("For their %s" % String(needed.get("name","")),13,Color("e0a35e")))
		else:
			var buy := _button(row,"Buy · %dg" % int(offer.price),func(): _result(VisitorService.buy(campaign,visitor_id,String(offer.offer_id))),true)
			buy.name = "Buy"; buy.disabled = campaign.banked_gold < int(offer.price)

func _result(result: Dictionary) -> void:
	notice.text = String(result.get("message",result.get("error","")))
	notice.add_theme_color_override("font_color",THEME.HIGHLIGHT_GOLD if bool(result.get("ok",false)) else Color("e07a62"))
	if bool(result.get("ok",false)): changed.emit()
	refresh()

func show_message(text_value: String) -> void:
	notice.text = text_value
	notice.add_theme_color_override("font_color",THEME.HIGHLIGHT_GOLD)

func _reward_text(reward: Dictionary) -> String:
	var bits := PackedStringArray()
	if int(reward.get("gold",0)) > 0: bits.append("%d gold" % int(reward.gold))
	if int(reward.get("renown",0)) > 0: bits.append("%d renown" % int(reward.renown))
	if int(reward.get("favour",0)) > 0: bits.append("+%d favour" % int(reward.favour))
	for item_id in Array(reward.get("items",[])): bits.append(String(HearthCatalog.item(String(item_id)).get("name",item_id)))
	for furnishing_id in Array(reward.get("furnishings",[])): bits.append(String(HearthLodging.furnishing(String(furnishing_id)).get("name",furnishing_id)))
	var food: Dictionary = Dictionary(reward.get("food",{}))
	for food_id in food: bits.append("%d %s" % [int(food[food_id]),String(HearthUpkeep.food(String(food_id)).get("name",food_id))])
	return ", ".join(bits) if not bits.is_empty() else "their thanks"

func _card(node_name: String, state_id: String) -> PanelContainer:
	var card := PanelContainer.new(); card.name = node_name
	var border: Color = {"ready":Color("8fd48a"),"available":Color("c9a36a"),"active":Color("8a6430")}.get(state_id,Color("4a3522"))
	var style := THEME.panel(Color("2b1e15") if state_id != "locked" else Color("1d150f"),border,8,1); style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel",style)
	return card

func _label(text_value: String, size_value: int, tint: Color) -> Label:
	var label := Label.new(); label.text = text_value
	label.add_theme_font_size_override("font_size",size_value); label.add_theme_color_override("font_color",tint)
	return label

func _button(parent: Node, text_value: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new(); button.text = text_value
	THEME.apply_button(button,primary,14,Vector2(0,36))
	button.pressed.connect(action)
	parent.add_child(button)
	return button
