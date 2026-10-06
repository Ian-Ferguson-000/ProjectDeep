extends "res://scripts/slasher/slasher_mage_kit_base.gd"

const GEAR_ID := "mirrorbound_manuscript"
const ACTIONS := {"basic":"Silver Script","special":"Read Again","defensive":"Blank Page","movement":"Set the Reflection"}
const TUNING := {
	"basic":{"cooldown":0.18,"resource_cost":0,"power_stat":"spell_power","damage_coefficient":12.0,"projectile_range":420.0,"projectile_speed":900.0,"hit_radius":24.0,"piercing":true,"visual":"aether","visual_scale":1.2,"tint":"#f0d8ff","animation_lock":0.1},
	"special":{"cooldown":0.9,"resource_cost":1,"power_stat":"spell_power","damage_coefficient":20.0,"projectile_range":420.0,"projectile_speed":900.0,"hit_radius":28.0,"piercing":true,"visual":"aether","visual_scale":1.65,"tint":"#f0d8ff","animation_lock":0.12},
	"defensive":{"cooldown":0.6,"resource_cost":0,"mitigation":0.6,"effect_duration":0.6,"animation_lock":0.1},
	"movement":{"cooldown":0.65,"resource_cost":0,"animation_lock":0.1}
}
var mirror: Dictionary = {}
var recording: Dictionary = {}
var pending_replays: Array[Dictionary] = []
var barrier := 0
var barrier_left := 0.0

static func gear() -> GearData:
	return GearData.create(GEAR_ID,"Mirrorbound Manuscript",3,false,0,"read_again","Leave a mirror that fires half-strength Silver Scripts, record your shot direction, then fire Read Again down two lanes. Blank Page trades the recording for a temporary barrier on prevention.","mage","blank_page")
func kit_id() -> String:return GEAR_ID
func element() -> String:return "arcane"
func action_name(slot: String) -> String:return String(ACTIONS.get(slot,slot))
func raw_tuning(slot: String) -> Dictionary:return TUNING.get(slot,{})

func perform(slot: String, result: Dictionary) -> Dictionary:
	match slot:
		"basic":
			var attack := attack_for(slot,"Script",true)
			actor._spawn_projectile(attack,false)
			if not mirror.is_empty():
				recording={"direction":actor.aim_direction,"attack":secondary_copy(attack)}
				var lesser := secondary_copy(attack)
				lesser.damage=maxi(1,int(round(int(attack.damage)*0.5)));lesser.damage_source="Reflection"
				lesser.visual_scale=0.85
				actor._spawn_projectile(lesser,false,actor.aim_direction,mirror.center)
				flash(mirror.center,24)
		"special":
			actor._spawn_projectile(attack_for(slot,"Read Again"),false)
			if not mirror.is_empty() and not recording.is_empty():
				var attack: Dictionary=Dictionary(recording.attack).duplicate(true);attack.damage_source="Replay"
				pending_replays.append({"origin":mirror.center,"direction":recording.direction,"attack":attack,"left":0.12})
				recording.clear()
		"defensive":actor.defense_kind="mage_kit";actor.defense_window=0.6
		"movement":
			var start := actor.global_position
			result=safe_move(start+actor.aim_direction*300,result)
			if result.started:mirror={"center":start,"left":5.0};recording.clear()
	return result

func on_prevented_damage(_amount: int) -> void:
	if mirror.is_empty() or recording.is_empty():return
	recording.clear();barrier=maxi(1,int(round(actor.max_health*0.1)));barrier_left=2.0
	flash(actor.global_position,45)

func absorb_damage(amount: int) -> int:
	var absorbed := mini(amount,barrier) if barrier_left>0 else 0
	barrier-=absorbed
	return absorbed

func _physics_process(delta: float) -> void:
	super(delta)
	if not mirror.is_empty():
		mirror.left-=delta
		if float(mirror.left)<=0:mirror.clear();recording.clear()
	barrier_left=maxf(0,barrier_left-delta)
	if barrier_left<=0:barrier=0
	for index in range(pending_replays.size()-1,-1,-1):
		var replay: Dictionary=pending_replays[index];replay.left-=delta
		if float(replay.left)<=0:
			actor._spawn_projectile(replay.attack,false,replay.direction,replay.origin)
			flash(replay.origin,30);pending_replays.remove_at(index)

func _draw() -> void:
	super()
	var tint := Color("#f0d8ff")
	if not mirror.is_empty():
		VISUALS.mirror(self,to_local(mirror.center),clock,not recording.is_empty(),Vector2(recording.get("direction",Vector2.RIGHT)))
		draw_arc(to_local(mirror.center),35,0,TAU*float(mirror.left)/5,40,tint,3)
	for replay in pending_replays:
		var point := to_local(replay.origin)
		draw_line(point,point+Vector2(replay.direction)*100,tint,3)

func draw_foreground(canvas: Node2D) -> void:
	super(canvas)
	if barrier>0 and barrier_left>0:
		canvas.draw_arc(Vector2.ZERO,43,0,TAU,48,Color("#e6e6ff"),4)
		canvas.draw_string(ThemeDB.fallback_font,Vector2(-35,-72),"WARD %d"%barrier,HORIZONTAL_ALIGNMENT_CENTER,70,12,Color("#f0d8ff"))
