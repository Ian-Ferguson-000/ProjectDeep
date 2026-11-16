"""Convert the supplied rigged Shadowkin FBX to the game's mage GLB."""
import argparse
import math
from pathlib import Path
import bpy
from mathutils import Vector, Quaternion

parser = argparse.ArgumentParser()
parser.add_argument("fbx")
args = parser.parse_args(__import__("sys").argv[__import__("sys").argv.index("--")+1:])
root = Path(__file__).resolve().parents[2]
out = root / "assets/models/mage"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=args.fbx)
rig = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
rig.animation_data_clear()
for bone in rig.pose.bones:
    bone.matrix_basis.identity()

# Bake palette changes into a copy of the supplied albedo, retaining its wear.
import numpy as np
textures = Path(args.fbx).parent / "Textures"
for mat in mesh.data.materials:
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    output = nodes.new("ShaderNodeOutputMaterial")
    mat.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    for suffix, socket in [("Base_color","Base Color"),("Roughness","Roughness"),("Metallic","Metallic"),("Normal_OpenGL","Normal")]:
        image = bpy.data.images.load(str(textures / (mat.name+"_"+suffix+".png")), check_existing=True)
        image.scale(2048,2048)
        if suffix == "Base_color":
            pixels = np.array(image.pixels[:], dtype=np.float32).reshape(-1,4)
            rgb = pixels[:,:3]
            if mat.name == "Pants":
                red = (rgb[:,0] > rgb[:,1]*1.35) & (rgb[:,0] > rgb[:,2]*1.35)
                value = rgb[red].max(axis=1)
                rgb[red] = value[:,None]*np.array([.12,.42,.85])
            else:
                value = rgb.max(axis=1)
                rgb[:] = value[:,None]*np.array([1,.69,.26])
            image.pixels.foreach_set(pixels.ravel())
            image.update()
        else:
            image.colorspace_settings.name = "Non-Color"
        image.pack()
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = image
        if socket == "Normal":
            normal = nodes.new("ShaderNodeNormalMap")
            mat.node_tree.links.new(texture.outputs["Color"],normal.inputs["Color"])
            mat.node_tree.links.new(normal.outputs["Normal"],shader.inputs[socket])
        else:
            mat.node_tree.links.new(texture.outputs["Color"],shader.inputs[socket])

