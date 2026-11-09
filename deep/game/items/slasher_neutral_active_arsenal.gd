extends Node2D
class_name SlasherNeutralActiveArsenal

const MINI_BEAST := preload("res://game/enemies/corrupted_mini_beast.gd")

## Universal active items. Passive effects are gated by the currently held
## item, while activations continue for their authored duration after use.

var actor: SlasherPlayer
var item_id := ""
var active_time := 0.0
var tick := 0.0
var confusion_cooldowns: Dictionary = {}
var frost: Dictionary = {}
var frost_proc_cooldowns: Dictionary = {}
var blooms: Array[Dictionary] = []
var phantasms: Array[Dictionary] = []
var titan_damage := 0
var adaption_boost_time := 0.0
var compass_polarity := -1
var compass_point := Vector2.ZERO
var registered: Dictionary = {}
var pending_adaption_type := ""
var last_actor_position := Vector2.INF
var momentum := 0.0
var momentum_release := 1.0
var momentum_release_frame := -1
var momentum_primed_time := 0.0
var kinetic_burst_frame := -1
var kinetic_bursts := 0
var shadow_stride := 0.0
var shadow_ambush_ready := false
var pressure: Dictionary = {}
var contact_cooldowns: Dictionary = {}
var fey: Array[Dictionary] = []
var wyrm: Dictionary = {}
var snares: Array[Dictionary] = []
var heart_marks: Dictionary = {}
var ensnared: Dictionary = {}
var heart_power_time := 0.0
var valor_time := 0.0
var visual_clock := 0.0
var bramble_chomps := 0
var bramble_catches := 0


func configure(player: SlasherPlayer, id: String) -> void:
	actor = player
	item_id = id
	set_process(true)
	_restore_state()
	queue_redraw()


func is_held() -> bool:
	return (
		is_instance_valid(actor)
		and actor.run_state != null
		and ActiveItems.held(actor.run_state) == item_id
	)


func activate() -> bool:
	if not is_instance_valid(actor):
		return false
	match item_id:
		"siren_song_lyre":
			active_time = 6.0
			tick = 0.0
		"witherbloom_brooche":
			for i in 4:
				_spawn_bloom(
					actor.global_position + Vector2.RIGHT.rotated(TAU * float(i) / 4.0) * 70.0
				)
		"white_dragon_mask":
			active_time = 10.0
			_frost_breath()
		"black_titan_crown":
			active_time = 9.0
			titan_damage = 0
		"dissonant_whisper_jar":
			_release_phantasms()
		"mahoragan_adaption_wheel":
			active_time = 10.0
			adaption_boost_time = 10.0
		"pandoras_paradoxical_compass":
			compass_polarity *= -1
			active_time = 7.0
			compass_point = actor.global_position + actor.aim_direction.normalized() * 180.0
			_paradox_pulse()
		"vibranium_tattoo":
			var stored := maxf(320.0, momentum)
			momentum_release = 1.0 + minf(4.0, stored / 220.0)
			momentum = 0.0
			momentum_primed_time = 8.0
			momentum_release_frame = -1
		"shadowfell_brand":
			shadow_stride = minf(15.0, shadow_stride + 4.0)
			active_time = 8.0
			shadow_ambush_ready = true
		"blood_ruby_gem":
			_spawn_blood_minions()
		"abyssal_sapphire_gem":
			if pressure.is_empty():
				for foe in _enemies():
					if foe.global_position.distance_to(actor.global_position) <= 260.0:
						for stack in 3:
							_add_pressure(foe)
			_rupture_pressure()
		"feywild_shawl":
			_summon_fey()
		"bramble_vine_snare":
			_summon_wyrm()
		"heartbreaker_amulet":
			heart_power_time = 8.0
			for foe in _enemies():
				if foe.global_position.distance_to(actor.global_position) <= 360.0:
					_mark_heart(foe)
		"war_horn_of_valor":
			valor_time = 8.0
		_:
			return false
	queue_redraw()
	return true


func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		queue_free()
		return
	visual_clock += delta
	active_time = maxf(0.0, active_time - delta)
	adaption_boost_time = maxf(0.0, adaption_boost_time - delta)
	heart_power_time = maxf(0.0, heart_power_time - delta)
	valor_time = maxf(0.0, valor_time - delta)
	momentum_primed_time = maxf(0.0, momentum_primed_time - delta)
	tick -= delta
	_register_enemies()
	_tick_maps(delta)
	_process_blooms(delta)
	_process_phantasms(delta)
	_process_new_passives(delta)
	_process_fey(delta)
	_process_wyrm(delta)
	match item_id:
		"siren_song_lyre":
			_process_siren()
		"black_titan_crown":
			_process_titan()
		"pandoras_paradoxical_compass":
			_process_compass(delta)
	queue_redraw()


