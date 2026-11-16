"""Build sprite-matched mage and spell GLBs. Blender Z-up, metres."""
import math
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/mage"
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.preferences.filepaths.save_version = 0

def material(name, color, metallic=0, emission=0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = .55
    shader.inputs["Emission Color"].default_value = (*color, 1)
    shader.inputs["Emission Strength"].default_value = emission
    return result

navy = material("Midnight blue wool", (.025,.085,.15))
blue = material("Blue coat panels", (.035,.19,.30))
gold = material("Warm gold piping", (.8,.43,.08), .7)
skin = material("Warm brown skin", (.34,.16,.075))
hair = material("Dark curls and beard", (.035,.023,.017))
leather = material("Dark leather", (.045,.033,.026))
cyan = material("Arcane crystal", (.025,.55,1), .25, 3)
white = material("Spell core", (.5,.9,1), 0, 5)
fire = material("Fire shell", (1,.13,.008), 0, 3)
ember = material("Fire core", (1,.65,.035), 0, 5)

def empty(name, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    return obj

def sphere(name, location, scale, mat, parent, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1)
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    obj.location = location
    obj.scale = scale
    obj.data.materials.append(mat)
    return obj

def cone(name, location, lower, upper, depth, mat, parent, vertices=12):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=lower, radius2=upper, depth=depth)
    obj = bpy.context.object
    obj.name = name
    obj.parent = parent
    obj.location = location
    obj.data.materials.append(mat)
    return obj

def rod(name, start, end, radius, mat, parent):
    delta = Vector(end)-Vector(start)
    obj = cone(name, (Vector(start)+Vector(end))/2, radius, radius, delta.length, mat, parent, 8)
    obj.rotation_euler = delta.to_track_quat("Z","Y").to_euler()
    return obj

mage = empty("Mage")
for x in [-.14,.14]:
    sphere("Boot", (x,-.055,.12), (.115,.18,.12), leather, mage)
    rod("Trouser", (x,0,.18), (x,0,.65), .095, leather, mage)
cone("Coat skirt", (0,0,.69), .34,.22,.55, navy, mage)
cone("Gold hem", (0,0,.425), .345,.339,.025, gold, mage)
cone("Coat torso", (0,0,1.04), .23,.29,.48, navy, mage)
cone("Belt", (0,0,.84), .244,.244,.065, leather, mage)
sphere("Buckle", (0,-.245,.84), (.055,.018,.05), gold, mage)
for x in [-.09,.09]:
    rod("Front gold piping", (x,-.22,.46), (x,-.245,1.21), .012, gold, mage)
    sphere("Blue skirt panel", (x*2,-.17,.64), (.1,.06,.19), blue, mage)
cone("High gold collar", (0,0,1.29), .205,.22,.065, gold, mage)
cone("High blue collar", (0,0,1.32), .20,.21,.06, blue, mage)
sphere("Head", (0,-.015,1.53), (.19,.165,.235), skin, mage)
sphere("Hair cap", (0,.015,1.70), (.2,.17,.105), hair, mage)
for index in range(18):
    angle = index*2.4
    radius = .15*math.sqrt((index+1)/18)
    sphere("Sculpted curl", (math.cos(angle)*radius, math.sin(angle)*radius,1.735-.1*radius), (.055,.05,.05), hair, mage, 1)
for x in [-.19,.19]:
    sphere("Ear", (x,0,1.54), (.04,.035,.065), skin, mage)
for x in [-.073,.073]:
    sphere("Eye", (x,-.165,1.56), (.033,.012,.023), leather, mage)
    rod("Brow", (x-.035,-.17,1.61), (x+.035,-.17,1.61), .014, hair, mage)
sphere("Nose", (0,-.18,1.52), (.035,.045,.045), skin, mage)
sphere("Beard", (0,-.115,1.405), (.135,.075,.08), hair, mage)
sphere("Moustache", (0,-.175,1.455), (.085,.02,.023), hair, mage)
arms = []
for side in [-1,1]:
    pivot = empty("LeftArm" if side < 0 else "StaffArm", mage)
    pivot.location = (side*.28,0,1.23)
    rod("Sleeve", (0,0,0), (side*.075,-.01,-.28), .105, blue, pivot)
    cone("Gold cuff", (side*.075,-.01,-.28), .11,.11,.045, gold, pivot)
    sphere("Hand", (side*.075,-.02,-.37), (.075,.075,.095), skin, pivot)
    arms.append(pivot)
staff = empty("CrystalStaff", arms[1])
rod("Staff shaft", (.11,-.035,-1.15), (.11,-.035,.25), .027, leather, staff)
rod("Gold staff setting", (.11,-.035,.18), (.11,-.035,.38), .045, gold, staff)
crystal = sphere("Blue focus crystal", (.11,-.035,.43), (.075,.065,.16), cyan, staff, 1)
sphere("Cape", (0,.17,.98), (.30,.075,.37), navy, mage)
for x in [-.25,.25]:
    rod("Cape gold edging", (x,.20,.67), (x*.85,.19,1.25), .012, gold, mage)

# Object animation keeps the separated low-poly parts editable in Blender and Godot.
def animate(name, frames, poses, loop=True):
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = frames
    for obj, values in poses:
        for frame, rotation in values:
            obj.rotation_euler = rotation
            obj.keyframe_insert("rotation_euler", frame=frame)
        obj.animation_data.action.name = name + "_" + obj.name
        track = obj.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, obj.animation_data.action)
        obj.animation_data.action = None

