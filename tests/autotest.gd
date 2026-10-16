extends Node
## Prueba automatica de humo: carga el juego, camina, mina, vuela, aterriza y salta.
## Uso: godot --path . res://tests/autotest.tscn   (agrega --headless si no hay pantalla)

var main: Node
var frame := 0
var step := 0
var wait := 0
var shots_dir := OS.get_environment("SHOTS_DIR")
var _inv_before := 0
var _errors := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.testing = true
	var env_seed := OS.get_environment("TEST_SEED")
	if env_seed != "":
		GameState.universe_seed = int(env_seed)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func _shot(name: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
	print("  captura: ", name)


func _check(cond: bool, msg: String) -> void:
	print(("  OK   " if cond else "  FALLO ") + msg)
	if not cond:
		_errors += 1


func _process(_delta: float) -> void:
	frame += 1
	if wait > 0:
		wait -= 1
		return
	if main._busy:
		if Time.get_ticks_msec() > 180000:
			print("FALLO: el sistema no termino de generarse")
			get_tree().quit(1)
		return
	var player: Player = main.player
	var ship: Ship = main.ship
	var system: StarSystem = main.system
	match step:
		0:
			main.hud.touch.visible = true
			print("Sistema: ", system.system_name, " planetas: ", system.planets.size())
			for p in system.planets:
				print("  - ", p.planet_name, " (", p.biome_id, ") r=", int(p.radius), " agua=", p.has_water)
			wait = 90
		1:
			var p := player.planet
			_check(p != null, "jugador dentro de la influencia de un planeta")
			_check(player.is_on_floor(), "jugador apoyado en el suelo")
			_check(absf(p.altitude_of(player.global_position)) < 3.0, "altitud del jugador ~0 (%.2f)" % p.altitude_of(player.global_position))
			_check(p.populated, "detalle del planeta poblado")
			print("  recursos en superficie: ", get_tree().get_nodes_in_group("minable").size() - get_tree().get_nodes_in_group("asteroid").size(), "  criaturas: ", get_tree().get_nodes_in_group("creature").size())
			_shot("01_a_pie")
			# Caminar hacia adelante 2 segundos
			TouchInput.move_vector = Vector2(0, 1)
			wait = 120
		2:
			TouchInput.move_vector = Vector2.ZERO
			_check(player.is_on_floor(), "sigue en el suelo tras caminar")
			print("  criaturas tras 2 s: ", get_tree().get_nodes_in_group("creature").size(), " lista=", player.planet._creatures.size(), " fauna=", player.planet.fauna_density, " especies=", player.planet.species.size())
			# Apuntar a un deposito cercano y minar
			var best: ResourceNode = null
			var bd := INF
			for n in get_tree().get_nodes_in_group("minable"):
				var rn := n as ResourceNode
				if rn.is_in_group("asteroid"):
					continue
				var d := rn.global_position.distance_to(player.global_position)
				if d < bd:
					bd = d
					best = rn
			_check(best != null, "hay un deposito minable cerca")
			if best:
				var up := player.get_up()
				var dir_to := best.global_position - up * 0.0 - best.global_transform.basis.y * -1.0
				var target := best.global_position + best.global_transform.basis.y * 1.0
				player.place_on_surface(target - (target - player.global_position).normalized() * 3.5, player.planet)
				wait = 10
				_inv_before = int(GameState.inventory[best.resource_id])
				player.set_meta("target", best)
				player.set_meta("target_id", best.resource_id)
		3:
			var best: ResourceNode = player.get_meta("target")
			if is_instance_valid(best):
				var target := best.global_position + best.global_transform.basis.y * 1.2
				var cam_pos := player.camera.global_position
				var up := player.get_up()
				var flat := (target - cam_pos) - up * (target - cam_pos).dot(up)
				player.global_transform.basis = Basis.looking_at(flat.normalized(), up)
				var to := (target - cam_pos).normalized()
				player._pitch = asin(clampf(to.dot(up), -1, 1))
				player.head.rotation.x = player._pitch
			Input.action_press("mine")
			var from := player.camera.global_position
			var q := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_transform.basis.z * 30.0)
			q.exclude = [player.get_rid()]
			var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
			print("  rayo de minado golpea: ", hit.get("collider"), " objetivo: ", best)
			wait = 90
		4:
			Input.action_release("mine")
			var id: String = player.get_meta("target_id")
			print("  %s: %d -> %d" % [id, _inv_before, GameState.inventory[id]])
			_check(int(GameState.inventory[id]) > _inv_before, "minar suma recursos")
			_shot("02_minando")
			player.scan()
			# Ir a la nave
			player.place_on_surface(ship.global_position + ship.global_transform.basis.x * 5.0, ship.system.get_dominant_planet(ship.global_position))
			wait = 10
		5:
			Input.action_press("interact")
			wait = 2
		6:
			Input.action_release("interact")
			wait = 5
		7:
			_check(main.mode == "ship", "subir a la nave")
			_shot("03_nave_aterrizada")
			Input.action_press("throttle_up")
			wait = 3
		8:
			Input.action_release("throttle_up")
			wait = 150
		9:
			_check(ship.state == Ship.State.FLYING, "despegue completado (estado %d)" % ship.state)
			var p := system.get_dominant_planet(ship.global_position)
			print("  altitud tras despegar: %.1f" % p.altitude_of(ship.global_position))
			# Subir: morro arriba y acelerar
			TouchInput.move_vector = Vector2(0, 1)
			Input.action_press("throttle_up")
			wait = 80
		10:
			TouchInput.move_vector = Vector2.ZERO
			wait = 200
		11:
			Input.action_release("throttle_up")
			var p := system.get_dominant_planet(ship.global_position)
			var alt := p.altitude_of(ship.global_position) if p else INF
			print("  altitud: %.1f  velocidad: %.1f  escudo: %.0f" % [alt, ship.speed, GameState.stats["escudo"]])
			_check(alt > 30.0, "la nave gana altitud")
			_shot("04_volando")
			# Salir al espacio: pulso
			Input.action_press("boost")
			wait = 360
		12:
			var p := system.get_dominant_planet(ship.global_position)
			var n := system.nearest_planet(ship.global_position)
			print("  distancia al planeta mas cercano: %.0f  velocidad %.0f  pulso=%s" % [ship.global_position.distance_to(n.global_position) - n.radius, ship.speed, ship.pulsing])
			Input.action_release("boost")
			_check(p == null or p.altitude_of(ship.global_position) > 200.0, "alcanza el espacio")
			# Mirar al planeta de origen para la captura
			var p0: Planet = system.planets[0]
			ship.global_transform.basis = Basis.looking_at(p0.global_position - ship.global_position, Vector3.UP)
			ship._snap_camera()
			wait = 5
		13:
			_shot("05_espacio")
			# Aterrizaje: llevar la nave sobre el planeta 1 (si existe) a baja altitud
			var p1: Planet = system.planets[1 if system.planets.size() > 1 else 0]
			var dir := Vector3(0.2, 1, 0.1).normalized()
			for i in 40:
				var d := Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1)).normalized()
				if d.dot(-p1.position.normalized()) < 0.5:
					continue
				if not p1.has_water or p1.sample_height(d) > p1.sea_level + 3.0:
					dir = d
					break
			var pos := p1.global_position + dir * (p1.radius + p1.sample_height(dir) + 50.0)
			var fwd := dir.cross(Vector3.UP).normalized()
			ship.global_transform = Transform3D(Basis.looking_at(fwd, dir), pos)
			ship.speed = 20.0
			ship.throttle = 0.0
			wait = 30
		14:
			Input.action_press("interact")
			wait = 2
		15:
			Input.action_release("interact")
			wait = 300
		16:
			_check(ship.state == Ship.State.LANDED, "aterrizaje en otro planeta (estado %d)" % ship.state)
			_shot("06_aterrizado_planeta2")
			Input.action_press("interact")
			wait = 2
		17:
			Input.action_release("interact")
			wait = 60
		18:
			_check(main.mode == "foot", "bajar de la nave")
			var p2 := player.planet
			var swimming := p2.has_water and player.global_position.distance_to(p2.global_position) < p2.radius + p2.sea_level
			_check(player.is_on_floor() or swimming, "explorador en el suelo (o nadando) en el planeta 2")
			_shot("07_planeta2_a_pie")
			# Salto de curvatura
			main._enter_ship()
			ship.place_in_space(Vector3(0, 6000, 0), Vector3.ZERO)
			GameState.stats["celdas"] = 1
			wait = 5
		19:
			var old_seed: int = GameState.universe_seed
			player.set_meta("old_seed", old_seed)
			Input.action_press("warp")
			wait = 2
		20:
			Input.action_release("warp")
			wait = 5
		21:
			_check(int(GameState.universe_seed) != int(player.get_meta("old_seed")), "salto a un nuevo sistema")
			print("  nuevo sistema: ", system.system_name)
			wait = 30
		22:
			_shot("08_nuevo_sistema")
			main.hud.toggle_menu()
			wait = 10
		23:
			_shot("09_menu")
			_check(get_tree().paused, "el menu pausa el juego")
			main.hud.toggle_menu()
			print("Errores: ", _errors)
			get_tree().quit(1 if _errors > 0 else 0)
	step += 1
