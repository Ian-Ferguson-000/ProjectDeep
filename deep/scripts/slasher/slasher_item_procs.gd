extends Node2D
class_name SlasherItemProcs

## Runs the "procs" listed in an item's combat block (data/pickup_items.json):
## flying crescents from sword swings, chain lightning, burning, chilling and
## bursts on kill. Every number comes from the item data so new items can be
## made by editing the JSON only. See docs/ItemEffects.md.
##
## Attacks made by a proc carry "item_proc": true so they never trigger further
## procs (no lightning that chains forever).

const WAVE := preload("res://scripts/slasher/slasher_item_wave.gd")
const ELEMENT_COLORS := {"fire":Color("#ff8a3d"),"lightning":Color("#9fe7ff"),"ice":Color("#a9dcff"),"physical":Color("#e9f6ff"),"wind":Color("#e9f6ff"),"poison":Color("#9ee05a"),"arcane":Color("#c79bff")}
const BURN_TICK := 0.5

var player: SlasherPlayer
var swing_counts: Dictionary = {}
var proc_cooldowns: Dictionary = {}
var burns: Dictionary = {}
var chills: Dictionary = {}
var bolts: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var _time := 0.0

func setup(actor: SlasherPlayer) -> void:
	player = actor
	top_level = true
	z_index = 40
	name = "SlasherItemProcs"

## All procs from the adventurer's current items, each tagged with its item.
func active_procs() -> Array[Dictionary]:
	var procs: Array[Dictionary] = []
	if player == null or player.item_runtime == null: return procs
	for record: Dictionary in player.item_runtime.records:
		var index := 0
		for value in Array(record.get("procs",[])):
			if value is Dictionary:
				var proc: Dictionary = Dictionary(value).duplicate(true)
				proc["_key"] = "%s:%d" % [String(record.get("item_id","")),index]
				proc["_item"] = String(record.get("item_id",""))
				procs.append(proc)
			index += 1
	return procs

func on_action(slot: String, base_damage: int) -> void:
	for proc in active_procs():
		var on := String(proc.get("on","hit"))
		if on == "swing" and slot != "basic": continue
		if on == "special" and slot != "special": continue
		if on == "dash" and slot != "movement": continue
		if not on in ["swing","special","dash"]: continue
		if not _ready_to_fire(proc): continue
		_fire(proc,base_damage,null,player.global_position)

func on_hit(target: Node2D, attack: Dictionary) -> void:
	if bool(attack.get("item_proc",false)): return
	for proc in active_procs():
		if String(proc.get("on","hit")) != "hit": continue
		if not _ready_to_fire(proc): continue
		_fire(proc,int(attack.get("damage",1)),target,target.global_position)

func on_kill(target: Node2D, attack: Dictionary) -> void:
	if bool(attack.get("item_proc",false)) and not bool(attack.get("allow_kill_procs",false)): return
	for proc in active_procs():
		if String(proc.get("on","hit")) != "kill": continue
		if not _ready_to_fire(proc): continue
		_fire(proc,int(attack.get("damage",1)),null,target.global_position)

func _ready_to_fire(proc: Dictionary) -> bool:
	var key := String(proc._key)
	if float(proc_cooldowns.get(key,0.0)) > 0.0: return false
	var every := int(proc.get("every",1))
	if every > 1:
		swing_counts[key] = int(swing_counts.get(key,0)) + 1
		if int(swing_counts[key]) < every: return false
		swing_counts[key] = 0
	if randf() > float(proc.get("chance",1.0)): return false
	if float(proc.get("cooldown",0.0)) > 0.0: proc_cooldowns[key] = float(proc.cooldown)
	return true

static func proc_damage(proc: Dictionary, base_damage: int) -> int:
	return maxi(1,int(round(float(base_damage) * float(proc.get("damage_percent",0.0)) / 100.0 + float(proc.get("damage",0.0)))))

func _fire(proc: Dictionary, base_damage: int, target: Node2D, origin: Vector2) -> void:
	match String(proc.get("type","")):
		"wave": _fire_waves(proc,base_damage)
		"chain_lightning": _chain_lightning(proc,base_damage,target,origin)
		"burn":
			if is_instance_valid(target): apply_burn(target,proc,base_damage)
		"chill":
			if is_instance_valid(target): apply_chill(target,proc)
		"nova": _nova(proc,base_damage,origin)
		"heal": player.heal(int(proc.get("amount",1)))
		_: return
	if String(proc.get("message","")) != "" and player.item_runtime:
		player.item_runtime.effect_activated.emit(String(proc.message))

# --- Crescent waves -----------------------------------------------------------