func adjust_external_attack(target: Node2D, attack: Dictionary) -> Dictionary:
	var result := attack.duplicate(true)
	if item_id == "black_titan_crown" and active_time > 0.0 and titan_damage > 0:
		result.damage = maxi(1, int(result.get("damage", 1)) + titan_damage)
		result["titan_burden"] = titan_damage
	if (
		item_id == "mahoragan_adaption_wheel"
		and adaption_boost_time > 0.0
		and target is SlasherEnemy
	):
		var learned := float(_adaptions().get(_enemy_type(target), 0.0))
		result.damage = maxi(1, int(round(float(result.get("damage", 1)) * (1.0 + learned))))
	if (
		item_id == "pandoras_paradoxical_compass"
		and active_time > 0.0
		and is_instance_valid(target)
		and target.global_position.distance_to(compass_point) <= 330.0
	):
		result.damage = maxi(1, int(round(float(result.get("damage", 1)) * 1.25)))
		result["paradox_reversal"] = true
	if item_id == "vibranium_tattoo" and is_held() and momentum_primed_time > 0.0:
		var frame := Engine.get_process_frames()
		if momentum_release_frame != frame:
			momentum_release_frame = frame
			momentum_primed_time = 0.0
		if momentum_release_frame == frame:
			result.damage = maxi(1, int(round(float(result.get("damage", 1)) * momentum_release)))
			result["vibranium_multiplier"] = momentum_release
			result["vibranium_release"] = true
	if item_id == "shadowfell_brand" and is_held():
		if shadow_ambush_ready:
			result.critical = true
			result.damage = maxi(1, int(round(float(result.get("damage", 1)) * 2.2)))
			result["shadowfell_ambush"] = true
			shadow_ambush_ready = false
			active_time = 0.0
		elif randf() < minf(0.55, 0.04 + shadow_stride * 0.032):
			result.critical = true
			result.damage = maxi(1, int(round(float(result.get("damage", 1)) * 1.75)))
	if item_id == "blood_ruby_gem" and is_held():
		var missing := 1.0 - float(actor.health) / maxf(1.0, float(actor.max_health))
		result.damage = maxi(1, int(round(float(result.get("damage", 1)) * (1.0 + missing * 1.35))))
	if item_id == "heartbreaker_amulet" and heart_power_time > 0.0:
		var health_ratio := float(actor.health) / maxf(1.0, float(actor.max_health))
		result.damage = maxi(
			1, int(round(float(result.get("damage", 1)) * (1.0 + health_ratio * 1.25)))
		)
	if item_id == "war_horn_of_valor" and valor_time > 0.0:
		result.damage = maxi(1, int(round(float(result.get("damage", 1)) * 1.5)))
	if item_id == "war_horn_of_valor" and is_held() and target is SlasherEnemy:
		var closeness := (
			1.0
			- clampf(actor.global_position.distance_to(target.global_position) / 330.0, 0.0, 1.0)
		)
		result.damage = maxi(
			1, int(round(float(result.get("damage", 1)) * (1.0 + 0.75 * closeness)))
		)
	if (
		item_id == "bramble_vine_snare"
		and target is SlasherEnemy
		and float(ensnared.get(target.get_instance_id(), 0.0)) > 0.0
	):
		result.damage = maxi(1, int(result.get("damage", 1)) * 2)
		result["bramble_vulnerability"] = true
	return result


func on_external_hit(target: SlasherEnemy, attack: Dictionary, was_dead: bool) -> void:
	if not is_instance_valid(target):
		return
	if (
		item_id == "vibranium_tattoo"
		and bool(attack.get("vibranium_release", false))
		and not bool(attack.get("neutral_secondary", false))
	):
		var frame := Engine.get_process_frames()
		if kinetic_burst_frame != frame:
			kinetic_burst_frame = frame
			kinetic_bursts += 1
			for foe in _enemies():
				if (
					foe != target
					and foe.global_position.distance_to(target.global_position) <= 135.0
				):
					_hit(
						foe,
						maxi(1, int(round(float(attack.get("damage", 1)) * 0.45))),
						"aether",
						{
							"damage_source": "vibranium_shockwave",
							"knockback": 110.0,
							"hit_stun_duration": 0.25,
							"neutral_secondary": true
						}
					)
	if (
		item_id == "white_dragon_mask"
		and frost.has(target.get_instance_id())
		and not was_dead
		and float(frost_proc_cooldowns.get(target.get_instance_id(), 0.0)) <= 0.0
	):
		frost_proc_cooldowns[target.get_instance_id()] = 0.22
		_cascade_ice(target, attack)
	if (
		item_id == "abyssal_sapphire_gem"
		and is_held()
		and not bool(attack.get("neutral_secondary", false))
	):
		_add_pressure(target)
	if (
		item_id == "heartbreaker_amulet"
		and is_held()
		and not bool(attack.get("heartbreaker_shared", false))
	):
		_mark_heart(target)
		var share := maxi(1, int(round(float(attack.get("damage", 1)) * 0.35)))
		for state in heart_marks.values():
			if not state is Dictionary:
				continue
			var stored_other: Variant = state.get("target")
			var other: SlasherEnemy = (
				stored_other as SlasherEnemy
				if is_instance_valid(stored_other) and stored_other is SlasherEnemy
				else null
			)
			if is_instance_valid(other) and other != target and not other.dead:
				_hit(
					other,
					share,
					String(attack.get("damage_type", "aether")),
					{
						"damage_source": "heartbreaker_shared",
						"heartbreaker_shared": true,
						"neutral_secondary": true
					}
				)
	if item_id == "war_horn_of_valor" and valor_time > 0.0 and not was_dead:
		actor.heal(maxi(1, int(round(float(attack.get("damage", 1)) * 0.15))))


