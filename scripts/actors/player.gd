class_name Player
extends CharacterBody3D
## Explorador en primera persona: gravedad radial, jetpack, multiherramienta
## para minar, escaner y soporte vital.

const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.0
const JUMP_SPEED := 6.5
const LOOK_SENS := 0.0035
const MINE_RANGE := 30.0

var system: StarSystem
var planet: Planet
var active := true
var camera: Camera3D
var head: Node3D
var _pitch := 0.0
var _laser: MeshInstance3D
var _laser_mat: StandardMaterial3D
var heat := 0.0
var overheated := false
var _hazard_timer := 0.0
var _jump_held_time := 0.0
var _scan_cooldown := 0.0


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs)
	head = Node3D.new()
	head.position = Vector3(0, 1.65, 0)
	add_child(head)
	camera = Camera3D.new()
	camera.fov = 75.0
	camera.near = 0.1
	camera.far = 40000.0
	head.add_child(camera)
	_build_multitool()


func _build_multitool() -> void:
	var tool_root := Node3D.new()
	tool_root.position = Vector3(0.28, -0.25, -0.5)
	camera.add_child(tool_root)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.1, 0.35)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.5, 0.15)
	mat.metallic = 0.6
	body.material_override = mat
	tool_root.add_child(body)
	var tip := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.025
	tm.bottom_radius = 0.035
	tm.height = 0.12
	tip.mesh = tm
	tip.rotation.x = PI * 0.5
	tip.position = Vector3(0, 0.01, -0.22)
	var tip_mat := StandardMaterial3D.new()
	tip_mat.albedo_color = Color(0.2, 0.9, 1.0)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(0.2, 0.9, 1.0)
	tip.material_override = tip_mat
	tool_root.add_child(tip)
	_laser = MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.03, 0.03, 1.0)
	_laser.mesh = lm
	_laser_mat = StandardMaterial3D.new()
	_laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_laser_mat.albedo_color = Color(0.3, 1.0, 1.0)
	_laser.material_override = _laser_mat
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.visible = false
	_laser.top_level = true
	tool_root.add_child(_laser)
	_laser.set_meta("muzzle", tip)


func set_active(on: bool) -> void:
	active = on
	visible = on
	set_physics_process(on)
	for c in get_children():
		if c is CollisionShape3D:
			c.disabled = not on
	if on:
		camera.make_current()
	else:
		_laser.visible = false


func get_up() -> Vector3:
	if planet:
		return (global_position - planet.global_position).normalized()
	return global_transform.basis.y


func _physics_process(delta: float) -> void:
	if not active or system == null:
		return
	planet = system.get_dominant_planet(global_position)
	var up := get_up()
	var g := planet.gravity if planet else 0.0

	# Orientacion: alinear el cuerpo con la normal del planeta y aplicar mirada.
	var look := TouchInput.consume_look()
	var fwd := -global_transform.basis.z
	fwd = fwd - up * fwd.dot(up)
	if fwd.length_squared() < 0.0001:
		fwd = global_transform.basis.y.cross(up)
	fwd = fwd.normalized().rotated(up, -look.x * LOOK_SENS)
	global_transform.basis = Basis.looking_at(fwd, up)
	_pitch = clampf(_pitch - look.y * LOOK_SENS, -1.45, 1.45)
	head.rotation.x = _pitch
	up_direction = up

	var input := TouchInput.get_move()
	var right := fwd.cross(up)
	var sprint := Input.is_action_pressed("boost") or TouchInput.move_vector.length() > 0.97
	var speed := SPRINT_SPEED if sprint else WALK_SPEED
	var wish := (fwd * input.y + right * input.x) * speed
	var vs := velocity.dot(up)
	var horiz := velocity - up * vs
	var on_floor := is_on_floor()
	horiz = horiz.lerp(wish, clampf((10.0 if on_floor else 2.5) * delta, 0.0, 1.0))

	var in_water := planet != null and planet.has_water and \
		global_position.distance_to(planet.global_position) < planet.radius + planet.sea_level - 0.9
	if in_water:
		vs = lerpf(vs, -1.0, 2.0 * delta)
		if Input.is_action_pressed("jump"):
			vs = lerpf(vs, 4.0, 4.0 * delta)
	else:
		vs -= g * delta
		var jet_level := 1.0 + 0.35 * int(GameState.upgrades["jetpack"])
		if Input.is_action_just_pressed("jump") and on_floor:
			vs = JUMP_SPEED
			_jump_held_time = 0.0
		elif Input.is_action_pressed("jump") and not on_floor:
			_jump_held_time += delta
			var fuel: float = GameState.stats["jetpack"]
			if _jump_held_time > 0.12 and fuel > 0.0:
				vs = minf(vs + (g + 14.0 * jet_level) * delta, 9.0 * jet_level)
				horiz += fwd * 4.0 * delta * jet_level
				GameState.stats["jetpack"] = maxf(fuel - 28.0 * delta / jet_level, 0.0)
	if on_floor:
		GameState.stats["jetpack"] = minf(float(GameState.stats["jetpack"]) + 35.0 * delta, 100.0)
	velocity = horiz + up * vs
	move_and_slide()

	_update_mining(delta)
	_update_life_support(delta, in_water)
	_scan_cooldown = maxf(_scan_cooldown - delta, 0.0)
	if Input.is_action_just_pressed("scan"):
		scan()


