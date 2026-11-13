"""Build the Heartwood Colossus (forest guardian) in Blender, from scratch.

Run headless:
    blender -b --python build_heartwood_colossus.py -- <out.blend> <out.glb>

Makes one low-poly mesh on an armature, flat-coloured to match the 3D forest
kit, plus one action per move in docs/dungeons/HeartwoodColossus.md.

Units and placement match the code placeholder in
game/dungeons/shared/world_3d/forest_room_art.gd (colossus()): one Blender unit
is one map cell before the game's GOLIATH_SCALE (2.3). The model stands on the
origin and faces -Y in Blender (+Z, south, in Godot), towards the player.
Its left is +X.

Everything is seeded, so a rerun gives the same tree. Edit freely afterwards:
the .blend is the source of truth once someone starts sculpting by hand.
"""

import math
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

RNG = random.Random(1307)
FPS = 30

# ---------------------------------------------------------------- palette
COLOURS = {
    "bark": ("5a4330", 0.0),
    "bark_dark": ("3e2d20", 0.0),
    "bark_light": ("7a5e40", 0.0),
    "hollow": ("140c08", 0.0),
    "leaf_dark": ("2f4a2a", 0.0),
    "leaf": ("43663a", 0.0),
    "leaf_light": ("5f8446", 0.0),
    "blight": ("4a3a52", 0.0),  # corrupted, greyed-purple foliage
    "moss": ("6e8a3e", 0.0),
    "eye": ("c8ff6e", 1.6),  # placeholder used a7d96e; flares red in phase two (in code)
    "heart": ("ffab4a", 1.8),
    "vein": ("d65cff", 1.2),  # corruption running under the bark
    "spore": ("ff8fc8", 0.5),  # the pink spores of Spore Bloom
    "thorn": ("2a1d14", 0.0),
}


def hex_rgb(value):
    """Hex sRGB to the linear values Blender's colour sockets expect."""

    def linear(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return tuple(linear(int(value[i : i + 2], 16) / 255.0) for i in (0, 2, 4))


def make_material(name):
    colour, emission = COLOURS[name]
    mat = bpy.data.materials.new("colossus_" + name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    rgb = hex_rgb(colour)
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    if emission > 0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


# ---------------------------------------------------------------- mesh parts
PARTS = []  # (object, bone name)


def _finish(bm, name, material, bone, jitter=0.0):
    if jitter > 0:
        for v in bm.verts:
            v.co += Vector((RNG.uniform(-1, 1), RNG.uniform(-1, 1), RNG.uniform(-1, 1))) * jitter
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False  # faceted, like the rest of the low-poly forest
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(MATERIALS[material])
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(mesh.vertices))), 1.0, "REPLACE")
    PARTS.append(obj)
    return obj


def tube(name, points, radii, material, bone, sides=7, wobble=0.12, cap=True):
    """A gnarled tube along a polyline: trunk, arms, roots, branches, thorns."""
    bm = bmesh.new()
    rings = []
    points = [Vector(p) for p in points]
    for i, centre in enumerate(points):
        ahead = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
        tangent = ahead.normalized()
        helper = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((1, 0, 0))
        normal = tangent.cross(helper).normalized()
        binormal = tangent.cross(normal).normalized()
        ring = []
        twist = RNG.uniform(0, math.tau)
        for s in range(sides):
            angle = twist * 0.15 + math.tau * s / sides
            r = radii[i] * (1.0 + RNG.uniform(-wobble, wobble))
            offset = normal * math.cos(angle) * r + binormal * math.sin(angle) * r
            ring.append(bm.verts.new(centre + offset))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for s in range(sides):
            bm.faces.new((a[s], a[(s + 1) % sides], b[(s + 1) % sides], b[s]))
    if cap:
        if radii[0] > 0.001:
            bm.faces.new(list(reversed(rings[0])))
        if radii[-1] > 0.001:
            bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _finish(bm, name, material, bone)


