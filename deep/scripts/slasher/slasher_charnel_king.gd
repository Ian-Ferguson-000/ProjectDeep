extends SlasherColossus
class_name SlasherCharnelKing

## The Charnel King: the Stone Crypt's guardian. A giant crowned skeleton sunk
## to the chest in the floor of the Charnel Throne, fought old-school
## bullet-hell style like the Heartwood Colossus. It never moves; each attack has
## a clear warning, and afterwards a weak point opens for a few seconds.
##
##   Grave Sweep  red lanes striped across the arena (an arrow shows which way)
##                -> a giant hand sweeps along each lane -> the hand lies open at the far end
##   Soul Wail    the jaw drops and blue rings pull into its mouth
##                -> rings of souls with a gap in each: find the gap -> soul gem opens
##   Bone Rain    (from phase two) pale circles appear around you, filling up
##                -> bones crash down on each in turn and splinter -> soul gem opens
##
## Phases at 66% and 33% health, like the Colossus: it roars, clears the bullets
## and speeds up. Phase two sweeps two lanes at once (one hand each way); phase
## three adds a fourth wail wave and calls revenants and grave rats.
## Numbers: data/slasher_balance.json enemies.charnel_king. See docs/Crypt.md.

## A sweep in progress: lane rect, hand position, direction, whether it hit.
var sweeps: Array[Dictionary] = []
## Bones still to fall: position, time until impact.
var rain: Array[Dictionary] = []
var wail_gap_angle := 0.0
var jaw := 0.0

func configure(floor_number:int,is_boss:bool=true,enemy_visual_id:String="charnel_king",is_mini_boss:bool=false,enemy_behavior_id:String="charnel_king")->void:
	colossus_id = "charnel_king"
	super.configure(floor_number,is_boss,"charnel_king",is_mini_boss,"charnel_king")

func _build_weak_points() -> void:
	heart = WEAK_POINT.new().setup(self,"gem",28.0,heart_texture)
	heart.position = Vector2(0,half.y + 24.0)
	add_child(heart)

# ---------------------------------------------------------------- patterns

func _start_next_pattern() -> void:
	cycle_count += 1
	var options: Array[String] = ["grave_sweep","soul_wail"]
	if phase >= 2: options.append("bone_rain")
	var pick := "grave_sweep" if cycle_count == 1 else options[(cycle_count * 5 + phase) % options.size()]
	if pick == pattern: pick = options[(options.find(pick) + 1) % options.size()]
	pattern = pick
	state = "telegraph"
	telegraphs.clear(); sweeps.clear(); rain.clear()
	match pattern:
		"grave_sweep":
			timer = _t("sweep_telegraph",1.2)
			_plan_sweeps()
		"soul_wail":
			timer = _t("wail_telegraph",1.0)
			telegraphs.append({"kind":"wail","pos":_mouth(),"t":0.0,"total":timer})
		"bone_rain":
			timer = 0.25
			_plan_rain()
	AudioCue.play_from(self,"enemy_attack")

## One lane through the player (two in phase two, the second sweeping the other way).
func _plan_sweeps() -> void:
	var room := arena_rect()
	var lane_height := _t("lane_height",120.0)
	var first_y := clampf(target.global_position.y,room.position.y + lane_height * 0.5,room.end.y - lane_height * 0.5)
	var lanes: Array[float] = [first_y]
	if phase >= 2:
		# A second lane a little way off, never across its own body.
		for offset in [lane_height * 1.7,-lane_height * 1.7,lane_height * 2.6,-lane_height * 2.6]:
			var other: float = first_y + offset
			if other < room.position.y + lane_height * 0.5 or other > room.end.y - lane_height * 0.5: continue
			if absf(other - global_position.y) < half.y + lane_height * 0.5: continue
			lanes.append(other)
			break
	for index in lanes.size():
		var direction := 1.0 if (target.global_position.x > global_position.x) == (index == 0) else -1.0
		var rect := Rect2(Vector2(room.position.x,lanes[index] - lane_height * 0.5),Vector2(room.size.x,lane_height))
		var start_x := room.position.x - 40.0 if direction > 0.0 else room.end.x + 40.0
		sweeps.append({"rect":rect,"dir":direction,"x":start_x,"hit":false})
		telegraphs.append({"kind":"lane","rect":rect,"dir":direction,"pos":rect.get_center(),"t":0.0,"total":timer})

