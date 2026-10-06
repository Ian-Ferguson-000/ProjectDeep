extends "res://scripts/slasher/slasher_mage_kit_base.gd"

const GEAR_ID := "stormbringers_grimoire"
const ACTIONS := {"basic":"Forked Spark","special":"Grounding Rod","defensive":"Static Screen","movement":"Flash Circuit"}
const TUNING := {
	"basic":{"cooldown":0.18,"resource_cost":0,"power_stat":"spell_power","damage_coefficient":12.0,"animation_lock":0.1},
	"special":{"cooldown":0.9,"resource_cost":1,"power_stat":"spell_power","damage_coefficient":8.0,"animation_lock":0.12},
	"defensive":{"cooldown":0.6,"resource_cost":0,"mitigation":0.5,"effect_duration":0.6,"animation_lock":0.1},
	"movement":{"cooldown":0.65,"resource_cost":0,"animation_lock":0.1}
}
const MAX_CHAIN_TARGETS := 4
const BOUNCE_RETAINED_DAMAGE := 0.7
const MAX_RODS := 3
var rods: Array[Dictionary] = []
# Oldest conductor accessor for existing diagnostics.
var conductor: Dictionary:
	get:return rods[0] if not rods.is_empty() else {}
var screen_left := 0.0
var blocked_shots := 0
var screen_rewarded := false
var last_chain: Array[Dictionary] = []

static func gear() -> GearData:
	return GearData.create(GEAR_ID,"Stormbringer's Grimoire",3,false,0,"grounding_rod","Forked Spark always chains to nearby enemies, losing 30% damage per bounce. Up to three conductors preserve full bounce damage and pulse lightning. Flash Circuit travels to the rod nearest your clicked point.","mage","static_screen")
func kit_id() -> String:return GEAR_ID
func element() -> String:return "lightning"
func action_name(slot: String) -> String:return String(ACTIONS.get(slot,slot))
func raw_tuning(slot: String) -> Dictionary:return TUNING.get(slot,{})
func defense_resource_gain() -> int:return 0 if screen_rewarded else 1
func on_prevented_damage(_amount: int) -> void:screen_rewarded=true

func first_target() -> SlasherEnemy:
	var found: SlasherEnemy
	var nearest := 400.0
	for enemy in enemies():
		var offset := enemy.global_position-actor.global_position
		var forward := offset.dot(actor.aim_direction)
		var lateral := absf(offset.cross(actor.aim_direction))
		var screen_point := get_canvas_transform()*enemy.global_position
		if forward>=0 and forward<=360 and lateral<=32 and offset.length()<nearest and get_viewport_rect().has_point(screen_point) and clear_line(actor.global_position,enemy.global_position):found=enemy;nearest=offset.length()
	return found

func fire_chain() -> void:
	last_chain.clear()
	var target := first_target()
	if target==null:arc(actor.global_position,actor.global_position+actor.aim_direction*360);return
	var attack := attack_for("basic","Spark",true)
	var damage := int(attack.damage)
	var previous := actor.global_position
	var visited: Dictionary = {}
	var supported := not conductor.is_empty() and float(conductor.left)>0
	if supported:arc(conductor.center,target.global_position)
	for index in MAX_CHAIN_TARGETS:
		if not is_instance_valid(target):break
		var point := target.global_position
		visited[target.get_instance_id()]=true
		var strike: Dictionary=attack.duplicate(true) if index==0 else secondary_copy(attack)
		strike.damage=damage;strike.damage_source="Spark" if index==0 else "Bounce"
		hit(target,strike,index==0)
		last_chain.append({"enemy":weakref(target),"damage":damage,"supported":supported})
		arc(previous,point);flash(point,25,"burst",0.18)
		var next_target: SlasherEnemy
		var distance := 181.0
		for candidate in enemies():
			var current := point.distance_to(candidate.global_position)
			if visited.has(candidate.get_instance_id()) or current>180 or not get_viewport_rect().has_point(get_canvas_transform()*candidate.global_position):continue
			if current<distance and clear_line(point,candidate.global_position):next_target=candidate;distance=current
		if not supported:damage=maxi(1,int(round(damage*BOUNCE_RETAINED_DAMAGE)))
		previous=point;target=next_target

