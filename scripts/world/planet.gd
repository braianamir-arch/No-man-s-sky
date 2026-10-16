class_name Planet
extends Node3D
## Planeta esferico procedural: terreno por ruido sobre una cubo-esfera,
## oceano, atmosfera, y detalle (flora, recursos y fauna) que aparece por
## celdas alrededor del jugador, de forma determinista segun la semilla.

const RES_HIGH := 88
const RES_LOW := 14
const DETAIL_RANGE := 150.0
const DETAIL_MAX_ALT := 320.0
const FACE_NORMALS: Array[Vector3] = [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]

const BIOMES := {
	"exuberante": {
		"label": "Exuberante", "hazard": 0.15, "hazard_name": "Ninguno", "water": 0.9, "flora": 1.0, "fauna": 1.0,
		"low": Color(0.76, 0.7, 0.5), "mid": Color(0.25, 0.55, 0.2), "high": Color(0.33, 0.45, 0.22),
		"peak": Color(0.95, 0.95, 0.97), "rock": Color(0.42, 0.38, 0.33), "atmo": Color(0.45, 0.65, 1.0),
		"watercol": Color(0.1, 0.35, 0.6), "trunk": Color(0.35, 0.22, 0.12), "leaf": Color(0.22, 0.6, 0.15),
		"tree": "round", "res": {"carbono": 3, "ferrita": 3, "oxigeno": 2, "sodio": 1, "dihidrogeno": 1},
	},
	"toxico": {
		"label": "Tóxico", "hazard": 1.0, "hazard_name": "Toxicidad", "water": 0.7, "flora": 0.8, "fauna": 0.6,
		"low": Color(0.55, 0.6, 0.25), "mid": Color(0.45, 0.55, 0.15), "high": Color(0.35, 0.4, 0.2),
		"peak": Color(0.75, 0.8, 0.4), "rock": Color(0.3, 0.32, 0.25), "atmo": Color(0.7, 0.85, 0.3),
		"watercol": Color(0.4, 0.6, 0.1), "trunk": Color(0.35, 0.28, 0.35), "leaf": Color(0.75, 0.3, 0.8),
		"tree": "mushroom", "res": {"carbono": 2, "ferrita": 2, "sodio": 3, "oxigeno": 1, "dihidrogeno": 1},
	},
	"helado": {
		"label": "Helado", "hazard": 0.9, "hazard_name": "Frío extremo", "water": 0.6, "flora": 0.5, "fauna": 0.5,
		"low": Color(0.8, 0.85, 0.9), "mid": Color(0.88, 0.92, 0.97), "high": Color(0.7, 0.78, 0.88),
		"peak": Color(1, 1, 1), "rock": Color(0.45, 0.5, 0.6), "atmo": Color(0.7, 0.85, 1.0),
		"watercol": Color(0.55, 0.75, 0.9), "trunk": Color(0.3, 0.25, 0.2), "leaf": Color(0.18, 0.4, 0.3),
		"tree": "pine", "res": {"ferrita": 3, "dihidrogeno": 3, "oxigeno": 2, "carbono": 1, "sodio": 1},
	},
	"abrasador": {
		"label": "Abrasador", "hazard": 1.3, "hazard_name": "Calor extremo", "water": 0.0, "flora": 0.4, "fauna": 0.4,
		"low": Color(0.55, 0.25, 0.12), "mid": Color(0.7, 0.35, 0.15), "high": Color(0.5, 0.2, 0.1),
		"peak": Color(0.25, 0.1, 0.08), "rock": Color(0.3, 0.15, 0.1), "atmo": Color(1.0, 0.55, 0.3),
		"watercol": Color(1, 0.3, 0), "trunk": Color(0.2, 0.12, 0.1), "leaf": Color(0.9, 0.4, 0.1),
		"tree": "spike", "res": {"ferrita": 3, "sodio": 3, "carbono": 1, "dihidrogeno": 1, "oxigeno": 1},
	},
	"yermo": {
		"label": "Yermo", "hazard": 0.6, "hazard_name": "Radiación", "water": 0.2, "flora": 0.3, "fauna": 0.3,
		"low": Color(0.7, 0.65, 0.55), "mid": Color(0.62, 0.56, 0.45), "high": Color(0.5, 0.45, 0.38),
		"peak": Color(0.8, 0.78, 0.7), "rock": Color(0.4, 0.38, 0.35), "atmo": Color(0.85, 0.75, 0.6),
		"watercol": Color(0.3, 0.4, 0.45), "trunk": Color(0.4, 0.5, 0.3), "leaf": Color(0.45, 0.6, 0.35),
		"tree": "cactus", "res": {"ferrita": 4, "dihidrogeno": 2, "carbono": 1, "sodio": 1, "oxigeno": 1},
	},
	"exotico": {
		"label": "Exótico", "hazard": 0.35, "hazard_name": "Anomalía", "water": 0.5, "flora": 1.2, "fauna": 0.8,
		"low": Color(0.9, 0.5, 0.7), "mid": Color(0.5, 0.2, 0.7), "high": Color(0.3, 0.6, 0.8),
		"peak": Color(1, 0.9, 1), "rock": Color(0.3, 0.2, 0.4), "atmo": Color(0.9, 0.4, 1.0),
		"watercol": Color(0.2, 0.9, 0.8), "trunk": Color(0.9, 0.9, 0.9), "leaf": Color(0.1, 1.0, 0.8),
		"tree": "mushroom", "res": {"carbono": 2, "ferrita": 2, "oxigeno": 2, "sodio": 2, "dihidrogeno": 2},
	},
}

