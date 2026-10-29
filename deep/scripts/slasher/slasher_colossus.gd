extends SlasherEnemy
class_name SlasherColossus

## The Heartwood Colossus: a corrupted ancient tree rooted in the middle of its
## arena, fought old-school bullet-hell style. It never moves; it cycles through
## attack patterns, each with a clear warning, and after every pattern a weak
## point opens for a few seconds. The body itself can't be hurt.
##
##   Spore Bloom   canopy swells, then rings of spores spread outward  -> heart opens
##   Root Slam     red circle marks where a fist will land             -> that fist lies open
##   Thorn Spiral  eyes flare red, then rotating arms of thorns        -> heart opens
##
## It speeds up at 66% and 33% health (with a roar and a short pause), adds the
## thorn spiral and double slams, and calls sporelings in the last phase.
## Numbers: data/slasher_balance.json enemies.heartwood_colossus.
## Art: set body_texture / heart_texture / fist_texture to replace the
## placeholder drawing (see docs/HeartwoodColossus.md).
##
## Other dungeons' colossi extend this (the crypt's Big Skelly Boi, in
## slasher_charnel_king.gd): they set colossus_id and override the patterns and
## drawing, and share the body, weak points, phases, telegraphs and boss bar
## (SlasherBossBar, top centre of the screen).

signal phase_changed(phase: int)

const WEAK_POINT := preload("res://scripts/slasher/slasher_colossus_weak_point.gd")
const CELL := 48.0
## Cells the body blocks: must match ForestRoomLibrary.COLOSSUS_SIZE.
const BODY_CELLS := Vector2i(7,5)
const PROJECTILE_CAP := 170

@export var body_texture: Texture2D
@export var heart_texture: Texture2D
@export var fist_texture: Texture2D

## Which colossus: its tuning (slasher_balance.json enemies.<id>) and journal name.
var colossus_id := "heartwood_colossus"
## The room's walkable area in world space, set by the room scene. Patterns that
## sweep the whole arena use it.
var arena := Rect2()
var half := Vector2(BODY_CELLS) * CELL * 0.5
var phase := 1
var state := "intro"
var pattern := ""
var timer := 2.2
var pattern_step := 0
var spiral_angle := 0.0
var fire_timer := 0.0
var slams_left := 0
var cycle_count := 0
var heart: SlasherColossusWeakPoint
var fists: Array[SlasherColossusWeakPoint] = []
var telegraphs: Array[Dictionary] = []
var telegraph_layer: Node2D
var boss_bar: CanvasLayer
var _shake_glow := 0.0

func configure(floor_number:int,is_boss:bool=true,enemy_visual_id:String="heartwood_colossus",is_mini_boss:bool=false,enemy_behavior_id:String="heartwood_colossus")->void:
	super.configure(floor_number,true,colossus_id,false,colossus_id)
	behavior_id = colossus_id; visual_id = colossus_id
	tuning = GameBalance.get_slasher_enemy_tuning("forest_boss")
	behavior_tuning = GameBalance.get_slasher_enemy_tuning(colossus_id)
	max_health = int(behavior_tuning.get("health_base",380)) + floor_number * int(behavior_tuning.get("health_per_floor",30))
	health = max_health
	damage = int(behavior_tuning.get("damage_base",3)) + int(floor_number * float(behavior_tuning.get("damage_per_floor",0.6)))
	reward = int(behavior_tuning.get("reward",40))
	speed = 0.0
	activation_delay = 0.0

func _ready() -> void:
	super._ready()
	# Only the weak points can be hit; the trunk is scenery you fight around.
	remove_from_group("slasher_damageable"); remove_from_group("slasher_enemy")
	if sprite: sprite.visible = false
	z_index = 0
	_build_weak_points()
	telegraph_layer = TelegraphLayer.new(); telegraph_layer.colossus = self; telegraph_layer.name = "Telegraphs"
	telegraph_layer.top_level = true; telegraph_layer.z_index = -1
	add_child(telegraph_layer)
	boss_bar = SlasherBossBar.new().setup(self,String(GameBalance.get_slasher_journal_entry(colossus_id).get("name","The Guardian")),[_t("phase_two",0.66),_t("phase_three",0.33)])
	add_child(boss_bar)

