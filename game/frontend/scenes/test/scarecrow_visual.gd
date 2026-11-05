@tool
class_name ScarecrowVisual
extends Node2D
## Practice target of the tutorial drawn in code: a straw scarecrow on a post, a sack for a head
## with stitched X eyes and a stitched grin, a patched shirt leaking straw. Visual only: the
## TrainingDummy's hurtbox and health are untouched. Origin at the foot of the post.
## `kick()` makes it wobble when hit; `set_broken(true)` slumps it once it is "dead".

const INK := Color(0.106, 0.098, 0.122)
const WOOD := Color(0.45, 0.32, 0.2)
const SACK := Color(0.7, 0.6, 0.42)
const SHIRT := Color(0.47, 0.3, 0.25)
const STRAW := Color(0.8, 0.7, 0.4)
const STRAW_DARK := Color(0.62, 0.52, 0.27)
const DIRT := Color(0.38, 0.28, 0.18)

var _time: float = 0.0
var _wobble: float = 0.0
var _wobble_v: float = 0.0
var _broken: bool = false
var _slump: float = 0.0


## A hit: the post rocks back and forth for a moment.
func kick(strength: float = 1.0) -> void:
	_wobble_v += 3.2 * strength


func set_broken(value: bool) -> void:
	_broken = value


func _process(delta: float) -> void:
	_time += delta
	# Damped spring back to upright.
	_wobble_v += (-_wobble * 60.0 - _wobble_v * 7.0) * delta
	_wobble += _wobble_v * delta
	_slump = move_toward(_slump, 1.0 if _broken else 0.0, delta * 2.5)
	queue_redraw()


