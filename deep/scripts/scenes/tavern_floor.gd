@tool
extends Node2D
class_name TavernFloor

@export var floor_size: Vector2i = Vector2i(36, 22)
@export var tile_size: Vector2i = Vector2i(32, 32)
@export var fill_variant: Vector2i = Vector2i(0, 0)

@onready var layer: TileMapLayer = $TileMapLayer

func _ready() -> void:
	_rebuild_if_empty()

func _rebuild_if_empty() -> void:
	if layer == null or layer.tile_set == null:
		return
	if layer.get_used_cells().is_empty():
		for y in floor_size.y:
			for x in floor_size.x:
				layer.set_cell(Vector2i(x, y), 0, fill_variant, 0)

func rebuild_floor() -> void:
	if layer == null:
		return
	layer.clear()
	_rebuild_if_empty()
