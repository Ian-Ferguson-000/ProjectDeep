class_name EnemyCharacter
extends CharacterBody2D

signal state_changed(state: String)
signal respawned
@export var definition:EnemyDefinition
@export var profile: EnemyProfile
@export var patrol_route: NodePath
@onready var sprite: AnimatedSprite2D=$AnimatedSprite2D
@onready var health: HealthComponent=$HealthComponent
@onready var statuses: StatusComponent=$StatusComponent
@onready var health_bar: ProgressBar=$HealthBar
@onready var status_label: Label=$StatusLabel
@onready var collision: CollisionShape2D=$CollisionShape2D
var player: PlayerCharacter
var spawn_position:=Vector2.ZERO
var state:="patrol"
var patrol_index:=0
var attack_cooldown:=0.0
var attack_elapsed:=0.0
var attack_hit:=false
var defeated:=false
var alerted:=false
var knockback_velocity:=Vector2.ZERO
var respawn_timer:=0.0
var ability_cooldowns:Dictionary={}
var active_ability:EnemyAbility
var lunge_remaining:=0.0
var lunge_direction:=Vector2.ZERO
var lunge_hit:=false

## Registers enemy groups, captures the spawn point, configures health/status components, connects feedback
## signals, and initializes the health bar. The required named children must exist before this callback.
func _ready() -> void:
	add_to_group("spell_target"); add_to_group("combat_enemy")
	spawn_position=global_position
	_apply_definition()
	if not profile: profile=EnemyProfile.new()
	health.configure(profile.max_health,profile.defense,profile.vulnerabilities)
	statuses.setup(health)
	statuses.status_changed.connect(_on_status_changed)
	health.health_changed.connect(_update_health_bar); health.damage_received.connect(_on_damaged); health.died.connect(_on_died)
	health_bar.max_value=profile.max_health; health_bar.value=profile.max_health
	health_bar.visible=false

## Applies the root definition to profile, animations, collision dimensions, labels, and ability cooldowns.
func _apply_definition() -> void:
	if not definition:return
	profile=definition.profile
	if definition.sprite_frames: sprite.sprite_frames=definition.sprite_frames
	sprite.position=definition.sprite_offset; sprite.scale=definition.sprite_scale
	var capsule:=CapsuleShape2D.new(); capsule.radius=definition.collision_radius; capsule.height=definition.collision_height; collision.shape=capsule
	var name_label:=get_node_or_null("EnemyName") as Label
	if name_label:name_label.text=definition.display_name.to_upper()
	ability_cooldowns.clear()
	for ability in definition.abilities: ability_cooldowns[ability.ability_id]=0.0

## Chooses and executes attack, status lock, retreat, leash return, chase, or patrol each physics frame. It
## expects profile ranges to be non-negative and uses direct collision-aware steering rather than navigation
## paths.
func _physics_process(delta: float) -> void:
	if defeated:
		if respawn_timer>0:
			respawn_timer=max(0.0,respawn_timer-delta)
			if respawn_timer<=0: _respawn_after_cooldown()
		return
	if not is_instance_valid(player): player=get_tree().get_first_node_in_group("player")
	attack_cooldown=max(0.0,attack_cooldown-delta)
	for ability_id in ability_cooldowns: ability_cooldowns[ability_id]=max(0.0,float(ability_cooldowns[ability_id])-delta)
	knockback_velocity=knockback_velocity.move_toward(Vector2.ZERO,700.0*delta)
	if statuses.blocks_actions():velocity=knockback_velocity;move_and_slide();sprite.play(_animation_name("idle"));return
	if statuses.blocks_spells() and state in ["attack","lunge"]:active_ability=null;_set_state("chase")
	if state=="attack": _process_attack(delta); return
	if state=="lunge": _process_lunge(delta); return
	if statuses.blocks_movement(): velocity=knockback_velocity; move_and_slide(); sprite.play(_animation_name("idle")); return
	if not player: _patrol(delta); return
	var distance:=global_position.distance_to(player.global_position)
	if health.health_ratio()<=profile.retreat_health_ratio and _enabled(3): _retreat(delta); return
	if global_position.distance_to(spawn_position)>profile.leash_range: alerted=false; _move_to(spawn_position,delta,"return"); return
	if (alerted or distance<=profile.aggro_range) and _enabled(1):
		alerted=true
		health_bar.visible=true
		var ability:=_select_ability(distance)
		if ability: _begin_ability(ability)
		elif not definition or definition.abilities.is_empty():
			if distance<=profile.attack_range and attack_cooldown<=0 and _enabled(2): _begin_attack()
			else: _move_to(player.global_position,delta,"chase")
		else: _position_for_abilities(distance,delta)
	else: _patrol(delta)

## Selects the first ready ability whose activation range currently contains the player.
func _select_ability(distance:float) -> EnemyAbility:
	if not definition or statuses.blocks_spells():return null
	for ability in definition.abilities:
		if float(ability_cooldowns.get(ability.ability_id,0.0))<=0 and distance<=ability.range:return ability
	return null