## The weak point that opens after most patterns, just outside the body's south edge.
func _build_weak_points() -> void:
	heart = WEAK_POINT.new().setup(self,"heart",30.0,heart_texture)
	heart.position = Vector2(0,half.y + 26.0)
	add_child(heart)

func arena_rect() -> Rect2:
	return arena if arena.has_area() else Rect2(global_position - Vector2(640,380),Vector2(1280,760))

func _t(key: String, fallback: float) -> float:
	return float(behavior_tuning.get(key,fallback))

func _pace() -> float:
	return [1.0,1.0,_t("phase_two_speed",1.2),_t("phase_three_speed",1.4)][phase]

func _physics_process(delta: float) -> void:
	retarget_timer -= delta
	if retarget_timer <= 0.0:
		_retarget_party(); retarget_timer = 0.45
	if dead or not is_instance_valid(target): return
	_shake_glow = maxf(0.0,_shake_glow - delta)
	for telegraph in telegraphs: telegraph.t = float(telegraph.t) + delta
	timer -= delta * (_pace() if state != "window" else 1.0)
	match state:
		"intro","rest","roar":
			if timer <= 0.0: _start_next_pattern()
		"telegraph":
			if timer <= 0.0: _begin_attack()
		"attack":
			_run_attack(delta)
		"window":
			if timer <= 0.0: _end_window()
	queue_redraw()

# ---------------------------------------------------------------- patterns

func _start_next_pattern() -> void:
	cycle_count += 1
	var options: Array[String] = ["spore_bloom","root_slam"]
	if phase >= 2: options.append("thorn_spiral")
	# Never repeat the same pattern twice in a row, and always open with a slam
	# so the first window teaches where to hit.
	var pick := "root_slam" if cycle_count == 1 else options[(cycle_count * 7 + phase) % options.size()]
	if pick == pattern: pick = options[(options.find(pick) + 1) % options.size()]
	pattern = pick
	state = "telegraph"
	telegraphs.clear()
	match pattern:
		"spore_bloom":
			timer = _t("bloom_telegraph",1.1)
			telegraphs.append({"kind":"bloom","pos":global_position + Vector2(0,-half.y * 0.6),"t":0.0,"total":timer})
		"thorn_spiral":
			timer = _t("spiral_telegraph",0.9)
			telegraphs.append({"kind":"eyes","pos":global_position,"t":0.0,"total":timer})
		"root_slam":
			slams_left = 2 if phase >= 2 else 1
			_telegraph_slam()
	AudioCue.play_from(self,"enemy_attack")

func _telegraph_slam() -> void:
	state = "telegraph"
	timer = _t("slam_telegraph",1.15)
	var spot := target.global_position
	telegraphs = [{"kind":"slam","pos":spot,"radius":_t("slam_radius",74.0),"t":0.0,"total":timer}]

func _begin_attack() -> void:
	state = "attack"; pattern_step = 0; fire_timer = 0.0
	match pattern:
		"spore_bloom": timer = 0.0
		"thorn_spiral": timer = _t("spiral_duration",3.2)
		"root_slam": _slam(Vector2(telegraphs[0].pos)); return
	telegraphs.clear()

func _run_attack(delta: float) -> void:
	match pattern:
		"spore_bloom":
			fire_timer -= delta * _pace()
			if fire_timer > 0.0: return
			var waves := 4 if phase >= 3 else 3
			var count := int(_t("bloom_bullets",16))
			var offset := (PI / count) * (pattern_step % 2) + randf() * 0.2
			for index in count:
				var direction := Vector2.RIGHT.rotated(offset + TAU * index / count)
				_fire(direction,_t("bloom_speed",150.0) * (1.0 + 0.1 * (phase - 1)),"spore",Color("#e86ad8"))
			AudioCue.play_from(self,"cast_ice")
			pattern_step += 1; fire_timer = _t("bloom_wave_gap",0.55)
			if pattern_step >= waves: _open_window(heart,_t("heart_window",2.6))
		"thorn_spiral":
			timer -= delta
			fire_timer -= delta
			if fire_timer <= 0.0:
				fire_timer = _t("spiral_interval",0.12) / _pace()
				var arms := 4 if phase >= 3 else 3
				for arm in arms: _fire(Vector2.RIGHT.rotated(spiral_angle + TAU * arm / arms),_t("spiral_speed",165.0),"bolt",Color("#d8763a"))
				spiral_angle += _t("spiral_turn",0.23)
			if timer <= 0.0: _open_window(heart,_t("heart_window",2.2))

