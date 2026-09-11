extends CharacterBody2D
class_name TavernKeeperController

signal interaction_requested(target: Node)
signal possession_changed(possessed: bool)
signal prompt_changed(text: String)

@export var movement_speed := 220.0
@export var interaction_radius := 82.0
var possessed := true
var input_enabled := true
var facing := "down"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("tavern_keeper")
	possess_keeper()

func possess_keeper() -> void:
	possessed = true
	input_enabled = true
	possessing_changed_signal()

func release_keeper() -> void:
	possessed = false
	input_enabled = false
	velocity = Vector2.ZERO
	possessing_changed_signal()

func is_keeper_possessed() -> bool:
	return possessed

func set_modal_paused(value: bool) -> void:
	input_enabled = not value and possessed
	if value:
		velocity = Vector2.ZERO

func move_input() -> Vector2:
	if not input_enabled:
		return Vector2.ZERO
	var actions := ["move_left", "move_right", "move_up", "move_down"]
	if actions.any(func(action: String): return not InputMap.has_action(action)):
		return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func nearest_interactable() -> Node:
	var nearest: Node = null
	var best := interaction_radius
	for candidate in get_tree().get_nodes_in_group("tavern_interactable"):
		if candidate == self or not is_instance_valid(candidate):
			continue
		if candidate is CanvasItem and not candidate.visible:
			continue
		var distance := global_position.distance_to((candidate as Node2D).global_position)
		if distance < best:
			best = distance
			nearest = candidate
	return nearest

func interact_nearby() -> void:
	var target := nearest_interactable()
	if target == null:
		return
	get_viewport().set_input_as_handled()
	interaction_requested.emit(target)

func _physics_process(_delta: float) -> void:
	if not possessed:
		return
	var input := move_input()
	velocity = input * movement_speed
	move_and_slide()
	if input.length_squared() > 0.01:
		if absf(input.x) > absf(input.y):
			facing = "right" if input.x > 0.0 else "left"
		else:
			facing = "down" if input.y > 0.0 else "up"
		sprite.play("run_" + facing)
	else:
		sprite.play("idle_" + facing)
	var target := nearest_interactable()
	prompt_changed.emit(target.prompt() if target != null and target.has_method("prompt") else "")
	if InputMap.has_action("interact") and Input.is_action_just_pressed("interact"):
		interact_nearby()

func possessing_changed_signal() -> void:
	possession_changed.emit(possessed)