func modify_incoming_damage_from(amount: int, attacker: SlasherEnemy) -> int:
	if item_id == "mahoragan_adaption_wheel":
		pending_adaption_type = ""
	if item_id == "black_titan_crown" and active_time > 0.0 and is_instance_valid(attacker):
		var proximity := (
			1.0
			- clampf(actor.global_position.distance_to(attacker.global_position) / 280.0, 0.0, 1.0)
		)
		return maxi(0, int(round(amount * (1.0 - 0.65 * proximity))))
	if item_id == "mahoragan_adaption_wheel" and is_held() and is_instance_valid(attacker):
		var key := _enemy_type(attacker)
		var values := _adaptions()
		var learned := float(values.get(key, 0.0))
		pending_adaption_type = key
		return maxi(0, int(round(amount * (1.0 - learned))))
	return amount


func on_owner_damaged(amount: int) -> void:
	if item_id == "black_titan_crown" and active_time > 0.0 and amount > 0:
		titan_damage += amount
	elif (
		item_id == "mahoragan_adaption_wheel"
		and is_held()
		and amount > 0
		and not pending_adaption_type.is_empty()
	):
		var values := _adaptions()
		values[pending_adaption_type] = minf(
			0.90, float(values.get(pending_adaption_type, 0.0)) + 0.08
		)
		_save_adaptions(values)
		pending_adaption_type = ""
	elif item_id == "shadowfell_brand" and amount > 0:
		shadow_stride = 0.0
		shadow_ambush_ready = false
		active_time = 0.0


func _register_enemies() -> void:
	if not is_inside_tree():
		return
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if not node is SlasherEnemy:
			continue
		var enemy := node as SlasherEnemy
		var id := enemy.get_instance_id()
		if registered.has(id):
			continue
		registered[id] = true
		if not enemy.defeated.is_connected(_on_enemy_defeated):
			enemy.defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(enemy: SlasherEnemy, _reward: int) -> void:
	if not is_held() or not is_instance_valid(enemy):
		return
	if (
		item_id == "witherbloom_brooche"
		and enemy.global_position.distance_to(actor.global_position) <= 360.0
	):
		_spawn_bloom(enemy.global_position)
	elif item_id == "dissonant_whisper_jar":
		_set_screams(_screams() + 1)
	elif (
		item_id == "blood_ruby_gem"
		and enemy.global_position.distance_to(actor.global_position) <= 420.0
	):
		_set_blood_charges(_blood_charges() + 1)


func _process_siren() -> void:
	if not is_held() and active_time <= 0.0:
		return
	for foe in _enemies():
		var id := foe.get_instance_id()
		var critical := foe.health <= maxi(1, int(ceil(foe.max_health * 0.25)))
		if (active_time > 0.0 or critical) and float(confusion_cooldowns.get(id, 0.0)) <= 0.0:
			confusion_cooldowns[id] = 0.75 if active_time > 0.0 else 2.4
			_confused_strike(foe, active_time > 0.0)


func _confused_strike(source: SlasherEnemy, cacophony: bool) -> void:
	var victim := _nearest_enemy(
		source.global_position, {source.get_instance_id(): true}, 220.0 if not cacophony else 9999.0
	)
	if victim == null:
		victim = source
	var damage := maxi(1, int(round(source.damage * (1.35 if cacophony else 0.8))))
	_hit(victim, damage, "psychic", {"damage_source": "siren_confusion", "hit_stun_duration": 0.35})
	source.hit_stun_timer = maxf(source.hit_stun_timer, 0.45)


func _spawn_bloom(point: Vector2) -> void:
	blooms.append({"point": point, "life": 4.0, "pulse": 0.01})
	queue_redraw()


func _process_blooms(delta: float) -> void:
	for index in range(blooms.size() - 1, -1, -1):
		var bloom: Dictionary = blooms[index]
		bloom.life = float(bloom.life) - delta
		bloom.pulse = float(bloom.pulse) - delta
		if float(bloom.pulse) <= 0.0:
			bloom.pulse = 0.8
			if actor.global_position.distance_to(Vector2(bloom.point)) <= 150.0:
				actor.heal(1)
			for foe in _enemies():
				if foe.global_position.distance_to(Vector2(bloom.point)) <= 145.0:
					foe.movement_slow = minf(foe.movement_slow, 0.55)
					foe.status_time = maxf(foe.status_time, 1.0)
		if float(bloom.life) <= 0.0:
			blooms.remove_at(index)
		else:
			blooms[index] = bloom


func _frost_breath() -> void:
	for foe in _enemies():
		var offset := foe.global_position - actor.global_position
		if (
			offset.length() <= 520.0
			and (offset.is_zero_approx() or actor.aim_direction.dot(offset.normalized()) >= -0.15)
		):
			frost[foe.get_instance_id()] = {"target": foe, "left": 10.0}
			foe.movement_slow = minf(foe.movement_slow, 0.42)
			foe.status_time = maxf(foe.status_time, 2.8)
			_hit(
				foe,
				_base(0.55),
				"ice",
				{
					"damage_source": "white_dragon_breath",
					"hit_stun_duration": 0.18,
					"neutral_secondary": true
				}
			)


