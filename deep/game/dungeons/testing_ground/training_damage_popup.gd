extends Node2D

const COLORS := {"physical":Color("#eee4ce"),"fire":Color("#ffad4d"),"arcane":Color("#c7a0ff"),"radiant":Color("#ffec82"),"poison":Color("#94eb7c"),"ice":Color("#86d9ff"),"lightning":Color("#a0f8f5")}
var amount := 0
var damage_type := "physical"
var source_label := ""
var critical := false
var age := 0.0
var lifetime := 0.85
var drift := 0.0
var compact := false

static func is_mage_source(source:String)->bool:
	return source in ["michaels_orb","gulthias_staff","gulthias_treant","skyblinder","dragonstaff","dragon_burn","jade_serpent","jade_poison","spectral_snake","tome","shango_lightning","shango_thunder","solar_aura","solar_flare","drumamu_gravity"]

static func is_compact_source(source:String)->bool:
	return is_mage_source(source) or source in ["eldritch_bowstaff","demon_blade","storm_trident","valkyrian_sling","dragonbone_dagger","archon_crossbow","divine_hammer","grim_reaver","sentinel_shield","umbral_bow","Radiant Splash","Divine Repeat","Corrupted Mini-Beast"]

static func type_color(kind: String) -> Color:
	return COLORS.get(kind,Color("#e5e0d8"))

func setup(value: int, kind: String, source: String, is_critical: bool, lane: int) -> void:
	amount=value;damage_type=kind;source_label=source;critical=is_critical
	compact=is_compact_source(source)
	if compact:lifetime=0.6
	drift=float(lane-1)*32.0
	z_index=80

func _process(delta: float) -> void:
	age+=delta
	if age>=lifetime:queue_free();return
	position+=Vector2(drift,-58.0)*delta
	modulate.a=clampf((lifetime-age)/0.25,0,1)
	queue_redraw()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var caption := damage_type.to_upper()+(" · "+source_label if not source_label.is_empty() else "")
	var number := str(amount)+("!" if critical else "")
	var tint := type_color(damage_type)
	var number_size := (22 if critical else 18) if compact else (27 if critical else 23)
	var x := -font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size).x/2.0
	draw_string_outline(font,Vector2(x,0),number,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size,5,Color("#130b08"))
	draw_string(font,Vector2(x,0),number,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size,tint)
	if compact:return
	var caption_x := -font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x/2.0
	draw_string_outline(font,Vector2(caption_x,17),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,4,Color("#130b08"))
	draw_string(font,Vector2(caption_x,17),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,tint)
