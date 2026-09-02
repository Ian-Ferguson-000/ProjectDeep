extends Control
class_name FieldSlasherMinimap

var run_state:RunState

func setup(state:RunState)->void:run_state=state;mouse_filter=Control.MOUSE_FILTER_IGNORE;queue_redraw()

func _draw()->void:
	if run_state==null:return
	draw_style_box(_panel(),Rect2(Vector2.ZERO,size))
	var rooms:Array=run_state.field_run.get("rooms",[]);var current:=int(run_state.field_run.get("current_room",0));var scale_value:=24.0;var center:=size*0.5
	for value in rooms:
		var room:Dictionary=value
		if not bool(room.get("visited",false)) and int(room.get("id",-1))!=current:continue
		var a:=center+Vector2(room.get("position",Vector2i.ZERO))*scale_value
		for neighbor in Dictionary(room.get("neighbors",{})).values():
			var other:Dictionary=rooms[int(neighbor)];var b:=center+Vector2(other.get("position",Vector2i.ZERO))*scale_value;draw_line(a,b,Color("#765238"),3.0)
	for value in rooms:
		var room:Dictionary=value;var id:=int(room.get("id",-1));var visited:=bool(room.get("visited",false))
		if not visited and id!=current:continue
		var point:=center+Vector2(room.get("position",Vector2i.ZERO))*scale_value;var color:=Color("#4d84c4") if id==current else (Color("#65a66b") if bool(room.get("cleared",false)) else Color("#b18b58"));var role:=String(room.get("role","combat"))
		if visited and role=="shop":color=Color("#e3b34d")
		elif visited and role=="treasure":color=Color("#d67ee8")
		elif visited and role=="elite":color=Color("#df6b45")
		elif visited and role=="boss":color=Color("#b83232")
		draw_circle(point,7.0,color);if id==current:draw_arc(point,10.0,0,TAU,20,Color.WHITE,2.0)

func _panel()->StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("#0c120fe8");style.border_color=Color("#795238");style.set_border_width_all(2);style.set_corner_radius_all(7);return style
