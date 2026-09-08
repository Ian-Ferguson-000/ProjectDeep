@tool
extends Node2D
class_name SlasherWallGenerator

## Editor-friendly owner of generated wall topology, visuals, and collision.
## Modify this script or the wall profile without touching a dungeon runtime.
@export var profile_id:="stone_wall"
@export_range(16,96,1) var tile_size:=48
@export_range(0,4,1) var maximum_facade_depth:=1
@export var render_visuals:=true
@export var render_collisions:=true
@export var generate_deep_facades:=true
@export var show_topology_debug:=false

var wall_topology:Dictionary={}
var source_cells:Dictionary={}
var doorway_edges:Array=[]
var generation_origin:=Vector2.ZERO

func generate(cells:Dictionary,doors:Array=[],world_origin:Vector2=Vector2.ZERO)->Dictionary:
	source_cells=cells.duplicate();doorway_edges=doors.duplicate(true);generation_origin=world_origin;_clear_generated()
	wall_topology=SlasherWallTopology.build(source_cells,doorway_edges,maximum_facade_depth)
	if render_collisions:
		var collisions:=SlasherWallRenderer.build_collisions(wall_topology,world_origin,tile_size);collisions.name="GeneratedCollisions";add_child(collisions)
	if render_visuals:
		var visuals:=SlasherWallRenderer.build_visuals(wall_topology,profile_id,world_origin,tile_size,generate_deep_facades);visuals.name="GeneratedVisuals";add_child(visuals)
	if show_topology_debug:
		var debug:=SlasherWallRenderer.build_debug_overlay(wall_topology,world_origin,tile_size);debug.name="GeneratedDebug";add_child(debug)
	return wall_topology

func rebuild()->Dictionary:return generate(source_cells,doorway_edges,generation_origin)

func set_deep_facades_enabled(enabled:bool)->void:
	generate_deep_facades=enabled;rebuild()

func set_debug_enabled(enabled:bool)->void:
	show_topology_debug=enabled;rebuild()

func generation_report()->Dictionary:
	var masks:=SlasherWallRenderer.mask_report(wall_topology,profile_id)
	return {"walkable_cells":source_cells.size(),"boundary_edges":Array(wall_topology.get("edges",[])).size(),"vertices":Array(wall_topology.get("vertices",[])).size(),"contours":Array(wall_topology.get("contours",[])).size(),"collision_runs":Array(wall_topology.get("collision_runs",[])).size(),"deep_facades":generate_deep_facades,"mask_counts":masks.mask_counts,"unsupported_masks":masks.unsupported_masks,"composite_masks":masks.composite_masks}

func _clear_generated()->void:
	for child in get_children():
		if child.name in ["GeneratedCollisions","GeneratedVisuals","GeneratedDebug"]:remove_child(child);child.queue_free()
