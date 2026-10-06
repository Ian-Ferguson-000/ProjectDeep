extends Node2D

const COLORS := {"physical":Color("#eee4ce"),"fire":Color("#ffad4d"),"arcane":Color("#c7a0ff"),"radiant":Color("#ffec82"),"poison":Color("#94eb7c"),"ice":Color("#86d9ff"),"lightning":Color("#a0f8f5")}
var amount := 0
var damage_type := "physical"
var source_label := ""
var critical := false
var age := 0.0
var lifetime := 0.85
var drift := 0.0

static func type_color(kind: String) -> Color:
	return COLORS.get(kind,Color("#e5e0d8"))

func setup(value: int, kind: String, source: String, is_critical: bool, lane: int) -> void:
	amount=value;damage_type=kind;source_label=source;critical=is_critical
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
	var number_size := 27 if critical else 23
	var x := -font.get_string_size(number,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size).x/2.0
	draw_string_outline(font,Vector2(x,0),number,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size,5,Color("#130b08"))
	draw_string(font,Vector2(x,0),number,HORIZONTAL_ALIGNMENT_LEFT,-1,number_size,tint)
	var caption_x := -font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x/2.0
	draw_string_outline(font,Vector2(caption_x,17),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,4,Color("#130b08"))
	draw_string(font,Vector2(caption_x,17),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,12,tint)
