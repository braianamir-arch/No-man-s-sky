extends Node
## Puente entre los controles (tactiles o raton) y la jugabilidad.

## Vector del joystick virtual (x = derecha, y = adelante), longitud <= 1.
var move_vector := Vector2.ZERO
## Desplazamiento de camara acumulado en pixeles (raton o arrastre tactil).
var _look_delta := Vector2.ZERO


func add_look(delta: Vector2) -> void:
	_look_delta += delta


func consume_look() -> Vector2:
	var d := _look_delta
	_look_delta = Vector2.ZERO
	return d


func get_move() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_back", "move_forward") + move_vector
	return v.limit_length(1.0)
