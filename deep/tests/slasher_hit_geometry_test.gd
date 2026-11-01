extends SceneTree

class Dummy extends Node2D:
	var hits:=0
	var radius:=20.0
	func combat_hurtbox()->Dictionary:return SlasherHitGeometry.circle(global_position,radius)
	func receive_attack(_data:Dictionary,_source:Node=null)->int:hits+=1;return 1

var failures:Array[String]=[]
func _initialize()->void:call_deferred("_run")
func check(condition:bool,message:String)->void:
	if not condition:failures.append(message)
func _player(id:String)->SlasherPlayer:
	var state:=RunState.new();state.set_class(id);state.start_new_run(GearData.create("hit_test","Hit Test",2,false,0,"","",id),"forest")
	var player:=SlasherPlayer.new();player.setup(state);root.add_child(player);player.set_physics_process(false);player.global_position=Vector2(300,300);return player
func _shot(player:SlasherPlayer,from:Vector2,to:Vector2)->SlasherHostileProjectile:
	var shot:=SlasherHostileProjectile.new().setup(null,player,from,from.direction_to(to),1,{"projectile_speed":1000.0,"projectile_range":1000.0,"hit_radius":8.0})
	root.add_child(shot);shot.set_physics_process(false);return shot
func _run()->void:
	var dummy:=Dummy.new();root.add_child(dummy);dummy.global_position=Vector2(135,0)
	check(SlasherHitGeometry.overlaps_sector(Vector2.ZERO,Vector2.RIGHT,118,92,dummy),"Visible outer body missed by slash")
	dummy.position=Vector2(140,0)
	check(not SlasherHitGeometry.overlaps_sector(Vector2.ZERO,Vector2.RIGHT,118,92,dummy),"Slash reaches beyond hurt body")
	dummy.position=Vector2(0,-90)
	check(SlasherHitGeometry.sweep(Vector2(-100,-90),Vector2(100,-90),dummy,4)<0.5,"Swept shot missed target between endpoints")
	check(SlasherHitGeometry.sweep(Vector2(-100,-115),Vector2(100,-115),dummy,4)==INF,"Near miss hit outside capsule")
	check(SlasherHitGeometry.sweep(dummy.position,dummy.position,dummy,0)==0.0,"Initial overlap missed")
	dummy.free()
	for id in ["warrior","mage"]:
		var player:=_player(id);var body:=player.combat_hurtbox();var center:Vector2=(Vector2(body.a)+Vector2(body.b))*0.5
		print(id," hurt capsule: ",body)
		check(center.y<player.global_position.y,"Body remains at feet for "+id)
		var health:=player.health
		var shot:=_shot(player,center-Vector2(100,0),center+Vector2(100,0));shot._physics_process(0.2)
		check(shot.impacted and player.health<health,"Fast torso crossing did not hit "+id)
		player.invulnerable=1.0;health=player.health
		body=player.combat_hurtbox();center=(Vector2(body.a)+Vector2(body.b))*0.5
		shot=_shot(player,center-Vector2(100,0),center+Vector2(100,0));shot._physics_process(0.2)
		check(shot.impacted and player.health==health,"Invulnerability handling changed")
		player.free();await process_frame
	var protected:=_player("warrior")
	var hurt:=protected.combat_hurtbox();var torso:Vector2=(Vector2(hurt.a)+Vector2(hurt.b))*0.5
	var wall:=StaticBody2D.new();wall.position=torso-Vector2(50,0)
	var wall_shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(8,120);wall_shape.shape=box;wall.add_child(wall_shape);root.add_child(wall)
	await physics_frame
	var health:=protected.health
	var blocked:=_shot(protected,torso-Vector2(100,0),torso+Vector2(100,0));blocked._physics_process(0.2)
	check(blocked.impacted and protected.health==health,"Projectile passed through wall")
	wall.position=torso+Vector2(50,0);await physics_frame
	var before_wall:=_shot(protected,torso-Vector2(100,0),torso+Vector2(100,0));before_wall._physics_process(0.2)
	check(before_wall.impacted and protected.health<health,"Wall beyond player swallowed earlier body contact")
	wall.free();protected.free();await process_frame
	var owner:=_player("mage");owner.position=Vector2(0,0)
	var near:=Dummy.new();near.position=Vector2(70,0)
	var far:=Dummy.new();far.position=Vector2(140,0)
	root.add_child(far);far.add_to_group("slasher_damageable");root.add_child(near);near.add_to_group("slasher_damageable")
	var spell:=SlasherProjectile.new().setup(owner,Vector2.ZERO,Vector2.RIGHT,{"speed":1000,"range":300,"damage":1,"hit_radius":8})
	root.add_child(spell);spell.set_physics_process(false);spell._physics_process(0.2)
	check(near.hits==1 and far.hits==0 and spell.impacted,"Projectile did not hit nearest body first")
	spell.free();near.free();far.free();owner.free()
	var boss:=SlasherEnemy.new();boss.configure(3,false,"briar_guardian",true,"elite_guardian");root.add_child(boss);boss.set_physics_process(false)
	var boss_body:=boss.combat_hurtbox();print("guardian hurt capsule: ",boss_body)
	check(float(boss_body.radius)>10 and Vector2(boss_body.a).y<boss.position.y,"Guardian body not aligned to visible torso")
	var weak:=SlasherColossusWeakPoint.new().setup(boss,"heart",30);root.add_child(weak);weak.position=Vector2(140,0)
	check(SlasherHitGeometry.overlaps_sector(Vector2.ZERO,Vector2.RIGHT,118,92,weak),"Boss weak-point rim is unhittable")
	var hp:=boss.health;weak.receive_attack({"damage":1});check(boss.health==hp,"Closed weak point took damage")
	weak.open_for(1);weak.receive_attack({"damage":1});check(boss.health<hp,"Open weak point did not take damage")
	var deflector:=_player("warrior");deflector.position=Vector2(-200,200)
	var return_shot:=_shot(deflector,weak.position-Vector2(100,0),weak.position+Vector2(100,0))
	return_shot.deflect(deflector,Vector2.RIGHT);hp=boss.health;return_shot._physics_process(0.2)
	check(return_shot.impacted and boss.health<hp,"Deflected shot missed boss weak point")
	boss.remove_from_group("slasher_enemy");boss.remove_from_group("slasher_damageable")
	var kit:=preload("res://scripts/slasher/slasher_warrior_kit.gd").new();kit.actor=deflector;root.add_child(kit);kit.set_physics_process(false)
	hp=boss.health;kit.slash(Vector2.ZERO,Vector2.RIGHT,118,92,{"damage":1},false)
	check(boss.health<hp,"Weapon-kit slash missed boss weak-point rim")
	kit.free()
	deflector.free()
	var victim:=_player("warrior");var victim_shape:=victim.combat_hurtbox()
	var victim_center:Vector2=(Vector2(victim_shape.a)+Vector2(victim_shape.b))*0.5
	boss.target=victim;boss.global_position=victim_center-Vector2(80,0)
	hp=victim.health;boss._release_guardian_burst(0.0)
	var burst_count:=0
	for projectile in get_nodes_in_group("slasher_hostile_projectile"):
		if projectile.source!=boss:continue
		burst_count+=1;projectile.set_physics_process(false);projectile._physics_process(0.4)
		if not projectile.is_queued_for_deletion():projectile.queue_free()
	check(burst_count>0 and victim.health<hp,"Actual Briar Guardian burst passed through torso")
	victim.free()
	weak.free();boss.free();await process_frame
	if failures.is_empty():print("SLASHER_HIT_GEOMETRY_TESTS_PASSED");quit(0)
	else:
		for message in failures:push_error(message)
		quit(1)
