class_name SpellCaster
extends Node

signal actor_requested(actor:Node2D)
signal mana_changed(current:float,maximum:float)
signal spell_started(rune_id:String)
signal spell_stopped(rune_id:String)
signal cast_failed(reason:String)
signal cooldown_changed(rune_id:String,remaining:float)
@export var max_mana:=100.0
@export var mana_regeneration:=12.0
@export var regeneration_delay:=0.75
var current_mana:=100.0
var regeneration_left:=0.0
var cooldowns:Dictionary={}
var active_channel:SpellEffect
var active_channel_rune:Dictionary={}
var persistent:Dictionary={}
var weapon_infusion:Dictionary={}
var weapon_time:=0.0
var caster:Node2D
var state:Node

## Binds the owning player and initializes the full mana pool.
func setup(source:Node2D,game_state:Node=null) -> void:caster=source;state=game_state if game_state else get_node("/root/GameState");current_mana=max_mana;mana_changed.emit(current_mana,max_mana)

## Advances mana regeneration, per-rune cooldowns, weapon duration, and channel drain/termination.
func update(delta:float,casting_held:bool,can_act:bool) -> void:
	for id in cooldowns:
		cooldowns[id]=maxf(0.0,float(cooldowns[id])-delta);cooldown_changed.emit(id,cooldowns[id])
	regeneration_left=maxf(0.0,regeneration_left-delta)
	if active_channel:
		if not casting_held or not can_act or not is_instance_valid(active_channel):stop_channel()
		else:
			var cost:=float(active_channel_rune.mana_per_second)*delta
			if current_mana<cost:stop_channel()
			else:_spend_mana(cost)
	elif regeneration_left<=0 and current_mana<max_mana:
		current_mana=minf(max_mana,current_mana+mana_regeneration*delta);mana_changed.emit(current_mana,max_mana)
	weapon_time=maxf(0.0,weapon_time-delta)
	if weapon_time<=0:weapon_infusion={}

## Attempts the selected spell, validating equipment, cooldown, mana, and target before dispatching its form.
func cast_selected(origin:Vector2,aim_position:Vector2) -> bool:
	var rune:Dictionary=state.selected_rune()
	if rune.is_empty():return _fail("No rune equipped in this slot.")
	if float(cooldowns.get(rune.id,0.0))>0:return _fail("Spell is cooling down.")
	var direction:Vector2=(aim_position-origin).normalized();var target_position:=origin+(aim_position-origin).limit_length(float(rune.range)*32.0)
	if rune.form=="remote":
		var target:=_remote_target(target_position,float(rune.range)*32.0)
		if not target:return _fail("No valid target near the cursor.")
		if not _pay(rune):return false
		_damage_remote(target,rune);_start_cooldown(rune);return true
	if rune.form=="beam":return _start_channel(rune,origin,direction)
	if not _pay(rune):return false
	match str(rune.form):
		"particle":_spawn_projectile(rune,origin,direction)
		"scatter":_spawn_scatter(rune,origin,direction)
		"weapon":weapon_infusion=rune;weapon_time=float(rune.duration)
		"aura":
			if rune.status_effect in ["regeneration","fortify","haste"] and caster.get("statuses"):caster.statuses.apply(rune.status_effect,int(rune.status_power),float(rune.duration))
			_spawn_persistent(rune,origin,direction,origin)
		"summoned":_spawn_persistent(rune,origin,direction,target_position)
		"zone","trap","environmental":_spawn_persistent(rune,origin,direction,target_position)
		"rocket":_spawn_rocket(rune,origin,target_position)
		"wave":_spawn_effect(rune,origin,direction)
	_start_cooldown(rune);spell_started.emit(rune.id);return true

## Begins one held beam actor and pays only through continuous drain while the input remains held.
func _start_channel(rune:Dictionary,origin:Vector2,direction:Vector2) -> bool:
	if active_channel:return false
	if current_mana<=0:return _fail("Not enough mana.")
	active_channel_rune=rune;active_channel=SpellEffect.new().setup(caster,rune,origin,direction);actor_requested.emit(active_channel);spell_started.emit(rune.id);regeneration_left=regeneration_delay;return true

## Stops the maintained beam, starts its cooldown, and clears channel ownership safely.
func stop_channel() -> void:
	if not active_channel:return
	var id:=str(active_channel_rune.id);if is_instance_valid(active_channel):active_channel.queue_free()
	_start_cooldown(active_channel_rune);active_channel=null;active_channel_rune={};spell_stopped.emit(id)

