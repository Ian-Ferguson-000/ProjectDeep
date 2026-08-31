class_name PlayerCharacter
extends CharacterBody2D
signal prompt_changed(text: String)
signal message_requested(text: String)
signal projectile_requested(projectile: Node2D)
signal health_changed(current: int, maximum: int)
signal defeated
signal status_changed(effect: String, active: bool)
signal mana_changed(current:float,maximum:float)
var speed := 230.0
var cast_cooldown := 0.0
@export var max_health := 100
@export var defense := 0
@export var invulnerability_time := 0.55
@export_category("Dash Attack")
@export var dash_speed:=620.0
@export var dash_duration:=0.28
@export var dash_cooldown_time:=0.85
@export var dash_damage:=18
@export var dash_hit_radius:=40.0
@export var dash_knockback:=180.0
@export var draw_placeholder := true
@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var health: HealthComponent = get_node_or_null("HealthComponent")
@onready var statuses: StatusComponent = get_node_or_null("StatusComponent")
var facing := "down"
var invulnerability_left:=0.0
var knockback_velocity:=Vector2.ZERO
var dead:=false
var dash_direction:=Vector2.ZERO
var dash_remaining:=0.0
var dash_cooldown:=0.0
var dash_hit_targets:Dictionary={}
var spell_caster:SpellCaster

## Registers the player group, creates collision/camera, configures health/statuses, forwards component
## signals, and emits initial health. Scene instances should contain the named combat and animation children.
func _ready() -> void:
	add_to_group("player")
	collision_layer=2; collision_mask=1
	var shape := CollisionShape2D.new(); var capsule := CapsuleShape2D.new(); capsule.radius=13; capsule.height=34; shape.shape=capsule; add_child(shape)
	var camera := Camera2D.new(); camera.position_smoothing_enabled=true; camera.position_smoothing_speed=7; camera.limit_left=0; camera.limit_top=0; camera.limit_right=1280; camera.limit_bottom=896; add_child(camera)
	if health:
		health.configure(max_health,defense,{})
		## Forwards component health values through the player-facing signal consumed by the HUD.
		health.health_changed.connect(func(current,maximum): health_changed.emit(current,maximum))
		## Converts component death into the player's persistent dead flag and defeat signal.
		health.died.connect(func(_packet): dead=true; defeated.emit())
	## Forwards status activation/deactivation without exposing component ownership to UI consumers.
	if statuses: statuses.setup(health); statuses.status_changed.connect(func(effect,active): status_changed.emit(effect,active))
	spell_caster=SpellCaster.new();spell_caster.name="SpellCaster";add_child(spell_caster);spell_caster.setup(self)
	spell_caster.actor_requested.connect(func(actor):projectile_requested.emit(actor))
	spell_caster.mana_changed.connect(func(current,maximum):mana_changed.emit(current,maximum))
	spell_caster.cast_failed.connect(func(reason):message_requested.emit(reason))
	GameState.runes_changed.connect(_on_runes_changed)
	queue_redraw(); health_changed.emit(max_health,max_health)

## Updates invulnerability, knockback, movement/status locks, animation, nearby prompts/interactions, casting,
## and fallback drawing each physics frame.
func _physics_process(delta: float) -> void:
	invulnerability_left=max(0.0,invulnerability_left-delta)
	if health: health.invulnerable=invulnerability_left>0
	knockback_velocity=knockback_velocity.move_toward(Vector2.ZERO,850.0*delta)
	dash_cooldown=max(0.0,dash_cooldown-delta); cast_cooldown=max(0.0,cast_cooldown-delta)
	var can_cast:=not dead and not (statuses and statuses.blocks_actions()) and not (statuses and statuses.blocks_spells())
	spell_caster.update(delta,Input.is_action_pressed("cast_spell"),can_cast)
	for slot in 4:
		if Input.is_action_just_pressed("spell_slot_%d"%(slot+1)):GameState.select_spell_slot(slot)
	if Input.is_action_just_pressed("special_melee") and _can_dash(): _start_dash()
	if dash_remaining>0:
		_process_dash(delta); prompt_changed.emit(""); queue_redraw(); return
	var input := Input.get_vector("move_left","move_right","move_up","move_down") if not dead and not (statuses and statuses.blocks_movement()) else Vector2.ZERO
	velocity=input*speed*(statuses.movement_multiplier() if statuses else 1.0)+knockback_velocity; move_and_slide()
	_update_animation(input)
	var nearest := _nearest_interactable(); prompt_changed.emit(nearest.prompt() if nearest else "")
	if Input.is_action_just_pressed("interact") and nearest:
		message_requested.emit(nearest.interact(self))
	if Input.is_action_just_pressed("cast_spell") and can_cast:_cast()
	queue_redraw()

## Reports whether the player can begin a new dash based on life, cooldown, and status movement/action locks.
func _can_dash() -> bool:
	if dead or dash_cooldown>0 or dash_remaining>0: return false
	if statuses and (statuses.blocks_movement() or statuses.blocks_actions()): return false
	return global_position.distance_squared_to(get_global_mouse_position())>1.0

