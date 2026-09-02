extends SlasherPlayer
class_name SlasherPartyCompanion

signal companion_fell(character_id:String)

var character_id := ""
var leader: SlasherPlayer
var follow_index := 0
var ai_attack_cooldown := 0.0
var ai_support_cooldown := 0.0
var preferred_range := 52.0

func setup_companion(campaign: CampaignState, member: CharacterRecord, party_leader: SlasherPlayer, index: int) -> void:
	character_id=member.id;leader=party_leader;follow_index=index
	var state:=RunState.new();state.attach_campaign(campaign);state.active_character_id=member.id;state.set_class(member.class_id);state.current_health=member.current_health if member.current_health>0 else state.max_health
	setup(state);input_locked=true;preferred_range=155.0 if class_id in ["mage","healer","summoner"] else (72.0 if class_id=="tank" else 48.0)

func _ready()->void:
	super();add_to_group("slasher_party_target");add_to_group("slasher_companion");name="Companion_%s"%character_id;defeated.connect(_on_defeated)
	var badge:=Label.new();badge.name="CompanionBadge";badge.text=run_state.get_active_character().display_name if run_state.get_active_character()!=null else class_id.capitalize();badge.position=Vector2(-48,-62);badge.size=Vector2(96,18);badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;badge.add_theme_font_size_override("font_size",10);badge.add_theme_color_override("font_color",Color("a9d8f0"));badge.add_theme_color_override("font_outline_color",Color.BLACK);badge.add_theme_constant_override("outline_size",3);add_child(badge)

func _physics_process(delta:float)->void:
	super(delta)
	if health<=0 or not is_instance_valid(leader):return
	ai_attack_cooldown=maxf(0.0,ai_attack_cooldown-delta);ai_support_cooldown=maxf(0.0,ai_support_cooldown-delta)
	var enemy:=_nearest_enemy()
	if class_id=="healer" and ai_support_cooldown<=0.0 and leader.health*2<leader.max_health:leader.heal(maxi(2,run_state.get_derived_stat("spell_potency")));ai_support_cooldown=7.0;_play_animation("special");return
	if enemy!=null:
		var distance:=global_position.distance_to(enemy.global_position)
		if distance<=preferred_range and ai_attack_cooldown<=0.0:_attack_target(enemy);return
		if distance<360.0 and class_id not in ["mage","healer","summoner"]:_move_ai(enemy.global_position);return
	var angle:=TAU*float(follow_index)/4.0;var follow_point:=leader.global_position+Vector2(cos(angle),sin(angle))*72.0
	if global_position.distance_to(follow_point)>34.0:_move_ai(follow_point)
	else:velocity=Vector2.ZERO;_play_animation("idle")

func _move_ai(destination:Vector2)->void:
	var safe_destination:Vector2=Vector2(position_sanitizer.call(destination)) if position_sanitizer.is_valid() else destination;var waypoint:Vector2=pathfinder.next_waypoint(global_position,safe_destination) if pathfinder!=null else safe_destination;var direction:=global_position.direction_to(waypoint);velocity=direction*speed*0.82;move_and_slide();_enforce_field_bounds();last_direction=direction;_play_animation("run")

func _attack_target(enemy:SlasherEnemy)->void:
	var damage:=maxi(2,attack_power if class_id not in ["mage","healer","summoner"] else spell_power);var multiplier:=0.75 if class_id=="healer" else (1.15 if class_id=="rogue" else 0.9)
	enemy.receive_attack({"damage":maxi(1,int(round(damage*multiplier))),"knockback":35.0,"hit_stun_duration":0.08},self);ai_attack_cooldown=1.15 if class_id in ["tank","healer"] else 0.8;last_direction=global_position.direction_to(enemy.global_position);_play_animation("attack")

func _nearest_enemy()->SlasherEnemy:
	var nearest:SlasherEnemy;var best:=INF
	for node in get_tree().get_nodes_in_group("slasher_enemy"):
		if node is SlasherEnemy and not node.dead:
			var distance:=global_position.distance_squared_to(node.global_position)
			if distance<best:best=distance;nearest=node
	return nearest

func _on_defeated()->void:
	var member:=run_state.get_active_character()
	if member!=null:member.current_health=0
	companion_fell.emit(character_id)
