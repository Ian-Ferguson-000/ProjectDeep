extends SceneTree
## Trees near the player, or between the player and the camera, turn see-through.
const FOREST := preload("res://scenes/forest3d/Forest3D.tscn")
class MemoryCampaign extends CampaignState:
	func save_atomic() -> bool: return true
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func expect(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func see_through(mesh: MeshInstance3D) -> float:
	return 0.0 if mesh.material_override == null else 1.0-float(mesh.material_override.albedo_color.a)
func _run() -> void:
	root.size = Vector2i(1600,1000)
	var scene := FOREST.instantiate()
	scene._ensure_designer_controls()
	var state := RunState.new()
	state.campaign = MemoryCampaign.new()
	state.requested_seed = 246810
	state.start_new_run(GearData.create("tree_fade_test","Tree Fade",3,false,0,"","","warrior"),"forest")
	state.starter_reward_claimed = true
	scene.run_state = state
	root.add_child(scene)
	for i in 8: await process_frame
	var w: Node3D = scene.world_3d
	var trees: Array = w.art.fading_trees
	expect(trees.size() > 3,"Forest trees are not tracked for fading")
	var record: Dictionary = trees[0]
	var mesh: MeshInstance3D = record.meshes[0]
	var look: Vector3 = w.camera.global_position-w.focus
	# Player just north of the tree (the camera looks from the south-east): it fades.
	var spot: Vector3 = record.root.global_position + Vector3(-0.3,0,-0.8)
	for i in 10: w.art.fade_trees(spot,look,0.1)
	expect(see_through(mesh) > 0.5,"Tree next to the player did not fade (%.2f)" % see_through(mesh))
	# Player a few cells behind the tree, out of the near radius: still fades.
	var behind: Vector3 = record.root.global_position - Vector3(look.x,0,look.z).normalized()*4.0
	for i in 10: w.art.fade_trees(behind,look,0.1)
	expect(see_through(mesh) > 0.5,"Tree in front of the player did not fade")
	var far_count := 0
	for other in trees:
		var gap: float = Vector2(other.root.global_position.x-spot.x,other.root.global_position.z-spot.z).length()
		if gap > 9.0 and see_through(other.meshes[0]) == 0.0: far_count += 1
	expect(far_count > 0,"Trees far from the player faded too")
	# Player in front of the tree (between it and the camera): stays solid.
	var front: Vector3 = record.root.global_position + Vector3(look.x,0,look.z).normalized()*4.0
	for i in 10: w.art.fade_trees(front,look,0.1)
	expect(see_through(mesh) < 0.05,"Tree behind the player faded")
	# The live scene runs the fade every frame.
	for i in 5: await process_frame
	expect(w.art.fading_trees.size() == trees.size(),"Live trees were dropped")
	# Doorways are clear of trees.
	for direction in Dictionary(scene.layout.doors):
		var door: Vector2 = Vector2(Vector2i(scene.layout.doors[direction]))
		for other in trees:
			var at: Vector3 = other.root.global_position
			if other.root.name == "Tree":
				expect(Vector2(at.x-0.5,at.z-0.5).distance_to(door) > 2.6,"A tree stands in the %s doorway" % direction)
	# Swapping scenes the way Main does (new one in, old one queue_free'd) must
	# not bring the 2D art back over the new 3D room.
	var hidden: int = w.HIDDEN_LAYER
	var next := FOREST.instantiate()
	next._ensure_designer_controls()
	next.run_state = state
	root.add_child(next)
	scene.queue_free()
	for i in 6: await process_frame
	expect(root.canvas_cull_mask & hidden == 0,"2D room art shows after a scene swap")
	next.queue_free()
	await process_frame
	if failures.is_empty(): print("TREE_FADE_TEST: PASS")
	quit(1 if not failures.is_empty() else 0)
