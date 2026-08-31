class_name PlayerMenu
extends Control

signal close_requested
signal soul_space_requested

@onready var tabs:TabContainer=%Tabs
@onready var rune_filter:OptionButton=%RuneFilter
@onready var rune_list:VBoxContainer=%RuneList
@onready var rune_details:RichTextLabel=%RuneDetails
@onready var rune_action:Button=%RuneAction
@onready var stats_text:RichTextLabel=%StatsText
@onready var resource_list:VBoxContainer=%ResourceList
@onready var journal_list:VBoxContainer=%JournalList
@onready var journal_portrait:TextureRect=%JournalPortrait
@onready var journal_details:RichTextLabel=%JournalDetails
var player:PlayerCharacter
var selected_rune:Dictionary={}
var selected_enemy_id:=""
var equip_slot:OptionButton
var form_filter:OptionButton
var runes:Array=[]
var item_texture:Texture2D=preload("res://assets/pixel_art/starter_atlas.png")
var item_holder_texture:Texture2D=preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Paper UI Pack/Plain/3 Item Holder/1.png")

## Builds page interactions, connects global refresh signals, and performs the initial menu population.
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	runes=RuneLibrary.load_runes()
	equip_slot=OptionButton.new();equip_slot.position=Vector2(370,18);equip_slot.size=Vector2(180,40)
	for slot in 4:equip_slot.add_item("Equip to Slot %d"%(slot+1))
	equip_slot.select(GameState.selected_spell_slot);tabs.get_node("Runes").add_child(equip_slot)
	form_filter=OptionButton.new();form_filter.position=Vector2(570,18);form_filter.size=Vector2(190,40);form_filter.add_item("All forms")
	for form in StarterRunes.FORMS:form_filter.add_item(str(form).capitalize())
	form_filter.item_selected.connect(func(_index):_refresh_runes());tabs.get_node("Runes").add_child(form_filter)
	if rune_filter.item_count>0: rune_filter.select(0)
	## Relays the scene button without coupling it to Main's overlay ownership.
	%CloseButton.pressed.connect(func(): close_requested.emit())
	## Requests the mutually exclusive transition into the drawing interface.
	%OpenSoulSpace.pressed.connect(func(): soul_space_requested.emit())
	## Rebuilds catalog rows whenever the chosen element filter changes.
	rune_filter.item_selected.connect(func(_index): _refresh_runes())
	rune_action.pressed.connect(_rune_action_pressed)
	## Refreshes live data whenever keyboard or mouse navigation changes pages.
	tabs.tab_changed.connect(func(_index): refresh_all())
	GameState.inventory_changed.connect(refresh_all)
	GameState.runes_changed.connect(refresh_all)
	GameState.soul_grid_changed.connect(func(_size,_segments,_placements):_refresh_runes())
	GameState.active_grid_runes_changed.connect(func(_ids):_refresh_runes())
	## Updates objective text in the live Stats page.
	GameState.objective_changed.connect(func(_text): _refresh_stats())
	## Refreshes mode labels and Dev-only journal visibility.
	GameState.game_mode_changed.connect(func(_mode): refresh_all())
	## Rebuilds counts and newly revealed enemy rows after a defeat.
	GameState.journal_changed.connect(func(_id,_count): _refresh_journal())
	refresh_all()

## Binds the live player used by the Stats page and connects its changing health and status state.
func bind_player(value: PlayerCharacter) -> void:
	player=value
	if player:
		## Mirrors current and maximum health without storing a duplicate menu value.
		player.health_changed.connect(func(_current,_maximum): _refresh_stats())
		## Rebuilds the active-effects line when a runtime status starts or ends.
		player.status_changed.connect(func(_effect,_active): _refresh_stats())
		## Refreshes live mana values while regenerating or channeling spells.
		player.mana_changed.connect(func(_current,_maximum):_refresh_stats())
	_refresh_stats()

## Refreshes all four pages so opening or changing tabs never presents stale run state.
func refresh_all() -> void:
	if not is_node_ready(): return
	_refresh_runes(); _refresh_stats(); _refresh_resources(); _refresh_journal()

## Rebuilds the filtered rune list with explicit hotbar, grid activation, detection, and crafting states.
func _refresh_runes() -> void:
	if not rune_list: return
	_clear_children(rune_list)
	var selected_filter:=maxi(0,rune_filter.selected)
	var filter_name:=rune_filter.get_item_text(selected_filter).to_lower().replace(" elements","")
	var selected_form:=form_filter.get_item_text(form_filter.selected).to_lower().replace(" forms","")
	for rune in runes:
		if filter_name!="all" and rune.element!=filter_name: continue
		if selected_form!="all" and rune.form!=selected_form:continue
		var id:=str(rune.id); var button:=Button.new()
		var marker:=_rune_state_marker(id,rune)
		button.text=marker+str(rune.name); button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.custom_minimum_size.y=54; button.add_theme_stylebox_override("normal",_item_style())
		button.pressed.connect(_select_rune.bind(id)); rune_list.add_child(button)
	if selected_rune.is_empty() and not runes.is_empty(): selected_rune=runes[0]
	_update_rune_details()

