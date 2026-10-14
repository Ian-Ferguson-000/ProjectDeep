extends Node2D

const POPUP := preload("res://scripts/slasher/training_damage_popup.gd")
const MAX_PER_TARGET := 6
var target_popups: Dictionary = {}
var popup_counts: Dictionary = {}

## Keep feedback beside targets, rather than on them, so lethal hits remain visible.
static func spawn(target: Node2D, amount: int, kind: String = "physical", source: String = "", critical: bool = false) -> void:
	if amount <= 0 or not is_instance_valid(target) or not target.is_inside_tree(): return
	var parent := target.get_parent()
	var layer := parent.get_node_or_null("DamagePopups")
	if layer == null:
		layer = load("res://scripts/slasher/slasher_damage_popups.gd").new()
		layer.name = "DamagePopups"
		layer.z_index = 80
		parent.add_child(layer)
	layer._show(target, amount, kind, source, critical)

func _show(target: Node2D, amount: int, kind: String, source: String, critical: bool) -> void:
	var target_id := target.get_instance_id()
	var active := _live_popups(target_id)
	while active.size() >= MAX_PER_TARGET:
		var oldest: Node = active.pop_front().get_ref()
		if is_instance_valid(oldest): oldest.queue_free()
	var ordinal := int(popup_counts.get(target_id, 0))
	var lane := ordinal % 3
	popup_counts[target_id] = ordinal + 1
	var popup := POPUP.new()
	popup.setup(amount, kind, source, critical, lane)
	add_child(popup)
	popup.global_position = target.global_position + Vector2((lane - 1) * 60, -66)
	active.append(weakref(popup))
	target_popups[target_id] = active

func _live_popups(target_id: int) -> Array:
	var active: Array = target_popups.get(target_id, [])
	return active.filter(func(reference: WeakRef):
		var popup: Node = reference.get_ref()
		return is_instance_valid(popup) and not popup.is_queued_for_deletion())

func _process(_delta: float) -> void:
	for target_id: int in target_popups.keys():
		var active := _live_popups(target_id)
		if active.is_empty():
			target_popups.erase(target_id)
			popup_counts.erase(target_id)
		else:
			target_popups[target_id] = active
