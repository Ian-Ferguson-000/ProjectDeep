extends RefCounted
class_name ActiveItems

## Active items (data/active_items.json): one slot, used with Space, recharged by
## clearing rooms or over time. The held item and its charge live in the run's
## stats (run_stats.active_item), so they're saved with the expedition and carry
## on into the next dungeon. Effects: scripts/slasher/slasher_active_effects.gd.

const PATH := "res://data/active_items.json"
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"items":{}}
	return _data

static func items() -> Dictionary:
	return Dictionary(data().get("items",{}))

static func item(id: String) -> Dictionary:
	return Dictionary(items().get(id,{}))

static func ids_for_class(class_id: String) -> Array[String]:
	var result: Array[String] = []
	for id in items():
		var classes: Array = Array(item(id).get("classes",[]))
		if classes.is_empty() or classes.has(class_id): result.append(String(id))
	result.sort()
	return result

static func uses_timer(id: String) -> bool:
	return String(item(id).get("charge","rooms")) == "timer"

## Full charge: room pips, or seconds for timer items.
static func max_charge(id: String) -> float:
	if id.is_empty(): return 1.0
	return float(item(id).get("seconds",4.0)) if uses_timer(id) else float(item(id).get("rooms",2))

static func _slot(state: RunState) -> Dictionary:
	var stats := state.run_stats()
	if not stats.has("active_item"): stats["active_item"] = {"id":"","charge":0.0}
	return stats["active_item"]

static func held(state: RunState) -> String:
	return String(_slot(state).get("id","")) if state != null else ""

static func charge(state: RunState) -> float:
	return float(_slot(state).get("charge",0.0))

static func is_ready(state: RunState) -> bool:
	var id := held(state)
	return not id.is_empty() and charge(state) >= max_charge(id) - 0.001

## Takes an item into the slot, fully charged. Returns the item it replaced ("" if none).
static func give(state: RunState, id: String) -> String:
	var slot := _slot(state)
	var old := String(slot.get("id",""))
	slot["id"] = id
	slot["charge"] = max_charge(id)
	return old

static func clear(state: RunState) -> void:
	var slot := _slot(state)
	slot["id"] = ""; slot["charge"] = 0.0

static func add_room_charge(state: RunState, rooms: int = 1) -> void:
	var id := held(state)
	if id.is_empty() or uses_timer(id): return
	var slot := _slot(state)
	slot["charge"] = minf(max_charge(id),float(slot.get("charge",0.0)) + rooms)

static func tick(state: RunState, delta: float) -> void:
	var id := held(state)
	if id.is_empty() or not uses_timer(id): return
	var slot := _slot(state)
	if float(slot.get("charge",0.0)) < max_charge(id): slot["charge"] = minf(max_charge(id),float(slot.get("charge",0.0)) + delta)

static func spend(state: RunState) -> void:
	_slot(state)["charge"] = 0.0