## Circles around the player, the first right on them, falling one after another.
func _plan_rain() -> void:
	var room := arena_rect().grow(-30.0)
	var count := int(_t("rain_count",7))
	var spread := _t("rain_spread",230.0)
	var radius := _t("rain_radius",58.0)
	for index in count:
		var spot := target.global_position if index == 0 else target.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(radius,spread)
		spot = spot.clamp(room.position,room.end)
		# Never inside the body.
		var local := spot - global_position
		if absf(local.x) < half.x + 10.0 and absf(local.y) < half.y + 10.0: spot = global_position + Vector2(local.x,half.y + radius + 20.0)
		var delay := _t("rain_telegraph",1.0) + index * _t("rain_stagger",0.16)
		rain.append({"pos":spot,"left":delay})
		telegraphs.append({"kind":"rain","pos":spot,"radius":radius,"t":0.0,"total":delay})

func _begin_attack() -> void:
	state = "attack"; pattern_step = 0; fire_timer = 0.0
	match pattern:
		"grave_sweep":
			# The lanes stay marked while the hands pass along them.
			timer = _t("sweep_duration",0.9)
		"soul_wail":
			telegraphs.clear()
			wail_gap_angle = global_position.direction_to(target.global_position).angle()
		"bone_rain": pass

func _run_attack(delta: float) -> void:
	match pattern:
		"grave_sweep": _run_sweep(delta)
		"soul_wail": _run_wail(delta)
		"bone_rain": _run_rain(delta)

func _run_sweep(delta: float) -> void:
	var room := arena_rect()
	var speed_px := (room.size.x + 80.0) / maxf(0.1,_t("sweep_duration",0.9))
	var done := true
	for sweep in sweeps:
		var end_x := room.end.x - 70.0 if float(sweep.dir) > 0.0 else room.position.x + 70.0
		sweep.x = float(sweep.x) + float(sweep.dir) * speed_px * delta * _pace()
		if (float(sweep.dir) > 0.0 and float(sweep.x) >= end_x) or (float(sweep.dir) < 0.0 and float(sweep.x) <= end_x): sweep.x = end_x
		else: done = false
		var lane: Rect2 = sweep.rect
		var hand := Vector2(float(sweep.x),lane.get_center().y)
		if not bool(sweep.hit) and is_instance_valid(target) and absf(target.global_position.y - hand.y) <= lane.size.y * 0.5 and absf(target.global_position.x - hand.x) <= 46.0:
			sweep.hit = true
			target.receive_damage(maxi(1,int(round(damage * _t("sweep_damage_multiplier",1.4)))),Vector2(float(sweep.dir) * 320.0,0.0),self)
			target.add_impact_shake(8.0,0.25)
	if not done: return
	telegraphs.clear()
	AudioCue.play_from(self,"impact")
	# Each hand lies open where it stopped.
	for sweep in sweeps:
		var lane: Rect2 = sweep.rect
		var hand_point: SlasherColossusWeakPoint = WEAK_POINT.new().setup(self,"hand",32.0,fist_texture)
		hand_point.top_level = true
		add_child(hand_point)
		hand_point.global_position = Vector2(float(sweep.x),lane.get_center().y)
		fists.append(hand_point)
		hand_point.open_for(_t("hand_window",2.6))
	sweeps.clear()
	state = "window"
	timer = _t("hand_window",2.6)

func _run_wail(delta: float) -> void:
	jaw = minf(1.0,jaw + delta * 4.0)
	fire_timer -= delta * _pace()
	if fire_timer > 0.0: return
	var waves := 4 if phase >= 3 else 3
	var count := int(_t("wail_bullets",28))
	var gap := int(_t("wail_gap",4))
	var step := TAU / count
	for index in count:
		var angle := wail_gap_angle + step * (index + 0.5)
		# Leave a gap of `gap` bullets centred on wail_gap_angle.
		if index >= count - gap / 2 or index < gap - gap / 2: continue
		_fire(Vector2.RIGHT.rotated(angle),_t("wail_speed",140.0) * (1.0 + 0.08 * (phase - 1)),"soul",Color("#7fe0ff"))
	AudioCue.play_from(self,"cast_aether")
	# The next wave's gap swings round, so you have to move.
	wail_gap_angle += (0.7 if pattern_step % 2 == 0 else -1.1)
	pattern_step += 1; fire_timer = _t("wail_wave_gap",0.75)
	if pattern_step >= waves: _open_window(heart,_t("gem_window",2.6))

