extends Node2D
class_name SlasherMageActiveArsenal

## Gameplay uses a fixed clock and bounded reusable records. Rendering never
## selects targets, advances timers, applies damage, or changes simulation state.
const RULES_PATH := "res://data/mage_active_items.json"
static var rules: Dictionary = {}
var config: Dictionary = {}
var actor: SlasherPlayer
var item_id := ""
var active_time := 0.0
var charge_time := 0.0
var tick_time := 0.0
var orb_energy := 0
var tome_stacks := 0
var tome_souls := 0
var dragon_fuel := 0.0
var flare_cooldown := 0.0
var flare_pending := 0.0
var web_active := false
var web_points: Array[Vector2] = []
var web_segments: Array[Dictionary] = []
var web_length := 0.0
var caught: Dictionary = {}
var poison: Dictionary = {}
var marked: Dictionary = {}
var exposure: Dictionary = {}
var heat: Dictionary = {}
var remains: Array[Dictionary] = []
var plants: Array[Dictionary] = []
var treants: Array[Dictionary] = []
var missiles: Array[Dictionary] = []
var delayed_bursts: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var anchor := Vector2.ZERO
var defer_spend_once := false
var visual_clock := 0.0
var phase := "idle"
var phase_time := 0.0
var aim_start := Vector2.ZERO
var aim_direction := Vector2.RIGHT
var preview: Array[Vector2] = []
var channel_held := false
var _owns_lock := false
var _accumulator := 0.0
var _scan_time := 0.0
var _enemies_cache: Array = []
var _ray_exclusions: Array[RID] = []
var _observed: Dictionary = {}
var _attack_records: Dictionary = {}
var _shango_hits: Dictionary = {}
var _serial := 0
var _pool: Array[Dictionary] = []
var _reduced := false
var _full_charge_cue := false
var flame_boundary: PackedVector2Array = []
var _shango_mouse := false
var orb_recoil := 0.0
var _spatial: Dictionary = {}
const TARGET_CELL := 128.0


func configure(player: SlasherPlayer, id: String) -> void:
	actor = player
	item_id = id
	if rules.is_empty():
		rules = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	config = Dictionary(rules.shared).duplicate(true)
	config.merge(Dictionary(rules.get(id, {})), true)
	dragon_fuel = value("initial_fuel", 0.0)
	z_index = 12
	set_process(true)
	set_physics_process(true)
	_refresh_targets()


func value(key: String, fallback: float = 0.0) -> float:
	return float(config.get(key, fallback))


func is_held() -> bool:
	return (
		is_instance_valid(actor)
		and actor.health > 0
		and ActiveItems.held(actor.run_state) == item_id
	)


func activate() -> bool:
	if not is_held():
		return false
	if phase in ["charging", "aiming", "channel"]:
		return false
	if phase == "recovery" and phase_time > 0.0:
		return false
	defer_spend_once = false
	_refresh_targets()
	aim_direction = actor.aim_direction.normalized()
	if aim_direction.is_zero_approx():
		aim_direction = Vector2.RIGHT
	match item_id:
		"michaels_orb":
			active_time = value("duration")
			_try_orb()
		"gulthias_staff":
			_fire_gulthias_bolt()
		"jade_serpent_staff":
			_fire_jade_dart()
		"skyblinder_staff":
			phase = "charging"
			charge_time = 0.0
			active_time = value("max_hold")
			_full_charge_cue = false
		"dragonstaff_of_ahghairon":
			if dragon_fuel <= 0.05:
				return false
			phase = "channel"
			phase_time = value("windup")
			tick_time = 0.0
			active_time = dragon_fuel
		"arachne_staff":
			if web_active:
				_end_web()
			else:
				web_active = true
				active_time = value("duration")
				anchor = actor.global_position
				web_points = [anchor]
				web_length = 0.0
				defer_spend_once = true
		"tome_of_toth":
			active_time = value("duration")
			_fire_bolt("tome", value("damage"), "aether")
		"shangos_shatterer":
			phase = "aiming"
			active_time = value("max_aim_time")
			var offset := actor.get_global_mouse_position() - actor.global_position
			_shango_mouse = offset.length() > 12.0 and offset.normalized().dot(aim_direction) > 0.95
			set_targeting_origin(
				(
					actor.global_position
					+ (
						offset.limit_length(value("start_range"))
						if _shango_mouse
						else aim_direction * value("start_range")
					)
				)
			)
			_update_preview()
		"solar_scepter":
			active_time = value("duration")
			tick_time = 0.0
		"drumamus_bargain":
			if actor.input_locked:
				return false
			phase = "channel"
			active_time = value("duration")
			charge_time = 0.0
			tick_time = 0.0
			anchor = actor.global_position
			actor.input_locked = true
			_owns_lock = true
			actor._play_animation("idle")
		_:
			return false
	_pulse(actor.global_position, 24.0, Color("#b4e9ff"), 0.2)
	return true


func _process(delta: float) -> void:
	visual_clock += delta
	var settings: Node = get_node_or_null("/root/GameSettings")
	_reduced = settings != null and settings.get_bool("reduced_effects", false)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_held():
		cancel()
		return
	channel_held = Input.is_action_pressed("slasher_special")
	_accumulator += delta
	var step := value("step", 1.0 / 60.0)
	while _accumulator + 0.0000001 >= step:
		_accumulator -= step
		_step(step)


func _step(delta: float) -> void:
	_scan_time -= delta
	if _scan_time <= 0.0:
		_refresh_targets()
	_rebuild_spatial()
	active_time = maxf(0.0, active_time - delta)
	phase_time = maxf(0.0, phase_time - delta)
	flare_cooldown = maxf(0.0, flare_cooldown - delta)
	orb_recoil = maxf(0.0, orb_recoil - delta)
	for i in range(impacts.size() - 1, -1, -1):
		impacts[i].left -= delta
		if float(impacts[i].left) <= 0.0:
			_recycle(impacts, i)
	_process_missiles(delta)
	_process_poison(delta)
	_process_delayed(delta)
	_process_growth(delta)
	match item_id:
		"michaels_orb":
			if active_time > 0.0:
				_try_orb()
		"skyblinder_staff":
			_process_skyblinder(delta)
		"dragonstaff_of_ahghairon":
			_process_dragonfire(delta)
		"arachne_staff":
			_process_web(delta)
		"solar_scepter":
			_process_solar(delta)
		"drumamus_bargain":
			_process_gravity(delta)
		"shangos_shatterer":
			if phase == "aiming":
				_update_preview()
				if not channel_held:
					_cast_shango()
				elif active_time <= 0.0:
					cancel()
	if phase == "recovery" and phase_time <= 0.0:
		phase = "idle"


func cancel() -> void:
	for raw in _enemies_cache:
		if _body(raw) != null:
			_body(raw).clear_mage_control(get_instance_id())
	if _owns_lock and is_instance_valid(actor):
		actor.input_locked = false
	_owns_lock = false
	if is_instance_valid(actor) and is_instance_valid(actor.kit_buffs):
		actor.kit_buffs.clear_source("arachne_web")
	for list in [missiles, delayed_bursts, impacts, plants, treants, remains, web_segments]:
		while not list.is_empty():
			_recycle(list, list.size() - 1)
	for map in [poison, marked, exposure, heat, caught, _attack_records, _shango_hits]:
		map.clear()
	web_points.clear()
	preview.clear()
	flame_boundary.clear()
	web_active = false
	charge_time = 0.0
	active_time = 0.0
	orb_energy = 0
	tome_stacks = 0
	tome_souls = 0
	flare_pending = 0.0
	phase = "idle"
	_accumulator = 0.0
	_disconnect_targets()


func _exit_tree() -> void:
	cancel()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		if phase in ["charging", "aiming", "channel"]:
			cancel()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and event.keycode == KEY_ESCAPE
		and phase in ["charging", "aiming", "channel"]
	):
		cancel()
		get_viewport().set_input_as_handled()


func _refresh_targets() -> void:
	_scan_time = value("target_refresh", 0.12)
	_enemies_cache.clear()
	_ray_exclusions.clear()
	if not is_inside_tree():
		return
	if not get_tree().node_added.is_connected(_observe_spawn):
		get_tree().node_added.connect(_observe_spawn)
	if is_instance_valid(actor):
		_ray_exclusions.append(actor.get_rid())
	for raw in get_tree().get_nodes_in_group("slasher_enemy"):
		if _body(raw) == null or raw.dead:
			continue
		_enemies_cache.append(raw)
		_ray_exclusions.append(_body(raw).get_rid())
		if item_id in ["jade_serpent_staff", "tome_of_toth", "dragonstaff_of_ahghairon"]:
			var body := _body(raw)
			if not body.defeated.is_connected(_on_enemy_death):
				body.defeated.connect(_on_enemy_death)
			_observed[body.get_instance_id()] = weakref(body)
	for id in _observed.keys():
		if _observed[id].get_ref() == null:
			_observed.erase(id)
	_rebuild_spatial()