var planet_seed := 0
var planet_name := ""
var biome_id := "exuberante"
var biome: Dictionary = {}
var radius := 300.0
var amplitude := 24.0
var has_water := false
var sea_level := 0.0
var gravity := 16.0
var hazard := 0.0
var atmo_color := Color.WHITE
var fog_density := 0.004
var flora_density := 1.0
var fauna_density := 1.0
var species: Array = []

var _pal := {}
var _continent := FastNoiseLite.new()
var _mountain := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _cells_per_face := 16
var _data_high: Dictionary = {}
var _data_low: Dictionary = {}

var populated := false
var _active_cells := {}
var _mined := {}
var _last_detail_pos := Vector3.INF
var _flora: MultiMeshInstance3D
var _rocks: MultiMeshInstance3D
var _creatures: Array = []
var _spawn_timer := 0.0


func setup(seed_value: int, r: float, biome_name: String) -> void:
	planet_seed = seed_value
	radius = r
	biome_id = biome_name
	biome = BIOMES[biome_name].duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	planet_name = NameGen.generate(rng)
	amplitude = r * rng.randf_range(0.06, 0.1)
	has_water = rng.randf() < float(biome["water"])
	sea_level = amplitude * rng.randf_range(-0.05, 0.08)
	gravity = remap(r, 220.0, 380.0, 13.0, 21.0)
	hazard = float(biome["hazard"]) * rng.randf_range(0.8, 1.2)
	flora_density = float(biome["flora"]) * rng.randf_range(0.6, 1.3)
	fauna_density = float(biome["fauna"]) * rng.randf_range(0.5, 1.3)
	fog_density = rng.randf_range(0.0025, 0.007)
	# Variacion de color por planeta (en exoticos mucho mayor).
	var hue_shift := rng.randf_range(-0.04, 0.04)
	if biome_name == "exotico":
		hue_shift = rng.randf()
	for k in ["low", "mid", "high", "peak", "rock", "atmo", "watercol", "trunk", "leaf"]:
		_pal[k] = _shift(biome[k], hue_shift, rng)
	atmo_color = _pal["atmo"]
	_cells_per_face = int(radius / 16.0)

	_continent.seed = rng.randi()
	_continent.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_continent.frequency = 1.0 / (radius * 0.55)
	_continent.fractal_octaves = 4
	_mountain.seed = rng.randi()
	_mountain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mountain.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain.frequency = 1.0 / (radius * 0.18)
	_mountain.fractal_octaves = 4
	_detail.seed = rng.randi()
	_detail.frequency = 0.03
	_detail.fractal_octaves = 2

	# Especies de fauna de este planeta.
	for i in rng.randi_range(2, 4):
		species.append({
			"index": i,
			"name": NameGen.generate(rng),
			"color": Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.8), rng.randf_range(0.4, 0.95)),
			"color2": Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.7), rng.randf_range(0.5, 1.0)),
			"size": rng.randf_range(0.5, 2.6),
			"legs": [0, 2, 4, 4, 6][rng.randi() % 5],
			"speed": rng.randf_range(1.5, 5.0),
			"neck": rng.randf_range(0.0, 1.0),
			"long": rng.randf_range(0.8, 2.0),
		})


func _shift(c: Color, hue: float, rng: RandomNumberGenerator) -> Color:
	var h := fposmod(c.h + hue + rng.randf_range(-0.02, 0.02), 1.0)
	return Color.from_hsv(h, clampf(c.s * rng.randf_range(0.85, 1.15), 0, 1), clampf(c.v * rng.randf_range(0.9, 1.1), 0, 1))


