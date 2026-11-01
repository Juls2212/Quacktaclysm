class_name InkType
extends RefCounted
## "Pato Tinta": Quacktaclysm's display typeface, drawn in code. Chunky capitals built from
## stroke skeletons, rendered as a stacked extrusion, an ink outline, the fill and a highlight,
## with a hand-cut wobble per letter. Lowercase input is set in capitals.
## Units: a capital is 10 units tall (y 0 = cap line, y 10 = baseline); `height` scales it.
## Covers A–Z, Ñ, Á É Í Ó Ú Ü, 0–9 and . , : ; ! ¡ ? ¿ - ' " ( ) / + and space.

const STROKE: float = 2.3
const SPACING: float = 1.5
const SPACE_WIDTH: float = 3.6

static var _glyphs: Dictionary = {}


## Look of a run of text. Colors follow the duck art: ink outline, warm fill, deep extrusion.
class Style:
	var fill: Color = Color(0.98, 0.83, 0.42)
	var extrude: Color = Color(0.42, 0.24, 0.14)
	var ink: Color = Color(0.106, 0.098, 0.122)
	var highlight: Color = Color(1.0, 0.97, 0.86, 0.75)
	## Depth of the extrusion in units (down-right).
	var depth: float = 0.9
	## 0 = rigid, 1 = full hand-cut tilt and bounce per letter.
	var wobble: float = 1.0
	## Units of vertical wave travelling along the word (animated with `time`).
	var wave: float = 0.0
	var time: float = 0.0


## Width in pixels of `text` at cap `height`.
static func measure(text: String, height: float) -> float:
	var u: float = height / 10.0
	var w: float = 0.0
	for ch in text.to_upper():
		w += _advance(ch)
	return maxf(w - SPACING, 0.0) * u


## Draws `text` on `canvas` with its cap line at `origin.y` and starting at `origin.x`.
static func draw(canvas: CanvasItem, text: String, origin: Vector2, height: float, style: Style) -> void:
	var u: float = height / 10.0
	var chars: String = text.to_upper()
	var passes: Array[int] = [0, 1, 2, 3]
	# Every pass runs over the whole word, so outlines of neighbours never cut into fills.
	for pass_index in passes:
		var x: float = 0.0
		for i in chars.length():
			var ch: String = chars[i]
			var glyph: Array = _glyph(ch)
			if not glyph.is_empty():
				var tilt: float = sin(float(i) * 2.17 + 0.6) * 0.055 * style.wobble
				var lift: float = sin(float(i) * 1.31 + 1.4) * 0.35 * style.wobble
				lift += sin(style.time * 3.0 - float(i) * 0.55) * style.wave
				# Tilt each letter about its own middle.
				var center := Vector2(float(glyph[0]) * 0.5, 5.0)
				var xf := Transform2D(tilt, Vector2.ONE, 0.0, origin + (Vector2(x, lift) + center) * u) * Transform2D(0.0, -center * u)
				_draw_glyph(canvas, glyph[1], xf, u, style, pass_index)
			x += _advance(ch)


static func _draw_glyph(canvas: CanvasItem, strokes: Array, xf: Transform2D, u: float, style: Style, pass_index: int) -> void:
	var w: float = STROKE * u
	var outline: float = maxf(0.55 * u, 1.5)
	for stroke in strokes:
		var pts := PackedVector2Array()
		for p in stroke:
			pts.append(xf * ((p as Vector2) * u))
		match pass_index:
			0:
				# Extrusion: the stroke repeated toward the lower right, outlined, like a cut block.
				var steps: int = maxi(int(style.depth * 3.0), 1)
				for s in range(steps, 0, -1):
					var off := Vector2(0.45, 0.65) * style.depth * u * float(s) / float(steps)
					_stroke(canvas, _shift(pts, off), w + outline * 2.0, style.ink)
					_stroke(canvas, _shift(pts, off), w, style.extrude)
			1:
				_stroke(canvas, pts, w + outline * 2.0, style.ink)
			2:
				_stroke(canvas, pts, w, style.fill)
			3:
				_stroke(canvas, _shift(pts, Vector2(-0.28, -0.32) * u), w * 0.28, style.highlight)