def blob(name, centre, radius, material, bone, scale=(1, 1, 1), subdiv=1, jitter=0.12):
    """A lumpy low-poly ball: canopy clumps, knots, the heart, eyes, fists."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in bm.verts:
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
        v.co *= 1.0 + RNG.uniform(-jitter, jitter)
        v.co += Vector(centre)
    return _finish(bm, name, material, bone)


def spike(name, base, tip, radius, material, bone, sides=5):
    mid = Vector(base).lerp(Vector(tip), 0.55)
    return tube(name, [base, mid, tip], [radius, radius * 0.55, 0.0], material, bone, sides, 0.05)


def lerp(a, b, t):
    return a + (b - a) * t


# ---------------------------------------------------------------- the body
SHOULDER = Vector((1.25, -0.15, 3.75))
ELBOW = Vector((2.55, -0.65, 2.85))
WRIST = Vector((2.75, -1.55, 1.05))
KNUCKLE = Vector((2.8, -1.95, 0.4))


def trunk_radius(z):
    # Wide root flare at the foot, a barrel in the middle, narrowing to the crown.
    return 1.55 - 0.42 * min(z, 1.2) / 1.2 * 1.0 + 0.08 * math.sin(z * 1.4) - 0.1 * max(0, z - 3.2)


def trunk_point(z, angle, out=0.0):
    r = trunk_radius(z) + out
    return Vector((math.cos(angle) * r, math.sin(angle) * r * 0.82, z))


def build_body():
    # Trunk, in two rigid halves that overlap at the waist so a bend hides the seam.
    lower_z = [0.0, 0.5, 1.0, 1.6, 2.2, 2.7]
    upper_z = [2.4, 2.9, 3.4, 3.9, 4.4, 4.75]
    tube(
        "TrunkLower",
        [(0.03 * math.sin(z), 0, z) for z in lower_z],
        [trunk_radius(z) for z in lower_z],
        "bark",
        "trunk_lower",
        sides=9,
        wobble=0.1,
    )
    tube(
        "TrunkUpper",
        [(0.05 * math.sin(z * 2), 0.04 * z, z) for z in upper_z],
        [trunk_radius(z) * 0.98 for z in upper_z],
        "bark",
        "trunk_upper",
        sides=9,
        wobble=0.1,
    )
    # Bark ridges and knots so the silhouette isn't a smooth can.
    for i in range(9):
        angle = math.tau * i / 9 + 0.2
        if abs(math.sin(angle) + 1) < 0.35:  # keep the face and heart clear
            continue
        z0 = RNG.uniform(0.3, 1.0)
        z1 = RNG.uniform(3.4, 4.4)
        bone = "trunk_lower"
        pts = [trunk_point(lerp(z0, 2.5, t), angle + t * 0.25, 0.05) for t in (0, 0.5, 1)]
        tube("Ridge%d" % i, pts, [0.16, 0.2, 0.12], "bark_dark", bone, 5, 0.15)
        pts = [trunk_point(lerp(2.5, z1, t), angle + 0.25 + t * 0.2, 0.04) for t in (0, 0.5, 1)]
        tube("RidgeUp%d" % i, pts, [0.12, 0.17, 0.06], "bark_dark", "trunk_upper", 5, 0.15)
    for i in range(5):
        angle = RNG.uniform(0, math.tau)
        if math.sin(angle) < -0.5:
            angle += math.pi
        z = RNG.uniform(1.4, 4.0)
        bone = "trunk_lower" if z < 2.5 else "trunk_upper"
        blob("Knot%d" % i, trunk_point(z, angle, 0.05), 0.28, "bark_light", bone, (1, 1, 0.8), 1)

    # ---- the face, on the upper trunk, facing -Y
    front = -math.pi / 2
    for side in (-1, 1):
        socket = trunk_point(3.45, front + side * 0.38, -0.05)
        blob("EyeSocket%d" % side, socket, 0.3, "hollow", "trunk_upper", (1.2, 0.6, 0.75), 1, 0.05)
        eye = socket + Vector((0, -0.12, 0))
        blob("Eye%d" % side, eye, 0.15, "eye", "trunk_upper", (1.3, 0.6, 0.8), 1, 0.03)
        # A heavy, angry brow: two slanted bark slabs.
        brow_a = trunk_point(3.85, front + side * 0.12, 0.1)
        brow_b = trunk_point(3.62, front + side * 0.62, 0.1)
        tube("Brow%d" % side, [brow_a, brow_b], [0.17, 0.12], "bark_dark", "trunk_upper", 5, 0.1)
    mouth = trunk_point(2.75, front, -0.02)
    blob("Mouth", mouth, 0.45, "hollow", "trunk_upper", (1.5, 0.5, 0.55), 1, 0.08)
    for i in range(6):
        x = (i - 2.5) * 0.2
        top = i % 2 == 0
        base = mouth + Vector((x, -0.15, 0.2 if top else -0.2))
        tip = base + Vector((RNG.uniform(-0.03, 0.03), -0.05, -0.2 if top else 0.18))
        spike("Tooth%d" % i, base, tip, 0.06, "bark_light", "trunk_upper", 4)

    # ---- the heart: a glowing core in a hollow at the foot of the trunk
    heart_at = Vector((0, -1.28, 0.78))
    blob("HeartHollow", heart_at + Vector((0, 0.12, 0)), 0.55, "hollow", "trunk_lower", (1, 0.6, 1.1), 1, 0.05)
    blob("Heart", heart_at, 0.3, "heart", "heart", (1, 0.85, 1.1), 2, 0.06)
    # Root "ribs" caging it, so it reads as protected until it opens.
    for side in (-1, 1):
        a = heart_at + Vector((side * 0.55, 0.15, 0.75))
        b = heart_at + Vector((side * 0.32, -0.3, 0.1))
        c = heart_at + Vector((side * 0.45, 0.0, -0.65))
        tube("Rib%d" % side, [a, b, c], [0.1, 0.09, 0.12], "bark_dark", "trunk_lower", 5, 0.1)

    # ---- corruption veins: glowing violet cracks climbing from the heart
    for v, (start_angle, drift) in enumerate([(-1.9, -0.3), (-1.25, 0.35), (-0.4, 0.2), (-2.75, -0.25)]):
        pts = [trunk_point(z, start_angle + drift * z / 3.0, 0.015) for z in (0.6, 1.3, 2.0, 2.45)]
        tube("Vein%d" % v, pts, [0.05, 0.045, 0.04, 0.0], "vein", "trunk_lower", 4, 0.2)
        pts = [trunk_point(z, start_angle + drift * z / 3.0, 0.015) for z in (2.45, 3.0)]
        if v < 2:
            tube("VeinUp%d" % v, pts, [0.04, 0.0], "vein", "trunk_upper", 4, 0.2)

    # ---- roots spreading over the arena floor (none straight ahead, so the heart shows)
    for i in range(11):
        angle = -math.pi / 2 + math.tau * (i + 0.5) / 11
        if abs(math.atan2(math.sin(angle + math.pi / 2), math.cos(angle + math.pi / 2))) < 0.5:
            continue
        reach = RNG.uniform(3.0, 3.9)
        d = Vector((math.cos(angle), math.sin(angle) * 0.85, 0))
        bend = Vector((-d.y, d.x, 0)) * RNG.uniform(-0.35, 0.35)
        pts = [
            d * 1.0 + Vector((0, 0, 0.75)),
            d * 1.6 + Vector((0, 0, 0.32)),
            d * 2.3 + bend + Vector((0, 0, 0.12)),
            d * (reach - 0.4) + bend * 1.6 + Vector((0, 0, 0.02)),
            d * reach + bend * 2.0 + Vector((0, 0, -0.12)),
        ]
        tube("Root%d" % i, pts, [0.6, 0.48, 0.34, 0.2, 0.04], "bark", "root", 6, 0.15)
        if i % 3 == 0:
            blob("RootMoss%d" % i, d * 1.6 + Vector((0, 0, 0.55)), 0.24, "moss", "root", (1.4, 1.4, 0.5), 1)

    # ---- arms: thick branch limbs ending in knotted fists with root claws
    for side, tag in ((1, "L"), (-1, "R")):
        m = Vector((side, 1, 1))
        s, e, w, k = (v * m for v in (SHOULDER, ELBOW, WRIST, KNUCKLE))
        blob("Shoulder." + tag, s, 0.62, "bark_dark", "trunk_upper", (1, 1, 0.9), 1)
        upper = [s, s.lerp(e, 0.5) + Vector((0, 0, 0.18)), e]
        tube("ArmUpper." + tag, upper, [0.5, 0.42, 0.38], "bark", "arm_upper." + tag, 7, 0.12)
        blob("Elbow." + tag, e, 0.44, "bark_dark", "arm_lower." + tag, (1, 1, 1), 1)
        lower = [e, e.lerp(w, 0.5), w]
        tube("ArmLower." + tag, lower, [0.38, 0.33, 0.36], "bark", "arm_lower." + tag, 7, 0.12)
        # Twigs and thorns along the forearm.
        for t in (0.3, 0.7):
            at = e.lerp(w, t)
            out = Vector((side * 0.5, RNG.uniform(-0.2, 0.3), 0.35))
            spike("ArmThorn%s%d" % (tag, t * 10), at, at + out, 0.09, "thorn", "arm_lower." + tag, 4)
        blob("Fist." + tag, w.lerp(k, 0.45), 0.55, "bark_dark", "fist." + tag, (1.05, 1.0, 0.85), 1, 0.1)
        for f in range(4):
            spread = (f - 1.5) * 0.28
            base = w.lerp(k, 0.6) + Vector((spread * side, -0.15, -0.1))
            tip = k + Vector((spread * 1.4 * side, -0.45, -0.35))
            mid = base.lerp(tip, 0.5) + Vector((0, -0.12, 0.12))
            tube("Claw%s%d" % (tag, f), [base, mid, tip], [0.13, 0.1, 0.0], "bark", "fist." + tag, 5, 0.1)
        # A curl of moss hanging off the forearm.
        blob("ArmMoss." + tag, e.lerp(w, 0.5) + Vector((0, 0.1, -0.2)), 0.2, "moss", "arm_lower." + tag, (1, 1, 1.6), 1)

    # ---- the canopy: dark clumps, blighted patches, dead antler branches, spore pods
    clumps = [
        ((0.0, 0.1, 5.35), 1.45, "leaf_dark"),
        ((-1.45, 0.25, 5.05), 1.15, "leaf"),
        ((1.45, 0.15, 5.1), 1.2, "leaf_dark"),
        ((-0.75, -0.45, 5.95), 1.05, "leaf_light"),
        ((0.85, -0.35, 6.05), 1.0, "leaf"),
        ((0.1, 0.7, 6.3), 1.0, "blight"),
        ((-2.25, 0.55, 4.6), 0.8, "blight"),
        ((2.3, 0.45, 4.7), 0.85, "leaf_dark"),
        ((0.0, -0.75, 4.85), 0.85, "leaf"),
    ]
    for i, (centre, radius, material) in enumerate(clumps):
        # Spread the clumps wider and lift them: from the high game camera the
        # crown is what reads as "giant tree".
        c = Vector(centre)
        c = Vector((c.x * 1.3, c.y, 4.4 + (c.z - 4.4) * 1.35 + 0.3))
        blob("Canopy%d" % i, c, radius * 1.35, material, "canopy", (1.15, 0.95, 0.8), 1, 0.16)
    for i, (dx, lean) in enumerate([(-0.5, -1), (0.5, 1), (-0.2, -0.4), (0.25, 0.5)]):
        base = Vector((dx, 0.15, 4.4))
        pts = [base, base + Vector((lean * 1.1, 0.2, 1.6)), base + Vector((lean * 2.0, 0.35, 3.2))]
        tube("Antler%d" % i, pts, [0.2, 0.13, 0.0], "bark_dark", "canopy", 5, 0.12)
        fork = pts[1] + Vector((lean * 0.2, 0.1, 0.4))
        spike("AntlerFork%d" % i, fork, fork + Vector((lean * 0.9, 0.0, 0.8)), 0.08, "bark_dark", "canopy", 4)
    pod_spots = [(-1.2, -0.7, 5.6), (1.1, -0.75, 5.7), (-0.2, -1.1, 5.2), (1.9, -0.3, 5.0),
                 (-1.9, -0.25, 5.15), (0.4, -0.6, 6.55), (-0.9, 0.0, 6.45), (2.4, 0.1, 4.35)]
    for i, spot in enumerate(pod_spots):
        p = Vector(spot)
        p = Vector((p.x * 1.3, p.y - 0.35, 4.4 + (p.z - 4.4) * 1.35 + 0.3))
        blob("SporePod%d" % i, p, RNG.uniform(0.2, 0.3), "spore", "canopy", (1, 1, 1.2), 1, 0.08)
    for i in range(7):
        x = RNG.uniform(-3.0, 3.0)
        top = Vector((x, RNG.uniform(-1.0, -0.4), 4.75 - abs(x) * 0.12))
        tube("Hang%d" % i, [top, top + Vector((0, -0.05, -0.55)), top + Vector((0.05, -0.08, -1.1))],
             [0.1, 0.07, 0.0], "moss", "canopy", 4, 0.1)


# ---------------------------------------------------------------- skeleton
BONES = [
    # name, head, tail, parent
    ("root", (0, 0, 0), (0, 0, 0.6), None),
    ("trunk_lower", (0, 0, 0.6), (0, 0, 2.5), "root"),
    ("trunk_upper", (0, 0, 2.5), (0, 0, 4.4), "trunk_lower"),
    ("canopy", (0, 0, 4.4), (0, 0, 7.2), "trunk_upper"),
    ("heart", (0, -1.0, 0.78), (0, -1.55, 0.78), "root"),
]
for side, tag in ((1, "L"), (-1, "R")):
    m = Vector((side, 1, 1))
    BONES += [
        ("arm_upper." + tag, SHOULDER * m, ELBOW * m, "trunk_upper"),
        ("arm_lower." + tag, ELBOW * m, WRIST * m, "arm_upper." + tag),
        ("fist." + tag, WRIST * m, KNUCKLE * m, "arm_lower." + tag),
    ]


def build_armature():
    data = bpy.data.armatures.new("HeartwoodColossusRig")
    rig = bpy.data.objects.new("HeartwoodColossusRig", data)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, head, tail, parent in BONES:
        bone = data.edit_bones.new(name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        if parent:
            bone.parent = data.edit_bones[parent]
            bone.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    data.display_type = "STICK"
    return rig


def join_and_bind(rig):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in PARTS:
        obj.select_set(True)
    body = PARTS[0]
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = "HeartwoodColossus"
    body.data.name = "HeartwoodColossusMesh"
    body.parent = rig
    modifier = body.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig
    return body


# ---------------------------------------------------------------- animation
# Poses are written as rotations about the *world* axes (as the model stands at
# rest), which is how you'd describe them: "lift the left arm out to the side"
# is a turn about the front-back axis (Y). They're converted into each bone's
# own space here.
def rest_quat(rig, bone):
    return rig.data.bones[bone].matrix_local.to_quaternion()


def world_rot(rig, bone, degrees):
    """degrees = (about X, about Y, about Z), world axes at rest."""
    q_world = Euler([math.radians(d) for d in degrees], "XYZ").to_quaternion()
    r = rest_quat(rig, bone)
    return r.inverted() @ q_world @ r


def world_loc(rig, bone, offset):
    return rest_quat(rig, bone).inverted() @ Vector(offset)


def new_action(rig, name, frames, loop):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    action.use_frame_range = True
    action.frame_start = 1
    action.frame_end = frames
    action.use_cyclic = loop
    rig.animation_data.action = action
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return action


def key(rig, frame, pose):
    """pose: {bone: {"rot": (x,y,z) deg, "loc": (x,y,z), "scale": s or (x,y,z)}}.
    Bones not named go back to rest, so every key is a complete pose."""
    for pb in rig.pose.bones:
        spec = pose.get(pb.name, {})
        pb.rotation_quaternion = world_rot(rig, pb.name, spec.get("rot", (0, 0, 0)))
        pb.location = world_loc(rig, pb.name, spec.get("loc", (0, 0, 0)))
        s = spec.get("scale", 1.0)
        pb.scale = Vector(s) if isinstance(s, (tuple, list)) else Vector((s, s, s))
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)
        pb.keyframe_insert("scale", frame=frame)


def arm(tag, raise_out=0.0, forward=0.0, twist=0.0, elbow=0.0, fist=0.0):
    """Arm helper. raise_out lifts the arm out to the side (degrees), forward
    swings it towards the player, elbow bends the forearm, fist curls the hand."""
    side = 1 if tag == "L" else -1
    return {
        "arm_upper." + tag: {"rot": (-forward, -raise_out * side, twist * side)},
        "arm_lower." + tag: {"rot": (-elbow, 0, 0)},
        "fist." + tag: {"rot": (-fist, 0, 0)},
    }


def merge(*poses):
    result = {}
    for pose in poses:
        for bone, spec in pose.items():
            result.setdefault(bone, {}).update(spec)
    return result


def body(lean=0.0, sway=0.0, twist=0.0, upper_lean=0.0, upper_twist=0.0, canopy=1.0, canopy_tilt=0.0, sink=0.0, heart=1.0):
    """lean: whole trunk tips back (+) or forward (-); sway: side to side."""
    return {
        "root": {"loc": (0, 0, -sink)},
        "trunk_lower": {"rot": (lean, sway, twist)},
        "trunk_upper": {"rot": (upper_lean, sway * 0.6, upper_twist)},
        "canopy": {"rot": (canopy_tilt, sway * 0.5, 0), "scale": canopy},
        "heart": {"scale": heart},
    }


def build_actions(rig):
    rig.animation_data_create()
    made = []

    # Idle: slow breathing, a creak of sway, the heart pulsing. Loops.
    a = new_action(rig, "Idle", 61, True)
    for f, (lean, sway, canopy, heart) in {
        1: (0, 0, 1.0, 1.0), 16: (1.5, 1.2, 1.03, 1.12), 31: (0, 0, 1.0, 1.0),
        46: (1.5, -1.2, 1.03, 1.12), 61: (0, 0, 1.0, 1.0),
    }.items():
        breathe = merge(body(lean=lean, sway=sway, canopy=canopy, heart=heart),
                        arm("L", raise_out=lean, elbow=lean), arm("R", raise_out=lean, elbow=lean))
        key(rig, f, breathe)
    made.append(a)

    # Root Slam, one per arm: rear back and lift (telegraph), smash down, fist
    # stays open on the ground for the weak-point window, then hauls back up.
    for tag in ("L", "R"):
        a = new_action(rig, "RootSlam" + tag, 60, False)
        side = 1 if tag == "L" else -1
        key(rig, 1, merge(body(), arm("L"), arm("R")))
        key(rig, 16, merge(body(lean=10, sway=-6 * side, upper_twist=-12 * side),
                           arm(tag, raise_out=75, forward=-20, elbow=-35, fist=-25)))
        key(rig, 20, merge(body(lean=11, sway=-7 * side, upper_twist=-14 * side),
                           arm(tag, raise_out=82, forward=-25, elbow=-40, fist=-30)))
        key(rig, 25, merge(body(lean=-12, sway=4 * side, upper_twist=8 * side, canopy=0.97),
                           arm(tag, raise_out=-6, forward=14, elbow=-28, fist=-20)))
        key(rig, 28, merge(body(lean=-10, sway=3 * side, upper_twist=6 * side, canopy=1.02),
                           arm(tag, raise_out=-5, forward=12, elbow=-24, fist=-18)))
        key(rig, 46, merge(body(lean=-9, sway=3 * side, upper_twist=6 * side),
                           arm(tag, raise_out=-5, forward=12, elbow=-24, fist=-18)))
        key(rig, 60, merge(body(), arm("L"), arm("R")))
        made.append(a)

    # Spore Bloom: lean back as the canopy swells, then a sharp puff (spores fly).
    a = new_action(rig, "SporeBloom", 55, False)
    key(rig, 1, merge(body(), arm("L"), arm("R")))
    key(rig, 26, merge(body(lean=9, canopy=1.28, canopy_tilt=6), arm("L", raise_out=25, elbow=-10), arm("R", raise_out=25, elbow=-10)))
    key(rig, 30, merge(body(lean=10, canopy=1.32, canopy_tilt=7), arm("L", raise_out=28, elbow=-12), arm("R", raise_out=28, elbow=-12)))
    key(rig, 33, merge(body(lean=-6, canopy=0.92, canopy_tilt=-8), arm("L", raise_out=10), arm("R", raise_out=10)))
    key(rig, 40, merge(body(lean=-3, canopy=1.05, canopy_tilt=-3), arm("L", raise_out=5), arm("R", raise_out=5)))
    key(rig, 55, merge(body(), arm("L"), arm("R")))
    made.append(a)

    # Thorn Spiral (phase two+): arms flung wide, the upper trunk wrenching round
    # and back. Loops for as long as the spiral lasts.
    a = new_action(rig, "ThornSpiral", 41, True)
    wide = merge(arm("L", raise_out=70, elbow=-20), arm("R", raise_out=70, elbow=-20))
    key(rig, 1, merge(body(upper_twist=-18, lean=3), wide))
    key(rig, 11, merge(body(upper_twist=0, lean=4, sway=3, canopy=1.04), wide))
    key(rig, 21, merge(body(upper_twist=18, lean=3), wide))
    key(rig, 31, merge(body(upper_twist=0, lean=4, sway=-3, canopy=1.04), wide))
    key(rig, 41, merge(body(upper_twist=-18, lean=3), wide))
    made.append(a)

    # Roar: the phase change. Rears back, arms up, the canopy thrashes.
    a = new_action(rig, "Roar", 60, False)
    key(rig, 1, merge(body(), arm("L"), arm("R")))
    up = merge(arm("L", raise_out=60, forward=-15, elbow=-30, fist=-20), arm("R", raise_out=60, forward=-15, elbow=-30, fist=-20))
    key(rig, 14, merge(body(lean=14, upper_lean=6, canopy=1.08), up))
    for i, f in enumerate(range(18, 44, 3)):
        shake = 4 if i % 2 == 0 else -4
        key(rig, f, merge(body(lean=14, upper_lean=6, sway=shake, canopy=1.1, canopy_tilt=shake), up))
    key(rig, 60, merge(body(), arm("L"), arm("R")))
    made.append(a)

    # Hit: a short flinch when the weak point is struck.
    a = new_action(rig, "Hit", 16, False)
    key(rig, 1, merge(body(), arm("L"), arm("R")))
    key(rig, 4, merge(body(lean=7, upper_lean=4, canopy=0.97, heart=0.8), arm("L", raise_out=10, elbow=-10), arm("R", raise_out=10, elbow=-10)))
    key(rig, 16, merge(body(), arm("L"), arm("R")))
    made.append(a)

    # Death: staggers, arms go limp, and the crown cracks and topples back into
    # the wall. The game leaves its split-stump remains where it stood.
    a = new_action(rig, "Death", 90, False)
    key(rig, 1, merge(body(), arm("L"), arm("R")))
    key(rig, 12, merge(body(lean=-8, sway=5, canopy=1.05, heart=1.4), arm("L", raise_out=20), arm("R", raise_out=15)))
    key(rig, 30, merge(body(lean=-4, sway=-6, upper_lean=-6, heart=0.6), arm("L", raise_out=-20, forward=10, elbow=20, fist=30), arm("R", raise_out=-18, forward=12, elbow=25, fist=30)))
    key(rig, 60, merge(body(lean=12, sway=-8, upper_lean=28, upper_twist=10, canopy=0.92, canopy_tilt=20, heart=0.3, sink=0.25),
                       arm("L", raise_out=-35, forward=-20, elbow=40, fist=40), arm("R", raise_out=-30, forward=-15, elbow=45, fist=40)))
    key(rig, 90, merge(body(lean=16, sway=-10, upper_lean=38, upper_twist=14, canopy=0.85, canopy_tilt=30, heart=0.05, sink=0.6),
                       arm("L", raise_out=-45, forward=-25, elbow=45, fist=45), arm("R", raise_out=-40, forward=-20, elbow=50, fist=45)))
    made.append(a)

    # Keep every action reachable: stash each on its own (muted) NLA track and
    # leave Idle active, so the .blend opens on the idle loop.
    for action in made:
        track = rig.animation_data.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, 1, action)
        track.mute = True
    rig.animation_data.action = bpy.data.actions["Idle"]
    return made


# ---------------------------------------------------------------- main
def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out_blend = argv[0] if argv else "heartwood_colossus.blend"
    out_glb = argv[1] if len(argv) > 1 else ""

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = 61

    global MATERIALS
    MATERIALS = {name: make_material(name) for name in COLOURS}
    build_body()
    rig = build_armature()
    mesh = join_and_bind(rig)
    actions = build_actions(rig)

    print("COLOSSUS verts=%d faces=%d actions=%s" % (
        len(mesh.data.vertices), len(mesh.data.polygons), [a.name for a in actions]))
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    if out_glb:
        bpy.ops.object.select_all(action="DESELECT")
        rig.select_set(True)
        mesh.select_set(True)
        bpy.ops.export_scene.gltf(
            filepath=out_glb,
            export_format="GLB",
            use_selection=True,
            export_animation_mode="ACTIONS",
            export_force_sampling=True,
            export_yup=True,
        )


MATERIALS = {}
main()
