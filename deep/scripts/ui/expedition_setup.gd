extends ColorRect
class_name ExpeditionSetup

## Setting out on an expedition, in three steps, picture first:
##   1 Destination  painted previews of each dungeon; ones not in this build are
##                  greyed out "Coming soon" tiles that can't be picked
##   2 Adventurer   portrait cards with hearts, mood and gear (runs are solo)
##   3 Gear & Supplies  their equipment slots (pick from storage), potions to
##                  pack, the rations the run will take, and open bounties
## then Set Out. Emits launch_requested(dungeon_id, character_id); the tavern
## starts the run. Opened from the Hearth's Expeditions page and the tavern's
## Expedition button.

signal launch_requested(dungeon_id: String, character_id: String)
signal closed

const THEME = preload("res://scripts/ui/tavern_ui_theme.gd")
const PREVIEWS := "res://assets/ui/destinations/%s.png"
## The three tiles on the Destination step, left to right. Only the forest can
## be chosen: deeper dungeons (the Stone Crypt) are reached by playing through
## it. The other two show as locked "Coming soon" tiles.
const DESTINATIONS := ["forest","ashen_farmstead","moonlit_grove"]
const STARTING_DUNGEON := "forest"
const TILE_SIZE := Vector2(372,0)
const PREVIEW_SIZE := Vector2(348,196)
const STEPS := ["Destination","Adventurer","Gear & Supplies"]
const SLOTS := ["weapon","armor","accessory","relic"]
const RARITY_COLORS := {"common":Color("ead9b8"),"uncommon":Color("8fd48a"),"rare":Color("7fb4ee"),"epic":Color("c79af0"),"legendary":Color("f0a24f")}
const CARD := Color("2b1e15")
const CARD_BORDER := Color("5d4428")

var campaign: CampaignState
var state: RunState
var step := 0
var dungeon_id := ""
var hero_id := ""
## A chosen run seed ("" = random). See RunSeed.
var seed_text := ""
var seed_status: Label
var content: VBoxContainer
var step_row: HBoxContainer
var footer_summary: HBoxContainer
var back_button: Button
var next_button: Button
var error_label: Label
var notice_label: Label

func _ready() -> void:
	name = "ExpeditionSetup"
	color = Color(0.015,0.012,0.009,0.96)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_" + side,32)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_" + side,18)
	add_child(margin)
	var shell := PanelContainer.new()
	var shell_style := THEME.panel(Color("21160f"),Color("8c5a26"),8,2)
	shell_style.set_content_margin_all(18)
	shell.add_theme_stylebox_override("panel",shell_style)
	margin.add_child(shell)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	shell.add_child(column)
	# Header: title, steps, close.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",16)
	column.add_child(header)
	var title := _label("Set Out",28,THEME.HIGHLIGHT_GOLD)
	header.add_child(title)
	step_row = HBoxContainer.new()
	step_row.add_theme_constant_override("separation",8)
	step_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_row.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(step_row)
	var close := Button.new(); close.name = "Close"; close.text = "Back to the Hearth"
	THEME.apply_button(close,false,14,Vector2(170,38))
	close.pressed.connect(func(): hide(); closed.emit())
	header.add_child(close)
	# Step content.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	# Footer: what's chosen so far, then Back / Next.
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	column.add_child(footer)
	footer_summary = HBoxContainer.new()
	footer_summary.add_theme_constant_override("separation",14)
	footer_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(footer_summary)
	error_label = _label("",14,Color("f0a08f"))
	footer.add_child(error_label)
	back_button = Button.new(); back_button.name = "Back"; back_button.text = "Back"
	THEME.apply_button(back_button,false,15,Vector2(110,44))
	back_button.pressed.connect(func(): go_to(step - 1))
	footer.add_child(back_button)
	next_button = Button.new(); next_button.name = "Next"
	next_button.pressed.connect(_next)
	footer.add_child(next_button)
	notice_label = _label("",14,Color("8fd48a"))
	column.add_child(notice_label)
	hide()

