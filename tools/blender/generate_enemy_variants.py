"""Reference-inspired industrial variants; editable sources and five-piece GLBs.
Run: blender --background --python-exit-code 1 --python tools/blender/generate_enemy_variants.py
Reuses the existing drone's packed atlas, never changes its source or export.
Godot coordinates: +Y up, -Z forward. Studio-free runtime exports.
"""
from pathlib import Path
import json, math
import bpy, bmesh
from mathutils import Vector
OUT = Path(__file__).resolve().parents[2]/'assets/models/enemies'
SOURCE = OUT/'source'
bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'industrial_drone.blend'))
bpy.context.preferences.filepaths.save_version = 0
atlas = bpy.data.materials['Industrial_Atlas_PBR']
atlas.use_fake_user = True
for image in bpy.data.images: image.use_fake_user = True
for obj in list(bpy.data.objects): bpy.data.objects.remove(obj,do_unlink=True)
scene = bpy.context.scene
model_collection = bpy.data.collections.new('VARIANT_MODEL')
scene.collection.children.link(model_collection)

def g(point):
    x, y, z = point
    return Vector((x, -z, y))

def move_collection(obj, collection):
    for previous in list(obj.users_collection): previous.objects.unlink(obj)
    collection.objects.link(obj)

def empty(name, point=(0,0,0), parent=None):
    obj = bpy.data.objects.new(name, None)
    model_collection.objects.link(obj)
    obj.location = g(point)
    if parent:
        world = obj.matrix_world.copy()
        bpy.context.view_layer.update()
        world.translation = g(point)
        obj.parent = parent
        obj.matrix_world = world
    obj.empty_display_size = 0.08
    obj.empty_display_type = 'PLAIN_AXES'
    return obj

def emissive(name, color, strength):
    material=bpy.data.materials.new(name);material.use_nodes=True
    shader=material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Metallic'].default_value=.15
    shader.inputs['Roughness'].default_value=.3
    shader.inputs['Emission Color'].default_value=(*color,1)
    shader.inputs['Emission Strength'].default_value=strength
    return material

