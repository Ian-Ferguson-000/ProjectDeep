class_name SoulSpaceOverlay
extends Control

signal close_requested

const GRID_RECT:=Rect2(54,118,610,410)
const NODE_SOURCE:=Rect2(365,350,145,145)
const NODE_SIZE:=Vector2(20,20)
var runes:Array=[]
var catalog_mode:=false
var erase_mode:=false
var dragging:=false
var last_dot:=Vector2i(-1,-1)
var hovered_dot:=Vector2i(-1,-1)
var selected_rune_id:=""
var selected_rune:Dictionary={}
var grid_controls:Array[Control]=[]
var catalog_panel:Panel
var detected_list:VBoxContainer
var detected_details:RichTextLabel
var detected_action:Button
var slot_buttons:Array[Button]=[]
var grid_label:Label
var element_filter:OptionButton
var form_filter:OptionButton
var rune_list:VBoxContainer
var catalog_details:RichTextLabel
var catalog_action:Button
var equip_slot:OptionButton
var clear_dialog:ConfirmationDialog
var status:="Draw across neighboring nodes to build a persistent rune network."
var spell_node_texture:Texture2D=preload("res://assets/pixel_art/spellnode.png")
var item_holder_texture:Texture2D=preload("res://assets/Humble Gift - Paper UI System v1.1/Sprites/Paper UI Pack/Plain/3 Item Holder/1.png")

## Enables pause-safe input, constructs both pages, and subscribes to authoritative grid and rune state.
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=Control.MOUSE_FILTER_STOP;runes=RuneLibrary.load_runes()
	_button("Soul Grid",Vector2(38,72),Vector2(145,38),_set_mode.bind(false))
	_button("Rune Catalog",Vector2(190,72),Vector2(155,38),_set_mode.bind(true))
	_build_grid_page();_build_catalog()
	GameState.soul_grid_changed.connect(_on_grid_changed);GameState.active_grid_runes_changed.connect(_on_active_changed)
	GameState.inventory_changed.connect(_refresh_all);GameState.runes_changed.connect(_refresh_all);_refresh_all()

## Creates a consistently sized action button and binds its pressed callback.
func _button(text:String,pos:Vector2,dimensions:Vector2,callback:Callable) -> Button:
	var button:=Button.new();button.text=text;button.position=pos;button.size=dimensions;button.pressed.connect(callback);add_child(button);return button

## Constructs editing controls, detected-pattern browser, slot assignment actions, and clear confirmation.
func _build_grid_page() -> void:
	var draw:=_button("Draw",Vector2(700,82),Vector2(92,38),_set_edit_mode.bind(false));var erase:=_button("Erase",Vector2(798,82),Vector2(92,38),_set_edit_mode.bind(true))
	grid_label=Label.new();grid_label.position=Vector2(902,72);grid_label.size=Vector2(165,58);grid_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;grid_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;grid_label.add_theme_color_override("font_color",Color("#402314"));add_child(grid_label)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(700,132);scroll.size=Vector2(365,190);add_child(scroll)
	detected_list=VBoxContainer.new();detected_list.custom_minimum_size=Vector2(345,0);scroll.add_child(detected_list)
	detected_details=RichTextLabel.new();detected_details.position=Vector2(700,330);detected_details.size=Vector2(365,130);detected_details.bbcode_enabled=true;detected_details.add_theme_color_override("default_color",Color("#402314"));add_child(detected_details)
	detected_action=_button("Craft Detected Rune",Vector2(700,468),Vector2(180,40),_craft_detected)
	for slot in 4:
		var slot_button:=_button("Slot %d"%(slot+1),Vector2(886+(slot%2)*90,468+(slot/2)*42),Vector2(84,36),_assign_detected.bind(slot));slot_buttons.append(slot_button)
	var clear:=_button("Clear Network",Vector2(700,554),Vector2(170,40),_request_clear);var close:=_button("Close [R/Esc]",Vector2(884,554),Vector2(180,40),_close)
	grid_controls.append_array([draw,erase,grid_label,scroll,detected_details,detected_action,clear,close]);grid_controls.append_array(slot_buttons)
	clear_dialog=ConfirmationDialog.new();clear_dialog.title="Clear Soul Network?";clear_dialog.dialog_text="Remove every connection? Equipped spells without another placement will be cleared.";clear_dialog.confirmed.connect(_confirm_clear);add_child(clear_dialog)

