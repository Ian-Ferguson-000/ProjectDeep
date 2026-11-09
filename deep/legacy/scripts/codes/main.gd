extends Node

var world_container: Node2D
var runtime_entities: Node2D
var player: PlayerCharacter
var prompt_label: Label
var message_label: Label
var objective_label: Label
var inventory_label: Label
var dev_badge: Label
var player_health_bar: ProgressBar
var player_mana_bar:ProgressBar
var hotbar_label:Label
var player_status_label: Label
var defeat_fade: ColorRect
var player_spawn:=Vector2.ZERO
var soul_panel: ColorRect
var player_menu: PlayerMenu
var message_timer := 0.0

## Builds world then UI, connects global signals, and performs initial objective/inventory refresh.
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	_build_world()
	_build_ui()
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.inventory_changed.connect(_refresh_inventory)
	GameState.runes_changed.connect(_refresh_inventory)
	_on_objective_changed(GameState.objective_text()); _refresh_inventory()

## Instantiates map/player/runtime roots, reads SpawnPoints/SouthSpawn, and wires player prompts, messages,
## projectiles, health, defeat, and statuses.
func _build_world() -> void:
	world_container=Node2D.new(); world_container.name="WorldContainer"; add_child(world_container)
	var map := preload("res://scenes/maps/StarterMap.tscn").instantiate(); world_container.add_child(map)
	runtime_entities=Node2D.new(); runtime_entities.name="RuntimeEntities"; add_child(runtime_entities)
	player_spawn=map.get_node("SpawnPoints/SouthSpawn").position
	player=preload("res://scenes/actors/Player.tscn").instantiate(); player.name="Player"; player.position=player_spawn; add_child(player)
	## Copies the player's current proximity prompt into the HUD when that label has been constructed.
	player.prompt_changed.connect(func(text): prompt_label.text=text if prompt_label else "")
	player.message_requested.connect(_show_message)
	## Parents newly cast projectiles under the runtime container so defeat cleanup can find them.
	player.projectile_requested.connect(func(shot): runtime_entities.add_child(shot))
	player.health_changed.connect(_on_player_health_changed)
	player.mana_changed.connect(_on_player_mana_changed)
	player.defeated.connect(_on_player_defeated)
	player.status_changed.connect(_on_player_status_changed)

## Creates the complete runtime HUD and centered Soul Space overlay, including Dev badge, vitality bar, defeat
## fade, and controls help.
func _build_ui() -> void:
	var canvas := CanvasLayer.new(); canvas.name="UI"; add_child(canvas)
	var top := ColorRect.new(); top.color=Color("#101522d8"); top.position=Vector2(16,16); top.size=Vector2(510,106); canvas.add_child(top)
	objective_label=_label(Vector2(16,10),Vector2(485,50),18); top.add_child(objective_label)
	inventory_label=_label(Vector2(16,66),Vector2(480,30),16); top.add_child(inventory_label)
	prompt_label=_label(Vector2(390,650),Vector2(500,34),20); prompt_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; canvas.add_child(prompt_label)
	message_label=_label(Vector2(240,590),Vector2(800,48),18); message_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; message_label.add_theme_color_override("font_color",Color("#fff1ad")); canvas.add_child(message_label)
	var help:=_label(Vector2(715,18),Vector2(550,35),14); help.text="WASD Move  •  E Interact  •  C Menu  •  R Soul Space  •  LMB Cast  •  RMB Dash"; help.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; canvas.add_child(help)
	dev_badge=_label(Vector2(1040,58),Vector2(220,40),20); dev_badge.text="DEV MODE • ∞ RESOURCES"; dev_badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; dev_badge.add_theme_color_override("font_color",Color("#ffcf58")); dev_badge.visible=GameState.is_dev_mode(); canvas.add_child(dev_badge)
	var health_text:=_label(Vector2(18,130),Vector2(120,28),16); health_text.text="VITALITY"; canvas.add_child(health_text)
	player_health_bar=ProgressBar.new(); player_health_bar.position=Vector2(18,158); player_health_bar.size=Vector2(250,20); player_health_bar.show_percentage=true; canvas.add_child(player_health_bar)
	player_health_bar.max_value=player.max_health; player_health_bar.value=player.max_health
	var mana_text:=_label(Vector2(18,184),Vector2(120,28),16);mana_text.text="MANA";canvas.add_child(mana_text)
	player_mana_bar=ProgressBar.new();player_mana_bar.position=Vector2(18,210);player_mana_bar.size=Vector2(250,20);player_mana_bar.max_value=100;player_mana_bar.value=100;player_mana_bar.show_percentage=true;canvas.add_child(player_mana_bar)
	hotbar_label=_label(Vector2(330,660),Vector2(620,44),17);hotbar_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;canvas.add_child(hotbar_label)
	player_status_label=_label(Vector2(280,152),Vector2(300,30),15); player_status_label.add_theme_color_override("font_color",Color("#ffcf58")); canvas.add_child(player_status_label)
	defeat_fade=ColorRect.new(); defeat_fade.color=Color(0.12,0,0,0); defeat_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); defeat_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE; defeat_fade.process_mode=Node.PROCESS_MODE_ALWAYS; canvas.add_child(defeat_fade)
	soul_panel=ColorRect.new(); soul_panel.name="SoulSpaceOverlay"; soul_panel.color=Color("#000000b0"); soul_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); soul_panel.visible=false; soul_panel.process_mode=Node.PROCESS_MODE_ALWAYS; canvas.add_child(soul_panel)
	var soul:=preload("res://scenes/ui/SoulSpace.tscn").instantiate()
	soul.set_anchors_preset(Control.PRESET_CENTER)
	soul.offset_left=-550.0; soul.offset_top=-325.0
	soul.offset_right=550.0; soul.offset_bottom=325.0
	soul.close_requested.connect(_toggle_soul_space)
	soul_panel.add_child(soul)
	player_menu=preload("res://scenes/ui/PlayerMenu.tscn").instantiate()
	player_menu.visible=false
	player_menu.close_requested.connect(_close_player_menu)
	player_menu.soul_space_requested.connect(_open_soul_from_player_menu)
	canvas.add_child(player_menu)
	player_menu.bind_player(player)

