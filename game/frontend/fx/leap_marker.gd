class_name LeapMarker
extends Node2D
## The landing marker of a leaping boss (Phase 15c): a ring and a cross on the floor spot where it will come
## down, pulsing so it reads as a warning, over a dark outline so it shows on any ground. Colors and radius come
## from a TelegraphStyle (the boss_leap entry of default_telegraphs.tres). Presentation only: the visual that
## owns it shows and hides it from the pattern signal `marker_changed`.

var style: TelegraphStyle = null
var shown: bool = false

var _time: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = -1
	visible = false


func show_marker(world_position: Vector2, new_style: TelegraphStyle) -> void:
	style = new_style
	shown = true
	global_position = world_position
	visible = true
	queue_redraw()


func hide_marker() -> void:
	shown = false
	visible = false


func _process(delta: float) -> void:
	if shown:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if not shown or style == null:
		return
	var radius: float = style.size
	var pulse: float = 0.5 + 0.5 * sin(_time * 12.0)
	# A flat ellipse on the floor (the ground is seen from the side).
	var squash: float = 0.32
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, radius, Color(style.color, 0.12 + 0.14 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, style.outline_color, style.width + 3.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, style.color, style.width, true)
	draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 32, Color(style.color, 0.6 + 0.3 * pulse), style.width * 0.6, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(radius * 0.25 * side, -4.0), Vector2(radius * 0.7 * side, -4.0), style.outline_color, style.width + 2.0)
		draw_line(Vector2(radius * 0.25 * side, -4.0), Vector2(radius * 0.7 * side, -4.0), style.color, style.width - 1.0)
