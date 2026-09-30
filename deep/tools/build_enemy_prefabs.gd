extends SceneTree

const BASE_SCRIPT:="res://scripts/slasher/slasher_enemy.gd"
const CRYPT_SCRIPT:="res://scripts/slasher/slasher_crypt_enemy.gd"
const HELL_SCRIPT:="res://scripts/slasher/slasher_hell_enemy.gd"
const CRYPT_IDS:=["skeletal_archer","necromancer","soul_wisp","crypt_boss"]
const HELL_IDS:=["infernal_caster","rift_stalker","hellcharger","cinder_bomber","fire_spirit","infernal_legate","balor"]
const IDS:=[
	"ash_rat","balor","blighted_farmhand","briar_guardian","cinder_bomber","crypt_boss",
	"dark_druid","drowned_foreman","ember_crow","feral_wolf","fire_mage","fire_spirit",
	"harvest_wretch","hellcharger","ice_mage","infernal_caster","infernal_legate","last_warmachine",
	"moon_court_huntress","necromancer","poison_ranger","possessed_scarecrow","rift_stalker",
	"skeletal_archer","skeleton","soul_wisp","spore_beast","thornback_boar","unwritten_curator",
	"wolf_charger","wolf_howler","wolf_hunter","wolf_lurker","wolf_vanguard"
]

func _init()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/slasher/enemies"))
	for enemy_id:String in IDS:_build_prefab(enemy_id)
	quit()

func _build_prefab(enemy_id:String)->void:
	var script_path:=HELL_SCRIPT if enemy_id in HELL_IDS else (CRYPT_SCRIPT if enemy_id in CRYPT_IDS else BASE_SCRIPT)
	var enemy:=CharacterBody2D.new();enemy.name=enemy_id.to_pascal_case();enemy.set_script(load(script_path))
	var collision:=CollisionShape2D.new();collision.name="CollisionShape2D";var circle:=CircleShape2D.new();circle.radius=14.0;collision.shape=circle;enemy.add_child(collision);collision.owner=enemy
	var sprite:=AnimatedSprite2D.new();sprite.name="AnimatedSprite2D";sprite.sprite_frames=load("res://assets/enemies/%s/frames.tres"%enemy_id);enemy.add_child(sprite);sprite.owner=enemy
	var packed:=PackedScene.new();var error:=packed.pack(enemy)
	if error==OK:error=ResourceSaver.save(packed,"res://scenes/slasher/enemies/%s.tscn"%enemy_id)
	if error!=OK:push_error("Failed to build enemy prefab %s: %s"%[enemy_id,error_string(error)])
	enemy.free()
