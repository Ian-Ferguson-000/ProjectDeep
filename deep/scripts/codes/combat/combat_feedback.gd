class_name CombatFeedback
extends RefCounted
static var flash_shader:Shader

## Creates a floating number and elemental impact effect beside target. It expects positive resolved damage
## and a valid target with a parent; zero damage and invalid targets intentionally produce no feedback. Call
## this after damage has been accepted, not before vulnerability/defense calculation.
static func spawn(target: Node2D, amount: int, packet: DamagePacket) -> void:
	if amount<=0 or not is_instance_valid(target): return
	var parent:=target.get_parent()
	if not parent: return
	var number:=FloatingDamageNumber.new().setup(amount,packet.damage_type)
	parent.add_child(number); number.global_position=target.global_position+Vector2(0,-42)
	var effect:=CombatHitEffect.new().setup(packet.damage_type)
	parent.add_child(effect); effect.global_position=target.global_position
	_flash_target(target)
	_shake_viewport(target,amount)

## Replaces only the target's visual pixels with white briefly, preserving labels, bars, and its prior material.
static func _flash_target(target:Node2D) -> void:
	var visual:CanvasItem=target.get_node_or_null("AnimatedSprite2D")
	if not visual:visual=target.get_node_or_null("PixelArt")
	if not visual and target is CanvasItem:visual=target
	if not visual:return
	if visual.has_meta("impact_flash_tween"):
		var previous:Tween=visual.get_meta("impact_flash_tween")
		if previous and previous.is_valid():previous.kill()
	var original:Material=visual.get_meta("impact_original_material",visual.material)
	visual.set_meta("impact_original_material",original)
	var material:=ShaderMaterial.new();material.shader=_get_flash_shader();material.set_shader_parameter("flash_amount",1.0);visual.material=material
	var tween:=visual.create_tween();visual.set_meta("impact_flash_tween",tween)
	## Fades the temporary white replacement back to the actor's original pixels.
	tween.tween_method(func(value):material.set_shader_parameter("flash_amount",value),1.0,0.0,0.13)
	## Restores the original material only when this remains the newest flash on the visual.
	tween.tween_callback(func():
		if is_instance_valid(visual) and visual.material==material:
			visual.material=original;visual.remove_meta("impact_flash_tween");visual.remove_meta("impact_original_material"))

## Creates and caches the canvas shader that blends opaque sprite pixels to pure white without filling alpha.
static func _get_flash_shader() -> Shader:
	if flash_shader:return flash_shader
	flash_shader=Shader.new();flash_shader.code="shader_type canvas_item; uniform float flash_amount : hint_range(0.0, 1.0) = 0.0; void fragment(){ vec4 pixel = texture(TEXTURE, UV) * COLOR; COLOR = vec4(mix(pixel.rgb, vec3(1.0), flash_amount * pixel.a), pixel.a); }"
	return flash_shader

## Starts or refreshes one small camera shake, scaling amplitude gently with resolved impact damage.
static func _shake_viewport(target:Node2D,amount:int) -> void:
	var viewport:=target.get_viewport();var camera:=viewport.get_camera_2d() if viewport else null
	if not camera:return
	var amplitude:=clampf(1.4+sqrt(float(amount))*0.42,1.8,5.0)
	var shake:ImpactScreenShake=camera.get_node_or_null("ImpactScreenShake")
	if shake:shake.add_trauma(amplitude);return
	shake=ImpactScreenShake.new().setup(camera,amplitude);shake.name="ImpactScreenShake";camera.add_child(shake)

## Returns the shared presentation color for every starter damage family and known legacy type.
static func damage_color(type:String) -> Color:
	match type:
		"fire","burn":return Color("#ff6138")
		"lightning":return Color("#ffe45e")
		"magnetism":return Color("#d48bff")
		"aether":return Color("#a982ff")
		"void":return Color("#643c8f")
		"force":return Color("#7fe8ff")
		"sonic":return Color("#63d4d0")
		"growth","poison":return Color("#83d640")
		"earth":return Color("#b68b5e")
		"light","spirit":return Color("#fff7a0")
		"wind","ice":return Color("#a8ecff")
		"physical":return Color("#f1e0c5")
		_:return Color.WHITE