## Spawns one existing projectile actor with complete rune metadata.
func _spawn_projectile(rune:Dictionary,origin:Vector2,direction:Vector2) -> void:actor_requested.emit(CleanseProjectile.new().setup(origin,direction,rune))

## Emits independently colliding projectiles across the rune's centered spread arc.
func _spawn_scatter(rune:Dictionary,origin:Vector2,direction:Vector2) -> void:
	var count:=int(rune.projectile_count);var spread:=deg_to_rad(float(rune.spread_angle))
	for index in count:
		var offset:=0.0 if count==1 else lerpf(-spread*0.5,spread*0.5,float(index)/float(count-1));_spawn_projectile(rune,origin,direction.rotated(offset))

## Creates a generic non-owned instantaneous spell actor.
func _spawn_effect(rune:Dictionary,position:Vector2,direction:Vector2) -> void:actor_requested.emit(SpellEffect.new().setup(caster,rune,position,direction))

## Spawns one rapid Rocket-form actor that detonates at the fixed range-clamped cursor point.
func _spawn_rocket(rune:Dictionary,origin:Vector2,target_position:Vector2) -> void:actor_requested.emit(SpellRocket.new().setup(caster,rune,origin,target_position))

## Adds a capped persistent actor and replaces the oldest owned instance when its per-form cap is reached.
func _spawn_persistent(rune:Dictionary,origin:Vector2,direction:Vector2,position:Vector2) -> void:
	var form:String=rune.form;var list:Array=persistent.get(form,[]);list=list.filter(func(actor):return is_instance_valid(actor) and not actor.is_queued_for_deletion())
	while list.size()>=int(rune.ownership_cap):var oldest=list.pop_front();oldest.queue_free()
	var actor:=SpellEffect.new().setup(caster,rune,position if form!="aura" else origin,direction);list.append(actor);persistent[form]=list;actor_requested.emit(actor)

## Finds the active target nearest the clamped cursor and rejects candidates outside cast range or selection radius.
func _remote_target(cursor:Vector2,range_pixels:float) -> Node2D:
	var best:Node2D;var distance:=48.0
	for target in get_tree().get_nodes_in_group("spell_target"):
		if not target is Node2D or not target.has_method("receive_damage") or caster.global_position.distance_to(target.global_position)>range_pixels:continue
		if target is CanvasItem and not target.visible:continue
		if target.has_method("is_combat_target_active") and not target.is_combat_target_active():continue
		var value:=cursor.distance_to(target.global_position)
		if value<distance:distance=value;best=target
	return best

## Applies an immediate remote DamagePacket without creating a traveling actor.
func _damage_remote(target:Node2D,rune:Dictionary) -> void:
	var direction:Vector2=(target.global_position-caster.global_position).normalized();target.receive_damage(DamagePacket.create(caster,int(rune.power),str(rune.damage_type),str(rune.status_effect),int(rune.status_power),float(rune.knockback),direction))

## Pays a discrete mana cost, reports failure without mutation, and delays regeneration after success.
func _pay(rune:Dictionary) -> bool:
	var cost:=float(rune.mana_cost)
	if current_mana<cost:return _fail("Not enough mana.")
	_spend_mana(cost);return true

## Deducts mana safely and emits its live HUD signal.
func _spend_mana(amount:float) -> void:current_mana=maxf(0.0,current_mana-amount);regeneration_left=regeneration_delay;mana_changed.emit(current_mana,max_mana)

## Starts the rune's independent cooldown and emits its initial value.
func _start_cooldown(rune:Dictionary) -> void:cooldowns[rune.id]=float(rune.cooldown);cooldown_changed.emit(rune.id,cooldowns[rune.id])

## Emits a user-facing failure and returns false for compact validation branches.
func _fail(reason:String) -> bool:cast_failed.emit(reason);return false

## Returns an infusion packet for the current dash or null when no Weapon spell is active.
func weapon_packet(direction:Vector2) -> DamagePacket:
	if weapon_infusion.is_empty():return null
	return DamagePacket.create(caster,int(weapon_infusion.power),str(weapon_infusion.damage_type),str(weapon_infusion.status_effect),int(weapon_infusion.status_power),float(weapon_infusion.knockback),direction)

## Clears channels, persistent actors, cooldowns, infusion, and restores full mana during combat reset.
func reset() -> void:
	stop_channel()
	for form in persistent:
		for actor in persistent[form]:if is_instance_valid(actor):actor.queue_free()
	persistent.clear();cooldowns.clear();weapon_infusion={};weapon_time=0;current_mana=max_mana;mana_changed.emit(current_mana,max_mana)
