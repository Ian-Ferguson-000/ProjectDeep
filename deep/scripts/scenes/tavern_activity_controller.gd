extends Node
class_name TavernActivityController

signal actor_interaction_requested(actor_kind:String,actor_id:String)
signal departure_finished

const ACTOR_SCENE:=preload("res://scenes/components/TavernActor.tscn")
@export var visible_adventurer_cap:=8
@export var idle_time_min:=2.8
@export var idle_time_max:=6.2

var run_state:RunState
var actors_root:Node2D
var anchors_root:Node2D
var actors:Dictionary={}
var reserved:Dictionary={}
var paused:=false
var departing:=false
var _departure_callback:Callable
var _departure_waiting:Dictionary={}
var _rng:=RandomNumberGenerator.new()

func setup(state:RunState,actor_parent:Node2D,anchor_parent:Node2D)->void:
	run_state=state;actors_root=actor_parent;anchors_root=anchor_parent
	_rng.seed=int(state.campaign.calendar_day)*7919+int(state.campaign.candidate_wave_id)*101
	populate(false)

func populate(enter_candidates:bool)->void:
	clear_population()
	_spawn_merchant("tavern")
	for merchant_id in GameBalance.get_merchants():
		if merchant_id!="tavern" and run_state.is_merchant_recruited(String(merchant_id)):_spawn_merchant(String(merchant_id))
	var count:=0
	for candidate in run_state.campaign.get_candidates():
		if count>=visible_adventurer_cap:break
		_spawn_adventurer("candidate",candidate.id,candidate.adventurer,enter_candidates);count+=1
	var roster:=run_state.campaign.living_roster()
	if not roster.is_empty():
		var offset:=run_state.campaign.calendar_day%roster.size()
		for step in roster.size():
			if count>=visible_adventurer_cap:break
			var member:CharacterRecord=roster[(step+offset)%roster.size()]
			if member.status==CharacterRecord.STATUS_AVAILABLE:_spawn_adventurer("roster",member.id,member,false);count+=1

func populate_from_campaign(state:RunState)->void:
	run_state=state
	populate(false)

func clear_population()->void:
	for child in actors_root.get_children():child.queue_free()
	actors.clear();reserved.clear()

func begin_arrivals()->void:
	populate(true)

func set_paused(value:bool)->void:
	paused=value
	for actor_value in actors.values():
		var actor:=actor_value as TavernActor
		actor.set_world_paused(value)
		actor.process_mode=Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT

func set_modal_paused(value:bool)->void:
	set_paused(value)

func resume_actor(actor_id:String)->void:
	var actor:=actors.get(actor_id) as TavernActor
	if actor!=null:actor.set_interaction_paused(false);_schedule_next(actor)

func begin_departure(party_ids:Array[String],callback:Callable)->void:
	if departing:return
	departing=true;paused=false;_departure_callback=callback;_departure_waiting.clear()
	var entrance:=_anchor("Entrance")
	for index in party_ids.size():
		var id:=party_ids[index];var actor:=actors.get(id) as TavernActor
		if actor==null:
			var member:=run_state.campaign.character(id)
			if member!=null:actor=_spawn_adventurer("roster",id,member,false)
		if actor!=null:
			actor.stand_up();actor.set_meta("departure_index",index);actor.set_meta("departure_phase","gather");actor.set_meta("exit_target",entrance.global_position+Vector2((index-party_ids.size()/2.0)*24.0,index*10.0));_departure_waiting[id]=true
			actor.move_to(entrance.global_position+Vector2((index-party_ids.size()/2.0)*42.0,-135.0-index*8.0),TavernActor.ActivityState.DEPARTING)
	if _departure_waiting.is_empty():_finish_departure();return
	var timer:=get_tree().create_timer(8.0);timer.timeout.connect(_finish_departure)

func fast_forward()->void:
	if not departing:return
	for value in actors.values():
		var actor:=value as TavernActor
		if actor.state==TavernActor.ActivityState.DEPARTING:actor.finish_immediately()
	_finish_departure()

func _finish_departure()->void:
	if not departing:return
	departing=false
	for value in actors.values():
		var actor:=value as TavernActor
		if actor.has_meta("departure_index"):actor.visible=false
	departure_finished.emit()
	var callback:=_departure_callback;_departure_callback=Callable()
	if callback.is_valid():callback.call()

func _spawn_merchant(merchant_id:String)->TavernActor:
	var data:=GameBalance.get_merchant(merchant_id);var anchor:=_anchor("Merchant_%s"%merchant_id)
	if data.is_empty():return null
	if anchor==null:anchor=_claim_anchor(merchant_id,["Merchant","Wait"])
	else:reserved[anchor.get_path()]=merchant_id
	if anchor==null:return null
	var actor:=ACTOR_SCENE.instantiate() as TavernActor;actors_root.add_child(actor);actor.global_position=anchor.global_position
	var frames:=SlasherSpriteLibrary.static_enemy_frames(String(data.get("portrait","")))
	actor.configure("merchant",merchant_id,String(data.get("name",merchant_id.capitalize())),frames,Vector2(0.82,0.82));actor.conversation_id="merchant_default";_register(actor);return actor

