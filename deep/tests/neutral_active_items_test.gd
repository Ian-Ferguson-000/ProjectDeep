extends SceneTree

const FOREST:=preload("res://scenes/slasher/SlasherForest.tscn")
const IDS:=["siren_song_lyre","witherbloom_brooche","white_dragon_mask","black_titan_crown","dissonant_whisper_jar","mahoragan_adaption_wheel","pandoras_paradoxical_compass","vibranium_tattoo","shadowfell_brand","blood_ruby_gem","abyssal_sapphire_gem","feywild_shawl","bramble_vine_snare","heartbreaker_amulet","war_horn_of_valor"]
var failures:Array[String]=[]

func _initialize()->void:_run.call_deferred()
func _expect(ok:bool,message:String)->void:
	if not ok:failures.append(message)
func _frames(count:int)->void:
	for i in count:await process_frame
func _dummy(scene,offset:Vector2)->SlasherEnemy:
	var foe:SlasherEnemy=scene._spawn_enemy(scene.player.global_position+offset,"bandit_cutthroat","bandit_cutthroat");foe.activation_delay=999.0;foe.max_health=100;foe.health=100;return foe
func _runtime(player:SlasherPlayer,id:String)->Node:
	for child in player.get_children():
		if child.get_meta("active_item_runtime_id","")==id:return child
	return null
func _equip(scene,state:RunState,id:String)->Node:
	ActiveItems.give(state,id);return SlasherActiveEffects.ensure_runtime(scene.player,id)