## Constructs element/form filters, catalog rows, recipe details, and slot-aware crafting controls.
func _build_catalog() -> void:
	catalog_panel=Panel.new();catalog_panel.position=Vector2(35,115);catalog_panel.size=Vector2(1030,485);catalog_panel.visible=false;add_child(catalog_panel)
	element_filter=OptionButton.new();element_filter.position=Vector2(18,14);element_filter.size=Vector2(170,38)
	for option in ["All elements","Spirit","Fire","Burn","Lightning","Magnetism","Aether","Void","Force","Wave","Growth","Earth","Light","Wind"]:element_filter.add_item(option)
	element_filter.item_selected.connect(func(_index):_refresh_catalog());catalog_panel.add_child(element_filter)
	form_filter=OptionButton.new();form_filter.position=Vector2(198,14);form_filter.size=Vector2(165,38);form_filter.add_item("All forms")
	for form in StarterRunes.FORMS:form_filter.add_item(str(form).capitalize())
	form_filter.item_selected.connect(func(_index):_refresh_catalog());catalog_panel.add_child(form_filter)
	var scroll:=ScrollContainer.new();scroll.position=Vector2(18,62);scroll.size=Vector2(345,350);catalog_panel.add_child(scroll)
	rune_list=VBoxContainer.new();rune_list.custom_minimum_size=Vector2(325,0);scroll.add_child(rune_list)
	catalog_details=RichTextLabel.new();catalog_details.position=Vector2(390,18);catalog_details.size=Vector2(610,330);catalog_details.bbcode_enabled=true;catalog_details.add_theme_color_override("default_color",Color("#402314"));catalog_panel.add_child(catalog_details)
	equip_slot=OptionButton.new();equip_slot.position=Vector2(390,360);equip_slot.size=Vector2(190,40)
	for slot in 4:equip_slot.add_item("Assign to Slot %d"%(slot+1))
	equip_slot.select(GameState.selected_spell_slot);catalog_panel.add_child(equip_slot)
	catalog_action=Button.new();catalog_action.position=Vector2(590,360);catalog_action.size=Vector2(210,40);catalog_action.pressed.connect(_catalog_action_pressed);catalog_panel.add_child(catalog_action)
	var close:=Button.new();close.text="Close [R/Esc]";close.position=Vector2(810,360);close.size=Vector2(190,40);close.pressed.connect(_close);catalog_panel.add_child(close)

## Switches between the persistent network editor and the complete rune catalog.
func _set_mode(use_catalog:bool) -> void:
	catalog_mode=use_catalog;catalog_panel.visible=use_catalog
	for control in grid_controls:control.visible=not use_catalog
	if use_catalog:_refresh_catalog()
	queue_redraw()

## Selects Draw or Erase behavior and reports the current drag operation.
func _set_edit_mode(use_erase:bool) -> void:
	erase_mode=use_erase;status="Erase mode: drag across connections." if erase_mode else "Draw mode: drag across neighboring nodes.";_update_status()

## Opens the parchment confirmation before destructive network clearing.
func _request_clear() -> void:clear_dialog.popup_centered(Vector2i(520,180))

## Clears the authoritative network and current editing anchor after confirmation, then updates feedback.
func _confirm_clear() -> void:GameState.clear_soul_grid();last_dot=Vector2i(-1,-1);status="Soul network cleared.";_update_status();queue_redraw()

## Rebuilds grid labels, detected rows, selection details, catalog state, and rendering.
func _refresh_all() -> void:
	if not is_node_ready():return
	_refresh_detected();_refresh_catalog();_update_grid_label();_update_status();queue_redraw()