def finish(obj, component, slot=0, bevel=0.0, segments=1, smooth=False, material=None):
    move_collection(obj,model_collection)
    bpy.context.view_layer.objects.active=obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.clear();obj.data.materials.append(material or atlas)
    if bevel:
        modifier=obj.modifiers.new('Manufactured edge radius','BEVEL')
        modifier.width=bevel;modifier.segments=segments
        modifier.affect='EDGES'
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    for polygon in obj.data.polygons:polygon.use_smooth=smooth or bevel>0
    if hasattr(obj.data,'use_auto_smooth'):obj.data.use_auto_smooth=True
    if bevel or smooth:
        modifier=obj.modifiers.new('Weighted hard-surface normals','WEIGHTED_NORMAL')
        modifier.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    if not material:
        if not obj.data.uv_layers:obj.data.uv_layers.new(name='UVMap')
        u0,v0=(slot%4)/4,(slot//4)/4
        for uv in obj.data.uv_layers.active.data:
            uv.uv=(u0+.012+uv.uv.x*.226, v0+.012+uv.uv.y*.226)
    world=obj.matrix_world.copy()
    obj.parent=components[component]
    obj.matrix_world=world
    parts.setdefault(component,[]).append(obj)
    obj.select_set(False)
    return obj

def box(name, point, size, component='Chassis', slot=0, bevel=.008, segments=1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=g(point))
    obj=bpy.context.object;obj.name=name
    obj.dimensions=(size[0],size[2],size[1])
    return finish(obj,component,slot,bevel,segments)

def cylinder(name, point, radius, depth, direction=(0,1,0), component='Chassis', slot=0, sides=12, bevel=0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=radius,depth=depth,location=g(point))
    obj=bpy.context.object;obj.name=name
    obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=Vector((0,0,1)).rotation_difference(g(direction).normalized())
    return finish(obj,component,slot,bevel,1,True)

def custom(name, vertices, faces, component, slot, smooth=False, material=None):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata([g(vertex) for vertex in vertices],[],faces)
    mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(mesh);bm.free()
    # Project simple object-space UVs before atlas remapping.
    uv=mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        for loop in polygon.loop_indices:
            coordinate=mesh.vertices[mesh.loops[loop].vertex_index].co
            uv.data[loop].uv=((coordinate.x*3)%1,(coordinate.z*3)%1)
    obj=bpy.data.objects.new(name,mesh);model_collection.objects.link(obj)
    return finish(obj,component,slot,0,1,smooth,material)

def lathe(name, origin, profile, component, slot=0, sides=16, axis=(0,1,0), material=None):
    direction=Vector(axis).normalized()
    u=Vector((1,0,0)) if abs(direction.x)<.9 else Vector((0,0,1))
    v=direction.cross(u).normalized()
    vertices=[]
    for radius,distance in profile:
        for index in range(sides):
            angle=index*math.tau/sides
            vertices.append(Vector(origin)+direction*distance+radius*(u*math.cos(angle)+v*math.sin(angle)))
    faces=[]
    for ring in range(len(profile)):
        for index in range(sides):
            following=(index+1)%sides
            next_ring=(ring+1)%len(profile)
            faces.append((ring*sides+index,ring*sides+following,next_ring*sides+following,next_ring*sides+index))
    return custom(name,vertices,faces,component,slot,True,material)

def tube(name, path, radius, component='Chassis', slot=2, sides=8):
    vertices=[]
    for index,point in enumerate(path):
        tangent=Vector(path[min(index+1,len(path)-1)])-Vector(path[max(index-1,0)])
        tangent.normalize()
        u=tangent.cross(Vector((0,1,0)))
        if u.length<.1:u=tangent.cross(Vector((1,0,0)))
        u.normalize();v=tangent.cross(u).normalized()
        for segment in range(sides):
            angle=segment*math.tau/sides
            vertices.append(Vector(point)+radius*(u*math.cos(angle)+v*math.sin(angle)))
    faces=[]
    for index in range(len(path)-1):
        for segment in range(sides):
            next_segment=(segment+1)%sides
            faces.append((index*sides+segment,index*sides+next_segment,(index+1)*sides+next_segment,(index+1)*sides+segment))
    faces += [tuple(range(sides-1,-1,-1)),tuple((len(path)-1)*sides+x for x in range(sides))]
    return custom(name,vertices,faces,component,slot,True)

red = emissive('Optic_Emission',(.9,.012,.004),1.2)
amber = emissive('Optic_Amber_Emission',(1,.30,.008),1.15)
blue = emissive('Thruster_Emission',(.025,.17,.28),.7)

def eye(point,radius,component='Optics',material=None):
    lathe('Sensor bezel',point,[(radius*.8,-.02),(radius*1.2,-.02),(radius*1.2,.025),(radius*.8,.025)],component,4,20,axis=(0,0,-1))
    lathe('Recessed optical glass',point,[(0,.014),(radius*.78,.014),(radius*.78,.018),(0,.018)],component,0,20,axis=(0,0,-1),material=material or red)

def thruster(x,y,z,component,radius=.17,length=.42):
    lathe('Ducted propulsion casting',(x,y,z),[(radius*.65,-length/2),(radius,-length/2),(radius*1.08,-length*.3),(radius*1.08,length*.3),(radius,length/2),(radius*.65,length/2)],component,0,16)
    for offset in [-length*.42,length*.42]:
        lathe('Reinforced motor ring',(x,y+offset,z),[(radius*.65,-.02),(radius*1.1,-.02),(radius*1.1,.02),(radius*.65,.02)],component,4,16)
    lathe('Recessed exhaust',(x,y-length*.49,z),[(0,0),(radius*.61,0),(radius*.61,.006),(0,.006)],component,0,16,material=blue)
    for zz in [-.065,.065]:
        box('Intake protection',(x,y+length/2,z+zz),(radius*1.8,.018,.026),component,2,0)
    box('Motor hazard strip',(x,y,z-radius*1.09),(radius*1.4,.10,.008),component,6,.002)

def guardian():
    box('Heavy torso',(0,.05,0),(.62,.58,.52),bevel=.045,segments=2)
    box('Chest apron',(0,.02,-.29),(.58,.42,.10),slot=1,bevel=.025)
    box('Chest warning band',(0,.20,-.35),(.50,.08,.012),slot=6,bevel=.002)
    box('Belly power enclosure',(0,-.30,.02),(.39,.16,.40),slot=2,bevel=.02)
    box('Helmet',(0,.43,-.07),(.28,.24,.29),'Optics',3,.035,2)
    box('Visor recess',(0,.43,-.224),(.23,.09,.014),'Optics',5,.003)
    custom('Red horizontal visor',[(-.10,.46,-.235),(.10,.46,-.235),(.075,.405,-.235),(-.075,.405,-.235)],[(0,3,2,1)],'Optics',0,material=red)
    box('Brow guard',(0,.50,-.23),(.27,.045,.055),'Optics',1,.009)
    for side,comp in [(-1,'PropulsionLeft'),(1,'PropulsionRight')]:
        x=side*.45
        cylinder('Shoulder axle',(side*.34,.20,0),.12,.20,(1,0,0),slot=4)
        box('Armored shoulder',(x,.24,.01),(.27,.27,.39),slot=1,bevel=.035,segments=2)
        box('Shoulder safety cap',(x,.385,.01),(.27,.03,.31),slot=6,bevel=.005)
        thruster(x,-.20,.12,comp,.145,.40)
        tube('Hydraulic supply',[(side*.24,.27,.24),(x,.22,.27),(x,-.15,.28)],.023,comp,2)
        for yy in [-.10,.12]:
            cylinder('Chest fastener',(side*.23,yy,-.35),.025,.012,(0,0,-1),slot=4,sides=8)
    box('Right cannon trunnion',(.38,-.02,-.18),(.22,.23,.29),'Weapon',0,.022)
    lathe('Heavy cannon shroud',(.38,-.05,-.32),[(.07,-.10),(.12,-.10),(.13,0),(.11,.24),(.075,.24)],'Weapon',1,16,axis=(0,0,-1))
    for zz in [-.35,-.42,-.49]:
        lathe('Cannon cooling collar',(.38,-.05,zz),[(.082,-.012),(.13,-.012),(.13,.012),(.082,.012)],'Weapon',2,16,axis=(0,0,-1))
    lathe('Dark cannon bore',(.38,-.05,-.555),[(0,0),(.068,0),(.068,.008),(0,.008)],'Weapon',5,16,axis=(0,0,-1))
    box('Left armored manipulator',(-.44,-.05,-.20),(.22,.23,.25),slot=0,bevel=.02)
    for x in [-.50,-.43,-.36]: box('Manipulator fingers',(x,-.16,-.26),(.052,.09,.12),slot=4,bevel=.007)
    for x in [-.18,-.09,0,.09,.18]: box('Rear heat exchanger',(x,.12,.28),(.025,.35,.06),slot=2,bevel=0)
    return (.38,-.05,-.58),(0,.43,-.25)

def scout():
    box('Slim reconnaissance fuselage',(0,0,0),(.43,.24,.88),slot=10,bevel=.065,segments=2)
    box('Dorsal access spine',(0,.145,.10),(.20,.07,.49),slot=1,bevel=.016)
    box('Sensor nose',(0,-.015,-.44),(.34,.20,.18),'Optics',10,.025)
    eye((0,-.025,-.54),.095,material=amber)
    for side,comp in [(-1,'PropulsionLeft'),(1,'PropulsionRight')]:
        tube('Swept motor strut',[(side*.14,.03,.22),(side*.44,0,.06),(side*.59,-.02,.13)],.046,slot=1)
        thruster(side*.59,-.025,.15,comp,.12,.25)
        box('Slim side armor',(side*.57,.10,.15),(.24,.045,.29),comp,10,.015)
        eye((side*.19,.015,-.48),.041,material=amber)
        box('Antenna foot',(side*.30,.12,.22),(.07,.08,.09),slot=2,bevel=.006)
        box('Short sensor mast',(side*.30,.23,.22),(.035,.15,.045),slot=1,bevel=.003)
        tube('Signal cable',[(side*.10,.13,.23),(side*.25,.16,.26),(side*.29,.14,.22)],.014,slot=2)
    for z in [-.12,-.02,.08,.18]: box('Top radiator',(0,.19,z),(.18,.025,.028),slot=4,bevel=0)
    # Keep the existing named weapon attachment; the unarmed scout hides it.
    box('Unused service port',(0,-.13,-.30),(.08,.035,.08),'Weapon',2,.004)
    return (0,-.13,-.37),(0,-.025,-.565)

def maintenance():
    box('Yellow service enclosure',(0,.17,0),(.66,.53,.44),slot=3,bevel=.065,segments=2)
    box('Removable front panel',(0,.15,-.24),(.53,.37,.04),slot=3,bevel=.016)
    eye((.13,.20,-.27),.092)
    for y in [.12,.17,.22,.27]: box('Vent slot',(-.17,y,-.265),(.10,.017,.008),slot=5,bevel=0)
    box('Lower tool carriage',(0,-.17,.02),(.29,.14,.30),slot=2,bevel=.018)
    for side,comp in [(-1,'PropulsionLeft'),(1,'PropulsionRight')]:
        thruster(side*.35,.10,.13,comp,.075,.23)
        tube('Jointed service arm',[(side*.10,-.20,0),(side*.25,-.30,-.02),(side*.27,-.48,-.12)],.045,'Weapon',3)
        cylinder('Elbow pin',(side*.24,-.30,-.02),.065,.10,(1,0,0),'Weapon',4)
        tube('Flexible tool feed',[(side*.16,-.15,.13),(side*.32,-.27,.12),(side*.32,-.43,-.08)],.019,'Weapon',2)
    cylinder('Service actuator',(-.27,-.47,-.12),.065,.17,(0,1,0),'Weapon',3)
    for side in [-1,1]:
        tube('Gripper jaw',[(-.27+side*.045,-.53,-.12),(-.27+side*.075,-.63,-.12),(-.27+side*.025,-.66,-.12)],.018,'Weapon',4)
    cylinder('Repair probe',(.27,-.56,-.12),.016,.23,(0,1,0),'Weapon',4,8)
    tube('Carry handle',[(-.15,.45,0),(-.15,.51,0),(.15,.51,0),(.15,.45,0)],.022,slot=2)
    return (.27,-.68,-.12),(.13,.20,-.30)

for name,build,pivots,scale in [
 ('heavy_guardian',guardian,{'Chassis':(0,0,0),'PropulsionLeft':(-.45,-.20,.12),'PropulsionRight':(.45,-.20,.12),'Weapon':(.38,-.05,-.32),'Optics':(0,.43,-.07)},(1.8,1.8,1.8)),
 ('scout_drone',scout,{'Chassis':(0,0,0),'PropulsionLeft':(-.59,-.025,.15),'PropulsionRight':(.59,-.025,.15),'Weapon':(0,-.13,-.30),'Optics':(0,0,-.44)},(.62,.45,.62)),
 ('maintenance_bot',maintenance,{'Chassis':(0,0,0),'PropulsionLeft':(-.35,.10,.13),'PropulsionRight':(.35,.10,.13),'Weapon':(0,-.4,0),'Optics':(.13,.20,-.27)},(1,1,1))]:
    for obj in list(model_collection.objects): bpy.data.objects.remove(obj,do_unlink=True)
    parts = {}
    root = empty(name)
    components = {key:empty(key,point,root) for key,point in pivots.items()}
    muzzle,axis = build()
    empty('Muzzle',muzzle,components['Weapon'])
    empty('OpticalAxis',axis,components['Optics'])
    for component,objects in parts.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects: obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join()
        obj=bpy.context.object;obj.name=component+'Mesh'
        bpy.ops.object.material_slot_remove_unused()
        modifier=obj.modifiers.new('Export triangles','TRIANGULATE')
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    # Keep the guardian inside its existing 1.26 m gameplay hull, including recoil.
    if name == 'heavy_guardian':
        for obj in model_collection.objects:
            obj.location *= .88
            if obj.type == 'MESH':
                for vertex in obj.data.vertices: vertex.co *= .88
        muzzle=tuple(value*.88 for value in muzzle)
        axis=tuple(value*.88 for value in axis)
    bpy.context.view_layer.update()
    meshes=[obj for obj in model_collection.objects if obj.type=='MESH']
    points=[obj.matrix_world@Vector(corner) for obj in meshes for corner in obj.bound_box]
    bounds=[Vector((p.x,p.z,-p.y)) for p in points]
    maximum_radius=max(Vector((p.x*scale[0],p.z*scale[1],-p.y*scale[2])).length for obj in meshes for vertex in obj.data.vertices for p in [obj.matrix_world@vertex.co])
    manifest={'generator':'tools/blender/generate_enemy_variants.py','triangles':sum(len(obj.data.polygons) for obj in meshes),'mesh_components':len(meshes),'pivots':list(components),'muzzle_godot':muzzle,'optical_axis_godot':axis,'runtime_scale':scale,'vertex_radius_m':maximum_radius,'bounds_min_godot':[min(p[i] for p in bounds) for i in range(3)],'bounds_max_godot':[max(p[i] for p in bounds) for i in range(3)]}
    (OUT/(name+'_manifest.json')).write_text(json.dumps(manifest,indent=2)+'\n')
    bpy.ops.object.select_all(action='DESELECT')
    for obj in model_collection.objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=root
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
    print('VARIANT_EXPORT '+json.dumps(manifest))
