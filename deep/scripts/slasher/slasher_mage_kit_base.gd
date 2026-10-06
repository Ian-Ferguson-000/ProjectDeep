extends Node2D

const VISUALS := preload("res://scripts/slasher/slasher_mage_visuals.gd")
const FOREGROUND := preload("res://scripts/slasher/slasher_mage_foreground.gd")
var actor: SlasherPlayer
var clock := 0.0
var cast_serial := 0
var rewarded_casts: Dictionary = {}
var effects: Array[Dictionary] = []
var foreground: Node2D

func setup(player: SlasherPlayer) -> void:
	actor=player
	# Floor fields render below combatants; bolts and status indicators render above.
	z_index=-1
	foreground=FOREGROUND.new();foreground.kit=self;foreground.z_index=7;add_child(foreground)

func kit_id() -> String:return ""
func element() -> String:return "arcane"
func visual_element() -> String:return element()
func action_name(slot: String) -> String:return slot.capitalize()
func raw_tuning(_slot: String) -> Dictionary:return {}

func tuning(slot: String) -> Dictionary:
	var result := raw_tuning(slot).duplicate(true)
	var baseline := GameBalance.get_slasher_ability_tuning("mage",slot)
	var progressed := actor.run_state.get_effective_slasher_ability_tuning(slot)
	for key in ["damage_coefficient","cooldown"]:
		if result.has(key) and float(baseline.get(key,0.0))>0:
			result[key]=float(result[key])*float(progressed.get(key,baseline[key]))/float(baseline[key])
	return result

func attack_for(slot: String, source: String, resource_hit: bool = false) -> Dictionary:
	cast_serial+=1
	var attack := actor._configured_attack(tuning(slot),element())
	attack.merge({"mage_kit":kit_id(),"mage_visual_kit":kit_id(),"mage_cast":cast_serial,"mage_resource":resource_hit,"damage_source":source},true)
	return attack

func on_direct_hit(target: Node2D, attack: Dictionary) -> void:
	if String(attack.get("mage_kit",""))!=kit_id() or bool(attack.get("mage_secondary",false)):return
	if not (target is SlasherEnemy):return
	if bool(attack.get("mage_resource",false)):
		var serial := int(attack.get("mage_cast",-1))
		if not rewarded_casts.has(serial):
			rewarded_casts[serial]=4.0
			actor._award_resource(1)
			actor.resource_changed.emit(actor.run_state.class_resource,actor.run_state.get_class_resource_max())
	if not target.dead:on_primary_hit(target,attack)

func on_primary_hit(_target: SlasherEnemy, _attack: Dictionary) -> void:pass
func on_prevented_damage(_amount: int) -> void:pass
func defense_resource_gain() -> int:return 1
func absorb_damage(_amount: int) -> int:return 0

func hit(target: Node2D, attack: Dictionary, primary: bool = false) -> int:
	if not is_instance_valid(target) or not target.has_method("receive_attack"):return 0
	var dealt: int=target.receive_attack(attack,actor)
	if primary:
		on_direct_hit(target,attack)
		if actor.item_runtime and target.is_in_group("slasher_enemy"):
			actor.item_runtime.handle_event({"trigger":"hit","target":target,"attack":attack})
		var echo_multiplier := float(attack.get("echo_damage_multiplier",0.0))
		if echo_multiplier>0:
			var echo := secondary_copy(attack)
			echo.damage=maxi(1,int(round(int(attack.damage)*echo_multiplier)))
			target.receive_attack(echo,actor)
	return dealt

func secondary_copy(attack: Dictionary) -> Dictionary:
	var result := attack.duplicate(true)
	for key in ["mage_kit","mage_cast","mage_resource","echo_damage_multiplier","force_prism"]:result.erase(key)
	result["mage_secondary"]=true
	return result

func secondary_damage(amount: int, source: String) -> Dictionary:
	return {"damage":maxi(1,amount),"damage_type":element(),"damage_source":source,"mage_secondary":true,"knockback":0.0,"hit_stun_duration":0.0,"screen_shake_multiplier":0.0}

