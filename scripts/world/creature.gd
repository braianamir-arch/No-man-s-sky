class_name Creature
extends Node3D
## Fauna procedural: cuerpo armado con primitivas, deambula sobre la superficie.

var planet: Planet
var species: Dictionary
var dir := Vector3.UP
var heading := Vector3.FORWARD
var moving := false
var _timer := 0.0
var _t := 0.0
var _legs: Array[Node3D] = []
var _hover := 0.0
var _size := 1.0


static func create(p: Planet, sp: Dictionary, start_dir: Vector3) -> Creature:
	var c := Creature.new()
	c.planet = p
	c.species = sp
	c.dir = start_dir
	c.add_to_group("creature")
	c._build()
	c._pick_heading()
	c.position = p.surface_point(start_dir)
	return c


func _build() -> void:
	_size = float(species["size"]) * randf_range(0.85, 1.15)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = species["color"]
	body_mat.roughness = 0.7
	var acc_mat := StandardMaterial3D.new()
	acc_mat.albedo_color = species["color2"]
	var legs: int = species["legs"]
	var length: float = species["long"]
	var leg_h := 0.0 if legs == 0 else 0.9
	_hover = 1.2 if legs == 0 else 0.0
	var root := Node3D.new()
	root.scale = Vector3.ONE * _size
	add_child(root)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.45
	cap.height = 0.9 + length * 0.6
	cap.radial_segments = 10
	cap.rings = 3
	body.mesh = cap
	body.material_override = body_mat
	body.rotation.x = PI * 0.5
	body.position = Vector3(0, leg_h + 0.45, 0)
	root.add_child(body)
	var neck: float = species["neck"]
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.32
	hs.height = 0.6
	hs.radial_segments = 8
	hs.rings = 4
	head.mesh = hs
	head.material_override = acc_mat
	head.position = Vector3(0, leg_h + 0.6 + neck * 0.9, -(cap.height * 0.5 + 0.1))
	root.add_child(head)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.07
		es.height = 0.14
		eye.mesh = es
		var em := StandardMaterial3D.new()
		em.albedo_color = Color.BLACK
		eye.material_override = em
		eye.position = head.position + Vector3(0.15 * side, 0.08, -0.25)
		root.add_child(eye)
	if legs > 0:
		var pairs := legs / 2
		for i in pairs:
			var z := lerpf(-cap.height * 0.3, cap.height * 0.3, 0.5 if pairs == 1 else float(i) / (pairs - 1))
			for side in [-1.0, 1.0]:
				var pivot := Node3D.new()
				pivot.position = Vector3(0.3 * side, leg_h, z)
				var leg := MeshInstance3D.new()
				var lm := CylinderMesh.new()
				lm.top_radius = 0.1
				lm.bottom_radius = 0.07
				lm.height = leg_h
				lm.radial_segments = 5
				leg.mesh = lm
				leg.material_override = acc_mat
				leg.position = Vector3(0, -leg_h * 0.5, 0)
				pivot.add_child(leg)
				root.add_child(pivot)
				_legs.append(pivot)


func _pick_heading() -> void:
	var ref := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var t1 := dir.cross(ref).normalized()
	var t2 := dir.cross(t1)
	var a := randf() * TAU
	heading = t1 * cos(a) + t2 * sin(a)
	moving = randf() < 0.65
	_timer = randf_range(2.0, 6.0)


func _process(delta: float) -> void:
	if planet == null:
		return
	_t += delta
	_timer -= delta
	if _timer <= 0.0:
		_pick_heading()
	var speed: float = species["speed"]
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.visible and player.global_position.distance_to(global_position) < 9.0 + _size * 3.0:
		var away := global_position - player.global_position
		heading = (away - dir * away.dot(dir)).normalized()
		moving = true
		speed *= 2.2
		_timer = 1.5
	if moving:
		var next := (dir + heading * speed * delta / planet.radius).normalized()
		if planet.has_water and planet.sample_height(next) < planet.sea_level + 0.3:
			heading = -heading
		else:
			dir = next
		heading = (heading - dir * heading.dot(dir)).normalized()
	var h := planet.sample_height(dir)
	var bob := sin(_t * 2.0) * 0.3 if _hover > 0.0 else 0.0
	position = dir * (planet.radius + h + _hover + bob - 0.1)
	transform.basis = Basis.looking_at(heading, dir)
	var swing := sin(_t * speed * 3.0) * 0.6 if moving else 0.0
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 2 == 0 else -1.0)