func _draw() -> void:
	var lean: float = sin(_time * 1.3) * 0.015 + _wobble * 0.18 + _slump * 0.22
	draw_set_transform(Vector2.ZERO, lean, Vector2.ONE)
	# Post and crossbar.
	_stroke(Vector2(0, 6), Vector2(0, -80), 7.0, WOOD)
	_stroke(Vector2(-25, -47), Vector2(25, -49), 5.0, WOOD)
	for p in [Vector2(-1, -30), Vector2(1, -8)]:
		draw_line(p, p + Vector2(2, 3), Color(INK, 0.6), 1.0, true)
	# Straw legs hanging from the shirt.
	for i in 7:
		var x: float = -9.0 + i * 3.0
		var sway: float = sin(_time * 2.0 + i) * 0.8
		_stroke(Vector2(x, -20), Vector2(x + sway + (i - 3) * 0.6, -8.0 + (i % 3) * 2.0), 1.8, STRAW if i % 2 == 0 else STRAW_DARK)
	# Patched shirt with a torn hem.
	var shirt := PackedVector2Array([Vector2(-14, -52), Vector2(14, -52), Vector2(13, -19), Vector2(9, -22), Vector2(6, -18),
			Vector2(1, -21), Vector2(-3, -17.5), Vector2(-7, -21), Vector2(-11, -18.5), Vector2(-13, -21)])
	_shape(shirt, SHIRT)
	for x in [-8.0, -2.0, 4.0, 10.0]:
		draw_line(Vector2(x, -51), Vector2(x - 0.5, -21), Color(0.3, 0.17, 0.15, 0.7), 1.2, true)
	for y in [-44.0, -34.0, -26.0]:
		draw_line(Vector2(-13.5, y), Vector2(13.5, y), Color(0.3, 0.17, 0.15, 0.7), 1.2, true)
	_patch(Vector2(-6, -38), 3.6, Color(0.52, 0.5, 0.38), 0.2)
	_patch(Vector2(7, -29), 3.0, Color(0.36, 0.4, 0.46), -0.3)
	draw_colored_polygon(_blob(Vector2(3, -44), Vector2(3.0, 2.2), 7), Color(DIRT, 0.4))
	# Sleeves along the crossbar, straw bursting from the cuffs.
	for side in [-1.0, 1.0]:
		var s: float = side
		var sleeve := PackedVector2Array([Vector2(s * 12, -52), Vector2(s * 22, -51.5), Vector2(s * 22, -44), Vector2(s * 12, -42)])
		if s < 0.0:
			sleeve.reverse()
		_shape(sleeve, SHIRT.darkened(0.08))
		for k in 4:
			var root := Vector2(s * 22.5, -50.5 + k * 2.0)
			_stroke(root, root + Vector2(s * (4.0 + (k % 2) * 2.0), (k - 1.5) * 1.6 + sin(_time * 2.4 + k) * 0.5), 1.6, STRAW)
	# Straw at the neck.
	for k in 5:
		var root := Vector2(-4.0 + k * 2.0, -52)
		_stroke(root, root + Vector2((k - 2) * 1.4, -4.0 - (k % 2) * 1.5), 1.5, STRAW)
	# Sack head tied with a rope, drooping when broken.
	var head := Vector2(0, -63)
	var droop: float = _slump * 0.5
	draw_set_transform(Vector2.ZERO, lean, Vector2.ONE)
	var sack := PackedVector2Array()
	for i in 18:
		var a: float = TAU * float(i) / 18.0
		var r: float = 11.0 + (0.8 if i % 3 == 0 else 0.0)
		sack.append(head + Vector2(cos(a) * r, sin(a) * r * 0.95).rotated(droop))
	_shape(sack, SACK)
	draw_line(head + Vector2(-8, 8).rotated(droop), head + Vector2(8, 8.5).rotated(droop), INK, 3.6, true)
	draw_line(head + Vector2(-8, 8).rotated(droop), head + Vector2(8, 8.5).rotated(droop), Color(0.66, 0.55, 0.35), 1.8, true)
	draw_line(head + Vector2(8, 8.5).rotated(droop), head + Vector2(11, 13).rotated(droop), Color(0.66, 0.55, 0.35), 1.6, true)
	# Burlap weave and a seam.
	for k in 3:
		var y: float = -6.0 + k * 5.0
		draw_line(head + Vector2(-9, y).rotated(droop), head + Vector2(9, y + 0.5).rotated(droop), Color(INK, 0.18), 0.8, true)
	draw_line(head + Vector2(-6, -9).rotated(droop), head + Vector2(-9, 2).rotated(droop), Color(INK, 0.4), 1.0, true)
	# Stitched X eyes and a stitched grin.
	for e in [Vector2(-4, -2.5), Vector2(4.5, -3)]:
		var c: Vector2 = head + (e as Vector2).rotated(droop)
		draw_line(c + Vector2(-2.2, -2.2), c + Vector2(2.2, 2.2), INK, 1.8, true)
		draw_line(c + Vector2(-2.2, 2.2), c + Vector2(2.2, -2.2), INK, 1.8, true)
	var grin := PackedVector2Array()
	for i in 7:
		var x: float = -5.0 + i * 1.7
		grin.append(head + Vector2(x, 4.0 + sin(i * 1.1) * 0.6 - absf(x) * 0.12).rotated(droop))
	draw_polyline(grin, INK, 1.4, true)
	for i in 4:
		var p: Vector2 = grin[1 + i]
		draw_line(p + Vector2(0, -1.4), p + Vector2(0, 1.4), INK, 1.0, true)
	# Straw poking out of the top of the sack.
	for k in 4:
		var root: Vector2 = head + Vector2(-4.0 + k * 2.6, -10.0).rotated(droop)
		_stroke(root, root + Vector2((k - 1.5) * 1.6, -4.5).rotated(droop + sin(_time * 1.8 + k) * 0.08), 1.6, STRAW)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _shape(points: PackedVector2Array, fill: Color, width: float = 2.6) -> void:
	draw_colored_polygon(points, fill)
	var outline := PackedVector2Array()
	for i in points.size():
		var p: Vector2 = points[i]
		outline.append(p + Vector2(sin(p.x * 1.7 + p.y * 0.9 + i * 2.3), cos(p.y * 1.3 - p.x * 0.7 + i * 1.7)) * 0.35)
	outline.append(outline[0])
	draw_polyline(outline, INK, width, true)


func _stroke(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, INK, width + 2.4, true)
	draw_line(a, b, color, width, true)


func _patch(at: Vector2, s: float, color: Color, rot: float) -> void:
	var pts := PackedVector2Array()
	for v in [Vector2(-s, -s), Vector2(s, -s * 0.9), Vector2(s * 1.05, s), Vector2(-s * 0.95, s * 1.05)]:
		pts.append(at + (v as Vector2).rotated(rot))
	_shape(pts, color, 1.5)
	for i in 4:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % 4]
		var n: Vector2 = (b - a).orthogonal().normalized()
		var m: Vector2 = a.lerp(b, 0.5)
		draw_line(m - n * 1.0, m + n * 1.0, INK, 0.9, true)


func _blob(c: Vector2, r: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		var k: float = 0.8 + 0.25 * absf(sin(i * 2.7))
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
	return pts
