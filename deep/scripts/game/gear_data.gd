extends Resource
class_name GearData

@export var id: String = ""
@export var display_name: String = ""
@export var damage: int = 1
@export var has_block: bool = false
@export var block_limit: int = 0
@export var special_id: String = ""
@export var class_id: String = "warrior"
@export var defense_id: String = ""
@export_multiline var description: String = ""

static func create(
	gear_id: String,
	gear_name: String,
	gear_damage: int,
	gear_has_block: bool,
	gear_block_limit: int,
	gear_special_id: String,
	gear_description: String,
	gear_class_id: String = "warrior",
	gear_defense_id: String = ""
) -> GearData:
	var gear := GearData.new()
	gear.id = gear_id
	gear.display_name = gear_name
	gear.damage = gear_damage
	gear.has_block = gear_has_block
	gear.block_limit = gear_block_limit
	gear.special_id = gear_special_id
	gear.class_id = gear_class_id
	gear.defense_id = gear_defense_id
	gear.description = gear_description
	return gear
