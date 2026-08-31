class_name CorruptionTarget
extends Node2D
var health := 9
var max_health := 9
var cleansed := false
@export var draw_placeholder := true
@onready var health_bar: ProgressBar=get_node_or_null("HealthBar")
## Registers spell-target and combat-reset groups, initializes the optional bar, and requests placeholder
## drawing.
func _ready() -> void:
	add_to_group("spell_target"); add_to_group("combat_enemy")
	if health_bar: health_bar.max_value=max_health; health_bar.value=health; health_bar.visible=false
	queue_redraw()
## Public combat interface. Rejects non-Spirit/non-Cleanse packets; otherwise spawns feedback, delegates
## health removal, and returns accepted damage.
func receive_damage(packet: DamagePacket) -> int:
	if packet.damage_type!="spirit" and packet.status_effect!="cleanse": return 0
	var amount: int=max(0,packet.base_damage)
	CombatFeedback.spawn(self,amount,packet); take_cleanse(amount); return amount
## Legacy/direct cleansing entry point. Removes health, updates the bar, marks the objective once at zero,
## recolors art, and redraws placeholders.
func take_cleanse(amount := 1) -> void:
	if cleansed: return
	health -= amount
	if health_bar: health_bar.value=max(0,health); health_bar.visible=health>0
	if health <= 0:
		cleansed=true; GameState.record_enemy_defeat("corrupted_heart"); GameState.mark_cleansed()
		remove_from_group("spell_target")
		var art:=get_node_or_null("PixelArt")
		if art: art.modulate=Color("#74c69d")
	queue_redraw()
## Restores health and visuals after player defeat unless the cleanse objective is already complete. It
## intentionally does not roll back completed progression.
func reset_combat() -> void:
	if GameState.objective_stage>=4: return
	health=max_health; cleansed=false
	if not is_in_group("spell_target"): add_to_group("spell_target")
	if health_bar: health_bar.max_value=max_health; health_bar.value=health; health_bar.visible=false
	var art:=get_node_or_null("PixelArt")
	if art: art.modulate=Color.WHITE
	queue_redraw()
## Reports whether the objective target remains eligible to receive cleansing projectiles.
func is_combat_target_active() -> bool:
	return not cleansed and health>0 and visible
## Draws fallback corruption/cleansed art and health text only when draw_placeholder is enabled.
func _draw() -> void:
	if not draw_placeholder: return
	if cleansed:
		draw_circle(Vector2.ZERO,38,Color("#74c69d")); draw_string(ThemeDB.fallback_font,Vector2(-30,65),"CLEANSED",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)
	else:
		for i in 8:
			var a := TAU*i/8.0; draw_line(Vector2.ZERO,Vector2.from_angle(a)*58,Color("#842c72"),8)
		draw_circle(Vector2.ZERO,40,Color("#4a153f")); draw_circle(Vector2(-14,-8),6,Color("#ff65c3")); draw_circle(Vector2(14,-8),6,Color("#ff65c3"))
		draw_string(ThemeDB.fallback_font,Vector2(-45,76),"CORRUPTION %d/%d" % [health,max_health],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
