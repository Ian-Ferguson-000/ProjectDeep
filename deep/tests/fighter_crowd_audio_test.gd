extends "res://tests/fighter_production_test.gd"

func _run()->void:
	var audio:Node=root.get_node("Audio")
	var settings:Node=root.get_node("GameSettings")
	var saved:Dictionary=settings.values.duplicate(true)
	settings.values=settings.DEFAULTS.duplicate(true);settings.apply_audio()
	audio.set_context("testing_ground")
	for music in audio.music_players:music.stop()
	for ambience in audio.ambience_players:ambience.stop()
	for reduced in [false,true]:
		settings.values["reduced_effects"]=reduced
		fixture("dragonbone_dagger")
		for voice in audio.voices.duplicate():audio._finish_voice(voice)
		audio.last_played.clear()
		var capture:=AudioEffectCapture.new();capture.buffer_length=1.0
		var master:=AudioServer.get_bus_index("Master")
		var effect_index:=AudioServer.get_bus_effect_count(master)
		AudioServer.add_bus_effect(master,capture)
		for i in 32:
			var enemy:=foe();enemy.position=player.position+Vector2.from_angle(i*TAU/32)*90
			for stack in 6:strike(enemy,100+i*6+stack,1)
		var fractures:=0
		for voice in audio.voices:
			if String(voice.get_meta("event_id"))=="fighter_armor_break":fractures+=1
		expect(fractures==2,"Mass armor breaks retain audible confirmation within the two-voice cap")
		expect(audio.voices.size()<=24,"Crowd contacts respect the global voice budget")
		await create_timer(0.65).timeout
		var frames:=capture.get_buffer(capture.get_frames_available())
		var peak:=0.0
		for frame in frames:peak=maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		expect(frames.size()>0 and peak>0.001,"Actual crowd contacts produce mixed audio")
		expect(peak<1.0,"Crowd output stays below digital clipping")
		print("FIGHTER CROWD AUDIO %s: voices=%d peak=%.5f frames=%d"%["reduced" if reduced else "normal",fractures,peak,frames.size()])
		AudioServer.remove_bus_effect(master,effect_index)
		await clear()
	settings.values=saved;settings.apply_audio()
	print("Fighter crowd audio: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
