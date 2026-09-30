extends SceneTree

const IDS:Array[String]=[
	"ash_rat","balor","blighted_farmhand","briar_guardian","cinder_bomber","crypt_boss",
	"dark_druid","drowned_foreman","ember_crow","feral_wolf","fire_mage","fire_spirit",
	"harvest_wretch","hellcharger","ice_mage","infernal_caster","infernal_legate","last_warmachine",
	"moon_court_huntress","necromancer","poison_ranger","possessed_scarecrow","rift_stalker",
	"skeletal_archer","skeleton","soul_wisp","spore_beast","thornback_boar","unwritten_curator",
	"wolf_charger","wolf_howler","wolf_hunter","wolf_lurker","wolf_vanguard"
]
const CRYPT_IDS:Array[String]=["skeletal_archer","necromancer","soul_wisp","crypt_boss"]
const HELL_IDS:Array[String]=["infernal_caster","rift_stalker","hellcharger","cinder_bomber","fire_spirit","infernal_legate","balor"]
const LOCAL_IDS:Array[String]=["dark_druid","spore_beast"]
var failures:Array[String]=[]

func _init()->void:
	call_deferred("_run")

func _run()->void:
	for enemy_id:String in IDS:_verify_enemy(enemy_id)
	if failures.is_empty():
		print("Verified %d enemy prefabs, frame resources, script families, and padded animation cells."%IDS.size());quit()
	else:
		for failure:String in failures:push_error(failure)
		quit(1)

func _verify_enemy(enemy_id:String)->void:
	var frames_path:="res://assets/enemies/%s/frames.tres"%enemy_id
	var prefab_path:="res://scenes/slasher/enemies/%s.tscn"%enemy_id
	if not ResourceLoader.exists(frames_path):failures.append("Missing frames: "+enemy_id);return
	if not ResourceLoader.exists(prefab_path):failures.append("Missing prefab: "+enemy_id);return
	var prefab:=load(prefab_path) as PackedScene
	if prefab==null:failures.append("Unreadable prefab: "+enemy_id);return
	var enemy:=prefab.instantiate()
	if not enemy is SlasherEnemy:failures.append("Prefab root is not SlasherEnemy: "+enemy_id);enemy.free();return
	if enemy_id in CRYPT_IDS and not enemy is SlasherCryptEnemy:failures.append("Wrong crypt script: "+enemy_id)
	if enemy_id in HELL_IDS and not enemy is SlasherHellEnemy:failures.append("Wrong hell script: "+enemy_id)
	var collision:=enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var sprite:=enemy.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if collision==null or collision.shape==null:failures.append("Missing collision shape: "+enemy_id)
	if sprite==null or sprite.sprite_frames==null:failures.append("Missing animated sprite frames: "+enemy_id)
	else:_verify_animations(enemy_id,sprite.sprite_frames,enemy_id not in LOCAL_IDS)
	root.add_child(enemy)
	if (enemy as SlasherEnemy).sprite!=sprite:failures.append("Prefab sprite was replaced during ready: "+enemy_id)
	root.remove_child(enemy)
	enemy.free()
	if enemy_id not in LOCAL_IDS:_verify_padding(enemy_id)

func _verify_animations(enemy_id:String,frames:SpriteFrames,directional:bool)->void:
	for state:String in ["idle","run","attack"]:
		if directional:
			for direction:String in ["down","left","right","up"]:_verify_animation(enemy_id,frames,StringName(state+"_"+direction))
		else:_verify_animation(enemy_id,frames,StringName(state))

func _verify_animation(enemy_id:String,frames:SpriteFrames,animation:StringName)->void:
	if not frames.has_animation(animation):failures.append("Missing %s animation: %s"%[animation,enemy_id]);return
	if frames.get_frame_count(animation)<2:failures.append("Animation has fewer than two frames (%s): %s"%[animation,enemy_id]);return
	for frame_index:int in frames.get_frame_count(animation):
		if frames.get_frame_texture(animation,frame_index)==null:failures.append("Null frame %d in %s: %s"%[frame_index,animation,enemy_id])

func _verify_padding(enemy_id:String)->void:
	var texture:=load("res://assets/enemies/%s/normalized_sheet.png"%enemy_id) as Texture2D
	var image:Image=texture.get_image() if texture!=null else null
	if image==null or image.is_empty():failures.append("Missing normalized atlas: "+enemy_id);return
	var columns:=6 if image.get_width()==576 else 1;var rows:=4 if image.get_height()==320 else 1
	if image.get_width()%columns!=0 or image.get_height()%rows!=0:failures.append("Unexpected atlas dimensions: "+enemy_id);return
	var cell_size:=Vector2i(image.get_width()/columns,image.get_height()/rows)
	for row:int in rows:
		for column:int in columns:
			var origin:=Vector2i(column*cell_size.x,row*cell_size.y)
			for x:int in cell_size.x:
				if image.get_pixelv(origin+Vector2i(x,0)).a>0.05 or image.get_pixelv(origin+Vector2i(x,cell_size.y-1)).a>0.05:failures.append("Vertical clipping risk in cell %d,%d: %s"%[column,row,enemy_id]);return
			for y:int in cell_size.y:
				if image.get_pixelv(origin+Vector2i(0,y)).a>0.05 or image.get_pixelv(origin+Vector2i(cell_size.x-1,y)).a>0.05:failures.append("Horizontal clipping risk in cell %d,%d: %s"%[column,row,enemy_id]);return