## Altura del terreno (sobre el radio) para una direccion unitaria local.
func sample_height(dir: Vector3) -> float:
	var p := dir * radius
	var c := _continent.get_noise_3dv(p)
	var m := clampf(_mountain.get_noise_3dv(p) * 0.5 + 0.5, 0.0, 1.0)
	var d := _detail.get_noise_3dv(p)
	var land := smoothstep(-0.1, 0.35, c)
	var h := c * 0.5 + land * m * m * m * 1.1 + d * 0.05
	return h * amplitude


func surface_point(dir: Vector3) -> Vector3:
	return dir * (radius + sample_height(dir))


func altitude_of(world_pos: Vector3) -> float:
	var local := world_pos - global_position
	return local.length() - radius - sample_height(local.normalized())


## Calculo pesado del terreno. Se ejecuta en hilos de trabajo.
func build_data() -> void:
	_data_high = _build_sphere(RES_HIGH, true)
	_data_low = _build_sphere(RES_LOW, false)


func _build_sphere(res: int, with_faces: bool) -> Dictionary:
	var side := res + 1
	var g := res + 3
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize(6 * side * side)
	normals.resize(6 * side * side)
	colors.resize(6 * side * side)
	var grid := PackedVector3Array()
	grid.resize(g * g)
	var heights := PackedFloat32Array()
	heights.resize(g * g)
	for f in 6:
		var n: Vector3 = FACE_NORMALS[f]
		var a := Vector3(n.y, n.z, n.x)
		var b := n.cross(a)
		for y in g:
			for x in g:
				var u := (float(x - 1) / res) * 2.0 - 1.0
				var v := (float(y - 1) / res) * 2.0 - 1.0
				var dir := (n + a * u + b * v).normalized()
				var h := sample_height(dir)
				grid[y * g + x] = dir * (radius + h)
				heights[y * g + x] = h
		var base := f * side * side
		for y in side:
			for x in side:
				var gi := (y + 1) * g + (x + 1)
				var p := grid[gi]
				var dir := p.normalized()
				var nrm := (grid[gi + 1] - grid[gi - 1]).cross(grid[gi + g] - grid[gi - g]).normalized()
				if nrm.dot(dir) < 0.0:
					nrm = -nrm
				var vi := base + y * side + x
				verts[vi] = p
				normals[vi] = nrm
				colors[vi] = _ground_color(heights[gi], nrm.dot(dir), p)
		# Godot usa orden horario para caras frontales: lo verificamos.
		var flip := (verts[base + side] - verts[base]).cross(verts[base + 1] - verts[base]).dot(verts[base]) > 0.0
		for y in res:
			for x in res:
				var i := base + y * side + x
				if flip:
					indices.append(i); indices.append(i + 1); indices.append(i + side)
					indices.append(i + 1); indices.append(i + side + 1); indices.append(i + side)
				else:
					indices.append(i); indices.append(i + side); indices.append(i + 1)
					indices.append(i + 1); indices.append(i + side); indices.append(i + side + 1)
	var out := {"verts": verts, "normals": normals, "colors": colors, "indices": indices}
	if with_faces:
		var faces := PackedVector3Array()
		faces.resize(indices.size())
		for k in indices.size():
			faces[k] = verts[indices[k]]
		out["faces"] = faces
	return out


func _ground_color(h: float, slope: float, p: Vector3) -> Color:
	var t := h / amplitude
	var col: Color = _pal["mid"]
	if has_water and h < sea_level + amplitude * 0.04:
		col = _pal["low"]
	elif t < 0.3:
		col = (_pal["low"] as Color).lerp(_pal["mid"], smoothstep(-0.2, 0.15, t))
	else:
		col = (_pal["mid"] as Color).lerp(_pal["high"], smoothstep(0.3, 0.7, t))
	col = col.lerp(_pal["rock"], smoothstep(0.93, 0.78, slope))
	col = col.lerp(_pal["peak"], smoothstep(0.75, 0.95, t) * smoothstep(0.75, 0.9, slope))
	var var_n := _detail.get_noise_3dv(p * 2.3) * 0.07
	return Color(col.r + var_n, col.g + var_n, col.b + var_n)


