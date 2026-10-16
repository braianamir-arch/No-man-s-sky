class_name ResourceNode
extends StaticBody3D
## Deposito minable (rocas, plantas, cristales, asteroides).

signal depleted(node: ResourceNode)

var resource_id := "ferrita"
var amount := 40
var key := ""
var _initial := 40
var _base_scale := Vector3.ONE
var _progress := 0.0
var _mesh: MeshInstance3D
var _marker: Label3D


static func create(id: String, size: float, amt: int, rng: RandomNumberGenerator, asteroid := false) -> ResourceNode:
	var n := ResourceNode.new()
	n.resource_id = id
	n.amount = amt
	n.add_to_group("minable")
	var col: Color = GameState.RESOURCES[id]["color"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.8
	var mi := MeshInstance3D.new()
	var shape_radius := size
	var shape_offset := Vector3.ZERO
	if asteroid:
		var s := SphereMesh.new()
		s.radius = size
		s.height = size * 2.0
		s.radial_segments = 7
		s.rings = 4
		mi.mesh = s
		mat.albedo_color = Color(0.35, 0.33, 0.3).lerp(col, 0.35)
		mat.emission_enabled = true
		mat.emission = col * 0.25
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
		mi.scale = Vector3(1.0, rng.randf_range(0.6, 1.0), rng.randf_range(0.7, 1.2))
	else:
		match id:
			"ferrita":
				var s := SphereMesh.new()
				s.radius = size
				s.height = size * 1.3
				s.radial_segments = 6
				s.rings = 3
				mi.mesh = s
				shape_offset = Vector3(0, size * 0.3, 0)
				mi.position = shape_offset
			"dihidrogeno":
				var p := PrismMesh.new()
				p.size = Vector3(size * 0.7, size * 2.6, size * 0.7)
				mi.mesh = p
				mi.position = Vector3(0, size * 1.1, 0)
				mat.emission_enabled = true
				mat.emission = col * 0.8
				mat.metallic = 0.4
				mat.roughness = 0.2
				shape_offset = Vector3(0, size, 0)
				shape_radius = size * 0.9
			_:
				# Plantas: tallo + bulbo brillante.
				var stem := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = size * 0.12
				c.bottom_radius = size * 0.18
				c.height = size * 1.6
				c.radial_segments = 6
				stem.mesh = c
				stem.position = Vector3(0, size * 0.8, 0)
				var stem_mat := StandardMaterial3D.new()
				stem_mat.albedo_color = Color(0.25, 0.35, 0.15)
				stem.material_override = stem_mat
				n.add_child(stem)
				var s := SphereMesh.new()
				s.radius = size * 0.55
				s.height = size * 1.0
				s.radial_segments = 8
				s.rings = 4
				mi.mesh = s
				mi.position = Vector3(0, size * 1.7, 0)
				mat.emission_enabled = true
				mat.emission = col * 0.6
				shape_offset = Vector3(0, size * 1.2, 0)
				shape_radius = size * 0.8
	mi.material_override = mat
	n.add_child(mi)
	n._mesh = mi
	n._base_scale = mi.scale
	n._initial = maxi(amt, 1)
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = shape_radius
	cs.shape = sphere
	cs.position = shape_offset
	n.add_child(cs)
	return n


## Aplica minado; devuelve la cantidad de recurso obtenida en este frame.
func mine(power: float) -> int:
	_progress += power
	var gained := 0
	while _progress >= 1.0 and amount > 0:
		_progress -= 1.0
		amount -= 1
		gained += 1
	if _mesh:
		var wobble := 1.0 + randf_range(-0.05, 0.05)
		_mesh.scale = _base_scale * wobble * (0.4 + 0.6 * float(amount) / float(_initial))
	if amount <= 0:
		depleted.emit(self)
		queue_free()
	return gained


func show_marker(seconds: float) -> void:
	if _marker == null:
		_marker = Label3D.new()
		_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_marker.no_depth_test = true
		_marker.fixed_size = true
		_marker.pixel_size = 0.0015
		_marker.font_size = 28
		_marker.outline_size = 8
		_marker.position = Vector3(0, 4, 0)
		_marker.modulate = GameState.RESOURCES[resource_id]["color"]
		add_child(_marker)
	_marker.text = "◆ %s" % GameState.RESOURCES[resource_id]["name"]
	_marker.visible = true
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(_marker):
			_marker.visible = false)