## Returns the Player Menu marker for equipped, active, crafted-inactive, detected, ready, or locked runes.
func _rune_state_marker(id:String,rune:Dictionary) -> String:
	if id in GameState.equipped_runes:return "[SLOT %d] "%(GameState.equipped_runes.find(id)+1)
	if GameState.is_rune_active_in_grid(id):return "[ACTIVE IN GRID] "
	if id in GameState.discovered_runes:return "[CRAFTED — ARRANGE IN SOUL SPACE] "
	if GameState.soul_grid_placements.has(id):return "[DETECTED — CRAFT TO ACTIVATE] "
	return "[READY] " if GameState.can_craft(rune.costs) else "[LOCKED] "

## Selects a rune through the canonical library and updates the detail/action panel.
func _select_rune(id: String) -> void:
	selected_rune=RuneLibrary.get_rune(id); _update_rune_details()

## Formats selected rune identity, combat data, path, recipe, and the appropriate craft/equip action.
func _update_rune_details() -> void:
	if selected_rune.is_empty(): return
	var costs:Array[String]=[]
	for item in selected_rune.costs: costs.append("%s ×%d" % [_resource_name(item),selected_rune.costs[item]])
	rune_details.text="[font_size=28]%s[/font_size]\n%s • %s • Invocation %s\n\n%s\n\nPower %s    Mana %s    Range %s    Cooldown %ss\nDamage %s    Targeting %s    Status %s (%s)\n\nPath: %s\nRecipe: %s" % [selected_rune.name,str(selected_rune.element).capitalize(),str(selected_rune.form).capitalize(),selected_rune.invocation,selected_rune.description,selected_rune.power,selected_rune.mana_cost,selected_rune.range,selected_rune.cooldown,str(selected_rune.damage_type).capitalize(),str(selected_rune.targeting).replace("_"," ").capitalize(),str(selected_rune.status_effect).replace("_"," ").capitalize(),selected_rune.status_power,RuneLibrary.path_text(selected_rune.path),", ".join(costs)]
	var id:=str(selected_rune.id)
	if id in GameState.discovered_runes:
		rune_action.text="Equip to Slot %d"%(equip_slot.selected+1) if GameState.is_rune_active_in_grid(id) else "Arrange in Soul Space"
		rune_action.disabled=not GameState.is_rune_active_in_grid(id)
	else: rune_action.text="Craft Rune"; rune_action.disabled=not GameState.can_craft(selected_rune.costs)

## Crafts the selected unknown rune or equips it when already discovered, then refreshes dependent pages.
func _rune_action_pressed() -> void:
	if selected_rune.is_empty(): return
	var id:=str(selected_rune.id)
	if id in GameState.discovered_runes and GameState.is_rune_active_in_grid(id): GameState.equip_rune(id,equip_slot.selected)
	else: GameState.craft_rune(selected_rune)
	refresh_all()

## Builds the live combat sheet from PlayerCharacter, HealthComponent, StatusComponent, and equipped rune data.
func _refresh_stats() -> void:
	if not stats_text: return
	if not player: stats_text.text="Player data becomes available after entering the world."; return
	var health_value:=player.health.current_health if player.health else player.max_health
	var effects:="None" if not player.statuses or player.statuses.effects.is_empty() else " • ".join(player.statuses.effects.keys()).capitalize()
	var rune:=RuneLibrary.get_rune(GameState.equipped_rune)
	var rune_sheet:="No rune equipped."
	if not rune.is_empty(): rune_sheet="[font_size=22]Equipped Rune: %s[/font_size]\nPower %s • Range %s • Cooldown %ss\n%s damage • %s targeting • %s status" % [rune.name,rune.power,rune.range,rune.cooldown,str(rune.damage_type).capitalize(),str(rune.targeting).replace("_"," ").capitalize(),str(rune.status_effect).replace("_"," ").capitalize()]
	var mana_value:float=player.spell_caster.current_mana if player.spell_caster else 0.0
	stats_text.text="[font_size=30]Player Combat Sheet[/font_size]\n\nVitality: %d / %d\nMana: %.0f / %.0f\nDefense: %d\nMovement Speed: %.0f\nDash: %d physical • %.2fs cooldown\nMode: %s\nActive Effects: %s\n\n%s\n\n[font_size=20]Current Objective[/font_size]\n%s" % [health_value,player.max_health,mana_value,player.spell_caster.max_mana if player.spell_caster else 0.0,player.defense,player.speed,player.dash_damage,player.dash_cooldown_time,"Developer" if GameState.is_dev_mode() else "Story",effects,rune_sheet,GameState.objective_text()]

