extends RefCounted
class_name MapPlaytest

## F6 on a room scene: starts a solo forest run where the first room is that
## map (using its first role, so a combat room has enemies). Walk through the
## doors to reach normal rooms.

const FOREST_SCENE := "res://scenes/slasher/SlasherForest.tscn"

static var room_path := ""

static func start(tree: SceneTree, path: String) -> void:
	room_path = path
	var state := RunState.new()
	state.set_class("warrior")
	state.start_new_run(HearthCatalog.gear("sword_shield"),"forest")
	var forest = load(FOREST_SCENE).instantiate()
	forest._ensure_designer_controls()
	forest.run_state = state
	var previous := tree.current_scene
	tree.root.add_child(forest)
	tree.current_scene = forest
	if previous != null: previous.queue_free()

static func active() -> bool:
	return not room_path.is_empty()

## The template for the room being tested.
static func template() -> Dictionary:
	if room_path.is_empty(): return {}
	var scene := load(room_path) as PackedScene
	if scene == null: return {}
	var node := scene.instantiate()
	var result: Dictionary = MapLibrary.to_template(node,room_path) if node is MapRoom else {}
	node.free()
	return result
