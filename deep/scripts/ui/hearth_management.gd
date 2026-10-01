extends ColorRect
class_name HearthManagement

signal manual_launch(dungeon_id: String, party: Array[String])
signal candidate_requested(candidate_id: String)
signal changed
signal closed

const THEME = preload("res://scripts/ui/tavern_ui_theme.gd")
const SECTIONS = ["Company","Armory","Expeditions","Facilities","Merchants","Reports"]
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
var bank_label: Label
var notice: Label
var body: VBoxContainer
var tabs: HBoxContainer

func _ready() -> void:
	color = Color(0.015,0.012,0.009,0.94)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right"]: margin.add_theme_constant_override("margin_"+side,48)
	for side in ["top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel",THEME.panel(Color("21160f"),Color("8c5a26"),8,2))
	margin.add_child(shell)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",12)
	shell.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	title_label = label("THE HEARTH",28,THEME.IVORY)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title_label)
	button(heading,"Return to Tavern",func(): hide(); closed.emit())
	bank_label = label("",16,THEME.GOLD)
	stack.add_child(bank_label)
	tabs = HBoxContainer.new()
	stack.add_child(tabs)
	for entry in SECTIONS: button(tabs,entry,show_section.bind(entry))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	notice = label("",16,THEME.IVORY)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(notice)
	var footer := HBoxContainer.new()
	stack.add_child(footer)
	button(footer,"Advance Day",func(): act(HearthCalendar.advance(campaign)))
	button(footer,"Advance to Next Event",func(): act(HearthCalendar.advance(campaign,112)))
	button(footer,"Buy 4 Supplies · 8g",_buy_supplies)
	section = initial_section
	hide()

func open(c: CampaignState, runtime: RunState, page: String = "Company") -> void:
	campaign = c
	state = runtime
	show()
	show_section(page)

func show_section(page: String) -> void:
	section = page
	refresh()

