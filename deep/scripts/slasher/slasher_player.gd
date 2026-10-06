extends CharacterBody2D
class_name SlasherPlayer
const SETTINGS_SERVICE:=preload("res://scripts/game/game_settings.gd")
const REQUIRED_INPUT_ACTIONS:Array[StringName]=[
	&"slasher_left",&"slasher_right",&"slasher_up",&"slasher_down",
	&"slasher_aim_left",&"slasher_aim_right",&"slasher_aim_up",&"slasher_aim_down",
	&"slasher_controller_basic",&"slasher_mobility",&"slasher_special",&"slasher_defend"
]

signal health_changed(current:int,maximum:int)
signal resource_changed(current:int,maximum:int)
signal combo_updated(state:Dictionary)

const PYROMANCY := preload("res://scripts/slasher/slasher_pyromancy.gd")
const MAGE_KITS := preload("res://scripts/slasher/slasher_mage_kits.gd")
var pyromancy: Node2D
var mage_kit: Node2D
const WARRIOR_KITS := preload("res://scripts/slasher/slasher_warrior_kits.gd")
var warrior_kit: Node2D
var warrior_combo_effects: Node2D
var kit_buffs: Node

var resource_suppression_time:=0.0
var resource_regen_accumulator:=0.0
signal ability_resolved(result:Dictionary)
signal defeated

const PROJECTILE:=preload("res://scripts/slasher/slasher_projectile.gd")
const ITEM_RUNTIME:=preload("res://scripts/slasher/slasher_item_runtime.gd")
const COMBO_RUNTIME:=preload("res://scripts/slasher/slasher_combo_runtime.gd")
var run_state:RunState
var pathfinder:SlasherGridPathfinder
var grid_navigator:=SlasherGridNavigator.new()
var class_id:="warrior"
var max_health:=20
var health:=20
var speed:=185.0
var attack_power:=4
var spell_power:=4
var cooldowns:={"basic":0.0,"special":0.0,"defensive":0.0,"movement":0.0}
var invulnerable:=0.0
var defense_window:=0.0
var defense_kind:=""
var _receiving_projectile := false
var empowered:=false
var is_hidden:=false
var hidden_time:=0.0
var marked_enemy:SlasherEnemy
var companion:CharacterBody2D
var last_direction:=Vector2.RIGHT
var aim_direction:=Vector2.RIGHT
var facing_name:="right"
var sprite:AnimatedSprite2D
var animation_lock:=0.0
var presentation_ready:=false
var retribution_stored:=0
var input_locked:=false
var position_sanitizer:Callable
var camera:Camera2D
var screen_shake_time:=0.0
var screen_shake_duration:=0.0
var screen_shake_strength:=0.0
var basic_mouse_held:=false
var warrior_dash_active:=false
var warrior_dash_destination:=Vector2.ZERO
var warrior_dash_speed:=0.0
var warrior_dash_attack:Dictionary={}
var warrior_dash_hit_ids:Dictionary={}
var warrior_dash_resource_gain:=0
var warrior_dash_resource_awarded:=false
var warrior_dash_landing_invulnerability:=0.0
var item_runtime:SlasherItemRuntime
var active_action_slot:="basic"
var consumable_aegis:=0
var consumable_speed_time:=0.0
var consumable_speed_multiplier:=1.0
var movement_debuff_multiplier:=1.0
var local_settings:Node
func _settings()->Node:
	var singleton:=get_node_or_null("/root/GameSettings")
	if singleton!=null:return singleton
	if local_settings==null:local_settings=SETTINGS_SERVICE.new();local_settings.values=SETTINGS_SERVICE.DEFAULTS.duplicate(true)
	return local_settings
var movement_debuff_time:=0.0
var next_attack_multiplier:=1.0
var mage_combo_effects: Node2D
var combo_runtime
var resolving_combo:Dictionary={}
var last_fireball_attack:Dictionary={}
var combo_cast_serial:=0
var combo_proc_targets:Dictionary={}
var warrior_slash_chain:=0
var warrior_slash_chain_time:=0.0

func snapshot_party_state()->Dictionary:
	var state:={"cooldowns":cooldowns.duplicate(true),"invulnerable":invulnerable,"defense_window":defense_window,"defense_kind":defense_kind,"empowered":empowered,"is_hidden":is_hidden,"hidden_time":hidden_time,"retribution_stored":retribution_stored,"consumable_aegis":consumable_aegis,"consumable_speed_time":consumable_speed_time,"consumable_speed_multiplier":consumable_speed_multiplier,"movement_debuff_time":movement_debuff_time,"movement_debuff_multiplier":movement_debuff_multiplier,"next_attack_multiplier":next_attack_multiplier,"last_fireball_attack":last_fireball_attack.duplicate(true),"warrior_slash_chain":warrior_slash_chain,"warrior_slash_chain_time":warrior_slash_chain_time,"last_direction":[last_direction.x,last_direction.y],"aim_direction":[aim_direction.x,aim_direction.y],"marked_enemy_instance_id":marked_enemy.get_instance_id() if is_instance_valid(marked_enemy) else 0}
	if combo_runtime!=null:state["combo"]=combo_runtime.snapshot()
	if item_runtime!=null:state["item_runtime"]={"cooldowns":item_runtime.cooldowns.duplicate(true),"floor_uses":item_runtime.floor_uses.duplicate(true),"precision_count":item_runtime.precision_count}
	return state

func restore_party_state(state:Dictionary)->void:
	cooldowns=Dictionary(state.get("cooldowns",{"basic":0.0,"special":0.0,"defensive":0.0,"movement":0.0})).duplicate(true);invulnerable=float(state.get("invulnerable",0.0));defense_window=float(state.get("defense_window",0.0));defense_kind=String(state.get("defense_kind",""));empowered=bool(state.get("empowered",false));is_hidden=bool(state.get("is_hidden",false));hidden_time=float(state.get("hidden_time",0.0));retribution_stored=int(state.get("retribution_stored",0));consumable_aegis=int(state.get("consumable_aegis",0));consumable_speed_time=float(state.get("consumable_speed_time",0.0));consumable_speed_multiplier=float(state.get("consumable_speed_multiplier",1.0));movement_debuff_time=float(state.get("movement_debuff_time",0.0));movement_debuff_multiplier=float(state.get("movement_debuff_multiplier",1.0));next_attack_multiplier=float(state.get("next_attack_multiplier",1.0));last_fireball_attack=Dictionary(state.get("last_fireball_attack",{})).duplicate(true);warrior_slash_chain=int(state.get("warrior_slash_chain",0));warrior_slash_chain_time=float(state.get("warrior_slash_chain_time",0.0))
	var direction:Array=state.get("last_direction",[]);if direction.size()>=2:last_direction=Vector2(float(direction[0]),float(direction[1]))
	var aim:Array=state.get("aim_direction",[]);if aim.size()>=2:aim_direction=Vector2(float(aim[0]),float(aim[1]))
	var marked_id:=int(state.get("marked_enemy_instance_id",0));marked_enemy=instance_from_id(marked_id) as SlasherEnemy if marked_id>0 else null
	if item_runtime!=null:
		var item_state:Dictionary=Dictionary(state.get("item_runtime",{}));item_runtime.cooldowns=Dictionary(item_state.get("cooldowns",{})).duplicate(true);item_runtime.floor_uses=Dictionary(item_state.get("floor_uses",{})).duplicate(true);item_runtime.precision_count=int(item_state.get("precision_count",0))
	if combo_runtime!=null:combo_runtime.restore(Dictionary(state.get("combo",{})))
	velocity=Vector2.ZERO;basic_mouse_held=false;animation_lock=0.0;warrior_dash_active=false;warrior_dash_hit_ids.clear()