## Responds to graph edits by rebuilding all derived Soul Space presentation.
func _on_grid_changed(_size:int,_segments:Dictionary,_placements:Dictionary) -> void:_refresh_all()

## Responds to crafted-pattern activation changes and refreshes assignment eligibility.
func _on_active_changed(_ids:Array[String]) -> void:_refresh_all()

## Displays current dimensions, five expansion pips, and progression-only upgrade guidance.
func _update_grid_label() -> void:
	var filled:=GameState.soul_grid_size-7;var pips:=""
	for index in 5:pips+="●" if index<filled else "○"
	grid_label.text="Grid %d×%d  %s\n%s"%[GameState.soul_grid_size,GameState.soul_grid_size,pips,"MAXIMUM SOUL SPACE" if GameState.soul_grid_size==12 else "Next expansion: progression reward"]
	grid_label.add_theme_font_size_override("font_size",11)

## Rebuilds every detected pattern card and preserves a valid selected placement for inspection.
func _refresh_detected() -> void:
	if not detected_list:return
	_clear_children(detected_list);var ids:Array=GameState.soul_grid_placements.keys();ids.sort()
	if selected_rune_id not in ids:selected_rune_id=str(ids[0]) if not ids.is_empty() else ""
	for id_value in ids:
		var id:=str(id_value);var rune:=RuneLibrary.get_rune(id);var crafted:=id in GameState.discovered_runes
		var button:=Button.new();button.text=("[ACTIVE IN GRID] " if crafted else "[DETECTED — CRAFT] ")+str(rune.get("name",id));button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size.y=42;button.add_theme_stylebox_override("normal",_item_style());button.pressed.connect(_select_detected.bind(id));detected_list.add_child(button)
	_update_detected_details()

## Selects one detected rune and highlights its first translated placement.
func _select_detected(id:String) -> void:selected_rune_id=id;_update_detected_details();queue_redraw()

## Shows selected pattern ownership, placement count, recipe state, and assignment availability.
func _update_detected_details() -> void:
	if selected_rune_id.is_empty():
		detected_details.text="[font_size=22]No patterns detected[/font_size]\nDraw a crafted rune path into the shared network.";detected_action.disabled=true
		for button in slot_buttons:button.disabled=true
		return
	var rune:=RuneLibrary.get_rune(selected_rune_id);var crafted:=selected_rune_id in GameState.discovered_runes;var active:=GameState.is_rune_active_in_grid(selected_rune_id);var placements:=GameState.soul_placements_for(selected_rune_id)
	detected_details.text="[font_size=22]%s[/font_size]\n%s • %s\n%d placement(s) detected\n%s"%[rune.name,str(rune.element).capitalize(),str(rune.form).capitalize(),placements.size(),"Active and available for a hotbar slot." if active else "Craft this detected pattern to activate it."]
	detected_action.text="Craft Rune" if not crafted else "Crafted — Active";detected_action.disabled=crafted or not GameState.can_craft(rune.costs)
	for button in slot_buttons:button.disabled=not active

## Crafts the currently detected rune without auto-equipping it.
func _craft_detected() -> void:
	var rune:=RuneLibrary.get_rune(selected_rune_id)
	if not rune.is_empty() and GameState.craft_rune(rune):status="Crafted %s. Choose a hotbar slot."%rune.name
	else:status="The required materials are not available."
	_update_status()

## Assigns the selected active pattern to one explicit hotbar slot.
func _assign_detected(slot:int) -> void:
	var rune:=RuneLibrary.get_rune(selected_rune_id)
	if GameState.equip_rune(selected_rune_id,slot):status="Assigned %s to slot %d."%[rune.get("name",selected_rune_id),slot+1]
	else:status="Only crafted runes currently present in the grid can be assigned."
	_update_status()