animate("Idle", 60, [(arms[0], [(1,(0,0,0)),(30,(.035,0,0)),(60,(0,0,0))])])
animate("Run", 24, [(arm, [(1,(side*.4,0,0)),(12,(-side*.4,0,0)),(24,(side*.4,0,0))]) for arm,side in zip(arms,[-1,1])])
animate("Cast", 24, [(arms[0], [(1,(0,0,0)),(8,(-1.3,0,-.25)),(16,(-1.3,0,-.25)),(24,(0,0,0))])], False)

missile = empty("ArcaneMissile")
sphere("Missile core", (0,0,0), (.11,.28,.11), white, missile, 1)
for index in range(4):
    angle = index*math.pi/2
    sphere("Arcane fin", (.12*math.cos(angle),.10,.12*math.sin(angle)), (.045,.31,.045), cyan, missile, 1)
fireball = empty("Fireball")
sphere("Flame shell", (0,0,0), (.23,.30,.23), fire, fireball)
sphere("Hot core", (0,-.12,0), (.17,.22,.17), ember, fireball)
for index in range(7):
    angle=index*2.4
    sphere("Flame tongue", (.14*math.cos(angle),.21,.14*math.sin(angle)), (.08,.28,.08), fire, fireball, 1)

def select_tree(root):
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for child in root.children_recursive:
        child.select_set(True)

for root, filename in [(mage,"mage"),(missile,"arcane_missile"),(fireball,"fireball")]:
    select_tree(root)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(filename+".glb")), use_selection=True, export_animation_mode="NLA_TRACKS")

# A reusable studio scene provides a reviewable preview alongside the source.
missile.location=(1,0,.85)
fireball.location=(-1,0,.85)
scene=bpy.context.scene
scene.render.engine="CYCLES"
scene.cycles.samples=32
scene.render.resolution_x=1200
scene.render.resolution_y=1000
scene.render.resolution_percentage=100
scene.world.color=(.12,.12,.12)
bpy.ops.object.camera_add(location=(3,-6,2.8))
camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,.9))-camera.location).to_track_quat("-Z","Y").to_euler()
camera.data.type="ORTHO"
camera.data.ortho_scale=3.5
scene.camera=camera
for location,energy,size in [((2,-4,5),650,4),((-3,-1,3),450,3),((0,3,4),800,3)]:
    bpy.ops.object.light_add(type="AREA",location=location)
    light=bpy.context.object
    light.data.energy=energy
    light.data.shape="DISK"
    light.data.size=size
    light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat("-Z","Y").to_euler()
scene.frame_set(1)
source_dir = OUT / "source"
source_dir.mkdir(exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source_dir/"mage_studio.blend"))
scene.render.filepath=str(OUT/"preview.png")
bpy.ops.render.render(write_still=True)
