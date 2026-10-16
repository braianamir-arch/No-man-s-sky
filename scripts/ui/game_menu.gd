extends PanelContainer
## Menu de inventario, fabricacion, mejoras y descubrimientos.

signal closed

var _content: VBoxContainer
var _inv_grid: GridContainer
var _info: Label
var _recipe_buttons: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 40
	offset_right = -40
	offset_top = 30
	offset_bottom = -30
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.92)
	sb.border_color = Color(0.4, 0.8, 1.0, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	add_theme_stylebox_override("panel", sb)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

	var header := HBoxContainer.new()
	_content.add_child(header)
	var title := Label.new()
	title.text = "INVENTARIO DEL EXOTRAJE"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "  Cerrar  "
	close.custom_minimum_size = Vector2(140, 56)
	close.pressed.connect(func(): closed.emit())
	header.add_child(close)

	_info = Label.new()
	_content.add_child(_info)

	_inv_grid = GridContainer.new()
	_inv_grid.columns = 3
	_inv_grid.add_theme_constant_override("h_separation", 30)
	_content.add_child(_inv_grid)

	var sub := Label.new()
	sub.text = "FABRICACIÓN Y RECARGA"
	sub.add_theme_font_size_override("font_size", 22)
	_content.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for r in GameState.RECIPES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = _recipe_text(r)
		b.pressed.connect(func():
			GameState.craft(r)
			refresh())
		b.set_meta("recipe", r)
		grid.add_child(b)
		_recipe_buttons.append(b)

	var save := Button.new()
	save.text = "Guardar partida"
	save.custom_minimum_size = Vector2(0, 60)
	save.pressed.connect(func():
		GameState.save_game()
		GameState.notify.emit("Partida guardada"))
	_content.add_child(save)

	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "Consejos: mina rocas (Ferrita), plantas (Carbono, Sodio, Oxígeno) y cristales (Di-hidrógeno). " \
		+ "Dispara a los asteroides desde la nave para obtener Tritio. Usa el escáner cerca de animales para descubrirlos. " \
		+ "Con una célula de curvatura puedes saltar a otro sistema estelar lejos de los planetas."
	_content.add_child(help)
	GameState.inventory_changed.connect(refresh)


func _recipe_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	var cost: Dictionary = r["cost"]
	for id in cost:
		parts.append("%d %s" % [cost[id], GameState.RESOURCES[id]["name"]])
	if r.has("units"):
		parts.append("%d u" % r["units"])
	return "%s\n(%s)" % [r["label"], ", ".join(parts)]


func refresh() -> void:
	if not is_inside_tree():
		return
	for c in _inv_grid.get_children():
		c.queue_free()
	for id in GameState.RESOURCES:
		var l := Label.new()
		l.text = "■ %s: %d/%d" % [GameState.RESOURCES[id]["name"], GameState.inventory.get(id, 0), GameState.capacity()]
		l.add_theme_color_override("font_color", GameState.RESOURCES[id]["color"])
		_inv_grid.add_child(l)
	_info.text = "Unidades: %d   ·   Células de curvatura: %d   ·   Descubrimientos: %d   ·   Sistemas visitados: %d" % [
		GameState.units, int(GameState.stats["celdas"]), GameState.discovered.size(), GameState.systems_visited]
	for b in _recipe_buttons:
		b.disabled = not GameState.can_afford(b.get_meta("recipe"))