func setup(state:RunState)->void:
	run_state=state;class_id=state.selected_class_id
	if is_instance_valid(warrior_kit):remove_child(warrior_kit);warrior_kit.queue_free()
	if is_instance_valid(warrior_combo_effects):remove_child(warrior_combo_effects);warrior_combo_effects.queue_free()
	if is_instance_valid(kit_buffs):remove_child(kit_buffs);kit_buffs.queue_free()
	warrior_kit=null;warrior_combo_effects=null
	kit_buffs=preload("res://scripts/slasher/slasher_combat_buffs.gd").new();kit_buffs.actor=self;add_child(kit_buffs)
	if class_id=="warrior" and state.selected_gear!=null and WARRIOR_KITS.has_kit(state.selected_gear.id):
		warrior_kit=WARRIOR_KITS.KIT.new();warrior_kit.configure(self,state.selected_gear.id,WARRIOR_KITS.DATA[state.selected_gear.id].actions);add_child(warrior_kit)
	if class_id=="warrior":
		warrior_combo_effects=preload("res://scripts/slasher/slasher_warrior_combo_effects.gd").new();warrior_combo_effects.configure(self,state.selected_gear.id if uses_warrior_kit() else "standard",{});add_child(warrior_combo_effects)
	if is_instance_valid(mage_kit):
		remove_child(mage_kit);mage_kit.queue_free()
	mage_kit=null;pyromancy=null
	var kit_script := MAGE_KITS.script_for(state.selected_gear.id if state.selected_gear!=null else "")
	if kit_script!=null:
		mage_kit=kit_script.new();mage_kit.name="MageKit";mage_kit.setup(self);add_child(mage_kit)
		if uses_pyromancy():pyromancy=mage_kit
	if combo_runtime==null:combo_runtime=COMBO_RUNTIME.new()
	if is_instance_valid(mage_combo_effects):remove_child(mage_combo_effects);mage_combo_effects.queue_free()
	mage_combo_effects=null
	if class_id=="mage":
		mage_combo_effects=preload("res://scripts/slasher/slasher_mage_combo_effects.gd").new()
		mage_combo_effects.configure(self,state.selected_gear.id if uses_mage_kit() else "standard");add_child(mage_combo_effects)
	_configure_combos();resolving_combo={}
	var tuning:Dictionary=GameBalance.get_slasher_class_tuning(class_id)
	speed=float(tuning.get("speed",speed));max_health=state.max_health;health=state.current_health
	attack_power=maxi(2,state.get_derived_stat("attack_power")+(state.selected_gear.damage if state.selected_gear else 1))
	spell_power=maxi(2,state.get_derived_stat("spell_potency")+(state.selected_gear.damage if state.selected_gear else 1))
	if item_runtime!=null:item_runtime.setup(state,self)
	var hitbox:=get_node_or_null("PlayerHitbox") as CollisionShape2D
	if hitbox!=null and hitbox.shape is CircleShape2D:(hitbox.shape as CircleShape2D).radius=float(tuning.get("collision_radius",18.0))
	if is_inside_tree():_refresh_presentation()

func _ready()->void:
	_ensure_input_actions_exist()
	add_to_group("slasher_player")
	item_runtime=ITEM_RUNTIME.new();item_runtime.name="SlasherItemRuntime";add_child(item_runtime);item_runtime.setup(run_state,self)
	if combo_runtime==null:combo_runtime=COMBO_RUNTIME.new();_configure_combos()
	var shape:=CollisionShape2D.new();shape.name="PlayerHitbox";var circle:=CircleShape2D.new();circle.radius=float(GameBalance.get_slasher_class_tuning(class_id).get("collision_radius",18.0));shape.shape=circle;add_child(shape);_refresh_presentation()

func _ensure_input_actions_exist()->void:
	for action:StringName in REQUIRED_INPUT_ACTIONS:
		if not InputMap.has_action(action):InputMap.add_action(action)

func _refresh_presentation()->void:
	if sprite==null:sprite=AnimatedSprite2D.new();sprite.name="AnimatedSprite2D";add_child(sprite)
	var tuning:Dictionary=GameBalance.get_slasher_class_tuning(class_id)
	sprite.sprite_frames=SlasherSpriteLibrary.player_frames(class_id);sprite.position=Vector2(float(tuning.get("sprite_offset_x",0.0)),float(tuning.get("sprite_offset_y",-30.0)));sprite.scale=Vector2.ONE*float(tuning.get("sprite_scale",0.9));presentation_ready=true;_play_animation("idle");queue_redraw()

func _physics_process(delta:float)->void:
	if combo_runtime!=null and combo_runtime.tick(delta):combo_updated.emit({"type":"progress","progress":combo_runtime.feedback()})
	warrior_slash_chain_time=maxf(0.0,warrior_slash_chain_time-delta)
	if warrior_slash_chain_time<=0.0:warrior_slash_chain=0
	resource_suppression_time=maxf(0.0,resource_suppression_time-delta)
	if run_state!=null and resource_suppression_time<=0.0 and run_state.class_resource<run_state.get_class_resource_max():
		resource_regen_accumulator += delta*float(run_state.get_class_resource_rules(class_id).get("regen_per_second",0.35))
		if resource_regen_accumulator>=1.0:
			var restored:=floori(resource_regen_accumulator);resource_regen_accumulator-=restored;run_state.gain_class_resource(restored);resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max())
	for key in cooldowns:cooldowns[key]=maxf(0.0,float(cooldowns[key])-delta)
	var was_invulnerable:=invulnerable>0.0
	invulnerable=maxf(0.0,invulnerable-delta);defense_window=maxf(0.0,defense_window-delta);animation_lock=maxf(0.0,animation_lock-delta);hidden_time=maxf(0.0,hidden_time-delta)
	if was_invulnerable or invulnerable>0.0:queue_redraw()
	consumable_speed_time=maxf(0.0,consumable_speed_time-delta)
	if consumable_speed_time<=0.0:consumable_speed_multiplier=1.0
	movement_debuff_time=maxf(0.0,movement_debuff_time-delta)
	if movement_debuff_time<=0.0:movement_debuff_multiplier=1.0
	if movement_debuff_time>0.0:queue_redraw()
	if hidden_time<=0.0:is_hidden=false
	_update_screen_shake(delta)
	if defense_window<=0.0 and defense_kind!="retribution_ready":defense_kind=""
	_update_aim()
	if warrior_dash_active:_process_warrior_dash(delta);return
	if input_locked:basic_mouse_held=false;velocity=Vector2.ZERO;return
	var direction:=Input.get_vector("slasher_left","slasher_right","slasher_up","slasher_down")
	if direction.length()>0.1:last_direction=direction.normalized()
	var kit_speed: float=mage_kit.movement_speed_multiplier() if is_instance_valid(mage_kit) and mage_kit.has_method("movement_speed_multiplier") else 1.0
	velocity=direction*speed*kit_speed*(kit_buffs.speed_multiplier() if is_instance_valid(kit_buffs) else 1.0)*consumable_speed_multiplier*movement_debuff_multiplier*(item_runtime.conversion("speed_multiplier",1.0) if item_runtime else 1.0);move_and_slide()
	_enforce_field_bounds()
	if animation_lock<=0.0:_play_animation("run" if direction.length()>0.1 else "idle")
	if Input.is_action_just_pressed("slasher_controller_basic"):use_action("basic", "controller")
	if Input.is_action_just_pressed("slasher_mobility"):use_action("movement", "controller")
	if Input.is_action_just_pressed("slasher_special"):use_action("special", "keyboard" if Input.is_physical_key_pressed(KEY_SPACE) else "controller")
	if Input.is_action_just_pressed("slasher_defend"):use_action("defensive", "controller")
	if basic_mouse_held and not Input.is_key_pressed(KEY_SHIFT) and float(cooldowns.get("basic",0.0))<=0.0:
		var held_result:Dictionary=use_action("basic", "mouse")
		if bool(held_result.get("started",false)):cooldowns.basic=float(cooldowns.basic)*float(GameBalance.get_slasher_balance("input").get("held_basic_cooldown_multiplier",2.25))