## Crea mallas, colision, oceano y atmosfera (hilo principal).
func finalize(sun_dir: Vector3) -> void:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	var hi := MeshInstance3D.new()
	hi.mesh = _make_mesh(_data_high)
	hi.material_override = mat
	hi.visibility_range_end = radius * 6.0
	add_child(hi)
	var lo := MeshInstance3D.new()
	lo.mesh = _make_mesh(_data_low)
	lo.material_override = mat
	lo.visibility_range_begin = radius * 6.0
	lo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lo)

	var body := StaticBody3D.new()
	body.add_to_group("terrain")
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_data_high["faces"])
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	_data_high = {}
	_data_low = {}

	if has_water:
		var water := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = radius + sea_level
		sm.height = (radius + sea_level) * 2.0
		sm.radial_segments = 96
		sm.rings = 48
		water.mesh = sm
		var wm := StandardMaterial3D.new()
		var wc: Color = _pal["watercol"]
		wm.albedo_color = Color(wc.r, wc.g, wc.b, 0.78)
		wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wm.roughness = 0.08
		wm.metallic = 0.3
		wm.cull_mode = BaseMaterial3D.CULL_DISABLED
		if biome_id == "abrasador":
			wm.emission_enabled = true
			wm.emission = wc
		water.material_override = wm
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)

	var atmo := MeshInstance3D.new()
	var am := SphereMesh.new()
	am.radius = radius * 1.16
	am.height = radius * 2.32
	am.radial_segments = 48
	am.rings = 24
	atmo.mesh = am
	var sh := ShaderMaterial.new()
	sh.shader = preload("res://shaders/atmosphere.gdshader")
	sh.set_shader_parameter("color", atmo_color)
	sh.set_shader_parameter("sun_dir", sun_dir)
	atmo.material_override = sh
	atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(atmo)

	_flora = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _make_tree_mesh()
	_flora.multimesh = mm
	add_child(_flora)
	_rocks = MultiMeshInstance3D.new()
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	var rock := SphereMesh.new()
	rock.radial_segments = 6
	rock.rings = 3
	rock.radius = 0.6
	rock.height = 0.8
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = _pal["rock"]
	rock.material = rock_mat
	rm.mesh = rock
	_rocks.multimesh = rm
	add_child(_rocks)


func _make_mesh(d: Dictionary) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = d["verts"]
	arrays[Mesh.ARRAY_NORMAL] = d["normals"]
	arrays[Mesh.ARRAY_COLOR] = d["colors"]
	arrays[Mesh.ARRAY_INDEX] = d["indices"]
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _make_tree_mesh() -> ArrayMesh:
	var style: String = biome["tree"]
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = _pal["trunk"]
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = _pal["leaf"]
	var trunk := CylinderMesh.new()
	trunk.radial_segments = 6
	trunk.rings = 1
	var leaf: PrimitiveMesh
	var trunk_h := 4.0
	var leaf_y := 4.5
	match style:
		"pine":
			trunk.top_radius = 0.2
			trunk.bottom_radius = 0.35
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 2.0
			cone.height = 6.0
			cone.radial_segments = 7
			leaf = cone
			leaf_y = 5.0
		"mushroom":
			trunk.top_radius = 0.35
			trunk.bottom_radius = 0.5
			trunk_h = 3.5
			var cap := SphereMesh.new()
			cap.radius = 2.4
			cap.height = 1.6
			cap.radial_segments = 10
			cap.rings = 4
			leaf = cap
			leaf_y = 3.6
			leaf_mat.emission_enabled = true
			leaf_mat.emission = (_pal["leaf"] as Color) * 0.5
		"spike":
			trunk.top_radius = 0.05
			trunk.bottom_radius = 0.4
			trunk_h = 5.0
			var spike := PrismMesh.new()
			spike.size = Vector3(1.5, 2.5, 0.4)
			leaf = spike
			leaf_y = 2.5
			leaf_mat.emission_enabled = true
			leaf_mat.emission = (_pal["leaf"] as Color) * 0.7
		"cactus":
			trunk.top_radius = 0.45
			trunk.bottom_radius = 0.5
			trunk.radial_segments = 8
			trunk_h = 3.0
			trunk_mat.albedo_color = _pal["leaf"]
			var arm := CapsuleMesh.new()
			arm.radius = 0.3
			arm.height = 1.8
			leaf = arm
			leaf_y = 2.0
		_:
			trunk.top_radius = 0.2
			trunk.bottom_radius = 0.35
			var crown := SphereMesh.new()
			crown.radius = 2.0
			crown.height = 3.2
			crown.radial_segments = 8
			crown.rings = 4
			leaf = crown
	trunk.height = trunk_h
	var leaf_xf := Transform3D(Basis(), Vector3(0, leaf_y, 0))
	if style == "cactus":
		leaf_xf = Transform3D(Basis(Vector3.BACK, 0.9), Vector3(0.7, leaf_y, 0))
	var mesh := ArrayMesh.new()
	add_transformed_surface(mesh, trunk, Transform3D(Basis(), Vector3(0, trunk_h * 0.5, 0)), trunk_mat)
	add_transformed_surface(mesh, leaf, leaf_xf, leaf_mat)
	return mesh


