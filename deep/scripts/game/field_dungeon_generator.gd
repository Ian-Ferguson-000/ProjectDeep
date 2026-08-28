extends RefCounted
class_name FieldDungeonGenerator

const DIRECTIONS := {
	"north": Vector2i.UP,
	"east": Vector2i.RIGHT,
	"south": Vector2i.DOWN,
	"west": Vector2i.LEFT,
}
const OPPOSITE := {"north":"south", "east":"west", "south":"north", "west":"east"}

static func generate(seed_value: int, minimum_rooms: int = 10, maximum_rooms: int = 12) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var target := rng.randi_range(minimum_rooms, maximum_rooms)
	var positions: Array[Vector2i] = [Vector2i.ZERO]
	var occupied := {Vector2i.ZERO: 0}
	var attempts := 0
	while positions.size() < target and attempts < target * 80:
		attempts += 1
		var origin := positions[rng.randi_range(0, positions.size() - 1)]
		var direction_values := DIRECTIONS.values()
		var candidate: Vector2i = origin + Vector2i(direction_values[rng.randi_range(0, direction_values.size() - 1)])
		if occupied.has(candidate): continue
		occupied[candidate] = positions.size()
		positions.append(candidate)
	if positions.size() < target:
		for x in range(1, target):
			var fallback := Vector2i(x, 0)
			if not occupied.has(fallback): occupied[fallback] = positions.size(); positions.append(fallback)
			if positions.size() >= target: break
	var rooms: Array[Dictionary] = []
	for i in range(positions.size()):
		rooms.append({"id":i,"position":positions[i],"neighbors":{},"role":"combat","visited":false,"cleared":false,"reward_claimed":false,"chest_opened":false})
	for i in range(positions.size()):
		for direction in DIRECTIONS:
			var neighbor_pos: Vector2i = positions[i] + Vector2i(DIRECTIONS[direction])
			if occupied.has(neighbor_pos): rooms[i]["neighbors"][direction] = int(occupied[neighbor_pos])
	rooms[0]["role"] = "start"
	rooms[0]["cleared"] = true
	var distances := _distances(rooms, 0)
	var dead_ends: Array[int] = []
	for room in rooms:
		if int(room["id"]) != 0 and Dictionary(room["neighbors"]).size() == 1: dead_ends.append(int(room["id"]))
	dead_ends.sort_custom(func(a: int, b: int): return int(distances.get(a, 0)) > int(distances.get(b, 0)))
	var boss_id := dead_ends[0] if not dead_ends.is_empty() else _farthest_room(distances, [0])
	rooms[boss_id]["role"] = "boss"
	var treasure_id := dead_ends[1] if dead_ends.size() > 1 else _farthest_room(distances, [0, boss_id])
	rooms[treasure_id]["role"] = "treasure"
	rooms[treasure_id]["cleared"] = true
	var shop_id := _closest_to_distance(rooms, distances, maxi(2, int(distances.get(boss_id, 4)) / 2), [0, boss_id, treasure_id])
	rooms[shop_id]["role"] = "shop"; rooms[shop_id]["cleared"] = true
	var elite_id := _farthest_room(distances, [0, boss_id, treasure_id, shop_id])
	rooms[elite_id]["role"] = "elite"
	for i in range(rooms.size()): rooms[i]["door_signature"] = door_signature(rooms[i]["neighbors"])
	return {"seed":seed_value,"rooms":rooms,"current_room":0,"previous_room":-1,"boss_defeated":false,"room_count":rooms.size()}

static func door_signature(neighbors: Dictionary) -> String:
	var signature := ""
	for direction in ["north","east","south","west"]:
		if neighbors.has(direction): signature += direction.substr(0, 1).to_upper()
	return signature

static func _distances(rooms: Array[Dictionary], start_id: int) -> Dictionary:
	var result := {start_id:0}; var queue: Array[int] = [start_id]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor in Dictionary(rooms[current]["neighbors"]).values():
			var next := int(neighbor)
			if result.has(next): continue
			result[next] = int(result[current]) + 1; queue.append(next)
	return result

static func _farthest_room(distances: Dictionary, excluded: Array) -> int:
	var best := 0; var best_distance := -1
	for id in distances:
		if excluded.has(int(id)): continue
		if int(distances[id]) > best_distance: best = int(id); best_distance = int(distances[id])
	return best

static func _closest_to_distance(rooms: Array[Dictionary], distances: Dictionary, target: int, excluded: Array) -> int:
	var best := -1; var delta := 999
	for room in rooms:
		var id := int(room["id"])
		if excluded.has(id): continue
		var candidate_delta: int = abs(int(distances.get(id, 0)) - target)
		if candidate_delta < delta: best = id; delta = candidate_delta
	return best if best >= 0 else _farthest_room(distances, excluded)
