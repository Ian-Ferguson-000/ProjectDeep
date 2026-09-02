class_name SpellImpact
extends Node2D

const AETHER_HIT:=preload("res://assets/effect_packs/Aether Effect 01/Aether VFX 1/Ice VFX 1 Hit.png")
const FIREBALL_HIT:=preload("res://assets/effect_packs/fireball/fireball_impact.png")
var frame_index:=0
var frame_count:=6
var frame_time:=0.0
var frames_per_second:=20.0
var color:=Color.WHITE
var animated_visual:AnimatedSprite2D

## Configures a bespoke impact strip when one exists, otherwise prepares a six-frame elemental burst.
func setup(rune_id:String,damage_type:String) -> SpellImpact:
	color=CombatFeedback.damage_color(damage_type)
	if rune_id in ["fireball","aether_blast"]:_build_strip(FIREBALL_HIT if rune_id=="fireball" else AETHER_HIT)
	return self

## Builds the eight-frame 48×32 Fireball or Aether impact animation and connects its final cleanup.
func _build_strip(texture:Texture2D) -> void:
	animated_visual=AnimatedSprite2D.new();animated_visual.sprite_frames=SpriteFrames.new();animated_visual.sprite_frames.remove_animation("default")
	animated_visual.sprite_frames.add_animation("impact");animated_visual.sprite_frames.set_animation_speed("impact",18.0);animated_visual.sprite_frames.set_animation_loop("impact",false)
	for index in 8:
		var frame:=AtlasTexture.new();frame.atlas=texture;frame.region=Rect2(index*48,0,48,32);animated_visual.sprite_frames.add_frame("impact",frame)
	animated_visual.scale=Vector2(1.5,1.5);animated_visual.animation_finished.connect(queue_free);add_child(animated_visual);animated_visual.play("impact")

## Advances generic elemental impact frames and frees the actor after the sixth rendered frame.
func _process(delta:float) -> void:
	if animated_visual:return
	frame_time+=delta
	var next_frame:=mini(frame_count-1,int(frame_time*frames_per_second))
	if next_frame!=frame_index:frame_index=next_frame;queue_redraw()
	if frame_time>=float(frame_count)/frames_per_second:queue_free()

## Draws one discrete expanding impact frame with a shrinking bright core and radial sparks.
func _draw() -> void:
	if animated_visual:return
	var progress:=float(frame_index+1)/float(frame_count);var radius:=6.0+progress*24.0
	draw_arc(Vector2.ZERO,radius,0,TAU,20,Color(color,1.0-progress*0.75),4.0)
	draw_circle(Vector2.ZERO,maxf(1.0,8.0*(1.0-progress)),Color.WHITE)
	for index in 8:
		var direction:=Vector2.from_angle(TAU*index/8.0);draw_line(direction*(radius-5.0),direction*(radius+6.0),Color(color,1.0-progress),3.0)
