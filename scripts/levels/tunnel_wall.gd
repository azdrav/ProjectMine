extends RefCounted
## Convex wall prism with ends cut on the same planes as adjoining room portals.
## Extending an ordinary tilted box leaves wedge-shaped openings at these joints.
static func build(start: Vector3, end: Vector3, frame: Basis, minimum: Vector2, maximum: Vector2, material: Material, overlap: float = 0.25) -> StaticBody3D:
	var direction := (end - start).normalized()
	var normal := Vector3.ZERO
	var axis := direction.abs().max_axis_index()
	normal[axis] = signf(direction[axis])
	var projection := direction.dot(normal)
	var length := start.distance_to(end)
	var corners := [Vector2(minimum.x, minimum.y), Vector2(maximum.x, minimum.y), Vector2(maximum.x, maximum.y), Vector2(minimum.x, maximum.y)]
	var vertices := PackedVector3Array()
	for endpoint in [0, 1]:
		var plane_distance := -overlap if endpoint == 0 else length * projection + overlap
		for corner in corners:
			var offset := frame * Vector3(corner.x, corner.y, 0)
			var distance := (plane_distance - offset.dot(normal)) / projection
			vertices.append(Vector3(corner.x, corner.y, length / 2.0 - distance))
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var center := Vector3.ZERO
	for vertex in vertices:
		center += vertex / vertices.size()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0,1,2,3], [4,5,6,7], [0,1,5,4], [1,2,6,5], [2,3,7,6], [3,0,4,7]]:
		var a: Vector3 = vertices[face[0]]
		var b: Vector3 = vertices[face[1]]
		var c: Vector3 = vertices[face[2]]
		var outward := (b-a).cross(c-a).normalized()
		var face_center: Vector3 = (a+b+c+vertices[face[3]]) / 4.0
		if outward.dot(face_center-center) < 0.0:
			outward = -outward
		# Godot's front-face winding is clockwise; use the supplied outward normals.
		for triangle in [[0,1,2], [0,2,3]]:
			var first: Vector3 = vertices[face[triangle[0]]]
			var second: Vector3 = vertices[face[triangle[1]]]
			var third: Vector3 = vertices[face[triangle[2]]]
			if (second-first).cross(third-first).dot(outward) > 0.0:
				var swap := second
				second = third
				third = swap
			for vertex in [first,second,third]:
				surface.set_normal(outward)
				surface.add_vertex(vertex)
	var visual := MeshInstance3D.new()
	visual.mesh = surface.commit()
	visual.material_override = material
	var body := StaticBody3D.new()
	body.name = "MiteredTunnelWall"
	body.collision_layer = 1
	body.collision_mask = 1
	body.transform = Transform3D(frame, (start + end) / 2.0)
	body.add_child(visual)
	body.add_child(collision)
	return body
