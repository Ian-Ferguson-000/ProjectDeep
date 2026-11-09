extends CanvasLayer
## Debug-only performance overlay. Press F3 during play to show or hide it.

const SAMPLE_WINDOW_SECONDS:=1.0

var _elapsed:=0.0
var _frame_count:=0
var _window_frame_ms:=0.0
var _window_max_frame_ms:=0.0
var _label:Label
var _panel:PanelContainer
var _last_nav_queries:=0
var _last_flow_fields:=0
var _last_astar_searches:=0

func _ready()->void:
	if not OS.is_debug_build():set_process(false);return
	layer=100
	_panel=PanelContainer.new();_panel.name="PerformancePanel";_panel.position=Vector2(12,12);_panel.custom_minimum_size=Vector2(270,0);_panel.visible=false;_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new();style.bg_color=Color(0.015,0.025,0.035,0.88);style.border_color=Color(0.35,0.72,0.72,0.9);style.set_border_width_all(1);style.set_corner_radius_all(5);style.set_content_margin_all(9);_panel.add_theme_stylebox_override("panel",style);add_child(_panel)
	_label=Label.new();_label.name="Stats";_label.add_theme_font_size_override("font_size",13);_label.add_theme_color_override("font_color",Color("#e6f5ef"));_panel.add_child(_label)

func _input(event:InputEvent)->void:
	if not OS.is_debug_build() or not event is InputEventKey:return
	var key_event:=event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode==KEY_F3:
		_panel.visible=not _panel.visible;get_viewport().set_input_as_handled()

func _process(delta:float)->void:
	_elapsed+=delta;_frame_count+=1;var frame_ms:=delta*1000.0;_window_frame_ms+=frame_ms;_window_max_frame_ms=maxf(_window_max_frame_ms,frame_ms)
	if _elapsed<SAMPLE_WINDOW_SECONDS:return
	var fps:=float(_frame_count)/_elapsed;var average_ms:=_window_frame_ms/maxi(1,_frame_count)
	var process_ms:=float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0
	var physics_ms:=float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0
	var nodes:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var objects:=int(Performance.get_monitor(Performance.OBJECT_COUNT));var orphan_nodes:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var draw_calls:=int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var nav_queries_per_second:=int(roundi(float(SlasherGridPathfinder.navigation_queries-_last_nav_queries)/_elapsed));var flow_fields_per_second:=int(roundi(float(SlasherGridPathfinder.flow_field_builds-_last_flow_fields)/_elapsed));var astar_per_second:=int(roundi(float(SlasherGridPathfinder.astar_searches-_last_astar_searches)/_elapsed))
	_label.text="PERFORMANCE  [F3]\nFPS %d   frame %.1f ms avg / %.1f ms max\nProcess %.1f ms   Physics %.1f ms\nNodes %d   Objects %d   Orphans %d\nDraw calls %d\nNavigation %d/s   Fields %d/s   A* %d/s\nSprite builds %d   last %.1f ms / max %.1f ms"%[roundi(fps),average_ms,_window_max_frame_ms,process_ms,physics_ms,nodes,objects,orphan_nodes,draw_calls,nav_queries_per_second,flow_fields_per_second,astar_per_second,SlasherSpriteLibrary.generated_enemy_build_count,SlasherSpriteLibrary.last_generated_enemy_build_ms,SlasherSpriteLibrary.max_generated_enemy_build_ms]
	_last_nav_queries=SlasherGridPathfinder.navigation_queries;_last_flow_fields=SlasherGridPathfinder.flow_field_builds;_last_astar_searches=SlasherGridPathfinder.astar_searches
	_elapsed=0.0;_frame_count=0;_window_frame_ms=0.0;_window_max_frame_ms=0.0
