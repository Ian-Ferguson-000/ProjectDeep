extends RefCounted
class_name SimpleCombat

## Small, readable combat numbers (slasher_balance.json → "simple_combat"),
## set up for balancing the Fighter (warrior) first:
##
## - Health is hearts: 1 health = 1 heart, no half hearts. Hearts come from
##   Constitution: CON / con_per_heart, rounded (CON 20 = 5 hearts).
## - Damage comes from the class's main stat (Strength for the Fighter):
##   stat / stat_per_damage, rounded, between min_damage and max_damage
##   (STR 20 = 4). Every player hit is converted to this scale where it lands,
##   keeping its size relative to a basic swing (a special that hit twice as
##   hard as a swing still does, up to the cap).
## - Every enemy hit on the player does enemy_hit_damage (1) once blocks and
##   shields have had their say (a fully blocked hit still does nothing).
## - Enemy health is multiplied by enemy_health_scale when they spawn, so a
##   fight takes about as many hits as before.
##
## Set "enabled": false to go back to the old numbers.

static func rules() -> Dictionary:
	return Dictionary(GameBalance.get_slasher_balance("simple_combat"))

static func enabled() -> bool:
	return bool(rules().get("enabled",false))

## Isaac-style health: health is counted in half hearts (units_per_heart = 2).
## Ordinary hits take half a heart (enemy_hit_damage), hits from bosses, mini
## bosses and champions (elites) a full heart (strong_hit_damage). Soul hearts
## sit on top and take damage first. Everything together caps at max_total_hearts.
static func units_per_heart() -> int:
	return maxi(1,int(rules().get("units_per_heart",1)))

## Health (in half hearts) from Constitution.
static func health_for(constitution: int) -> int:
	return hearts_for(constitution) * units_per_heart()

static func max_health_units() -> int:
	return int(rules().get("max_total_hearts",12)) * units_per_heart()

## How much one enemy hit takes: half a heart, or a full heart from the big ones.
static func hit_from(attacker: Node) -> int:
	var strong: bool = is_instance_valid(attacker) and (("boss" in attacker and bool(attacker.get("boss"))) or ("mini_boss" in attacker and bool(attacker.get("mini_boss"))) or ("elite" in attacker and bool(attacker.get("elite"))))
	return int(rules().get("strong_hit_damage",2)) if strong else enemy_hit_damage()

## Hearts from Constitution.
static func hearts_for(constitution: int) -> int:
	var r := rules()
	return maxi(int(r.get("min_hearts",1)),int(round(float(constitution) / float(r.get("con_per_heart",4)))))

## Damage per hit from the main stat.
static func damage_for(stat_value: int) -> int:
	var r := rules()
	return clampi(int(round(float(stat_value) / float(r.get("stat_per_damage",5)))),int(r.get("min_damage",1)),int(r.get("max_damage",4)))

## Which attribute drives a class's damage (the Fighter's is Strength).
static func damage_stat(class_id: String) -> String:
	return String(Dictionary(rules().get("damage_stat_by_class",{})).get(class_id,"str"))

## A player hit converted to the simple scale: base damage times how big this
## hit was next to the player's ordinary swing, rounded, capped.
static func player_hit(amount: int, reference: int, base: int) -> int:
	if amount <= 0: return 0
	var r := rules()
	var ratio := float(amount) / float(maxi(1,reference))
	return clampi(int(round(base * ratio)),int(r.get("min_damage",1)),int(r.get("max_damage",4)))

static func enemy_hit_damage() -> int:
	return int(rules().get("enemy_hit_damage",1))

static func enemy_health(health: int) -> int:
	return maxi(1,int(round(health * float(rules().get("enemy_health_scale",1.0)))))

# ---------------------------------------------------------------- what each stat does
##   STR  damage with strength weapons (swords, spears, hammers, shields)
##   DEX  movement speed for every class, damage with dexterity weapons
##        (daggers, bows, slings) and a dodge chance. Items that make you faster
##        add Dexterity ("dex" in their stats).
##   CON  hearts
##   INT  magic strength (spells)
##   WIS  summon strength
##   CHA  trader prices and training odds at the Hearth; can't be trained

## The stat a weapon hits with (weapon_stats), else the class's default.
static func weapon_stat(weapon_id: String, class_id: String) -> String:
	var stats: Dictionary = Dictionary(rules().get("weapon_stats",{}))
	return String(stats[weapon_id]) if stats.has(weapon_id) else damage_stat(class_id)

## Tests that need every hit to land set this to 0 (-1 = use Dexterity).
static var dodge_override := -1.0

## Chance (0..1) to dodge a hit completely, from Dexterity above 10.
static func dodge_chance(dexterity: int) -> float:
	if dodge_override >= 0.0: return dodge_override
	var r := rules()
	return clampf(maxi(0,dexterity - 10) * float(r.get("dodge_per_dex_point",0.01)),0.0,float(r.get("dodge_max",0.15)))

## Walking speed (pixels a second) from Dexterity, the same for every class:
## move_speed_base at DEX 10, plus move_speed_per_dex for each point above
## (or minus for each below), kept between move_speed_min and move_speed_max.
static func move_speed(dexterity: int) -> float:
	var r := rules()
	var speed := float(r.get("move_speed_base",265.0)) + float(dexterity - 10) * float(r.get("move_speed_per_dex",10.0))
	return clampf(speed,float(r.get("move_speed_min",180.0)),float(r.get("move_speed_max",420.0)))

## Price multiplier from Charisma (CHA 20 = 30% off, CHA 6 = 12% dearer).
static func price_factor(charisma: int) -> float:
	var r := rules()
	var limits: Array = Array(r.get("charisma_price_limits",[0.7,1.3]))
	return clampf(1.0 - (charisma - 10) * float(r.get("charisma_price_per_point",0.03)),float(limits[0]),float(limits[1]))

static func price(base: int, charisma: int) -> int:
	if not enabled(): return base
	return maxi(1,int(round(base * price_factor(charisma))))

## Training chance bonus (percentage points) from Charisma.
static func training_bonus(charisma: int) -> int:
	if not enabled(): return 0
	return (charisma - 10) * int(rules().get("charisma_training_per_point",2))

static func trainable(stat: String) -> bool:
	return not (enabled() and Array(rules().get("untrainable_stats",[])).has(stat))

static func describe(stat: String) -> String:
	return String(Dictionary(rules().get("stat_descriptions",{})).get(stat,""))
