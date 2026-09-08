extends RefCounted
class_name WallTilesetProfile

const DATA_PATH := "res://data/slasher_wall_tilesets.json"
static var _data:Dictionary={}

static func get_profile(profile_id:String="stone_wall") -> Dictionary:
	_load()
	var profiles:Dictionary=Dictionary(_data.get("profiles",{}))
	var profile:Dictionary=Dictionary(profiles.get(profile_id,profiles.get("stone_wall",{}))).duplicate(true)
	profile["id"]=profile_id
	profile["spec"]=Dictionary(profile.get("atlas_spec",_data.get("atlas_spec",{}))).duplicate(true)
	return profile

static func texture(profile:Dictionary)->Texture2D:
	var path:=String(profile.get("texture",""))
	return load(path) as Texture2D if ResourceLoader.exists(path) else null

static func regions(profile:Dictionary,role:String)->Array[Rect2]:
	var spec:Dictionary=Dictionary(profile.get("spec",{}));var values:Array=[]
	if Dictionary(spec.get("boundary_roles",{})).has(role):values=Array(Dictionary(spec.boundary_roles).get(role,[]))
	else:values=Array(Dictionary(spec.get("facade_roles",{})).get(role,[]))
	return _rects(values)

static func roles_for_mask(profile:Dictionary,mask:int)->Array[String]:
	var result:Array[String]=[];var composition:Dictionary=Dictionary(Dictionary(profile.get("spec",{})).get("mask_composition",{}))
	for value in Array(composition.get(str(mask),[])):result.append(String(value))
	return result

static func _rects(values:Array)->Array[Rect2]:
	var result:Array[Rect2]=[]
	for value in values:
		var rect:Array=Array(value)
		if rect.size()==4:result.append(Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])))
	return result

static func validate()->Array[String]:
	_load();var errors:Array[String]=[]
	if int(_data.get("spec_version",0))<1:errors.append("Wall tileset spec_version is missing.")
	for profile_id_value in Dictionary(_data.get("profiles",{})):
		var profile_id:=String(profile_id_value);var profile:=get_profile(profile_id);var spec:=Dictionary(profile.get("spec",{}));var boundary_roles:=Dictionary(spec.get("boundary_roles",{}));var composition:=Dictionary(spec.get("mask_composition",{}));var facade_roles:=Dictionary(spec.get("facade_roles",{}));var path:=String(profile.get("texture",""))
		if int(spec.get("logical_tile_size",0))<=0:errors.append("Wall profile %s logical tile size must be positive."%profile_id)
		for role_value in Array(spec.get("required_roles",[])):
			var role:=String(role_value)
			if not boundary_roles.has(role) or Array(boundary_roles.get(role,[])).is_empty():errors.append("Wall profile %s is missing boundary role '%s'."%[profile_id,role])
		for mask in range(1,16):
			var key:=str(mask)
			if not composition.has(key) or Array(composition.get(key,[])).is_empty():errors.append("Wall profile %s boundary mask %d has no composition."%[profile_id,mask]);continue
			for role_value in Array(composition[key]):
				if not boundary_roles.has(String(role_value)):errors.append("Wall profile %s boundary mask %d uses missing role '%s'."%[profile_id,mask,String(role_value)])
		for role_value in Array(spec.get("required_facade_roles",[])):
			var role:=String(role_value)
			if not facade_roles.has(role) or Array(facade_roles.get(role,[])).is_empty():errors.append("Wall profile %s is missing facade role '%s'."%[profile_id,role])
		if not ResourceLoader.exists(path):errors.append("Wall profile %s texture does not exist: %s"%[profile_id,path]);continue
		var expected:Array=Array(profile.get("atlas_size",[]));var image:=Image.load_from_file(ProjectSettings.globalize_path(path))
		if image==null or image.is_empty():errors.append("Wall profile %s texture cannot be read."%profile_id);continue
		if expected.size()==2 and Vector2i(expected[0],expected[1])!=image.get_size():errors.append("Wall profile %s atlas size does not match its manifest."%profile_id)
		for role in boundary_roles:_validate_regions(image,Array(boundary_roles[role]),"boundary role %s"%role,errors)
		for role in facade_roles:_validate_regions(image,Array(facade_roles[role]),"facade role %s"%role,errors)
	return errors

static func _validate_regions(image:Image,values:Array,label:String,errors:Array[String])->void:
	for value in values:
		var r:Array=Array(value)
		if r.size()!=4 or int(r[2])<=0 or int(r[3])<=0:errors.append("Wall %s has an invalid region."%label);continue
		var rect:=Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
		if rect.position.x<0 or rect.position.y<0 or rect.end.x>image.get_width() or rect.end.y>image.get_height():errors.append("Wall %s exceeds atlas bounds."%label);continue
		var visible:=false
		for y in range(rect.position.y,rect.end.y):
			for x in range(rect.position.x,rect.end.x):
				if image.get_pixel(x,y).a>0.01:visible=true;break
			if visible:break
		if not visible:errors.append("Wall %s region %s is fully transparent."%[label,rect])

static func _load()->void:
	if not _data.is_empty():return
	var file:=FileAccess.open(DATA_PATH,FileAccess.READ)
	if file==null:_data={};return
	var parsed:Variant=JSON.parse_string(file.get_as_text())
	_data=Dictionary(parsed) if parsed is Dictionary else {}
