extends SceneTree

const TAVERN:=preload("res://scenes/tavern/Tavern.tscn")

func _initialize()->void:call_deferred("_capture")

func _capture()->void:
	for size in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		var error:=await _capture_size(size)
		if error!=OK:
			push_error("Could not save living tavern capture at %s: %s"%[size,error])
			quit(1)
			return
	quit(0)

func _capture_size(size:Vector2i)->Error:
	root.size=size
	var state:=RunState.new()
	state.campaign.apply_post_tutorial_state("victory")
	state.campaign.last_presented_wave_id=state.campaign.candidate_wave_id
	state.campaign.tavern_phase=CampaignState.TAVERN_OPEN
	state.set_class("warrior")
	var tavern:=TAVERN.instantiate()
	var gear_list:Array[GearData]=[]
	tavern.setup(null,state,gear_list,"")
	root.add_child(tavern)
	await process_frame
	await process_frame
	await process_frame
	var file_name:="tavern_living_%dx%d.png"%[size.x,size.y]
	var error:=root.get_texture().get_image().save_png("user://"+file_name)
	print("Living tavern capture: ",ProjectSettings.globalize_path("user://"+file_name))
	tavern.free()
	await process_frame
	return error