## Locks direction toward the cursor, starts the lunge animation, cooldown, and dash-long invulnerability.
func _start_dash() -> void:
	dash_direction=(get_global_mouse_position()-global_position).normalized()
	dash_remaining=dash_duration; dash_cooldown=dash_cooldown_time; dash_hit_targets.clear()
	knockback_velocity=Vector2.ZERO; facing=_facing_from_vector(dash_direction)
	invulnerability_left=max(invulnerability_left,dash_duration+0.08)
	if health: health.invulnerable=true
	if animated_sprite: animated_sprite.play("attack2_"+facing)

## Advances collision-aware dash movement and damages each active target at most once along the swept path.
func _process_dash(delta: float) -> void:
	var previous_position:=global_position
	velocity=dash_direction*dash_speed
	move_and_slide()
	_damage_dash_path(previous_position,global_position)
	dash_remaining=max(0.0,dash_remaining-delta)
	if dash_remaining<=0:
		velocity=Vector2.ZERO
		if animated_sprite: animated_sprite.play("idle_"+facing)

## Applies one physical melee packet to every eligible spell target intersecting the traveled line segment.
func _damage_dash_path(start: Vector2, finish: Vector2) -> void:
	for target in get_tree().get_nodes_in_group("spell_target"):
		if not _is_active_dash_target(target): continue
		var target_id:=target.get_instance_id()
		if dash_hit_targets.has(target_id): continue
		var closest:=Geometry2D.get_closest_point_to_segment(target.global_position,start,finish)
		if closest.distance_to(target.global_position)>dash_hit_radius: continue
		dash_hit_targets[target_id]=true
		var direction:Vector2=(target.global_position-start).normalized()
		target.receive_damage(DamagePacket.create(self,dash_damage,"physical","",0,dash_knockback,direction))
		var infusion:=spell_caster.weapon_packet(direction) if spell_caster else null
		if infusion:target.receive_damage(infusion)

## Rejects hidden, inactive, and non-damageable nodes from the dash attack's swept target query.
func _is_active_dash_target(target: Node) -> bool:
	if not is_instance_valid(target) or not target is Node2D or not target.has_method("receive_damage"): return false
	if target is CanvasItem and not target.visible: return false
	if target.has_method("is_combat_target_active") and not target.is_combat_target_active(): return false
	return true

## Converts an aim vector to the dominant-axis direction suffix used by the player SpriteFrames resource.
func _facing_from_vector(direction: Vector2) -> String:
	if abs(direction.x)>abs(direction.y): return "right" if direction.x>0 else "left"
	return "down" if direction.y>0 else "up"

## Selects dominant-axis facing, plays directional Run while moving, and preserves the last direction for
## Idle.
func _update_animation(input: Vector2) -> void:
	if not animated_sprite: return
	if input.length_squared() > 0.01:
		if abs(input.x) > abs(input.y): facing = "right" if input.x > 0 else "left"
		else: facing = "down" if input.y > 0 else "up"
		animated_sprite.play("run_" + facing)
	else:
		animated_sprite.play("idle_" + facing)

## Searches the interaction group for the closest visible node within 75 pixels. Returns null when nothing is
## eligible.
func _nearest_interactable() -> WorldInteractable:
	var best: WorldInteractable; var distance := 75.0
	for candidate in get_tree().get_nodes_in_group("interactable"):
		if not candidate.visible: continue
		var d := global_position.distance_to(candidate.global_position)
		if d < distance: distance=d; best=candidate
	return best

## Validates cooldown/equipment/action state, loads equipped rune metadata, starts cooldown, constructs a
## metadata-carrying projectile, and emits it for Main to parent.
func _cast() -> void:
	spell_caster.cast_selected(global_position,get_global_mouse_position())

## Stops an active held spell immediately when equipment or selected hotbar slot changes.
func _on_runes_changed() -> void:
	if spell_caster and spell_caster.active_channel:spell_caster.stop_channel()

## Cycles the four-slot hotbar with the mouse wheel while gameplay owns input.
func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var step:=-1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1;GameState.select_spell_slot(posmod(GameState.selected_spell_slot+step,4));get_viewport().set_input_as_handled()

## Public player hit interface. Resolves health damage, spawns feedback, starts invulnerability, applies
## statuses/knockback, flashes the sprite, and returns final damage.
func receive_damage(packet: DamagePacket) -> int:
	if dead or not health: return 0
	var amount:=health.receive_damage(packet)
	if amount>0:
		CombatFeedback.spawn(self,amount,packet)
		invulnerability_left=invulnerability_time
		if statuses: statuses.apply(packet.status_effect,packet.status_power)
		knockback_velocity+=packet.direction*packet.knockback
	return amount

## Restores position and control state, clears statuses/knockback/cooldowns, fully heals, and re-enables
## physics after defeat.
func reset_combat(spawn: Vector2) -> void:
	global_position=spawn; dead=false; cast_cooldown=0; dash_cooldown=0; dash_remaining=0; dash_hit_targets.clear(); invulnerability_left=0; knockback_velocity=Vector2.ZERO
	if statuses: statuses.clear()
	if health: health.reset_health()
	if spell_caster:spell_caster.reset()
	set_physics_process(true)

## Draws the old placeholder player and aim indicator only when draw_placeholder is enabled.
func _draw() -> void:
	if not draw_placeholder: return
	draw_circle(Vector2.ZERO,18,Color("#2a3f73")); draw_circle(Vector2(0,-7),10,Color("#f0c9a1")); draw_line(Vector2.ZERO,(get_global_mouse_position()-global_position).normalized()*28,Color("#fff6a5"),3)
