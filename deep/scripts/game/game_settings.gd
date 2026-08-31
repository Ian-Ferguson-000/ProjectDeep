extends Node
class_name GameSettingsService

signal settings_changed(key:String,value:Variant)

const SETTINGS_PATH:="user://settings.cfg"
const RESOLUTIONS=[Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]
const DEFAULTS:Dictionary={
	"window_mode":"windowed","resolution":Vector2i(1280,720),"vsync":"on","ui_scale":1.0,
	"slasher_zoom":1.30,"master_volume":1.0,"music_volume":0.8,"sfx_volume":0.9,
	"master_mute":false,"music_mute":false,"sfx_mute":false,"screen_shake_intensity":1.0
}

var values:Dictionary={}

func _ready()->void:
	load_settings();_ensure_audio_buses();call_deferred("apply_display");call_deferred("apply_audio")

func get_value(key:String,fallback:Variant=null)->Variant:return values.get(key,DEFAULTS.get(key,fallback))
func get_float(key:String,fallback:float=0.0)->float:return float(get_value(key,fallback))
func get_bool(key:String,fallback:bool=false)->bool:return bool(get_value(key,fallback))
func get_string(key:String,fallback:String="")->String:return String(get_value(key,fallback))

func set_value(key:String,value:Variant,apply_now:bool=true)->void:
	if not DEFAULTS.has(key):return
	values[key]=_sanitize(key,value);save()
	if apply_now:
		if key in ["window_mode","resolution","vsync","ui_scale"]:apply_display()
		elif key.contains("volume") or key.contains("mute"):apply_audio()
	settings_changed.emit(key,values[key])

func load_settings()->void:
	values=DEFAULTS.duplicate(true);var config:=ConfigFile.new()
	if config.load(SETTINGS_PATH)!=OK:return
	for key_value:Variant in DEFAULTS:
		var key:String=String(key_value);values[key]=_sanitize(key,config.get_value("settings",key,DEFAULTS[key]))

@warning_ignore("shadowed_global_identifier")
func load()->void:load_settings()

func save()->void:
	var config:=ConfigFile.new()
	for key_value:Variant in values:config.set_value("settings",String(key_value),values[key_value])
	config.save(SETTINGS_PATH)

func reset_defaults()->void:
	values=DEFAULTS.duplicate(true);save();apply_display();apply_audio();settings_changed.emit("reset",values.duplicate(true))

func apply_display()->void:
	var mode:String=get_string("window_mode","windowed")
	match mode:
		"borderless":DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"fullscreen":DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var resolution:Vector2i=Vector2i(get_value("resolution",Vector2i(1280,720)));DisplayServer.window_set_size(resolution);_center_window(resolution)
	var vsync:String=get_string("vsync","on")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if vsync=="off" else (DisplayServer.VSYNC_ADAPTIVE if vsync=="adaptive" else DisplayServer.VSYNC_ENABLED))
	if get_tree()!=null:get_tree().root.content_scale_factor=get_float("ui_scale",1.0)

func apply_audio()->void:
	_ensure_audio_buses();_apply_bus("Master","master");_apply_bus("Music","music");_apply_bus("SFX","sfx")

func _apply_bus(bus_name:String,key_prefix:String)->void:
	var index:int=AudioServer.get_bus_index(bus_name)
	if index<0:return
	var volume:float=clampf(get_float("%s_volume"%key_prefix,1.0),0.0,1.0)
	AudioServer.set_bus_volume_db(index,-80.0 if volume<=0.001 else linear_to_db(volume));AudioServer.set_bus_mute(index,get_bool("%s_mute"%key_prefix,false))

func _ensure_audio_buses()->void:
	for bus_name in ["Music","SFX"]:
		if AudioServer.get_bus_index(bus_name)<0:AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)

func _sanitize(key:String,value:Variant)->Variant:
	match key:
		"window_mode":return String(value) if String(value) in ["windowed","borderless","fullscreen"] else "windowed"
		"resolution":
			var resolution:Vector2i=Vector2i(value);return resolution if resolution in RESOLUTIONS else Vector2i(1280,720)
		"vsync":return String(value) if String(value) in ["off","on","adaptive"] else "on"
		"ui_scale":return clampf(float(value),0.75,1.5)
		"slasher_zoom":return clampf(float(value),1.0,1.5)
		"master_volume","music_volume","sfx_volume":return clampf(float(value),0.0,1.0)
		"screen_shake_intensity":return clampf(float(value),0.0,1.5)
		"master_mute","music_mute","sfx_mute":return bool(value)
	return DEFAULTS.get(key,value)

func _center_window(resolution:Vector2i)->void:
	var screen:int=DisplayServer.window_get_current_screen();var screen_position:Vector2i=DisplayServer.screen_get_position(screen);var screen_size:Vector2i=DisplayServer.screen_get_size(screen)
	DisplayServer.window_set_position(screen_position+(screen_size-resolution)/2)