func _unhandled_input(event:InputEvent)->void:
	if input_locked:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:
				basic_mouse_held=not event.shift_pressed;use_action("defensive" if event.shift_pressed else "basic", "mouse_shift" if event.shift_pressed else "mouse")
			else:basic_mouse_held=false
			get_viewport().set_input_as_handled()
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:use_action("movement", "mouse");get_viewport().set_input_as_handled()

func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:basic_mouse_held=false

func use_action(slot:String,input_source:String="system")->Dictionary:
	var result:={"started":false,"slot":slot,"class_id":class_id,"input_source":input_source,"targets_hit":0,"projectiles_deflected":0,"resource_gained":0,"resource_spent":0,"damage_prevented":0,"failure":""}
	if float(cooldowns.get(slot,0.0))>0.0:result.failure="%s is cooling down."%_action_name(slot);ability_resolved.emit(result);return result
	var tuning:Dictionary=_ability_tuning(slot)
	var default_cost:=2 if slot=="special" else (int(run_state.get_class_resource_rules(class_id).get("movement_cost",1)) if slot=="movement" else 0)
	var resource_cost:=int(tuning.get("resource_cost",default_cost))
	if slot=="movement" and resource_cost<=0 and not uses_mage_kit() and not uses_warrior_kit(): resource_cost=default_cost
	var combo_before:Dictionary=combo_runtime.snapshot() if combo_runtime!=null else {}
	var combo_outcome:Dictionary=combo_runtime.record_action(slot) if combo_runtime!=null else {"triggered":{},"progress":{}}
	resolving_combo=Dictionary(combo_outcome.get("triggered",{}))
	var combo_effect:Dictionary=Dictionary(resolving_combo.get("effect",{}))
	if combo_effect.has("resource_cost_override"):resource_cost=int(combo_effect.resource_cost_override)
	if resource_cost>0 and not run_state.spend_class_resource(resource_cost):
		if combo_runtime!=null:combo_runtime.restore(combo_before)
		resolving_combo={};result.failure="Not enough %s."%run_state.get_class_resource_name();ability_resolved.emit(result);return result
	result.started=true
	var combo_context: Dictionary=mage_combo_effects.capture() if is_instance_valid(mage_combo_effects) else warrior_combo_effects.capture() if is_instance_valid(warrior_combo_effects) else {}
	active_action_slot=slot
	if uses_warrior_kit():
		result=warrior_kit.perform(slot,result)
	elif uses_mage_kit():
		result=mage_kit.perform(slot,result)
	else:
		match slot:
			"basic":result=_basic(result)
			"movement":result=_movement(result)
			"special":result=_special(result)
			"defensive":result=_defensive(result)
	if not bool(result.get("started",false)):
		if combo_runtime!=null:combo_runtime.restore(combo_before)
		resolving_combo={}
		if resource_cost>0:run_state.gain_class_resource(resource_cost)
		resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max());ability_resolved.emit(result);return result
	if is_instance_valid(mage_combo_effects):mage_combo_effects.accept_action(slot,combo_context)
	if is_instance_valid(warrior_combo_effects):warrior_combo_effects.accept_action(slot,combo_context)
	if class_id=="warrior" and slot!="basic":warrior_slash_chain=0;warrior_slash_chain_time=0.0
	if not resolving_combo.is_empty():
		if is_instance_valid(mage_combo_effects) and bool(combo_effect.get("mage_combo",false)):mage_combo_effects.execute(resolving_combo)
		if is_instance_valid(warrior_combo_effects) and bool(combo_effect.get("warrior_combo",false)):warrior_combo_effects.execute(resolving_combo)
		result["combo_id"]=String(resolving_combo.get("id",""));result["combo_name"]=String(resolving_combo.get("name",""))
		combo_updated.emit({"type":"triggered","combo":resolving_combo.duplicate(true)})
	elif combo_runtime!=null:combo_updated.emit({"type":"progress","progress":combo_runtime.feedback()})
	for confirmation in Array(result.get("combo_confirmations",[])):_record_combo_confirmation(String(confirmation))
	if combo_effect.has("reset_cooldown"):cooldowns[String(combo_effect.reset_cooldown)]=0.0
	resolving_combo={}
	if int(result.get("targets_hit",0))>0 and int(tuning.get("resource_refund_on_hit",0))>0:_gain_resource(result,int(tuning.resource_refund_on_hit))
	result.resource_spent=resource_cost
	cooldowns[slot]=float(result.get("cooldown_override",tuning.get("cooldown",0.4 if slot=="basic" else 3.0)))*(item_runtime.cooldown_multiplier() if item_runtime else 1.0)
	resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max());_play_action_animation(_action_animation_state(slot),float(cooldowns[slot]));animation_lock=minf(float(tuning.get("animation_lock",0.32)),float(cooldowns[slot]));ability_resolved.emit(result);return result

func _action_animation_state(slot:String)->String:
	# The standard Mage's blink/repel artwork is blue; the fire kit draws its own effects.
	if uses_mage_kit() and slot in ["movement","defensive"]:return "idle"
	if class_id!="warrior":return slot
	if slot=="special" or slot=="defensive":return slot
	return "attack"