func _cascade_ice(primary: SlasherEnemy, _attack: Dictionary) -> void:
	for foe in _enemies():
		if foe == primary or foe.global_position.distance_to(primary.global_position) > 135.0:
			continue
		_hit(
			foe,
			_base(0.7),
			"ice",
			{
				"damage_source": "white_dragon_shard",
				"status": "slow",
				"status_strength": 0.55,
				"status_duration": 2.0,
				"neutral_secondary": true
			}
		)


func _process_titan() -> void:
	if active_time <= 0.0:
		return
	for foe in _enemies():
		var proximity := (
			1.0 - clampf(actor.global_position.distance_to(foe.global_position) / 310.0, 0.0, 1.0)
		)
		if proximity > 0.0:
			foe.movement_slow = minf(foe.movement_slow, 1.0 - 0.78 * proximity)
			foe.status_time = maxf(foe.status_time, 0.25)


func _release_phantasms() -> void:
	var count := clampi(_screams(), 1, 14)
	_set_screams(0)
	for index in count:
		var direction := Vector2.RIGHT.rotated(TAU * float(index) / float(count))
		phantasms.append(
			{
				"position": actor.global_position + direction * 18.0,
				"direction": direction,
				"life": 4.8,
				"hits": {},
				"retarget": 0.0
			}
		)


func _process_phantasms(delta: float) -> void:
	for index in range(phantasms.size() - 1, -1, -1):
		var ghost: Dictionary = phantasms[index]
		ghost.life = float(ghost.life) - delta
		ghost.retarget = float(ghost.retarget) - delta
		if float(ghost.retarget) <= 0.0:
			ghost.retarget = 0.16
			var target := _nearest_enemy(Vector2(ghost.position), Dictionary(ghost.hits), 520.0)
			if target != null:
				ghost.direction = Vector2(ghost.position).direction_to(target.global_position)
		ghost.position = Vector2(ghost.position) + Vector2(ghost.direction) * 430.0 * delta
		for foe in _enemies():
			if (
				not Dictionary(ghost.hits).has(foe.get_instance_id())
				and foe.global_position.distance_to(Vector2(ghost.position)) <= 22.0
			):
				var hits: Dictionary = ghost.hits
				hits[foe.get_instance_id()] = true
				ghost.hits = hits
				_hit(
					foe,
					_base(1.25),
					"aether",
					{"damage_source": "dissonant_phantasm", "hit_stun_duration": 0.2}
				)
		if float(ghost.life) <= 0.0:
			phantasms.remove_at(index)
		else:
			phantasms[index] = ghost


func _process_compass(delta: float) -> void:
	if active_time <= 0.0:
		return
	for foe in _enemies():
		var offset := compass_point - foe.global_position
		var distance := offset.length()
		if distance > 310.0 or distance < 1.0:
			continue
		var direction := offset.normalized() * compass_polarity
		foe.move_and_collide(direction * minf((80.0 + distance * 0.35) * delta, 28.0))
		foe.hit_stun_timer = maxf(foe.hit_stun_timer, 0.04)


func _paradox_pulse() -> void:
	for foe in _enemies():
		var distance := foe.global_position.distance_to(compass_point)
		if distance <= 180.0:
			_hit(
				foe,
				_base(0.85),
				"aether",
				{
					"damage_source": "pandora_pulse",
					"hit_stun_duration": 0.35,
					"knockback": -90.0 if compass_polarity > 0 else 120.0,
					"neutral_secondary": true
				}
			)


func _process_new_passives(delta: float) -> void:
	if last_actor_position == Vector2.INF:
		last_actor_position = actor.global_position
	var travelled := last_actor_position.distance_to(actor.global_position)
	last_actor_position = actor.global_position
	if (
		item_id == "vibranium_tattoo"
		and is_held()
		and momentum_primed_time <= 0.0
		and travelled > 0.5
	):
		momentum = minf(1200.0, momentum + travelled)
	if item_id == "shadowfell_brand" and is_held():
		if travelled > 0.5:
			shadow_stride = minf(15.0, shadow_stride + delta)
		if is_instance_valid(actor.kit_buffs):
			actor.kit_buffs.grant_speed(
				"shadowfell_brand",
				1.0 + minf(0.45, shadow_stride * 0.03) + (0.25 if active_time > 0.0 else 0.0),
				0.25
			)
	if item_id == "abyssal_sapphire_gem" and is_held():
		for foe in _enemies():
			var id := foe.get_instance_id()
			if (
				foe.global_position.distance_to(actor.global_position) <= 38.0
				and float(contact_cooldowns.get(id, 0.0)) <= 0.0
			):
				contact_cooldowns[id] = 0.55
				_add_pressure(foe)
	if item_id == "war_horn_of_valor" and (is_held() or valor_time > 0.0):
		for foe in _enemies():
			var closeness := (
				1.0
				- clampf(actor.global_position.distance_to(foe.global_position) / 330.0, 0.0, 1.0)
			)
			if closeness > 0.0:
				foe.speed_boost_multiplier = maxf(
					foe.speed_boost_multiplier, 1.0 + 0.65 * closeness
				)
				foe.speed_boost_time = maxf(foe.speed_boost_time, 0.25)


