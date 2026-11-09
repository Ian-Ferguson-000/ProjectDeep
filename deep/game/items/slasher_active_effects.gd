extends RefCounted
class_name SlasherActiveEffects

const FIGHTER_ARSENAL := preload("res://game/player/warrior/slasher_fighter_arsenal.gd")
const MAGE_ACTIVE_ARSENAL := preload("res://game/player/mage/slasher_mage_active_arsenal.gd")
const NEUTRAL_ACTIVE_ARSENAL := preload("res://game/items/slasher_neutral_active_arsenal.gd")
const WARRIOR_KITS := preload("res://game/player/warrior/slasher_warrior_kits.gd")
const ACTIVE_ITEM_VFX := preload("res://game/items/slasher_active_item_vfx.gd")
const ICON_ROOT := "res://assets/slasher/active_item_icons/"
static var _icon_cache: Dictionary = {}

## What each active item does when used (data/active_items.json "effect.kind").
##
##   dash   Shadow Step     dash along your movement (or aim), invulnerable
##   spin   Whirlwind       hit everything around you, hard, and throw it back
##   line   Earthsplitter   a crack along the ground ahead hurts and stuns
##   rally  War Horn        a few seconds of harder, faster hits; knocks foes back
##   ward   Iron Skin       a barrier that soaks up damage for a while
##
## Damage scales from the hero's basic attack, so items keep up with relics and levels.

static func use(player: SlasherPlayer, id: String) -> bool:
	var record := ActiveItems.item(id)
	if record.is_empty() or not is_instance_valid(player): return false
	var effect: Dictionary = Dictionary(record.get("effect",{}))
	match String(effect.get("kind","")):
		"dash": _dash(player,effect)
		"spin": _spin(player,effect)
		"line": _line(player,effect)
		"rally": _rally(player,effect)
		"ward": _ward(player,effect)
		"fighter_weapon": return _fighter_weapon(player,id,effect)
		"mage_item": return _mage_item(player,id)
		"neutral_item": return _neutral_item(player,id)
		_: return false
	return true

static func _base_damage(player: SlasherPlayer) -> int:
	return maxi(1,player._scaled_damage(player._ability_tuning("basic")))

static func _targets(player: SlasherPlayer) -> Array:
	return player.get_tree().get_nodes_in_group("slasher_damageable").filter(func(node): return is_instance_valid(node) and node != player and node.has_method("receive_attack"))

# ------------------------------------------------------------------ effects

static func _dash(player: SlasherPlayer, effect: Dictionary) -> void:
	var direction := player.velocity.normalized() if player.velocity.length() > 10.0 else player.aim_direction.normalized()
	if direction == Vector2.ZERO: direction = Vector2.DOWN
	player.invulnerable = maxf(player.invulnerable,float(effect.get("invulnerable",0.35)))
	var dash := DashMotion.new()
	dash.direction = direction
	dash.speed = float(effect.get("distance",190.0)) / maxf(0.05,float(effect.get("duration",0.14)))
	dash.left = float(effect.get("duration",0.14))
	player.add_child(dash)
	AudioCue.play_from(player,"sword_swing")

static func _spin(player: SlasherPlayer, effect: Dictionary) -> void:
	var radius := float(effect.get("radius",125.0))
	var damage := int(round(_base_damage(player) * float(effect.get("damage_multiplier",3.0))))
	for target in _targets(player):
		if target.global_position.distance_to(player.global_position) > radius: continue
		target.receive_attack(player._attack_data(damage,"physical",{"knockback":float(effect.get("knockback",280.0)),"damage_source":"active_item"}),player)
	player.add_impact_shake(6.0,0.2)
	_flash(player,SpinFlash.new(),{"radius":radius})
	AudioCue.play_from(player,"sword_swing")