func perform(slot: String, result: Dictionary) -> Dictionary:
	match slot:
		"basic":fire_chain();result.targets_hit=last_chain.size()
		"special":
			var center := aimed_point(340)
			if not clear_line(actor.global_position,center):result.started=false;result.failure="The conductor needs a clear placement path.";return result
			rods.append({"center":center,"left":5.0,"tick":0.18,"charged":false,"attack":attack_for(slot,"Conductor")})
			if rods.size()>MAX_RODS:rods.pop_front()
			flash(center,110)
		"defensive":
			screen_left=0.6;blocked_shots=0;screen_rewarded=false
			actor.defense_kind="mage_kit";actor.defense_window=0.6
		"movement":
			var destination := actor.global_position+actor.aim_direction*240
			var selected: Dictionary={}
			var click := actor.get_global_mouse_position()
			if Input.get_vector("slasher_aim_left","slasher_aim_right","slasher_aim_up","slasher_aim_down").length()>0.2:click=actor.global_position+actor.aim_direction*340
			var nearest := INF
			for rod in rods:
				var distance: float=Vector2(rod.center).distance_to(click)
				if distance<nearest:nearest=distance;selected=rod
			if not selected.is_empty():destination=selected.center
			result=safe_move(destination,result)
	return result

func _physics_process(delta: float) -> void:
	super(delta)
	screen_left=maxf(0,screen_left-delta)
	if screen_left>0:
		for shot in hostile_shots():
			if blocked_shots>=3:break
			var offset := shot.global_position-actor.global_position
			if offset.length()<=130 and (offset.is_zero_approx() or offset.normalized().dot(actor.aim_direction)>=0.5) and clear_line(actor.global_position,shot.global_position):
				shot._finish();blocked_shots+=1;arc(actor.global_position,shot.global_position)
				if not screen_rewarded:
					screen_rewarded=true;actor._award_resource(1);actor.resource_changed.emit(actor.run_state.class_resource,actor.run_state.get_class_resource_max())
				if blocked_shots==1:
					for rod in rods:rod.charged=true
	for index in range(rods.size()-1,-1,-1):
		var rod: Dictionary=rods[index]
		rod.left-=delta;rod.tick-=delta
		if float(rod.left)<=0:rods.remove_at(index);continue
		if float(rod.tick)<=0:
			rod.tick+=0.45
			var attack := secondary_copy(rod.attack)
			attack.damage=maxi(1,int(round(int(attack.damage)*(float(rod.get("pulse_bonus",1.5)) if bool(rod.charged) else 1.0))))
			attack["hit_stun_duration"]=0.0;attack["screen_shake_multiplier"]=0.0
			rod.charged=false;rod.erase("pulse_bonus")
			for enemy in enemies():
				if enemy.global_position.distance_to(rod.center)<=110 and clear_line(rod.center,enemy.global_position):hit(enemy,attack);arc(rod.center,enemy.global_position)
			flash(rod.center,110,"burst",0.3)

func _draw() -> void:
	super()
	var tint := VISUALS.color_for("lightning")
	for rod in rods:
		var point := to_local(rod.center)
		VISUALS.sigil(self,point,110,clock,tint)
		draw_line(point,point+Vector2(0,-58),Color("#b69a64"),7)
		draw_line(point+Vector2(-14,-42),point+Vector2(14,-42),Color("#ffd891"),5)
		VISUALS.lightning(self,point+Vector2(-12,-54),point+Vector2(12,-54),clock,tint)
		draw_circle(point+Vector2(0,-58),7 if not bool(rod.charged) else 12,Color.WHITE)
		draw_arc(point,118,0,TAU*float(rod.left)/5,48,Color("#e7dd93"),3)
	if screen_left>0:
		var line := PackedVector2Array()
		for index in 21:line.append(actor.aim_direction.rotated(deg_to_rad(-60+index*6))*125)
		draw_polyline(line,Color(0.5,0.9,1,0.25),14,true);draw_polyline(line,tint,3,true)
