extends Node3D
## Bucle principal: genera el sistema, alterna entre explorador y nave,
## actualiza cielo/niebla/luz segun la altitud y gestiona los saltos.

var system: StarSystem
var player: Player
var ship: Ship
var hud: HUD
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var mode := "foot"
var _busy := true


func _ready() -> void:
	GameState.load_game()
	_setup_world()
	hud = HUD.new()
	add_child(hud)
	player = Player.new()
	add_child(player)
	ship = Ship.new()
	add_child(ship)
	await _load_system(true)


func _setup_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.2, 0.22, 0.3)
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_density = 0.0
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.light_energy = 1.25
	add_child(sun)


func _load_system(landed: bool) -> void:
	_busy = true
	hud.show_loading(true, "Generando sistema estelar...")
	player.set_active(false)
	ship.exit_ship()
	await get_tree().process_frame
	if system:
		system.queue_free()
		system = null
		await get_tree().process_frame
	system = StarSystem.new()
	add_child(system)
	player.system = system
	ship.system = system
	await system.generate(GameState.universe_seed, hud.set_loading_progress)

	sun.light_color = system.star_color
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.universe_seed
	sky_mat.set_shader_parameter("seed", float(GameState.universe_seed % 997))
	sky_mat.set_shader_parameter("nebula_color", Color.from_hsv(rng.randf(), 0.7, 0.6))

	var p0: Planet = system.planets[0]
	if landed:
		ship.place_landed(p0, _find_landing_dir(p0, rng))
		player.place_on_surface(ship.global_position + ship.global_transform.basis.x * 7.0, p0)
		player.set_active(true)
		_set_mode("foot")
		system.viewer = player
	else:
		var from_dir := (p0.position.normalized() * -1.0 + Vector3.UP * 0.3).normalized()
		ship.place_in_space(p0.global_position + from_dir * p0.radius * 4.5, p0.global_position)
		ship.enter()
		_set_mode("ship")
		system.viewer = ship
	hud.show_loading(false)
	GameState.notify.emit("Sistema %s · %d planetas" % [system.system_name, system.planets.size()])
	_busy = false


func _find_landing_dir(p: Planet, rng: RandomNumberGenerator) -> Vector3:
	# Empezamos del lado diurno del planeta (la estrella esta en el origen).
	var sun_dir := -p.position.normalized()
	var best := sun_dir
	for i in 120:
		var d := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if d.dot(sun_dir) < 0.55:
			continue
		var h := p.sample_height(d)
		if p.has_water and h < p.sea_level + 2.0:
			continue
		# Terreno razonablemente plano.
		var ref := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
		var t := d.cross(ref).normalized() * (6.0 / p.radius)
		if absf(p.sample_height((d + t).normalized()) - h) < 1.5 and absf(p.sample_height((d - t).normalized()) - h) < 1.5:
			return d
		best = d
	return best


func _set_mode(m: String) -> void:
	mode = m
	hud.set_mode(m)
	hud.set_prompt("")
	hud.set_speed("")