## Rebuilds catalog rows with slot, active, arranged-unowned, crafted-inactive, craftable, and locked states.
func _refresh_catalog() -> void:
	if not rune_list:return
	_clear_children(rune_list)
	var filter_name:=element_filter.get_item_text(maxi(0,element_filter.selected)).to_lower().replace(" elements","");var selected_form:=form_filter.get_item_text(maxi(0,form_filter.selected)).to_lower().replace(" forms","")
	for rune in runes:
		if filter_name!="all" and rune.element!=filter_name:continue
		if selected_form!="all" and rune.form!=selected_form:continue
		var id:=str(rune.id);var button:=Button.new();button.text=_rune_marker(id,rune)+str(rune.name);button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size.y=42;button.add_theme_stylebox_override("normal",_item_style());button.pressed.connect(_select_catalog_rune.bind(id));rune_list.add_child(button)
	if selected_rune.is_empty() and not runes.is_empty():selected_rune=runes[0]
	_update_catalog_details()

## Returns the precise loadout-state marker shared by Soul Space catalog rows.
func _rune_marker(id:String,rune:Dictionary) -> String:
	if id in GameState.equipped_runes:return "[SLOT %d] "%(GameState.equipped_runes.find(id)+1)
	if GameState.is_rune_active_in_grid(id):return "[ACTIVE IN GRID] "
	if id in GameState.discovered_runes:return "[CRAFTED — ARRANGE] "
	if GameState.soul_grid_placements.has(id):return "[DETECTED — CRAFT] "
	return "[READY] " if GameState.can_craft(rune.costs) else "[LOCKED] "

## Loads a catalog rune by stable ID and updates its recipe/action panel.
func _select_catalog_rune(id:String) -> void:selected_rune=RuneLibrary.get_rune(id);_update_catalog_details()

## Formats catalog combat/recipe data and enforces grid-aware Craft or Assign eligibility.
func _update_catalog_details() -> void:
	if selected_rune.is_empty():return
	var costs:Array[String]=[]
	for item in selected_rune.costs:costs.append("%s ×%d"%[str(item).replace("_"," ").capitalize(),selected_rune.costs[item]])
	catalog_details.text="[font_size=27][color=%s]%s[/color][/font_size]\n%s • %s • Invocation %s\n\n%s\n\nPower %s   Mana %s   Range %s   Cooldown %ss\nStatus %s (%s)\n\nPath: %s\nRecipe: %s"%[_element_color(selected_rune.element),selected_rune.name,str(selected_rune.element).capitalize(),str(selected_rune.form).capitalize(),selected_rune.invocation,selected_rune.description,selected_rune.power,selected_rune.mana_cost,selected_rune.range,selected_rune.cooldown,str(selected_rune.status_effect).replace("_"," ").capitalize(),selected_rune.status_power,RuneLibrary.path_text(selected_rune.path),", ".join(costs)]
	var id:=str(selected_rune.id)
	if id in GameState.discovered_runes:catalog_action.text="Assign to Slot %d"%(equip_slot.selected+1) if GameState.is_rune_active_in_grid(id) else "Arrange in Soul Grid";catalog_action.disabled=not GameState.is_rune_active_in_grid(id)
	else:catalog_action.text="Craft Rune";catalog_action.disabled=not GameState.can_craft(selected_rune.costs)

## Crafts an unknown catalog rune or assigns an active crafted rune to the chosen slot.
func _catalog_action_pressed() -> void:
	var id:=str(selected_rune.id)
	if id in GameState.discovered_runes:GameState.equip_rune(id,equip_slot.selected)
	else:GameState.craft_rune(selected_rune)
	_refresh_all()

