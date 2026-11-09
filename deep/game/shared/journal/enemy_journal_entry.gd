class_name EnemyJournalEntry
extends Resource

@export var enemy_id := "enemy"
@export var display_name := "Unknown Enemy"
@export_enum("Standard","Special","Boss") var category := "Standard"
@export var portrait: Texture2D
@export_multiline var description := ""
@export var habitat := "Unknown"
@export_multiline var behavior_summary := ""
@export var max_health := 1
@export var defense := 0
@export var attack_damage := 0
@export var damage_type := "neutral"
@export var vulnerabilities: Dictionary = {}