func _basic(result:Dictionary)->Dictionary:
	var tuning:=_ability_tuning("basic")
	match class_id:
		"mage","healer":_spawn_projectile(_configured_attack(tuning,"arcane" if class_id=="mage" else "radiant"),true)
		"summoner":
			marked_enemy=_enemy_near_aim(float(tuning.get("target_range",360.0)),float(tuning.get("aim_dot_threshold",0.8)));_ensure_companion()
			if is_instance_valid(marked_enemy):companion.set_meta("marked",marked_enemy);result.targets_hit=1;_gain_resource(result,int(tuning.get("resource_gain",1)))
			else:companion.set_meta("command_position",global_position+aim_direction*float(tuning.get("command_distance",180.0)))
		_:
			var attack:=_configured_attack(tuning,"physical")
			if class_id=="warrior":
				if warrior_slash_chain_time<=0.0:warrior_slash_chain=0
				warrior_slash_chain+=1
				if warrior_slash_chain>=3:result["cooldown_override"]=float(tuning.get("combo_finisher_cooldown",0.90));result["basic_chain_complete"]=true;warrior_slash_chain=0;warrior_slash_chain_time=0.0
				else:result["cooldown_override"]=float(tuning.get("cooldown",0.18));warrior_slash_chain_time=float(tuning.get("combo_reset_window",0.70))
			if class_id=="warrior" and String(resolving_combo.get("id",""))=="crosscut":
				var effect:Dictionary=Dictionary(resolving_combo.get("effect",{}));attack.damage=maxi(1,int(round(float(attack.damage)*float(effect.get("damage_multiplier",2.0)))));attack.knockback=float(attack.get("knockback",0.0))*float(effect.get("knockback_multiplier",2.0));attack.screen_shake_multiplier=float(effect.get("screen_shake_multiplier",1.6));attack.critical=true;result.critical=true
			if class_id=="rogue":result.targets_hit=_line_attack(global_position,global_position+aim_direction*float(attack.get("reach",72.0)),float(attack.get("line_radius",18.0)),attack);is_hidden=false;hidden_time=0.0
			else:result.targets_hit=_melee_attack(attack)
			result.projectiles_deflected=_deflect_projectiles(float(tuning.get("deflect_reach",tuning.get("reach",0.0))),float(tuning.get("deflect_arc_degrees",tuning.get("arc_degrees",0.0))))
			if result.targets_hit>0:_gain_resource(result,int(tuning.get("resource_gain",1)))
	return result

func _special(result:Dictionary)->Dictionary:
	var tuning:=_ability_tuning("special")
	match class_id:
		"warrior":
			var attack:=_configured_attack(tuning,"physical");var normal_damage:=int(attack.damage);var combo_id:=String(resolving_combo.get("id",""));var effect:Dictionary=Dictionary(resolving_combo.get("effect",{}))
			if combo_id in ["break_the_line","vengeful_spiral"]:
				attack.damage=maxi(1,int(round(float(attack.damage)*float(effect.get("damage_multiplier",1.25)))));attack.arc_degrees=float(effect.get("arc_degrees",360.0));attack.knockback=float(effect.get("knockback",attack.get("knockback",30.0)))
				if effect.has("status"):attack.status=String(effect.status);attack.status_duration=float(effect.get("status_duration",0.5))
			result.targets_hit=_melee_attack(attack)
			if combo_id=="vengeful_spiral":
				_gain_resource(result,int(effect.get("resource_refund",1)))
				var echo:=attack.duplicate(true);echo.damage=maxi(1,int(round(normal_damage*float(effect.get("echo_damage_multiplier",0.60)))));echo.erase("status");echo.erase("status_duration")
				get_tree().create_timer(float(effect.get("echo_delay",0.18))).timeout.connect(func():
					if is_instance_valid(self) and class_id=="warrior":_melee_attack(echo))
		"mage":
			var attack:=_configured_attack(tuning,"arcane");last_fireball_attack=attack.duplicate(true);var combo_id:=String(resolving_combo.get("id",""));var effect:Dictionary=Dictionary(resolving_combo.get("effect",{}));var cast_id:=_next_combo_cast_id() if not combo_id.is_empty() else ""
			if combo_id=="spellstorm_volley":
				var spread:=deg_to_rad(float(effect.get("spread_degrees",12.0)));var multiplier:=float(effect.get("damage_multiplier",0.45))
				for angle in [-spread,0.0,spread]:var projectile_attack:=attack.duplicate(true);projectile_attack.damage=maxi(1,int(round(float(attack.damage)*multiplier)));_spawn_projectile(projectile_attack,false,aim_direction.rotated(float(angle)),global_position+aim_direction.rotated(float(angle))*24.0,cast_id)
			elif combo_id=="force_prism":
				attack.force_prism=true;attack.force_prism_effect=effect.duplicate(true);_spawn_projectile(attack,false,aim_direction,global_position+aim_direction*24.0,cast_id)
			else:_spawn_projectile(attack,false)
		"healer":empowered=true
		"tank":defense_kind="retribution_ready";defense_window=float(tuning.get("effect_duration",2.0));retribution_stored=0
		"rogue":
			var target:=_enemy_near_aim(float(tuning.get("target_range",100.0)),float(tuning.get("aim_dot_threshold",0.65)))
			if target:
				var isolated:=_nearby_enemy_count(target.global_position,float(tuning.get("isolation_radius",95.0)))<=1
				var low_health:=float(target.health)/maxf(1.0,float(target.max_health))<float(tuning.get("low_health_fraction",0.5))
				var coefficient:=float(tuning.get("bonus_damage_coefficient",3.0)) if is_hidden or isolated or low_health else float(tuning.get("damage_coefficient",2.0))
				var attack:=_configured_attack(tuning,"physical");attack.damage=_scaled_damage(tuning,coefficient);target.receive_attack(attack,self);result.targets_hit=1;is_hidden=false;hidden_time=0.0
			else:result.started=false;result.failure="No target in Assassinate range."
		"summoner":
			_ensure_companion()
			if is_instance_valid(marked_enemy):companion.set_meta("marked",marked_enemy);companion.set_meta("pounce",true);result.targets_hit=1
	return result

