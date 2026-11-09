extends RefCounted
class_name RunSeed

## Run seeds: every run is generated from one number (floors, rooms, foes,
## chests, the trader, drops), shown and typed as an 8-character code like
## "K7QF-2MXA" (Isaac style). The same seed gives the same run layout and loot;
## combat rolls (crits, procs, boss patterns) stay random.
##
## Good seeds can be saved for testing (user://saved_seeds.json) and picked on
## the Set Out screen.

## No 0/O or 1/I/L, so codes are easy to read out.
const ALPHABET := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const LENGTH := 8
const SAVED_PATH := "user://saved_seeds.json"
const MAX_SAVED := 50


static func random_value() -> int:
	var base := ALPHABET.length()
	var value := 0
	for index in LENGTH:
		value = value * base + randi_range(0, base - 1)
	return maxi(1, value)


## 12345 -> "AAAA-BN4Q"
static func encode(value: int) -> String:
	var base := ALPHABET.length()
	var chars := ""
	var rest := maxi(0, value)
	for index in LENGTH:
		chars = ALPHABET[rest % base] + chars
		rest = rest / base
	return chars.substr(0, 4) + "-" + chars.substr(4)


## "k7qf 2mxa" -> the seed, or 0 if it isn't a valid code. Case, spaces and
## dashes don't matter.
static func decode(text: String) -> int:
	var clean := text.strip_edges().to_upper().replace("-", "").replace(" ", "")
	if clean.length() != LENGTH:
		return 0
	var base := ALPHABET.length()
	var value := 0
	for character in clean:
		var digit := ALPHABET.find(character)
		if digit < 0:
			return 0
		value = value * base + digit
	return value if value > 0 else 0


static func is_valid(text: String) -> bool:
	return decode(text) > 0


# ---------------------------------------------------------------- saved seeds


static func saved() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(SAVED_PATH):
		return result
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVED_PATH))
	if parsed is Array:
		for entry in parsed:
			if entry is Dictionary and is_valid(String(entry.get("code", ""))):
				result.append(entry)
	return result


## Adds (or moves to the top) a seed with a short note. Returns false if the
## file couldn't be written.
static func save_seed(code: String, note: String = "") -> bool:
	if not is_valid(code):
		return false
	var canonical := encode(decode(code))
	var list := saved().filter(func(entry): return String(entry.code) != canonical)
	list.push_front(
		{"code": canonical, "note": note, "saved_unix": int(Time.get_unix_time_from_system())}
	)
	if list.size() > MAX_SAVED:
		list.resize(MAX_SAVED)
	return _write(list)


static func forget(code: String) -> bool:
	var canonical := encode(decode(code))
	return _write(saved().filter(func(entry): return String(entry.code) != canonical))


static func is_saved(code: String) -> bool:
	var canonical := encode(decode(code))
	return saved().any(func(entry): return String(entry.code) == canonical)


static func _write(list: Array) -> bool:
	var file := FileAccess.open(SAVED_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(list, "\t"))
	return true
