extends Control

const MAP_SIZE := Vector2(148.0, 108.0)
const PADDING := 8.0

var floor_ref: Node2D
var player_ref: Node2D
var door_unlocked: bool = false
var is_boss_floor: bool = false

func _ready() -> void:
	custom_minimum_size = MAP_SIZE + Vector2(PADDING * 2.0, PADDING * 2.0)
	size = custom_minimum_size

func setup(floor_node: Node2D, player_node: Node2D) -> void:
	floor_ref = floor_node
	player_ref = player_node
	queue_redraw()

func set_door_unlocked(unlocked: bool) -> void:
	door_unlocked = unlocked
	queue_redraw()

func set_boss_floor(boss: bool) -> void:
	is_boss_floor = boss
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var inner := Rect2(PADDING, PADDING, MAP_SIZE.x, MAP_SIZE.y)
	draw_rect(inner, Color(0.05, 0.05, 0.1, 0.85))
	draw_rect(inner, Color(0.35, 0.35, 0.45), false, 2.0)

	if not is_instance_valid(floor_ref):
		return

	var floor_width: float = floor_ref.floor_width
	var floor_height: float = floor_ref.floor_height
	var scale := minf(
		(MAP_SIZE.x - 12.0) / floor_width,
		(MAP_SIZE.y - 12.0) / floor_height
	)
	var origin := inner.position + inner.size / 2.0

	# Door marker
	var door_dir: Vector2 = floor_ref.get_door_direction()
	var door_pos := door_dir * Vector2(floor_width / 2.0 - 8.0, floor_height / 2.0 - 8.0) * scale
	var door_color := Color(0.2, 0.9, 0.4) if door_unlocked else Color(0.45, 0.45, 0.5)
	draw_circle(origin + door_pos, 4.0, door_color)

	# Enemies
	var enemies_node: Node2D = floor_ref.get_node("Enemies")
	for enemy in enemies_node.get_children():
		if is_instance_valid(enemy):
			var local_pos: Vector2 = enemy.position * scale
			var radius := 4.0 if enemy.is_in_group("bosses") else 2.5
			var color := Color(0.75, 0.2, 0.9) if enemy.is_in_group("bosses") else Color(0.95, 0.25, 0.3)
			draw_circle(origin + local_pos, radius, color)

	# Player
	if is_instance_valid(player_ref):
		var player_pos := floor_ref.to_local(player_ref.global_position) * scale
		draw_circle(origin + player_pos, 3.5, Color(0.3, 0.75, 1.0))

	# Label
	var title := "BOSS" if is_boss_floor else "MAP"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(PADDING + 4.0, PADDING + 12.0),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		Color(0.85, 0.85, 0.9)
	)
