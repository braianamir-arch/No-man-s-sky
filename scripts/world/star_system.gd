class_name StarSystem
extends Node3D
## Sistema estelar: una estrella en el origen, varios planetas y campos de asteroides.

const STAR_COLORS := [
	Color(1.0, 0.95, 0.8), Color(1.0, 0.75, 0.45), Color(0.65, 0.8, 1.0),
	Color(1.0, 0.5, 0.35), Color(0.6, 1.0, 0.6),
]

var system_seed := 0
var system_name := ""
var star_color := Color.WHITE
var planets: Array[Planet] = []
## Nodo que el detalle de los planetas sigue (jugador o nave).
var viewer: Node3D


func generate(seed_value: int, progress: Callable) -> void:
	system_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	system_name = NameGen.generate(rng)
	star_color = STAR_COLORS[rng.randi() % STAR_COLORS.size()]
	_build_star()

	var count := rng.randi_range(3, 5)
	var keys := Planet.BIOMES.keys()
	var dist := 3200.0
	for i in count:
		var biome_name: String = keys[rng.randi() % keys.size()]
		if i == 0:
			biome_name = ["exuberante", "exotico", "yermo"][rng.randi() % 3]
		var p := Planet.new()
		p.setup(rng.randi(), rng.randf_range(230.0, 380.0), biome_name)
		var ang := rng.randf() * TAU
		p.position = Vector3(cos(ang) * dist, rng.randf_range(-350.0, 350.0), sin(ang) * dist)
		p.name = "Planeta%d" % i
		dist += rng.randf_range(1700.0, 2500.0)
		add_child(p)
		planets.append(p)

	var t0 := Time.get_ticks_msec()
	var tasks: Array[int] = []
	for p in planets:
		tasks.append(WorkerThreadPool.add_task(p.build_data, true, "planeta"))
	while true:
		var done := 0
		for t in tasks:
			if WorkerThreadPool.is_task_completed(t):
				done += 1
		progress.call(0.85 * done / tasks.size())
		if done == tasks.size():
			break
		await get_tree().process_frame
	for t in tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	for p in planets:
		p.finalize(-p.position.normalized())
		_build_asteroids_around(p, rng)
		await get_tree().process_frame
	_build_belt(rng, dist * 0.55)
	progress.call(1.0)
	print("Sistema %s generado en %d ms" % [system_name, Time.get_ticks_msec() - t0])


func _build_star() -> void:
	var star := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 700.0
	sm.height = 1400.0
	star.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = star_color
	mat.disable_fog = true
	star.material_override = mat
	star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(star)


func _build_asteroids_around(p: Planet, rng: RandomNumberGenerator) -> void:
	for i in 26:
		var dir := Vector3(rng.randfn(), rng.randfn() * 0.25, rng.randfn()).normalized()
		var pos := p.position + dir * p.radius * rng.randf_range(1.7, 2.4)
		_add_asteroid(pos, rng)


func _build_belt(rng: RandomNumberGenerator, belt_radius: float) -> void:
	for i in 90:
		var a := rng.randf() * TAU
		var pos := Vector3(cos(a), 0, sin(a)) * (belt_radius + rng.randf_range(-300.0, 300.0))
		pos.y = rng.randf_range(-150.0, 150.0)
		_add_asteroid(pos, rng)


func _add_asteroid(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var size := rng.randf_range(4.0, 12.0)
	var a := ResourceNode.create("tritio", size, int(size * 5.0), rng, true)
	a.position = pos
	a.add_to_group("asteroid")
	add_child(a)


## Planeta cuya zona de influencia contiene la posicion (o null si en el espacio).
func get_dominant_planet(pos: Vector3) -> Planet:
	var best: Planet = null
	var best_alt := INF
	for p in planets:
		var alt := pos.distance_to(p.global_position) - p.radius
		if alt < p.radius * 1.6 and alt < best_alt:
			best_alt = alt
			best = p
	return best


func nearest_planet(pos: Vector3) -> Planet:
	var best: Planet = null
	var best_d := INF
	for p in planets:
		var d := pos.distance_to(p.global_position) - p.radius
		if d < best_d:
			best_d = d
			best = p
	return best


func _process(delta: float) -> void:
	if viewer == null or not is_instance_valid(viewer):
		return
	var dom := get_dominant_planet(viewer.global_position)
	for p in planets:
		if p == dom:
			p.update_detail(viewer.global_position, delta)
		elif p.populated:
			p.depopulate()