static func _line(player: SlasherPlayer, effect: Dictionary) -> void:
	var direction := player.aim_direction.normalized() if player.aim_direction != Vector2.ZERO else Vector2.DOWN
	var length := float(effect.get("length",380.0)); var width := float(effect.get("width",54.0))
	var damage := int(round(_base_damage(player) * float(effect.get("damage_multiplier",2.5))))
	for target in _targets(player):
		var offset: Vector2 = target.global_position - player.global_position
		var along := offset.dot(direction)
		if along < 0.0 or along > length or absf(offset.dot(direction.orthogonal())) > width: continue
		target.receive_attack(player._attack_data(damage,"physical",{"knockback":140.0,"hit_stun_duration":float(effect.get("stun",0.9)),"damage_source":"active_item"}),player)
	player.add_impact_shake(10.0,0.3)
	_flash(player,CrackFlash.new(),{"direction":direction,"length":length})
	AudioCue.play_from(player,"impact")

static func _rally(player: SlasherPlayer, effect: Dictionary) -> void:
	player.active_buff_time = float(effect.get("seconds",6.0))
	player.active_buff_damage = float(effect.get("damage_multiplier",1.5))
	player.active_buff_haste = float(effect.get("haste",1.4))
	var radius := float(effect.get("push_radius",150.0))
	for node in player.get_tree().get_nodes_in_group("slasher_enemy"):
		var foe := node as SlasherEnemy
		if foe == null or foe.dead or foe.global_position.distance_to(player.global_position) > radius: continue
		foe.move_and_collide(player.global_position.direction_to(foe.global_position) * float(effect.get("push",240.0)) * 0.25)
		foe.hit_stun_timer = maxf(foe.hit_stun_timer,0.4)
	var aura := RallyAura.new(); aura.player = player
	player.add_child(aura)
	_flash(player,SpinFlash.new(),{"radius":radius,"colour":Color(1.0,0.45,0.25)})
	AudioCue.play_from(player,"combo")

static func _ward(player: SlasherPlayer, effect: Dictionary) -> void:
	if is_instance_valid(player.kit_buffs): player.kit_buffs.grant_ward("active_item",int(effect.get("amount",8)),float(effect.get("seconds",10.0)))
	_flash(player,SpinFlash.new(),{"radius":40.0,"colour":Color(0.75,0.82,0.95)})
	AudioCue.play_from(player,"block")

## Executes one of the authored fighter weapons through the same runtime used
## by equipped versions. Reusing the node preserves returning shots, deployed
## tridents, curses, wounds, rampage and leashes between activations.
static func _fighter_weapon(player: SlasherPlayer,id:String,effect:Dictionary)->bool:
	var weapon_id:=String(effect.get("weapon_id",id));var runtime:Node
	for child in player.get_children():
		if child.get_meta("fighter_active_weapon_id","")==weapon_id:runtime=child;break
	if runtime==null:
		runtime=FIGHTER_ARSENAL.new();runtime.name="Active_%s"%weapon_id.to_pascal_case();runtime.set_meta("fighter_active_weapon_id",weapon_id);runtime.set_meta("active_item_runtime_id",weapon_id)
		var record:=WARRIOR_KITS.data_for(weapon_id)
		if record.is_empty():return false
		runtime.call("configure",player,weapon_id,record.actions);player.add_child(runtime)
	var result:Dictionary=runtime.call("perform",String(effect.get("slot","special")),{"started":true,"targets_hit":0,"projectiles_deflected":0,"failure":""})
	if not bool(result.get("started",false)):return false
	var duration:float=runtime.presentation_action_duration(0.3)
	player._play_action_animation(runtime.presentation_animation_state(),duration,duration)
	player.animation_lock=duration
	# Fighter runtime draws anticipation and contact on its authoritative clock.
	# A generic activation burst would falsely imply an immediate damaging hit.
	AudioCue.play_from(player,"combo")
	return true

static func _mage_item(player:SlasherPlayer,id:String)->bool:
	var runtime:=ensure_runtime(player,id)
	if not bool(runtime.call("activate")):return false
	if bool(runtime.get("defer_spend_once")):player.set_meta("active_item_skip_spend_once",true)
	AudioCue.play_from(player,"combo")
	return true