func _movement(result:Dictionary)->Dictionary:
	var tuning:=_ability_tuning("movement");var distance:=float(tuning.get("movement_distance",150.0));var start:=global_position;var intended_destination:=global_position+aim_direction*distance
	if class_id=="warrior":
		warrior_dash_destination=_safe_destination(intended_destination,float(tuning.get("destination_clearance",22.0)))
		if warrior_dash_destination.is_equal_approx(global_position):result.started=false;result.failure="Charge has no clear path.";return result
		warrior_dash_speed=maxf(1.0,float(tuning.get("dash_speed",1100.0)))
		warrior_dash_attack=_configured_attack(tuning,"physical");warrior_dash_hit_ids.clear();warrior_dash_resource_gain=int(tuning.get("resource_gain",0));warrior_dash_resource_awarded=false
		warrior_dash_landing_invulnerability=float(tuning.get("landing_invulnerability",0.08));warrior_dash_active=not warrior_dash_destination.is_equal_approx(global_position)
		var dash_duration:=global_position.distance_to(warrior_dash_destination)/warrior_dash_speed
		var dash_invulnerability:=maxf(float(tuning.get("invulnerability",0.0)),dash_duration+warrior_dash_landing_invulnerability)
		invulnerable=maxf(invulnerable,dash_invulnerability);result["invulnerability_granted"]=dash_invulnerability;result["dash_duration"]=dash_duration;queue_redraw();return result
	if class_id=="rogue":
		var shadow_target:=_enemy_near_aim(distance,float(tuning.get("aim_dot_threshold",0.72)))
		if is_instance_valid(shadow_target):intended_destination=shadow_target.global_position+aim_direction*float(tuning.get("pass_through_distance",36.0));result["passed_through_target"]=true
	var resolved_destination:=_safe_destination(intended_destination,float(tuning.get("destination_clearance",22.0)))
	if resolved_destination.is_equal_approx(global_position):result.started=false;result.failure="%s has no clear destination."%_action_name("movement");return result
	global_position=resolved_destination
	# Mobility protection begins after destination resolution, making Blink and every other movement
	# ability safe on landing without extending the window by its travel calculation.
	var landing_invulnerability:=maxf(0.05,float(tuning.get("invulnerability",0.05)))
	invulnerable=maxf(invulnerable,landing_invulnerability)
	result["invulnerability_granted"]=landing_invulnerability
	queue_redraw()
	if class_id=="mage" and String(resolving_combo.get("id",""))=="riftburst":
		var effect:Dictionary=Dictionary(resolving_combo.get("effect",{}));var attack:=last_fireball_attack.duplicate(true)
		if attack.is_empty():attack=_configured_attack(_ability_tuning("special"),"arcane")
		attack.damage=maxi(1,int(round(float(attack.damage)*float(effect.get("damage_multiplier",0.75)))));attack.area_radius=float(effect.get("area_radius",105.0));attack.knockback=float(effect.get("knockback",35.0));attack.erase("echo_damage_multiplier")
		result.targets_hit=_area_attack(start,float(attack.area_radius),attack)
	match class_id:
		"healer":
			if global_position.distance_to(start)>=float(tuning.get("heal_travel_threshold",80.0)):heal(_scaled_heal(tuning))
		"tank":result.targets_hit=_area_attack(global_position,float(tuning.get("area_radius",72.0)),_configured_attack(tuning,"physical"))
		"rogue":
			is_hidden=true;hidden_time=float(tuning.get("hidden_duration",0.5))
			if Array(tuning.get("progression_flags",[])).has("shadowstep_damage"):result.targets_hit=_line_attack(start,global_position,float(tuning.get("path_radius",22.0)),_configured_attack(tuning,"physical"))
		"summoner":_ensure_companion();companion.global_position=global_position-aim_direction*float(tuning.get("mount_offset",24.0))
	if result.targets_hit>0 and int(tuning.get("resource_gain",0))>0:_gain_resource(result,int(tuning.get("resource_gain",0)))
	return result

func _process_warrior_dash(delta:float)->void:
	var previous:=global_position
	global_position=global_position.move_toward(warrior_dash_destination,warrior_dash_speed*delta);_enforce_field_bounds();velocity=Vector2.ZERO
	_dash_slash_segment(previous,global_position,float(warrior_dash_attack.get("path_radius",36.0)))
	if global_position.is_equal_approx(warrior_dash_destination):
		warrior_dash_active=false;invulnerable=maxf(invulnerable,warrior_dash_landing_invulnerability);warrior_dash_hit_ids.clear()

func _dash_slash_segment(start:Vector2,end:Vector2,radius:float)->void:
	var segment:=end-start;var segment_length_squared:=segment.length_squared()
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_damageable"):
		var damageable:Node2D=node_value as Node2D
		if not is_instance_valid(damageable) or not damageable.has_method("receive_attack") or warrior_dash_hit_ids.has(damageable.get_instance_id()):continue
		var progress:=0.0 if segment_length_squared<=0.001 else clampf((damageable.global_position-start).dot(segment)/segment_length_squared,0.0,1.0)
		if (start+segment*progress).distance_to(damageable.global_position)>radius:continue
		warrior_dash_hit_ids[damageable.get_instance_id()]=true;damageable.call("receive_attack",warrior_dash_attack,self);_apply_echo_hit(damageable,warrior_dash_attack)
		if damageable.is_in_group("slasher_enemy") and not warrior_dash_resource_awarded:
			warrior_dash_resource_awarded=true;_award_resource(warrior_dash_resource_gain);resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max());_record_combo_confirmation("movement_hit")

func _defensive(result:Dictionary)->Dictionary:
	var tuning:=_ability_tuning("defensive");defense_window=float(tuning.get("effect_duration",1.0))
	match class_id:
		"warrior":defense_kind="parry"
		"mage":
			defense_kind="repel";result.targets_hit=_push_nearby(float(tuning.get("push_radius",100.0)),float(tuning.get("push_distance",70.0)))
			if result.targets_hit>0:result["combo_confirmations"]=["repel_hit"]
		"healer":defense_kind="recover"
		"tank":defense_kind="guard"
		"rogue":
			defense_kind="evade";invulnerable=float(tuning.get("invulnerability",defense_window));global_position=_safe_destination(global_position-aim_direction*float(tuning.get("movement_distance",70.0)),float(tuning.get("destination_clearance",22.0)))
			if Array(tuning.get("progression_flags",[])).has("evade_hidden"):is_hidden=true;hidden_time=maxf(hidden_time,float(tuning.get("hidden_duration",0.5)))
		"summoner":_ensure_companion();defense_kind="cover"
	return result

func receive_damage(amount:int,knockback:Vector2,attacker:SlasherEnemy=null)->void:
	var tuning:=_ability_tuning("special" if defense_kind=="retribution_ready" else "defensive")
	if invulnerable>0.0:
		if defense_kind=="evade":
			_award_resource(int(tuning.get("resource_gain",1)));resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max());defense_kind="";defense_window=0.0
			if is_instance_valid(attacker) and Array(tuning.get("progression_flags",[])).has("evade_counter"):attacker.receive_attack(_configured_attack(tuning,"physical"),self)
		return
	var prevented:=0
	if defense_window>0.0:
		match defense_kind:
			"parry":
				prevented=int(round(amount*float(tuning.get("mitigation",1.0))))
				if is_instance_valid(attacker):attacker.receive_attack(_attack_data(_scaled_damage(tuning,float(tuning.get("counter_coefficient",1.0)),"counter_flat_damage"),"physical",{"knockback":float(tuning.get("counter_knockback",35.0))}),self)
				_record_combo_confirmation("parry_success")
			"repel":
				prevented=int(round(amount*float(tuning.get("mitigation",0.5))))
				if is_instance_valid(attacker):attacker.position+=global_position.direction_to(attacker.global_position)*float(tuning.get("push_distance",70.0))
			"furnace":
				prevented=int(round(amount*0.6))
				if prevented>0 and is_instance_valid(pyromancy):pyromancy.furnace_counter()
			"mage_kit":
				prevented=int(round(amount*float(tuning.get("mitigation",0.5))))
				if prevented>0 and is_instance_valid(mage_kit):
					var gain: int=mage_kit.defense_resource_gain()
					mage_kit.on_prevented_damage(prevented);_award_resource(gain)
			"warrior_kit":
				if is_instance_valid(warrior_kit):
					prevented=int(round(amount*warrior_kit.mitigation_for(attacker,knockback)))
					if prevented>0:warrior_kit.prevention(attacker)
			"guard":
				prevented=int(round(amount*float(tuning.get("mitigation",0.75))))
				if prevented>0:_award_resource(int(tuning.get("resource_gain",1)))
			"cover":
				var wolf:=GameBalance.get_slasher_companion_tuning("wolf");var nearby:=is_instance_valid(companion) and companion.global_position.distance_to(global_position)<float(wolf.get("interception_radius",90.0))
				prevented=int(round(amount*float(wolf.get("cover_mitigation_near" if nearby else "cover_mitigation_far",0.6 if nearby else 0.3))))
			"retribution_ready":prevented=int(round(amount*float(tuning.get("mitigation",0.5))));retribution_stored+=int(round(amount*float(tuning.get("storage_fraction",0.5))))
		if defense_kind!="warrior_kit" or prevented>0:defense_window=0.0
	if prevented>0 and defense_kind not in ["guard","mage_kit","warrior_kit"]: _award_resource(1)
	if is_instance_valid(mage_kit) and not uses_pyromancy():
		prevented+=int(mage_kit.absorb_damage(maxi(0,amount-prevented)))
	if is_instance_valid(mage_combo_effects):prevented+=mage_combo_effects.absorb_damage(maxi(0,amount-prevented))
	if is_instance_valid(kit_buffs):prevented+=kit_buffs.absorb_damage(maxi(0,amount-prevented))
	if consumable_aegis>0:
		var aegis_prevented:int=mini(consumable_aegis,maxi(0,amount-prevented));consumable_aegis-=aegis_prevented;prevented+=aegis_prevented
	var final:=maxi(0,amount-prevented)
	if item_runtime:
		var mitigation:Dictionary=item_runtime.mitigate_damage(final);prevented+=int(mitigation.prevented);final=int(mitigation.damage)
		if item_runtime.try_prevent_lethal(final,health):final=maxi(0,health-1)
	health=maxi(0,health-final);run_state.current_health=health
	if final>0:add_impact_shake(minf(9.0+float(final)*0.75,12.0),0.24)
	move_and_collide(knockback*(0.25 if prevented>0 else 1.0));_enforce_field_bounds()
	if defense_kind=="recover" and final>0:heal(int(ceil(final*float(tuning.get("recover_fraction",0.5)))))
	if defense_kind=="retribution_ready" and retribution_stored>0:_area_attack(global_position,float(tuning.get("release_radius",80.0)),_attack_data(retribution_stored,"physical",{"knockback":float(tuning.get("release_knockback",30.0))}));retribution_stored=0
	if defense_window<=0:defense_kind=""
	health_changed.emit(health,max_health);queue_redraw()
	if health<=0:defeated.emit()