func _run()->void:
	var state:=RunState.new();state.start_new_run(GearData.create("neutral_test","Neutral Tester",3,false,0,"","","warrior"),"forest")
	var scene=FOREST.instantiate();scene._ensure_designer_controls();scene.run_state=state;root.add_child(scene);await _frames(4);paused=false
	scene.player.invulnerable=9999.0;scene.player.aim_direction=Vector2.RIGHT
	for id in IDS:
		var runtime:=_equip(scene,state,id)
		_expect(runtime!=null,"%s created no held-item runtime"%id)
		_expect(scene.use_active_item(),"%s did not activate"%id)

	# Critically wounded creatures turn on one another near the Lyre.
	var first:=_dummy(scene,Vector2(80,0));var second:=_dummy(scene,Vector2(115,0));first.health=20
	var lyre=_equip(scene,state,"siren_song_lyre");lyre._process_siren()
	_expect(second.health<100 or first.health<20,"Siren Song Lyre did not confuse a critically wounded enemy")

	# Any registered death produces a healing/slowing bloom or a stored scream.
	var brooch=_equip(scene,state,"witherbloom_brooche");var bloom_count:int=brooch.blooms.size();brooch._on_enemy_defeated(first,1)
	_expect(brooch.blooms.size()==bloom_count+1,"Witherbloom Brooche produced no flower")
	var jar=_equip(scene,state,"dissonant_whisper_jar");jar.phantasms.clear();jar._set_screams(0);jar._on_enemy_defeated(second,1)
	_expect(jar._screams()==1,"Dissonant Whisper Jar did not retain a death scream")
	jar.activate();_expect(jar.phantasms.size()==1 and jar._screams()==0,"Whisper Jar did not release and consume its stored phantasm")

	# Frosted targets cascade shards into nearby creatures when hit.
	var frost_primary:=_dummy(scene,Vector2(140,0));var frost_near:=_dummy(scene,Vector2(185,0));var mask=_equip(scene,state,"white_dragon_mask");mask.activate();mask.frost_proc_cooldowns[frost_primary.get_instance_id()]=0.0;var near_health:=frost_near.health
	mask.on_external_hit(frost_primary,{"damage":1},false)
	_expect(mask.frost.has(frost_primary.get_instance_id()) and frost_near.health<near_health,"White Dragon Mask produced no cascading frost shards (frost=%s, nearby %d→%d)"%[mask.frost.has(frost_primary.get_instance_id()),near_health,frost_near.health])

	# Titan defense scales with proximity and converts endured damage to offense.
	var crown=_equip(scene,state,"black_titan_crown");crown.activate();var reduced:int=int(crown.modify_incoming_damage_from(20,frost_primary));crown.on_owner_damaged(reduced)
	_expect(reduced<20 and int(crown.adjust_external_attack(frost_primary,{"damage":10}).damage)>10,"Black Titan Crown did not convert proximity defense into damage")

	# Repeated attacks from one archetype teach resistance; activation mirrors it offensively.
	var wheel=_equip(scene,state,"mahoragan_adaption_wheel");var one:int=int(wheel.modify_incoming_damage_from(20,frost_primary));wheel.on_owner_damaged(one);var two:int=int(wheel.modify_incoming_damage_from(20,frost_primary));wheel.on_owner_damaged(two);wheel.activate()
	_expect(two<one and int(wheel.adjust_external_attack(frost_primary,{"damage":10}).damage)>10,"Mahoragan wheel did not learn and weaponize resistance")

	# The compass remembers and reverses its polarity between activations.
	var compass_target:=_dummy(scene,scene.player.aim_direction*180.0);var compass=_equip(scene,state,"pandoras_paradoxical_compass");var compass_health:=compass_target.health;compass.activate();var polarity:int=int(compass.compass_polarity);compass.activate()
	_expect(compass.compass_polarity==-polarity and compass_target.health<compass_health,"Pandora's Compass neither pulsed nor reversed polarity")

	# Movement banks momentum, while uninterrupted shadow movement raises agility.
	var tattoo=_equip(scene,state,"vibranium_tattoo");tattoo.momentum_primed_time=0.0;tattoo.last_actor_position=scene.player.global_position;scene.player.global_position+=Vector2(260,0);tattoo._process_new_passives(1.0);var banked_momentum:float=tattoo.momentum;tattoo.activate();var kinetic_attack:Dictionary=tattoo.adjust_external_attack(frost_primary,{"damage":10});var shock_target:=_dummy(scene,frost_primary.global_position-scene.player.global_position+Vector2(40,0));var shock_health:=shock_target.health;tattoo.on_external_hit(frost_primary,kinetic_attack,false)
	_expect(banked_momentum>=250.0 and int(kinetic_attack.damage)>=20 and tattoo.kinetic_bursts==1 and shock_target.health<shock_health,"Vibranium Tattoo did not deliberately release stored movement as an empowered shockwave")
	var brand=_equip(scene,state,"shadowfell_brand");brand.last_actor_position=scene.player.global_position;scene.player.global_position+=Vector2(40,0);brand._process_new_passives(2.0)
	_expect(brand.shadow_stride>=2.0 and scene.player.kit_buffs.speed_multiplier()>1.0,"Shadowfell Brand did not build movement agility")
	brand.activate();var ambush:Dictionary=brand.adjust_external_attack(frost_primary,{"damage":10});_expect(bool(ambush.get("critical",false)) and int(ambush.damage)>=20,"Shadowfell activation did not guarantee a tactical ambush")
	brand.activate();brand.on_owner_damaged(1);_expect(brand.shadow_stride==0.0 and not brand.shadow_ambush_ready,"Shadowfell Brand did not break on damage")

	# Blood charges persist until they become allied minions.
	var ruby=_equip(scene,state,"blood_ruby_gem");ruby._set_blood_charges(2);var child_count:int=int(scene.player.get_parent().get_child_count());ruby.activate()
	_expect(ruby._blood_charges()==0 and scene.player.get_parent().get_child_count()>=child_count+2,"Blood Ruby did not consume charges into minions")
	var full_damage:=int(ruby.adjust_external_attack(frost_primary,{"damage":10}).damage);scene.player.health=maxi(1,scene.player.max_health/2)
	_expect(int(ruby.adjust_external_attack(frost_primary,{"damage":10}).damage)>full_damage,"Blood Ruby did not scale damage with missing health")

	# Abyssal pressure stacks both slow and damage loss, then ruptures for force damage.
	var sapphire=_equip(scene,state,"abyssal_sapphire_gem");var original_damage:=frost_primary.damage;sapphire._add_pressure(frost_primary);sapphire._add_pressure(frost_primary);var pressured_health:=frost_primary.health;sapphire.activate()
	_expect(frost_primary.damage<=original_damage and frost_primary.health<pressured_health and sapphire.pressure.is_empty(),"Abyssal Sapphire did not stack and rupture pressure")
	var fresh_pressure_target:=_dummy(scene,Vector2(90,-40));var fresh_pressure_health:=fresh_pressure_target.health;sapphire.activate();_expect(fresh_pressure_target.health<fresh_pressure_health,"Abyssal Sapphire activation did nothing without prebuilt pressure")

	# Summon activations create persistent battlefield actors and snares.
	var shawl=_equip(scene,state,"feywild_shawl");shawl.activate();_expect(shawl.fey.size()>=2,"Feywild Shawl summoned no fey")
	var bramble_target:=_dummy(scene,scene.player.aim_direction*320.0);var bramble_health:=bramble_target.health;var bramble=_equip(scene,state,"bramble_vine_snare");var expected_bramble_point:Vector2=bramble._safe_room_point(scene.player.global_position+scene.player.aim_direction*320.0);bramble.activate();var intended_point:Vector2=bramble.wyrm.destination;bramble._process_wyrm(1.3)
	_expect(intended_point.distance_to(expected_bramble_point)<2.0 and bramble.bramble_chomps==1 and bramble_target.health<bramble_health and bramble.snares.size()>=4,"Bramble Vine Snare failed targeted sequence (aim error %.1f, chomps %d, health %d→%d, snares %d)"%[intended_point.distance_to(expected_bramble_point),bramble.bramble_chomps,bramble_health,bramble_target.health,bramble.snares.size()])

	# Heart marks share damage and Valor supplies proximity risk plus life-steal.
	var heart=_equip(scene,state,"heartbreaker_amulet");var linked_a:=_dummy(scene,Vector2(80,40));var linked_b:=_dummy(scene,Vector2(100,40));heart.activate();_expect(heart.heart_marks.has(linked_a.get_instance_id()) and heart.heart_marks.has(linked_b.get_instance_id()),"Heartbreaker activation did not establish tactical links");heart.on_external_hit(linked_a,{"damage":10,"damage_type":"physical"},false);heart.on_external_hit(linked_b,{"damage":10,"damage_type":"physical"},false);var linked_health:=linked_a.health;heart.on_external_hit(linked_b,{"damage":10,"damage_type":"physical"},false)
	_expect(linked_a.health<linked_health,"Heartbreaker marks did not share damage")
	var valor=_equip(scene,state,"war_horn_of_valor");scene.player.health=maxi(1,scene.player.max_health-5);var hurt_health:int=int(scene.player.health);valor.activate();valor.on_external_hit(linked_a,{"damage":10},false)
	_expect(scene.player.health>hurt_health and int(valor.adjust_external_attack(linked_a,{"damage":10}).damage)>10,"War Horn of Valor supplied neither life-steal nor damage")

	scene.queue_free();await _frames(3)
	if failures.is_empty():print("NEUTRAL_ACTIVE_ITEMS_TESTS_PASSED");quit(0)
	else:
		for failure in failures:printerr("FAIL: "+failure)
		quit(1)