static func ensure_runtime(player:SlasherPlayer,id:String)->Node:
	if not is_instance_valid(player) or id.is_empty():return null
	for child in player.get_children():
		if child is SlasherMageActiveArsenal and child.item_id!=id:child.cancel()
	var effect:Dictionary=Dictionary(ActiveItems.item(id).get("effect",{}))
	var kind:=String(effect.get("kind",""))
	if kind not in ["neutral_item","mage_item"]:return null
	for child in player.get_children():
		if child.get_meta("active_item_runtime_id","")==id:return child
	var runtime:Node= MAGE_ACTIVE_ARSENAL.new() if kind=="mage_item" else NEUTRAL_ACTIVE_ARSENAL.new()
	runtime.name="Active_%s"%id.to_pascal_case();runtime.set_meta("active_item_runtime_id",id);player.add_child(runtime);runtime.configure(player,id);return runtime

static func _neutral_item(player:SlasherPlayer,id:String)->bool:
	var runtime:=ensure_runtime(player,id)
	if runtime==null or not bool(runtime.call("activate")):return false
	_play_authored_vfx(player,id)
	_flash(player,SpinFlash.new(),{"radius":58.0,"colour":Color("#f1d46c")})
	AudioCue.play_from(player,"combo")
	return true

static func _flash(player: SlasherPlayer, node: Node2D, values: Dictionary) -> void:
	for key in values: node.set(key,values[key])
	node.top_level = true
	player.add_child(node)
	node.global_position = player.global_position

static func _play_authored_vfx(player:SlasherPlayer,id:String)->void:
	var vfx:Node2D
	for child in player.get_children():
		if child.get_meta("active_item_vfx_id","")==id:vfx=child;break
	if vfx==null:
		vfx=ACTIVE_ITEM_VFX.new();vfx.name="Vfx_%s"%id.to_pascal_case();vfx.set_meta("active_item_vfx_id",id)
		player.add_child(vfx);vfx.call("configure",player,id)
	vfx.call("play_activation",player.aim_direction)

# ------------------------------------------------------------------ icons

static func icon_texture(id:String)->Texture2D:
	if _icon_cache.has(id):return _icon_cache[id]
	var path:=ICON_ROOT+id+".png"
	var texture:Texture2D=load(path) if ResourceLoader.exists(path) else null
	_icon_cache[id]=texture
	return texture