func _add_pressure(target: SlasherEnemy) -> void:
	if not is_instance_valid(target) or target.dead:
		return
	var id := target.get_instance_id()
	var state: Dictionary = pressure.get(
		id, {"target": target, "stacks": 0, "left": 0.0, "original_damage": target.damage}
	)
	state.stacks = mini(7, int(state.stacks) + 1)
	state.left = 7.0
	pressure[id] = state
	var stacks := int(state.stacks)
	target.movement_slow = minf(target.movement_slow, maxf(0.12, 1.0 - stacks * 0.12))
	target.status_time = maxf(target.status_time, 1.0)
	target.damage = maxi(1, int(round(int(state.original_damage) * (1.0 - stacks * 0.09))))


func _rupture_pressure() -> void:
	for id in pressure.keys().duplicate():
		var state: Dictionary = pressure[id]
		var stored_target: Variant = state.get("target")
		var target: SlasherEnemy = (
			stored_target as SlasherEnemy
			if is_instance_valid(stored_target) and stored_target is SlasherEnemy
			else null
		)
		var stacks := int(state.get("stacks", 0))
		if is_instance_valid(target) and not target.dead:
			target.damage = int(state.get("original_damage", target.damage))
			_hit(
				target,
				_base(0.65 * stacks),
				"aether",
				{
					"damage_source": "abyssal_pressure_rupture",
					"knockback": 55.0 * stacks,
					"hit_stun_duration": 0.12 * stacks,
					"neutral_secondary": true
				}
			)
		pressure.erase(id)


func _spawn_blood_minions() -> void:
	var count := clampi(_blood_charges(), 0, 16)
	_set_blood_charges(0)
	for index in count:
		var beast := MINI_BEAST.new().setup(
			actor,
			(
				actor.global_position
				+ Vector2.RIGHT.rotated(TAU * float(index) / maxf(1.0, float(count))) * 22.0
			),
			index
		)
		beast.tint = Color("#c73f52")
		beast.lifetime = 15.0
		actor.get_parent().add_child(beast)


func _summon_fey() -> void:
	var charisma := _charisma()
	var count := randi_range(2, 5) + clampi((charisma - 10) / 4, 0, 3)
	for index in count:
		fey.append(
			{
				"position":
				(
					actor.global_position
					+ Vector2.RIGHT.rotated(TAU * float(index) / float(count)) * 70.0
				),
				"life": 10.0 + randf() * 4.0,
				"cooldown": randf_range(0.2, 1.0),
				"friendly_chance": clampf(0.58 + (charisma - 10) * 0.025, 0.35, 0.92),
				"hue": randf()
			}
		)


func _process_fey(delta: float) -> void:
	for index in range(fey.size() - 1, -1, -1):
		var spirit: Dictionary = fey[index]
		spirit.life = float(spirit.life) - delta
		spirit.cooldown = float(spirit.cooldown) - delta
		var target := _nearest_enemy(Vector2(spirit.position), {}, 480.0)
		if target != null:
			spirit.position = Vector2(spirit.position).move_toward(
				target.global_position, 95.0 * delta
			)
		if float(spirit.cooldown) <= 0.0:
			spirit.cooldown = randf_range(0.65, 1.35)
			if target != null and randf() < float(spirit.friendly_chance):
				_hit(
					target,
					_base(randf_range(0.55, 1.1)),
					["fire", "ice", "lightning", "aether"][randi() % 4],
					{"damage_source": "wild_fey", "neutral_secondary": true}
				)
			elif actor.health > 1:
				actor.receive_damage(maxi(1, _base(0.22)), Vector2.ZERO, null)
		if float(spirit.life) <= 0.0:
			fey.remove_at(index)
		else:
			fey[index] = spirit


func _summon_wyrm() -> void:
	var aim := (
		actor.aim_direction.normalized()
		if not actor.aim_direction.is_zero_approx()
		else Vector2.RIGHT
	)
	var destination := _safe_room_point(actor.global_position + aim * 320.0)
	wyrm = {
		"position": actor.global_position,
		"destination": destination,
		"life": 3.2,
		"trail": 0.0,
		"chomped": false
	}
	snares.clear()
	for i in 4:
		snares.append(
			{
				"point": actor.global_position.lerp(destination, float(i + 1) / 5.0),
				"left": 5.0,
				"resolved": {}
			}
		)


