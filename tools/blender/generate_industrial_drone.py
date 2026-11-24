"""Generate the ProjectMine security drone. Blender 4.x, no add-on dependencies.
Run: blender --background --python-exit-code 1 --python tools/blender/generate_industrial_drone.py -- --render
Coordinates in this authoring script are Godot metres (X right, Y up, -Z forward).
The conversion g() authors Blender +Y forward, +Z up; glTF export restores Godot axes.
"""
from pathlib import Path
import argparse
import json
import math
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector

parser = argparse.ArgumentParser()
parser.add_argument('--project-root', type=Path, default=Path(__file__).resolve().parents[2])
parser.add_argument('--render', action='store_true')
args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
OUT = args.project_root / 'assets/models/enemies'
SOURCE = OUT / 'source'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / '.gdignore').touch()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
model_collection = bpy.data.collections.new('DRONE_MODEL')
scene.collection.children.link(model_collection)
studio_collection = bpy.data.collections.new('SOURCE_STUDIO_NOT_EXPORTED')
scene.collection.children.link(studio_collection)
parts = {}

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

root = empty('IndustrialDrone')
root['forward_axis'] = 'Godot -Z; authored Blender +Y'
root['unit'] = 'metres'
components = {name: empty(name, point, root) for name,point in {
    'Chassis':(0,0,0), 'PropulsionLeft':(-.55,-.01,.08),
    'PropulsionRight':(.55,-.01,.08), 'Optics':(-.045,.09,-.435),
    'Weapon':(.235,-.18,-.42)}.items()}