# Normalize the original centimetre-scale asset to a 1.75 metre character.
corners = [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
height = max(v.z for v in corners)-min(v.z for v in corners)
holder = bpy.data.objects.new("ShadowkinMage",None)
bpy.context.collection.objects.link(holder)
rig.parent = holder
holder.scale = (1.75/height,)*3
holder.location.z = -min(v.z for v in corners)*holder.scale.z

# Animate around character-space axes, converted through each bone's rest basis.
# This avoids rolling the arms when lowering them out of the supplied T-pose.
def rotate_bone(name, axis, angle):
    bone = rig.pose.bones[name]
    local_axis = bone.bone.matrix_local.to_3x3().inverted() @ Vector(axis)
    bone.rotation_quaternion = Quaternion(local_axis,angle) @ bone.rotation_quaternion

def smoothstep(value):
    value = max(0.0,min(1.0,value))
    return value*value*(3-2*value)

scene = bpy.context.scene
scene.render.fps = 30
for name, duration in [("Idle",90),("Run",24),("Cast",18)]:
    rig.animation_data_create()
    rig.animation_data.action = None
    for frame in range(1,duration+2):
        progress = (frame-1)/duration
        phase = progress*math.tau
        for bone in rig.pose.bones:
            bone.rotation_mode = "QUATERNION"
            bone.rotation_quaternion = Quaternion()
            bone.location = (0,0,0)
        # A relaxed, slightly bent elbow silhouette in all three clips.
        for side, sign in [("L",1),("R",-1)]:
            prefix = "CC_Base_"+side+"_"
            rotate_bone(prefix+"Upperarm",(0,1,0),sign*math.radians(76))
            rotate_bone(prefix+"Forearm",(1,0,0),-.20)
            if name == "Run":
                stride = phase+(0 if side == "L" else math.pi)
                swing = math.sin(stride)
                lift = max(0.0,-math.cos(stride))
                rotate_bone(prefix+"Thigh",(1,0,0),swing*.62)
                rotate_bone(prefix+"Calf",(1,0,0),.18+lift*1.05)
                rotate_bone(prefix+"Foot",(1,0,0),-swing*.23-lift*.30)
                rotate_bone(prefix+"Upperarm",(1,0,0),-swing*.36-.12)
                rotate_bone(prefix+"Forearm",(1,0,0),-.55-lift*.18)
                rotate_bone(prefix+"Clavicle",(0,0,1),sign*swing*.035)
            elif name == "Cast":
                # Release begins immediately, matching the gameplay projectile.
                # A short recoil settles into the shared idle pose.
                extension = 1-smoothstep((progress-.18)/.82)
                if side == "L":
                    rotate_bone(prefix+"Upperarm",(1,0,0),-1.35*extension)
                    rotate_bone(prefix+"Forearm",(1,0,0),-.18*extension)
                    rotate_bone(prefix+"Hand",(1,0,0),.18*extension)
                else:
                    rotate_bone(prefix+"Upperarm",(1,0,0),-.35*extension)
                    rotate_bone(prefix+"Forearm",(1,0,0),-.7*extension)
            elif name == "Idle":
                rotate_bone(prefix+"Upperarm",(1,0,0),math.sin(phase)*.018)
            for finger in ["Index","Mid","Ring","Pinky"]:
                for joint in [1,2,3]:
                    rotate_bone(prefix+finger+str(joint),(1,0,0),-.12)
        if name == "Run":
            rotate_bone("CC_Base_Waist",(1,0,0),.10)
            rotate_bone("CC_Base_Pelvis",(0,0,1),math.sin(phase)*.06)
            rotate_bone("CC_Base_Spine02",(0,0,1),-math.sin(phase)*.08)
            rotate_bone("CC_Base_Head",(1,0,0),-.07)
            bob = (.5-.5*math.cos(phase*2))*.028
            hip = rig.pose.bones["CC_Base_Hip"]
            hip.location = hip.bone.matrix_local.to_3x3().inverted() @ Vector((0,0,bob/holder.scale.z))
        elif name == "Cast":
            extension = 1-smoothstep((progress-.18)/.82)
            rotate_bone("CC_Base_Spine02",(0,0,1),-.12*extension)
            rotate_bone("CC_Base_Spine01",(1,0,0),-.07*extension)
        else:
            rotate_bone("CC_Base_Spine02",(1,0,0),math.sin(phase)*.012)
        for index in range(1,9):
            rotate_bone("Cloak"+str(index),(1,0,0),
                        (.08+math.sin(phase-.35*index)*.025) if name == "Run" else math.sin(phase-.25*index)*.012)
        for bone in rig.pose.bones:
            bone.keyframe_insert("rotation_quaternion",frame=frame,group=bone.name)
        rig.pose.bones["CC_Base_Hip"].keyframe_insert("location",frame=frame)
    action = rig.animation_data.action
    action.name = name
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name,1,action)
    rig.animation_data.action = None
    track.mute = True

bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action="DESELECT")
for obj in [holder,rig,mesh]:
    obj.select_set(True)
for track in rig.animation_data.nla_tracks:
    track.mute = False
bpy.ops.export_scene.gltf(filepath=str(out/"shadowkin_mage.glb"),use_selection=True,export_animation_mode="NLA_TRACKS")
for track in rig.animation_data.nla_tracks:
    track.mute = track.name != "Idle"
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(out/"source/shadowkin_mage.blend"))

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 900
scene.render.resolution_y = 1000
scene.render.resolution_percentage = 100
scene.world.color = (.15,.15,.15)
bpy.ops.object.camera_add(location=(3,-5,2.4))
camera = bpy.context.object
camera.rotation_euler = (Vector((0,0,.9))-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.5
scene.camera = camera
for location in [(2,-4,5),(-3,-2,3),(0,3,4)]:
    bpy.ops.object.light_add(type="AREA",location=location)
    light = bpy.context.object
    light.data.energy = 450
    light.data.size = 4
    light.rotation_euler = (Vector((0,0,1))-light.location).to_track_quat("-Z","Y").to_euler()
scene.render.filepath = str(out/"shadowkin_preview.png")
bpy.ops.render.render(write_still=True)
scene.render.resolution_percentage = 50
for clip, frames in [("Run",[4,10,16,22]),("Cast",[1,7,13,19])]:
    for track in rig.animation_data.nla_tracks:
        track.mute = track.name != clip
    for frame in frames:
        scene.frame_set(frame)
        scene.render.filepath = str(out/"source"/(clip.lower()+"_"+str(frame)+".png"))
        bpy.ops.render.render(write_still=True)