func _spawn_projectile(data:Dictionary,gain_on_hit:bool,direction_override:Vector2=Vector2.ZERO,origin_override:Vector2=Vector2.INF,combo_cast_id:String="")->void:
	if empowered:
		var empower:=_ability_tuning("special");data.damage=int(round(int(data.damage)*float(empower.get("empower_damage_multiplier",2.0))));data.status_duration=float(data.get("status_duration",0.0))+float(empower.get("empower_status_duration_bonus",1.0));empowered=false
	var direction:=aim_direction if direction_override.is_zero_approx() else direction_override.normalized();var origin:=global_position+direction*24.0 if origin_override==Vector2.INF else origin_override
	if not combo_cast_id.is_empty():data["combo_cast_id"]=combo_cast_id
	var projectile:SlasherProjectile=PROJECTILE.new().setup(self,origin,direction,data);get_parent().add_child(projectile)
	projectile.hit_landed.connect(func(hit_target:Node2D,_distance:float):
		if is_instance_valid(pyromancy):pyromancy.on_direct_hit(hit_target,data)
		elif is_instance_valid(mage_kit):mage_kit.on_direct_hit(hit_target,data)
		elif is_instance_valid(warrior_kit):warrior_kit.on_direct_hit(hit_target,data)
		if item_runtime and not bool(data.get("mage_secondary",false)) and hit_target.is_in_group("slasher_enemy") and _combo_proc_allowed(combo_cast_id,hit_target):item_runtime.handle_event({"trigger":"hit","target":hit_target,"attack":data}))
	if bool(data.get("force_prism",false)):
		projectile.impact_resolved.connect(func(impact_position:Vector2,_impact_data:Dictionary):_spawn_force_prism_bolts(impact_position,data,combo_cast_id),CONNECT_ONE_SHOT)
	var echo_multiplier:float=float(data.get("echo_damage_multiplier",0.0))
	if echo_multiplier>0.0:
		var echo_data:Dictionary=data.duplicate(true)
		for key in ["pyro_burn","pyro_cast","mage_kit","mage_cast","mage_resource","warrior_kit","warrior_cast","warrior_resource"]:echo_data.erase(key)
		echo_data["mage_secondary"]=true;echo_data.damage=maxi(1,int(round(int(data.damage)*echo_multiplier)));echo_data["screen_shake_multiplier"]=float(data.get("screen_shake_multiplier",1.0))*0.6
		var echo:SlasherProjectile=PROJECTILE.new().setup(self,global_position+aim_direction.rotated(0.08)*24.0,aim_direction.rotated(0.08),echo_data);get_parent().add_child(echo)
	if gain_on_hit:projectile.hit_landed.connect(func(hit_target:Node2D,distance:float):
		if not hit_target.is_in_group("slasher_enemy"):return
		var tuning:=_ability_tuning("basic");_award_resource(int(tuning.get("resource_gain",1))+int(tuning.get("resource_refund_on_hit",0)));resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max()))

func _spawn_force_prism_bolts(origin:Vector2,fireball_attack:Dictionary,combo_cast_id:String)->void:
	var effect:Dictionary=Dictionary(fireball_attack.get("force_prism_effect",{}));var count:=maxi(1,int(effect.get("projectiles",6)))
	for index in count:
		var bolt:=fireball_attack.duplicate(true);bolt.erase("force_prism");bolt.erase("force_prism_effect");bolt.erase("area_radius");bolt.erase("piercing");bolt.damage=maxi(1,int(round(float(fireball_attack.damage)*float(effect.get("damage_multiplier",0.20)))));bolt.range=float(effect.get("projectile_range",220.0));bolt.speed=float(effect.get("projectile_speed",620.0));bolt.visual="aether";bolt.visual_scale=1.0
		var direction:=Vector2.RIGHT.rotated(TAU*float(index)/float(count));_spawn_projectile(bolt,false,direction,origin+direction*12.0,combo_cast_id)

func _next_combo_cast_id()->String:
	combo_cast_serial+=1;var id:="%s:%d"%[run_state.active_character_id if run_state!=null else class_id,combo_cast_serial];combo_proc_targets[id]={}
	get_tree().create_timer(3.0).timeout.connect(func():combo_proc_targets.erase(id))
	return id

func _combo_proc_allowed(cast_id:String,target:Node2D)->bool:
	if cast_id.is_empty():return true
	var targets:Dictionary=combo_proc_targets.get(cast_id,{})
	if targets.has(target.get_instance_id()):return false
	targets[target.get_instance_id()]=true;combo_proc_targets[cast_id]=targets;return true

func _record_combo_confirmation(token:String)->void:
	if combo_runtime==null:return
	var outcome:Dictionary=combo_runtime.record_confirmation(token);combo_updated.emit({"type":"progress","progress":Dictionary(outcome.get("progress",{}))})

func _configure_combos() -> void:
	var names: Dictionary={}
	for slot in ["basic","special","defensive","movement"]:names[slot]=_action_name(slot)
	combo_runtime.setup(class_id,run_state.selected_gear.id if uses_mage_kit() or uses_warrior_kit() else "standard",names)