func _slam(spot: Vector2) -> void:
	telegraphs.clear()
	var radius := _t("slam_radius",74.0)
	if is_instance_valid(target) and target.global_position.distance_to(spot) <= radius:
		target.receive_damage(maxi(1,int(round(damage * _t("slam_damage_multiplier",1.3)))),(target.global_position - spot).normalized() * 260.0,self)
	if is_instance_valid(target): target.add_impact_shake(9.0,0.3)
	AudioCue.play_from(self,"impact")
	# A ring of splinters from the impact.
	var shards := int(_t("slam_shards",10))
	for index in shards: _fire(Vector2.RIGHT.rotated(TAU * index / shards + randf() * 0.2),_t("slam_shard_speed",175.0),"arrow",Color("#c9a36a"),spot)
	var fist: SlasherColossusWeakPoint = WEAK_POINT.new().setup(self,"fist",34.0,fist_texture)
	fist.top_level = true
	add_child(fist)
	fist.global_position = spot
	fists.append(fist)
	_open_window(fist,_t("fist_window",2.4))

func _open_window(part: SlasherColossusWeakPoint, seconds: float) -> void:
	state = "window"
	timer = seconds
	part.open_for(seconds)

func _end_window() -> void:
	heart.close()
	_free_fists()
	if pattern == "root_slam" and slams_left > 1:
		slams_left -= 1
		_telegraph_slam()
		return
	state = "rest"
	timer = _t("rest",0.9)
	if phase >= 3 and cycle_count % 2 == 0: reinforcement_requested.emit(Array(behavior_tuning.get("reinforcements",["sporeling","sporeling"])),global_position + Vector2(0,half.y + 90.0))

func _fire(direction: Vector2, projectile_speed: float, visual: String, colour: Color, from: Vector2 = Vector2.INF) -> void:
	if get_tree().get_nodes_in_group("colossus_projectile").size() >= PROJECTILE_CAP: return
	var origin := edge_point(direction) if from == Vector2.INF else from + direction * 20.0
	var config := {"projectile_speed":projectile_speed,"projectile_range":1100.0,"hit_radius":11.0,"color":colour.to_html(),"visual_type":visual}
	var bullet := HOSTILE_PROJECTILE.new().setup(self,target,origin,direction,maxi(1,int(round(damage * _t("bullet_damage_multiplier",0.5)))),config)
	get_parent().add_child(bullet)
	bullet.add_to_group("colossus_projectile")

## Where a shot leaves the body: just outside the blocked cells, so walls don't eat it.
func edge_point(direction: Vector2) -> Vector2:
	var d := direction.normalized()
	var reach := minf(half.x / maxf(absf(d.x),0.001),half.y / maxf(absf(d.y),0.001))
	return global_position + d * (reach + 20.0)

# ---------------------------------------------------------------- damage and phases

func receive_hit(amount:int,knockback:Vector2=Vector2.ZERO,attacker:SlasherPlayer=null,stun_duration:float=-1.0,shake_multiplier:float=1.0,sound_event:String="impact")->int:
	var dealt := super.receive_hit(amount,Vector2.ZERO,attacker,0.0,shake_multiplier,sound_event)
	hit_stun_timer = 0.0
	var fraction := float(health) / float(max_health)
	var next_phase := 3 if fraction <= _t("phase_three",0.33) else (2 if fraction <= _t("phase_two",0.66) else 1)
	if next_phase > phase and not dead:
		phase = next_phase
		phase_changed.emit(phase)
		# A roar: everything closes, bullets clear, a short breather.
		heart.close()
		_free_fists(); telegraphs.clear()
		_clear_bullets()
		state = "roar"; timer = _t("roar",1.4); _shake_glow = 1.4
		if is_instance_valid(target): target.add_impact_shake(12.0,0.6)
		AudioCue.play_from(self,"combo")
	if dead: _clear_bullets()
	return dealt

func _free_fists() -> void:
	for fist in fists:
		if is_instance_valid(fist): fist.queue_free()
	fists.clear()