func _spawn_adventurer(kind:String,id:String,member:CharacterRecord,entering:bool)->TavernActor:
	var target:=_claim_anchor(id,["Wait","Wander","Seat"])
	var actor:=ACTOR_SCENE.instantiate() as TavernActor;actors_root.add_child(actor);actor.global_position=_anchor("Entrance").global_position if entering else target.global_position
	actor.configure(kind,id,member.display_name,SlasherSpriteLibrary.player_frames(member.class_id),_tavern_actor_scale(member.class_id));actor.conversation_id="candidate_default" if kind=="candidate" else "roster_default";_register(actor)
	if entering:actor.state=TavernActor.ActivityState.ENTERING;actor.set_meta("target_kind",String(target.get_meta("activity_kind","Wait")));actor.move_to(target.global_position)
	elif String(target.get_meta("activity_kind",""))=="Seat":actor.seat_at(target.global_position);_schedule_next(actor)
	else:_schedule_next(actor)
	return actor

func _tavern_actor_scale(class_id:String)->Vector2:
	var tuning:=GameBalance.get_slasher_class_tuning(class_id)
	var source_scale:=float(tuning.get("sprite_scale",1.0))
	# The legacy warrior sheet is 96x80 while the newer class animation boards
	# use much larger cells. Normalize their authored gameplay scale so every
	# tavern visitor occupies the same readable silhouette range.
	return Vector2.ONE*clampf(1.08*source_scale/1.58,0.28,1.08)

func _register(actor:TavernActor)->void:
	actors[actor.actor_id]=actor;actor.interaction_requested.connect(_on_actor_interaction);actor.destination_reached.connect(_on_actor_arrived)

func _on_actor_interaction(kind:String,id:String)->void:
	var actor:=actors.get(id) as TavernActor
	if actor!=null:actor.set_interaction_paused(true)
	actor_interaction_requested.emit(kind,id)

func _on_actor_arrived(actor:TavernActor)->void:
	if departing and actor.has_meta("departure_index"):
		if String(actor.get_meta("departure_phase",""))=="gather":
			actor.set_meta("departure_phase","exit");actor.move_to(Vector2(actor.get_meta("exit_target")),TavernActor.ActivityState.DEPARTING);return
		_departure_waiting.erase(actor.actor_id);var tween:=actor.create_tween();tween.tween_property(actor,"modulate:a",0.0,0.28)
		if _departure_waiting.is_empty():tween.tween_callback(_finish_departure)
		return
	var target_kind:=String(actor.get_meta("target_kind",""))
	if target_kind=="Seat":actor.seat_at(actor.global_position)
	elif target_kind=="Conversation":actor.state=TavernActor.ActivityState.CHATTING;actor.show_emote(["💬","🍻","!"][_rng.randi_range(0,2)])
	_schedule_next(actor)

func _schedule_next(actor:TavernActor)->void:
	if paused or departing or not is_instance_valid(actor):return
	var actor_ref:WeakRef=weakref(actor);var delay:float=_rng.randf_range(idle_time_min,idle_time_max);var timer:SceneTreeTimer=get_tree().create_timer(delay)
	timer.timeout.connect(func():
		var live_actor:=actor_ref.get_ref() as TavernActor
		if paused or departing or live_actor==null or live_actor.state==TavernActor.ActivityState.INTERACTING:return
		live_actor.stand_up();var anchor:=_claim_anchor(live_actor.actor_id,["Seat","Conversation","Wander","Wait"]);live_actor.set_meta("target_kind",String(anchor.get_meta("activity_kind","Wander")));live_actor.move_to(anchor.global_position))

func _claim_anchor(actor_id:String,kinds:Array[String])->Marker2D:
	for path in reserved.keys():
		if String(reserved[path])==actor_id:reserved.erase(path)
	var choices:Array[Marker2D]=[]
	for child_value in anchors_root.get_parent().find_children("*","Marker2D",true,false):
		var child:=child_value as Marker2D
		if child!=null and String(child.get_meta("activity_kind","")) in kinds and not reserved.has(child.get_path()):choices.append(child)
	if choices.is_empty():return _anchor("Entrance")
	var selected:=choices[_rng.randi_range(0,choices.size()-1)];reserved[selected.get_path()]=actor_id;return selected

func _anchor(name_value:String)->Marker2D:
	return anchors_root.find_child(name_value,true,false) as Marker2D