func _run_rain(delta: float) -> void:
	for index in range(rain.size() - 1,-1,-1):
		var drop: Dictionary = rain[index]
		drop.left = float(drop.left) - delta * _pace()
		if float(drop.left) > 0.0: continue
		_bone_impact(Vector2(drop.pos))
		rain.remove_at(index)
		for t_index in range(telegraphs.size() - 1,-1,-1):
			if Vector2(telegraphs[t_index].pos) == Vector2(drop.pos): telegraphs.remove_at(t_index)
	if rain.is_empty(): _open_window(heart,_t("gem_window",2.6))

func _bone_impact(spot: Vector2) -> void:
	var radius := _t("rain_radius",58.0)
	if is_instance_valid(target) and target.global_position.distance_to(spot) <= radius:
		target.receive_damage(maxi(1,int(round(damage * _t("rain_damage_multiplier",1.2)))),(target.global_position - spot).normalized() * 220.0,self)
		target.add_impact_shake(6.0,0.2)
	AudioCue.play_from(self,"impact")
	var shards := int(_t("rain_shards",6))
	for index in shards: _fire(Vector2.RIGHT.rotated(TAU * index / shards + randf() * 0.3),_t("rain_shard_speed",160.0),"bone",Color("#d9d0bd"),spot)

func _end_window() -> void:
	jaw = 0.0
	super._end_window()

func _mouth() -> Vector2:
	return global_position + Vector2(0,-half.y * 0.05)

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if body_texture != null:
		draw_texture(body_texture,-body_texture.get_size() * 0.5)
		_draw_arms()
		return
	var t := Time.get_ticks_msec() / 1000.0
	var angry := state == "roar"
	var wailing := (state == "telegraph" and pattern == "soul_wail") or (state == "attack" and pattern == "soul_wail")
	var open_jaw := jaw if wailing else 0.0
	if state == "telegraph" and pattern == "soul_wail": open_jaw = clampf(1.0 - timer / maxf(0.01,_t("wail_telegraph",1.0)),0.0,1.0)
	var bone := Color("#c9c1ae").lerp(Color("#e8a090"),_shake_glow * 0.3)
	var shade := Color("#7d7566")
	var dark := Color("#120d16")
	# Broken floor where it bursts out.
	draw_set_transform(Vector2(0,half.y * 0.55),0.0,Vector2(1.0,0.38))
	draw_circle(Vector2.ZERO,half.x * 1.05,Color(0.02,0.01,0.04,0.75))
	draw_set_transform(Vector2.ZERO)
	for index in 10:
		var angle := PI * 0.05 + PI * 0.9 * index / 9.0
		var at := Vector2(cos(angle) * half.x * 0.95,half.y * 0.55 + sin(angle) * half.y * 0.32)
		draw_rect(Rect2(at - Vector2(9,6),Vector2(18,12)),Color("#3a3640"))
	# Ribcage rising out of the floor.
	for rib in 4:
		var y := half.y * 0.05 + rib * 22.0
		var width := half.x * (0.55 - rib * 0.06)
		draw_arc(Vector2(0,y),width,PI * 1.05,PI * 1.95,18,dark,12.0)
		draw_arc(Vector2(0,y),width,PI * 1.05,PI * 1.95,18,bone,8.0)
	draw_line(Vector2(0,-half.y * 0.1),Vector2(0,half.y * 0.6),dark,14.0)
	draw_line(Vector2(0,-half.y * 0.1),Vector2(0,half.y * 0.6),shade,9.0)
	_draw_arms()
	# Skull.
	var skull := Vector2(0,-half.y * 0.48 + sin(t * 0.9) * 2.0)
	draw_circle(skull,74,dark); draw_circle(skull,70,bone)
	draw_circle(skull + Vector2(-18,-20),40,bone.lightened(0.06))
	var eye_colour := Color("#ff4a3a") if angry else (Color("#7fe0ff") if wailing else Color("#9fd8ff"))
	for side in [-1,1]:
		var eye := skull + Vector2(side * 26,-4)
		draw_circle(eye,19,dark)
		draw_circle(eye,7 + (4 if angry else 0) + sin(t * 3.0) * 1.2,eye_colour)
	draw_colored_polygon(PackedVector2Array([skull + Vector2(-7,18),skull + Vector2(7,18),skull + Vector2(0,30)]),dark)
	# Jaw: drops open for the wail.
	var jaw_top := skull + Vector2(0,40 + open_jaw * 26.0)
	draw_rect(Rect2(jaw_top + Vector2(-44,0),Vector2(88,24)),dark)
	draw_rect(Rect2(jaw_top + Vector2(-40,2),Vector2(80,18)),bone.darkened(0.08))
	for tooth in 7:
		draw_rect(Rect2(jaw_top + Vector2(-35 + tooth * 10,-4),Vector2(7,8)),bone.lightened(0.1))
	if open_jaw > 0.05: draw_rect(Rect2(skull + Vector2(-38,38),Vector2(76,open_jaw * 26.0)),Color(0.35,0.85,1.0,0.35 + open_jaw * 0.4))
	# Rusted crown.
	for spike in 5:
		var x := -48.0 + spike * 24.0
		var tall := 34.0 if spike == 2 else 24.0
		draw_colored_polygon(PackedVector2Array([skull + Vector2(x - 11,-56),skull + Vector2(x,-56 - tall),skull + Vector2(x + 11,-56)]),Color("#8a7038"))
	draw_rect(Rect2(skull + Vector2(-60,-62),Vector2(120,12)),Color("#a8873e"))
	draw_circle(skull + Vector2(0,-56),6,Color("#c2453c"))