func reset_combo_progress()->void:
	if combo_runtime!=null:_configure_combos()
	last_fireball_attack={};resolving_combo={};warrior_slash_chain=0;warrior_slash_chain_time=0.0;combo_updated.emit({"type":"progress","progress":{}})

func _melee_attack(data:Dictionary)->int:
	var hits:=0;var reach:=float(data.get("reach",64.0));var threshold:=cos(deg_to_rad(float(data.get("arc_degrees",70.0))*0.5))
	for node in get_tree().get_nodes_in_group("slasher_damageable"):
		if node is Node2D and node.has_method("receive_attack"):
			var offset:Vector2=node.global_position-global_position
			if offset.length()<=reach and aim_direction.dot(offset.normalized())>=threshold:
				node.call("receive_attack",data,self)
				_apply_echo_hit(node,data)
				if node.is_in_group("slasher_enemy"):hits+=1
	return hits

func _line_attack(start:Vector2,end:Vector2,radius:float,data:Dictionary)->int:
	var hits:int=0;var segment:Vector2=end-start;var segment_length_squared:float=segment.length_squared()
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_damageable"):
		var damageable:Node2D=node_value as Node2D
		if not is_instance_valid(damageable) or not damageable.has_method("receive_attack"):continue
		var progress:float=0.0 if segment_length_squared<=0.001 else clampf((damageable.global_position-start).dot(segment)/segment_length_squared,0.0,1.0)
		var closest:Vector2=start+segment*progress
		if closest.distance_to(damageable.global_position)<=radius:
			damageable.call("receive_attack",data,self)
			_apply_echo_hit(damageable,data)
			if damageable.is_in_group("slasher_enemy"):hits+=1
	return hits

func _area_attack(center:Vector2,radius:float,data:Dictionary)->int:
	var hits:=0
	for node in get_tree().get_nodes_in_group("slasher_damageable"):
		if node is Node2D and node.has_method("receive_attack") and center.distance_to(node.global_position)<=radius:
			node.call("receive_attack",data,self)
			_apply_echo_hit(node,data)
			if node.is_in_group("slasher_enemy"):hits+=1
	return hits

func _deflect_projectiles(reach:float,arc_degrees:float)->int:
	if reach<=0.0 or arc_degrees<=0.0:return 0
	var count:=0;var threshold:=cos(deg_to_rad(arc_degrees)*0.5)
	for node_value:Variant in get_tree().get_nodes_in_group("slasher_hostile_projectile"):
		var projectile:SlasherHostileProjectile=node_value as SlasherHostileProjectile
		if not is_instance_valid(projectile):continue
		var offset:=projectile.global_position-global_position
		if offset.length()<=reach and (offset.is_zero_approx() or aim_direction.dot(offset.normalized())>=threshold):
			if projectile.deflect(self,aim_direction):count+=1
	return count

func _attack_data(damage:int,damage_type:String,extra:Dictionary={})->Dictionary:
	var data:={"damage":damage,"damage_type":damage_type,"knockback":0.0,"status":"","status_duration":0.0}
	for key in extra:data[key]=extra[key]
	return data

func _scaled_damage(tuning:Dictionary,coefficient_override:float=NAN,flat_key:String="flat_damage")->int:
	var stat_name:=String(tuning.get("power_stat","attack_power"))
	var stat_value:=spell_power if stat_name=="spell_power" else attack_power
	var coefficient:=float(tuning.get("damage_coefficient",1.0)) if is_nan(coefficient_override) else coefficient_override
	return maxi(1,int(round(stat_value*coefficient))+int(tuning.get(flat_key,0)))

func _scaled_heal(tuning:Dictionary)->int:
	return maxi(0,int(round(spell_power*float(tuning.get("heal_coefficient",0.0))))+int(tuning.get("flat_heal",0)))

func _configured_attack(tuning:Dictionary,damage_type:String)->Dictionary:
	var data:=_attack_data(_scaled_damage(tuning),damage_type)
	if next_attack_multiplier>1.0:data.damage=maxi(1,int(round(float(data.damage)*next_attack_multiplier)));next_attack_multiplier=1.0
	for key in ["reach","arc_degrees","line_radius","path_radius","area_radius","hit_radius","piercing","knockback","status","status_duration","status_strength","visual","visual_scale","tint","screen_shake_multiplier","echo_damage_multiplier","progression_flags"]:
		if tuning.has(key):data[key]=tuning[key]
	if tuning.has("projectile_range"):data.range=tuning.projectile_range
	if tuning.has("projectile_speed"):data.speed=tuning.projectile_speed
	return item_runtime.transform_attack(data,active_action_slot) if item_runtime else data

func apply_consumable(effects:Dictionary)->void:
	if int(effects.get("heal",0))>0:heal(int(effects.heal)+run_state.get_derived_stat("potion_heal_bonus"))
	if bool(effects.get("resource_fill",false)):run_state.class_resource=run_state.get_class_resource_max()
	elif int(effects.get("resource",0))>0:run_state.gain_class_resource(int(effects.resource))
	if bool(effects.get("hidden",false)):is_hidden=true;hidden_time=maxf(hidden_time,5.0)
	if int(effects.get("temporary_aegis",0))>0:consumable_aegis+=int(effects.temporary_aegis)
	if float(effects.get("movement_multiplier",1.0))>1.0 or int(effects.get("movement",0))>0:consumable_speed_multiplier=maxf(float(effects.get("movement_multiplier",1.0)),1.0+int(effects.get("movement",0))*0.15);consumable_speed_time=6.0
	if int(effects.get("extra_actions",0))>0:
		for key:Variant in cooldowns:cooldowns[key]=maxf(0.0,float(cooldowns[key])-1.0)
	if float(effects.get("next_attack_damage_multiplier",1.0))>1.0:next_attack_multiplier=float(effects.next_attack_damage_multiplier)
	if int(effects.get("next_attack_accuracy",0))>0 and item_runtime:item_runtime.precision_count=maxi(item_runtime.precision_count,5)
	resource_changed.emit(run_state.class_resource,run_state.get_class_resource_max())

func apply_movement_slow(multiplier:float,duration:float)->void:
	multiplier=clampf(multiplier,0.1,1.0)
	if movement_debuff_time<=0.0 or multiplier<movement_debuff_multiplier:movement_debuff_multiplier=multiplier
	movement_debuff_time=maxf(movement_debuff_time,duration)
	queue_redraw()
	if sprite:
		var tween:=create_tween();tween.tween_property(sprite,"modulate",Color("#8fc7ff"),0.08);tween.tween_property(sprite,"modulate",Color.WHITE,0.22)

func _safe_destination(destination:Vector2,clearance:float=22.0)->Vector2:
	var query:=PhysicsRayQueryParameters2D.create(global_position,destination,1);query.exclude.append(get_rid());var hit:=get_world_2d().direct_space_state.intersect_ray(query)
	var resolved:Vector2=Vector2(hit.position)-aim_direction*clearance if not hit.is_empty() and hit.collider is StaticBody2D else destination
	if position_sanitizer.is_valid():
		var sanitized:Variant=position_sanitizer.call(resolved)
		if sanitized is Vector2:return sanitized
	return resolved

func _enforce_field_bounds()->void:
	if not position_sanitizer.is_valid():return
	var sanitized:Variant=position_sanitizer.call(global_position)
	if sanitized is Vector2:global_position=sanitized

