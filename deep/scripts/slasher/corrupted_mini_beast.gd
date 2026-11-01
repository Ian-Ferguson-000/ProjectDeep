extends Node2D
class_name CorruptedMiniBeast

var owner_player: SlasherPlayer
var lifetime := 12.0
var attack_cooldown := 0.0
var orbit_offset := Vector2.ZERO
var tint := Color("#a956d8")

func setup(player: SlasherPlayer, origin: Vector2, index: int) -> CorruptedMiniBeast:
	owner_player=player;global_position=origin
	orbit_offset=Vector2.RIGHT.rotated(float(index)*2.399)*float(28+index%3*10)
	z_index=5
	return self

func _physics_process(delta: float) -> void:
	if not is_instance_valid(owner_player) or owner_player.health<=0:queue_free();return
	lifetime-=delta;attack_cooldown=maxf(0.0,attack_cooldown-delta)
	if lifetime<=0.0:queue_free();return
	var target: SlasherEnemy;var best:=INF
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and not node.dead and owner_player.get_parent().is_ancestor_of(node):
			var distance:=global_position.distance_squared_to(node.global_position)
			if distance<best:best=distance;target=node
	if target==null:
		global_position=global_position.move_toward(owner_player.global_position+orbit_offset,150.0*delta)
	elif best>42.0*42.0:
		global_position=global_position.move_toward(target.global_position,190.0*delta)
	elif attack_cooldown<=0.0:
		var damage:=maxi(1,int(round(owner_player.attack_power*0.45)))
		target.receive_attack({"damage":damage,"damage_type":"aether","damage_source":"Corrupted Mini-Beast","knockback":18.0,"hit_stun_duration":0.03,"mage_secondary":true},owner_player)
		attack_cooldown=0.7;queue_redraw()
	queue_redraw()

func _draw() -> void:
	var pulse:=1.0+sin(Time.get_ticks_msec()*0.008+get_instance_id()%11)*0.12
	draw_circle(Vector2.ZERO,8.0*pulse,Color(tint,0.72))
	draw_circle(Vector2(-3,-2),1.5,Color("#f4d7ff"));draw_circle(Vector2(3,-2),1.5,Color("#f4d7ff"))
	draw_arc(Vector2.ZERO,12.0,0,TAU,18,Color(tint,0.45),2.0)
