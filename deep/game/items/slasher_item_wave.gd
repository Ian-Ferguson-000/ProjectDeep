extends Node2D

## A crescent of wind, fire, frost or lightning thrown forward by an item proc
## (for example a sword swing). It passes through enemies, striking each once,
## and stops at walls. Drawn in code so any element colour works.

var player: SlasherPlayer
var procs: Node
var direction := Vector2.RIGHT
var attack: Dictionary = {}
var proc: Dictionary = {}
var speed := 520.0
var max_range := 260.0
var width := 34.0
var traveled := 0.0
var hit_ids: Dictionary = {}
var color := Color.WHITE
var core := Color.WHITE
var _fade := 0.0

func setup(actor: SlasherPlayer, owner_procs: Node, origin: Vector2, aim: Vector2, attack_data: Dictionary, proc_data: Dictionary) -> void:
	player = actor
	procs = owner_procs
	global_position = origin
	direction = aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT
	rotation = direction.angle()
	attack = attack_data
	proc = proc_data
	speed = float(proc.get("speed",520.0))
	max_range = float(proc.get("range",260.0))
	width = float(proc.get("width",34.0))
	var element := String(proc.get("element","physical"))
	color = Color(String(proc.get("color",""))) if String(proc.get("color","")) != "" else Color(SlasherItemProcs.ELEMENT_COLORS.get(element,Color.WHITE))
	core = color.lerp(Color.WHITE,0.65)
	z_index = 30
	name = "ItemWave"
	add_to_group("slasher_item_wave")

func _physics_process(delta: float) -> void:
	if _fade > 0.0:
		_fade -= delta
		modulate.a = clampf(_fade / 0.12,0.0,1.0)
		if _fade <= 0.0: queue_free()
		return
	if not is_instance_valid(player) or not is_instance_valid(procs):
		queue_free()
		return
	var movement := direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(global_position,global_position + movement,1)
	query.exclude.append(player.get_rid())
	var collision := get_world_2d().direct_space_state.intersect_ray(query)
	if not collision.is_empty():
		var collider := collision.get("collider") as Node2D
		if collider is StaticBody2D and not (is_instance_valid(collider) and collider.is_in_group("slasher_damageable")):
			_fade = 0.12
			return
	global_position += movement
	traveled += movement.length()
	for value in get_tree().get_nodes_in_group("slasher_enemy"):
		var enemy := value as Node2D
		if not is_instance_valid(enemy) or hit_ids.has(enemy.get_instance_id()): continue
		var offset := enemy.global_position - global_position
		# The crescent is wide across its path and thin along it.
		if absf(offset.dot(direction)) <= 22.0 and absf(offset.dot(direction.orthogonal())) <= width:
			hit_ids[enemy.get_instance_id()] = true
			procs.wave_hit(enemy,attack,proc)
	if traveled >= max_range: _fade = 0.12
	queue_redraw()

func _draw() -> void:
	var life := 1.0 - clampf(traveled / max_range,0.0,1.0) * 0.55
	var glow := color
	glow.a = 0.35 * life
	var edge := core
	edge.a = 0.95 * life
	draw_arc(Vector2(-width * 0.55,0),width,-1.15,1.15,24,glow,14.0)
	draw_arc(Vector2(-width * 0.55,0),width,-1.05,1.05,24,color,6.0)
	draw_arc(Vector2(-width * 0.55,0),width,-0.9,0.9,20,edge,2.5)
	for index in 3:
		var trail := color
		trail.a = 0.18 * life * (3 - index)
		draw_arc(Vector2(-width * 0.55 - 10.0 * (index + 1),0),width * (0.92 - index * 0.08),-0.8,0.8,16,trail,3.0)
