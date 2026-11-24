"""Author the ProjectMine 0.9 cockpit in Godot coordinates. No external art required.
blender --background --python-exit-code 1 --python tools/blender/generate_industrial_cockpit.py
"""
from pathlib import Path
import json, math
import bpy, bmesh
import numpy as np
from mathutils import Vector
OUT=Path(__file__).resolve().parents[2]/'assets/models/cockpit'
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

# A lower beam, load-bearing pillars and real tubes join both cannons to the ship.
box('Lower structural beam',(0,-.76,-.62),(2.30,.16,.22),'Frame',0,.025,2)
box('Upper dashboard sill',(0,-.63,-.68),(1.25,.10,.15),'Frame',1,.012)
for side in [-1,1]:
    prefix='Left' if side<0 else 'Right'
    x=side*.62; y=-.40; z=-.85
    housing=prefix+'Housing'; barrel=prefix+'Barrel'; mount=prefix+'Mount'
    # Receiver is a broad bevelled casting with layered armour and access seams.
    box('Receiver casting',(x,y,z),(.32,.27,.46),housing,0,.022,2)
    box('Top protective plate',(x,y+.15,z+.015),(.35,.055,.43),housing,1,.012)
    box('Rear armoured breech',(x,y,z+.24),(.34,.29,.055),housing,4,.012)
    for face in [-1,1]:
        xx=x+face*.171
        box('Side service plate',(xx,y,z),(.022,.19,.35),housing,11,.006)
        box('Hazard paint',(xx,y+.106,z-.055),(.024,.055,.22),housing,6,.001)
        for zz in [-.12,-.065,-.01,.045,.10]:
            box('Vent slot',(xx+face*.014,y-.012,z+zz),(.008,.09,.023),housing,5,0)
        for yy in [-.095,.095]:
            for zz in [-.15,.15]:
                cylinder('Hex captive bolt',(xx+face*.02,y+yy,z+zz),.014,.016,(face,0,0),housing,4,6)
        # Orange strip is emissive, not an extra dynamic light.
        obj=box('Lamp inset',(xx+face*.01,y-.085,z-.07),(.014,.023,.10),housing,5,.003)
        obj=box('Amber insert',(xx+face*.02,y-.085,z-.07),(.012,.010,.08),housing,5,0)
        obj.data.materials.clear();obj.data.materials.append(orange)
    for zz in [-.12,-.065,-.01,.045,.10]:
        box('Top radiator',(x,y+.185,z+zz),(.22,.014,.023),housing,2,.002)
    # Visible aft receiver face: recessed service panel, eight fasteners and hydraulic coupling.
    box('Rear recess',(x,y,z+.273),(.27,.22,.018),housing,2,.008)
    box('Aft service plate',(x,y+.01,z+.286),(.21,.16,.012),housing,11,.009)
    for xx in [-.13,.13]:
        for yy in [-.10,0,.10]:
            cylinder('Aft captive hex',(x+xx,y+yy,z+.292),.014,.016,(0,0,1),housing,4,8,.001)
    cylinder('Hydraulic socket',(x+side*.065,y-.015,z+.31),.033,.04,(0,0,1),housing,4,12,.003)
    tube('Visible piston',[(x+side*.065,y-.015,z+.34),(x+side*.18,y-.06,z+.39),(side*.94,-.62,-.55)],.021,mount,4,10)
    box('Hazard shoulder',(x,y+.18,z+.16),(.31,.024,.095),housing,6,.004)
    lamp=box('Aft amber status',(x-side*.05,y-.065,z+.302),(.085,.012,.012),housing,5,.001)
    lamp.data.materials.clear();lamp.data.materials.append(orange)
    # Barrel: hollow muzzle, reinforced collars, fin rings and sliding pistons.
    barrel_y=y+.10
    origin=(x,barrel_y,-.95)
    lathe('Barrel tube',origin,[(.065,-.10),(.096,-.10),(.099,.47),(.079,.53),(.065,.53)],barrel,4,24,axis=(0,0,-1))
    lathe('Muzzle crown',origin,[(.065,.44),(.113,.44),(.118,.49),(.106,.55),(.065,.55)],barrel,0,24,axis=(0,0,-1))
    lathe('Dark bore',origin,[(0,.37),(.064,.37),(.064,.39),(0,.39)],barrel,5,16,axis=(0,0,-1))
    for depth in [.04,.13,.22,.31]:
        lathe('Cooling collar',origin,[(.096,depth),(.126,depth),(.126,depth+.028),(.096,depth+.028)],barrel,1,20,axis=(0,0,-1))
    for face in [-1,1]:
        cylinder('Recoil rail',(x+face*.117,barrel_y-.06,-1.05),.018,.40,(0,0,-1),barrel,4,10)
    empty('Muzzle'+prefix,(x,barrel_y,-1.51),components[barrel])
    # Saddle and side arm are rigid; the bracket receives only a small reaction.
    box('Load saddle',(x,y-.18,z+.025),(.40,.10,.34),mount,0,.014)
    cylinder('Pivot pin',(x,y-.10,z+.20),.071,.43,(1,0,0),mount,4,16,.004)
    for face in [-1,1]:
        cylinder('Pivot cover',(x+face*.23,y-.10,z+.20),.053,.035,(1,0,0),mount,0,12,.004)
        cylinder('Pivot hex',(x+face*.252,y-.10,z+.20),.022,.018,(1,0,0),mount,4,6)
    tube('Support arm',[(side*.98,-.70,-.63),(side*.90,-.57,-.68),(x,-.57,-.83)],.055,mount,0,8)
    tube('Hydraulic body',[(side*.96,-.65,-.62),(side*.80,-.52,-.69)],.035,mount,1,12)
    tube('Hydraulic piston',[(side*.80,-.52,-.69),(x,-.49,-.83)],.018,mount,4,12)
    tube('Power conduit',[(x+.08*side,-.58,-.85),(side*.83,-.65,-.69),(side*1.04,-.74,-.59)],.021,'Frame',2,8)
    tube('Amber cable',[(x-.08*side,-.58,-.84),(side*.75,-.66,-.68),(side*.96,-.75,-.61)],.015,'Frame',7,8)
    # Diagonal cockpit pillars stay at the extreme sides of the field of view.
    path=[(side*1.00,-.73,-.66),(side*1.08,-.27,-.73),(side*1.32,.65,-.86)]
    tube('Armoured side pillar',path,.066,'Frame',0,8)
    tube('Pillar edge rail',[(p[0]-side*.065,p[1],p[2]+.018) for p in path],.012,'Frame',4,6)
    for k in range(4):
        yy=-.58+k*.25; xx=side*(1.00+k*.065); zz=-.68-k*.035
        box('Pillar hazard tab',(xx,yy,zz+.075),(.09,.075,.015),'Frame',6,.002)
        cylinder('Frame bolt',(xx,yy+.065,zz+.085),.013,.015,(0,0,1),'Frame',4,6)
    obj=box('Pillar light',(side*1.195,.19,-.70),(.025,.17,.018),'Frame',5,.003)
    obj.data.materials.clear();obj.data.materials.append(orange)
    for xx in [side*.85,side*1.05]:
        cylinder('Beam bolt',(xx,-.71,-.48),.018,.02,(0,0,1),'Frame',4,6)
# Join by animated rigid component: two shared material surfaces, no tiny-node draw calls.
for component,objects in parts.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object;obj.name=component+'Mesh'
    bpy.ops.object.material_slot_remove_unused()
    modifier=obj.modifiers.new('Export triangles','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=modifier.name)
meshes=[o for o in model_collection.all_objects if o.type=='MESH']
triangles=sum(len(o.data.polygons) for o in meshes)
manifest={'generator':'tools/blender/generate_industrial_cockpit.py','triangles':triangles,'rigid_meshes':len(meshes),'textures_px':512,'forward':'-Z','components':list(components),'collision':'none; visual-only cockpit','muzzles':{'left':[-.62,-.30,-1.51],'right':[.62,-.30,-1.51]}}
(OUT/'industrial_cockpit_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'industrial_cockpit.blend'))
bpy.ops.object.select_all(action='DESELECT')
for obj in model_collection.all_objects:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'industrial_cockpit.glb'),export_format='GLB',use_selection=True,export_yup=True,export_cameras=False,export_lights=False)
print('COCKPIT',json.dumps(manifest))