func open(c: CampaignState, runtime: RunState) -> void:
	campaign = c; state = runtime
	if dungeon_id.is_empty() or not _selectable(dungeon_id): dungeon_id = "forest"
	if hero_id.is_empty() or not _hero_ready(campaign.character(hero_id)):
		hero_id = ""
		for member in campaign.living_roster():
			if _hero_ready(member): hero_id = member.id; break
	step = 0
	notice_label.text = ""
	show()
	refresh()

func go_to(index: int) -> void:
	step = clampi(index,0,STEPS.size() - 1)
	if step >= 1 and not _selectable(dungeon_id): step = 0
	if step >= 2 and campaign.character(hero_id) == null: step = 1
	refresh()

func _next() -> void:
	if step < STEPS.size() - 1:
		go_to(step + 1)
		return
	var ready := readiness()
	if not ready.ok: return
	if state != null: state.requested_seed = RunSeed.decode(seed_text) if not seed_text.strip_edges().is_empty() else 0
	hide()
	launch_requested.emit(dungeon_id,hero_id)

func readiness() -> Dictionary:
	if not _selectable(dungeon_id): return {"ok":false,"error":"Choose a destination."}
	if not _hero_ready(campaign.character(hero_id)): return {"ok":false,"error":"Choose an adventurer who is home and ready."}
	if not seed_text.strip_edges().is_empty() and not RunSeed.is_valid(seed_text): return {"ok":false,"error":"That seed isn't valid: 8 letters and numbers, like K7QF-2MXA."}
	var ids: Array[String] = [hero_id]
	return HearthExpeditions.readiness(campaign,ids,dungeon_id)

func refresh() -> void:
	if campaign == null: return
	for container in [content,step_row,footer_summary]:
		for child in container.get_children():
			container.remove_child(child); child.queue_free()
	for index in STEPS.size():
		var pill := Button.new()
		pill.name = "Step%d" % (index + 1)
		pill.text = "%d  %s" % [index + 1,STEPS[index]]
		THEME.apply_button(pill,index == step,15,Vector2(190,40))
		pill.disabled = (index >= 1 and not _selectable(dungeon_id)) or (index >= 2 and campaign.character(hero_id) == null)
		pill.pressed.connect(go_to.bind(index))
		step_row.add_child(pill)
	match step:
		0: _destination_step()
		1: _adventurer_step()
		2: _gear_step()
	_footer()

# ---------------------------------------------------------------- step 1: destination

func _destination_step() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(row)
	for id in DESTINATIONS:
		if GameBalance.get_dungeon(id).is_empty(): continue
		if RunState.is_coming_soon(id): row.add_child(_coming_soon_tile(id))
		else: row.add_child(_destination_card(id))

## Runs always start in the forest; the crypt and beyond are reached from inside a run.
func _selectable(id: String) -> bool:
	return id == STARTING_DUNGEON and RunState.dungeon_available(id) and state != null and state.is_dungeon_unlocked(id)

func _preview(id: String, dimmed: bool) -> TextureRect:
	var preview := TextureRect.new()
	preview.name = "Preview"
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := PREVIEWS % id
	if ResourceLoader.exists(path): preview.texture = load(path)
	if dimmed:
		preview.material = ShaderMaterial.new()
		(preview.material as ShaderMaterial).shader = SlasherEnemy.desaturate_shader()
		(preview.material as ShaderMaterial).set_shader_parameter("amount",0.75)
		preview.modulate = Color(0.55,0.55,0.58)
	return preview

