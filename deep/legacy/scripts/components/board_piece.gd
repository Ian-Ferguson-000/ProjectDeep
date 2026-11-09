extends Node2D
class_name BoardPiece

enum PieceShape { CIRCLE, SQUARE }

@export var label_text: String = "?":
	set(value):
		label_text = value
		_apply_visuals()
@export var fill_color: Color = Color(0.4, 0.4, 0.4):
	set(value):
		fill_color = value
		_apply_visuals()
@export var outline_color: Color = Color(0.96, 0.90, 0.70):
	set(value):
		outline_color = value
		_apply_visuals()
@export var label_color: Color = Color.WHITE:
	set(value):
		label_color = value
		_apply_visuals()
@export var radius: float = 18.0:
	set(value):
		radius = value
		_apply_visuals()
@export var size: Vector2 = Vector2(36, 36):
	set(value):
		size = value
		_apply_visuals()
@export_enum("Circle", "Square") var shape: int = PieceShape.CIRCLE:
	set(value):
		shape = value
		_apply_visuals()
@export var sprite_texture: Texture2D:
	set(value):
		sprite_texture = value
		_apply_visuals()
@export var sprite_region_enabled: bool = false:
	set(value):
		sprite_region_enabled = value
		_apply_visuals()
@export var sprite_region: Rect2 = Rect2(0, 0, 96, 80):
	set(value):
		sprite_region = value
		_apply_visuals()
@export var sprite_scale: Vector2 = Vector2.ONE:
	set(value):
		sprite_scale = value
		_apply_visuals()
@export var show_label: bool = true:
	set(value):
		show_label = value
		_apply_visuals()
@export var show_panel: bool = true:
	set(value):
		show_panel = value
		_apply_visuals()

@onready var panel: Panel = $Panel
@onready var sprite: Sprite2D = $Sprite
@onready var label: Label = $Label

func _ready() -> void:
	_apply_visuals()

func configure(text: String, color: Color, piece_shape: int = PieceShape.CIRCLE) -> void:
	label_text = text
	fill_color = color
	shape = piece_shape
	_apply_visuals()

func _apply_visuals() -> void:
	if not is_inside_tree() or panel == null or sprite == null or label == null:
		return

	var visual_size := size
	if shape == PieceShape.CIRCLE:
		visual_size = Vector2(radius * 2.0, radius * 2.0)

	panel.position = -visual_size * 0.5
	panel.size = visual_size
	panel.visible = show_panel

	sprite.texture = sprite_texture
	sprite.visible = sprite_texture != null
	sprite.region_enabled = sprite_region_enabled
	sprite.region_rect = sprite_region
	sprite.scale = sprite_scale

	label.position = panel.position
	label.size = visual_size
	label.text = label_text
	label.visible = show_label
	label.add_theme_color_override("font_color", label_color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = outline_color
	style.set_border_width_all(2)
	var corner := int(visual_size.x * 0.5) if shape == PieceShape.CIRCLE else 5
	style.set_corner_radius_all(corner)
	panel.add_theme_stylebox_override("panel", style)
