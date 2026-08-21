extends RefCounted
class_name RunState

var selected_gear: GearData
var selected_class_id: String = "fighter"
var selected_class_name: String = "Fighter"
var current_health: int = 12
var max_health: int = 12
var gold: int = 0
var keys: int = 0
var potions: int = 0
var floor_seed: int = 1001
var current_floor: int = 1
var max_floors: int = 5
var run_outcome: String = "The bartender polishes a glass and waits."
var completed_runs: int = 0
var deaths: int = 0

func set_class(class_id: String) -> void:
	selected_class_id = class_id
	selected_class_name = "Mage" if class_id == "mage" else "Fighter"

func start_new_run(gear: GearData) -> void:
	selected_gear = gear
	current_health = max_health
	gold = 0
	keys = 0
	potions = 0
	current_floor = 1
	floor_seed += 37
	run_outcome = "The forest door opens. The tavern falls quiet behind you."

func advance_floor() -> bool:
	if current_floor >= max_floors:
		return false
	current_floor += 1
	return true

func get_current_floor_seed() -> int:
	return floor_seed + current_floor * 997

func finish_run(outcome: String, message: String) -> void:
	run_outcome = message
	if outcome == "victory":
		completed_runs += 1
	elif outcome == "death":
		deaths += 1
	selected_gear = null

func heal(amount: int) -> void:
	current_health = mini(max_health, current_health + amount)

func hurt(amount: int) -> void:
	current_health = maxi(0, current_health - amount)
