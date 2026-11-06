"""Build the Hearth's editable room kit. Run with Blender --background --python.
All dimensions are metres; Blender Z-up is converted to Godot Y-up by glTF.
No downloaded assets, external textures, or Blender addons are required.
"""
import bpy
import math
import random
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
random.seed(17)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for data in list(bpy.data.materials):
    bpy.data.materials.remove(data)
scene = bpy.context.scene
bpy.context.preferences.filepaths.save_version = 0
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
materials = {}
groups = {}
current = None

def material(name, color, metal=0, rough=.72, emission=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    if emission:
        bsdf.inputs['Emission Color'].default_value = (*color, 1)
        bsdf.inputs['Emission Strength'].default_value = emission
    materials[name] = m
    return m

material('Oak / structural', (.14,.064,.026))
material('Oak / cut edges', (.30,.15,.058))
material('Oak / counter', (.37,.18,.057), rough=.38)
for i in range(6):
    material(f'Floor / oak {i+1}', (.22+i*.018,.105+i*.010,.043+i*.005))
material('Plaster / honey', (.62,.43,.24))
material('Plaster / cream', (.73,.57,.36))
material('Stone / warm limestone', (.30,.29,.26))
material('Stone / light edge', (.43,.41,.35))
material('Iron / forged', (.055,.063,.066), .72,.38)
material('Brass / aged', (.48,.29,.075), .72,.32)
material('Rug / wine', (.24,.027,.037))
material('Rug / ochre border', (.63,.37,.09))
material('Bottle / green', (.055,.22,.10), rough=.24)
material('Bottle / amber', (.34,.115,.026), rough=.24)
material('Bottle / blue', (.035,.13,.20), rough=.24)
material('Ceramic / cream', (.73,.67,.48), rough=.4)
material('Lantern / warm glass', (1,.38,.055), rough=.35, emission=3)
material('Fire / embers', (1,.10,.012), emission=4)
material('Fire / gold', (1,.48,.035), emission=5)

def group(name):
    global current
    coll = bpy.data.collections.new(name)
    scene.collection.children.link(coll)
    obj = bpy.data.objects.new(name, None)
    coll.objects.link(obj)
    groups[name] = (coll,obj)
    current = groups[name]
    return obj

def finish(obj,name,mat):
    obj.name = name
    for c in list(obj.users_collection): c.objects.unlink(obj)
    current[0].objects.link(obj)
    obj.parent=current[1]
    if mat: obj.data.materials.append(materials[mat])
    return obj

def box(name,loc,size,mat='Oak / structural',bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=bpy.context.object
    o.dimensions=size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(o,name,mat)
    if bevel:
        mod=o.modifiers.new('Small worn edges','BEVEL'); mod.width=bevel; mod.segments=1
        mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
    return o

def cylinder(name,loc,radius,depth,mat,vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    return finish(bpy.context.object,name,mat)

def beam(name,a,b,width,depth=None,mat='Oak / structural'):
    a,b=Vector(a),Vector(b)
    o=box(name,(a+b)/2,(width,depth or width,(b-a).length),mat,.015)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return o

def torus(name,loc,major,minor,mat):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=12,minor_segments=4,location=loc)
    return finish(bpy.context.object,name,mat)

def lantern(x,y,z):
    box('Lantern glowing glass',(x,y,z),(.18,.18,.30),'Lantern / warm glass',.015)
    for h in [-.19,.19]: box('Lantern iron cap',(x,y,z+h),(.25,.25,.07),'Iron / forged')
    for dx in [-.105,.105]:
        for dy in [-.105,.105]: box('Lantern frame',(x+dx,y+dy,z),(.025,.025,.34),'Iron / forged',.003)
    ring=torus('Lantern hanging ring',(x,y,z+.3),.07,.014,'Iron / forged');ring.rotation_euler.x=math.pi/2
    bpy.ops.object.light_add(type='POINT',location=(x,y-.15,z))
    light=finish(bpy.context.object,'Lantern light',None)
    light.data.energy=48;light.data.color=(1,.50,.19);light.data.shadow_soft_size=.6

group('Floor')
box('Foundation',(0,0,-.22),(18.5,11.5,.44),'Stone / warm limestone',.08)
# Reusable planks: linked geometry for each colour/length, with staggered joints.
plank_cache={}
for row in range(28):
    y=-5.5+(row+.5)*(11/28)
    start=-9
    lengths=([1.5]+[3]*5+[1.5]) if row%2 else [3]*6
    for length in lengths:
        variant=random.randrange(6);key=(length,variant)
        loc=(start+length/2,y,.005)
        if key in plank_cache:
            src=plank_cache[key];o=src.copy();o.data=src.data;current[0].objects.link(o);o.location=loc
        else:
            o=box('Floor plank',loc,(length-.018,11/28-.015,.10),f'Floor / oak {variant+1}',.008);plank_cache[key]=o
        start+=length
for x in [-9,9]:
    for y in [-3.3,3.3]: box('Perimeter sill',(x,y,.12),(.22,4.4,.24))
box('Rear sill',(0,5.5,.12),(18.2,.22,.24))
for x in [-5.125,5.125]: box('Front sill',(x,-5.5,.12),(7.75,.22,.24))

# Panels are grouped by wall, so either near wall can be hidden for a cutaway.
def wall_run(name,axis,fixed,start,end,door=None):
    group(name)
    spans=[(start,end)] if door is None else [(start,door[0]),(door[1],end)]
    def point(t,z,offset=0): return (t,fixed+offset,z) if axis=='X' else (fixed+offset,t,z)
    def size(length,depth,height):return (length,depth,height) if axis=='X' else (depth,length,height)
    for a,b in spans:
        count=math.ceil((b-a)/2.1)
        for i in range(count):
            lo=a+(b-a)*i/count;hi=a+(b-a)*(i+1)/count;mid=(lo+hi)/2
            box('Plaster infill',point(mid,1.9),size(hi-lo,.20,3.6),'Plaster / honey',.015)
            box('Oak lower panel',point(mid,.57),size(hi-lo,.27,.95),'Oak / cut edges')
            for t in ([lo,hi] if i == count-1 else [lo]):box('Wall post',point(t,1.85),size(.18,.34,3.7))
            # Brace on the inward-facing surface.
            inward=-.18 if fixed>0 else .18
            beam('Diagonal brace',point(lo+.14,1.28,inward),point(hi-.14,3.36,inward),.13,.14)
        for z in [.20,1.10,3.52]:box('Continuous wall rail',point((a+b)/2,z),size(b-a,.36,.18))
    if door:
        a,b=door;mid=(a+b)/2
        for t in door:
            box('Door jamb',point(t,1.45),size(.28,.48,2.9),'Oak / cut edges')
            box('Door stone foot',point(t,.19),size(.36,.52,.38),'Stone / light edge')
        box('Door lintel',point(mid,2.86),size(b-a+.5,.48,.28),'Oak / cut edges')
        box('Door overpanel',point(mid,3.3),size(b-a,.20,.62),'Plaster / honey')
        box('Door threshold',point(mid,.07),size(b-a,.65,.12),'Stone / light edge')
wall_run('RearWall','X',5.5,-9,9)
wall_run('WestWall','Y',-9,-5.5,5.5,(-1.1,1.1))
wall_run('EastWall','Y',9,-5.5,5.5,(-1.1,1.1))
wall_run('FrontWall','X',-5.5,-9,9,(-1.25,1.25))
# Door labels as metadata survive in the source without image textures.
groups['WestWall'][1]['passage']='Lodgings'
groups['EastWall'][1]['passage']='Training yard'
groups['FrontWall'][1]['passage']='Main entrance'

group('CeilingBeams')
# Leave a stairwell opening above the northeast stair flight.
for x in [-6,-2,2]:
    box('Overhead crossbeam',(x,0,3.72),(.23,11.2,.30))
    for y in [-5.3,5.3]:beam('Knee brace',(x,y,2.9),(x,y-math.copysign(.8,y),3.65),.18)

box('Stairwell front beam',(6,-2.35,3.72),(.23,6.3,.30))

group('Bar')
# Main bar at the back, with a 1.15m working aisle.
box('Counter carcass',(-1.1,2.75,.54),(4.6,.76,1.02),'Oak / cut edges',.04)
box('Counter top',(-1.1,2.75,1.12),(4.95,1.05,.17),'Oak / counter',.05)
for x in [-3.35,-2.2,-1.1,0,1.15]:box('Counter front post',(x,2.32,.57),(.14,.12,1.02))
for z in [.18,.92]:box('Counter front rail',(-1.1,2.31,z),(4.6,.13,.12))
beam('Brass foot rail',(-3.35,2.12,.24),(1.15,2.12,.24),.055,mat='Brass / aged')
for x in [-3.1,0.9]:beam('Foot rail bracket',(x,2.1,.24),(x,2.4,.24),.05,mat='Brass / aged')
box('Backbar cabinet',(-1.1,5.0,.48),(4.9,.6,.92),'Oak / cut edges')
box('Bottle shelf back',(-1.1,5.24,1.95),(4.9,.14,2.0))
for x in [-3.6,-1.1,1.4]:box('Shelf upright',(x,4.95,1.9),(.17,.62,2.4))
for z in [.98,1.64,2.3,3.03]:box('Shelf board',(-1.1,4.96,z),(5.1,.68,.12),'Oak / counter')
for level,z in enumerate([1.05,1.71,2.37]):
    for i in range(15):
        x=-3.36+i*.316+random.uniform(-.035,.035)
        h=random.uniform(.26,.43);mat=random.choice(['Bottle / green','Bottle / amber','Bottle / blue'])
        cylinder('Bottle body',(x,4.94,z+h*.42),.075,h*.84,mat)
        cylinder('Bottle neck',(x,4.94,z+h*.96),.035,h*.28,mat)
        cylinder('Cork',(x,4.94,z+h*1.12),.036,.035,'Oak / cut edges')
for x in [-2.7,-.4,.6]:
    cylinder('Counter tankard',(x,2.72,1.34),.10,.25,'Ceramic / cream')
    handle=torus('Tankard handle',(x+.11,2.72,1.35),.075,.02,'Brass / aged');handle.rotation_euler.x=math.pi/2

group('Staircase')
# Actual 0.21m risers; top landing deliberately stops at the shell's future upper floor.
for i in range(12):
    h=(i+1)*.21;y=1.45+i*.31
    box(f'Step {i+1:02}',(6.5,y,h/2),(2.05,.32,h),'Oak / cut edges',.015)
    box('Tread nosing',(6.5,y-.025,h+.025),(2.12,.36,.05),'Oak / counter',.01)
for x in [5.4,7.6]:
    for i in [0,4,8,11]:box('Stair baluster',(x,1.45+i*.31,(i+1)*.21+.47),(.10,.10,.94))
    beam('Stair handrail',(x,1.40,1.13),(x,4.91,3.49),.13,mat='Oak / counter')
box('Upper landing',(6.5,5.04,2.55),(2.18,.60,.15),'Oak / counter')

group('Hearth')
box('Hearth stone slab',(-7.9,3.35,.15),(1.9,3.1,.30),'Stone / light edge',.07)
box('Chimney breast',(-8.58,3.35,2.45),(.76,2.65,2.5),'Stone / warm limestone',.06)
for y in [2.18,4.52]:
    for z in [.48,.90,1.32]:box('Fireplace pier',(-8.25,y,z),(1.1,.38,.40),'Stone / light edge',.04)
box('Fireplace lintel',(-8.22,3.35,1.57),(1.2,2.8,.36),'Stone / light edge',.05)
box('Oak mantel',(-8.14,3.35,1.82),(1.40,2.98,.18),'Oak / counter',.04)
box('Soot recess',(-8.8,3.35,.90),(.05,1.95,1.1),'Iron / forged',0)
for i in range(4):
    log=cylinder('Hearth log',(-8.08,2.8+i*.34,.43),.12,.85,'Oak / structural');log.rotation_euler.y=math.pi/2
for i in range(7):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(-8.03,2.65+i*.22,.68))
    flame=finish(bpy.context.object,'Stylized flame','Fire / gold' if i%2 else 'Fire / embers');flame.scale=(.15,.13,random.uniform(.25,.44))
bpy.ops.object.light_add(type='POINT',location=(-7.6,3.35,1.0));fire=finish(bpy.context.object,'Hearth glow',None);fire.data.energy=180;fire.data.color=(1,.28,.055);fire.data.shadow_soft_size=1.0

def barrel(x,y):
    # Low-poly bulged staves, with shared iron hoops.
    n=12;verts=[];faces=[]
    for z,r in [(0,.33),(.1,.38),(.5,.44),(.9,.38),(1,.33)]:
        for i in range(n):verts.append((x+r*math.cos(i*2*math.pi/n),y+r*math.sin(i*2*math.pi/n),z))
    for ring in range(4):
        for i in range(n):faces.append((ring*n+i,ring*n+(i+1)%n,(ring+1)*n+(i+1)%n,(ring+1)*n+i))
    faces.extend([tuple(range(n-1,-1,-1)),tuple(4*n+i for i in range(n))])
    mesh=bpy.data.meshes.new('Barrel stave mesh');mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new('Ale barrel',mesh);current[0].objects.link(o);o.parent=current[1];o.data.materials.append(materials['Oak / cut edges'])
    for z,r in [(.13,.39),(.5,.445),(.87,.39)]:torus('Barrel iron hoop',(x,y,z),r,.027,'Iron / forged')
    cylinder('Barrel lid',(x,y,1.01),.33,.035,'Oak / counter')

group('Furniture')
for x,y in [(-5.1,3.9),(-4.3,4.5),(-5.2,4.9)]:barrel(x,y)
for tx,ty in [(-4.6,-.55),(4.55,-.55),(-3.8,-3.25)]:
    for i in range(5):box('Table top plank',(tx,ty+(i-2)*.25,.88),(2.0,.244,.13),'Oak / counter',.018)
    for dx in [-.72,.72]:
        for dy in [-.42,.42]:box('Table leg',(tx+dx,ty+dy,.43),(.13,.13,.85))
    beam('Table stretcher',(tx-.72,ty,.28),(tx+.72,ty,.28),.13)
    for dy in [-1.0,1.0]:
        box('Bench seat',(tx,ty+dy,.48),(2.05,.34,.12),'Oak / counter')
        for dx in [-.72,.72]:box('Bench leg',(tx+dx,ty+dy,.23),(.16,.25,.46))
    for dx in [-.5,.5]:
        cylinder('Table plate',(tx+dx,ty,.968),.19,.024,'Ceramic / cream',16)
        cylinder('Table cup',(tx+dx,ty+.32,1.04),.065,.17,'Ceramic / cream')
    cylinder('Table candle holder',(tx,ty,1.0),.11,.08,'Brass / aged')
    cylinder('Table candle',(tx,ty,1.12),.04,.20,'Ceramic / cream')
    cylinder('Candle flame',(tx,ty,1.24),.025,.055,'Lantern / warm glass',6)
# Rug leaves the entrance circulation route open.
box('Company rug border',(.7,-2.4,.072),(3.15,2.55,.025),'Rug / ochre border',.01)
box('Company rug field',(.7,-2.4,.09),(2.93,2.33,.015),'Rug / wine',.006)
for x in [-.56,1.96]:box('Rug woven stripe',(x,-2.4,.101),(.035,2.12,.008),'Rug / ochre border',0)
for y in [-3.43,-1.37]:box('Rug woven stripe',(.7,y,.101),(2.55,.035,.008),'Rug / ochre border',0)
# A simple geometric hearth emblem.
emblem=box('Rug diamond',(.7,-2.4,.105),(.58,.58,.009),'Rug / ochre border',0);emblem.rotation_euler.z=math.pi/4
emblem=box('Rug diamond inset',(.7,-2.4,.111),(.40,.40,.009),'Rug / wine',0);emblem.rotation_euler.z=math.pi/4

group('WallDetails')
for x in [-6,-1.1,3.3,8.2]:
    beam('Lantern wall bracket',(x,5.38,2.8),(x,4.99,2.8),.055,mat='Iron / forged')
    lantern(x,4.98,2.45)
# Notice board by the lodgings entrance, rotated to face inward.
box('Notice board',(-8.70,-2.1,1.85),(.15,1.35,1.1),'Oak / counter')
for i in range(4):box('Notice parchment',(-8.61,-2.48+(i%2)*.58,1.62+(i//2)*.45),(.015,.40,.33),'Ceramic / cream',.002)

# Lighting and presentation objects are kept out of the GLB export.
group('Presentation')
def area(name,loc,power,size,color,target=(0,0,0)):
    bpy.ops.object.light_add(type='AREA',location=loc);o=finish(bpy.context.object,name,None);o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=color;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
area('Large warm skylight',(1,-3,12),2100,10,(1,.79,.55))
area('Cool window fill',(4,5,8),1600,8,(.58,.72,1))
area('Front fill',(-3,-9,6),1100,8,(1,.88,.72))
bpy.ops.object.camera_add(location=(19,-25,23));cam=finish(bpy.context.object,'Room overview',None);cam.rotation_euler=(Vector((0,0,1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=25;scene.camera=cam
scene.render.engine='CYCLES';scene.cycles.samples=32
scene.cycles.use_denoising=True
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.color=(.16,.16,.16)
scene.view_settings.view_transform='AgX'
# Cutaway is only a presentation setting; all room meshes export.
for name in ['FrontWall','EastWall','CeilingBeams']:
    groups[name][0].hide_render=True
    groups[name][0].hide_viewport=True
# Export a full room with explicit selection, unaffected by preview visibility.
for coll,root in groups.values():coll.hide_viewport=False
bpy.ops.object.select_all(action='DESELECT')
for name,(coll,root) in groups.items():
    if name=='Presentation':continue
    for o in coll.objects:
        if o.type in {'MESH','EMPTY'}:o.select_set(True)
export_path=ROOT/'assets/tavern3d/hearth_room.glb'
bpy.ops.export_scene.gltf(filepath=str(export_path),export_format='GLB',use_selection=True,export_apply=True,export_cameras=False,export_lights=False,export_extras=True)
# Evaluate geometry, not just unmodified source meshes.
triangles=0;mesh_count=0
for o in scene.objects:
    if o.type=='MESH':
        mesh_count+=1;mesh=o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh();mesh.calc_loop_triangles();triangles+=len(mesh.loop_triangles);o.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
for name in ['FrontWall','EastWall','CeilingBeams']:groups[name][0].hide_viewport=True
bpy.ops.object.select_all(action='DESELECT')
# Opening the source file starts in a useful material-shaded camera view.
for screen in bpy.data.screens:
    for a in screen.areas:
        if a.type=='VIEW_3D':
            a.spaces.active.region_3d.view_perspective='CAMERA'
            a.spaces.active.shading.type='MATERIAL'
scene.render.filepath=str(ROOT/'build/visual_checks/tavern_3d_overview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art_source/tavern/hearth_room.blend'),compress=True)
report={'dimensions_m':[18,11,3.87],'mesh_objects':mesh_count,'evaluated_triangles':triangles,'materials':len(materials),'glb_bytes':export_path.stat().st_size,'source':'tools/blender/build_tavern_room.py','coordinate_system':'Blender Z-up, exported glTF Y-up','door_clear_widths_m':{'entrance':2.22,'lodgings':1.92,'yard':1.92}}
(ROOT/'assets/tavern3d/hearth_room_stats.json').write_text(json.dumps(report,indent=2)+'\n')
print('HEARTH_ROOM_STATS',json.dumps(report),flush=True)
bpy.ops.render.render(write_still=True)