# Shared 512px atlases: base colour and standard glTF roughness(G)/metallic(B).
# All hard-surface pieces share one material, rather than one draw call per bolt.
SIZE, CELL = 512, 128
rng = np.random.default_rng(417)
base = np.ones((SIZE,SIZE,4), dtype=np.float32)
orm = np.ones_like(base)
swatches = [
    ((.28,.30,.31),.72,.78), ((.37,.38,.37),.64,.82),
    ((.055,.060,.062),.88,.08), ((.75,.51,.10),.79,.12),
    ((.46,.47,.44),.52,.86), ((.035,.038,.038),.95,.05),
    ((.72,.49,.085),.82,.12), ((.30,.16,.075),.89,.42),
    ((.16,.018,.012),.26,.15), ((.07,.075,.07),.80,.04),
    ((.34,.36,.33),.85,.18), ((.24,.25,.26),.73,.72),
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
albedo = image('Drone_Albedo_512',base)
roughmetal = image('Drone_RoughMetal_512',orm,True)
atlas = bpy.data.materials.new('Industrial_Atlas_PBR')
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
red=emissive('Optic_Emission',(.8,.008,.003),1.1)
blue=emissive('Thruster_Emission',(.025,.18,.32),.65)

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

# Armoured chassis: compact casting, removable plates, narrow seams, service fittings.
box('Main armoured casting',(0,0,0),(.82,.59,.78),bevel=.045,segments=2)
box('Upper armour',(0,.325,.0),(.86,.10,.80),slot=1,bevel=.018)
box('Lower skid armour',(0,-.325,.01),(.73,.08,.66),slot=0,bevel=.014)
box('Front yellow brow',(0,.28,-.405),(.74,.10,.09),slot=3,bevel=.012)
for side in [-1,1]:
    box('Front cheek',(.29*side,-.015,-.395),(.19,.40,.12),slot=1,bevel=.018)
    box('Cheek safety paint',(.29*side,.12,-.462),(.13,.11,.006),slot=6,bevel=0)
    box('Side service panel',(.416*side,.01,.015),(.025,.36,.43),slot=10,bevel=.007)
    cylinder('Pivot pin',(.465*side,-.005,.08),.085,.16,(1,0,0),slot=4,sides=12,bevel=.004)
    for z in [-.27,.27]:
        cylinder('Top captive bolt',(.30*side,.386,z),.026,.016,slot=4,sides=8)
    for y in [-.12,.14]:
        cylinder('Front captive bolt',(.32*side,y,-.465),.022,.014,(0,0,-1),slot=4,sides=8)
box('Rear radiator surround',(-.04,.005,.405),(.60,.40,.06),slot=2,bevel=.01)
for index in range(8):
    box('Rear cooling fin',(-.29+index*.071,.015,.448),(.025,.32,.04),slot=1,bevel=0)
# Asymmetric electrical enclosure, grease cover, cable and lifting handle.
box('Raised service housing',(.21,.39,.18),(.25,.16,.30),slot=10,bevel=.016)
box('Service housing hazard paint',(.21,.478,.18),(.18,.006,.23),slot=6,bevel=0)
box('Side grease cover',(-.438,.035,-.08),(.02,.17,.18),slot=7,bevel=.006)
tube('Armoured power cable',[(.27,.40,.27),(.25,.40,.40),(.08,.30,.46),(-.17,.20,.46),(-.31,.08,.36)],.025)
tube('Lifting handle',[(-.24,.375,.06),(-.24,.465,.06),(.09,.465,.06),(.09,.375,.06)],.023,slot=1)
# A flat decal uses one atlas tile; no floating font meshes or external typefaces.
decal=custom('Painted SEC17 stencil',[(-.19,-.235,-.397),(.19,-.235,-.397),(.19,-.155,-.397),(-.19,-.155,-.397)],[(0,3,2,1)],'Chassis',9)
for index,uv in enumerate(decal.data.uv_layers.active.data):
    coords=[(.98,.02),(.98,.98),(.02,.98),(.02,.02)][index]
    uv.uv=((9%4)/4+.012+coords[0]*.226,(9//4)/4+.012+coords[1]*.226)

# Twin vertical ducted propulsion units, separate pivots; their blue apertures are recessed.
for side,component in [(-1,'PropulsionLeft'),(1,'PropulsionRight')]:
    x=side*.55; y=-.01; z=.08
    lathe('Motor shroud',(x,y,z),[(.105,-.30),(.158,-.30),(.18,-.25),(.18,.235),(.15,.30),(.105,.30)],component,0,16)
    lathe('Top protective rim',(x,y+.30,z),[(.106,-.02),(.158,-.02),(.17,.0),(.158,.025),(.106,.025)],component,4,16)
    lathe('Exhaust nozzle',(x,y-.30,z),[(.10,-.025),(.155,-.025),(.165,0),(.15,.025),(.10,.025)],component,2,16)
    cylinder('Turbine hub',(x,y+.27,z),.055,.04,component=component,slot=1,sides=12)
    for index in range(4):
        angle=index*math.pi/2
        # Four simple protective blades span the small intake.
        blade=box('Intake guard',(x,y+.31,z),(.27,.018,.025),component,2,0)
        blade.rotation_mode='XYZ';blade.rotation_euler.z=angle/2
    lathe('Recessed blue exhaust',(x,y-.295,z),[(0,0),(.09,0),(.09,.006),(0,.006)],component,0,16,material=blue)
    custom('Blue service aperture',[(x-.035,y-.21,z-.186),(x+.035,y-.21,z-.186),(x+.035,y-.16,z-.186),(x-.035,y-.16,z-.186)],[(0,3,2,1)],component,0,material=blue)
    box('Shroud safety band',(x,y+.08,z-.178),(.21,.11,.012),component,6,.003)
    box('Shroud rear access',(x,y-.02,z+.175),(.16,.23,.025),component,10,.004)
    for yy in [-.16,.16]:
        box('Gimbal cheek',(.49*side,yy,z),(.08,.075,.21),component,1,.008)
    for offset in [-.08,.08]:
        cylinder('Access fastener',(x+offset,y-.02,z+.195),.018,.014,(0,0,1),component,4,8)

# One large recessed red eye in a mechanical bezel; no facial/cartoon features.
optic=(-.045,.09,-.435)
lathe('Optical bezel',optic,[(.12,-.015),(.17,-.015),(.181,.01),(.165,.047),(.125,.047),(.115,.028)],'Optics',4,24,axis=(0,0,-1))
lathe('Dark optical recess',optic,[(.108,.025),(.127,.025),(.127,.046),(.108,.046)],'Optics',2,24,axis=(0,0,-1))
lathe('Optical lens',optic,[(0,.065),(.06,.06),(.105,.048),(.11,.04),(.10,.026),(0,.026)],'Optics',0,24,axis=(0,0,-1),material=red)
for x,y in [(-.17,-.07),(.08,-.07),(-.17,.22),(.08,.22)]:
    cylinder('Optics retainer',(x,y,-.465),.018,.014,(0,0,-1),'Optics',1,8)

# The laser is embedded below/right of the optic, not a separate external turret.
box('Laser receiver',(.235,-.18,-.40),(.23,.19,.32),'Weapon',0,.016)
lathe('Laser barrel',(.235,-.18,-.535),[(.041,-.07),(.073,-.07),(.083,-.045),(.083,.10),(.064,.135),(.041,.135)],'Weapon',1,16,axis=(0,0,-1))
lathe('Dark laser bore',(.235,-.18,-.535),[(0,.03),(.04,.03),(.04,.04),(0,.04)],'Weapon',5,12,axis=(0,0,-1))
for y in [-.13,-.20,-.27]:
    box('Receiver cooling slit',(.235,y,-.565),(.12,.017,.005),'Weapon',5,0)
empty('Muzzle',(.235,-.18,-.68),components['Weapon'])
empty('OpticalAxis',(-.045,.09,-.51),components['Optics'])

# Join per moving component, retaining the shared atlas and emissive material slots.
for component,objects in parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object;obj.name=component+'Mesh'
    # Joining identical slot materials can leave duplicate slots; remove safely.
    bpy.ops.object.material_slot_remove_unused()
    triangulate=obj.modifiers.new('Export triangles','TRIANGULATE')
    if hasattr(triangulate,'keep_custom_normals'):triangulate.keep_custom_normals=True
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    obj['component']=component

bpy.context.view_layer.update()
model_objects=list(model_collection.all_objects)
meshes=[obj for obj in model_objects if obj.type=='MESH']
triangles=sum(len(obj.data.polygons) for obj in meshes)
points=[obj.matrix_world@Vector(corner) for obj in meshes for corner in obj.bound_box]
godot_points=[Vector((p.x,p.z,-p.y)) for p in points]
minimum=[min(p[axis] for p in godot_points) for axis in range(3)]
maximum=[max(p[axis] for p in godot_points) for axis in range(3)]
manifest={'generator':'tools/blender/generate_industrial_drone.py','blender':bpy.app.version_string,
          'triangles':triangles,'mesh_components':len(meshes),'dimensions_m':[maximum[i]-minimum[i] for i in range(3)],
          'bounds_min_godot':minimum,'bounds_max_godot':maximum,'forward':'-Z','up':'+Y','origin':[0,0,0],
          'pivots':list(components),'muzzle_godot':[.235,-.18,-.68],
          'textures':[{'name':'albedo','size':[SIZE,SIZE]},{'name':'roughness_metallic','size':[SIZE,SIZE]}],
          'collision':'Existing Godot SphereShape3D radius 0.70m remains unchanged.'}
(OUT/'industrial_drone_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
root['triangles']=triangles

# Source-only inspection studio. Explicit export selection excludes this collection.
world=bpy.data.worlds.new('Neutral inspection world');world.use_nodes=True
world.node_tree.nodes.get('Background').inputs[0].default_value=(.055,.065,.075,1)
world.node_tree.nodes.get('Background').inputs[1].default_value=.35
scene.world=world

def aim(obj, target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
for name,point,power,size in [('Key',(2.4,3.2,3.1),450,3),('Fill',(-2.0,2.1,1.0),220,2.5),('Rim',(1.0,-2.0,2.5),500,2)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);studio_collection.objects.link(obj);obj.location=Vector(point);aim(obj,(0,0,0))
camera_data=bpy.data.cameras.new('InspectionCamera')
camera=bpy.data.objects.new('InspectionCamera',camera_data);studio_collection.objects.link(camera)
camera.location=(2.0,3.0,1.75);aim(camera,(0,0,.03));camera_data.type='ORTHO';camera_data.ortho_scale=2.2;scene.camera=camera
scene.render.engine='BLENDER_EEVEE'
scene.eevee.use_gtao=True;scene.eevee.gtao_distance=.22;scene.eevee.gtao_factor=1.2
scene.eevee.taa_render_samples=64
scene.render.resolution_x=1200;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.film_transparent=True
scene.view_settings.view_transform='AgX'
scene.render.filepath=str(SOURCE/'industrial_drone_preview.png')
# Save an inspection-friendly .blend; runtime is the self-contained GLB only.
bpy.ops.object.select_all(action='DESELECT')
for obj in meshes:obj.select_set(True)
bpy.context.view_layer.objects.active=meshes[0]
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'industrial_drone.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in model_objects:obj.select_set(True)
bpy.context.view_layer.objects.active=root
bpy.ops.export_scene.gltf(filepath=str(OUT/'industrial_drone.glb'),export_format='GLB',use_selection=True,
    export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True,
    export_normals=True,export_texcoords=True,export_materials='EXPORT',
    export_draco_mesh_compression_enable=False)
print('DRONE_EXPORT '+json.dumps(manifest))
if args.render:bpy.ops.render.render(write_still=True)
