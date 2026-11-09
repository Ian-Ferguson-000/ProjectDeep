extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://game/tavern/3d/TavernRoomPreview.tscn") as PackedScene
	assert(packed != null)
	var preview := packed.instantiate()
	root.add_child(preview)
	await process_frame
	for group_name in ["Floor","RearWall","WestWall","EastWall","FrontWall","CeilingBeams","Bar","Staircase","Hearth","Furniture"]:
		assert(preview.room.find_child(group_name,true,false) != null,"Missing room group: "+group_name)
	var meshes: Array[Node] = preview.room.find_children("*","MeshInstance3D",true,false)
	assert(meshes.size() > 100)
	var bounds := AABB()
	for mesh in meshes:
		assert(mesh.mesh != null)
		bounds = bounds.merge(mesh.global_transform * mesh.get_aabb())
	assert(bounds.size.x > 18.0 and bounds.size.x < 20.0)
	assert(bounds.size.z > 11.0 and bounds.size.z < 13.0)
	assert(bounds.size.y > 3.5 and bounds.size.y < 5.0)
	assert(not preview.room.find_child("FrontWall",true,false).visible)
	preview.cutaway = false
	preview._set_cutaway()
	assert(preview.room.find_child("FrontWall",true,false).visible)
	preview.cutaway = true
	preview._set_cutaway()
	if "--capture" in OS.get_cmdline_user_args():
		root.size=Vector2i(1600,1000)
		await process_frame
		await RenderingServer.frame_post_draw
		var output := "res://build/visual_checks/tavern_3d_godot.png"
		assert(root.get_texture().get_image().save_png(output)==OK)
	print("TAVERN_ROOM_3D_PASSED: ",meshes.size()," mesh instances; bounds ",bounds)
	quit(0)