func refresh() -> void:
	if campaign == null or body == null: return
	# A number of controls refresh this page from their own pressed/toggled signal.
	# Destroying the emitting control synchronously is a native use-after-free in
	# Godot 4.7, so detach it now and defer destruction until the frame is safe.
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	title_label.text = section.to_upper()
	bank_label.text = "%s   •   Day %d   •   %dg   •   %d supplies   •   %d essence   •   Reputation %d   •   Rooms %d/%d" % [HearthCatalog.tier(campaign.establishment_tier).name,campaign.calendar_day,campaign.banked_gold,campaign.supplies,campaign.relic_essence,campaign.reputation,campaign.living_roster().size(),campaign.get_roster_capacity()]
	for child in tabs.get_children(): child.modulate = THEME.GOLD if child.text == section else Color.WHITE
	match section:
		"Company": company_page()
		"Armory": armory_page()
		"Expeditions": expedition_page()
		"Facilities": facilities_page()
		"Merchants": merchant_page()
		"Reports": reports_page()

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
	THEME.apply_button(result,false,15,Vector2(110,42))
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func card(title: String, description: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",THEME.panel(Color("302219"),Color("685031"),5,1))
	body.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	panel.add_child(content)
	content.add_child(label(title,20,THEME.GOLD))
	var copy := label(description)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(copy)
	return content

func act(result: Dictionary) -> void:
	notice.text = String(result.get("message",result.get("error","Updated.")))
	if result.get("ok",false):
		state.gold = campaign.banked_gold
		state.sync_campaign_runtime()
		# Management mutations use the same atomic commit path as floor entry. Keep
		# the call indirect here so UI cannot accidentally create a second save policy.
		if state != null and not bool(state.call("autosave_on_floor_entry")): notice.text += " Save failed: "+campaign.last_save_error
		changed.emit()
	refresh()

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

func company_page() -> void:
	card("Your company","Adventurers receive 20% of expedition gold collectively. Resting adventurers do not draw wages. Equipment stays with the Hearth when a recruit retires.")
	for member in campaign.living_roster():
		var content := card("%s · %s · Level %d" % [member.display_name,member.class_id.capitalize(),member.level],"%s   •   Age %d / retirement 60   •   Health %d/%d   •   %d victories\n%s" % [member.status.capitalize(),member.age_on(campaign.calendar_day),member.current_health,member.max_health,member.victories,member.biography])
		var actions := HBoxContainer.new()
		content.add_child(actions)
		button(actions,"Equipment",func(): member_id=member.id; show_section("Armory"))
		button(actions,"Train · %dg" % (15*member.level),func(): act(HearthFacilities.train(campaign,member.id)),member.status=="available")
		button(actions,"Retire",_confirm_retire.bind(member.id),member.status=="available")
		if member.recovery_until>campaign.calendar_day: content.add_child(label("Ready on Day %d" % member.recovery_until,15,THEME.MUTED))
	card("Arrivals","Contracts show signing costs before recruitment. Assess candidates through conversation to learn their strengths.")
	for candidate in campaign.get_candidates():
		var member := candidate.adventurer
		var content := card(member.display_name+" · "+member.class_id.capitalize(),"Signing fee %dg · 20%% collective expedition share · %s" % [member.signing_fee,candidate.motivation])
		button(content,"Meet and assess",func(): hide(); candidate_requested.emit(candidate.id))

func _confirm_retire(id: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Retire this adventurer permanently? Their equipment returns to the armory."
	dialog.confirmed.connect(func(): act(HearthCalendar.retire(campaign,campaign.character(id))); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func member_picker() -> CharacterRecord:
	var members := campaign.living_roster()
	if members.is_empty(): card("An empty company","Recruit an adventurer before assigning equipment."); return null
	if campaign.character(member_id)==null or campaign.character(member_id).status=="dead": member_id=members[0].id
	var picker := OptionButton.new()
	for member in members:
		picker.add_item(member.display_name+" · "+member.class_id.capitalize()+" · "+member.status)
		if member.id==member_id: picker.select(picker.item_count-1)
	picker.item_selected.connect(func(index:int): member_id=members[index].id; refresh())
	body.add_child(picker)
	return campaign.character(member_id)

func armory_page() -> void:
	var member := member_picker()
	if member==null: return
	var page_body := body
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation",16)
	page_body.add_child(columns)
	var loadout_column := VBoxContainer.new()
	loadout_column.custom_minimum_size.x=360
	columns.add_child(loadout_column)
	var inventory_column := VBoxContainer.new()
	inventory_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	inventory_column.add_theme_constant_override("separation",10)
	columns.add_child(inventory_column)
	body=loadout_column
	var slots := card("%s’s loadout" % member.display_name,"Select equipment below to compare and assign. Each copy has one wearer. Away adventurers’ loadouts are locked.")
	for slot in ["weapon","armor","accessory","relic"]:
		var id: String = member.equipment.get(slot,"")
		var entry := HearthCatalog.item(String(Dictionary(campaign.armory.get(id,{})).get("item_id","")))
		var row := HBoxContainer.new()
		slots.add_child(row)
		var text_value := label("%s: %s" % [slot.capitalize(),entry.get("name","Empty")])
		text_value.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(text_value)
		button(row,"Unassign",func(): act(HearthArmory.unequip(campaign,member.id,slot)),not id.is_empty() and member.status=="available")
	body=inventory_column
	var filters := HBoxContainer.new()
	body.add_child(filters)
	for slot in ["all","weapon","armor","accessory","relic"]: button(filters,slot.capitalize(),func(): slot_filter=slot; refresh())
	for id in campaign.armory:
		var instance: Dictionary = campaign.armory[id]
		var entry := HearthCatalog.item(instance.item_id)
		if slot_filter!="all" and entry.slot!=slot_filter: continue
		if entry.get("class_id",member.class_id)!=member.class_id: continue
		var owner := campaign.character(String(instance.owner))
		var content := card(entry.name+" · "+String(entry.rarity).capitalize(),entry.description+"\n"+("Available in storage" if owner==null else "Assigned to "+owner.display_name))
		var equipped: Dictionary = campaign.armory.get(member.equipment.get(entry.slot,""),{})
		var previous := HearthCatalog.item(String(equipped.get("item_id","")))
		var comparison: Array[String] = []
		var keys: Dictionary = Dictionary(entry.modifiers).duplicate()
		keys.merge(Dictionary(previous.get("modifiers",{})))
		for stat in keys:
			var delta := float(entry.modifiers.get(stat,0))-float(Dictionary(previous.get("modifiers",{})).get(stat,0))
			comparison.append("%s %+.1f" % [String(stat).replace("_"," "),delta])
		if entry.slot=="weapon": comparison.append("damage %+d" % (int(entry.damage)-int(previous.get("damage",0))))
		var differences := label("Compared with equipped: "+", ".join(comparison),14,THEME.MUTED)
		differences.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		content.add_child(differences)
		var actions := HBoxContainer.new()
		content.add_child(actions)
		button(actions,"Equip",func(): act(HearthArmory.equip(campaign,member.id,id)),owner==null and member.status=="available")
		button(actions,"Sell · %dg" % int(entry.price/3),func(): act(HearthArmory.sell(campaign,id)),owner==null and not instance.bound)
	body=loadout_column
	var provisions := card("Consumables · %d/4" % member.provisions.size(),", ".join(member.provisions) if not member.provisions.is_empty() else "No consumables assigned.")
	for id in campaign.consumable_stock:
		if int(campaign.consumable_stock[id])>0: button(provisions,"Assign %s (%d stored)" % [String(id).replace("_"," "),campaign.consumable_stock[id]],func(): act(HearthArmory.provision(campaign,member.id,id)))
	body=page_body

func expedition_page() -> void:
	var unlocked: Array[String] = []
	var picker := OptionButton.new()
	for id in HearthCatalog.data().dungeon_levels:
		if state.is_dungeon_unlocked(id):
			unlocked.append(id)
			picker.add_item(GameBalance.get_dungeon(id).get("name",id))
	if not unlocked.has(dungeon_id): dungeon_id="forest"
	picker.select(maxi(0,unlocked.find(dungeon_id)))
	picker.item_selected.connect(func(index:int): dungeon_id=unlocked[index]; selected_party.clear(); refresh())
	body.add_child(picker)
	var party := card("Assemble the expedition","Seven days away. Survivors keep their equipment; deaths lose assigned gear. Retreat banks secured rewards without boss-clear credit.")
	selected_party = selected_party.filter(func(id:String): return campaign.character(id)!=null and campaign.character(id).status=="available")
	for member in campaign.living_roster():
		var check := CheckBox.new()
		check.text = "%s · %s L%d · %s · %d/%d HP" % [member.display_name,member.class_id,member.level,member.status,member.current_health,member.max_health]
		check.button_pressed=selected_party.has(member.id)
		check.disabled=member.status!="available"
		check.toggled.connect(func(on:bool):
			if on and selected_party.size()<campaign.get_party_cap(dungeon_id): selected_party.append(member.id)
			elif not on: selected_party.erase(member.id)
			refresh())
		party.add_child(check)
	var risk := HearthExpeditions.risk(campaign,selected_party,dungeon_id)
	card("%s risk · %d/%d adventurers" % [risk.band,selected_party.size(),campaign.get_party_cap(dungeon_id)],"\n".join(risk.reasons)+"\nKeeper retains 80%% of recovered gold. Expected return: Day %d." % (campaign.calendar_day+7))
	var controls := HBoxContainer.new()
	body.add_child(controls)
	for value in ["cautious","balanced","bold"]: button(controls,("✓ " if value==policy else "")+value.capitalize(),func(): policy=value; refresh())
	var readiness := HearthExpeditions.readiness(campaign,selected_party,dungeon_id)
	if not readiness.ok: body.add_child(label(readiness.error,16,THEME.MUTED))
	var launch := HBoxContainer.new()
	body.add_child(launch)
	button(launch,"Lead Expedition",func(): hide(); manual_launch.emit(dungeon_id,selected_party.duplicate()),readiness.ok)
	button(launch,"Dispatch Party",func(): act(HearthExpeditions.dispatch(campaign,selected_party,dungeon_id,policy)),readiness.ok and campaign.has_completed_dungeon(dungeon_id))
	if not campaign.has_completed_dungeon(dungeon_id): body.add_child(label("Manually clear this dungeon to unlock automated dispatch.",15,THEME.MUTED))
	for value in campaign.dispatches.values(): card("Party away · "+String(value.dungeon_id).capitalize(),"Return Day %d · %s retreat policy" % [value.due_day,value.retreat_policy])

func facilities_page() -> void:
	for rank in range(4):
		var tier := HearthCatalog.tier(rank)
		card(tier.name+(" · CURRENT" if rank==campaign.establishment_tier else ""),"%d rooms · %d expedition slots · Recruit levels %d–%d" % [tier.capacity,tier.expedition_slots,tier.recruit_levels[0],tier.recruit_levels[1]])
	var branches: Array = ["roster_services"]+HearthCatalog.data().facilities.keys()
	for branch in branches:
		var definition: Dictionary=HearthCatalog.data().facilities.get(branch,{"name":"Expand the Hearth","description":"Build the next authored wing and increase company capacity."})
		var cost := HearthFacilities.quote(campaign,branch)
		var text_value: String = definition.description
		if campaign.construction.has(branch): text_value+="\nConstruction completes Day %d." % campaign.construction[branch].due_day
		elif cost.available: text_value+="\n%d gold · %d essence · %d days · Tier %d · Reputation %d · %d manual clears" % [cost.gold,cost.essence,cost.days,int(cost.tier)+1,cost.get("reputation",0),cost.get("manual_clears",0)]
		else: text_value+="\n"+String(cost.error)
		var content := card("%s · Rank %d" % [definition.name,campaign.tavern_upgrades.get(branch,0)],text_value)
		button(content,"Commission",func(): act(HearthFacilities.purchase(campaign,branch)),cost.available)

func merchant_page() -> void:
	card("Hearth suppliers","Purchases go directly to permanent storage. Equipment stock refreshes each week. Dungeon-only relics must be recovered by an expedition.")
	for id in HearthCatalog.data().consumables:
		var content := card(GameBalance.get_consumable(id).get("name",id),"%d in storage" % int(campaign.consumable_stock.get(id,0)))
		button(content,"Buy · %dg" % (8 if id=="healing_potion" else 18),func(): act(HearthArmory.buy_consumable(campaign,id)))
	for id in HearthCatalog.data().items:
		var entry := HearthCatalog.item(id)
		if not entry.sources.has("merchant") or int(entry.tier)>campaign.establishment_tier: continue
		var content := card(entry.name+" · "+String(entry.slot).capitalize(),entry.description)
		button(content,"Buy · %dg" % entry.price,func(): act(HearthArmory.buy(campaign,id)))

func reports_page() -> void:
	if campaign.return_reports.is_empty(): card("The ledger awaits your first return","Every expedition records gold, contracts, equipment, survivors and losses here.")
	for index in range(campaign.return_reports.size()-1,-1,-1):
		var report: Dictionary=campaign.return_reports[index]
		card(report.headline,"Gross %dg − adventurer share %dg = net %dg · Essence %d\nReturned: %s\nLost: %s\nRecovered gear: %s\n%s" % [report.gold,report.share,report.net,report.essence,", ".join(report.returned),", ".join(report.lost),", ".join(report.items),"\n".join(report.events)])

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide()
		closed.emit()
		get_viewport().set_input_as_handled()
