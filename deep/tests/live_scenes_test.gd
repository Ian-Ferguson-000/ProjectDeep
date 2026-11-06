extends SceneTree
## What the player sees is 3D: the tavern, and every dungeon that isn't Coming
## Soon, load 3D scenes. The 2D scenes stay in the project only as references and
## as the base the 3D ones are built on (docs/Scenes.md). The 2D testing ground
## is a dev tool and can't be reached in a normal build.
const MAIN := preload("res://scripts/main.gd")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _is_3d(scene: PackedScene) -> bool:
	var node := scene.instantiate()
	var path := String(node.get_script().resource_path) if node.get_script() != null else ""
	node.free()
	return path.contains("3d/")

func _run() -> void:
	expect(_is_3d(MAIN.TavernScene),"The tavern isn't the 3D one")
	var dungeons: Dictionary = GameBalance.get_dungeons()
	var open := 0
	for id in dungeons:
		var dungeon: Dictionary = dungeons[id]
		if bool(dungeon.get("coming_soon",false)): continue
		open += 1
		var scene := MAIN.dungeon_scene(String(dungeon.get("runtime",id)))
		expect(scene != null,"%s has no scene" % id)
		if scene != null: expect(_is_3d(scene),"%s is open but still loads a 2D scene" % id)
	expect(open >= 2,"Expected the forest and crypt to be open")
	expect(not GameSettingsService.dev_mode_available,"Dev tools (and the 2D testing ground) are reachable in a normal build")
	if failures.is_empty(): print("LIVE_SCENES_TESTS_PASSED"); quit(0)
	else:
		for f in failures: printerr("FAIL: "+f)
		quit(1)