func _update_mining(delta: float) -> void:
	if overheated:
		heat = maxf(heat - 45.0 * delta, 0.0)
		if heat <= 0.0:
			overheated = false
	if not Input.is_action_pressed("mine") or overheated:
		_laser.visible = false
		if not overheated:
			heat = maxf(heat - 30.0 * delta, 0.0)
		return
	heat += 22.0 * delta
	if heat >= 100.0:
		overheated = true
		GameState.notify.emit("¡Multiherramienta sobrecalentada!")
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * MINE_RANGE
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end_point := to
	if hit:
		end_point = hit["position"]
		var col: Object = hit["collider"]
		if col is ResourceNode:
			var rn := col as ResourceNode
			var id := rn.resource_id
			var got := rn.mine(18.0 * delta)
			if got > 0:
				GameState.add_resource(id, got)
	var muzzle: Node3D = _laser.get_meta("muzzle")
	var start := muzzle.global_position
	var length := start.distance_to(end_point)
	_laser.visible = true
	_laser.global_transform = Transform3D(Basis.looking_at(end_point - start, camera.global_transform.basis.y), (start + end_point) * 0.5)
	_laser.scale = Vector3(1, 1, length)
	_laser_mat.albedo_color = Color(0.3, 1.0, 1.0).lerp(Color(1.0, 0.3, 0.1), heat / 100.0)


func _update_life_support(delta: float, in_water: bool) -> void:
	var st := GameState.stats
	st["soporte"] = maxf(float(st["soporte"]) - 0.3 * delta, 0.0)
	var hz := planet.hazard if planet else 0.0
	if in_water:
		hz += 0.5
	if hz > 0.2:
		st["peligro"] = maxf(float(st["peligro"]) - hz * 0.55 * delta, 0.0)
	var damage := 0.0
	if float(st["soporte"]) <= 0.0:
		damage += 4.0
	if float(st["peligro"]) <= 0.0 and hz > 0.2:
		damage += 3.0 * hz
	if damage > 0.0:
		st["salud"] = maxf(float(st["salud"]) - damage * delta, 0.0)
		_hazard_timer -= delta
		if _hazard_timer <= 0.0:
			_hazard_timer = 6.0
			GameState.notify.emit("¡Peligro! Recarga el exotraje desde el menú")
	elif float(st["salud"]) < 100.0:
		st["salud"] = minf(float(st["salud"]) + 1.5 * delta, 100.0)


func scan() -> void:
	if _scan_cooldown > 0.0:
		return
	_scan_cooldown = 4.0
	var count := 0
	for n in get_tree().get_nodes_in_group("minable"):
		var rn := n as ResourceNode
		if rn and not rn.is_in_group("asteroid") and rn.global_position.distance_to(global_position) < 110.0:
			rn.show_marker(10.0)
			count += 1
	var msg := "Escáner: %d depósitos cerca" % count
	if planet:
		var c := planet.nearest_creature(global_position, 30.0)
		if c:
			var sp := c.species
			GameState.discover("fauna_%d_%d" % [planet.planet_seed, sp["index"]], "Especie %s" % sp["name"], 250)
	GameState.notify.emit(msg)


## Coloca al jugador de pie sobre la superficie cerca de una posicion global.
func place_on_surface(world_pos: Vector3, p: Planet) -> void:
	planet = p
	var dir := (world_pos - p.global_position).normalized()
	var pos := p.global_position + dir * (p.radius + p.sample_height(dir) + 1.5)
	var fwd := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	global_transform = Transform3D(Basis.looking_at(fwd, dir), pos)
	velocity = Vector3.ZERO
	_pitch = 0.0