func _unhandled_input(event: InputEvent) -> void:
	if OS.has_feature("mobile"):
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		TouchInput.add_look((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _busy or system == null:
		return
	hud.update_stats()
	_update_environment(delta)
	if mode == "foot":
		_foot_logic()
	else:
		_ship_logic()
	if float(GameState.stats["salud"]) <= 0.0:
		_respawn()


func _foot_logic() -> void:
	var near_ship := ship.is_landed() and player.global_position.distance_to(ship.global_position) < 9.0
	if near_ship:
		hud.set_prompt("USAR (E): subir a la nave")
	elif player.overheated:
		hud.set_prompt("Multiherramienta sobrecalentada...")
	else:
		hud.set_prompt("")
	if near_ship and Input.is_action_just_pressed("interact"):
		_enter_ship()
		return
	var p := player.planet
	if p:
		hud.set_location("%s  ·  %s\nPeligro: %s  ·  Gravedad %.1f" % [p.planet_name, p.biome["label"], p.biome["hazard_name"], p.gravity])
		GameState.discover("planeta_%d" % p.planet_seed, "Planeta %s" % p.planet_name, 150)


func _ship_logic() -> void:
	var p := system.get_dominant_planet(ship.global_position)
	match ship.state:
		Ship.State.LANDED:
			hud.touch.set_label("throttle_up", "DESPEGAR")
			hud.touch.set_label("interact", "SALIR")
			hud.set_prompt("ACEL. (W): despegar  ·  USAR (E): salir")
			if Input.is_action_just_pressed("interact"):
				_exit_ship()
				return
			if Input.is_action_just_pressed("throttle_up"):
				ship.request_takeoff()
		Ship.State.FLYING:
			hud.touch.set_label("throttle_up", "ACEL.")
			hud.touch.set_label("interact", "ATERRIZAR")
			if ship.can_land():
				hud.set_prompt("USAR (E): aterrizar")
			elif ship.can_warp():
				hud.set_prompt("SALTO CURV. (J): viajar a otro sistema")
			elif p == null:
				hud.set_prompt("Mantén PULSO (Shift) para viajar rápido")
			else:
				hud.set_prompt("")
			if Input.is_action_just_pressed("interact"):
				if ship.can_land():
					ship.request_landing()
				else:
					GameState.notify.emit("Acércate más a la superficie para aterrizar")
			if Input.is_action_just_pressed("warp"):
				if ship.can_warp():
					_warp()
					return
				elif int(GameState.stats["celdas"]) <= 0:
					GameState.notify.emit("Necesitas una célula de curvatura (menú)")
				else:
					GameState.notify.emit("Aléjate de los planetas para saltar")
		_:
			hud.set_prompt("")
	hud.set_speed("%d u/s%s" % [int(ship.speed), "   » PULSO »" if ship.pulsing else ""])
	if p:
		hud.set_location("%s  ·  %s\nAltitud %d" % [p.planet_name, p.biome["label"], int(p.altitude_of(ship.global_position))])
	else:
		var n := system.nearest_planet(ship.global_position)
		var d := int(ship.global_position.distance_to(n.global_position) - n.radius) if n else 0
		hud.set_location("Espacio  ·  Sistema %s\n%s a %d u" % [system.system_name, n.planet_name if n else "", d])


func _enter_ship() -> void:
	player.set_active(false)
	ship.enter()
	system.viewer = ship
	_set_mode("ship")


func _exit_ship() -> void:
	var p := system.get_dominant_planet(ship.global_position)
	if p == null:
		return
	ship.exit_ship()
	player.place_on_surface(ship.global_position + ship.global_transform.basis.x * 6.0, p)
	player.set_active(true)
	system.viewer = player
	_set_mode("foot")


func _warp() -> void:
	GameState.stats["celdas"] = int(GameState.stats["celdas"]) - 1
	GameState.systems_visited += 1
	GameState.universe_seed = hash([GameState.universe_seed, "curvatura", GameState.systems_visited]) & 0x7fffffff
	await _load_system(false)
	GameState.save_game()


func _respawn() -> void:
	var st := GameState.stats
	st["salud"] = 100.0
	st["soporte"] = maxf(float(st["soporte"]), 60.0)
	st["peligro"] = maxf(float(st["peligro"]), 60.0)
	for id in GameState.inventory:
		GameState.inventory[id] = int(GameState.inventory[id] * 0.6)
	GameState.inventory_changed.emit()
	GameState.notify.emit("Has muerto. Perdiste parte del inventario.")
	var p := system.get_dominant_planet(ship.global_position)
	if mode == "foot" and p:
		player.place_on_surface(ship.global_position + ship.global_transform.basis.x * 6.0, p)


func _update_environment(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pos := cam.global_position
	var p := system.nearest_planet(pos)
	var atmo := 0.0
	var up := Vector3.UP
	var light_dir := pos.normalized()
	if p:
		var alt := pos.distance_to(p.global_position) - p.radius
		atmo = clampf(1.0 - (alt - p.amplitude) / (p.radius * 0.3), 0.0, 1.0)
		up = (pos - p.global_position).normalized()
		if alt < p.radius * 1.5:
			light_dir = p.global_position.normalized()
		sky_mat.set_shader_parameter("atmo_color", p.atmo_color)
		var day := clampf(up.dot(-light_dir) * 2.0 + 0.3, 0.04, 1.0)
		env.fog_density = lerpf(env.fog_density, p.fog_density * atmo, clampf(delta * 3.0, 0.0, 1.0))
		env.fog_light_color = p.atmo_color * day
		env.ambient_light_color = Color(0.12, 0.13, 0.2).lerp(p.atmo_color * (0.4 + 0.4 * day), atmo)
	sky_mat.set_shader_parameter("atmo_density", atmo)
	sky_mat.set_shader_parameter("up_dir", up)
	if light_dir.length_squared() > 0.001:
		var ref := Vector3.UP if absf(light_dir.y) < 0.95 else Vector3.RIGHT
		sun.global_transform.basis = Basis.looking_at(light_dir, ref)
