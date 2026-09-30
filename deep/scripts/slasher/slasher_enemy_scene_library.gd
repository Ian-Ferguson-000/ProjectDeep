extends RefCounted
class_name SlasherEnemySceneLibrary

const PREFAB_ROOT:="res://scenes/slasher/enemies/"
const BASE_SCRIPT:=preload("res://scripts/slasher/slasher_enemy.gd")
const CRYPT_SCRIPT:=preload("res://scripts/slasher/slasher_crypt_enemy.gd")
const HELL_SCRIPT:=preload("res://scripts/slasher/slasher_hell_enemy.gd")
const CRYPT_IDS:=["skeletal_archer","necromancer","soul_wisp","crypt_boss"]
const HELL_IDS:=["infernal_caster","rift_stalker","hellcharger","cinder_bomber","fire_spirit","infernal_legate","balor"]

static func create(visual_id:String)->SlasherEnemy:
	var prefab_path:=PREFAB_ROOT+visual_id+".tscn"
	if ResourceLoader.exists(prefab_path):
		var prefab:=load(prefab_path) as PackedScene
		if prefab!=null:
			var instance:=prefab.instantiate()
			if instance is SlasherEnemy:return instance as SlasherEnemy
			instance.free()
	push_warning("Missing enemy prefab for '%s'; using a runtime fallback."%visual_id)
	if visual_id in HELL_IDS:return HELL_SCRIPT.new() as SlasherEnemy
	if visual_id in CRYPT_IDS:return CRYPT_SCRIPT.new() as SlasherEnemy
	return BASE_SCRIPT.new() as SlasherEnemy

static func warm(visual_id:String)->void:
	var prefab_path:=PREFAB_ROOT+visual_id+".tscn"
	if ResourceLoader.exists(prefab_path):ResourceLoader.load(prefab_path)