func _enemy_near_aim(range_value:float,dot_threshold:float)->SlasherEnemy:
	var result:SlasherEnemy;var best:=range_value
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy:
			var offset:Vector2=node.global_position-global_position
			if offset.length()<best and aim_direction.dot(offset.normalized())>=dot_threshold:best=offset.length();result=node
	return result

func _nearby_enemy_count(center:Vector2,radius:float)->int:
	var count:=0
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and center.distance_to(node.global_position)<=radius:count+=1
	return count
func _push_nearby(radius:float,distance:float)->int:
	var count:=0
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and global_position.distance_to(node.global_position)<=radius:node.position+=global_position.direction_to(node.global_position)*distance;count+=1
	return count
func _ensure_companion()->void:
	if is_instance_valid(companion):return
	var tuning:=GameBalance.get_slasher_companion_tuning("wolf");var spawn:Array=tuning.get("spawn_offset",[28,0])
	companion=load("res://scripts/slasher/slasher_wolf.gd").new();companion.name="BondedWolf";get_parent().add_child(companion);companion.global_position=global_position+Vector2(float(spawn[0]),float(spawn[1]));companion.call("setup",self,run_state.active_character_id)
func _update_aim()->void:
	var stick_aim:=Input.get_vector("slasher_aim_left","slasher_aim_right","slasher_aim_up","slasher_aim_down")
	var mouse_offset:=get_global_mouse_position()-global_position
	if stick_aim.length()>0.2:aim_direction=stick_aim.normalized()
	elif mouse_offset.length()>4.0:aim_direction=mouse_offset.normalized()
	facing_name=SlasherSpriteLibrary.direction_name(aim_direction,facing_name)
func uses_pyromancy()->bool:
	return run_state!=null and run_state.selected_gear!=null and run_state.selected_gear.id==PYROMANCY.GEAR_ID

func uses_warrior_kit()->bool:
	return class_id=="warrior" and run_state!=null and run_state.selected_gear!=null and WARRIOR_KITS.has_kit(run_state.selected_gear.id)

func uses_mage_kit()->bool:
	return run_state!=null and run_state.selected_gear!=null and MAGE_KITS.script_for(run_state.selected_gear.id)!=null

func _ability_tuning(slot:String)->Dictionary:
	if uses_warrior_kit() and is_instance_valid(warrior_kit):return warrior_kit.tuning(slot)
	if uses_mage_kit() and is_instance_valid(mage_kit):return mage_kit.tuning(slot)
	return run_state.get_effective_slasher_ability_tuning(slot) if run_state!=null else GameBalance.get_slasher_ability_tuning(class_id,slot)
func _apply_echo_hit(target:Node,data:Dictionary)->void:
	var multiplier:float=float(data.get("echo_damage_multiplier",0.0))
	if multiplier<=0.0:return
	var echo:Dictionary=data.duplicate(true);echo.erase("echo_damage_multiplier");echo.damage=maxi(1,int(round(int(data.damage)*multiplier)));echo.knockback=float(data.get("knockback",0.0))*0.5;target.call("receive_attack",echo,self)
func _action_name(slot:String)->String:
	if uses_warrior_kit() and is_instance_valid(warrior_kit):return warrior_kit.action_name(slot)
	if uses_pyromancy():return String(PYROMANCY.ACTIONS.get(slot,slot.capitalize()))
	if uses_mage_kit() and is_instance_valid(mage_kit):return mage_kit.action_name(slot)
	return String(GameBalance.get_class_action(class_id,slot).get("name",slot.capitalize()))
func suppress_resource_gain(duration:float)->void:resource_suppression_time=maxf(resource_suppression_time,duration)
func _award_resource(amount:int)->int:
	if resource_suppression_time>0.0:return 0
	run_state.gain_class_resource(amount);return amount
func _gain_resource(result:Dictionary,amount:int)->void:var awarded:=_award_resource(amount);result.resource_gained=int(result.get("resource_gained",0))+awarded
func heal(amount:int)->void:health=mini(max_health,health+amount);run_state.current_health=health;health_changed.emit(health,max_health)
func add_impact_shake(strength:float,duration:float)->void:
	strength*=_settings().get_float("screen_shake_intensity",1.0)
	if strength<=0.0 or duration<=0.0:return
	screen_shake_strength=minf(12.0,sqrt(screen_shake_strength*screen_shake_strength+strength*strength));screen_shake_time=maxf(screen_shake_time,duration);screen_shake_duration=maxf(screen_shake_duration,duration)
	if camera!=null:camera.offset=Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0)).normalized()*screen_shake_strength
func _update_screen_shake(delta:float)->void:
	if camera==null:return
	if _settings().get_float("screen_shake_intensity",1.0)<=0.0:camera.offset=Vector2.ZERO;screen_shake_time=0.0;screen_shake_strength=0.0;screen_shake_duration=0.0;return
	if screen_shake_time<=0.0:camera.offset=Vector2.ZERO;screen_shake_strength=0.0;screen_shake_duration=0.0;return
	screen_shake_time=maxf(0.0,screen_shake_time-delta)
	var falloff:=screen_shake_time/maxf(0.001,screen_shake_duration)
	camera.offset=Vector2(randf_range(-1.0,1.0),randf_range(-1.0,1.0))*screen_shake_strength*falloff
func _draw()->void:
	if is_instance_valid(kit_buffs) and kit_buffs.ward_amount()>0:
		draw_arc(Vector2.ZERO,45,0,TAU,48,Color("#ffdc93"),3)
		draw_string(ThemeDB.fallback_font,Vector2(-45,-83),"WARD %d"%kit_buffs.ward_amount(),HORIZONTAL_ALIGNMENT_CENTER,90,12,Color("#ffdc93"))
	if sprite==null or sprite.sprite_frames==null:draw_circle(Vector2.ZERO,18.0,Color.WHITE)
	if invulnerable>0.0:
		var pulse:=0.72+sin(Time.get_ticks_msec()*0.025)*0.18
		draw_arc(Vector2.ZERO,27.0,0.0,TAU,32,Color(0.62,0.88,1.0,pulse),3.0)
	if movement_debuff_time>0.0:draw_arc(Vector2.ZERO,24.0,0.0,TAU,28,Color("#79bfff"),3.0)
func _play_animation(state:String)->void:
	if sprite==null or sprite.sprite_frames==null:return
	var animation:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,state,facing_name)
	if not animation.is_empty() and sprite.animation!=animation:sprite.play(animation)

func _play_action_animation(state:String,cooldown:float)->void:
	if sprite==null or sprite.sprite_frames==null:return
	var animation:=SlasherSpriteLibrary.resolved_animation(sprite.sprite_frames,state,facing_name)
	if animation.is_empty():return
	var frame_count:int=sprite.sprite_frames.get_frame_count(animation)
	var base_fps:float=sprite.sprite_frames.get_animation_speed(animation)
	var natural_duration:float=float(frame_count)/maxf(0.001,base_fps)
	var playback_scale:float=maxf(1.0,natural_duration/maxf(0.001,cooldown))
	# Action playback always restarts so every successfully resolved attack gets a full swing.
	sprite.stop();sprite.play(animation,playback_scale)
