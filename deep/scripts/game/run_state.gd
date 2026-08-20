extends RefCounted
class_name RunState

var selected_gear: GearData
var current_health: int = 12
var max_health: int = 12
var gold: int = 0
var keys: int = 0
var potions: int = 0
var floor_seed: int = 1001
var run_outcome: String = "The bartender polishes a glass and waits."
var completed_runs: int = 0
var deaths: int = 0

func start_new_run(gear: GearData) -> void:
	selected_gear = gear
	current_health = max_health
	gold = 0
	keys = 0
	potions = 0
	floor_seed += 37
	run_outcome = "The forest door opens. The tavern falls quiet behind you."

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