func _observe_spawn(node: Node) -> void:
	if not is_held() or not actor.get_parent().is_ancestor_of(node):
		return
	var body := _body(node)
	if body == null:
		return
	if not _enemies_cache.has(node):
		_enemies_cache.append(node)
	if not _ray_exclusions.has(body.get_rid()):
		_ray_exclusions.append(body.get_rid())
	if item_id in ["jade_serpent_staff", "tome_of_toth", "dragonstaff_of_ahghairon"]:
		if not body.defeated.is_connected(_on_enemy_death):
			body.defeated.connect(_on_enemy_death)
		_observed[body.get_instance_id()] = weakref(body)


func _disconnect_targets() -> void:
	if is_inside_tree() and get_tree().node_added.is_connected(_observe_spawn):
		get_tree().node_added.disconnect(_observe_spawn)
	for ref in _observed.values():
		var node: Variant = ref.get_ref()
		if is_instance_valid(node) and node.defeated.is_connected(_on_enemy_death):
			node.defeated.disconnect(_on_enemy_death)
	_observed.clear()
	_enemies_cache.clear()
	_spatial.clear()


func _body(raw: Variant) -> SlasherEnemy:
	if not is_instance_valid(raw):
		return null
	if raw is SlasherEnemy:
		return raw
	if raw is SlasherColossusWeakPoint and is_instance_valid(raw.colossus):
		return raw.colossus
	return null


func _combat_id(raw: Node2D) -> int:
	return _body(raw).get_instance_id()


func _valid_target(raw: Variant) -> bool:
	var body := _body(raw)
	if body == null or body.dead:
		return false
	if raw is SlasherColossusWeakPoint:
		return raw.open
	if raw is SlasherCryptEnemy and raw.transition_time > 0.0:
		return false
	return true


func _enemies() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for raw in _enemies_cache:
		if _valid_target(raw):
			result.append(raw)
	return result


func _rebuild_spatial() -> void:
	# One broad-phase update serves every projectile and area query this tick.
	_spatial.clear()
	for raw in _enemies_cache:
		if _valid_target(raw):
			_index_target(raw)


func _index_target(target: Node2D) -> void:
	if not _valid_target(target):
		return
	var shape := SlasherHitGeometry.body(target)
	var a: Vector2 = shape.a
	var b: Vector2 = shape.b
	var padding := Vector2.ONE * (float(shape.radius) + 8.0)
	var minimum := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - padding
	var maximum := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + padding
	for x in range(floori(minimum.x / TARGET_CELL), floori(maximum.x / TARGET_CELL) + 1):
		for y in range(floori(minimum.y / TARGET_CELL), floori(maximum.y / TARGET_CELL) + 1):
			var cell := Vector2i(x, y)
			if not _spatial.has(cell):
				_spatial[cell] = []
			if not _spatial[cell].has(target):
				_spatial[cell].append(target)


