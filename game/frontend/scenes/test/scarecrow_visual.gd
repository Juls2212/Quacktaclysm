@tool
class_name ScarecrowVisual
extends Node2D
## Practice target of the tutorial drawn in code: a straw scarecrow on a post and crossbar, a sewn
## sack for a head with button and stitched-X eyes and a stitched grin, an old torn hat, a torn
## plaid shirt with patches and a rope belt, straw poking out of the neck, sleeves and boots, and a
## crow perched on one arm. Visual only: the TrainingDummy's hurtbox and health are untouched.
## `kick()` (a hit) rocks it, sheds straw and a feather and leaves a new cut or patch; the crow
## flies off at the first hit. `set_broken(true)` slumps it; after a moment it stands back up.
## Origin at the foot of the post.

const INK := Color(0.106, 0.098, 0.122)
const WOOD := Color(0.45, 0.32, 0.2)
const SACK := Color(0.72, 0.61, 0.42)
const SHIRT := Color(0.52, 0.2, 0.17)
const SHIRT_LINE := Color(0.28, 0.1, 0.09)
const STRAW := Color(0.82, 0.71, 0.4)
const STRAW_DARK := Color(0.62, 0.52, 0.27)
const HAT := Color(0.3, 0.25, 0.2)
const DIRT := Color(0.38, 0.28, 0.18)
const CROW := Color(0.08, 0.08, 0.1)

var _time: float = 0.0
var _wobble: float = 0.0
var _wobble_v: float = 0.0
var _broken: bool = false
var _broken_for: float = 0.0
var _slump: float = 0.0
var _hits: int = 0
var _debris: Array[Dictionary] = []
var _crow_gone: bool = false
var _crow_t: float = -1.0


## A hit: rocks the post, sheds straw and a feather, leaves a cut or patch; scares off the crow.
func kick(strength: float = 1.0) -> void:
	_wobble_v += 3.4 * strength
	_hits += 1
	for i in 7:
		_debris.append({"p": Vector2(randf_range(-12, 12), randf_range(-60, -30)), "v": Vector2(randf_range(-90, 90), randf_range(-160, -40)),
				"life": 1.2, "rot": randf() * TAU, "feather": i == 0})
	if not _crow_gone:
		_crow_gone = true
		_crow_t = 0.0


func set_broken(value: bool) -> void:
	_broken = value
	_broken_for = 0.0


func _process(delta: float) -> void:
	_time += delta
	_wobble_v += (-_wobble * 60.0 - _wobble_v * 7.0) * delta
	_wobble += _wobble_v * delta
	# Slumps when "dead", then after a moment drags itself upright again (visual only).
	if _broken:
		_broken_for += delta
	var down: bool = _broken and _broken_for < 2.6
	_slump = move_toward(_slump, 1.0 if down else 0.0, delta * (2.5 if down else 1.2))
	for d in _debris:
		d["v"] += Vector2(0, 260) * delta
		d["p"] += d["v"] * delta
		d["rot"] += delta * 4.0
		d["life"] -= delta
	_debris = _debris.filter(func(d: Dictionary) -> bool: return d["life"] > 0.0)
	if _crow_t >= 0.0:
		_crow_t += delta
	queue_redraw()


