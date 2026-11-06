@tool
class_name DebrisSkin
extends Node2D
## Salvaged look for a tutorial platform, drawn over (never instead of) its collision box: broken
## planks nailed together, a rusty steel girder snapped at one end, or a concrete slab with rebar
## sticking out. Its top edge is the walkable top of the box (`size`, centered on the origin).
## `prize` sets a small glowing star on top (decoration only). Visual only, no collision.

enum Look { PLANKS, GIRDER, SLAB }

const INK := Color(0.106, 0.098, 0.122)

@export var size: Vector2 = Vector2(160, 24):
	set(value):
		size = value
		queue_redraw()
@export var look: Look = Look.PLANKS:
	set(value):
		look = value
		queue_redraw()
@export var prize: bool = false

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	if prize:
		queue_redraw()


func _draw() -> void:
	var half: Vector2 = size * 0.5
	match look:
		Look.PLANKS:
			_planks(half)
		Look.GIRDER:
			_girder(half)
		Look.SLAB:
			_slab(half)
	if prize:
		_prize_star(Vector2(0, -half.y - 22.0 + sin(_time * 2.2) * 3.0))


func _planks(half: Vector2) -> void:
	# Two crossbeams underneath, then boards of uneven length with snapped ends.
	for x in [-half.x * 0.6, half.x * 0.55]:
		_shape(PackedVector2Array([Vector2(x - 5, -half.y + 4), Vector2(x + 5, -half.y + 4), Vector2(x + 7, half.y + 14), Vector2(x - 3, half.y + 16)]),
				Color(0.38, 0.27, 0.17), 2.2)
	var boards: int = maxi(int(size.x / 34.0), 2)
	var w: float = size.x / float(boards)
	for i in boards:
		var x0: float = -half.x + w * float(i) + 1.0
		var x1: float = x0 + w - 2.0
		var drop: float = (_h(i) - 0.5) * 2.0
		var pts := PackedVector2Array([Vector2(x0, -half.y + drop), Vector2(x1, -half.y + drop * 0.5), Vector2(x1, half.y - 2.0)])
		if i == boards - 1:
			# Snapped end: a jagged edge.
			pts = PackedVector2Array([Vector2(x0, -half.y + drop), Vector2(x1 + 4.0, -half.y + 2.0), Vector2(x1 - 2.0, -half.y + 8.0),
					Vector2(x1 + 3.0, half.y - 6.0), Vector2(x1 - 4.0, half.y - 2.0)])
		pts.append(Vector2(x0, half.y - 2.0 + drop * 0.3))
		var wood: Color = Color(0.58, 0.42, 0.27).darkened(0.08 * float(i % 3))
		_shape(pts, wood, 2.2)
		draw_line(Vector2(x0 + 3, -half.y + 7), Vector2(x1 - 4, -half.y + 8), Color(0.35, 0.24, 0.14, 0.7), 1.2, true)
		draw_circle(Vector2(x0 + 5, -half.y + 4), 1.6, INK)
	draw_line(Vector2(-half.x, -half.y), Vector2(half.x, -half.y), INK, 3.0, true)


func _girder(half: Vector2) -> void:
	var rust := Color(0.5, 0.3, 0.2)
	var flange_h: float = 6.0
	var top := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x - 10, -half.y), Vector2(half.x, -half.y + 3), Vector2(half.x - 6, -half.y + flange_h), Vector2(-half.x, -half.y + flange_h)])
	var web := PackedVector2Array([Vector2(-half.x + 2, -half.y + flange_h), Vector2(half.x - 14, -half.y + flange_h), Vector2(half.x - 8, half.y - flange_h), Vector2(-half.x + 2, half.y - flange_h)])
	var bottom := PackedVector2Array([Vector2(-half.x, half.y - flange_h), Vector2(half.x - 16, half.y - flange_h), Vector2(half.x - 12, half.y), Vector2(-half.x, half.y)])
	_shape(web, rust.darkened(0.2), 2.0)
	_shape(bottom, rust, 2.2)
	_shape(top, rust.lightened(0.08), 2.2)
	for k in int(size.x / 26.0):
		var x: float = -half.x + 12.0 + float(k) * 26.0
		draw_circle(Vector2(x, -half.y + 3), 1.4, Color(0.82, 0.7, 0.55))
		draw_line(Vector2(x, -half.y + flange_h + 1), Vector2(x + 6, half.y - flange_h - 1), Color(INK, 0.35), 1.2, true)
	for k in 3:
		var p := Vector2(-half.x * 0.6 + float(k) * half.x * 0.5, 0)
		draw_circle(p, 2.4, Color(0.7, 0.38, 0.16, 0.6))
	# Bent rebar sticking out of the broken end.
	draw_line(Vector2(half.x - 6, -half.y + 4), Vector2(half.x + 10, -half.y - 6), INK, 2.0, true)
	draw_line(Vector2(half.x - 8, half.y - 4), Vector2(half.x + 8, half.y + 6), INK, 2.0, true)


func _slab(half: Vector2) -> void:
	var pts := PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x + 2, -half.y + 8), Vector2(half.x - 6, half.y),
			Vector2(-half.x * 0.2, half.y + 6), Vector2(-half.x + 6, half.y + 2), Vector2(-half.x - 3, -half.y + 10)])
	_shape(pts, Color(0.55, 0.53, 0.5), 2.4)
	draw_line(Vector2(-half.x * 0.3, -half.y + 2), Vector2(-half.x * 0.1, half.y - 2), Color(INK, 0.6), 1.4, true)
	draw_line(Vector2(half.x * 0.4, -half.y + 3), Vector2(half.x * 0.5, 0), Color(INK, 0.5), 1.2, true)
	for k in 2:
		var x: float = -half.x * 0.5 + float(k) * half.x
		draw_line(Vector2(x, half.y), Vector2(x + 4, half.y + 14), INK, 2.0, true)
	draw_rect(Rect2(Vector2(-half.x, -half.y), Vector2(size.x, 4)), Color(0.66, 0.63, 0.58))


## The reward up high: a little star bobbing and glowing (decoration only).
func _prize_star(c: Vector2) -> void:
	var pulse: float = 0.75 + 0.25 * sin(_time * 3.0)
	for k in 4:
		draw_circle(c, 10.0 + float(k) * 7.0, Color(1.0, 0.85, 0.4, 0.06 * pulse))
	var pts := PackedVector2Array()
	for i in 10:
		var r: float = 11.0 if i % 2 == 0 else 4.6
		pts.append(c + Vector2.from_angle(TAU * float(i) / 10.0 - PI * 0.5 + sin(_time * 1.3) * 0.15) * r)
	_shape(pts, Color(1.0, 0.86, 0.4), 2.0)
	draw_circle(c, 2.6, Color(1, 1, 0.9))


func _shape(pts: PackedVector2Array, fill: Color, width: float) -> void:
	draw_colored_polygon(pts, fill)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, INK, width, true)


func _h(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)