## Kites when too close, otherwise chases until an ability reaches its preferred engagement band.
func _position_for_abilities(distance:float,delta:float) -> void:
	var primary:EnemyAbility=definition.abilities[0]
	if distance<primary.preferred_min_range:
		_move_to(global_position+(global_position-player.global_position).normalized()*100.0,delta,"kite")
	elif distance>primary.preferred_max_range:_move_to(player.global_position,delta,"chase")
	else: velocity=Vector2.ZERO; sprite.play(definition.idle_animation); _set_state("hold")

## Starts one data-driven ability, locks movement, and plays the configured attack animation.
func _begin_ability(ability:EnemyAbility) -> void:
	active_ability=ability; attack_elapsed=0.0; attack_hit=false; velocity=Vector2.ZERO
	sprite.play(definition.attack_animation); _set_state("attack")
	if player and abs(player.global_position.x-global_position.x)>2:sprite.flip_h=player.global_position.x<global_position.x

## Public hit entry point. Resolves damage through HealthComponent, alerts the enemy, applies supported
## statuses, and accumulates resisted knockback only when damage succeeds. Returns final damage dealt.
func receive_damage(packet: DamagePacket) -> int:
	var amount:=health.receive_damage(packet)
	if amount>0:
		alerted=true; statuses.apply(packet.status_effect,packet.status_power)
		knockback_velocity+=packet.direction*packet.knockback*(1.0-profile.knockback_resistance)
	return amount

## Moves between configured patrol markers, returns to spawn when no route exists, or idles when Patrol is
## disabled. Patrol markers must be world-stationary siblings, not children that move with the enemy.
func _patrol(delta: float) -> void:
	if not _enabled(0): velocity=knockback_velocity; move_and_slide(); sprite.play(_animation_name("idle")); _set_state("idle"); return
	var points:=_patrol_points()
	if points.is_empty(): _move_to(spawn_position,delta,"patrol"); return
	var destination:Vector2=points[patrol_index%points.size()]
	if global_position.distance_to(destination)<12: patrol_index=(patrol_index+1)%points.size(); destination=points[patrol_index]
	_move_to(destination,delta,"patrol")

## Moves away from the player or back toward spawn when the retreat distance has already been exceeded. Called
## only when Retreat is enabled and health is below the profile threshold.
func _retreat(delta: float) -> void:
	var away:=(global_position-player.global_position).normalized()
	var destination:=spawn_position if global_position.distance_to(spawn_position)>profile.retreat_range else global_position+away*profile.retreat_range
	_move_to(destination,delta,"retreat")

## Applies profile movement speed plus knockback, flips the side-facing sprite, calls move_and_slide(), plays
## Run, and publishes the requested state. Destination is a global position.
func _move_to(destination: Vector2, _delta: float, next_state: String) -> void:
	var direction:=(destination-global_position).normalized(); velocity=direction*profile.move_speed*statuses.movement_multiplier()+knockback_velocity
	if abs(direction.x)>0.05: sprite.flip_h=direction.x<0
	move_and_slide(); sprite.play(_animation_name("run")); _set_state(next_state)

## Stops normal movement, resets one-hit attack bookkeeping, faces the player, plays Attack, and enters the
## attack state. It does not apply damage immediately.
func _begin_attack() -> void:
	velocity=Vector2.ZERO; attack_elapsed=0.0; attack_hit=false; sprite.play(_animation_name("attack")); _set_state("attack")
	if player and abs(player.global_position.x-global_position.x)>2: sprite.flip_h=player.global_position.x<global_position.x

## Advances attack wind-up, applies exactly one melee packet if the player remains in range at impact time,
## then starts cooldown and returns to chase. Profile wind-up should align with the intended animation impact
## frame.
func _process_attack(delta: float) -> void:
	attack_elapsed+=delta; velocity=knockback_velocity; move_and_slide()
	if active_ability:
		if not attack_hit and attack_elapsed>=active_ability.windup:
			attack_hit=true; _execute_ability(active_ability)
		if state=="lunge":return
		if attack_elapsed>=max(active_ability.windup+0.2,0.45):
			ability_cooldowns[active_ability.ability_id]=active_ability.cooldown; active_ability=null; _set_state("chase")
		return
	if not attack_hit and attack_elapsed>=profile.attack_windup:
		attack_hit=true
		if player and global_position.distance_to(player.global_position)<=profile.attack_range+12:
			var direction:=(player.global_position-global_position).normalized()
			player.receive_damage(DamagePacket.create(self,profile.attack_damage,profile.attack_damage_type,"",0,profile.attack_knockback,direction))
	if attack_elapsed>=max(profile.attack_windup+0.2,0.5):
		attack_cooldown=profile.attack_cooldown; _set_state("chase")

