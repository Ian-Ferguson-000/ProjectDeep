extends Node
signal map_changed(map_id: String)
signal transition_started
signal transition_finished
var transitioning := false
var _fade: ColorRect

## Records the next spawn and emits a map request. Current vertical slice has no listener that swaps maps yet.
func change_map(map_id: String, new_spawn_id := "default") -> void:
	GameState.spawn_id = new_spawn_id; map_changed.emit(map_id)

## Guards duplicate transitions, initializes GameState, and transitions to gameplay.
func start_game(mode: GameState.GameMode) -> void:
	if transitioning: return
	GameState.start_new_game(mode)
	await _transition_to("res://scenes/Main.tscn")

## Guards duplicate transitions and returns to the start menu. No current gameplay button invokes it.
func return_to_menu() -> void:
	if transitioning: return
	await _transition_to("res://scenes/StartMenu.tscn")

## Blocks input, fades out, changes scenes, fades in, restores input, and emits lifecycle signals. On load
## failure it logs an error and clears the transition lock.
func _transition_to(scene_path: String) -> void:
	transitioning = true; transition_started.emit()
	_ensure_fade()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	await tween.finished
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Unable to load scene: %s" % scene_path)
		transitioning=false; return
	await get_tree().process_frame
	var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(_fade, "color:a", 0.0, 0.25)
	await reveal.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transitioning=false; transition_finished.emit()

## Lazily creates the persistent high-layer full-screen fade rectangle. Safe to call repeatedly.
func _ensure_fade() -> void:
	if is_instance_valid(_fade): return
	var canvas:=CanvasLayer.new(); canvas.layer=1000; canvas.process_mode=Node.PROCESS_MODE_ALWAYS; add_child(canvas)
	_fade=ColorRect.new(); _fade.color=Color(0.04,0.025,0.02,0.0); _fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _fade.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.add_child(_fade)
