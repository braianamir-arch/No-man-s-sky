extends Control
## Controles tactiles multitouch: joystick dinamico a la izquierda, arrastre
## para mirar a la derecha y botones que pulsan acciones del InputMap.

const TOUCH_LOOK_SENS := 1.6

var mode := "foot"
var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_offset := Vector2.ZERO
var _joy_radius := 100.0
var _look_index := -1
var _look_last := Vector2.ZERO
var _font: Font

## Botones: ancla relativa a la pantalla + desplazamiento en pixeles.
var buttons: Array = [
	{"action": "mine", "label": "MINAR", "anchor": Vector2(1, 1), "off": Vector2(-120, -140), "r": 62.0, "modes": ["foot"]},
	{"action": "jump", "label": "SALTO", "anchor": Vector2(1, 1), "off": Vector2(-270, -80), "r": 50.0, "modes": ["foot"]},
	{"action": "scan", "label": "ESCÁNER", "anchor": Vector2(1, 1), "off": Vector2(-95, -300), "r": 42.0, "modes": ["foot"]},
	{"action": "interact", "label": "USAR", "anchor": Vector2(1, 1), "off": Vector2(-265, -215), "r": 44.0, "modes": ["foot"]},
	{"action": "mine", "label": "FUEGO", "anchor": Vector2(1, 1), "off": Vector2(-120, -140), "r": 62.0, "modes": ["ship"]},
	{"action": "throttle_up", "label": "ACEL.", "anchor": Vector2(1, 1), "off": Vector2(-270, -200), "r": 46.0, "modes": ["ship"]},
	{"action": "throttle_down", "label": "FRENO", "anchor": Vector2(1, 1), "off": Vector2(-270, -80), "r": 42.0, "modes": ["ship"]},
	{"action": "boost", "label": "PULSO", "anchor": Vector2(1, 1), "off": Vector2(-95, -300), "r": 44.0, "modes": ["ship"]},
	{"action": "interact", "label": "ATERRIZAR", "anchor": Vector2(1, 1), "off": Vector2(-400, -110), "r": 46.0, "modes": ["ship"]},
	{"action": "warp", "label": "SALTO\nCURV.", "anchor": Vector2(1, 0), "off": Vector2(-170, 70), "r": 38.0, "modes": ["ship"]},
	{"action": "menu", "label": "MENÚ", "anchor": Vector2(1, 0), "off": Vector2(-70, 70), "r": 38.0, "modes": ["foot", "ship"]},
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	resized.connect(queue_redraw)
	for b in buttons:
		b["index"] = -1


func set_mode(m: String) -> void:
	if m == mode:
		return
	release_all()
	mode = m
	queue_redraw()


func set_label(action: String, text: String) -> void:
	for b in buttons:
		if b["action"] == action and mode in b["modes"] and b["label"] != text:
			b["label"] = text
			queue_redraw()


func release_all() -> void:
	for b in buttons:
		if b["index"] != -1:
			Input.action_release(b["action"])
			b["index"] = -1
	_joy_index = -1
	_look_index = -1
	_joy_offset = Vector2.ZERO
	TouchInput.move_vector = Vector2.ZERO


func _center(b: Dictionary) -> Vector2:
	var s := size
	var a: Vector2 = b["anchor"]
	return Vector2(s.x * a.x, s.y * a.y) + (b["off"] as Vector2)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			for b in buttons:
				if mode in b["modes"] and b["index"] == -1 and st.position.distance_to(_center(b)) <= float(b["r"]) * 1.2:
					b["index"] = st.index
					Input.action_press(b["action"])
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			if st.position.x < size.x * 0.42 and _joy_index == -1:
				_joy_index = st.index
				_joy_center = st.position
				_joy_offset = Vector2.ZERO
			elif _look_index == -1:
				_look_index = st.index
				_look_last = st.position
			queue_redraw()
		else:
			for b in buttons:
				if b["index"] == st.index:
					b["index"] = -1
					Input.action_release(b["action"])
			if st.index == _joy_index:
				_joy_index = -1
				_joy_offset = Vector2.ZERO
				TouchInput.move_vector = Vector2.ZERO
			if st.index == _look_index:
				_look_index = -1
			queue_redraw()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _joy_index:
			_joy_offset = (sd.position - _joy_center).limit_length(_joy_radius)
			TouchInput.move_vector = Vector2(_joy_offset.x, -_joy_offset.y) / _joy_radius
			queue_redraw()
		elif sd.index == _look_index:
			TouchInput.add_look((sd.position - _look_last) * TOUCH_LOOK_SENS)
			_look_last = sd.position


func _draw() -> void:
	var joy_c := _joy_center if _joy_index != -1 else Vector2(size.x * 0.13, size.y * 0.74)
	draw_circle(joy_c, _joy_radius, Color(1, 1, 1, 0.08))
	draw_arc(joy_c, _joy_radius, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_circle(joy_c + _joy_offset, 38.0, Color(1, 1, 1, 0.35))
	for b in buttons:
		if not mode in b["modes"]:
			continue
		var c := _center(b)
		var r: float = b["r"]
		var pressed: bool = b["index"] != -1
		draw_circle(c, r, Color(0.1, 0.8, 1.0, 0.45) if pressed else Color(0, 0, 0, 0.35))
		draw_arc(c, r, 0, TAU, 40, Color(0.6, 0.95, 1.0, 0.8), 2.5)
		var lines: PackedStringArray = String(b["label"]).split("\n")
		var fs := 17
		for i in lines.size():
			var w := _font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var y := c.y + fs * 0.35 + (i - (lines.size() - 1) * 0.5) * fs * 1.1
			draw_string(_font, Vector2(c.x - w * 0.5, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
