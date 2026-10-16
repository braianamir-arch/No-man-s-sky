class_name Ship
extends CharacterBody3D
## Nave estelar: despegue, vuelo atmosferico, motor de pulso en el espacio,
## aterrizaje, laseres para asteroides y salto de curvatura.

enum State { LANDED, TAKEOFF, FLYING, LANDING }

const LOOK_SENS := 0.0025

var system: StarSystem
var state := State.LANDED
var piloted := false
var speed := 0.0
var throttle := 0.35
var pulsing := false
var camera: Camera3D
var _land_target := Transform3D()
var _takeoff_time := 0.0
var _lasers: Array[MeshInstance3D] = []
var _engine_mat: StandardMaterial3D
var _fire_time := 0.0
var _crash_cooldown := 0.0


func _ready() -> void:
	add_to_group("ship")
	_build_visual()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.5, 1.6, 7.0)
	cs.shape = box
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	camera = Camera3D.new()
	camera.top_level = true
	camera.fov = 72.0
	camera.near = 0.2
	camera.far = 40000.0
	add_child(camera)


func _build_visual() -> void:
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.85, 0.85, 0.82)
	hull.metallic = 0.5
	hull.roughness = 0.4
	var accent := StandardMaterial3D.new()
	accent.albedo_color = Color(0.85, 0.3, 0.12)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.2, 0.3)
	glass.metallic = 0.9
	glass.roughness = 0.05
	_engine_mat = StandardMaterial3D.new()
	_engine_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_engine_mat.albedo_color = Color(0.4, 0.8, 1.0)

	var parts := [
		# [mesh, material, posicion, rotacion]
		[_box(Vector3(1.6, 1.1, 6.0)), hull, Vector3(0, 1.1, 0), Vector3.ZERO],
		[_box(Vector3(6.0, 0.18, 2.2)), hull, Vector3(0, 0.95, 0.9), Vector3.ZERO],
		[_box(Vector3(0.2, 1.2, 1.6)), accent, Vector3(0, 2.0, 2.2), Vector3(0.4, 0, 0)],
		[_box(Vector3(0.25, 0.5, 2.0)), accent, Vector3(-3.0, 1.0, 0.9), Vector3.ZERO],
		[_box(Vector3(0.25, 0.5, 2.0)), accent, Vector3(3.0, 1.0, 0.9), Vector3.ZERO],
		[_sphere(0.75, 1.1), glass, Vector3(0, 1.65, -1.2), Vector3.ZERO],
		[_cyl(0.45, 0.55, 1.4), hull, Vector3(-1.1, 1.0, 2.5), Vector3(PI * 0.5, 0, 0)],
		[_cyl(0.45, 0.55, 1.4), hull, Vector3(1.1, 1.0, 2.5), Vector3(PI * 0.5, 0, 0)],
		[_cyl(0.35, 0.35, 0.1), _engine_mat, Vector3(-1.1, 1.0, 3.22), Vector3(PI * 0.5, 0, 0)],
		[_cyl(0.35, 0.35, 0.1), _engine_mat, Vector3(1.1, 1.0, 3.22), Vector3(PI * 0.5, 0, 0)],
		[_cyl(0.08, 0.12, 1.0), accent, Vector3(-1.2, 0.35, -1.5), Vector3.ZERO],
		[_cyl(0.08, 0.12, 1.0), accent, Vector3(1.2, 0.35, -1.5), Vector3.ZERO],
		[_cyl(0.08, 0.12, 1.0), accent, Vector3(0, 0.35, 2.0), Vector3.ZERO],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.material_override = p[1]
		mi.position = p[2]
		mi.rotation = p[3]
		add_child(mi)
	var laser_mat := StandardMaterial3D.new()
	laser_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	laser_mat.albedo_color = Color(1.0, 0.35, 0.2)
	for x in [-2.9, 2.9]:
		var l := MeshInstance3D.new()
		l.mesh = _box(Vector3(0.1, 0.1, 1.0))
		l.material_override = laser_mat
		l.top_level = true
		l.visible = false
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		l.set_meta("offset", Vector3(x, 1.0, -0.5))
		add_child(l)
		_lasers.append(l)


func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m


func _sphere(r: float, h: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 6
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 10
	return m


func enter() -> void:
	piloted = true
	camera.make_current()
	_snap_camera()


func exit_ship() -> void:
	piloted = false
	for l in _lasers:
		l.visible = false


func is_landed() -> bool:
	return state == State.LANDED


func planet_up(p: Planet) -> Vector3:
	return (global_position - p.global_position).normalized()


func altitude() -> float:
	var p := system.get_dominant_planet(global_position) if system else null
	return p.altitude_of(global_position) if p else INF


func can_land() -> bool:
	return state == State.FLYING and altitude() < 90.0


func can_warp() -> bool:
	return state == State.FLYING and system.get_dominant_planet(global_position) == null and int(GameState.stats["celdas"]) > 0


func request_takeoff() -> void:
	if state != State.LANDED:
		return
	if float(GameState.stats["despegue"]) < 20.0:
		GameState.notify.emit("Propulsor de despegue sin combustible (usa Di-hidrógeno)")
		return
	GameState.stats["despegue"] = float(GameState.stats["despegue"]) - 20.0
	state = State.TAKEOFF
	_takeoff_time = 0.0
	speed = 0.0


func request_landing() -> void:
	if not can_land():
		return
	var p := system.get_dominant_planet(global_position)
	var up := planet_up(p)
	var from := global_position
	var to := p.global_position + up * (p.radius - p.amplitude * 2.0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground: Vector3 = hit["position"] if hit else p.global_position + up * (p.radius + p.sample_height(up))
	if p.has_water:
		var water_r := p.radius + p.sea_level
		if ground.distance_to(p.global_position) < water_r:
			GameState.notify.emit("No se puede aterrizar en el agua")
			return
	var fwd := -global_transform.basis.z
	fwd = (fwd - up * fwd.dot(up)).normalized()
	_land_target = Transform3D(Basis.looking_at(fwd, up), ground + up * 0.25)
	state = State.LANDING


func _physics_process(delta: float) -> void:
	if system == null:
		return
	_crash_cooldown = maxf(_crash_cooldown - delta, 0.0)
	match state:
		State.LANDED:
			speed = 0.0
			_engine_mat.albedo_color = Color(0.15, 0.25, 0.35)
		State.TAKEOFF:
			_takeoff_time += delta
			var p := system.get_dominant_planet(global_position)
			var up := planet_up(p) if p else global_transform.basis.y
			global_position += up * 14.0 * delta
			if _takeoff_time > 1.0:
				# Inclinar el morro suavemente hacia adelante/arriba.
				global_transform.basis = global_transform.basis.slerp(
					global_transform.basis.rotated(global_transform.basis.x.normalized(), 0.35), delta).orthonormalized()
			_engine_mat.albedo_color = Color(0.5, 0.9, 1.0)
			if _takeoff_time > 2.2:
				state = State.FLYING
				speed = 35.0
				throttle = 0.4
		State.LANDING:
			global_transform = global_transform.interpolate_with(_land_target, clampf(2.0 * delta, 0.0, 1.0))
			if global_position.distance_to(_land_target.origin) < 0.3:
				global_transform = _land_target
				state = State.LANDED
				GameState.notify.emit("Aterrizaje completado")
		State.FLYING:
			_fly(delta)
	if piloted:
		_update_weapons(delta)
		_update_camera(delta)


func _fly(delta: float) -> void:
	var b := global_transform.basis
	var look := TouchInput.consume_look() if piloted else Vector2.ZERO
	var steer := TouchInput.move_vector if piloted else Vector2.ZERO
	var yaw := -steer.x * 1.3 * delta - look.x * LOOK_SENS
	var pitch := steer.y * 1.1 * delta - look.y * LOOK_SENS
	var roll := Input.get_axis("roll_left", "roll_right") * 1.8 * delta if piloted else 0.0
	b = b.rotated(b.y.normalized(), yaw)
	b = b.rotated(b.x.normalized(), pitch)
	b = b.rotated(b.z.normalized(), -roll)
	var p := system.get_dominant_planet(global_position)
	if p and absf(roll) < 0.0001:
		# Autonivelado respecto al horizonte del planeta.
		var up := planet_up(p)
		var target_x := up.cross(b.z)
		if target_x.length_squared() > 0.01:
			var err := b.x.signed_angle_to(target_x.normalized(), b.z)
			b = b.rotated(b.z.normalized(), err * clampf(1.5 * delta, 0.0, 1.0))
	b = b.orthonormalized()

	var level := 1.0 + 0.3 * int(GameState.upgrades["nave"])
	if piloted:
		throttle = clampf(throttle + Input.get_axis("throttle_down", "throttle_up") * 0.7 * delta, 0.0, 1.0)
	var target := lerpf(12.0, 110.0 * level, throttle)
	pulsing = false
	if piloted and Input.is_action_pressed("boost"):
		var space := p == null or p.altitude_of(global_position) > p.radius * 0.7
		if space and float(GameState.stats["pulso"]) > 0.0:
			pulsing = true
			target = 1100.0 * level
			GameState.stats["pulso"] = maxf(float(GameState.stats["pulso"]) - 2.0 * delta, 0.0)
		else:
			target *= 1.8
	var accel := 400.0 if pulsing else 60.0
	if not pulsing and speed > target:
		accel = 900.0
	speed = move_toward(speed, target, accel * delta)
	global_transform.basis = b
	var motion := -b.z * speed * delta
	var col := move_and_collide(motion)
	if col:
		var normal := col.get_normal()
		global_position += normal * 0.5
		if _crash_cooldown <= 0.0:
			_crash_cooldown = 1.0
			var dmg := clampf(speed * 0.4, 5.0, 60.0)
			GameState.stats["escudo"] = maxf(float(GameState.stats["escudo"]) - dmg, 0.0)
			GameState.notify.emit("¡Impacto! Escudo -%d" % int(dmg))
		speed *= 0.2
	_engine_mat.albedo_color = Color(0.4, 0.8, 1.0).lerp(Color(1.0, 0.9, 0.6), 1.0 if pulsing else throttle * 0.5)


func _update_weapons(delta: float) -> void:
	var firing := state == State.FLYING and Input.is_action_pressed("mine")
	_fire_time += delta
	for l in _lasers:
		l.visible = false
	if not firing:
		return
	var b := global_transform.basis
	var from := global_position + b.y * 1.0
	var to := from - b.z * 600.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end_point := to
	if hit:
		end_point = hit["position"]
		var target: Object = hit["collider"]
		if target is ResourceNode:
			var rn := target as ResourceNode
			var id := rn.resource_id
			var got := rn.mine(14.0 * delta)
			if got > 0:
				GameState.add_resource(id, got)
	var flicker := fmod(_fire_time * 14.0, 1.0) < 0.7
	for l in _lasers:
		var start := global_transform * (l.get_meta("offset") as Vector3)
		var beam_len := start.distance_to(end_point)
		l.global_transform = Transform3D(Basis.looking_at(end_point - start, b.y), (start + end_point) * 0.5)
		l.scale = Vector3(1, 1, beam_len)
		l.visible = flicker


func _snap_camera() -> void:
	camera.global_transform = _camera_target()


func _camera_target() -> Transform3D:
	var b := global_transform.basis
	var dist := 14.0 + (10.0 if pulsing else 0.0)
	var pos := global_position + b.y * 4.0 + b.z * dist
	var look_at_point := global_position - b.z * 25.0
	return Transform3D(Basis.looking_at(look_at_point - pos, b.y), pos)


func _update_camera(delta: float) -> void:
	var t := _camera_target()
	var k := clampf(8.0 * delta, 0.0, 1.0)
	# La posicion sigue rigida (a velocidad de pulso un lerp quedaria muy atras);
	# solo se suaviza la rotacion.
	camera.global_transform = Transform3D(camera.global_transform.basis.slerp(t.basis, k).orthonormalized(), t.origin)
	camera.fov = lerpf(camera.fov, 90.0 if pulsing else 72.0, 3.0 * delta)


## Posiciona la nave aterrizada sobre un planeta en una direccion local.
func place_landed(p: Planet, dir: Vector3) -> void:
	var pos := p.global_position + dir * (p.radius + p.sample_height(dir) + 0.25)
	var fwd := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	global_transform = Transform3D(Basis.looking_at(fwd, dir), pos)
	state = State.LANDED
	speed = 0.0


func place_in_space(pos: Vector3, look_target: Vector3) -> void:
	var fwd := (look_target - pos).normalized()
	var ref := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
	global_transform = Transform3D(Basis.looking_at(fwd, ref), pos)
	state = State.FLYING
	speed = 80.0
	throttle = 0.6
	_snap_camera()
