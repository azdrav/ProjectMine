extends RefCounted
## Visual-only construction kit. Shared meshes/materials; no bodies, lights or gameplay.
static func material(color: Color, metal: float=0.0, glow: float=0.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.albedo_color=color;m.metallic=metal;m.roughness=.76 if metal<.5 else .42
	if glow>0:
		m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=glow
	return m
static func part(parent: Node3D, mesh: Mesh, point: Vector3, mat: Material) -> MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=point;node.material_override=mat
	parent.add_child(node)
	return node
static func block(parent: Node3D, point: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size
	return part(parent,mesh,point,mat)
static func tube(parent: Node3D, point: Vector3, radius: float, length: float, mat: Material, tip: float=-1) -> MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.bottom_radius=radius;mesh.top_radius=radius if tip<0 else tip
	mesh.height=length;mesh.radial_segments=16
	var node:=part(parent,mesh,point,mat);node.rotation.x=PI/2
	return node
static func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var node:=block(parent,(a+b)*.5,Vector3(width,width,a.distance_to(b)),mat)
	node.basis=Basis.looking_at(b-a,Vector3.UP if absf((b-a).normalized().y)<.95 else Vector3.FORWARD)
static func loft(parent: Node3D, sections: Array[Vector3], mat: Material) -> MeshInstance3D:
	# Each section is (half width, half height, z). Chamfered octagonal armor.
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector2]=[Vector2(-.72,1),Vector2(.72,1),Vector2(1,.55),Vector2(1,-.55),Vector2(.72,-1),Vector2(-.72,-1),Vector2(-1,-.55),Vector2(-1,.55)]
	var vertices: Array[Vector3]=[]
	for section in sections:
		for p in outline: vertices.append(Vector3(p.x*section.x,p.y*section.y,section.z))
	for ring in range(sections.size()-1):
		for j in range(8):
			var a:=ring*8+j;var b:=ring*8+(j+1)%8;var c:=b+8;var d:=a+8
			for idx in [a,b,c,a,c,d]: st.add_vertex(vertices[idx])
	for end in [0,sections.size()-1]:
		var center:=Vector3(0,0,sections[end].z)
		for j in range(8):
			var a:=vertices[end*8+j];var b:=vertices[end*8+(j+1)%8]
			for v in ([center,b,a] if end==0 else [center,a,b]): st.add_vertex(v)
	st.generate_normals();return part(parent,st.commit(),Vector3.ZERO,mat)
static func rock(parent: Node3D, point: Vector3, size: Vector3, seed_value: int, entrance: bool=false) -> void:
	var noise:=FastNoiseLite.new();noise.seed=seed_value;noise.frequency=1.2;noise.fractal_octaves=2
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	var craters: Array[Vector4]=[]
	for i in range(16):
		var direction:=Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1)).normalized()
		craters.append(Vector4(direction.x,direction.y,direction.z,rng.randf_range(.09,.23)))
	craters.append(Vector4(-.35,.30,-.887,.25))
	craters.append(Vector4(-.50,-.25,-.829,.19))
	var rings:=40;var segments:=80
	var positions: Array[Vector3]=[];var colors: Array[Color]=[]
	for i in range(rings+1):
		var theta:=lerpf(.21 if entrance else .002,PI-.002,float(i)/rings)
		for j in range(segments+1):
			var phi:=TAU*float(j)/segments
			var d:=Vector3(sin(theta)*cos(phi),sin(theta)*sin(phi),-cos(theta))
			var n:=noise.get_noise_3dv(d*3)
			var radius:=1.0+.22*noise.get_noise_3dv(d)+.018*n
			for crater in craters:
				var distance:=d.distance_to(Vector3(crater.x,crater.y,crater.z))/crater.w
				if distance<1.3:
					radius-=.055*exp(-distance*distance*4)
					radius+=.018*exp(-pow((distance-.92)*7,2))
			# Preserve a stable portal opening while retaining an irregular outer silhouette.
			if entrance and i<3: radius=lerpf(1.0,radius,float(i)/3)
			positions.append(d*size*radius)
			var tone:=clampf(.72+n*.6,.42,1.0)
			colors.append(Color(.40,.365,.32)*tone)
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(0)
	for i in range(rings):
		for j in range(segments):
			var a:=i*(segments+1)+j;var b:=a+1;var c:=a+segments+1;var d:=c+1
			for idx in [a,c,b,b,c,d]: st.set_color(colors[idx]);st.add_vertex(positions[idx])
	st.generate_normals()
	var mat:=material(Color.WHITE);mat.vertex_color_use_as_albedo=true;mat.roughness=.96
	var grain:=FastNoiseLite.new();grain.seed=seed_value;grain.frequency=.085;grain.fractal_octaves=4
	var image:=Image.create(256,256,false,Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var shade:=clampf(.78+grain.get_noise_2d(x,y)*.4,.5,1)
			image.set_pixel(x,y,Color(shade,shade,shade))
	image.generate_mipmaps();mat.albedo_texture=ImageTexture.create_from_image(image)
	mat.uv1_triplanar=true;mat.uv1_scale=Vector3.ONE*.18
	part(parent,st.commit(),point,mat).name="CrateredAsteroid"
static func craft(parent: Node3D) -> Node3D:
	var ship:=Node3D.new();ship.name="IndustrialMiningSkiff";parent.add_child(ship)
	var steel:=material(Color(.23,.28,.30),.7)
	var armor:=material(Color(.34,.38,.37),.65)
	var dark:=material(Color(.035,.045,.05),.4)
	var yellow:=material(Color(.7,.43,.065),.55)
	var chrome:=material(Color(.48,.55,.58),.85)
	var glass:=material(Color(.025,.11,.16),.75)
	glass.roughness=.17
	var cyan:=material(Color(.18,.65,.78),.3,1.5)
	var amber:=material(Color(1,.25,.035),0,2.2)
	loft(ship,[Vector3(.65,.43,-2.25),Vector3(1.18,.60,-1.3),Vector3(1.25,.60,.85),Vector3(.9,.42,1.8)],steel)
	var cabin:=loft(ship,[Vector3(.61,.25,-1.72),Vector3(.77,.37,-.55),Vector3(.62,.32,.45)],armor)
	cabin.position.y=.64
	# Sloped panoramic glazing, inset between heavy structural rails.
	var window:=loft(ship,[Vector3(.54,.19,-1.75),Vector3(.67,.26,-.61)],glass)
	window.position.y=.90
	beam(ship,Vector3(0,1.09,-1.75),Vector3(0,1.16,-.58),.055,steel)
	for side in [-1.0,1.0]:
		beam(ship,Vector3(side*.56,1.08,-1.74),Vector3(side*.7,1.16,-.55),.065,chrome)
		block(ship,Vector3(side*.96,.57,.25),Vector3(.22,.13,1.5),yellow)
		block(ship,Vector3(side*1.2,-.18,-.65),Vector3(.2,.34,2.1),dark)
		beam(ship,Vector3(side*.9,-.25,.65),Vector3(side*1.75,-.22,.45),.25,steel)
		var pod:=loft(ship,[Vector3(.39,.4,-.5),Vector3(.5,.47,.5),Vector3(.42,.4,1.95)],armor)
		pod.position=Vector3(side*1.65,-.12,0)
		tube(ship,Vector3(side*1.65,-.12,1.93),.39,.28,dark)
		tube(ship,Vector3(side*1.65,-.12,2.08),.31,.1,chrome)
		tube(ship,Vector3(side*1.65,-.12,2.14),.25,.06,amber)
		var plume:=tube(ship,Vector3(side*1.65,-.12,2.7),.23,1.1,amber,.025)
		plume.name="Exhaust";plume.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Cannons, cooling collars and hydraulic mounting assemblies.
		block(ship,Vector3(side*1.14,-.38,-1.1),Vector3(.48,.47,.8),armor)
		tube(ship,Vector3(side*1.14,-.38,-2.0),.18,1.3,steel)
		for z in [-1.5,-1.75,-2.0,-2.45]: tube(ship,Vector3(side*1.14,-.38,z),.215,.08,chrome)
		tube(ship,Vector3(side*1.14,-.38,-2.68),.185,.18,dark)
		beam(ship,Vector3(side*1.02,-.52,-.3),Vector3(side*1.65,-.34,-.45),.09,chrome)
		for i in range(5):
			block(ship,Vector3(side*1.68,.365,.4+i*.22),Vector3(.55,.035,.075),dark)
		for z in [-.9,-.6,-.3]:
			var stripe:=block(ship,Vector3(side*.96,.65,z),Vector3(.24,.025,.10),dark)
			stripe.rotation.y=.4
		block(ship,Vector3(side*.82,.22,-1.77),Vector3(.19,.11,.035),cyan)
		block(ship,Vector3(side*2.08,-.10,.2),Vector3(.025,.10,.26),amber)
	block(ship,Vector3(0,.67,.9),Vector3(.82,.12,.6),dark)
	for i in range(6): block(ship,Vector3(-.32+i*.13,.75,.9),Vector3(.055,.07,.55),chrome)
	# Small stencilled identifier is fixed on the hull, not a floating HUD label.
	var label:=Label3D.new();label.text="PM / 07";label.font_size=32;label.pixel_size=.006
	label.position=Vector3(0,.615,.24);label.rotation.x=-PI/2;label.modulate=Color(.8,.73,.5)
	ship.add_child(label)
	return ship
static func portal(parent: Node3D) -> void:
	var steel:=material(Color(.20,.24,.25),.7)
	var concrete:=material(Color(.27,.26,.23),.2)
	var dark:=material(Color(.045,.055,.06),.45)
	var yellow:=material(Color(.78,.48,.07),.5)
	var amber:=material(Color(1,.30,.045),.1,2)
	var green:=material(Color(.2,.8,.5),.1,1.2)
	# Octagonal bore remains visibly hollow all the way into the mountain.
	for i in range(8):
		var angle:=TAU*(i+.5)/8
		var radial:=Vector3(cos(angle),sin(angle),0)
		var wall:=block(parent,radial*4.85+Vector3(0,0,3),Vector3(.6,4.05,15),steel)
		wall.rotation.z=angle
		for z in [-4.5,-1.0,2.5,6.0,9.5]:
			var rib:=block(parent,radial*4.48+Vector3(0,0,z),Vector3(.23,3.8,.22),dark)
			rib.rotation.z=angle
			if i%2==0:
				var light:=block(parent,radial*4.30+Vector3(0,0,z-.18),Vector3(.06,1.05,.10),green)
				light.rotation.z=angle
		var rim:=block(parent,radial*5.0+Vector3(0,0,-4.8),Vector3(1.1,4.45,.75),concrete)
		rim.rotation.z=angle
		var armor:=block(parent,radial*4.9+Vector3(0,0,-5.23),Vector3(.45,3.6,.16),steel)
		armor.rotation.z=angle
		for t in [-1.25,1.25]:
			var tangent:=Vector3(-sin(angle),cos(angle),0)
			var lamp:=block(parent,radial*4.75+tangent*t+Vector3(0,0,-5.36),Vector3(.11,.5,.10),amber)
			lamp.rotation.z=angle
		# Brackets continue beyond the rim into the asteroid rock.
		beam(parent,radial*5.1+Vector3(0,0,-4.3),radial*7.0+Vector3(0,0,0),.32,steel)
	for side in [-1.0,1.0]:
		block(parent,Vector3(side*5.75,-1,-4.2),Vector3(1.0,3.1,1.5),steel)
		for y in [-2.1,-1.55,-1.0,-.45]:
			block(parent,Vector3(side*5.75,y,-4.99),Vector3(.75,.22,.05),yellow if int(y*10)%2 else dark)
		beam(parent,Vector3(side*3,-4.8,-4),Vector3(side*5,-8,1),.4,steel)
	var sign:=Label3D.new();sign.text="E—04  /  EVACUATION";sign.font_size=48;sign.pixel_size=.017
	sign.position=Vector3(0,5.7,-5.35);sign.rotation.y=PI;sign.modulate=Color(.6,.85,.8)
	parent.add_child(sign)
	block(parent,Vector3(0,5.7,-5.1),Vector3(7.5,.95,.25),dark)