func _fire_waves(proc: Dictionary, base_damage: int) -> void:
	var count := maxi(1,int(proc.get("count",1)))
	var spread := deg_to_rad(float(proc.get("spread_degrees",18.0)))
	var element := String(proc.get("element","physical"))
	for index in count:
		var angle := 0.0 if count == 1 else lerpf(-spread,spread,float(index) / float(count - 1))
		var direction := player.aim_direction.rotated(angle)
		var attack := proc_attack(proc_damage(proc,base_damage),element)
		attack["knockback"] = float(proc.get("knockback",40.0))
		var wave: Node2D = WAVE.new()
		wave.setup(player,self,player.global_position + direction * 26.0,direction,attack,proc)
		player.get_parent().add_child(wave)
	AudioCue.play_from(player,AudioCue.cast_event(element) if element in ["fire","ice","lightning"] else "sword_swing")

## Called by a wave each time it passes through an enemy.
func wave_hit(target: Node2D, attack: Dictionary, proc: Dictionary) -> void:
	if not is_instance_valid(target) or not target.has_method("receive_attack"): return
	var was_dead := _is_dead(target)
	target.call("receive_attack",attack,player)
	if Dictionary(proc.get("burn",{})).size() > 0: apply_burn(target,Dictionary(proc.burn),int(attack.damage))
	if Dictionary(proc.get("chill",{})).size() > 0: apply_chill(target,Dictionary(proc.chill))
	if not was_dead and _is_dead(target): on_kill(target,attack)

# --- Chain lightning ------------------------------------------------------------

func _chain_lightning(proc: Dictionary, base_damage: int, first: Node2D, origin: Vector2) -> void:
	var damage := proc_damage(proc,base_damage)
	var jumps := maxi(1,int(proc.get("jumps",3)))
	var jump_range := float(proc.get("jump_range",170.0))
	var struck := {}
	var from := origin
	var points: Array[Vector2] = [player.global_position if first == null else origin]
	if is_instance_valid(first): struck[first.get_instance_id()] = true
	for jump in jumps:
		var next := _nearest_enemy(from,jump_range,struck)
		if next == null: break
		struck[next.get_instance_id()] = true
		points.append(next.global_position)
		var was_dead := _is_dead(next)
		next.call("receive_attack",proc_attack(damage,"lightning"),player)
		if not was_dead and _is_dead(next): on_kill(next,{"damage":damage,"item_proc":true})
		from = next.global_position
	if points.size() > 1:
		bolts.append({"points":points,"time":0.22,"seed":randi()})
		AudioCue.play_from(player,"impact_lightning")
		queue_redraw()

func _nearest_enemy(from: Vector2, max_range: float, skip: Dictionary) -> Node2D:
	var best: Node2D = null
	var best_distance := max_range
	for value in get_tree().get_nodes_in_group("slasher_enemy"):
		var enemy := value as Node2D
		if not is_instance_valid(enemy) or skip.has(enemy.get_instance_id()) or _is_dead(enemy) or not enemy.has_method("receive_attack"): continue
		if player.get_parent() != enemy.get_parent() and not player.get_parent().is_ancestor_of(enemy): continue
		var distance := from.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best

# --- Burning and chilling ---------------------------------------------------------

func apply_burn(target: Node2D, proc: Dictionary, base_damage: int) -> void:
	var tick_damage := maxi(1,int(round(float(proc.get("damage",1.0)) + float(base_damage) * float(proc.get("damage_percent",0.0)) / 100.0)))
	var entry: Dictionary = burns.get(target.get_instance_id(),{"target":target,"tick":BURN_TICK})
	entry.target = target
	entry.damage = maxi(int(entry.get("damage",0)),tick_damage)
	entry.time = maxf(float(entry.get("time",0.0)),float(proc.get("duration",3.0)))
	burns[target.get_instance_id()] = entry

func apply_chill(target: Node2D, proc: Dictionary) -> void:
	if "movement_slow" in target and "status_time" in target:
		target.set("movement_slow",clampf(float(proc.get("slow",0.5)),0.1,1.0))
		target.set("status_time",maxf(float(target.get("status_time")),float(proc.get("duration",1.5))))
	chills[target.get_instance_id()] = {"target":target,"time":float(proc.get("duration",1.5))}

# --- Novas --------------------------------------------------------------------

func _nova(proc: Dictionary, base_damage: int, origin: Vector2) -> void:
	var radius := float(proc.get("radius",80.0))
	var element := String(proc.get("element","fire"))
	var attack := proc_attack(proc_damage(proc,base_damage),element)
	attack["knockback"] = float(proc.get("knockback",60.0))
	for value in get_tree().get_nodes_in_group("slasher_enemy"):
		var enemy := value as Node2D
		if is_instance_valid(enemy) and not _is_dead(enemy) and enemy.has_method("receive_attack") and origin.distance_to(enemy.global_position) <= radius:
			enemy.call("receive_attack",attack,player)
	rings.append({"position":origin,"radius":radius,"time":0.32,"color":ELEMENT_COLORS.get(element,Color.WHITE)})
	AudioCue.play_from(player,"impact_" + element if element in ["fire","ice","lightning"] else "impact")
	queue_redraw()