## Copia la geometria de una primitiva desplazada/rotada como nueva superficie.
static func add_transformed_surface(mesh: ArrayMesh, prim: PrimitiveMesh, xf: Transform3D, mat: Material) -> void:
	var arrays := prim.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in verts.size():
		verts[i] = xf * verts[i]
		normals[i] = (xf.basis * normals[i]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


# ---------------------------------------------------------------- Detalle

func _face_basis(f: int) -> Array:
	var n: Vector3 = FACE_NORMALS[f]
	var a := Vector3(n.y, n.z, n.x)
	return [n, a, n.cross(a)]


func _cell_of(dir: Vector3) -> Vector3i:
	var best := 0
	var best_d := -2.0
	for f in 6:
		var d := dir.dot(FACE_NORMALS[f])
		if d > best_d:
			best_d = d
			best = f
	var fb := _face_basis(best)
	var cube: Vector3 = dir / best_d
	var u := cube.dot(fb[1])
	var v := cube.dot(fb[2])
	var n := _cells_per_face
	return Vector3i(best, clampi(int((u + 1.0) * 0.5 * n), 0, n - 1), clampi(int((v + 1.0) * 0.5 * n), 0, n - 1))


func _rand_dir_in_cell(c: Vector3i, rng: RandomNumberGenerator) -> Vector3:
	var fb := _face_basis(c.x)
	var n := float(_cells_per_face)
	var u := ((c.y + rng.randf()) / n) * 2.0 - 1.0
	var v := ((c.z + rng.randf()) / n) * 2.0 - 1.0
	return ((fb[0] as Vector3) + (fb[1] as Vector3) * u + (fb[2] as Vector3) * v).normalized()


static func basis_on_surface(up: Vector3, angle: float) -> Basis:
	var ref := Vector3.UP if absf(up.y) < 0.95 else Vector3.RIGHT
	var x := ref.cross(up).normalized()
	var z := x.cross(up)
	return Basis(up, angle) * Basis(x, up, z)


func _cell_content(c: Vector3i) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([planet_seed, c.x, c.y, c.z])
	var trees: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var deposits: Array = []
	for i in int(rng.randf() * 6.0 * flora_density):
		var dir := _rand_dir_in_cell(c, rng)
		var h := sample_height(dir)
		if has_water and h < sea_level + 0.8:
			continue
		var s := rng.randf_range(0.6, 1.5)
		trees.append(Transform3D(basis_on_surface(dir, rng.randf() * TAU).scaled(Vector3.ONE * s), dir * (radius + h - 0.4)))
	for i in rng.randi_range(0, 5):
		var dir := _rand_dir_in_cell(c, rng)
		var h := sample_height(dir)
		var s := rng.randf_range(0.4, 2.2)
		rocks.append(Transform3D(basis_on_surface(dir, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.5, 1.0), s)), dir * (radius + h - 0.2)))
	if rng.randf() < 0.3:
		var id := _pick_resource(rng)
		var center := _rand_dir_in_cell(c, rng)
		for k in rng.randi_range(1, 3):
			var dir := (center + Vector3(rng.randfn(), rng.randfn(), rng.randfn()) * (4.0 / radius)).normalized()
			var h := sample_height(dir)
			if has_water and h < sea_level + 0.3:
				continue
			deposits.append({"id": id, "dir": dir, "h": h, "k": "%d_%d_%d_%d" % [c.x, c.y, c.z, k], "angle": rng.randf() * TAU})
	return {"trees": trees, "rocks": rocks, "deposits": deposits}


func _pick_resource(rng: RandomNumberGenerator) -> String:
	var weights: Dictionary = biome["res"]
	var total := 0
	for k in weights:
		total += int(weights[k])
	var r := rng.randi() % total
	for k in weights:
		r -= int(weights[k])
		if r < 0:
			return k
	return "ferrita"


