class_name EnemyDefinition
extends Resource

@export_category("Identity")
@export var enemy_id:="enemy"
@export var display_name:="Enemy"
@export var faction:="hostile"
@export_enum("Standard","Special","Boss") var category:="Standard"
@export var profile:EnemyProfile
@export var journal_entry:EnemyJournalEntry
@export_category("Presentation")
@export var sprite_frames:SpriteFrames
@export var sprite_offset:=Vector2(0,-24)
@export var sprite_scale:=Vector2.ONE
@export var collision_radius:=14.0
@export var collision_height:=34.0
@export var idle_animation:="idle"
@export var run_animation:="run"
@export var attack_animation:="attack"
@export_category("Combat")
@export var abilities:Array[EnemyAbility]=[]

