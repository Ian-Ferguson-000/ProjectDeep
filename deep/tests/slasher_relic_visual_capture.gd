extends SceneTree

const RELIC_MODAL:=preload("res://scripts/slasher/slasher_relic_choice_modal.gd")

func _initialize()->void:
	call_deferred("_capture")

func _capture()->void:
	var backdrop:=ColorRect.new();backdrop.color=Color("#17342b");backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(backdrop)
	var state:=RunState.new();state.pending_chest_choices=["charred_horseshoe","harvesters_gloves","cinderheart_locket"]
	var modal:SlasherRelicChoiceModal=RELIC_MODAL.new();root.add_child(modal);await process_frame
	modal.open(state,state.pending_chest_choices,true);await create_timer(0.22).timeout;await process_frame
	var failures:Array[String]=[]
	if modal.choice_buttons.size()!=3:failures.append("Relic picker did not render three composed choices")
	for button:Button in modal.choice_buttons:
		if button.size.x<310 or button.size.y<465:failures.append("Relic card collapsed below its readable minimum")
		if button.get_child_count()==0:failures.append("Relic card content hierarchy is missing")
		var background:=button.find_child("CardBackground",true,false) as TextureRect
		if background==null or background.texture==null:failures.append("Supplied card1.png background is missing from a relic choice")
	if not modal.choice_buttons[0].has_focus():failures.append("First relic did not receive default keyboard focus")
	if DisplayServer.get_name()!="headless":
		var viewport_texture:=root.get_texture()
		if viewport_texture==null:failures.append("Rendered viewport texture is unavailable")
		else:
			var image:=viewport_texture.get_image()
			if image!=null:
				var error:=image.save_png("res://build/slasher_relic_choices_1280x720.png")
				if error!=OK:failures.append("Could not save relic picker visual baseline")
	if failures.is_empty():print("SLASHER_RELIC_VISUAL_CAPTURE_PASSED");quit(0)
	else:
		for failure:String in failures:push_error(failure)
		quit(1)
