"""Render preview stills of the colossus from the game's camera angle.

    blender -b heartwood_colossus.blend --python render_previews.py -- <out_dir> [action:frame ...]

The camera copies the 3D dungeon camera (forest_world_3d.gd): orthographic,
sitting at offset (10, 23, 18) in Godot from what it looks at, i.e.
(10, -18, 23) in Blender. A grass ground plane gives the colours some context.
Without action:frame pairs it renders a set covering every move.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1 :]
out_dir = argv[0]
shots = argv[1:] or [
    "Idle:1", "RootSlamL:20", "RootSlamL:28", "SporeBloom:30",
    "ThornSpiral:1", "Roar:20", "Hit:4", "Death:90",
]
os.makedirs(out_dir, exist_ok=True)

scene = bpy.context.scene
rig = bpy.data.objects["HeartwoodColossusRig"]
for track in rig.animation_data.nla_tracks:
    track.mute = True

# Ground.
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, -4, -0.02))
ground = bpy.context.object
mat = bpy.data.materials.new("preview_ground")
mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.13, 0.2, 0.09, 1)
ground.data.materials.append(mat)

# Light: roughly the dungeon sun (Godot rotation -52, -28) plus soft fill.
bpy.ops.object.light_add(type="SUN", location=(0, 0, 10))
sun = bpy.context.object
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(45), 0, math.radians(30))
world = bpy.data.worlds.new("preview_world")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.2, 0.24, 0.28, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
scene.world = world

# Camera.
target = Vector((0, -1.0, 3.4))
bpy.ops.object.camera_add(location=target + Vector((10, -18, 23)).normalized() * 40)
cam = bpy.context.object
cam.data.type = "ORTHO"
cam.data.ortho_scale = 16
direction = target - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 48
scene.cycles.use_denoising = False
scene.render.resolution_x = 520
scene.render.resolution_y = 520

for shot in shots:
    name, frame = shot.split(":")
    rig.animation_data.action = bpy.data.actions[name]
    scene.frame_set(int(frame))
    scene.render.filepath = os.path.join(out_dir, "%s_%s.png" % (name, frame))
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)
