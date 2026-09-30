extends RefCounted
class_name SlasherGridNavigator

const RECALCULATE_INTERVAL_USEC:=100000

var _from_cell:=Vector2i(2147483647,2147483647)
var _target_cell:=Vector2i(2147483647,2147483647)
var _pathfinder_id:=0
var _path_revision:=-1
var _last_refresh_usec:=0
var _waypoint:=Vector2.ZERO
var _direct_to_target:=true
var _has_waypoint:=false

## Reuses steering while an actor and its target remain in the same grid cells.
## A clear route still tracks the target's exact position every frame.
func next_waypoint(pathfinder:SlasherGridPathfinder,from_world:Vector2,to_world:Vector2)->Vector2:
	if pathfinder==null:return to_world
	var from_cell:=pathfinder.world_to_cell(from_world);var target_cell:=pathfinder.world_to_cell(to_world)
	var pathfinder_id:=pathfinder.get_instance_id()
	var route_changed:=not _has_waypoint or pathfinder_id!=_pathfinder_id or from_cell!=_from_cell or target_cell!=_target_cell or pathfinder.revision!=_path_revision
	var now_usec:=Time.get_ticks_usec()
	if route_changed or now_usec-_last_refresh_usec>=RECALCULATE_INTERVAL_USEC:
		_from_cell=from_cell;_target_cell=target_cell;_pathfinder_id=pathfinder_id;_path_revision=pathfinder.revision
		_waypoint=pathfinder.next_waypoint(from_world,to_world);_direct_to_target=_waypoint.is_equal_approx(to_world)
		_last_refresh_usec=now_usec;_has_waypoint=true
	return to_world if _direct_to_target else _waypoint