## Processes click-to-click and press-drag editing while preserving the last anchor between clicks.
func _gui_input(event:InputEvent) -> void:
	if catalog_mode:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging=event.pressed
		if event.pressed:
			var dot:=_dot_at(event.position)
			if dot.x>=0:
				if last_dot.x<0:last_dot=dot;status="Node selected. Click or drag to a neighboring node."
				elif dot!=last_dot and _edit_segment(last_dot,dot):last_dot=dot
				_update_status();queue_redraw()
	elif event is InputEventMouseMotion:
		var dot:=_dot_at(event.position)
		if dot!=hovered_dot:hovered_dot=dot;queue_redraw()
		if dragging and dot.x>=0 and last_dot.x>=0 and dot!=last_dot:
			if _edit_segment(last_dot,dot):last_dot=dot

## Adds or erases one neighboring edge and reports whether the cursor may advance to its endpoint.
func _edit_segment(a:Vector2i,b:Vector2i) -> bool:
	if RuneLibrary.direction(a,b)<0:
		status="Invalid jump ignored. Return to the anchor and choose a neighboring node.";_update_status();return false
	if erase_mode:
		status="Connection erased." if GameState.remove_soul_segment(a,b) else "No connection exists there."
	else:
		var added:=GameState.add_soul_segment(a,b);status="Connection added." if added else "Connection selected—continue from this node."
	_update_status();queue_redraw();return true

## Closes Soul Space from its shortcut or cancel action while paused.
func _unhandled_input(event:InputEvent) -> void:
	if visible and (event.is_action_pressed("soul_space") or event.is_action_pressed("ui_cancel")):_close();get_viewport().set_input_as_handled()

## Emits the close request while Main retains pause and overlay ownership.
func _close() -> void:close_requested.emit()

## Updates the editor-native parchment status line.
func _update_status() -> void:
	var label:=get_node_or_null("%StatusLabel")
	if label:label.text=status

## Computes responsive staggered-lattice spacing capped at 52 pixels for grids from 7×7 through 12×12.
func _grid_metrics() -> Dictionary:
	var count:=GameState.soul_grid_size;var gap:=minf(52.0,minf((GRID_RECT.size.x-36.0)/(count-0.5),(GRID_RECT.size.y-36.0)/((count-1)*0.86)))
	var dimensions:=Vector2((count-1)*gap+gap*0.5,(count-1)*gap*0.86);return {"gap":gap,"origin":GRID_RECT.position+(GRID_RECT.size-dimensions)*0.5}

## Converts a logical staggered-grid coordinate into a centered local pixel position.
func _dot_position(dot:Vector2i) -> Vector2:
	var metrics:=_grid_metrics();var gap:float=metrics.gap;return metrics.origin+Vector2(dot.x*gap+(gap*0.5 if dot.y%2 else 0.0),dot.y*gap*0.86)

## Hit-tests every unlocked node and returns the nearest coordinate or the invalid sentinel.
func _dot_at(mouse:Vector2) -> Vector2i:
	var radius:=maxf(18.0,_grid_metrics().gap*0.42)
	for y in GameState.soul_grid_size:
		for x in GameState.soul_grid_size:
			if mouse.distance_to(_dot_position(Vector2i(x,y)))<=radius:return Vector2i(x,y)
	return Vector2i(-1,-1)

## Returns East, South-West, and South-East neighbors for one-pass undirected lattice drawing.
func _forward_neighbors(dot:Vector2i) -> Array[Vector2i]:
	var side:=1 if dot.y%2!=0 else 0;return [Vector2i(dot.x+1,dot.y),Vector2i(dot.x-1+side,dot.y+1),Vector2i(dot.x+side,dot.y+1)]

