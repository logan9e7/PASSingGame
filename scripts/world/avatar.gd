class_name PlaygroundAvatar
extends CharacterBody3D

const PALETTE := [Color("e6f778"), Color("b7a1e8"), Color("f29478"), Color("79c7d7"), Color("e7a2c5"), Color("88c9a7"), Color("e5bb63"), Color("a3b7dc")]
var player_id := 0
var desired := Vector3.ZERO
var initialized := false
var eliminated := false
var model: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var name_label: Label3D
var role_label: Label3D
var ring: MeshInstance3D
var beacon: MeshInstance3D
var _clock := 0.0
var _speed := 0.0
var _last := Vector3.ZERO

func _ready() -> void:
	# Network proxies are placed from the authoritative simulation, never locally
	# used to claim catches or scores. Their capsule supports camera obstruction.
	collision_layer = 2
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.85
	collision.shape = capsule
	collision.position.y = 0.95
	add_child(collision)
	model = Node3D.new()
	add_child(model)
	var shirt: Color = PALETTE[player_id % PALETTE.size()]
	_part(model, CapsuleMesh.new(), Vector3(0, 1.05, 0), Vector3(0.72, 0.55, 0.43), shirt)
	_part(model, SphereMesh.new(), Vector3(0, 1.68, 0), Vector3(0.65, 0.65, 0.63), Color("e9bc94"))
	_part(model, SphereMesh.new(), Vector3(0, 1.87, 0.04), Vector3(0.7, 0.34, 0.65), Color("3c3e3d"))
	for x in [-0.12, 0.12]:
		_part(model, SphereMesh.new(), Vector3(x, 1.70, -0.29), Vector3(0.065, 0.075, 0.04), Color("253a3b"))
	left_arm = _limb(Vector3(-0.46, 1.25, 0), Vector3(0.22, 0.6, 0.23), shirt)
	right_arm = _limb(Vector3(0.46, 1.25, 0), Vector3(0.22, 0.6, 0.23), shirt)
	left_leg = _limb(Vector3(-0.2, 0.74, 0), Vector3(0.26, 0.7, 0.28), Color("314b56"))
	right_leg = _limb(Vector3(0.2, 0.74, 0), Vector3(0.26, 0.7, 0.28), Color("314b56"))
	for leg in [left_leg, right_leg]:
		_part(leg, BoxMesh.new(), Vector3(0, -0.6, -0.08), Vector3(0.3, 0.18, 0.48), Color("f3efd8"))
	name_label = _label(2.4, 40)
	role_label = _label(2.78, 30)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.63
	ring_mesh.outer_radius = 0.69
	ring = _part(self, ring_mesh, Vector3(0, 0.045, 0), Vector3.ONE, Color("f3a176"))
	var marker := CylinderMesh.new()
	marker.top_radius = 0.28
	marker.bottom_radius = 0.0
	marker.height = 0.4
	beacon = _part(self, marker, Vector3(0, 3.35, 0), Vector3.ONE, Color("f3a176"))

func update_player(data: Dictionary, state: Dictionary, local_id: int) -> void:
	var pos: Vector2 = data.position
	desired = Vector3(pos.x, 0, pos.y)
	if not initialized:
		global_position = desired
		_last = desired
		initialized = true
	eliminated = data.eliminated
	model.visible = not eliminated
	name_label.text = String(data.name) + (" · YOU" if player_id == local_id else "")
	var color: Color = PALETTE[int(data.color) % PALETTE.size()]
	(model.get_child(0) as MeshInstance3D).material_override.albedo_color = color
	(left_arm.get_child(0) as MeshInstance3D).material_override.albedo_color = color
	(right_arm.get_child(0) as MeshInstance3D).material_override.albedo_color = color
	var is_chaser: bool = state.chaser == player_id
	var is_target: bool = state.target == player_id
	var running: bool = state.phase == "playing"
	role_label.text = "OUT THIS ROUND" if eliminated else "CHASER" if is_chaser and running else "TARGET" if is_target and running else ""
	role_label.modulate = Color("f3a176") if is_target else Color("e6f778")
	ring.visible = running and not eliminated and (is_target or is_chaser or player_id == local_id)
	beacon.visible = running and not eliminated and is_target
	var ring_mat: StandardMaterial3D = ring.material_override
	ring_mat.albedo_color = Color("f3a176") if is_target else Color("e6f778") if is_chaser else Color("f7f7df")

func _process(delta: float) -> void:
	if not initialized:
		return
	var displacement := desired - global_position
	if displacement.length() > 5.0:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, 1.0 - exp(-delta * 18.0))
	var motion := global_position - _last
	_speed = lerpf(_speed, motion.length() / maxf(delta, 0.001), minf(1, delta * 12))
	if motion.length_squared() > 0.00001:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(-motion.x, -motion.z), delta * 12.0)
	_clock += delta * (10 if _speed > 0.1 else 2)
	var swing := sin(_clock) * minf(_speed / 5.2, 1.0) * 0.7
	left_leg.rotation.x = swing
	right_leg.rotation.x = -swing
	left_arm.rotation.x = -swing
	right_arm.rotation.x = swing
	model.position.y = absf(sin(_clock)) * minf(_speed, 5.0) * 0.015
	beacon.position.y = 3.35 + sin(_clock * 0.5) * 0.12
	_last = global_position

func _limb(at: Vector3, size: Vector3, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	model.add_child(pivot)
	_part(pivot, CapsuleMesh.new(), Vector3(0, -size.y * 0.4, 0), size, color)
	return pivot

func _part(parent: Node3D, mesh: Mesh, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	# Primitive meshes have predictable local units; use box size or scale spheres.
	if mesh is BoxMesh:
		mesh.size = size
	elif mesh is SphereMesh:
		mesh.radius = 0.5
		mesh.height = 1.0
		node.scale = size
	elif mesh is CapsuleMesh:
		mesh.radius = 0.5
		mesh.height = 2.0
		node.scale = Vector3(size.x, size.y, size.z)
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	node.material_override = mat
	parent.add_child(node)
	return node

func _label(y: float, font_size_value: int) -> Label3D:
	var label := Label3D.new()
	label.position.y = y
	label.font_size = font_size_value
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 9
	add_child(label)
	return label
