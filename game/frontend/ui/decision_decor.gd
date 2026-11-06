class_name DecisionDecor
extends Control
## Pieces of the soul fragment's decision card, drawn in code. VIGNETTE: dark edges over the
## night-blue veil. CARD: a dark card (gradient #1a1a24 -> #0d0d14) with burnt-paper edges and a
## faint blue rim, filling its panel. GEM: the fragment's crystal (GemDrawer), halo tinted by
## `tint`. Visual only, never takes input.

enum Mode { VIGNETTE, CARD, GEM }

@export var mode: Mode = Mode.CARD
var tint: Color = Color(0.6, 0.9, 1.0)
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	if mode == Mode.GEM:
		queue_redraw()


func _draw() -> void:
	match mode:
		Mode.VIGNETTE:
			var s: Vector2 = size
			var edge := Color(0, 0, 0, 0.75)
			var clear := Color(0, 0, 0, 0)
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.3), Vector2(0, s.y * 0.3)]), PackedColorArray([edge, edge, clear, clear]))
			draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.7), Vector2(s.x, s.y * 0.7), Vector2(s.x, s.y), Vector2(0, s.y)]), PackedColorArray([clear, clear, edge, edge]))
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.25, 0), Vector2(s.x * 0.25, s.y), Vector2(0, s.y)]), PackedColorArray([edge, clear, clear, edge]))
			draw_polygon(PackedVector2Array([Vector2(s.x * 0.75, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(s.x * 0.75, s.y)]), PackedColorArray([clear, edge, edge, clear]))
		Mode.CARD:
			_draw_card()
		Mode.GEM:
			GemDrawer.draw(self, Vector2(size.x * 0.5, size.y * 0.55), minf(size.y * 0.42, 70.0), _time, tint)


func _draw_card() -> void:
	var s: Vector2 = size
	var pts := PackedVector2Array()
	# Ragged burnt edge all the way round.
	var steps: int = 40
	for i in steps:
		var u: float = float(i) / float(steps)
		pts.append(Vector2(u * s.x, _burn(i) - 4.0))
	for i in steps:
		var u: float = float(i) / float(steps)
		pts.append(Vector2(s.x + 4.0 - _burn(i + 50), u * s.y))
	for i in steps:
		var u: float = float(i) / float(steps)
		pts.append(Vector2(s.x - u * s.x, s.y + 4.0 - _burn(i + 100)))
	for i in steps:
		var u: float = float(i) / float(steps)
		pts.append(Vector2(_burn(i + 150) - 4.0, s.y - u * s.y))
	var top := Color("1a1a24")
	var bottom := Color("0d0d14")
	var colors := PackedColorArray()
	for p in pts:
		colors.append(top.lerp(bottom, clampf(p.y / maxf(s.y, 1.0), 0.0, 1.0)))
	draw_polygon(pts, colors)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, Color(0.05, 0.03, 0.02), 5.0, true)
	draw_polyline(closed, Color(0.35, 0.55, 1.0, 0.45), 1.6, true)
	# Scorch marks near the corners.
	for c in [Vector2(10, 10), Vector2(s.x - 12, 14), Vector2(14, s.y - 12), Vector2(s.x - 10, s.y - 10)]:
		draw_circle(c, 14.0, Color(0.0, 0.0, 0.0, 0.35))


func _burn(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return (v - floorf(v)) * 7.0
