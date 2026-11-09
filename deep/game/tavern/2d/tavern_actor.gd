extends Node2D
class_name TavernActor

signal interaction_requested(actor_kind:String, actor_id:String)
signal destination_reached(actor:TavernActor)

enum ActivityState { ENTERING, IDLE, WALKING, SEATED, CHATTING, INTERACTING, DEPARTING }

@export var movement_speed:=115.0
var actor_kind:=""
var actor_id:=""
var display_name:=""
var conversation_id:=""
var state:=ActivityState.IDLE
var paused:=false
var destination:=Vector2.ZERO
var _last_direction:="down"
var _movement_delta:=0.0
var _standing_scale:=Vector2.ONE

@onready var sprite:AnimatedSprite2D=$Sprite
@onready var agent:NavigationAgent2D=$NavigationAgent2D
@onready var hit_target:Button=$HitTarget
@onready var nameplate:Label=$Nameplate
@onready var bubble:Label=$AmbientBubble

func configure(kind:String,id:String,name_value:String,frames:SpriteFrames,scale_value:Vector2=Vector2.ONE)->void:
	actor_kind=kind;actor_id=id;display_name=name_value
	if not is_node_ready():await ready
	sprite.sprite_frames=frames;sprite.scale=scale_value;_standing_scale=scale_value;nameplate.text=name_value
	hit_target.tooltip_text="Speak with %s"%name_value;hit_target.accessibility_name=hit_target.tooltip_text
	_play("idle")

func configure_from_dict(config:Dictionary)->void:
	configure(String(config.get("actor_kind", "")),String(config.get("campaign_id", "")),String(config.get("display_name", "")),config.get("sprite_frames") as SpriteFrames,Vector2(config.get("scale", Vector2.ONE)))
	conversation_id=String(config.get("conversation_id", ""))

func _ready()->void:
	add_to_group("tavern_interactable")
	hit_target.pressed.connect(func():interaction_requested.emit(actor_kind,actor_id))
	agent.path_desired_distance=10.0;agent.target_desired_distance=9.0;agent.radius=18.0;agent.max_speed=movement_speed
	agent.avoidance_enabled=false;agent.velocity_computed.connect(_on_safe_velocity)
	bubble.visible=false

func interact(_actor: Node) -> String:
	interaction_requested.emit(actor_kind, actor_id)
	return ""

func prompt() -> String:
	return "[E] Speak with %s" % display_name

func move_to(point:Vector2,next_state:int=ActivityState.IDLE)->void:
	destination=point;state=ActivityState.DEPARTING if next_state==ActivityState.DEPARTING else ActivityState.WALKING
	set_meta("arrival_state",next_state);agent.target_position=point;agent.avoidance_enabled=true

func seat_at(point:Vector2)->void:
	global_position=point;state=ActivityState.SEATED;sprite.scale=Vector2(_standing_scale.x,_standing_scale.y*0.76);z_index=-1;_play("idle");show_emote("🍲")

func stand_up()->void:
	sprite.scale=_standing_scale;z_index=0;state=ActivityState.IDLE;bubble.visible=false;_play("idle")

func show_emote(text_value:String,duration:=2.4)->void:
	bubble.text=text_value;bubble.visible=true
	var tween:=create_tween();tween.tween_interval(duration);tween.tween_callback(func():if is_instance_valid(bubble):bubble.visible=false)

func set_interaction_paused(value:bool)->void:
	paused=value
	if value:state=ActivityState.INTERACTING;agent.avoidance_enabled=false;_play("idle")

func set_world_paused(value:bool)->void:
	paused=value
	_play("idle" if value or state not in [ActivityState.WALKING,ActivityState.DEPARTING] else "run")

func finish_immediately()->void:
	global_position=destination;agent.avoidance_enabled=false;_arrive()

func _physics_process(delta:float)->void:
	if paused or state not in [ActivityState.WALKING,ActivityState.DEPARTING]:return
	if agent.is_navigation_finished():_arrive();return
	var next:=agent.get_next_path_position();var desired:=global_position.direction_to(next)*movement_speed
	_last_direction=SlasherSpriteLibrary.direction_name(desired,_last_direction);_movement_delta=delta;agent.velocity=desired

func _on_safe_velocity(safe_velocity:Vector2)->void:
	if paused or state not in [ActivityState.WALKING,ActivityState.DEPARTING]:return
	if safe_velocity.length_squared()>0.01:
		_last_direction=SlasherSpriteLibrary.direction_name(safe_velocity,_last_direction);_play("run")
	else:_play("idle")
	global_position+=safe_velocity*_movement_delta
	if global_position.distance_to(destination)<=agent.target_desired_distance:_arrive()

func _arrive()->void:
	agent.avoidance_enabled=false;state=int(get_meta("arrival_state",ActivityState.IDLE));_play("idle");destination_reached.emit(self)

func _play(action:String)->void:
	if sprite==null or sprite.sprite_frames==null:return
	var animation:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,action,_last_direction)
	if not animation.is_empty() and sprite.animation!=animation:sprite.play(animation)