# --- Shared ---------------------------------------------------------------------

func proc_attack(damage: int, element: String) -> Dictionary:
	return {"damage":damage,"damage_type":"physical" if element == "wind" else element,"damage_source":"item","item_proc":true,"knockback":0.0,"hit_stun_duration":0.06,"screen_shake_multiplier":0.35}

static func _is_dead(node: Node) -> bool:
	return not is_instance_valid(node) or ("dead" in node and bool(node.get("dead")))

func _process(delta: float) -> void:
	_time += delta
	global_position = Vector2.ZERO
	for key in proc_cooldowns.keys(): proc_cooldowns[key] = maxf(0.0,float(proc_cooldowns[key]) - delta)
	for id in burns.keys():
		var entry: Dictionary = burns[id]
		var target: Node2D = entry.target
		if _is_dead(target):
			burns.erase(id)
			continue
		entry.time = float(entry.time) - delta
		entry.tick = float(entry.tick) - delta
		if float(entry.tick) <= 0.0:
			entry.tick = BURN_TICK
			var attack := proc_attack(int(entry.damage),"fire")
			attack["hit_stun_duration"] = 0.0
			attack["screen_shake_multiplier"] = 0.0
			attack["allow_kill_procs"] = true
			target.call("receive_attack",attack,player)
			if _is_dead(target): on_kill(target,attack)
		if float(entry.time) <= 0.0: burns.erase(id)
	for id in chills.keys():
		chills[id].time = float(chills[id].time) - delta
		if float(chills[id].time) <= 0.0 or _is_dead(chills[id].target): chills.erase(id)
	for bolt in bolts: bolt.time = float(bolt.time) - delta
	bolts = bolts.filter(func(bolt): return float(bolt.time) > 0.0)
	for ring in rings: ring.time = float(ring.time) - delta
	rings = rings.filter(func(ring): return float(ring.time) > 0.0)
	if not burns.is_empty() or not chills.is_empty() or not bolts.is_empty() or not rings.is_empty(): queue_redraw()
	elif get_meta("drew_last",false): queue_redraw()

func _draw() -> void:
	set_meta("drew_last",not burns.is_empty() or not chills.is_empty() or not bolts.is_empty() or not rings.is_empty())
	for entry in burns.values():
		if _is_dead(entry.target): continue
		var base: Vector2 = entry.target.global_position
		for index in 3:
			var phase := _time * 9.0 + index * 2.1
			var offset := Vector2(sin(phase) * 7.0 + (index - 1) * 6.0,-8.0 - absf(sin(phase * 0.7)) * 10.0)
			draw_circle(base + offset,4.0 - index * 0.6,Color(1.0,0.55,0.15,0.75))
			draw_circle(base + offset + Vector2(0,-2),2.0,Color(1.0,0.9,0.5,0.9))
	for entry in chills.values():
		if _is_dead(entry.target): continue
		draw_arc(entry.target.global_position + Vector2(0,6),16.0,0.0,TAU,24,Color(0.65,0.88,1.0,0.7),2.0)
	for bolt in bolts:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(bolt.seed) + int(_time * 30.0)
		var points: Array = bolt.points
		var alpha := clampf(float(bolt.time) / 0.22,0.0,1.0)
		for index in points.size() - 1:
			var line := PackedVector2Array()
			var a: Vector2 = points[index]
			var b: Vector2 = points[index + 1]
			var normal := (b - a).orthogonal().normalized()
			line.append(a)
			for step in range(1,6): line.append(a.lerp(b,step / 6.0) + normal * rng.randf_range(-10.0,10.0))
			line.append(b)
			draw_polyline(line,Color(0.3,0.75,1.0,0.45 * alpha),12.0,true)
			draw_polyline(line,Color(0.06,0.14,0.42,0.85 * alpha),5.5,true)
			draw_polyline(line,Color(0.95,1.0,1.0,alpha),2.5,true)
	for ring in rings:
		var progress := 1.0 - float(ring.time) / 0.32
		var color: Color = ring.color
		color.a = 0.8 * (1.0 - progress)
		var radius := float(ring.radius) * (0.35 + 0.65 * progress)
		var width := 6.0 * (1.0 - progress) + 2.0
		color.a = 0.9 * (1.0 - progress)
		draw_circle(ring.position,radius,Color(color.r,color.g,color.b,0.18 * (1.0 - progress)))
		draw_arc(ring.position,radius,0.0,TAU,40,Color(0.05,0.05,0.08,0.55 * (1.0 - progress)),width + 3.0)
		draw_arc(ring.position,radius,0.0,TAU,40,color,width)
