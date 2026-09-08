extends SceneTree

const GENERATOR_SCENE:=preload("res://scenes/slasher/tools/SlasherWallGenerator.tscn")
const LAB_SCENE:=preload("res://scenes/slasher/tools/WallGenerationLab.tscn")

func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[]
	var generator:SlasherWallGenerator=GENERATOR_SCENE.instantiate();root.add_child(generator);var cells:Dictionary={}
	for y in 4:
		for x in 6:cells[Vector2i(x,y)]=true
	generator.generate(cells,[],Vector2(96,96));var report:=generator.generation_report();_expect(int(report.boundary_edges)==20 and int(report.contours)==1,"Standalone generator scene produced incorrect topology",failures);_expect(report.has("mask_counts") and report.has("unsupported_masks") and report.has("composite_masks"),"Standalone generator omits mask diagnostics",failures);_expect(generator.has_node("GeneratedVisuals") and generator.has_node("GeneratedCollisions"),"Standalone generator did not own visuals and collision",failures);_expect(not generator.find_children("DeepFacade_*","Node2D",true,false).is_empty(),"Authored wall defaults omitted south-facing facades",failures)
	generator.generate_deep_facades=false;generator.rebuild();_expect(generator.find_children("DeepFacade_*","Node2D",true,false).is_empty(),"Facade review toggle did not rebuild the generator",failures);generator.queue_free();await process_frame
	var lab=LAB_SCENE.instantiate();lab.show_authored_reference=false;lab.start_with_deep_facades=true;root.add_child(lab);await process_frame;await process_frame;_expect(lab.wall_generator!=null and lab.cells.size()>100,"Wall Generation Lab did not build its complex fixture",failures);_expect(lab.report_label!=null and lab.report_label.text.contains("WALL GENERATION LAB") and lab.report_label.text.contains("GENERATED"),"Wall Generation Lab lacks comparison controls",failures)
	var lab_report:Dictionary=lab.wall_generator.generation_report()
	for mask in range(1,16):_expect(Dictionary(lab_report.mask_counts).has(mask),"Wall Generation Lab does not exercise mask %d"%mask,failures)
	if DisplayServer.get_name()!="headless":root.get_texture().get_image().save_png("res://build/wall_generation_lab_1280x720.png")
	lab.queue_free();await process_frame
	if failures.is_empty():print("WALL_GENERATOR_SCENE_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
