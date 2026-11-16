extends Node3D
## Volumetric presentation of the shared hostile projectile simulation.
var visual_type := ""
var material: StandardMaterial3D

func setup(projectile: SlasherHostileProjectile) -> void:
	visual_type = projectile.visual_type
	material = StandardMaterial3D.new()
	material.albedo_color = projectile.tint
	material.emission_enabled = true
	material.emission = projectile.tint
	material.emission_energy_multiplier = 0.6
	material.roughness = 0.45
	match visual_type:
		"arrow", "spectral_arrow", "knife":
			_add_mesh(_cylinder(0.025,0.025,0.48),Vector3.ZERO,Vector3(PI/2,0,0))
			_add_mesh(_cylinder(0.0,0.10,0.20),Vector3(0,0,-0.30),Vector3(-PI/2,0,0))
		"bone":
			_add_mesh(_cylinder(0.045,0.045,0.38),Vector3.ZERO,Vector3(PI/2,0,0))
			for end in [-0.19,0.19]:
				for side in [-0.045,0.045]:
					_add_mesh(_sphere(0.065),Vector3(side,0,end))
		"flaming_disk":
			_add_mesh(_cylinder(0.25,0.25,0.09),Vector3.ZERO)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.20
			ring.outer_radius = 0.30
			ring.rings = 12
			ring.ring_segments = 8
			_add_mesh(ring,Vector3.ZERO)
		"necrotic_skull", "necrotic_skull_small":
			_add_mesh(_sphere(0.17),Vector3.ZERO)
			_add_mesh(_sphere(0.11),Vector3(0,-0.12,-0.04))
			for side in [-0.07,0.07]:
				var eye := _add_mesh(_sphere(0.045),Vector3(side,0.035,-0.15))
				var dark := StandardMaterial3D.new()
				dark.albedo_color = Color("170c25")
				eye.material_override = dark
		"rift_shard", "bolt":
			var shard := _add_mesh(_sphere(0.14),Vector3.ZERO)
			shard.scale = Vector3(0.65,0.8,2.1)
		_:
			_add_mesh(_sphere(0.17),Vector3.ZERO)
			if visual_type in ["soul","soul_flame","hellfire_orb"]:
				for index in 3:
					_add_mesh(_sphere(0.12-index*0.03),Vector3(0,0,0.16+index*0.13))
	var radius := clampf(projectile.hit_radius/48.0,0.12,0.4)
	scale = Vector3.ONE*radius/0.2

func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh

func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	return mesh

func _add_mesh(mesh: Mesh, offset: Vector3, angles := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	instance.rotation = angles
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func sync(projectile: SlasherHostileProjectile) -> void:
	visible = projectile.visible and not projectile.impacted
	rotation = Vector3(0,atan2(-projectile.direction.x,-projectile.direction.y),0)
	if visual_type in ["bone","knife"]:
		rotation.z = projectile.age*12.0
	if visual_type == "spore":
		var pulse := 1.0+sin(projectile.age*12.0)*0.10
		scale = Vector3.ONE*clampf(projectile.hit_radius/48.0,0.12,0.4)/0.2*pulse
	var colour := Color("dffcff") if is_instance_valid(projectile.deflected_by) else projectile.tint
	material.albedo_color = colour
	material.emission = colour
