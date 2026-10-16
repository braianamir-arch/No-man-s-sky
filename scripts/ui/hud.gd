class_name HUD
extends CanvasLayer
## Interfaz: barras de estado, ubicacion, mensajes, mira, menu y pantalla de carga.

const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const GameMenu := preload("res://scripts/ui/game_menu.gd")

var touch: Control
var menu: Control
var _bars := {}
var _bar_box: VBoxContainer
var _location: Label
var _prompt: Label
var _messages: VBoxContainer
var _crosshair: Label
var _loading: ColorRect
var _loading_label: Label
var _loading_bar: ProgressBar
var _speed_label: Label
var _mode := ""


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 20
	root.theme = theme
	add_child(root)

	_bar_box = VBoxContainer.new()
	_bar_box.position = Vector2(20, 16)
	_bar_box.custom_minimum_size = Vector2(250, 0)
	_bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bar_box)
	for def in [
		["salud", "Salud", Color(0.9, 0.25, 0.25)],
		["soporte", "Soporte vital", Color(0.3, 0.8, 1.0)],
		["peligro", "Protección", Color(1.0, 0.75, 0.2)],
		["jetpack", "Jetpack", Color(0.7, 0.7, 1.0)],
		["escudo", "Escudo", Color(0.4, 0.6, 1.0)],
		["despegue", "Despegue", Color(1.0, 0.55, 0.2)],
		["pulso", "Pulso", Color(0.5, 1.0, 0.6)],
	]:
		_bars[def[0]] = _make_bar(def[1], def[2])

	_location = Label.new()
	_location.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_location.position = Vector2(-300, 12)
	_location.size = Vector2(600, 60)
	_location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_location.add_theme_font_size_override("font_size", 22)
	_location.add_theme_constant_override("outline_size", 6)
	_location.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(_location)

	_speed_label = Label.new()
	_speed_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_speed_label.position = Vector2(-200, 70)
	_speed_label.size = Vector2(400, 30)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.add_theme_constant_override("outline_size", 6)
	_speed_label.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(_speed_label)

	_crosshair = Label.new()
	_crosshair.text = "+"
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-10, -18)
	_crosshair.add_theme_font_size_override("font_size", 30)
	root.add_child(_crosshair)

	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-300, 40)
	_prompt.size = Vector2(600, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(_prompt)

	_messages = VBoxContainer.new()
	_messages.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_messages.position = Vector2(-320, -200)
	_messages.size = Vector2(640, 160)
	_messages.alignment = BoxContainer.ALIGNMENT_END
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_messages)

	touch = TouchControls.new()
	touch.visible = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	root.add_child(touch)

	menu = GameMenu.new()
	menu.visible = false
	root.add_child(menu)

	_loading = ColorRect.new()
	_loading.color = Color(0.01, 0.01, 0.03)
	_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_loading)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-250, -60)
	box.custom_minimum_size = Vector2(500, 120)
	_loading.add_child(box)
	_loading_label = Label.new()
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 26)
	box.add_child(_loading_label)
	_loading_bar = ProgressBar.new()
	_loading_bar.max_value = 1.0
	_loading_bar.custom_minimum_size = Vector2(500, 24)
	box.add_child(_loading_bar)

	GameState.notify.connect(show_message)
	menu.closed.connect(toggle_menu)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("menu") and not is_loading():
		toggle_menu()


func _make_bar(text: String, col: Color) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(130, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(130, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	_bar_box.add_child(row)
	row.set_meta("bar", bar)
	return row


func set_mode(m: String) -> void:
	_mode = m
	touch.set_mode(m)
	var foot := ["salud", "soporte", "peligro", "jetpack"]
	var ship := ["escudo", "despegue", "pulso"]
	for k in _bars:
		(_bars[k] as Control).visible = (k in foot) if m == "foot" else (k in ship)


func update_stats() -> void:
	for k in _bars:
		var bar: ProgressBar = (_bars[k] as Control).get_meta("bar")
		bar.value = float(GameState.stats[k])


func set_location(text: String) -> void:
	_location.text = text


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_speed(text: String) -> void:
	_speed_label.text = text


func show_message(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	_messages.add_child(l)
	while _messages.get_child_count() > 4:
		_messages.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func show_loading(on: bool, text := "") -> void:
	_loading.visible = on
	_loading_label.text = text
	_loading_bar.value = 0.0


func set_loading_progress(v: float) -> void:
	_loading_bar.value = v


func is_loading() -> bool:
	return _loading.visible


func toggle_menu() -> void:
	menu.visible = not menu.visible
	touch.release_all()
	touch.visible = (not menu.visible) and (OS.has_feature("mobile") or DisplayServer.is_touchscreen_available())
	if menu.visible:
		menu.refresh()
	get_tree().paused = menu.visible