func _destination_card(id: String) -> Control:
	var dungeon := GameBalance.get_dungeon(id)
	var open := _selectable(id)
	var card := _card_button("Destination_%s" % id,id == dungeon_id,TILE_SIZE)
	card.disabled = not open
	card.pressed.connect(func(): dungeon_id = id; refresh())
	var box := _card_body(card)
	box.add_child(_preview(id,not open))
	box.add_child(_label(String(dungeon.get("name",id)),22,THEME.HIGHLIGHT_GOLD if open else THEME.MUTED))
	box.add_child(_label(String(dungeon.get("subtitle","")),14,THEME.IVORY if open else THEME.MUTED))
	var chips := HBoxContainer.new(); chips.add_theme_constant_override("separation",6); chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(chips)
	chips.add_child(_chip("%d floors" % int(dungeon.get("floors",5)),THEME.GOLD))
	chips.add_child(_chip(String(dungeon.get("difficulty","")),Color("c9a36a")))
	var record := ClearRecords.best(campaign,id)
	box.add_child(_label(("Record %s · %s" % [ClearRecords.format_time(float(record.time)),String(record.hero)]) if not record.is_empty() else "No clear yet: set the first time.",13,Color("8fd48a") if not record.is_empty() else THEME.MUTED))
	if not open: box.add_child(_wrap(_label("Locked · %s" % String(dungeon.get("unlock_text","")),13,Color("e0a35e"))))
	elif id == STARTING_DUNGEON: box.add_child(_wrap(_label("Fight through it to find the way down to the Stone Crypt.",13,Color("b9a98f"))))
	return card

func _coming_soon_tile(id: String) -> Control:
	var dungeon := GameBalance.get_dungeon(id)
	# A panel, not a button: it can't be picked.
	var tile := PanelContainer.new()
	tile.name = "ComingSoon_%s" % id
	tile.custom_minimum_size = TILE_SIZE
	tile.size_flags_vertical = Control.SIZE_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN
	tile.tooltip_text = "%s isn't in this build yet." % String(dungeon.get("name",id))
	var accent := Color("#" + String(dungeon.get("accent","777777")))
	var style := THEME.panel(Color("17110c"),accent.darkened(0.55),8,1); style.set_content_margin_all(12)
	tile.add_theme_stylebox_override("panel",style)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",6); box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)
	var picture := Control.new(); picture.custom_minimum_size = PREVIEW_SIZE; picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(picture)
	var preview := _preview(id,true); preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.add_child(preview)
	var lock := LockBadge.new(); lock.name = "Lock"; lock.accent = accent; lock.set_anchors_preset(Control.PRESET_FULL_RECT); lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_child(lock)
	var top := HBoxContainer.new(); top.mouse_filter = Control.MOUSE_FILTER_IGNORE; box.add_child(top)
	var name_label := _label(String(dungeon.get("name",id)),22,Color("8a7e70")); name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)
	box.add_child(_label(String(dungeon.get("subtitle","")),14,Color("6f6458")))
	box.add_child(_label("Not in this build yet.",13,accent.lerp(Color("8a7e70"),0.5)))
	return tile

# ---------------------------------------------------------------- step 2: adventurer

func _hero_ready(member: CharacterRecord) -> bool:
	return member != null and member.status == CharacterRecord.STATUS_AVAILABLE and member.recovery_until <= campaign.calendar_day