func enemies() -> Array[SlasherEnemy]:
	var result: Array[SlasherEnemy]=[]
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and is_instance_valid(node) and not node.dead and actor.get_parent().is_ancestor_of(node):result.append(node)
	return result

func hostile_shots() -> Array[SlasherHostileProjectile]:
	var result: Array[SlasherHostileProjectile]=[]
	for node in get_tree().get_nodes_in_group("slasher_hostile_projectile"):
		if node is SlasherHostileProjectile and not node.impacted and not is_instance_valid(node.deflected_by) and node.visual_type!="beam" and not node.get_meta("unblockable",false) and actor.get_parent().is_ancestor_of(node):result.append(node)
	return result

func clear_line(start: Vector2, end: Vector2) -> bool:
	if start.is_equal_approx(end):return true
	var query := PhysicsRayQueryParameters2D.create(start,end,1)
	query.exclude=[actor.get_rid()]
	for enemy in enemies():query.exclude.append(enemy.get_rid())
	for player in get_tree().get_nodes_in_group("slasher_player"):
		if player is SlasherPlayer and player!=actor:query.exclude.append(player.get_rid())
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	return result.is_empty() or not (result.collider is StaticBody2D)

func aimed_point(distance: float) -> Vector2:
	var offset := actor.get_global_mouse_position()-actor.global_position
	if Input.get_vector("slasher_aim_left","slasher_aim_right","slasher_aim_up","slasher_aim_down").length()>0.2:offset=actor.aim_direction*distance
	return actor._safe_destination(actor.global_position+offset.limit_length(distance))

func safe_move(destination: Vector2, result: Dictionary, protection: float = 0.2) -> Dictionary:
	var start := actor.global_position
	var end := actor._safe_destination(destination)
	if start.distance_to(end)<1:
		result.started=false;result.failure="No clear destination."
		return result
	actor.global_position=end;actor.invulnerable=maxf(actor.invulnerable,protection)
	result["invulnerability_granted"]=protection
	flash(start,40);flash(end,40)
	return result

func flash(center: Vector2, radius: float, kind: String = "burst", duration: float = 0.4) -> void:
	effects.append({"kind":kind,"center":center,"radius":radius,"left":duration,"duration":duration})
	while effects.size()>32:effects.pop_front()
	queue_redraw()
	if is_instance_valid(foreground):foreground.queue_redraw()

func arc(start: Vector2, end: Vector2) -> void:
	effects.append({"kind":"arc","a":start,"b":end,"left":0.2,"duration":0.2})
	while effects.size()>32:effects.pop_front()
	if is_instance_valid(foreground):foreground.queue_redraw()

func _physics_process(delta: float) -> void:
	clock+=delta
	for id in rewarded_casts.keys():
		rewarded_casts[id]-=delta
		if float(rewarded_casts[id])<=0:rewarded_casts.erase(id)
	for index in range(effects.size()-1,-1,-1):
		effects[index].left-=delta
		if float(effects[index].left)<=0:effects.remove_at(index)
	queue_redraw()
	if is_instance_valid(foreground):foreground.queue_redraw()

func _draw() -> void:
	var tint := VISUALS.color_for(visual_element())
	for effect in effects:
		var progress := clampf(1-float(effect.left)/float(effect.duration),0,1)
		if effect.kind!="arc":VISUALS.burst(self,to_local(effect.center),float(effect.radius),progress,tint,visual_element())

func draw_foreground(canvas: Node2D) -> void:
	if not is_instance_valid(actor):return
	var tint := VISUALS.color_for(visual_element())
	for effect in effects:
		if effect.kind=="arc":VISUALS.lightning(canvas,to_local(effect.a),to_local(effect.b),clock,tint,float(effect.left)/float(effect.duration))
	if actor.defense_kind=="mage_kit" and actor.defense_window>0:
		VISUALS.sigil(canvas,Vector2.ZERO,34,clock,tint)
	for node in actor.get_parent().get_children():
		if node is SlasherProjectile and String(node.attack.get("mage_visual_kit",node.attack.get("mage_kit","")))==kit_id() and not node.impacted:
			VISUALS.projectile(canvas,to_local(node.global_position),node.direction,clock,visual_element())
