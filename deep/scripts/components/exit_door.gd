extends BoardPiece
class_name ExitDoor

signal door_entered(door: ExitDoor)
signal door_unlocked

@export var locked_color: Color = Color(0.35, 0.35, 0.40)
@export var unlocked_color: Color = Color(0.25, 0.62, 0.36)

var is_unlocked: bool = true
var grid_position := Vector2i.ZERO

func _ready() -> void:
	super()
	shape = PieceShape.SQUARE
	label_text = "E"
	set_locked(false)

func setup(tile: Vector2i, unlocked: bool = true) -> void:
	grid_position = tile
	set_locked(not unlocked)

func set_locked(locked: bool) -> void:
	is_unlocked = not locked
	fill_color = unlocked_color if is_unlocked else locked_color
	modulate.a = 1.0 if is_unlocked else 0.55
	if is_unlocked:
		door_unlocked.emit()

func unlock() -> void:
	if is_unlocked:
		return
	set_locked(false)

func enter() -> void:
	if is_unlocked:
		door_entered.emit(self)
