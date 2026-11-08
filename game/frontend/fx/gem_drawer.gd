class_name GemDrawer
extends RefCounted
## Draws a soul fragment's gem on any CanvasItem: a long crystal (long point up, short point down)
## cut in facets, white core to sky blue (#9fe8ff) to blue (#2c7fe0) to deep blue at the edges, a
## blue halo (tinted by the fragment), a hard point of light inside, curved threads of light
## turning around it and bright motes. `red` (0..1) turns it into the corrupted red gem and
## `crack` (0..1) splits it with black lines. Visual only.

const CORE := Color(1.0, 1.0, 1.0)
const SKY := Color("9fe8ff")
const BLUE := Color("2c7fe0")
const DEEP := Color(0.04, 0.14, 0.42)
const RED := Color("c2331f")
const INK := Color(0.106, 0.098, 0.122)


static func draw(canvas: CanvasItem, c: Vector2, s: float, time: float, tint: Color = Color(0.6, 0.9, 1.0), red: float = 0.0, crack: float = 0.0, spin: float = 0.0) -> void:
	var halo: Color = BLUE.lerp(tint, 0.35).lerp(RED, red)
	for k in 5:
		canvas.draw_circle(c, s * (0.6 + float(k) * 0.32), Color(halo, 0.07))
	# Threads of light curving around the gem.
	for k in 3:
		var pts := PackedVector2Array()
		var tilt: float = 0.5 + float(k) * 0.6
		var rot: float = time * (1.2 + float(k) * 0.4) + float(k) * 2.1
		for i in 18:
			var a: float = rot + float(i) / 17.0 * PI * 1.3
			pts.append(c + Vector2(cos(a) * s * (0.75 + 0.12 * float(k)), sin(a) * s * 0.3).rotated(tilt))
		canvas.draw_polyline(pts, Color(SKY.lerp(RED.lightened(0.3), red), 0.55), maxf(s * 0.025, 1.0), true)
	# The crystal: facets fanned from an inner point, lit from the middle out.
	var w: float = s * 0.34
	var outline: Array[Vector2] = [Vector2(0, -s), Vector2(w, -s * 0.12), Vector2(w * 0.7, s * 0.26), Vector2(0, s * 0.46),
			Vector2(-w * 0.7, s * 0.26), Vector2(-w, -s * 0.12)]
	var inner := Vector2(0, s * 0.06)
	var core_col: Color = CORE.lerp(Color(1.0, 0.75, 0.65), red)
	var mid_col: Color = SKY.lerp(Color(1.0, 0.45, 0.35), red)
	var edge_cols: Array[Color] = [BLUE.lerp(RED, red), DEEP.lerp(Color(0.3, 0.02, 0.03), red)]
	for i in outline.size():
		var a: Vector2 = outline[i].rotated(spin)
		var b: Vector2 = outline[(i + 1) % outline.size()].rotated(spin)
		var e0: Color = edge_cols[i % 2]
		var e1: Color = edge_cols[(i + 1) % 2]
		canvas.draw_polygon(PackedVector2Array([c + inner.rotated(spin), c + a, c + b]), PackedColorArray([mid_col, e0, e1]))
	# Facet edges and the outline.
	var closed := PackedVector2Array()
	for p in outline:
		closed.append(c + p.rotated(spin))
		canvas.draw_line(c + inner.rotated(spin), c + p.rotated(spin), Color(SKY.lerp(RED.lightened(0.4), red), 0.45), maxf(s * 0.015, 1.0), true)
	closed.append(c + outline[0].rotated(spin))
	canvas.draw_polyline(closed, Color(SKY.lerp(RED.lightened(0.2), red), 0.9), maxf(s * 0.03, 1.2), true)
	# The point of light inside, pulsing.
	var pulse: float = 0.8 + 0.2 * sin(time * 4.0)
	canvas.draw_circle(c + Vector2(0, s * 0.12).rotated(spin), s * 0.16 * pulse, Color(mid_col, 0.5))
	canvas.draw_circle(c + Vector2(0, s * 0.12).rotated(spin), s * 0.08, core_col)
	if crack > 0.0:
		var lines: Array = [[Vector2(-w * 0.6, -s * 0.3), Vector2(-w * 0.1, -s * 0.05), Vector2(w * 0.2, -s * 0.2), Vector2(w * 0.7, s * 0.1)],
				[Vector2(0, -s * 0.8), Vector2(w * 0.15, -s * 0.45), Vector2(-w * 0.1, -s * 0.1)],
				[Vector2(-w * 0.4, s * 0.2), Vector2(0, s * 0.05), Vector2(w * 0.3, s * 0.3)]]
		for line in lines:
			var pts := PackedVector2Array()
			for p in line:
				pts.append(c + (p as Vector2).rotated(spin))
			canvas.draw_polyline(pts, Color(INK, crack), maxf(s * 0.045, 1.4), true)
	# Bright motes drifting around it.
	for k in 7:
		var a: float = time * (0.6 + 0.1 * float(k)) + float(k) * 0.9
		var p: Vector2 = c + Vector2(cos(a) * s * (1.0 + 0.1 * float(k % 3)), sin(a * 1.3) * s * 0.7)
		canvas.draw_circle(p, maxf(s * 0.025, 1.0), Color(1.0, 1.0, 1.0, 0.6 + 0.4 * sin(time * 3.0 + float(k))))
