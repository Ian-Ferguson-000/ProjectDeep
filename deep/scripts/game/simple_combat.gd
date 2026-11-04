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