func _adventurer_step() -> void:
	content.add_child(_label("Who goes? Runs are solo: one adventurer, led by you.",15,THEME.MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation",12); flow.add_theme_constant_override("v_separation",12)
	content.add_child(flow)
	for member in campaign.living_roster(): flow.add_child(_hero_card(member))

func _portrait(member: CharacterRecord, size_value: Vector2) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = size_value
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := "res://assets/roster_portraits/%s_%d.png" % [member.class_id,member.portrait_variant]
	if ResourceLoader.exists(path): portrait.texture = load(path)
	return portrait

func _hero_card(member: CharacterRecord) -> Control:
	var ready := _hero_ready(member)
	var card := _card_button("Hero_%s" % member.id,member.id == hero_id,Vector2(360,0))
	card.disabled = not ready
	card.pressed.connect(func(): hero_id = member.id; refresh())
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",12); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_body(card).add_child(row)
	var portrait := _portrait(member,Vector2(96,112))
	if not ready: portrait.modulate = Color(0.5,0.5,0.5)
	row.add_child(portrait)
	var info := VBoxContainer.new(); info.add_theme_constant_override("separation",4); info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(_label(member.display_name,20,THEME.HIGHLIGHT_GOLD if ready else THEME.MUTED))
	info.add_child(_label(member.class_id.capitalize(),14,THEME.IVORY))
	var hearts := HeartRow.new(); hearts.health = member.current_health; hearts.maximum = member.max_health
	info.add_child(hearts)
	info.add_child(_mood_row(member))
	var weapon := HearthCatalog.item(String(Dictionary(campaign.armory.get(member.equipment.get("weapon",""),{})).get("item_id","")))
	info.add_child(_label("Wields %s" % String(weapon.get("name","nothing")),13,THEME.MUTED))
	var cut := _label("Tavern cut %d%%" % HearthCut.percent(campaign,member),13,THEME.HIGHLIGHT_GOLD)
	cut.name = "Cut"; cut.tooltip_text = HearthCut.explain(campaign,member); cut.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(cut)
	if not ready:
		var why := "Away on an expedition" if member.status == CharacterRecord.STATUS_EXPEDITION else ("Recovering until Day %d" % member.recovery_until if member.recovery_until > campaign.calendar_day or member.status == "recovering" else member.status.capitalize())
		info.add_child(_label(why,13,Color("e0a35e")))
	return card

func _mood_row(member: CharacterRecord) -> Control:
	var band := HearthUpkeep.band(HearthUpkeep.happiness(member))
	var colour := Color(String(band.get("color","#e8cf72")))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",6); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.tooltip_text = "Happiness %d / 100. Good food and victories keep adventurers happy; unhappy ones may leave the Hearth." % HearthUpkeep.happiness(member)
	row.add_child(_label(String(band.get("name","")),13,colour))
	var bar := ProgressBar.new(); bar.show_percentage = false; bar.max_value = 100; bar.value = HearthUpkeep.happiness(member)
	bar.custom_minimum_size = Vector2(110,8); bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER; bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new(); back.bg_color = Color("120c08"); bar.add_theme_stylebox_override("background",back)
	var fill := StyleBoxFlat.new(); fill.bg_color = colour; bar.add_theme_stylebox_override("fill",fill)
	row.add_child(bar)
	return row

# ---------------------------------------------------------------- step 3: gear & supplies

func _gear_step() -> void:
	var member := campaign.character(hero_id)
	if member == null: return
	var columns := HBoxContainer.new(); columns.add_theme_constant_override("separation",16)
	content.add_child(columns)
	# Who.
	var who := _panel_box(columns,Vector2(230,0))
	who.add_child(_portrait(member,Vector2(200,220)))
	who.add_child(_label(member.display_name,20,THEME.HIGHLIGHT_GOLD))
	var hearts := HeartRow.new(); hearts.health = member.current_health; hearts.maximum = member.max_health
	who.add_child(hearts)
	who.add_child(_mood_row(member))
	# Their one expedition: what the Hearth keeps, and that they leave afterwards.
	var cut_percent := HearthCut.percent(campaign,member)
	var deal := _wrap(_label("The Hearth keeps %d%% of what %s brings home. They keep the rest and retire to Eros town after this run." % [cut_percent,member.display_name],13,THEME.IVORY))
	deal.name = "Deal"; deal.tooltip_text = HearthCut.explain(campaign,member); deal.mouse_filter = Control.MOUSE_FILTER_PASS
	who.add_child(_label("TAVERN CUT  %d%%" % cut_percent,13,THEME.GOLD))
	who.add_child(deal)
	# Equipment.
	var gear := _panel_box(columns,Vector2(430,0))
	gear.add_child(_label("EQUIPMENT",13,THEME.GOLD))
	for slot in SLOTS: gear.add_child(_slot_row(member,slot))
	gear.add_child(_seed_box())
	# Supplies, potions, bounties.
	var side := _panel_box(columns,Vector2(0,0))
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(_label("RATIONS",13,THEME.GOLD))
	var served := HearthUpkeep.food(campaign.served_food)
	side.add_child(_wrap(_label("This run takes %d rations from the pantry (%s first)." % [HearthUpkeep.rations_per_run(),String(served.get("name","supplies"))],14,THEME.IVORY)))
	var pantry := HBoxContainer.new(); pantry.add_theme_constant_override("separation",6)
	side.add_child(pantry)
	for food_id in HearthUpkeep.order(): pantry.add_child(_chip("%s %d" % [String(HearthUpkeep.food(food_id).get("name",food_id)),int(campaign.pantry.get(food_id,0))],THEME.GOLD if food_id == campaign.served_food else THEME.MUTED))
	side.add_child(_label("POTIONS",13,THEME.GOLD))
	var packed := member.provisions.count("healing_potion")
	var stored := int(campaign.consumable_stock.get("healing_potion",0))
	side.add_child(_label("Packed %d · %d in storage" % [packed,stored],14,THEME.IVORY))
	var pack := Button.new(); pack.name = "PackPotion"; pack.text = "Pack a potion"
	THEME.apply_button(pack,false,14,Vector2(150,36))
	pack.disabled = stored <= 0 or member.provisions.size() >= 4
	pack.pressed.connect(func(): _act(HearthArmory.provision(campaign,member.id,"healing_potion")))
	side.add_child(pack)
	BountyBoard.refresh(campaign)
	var offers: Array = BountyBoard.offers(campaign)
	if not offers.is_empty():
		side.add_child(_label("BOUNTIES",13,THEME.GOLD))
		for bounty in offers: side.add_child(_wrap(_label("•  %s  (%s)" % [String(bounty.text),BountyBoard.reward_text(bounty.reward)],13,THEME.IVORY)))

## Optional run seed: type one, pick a saved one, or leave it blank for a random run.
func _seed_box() -> Control:
	var box := VBoxContainer.new(); box.name = "SeedBox"; box.add_theme_constant_override("separation",4)
	box.add_child(_label("RUN SEED",13,THEME.GOLD))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",8); box.add_child(row)
	var field := LineEdit.new(); field.name = "SeedField"
	field.placeholder_text = "Random"
	field.text = seed_text
	field.max_length = 12
	field.custom_minimum_size = Vector2(170,34)
	field.text_changed.connect(_on_seed_typed)
	row.add_child(field)
	var picker := OptionButton.new(); picker.name = "SavedSeeds"; picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_item("Saved seeds…"); picker.set_item_metadata(0,"")
	for entry in RunSeed.saved():
		var note := String(entry.get("note",""))
		picker.add_item("%s%s" % [String(entry.code),"  ·  " + note if not note.is_empty() else ""])
		picker.set_item_metadata(picker.item_count - 1,String(entry.code))
	picker.disabled = picker.item_count <= 1
	picker.item_selected.connect(func(index: int):
		var code := String(picker.get_item_metadata(index))
		if code.is_empty(): return
		field.text = code
		_on_seed_typed(code))
	row.add_child(picker)
	seed_status = _label("",12,THEME.MUTED)
	box.add_child(seed_status)
	_show_seed_status()
	return box

func _on_seed_typed(text_value: String) -> void:
	seed_text = text_value
	_show_seed_status()
	for child in footer_summary.get_children():
		footer_summary.remove_child(child); child.queue_free()
	_footer()

func _show_seed_status() -> void:
	if seed_status == null or not is_instance_valid(seed_status): return
	if seed_text.strip_edges().is_empty():
		seed_status.text = "Blank for a new random run. Same seed, same floors and loot."
		seed_status.add_theme_color_override("font_color",THEME.MUTED)
	elif RunSeed.is_valid(seed_text):
		seed_status.text = "Seeded run: %s" % RunSeed.encode(RunSeed.decode(seed_text))
		seed_status.add_theme_color_override("font_color",Color("8fd48a"))
	else:
		seed_status.text = "Not a valid seed yet (8 letters and numbers)."
		seed_status.add_theme_color_override("font_color",Color("e0a35e"))

func _slot_row(member: CharacterRecord, slot: String) -> Control:
	var row := HBoxContainer.new(); row.name = "Slot_%s" % slot; row.add_theme_constant_override("separation",8)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",0); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)
	box.add_child(_label(slot.to_upper(),11,THEME.MUTED))
	var picker := OptionButton.new(); picker.name = "Picker"
	picker.custom_minimum_size = Vector2(0,36)
	picker.add_theme_font_size_override("font_size",14)
	box.add_child(picker)
	var current := String(member.equipment.get(slot,""))
	var choices: Array[String] = [""]
	picker.add_item("— empty —")
	for id in campaign.armory:
		var instance: Dictionary = campaign.armory[id]
		var entry := HearthCatalog.item(String(instance.get("item_id","")))
		if String(entry.get("slot","")) != slot or String(entry.get("class_id",member.class_id)) != member.class_id: continue
		var owner := String(instance.get("owner",""))
		if not owner.is_empty() and owner != member.id: continue
		choices.append(String(id))
		picker.add_item("%s  (%s)" % [String(entry.get("name",id)),String(entry.get("rarity","common")).capitalize()])
		picker.set_item_tooltip(picker.item_count - 1,String(entry.get("description","")))
	picker.selected = maxi(0,choices.find(current))
	picker.disabled = choices.size() <= 1 and current.is_empty()
	picker.item_selected.connect(func(index: int):
		var chosen: String = choices[index]
		if chosen == current: return
		if chosen.is_empty(): _act(HearthArmory.unequip(campaign,member.id,slot))
		else: _act(HearthArmory.equip(campaign,member.id,chosen)))
	return row

func _act(result: Dictionary) -> void:
	notice_label.add_theme_color_override("font_color",Color("8fd48a") if bool(result.get("ok",false)) else Color("f0a08f"))
	notice_label.text = String(result.get("message",result.get("error","")))
	call_deferred("refresh")

# ---------------------------------------------------------------- footer

func _footer() -> void:
	var dungeon := GameBalance.get_dungeon(dungeon_id)
	if _selectable(dungeon_id):
		footer_summary.add_child(_chip(String(dungeon.get("name",dungeon_id)),THEME.GOLD))
	var member := campaign.character(hero_id)
	if member != null and step >= 1:
		footer_summary.add_child(_portrait(member,Vector2(34,40)))
		footer_summary.add_child(_label(member.display_name,15,THEME.IVORY))
	back_button.visible = step > 0
	var last := step == STEPS.size() - 1
	next_button.text = "Set Out" if last else "Next"
	var allowed := true
	error_label.text = ""
	if step == 0: allowed = _selectable(dungeon_id)
	elif step == 1: allowed = _hero_ready(member)
	else:
		var ready := readiness()
		allowed = ready.ok
		if not ready.ok: error_label.text = String(ready.get("error",""))
	THEME.apply_button(next_button,true,17,Vector2(170,46))
	next_button.disabled = not allowed

# ---------------------------------------------------------------- building blocks

func _label(text_value: String, size_value: int, tint: Color) -> Label:
	var label := Label.new(); label.text = text_value
	label.add_theme_font_size_override("font_size",size_value)
	label.add_theme_color_override("font_color",tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 200
	return label

func _chip(text_value: String, tint: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := THEME.panel(Color(tint.r,tint.g,tint.b,0.12),Color(tint.r,tint.g,tint.b,0.6),10,1)
	style.content_margin_left = 8; style.content_margin_right = 8; style.content_margin_top = 2; style.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel",style)
	chip.add_child(_label(text_value,12,tint.lightened(0.2)))
	return chip

func _card_button(node_name: String, selected: bool, size_value: Vector2) -> Button:
	var card := Button.new()
	card.name = node_name
	card.custom_minimum_size = size_value
	card.toggle_mode = false
	card.focus_mode = Control.FOCUS_ALL
	var normal := THEME.panel(Color("3a2716") if selected else CARD,THEME.HIGHLIGHT_GOLD if selected else CARD_BORDER,8,3 if selected else 1)
	normal.set_content_margin_all(12)
	var hover := THEME.panel(Color("33241a"),THEME.GOLD,8,2); hover.set_content_margin_all(12)
	var disabled := THEME.panel(Color("1d150f"),Color("3a2a1c"),8,1); disabled.set_content_margin_all(12)
	card.add_theme_stylebox_override("normal",normal)
	card.add_theme_stylebox_override("hover",hover if not selected else normal)
	card.add_theme_stylebox_override("pressed",normal)
	card.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	card.add_theme_stylebox_override("disabled",disabled)
	return card

## A content box that sizes the card button around it.
func _card_body(card: Button) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(12,12)
	card.add_child(box)
	box.resized.connect(func(): card.custom_minimum_size.y = box.size.y + 24.0; box.size.x = card.size.x - 24.0)
	card.resized.connect(func(): box.size.x = card.size.x - 24.0)
	return box

func _panel_box(parent: Node, size_value: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size_value
	var style := THEME.panel(CARD,CARD_BORDER,8,1); style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation",8)
	panel.add_child(box)
	return box

## A row of small pixel hearts, like the dungeon HUD (health per heart from
## slasher_balance.json "hud"; 1 with simple combat).
class HeartRow extends Control:
	var health := 0
	var maximum := 1
	static func per_heart() -> int:
		return maxi(1,int(Dictionary(GameBalance.get_slasher_balance("hud")).get("health_per_heart",4)))
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(minf(10.0,ceil(maximum / float(per_heart()))) * 17.0,15)
	func _draw() -> void:
		var per := float(per_heart())
		var hearts := int(ceil(maximum / per))
		for index in mini(hearts,10):
			var filled := clampf(float(health - index * per) / per,0.0,1.0)
			var at := Vector2(index * 17.0,0)
			var shape := [".XX.XX.","XXXXXXX","XXXXXXX",".XXXXX.","..XXX..","...X..."]
			for y in shape.size():
				for x in 7:
					if String(shape[y])[x] != "X": continue
					var colour := Color("#d42a2a") if float(x) + 0.5 <= filled * 7.0 else Color("#3a2424")
					draw_rect(Rect2(at + Vector2(x,y) * 2.0,Vector2(2,2)),colour)

## A padlock and a "COMING SOON" ribbon over a locked destination's picture.
class LockBadge extends Control:
	var accent := Color("#c9a36a")
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.05,0.03,0.02,0.35))
		var centre := size * 0.5 + Vector2(0,-14)
		draw_circle(centre,34.0,Color(0.06,0.04,0.03,0.85))
		draw_arc(centre,34.0,0.0,TAU,48,accent.darkened(0.2),2.0,true)
		var metal := Color("#d8c39a"); var shade := Color("#7a6648")
		# Shackle, then the body with a keyhole.
		draw_arc(centre + Vector2(0,-6),10.0,PI,TAU,24,shade,7.0,true)
		draw_arc(centre + Vector2(0,-6),10.0,PI,TAU,24,metal,4.0,true)
		for side in [-10.0,10.0]: draw_line(centre + Vector2(side,-6),centre + Vector2(side,2),metal,4.0)
		var body := Rect2(centre + Vector2(-15,0),Vector2(30,22))
		draw_rect(body.grow(1.5),shade); draw_rect(body,metal)
		draw_rect(Rect2(body.position,Vector2(body.size.x,3)),metal.lightened(0.3))
		draw_circle(centre + Vector2(0,8),3.5,Color("#2a1d12"))
		draw_rect(Rect2(centre + Vector2(-1.5,9),Vector2(3,8)),Color("#2a1d12"))
		# Ribbon.
		var font := ThemeDB.fallback_font
		var text := "COMING SOON"
		var text_size := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,15)
		var ribbon := Rect2(Vector2((size.x - text_size.x) * 0.5 - 16,centre.y + 44),Vector2(text_size.x + 32,24))
		draw_rect(ribbon.grow(1.5),Color("#140b04")); draw_rect(ribbon,accent.darkened(0.45))
		draw_string(font,Vector2(ribbon.position.x + 16,ribbon.position.y + 17),text,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("#f2e3c4"))