## Draws an item's icon on any canvas (HUD slot, pedestal), centred at `at`,
## about `size` pixels across. Authored items use unique pixel art; legacy items
## retain the compact procedural glyphs below as a graceful fallback.
static func draw_icon(canvas: CanvasItem, id: String, at: Vector2, size: float, dim: bool = false) -> void:
	var texture:=icon_texture(id)
	if texture!=null:
		var draw_size:=Vector2.ONE*size
		canvas.draw_texture_rect(texture,Rect2(at-draw_size*0.5,draw_size),false,Color(0.5,0.52,0.56,0.72) if dim else Color.WHITE)
		return
	var kind := String(Dictionary(ActiveItems.item(id).get("effect",{})).get("kind",""))
	var s := size / 32.0
	var ink := Color("#1c1410")
	var steel := Color("#c9d2dc") if not dim else Color("#7d838a")
	var gold := Color("#e0b44c") if not dim else Color("#8a7444")
	var accent := Color("#e0503c") if not dim else Color("#7a4a44")
	match kind:
		"dash":
			# A boot with speed lines behind it.
			for i in 3: canvas.draw_line(at + Vector2(-14,-6 + i * 6) * s,at + Vector2(-5,-6 + i * 6) * s,Color("#6fa8dc") if not dim else Color("#5a6a7a"),2.5 * s)
			var boot := PackedVector2Array([Vector2(-3,-12),Vector2(5,-12),Vector2(5,2),Vector2(14,6),Vector2(14,11),Vector2(-3,11)])
			var points := PackedVector2Array()
			for p in boot: points.append(at + p * s)
			canvas.draw_colored_polygon(points,Color("#7a4e2d") if not dim else Color("#5a4a40"))
			canvas.draw_polyline(points + PackedVector2Array([points[0]]),ink,1.5 * s)
			canvas.draw_line(at + Vector2(-3,7) * s,at + Vector2(14,7) * s,gold,2.0 * s)
		"spin":
			# A sword with a curling arc round it.
			canvas.draw_arc(at,13.0 * s,PI * 0.15,PI * 1.7,20,Color("#6fa8dc") if not dim else Color("#5a6a7a"),2.5 * s)
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(12,-13) * s,at + Vector2(15,-10) * s,at + Vector2(10,-8) * s]),Color("#6fa8dc") if not dim else Color("#5a6a7a"))
			_sword(canvas,at,s,Vector2(1,1).normalized(),steel,gold,ink)
		"line":
			# A sword driven into the ground, a crack running off.
			canvas.draw_polyline(PackedVector2Array([at + Vector2(-2,10) * s,at + Vector2(4,6) * s,at + Vector2(8,11) * s,at + Vector2(14,7) * s]),accent,2.5 * s)
			canvas.draw_line(at + Vector2(-14,11) * s,at + Vector2(14,11) * s,ink,1.5 * s)
			_sword(canvas,at + Vector2(-3,-2) * s,s,Vector2.DOWN,steel,gold,ink)
		"rally":
			# A war horn and its call.
			var horn := PackedVector2Array([Vector2(-13,6),Vector2(-10,0),Vector2(0,-6),Vector2(8,-10),Vector2(9,-2),Vector2(0,4),Vector2(-9,9)])
			var horn_points := PackedVector2Array()
			for p in horn: horn_points.append(at + p * s)
			canvas.draw_colored_polygon(horn_points,Color("#e8dcc0") if not dim else Color("#8a8478"))
			canvas.draw_polyline(horn_points + PackedVector2Array([horn_points[0]]),ink,1.5 * s)
			canvas.draw_line(at + Vector2(-8,3) * s,at + Vector2(-5,-1) * s,gold,2.0 * s)
			for r in [6.0,10.0]: canvas.draw_arc(at + Vector2(9,-6) * s,r * s,-PI * 0.45,PI * 0.25,8,accent,1.8 * s)
		"ward":
			# An iron shield with rivets.
			var shield := PackedVector2Array([Vector2(-11,-12),Vector2(11,-12),Vector2(11,0),Vector2(0,13),Vector2(-11,0)])
			var shield_points := PackedVector2Array()
			for p in shield: shield_points.append(at + p * s)
			canvas.draw_colored_polygon(shield_points,steel.darkened(0.25))
			canvas.draw_polyline(shield_points + PackedVector2Array([shield_points[0]]),ink,2.0 * s)
			canvas.draw_line(at + Vector2(0,-11) * s,at + Vector2(0,11) * s,steel.lightened(0.2),2.0 * s)
			for p in [Vector2(-7,-8),Vector2(7,-8),Vector2(-7,-1),Vector2(7,-1)]: canvas.draw_circle(at + p * s,1.6 * s,gold)
		"fighter_weapon":
			# Crossed steel and a bright active-item core; the item name distinguishes
			# the authored weapon while keeping the small HUD glyph readable.
			_sword(canvas,at+Vector2(-3,1)*s,s,Vector2(1,-1).normalized(),steel,gold,ink)
			_sword(canvas,at+Vector2(3,1)*s,s,Vector2(-1,-1).normalized(),steel,Color("#a56de2") if not dim else Color("#685676"),ink)
			canvas.draw_circle(at,3.0*s,accent)
		"mage_item":
			canvas.draw_circle(at,11.0*s,Color("#6551a8") if not dim else Color("#514b63"))
			canvas.draw_arc(at,13.0*s,0,TAU,24,Color("#91eaff") if not dim else Color("#657780"),2.0*s)
			canvas.draw_circle(at-Vector2(3,3)*s,3.0*s,Color("#f8d6ff") if not dim else Color("#8b8190"))
		"neutral_item":
			canvas.draw_arc(at,12.0*s,0,TAU,24,Color("#f1d46c") if not dim else Color("#746d4d"),3.0*s)
			canvas.draw_line(at+Vector2(0,-10)*s,at+Vector2(0,10)*s,Color("#d9f5ff") if not dim else steel,2.0*s)
			canvas.draw_circle(at,4.0*s,Color("#7d5fc2") if not dim else Color("#5a526b"))
		_:
			canvas.draw_circle(at,10.0 * s,gold)

