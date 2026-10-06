extends "res://scripts/slasher/training_combatant.gd"

var total_damage := 0
var hits := 0

func _ready() -> void:
	super()
	if sprite: sprite.hide()
	if role_label: role_label.hide()

func _physics_process(delta: float) -> void:
	damage_shield_remaining = maxf(0.0,damage_shield_remaining-delta)
	queue_redraw()

func receive_hit(amount: int, knockback: Vector2 = Vector2.ZERO, attacker: SlasherPlayer = null, stun_duration: float = -1.0, shake_multiplier: float = 1.0, sound_event: String = "impact") -> int:
	# Infinite durability, while retaining the real boss hit-cap/shield pipeline.
	# Leave enough health for any incoming hit without changing boss cap math.
	health = maxi(max_health,maxi(1,amount))+1
	var dealt := super(amount,Vector2.ZERO,attacker,0.0,shake_multiplier,sound_event)
	total_damage += dealt
	hits += 1
	health = max_health
	return dealt

func _draw() -> void:
	var accent := Color("#ffd17c") if boss else Color("#a9bca5")
	draw_circle(Vector2(0,23),35.0,Color(0.03,0.03,0.02,0.6))
	draw_circle(Vector2(0,23),30.0,Color("#3f392c"))
	draw_arc(Vector2(0,23),30,0,TAU,40,Color("#8b7351"),2)
	draw_rect(Rect2(-8,-20,16,52),Color("#67462a"))
	draw_line(Vector2(-28,-4),Vector2(28,-4),accent,7.0)
	draw_line(Vector2(0,-25),Vector2(0,28),accent,8.0)
	draw_circle(Vector2(0,-26),13.0,accent)
	draw_circle(Vector2(0,-26),5.0,Color("#463522"))
	draw_circle(Vector2(0,-7),14.0,Color("#3f2c20"))
	draw_arc(Vector2(0,-7),12.0,0,TAU,24,Color("#dc9b59"),3)
	draw_circle(Vector2(0,-7),4.0,Color("#fff0ae"))
	if damage_shield_remaining>0.0: draw_arc(Vector2.ZERO,34.0,0.0,TAU,32,Color("#8fd8ff"),2.0)
	draw_string(ThemeDB.fallback_font,Vector2(-47,-54),"BOSS" if boss else "TARGET",HORIZONTAL_ALIGNMENT_CENTER,94,14,accent)
	draw_string(ThemeDB.fallback_font,Vector2(-70,53),"%d dmg / %d hits"%[total_damage,hits],HORIZONTAL_ALIGNMENT_CENTER,140,13,accent)
	if hits>0:
		draw_string(ThemeDB.fallback_font,Vector2(-70,69),last_damage_type.to_upper(),HORIZONTAL_ALIGNMENT_CENTER,140,12,preload("res://scripts/slasher/training_damage_popup.gd").type_color(last_damage_type))