func update_detail(viewer: Vector3, delta: float) -> void:
	var local := viewer - global_position
	var alt := local.length() - radius
	if alt > DETAIL_MAX_ALT:
		if populated:
			depopulate()
		return
	_update_creatures(local, delta)
	if populated and local.distance_to(_last_detail_pos) < 10.0:
		return
	populated = true
	_last_detail_pos = local
	var dir := local.normalized()
	var ref := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var t1 := dir.cross(ref).normalized()
	var t2 := dir.cross(t1)
	var ang := DETAIL_RANGE / radius
	var wanted := {}
	var steps := 9
	for i in range(-steps, steps + 1):
		for j in range(-steps, steps + 1):
			var off := Vector2(i, j) / steps * ang
			if off.length() > ang:
				continue
			wanted[_cell_of((dir + t1 * off.x + t2 * off.y).normalized())] = true
	var changed := false
	for key in _active_cells.keys():
		if not wanted.has(key):
			for node in _active_cells[key]["nodes"]:
				if is_instance_valid(node):
					node.queue_free()
			_active_cells.erase(key)
			changed = true
	for key in wanted:
		if _active_cells.has(key):
			continue
		var content := _cell_content(key)
		var nodes: Array = []
		for dep in content["deposits"]:
			if _mined.has(dep["k"]):
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(dep["k"])
			var size := rng.randf_range(0.9, 2.2)
			var node := ResourceNode.create(dep["id"], size, int(size * 25.0), rng)
			node.key = dep["k"]
			node.transform = Transform3D(basis_on_surface(dep["dir"], dep["angle"]), (dep["dir"] as Vector3) * (radius + float(dep["h"]) - 0.3))
			node.depleted.connect(func(n: ResourceNode): _mined[n.key] = true)
			add_child(node)
			nodes.append(node)
		_active_cells[key] = {"content": content, "nodes": nodes}
		changed = true
	if changed:
		_rebuild_multimeshes()


func _rebuild_multimeshes() -> void:
	var trees: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	for key in _active_cells:
		trees.append_array(_active_cells[key]["content"]["trees"])
		rocks.append_array(_active_cells[key]["content"]["rocks"])
	var mm := _flora.multimesh
	mm.instance_count = trees.size()
	for i in trees.size():
		mm.set_instance_transform(i, trees[i])
	var rm := _rocks.multimesh
	rm.instance_count = rocks.size()
	for i in rocks.size():
		rm.set_instance_transform(i, rocks[i])


func depopulate() -> void:
	populated = false
	_last_detail_pos = Vector3.INF
	for key in _active_cells:
		for node in _active_cells[key]["nodes"]:
			if is_instance_valid(node):
				node.queue_free()
	_active_cells.clear()
	if _flora:
		_flora.multimesh.instance_count = 0
		_rocks.multimesh.instance_count = 0
	for c in _creatures:
		if is_instance_valid(c):
			c.queue_free()
	_creatures.clear()


func _update_creatures(viewer_local: Vector3, delta: float) -> void:
	var alive: Array = []
	for c in _creatures:
		if not is_instance_valid(c):
			continue
		if (c as Node3D).position.distance_to(viewer_local) > 230.0:
			c.queue_free()
		else:
			alive.append(c)
	_creatures = alive
	_spawn_timer -= delta
	var max_count := int(12.0 * fauna_density)
	if _spawn_timer > 0.0 or _creatures.size() >= max_count or species.is_empty():
		return
	_spawn_timer = 0.4
	var dir := viewer_local.normalized()
	var ref := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var t1 := dir.cross(ref).normalized()
	var t2 := dir.cross(t1)
	var a := randf() * TAU
	var dist := randf_range(40.0, 140.0) / radius
	var spawn_dir := (dir + (t1 * cos(a) + t2 * sin(a)) * dist).normalized()
	if has_water and sample_height(spawn_dir) < sea_level + 0.5:
		return
	var sp: Dictionary = species[randi() % species.size()]
	var herd := randi_range(1, 3)
	for i in herd:
		var d := (spawn_dir + Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1)) * (5.0 / radius)).normalized()
		var cr := Creature.create(self, sp, d)
		add_child(cr)
		_creatures.append(cr)


## Criatura mas cercana a una posicion global (para el escaner).
func nearest_creature(world_pos: Vector3, max_dist: float) -> Creature:
	var best: Creature = null
	var best_d := max_dist
	for c in _creatures:
		if is_instance_valid(c):
			var d := (c as Node3D).global_position.distance_to(world_pos)
			if d < best_d:
				best_d = d
				best = c
	return best
