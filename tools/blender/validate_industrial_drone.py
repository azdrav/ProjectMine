"""Validate the exported self-contained GLB using only Python's standard library."""
from pathlib import Path
from itertools import product
import json,struct,math
ROOT=Path(__file__).resolve().parents[2]
path=ROOT/'assets/models/enemies/industrial_drone.glb'
data=path.read_bytes()
magic,version,length=struct.unpack_from('<4sII',data)
assert magic==b'glTF' and version==2 and length==len(data),'Invalid GLB header'
json_length,kind=struct.unpack_from('<II',data,12)
assert kind==0x4E4F534A
asset=json.loads(data[20:20+json_length])
manifest=json.loads((path.parent/'industrial_drone_manifest.json').read_text())
triangles=0
for mesh in asset['meshes']:
    for primitive in mesh['primitives']:
        assert primitive.get('mode',4)==4,'Non-triangular primitive'
        attributes=primitive['attributes']
        assert {'POSITION','NORMAL','TEXCOORD_0'} <= attributes.keys()
        triangles+=asset['accessors'][primitive['indices']]['count']//3
assert triangles==manifest['triangles'] and 3000<=triangles<=5000,(triangles,manifest['triangles'])
assert len(asset['meshes'])==5
assert 'KHR_draco_mesh_compression' not in asset.get('extensionsUsed',[]),'Unexpected decoder dependency'
assert all('bufferView' in image and 'uri' not in image for image in asset['images']),'External texture dependency'
assert all('uri' not in buffer for buffer in asset['buffers'])
assert 'cameras' not in asset and 'KHR_lights_punctual' not in asset.get('extensions',{}),'Studio leaked into runtime'
names={node['name'] for node in asset['nodes']}
assert {'Chassis','PropulsionLeft','PropulsionRight','Optics','Weapon','Muzzle','OpticalAxis'}<=names

def identity():return [[float(r==c) for c in range(4)] for r in range(4)]
def multiply(a,b):return [[sum(a[r][k]*b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]
def matrix(node):
    if 'matrix' in node:return [[node['matrix'][c*4+r] for c in range(4)] for r in range(4)]
    x,y,z,w=node.get('rotation',[0,0,0,1]);scale=node.get('scale',[1,1,1]);translation=node.get('translation',[0,0,0])
    rotation=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
              [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
              [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    result=identity()
    for r in range(3):
        for c in range(3):result[r][c]=rotation[r][c]*scale[c]
        result[r][3]=translation[r]
    return result
points=[];attachments={}
def walk(index,parent):
    node=asset['nodes'][index];world=multiply(parent,matrix(node))
    attachments[node.get('name','')]=[world[r][3] for r in range(3)]
    if 'mesh' in node:
        for primitive in asset['meshes'][node['mesh']]['primitives']:
            accessor=asset['accessors'][primitive['attributes']['POSITION']]
            for point in product(*zip(accessor['min'],accessor['max'])):
                points.append([sum(world[r][c]*point[c] for c in range(3))+world[r][3] for r in range(3)])
    for child in node.get('children',[]):walk(child,world)
for node in asset['scenes'][asset.get('scene',0)]['nodes']:walk(node,identity())
minimum=[min(p[axis] for p in points) for axis in range(3)]
maximum=[max(p[axis] for p in points) for axis in range(3)]
for actual,expected in zip(minimum+maximum,manifest['bounds_min_godot']+manifest['bounds_max_godot']):assert abs(actual-expected)<.0001,(actual,expected)
assert all(abs(a-b)<.00001 for a,b in zip(attachments['Muzzle'],manifest['muzzle_godot']))
assert all(abs(v)<.00001 for v in attachments['IndustrialDrone'])
assert attachments['OpticalAxis'][2]<0 and attachments['Muzzle'][2]<0,'Wrong forward direction'
materials={material['name']:material for material in asset['materials']}
metal=materials['Industrial_Atlas_PBR']['pbrMetallicRoughness']
assert 'baseColorTexture' in metal and 'metallicRoughnessTexture' in metal,'PBR maps not exported'
assert materials['Optic_Emission']['emissiveFactor'][0]>0
assert materials['Thruster_Emission']['emissiveFactor'][2]>0
print(f'GLB PASS: {triangles} triangles, 5 component meshes, {len(asset["materials"])} materials, {len(asset["images"])} embedded textures, {len(data)} bytes')
print('Godot bounds:',minimum,maximum,'Muzzle:',attachments['Muzzle'])
