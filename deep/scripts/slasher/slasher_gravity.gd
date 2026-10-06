extends "res://scripts/slasher/slasher_mage_kit_base.gd"

const GEAR_ID := "grimoire_of_gravity"
const ACTIONS := {"basic":"Orbiting Stone","special":"Collapse","defensive":"Heavy Air","movement":"Anchor Exchange"}
const TUNING := {
	"basic":{"cooldown":0.18,"resource_cost":0,"power_stat":"spell_power","damage_coefficient":12.0,"projectile_range":400.0,"projectile_speed":700.0,"hit_radius":24.0,"area_radius":65.0,"visual":"aether","visual_scale":1.3,"tint":"#c3a3ff","animation_lock":0.1},
	"special":{"cooldown":0.9,"resource_cost":1,"power_stat":"spell_power","damage_coefficient":25.0,"animation_lock":0.12},
	"defensive":{"cooldown":0.6,"resource_cost":0,"mitigation":0.5,"effect_duration":0.6,"animation_lock":0.1},
	"movement":{"cooldown":0.65,"resource_cost":0,"animation_lock":0.1}
}
var pending_stones: Array[Dictionary] = []
var well: Dictionary = {}
var anchor: Dictionary = {}
var air_left := 0.0
var slowed_shots: Dictionary = {}

static func gear() -> GearData:
	return GearData.create(GEAR_ID,"Grimoire of Gravity",3,false,0,"collapse","Lob explosive stones into a pulling well. Heavy Air slows hostile shots. Anchor Exchange offers one return to your departure point.","mage","heavy_air")
func kit_id() -> String:return GEAR_ID
func element() -> String:return "arcane"
func visual_element() -> String:return "gravity"
func action_name(slot: String) -> String:return String(ACTIONS.get(slot,slot))
func raw_tuning(slot: String) -> Dictionary:return TUNING.get(slot,{})

func perform(slot: String, result: Dictionary) -> Dictionary:
	match slot:
		"basic":pending_stones.append({"origin":actor.global_position+actor.aim_direction*24,"direction":actor.aim_direction,"left":0.1,"attack":attack_for(slot,"Stone",true)})
		"special":
			var center := aimed_point(300)
			if not clear_line(actor.global_position,center):result.started=false;result.failure="Collapse needs a clear placement path.";return result
			# Replacing an unresolved well pays out its remaining burst once, not repeatedly.
			if not well.is_empty():resolve_well()
			well={"center":center,"radius":115.0,"left":0.45,"duration":0.45,"attack":attack_for(slot,"Collapse")}
		"defensive":air_left=0.6;actor.defense_kind="mage_kit";actor.defense_window=0.6
		"movement":
			if not anchor.is_empty():
				result=safe_move(anchor.center,result,0.15)
				if result.started:anchor.clear()
			else:
				var start := actor.global_position
				result=safe_move(start+actor.aim_direction*300,result,0.15)
				if result.started:anchor={"center":start,"left":3.0};result["cooldown_override"]=0.2
	return result

func resolve_well() -> void:
	if well.is_empty():return
	for enemy in enemies():
		if enemy.global_position.distance_to(well.center)<=float(well.radius) and clear_line(well.center,enemy.global_position):hit(enemy,well.attack,true)
	flash(well.center,float(well.radius),"collapse",0.5);well.clear()

func restore_shot(id: int) -> void:
	if not slowed_shots.has(id):return
	var entry: Dictionary=slowed_shots[id]
	var shot := (entry.shot as WeakRef).get_ref() as SlasherHostileProjectile
	if is_instance_valid(shot):shot.speed=float(entry.speed)
	slowed_shots.erase(id)

func _exit_tree() -> void:
	for id in slowed_shots.keys():restore_shot(id)

func _physics_process(delta: float) -> void:
	super(delta)
	for index in range(pending_stones.size()-1,-1,-1):
		var stone: Dictionary=pending_stones[index];stone.left-=delta
		if float(stone.left)<=0:
			actor._spawn_projectile(stone.attack,false,stone.direction,stone.origin);pending_stones.remove_at(index)
	if not well.is_empty():
		well.left-=delta
		for enemy in enemies():
			if enemy.boss or enemy.mini_boss:continue
			var offset := Vector2(well.center)-enemy.global_position
			if offset.length()<=float(well.radius) and offset.length()>12 and clear_line(enemy.global_position,well.center):enemy.move_and_collide(offset.limit_length(180*delta))
		if float(well.left)<=0:resolve_well()
	if not anchor.is_empty():
		anchor.left-=delta
		if float(anchor.left)<=0:anchor.clear()
	air_left=maxf(0,air_left-delta)
	var inside: Dictionary = {}
	if air_left>0:
		for shot in hostile_shots():
			if shot.global_position.distance_to(actor.global_position)>105:continue
			var id := shot.get_instance_id();inside[id]=true
			if not slowed_shots.has(id):slowed_shots[id]={"shot":weakref(shot),"speed":shot.speed};shot.speed*=0.5
	for id in slowed_shots.keys():
		if not inside.has(id):restore_shot(id)

func _draw() -> void:
	super()
	var tint := VISUALS.color_for("gravity")
	if not well.is_empty():VISUALS.vortex(self,to_local(well.center),float(well.radius),clock,1-float(well.left)/float(well.duration))
	if not anchor.is_empty():
		var point := to_local(anchor.center)
		VISUALS.sigil(self,point,28,clock,tint)
		draw_line(point-Vector2(12,0),point+Vector2(12,0),tint,3);draw_line(point-Vector2(0,12),point+Vector2(0,12),tint,3)
		draw_arc(point,35,0,TAU*float(anchor.left)/3,32,tint,3)
	if air_left>0:VISUALS.vortex(self,Vector2.ZERO,105,clock,air_left/0.6)
	for stone in pending_stones:VISUALS.projectile(self,to_local(stone.origin),stone.direction,clock,"gravity")