func _clear_bullets() -> void:
	for bullet in get_tree().get_nodes_in_group("colossus_projectile"): bullet.queue_free()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if body_texture != null:
		draw_texture(body_texture,-body_texture.get_size() * 0.5)
		_draw_fist_arms()
		return
	var t := Time.get_ticks_msec() / 1000.0
	var sway := sin(t * 0.8) * 3.0
	var angry := state == "roar" or (state == "telegraph" and pattern == "thorn_spiral")
	# Roots spreading over the arena floor.
	var root := Color("#3d2817")
	for index in 9:
		var angle := PI * 0.08 + PI * 0.84 * index / 8.0
		var start := Vector2(cos(angle) * half.x * 0.7,half.y * 0.55)
		draw_polyline(PackedVector2Array([start,start + Vector2(cos(angle) * 60,40),start + Vector2(cos(angle) * 110,70 + sin(index) * 10)]),root,7.0,true)
	# Shadow and trunk.
	draw_set_transform(Vector2(0,half.y * 0.75),0.0,Vector2(1.0,0.35))
	draw_circle(Vector2.ZERO,half.x * 1.05,Color(0,0,0,0.3))
	draw_set_transform(Vector2.ZERO)
	var bark := Color("#5b3d26").lerp(Color("#7a2f1c"),_shake_glow * 0.4)
	var trunk := PackedVector2Array([Vector2(-half.x * 0.62,half.y * 0.8),Vector2(-half.x * 0.5,-half.y * 0.2),Vector2(-half.x * 0.38,-half.y * 0.9),Vector2(half.x * 0.38,-half.y * 0.9),Vector2(half.x * 0.5,-half.y * 0.2),Vector2(half.x * 0.62,half.y * 0.8)])
	draw_colored_polygon(trunk,bark.darkened(0.35))
	var inner := PackedVector2Array()
	for p in trunk: inner.append(p * 0.9 + Vector2(0,-4))
	draw_colored_polygon(inner,bark)
	for index in 6:
		var x := -half.x * 0.42 + index * half.x * 0.17
		draw_line(Vector2(x,-half.y * 0.8),Vector2(x + sin(index * 1.7) * 10,half.y * 0.7),bark.darkened(0.25),3.0)
	# Arms (branches) resting at the sides unless a fist is down.
	_draw_fist_arms()
	if fists.is_empty():
		for side in [-1,1]:
			var shoulder := Vector2(side * half.x * 0.5,-half.y * 0.3)
			draw_polyline(PackedVector2Array([shoulder,shoulder + Vector2(side * 70,-10 + sway),shoulder + Vector2(side * 120,40 + sway)]),bark.darkened(0.2),18.0,true)
			draw_circle(shoulder + Vector2(side * 120,40 + sway),24,bark.darkened(0.1))
	# Face.
	var eye_colour := Color("#ff3b2a") if angry else Color("#f6d55c")
	for side in [-1,1]:
		var eye := Vector2(side * 30,-half.y * 0.35)
		draw_circle(eye,16,Color("#140a05"))
		draw_circle(eye,8 + (3 if angry else 0) + sin(t * 3.0) * 1.0,eye_colour)
		draw_line(eye + Vector2(-side * 22,-24),eye + Vector2(side * 14,-14 - (6 if angry else 0)),Color("#2c1b10"),6.0)
	draw_arc(Vector2(0,half.y * 0.05),26,0.2,PI - 0.2,12,Color("#140a05"),6.0)
	# Canopy.
	var leaf := Color("#2f5a2a")
	var bloom := 0.0
	if state == "telegraph" and pattern == "spore_bloom": bloom = clampf(1.0 - timer / maxf(0.01,_t("bloom_telegraph",1.1)),0.0,1.0)
	for index in 11:
		var angle := TAU * index / 11.0
		var spot := Vector2(cos(angle) * half.x * 0.85,-half.y * 1.0 + sin(angle) * half.y * 0.45 + sway)
		draw_circle(spot,52 + bloom * 10,leaf.darkened(0.25))
		draw_circle(spot + Vector2(-6,-8),42 + bloom * 10,leaf.lerp(Color("#9ad16a"),bloom * 0.6))
	draw_circle(Vector2(0,-half.y * 1.05 + sway),70 + bloom * 12,leaf.lerp(Color("#b8e070"),bloom * 0.7))
	# Spore pods.
	for index in 5:
		var pod := Vector2(-half.x * 0.6 + index * half.x * 0.3,-half.y * 0.75 + sin(index * 2.0 + t) * 6)
		draw_circle(pod,9 + bloom * 6,Color("#d7e58a").lerp(Color("#ffffff"),bloom * 0.5))

