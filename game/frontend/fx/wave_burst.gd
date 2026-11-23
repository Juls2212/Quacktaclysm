class_name WaveBurst
extends Node2D
## The short burst where a sword wave hits something (Phase 15d-bis), in the colors of the wave tier: a ring that opens,
## a few sparks and a flash of the rim color. It frees itself after `LIFETIME` seconds. Presentation only.

const LIFETIME: float = 0.35

var glow_color: Color = Color(0.65, 0.85, 1.0)
var rim_color: Color = Color(1.0, 1.0, 1.0)
var core_color: Color = Color(0.0, 0.0, 0.0, 0.0)
var scale_factor: float = 1.0

var _age: float = 0.0


func _ready() -> void:
	z_index = 5
	var timer: SceneTreeTimer = get_tree().create_timer(LIFETIME)
	timer.timeout.connect(queue_free)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_age / LIFETIME, 0.0, 1.0)
	var fade: float = 1.0 - t
	var radius: float = (10.0 + 30.0 * t) * scale_factor
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(glow_color, 0.85 * fade), 4.0 * fade + 1.0, true)
	draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 24, Color(rim_color, 0.7 * fade), 2.0, true)
	if core_color.a > 0.0:
		draw_circle(Vector2.ZERO, radius * 0.35, Color(core_color, 0.7 * fade))
	for i in 8:
		var angle: float = float(i) * TAU / 8.0 + 0.4
		var inner: Vector2 = Vector2(cos(angle), sin(angle)) * radius * 0.8
		var outer: Vector2 = Vector2(cos(angle), sin(angle)) * (radius + 12.0 * scale_factor * (1.0 - t))
		draw_line(inner, outer, Color(rim_color, 0.9 * fade), 2.0, true)
