extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var failures:Array[String]=[];var definition:=GameBalance.get_dungeon("crypt")
	_expect(Array(definition.supported_modes).has("slasher") and String(definition.slasher_runtime)=="crypt","Crypt Slasher routing is incomplete",failures)
	_expect(ResourceLoader.exists("res://scenes/slasher/SlasherCrypt.tscn") and ResourceLoader.exists("res://scripts/slasher/slasher_crypt.gd"),"Crypt Slasher assets are missing",failures)
	var profile:=DungeonRuntimeProfile.get_profile("crypt");_expect(Array(profile.hazards).has("curses") and String(profile.boss)=="crypt_boss","Crypt runtime profile lacks its hazards or boss",failures)
	for boss_id in ["crypt_boss","drowned_foreman","last_warmachine","moon_court_huntress","unwritten_curator"]:
		_expect(ResourceLoader.exists("res://assets/enemies/%s/generated_source.png"%boss_id),"%s generated sprite board is missing"%boss_id,failures)
		var frames:=SlasherSpriteLibrary.enemy_frames(boss_id);_expect(frames!=null and frames.has_animation("idle_down") and frames.has_animation("run_left") and frames.has_animation("attack_up"),"%s runtime animations are incomplete"%boss_id,failures)
	if failures.is_empty():print("CRYPT_SLASHER_CONTRACT_TESTS_PASSED");quit(0)
	else:
		for failure in failures:push_error(failure)
		quit(1)
func _expect(condition:bool,message:String,failures:Array[String])->void:
	if not condition:failures.append(message)
