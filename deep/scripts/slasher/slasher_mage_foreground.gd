extends Node2D

var kit: Node2D

func _draw() -> void:
	if is_instance_valid(kit):kit.draw_foreground(self)
