@tool
extends Node2D
class_name TavernFloor

@export var floor_size: Vector2i = Vector2i(36, 22)
@export var tile_size: Vector2i = Vector2i(32, 32)
## Top-left tile of the floor style to use. Each style in "Tavern Floor Revised.png"
## is a 4x2 block of tiles; the floor cycles through the whole block so the
## pattern does not repeat every tile.
@export var fill_variant: Vector2i = Vector2i(0, 0)
@export var pattern_size: Vector2i = Vector2i(4, 2)

@onready var layer: TileMapLayer = $TileMapLayer

func _ready() -> void:
	_rebuild_if_empty()

func _rebuild_if_empty() -> void:
	if layer == null or layer.tile_set == null:
		return
	if layer.get_used_cells().is_empty():
		for y in floor_size.y:
			for x in floor_size.x:
				layer.set_cell(Vector2i(x, y), 0, fill_variant + Vector2i(x % pattern_size.x, y % pattern_size.y), 0)

func rebuild_floor() -> void:
	if layer == null:
		return
	layer.clear()
	_rebuild_if_empty()