## Convenience factory for consistently positioned, wrapped Labels. Caller must parent and populate the
## result.
func _label(pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label:=Label.new(); label.position=pos; label.size=dimensions; label.add_theme_font_size_override("font_size",font_size); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; return label

## Opens/closes Soul Space for the configured action and consumes the event.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("soul_space"):
		_toggle_soul_space(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("player_menu"):
		_toggle_player_menu(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if soul_panel.visible: _set_soul_space_open(false); get_viewport().set_input_as_handled()
		elif player_menu.visible: _set_player_menu_open(false); get_viewport().set_input_as_handled()

## Toggles overlay visibility and pauses/unpauses the tree; the overlay remains processable while paused.
func _toggle_soul_space() -> void:
	_set_soul_space_open(not soul_panel.visible)

## Opens or closes Soul Space, closing the player menu first and synchronizing world pause state.
func _set_soul_space_open(open: bool) -> void:
	if open and player_menu: player_menu.visible=false
	soul_panel.visible=open
	if open: soul_panel.get_child(0).queue_redraw()
	_sync_pause_state()

## Toggles the parchment player menu from the dedicated input action.
func _toggle_player_menu() -> void:
	_set_player_menu_open(not player_menu.visible)

## Opens or closes the player menu, closing Soul Space first and refreshing its live page data.
func _set_player_menu_open(open: bool) -> void:
	if open:
		soul_panel.visible=false
		player_menu.refresh_all()
	player_menu.visible=open
	_sync_pause_state()

## Handles the menu close signal without changing the state of the other pause overlay.
func _close_player_menu() -> void:
	_set_player_menu_open(false)

## Transfers directly from the Runes page to Soul Space while preserving a single paused overlay.
func _open_soul_from_player_menu() -> void:
	_set_player_menu_open(false)
	_set_soul_space_open(true)

## Pauses gameplay exactly while either always-processing overlay is visible.
func _sync_pause_state() -> void:
	if (soul_panel.visible or (player_menu and player_menu.visible)) and player and player.spell_caster:player.spell_caster.stop_channel()
	get_tree().paused=soul_panel.visible or (player_menu and player_menu.visible)

## Counts down transient message display time and clears expired text.
func _process(delta: float) -> void:
	if message_timer>0:
		message_timer-=delta
		if message_timer<=0: message_label.text=""

## Displays interaction/combat guidance for five seconds.
func _show_message(text: String) -> void:
	message_label.text=text; message_timer=5.0
## Signal handler that updates the objective HUD when it exists.
func _on_objective_changed(text: String) -> void:
	if objective_label: objective_label.text="OBJECTIVE\n"+text
## Rebuilds material/equipped-rune HUD text from GameState.
func _refresh_inventory() -> void:
	if inventory_label:
		inventory_label.text="Sun Shard %d  •  Moon Moss %d  •  Rune: %s" % [GameState.inventory.get("sun_shard",0),GameState.inventory.get("moon_moss",0),GameState.equipped_rune if GameState.equipped_rune!="" else "none"]
	if hotbar_label:
		var slots:Array=[]
		for index in 4:
			var id:String=GameState.equipped_runes[index];var name:String=str(RuneLibrary.get_rune(id).get("name","Empty"))
			slots.append("[%d %s]"%[index+1,name] if index==GameState.selected_spell_slot else "%d %s"%[index+1,name])
		hotbar_label.text="   •   ".join(slots)

## Synchronizes the HUD vitality bar.
func _on_player_health_changed(current: int, maximum: int) -> void:
	if player_health_bar: player_health_bar.max_value=maximum; player_health_bar.value=current

## Synchronizes the HUD mana bar with the player's regenerating SpellCaster pool.
func _on_player_mana_changed(current:float,maximum:float) -> void:
	if player_mana_bar:player_mana_bar.max_value=maximum;player_mana_bar.value=current

## Rebuilds the player status HUD from the component’s active keys.
func _on_player_status_changed(_effect: String, _active: bool) -> void:
	if player_status_label and player.statuses: player_status_label.text=" • ".join(player.statuses.effects.keys()).to_upper()

## Disables player control, fades out, clears projectiles, resets every combat_enemy, respawns/heals the
## player, fades in, and restores input.
func _on_player_defeated() -> void:
	player.set_physics_process(false); defeat_fade.mouse_filter=Control.MOUSE_FILTER_STOP
	var fade:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS); fade.tween_property(defeat_fade,"color:a",0.9,0.35); await fade.finished
	for projectile in runtime_entities.get_children(): projectile.queue_free()
	for enemy in get_tree().get_nodes_in_group("combat_enemy"): enemy.reset_combat()
	player.reset_combat(player_spawn)
	var reveal:=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS); reveal.tween_property(defeat_fade,"color:a",0.0,0.45); await reveal.finished
	defeat_fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