## Rebuilds resource cards from all inventory keys, including generic presentation for future resources.
func _refresh_resources() -> void:
	if not resource_list: return
	_clear_children(resource_list)
	for resource_id in GameState.inventory:
		var card:=PanelContainer.new(); card.add_theme_stylebox_override("panel",_item_style()); resource_list.add_child(card)
		var row:=HBoxContainer.new(); row.custom_minimum_size=Vector2(0,86); card.add_child(row)
		var icon:=TextureRect.new(); icon.custom_minimum_size=Vector2(72,72); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; icon.texture=_resource_icon(resource_id); row.add_child(icon)
		var text:=Label.new(); text.custom_minimum_size=Vector2(760,72); text.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; text.add_theme_font_size_override("font_size",18); text.text="%s    × %d\n%s" % [_resource_name(resource_id),GameState.inventory[resource_id],_resource_description(resource_id)]; row.add_child(text)

## Rebuilds journal buttons using Story discovery rules or Dev visibility and keeps details synchronized.
func _refresh_journal() -> void:
	if not journal_list: return
	_clear_children(journal_list)
	for entry in EnemyJournal.all():
		var discovered:=GameState.is_enemy_discovered(entry.enemy_id); var button:=Button.new()
		button.text=(entry.display_name+"  •  Defeated %d" % GameState.enemy_defeat_count(entry.enemy_id)) if discovered else "????  •  Undiscovered"
		button.alignment=HORIZONTAL_ALIGNMENT_LEFT; button.custom_minimum_size.y=58; button.add_theme_stylebox_override("normal",_item_style()); button.pressed.connect(_select_enemy.bind(entry.enemy_id)); journal_list.add_child(button)
	if selected_enemy_id.is_empty() and not EnemyJournal.all().is_empty(): selected_enemy_id=EnemyJournal.all()[0].enemy_id
	_update_journal_details()

## Selects an enemy journal ID and redraws its discovered or silhouette detail presentation.
func _select_enemy(enemy_id: String) -> void:
	selected_enemy_id=enemy_id; _update_journal_details()

## Displays the selected enemy portrait and full combat lore, or hides it behind an unknown silhouette.
func _update_journal_details() -> void:
	var entry:=EnemyJournal.get_entry(selected_enemy_id)
	if not entry: return
	var discovered:=GameState.is_enemy_discovered(entry.enemy_id)
	journal_portrait.texture=entry.portrait; journal_portrait.modulate=Color.WHITE if discovered else Color(0.05,0.04,0.06,1)
	if not discovered: journal_details.text="[font_size=30]Unknown Creature[/font_size]\n\nDefeat this enemy to record its identity and combat information."; return
	var multipliers:Array[String]=[]
	for type in entry.vulnerabilities: multipliers.append("%s %.2fx" % [str(type).capitalize(),entry.vulnerabilities[type]])
	journal_details.text="[font_size=30]%s[/font_size]\n%s • Defeated %d\n\n%s\n\nHabitat: %s\nBehavior: %s\n\nHP %d    Defense %d    Attack %d %s\nVulnerabilities: %s" % [entry.display_name,entry.category,GameState.enemy_defeat_count(entry.enemy_id),entry.description,entry.habitat,entry.behavior_summary,entry.max_health,entry.defense,entry.attack_damage,entry.damage_type.capitalize(),", ".join(multipliers)]

## Removes dynamic list children safely at the end of the current frame.
func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

## Converts a resource ID into a readable title used by cards and recipes.
func _resource_name(resource_id: String) -> String:
	return resource_id.replace("_"," ").capitalize()

## Returns authored starter-resource lore and a safe generic description for future keys.
func _resource_description(resource_id: String) -> String:
	match resource_id:
		"sun_shard": return "A warm resonant crystal used to stabilize forceful rune patterns."
		"moon_moss": return "Luminous moss that binds subtle and aetheric rune structures."
		_: return "A crafting resource carried within the alchemist's soul space."

## Creates atlas-backed starter resource icons and returns null for unknown future resources.
func _resource_icon(resource_id: String) -> Texture2D:
	var atlas:=AtlasTexture.new(); atlas.atlas=item_texture
	if resource_id=="sun_shard": atlas.region=Rect2(55,760,155,205)
	elif resource_id=="moon_moss": atlas.region=Rect2(235,755,220,205)
	else: return null
	return atlas

## Creates a reusable Humble Gift item-holder surface for generated rune, resource, and journal rows.
func _item_style() -> StyleBoxTexture:
	var style:=StyleBoxTexture.new(); style.texture=item_holder_texture
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_texture_margin(side,18.0)
	return style
