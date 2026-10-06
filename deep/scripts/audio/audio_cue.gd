class_name AudioCue
extends RefCounted

# Safe in standalone SceneTree tests as well as the normal autoloaded game.
static func play_from(source:Node,event_id:String,spatial:bool=true)->void:
	if not is_instance_valid(source) or not source.is_inside_tree():return
	var audio:=source.get_node_or_null("/root/Audio")
	if audio==null or String(audio.context).is_empty():return
	var point:Vector2=source.global_position if spatial and source is Node2D else Vector2.INF
	audio.play_event(event_id,point,source.get_instance_id())

static func play_at_from(source:Node,event_id:String,point:Vector2)->void:
	if not is_instance_valid(source) or not source.is_inside_tree():return
	var audio:=source.get_node_or_null("/root/Audio")
	if audio!=null and not String(audio.context).is_empty():audio.play_event(event_id,point,source.get_instance_id())

static func context_from(source:Node,context:String)->void:
	if not is_instance_valid(source) or not source.is_inside_tree():return
	var audio:=source.get_node_or_null("/root/Audio")
	if audio!=null:audio.set_context(context)

static func cast_event(element:String)->String:
	match element:
		"fire","burn","pyromancy":return "cast_fire"
		"ice","cold","cryomancy":return "cast_ice"
		"lightning","electromancy":return "cast_lightning"
		"growth","poison","healer","summoner":return "cast_growth"
		_:return "cast_aether"
