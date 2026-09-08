extends SceneTree

const LAB:=preload("res://scenes/slasher/tools/WallGenerationLab.tscn")

func _initialize()->void:call_deferred("_run")
func _run()->void:
	var lab=LAB.instantiate();lab.show_authored_reference=false;lab.start_with_deep_facades=true;root.add_child(lab);await process_frame;await process_frame
	var reference:TileMapLayer=lab.get_node("TileMapLayer");var visuals:Node=lab.wall_generator.get_node("GeneratedVisuals");var compared:=0;var matched:=0;var missing:=0;var wrong:=0;var core_compared:=0;var core_matched:=0;var core_missing:=0;var core_wrong:=0;var bend_corrections:=0;var coverage_corrections:=0;var inset_corrections:=0;var examples:Array[String]=[];var missing_examples:Array[String]=[]
	for node in visuals.find_children("*","Sprite2D",true,false):
		var sprite:=node as Sprite2D
		if not sprite.texture is AtlasTexture:continue
		var map_cell:=reference.local_to_map(reference.to_local(sprite.global_position));var expected:=reference.get_cell_atlas_coords(map_cell);var region:Rect2=(sprite.texture as AtlasTexture).region;var actual:=Vector2i(region.position/16.0);compared+=1
		var expected_family:=_family(expected);var actual_family:=_family(actual);var core:=map_cell.y<70
		if core:core_compared+=1
		if expected==Vector2i(-1,-1):
			missing+=1
			# The authored comparison layer predates facade coverage beneath a left return.
			# Permit only the newly generated masonry rows; every other extra remains a failure.
			var intentional_inset:=core and sprite.get_parent()!=null and bool(sprite.get_parent().get_meta("inset_boundary",false))
			var intentional_coverage:=core and actual.y in [7,8,9] and actual.x in [2,3,4,5,6,7]
			if intentional_inset:inset_corrections+=1
			elif intentional_coverage:coverage_corrections+=1
			elif core:core_missing+=1
			if core and missing_examples.size()<30:missing_examples.append("%s generated %s (%s)"%[map_cell,actual,sprite.name])
		elif expected_family==actual_family:
			matched+=1
			if core:core_matched+=1
		else:
			wrong+=1
			# The x=6..9 bend strip is the corrected authored join between the
			# four-tile overhang and its descending facade.
			var intentional_bend:=core and sprite.name.begins_with("RightBend") and actual.x in [6,7,8,9] and actual.y in [12,13,14,15]
			var intentional_inset:=core and sprite.get_parent()!=null and bool(sprite.get_parent().get_meta("inset_boundary",false))
			if intentional_inset:inset_corrections+=1
			elif intentional_bend:bend_corrections+=1
			elif core:core_wrong+=1
			if core and examples.size()<40:examples.append("%s expected %s got %s (%s)"%[map_cell,expected,actual,sprite.name])
	for example in examples:print(example)
	for example in missing_examples:print(example)
	print("CORE PARITY compared=",core_compared," matched=",core_matched," missing=",core_missing," wrong=",core_wrong," corrected_coverage=",coverage_corrections," corrected_bends=",bend_corrections," inset_pieces=",inset_corrections)
	lab.free()
	# The paired core returns contribute 32 corrected pieces per side. Requiring
	# both sets prevents a future regression back to one-sided bend handling.
	if core_compared>0 and core_missing==0 and core_wrong==0 and bend_corrections>=64 and inset_corrections>0:print("WALL_REFERENCE_PARITY_TESTS_PASSED");quit(0)
	else:push_error("Generated wall grammar diverges from the authored core fixture.");quit(1)

func _family(atlas:Vector2i)->String:
	if atlas.y==2:
		if atlas.x==2:return "north_west"
		if atlas.x==7:return "north_east"
		if atlas.x in [3,4,5,6]:return "north"
	if atlas.y in [3,4,5]:
		if atlas.x==2:return "west"
		if atlas.x==7:return "east"
	if atlas.y==6:
		if atlas.x==2:return "south_west"
		if atlas.x==7:return "south_east"
		if atlas.x in [3,4,5,6]:return "south"
	if atlas.y in [7,8,9] and atlas.x in [2,3,4,5,6,7]:return "facade_%d"%atlas.y
	return "special_%d_%d"%[atlas.x,atlas.y]