func _segment_candidates(start: Vector2, end: Vector2, padding: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var seen: Dictionary = {}
	var minimum := Vector2(minf(start.x, end.x), minf(start.y, end.y)) - Vector2.ONE * padding
	var maximum := Vector2(maxf(start.x, end.x), maxf(start.y, end.y)) + Vector2.ONE * padding
	for x in range(floori(minimum.x / TARGET_CELL), floori(maximum.x / TARGET_CELL) + 1):
		for y in range(floori(minimum.y / TARGET_CELL), floori(maximum.y / TARGET_CELL) + 1):
			for raw in _spatial.get(Vector2i(x, y), []):
				if not _valid_target(raw) or seen.has(raw.get_instance_id()):
					continue
				seen[raw.get_instance_id()] = true
				result.append(raw)
	return result


func _wall(start: Vector2, end: Vector2) -> Dictionary:
	if start.is_equal_approx(end) or not is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters2D.create(start, end, 1, _ray_exclusions)
	query.hit_from_inside = true
	var excluded := _ray_exclusions.duplicate()
	for i in 32:
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.get("collider") is StaticBody2D:
			return hit
		excluded.append(hit.rid)
		query.exclude = excluded
	return {"position": start}


func _nearest(
	point: Vector2,
	excluded: Dictionary = {},
	reach: float = 99999.0,
	only_marks: bool = false,
	require_sight: bool = true
) -> Node2D:
	var best: Node2D
	var distance := reach
	for foe in _enemies() if reach > 2000.0 else _segment_candidates(point, point, reach):
		var id := _combat_id(foe)
		if excluded.has(id) or (only_marks and not marked.has(id)):
			continue
		var d := point.distance_to(foe.global_position)
		if d < distance and (not require_sight or _wall(point, foe.global_position).is_empty()):
			distance = d
			best = foe
	return best


func _record(values: Dictionary) -> Dictionary:
	var result: Dictionary = {} if _pool.is_empty() else _pool.pop_back()
	result.clear()
	result.merge(values)
	return result


func _recycle(list: Array, index: int) -> void:
	var record: Dictionary = list[index]
	list.remove_at(index)
	record.clear()
	if _pool.size() < int(value("record_cap", 256)):
		_pool.append(record)


func _pulse(point: Vector2, radius: float, color: Color, duration: float = 0.35) -> void:
	if impacts.size() >= int(value("impact_cap", 48)):
		_recycle(impacts, 0)
	impacts.append(
		_record(
			{
				"point": point,
				"radius": radius,
				"color": color,
				"left": duration,
				"duration": duration
			}
		)
	)


func _ribbon(point: Vector2, end: Vector2, color: Color, duration: float = 0.35) -> void:
	_pulse(point, 12.0, color, duration)
	impacts.back()["end"] = end


func _base(multiplier: float = 1.0) -> int:
	return maxi(1, roundi(maxi(actor.spell_power, actor.attack_power) * multiplier))


func _hit(target: Node2D, damage: int, kind: String, extra: Dictionary = {}) -> void:
	if not _valid_target(target):
		return
	var data := actor._attack_data(damage, kind, extra)
	data["mage_secondary"] = true
	target.receive_attack(actor.adjust_active_weapon_attack(target, data), actor)
	_index_target(target)


func _damage_area(
	point: Vector2,
	radius: float,
	multiplier: float,
	kind: String,
	extra: Dictionary = {},
	limit: Dictionary = {},
	cap: int = 0
) -> int:
	var count := 0
	var seen: Dictionary = {}
	for foe in _segment_candidates(point, point, radius):
		var id := _combat_id(foe)
		if seen.has(id):
			continue
		if cap > 0 and int(limit.get(id, 0)) >= cap:
			continue
		if (
			SlasherHitGeometry.overlaps_circle(point, radius, foe)
			and _wall(point, foe.global_position).is_empty()
		):
			seen[id] = true
			if cap > 0:
				limit[id] = int(limit.get(id, 0)) + 1
			_hit(foe, _base(multiplier), kind, extra)
			count += 1
	return count


func _attack_once(attack: Dictionary, key: String, cap: int = 1) -> bool:
	var id := String(attack.get("attack_id", ""))
	if id.is_empty():
		return false
	var record_key := key + id
	var count := int(_attack_records.get(record_key, 0))
	if count >= cap:
		return false
	_attack_records[record_key] = count + 1
	while _attack_records.size() > int(value("record_cap", 256)):
		_attack_records.erase(_attack_records.keys()[0])
	return true


func adjust_external_attack(_target: Node2D, attack: Dictionary) -> Dictionary:
	if not is_held():
		return attack
	var result := attack.duplicate(true)
	if (
		item_id == "tome_of_toth"
		and active_time > 0.0
		and not bool(result.get("tome_empowered", false))
	):
		result.damage = maxi(
			1,
			roundi(float(result.get("damage", 1)) * (1.0 + value("damage_per_stack") * tome_stacks))
		)
		result.tome_empowered = true
	if item_id == "arachne_staff" and not caught.is_empty():
		result.damage = maxi(
			1,
			roundi(
				(
					float(result.get("damage", 1))
					* (
						1.0
						+ value("damage_per_enemy") * mini(int(value("bonus_cap")), caught.size())
					)
				)
			)
		)
	return result


func fire_basic() -> bool:
	if not is_held() or item_id != "tome_of_toth" or active_time <= 0.0:
		return false
	_fire_bolt("tome", value("damage"), "aether")
	return true


func on_external_hit(target: SlasherEnemy, attack: Dictionary, was_dead: bool) -> void:
	if not is_held() or not is_instance_valid(target) or was_dead:
		return
	var source := String(attack.get("damage_source", ""))
	match item_id:
		"michaels_orb":
			if (
				active_time > 0.0
				and String(attack.get("action_slot", "")) == "basic"
				and not bool(attack.get("mage_secondary", false))
				and not bool(attack.get("item_proc", false))
				and _attack_once(attack, "orb", int(value("charge_per_attack")))
			):
				orb_energy = mini(int(value("charges")), orb_energy + 1)
				_ribbon(
					target.global_position,
					actor.global_position + _orb_position(),
					Color("#b6eaff"),
					0.3
				)
				_try_orb()
		"gulthias_staff":
			if target.dead and source == "gulthias_staff":
				_spawn_foliage(target.global_position)
		"tome_of_toth":
			if (
				active_time > 0.0
				and (
					source == "tome"
					or (
						not bool(attack.get("mage_secondary", false))
						and attack.has("projectile_id")
					)
				)
				and _attack_once(attack, "tome")
			):
				tome_stacks = mini(tome_capacity(), tome_stacks + 1)


func on_projectile_miss(attack: Dictionary) -> void:
	if not is_held() or item_id != "tome_of_toth" or active_time <= 0.0:
		return
	if (
		bool(attack.get("enemy_hit", false))
		or (
			bool(attack.get("mage_secondary", false))
			and String(attack.get("damage_source", "")) != "tome"
		)
	):
		return
	if _attack_once(attack, "tome"):
		tome_stacks = maxi(
			0, tome_stacks - maxi(1, ceili(tome_stacks * value("miss_loss_fraction")))
		)
		_pulse(actor.global_position, 35.0, Color("#9b779a"))


func tome_capacity() -> int:
	return mini(
		int(value("stack_cap")),
		int(value("base_capacity")) + tome_souls * int(value("capacity_per_soul"))
	)


func _on_enemy_death(enemy: SlasherEnemy, _reward: int) -> void:
	if not is_held():
		return
	var id := enemy.get_instance_id()
	match item_id:
		"jade_serpent_staff":
			if marked.has(id):
				var allow := String(enemy.incoming_source) != "spectral_snake"
				marked.erase(id)
				poison.erase(id)
				if allow:
					_launch_snake(enemy.global_position)
		"dragonstaff_of_ahghairon":
			if heat.has(id) and float(heat[id].burn) > 0.0:
				if remains.size() >= int(value("remains_cap")):
					_recycle(remains, 0)
				remains.append(
					_record(
						{"point": enemy.global_position, "left": value("remains_life"), "age": 0.0}
					)
				)
			heat.erase(id)
		"tome_of_toth":
			if (
				active_time > 0.0
				and actor.global_position.distance_to(enemy.global_position) <= value("soul_range")
			):
				tome_souls = mini(int(value("soul_cap")), tome_souls + 1)
				_ribbon(
					enemy.global_position,
					actor.global_position - Vector2(24, 24),
					Color("#b287ff"),
					0.45
				)


func _try_orb() -> void:
	if orb_energy < int(value("charges")) or missiles.size() >= int(value("missile_cap")):
		return
	var target := _nearest(actor.global_position, {}, value("range"))
	if target != null:
		orb_energy = 0
		_launch_orb(target)


func _launch_orb(first: Node2D) -> void:
	if not is_instance_valid(first):
		return
	orb_recoil = 0.25
	_new_missile(
		"orb",
		actor.global_position + _orb_position(),
		first,
		{
			"bounces": int(value("impacts")),
			"element": ["fire", "ice", "lightning"][_serial % 3],
			"multiplier": value("damage")
		}
	)


func _orb_position() -> Vector2:
	var angle := visual_clock * (2.0 + orb_energy * 0.5)
	return (
		Vector2(cos(angle) * 28.0, -34.0 + sin(angle) * 10.0)
		- actor.aim_direction * orb_recoil * 24.0
	)


func _new_missile(kind: String, point: Vector2, target: Node2D, extra: Dictionary = {}) -> void:
	if missiles.size() >= int(value("missile_cap")):
		return
	_serial += 1
	var data: Dictionary = {
		"kind": kind,
		"position": point,
		"target": target,
		"heading": actor.aim_direction.normalized(),
		"speed": value("projectile_speed"),
		"hits": {},
		"bounces": 1,
		"left": value("missile_life"),
		"windup": value("windup"),
		"traveled": 0.0,
		"id": "%d:%d" % [get_instance_id(), _serial],
		"trail": []
	}
	data.merge(extra, true)
	missiles.append(_record(data))


func _fire_bolt(kind: String, multiplier: float, element: String, extra: Dictionary = {}) -> void:
	var data: Dictionary = {"multiplier": multiplier, "element": element}
	data.merge(extra, true)
	_new_missile(kind, actor.global_position + actor.aim_direction * 20.0, null, data)
	phase = "recovery"
	phase_time = value("windup") + value("recovery")
	_pulse(
		actor.global_position + actor.aim_direction * 24,
		20,
		Color("#d7edc4"),
		value("windup") + 0.12
	)


func _fire_gulthias_bolt() -> void:
	_fire_bolt("gulthias_staff", value("damage"), "aether")


func _fire_jade_dart() -> void:
	_fire_bolt("jade_serpent", value("damage"), "poison")


func _mark_poison(target: Node2D, snake_origin: bool = false) -> void:
	if not _valid_target(target):
		return
	var id := _combat_id(target)
	if not poison.has(id) and poison.size() >= int(value("record_cap")):
		return
	marked[id] = target
	var old: Dictionary = poison.get(id, {})
	poison[id] = {
		"target": target,
		"time": value("mark_duration"),
		"tick": float(old.get("tick", value("poison_tick"))),
		"stacks": mini(int(value("poison_cap")), int(old.get("stacks", 0)) + 1),
		"snake_origin": snake_origin
	}
	var body := _body(target)
	body.apply_mage_slow(get_instance_id(), value("slow"), value("mark_duration"))
	if not body.defeated.is_connected(_on_enemy_death):
		body.defeated.connect(_on_enemy_death)
		_observed[id] = weakref(body)


func _process_poison(delta: float) -> void:
	for id in poison.keys():
		var state: Dictionary = poison[id]
		var raw: Variant = state.get("target")
		if _body(raw) == null or raw.dead:
			poison.erase(id)
			marked.erase(id)
			continue
		state.time -= delta
		state.tick -= delta
		if float(state.time) <= 0.0:
			poison.erase(id)
			marked.erase(id)
			continue
		if float(state.tick) <= 0.0:
			state.tick += value("poison_tick")
			_hit(
				raw,
				_base(value("poison_damage") * int(state.stacks)),
				"poison",
				{"damage_source": "spectral_snake" if bool(state.snake_origin) else "jade_poison"}
			)


func _launch_snake(point: Vector2) -> void:
	if (
		missiles.filter(func(shot: Dictionary): return shot.kind == "snake").size()
		>= int(value("snake_cap"))
	):
		return
	var target := _nearest(point, {}, value("snake_range"), true)
	if target != null:
		_new_missile(
			"snake",
			point,
			target,
			{
				"bounces": int(value("snake_targets")),
				"left": value("snake_life"),
				"multiplier": value("bite_damage"),
				"element": "poison"
			}
		)


func _process_missiles(delta: float) -> void:
	# New serpent records can be appended by death callbacks; never process those
	# until the next fixed step.
	for index in range(missiles.size() - 1, -1, -1):
		var shot: Dictionary = missiles[index]
		shot.left = float(shot.get("left", value("missile_life"))) - delta
		shot.windup = maxf(0.0, float(shot.get("windup", 0.0)) - delta)
		if float(shot.left) <= 0.0:
			_finish_missile(index)
			continue
		if float(shot.windup) > 0.0:
			continue
		var kind := String(shot.kind)
		var seeking := kind in ["orb", "snake"]
		var target: Node2D
		var raw: Variant = shot.get("target")
		if _valid_target(raw):
			target = raw
		var pos: Vector2 = shot.position
		if seeking:
			if target == null or (kind == "snake" and not marked.has(_combat_id(target))):
				target = _nearest(
					pos,
					shot.hits,
					value("snake_range", value("bounce_range", 340)),
					kind == "snake"
				)
			if target == null:
				_finish_missile(index)
				continue
			shot.target = target
			if (
				kind == "snake"
				and pos.distance_to(target.global_position) < 55.0
				and not bool(shot.get("bite_ready", false))
			):
				shot["bite_ready"] = true
				shot["bite_pause"] = value("bite_windup")
			if float(shot.get("bite_pause", 0.0)) > 0.0:
				shot.bite_pause = maxf(0.0, float(shot.bite_pause) - delta)
				continue
			var heading: Vector2 = shot.get("heading", actor.aim_direction)
			var desired := pos.direction_to(target.global_position)
			shot.heading = heading.rotated(
				clampf(
					heading.angle_to(desired),
					-value("turn_rate") * delta,
					value("turn_rate") * delta
				)
			)
		var end: Vector2 = pos + Vector2(shot.heading) * float(shot.speed) * delta
		var wall := _wall(pos, end)
		var wall_t := (
			pos.distance_to(wall.position) / maxf(0.001, pos.distance_to(end))
			if not wall.is_empty()
			else INF
		)
		var contact := wall_t
		var victim: Node2D
		var plant_index := -1
		if kind == "gulthias_staff":
			for i in plants.size():
				var plant: Dictionary = plants[i]
				if float(plant.age) < value("growth_time"):
					continue
				var t := SlasherHitGeometry._circle_time(pos, end, plant.point, 18.0)
				if t < contact:
					contact = t
					plant_index = i
		for foe in _segment_candidates(pos, end, value("projectile_radius")):
			if shot.hits.has(_combat_id(foe)) or (seeking and foe != target):
				continue
			var t := SlasherHitGeometry.sweep(pos, end, foe, value("projectile_radius"))
			if t < contact:
				contact = t
				victim = foe
				plant_index = -1
		shot.position = pos.lerp(end, contact) if contact != INF else end
		shot.traveled = float(shot.get("traveled", 0.0)) + pos.distance_to(shot.position)
		var trail: Array = shot.get("trail", [])
		trail.push_front(shot.position)
		if trail.size() > 12:
			trail.pop_back()
		shot.trail = trail
		if plant_index >= 0:
			if treants.size() < int(value("summon_cap")):
				spawn_treant(plants[plant_index].point)
				_recycle(plants, plant_index)
			_finish_missile(index)
			continue
		if victim != null:
			shot.hits[_combat_id(victim)] = true
			var extra: Dictionary = {
				"damage_source":
				"michaels_orb" if kind == "orb" else "spectral_snake" if kind == "snake" else kind,
				"attack_id": shot.get("id", ""),
				"projectile_id": shot.get("id", "")
			}
			if kind == "jade_serpent":
				_mark_poison(victim)
			if kind == "snake":
				_mark_poison(victim, true)
			_hit(
				victim,
				_base(float(shot.get("multiplier", 1.0))),
				String(shot.get("element", "aether")),
				extra
			)
			if kind == "orb":
				_damage_area(
					shot.position,
					value("splash_radius"),
					(
						value("splash_damage")
						* pow(value("bounce_falloff"), int(value("impacts")) - int(shot.bounces))
					),
					shot.element,
					extra
				)
				_pulse(shot.position, value("splash_radius"), Color("#9eeaff"))
				shot.multiplier *= value("bounce_falloff")
			elif kind == "skyblinder":
				_sky_impact(shot, victim)
			else:
				_pulse(shot.position, 18.0, Color("#84e9a0"))
			shot.bounces -= 1
			shot["bite_ready"] = false
			if int(shot.bounces) <= 0 or not seeking:
				_finish_missile(index)
				continue
			shot.target = _nearest(
				shot.position,
				shot.hits,
				value("snake_range", value("bounce_range", 340)),
				kind == "snake"
			)
			if shot.target == null:
				_finish_missile(index)
		elif wall_t != INF or float(shot.traveled) >= value("projectile_range"):
			if kind == "skyblinder" and wall_t != INF:
				shot.position -= Vector2(shot.heading)
				_sky_impact(shot, null)
			_finish_missile(index)


func _finish_missile(index: int) -> void:
	var shot: Dictionary = missiles[index]
	if shot.kind == "tome" and Dictionary(shot.hits).is_empty():
		on_projectile_miss(
			{"damage_source": "tome", "attack_id": shot.id, "projectile_id": shot.id}
		)
	_pulse(shot.position, 12.0, Color("#a6c9d8"), 0.2)
	if shot.kind == "snake":
		impacts.back()["snake_tail"] = Array(shot.get("trail", [])).duplicate()
		impacts.back()["color"] = Color("#7de794")
	_recycle(missiles, index)


func _valid_ground(point: Vector2) -> Vector2:
	for i in 9:
		var candidate := point + Vector2.from_angle(i * TAU / 8.0) * (0.0 if i == 0 else 28.0)
		if actor.pathfinder != null:
			var cell := actor.pathfinder.world_to_cell(candidate)
			if not actor.pathfinder.is_walkable_cell(cell):
				continue
			if (
				actor
				. pathfinder
				. find_cell_path(actor.pathfinder.world_to_cell(actor.global_position), cell)
				. is_empty()
			):
				continue
		elif not _wall(actor.global_position, candidate).is_empty():
			continue
		var clear := true
		for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
			if not _wall(candidate, candidate + direction * 18.0).is_empty():
				clear = false
				break
		if clear:
			return candidate
	return Vector2.INF


func _spawn_foliage(point: Vector2) -> void:
	if plants.size() >= int(value("growth_cap")):
		return
	var ground := _valid_ground(point)
	if ground == Vector2.INF:
		return
	plants.append(_record({"point": ground, "age": 0.0, "left": value("growth_life")}))


func spawn_treant(point: Vector2) -> void:
	if treants.size() >= int(value("summon_cap")):
		return
	var ground := _valid_ground(point)
	if ground == Vector2.INF:
		return
	treants.append(
		_record(
			{
				"point": ground,
				"left": value("summon_life"),
				"cooldown": 0.0,
				"windup": 0.0,
				"target": null,
				"scan": 0.0
			}
		)
	)
	_pulse(ground, 35.0, Color("#87af58"))


func _process_growth(delta: float) -> void:
	for i in range(plants.size() - 1, -1, -1):
		plants[i].age += delta
		plants[i].left -= delta
		if float(plants[i].left) <= 0.0:
			_recycle(plants, i)
	for i in range(treants.size() - 1, -1, -1):
		var tree: Dictionary = treants[i]
		tree.left -= delta
		tree.cooldown = maxf(0.0, float(tree.cooldown) - delta)
		tree.scan -= delta
		if float(tree.left) <= 0.0:
			_pulse(tree.point, 28.0, Color("#876947"))
			_recycle(treants, i)
			continue
		if float(tree.windup) > 0.0:
			tree.windup -= delta
			if float(tree.windup) <= 0.0:
				_damage_area(
					tree.point,
					value("stomp_radius"),
					value("stomp_damage"),
					"physical",
					{"damage_source": "gulthias_treant", "knockback": 25.0}
				)
				_pulse(tree.point, value("stomp_radius"), Color("#a9be70"))
				tree.cooldown = value("stomp_recovery")
			continue
		if float(tree.scan) <= 0.0:
			tree.target = _nearest(tree.point, {}, value("summon_range"), false, false)
			tree.scan = 0.25
		var raw: Variant = tree.target
		if _body(raw) == null or raw.dead:
			continue
		if Vector2(tree.point).distance_to(raw.global_position) <= value("stomp_radius"):
			if float(tree.cooldown) <= 0.0:
				tree.windup = value("stomp_windup")
		else:
			var destination: Vector2 = (
				actor.pathfinder.next_waypoint(tree.point, raw.global_position)
				if actor.pathfinder != null
				else raw.global_position
			)
			var direction := Vector2(tree.point).direction_to(destination)
			for angle in [0.0, 0.8, -0.8, 1.5, -1.5]:
				var step := direction.rotated(angle) * value("summon_speed") * delta
				if (
					_wall(tree.point, Vector2(tree.point) + step + step.normalized() * 16.0)
					. is_empty()
				):
					tree.point += step
					break


func _process_skyblinder(delta: float) -> void:
	if phase != "charging":
		return
	charge_time = minf(value("charge_time"), charge_time + delta)
	if charge_time >= value("charge_time") and not _full_charge_cue:
		_full_charge_cue = true
		AudioCue.play_from(actor, "combo")
	if not channel_held:
		_release_skyblinder()
	elif active_time <= 0.0:
		cancel()


func _release_skyblinder() -> void:
	var ratio := clampf(charge_time / value("charge_time"), 0.0, 1.0)
	_fire_bolt(
		"skyblinder",
		lerpf(value("damage"), value("charged_damage"), ratio),
		"radiant",
		{"ratio": ratio}
	)
	charge_time = 0.0
	active_time = 0.0


func _sky_impact(shot: Dictionary, primary: Node2D) -> void:
	var ratio := float(shot.ratio)
	var radius := value("radius") if ratio >= 0.999 else lerpf(12.0, value("partial_radius"), ratio)
	_pulse(shot.position, radius, Color("#fff4a6"))
	var victims: Array[Node2D] = [primary]
	if ratio > 0.05:
		victims = _enemies().filter(
			func(foe: Node2D): return SlasherHitGeometry.overlaps_circle(shot.position, radius, foe) and _wall(shot.position, foe.global_position).is_empty()
		)
	for foe in victims:
		if not is_instance_valid(foe) or foe.dead:
			continue
		if foe != primary:
			_hit(foe, _base(float(shot.multiplier)), "radiant", {"damage_source": "skyblinder"})
		var body := _body(foe)
		var resistance := value("boss_control_scale") if body.boss or body.mini_boss else 1.0
		body.apply_disorientation(value("disorient") * resistance, get_instance_id())
		if ratio > 0.05:
			body.apply_mage_stun(get_instance_id(), value("stun") * ratio * resistance)


func _process_dragonfire(delta: float) -> void:
	for i in range(remains.size() - 1, -1, -1):
		var corpse: Dictionary = remains[i]
		corpse.left -= delta
		corpse.age += delta
		if corpse.has("harvesting"):
			corpse.harvesting -= delta
			if float(corpse.harvesting) > 0.0:
				continue
			dragon_fuel = minf(value("fuel_cap"), dragon_fuel + value("fuel_per_corpse"))
			_recycle(remains, i)
		elif (
			float(corpse.age) > 0.15
			and actor.global_position.distance_to(corpse.point) <= value("harvest_range")
			and _wall(actor.global_position, corpse.point).is_empty()
		):
			corpse["harvesting"] = value("harvest_travel")
			_ribbon(
				corpse.point,
				actor.global_position + actor.aim_direction * 24,
				Color("#ffbb66"),
				value("harvest_travel")
			)
		elif float(corpse.left) <= 0.0:
			_recycle(remains, i)
	for id in heat.keys():
		var state: Dictionary = heat[id]
		var raw: Variant = state.target
		if not is_instance_valid(raw) or raw.dead:
			heat.erase(id)
			continue
		state.burn = maxf(0.0, float(state.burn) - delta)
		state.heat = maxf(0.0, float(state.heat) - delta * 0.1)
		state.tick -= delta
		if float(state.burn) > 0.0 and float(state.tick) <= 0.0:
			state.tick = value("burn_tick")
			_hit(raw, _base(value("burn_damage")), "fire", {"damage_source": "dragon_burn"})
		elif float(state.burn) <= 0.0 and float(state.heat) <= 0.0:
			heat.erase(id)
	if phase != "channel":
		dragon_fuel = minf(value("fuel_cap"), dragon_fuel + value("regen") * delta)
		return
	if not channel_held or dragon_fuel <= 0.0:
		phase = "recovery"
		phase_time = value("recovery")
		active_time = 0.0
		return
	if phase_time > 0.0:
		return
	flame_boundary = PackedVector2Array([actor.global_position])
	for i in 13:
		var direction := actor.aim_direction.rotated(
			lerpf(-value("half_angle"), value("half_angle"), float(i) / 12.0)
		)
		var end := actor.global_position + direction * value("range")
		var hit := _wall(actor.global_position, end)
		flame_boundary.append(Vector2(hit.position) if not hit.is_empty() else end)
	dragon_fuel = maxf(0.0, dragon_fuel - delta)
	active_time = dragon_fuel
	tick_time -= delta
	while tick_time <= 0.0:
		tick_time += value("tick")
		for foe in _enemies():
			var offset := foe.global_position - actor.global_position
			if (
				offset.length() > value("range")
				or actor.aim_direction.dot(offset.normalized()) < cos(value("half_angle"))
				or not _wall(actor.global_position, foe.global_position).is_empty()
			):
				continue
			var id := _combat_id(foe)
			if not heat.has(id) and heat.size() >= int(value("record_cap")):
				continue
			var state: Dictionary = heat.get(
				id, {"target": foe, "heat": 0.0, "burn": 0.0, "tick": value("burn_tick")}
			)
			state.heat = minf(value("heat_cap"), float(state.heat) + value("tick"))
			if float(state.heat) >= value("ignite_heat"):
				state.burn = value("burn_duration")
			heat[id] = state
			_hit(foe, _base(value("damage")), "fire", {"damage_source": "dragonstaff"})


func _process_web(delta: float) -> void:
	if web_active:
		if (
			active_time <= 0.0
			or web_length >= value("max_length")
			or web_segments.size() >= int(value("segment_cap"))
		):
			_end_web()
		else:
			var point := actor.global_position
			var from: Vector2 = web_points.back()
			var distance := from.distance_to(point)
			if distance > value("teleport_distance") or not _wall(from, point).is_empty():
				web_points = [point]
			elif distance >= value("segment_length"):
				while (
					from.distance_to(point) >= value("segment_length")
					and web_segments.size() < int(value("segment_cap"))
					and web_length < value("max_length")
				):
					var next := from.move_toward(
						point, minf(value("segment_length"), value("max_length") - web_length)
					)
					web_segments.append(_record({"a": from, "b": next, "left": value("persist")}))
					web_length += from.distance_to(next)
					from = next
				web_points.append(from)
				if web_points.size() > int(value("segment_cap")):
					web_points.pop_front()
	for i in range(web_segments.size() - 1, -1, -1):
		if not web_active:
			web_segments[i].left -= delta
		if float(web_segments[i].left) <= 0.0:
			_recycle(web_segments, i)
	caught.clear()
	for foe in _enemies():
		for segment in web_segments:
			if (
				(
					(
						Geometry2D
						. get_closest_point_to_segment(foe.global_position, segment.a, segment.b)
						. distance_to(foe.global_position)
					)
					<= value("width")
				)
				and (
					_wall(
						foe.global_position,
						Geometry2D.get_closest_point_to_segment(
							foe.global_position, segment.a, segment.b
						)
					)
					. is_empty()
				)
			):
				caught[_combat_id(foe)] = foe
				_body(foe).apply_mage_slow(get_instance_id(), value("slow"), value("linger"))
				break
	if is_instance_valid(actor.kit_buffs):
		actor.kit_buffs.clear_source("arachne_web")
		if not caught.is_empty():
			actor.kit_buffs.grant_speed(
				"arachne_web",
				1.0 + value("speed_per_enemy") * mini(int(value("bonus_cap")), caught.size()),
				0.1
			)


func _end_web() -> void:
	web_active = false
	active_time = 0.0
	if is_held():
		ActiveItems.spend(actor.run_state)
	_pulse(actor.global_position, 20.0, Color("#d8cbea"))


func set_targeting_origin(requested: Vector2) -> void:
	var offset := requested - actor.global_position
	var point := actor.global_position + offset.limit_length(value("start_range"))
	var wall := _wall(actor.global_position, point)
	aim_start = Vector2(wall.position) - offset.normalized() * 4.0 if not wall.is_empty() else point


func _update_preview() -> void:
	var stick := Input.get_vector(
		"slasher_aim_left", "slasher_aim_right", "slasher_aim_up", "slasher_aim_down"
	)
	if stick.length() > 0.2:
		_shango_mouse = false
		aim_direction = stick.normalized()
	elif _shango_mouse:
		var drag := actor.get_global_mouse_position() - aim_start
		if drag.length() > 12.0:
			aim_direction = drag.normalized()
	else:
		aim_direction = actor.aim_direction.normalized()
	if aim_direction.is_zero_approx():
		aim_direction = Vector2.RIGHT
	preview.clear()
	for i in int(value("count")):
		var next := aim_start + aim_direction * value("spacing") * i
		if not _wall(aim_start, next).is_empty():
			break
		preview.append(next)


func _cast_shango() -> void:
	if preview.is_empty():
		_update_preview()
	delayed_bursts.clear()
	_shango_hits.clear()
	var line_hits: Dictionary = {}
	for i in preview.size():
		var point: Vector2 = preview[i]
		var delay := value("delay") + i * value("sequence_delay")
		delayed_bursts.append(
			_record({"time": delay, "delay": delay, "point": point, "radius": value("radius")})
		)
	if not preview.is_empty():
		_ribbon(preview.front(), preview.back(), Color("#dcf3ff"), 0.15)
		impacts.back()["ray"] = true
		for foe in _enemies():
			if (
				(
					SlasherHitGeometry.sweep(
						preview.front(), preview.back(), foe, value("line_width")
					)
					!= INF
				)
				and _wall(aim_start, foe.global_position).is_empty()
			):
				if not line_hits.has(_combat_id(foe)):
					line_hits[_combat_id(foe)] = true
					_hit(
						foe,
						_base(value("lightning_damage")),
						"lightning",
						{"damage_source": "shango_lightning"}
					)
	phase = "recovery"
	phase_time = value("recovery")
	preview.clear()


func _process_delayed(delta: float) -> void:
	# Forward iteration preserves start-to-end order even after a long frame.
	var i := 0
	while i < delayed_bursts.size():
		var burst: Dictionary = delayed_bursts[i]
		burst.time -= delta
		if float(burst.time) <= 0.0:
			_damage_area(
				burst.point,
				burst.radius,
				value("thunder_damage"),
				"thunder",
				{"damage_source": "shango_thunder"},
				_shango_hits,
				int(value("overlap_cap"))
			)
			_pulse(burst.point, burst.radius, Color("#8dbbff"), 0.45)
			impacts.back()["plume"] = true
			_recycle(delayed_bursts, i)
		else:
			i += 1


func on_owner_damaged(amount: int, enemy_damage: bool = false) -> void:
	if not is_held():
		return
	if (
		item_id == "solar_scepter"
		and active_time > 0.0
		and amount > 0
		and enemy_damage
		and flare_cooldown <= 0.0
	):
		flare_cooldown = value("flare_cooldown")
		flare_pending = value("flare_windup")


func fire_vulnerability(target: SlasherEnemy) -> float:
	return (
		1.0 + float(exposure.get(target.get_instance_id(), 0.0)) * value("fire_bonus")
		if is_held() and item_id == "solar_scepter"
		else 1.0
	)


func _process_solar(delta: float) -> void:
	var inside: Dictionary = {}
	if active_time > 0.0:
		for foe in _enemies():
			if (
				actor.global_position.distance_to(foe.global_position) > value("radius")
				or not _wall(actor.global_position, foe.global_position).is_empty()
			):
				continue
			var id := _combat_id(foe)
			if inside.has(id):
				continue
			if not exposure.has(id) and exposure.size() >= int(value("record_cap")):
				continue
			inside[id] = true
			var previous := float(exposure.get(id, 0.0))
			exposure[id] = minf(value("exposure_cap"), previous + delta)
			if (
				previous < value("disorient_threshold")
				and float(exposure[id]) >= value("disorient_threshold")
			):
				var body := _body(foe)
				body.apply_disorientation(
					(
						value("disorient_duration")
						* (value("boss_control_scale") if body.boss or body.mini_boss else 1.0)
					),
					get_instance_id()
				)
		tick_time -= delta
		while tick_time <= 0.0:
			tick_time += value("tick")
			_damage_area(
				actor.global_position,
				value("radius"),
				value("damage"),
				"radiant",
				{"damage_source": "solar_aura"}
			)
	for id in exposure.keys():
		if not inside.has(id):
			exposure[id] = maxf(0.0, float(exposure[id]) - delta * value("exposure_decay"))
			if float(exposure[id]) <= 0.0:
				exposure.erase(id)
	if flare_pending > 0.0:
		flare_pending -= delta
		if flare_pending <= 0.0:
			_damage_area(
				actor.global_position,
				value("flare_radius"),
				value("flare_damage"),
				"fire",
				{"damage_source": "solar_flare"}
			)
			_pulse(actor.global_position, value("flare_radius"), Color("#ffb85b"), 0.4)


func gravity_radius() -> float:
	return minf(value("max_radius"), value("radius") + charge_time * value("growth"))


func _process_gravity(delta: float) -> void:
	if phase != "channel":
		return
	if active_time <= 0.0 or not channel_held:
		_pulse(anchor, gravity_radius(), Color("#b984f0"), 0.25)
		impacts.back()["contract"] = true
		if _owns_lock:
			actor.input_locked = false
		_owns_lock = false
		phase = "recovery"
		phase_time = value("recovery")
		charge_time = 0.0
		active_time = 0.0
		return
	actor.global_position = anchor
	actor.velocity = Vector2.ZERO
	charge_time += delta
	var radius := gravity_radius()
	for foe in _enemies():
		var offset := anchor - foe.global_position
		if offset.length() > radius or not _wall(anchor, foe.global_position).is_empty():
			continue
		var direction := (
			offset.normalized()
			if offset.length() > 0.01
			else Vector2.from_angle(foe.get_instance_id() % 360)
		)
		if foe is SlasherColossusWeakPoint:
			continue
		var body := _body(foe)
		var resistance := (
			value("boss_control_scale")
			if body.boss or body.mini_boss
			else clampf(float(body.tuning.get("received_knockback_multiplier", 1.0)), 0.1, 1.0)
		)
		var radial := clampf(
			offset.length() - value("inner_orbit"),
			-value("pull_speed") * delta,
			value("pull_speed") * delta
		)
		body.move_and_collide(
			(
				(direction * radial + direction.orthogonal() * value("swirl_speed") * delta)
				* resistance
			)
		)
	tick_time -= delta
	while tick_time <= 0.0:
		tick_time += value("tick")
		_damage_area(
			anchor, radius, value("damage"), "aether", {"damage_source": "drumamu_gravity"}
		)


func status_text() -> String:
	if item_id in ["michaels_orb", "tome_of_toth"] and active_time <= 0.0:
		return "SPACE · AWAKEN"
	match item_id:
		"michaels_orb":
			return (
				"ORB %d/%d%s"
				% [
					orb_energy,
					int(value("charges")),
					" READY" if orb_energy >= int(value("charges")) else ""
				]
			)
		"gulthias_staff":
			return (
				"GROWTH %d/%d · TREANTS %d/%d"
				% [
					plants.size(),
					int(value("growth_cap")),
					treants.size(),
					int(value("summon_cap"))
				]
			)
		"skyblinder_staff":
			return (
				"LIGHT %d%% · RELEASE" % roundi(charge_time / value("charge_time") * 100)
				if phase == "charging"
				else "HOLD SPACE · CHARGE"
			)
		"dragonstaff_of_ahghairon":
			return "FUEL %.1f/%.1f · HOLD SPACE" % [dragon_fuel, value("fuel_cap")]
		"jade_serpent_staff":
			return (
				"MARKS %d · SERPENTS %d"
				% [
					marked.size(),
					missiles.filter(func(s: Dictionary): return s.kind == "snake").size()
				]
			)
		"arachne_staff":
			return (
				"CAUGHT %d/%d · %s"
				% [
					mini(caught.size(), int(value("bonus_cap"))),
					int(value("bonus_cap")),
					(
						"SPACE TO CUT"
						if web_active
						else "SILK FADING" if not web_segments.is_empty() else "SPACE TO ANCHOR"
					)
				]
			)
		"tome_of_toth":
			return "SOULS %d · POWER %d/%d" % [tome_souls, tome_stacks, tome_capacity()]
		"shangos_shatterer":
			return (
				"DRAG DIRECTION · RELEASE · ESC CANCEL"
				if phase == "aiming"
				else "SPACE AT CURSOR · THUNDER %d" % delayed_bursts.size()
			)
		"solar_scepter":
			return (
				"AURA %.1fs · FLARE %s"
				% [active_time, "READY" if flare_cooldown <= 0.0 else "%.1fs" % flare_cooldown]
			)
		"drumamus_bargain":
			return (
				"VORTEX %d%% · RELEASE TO END" % roundi(charge_time / value("duration") * 100)
				if phase == "channel"
				else "HOLD SPACE · ANCHOR"
			)
	return ""


func _draw() -> void:
	if not is_held():
		return
	_draw_effects()


func _ring(point: Vector2, radius: float, color: Color, width: float = 2.0) -> void:
	draw_arc(point, radius, 0, TAU, 24 if _reduced else 64, color, width, true)


func _draw_effects() -> void:
	var origin := actor.global_position
	var detail := 4 if _reduced else 10
	var font := ThemeDB.fallback_font
	var text := status_text()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	draw_style_box(
		_status_backdrop(),
		Rect2(Vector2(-text_size.x * 0.5 - 6, 42), Vector2(text_size.x + 12, 20))
	)
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, 56),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color("#e9eee3")
	)
	for fx in impacts:
		var progress := 1.0 - float(fx.left) / float(fx.duration)
		var color := Color(fx.color, 0.8 * (1.0 - progress))
		if fx.has("snake_tail"):
			var trail: Array = fx.snake_tail
			var count := maxi(0, floori(trail.size() * (1.0 - progress)))
			for i in range(1, count):
				draw_line(
					Vector2(trail[i - 1]) - origin,
					Vector2(trail[i]) - origin,
					color,
					maxf(1, 5 - i * 0.3),
					true
				)
			continue
		if fx.has("end"):
			var start: Vector2 = fx.point
			var end: Vector2 = fx.end
			if bool(fx.get("ray", false)):
				draw_line(start - origin, end - origin, color, 4.0 * (1.0 - progress) + 1.0, true)
			else:
				var direction := start.direction_to(end)
				var head := (
					start.lerp(end, progress) + direction.orthogonal() * sin(progress * PI) * 18.0
				)
				var tail := (
					start.lerp(end, maxf(0, progress - 0.18))
					+ direction.orthogonal() * sin(maxf(0, progress - 0.18) * PI) * 18.0
				)
				draw_line(tail - origin, head - origin, color, 3, true)
				draw_circle(head - origin, 3, color)
			continue
		if bool(fx.get("contract", false)):
			_ring(Vector2(fx.point) - origin, float(fx.radius) * (1.0 - progress), color, 2)
			continue
		_ring(Vector2(fx.point) - origin, float(fx.radius), Color(color, 0.2 * (1.0 - progress)))
		_ring(
			Vector2(fx.point) - origin,
			float(fx.radius) * (0.2 + 0.8 * progress),
			color,
			3.0 * (1.0 - progress) + 1.0
		)
		if bool(fx.get("plume", false)):
			var p: Vector2 = Vector2(fx.point) - origin
			draw_line(
				p,
				p - Vector2(0, float(fx.radius) * sin(progress * PI)),
				color,
				4.0 * (1 - progress) + 1,
				true
			)
		if not _reduced:
			for i in 6:
				var p := (
					Vector2(fx.point)
					- origin
					+ Vector2.from_angle(i * TAU / 6 + progress) * float(fx.radius) * progress
				)
				draw_line(p, p + Vector2.from_angle(i * TAU / 6) * 6, color, 2.0)
	for shot in missiles:
		var p: Vector2 = Vector2(shot.position) - origin
		var heading: Vector2 = shot.get("heading", Vector2.RIGHT)
		var kind := String(shot.kind)
		var color := (
			Color("#a8f3ff")
			if kind == "orb"
			else (
				Color("#fff1a2")
				if kind == "skyblinder"
				else Color("#ae86ed") if kind == "tome" else Color("#7de794")
			)
		)
		if float(shot.get("windup", 0)) > 0.0:
			_ring(p, 14.0 + float(shot.windup) * 40.0, Color(color, 0.7))
			continue
		var trail: Array = shot.get("trail", [])
		for i in range(1, trail.size(), 2 if _reduced else 1):
			var a: Vector2 = trail[i - 1] - origin
			var b: Vector2 = trail[i] - origin
			if kind == "snake":
				b += heading.orthogonal() * sin(i * 0.7 - visual_clock * 12.0) * 5.0
			draw_line(
				a,
				b,
				(
					Color.from_hsv(
						fmod(i * 0.09 + visual_clock * 0.2, 1.0), 0.4, 1.0, 1.0 - float(i) / 12.0
					)
					if kind == "orb"
					else Color(color, 1.0 - float(i) / 12.0)
				),
				maxf(1, 6.0 - i * 0.4),
				true
			)
		draw_colored_polygon(
			PackedVector2Array(
				[
					p + heading * 12,
					p - heading * 8 + heading.orthogonal() * 5,
					p - heading * 5 - heading.orthogonal() * 5
				]
			),
			color
		)
		if kind == "snake":
			draw_circle(p + heading.orthogonal() * 3, 1.5, Color("#123b24"))
			draw_line(p + heading * 10, p + heading * 15 + heading.orthogonal() * 4, color, 1.0)
			if float(shot.get("bite_pause", 0)) > 0:
				for side in [-1, 1]:
					draw_line(
						p + heading * 8 + heading.orthogonal() * side * 5,
						p + heading * 17 + heading.orthogonal() * side * 8,
						Color("#c4ff98"),
						2,
						true
					)
		elif kind == "tome":
			_ring(p, 9.0, color)
			draw_line(p - Vector2(0, 5), p + Vector2(0, 5), Color.WHITE)
	for plant in plants:
		var p: Vector2 = Vector2(plant.point) - origin
		var stage := clampf(float(plant.age) / value("growth_time"), 0.0, 1.0)
		var fade := minf(1.0, float(plant.left))
		_ring(p, 18, Color(0.35, 0.7, 0.3, fade * 0.5))
		draw_line(p, p - Vector2(0, 22 * stage), Color("#83633e"), 4, true)
		if stage < 0.3:
			draw_circle(p - Vector2(0, 8 * (1 - stage)), 3, Color("#d1e773"))
		if stage > 0.3:
			for side in [-1, 1]:
				draw_line(
					p - Vector2(0, 10 * stage),
					p + Vector2(side * 14 * stage, -19 * stage),
					Color("#826d3d"),
					3,
					true
				)
				draw_circle(
					p + Vector2(side * 12 * stage, -22 * stage),
					6 * stage,
					Color(0.4, 0.7, 0.3, fade)
				)
		if stage >= 1.0:
			_ring(p - Vector2(0, 18), 4 + sin(visual_clock * 3), Color("#d4fca1"))
	for tree in treants:
		var p: Vector2 = Vector2(tree.point) - origin
		var fade := minf(1.0, float(tree.left))
		var windup := float(tree.windup)
		if windup > 0.0:
			_ring(p, value("stomp_radius"), Color(0.7, 0.85, 0.45, 0.6))
			_ring(
				p, value("stomp_radius") * (1.0 - windup / value("stomp_windup")), Color("#b7d979")
			)
		var lift := sin(visual_clock * 8.0) * 3 if windup <= 0.0 else -8.0
		draw_line(p + Vector2(-8, -5), p + Vector2(-16, 12 + lift), Color("#967449"), 6)
		draw_line(p + Vector2(8, -5), p + Vector2(16, 12 - lift), Color("#967449"), 6)
		draw_rect(Rect2(p + Vector2(-12, -28), Vector2(24, 30)), Color(0.42, 0.3, 0.17, fade))
		draw_line(p + Vector2(-10, -18), p + Vector2(-26, -12 + lift), Color("#967449"), 5)
		draw_line(p + Vector2(10, -18), p + Vector2(26, -12 + lift), Color("#967449"), 5)
		for side in [-1, 1]:
			draw_circle(p + Vector2(side * 5, -21), 2, Color("#c7ed81"))
	for raw in marked.values():
		if _body(raw) == null or raw.dead:
			continue
		var p: Vector2 = raw.global_position - origin - Vector2(0, 32)
		draw_arc(p, 7, 0.4, TAU, 16, Color("#7aed94"), 2, true)
		draw_circle(p + Vector2(6, 1), 2, Color("#c2ff7c"))
	for state in heat.values():
		var raw: Variant = state.target
		if not is_instance_valid(raw) or raw.dead:
			continue
		var p: Vector2 = raw.global_position - origin
		_ring(p, 19, Color(1.0, 0.45, 0.1, 0.6))
		if float(state.burn) > 0.0:
			for i in 3:
				draw_line(
					p + Vector2(-8 + i * 8, -10),
					p + Vector2(-8 + i * 8, -22 - sin(visual_clock * 10 + i) * 4),
					Color("#ffd07b"),
					2
				)
	for corpse in remains:
		if corpse.has("harvesting"):
			continue
		var p: Vector2 = Vector2(corpse.point) - origin
		draw_circle(p, 8, Color("#37291f"))
		_ring(p, 10, Color("#e89048"))
	for segment in web_segments:
		var a: Vector2 = Vector2(segment.a) - origin
		var b: Vector2 = Vector2(segment.b) - origin
		var normal: Vector2 = a.direction_to(b).orthogonal() * value("width")
		var fade := minf(1.0, float(segment.left) / 1.5)
		draw_line(a + normal, b + normal, Color(0.84, 0.83, 1, 0.65 * fade), 1, true)
		draw_line(a - normal, b - normal, Color(0.84, 0.83, 1, 0.65 * fade), 1, true)
		draw_line(a + normal, b - normal, Color(0.84, 0.83, 1, 0.35 * fade), 1, true)
		if not _reduced:
			draw_line(a - normal, b + normal, Color(0.84, 0.83, 1, 0.35 * fade), 1, true)
	if item_id == "arachne_staff" and (web_active or not web_segments.is_empty()):
		var p := anchor - origin
		_ring(p, 12, Color("#c4a6ee"))
		for i in 8:
			draw_line(
				p + Vector2.from_angle(i * TAU / 8) * 4,
				p + Vector2.from_angle(i * TAU / 8) * 16,
				Color("#c4a6ee"),
				1,
				true
			)
		if web_active and not web_points.is_empty():
			draw_line(web_points.back() - origin, Vector2.ZERO, Color("#ede1ff"), 1, true)
		if not caught.is_empty():
			_ring(Vector2.ZERO, 24 + sin(visual_clock * 6) * 2, Color(0.75, 0.6, 1, 0.6))
	for raw in caught.values():
		if is_instance_valid(raw) and not raw.dead:
			_ring(raw.global_position - origin, 21, Color("#e2d4ff"))
	for point in preview:
		_ring(point - origin, value("radius"), Color(0.55, 0.72, 1, 0.65))
	if preview.size() > 1:
		var normal := aim_direction.orthogonal() * value("line_width")
		for side in [-1, 1]:
			draw_line(
				preview.front() - origin + normal * side,
				preview.back() - origin + normal * side,
				Color("#c6e1ff"),
				1,
				true
			)
	for burst in delayed_bursts:
		var p: Vector2 = Vector2(burst.point) - origin
		var ratio := clampf(float(burst.time) / float(burst.delay), 0, 1)
		_ring(p, burst.radius, Color("#719be0"))
		_ring(p, float(burst.radius) * ratio, Color("#ffe8a4"), 3)
		draw_line(p - Vector2(5, 0), p + Vector2(5, 0), Color("#f6e2a1"), 2)
	if item_id == "michaels_orb":
		var p := _orb_position()
		var prism := PackedVector2Array()
		for i in 6:
			prism.append(
				p + Vector2.from_angle(TAU * i / 6 + visual_clock) * (10 - orb_recoil * 12)
			)
		draw_colored_polygon(
			prism, Color(0.65, 0.65, 1, 0.35 + float(orb_energy) / value("charges") * 0.4)
		)
		for i in 6:
			draw_line(p, prism[i], Color.from_hsv(float(i) / 6, 0.4, 1.0), 1, true)
			draw_line(prism[i], prism[(i + 1) % 6], Color("#d0f6ff"), 1.5, true)
		for i in int(value("charges")):
			draw_circle(
				p + Vector2((i - 1) * 8, -17),
				2.5,
				Color("#fff1aa") if i < orb_energy else Color("#4d5268")
			)
		if orb_energy >= int(value("charges")):
			for i in 4:
				draw_line(
					p,
					p + Vector2.from_angle(i * TAU / 4 + visual_clock) * 15,
					Color("#ffffff"),
					2,
					true
				)
	if item_id == "skyblinder_staff" and phase == "charging":
		var ratio := charge_time / value("charge_time")
		var p := actor.aim_direction * 28
		draw_circle(p, 4 + ratio * 8, Color("#fff8c4"))
		for i in 3:
			draw_arc(
				p,
				15 + i * 7 * (1 - ratio),
				visual_clock + i,
				visual_clock + i + TAU * ratio,
				24,
				Color("#ffe795"),
				2,
				true
			)
		if not _reduced:
			for i in 8:
				var angle := TAU * i / 8 + visual_clock
				var distance := 18 + fmod(visual_clock * 24 + i * 6, 32.0) * (1 - ratio * 0.7)
				draw_line(
					p + Vector2.from_angle(angle) * distance,
					p + Vector2.from_angle(angle) * (distance + 5),
					Color("#fff3a8"),
					1,
					true
				)
	if item_id == "dragonstaff_of_ahghairon" and phase == "channel" and phase_time <= 0.0:
		var fan := PackedVector2Array()
		for p in flame_boundary:
			fan.append(p - origin)
		if fan.size() > 2:
			draw_colored_polygon(fan, Color(1, 0.38, 0.08, 0.16))
			draw_polyline(fan, Color(1, 0.65, 0.22, 0.35), 1, true)
			for i in range(1, fan.size(), 3 if _reduced else 1):
				for j in 2 if _reduced else 5:
					var travel := fmod(visual_clock * 1.6 + j * 0.19 + i * 0.08, 0.9) + 0.05
					var radius := minf(4 + travel * 10, fan[i].length() * (1 - travel) * 0.4)
					if radius > 0:
						draw_circle(
							fan[i] * travel,
							radius,
							Color(1, 0.25 + travel * 0.3, 0.05, (1 - travel) * 0.6)
						)
			draw_line(actor.aim_direction * 8, actor.aim_direction * 38, Color("#ffe9a2"), 5, true)
	if item_id == "tome_of_toth" and active_time > 0:
		var p := Vector2(-24, -24)
		draw_colored_polygon(
			PackedVector2Array(
				[
					p + Vector2(-13, -8),
					p + Vector2(0, -5),
					p + Vector2(13, -8),
					p + Vector2(13, 9),
					p + Vector2(0, 12),
					p + Vector2(-13, 9)
				]
			),
			Color("#80b6ac")
		)
		for i in mini(tome_stacks, detail):
			draw_line(
				p + Vector2(-10, -4 + i * 2), p + Vector2(-2, -2 + i * 2), Color("#dbb3ff"), 1
			)
		draw_line(p + Vector2(0, -5), p + Vector2(0, 12), Color("#e0ffe9"), 1)
	if item_id == "solar_scepter":
		if active_time > 0:
			_ring(Vector2.ZERO, value("radius"), Color(1, 0.8, 0.3, 0.6))
			for i in detail:
				var p := Vector2.from_angle(TAU * i / detail + visual_clock * 0.2) * value("radius")
				draw_line(p * 0.94, p, Color("#efc365"), 2)
		if flare_pending > 0:
			_ring(Vector2.ZERO, value("flare_radius"), Color(1, 0.8, 0.6, 0.3), 1)
			_ring(
				Vector2.ZERO,
				value("flare_radius") * flare_pending / value("flare_windup"),
				Color("#ffcdb0"),
				3
			)
		_ring(Vector2(0, -38), 9, Color("#fff2b3") if flare_cooldown <= 0 else Color("#8a7148"))
		for raw in _enemies_cache:
			if is_instance_valid(raw) and not raw.dead and exposure.has(_combat_id(raw)):
				var p: Vector2 = raw.global_position - origin - Vector2(0, 34)
				var strength := float(exposure[_combat_id(raw)]) / value("exposure_cap")
				draw_circle(p, 3 + strength * 4, Color(1, 0.5 + 0.35 * strength, 0.2, 0.8))
	if item_id == "drumamus_bargain" and phase == "channel":
		var p := anchor - origin
		var radius := gravity_radius()
		_ring(p, radius, Color("#bc8bec"), 2)
		_ring(p, value("inner_orbit"), Color(0.6, 0.4, 0.9, 0.45))
		for i in detail:
			var curve := PackedVector2Array()
			for j in 12:
				curve.append(
					(
						p
						+ (
							Vector2.from_angle(TAU * i / detail + visual_clock * 2 + j * 0.13)
							* lerpf(value("inner_orbit"), radius, float(j) / 11)
						)
					)
				)
			draw_polyline(curve, Color(0.6, 0.4, 0.9, 0.35), 1.5, true)
		draw_circle(p - Vector2(0, 24), 8, Color("#291c45"))


static var _backdrop: StyleBoxFlat


func _status_backdrop() -> StyleBoxFlat:
	if _backdrop == null:
		_backdrop = StyleBoxFlat.new()
		_backdrop.bg_color = Color(0.03, 0.04, 0.07, 0.85)
		_backdrop.set_corner_radius_all(3)
	return _backdrop