func _draw() -> void:
	var lean: float = sin(_time * 1.3) * 0.015 + _wobble * 0.18 + _slump * 0.5
	draw_set_transform(Vector2.ZERO, lean, Vector2.ONE)
	# Post and crossbar with a nail and grain.
	_stroke(Vector2(0, 6), Vector2(0, -82), 7.0, WOOD)
	_stroke(Vector2(-27, -48), Vector2(27, -50), 5.0, WOOD)
	for p in [Vector2(-1, -30), Vector2(1, -10)]:
		draw_line(p, p + Vector2(2, 4), Color(INK, 0.6), 1.0, true)
	draw_circle(Vector2(0, -49), 1.6, INK)
	# Straw legs and boots.
	for side in [-1.0, 1.0]:
		var s: float = side
		var knee := Vector2(s * 5.0, -10.0)
		_stroke(Vector2(s * 4.0, -20), knee, 5.0, Color(0.36, 0.3, 0.24))
		var boot := PackedVector2Array([knee + Vector2(-5, 0), knee + Vector2(5, 0), knee + Vector2(6 + s * 4.0, 8), knee + Vector2(-6 + s * 2.0, 9)])
		_shape(boot, Color(0.24, 0.17, 0.12), 2.0)
		for k in 3:
			_stroke(knee + Vector2(float(k - 1) * 3.0, 0), knee + Vector2(float(k - 1) * 4.0 + s * 2.0, -6.0 - float(k)), 1.4, STRAW)
	# Torn plaid shirt with patches and a rope belt.
	var shirt := PackedVector2Array([Vector2(-14, -53), Vector2(14, -53), Vector2(13, -19), Vector2(9, -22), Vector2(6, -18),
			Vector2(1, -21), Vector2(-3, -17.5), Vector2(-7, -21), Vector2(-11, -18.5), Vector2(-13, -21)])
	_shape(shirt, SHIRT)
	for x in [-9.0, -3.0, 3.0, 9.0]:
		draw_line(Vector2(x, -52), Vector2(x - 0.5, -21), Color(SHIRT_LINE, 0.8), 1.4, true)
	for y in [-46.0, -38.0, -30.0]:
		draw_line(Vector2(-13.5, y), Vector2(13.5, y), Color(SHIRT_LINE, 0.8), 1.4, true)
	_patch(Vector2(-6, -40), 3.4, Color(0.5, 0.48, 0.36), 0.2)
	_patch(Vector2(7, -31), 2.8, Color(0.34, 0.38, 0.44), -0.3)
	draw_colored_polygon(_blob(Vector2(3, -45), Vector2(3.0, 2.2), 7), Color(DIRT, 0.4))
	_stroke(Vector2(-13, -26), Vector2(13, -25), 2.4, Color(0.7, 0.6, 0.4))
	_stroke(Vector2(2, -25.5), Vector2(4, -18), 1.6, Color(0.7, 0.6, 0.4))
	# Fresh damage, one mark per hit (cuts and patches).
	for i in mini(_hits, 6):
		var at := Vector2(-9.0 + float(i % 3) * 8.0, -48.0 + float(i / 3) * 12.0)
		if i % 2 == 0:
			draw_line(at, at + Vector2(5, 3), INK, 1.6, true)
			for k in 2:
				var m: Vector2 = at.lerp(at + Vector2(5, 3), 0.33 + 0.33 * float(k))
				draw_line(m + Vector2(-1, 1.5), m + Vector2(1, -1.5), Color(0.9, 0.85, 0.7), 1.0, true)
		else:
			_patch(at + Vector2(2, 1), 2.4, Color(0.62, 0.55, 0.3), 0.4)
	# Sleeves along the crossbar, straw bursting from the cuffs.
	for side in [-1.0, 1.0]:
		var s: float = side
		var sleeve := PackedVector2Array([Vector2(s * 12, -53), Vector2(s * 23, -52.5), Vector2(s * 23, -44), Vector2(s * 12, -42)])
		_shape(sleeve, SHIRT.darkened(0.08))
		draw_line(Vector2(s * 17, -53), Vector2(s * 17, -42), Color(SHIRT_LINE, 0.8), 1.2, true)
		for k in 4:
			var root := Vector2(s * 23.5, -51.5 + float(k) * 2.2)
			_stroke(root, root + Vector2(s * (4.0 + float(k % 2) * 2.5), (float(k) - 1.5) * 1.6 + sin(_time * 2.4 + float(k)) * 0.5), 1.6, STRAW)
	for k in 5:
		var root := Vector2(-4.0 + float(k) * 2.0, -53)
		_stroke(root, root + Vector2((float(k) - 2.0) * 1.4, -4.0 - float(k % 2) * 1.5), 1.5, STRAW)
	# Sack head (drooping when slumped), tied with a rope.
	var head := Vector2(0, -64)
	var droop: float = _slump * 0.6
	var sack := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		var r: float = 11.0 + (0.8 if i % 3 == 0 else 0.0)
		sack.append(head + Vector2(cos(a) * r, sin(a) * r * 0.95).rotated(droop))
	_shape(sack, SACK)
	for k in 3:
		var y: float = -6.0 + float(k) * 5.0
		draw_line(head + Vector2(-9, y).rotated(droop), head + Vector2(9, y + 0.5).rotated(droop), Color(INK, 0.16), 0.8, true)
	draw_line(head + Vector2(-6, -9).rotated(droop), head + Vector2(-9, 2).rotated(droop), Color(INK, 0.45), 1.0, true)
	draw_line(head + Vector2(-8, 8).rotated(droop), head + Vector2(8, 8.5).rotated(droop), INK, 3.6, true)
	draw_line(head + Vector2(-8, 8).rotated(droop), head + Vector2(8, 8.5).rotated(droop), Color(0.66, 0.55, 0.35), 1.8, true)
	# One button eye, one stitched X, a stitched grin.
	var button: Vector2 = head + Vector2(-4, -2.5).rotated(droop)
	draw_circle(button, 3.0, INK)
	draw_circle(button, 2.2, Color(0.3, 0.32, 0.36))
	draw_line(button + Vector2(-0.8, -0.8), button + Vector2(0.8, 0.8), INK, 0.8, true)
	draw_line(button + Vector2(-0.8, 0.8), button + Vector2(0.8, -0.8), INK, 0.8, true)
	var xe: Vector2 = head + Vector2(4.5, -3).rotated(droop)
	draw_line(xe + Vector2(-2.2, -2.2), xe + Vector2(2.2, 2.2), INK, 1.8, true)
	draw_line(xe + Vector2(-2.2, 2.2), xe + Vector2(2.2, -2.2), INK, 1.8, true)
	var grin := PackedVector2Array()
	for i in 7:
		var x: float = -5.0 + float(i) * 1.7
		grin.append(head + Vector2(x, 4.0 + sin(float(i) * 1.1) * 0.6 - absf(x) * 0.12).rotated(droop))
	draw_polyline(grin, INK, 1.4, true)
	for i in 4:
		var p: Vector2 = grin[1 + i]
		draw_line(p + Vector2(0, -1.4), p + Vector2(0, 1.4), INK, 1.0, true)
	# Old torn hat.
	var brim := PackedVector2Array([head + Vector2(-16, -8).rotated(droop), head + Vector2(15, -10).rotated(droop),
			head + Vector2(13, -6.5).rotated(droop), head + Vector2(-14, -4.5).rotated(droop)])
	_shape(brim, HAT, 2.2)
	var crown := PackedVector2Array([head + Vector2(-8, -8).rotated(droop), head + Vector2(-7, -18).rotated(droop), head + Vector2(-1, -16.5).rotated(droop),
			head + Vector2(1, -19).rotated(droop), head + Vector2(7, -17).rotated(droop), head + Vector2(8, -9).rotated(droop)])
	_shape(crown, HAT.lightened(0.06), 2.2)
	draw_line(head + Vector2(-7.5, -11).rotated(droop), head + Vector2(7.8, -11.5).rotated(droop), Color(0.5, 0.2, 0.15), 2.0, true)
	for k in 3:
		var root: Vector2 = head + Vector2(-3.0 + float(k) * 3.0, -18.5).rotated(droop)
		_stroke(root, root + Vector2((float(k) - 1.0) * 1.8, -3.5).rotated(droop), 1.3, STRAW)
	_draw_crow()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Straw and feathers knocked loose (world-aligned, they just fall).
	for d in _debris:
		var p: Vector2 = d["p"]
		var a: float = clampf(float(d["life"]), 0.0, 1.0)
		var dir := Vector2.from_angle(float(d["rot"]))
		if bool(d["feather"]):
			var feather := PackedVector2Array([p - dir * 6.0, p + dir.orthogonal() * 2.0, p + dir * 6.0, p - dir.orthogonal() * 2.0])
			draw_colored_polygon(feather, Color(0.85, 0.82, 0.74, a))
			draw_line(p - dir * 6.0, p + dir * 6.0, Color(INK, a), 1.0, true)
		else:
			draw_line(p - dir * 4.0, p + dir * 4.0, Color(STRAW, a), 1.6, true)


