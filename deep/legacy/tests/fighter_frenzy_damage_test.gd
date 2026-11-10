extends "res://legacy/tests/fighter_production_test.gd"

func _run()->void:
	for source in ["environment","enemy","enemy_projectile"]:
		fixture("demon_blade");player.warrior_kit=kit
		player.health=500;player.max_health=1000;player.invulnerable=0;player.defense_window=0
		var enemy:=foe();strike(enemy,1,1)
		player.receive_damage(10,Vector2.ZERO,enemy if source=="enemy" else null,source=="enemy_projectile")
		expect(player.health==480,source+": actual incoming damage doubles once")
		player.invulnerable=0;player.consumable_aegis=6
		player.receive_damage(10,Vector2.ZERO,enemy if source=="enemy" else null,source=="enemy_projectile")
		expect(player.health==472,source+": only post-mitigation remainder is doubled")
		player.invulnerable=0;player.consumable_aegis=10;player.fighter_frenzy_hurt_flash=0
		player.receive_damage(10,Vector2.ZERO,enemy if source=="enemy" else null,source=="enemy_projectile")
		expect(player.health==472 and player.fighter_frenzy_hurt_flash==0,source+": fully absorbed damage neither hurts nor fractures aura")
		player.heal(10)
		expect(player.health==482,"Frenzy does not multiply healing")
		# The signed health-adjustment API bypasses combat damage, as a health
		# expenditure should. This does not introduce a new health-cost mechanic.
		player.heal(-10)
		expect(player.health==472,"Frenzy does not multiply signed non-combat health adjustments")
		await clear()
	print("Fighter frenzy damage: %d checks, %d failures"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