func _process_wyrm(delta: float) -> void:
	if wyrm.is_empty():
		return
	wyrm.life = float(wyrm.life) - delta
	wyrm.trail = float(wyrm.trail) - delta
	var position := Vector2(wyrm.position)
	var destination := Vector2(wyrm.destination)
	position = position.move_toward(destination, 260.0 * delta)
	wyrm.position = position
	if float(wyrm.trail) <= 0.0:
		wyrm.trail = 0.38
		snares.append({"point": position, "left": 5.0, "resolved": {}})
	for index in range(snares.size() - 1, -1, -1):
		var snare: Dictionary = snares[index]
		snare.left = float(snare.left) - delta
		for foe in _enemies():
			var id := foe.get_instance_id()
			var resolved: Dictionary = snare.resolved
			if resolved.has(id) or foe.global_position.distance_to(Vector2(snare.point)) > 34.0:
				continue
			var effective_speed := foe.speed * foe.movement_slow
			var evaded := effective_speed > 180.0 and randf() < 0.55
			if evaded:
				resolved[id] = "evaded"
			else:
				resolved[id] = "caught"
				ensnared[id] = maxf(float(ensnared.get(id, 0.0)), 2.25)
				foe.hit_stun_timer = maxf(foe.hit_stun_timer, 1.5)
				bramble_catches += 1
			snare.resolved = resolved
		if float(snare.left) <= 0.0:
			snares.remove_at(index)
		else:
			snares[index] = snare
	if (
		(position.distance_to(destination) <= 12.0 or float(wyrm.life) <= 0.0)
		and not bool(wyrm.chomped)
	):
		wyrm.chomped = true
		wyrm.life = 0.35
		_damage_wyrm_chomp(destination)
	elif bool(wyrm.chomped) and float(wyrm.life) <= 0.0:
		wyrm.clear()


func _damage_wyrm_chomp(point: Vector2) -> void:
	bramble_chomps += 1
	for foe in _enemies():
		var distance := foe.global_position.distance_to(point)
		if distance <= 155.0:
			if distance > 18.0:
				foe.move_and_collide(
					foe.global_position.direction_to(point) * minf(45.0, distance - 12.0)
				)
			if distance <= 125.0:
				_hit(
					foe,
					_base(2.8),
					"physical",
					{
						"damage_source": "bramble_wyrm_chomp",
						"knockback": 65.0,
						"hit_stun_duration": 1.1,
						"neutral_secondary": true
					}
				)


func _mark_heart(target: SlasherEnemy) -> void:
	if is_instance_valid(target):
		heart_marks[target.get_instance_id()] = {"target": target, "left": 8.0}


func _safe_room_point(point: Vector2) -> Vector2:
	if actor.position_sanitizer.is_valid():
		var result: Variant = actor.position_sanitizer.call(point)
		if result is Vector2:
			return result
	return point


func _charisma() -> int:
	if actor.run_state != null and actor.run_state.campaign != null:
		var member := actor.run_state.campaign.character(actor.run_state.active_character_id)
		if member != null:
			return int(member.attributes.get("cha", 10))
	return 10


func _tick_maps(delta: float) -> void:
	for map in [confusion_cooldowns, frost_proc_cooldowns, contact_cooldowns, ensnared]:
		for id in map.keys():
			map[id] = maxf(0.0, float(map[id]) - delta)
	for id in frost.keys().duplicate():
		var state: Dictionary = frost[id]
		state.left = float(state.left) - delta
		if float(state.left) <= 0.0 or not is_instance_valid(state.get("target")):
			frost.erase(id)
		else:
			frost[id] = state
	for id in pressure.keys().duplicate():
		var state: Dictionary = pressure[id]
		state.left = float(state.left) - delta
		var stored_target: Variant = state.get("target")
		var target: SlasherEnemy = (
			stored_target as SlasherEnemy
			if is_instance_valid(stored_target) and stored_target is SlasherEnemy
			else null
		)
		if float(state.left) <= 0.0 or not is_instance_valid(target):
			if is_instance_valid(target):
				target.damage = int(state.get("original_damage", target.damage))
			pressure.erase(id)
		else:
			pressure[id] = state
	for id in heart_marks.keys().duplicate():
		var state: Dictionary = heart_marks[id]
		state.left = float(state.left) - delta
		if float(state.left) <= 0.0 or not is_instance_valid(state.get("target")):
			heart_marks.erase(id)
		else:
			heart_marks[id] = state


func _base(multiplier: float = 1.0) -> int:
	return maxi(1, int(round(maxi(actor.attack_power, actor.spell_power) * multiplier)))


func _hit(target: SlasherEnemy, damage: int, kind: String, extra: Dictionary = {}) -> void:
	if is_instance_valid(target) and not target.dead:
		target.receive_attack(actor._attack_data(damage, kind, extra), actor)


func _enemies() -> Array[SlasherEnemy]:
	var result: Array[SlasherEnemy] = []
	if not is_inside_tree():
		return result
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and is_instance_valid(node) and not node.dead:
			result.append(node)
	return result


func _nearest_enemy(
	point: Vector2, excluded: Dictionary = {}, max_range: float = 99999.0
) -> SlasherEnemy:
	var best: SlasherEnemy
	var distance := max_range
	for foe in _enemies():
		if excluded.has(foe.get_instance_id()):
			continue
		var current := point.distance_to(foe.global_position)
		if current < distance:
			distance = current
			best = foe
	return best


func _enemy_type(enemy: SlasherEnemy) -> String:
	return enemy.behavior_id if not enemy.behavior_id.is_empty() else enemy.visual_id


func _neutral_state() -> Dictionary:
	var stats := actor.run_state.run_stats()
	if not stats.has("neutral_active_state"):
		stats["neutral_active_state"] = {}
	return stats.neutral_active_state


func _screams() -> int:
	return int(_neutral_state().get("whisper_screams", 0))