func _draw_fist_arms() -> void:
	for fist in fists:
		if not is_instance_valid(fist): continue
		var local := to_local(fist.global_position)
		var shoulder := Vector2(signf(local.x if absf(local.x) > 1 else 1.0) * half.x * 0.5,-half.y * 0.3)
		draw_polyline(PackedVector2Array([shoulder,shoulder.lerp(local,0.5) + Vector2(0,-30),local]),Color("#4a3120"),22.0,true)

## Warning shapes on the ground, under everyone.
class TelegraphLayer extends Node2D:
	var colossus: SlasherColossus
	func _process(_delta: float) -> void:
		global_position = Vector2.ZERO
		queue_redraw()
	func _draw() -> void:
		if not is_instance_valid(colossus): return
		for telegraph in colossus.telegraphs:
			var progress := clampf(float(telegraph.t) / maxf(0.01,float(telegraph.total)),0.0,1.0)
			var at: Vector2 = telegraph.pos
			match String(telegraph.kind):
				"slam":
					var radius: float = telegraph.radius
					draw_circle(at,radius,Color(0.9,0.15,0.1,0.18))
					draw_circle(at,radius * progress,Color(0.95,0.2,0.1,0.35))
					draw_arc(at,radius,0,TAU,40,Color(1,0.3,0.2,0.95),3.0)
					draw_line(at + Vector2(-14,-14),at + Vector2(14,14),Color(1,0.3,0.2,0.9),4.0); draw_line(at + Vector2(14,-14),at + Vector2(-14,14),Color(1,0.3,0.2,0.9),4.0)
				"bloom":
					for ring in 3:
						var r := fmod(progress * 3.0 + ring / 3.0,1.0) * 260.0
						draw_arc(at,r,0,TAU,48,Color(0.75,0.9,0.4,0.6 * (1.0 - r / 260.0)),3.0)
				"eyes":
					draw_arc(at,colossus.half.x * (1.4 - progress * 0.3),0,TAU,48,Color(1,0.3,0.15,0.35 + progress * 0.5),4.0)
				"lane":
					# A band across the arena that a giant hand will sweep along.
					var lane: Rect2 = telegraph.rect
					var d := float(telegraph.get("dir",1.0))
					draw_rect(lane,Color(0.85,0.15,0.2,0.12 + progress * 0.14))
					var stripes := int(lane.size.x / 48.0)
					for index in stripes:
						var x := lane.position.x + fmod(index * 48.0 + progress * 60.0 * d + lane.size.x,lane.size.x)
						draw_line(Vector2(x,lane.position.y),Vector2(x + 20.0,lane.end.y),Color(1,0.3,0.3,0.25),3.0)
					draw_rect(lane,Color(1,0.3,0.3,0.85),false,3.0)
					var arrow_at := Vector2(lane.position.x + 40.0 if d > 0.0 else lane.end.x - 40.0,lane.get_center().y)
					draw_colored_polygon(PackedVector2Array([arrow_at + Vector2(16 * d,0),arrow_at + Vector2(-8 * d,-14),arrow_at + Vector2(-8 * d,14)]),Color(1,0.35,0.3,0.9))
				"wail":
					# Soul rings drawn in toward the mouth.
					for ring in 3:
						var r := (1.0 - fmod(progress * 2.0 + ring / 3.0,1.0)) * 300.0
						draw_arc(at,r,0,TAU,48,Color(0.5,0.9,1.0,0.55 * (1.0 - r / 300.0) + 0.1),3.0)
				"rain":
					var radius: float = telegraph.radius
					draw_circle(at,radius,Color(0.8,0.75,0.65,0.14))
					draw_circle(at,radius * progress,Color(0.9,0.85,0.7,0.3))
					draw_arc(at,radius,0,TAU,36,Color(0.95,0.9,0.75,0.9),3.0)
					draw_circle(at,5.0,Color(0.95,0.9,0.75,0.9))
