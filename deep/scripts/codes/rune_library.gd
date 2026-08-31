class_name RuneLibrary
extends RefCounted
## Returns the generated starter catalog. The unused path parameter preserves compatibility with the former
## JSON loader.
static func load_runes(_path := "") -> Array:
	return StarterRunes.all()

## Delegates a defensive rune lookup to StarterRunes.
static func get_rune(id: String) -> Dictionary:
	return StarterRunes.get_rune(id)

## Converts numeric directions to readable arrow-separated abbreviations; unknown values become ?.
static func path_text(path: Array) -> String:
	var names := ["E", "NE", "NW", "W", "SW", "SE"]
	var parts: PackedStringArray = []
	for step in path: parts.append(names[int(step)] if int(step) >= 0 and int(step) < 6 else "?")
	return " → ".join(parts)
## Returns the six-direction code for adjacent staggered-grid coordinates or -1 for invalid/non-neighbor
## movement. Row parity is significant.
static func direction(a: Vector2i, b: Vector2i) -> int:
	var dr := b.y-a.y; var dc := b.x-a.x
	if dr == 0 and dc == 1: return 0
	if dr == 0 and dc == -1: return 3
	var odd := a.y % 2 != 0
	if dr == -1 and dc == (1 if odd else 0): return 1
	if dr == -1 and dc == (0 if odd else -1): return 2
	if dr == 1 and dc == (0 if odd else -1): return 4
	if dr == 1 and dc == (1 if odd else 0): return 5
	return -1
## Converts point coordinates to translation-independent direction steps. Any invalid segment rejects the
## complete path with an empty array.
static func normalize_path(points: Array[Vector2i]) -> Array[int]:
	var steps: Array[int] = []
	for i in range(points.size()-1):
		var step := direction(points[i], points[i+1])
		if step < 0: return []
		steps.append(step)
	return steps
## Normalizes the drawing and returns the first exact path match or an empty dictionary.
static func find_match(points: Array[Vector2i], runes: Array) -> Dictionary:
	var steps := normalize_path(points)
	for rune in runes:
		if Array(rune.get("path", [])) == steps: return rune
	return {}
