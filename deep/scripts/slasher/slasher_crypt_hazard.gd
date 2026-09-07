extends Node2D
class_name SlasherCryptHazard

signal projectile_requested(origin:Vector2,direction:Vector2,config:Dictionary)

enum Phase {DORMANT,TELEGRAPH,ACTIVE,COOLDOWN,DISABLED}
const SOURCES={"bone_spikes":preload("res://assets/crypt/hazards/bone_spikes_source.png"),"soulflame":preload("res://assets/crypt/hazards/soulflame_source.png"),"curse_sigil":preload("res://assets/crypt/hazards/curse_sigil_source.png")}

var kind:="bone_spikes"
var phase:=Phase.DORMANT
var timer:=0.0
var cycle_offset:=0.0
var radius:=42.0
var damage:=2
var target:SlasherPlayer
var sprite:AnimatedSprite2D
var hit_this_cycle:=false
var volley_index:=0

func setup(hazard_kind:String,player:SlasherPlayer,offset:float=0.0)->SlasherCryptHazard:
	kind=hazard_kind;target=player;cycle_offset=offset;return self

func _ready()->void:
	add_to_group("crypt_hazard");z_index=1;sprite=AnimatedSprite2D.new();sprite.sprite_frames=_frames();sprite.scale=Vector2.ONE*(0.20 if kind=="soulflame" else 0.16);sprite.position.y=-8;add_child(sprite);sprite.play("dormant");timer=1.5+cycle_offset;queue_redraw()

func _physics_process(delta:float)->void:
	if phase==Phase.DISABLED:return
	timer-=delta
	match phase:
		Phase.DORMANT:
			if timer<=0.0:telegraph()
		Phase.TELEGRAPH:
			if timer<=0.0:activate()
		Phase.ACTIVE:
			_apply_active_effect()
			if kind=="soulflame" and timer<=0.45 and volley_index==0:_emit_soulflame();volley_index=1
			if timer<=0.0:cooldown()
		Phase.COOLDOWN:
			if timer<=0.0:phase=Phase.DORMANT;timer=_cycle_delay();hit_this_cycle=false;volley_index=0;sprite.play("dormant");queue_redraw()

func telegraph()->void:
	if phase==Phase.DISABLED:return
	phase=Phase.TELEGRAPH;timer=0.85 if kind=="bone_spikes" else 1.05;sprite.play("warning");queue_redraw()

func activate()->void:
	if phase==Phase.DISABLED:return
	phase=Phase.ACTIVE;timer=0.55 if kind=="bone_spikes" else (1.8 if kind=="curse_sigil" else 0.9);sprite.play("active");queue_redraw()

func cooldown()->void:
	phase=Phase.COOLDOWN;timer=2.8 if kind=="bone_spikes" else 3.6;sprite.play("cooldown");queue_redraw()

func disable()->void:
	phase=Phase.DISABLED;timer=0.0;set_physics_process(false);visible=false

func _apply_active_effect()->void:
	if not is_instance_valid(target) or global_position.distance_to(target.global_position)>radius:return
	if kind=="curse_sigil":target.apply_movement_slow(0.68,0.22);target.suppress_resource_gain(0.25)
	elif kind=="bone_spikes" and not hit_this_cycle:target.receive_damage(damage,global_position.direction_to(target.global_position)*165.0);hit_this_cycle=true

func _emit_soulflame()->void:
	for index:int in 5:
		var direction:=Vector2.RIGHT.rotated(TAU*float(index)/5.0+cycle_offset)
		projectile_requested.emit(global_position+direction*18.0,direction,{"projectile_speed":155.0,"projectile_range":250.0,"hit_radius":10.0,"color":"#71e8ff","visual_type":"soul","movement_pattern":"curve","angular_velocity":0.22})

func _cycle_delay()->float:return 2.0+fmod(cycle_offset,1.5)

func _frames()->SpriteFrames:
	var frames:=SpriteFrames.new();frames.remove_animation("default");var texture:Texture2D=SOURCES.get(kind)
	for index:int in 4:
		var name:StringName=StringName(["dormant","warning","active","cooldown"][index]);frames.add_animation(name);frames.set_animation_loop(name,true);frames.set_animation_speed(name,4.0);var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(float(index)*texture.get_width()/4.0,0,float(texture.get_width())/4.0,float(texture.get_height()));frames.add_frame(name,atlas)
	return frames

func _draw()->void:
	if phase not in [Phase.TELEGRAPH,Phase.ACTIVE]:return
	var color:=Color("#ddd0ff55") if phase==Phase.TELEGRAPH else Color("#844ee866")
	draw_circle(Vector2.ZERO,radius,color);draw_arc(Vector2.ZERO,radius,0.0,TAU,36,Color(color,0.9),3.0)