## Arms resting on the floor, or reaching out to the sweeping/opened hands.
func _draw_arms() -> void:
	var dark := Color("#120d16"); var bone := Color("#b8b09c")
	var hands: Array[Vector2] = []
	for sweep in sweeps:
		var lane: Rect2 = sweep.rect
		hands.append(to_local(Vector2(float(sweep.x),lane.get_center().y)))
	for fist in fists:
		if is_instance_valid(fist): hands.append(to_local(fist.global_position))
	if hands.is_empty():
		for side in [-1,1]:
			var shoulder := Vector2(side * half.x * 0.42,-half.y * 0.05)
			var elbow := shoulder + Vector2(side * 70,40)
			var wrist := elbow + Vector2(side * 30,55)
			draw_polyline(PackedVector2Array([shoulder,elbow,wrist]),dark,16.0,true)
			draw_polyline(PackedVector2Array([shoulder,elbow,wrist]),bone,10.0,true)
			for finger in 4: draw_line(wrist,wrist + Vector2(side * (6 + finger * 6),18 + finger * 2),bone,5.0)
		return
	for hand in hands:
		var side := signf(hand.x) if absf(hand.x) > 1.0 else 1.0
		var shoulder := Vector2(side * half.x * 0.42,-half.y * 0.05)
		var middle := shoulder.lerp(hand,0.5) + Vector2(0,-40)
		draw_polyline(PackedVector2Array([shoulder,middle,hand]),dark,18.0,true)
		draw_polyline(PackedVector2Array([shoulder,middle,hand]),bone,12.0,true)
		# A sweeping hand is drawn here; an opened one is its weak point.
		var sweeping := false
		for sweep in sweeps:
			var lane: Rect2 = sweep.rect
			if to_local(Vector2(float(sweep.x),lane.get_center().y)).is_equal_approx(hand): sweeping = true
		if sweeping:
			draw_circle(hand,30,dark); draw_circle(hand,26,bone)
			for finger in 4:
				var x := -18.0 + finger * 12.0
				draw_line(hand + Vector2(x,-10),hand + Vector2(x * 1.2,-36),bone,6.0)