static func _stroke(canvas: CanvasItem, pts: PackedVector2Array, width: float, color: Color) -> void:
	# Separate segments (no mitre spikes on sharp corners like M or W) plus round joints and caps.
	for i in range(pts.size() - 1):
		canvas.draw_line(pts[i], pts[i + 1], color, width, true)
	for p in pts:
		canvas.draw_circle(p, width * 0.5, color)


static func _shift(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + off)
	return out


static func _advance(ch: String) -> float:
	if ch == " ":
		return SPACE_WIDTH + SPACING
	var glyph: Array = _glyph(ch)
	if glyph.is_empty():
		return SPACE_WIDTH + SPACING
	return float(glyph[0]) + STROKE + SPACING


static func _glyph(ch: String) -> Array:
	if _glyphs.is_empty():
		_build()
	return _glyphs.get(ch, [])


# =====================================================================================
# Glyph skeletons: [width, [stroke, stroke...]], each stroke an array of points.
# =====================================================================================

static func _build() -> void:
	var g: Dictionary = {}
	g["A"] = [7.0, [[Vector2(0, 10), Vector2(3.5, 0), Vector2(7, 10)], [Vector2(1.4, 6.4), Vector2(5.6, 6.4)]]]
	g["B"] = [6.0, [[Vector2(0, 10), Vector2(0, 0), Vector2(3.6, 0)] + _arc(3.6, 2.5, 2.4, 2.5, -90, 90) + [Vector2(0, 5)],
			[Vector2(0, 5), Vector2(3.8, 5)] + _arc(3.8, 7.5, 2.4, 2.5, -90, 90) + [Vector2(0, 10)]]]
	g["C"] = [6.4, [_arc(3.7, 5, 3.7, 5, -42, -318)]]
	g["D"] = [6.6, [[Vector2(0, 10), Vector2(0, 0), Vector2(2.4, 0)] + _arc(2.4, 5, 4.2, 5, -90, 90) + [Vector2(0, 10)]]]
	g["E"] = [5.4, [[Vector2(5.4, 0), Vector2(0, 0), Vector2(0, 10), Vector2(5.4, 10)], [Vector2(0, 5), Vector2(4.4, 5)]]]
	g["F"] = [5.4, [[Vector2(5.4, 0), Vector2(0, 0), Vector2(0, 10)], [Vector2(0, 5), Vector2(4.4, 5)]]]
	g["G"] = [6.8, [_arc(3.6, 5, 3.6, 5, -45, -360) + [Vector2(7.2, 7.2)], [Vector2(7.2, 5.4), Vector2(4.2, 5.4)]]]
	g["H"] = [6.4, [[Vector2(0, 0), Vector2(0, 10)], [Vector2(6.4, 0), Vector2(6.4, 10)], [Vector2(0, 5), Vector2(6.4, 5)]]]
	g["I"] = [1.0, [[Vector2(0.5, 0), Vector2(0.5, 10)]]]
	g["J"] = [5.0, [[Vector2(5, 0), Vector2(5, 7.5)] + _arc(2.5, 7.5, 2.5, 2.5, 0, 180)]]
	g["K"] = [6.0, [[Vector2(0, 0), Vector2(0, 10)], [Vector2(6, 0), Vector2(0, 6.2)], [Vector2(2.2, 4.2), Vector2(6, 10)]]]
	g["L"] = [5.0, [[Vector2(0, 0), Vector2(0, 10), Vector2(5, 10)]]]
	g["M"] = [8.0, [[Vector2(0, 10), Vector2(0, 0), Vector2(4, 6.6), Vector2(8, 0), Vector2(8, 10)]]]
	g["N"] = [6.4, [[Vector2(0, 10), Vector2(0, 0), Vector2(6.4, 10), Vector2(6.4, 0)]]]
	g["O"] = [7.4, [_arc(3.7, 5, 3.7, 5, 0, 360)]]
	g["P"] = [6.0, [[Vector2(0, 10), Vector2(0, 0), Vector2(3.4, 0)] + _arc(3.4, 2.8, 2.6, 2.8, -90, 90) + [Vector2(0, 5.6)]]]
	g["Q"] = [7.4, [_arc(3.7, 5, 3.7, 5, 0, 360), [Vector2(4.4, 6.9), Vector2(7.6, 10.4)]]]
	g["R"] = [6.0, [[Vector2(0, 10), Vector2(0, 0), Vector2(3.4, 0)] + _arc(3.4, 2.8, 2.6, 2.8, -90, 90) + [Vector2(0, 5.6)],
			[Vector2(2.8, 5.6), Vector2(6, 10)]]]
	g["S"] = [6.0, [_arc(3.0, 2.6, 2.9, 2.6, -15, -270) + _arc(3.0, 7.5, 3.0, 2.5, -90, 165)]]
	g["T"] = [6.4, [[Vector2(0, 0), Vector2(6.4, 0)], [Vector2(3.2, 0), Vector2(3.2, 10)]]]
	g["U"] = [6.4, [[Vector2(0, 0), Vector2(0, 6.8)] + _arc(3.2, 6.8, 3.2, 3.2, 180, 0) + [Vector2(6.4, 0)]]]
	g["V"] = [7.0, [[Vector2(0, 0), Vector2(3.5, 10), Vector2(7, 0)]]]
	g["W"] = [9.4, [[Vector2(0, 0), Vector2(2.3, 10), Vector2(4.7, 3.2), Vector2(7.1, 10), Vector2(9.4, 0)]]]
	g["X"] = [6.4, [[Vector2(0, 0), Vector2(6.4, 10)], [Vector2(6.4, 0), Vector2(0, 10)]]]
	g["Y"] = [6.4, [[Vector2(0, 0), Vector2(3.2, 5.2), Vector2(6.4, 0)], [Vector2(3.2, 5.2), Vector2(3.2, 10)]]]
	g["Z"] = [6.0, [[Vector2(0, 0), Vector2(6, 0), Vector2(0, 10), Vector2(6, 10)]]]
	g["0"] = [6.0, [_arc(3, 5, 3, 5, 0, 360)]]
	g["1"] = [3.0, [[Vector2(0, 2.2), Vector2(2.6, 0), Vector2(2.6, 10)]]]
	g["2"] = [6.0, [_arc(3, 3, 3, 3, -170, 25) + [Vector2(0, 10), Vector2(6, 10)]]]
	g["3"] = [6.0, [_arc(2.8, 2.6, 2.8, 2.6, -160, 90) + _arc(2.8, 7.5, 3.1, 2.5, -90, 160)]]
	g["4"] = [6.4, [[Vector2(5, 10), Vector2(5, 0), Vector2(0, 7), Vector2(6.4, 7)]]]
	g["5"] = [6.0, [[Vector2(5.8, 0), Vector2(0.6, 0), Vector2(0.3, 4.6)] + _arc(3, 7, 3, 3, -150, 150)]]
	g["6"] = [6.0, [_arc(3, 7, 3, 3, 0, 360), _arc(5.2, 7, 5.2, 6.6, 180, 250)]]
	g["7"] = [6.0, [[Vector2(0, 0), Vector2(6, 0), Vector2(2.2, 10)]]]
	g["8"] = [6.0, [_arc(3, 2.5, 2.6, 2.5, 0, 360), _arc(3, 7.4, 3, 2.6, 0, 360)]]
	g["9"] = [6.0, [_arc(3, 3, 3, 3, 0, 360), _arc(0.8, 3, 5.2, 6.6, 0, 70)]]
	g["."] = [1.0, [[Vector2(0.5, 9.6), Vector2(0.5, 9.7)]]]
	g[","] = [1.4, [[Vector2(1.0, 9.3), Vector2(0.2, 11.2)]]]
	g[":"] = [1.0, [[Vector2(0.5, 3.6), Vector2(0.5, 3.7)], [Vector2(0.5, 9.6), Vector2(0.5, 9.7)]]]
	g[";"] = [1.4, [[Vector2(0.9, 3.6), Vector2(0.9, 3.7)], [Vector2(1.0, 9.3), Vector2(0.2, 11.2)]]]
	g["!"] = [1.0, [[Vector2(0.5, 0), Vector2(0.5, 6.6)], [Vector2(0.5, 9.6), Vector2(0.5, 9.7)]]]
	g["¡"] = [1.0, [[Vector2(0.5, 0.3), Vector2(0.5, 0.4)], [Vector2(0.5, 3.4), Vector2(0.5, 10)]]]
	var question: Array = [_arc(2.7, 2.7, 2.7, 2.7, -170, 70) + [Vector2(2.7, 6.6)], [Vector2(2.7, 9.6), Vector2(2.7, 9.7)]]
	g["?"] = [5.4, question]
	g["¿"] = [5.4, _flip(question, 5.4)]
	g["-"] = [3.4, [[Vector2(0, 5.6), Vector2(3.4, 5.6)]]]
	g["+"] = [4.6, [[Vector2(0, 5.4), Vector2(4.6, 5.4)], [Vector2(2.3, 3.1), Vector2(2.3, 7.7)]]]
	g["'"] = [1.0, [[Vector2(0.5, 0), Vector2(0.5, 2.6)]]]
	g["\""] = [2.6, [[Vector2(0.4, 0), Vector2(0.4, 2.6)], [Vector2(2.2, 0), Vector2(2.2, 2.6)]]]
	g["("] = [2.6, [_arc(3.4, 5, 3.4, 5.6, -125, -235)]]
	g[")"] = [2.6, [_arc(-0.8, 5, 3.4, 5.6, -55, 55)]]
	g["/"] = [4.0, [[Vector2(4, 0), Vector2(0, 10)]]]
	# Accented capitals: the base letter plus a mark above the cap line.
	for pair in [["Á", "A"], ["É", "E"], ["Í", "I"], ["Ó", "O"], ["Ú", "U"]]:
		var base: Array = g[pair[1]]
		var cx: float = float(base[0]) * 0.5
		g[pair[0]] = [base[0], (base[1] as Array) + [[Vector2(cx - 0.7, -1.3), Vector2(cx + 1.0, -2.9)]]]
	var n_base: Array = g["N"]
	g["Ñ"] = [n_base[0], (n_base[1] as Array) + [[Vector2(1.2, -1.6), Vector2(2.4, -2.6), Vector2(4.0, -1.6), Vector2(5.2, -2.5)]]]
	var u_base: Array = g["U"]
	g["Ü"] = [u_base[0], (u_base[1] as Array) + [[Vector2(1.8, -1.8), Vector2(1.8, -1.7)], [Vector2(4.6, -1.8), Vector2(4.6, -1.7)]]]
	_glyphs = g


## Points along an ellipse arc, degrees, y down (0 = right, 90 = down).
static func _arc(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float) -> Array:
	var pts: Array = []
	var steps: int = maxi(int(absf(a1 - a0) / 15.0), 3)
	for i in steps + 1:
		var a: float = deg_to_rad(lerpf(a0, a1, float(i) / float(steps)))
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


## Mirror a glyph through its center (turns ? into ¿).
static func _flip(strokes: Array, width: float) -> Array:
	var out: Array = []
	for stroke in strokes:
		var s: Array = []
		for p in stroke:
			s.append(Vector2(width - (p as Vector2).x, 10.0 - (p as Vector2).y))
		out.append(s)
	return out
