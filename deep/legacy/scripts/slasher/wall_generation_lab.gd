@tool
extends Node2D

@export var rebuild_preview:=false:
	set(value):
		rebuild_preview=false
		if is_inside_tree():rebuild_lab()
@export var start_with_deep_facades:=false
@export var start_with_debug_overlay:=false
@export var show_authored_reference:=true

@onready var wall_generator:SlasherWallGenerator=$SlasherWallGenerator
var cells:Dictionary={}
var camera:Camera2D
var report_label:Label

func _ready()->void:
	build_layout();_build_runtime_ui();rebuild_lab();_apply_comparison_visibility()

func build_layout()->void:
	cells.clear()
	# Main room, two-cell corridor, offset room, concave U, internal hole, narrow gap, and diagonal contact.
	_carve_rect(Rect2i(2,2,12,8));_carve_rect(Rect2i(14,5,7,2));_carve_rect(Rect2i(21,2,10,9))
	_carve_rect(Rect2i(5,10,2,7));_carve_rect(Rect2i(5,15,10,2));_carve_rect(Rect2i(13,11,2,6))
	_carve_rect(Rect2i(18,14,9,7));_remove_rect(Rect2i(21,16,3,3))
	_carve_rect(Rect2i(30,13,5,3));_carve_rect(Rect2i(30,17,5,3))
	cells[Vector2i(37,16)]=true;cells[Vector2i(38,17)]=true
	_build_mask_gallery()

func _build_mask_gallery()->void:
	# Fifteen separated fixtures guarantee that every N/E/S/W boundary mask can be reviewed.
	var directions:Array[Vector2i]=[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
	for mask in range(1,16):
		var center:=Vector2i(2+(mask-1)%8*5,24+int((mask-1)/8)*5);cells[center]=true
		for index in directions.size():
			if (mask&(1<<index))==0:cells[center+directions[index]]=true

func rebuild_lab()->void:
	if wall_generator==null:return
	wall_generator.generate_deep_facades=start_with_deep_facades;wall_generator.show_topology_debug=start_with_debug_overlay;wall_generator.render_collisions=not Engine.is_editor_hint();wall_generator.generate(cells,[],Vector2(96,96));queue_redraw();_refresh_report()

func _draw()->void:
	draw_rect(Rect2(-2000,-2000,5000,4000),Color("07100d"))
	for value in cells:
		var cell:=Vector2i(value);var rect:=Rect2(Vector2(96,96)+Vector2(cell)*48,Vector2(48,48));draw_rect(rect,Color("69751d"));draw_rect(rect,Color("7d8730"),false,1.0)

func _unhandled_input(event:InputEvent)->void:
	if Engine.is_editor_hint():return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F:start_with_deep_facades=not start_with_deep_facades;rebuild_lab();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_G:start_with_debug_overlay=not start_with_debug_overlay;rebuild_lab();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_H:show_authored_reference=not show_authored_reference;_apply_comparison_visibility();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_R:rebuild_lab();get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and camera!=null:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.zoom*=1.1
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.zoom/=1.1

func _process(delta:float)->void:
	if Engine.is_editor_hint() or camera==null:return
	var movement:=Vector2(float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))-float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))-float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)));camera.position+=movement.normalized()*520.0*delta/camera.zoom.x if not movement.is_zero_approx() else Vector2.ZERO

func _build_runtime_ui()->void:
	if Engine.is_editor_hint():return
	camera=Camera2D.new();camera.name="LabCamera";camera.position=Vector2(960,620);camera.zoom=Vector2.ONE*0.72;add_child(camera);camera.make_current()
	var layer:=CanvasLayer.new();layer.name="LabUI";add_child(layer);var panel:=PanelContainer.new();panel.position=Vector2(18,18);panel.custom_minimum_size=Vector2(720,112);var style:=StyleBoxFlat.new();style.bg_color=Color("10140fef");style.border_color=Color("b98335");style.set_border_width_all(2);style.set_corner_radius_all(6);panel.add_theme_stylebox_override("panel",style);layer.add_child(panel)
	var margin:=MarginContainer.new();margin.add_theme_constant_override("margin_left",14);margin.add_theme_constant_override("margin_right",14);margin.add_theme_constant_override("margin_top",10);margin.add_theme_constant_override("margin_bottom",10);panel.add_child(margin);report_label=Label.new();report_label.add_theme_font_size_override("font_size",16);report_label.add_theme_color_override("font_color",Color("ead9b8"));margin.add_child(report_label)

func _refresh_report()->void:
	if report_label==null:return
	var report:=wall_generator.generation_report();var unsupported:Array=report.unsupported_masks
	report_label.text="WALL GENERATION LAB\nWASD/Arrows pan · Wheel zoom · H authored/generated · F facades · G topology · R rebuild\nView: %s · %d cells · %d edges · %d contours · Deep: %s · Unsupported: %d\nMasks: %s"%["AUTHORED REFERENCE" if show_authored_reference else "GENERATED",report.walkable_cells,report.boundary_edges,report.contours,"ON" if report.deep_facades else "OFF",unsupported.size(),str(report.mask_counts)]
	report_label.add_theme_color_override("font_color",Color("ff8c69") if not unsupported.is_empty() else Color("ead9b8"))

func _apply_comparison_visibility()->void:
	wall_generator.visible=not show_authored_reference
	for child in get_children():
		if child is TileMapLayer:(child as TileMapLayer).visible=show_authored_reference
	_refresh_report()

func _carve_rect(rect:Rect2i)->void:
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):cells[Vector2i(x,y)]=true

func _remove_rect(rect:Rect2i)->void:
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):cells.erase(Vector2i(x,y))
