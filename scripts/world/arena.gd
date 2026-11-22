class_name PlaygroundArena
extends Node3D

const Rules = preload("res://scripts/core/round_rules.gd")
var _materials: Dictionary = {}

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("95c8d6")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d3e5d1")
	settings.ambient_light_energy = 0.35
	environment.environment = settings
	add_child(environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52, -28, 0)
	sunlight.light_color = Color("fff0d1")
	sunlight.light_energy = 0.8
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 70
	add_child(sunlight)
	box(Vector3(0, -0.3, 0), Vector3(70, 0.5, 70), Color("4d815c"))
	box(Vector3(0, -0.035, 0), Vector3(34, 0.05, 34), Color("7ca567"))
	# Mown strips and crossing paths make scale and player motion easy to read.
	for x in range(-16, 17, 4):
		box(Vector3(x, 0, 0), Vector3(2, 0.015, 34), Color("83ac6b"))
	box(Vector3(0, 0.018, 0), Vector3(3.5, 0.025, 33.4), Color("c8b88b"))
	box(Vector3(0, 0.02, 0), Vector3(33.4, 0.025, 3.5), Color("c8b88b"))
	var court := cylinder(Vector3(0, 0.055, 0), 4.4, 0.03, Color("80b0a4"))
	court.mesh.radial_segments = 64
	var ring := TorusMesh.new()
	ring.inner_radius = 3.75
	ring.outer_radius = 3.83
	mesh_at(ring, Vector3(0, 0.09, 0), Color("e8ead1"))
	for axis in [0, 1]:
		var line_size := Vector3(0.08, 0.02, 8.5) if axis == 0 else Vector3(8.5, 0.02, 0.08)
		box(Vector3(0, 0.09, 0), line_size, Color("e8ead1"))
	# Crossing this paint eliminates a player; it is deliberately not a wall.
	for n in range(-17, 18):
		for edge in [-17.0, 17.0]:
			box(Vector3(n, 0.08, edge), Vector3(0.75, 0.06, 0.14), Color("f5e4a0"))
			box(Vector3(edge, 0.08, n), Vector3(0.14, 0.06, 0.75), Color("f5e4a0"))
	for center in Rules.TREES:
		_tree(Vector3(center.x, 0, center.y), true)
	for x in [-23, -19, 19, 23]:
		for z in [-24, -18, 0, 18, 24]:
			_tree(Vector3(x, 0, z), false)
	for center in Rules.BENCHES:
		_bench(Vector3(center.x, 0, center.y))
	for side in [-1, 1]:
		for n in range(-20, 21, 2):
			box(Vector3(n, 0.6, side * 20), Vector3(0.12, 1.2, 0.12), Color("cfdfb1"))
			box(Vector3(side * 20, 0.6, n), Vector3(0.12, 1.2, 0.12), Color("cfdfb1"))
		for y in [0.35, 0.9]:
			box(Vector3(0, y, side * 20), Vector3(40, 0.1, 0.1), Color("cfdfb1"))
			box(Vector3(side * 20, y, 0), Vector3(0.1, 0.1, 40), Color("cfdfb1"))
	var board := Label3D.new()
	board.text = "PASSING GAME\nPASS. CHASE. SURVIVE."
	board.font_size = 75
	board.pixel_size = 0.012
	board.position = Vector3(0, 4.5, -20.5)
	board.modulate = Color("f6f4d7")
	add_child(board)
	box(Vector3(0, 4.4, -20.7), Vector3(13, 2.8, 0.3), Color("234e45"))
	for x in [-5, 5]:
		box(Vector3(x, 1.8, -20.7), Vector3(0.3, 3.6, 0.3), Color("57714c"))

func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.9
		_materials[key] = mat
	return _materials[key]

func mesh_at(shape: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material(color)
	node.position = at
	add_child(node)
	return node

func box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh_at(shape, at, color)

func cylinder(at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 12
	return mesh_at(shape, at, color)

func _tree(at: Vector3, solid: bool) -> void:
	cylinder(at + Vector3(0, 1.6, 0), 0.45, 3.2, Color("8e7251"))
	for offset in [Vector3(0, 4.2, 0), Vector3(-0.9, 3.6, 0.2), Vector3(0.7, 3.8, -0.3)]:
		var leaf := SphereMesh.new()
		leaf.radius = 1.5
		leaf.height = 2.8
		leaf.radial_segments = 10
		leaf.rings = 5
		mesh_at(leaf, at + offset, Color("427f52") if offset.x < 0 else Color("67984e"))
	if solid:
		var body := StaticBody3D.new()
		body.position = at + Vector3(0, 1.5, 0)
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.45
		shape.height = 3.0
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

func _bench(at: Vector3) -> void:
	box(at + Vector3(0, 0.65, 0), Vector3(2.7, 0.18, 0.86), Color("d7a76c"))
	box(at + Vector3(0, 1.15, 0.33), Vector3(2.7, 0.75, 0.16), Color("d7a76c"))
	for x in [-0.95, 0.95]:
		box(at + Vector3(x, 0.3, 0), Vector3(0.16, 0.6, 0.7), Color("304c4b"))
	var body := StaticBody3D.new()
	body.position = at + Vector3(0, 0.6, 0)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.7, 1.2, 0.86)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
