extends Node
## Estado global: inventario, estadisticas del exotraje y la nave, descubrimientos,
## recetas de fabricacion y guardado.

signal inventory_changed
signal notify(text: String)

const SAVE_PATH := "user://partida.json"

const RESOURCES := {
	"carbono": {"name": "Carbono", "color": Color(0.85, 0.25, 0.2)},
	"ferrita": {"name": "Ferrita", "color": Color(0.72, 0.72, 0.78)},
	"sodio": {"name": "Sodio", "color": Color(1.0, 0.8, 0.15)},
	"oxigeno": {"name": "Oxígeno", "color": Color(0.35, 0.85, 1.0)},
	"dihidrogeno": {"name": "Di-hidrógeno", "color": Color(0.3, 0.45, 1.0)},
	"tritio": {"name": "Tritio", "color": Color(0.55, 1.0, 0.55)},
}

## Recetas del menu: coste en recursos/unidades y efecto.
const RECIPES := [
	{"id": "soporte", "label": "Recargar soporte vital", "cost": {"oxigeno": 20}},
	{"id": "peligro", "label": "Recargar protección contra peligros", "cost": {"sodio": 20}},
	{"id": "salud", "label": "Curar exotraje", "cost": {"carbono": 30}},
	{"id": "despegue", "label": "Cargar propulsor de despegue", "cost": {"dihidrogeno": 25}},
	{"id": "pulso", "label": "Cargar motor de pulso", "cost": {"tritio": 20}},
	{"id": "escudo", "label": "Reparar escudo de la nave", "cost": {"ferrita": 30}},
	{"id": "celda", "label": "Fabricar célula de curvatura", "cost": {"tritio": 50, "ferrita": 40, "dihidrogeno": 30}},
	{"id": "mejora_traje", "label": "Mejorar exotraje (+inventario)", "cost": {"ferrita": 60}, "units": 500},
	{"id": "mejora_jetpack", "label": "Mejorar jetpack", "cost": {"carbono": 40}, "units": 400},
	{"id": "mejora_nave", "label": "Mejorar motores de la nave", "cost": {"dihidrogeno": 50}, "units": 800},
]

## Las pruebas automaticas lo activan para no tocar la partida guardada.
var testing := false
var universe_seed: int = 1337
var systems_visited: int = 1
var units: int = 0
var inventory: Dictionary = {}
var stats: Dictionary = {}
var upgrades: Dictionary = {"traje": 0, "jetpack": 0, "nave": 0}
var discovered: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	reset()


func reset() -> void:
	inventory.clear()
	for id in RESOURCES:
		inventory[id] = 0
	inventory["carbono"] = 40
	inventory["oxigeno"] = 30
	inventory["sodio"] = 20
	inventory["dihidrogeno"] = 25
	stats = {
		"salud": 100.0,
		"soporte": 100.0,
		"peligro": 100.0,
		"jetpack": 100.0,
		"escudo": 100.0,
		"despegue": 100.0,
		"pulso": 100.0,
		"celdas": 0,
	}


func capacity() -> int:
	return 250 + int(upgrades["traje"]) * 250


func add_resource(id: String, amount: int) -> int:
	var before: int = inventory.get(id, 0)
	var after: int = mini(before + amount, capacity())
	inventory[id] = after
	if after == before and amount > 0:
		notify.emit("Inventario lleno: %s" % RESOURCES[id]["name"])
	inventory_changed.emit()
	return after - before


func can_afford(recipe: Dictionary) -> bool:
	var cost: Dictionary = recipe.get("cost", {})
	for id in cost:
		if int(inventory.get(id, 0)) < int(cost[id]):
			return false
	return units >= int(recipe.get("units", 0))


func craft(recipe: Dictionary) -> bool:
	if not can_afford(recipe):
		notify.emit("Faltan recursos")
		return false
	var cost: Dictionary = recipe.get("cost", {})
	for id in cost:
		inventory[id] = int(inventory[id]) - int(cost[id])
	units -= int(recipe.get("units", 0))
	match recipe["id"]:
		"soporte": stats["soporte"] = 100.0
		"peligro": stats["peligro"] = 100.0
		"salud": stats["salud"] = 100.0
		"despegue": stats["despegue"] = 100.0
		"pulso": stats["pulso"] = 100.0
		"escudo": stats["escudo"] = 100.0
		"celda": stats["celdas"] = int(stats["celdas"]) + 1
		"mejora_traje": upgrades["traje"] = int(upgrades["traje"]) + 1
		"mejora_jetpack": upgrades["jetpack"] = int(upgrades["jetpack"]) + 1
		"mejora_nave": upgrades["nave"] = int(upgrades["nave"]) + 1
	notify.emit("%s: listo" % recipe["label"])
	inventory_changed.emit()
	return true


## Registra un descubrimiento (planeta, especie...). Devuelve true si es nuevo.
func discover(key: String, title: String, reward: int) -> bool:
	if discovered.has(key):
		return false
	discovered[key] = title
	units += reward
	notify.emit("Descubierto: %s  (+%d unidades)" % [title, reward])
	inventory_changed.emit()
	return true


func save_game() -> void:
	if testing:
		return
	var data := {
		"seed": universe_seed,
		"systems_visited": systems_visited,
		"units": units,
		"inventory": inventory,
		"stats": stats,
		"upgrades": upgrades,
		"discovered": discovered,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> bool:
	if testing:
		return false
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	universe_seed = int(data.get("seed", universe_seed))
	systems_visited = int(data.get("systems_visited", 1))
	units = int(data.get("units", 0))
	var inv: Dictionary = data.get("inventory", {})
	for id in inv:
		inventory[id] = int(inv[id])
	var st: Dictionary = data.get("stats", {})
	for k in st:
		stats[k] = st[k]
	var up: Dictionary = data.get("upgrades", {})
	for k in up:
		upgrades[k] = int(up[k])
	discovered = data.get("discovered", {})
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func _register_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"throttle_up": [KEY_W, KEY_UP],
		"throttle_down": [KEY_S, KEY_DOWN],
		"roll_left": [KEY_A],
		"roll_right": [KEY_D],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
		"scan": [KEY_C],
		"menu": [KEY_TAB, KEY_I],
		"boost": [KEY_SHIFT],
		"warp": [KEY_J],
		"mine": [KEY_F],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	# En movil el toque se emula como clic: no enlazamos el raton a "minar" alli.
	if not OS.has_feature("mobile"):
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("mine", mb)
