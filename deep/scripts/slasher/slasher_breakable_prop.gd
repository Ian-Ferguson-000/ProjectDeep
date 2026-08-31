extends StaticBody2D
class_name SlasherBreakableProp

signal broken(prop:SlasherBreakableProp,kind:String,cell:Vector2i)
signal opened(prop:SlasherBreakableProp,cell:Vector2i)

var prop_kind:="rock"
var cell:=Vector2i.ZERO
var health:=4
var maximum_health:=4
var destroyed:=false
var is_open:=false
var tuning:Dictionary={}
var sprite:Sprite2D
var collision:CollisionShape2D

func setup(kind:String,grid_cell:Vector2i)->void:
	prop_kind=kind;cell=grid_cell;var records:Dictionary=GameBalance.get_slasher_balance("breakable_props");tuning=Dictionary(records.get(kind,{}))
	health=maxi(1,int(tuning.get("health",6)));maximum_health=health

func _ready()->void:
	add_to_group("slasher_damageable");collision=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=float(tuning.get("collision_radius",17.0));collision.shape=circle;add_child(collision)
	sprite=SlasherForestArt.make_sprite(prop_kind);sprite.position=Vector2(0,-8);add_child(sprite)
	if prop_kind=="chest":add_to_group("slasher_chest")

func receive_attack(attack:Dictionary,attacker:SlasherPlayer=null)->int:
	if destroyed or is_open:return 0
	var amount:int=maxi(1,int(attack.get("damage",1)));health=maxi(0,health-amount)
	if is_instance_valid(attacker):attacker.add_impact_shake(2.5*float(attack.get("screen_shake_multiplier",1.0)),0.11)
	if sprite!=null:
		var tween:=create_tween();tween.tween_property(sprite,"modulate",Color(1.8,1.8,1.8,1),0.04);tween.tween_property(sprite,"modulate",Color.WHITE,0.10)
	if health<=0:_break()
	return amount

func _break()->void:
	if destroyed:return
	destroyed=true;remove_from_group("slasher_damageable");collision.set_deferred("disabled",true);broken.emit(self,prop_kind,cell)
	var duration:float=float(tuning.get("break_duration",0.24));var tween:=create_tween();tween.set_parallel(true);tween.tween_property(sprite,"scale",sprite.scale*1.2,duration);tween.tween_property(sprite,"modulate:a",0.0,duration);tween.tween_property(sprite,"position:y",sprite.position.y+10.0,duration);tween.chain().tween_callback(queue_free)

func open_chest()->bool:
	if prop_kind!="chest" or destroyed or is_open:return false
	is_open=true;remove_from_group("slasher_damageable");remove_from_group("slasher_chest");collision.set_deferred("disabled",true)
	var tween:=create_tween();tween.tween_property(sprite,"position:y",sprite.position.y-5.0,0.10);tween.tween_property(sprite,"modulate",Color("#ffe49a"),0.12);opened.emit(self,cell);return true

static func deterministic_gold_drop(run_seed:int,floor_number:int,grid_cell:Vector2i,kind:String,drop_tuning:Dictionary)->Dictionary:
	var chance_percent:int=int(round(float(drop_tuning.get("gold_chance",0.12))*100.0));var roll_seed:int=run_seed+floor_number*83492791+grid_cell.x*73856093+grid_cell.y*19349663+kind.hash()
	if posmod(roll_seed,100)>=chance_percent:return {"drops":false,"amount":0}
	var minimum:int=int(drop_tuning.get("gold_min",1));var maximum:int=maxi(minimum,int(drop_tuning.get("gold_max",3)));return {"drops":true,"amount":minimum+posmod(floori(float(roll_seed)/101.0),maximum-minimum+1)}

static func deterministic_chest_reward(run_seed:int,floor_number:int,grid_cell:Vector2i,chest_tuning:Dictionary)->Dictionary:
	var reward_seed:int=run_seed+floor_number*961748927+grid_cell.x*73856093+grid_cell.y*19349663
	var minimum:int=int(chest_tuning.get("open_gold_min",4));var maximum:int=maxi(minimum,int(chest_tuning.get("open_gold_max",8)));var potion_chance:int=int(round(float(chest_tuning.get("open_potion_chance",0.25))*100.0))
	return {"gold":minimum+posmod(reward_seed,maximum-minimum+1),"potion":posmod(floori(float(reward_seed)/103.0),100)<potion_chance}
