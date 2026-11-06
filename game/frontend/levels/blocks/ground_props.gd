@tool
class_name GroundProps
extends Node2D
## Junk along the tutorial floor, drawn in ink: crates, barrels, broken fences and old signs with
## arrows and symbols (no words). Origin on the floor's top edge; `props` lists [kind, x].
## Visual only, no collision.

const INK := Color(0.106, 0.098, 0.122)

@export var props: Array = [
	["crate", 250.0], ["barrel", 292.0], ["fence", 560.0], ["sign_arrow", 720.0], ["crates", 1080.0],
	["barrel", 1300.0], ["fence", 1580.0], ["sign_skull", 1830.0], ["crate", 2120.0], ["sign_arrow", 2200.0],
]


func _draw() -> void:
	for p in props:
		var x: float = float(p[1])
		match String(p[0]):
			"crate":
				_crate(Vector2(x, 0), 30.0, 0.0)
			"crates":
				_crate(Vector2(x, 0), 34.0, 0.0)
				_crate(Vector2(x + 36, 0), 28.0, 0.05)
				_crate(Vector2(x + 14, -34), 26.0, -0.12)
			"barrel":
				_barrel(Vector2(x, 0))
			"fence":
				_fence(x)
			"sign_arrow":
				_sign(Vector2(x, 0), 0)
			"sign_skull":
				_sign(Vector2(x, 0), 1)


func _crate(base: Vector2, s: float, tilt: float) -> void:
	var c: Vector2 = base + Vector2(0, -s * 0.5)
	var pts := PackedVector2Array()
	for v in [Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)]:
		pts.append(c + ((v as Vector2) * 0.5).rotated(tilt))
	_shape(pts, Color(0.55, 0.4, 0.25), 2.4)
	draw_line(pts[0], pts[2], Color(0.35, 0.24, 0.14), 2.2, true)
	draw_line(c + Vector2(-s * 0.5, 0).rotated(tilt), c + Vector2(s * 0.5, 0).rotated(tilt), Color(0.35, 0.24, 0.14), 1.6, true)


func _barrel(base: Vector2) -> void:
	var pts := PackedVector2Array([base + Vector2(-13, 0), base + Vector2(-15, -20), base + Vector2(-13, -40), base + Vector2(13, -40), base + Vector2(15, -20), base + Vector2(13, 0)])
	_shape(pts, Color(0.42, 0.24, 0.16), 2.4)
	for y in [-10.0, -30.0]:
		draw_line(base + Vector2(-14.5, y), base + Vector2(14.5, y), Color(0.25, 0.22, 0.2), 3.0, true)
	draw_circle(base + Vector2(4, -22), 3.0, Color(0.7, 0.38, 0.16, 0.6))


func _fence(x0: float) -> void:
	var tops: Array[Vector2] = []
	for i in 6:
		var x: float = x0 + float(i) * 26.0
		var lean: float = (sin(float(i) * 2.3) - 0.2) * 0.25
		if i == 3:
			continue
		var foot := Vector2(x, 2)
		var top: Vector2 = foot + Vector2.from_angle(-PI * 0.5 + lean) * (36.0 + float(i % 2) * 6.0)
		draw_line(foot, top, INK, 6.0, true)
		draw_line(foot, top, Color(0.5, 0.38, 0.26), 3.4, true)
		tops.append(top)
	for i in tops.size() - 1:
		if i == 1:
			continue
		var a: Vector2 = tops[i].lerp(Vector2(tops[i].x, 0), 0.3)
		var b: Vector2 = tops[i + 1].lerp(Vector2(tops[i + 1].x, 0), 0.3)
		draw_line(a, b, INK, 5.0, true)
		draw_line(a, b, Color(0.5, 0.38, 0.26), 2.6, true)


func _sign(base: Vector2, symbol: int) -> void:
	draw_line(base + Vector2(0, 2), base + Vector2(2, -54), INK, 6.0, true)
	draw_line(base + Vector2(0, 2), base + Vector2(2, -54), Color(0.45, 0.32, 0.2), 3.4, true)
	var board := PackedVector2Array([base + Vector2(-22, -70), base + Vector2(24, -73), base + Vector2(26, -48), base + Vector2(-20, -46)])
	_shape(board, Color(0.62, 0.52, 0.36), 2.4)
	var c: Vector2 = base + Vector2(2, -60)
	if symbol == 0:
		# Arrow to the right: this way.
		draw_line(c + Vector2(-12, 0), c + Vector2(10, -1), Color(0.6, 0.16, 0.1), 4.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(8, -7), c + Vector2(16, -1), c + Vector2(8, 5)]), Color(0.6, 0.16, 0.1))
	else:
		# A crude skull: danger ahead.
		draw_circle(c + Vector2(0, -2), 7.0, Color(0.9, 0.86, 0.74))
		draw_circle(c + Vector2(-3, -3), 1.8, INK)
		draw_circle(c + Vector2(3, -3), 1.8, INK)
		draw_line(c + Vector2(-4, 5), c + Vector2(4, 5), Color(0.9, 0.86, 0.74), 3.0, true)


func _shape(pts: PackedVector2Array, fill: Color, width: float) -> void:
	draw_colored_polygon(pts, fill)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, INK, width, true)
