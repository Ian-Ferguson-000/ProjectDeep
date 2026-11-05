extends "res://tests/fighter_production_test.gd"

func _run()->void:
	GameBalance.set_actions_override(GameBalance.ALL_ACTIONS)
	for id in ARSENAL.WEAPON_IDS:
		for slot in ["basic","special"]:
			for haste in [0.1,0.5,1.0,4.0,10.0,100.0]:
				fixture(id);player.warrior_kit=kit
				player.run_state.selected_gear=GearData.create(id,id,3,false,0,"","","warrior")
				expect(player.uses_warrior_kit(),id+": fixture selects the real equipped-item route")
				player.run_state.class_resource=player.run_state.get_class_resource_max()
				player.fighter_frenzy_left=4;player.fighter_frenzy_haste=haste
				var result:Dictionary=player.use_action(slot)
				var label:String="%s/%s/%.1fx"%[id,slot,haste]
				expect(bool(result.get("started",false)),label+": native input starts attack")
				var duration:float=kit.presentation_action_duration(float(player.cooldowns[slot]))
				if id=="storm_trident" and slot=="special":
					expect(absf(duration-float(kit.rules.windup)*maxf(0.1,1.0/haste))<0.001,label+": throw anticipation follows haste up to the authored readable-windup floor")
				var animation:StringName=player.sprite.animation
				expect(String(animation).begins_with("slash_"),label+": item pose excludes generic baked-in contact crescent")
				var frames:SpriteFrames=player.sprite.sprite_frames
				var played_duration:=float(frames.get_frame_count(animation))/maxf(0.001,frames.get_animation_speed(animation)*absf(player.sprite.get_playing_speed()))
				expect(absf(played_duration-duration)<0.001,label+": sprite playback matches authoritative attack clock")
				expect(absf(player.animation_lock-duration)<0.001,label+": idle cannot overwrite attack pose before its clock ends")
				player.run_state.class_resource=player.run_state.get_class_resource_max()
				var resource_before:int=player.run_state.class_resource
				player.cooldowns[slot]=0.0
				var rejected:Dictionary=player.use_action(slot)
				expect(not bool(rejected.get("started",false)),label+": pending attack rejects duplicate input")
				expect(player.run_state.class_resource==resource_before and float(player.cooldowns[slot])==0,label+": rejected activation refunds resources and does not start cooldown")
				expect(absf(player.animation_lock-duration)<0.001,label+": rejected activation does not restart presentation")
				await clear()
	fixture("divine_hammer")
	var chain_victim:=foe();chain_victim.position=player.position+Vector2(-100,0)
	kit._queue_hammer({"damage":1,"warrior_cast":1},1,chain_victim)
	expect(player.facing_name=="left","Automatic Hammer repeat turns its body toward the new target")
	var chain_frames:SpriteFrames=player.sprite.sprite_frames
	var chain_duration:=float(chain_frames.get_frame_count(player.sprite.animation))/maxf(0.001,chain_frames.get_animation_speed(player.sprite.animation)*absf(player.sprite.get_playing_speed()))
	expect(absf(chain_duration-float(kit.hammer_chain.duration))<0.001,"Automatic Hammer repeat restarts the compressed sprite windup")
	expect(absf(player.animation_lock-float(kit.hammer_chain.duration))<0.001,"Automatic Hammer repeat retains its pose until contact")
	await clear()
	for haste in [0.1,0.5,1.0,4.0,10.0,100.0]:
		fixture("storm_trident");player.warrior_kit=kit
		player.fighter_frenzy_left=4;player.fighter_frenzy_haste=haste
		kit.perform("special",{"started":true})
		var launch_time:float=kit.trident.left
		kit._tick_trident_aim(launch_time*0.99)
		expect(kit.missiles.is_empty(),"Hasted Trident cannot launch before the visible windup ends")
		kit._tick_trident_aim(launch_time*0.02)
		expect(kit.missiles.size()==1 and kit.trident.state=="flying","Hasted Trident launches as its authoritative windup ends")
		await clear()
	for ranged_id in ["valkyrian_sling","archon_crossbow","umbral_bow"]:
		fixture(ranged_id);kit.perform("basic",{"started":true})
		var flight_duration:float=kit.ranged_attack.duration
		var release_fraction:float=kit.ranged_attack.release
		kit._tick_ranged(flight_duration*release_fraction*0.99)
		expect(kit.ranged_presentation().loaded and kit.missiles.is_empty(),ranged_id+": loaded weapon remains visible until actual release")
		kit._tick_ranged(flight_duration*release_fraction*0.02)
		expect(not kit.ranged_presentation().loaded and kit.missiles.size()==1,ranged_id+": released weapon cannot show a second loaded projectile")
		var mid_recovery:=flight_duration*(release_fraction+(1-release_fraction)*0.5)
		kit._tick_ranged(mid_recovery-float(kit.ranged_attack.elapsed))
		expect(absf(float(kit.ranged_presentation().recovery)-0.5)<0.001 and kit.missiles.size()==1,ranged_id+": recovery follows attack clock without creating a second shot")
		kit._tick_ranged(flight_duration)
		expect(kit.ranged_presentation().is_empty(),ranged_id+": recovery pose clears at the end of its timeline")
		await clear()
	print("Fighter animation timing: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
