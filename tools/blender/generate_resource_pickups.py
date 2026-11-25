"""Author the ProjectMine 0.9 cockpit in Godot coordinates. No external art required.
blender --background --python-exit-code 1 --python tools/blender/generate_industrial_cockpit.py
"""
from pathlib import Path
import json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector
OUT=Path(__file__).resolve().parents[2]/'assets/models/pickups'
SOURCE=OUT/'source'
SOURCE.mkdir(parents=True,exist_ok=True)
(SOURCE/'.gdignore').touch()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene
model_collection=bpy.data.collections.new('COCKPIT_MODEL')
scene.collection.children.link(model_collection)
parts={}
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

root=empty('IndustrialCockpit')
components={name:empty(name,pivot,root) for name,pivot in {
 'Frame':(0,0,0),
 'LeftHousing':(-.62,-.40,-.85),'RightHousing':(.62,-.40,-.85),
 'LeftBarrel':(-.62,-.30,-.95),'RightBarrel':(.62,-.30,-.95),
 'LeftMount':(-.62,-.40,-.85),'RightMount':(.62,-.40,-.85)}.items()}
SIZE, CELL = 512, 128
rng = np.random.default_rng(417)
base = np.ones((SIZE,SIZE,4), dtype=np.float32)
orm = np.ones_like(base)
swatches = [
    ((.11,.135,.15),.46,.68), ((.24,.26,.27),.38,.82),
    ((.055,.060,.062),.88,.08), ((.75,.51,.10),.79,.12),
    ((.42,.45,.47),.32,.88), ((.035,.038,.038),.95,.05),
    ((.72,.49,.085),.82,.12), ((.30,.16,.075),.89,.42),
    ((.16,.018,.012),.26,.15), ((.07,.075,.07),.80,.04),
    ((.34,.36,.33),.85,.18), ((.14,.16,.17),.56,.65),
]
for slot,(color,roughness,metallic) in enumerate(swatches):
    row,col = divmod(slot,4)
    noise = rng.normal(0,1,(CELL,CELL)).astype(np.float32)
    for _ in range(3):
        noise = (noise+np.roll(noise,1,0)+np.roll(noise,-1,0)+np.roll(noise,1,1)+np.roll(noise,-1,1))/5
    fine = rng.normal(0,.009,(CELL,CELL))
    value = np.clip(np.asarray(color)[None,None,:] * (1+noise[:,:,None]*.14) + fine[:,:,None], .012, .95)
    if slot == 6:
        yy,xx = np.indices((CELL,CELL))
        stripe = ((xx+yy)//24)%2 == 0
        value[stripe] *= .075
    for _ in range(24):
        x,y = rng.integers(8,CELL-8,2)
        length = int(rng.integers(2,15))
        value[y,min(x,CELL-2):min(x+length,CELL-2)] += .025
    base[row*CELL:(row+1)*CELL,col*CELL:(col+1)*CELL,:3] = np.clip(value,0,1)
    orm[row*CELL:(row+1)*CELL,col*CELL:(col+1)*CELL,1] = np.clip(roughness+noise*.08,.2,1)
    orm[row*CELL:(row+1)*CELL,col*CELL:(col+1)*CELL,2] = metallic
# Stencilled identification, painted into the shared atlas (no font dependency).
glyphs = {'S':['11111','10000','10000','11111','00001','00001','11111'],
          'E':['11111','10000','10000','11110','10000','10000','11111'],
          'C':['11111','10000','10000','10000','10000','10000','11111'],
          '-':['00000','00000','00000','11111','00000','00000','00000'],
          '1':['00100','01100','00100','00100','00100','00100','01110'],
          '7':['11111','00001','00010','00100','01000','01000','01000']}
for index,letter in enumerate('SEC-17'):
    for y,line in enumerate(glyphs[letter]):
        for x,pixel in enumerate(line):
            if pixel=='1':
                xx = CELL + 11 + (index*6+x)*3
                yy = 2*CELL + 72-y*3
                base[yy:yy+3,xx:xx+3,:3] = (.74,.73,.65)

def image(name, pixels, noncolor=False):
    result = bpy.data.images.new(name, width=SIZE, height=SIZE, alpha=True)
    result.colorspace_settings.name = 'Non-Color' if noncolor else 'sRGB'
    result.pixels.foreach_set(pixels.ravel())
    result.file_format = 'PNG'
    result.pack()
    return result
albedo = image('Cockpit_Albedo_512',base)
roughmetal = image('Cockpit_RoughMetal_512',orm,True)
atlas = bpy.data.materials.new('Cockpit_Atlas_PBR')
atlas.use_nodes = True
nodes = atlas.node_tree.nodes
principled = nodes.get('Principled BSDF')
tex = nodes.new('ShaderNodeTexImage'); tex.image=albedo
atlas.node_tree.links.new(tex.outputs['Color'],principled.inputs['Base Color'])
tex2=nodes.new('ShaderNodeTexImage'); tex2.image=roughmetal
split=nodes.new('ShaderNodeSeparateRGB')
atlas.node_tree.links.new(tex2.outputs['Color'],split.inputs[0])
atlas.node_tree.links.new(split.outputs['G'],principled.inputs['Roughness'])
atlas.node_tree.links.new(split.outputs['B'],principled.inputs['Metallic'])

def emissive(name, color, strength):
    material=bpy.data.materials.new(name);material.use_nodes=True
    shader=material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Metallic'].default_value=.15
    shader.inputs['Roughness'].default_value=.3
    shader.inputs['Emission Color'].default_value=(*color,1)
    shader.inputs['Emission Strength'].default_value=strength
    return material
orange=emissive('Cockpit_Amber',(.95,.16,.012),1.3)
# Apply bevel + weighted normals before joining/export; preserve flat armour faces.
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


# Standalone pickups reuse the cockpit atlas and hard-surface helpers.
for kind in ['ammo','missiles','energy','shield']:
    for ob in list(model_collection.objects):
        if ob.type in ['MESH','EMPTY']: bpy.data.objects.remove(ob,do_unlink=True)
    parts={}
    root=empty('Industrial_'+kind)
    components={'Body':empty('Body',(0,0,0),root)}
    color={'ammo':(1,.35,.02),'missiles':(.8,.015,.01),'energy':(.01,.45,1),'shield':(.02,.8,.17)}[kind]
    light=emissive(kind+'_status',color,.9)
    box('Base',(0,-.13,0),(.46,.10,.56),'Body',0,.016)
    for x in [-.21,.21]:
        box('Reinforced rail',(x,.015,0),(.045,.26,.58),'Body',4,.007)
        for z in [-.24,.24]:
            box('Corner',(x,.08,z),(.075,.18,.075),'Body',0,.008)
            cylinder('Bolt',(x,.18,z),.018,.012,(0,1,0),'Body',4,6)
    if kind in ['ammo','missiles']:
        for x in ([-.13,0,.13] if kind=='ammo' else [-.105,.105]):
            cylinder('Cartridge' if kind=='ammo' else 'Missile',(x,.04,0),.052 if kind=='ammo' else .065,.34 if kind=='ammo' else .46,(0,0,-1),'Body',4,12,.003)
            lathe('Nose',(x,.04,-.15 if kind=='ammo' else -.18),[(.05,0),(.05,.05),(.014,.10)],'Body',3 if kind=='ammo' else 7,12,axis=(0,0,-1))
        box('Identification',(0,-.065,.265),(.36,.05,.016),'Body',6 if kind=='ammo' else 7,.002)
        if kind=='missiles':
            for x in [-.105,.105]: box('Tail fins',(x,.04,.19),(.16,.025,.09),'Body',0,.002)
    else:
        core=cylinder('Core',(0,.05,0),.12,.28,(0,0,1),'Body',4,16)
        core.data.materials.clear();core.data.materials.append(light)
        for z in [-.18,.18]:
            lathe('Protective hoop',(0,.05,z),[(.12,0),(.16,0),(.16,.03),(.12,.03)],'Body',4,16,axis=(0,0,1))
        if kind=='shield':
            box('Cross horizontal',(0,.22,0),(.31,.045,.07),'Body',1,.004)
            box('Cross vertical',(0,.22,0),(.07,.045,.31),'Body',1,.004)
    lamp=box('Status',(0,.01,.29),(.10,.035,.016),'Body',0,.002)
    lamp.data.materials.clear();lamp.data.materials.append(light)
    bpy.ops.object.select_all(action='DESELECT')
    objects=parts['Body']
    for ob in objects: ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    bpy.context.object.name=kind+'_mesh'
    bpy.ops.object.material_slot_remove_unused()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(kind+'.blend')))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in model_collection.all_objects: ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(kind+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