## The crow on the right arm; flaps away and is gone at the first hit.
func _draw_crow() -> void:
	var perch := Vector2(20, -53)
	if _crow_t >= 1.6:
		return
	var p: Vector2 = perch
	var flap: float = 0.0
	if _crow_t >= 0.0:
		p = perch + Vector2(_crow_t * 120.0, -_crow_t * 150.0 - _crow_t * _crow_t * 40.0)
		flap = sin(_crow_t * 30.0)
	else:
		# Pecks and looks around now and then.
		flap = 0.0
		p.y += absf(sin(_time * 0.9)) * 0.6
	var body := PackedVector2Array([p + Vector2(-6, -4), p + Vector2(3, -6), p + Vector2(7, -3), p + Vector2(4, 1), p + Vector2(-5, 1), p + Vector2(-10, 3)])
	_shape(body, CROW, 1.4)
	draw_circle(p + Vector2(5, -8), 3.6, CROW)
	draw_colored_polygon(PackedVector2Array([p + Vector2(8, -9), p + Vector2(12, -7.5), p + Vector2(8, -6.5)]), Color(0.35, 0.33, 0.3))
	draw_circle(p + Vector2(6, -8.6), 0.8, Color(1.0, 0.85, 0.3))
	if _crow_t >= 0.0:
		var wing := PackedVector2Array([p + Vector2(-2, -4), p + Vector2(-8, -12 - flap * 6.0), p + Vector2(4, -5)])
		_shape(wing, CROW, 1.2)
	else:
		draw_line(p + Vector2(-1, 1), p + Vector2(-1, 3), INK, 1.0, true)
		draw_line(p + Vector2(2, 1), p + Vector2(2, 3), INK, 1.0, true)


func _shape(points: PackedVector2Array, fill: Color, width: float = 2.6) -> void:
	draw_colored_polygon(points, fill)
	var outline := PackedVector2Array()
	for i in points.size():
		var p: Vector2 = points[i]
		outline.append(p + Vector2(sin(p.x * 1.7 + p.y * 0.9 + float(i) * 2.3), cos(p.y * 1.3 - p.x * 0.7 + float(i) * 1.7)) * 0.35)
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
		var k: float = 0.8 + 0.25 * absf(sin(float(i) * 2.7))
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y) * k)
	return pts