static func _sword(canvas: CanvasItem, at: Vector2, s: float, down: Vector2, steel: Color, gold: Color, ink: Color) -> void:
	var tip := at + down * 13.0 * s; var hilt := at - down * 6.0 * s
	canvas.draw_line(hilt,tip,ink,5.0 * s); canvas.draw_line(hilt,tip,steel,3.0 * s)
	var guard := down.orthogonal() * 6.0 * s
	canvas.draw_line(hilt - guard,hilt + guard,gold,3.0 * s)
	canvas.draw_line(hilt,hilt - down * 6.0 * s,Color("#6b4a2b"),3.0 * s)
	canvas.draw_circle(hilt - down * 7.0 * s,2.0 * s,gold)

# ------------------------------------------------------------------ pieces

## Moves the hero quickly for a moment; walls stop it.
class DashMotion extends Node2D:
	var direction := Vector2.DOWN
	var speed := 1200.0
	var left := 0.14
	var ghost_timer := 0.0
	func _physics_process(delta: float) -> void:
		var body := get_parent() as CharacterBody2D
		if body == null or left <= 0.0:
			queue_free(); return
		left -= delta
		body.move_and_collide(direction * speed * delta)
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.03
			var ghost := Ghost.new(); ghost.top_level = true
			body.get_parent().add_child(ghost); ghost.global_position = body.global_position

## A fading after-image left by a dash.
class Ghost extends Node2D:
	var life := 0.25
	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0: queue_free()
		queue_redraw()
	func _draw() -> void:
		var a := clampf(life / 0.25,0.0,1.0)
		draw_circle(Vector2(0,-18),13.0,Color(0.45,0.55,0.9,0.35 * a))
		draw_circle(Vector2(0,-6),9.0,Color(0.45,0.55,0.9,0.25 * a))

## An expanding ring (Whirlwind, War Horn, Iron Skin).
class SpinFlash extends Node2D:
	var radius := 120.0
	var colour := Color(1.0,0.95,0.8)
	var age := 0.0
	func _process(delta: float) -> void:
		age += delta
		if age > 0.3: queue_free()
		queue_redraw()
	func _draw() -> void:
		var t := clampf(age / 0.3,0.0,1.0)
		draw_arc(Vector2.ZERO,radius * (0.4 + t * 0.6),0,TAU,48,Color(colour.r,colour.g,colour.b,1.0 - t),6.0 * (1.0 - t) + 2.0)
		for i in 3: draw_arc(Vector2.ZERO,radius * (0.3 + t * 0.6),t * TAU * 2.0 + i * TAU / 3.0,t * TAU * 2.0 + i * TAU / 3.0 + 1.2,12,Color(colour.r,colour.g,colour.b,0.7 * (1.0 - t)),4.0)

## The crack Earthsplitter tears along the ground.
class CrackFlash extends Node2D:
	var direction := Vector2.DOWN
	var length := 380.0
	var age := 0.0
	var jag: PackedFloat32Array
	func _ready() -> void:
		z_index = -1
		for i in 14: jag.append(randf_range(-9.0,9.0))
	func _process(delta: float) -> void:
		age += delta
		if age > 0.6: queue_free()
		queue_redraw()
	func _draw() -> void:
		var reach := clampf(age / 0.12,0.0,1.0) * length
		var fade := 1.0 - clampf((age - 0.25) / 0.35,0.0,1.0)
		var points := PackedVector2Array([Vector2.ZERO])
		for i in jag.size():
			var along := reach * float(i + 1) / jag.size()
			points.append(direction * along + direction.orthogonal() * jag[i])
		draw_polyline(points,Color(0.1,0.06,0.04,0.9 * fade),9.0)
		draw_polyline(points,Color(1.0,0.6,0.25,0.8 * fade),3.0)

## A red glow around the hero while War Horn lasts.
class RallyAura extends Node2D:
	var player: SlasherPlayer
	func _process(_delta: float) -> void:
		if not is_instance_valid(player) or player.active_buff_time <= 0.0:
			queue_free(); return
		queue_redraw()
	func _draw() -> void:
		var pulse := 0.6 + sin(Time.get_ticks_msec() / 120.0) * 0.2
		draw_arc(Vector2(0,-8),26.0,0,TAU,32,Color(1.0,0.35,0.2,pulse),3.0)