## Renders lattice rails, persistent edges, all detected highlights, selected placement, and spell nodes.
func _draw() -> void:
	if catalog_mode:return
	for y in GameState.soul_grid_size:
		for x in GameState.soul_grid_size:
			var point:=Vector2i(x,y)
			for neighbor in _forward_neighbors(point):
				if neighbor.x>=0 and neighbor.y>=0 and neighbor.x<GameState.soul_grid_size and neighbor.y<GameState.soul_grid_size:draw_line(_dot_position(point),_dot_position(neighbor),Color("#39251f"),4,true)
	for edge in GameState.soul_grid_segments.values():draw_line(_dot_position(edge[0]),_dot_position(edge[1]),Color("#0d0807"),11,true);draw_line(_dot_position(edge[0]),_dot_position(edge[1]),Color("#321b18"),6,true)
	_draw_pattern_highlights()
	for y in GameState.soul_grid_size:
		for x in GameState.soul_grid_size:
			var point:=Vector2i(x,y);var center:=_dot_position(point)
			draw_circle(center,NODE_SIZE.x*0.53,Color("#241713"))
			if point==last_dot:draw_arc(center,14.0,0.0,TAU,24,Color("#24120d"),3.0,true)
			if point==hovered_dot:draw_arc(center,17.0,0.0,TAU,24,Color("#5b2d20"),3.0,true)
			draw_texture_rect_region(spell_node_texture,Rect2(center-NODE_SIZE*0.5,NODE_SIZE),NODE_SOURCE,Color("#70584d"))

## Layers muted or elemental highlights for detected placements and brightens the selected match.
func _draw_pattern_highlights() -> void:
	var shared_counts:Dictionary={};var shared_edges:Dictionary={}
	for id_value in GameState.soul_grid_placements:
		var id:=str(id_value);var rune:=RuneLibrary.get_rune(id);var color:=Color(_grid_element_color(str(rune.get("element","spirit")))) if id in GameState.discovered_runes else Color("#4b3559")
		for placement in GameState.soul_grid_placements[id]:
			_draw_placement(placement,color,5.0)
			for index in range(placement.size()-1):
				var key:=GameState.soul_segment_key(placement[index],placement[index+1]);shared_counts[key]=int(shared_counts.get(key,0))+1;shared_edges[key]=[placement[index],placement[index+1]]
	for key in shared_counts:
		if shared_counts[key]>1:
			var edge:Array=shared_edges[key];draw_line(_dot_position(edge[0]),_dot_position(edge[1]),Color("#231728"),4.0,true)
	if not selected_rune_id.is_empty():
		var placements:=GameState.soul_placements_for(selected_rune_id)
		if not placements.is_empty():_draw_placement(placements[0],Color("#24120d"),9.0)

## Draws every consecutive segment in one detected placement with a requested color and width.
func _draw_placement(placement:Array,color:Color,width:float) -> void:
	for index in range(placement.size()-1):draw_line(_dot_position(placement[index]),_dot_position(placement[index+1]),color,width,true)

## Returns stable elemental highlight colors for all twelve families plus Spirit.
func _element_color(element:String) -> String:
	match element:
		"fire":return "#ed6335"
		"burn":return "#d83d22"
		"lightning":return "#e5c93e"
		"magnetism":return "#8e91a8"
		"aether":return "#8c6fd1"
		"void":return "#5f3b82"
		"force":return "#4f9fc8"
		"wave":return "#4bbfc5"
		"growth":return "#70a940"
		"earth":return "#9b7144"
		"light":return "#f4dc83"
		"wind":return "#91d3c8"
		_:return "#62b783"

## Returns darker elemental variants that remain legible over the light parchment Soul Grid surface.
func _grid_element_color(element:String) -> String:
	match element:
		"fire":return "#7e2418"
		"burn":return "#651914"
		"lightning":return "#75611b"
		"magnetism":return "#414456"
		"aether":return "#49336f"
		"void":return "#332044"
		"force":return "#285473"
		"wave":return "#276267"
		"growth":return "#385d25"
		"earth":return "#573b24"
		"light":return "#79642d"
		"wind":return "#376c67"
		_:return "#2c6548"

## Creates a Humble Gift item-holder style for detected and catalog rows.
func _item_style() -> StyleBoxTexture:
	var style:=StyleBoxTexture.new();style.texture=item_holder_texture
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_texture_margin(side,18.0)
	return style

## Removes generated list rows immediately without leaving stale layout children.
func _clear_children(container:Node) -> void:
	for child in container.get_children():container.remove_child(child);child.queue_free()