func _set_screams(value: int) -> void:
	_neutral_state()["whisper_screams"] = maxi(0, value)


func _blood_charges() -> int:
	return int(_neutral_state().get("blood_ruby_charges", 0))


func _set_blood_charges(value: int) -> void:
	_neutral_state()["blood_ruby_charges"] = maxi(0, value)


func _adaptions() -> Dictionary:
	return Dictionary(_neutral_state().get("mahoraga_adaptions", {})).duplicate(true)


func _save_adaptions(value: Dictionary) -> void:
	_neutral_state()["mahoraga_adaptions"] = value.duplicate(true)


func _restore_state() -> void:
	pass


func _draw() -> void:
	if not is_instance_valid(actor):
		return
	for bloom in blooms:
		var p := Vector2(bloom.point) - actor.global_position
		var pulse := sin(visual_clock * 7.0 + float(bloom.life)) * 3.0
		for i in 8:
			draw_circle(
				p + Vector2.from_angle(TAU * i / 8.0 + visual_clock * 0.5) * (10.0 + pulse),
				5.0,
				Color(0.5, 0.86, 0.52, 0.7)
			)
		draw_circle(p, 5.0, Color("#fff19b"))
		draw_arc(p, 30.0 + pulse, 0, TAU, 24, Color(0.7, 1.0, 0.65, 0.35), 2.0, true)
	for ghost in phantasms:
		var p := Vector2(ghost.position) - actor.global_position
		var heading := Vector2(ghost.direction)
		var tail := PackedVector2Array()
		for i in 7:
			tail.append(
				(
					p
					- heading * i * 7.0
					+ heading.orthogonal() * sin(i * 1.5 - visual_clock * 13.0) * 5.0
				)
			)
		draw_polyline(tail, Color(0.55, 0.4, 0.9, 0.5), 6.0, true)
		draw_circle(p, 8.0, Color(0.72, 0.9, 1.0, 0.75))
	for spirit in fey:
		var p := Vector2(spirit.position) - actor.global_position
		var color := Color.from_hsv(float(spirit.hue), 0.55, 1.0, 0.78)
		draw_circle(p, 6.0, color)
		draw_line(p, p + Vector2(-10, -5).rotated(sin(visual_clock * 15.0) * 0.3), color, 3.0, true)
		draw_line(p, p + Vector2(10, -5).rotated(-sin(visual_clock * 15.0) * 0.3), color, 3.0, true)
		draw_arc(
			p, 12.0, visual_clock, visual_clock + 5.0, 14, Color(0.9, 1.0, 0.8, 0.45), 2.0, true
		)
	for snare in snares:
		var p := Vector2(snare.point) - actor.global_position
		draw_arc(
			p,
			25.0 + sin(visual_clock * 6.0) * 3.0,
			visual_clock,
			visual_clock + 5.4,
			18,
			Color(0.25, 0.65, 0.25, 0.75),
			4.0,
			true
		)
		for i in 6:
			draw_line(
				p + Vector2.from_angle(TAU * i / 6.0) * 14.0,
				p + Vector2.from_angle(TAU * i / 6.0) * 31.0,
				Color("#a6c85b"),
				2.0,
				true
			)
	if not wyrm.is_empty():
		var p := Vector2(wyrm.position) - actor.global_position
		for i in 4:
			draw_circle(
				p - Vector2(i * 10, 0) + Vector2(0, sin(visual_clock * 10.0 + i) * 5.0),
				16.0 - i * 2.0,
				Color(0.28, 0.5, 0.2, 0.45)
			)
			draw_arc(
				p,
				24.0,
				visual_clock,
				visual_clock + 5.2,
				18,
				Color(0.65, 0.4, 0.18, 0.75),
				5.0,
				true
			)
	if item_id == "siren_song_lyre" and (is_held() or active_time > 0.0):
		for ring in 3:
			draw_arc(
				Vector2.ZERO,
				46.0 + ring * 25.0 + fmod(visual_clock * 35.0, 25.0),
				0,
				TAU,
				40,
				Color(0.9, 0.5, 0.9, 0.35 - float(ring) * 0.07),
				3.0,
				true
			)
		for i in 4:
			var p := Vector2.from_angle(TAU * i / 4.0 - visual_clock) * 62.0
			draw_circle(p, 4.0, Color("#7be0ef"))
			draw_line(p, p + Vector2(0, 13), Color("#f49bdc"), 2.0, true)
	for state in frost.values():
		var stored_target: Variant = state.get("target")
		var target: SlasherEnemy = (
			stored_target as SlasherEnemy
			if is_instance_valid(stored_target) and stored_target is SlasherEnemy
			else null
		)
		if is_instance_valid(target):
			var p := target.global_position - actor.global_position
			for i in 6:
				var q := p + Vector2.from_angle(TAU * i / 6.0 + visual_clock) * 25.0
				draw_line(q - Vector2(4, 0), q + Vector2(4, 0), Color("#d9f7ff"), 2.0, true)
				draw_line(q - Vector2(0, 4), q + Vector2(0, 4), Color("#79c8ee"), 2.0, true)
	if item_id == "black_titan_crown" and active_time > 0.0:
		draw_arc(Vector2.ZERO, 310.0, 0, TAU, 64, Color(0.3, 0.25, 0.15, 0.45), 5.0, true)
		for foe in _enemies():
			var p := foe.global_position - actor.global_position
			if p.length() < 310.0:
				draw_line(p, p + p.normalized() * 18.0, Color(0.15, 0.12, 0.18, 0.5), 5.0, true)
		for i in mini(titan_damage, 12):
			draw_circle(
				(
					Vector2.from_angle(TAU * i / maxf(1.0, mini(titan_damage, 12)) + visual_clock)
					* 42.0
				),
				3.0,
				Color("#d4ad53")
			)
	if item_id == "mahoragan_adaption_wheel" and is_held():
		var center := Vector2(0, -34)
		draw_arc(center, 20.0, 0, TAU, 28, Color("#f1d46c"), 4.0, true)
		for i in 8:
			var ray := Vector2.from_angle(TAU * i / 8.0 + visual_clock * 2.2)
			draw_line(center + ray * 7.0, center + ray * 24.0, Color("#c9e8ef"), 3.0, true)
	if item_id == "pandoras_paradoxical_compass" and active_time > 0.0:
		var p := compass_point - actor.global_position
		for i in 3:
			draw_arc(
				p,
				26.0 + i * 14.0,
				visual_clock * (i + 1) * compass_polarity,
				visual_clock * (i + 1) * compass_polarity + 5.1,
				30,
				Color("#75d9ff") if compass_polarity > 0 else Color("#ff718c"),
				4.0 - i,
				true
			)
			var needle := Vector2.from_angle(visual_clock * 4.0 * compass_polarity) * 32.0
			draw_line(p - needle, p + needle, Color.WHITE, 2.0, true)
	if item_id == "vibranium_tattoo" and is_held():
		var radius := 30.0 + minf(24.0, momentum / 45.0)
		draw_arc(
			Vector2.ZERO,
			radius,
			visual_clock * 3.0,
			visual_clock * 3.0 + 5.4,
			36,
			Color(0.7, 0.5, 1.0, 0.75),
			4.0,
			true
		)
		for i in 5:
			draw_line(
				-actor.velocity.normalized() * i * 9.0 + Vector2(-8, 0),
				-actor.velocity.normalized() * i * 9.0 + Vector2(8, 0),
				Color(0.35, 0.8, 1.0, 0.45),
				2.0,
				true
			)
	if item_id == "shadowfell_brand" and is_held():
		draw_arc(
			Vector2.ZERO,
			35.0 + sin(visual_clock * 5.0) * 4.0,
			0,
			TAU,
			30,
			Color(0.22, 0.12, 0.35, minf(0.8, 0.2 + shadow_stride * 0.04)),
			5.0,
			true
		)
		for i in 6:
			draw_circle(
				Vector2.from_angle(TAU * i / 6.0 - visual_clock) * 48.0,
				4.0,
				Color(0.65, 0.3, 0.85, 0.35)
			)
	if item_id == "blood_ruby_gem" and is_held():
		for i in mini(_blood_charges(), 16):
			draw_circle(
				(
					Vector2.from_angle(
						TAU * i / maxf(1.0, mini(_blood_charges(), 16)) + visual_clock
					)
					* 48.0
				),
				5.0,
				Color("#d8294b")
			)
	for state in pressure.values():
		var stored_target: Variant = state.get("target")
		var target: SlasherEnemy = (
			stored_target as SlasherEnemy
			if is_instance_valid(stored_target) and stored_target is SlasherEnemy
			else null
		)
		if is_instance_valid(target):
			var p := target.global_position - actor.global_position
			var stacks := int(state.get("stacks", 0))
			for i in stacks:
				draw_arc(
					p,
					18.0 + i * 3.0,
					visual_clock * i,
					visual_clock * i + 4.8,
					18,
					Color(0.2, 0.65, 1.0, 0.6),
					2.0,
					true
				)
	if not heart_marks.is_empty():
		var points: Array[Vector2] = []
		for state in heart_marks.values():
			var stored_target: Variant = state.get("target")
			var target: SlasherEnemy = (
				stored_target as SlasherEnemy
				if is_instance_valid(stored_target) and stored_target is SlasherEnemy
				else null
			)
			if is_instance_valid(target):
				points.append(target.global_position - actor.global_position)
		for a in points:
			for b in points:
				if a != b:
					draw_line(a, b, Color(1.0, 0.25, 0.45, 0.35), 2.0, true)
			var pulse := 5.0 + sin(visual_clock * 8.0) * 2.0
			draw_circle(a + Vector2(-pulse * 0.6, -2), pulse, Color("#ff5275"))
			draw_circle(a + Vector2(pulse * 0.6, -2), pulse, Color("#ff5275"))
	if item_id == "war_horn_of_valor" and (is_held() or valor_time > 0.0):
		for i in 4:
			draw_arc(
				Vector2.ZERO,
				55.0 + i * 45.0 + fmod(visual_clock * 45.0, 35.0),
				-1.2,
				1.2,
				30,
				Color(0.95, 0.7, 0.25, 0.45 - float(i) * 0.08),
				4.0,
				true
			)