## Executes melee, projectile, area, or lunge behavior using the common DamagePacket contract.
func _execute_ability(ability:EnemyAbility) -> void:
	if not player:return
	var direction:=(player.global_position-global_position).normalized()
	match ability.kind:
		EnemyAbility.Kind.PROJECTILE:
			var projectile:=EnemyProjectile.new(); get_parent().add_child(projectile); projectile.setup(global_position,direction,ability,self)
		EnemyAbility.Kind.AREA:
			if global_position.distance_to(player.global_position)<=ability.area_radius: player.receive_damage(DamagePacket.create(self,ability.damage,ability.damage_type,ability.status_effect,ability.status_power,ability.knockback,direction))
		EnemyAbility.Kind.LUNGE:
			lunge_direction=direction; lunge_remaining=ability.lunge_duration; lunge_hit=false; _set_state("lunge")
		_:
			if global_position.distance_to(player.global_position)<=ability.range+12: player.receive_damage(DamagePacket.create(self,ability.damage,ability.damage_type,ability.status_effect,ability.status_power,ability.knockback,direction))

## Advances a collision-aware lunge and applies its packet once when the player enters the attack radius.
func _process_lunge(delta:float) -> void:
	if not active_ability:return
	velocity=lunge_direction*active_ability.lunge_speed; move_and_slide(); lunge_remaining-=delta
	if not lunge_hit and player and global_position.distance_to(player.global_position)<=active_ability.area_radius:
		lunge_hit=true; player.receive_damage(DamagePacket.create(self,active_ability.damage,active_ability.damage_type,active_ability.status_effect,active_ability.status_power,active_ability.knockback,lunge_direction))
	if lunge_remaining<=0:
		ability_cooldowns[active_ability.ability_id]=active_ability.cooldown; active_ability=null; velocity=Vector2.ZERO; _set_state("chase")

## Signal handler that shows shared damage feedback and reveals the health bar. It
## expects already-resolved positive damage.
func _on_damaged(_amount: int, _packet: DamagePacket) -> void:
	CombatFeedback.spawn(self,_amount,_packet)
	health_bar.visible=true
## Marks the enemy defeated, removes it from projectile targeting, hides it, disables collision deferred,
## stops movement, and enters Dead. The node is retained so encounters can reset it.
func _on_died(_packet: DamagePacket) -> void:
	GameState.record_enemy_defeat(profile.journal_id if not profile.journal_id.is_empty() else profile.enemy_id)
	remove_from_group("spell_target")
	respawn_timer=max(0.0,profile.respawn_time)
	defeated=true; visible=false; collision.set_deferred("disabled",true); velocity=Vector2.ZERO; _set_state("dead")

## Restores the encounter after its configured death cooldown and announces the completed respawn.
func _respawn_after_cooldown() -> void:
	reset_combat()
	respawned.emit()
## Restores spawn position, visibility, collision, health, statuses, cooldowns, patrol index, and AI state.
## Called by Main after player defeat.
func reset_combat() -> void:
	global_position=spawn_position; defeated=false; visible=true; collision.set_deferred("disabled",false)
	if not is_in_group("spell_target"): add_to_group("spell_target")
	respawn_timer=0; alerted=false; attack_cooldown=0; attack_elapsed=0; active_ability=null; lunge_remaining=0; knockback_velocity=Vector2.ZERO; patrol_index=0
	for ability_id in ability_cooldowns: ability_cooldowns[ability_id]=0.0
	statuses.clear(); health.reset_health(); sprite.play(_animation_name("idle")); _set_state("patrol")
	health_bar.visible=false

## Reports whether this retained encounter node may currently receive and intercept spell projectiles.
func is_combat_target_active() -> bool:
	return not defeated and visible and health and health.current_health>0

## Synchronizes bar range/value and shows it only while damaged and alive. Connected to
## HealthComponent.health_changed.
func _update_health_bar(current: int, maximum: int) -> void:
	health_bar.max_value=maximum; health_bar.value=current; health_bar.visible=current<maximum and current>0
## Rebuilds the overhead status string from active status keys. Signal arguments are informational;
## StatusComponent.effects is authoritative.
func _on_status_changed(_effect: String, _active: bool) -> void:
	status_label.text=" • ".join(statuses.effects.keys()).to_upper()
## Changes state and emits state_changed only when the value actually differs. Use this instead of assigning
## state when listeners need notification.
func _set_state(next: String) -> void:
	if state!=next: state=next; state_changed.emit(state)
## Resolves definition-specific animation names while preserving legacy Kobold defaults.
func _animation_name(kind:String) -> String:
	if not definition:return kind
	match kind:
		"run":return definition.run_animation
		"attack":return definition.attack_animation
		_:return definition.idle_animation
## Tests a behavior bit in profile.enabled_behaviors. Callers use the fixed Patrol/Chase/Melee/Retreat bit
## order documented above.
func _enabled(bit: int) -> bool: return profile.enabled_behaviors & (1<<bit) != 0
## Resolves the exported route and returns child Marker2D global positions. An empty/missing path safely
## returns an empty array.
func _patrol_points() -> Array[Vector2]:
	var result:Array[Vector2]=[]
	if patrol_route.is_empty(): return result
	var route:=get_node_or_null(patrol_route)
	if route:
		for point in route.get_children():
			if point is Marker2D: result.append(point.global_position)
	return result
