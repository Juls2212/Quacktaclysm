class_name SoulWisp
extends Node2D
## A few pale orbs that rise and fade where an enemy died: a small soul leaving the body, in the
## spirit of the fragment and exorcism effects. Drawn in code, visual only, frees itself.
## `SoulWisp.spawn(container, position)`.

const LIFETIME: float = 1.3
const RISE: float = 70.0

var tint: Color = Color(0.78, 0.92, 1.0)
var _age: float = 0.0


static func spawn(container: Node, at: Vector2, wisp_tint: Color = Color(0.78, 0.92, 1.0)) -> SoulWisp:
	if container == null or not container.is_inside_tree():
		return null
	var wisp := SoulWisp.new()
	wisp.name = "SoulWisp"
	wisp.tint = wisp_tint
	wisp.z_index = 6
	container.add_child(wisp)
	wisp.global_position = at
	return wisp


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = clampf(_age / LIFETIME, 0.0, 1.0)
	var fade: float = 1.0 - k * k
	for i in 3:
		var phase: float = float(i) * 2.1
		var delay: float = float(i) * 0.08
		var rise: float = maxf(k - delay, 0.0) * RISE * (1.0 + 0.25 * float(i))
		var at := Vector2(sin(_age * 5.0 + phase) * (6.0 + 3.0 * float(i)), -rise - 8.0 * float(i))
		var radius: float = 6.0 - 1.4 * float(i)
		draw_circle(at, radius * 2.4, Color(tint, 0.14 * fade))
		draw_circle(at, radius, Color(tint, 0.8 * fade))
		draw_circle(at + Vector2(-radius * 0.3, -radius * 0.3), radius * 0.35, Color(1, 1, 1, 0.9 * fade))
