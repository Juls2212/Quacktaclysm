@tool
class_name UiFx
extends Control
## Hand-drawn pieces of the shelter-salvage UI, all in ink: one node draws one `mode`.
## INK_WIPE   a blot of ink that bursts open and fades when a panel opens or closes (`play()`).
## FEATHERS   dirty feathers drifting down over the screen (game over).
## SPLAT      a stylised splat of ink and blood behind a title (`play()` grows it in).
## CORK       a sheet of old paper pinned and taped over a cork board (sits inside its panel).
## TAPE       strips of tape, a crease and stains on a cardboard sign.
## NEWSPAPER  column rules, halftone and stains of an end-of-the-world newspaper.
## TITLE_BOARD a weathered painted board behind the game title, nailed on crooked.
## TITLE_CRACK the crack across the title, glowing like a fallen star.
## STAR_BIRTH a speck of light rising from a fallen duck, growing into a star that stays shining
##            (`play_star()`): when a duck dies, a star is born.
## SHADOW_EDGE deformed shadow ducks with glowing eyes creeping in from the screen edges.
## Visual only: never takes mouse input, never blocks a button or delays any logic.

enum Mode { INK_WIPE, FEATHERS, SPLAT, CORK, TAPE, NEWSPAPER, TITLE_BOARD, TITLE_CRACK, STAR_BIRTH, SHADOW_EDGE }

const INK := Color(0.106, 0.098, 0.122)
const STAR := Color(1.0, 0.42, 0.16)
const WIPE_TIME: float = 0.34

@export var mode: Mode = Mode.INK_WIPE:
	set(value):
		mode = value
		queue_redraw()
@export var color: Color = Color(0.106, 0.098, 0.122):
	set(value):
		color = value
		queue_redraw()
## Feathers on screen at once (FEATHERS).
@export var count: int = 18

var _time: float = 0.0
## Progress of the INK_WIPE or SPLAT animation, 0..1 (1 = done).
var _t: float = 1.0
var _center: Vector2 = Vector2.ZERO
var _radius: float = 300.0
var _feathers: Array[Dictionary] = []
var _star_from: Vector2 = Vector2.ZERO
var _star_to: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mode == Mode.SPLAT and not Engine.is_editor_hint():
		_t = 1.0


## INK_WIPE: bursts from `center` (local) up to `radius`. SPLAT: grows the splat in.
func play(center: Vector2 = Vector2(-1, -1), radius: float = -1.0) -> void:
	_t = 0.0
	_center = center if center.x >= 0.0 else size * 0.5
	_radius = radius if radius > 0.0 else maxf(size.x, size.y) * 0.6
	queue_redraw()


## STAR_BIRTH: the light rises from `from` (local) up to `to` and becomes a star.
## SHADOW_EDGE: starts the shadows creeping in.
func play_star(from: Vector2, to: Vector2) -> void:
	_star_from = from
	_star_to = to
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _t < 1.0:
		var duration: float = 0.4
		match mode:
			Mode.INK_WIPE:
				duration = WIPE_TIME
			Mode.STAR_BIRTH:
				duration = 1.35
			Mode.SHADOW_EDGE:
				duration = 1.2
		_t = minf(_t + delta / duration, 1.0)
	if mode == Mode.FEATHERS:
		_advance_feathers(delta)
	if mode == Mode.INK_WIPE and _t >= 1.0:
		return
	queue_redraw()


func _draw() -> void:
	match mode:
		Mode.INK_WIPE:
			_draw_wipe()
		Mode.FEATHERS:
			for f in _feathers:
				_feather(f["pos"], f["rot"], f["size"])
		Mode.SPLAT:
			_draw_splat()
		Mode.CORK:
			_draw_cork()
		Mode.TAPE:
			_draw_tape()
		Mode.NEWSPAPER:
			_draw_newspaper()
		Mode.TITLE_BOARD:
			_draw_title_board()
		Mode.TITLE_CRACK:
			_draw_title_crack()
		Mode.STAR_BIRTH:
			_draw_star_birth()
		Mode.SHADOW_EDGE:
			_draw_shadow_edge()


# =====================================================================================
# Ink wipe
# =====================================================================================

func _draw_wipe() -> void:
	if _t >= 1.0:
		return
	var grow: float = 1.0 - pow(1.0 - minf(_t / 0.55, 1.0), 3.0)
	var r: float = _radius * (0.15 + 0.85 * grow) * (1.0 + 0.12 * maxf(_t - 0.55, 0.0) / 0.45)
	var alpha: float = 0.92 if _t < 0.55 else 0.92 * (1.0 - (_t - 0.55) / 0.45)
	var c := Color(color, alpha)
	draw_colored_polygon(_blot(_center, r, 22, 3), c)
	for i in 9:
		var a: float = _h(i * 5) * TAU
		var d: float = r * (1.05 + _h(i * 5 + 1) * 0.35)
		draw_circle(_center + Vector2.from_angle(a) * d, 4.0 + _h(i * 5 + 2) * 10.0 * grow, c)
	# Ash flakes blown out of the blot.
	for i in 14:
		var a: float = _h(i * 3 + 40) * TAU
		var p: Vector2 = _center + Vector2.from_angle(a) * r * (0.9 + 0.6 * _t)
		draw_rect(Rect2(p, Vector2(3, 2)), Color(0.55, 0.53, 0.5, alpha * 0.8))


# =====================================================================================
# Feathers
# =====================================================================================

func _advance_feathers(delta: float) -> void:
	while _feathers.size() < count:
		_feathers.append({
			"pos": Vector2(_rng(_feathers.size() + int(_time * 10.0)) * maxf(size.x, 1.0), -20.0 - _rng(_feathers.size() * 3) * maxf(size.y, 1.0)),
			"rot": 0.0, "size": 0.8 + _rng(_feathers.size() * 7) * 0.9, "phase": _rng(_feathers.size() * 11) * TAU,
		})
	for f in _feathers:
		var ph: float = f["phase"]
		var s: float = f["size"]
		f["pos"] += Vector2(sin(_time * 1.4 + ph) * 46.0, 48.0 + 18.0 * s) * delta
		f["rot"] = sin(_time * 1.4 + ph) * 0.9 + 0.3
		if (f["pos"] as Vector2).y > size.y + 30.0:
			f["pos"] = Vector2(_rng(int(_time * 37.0) + int(ph * 10.0)) * size.x, -30.0)


func _feather(pos: Vector2, rot: float, s: float) -> void:
	var length: float = 26.0 * s
	var pts := PackedVector2Array()
	for i in 9:
		var t: float = float(i) / 8.0
		pts.append(Vector2(lerpf(-length * 0.5, length * 0.5, t), -sin(t * PI) * 6.5 * s))
	for i in range(7, 0, -1):
		var t: float = float(i) / 8.0
		pts.append(Vector2(lerpf(-length * 0.5, length * 0.5, t), sin(t * PI) * 4.5 * s + t * 2.0))
	var shape := PackedVector2Array()
	for p in pts:
		shape.append(pos + p.rotated(rot))
	draw_colored_polygon(shape, Color(0.84, 0.8, 0.7, 0.95))
	_outline(shape, 1.8)
	draw_line(pos + Vector2(-length * 0.62, 1).rotated(rot), pos + Vector2(length * 0.5, 0).rotated(rot), INK, 1.4, true)


# =====================================================================================
# Splat behind a title
# =====================================================================================

func _draw_splat() -> void:
	var k: float = 1.0 - pow(1.0 - _t, 3.0)
	if k <= 0.0:
		return
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x * 0.42, size.y * 0.9) * (0.4 + 0.6 * k)
	var blood := Color(0.42, 0.05, 0.06, 0.92)
	draw_colored_polygon(_blot(c, r, 26, 11, Vector2(1.9, 0.75)), blood)
	draw_colored_polygon(_blot(c + Vector2(r * 0.3, -r * 0.1), r * 0.45, 14, 17, Vector2(1.6, 0.7)), Color(0.3, 0.03, 0.05, 0.9))
	for i in 12:
		var a: float = _h(i * 7 + 60) * TAU
		var d: float = r * (1.25 + _h(i * 7 + 61) * 0.6)
		draw_circle(c + Vector2(cos(a) * d * 1.8, sin(a) * d * 0.7), 3.0 + _h(i * 7 + 62) * 7.0, blood)
	# Drips running down.
	for i in 5:
		var x: float = c.x + (float(i) - 2.0) * r * 0.5 + _h(i + 80) * 20.0
		var top: float = c.y + r * 0.45
		var drip: float = (18.0 + _h(i + 90) * 46.0) * k + sin(_time * 0.8 + i) * 2.0
		draw_line(Vector2(x, top), Vector2(x, top + drip), blood, 6.0 - i % 3, true)
		draw_circle(Vector2(x, top + drip), 4.0 - float(i % 3) * 0.8, blood)


# =====================================================================================
# Panel decorations
# =====================================================================================

## Old paper pinned over the cork: covers the panel's content area, pins and tape on top.
func _draw_cork() -> void:
	var s: Vector2 = size
	var paper := PackedVector2Array([Vector2(-12, -8), Vector2(s.x + 8, -14), Vector2(s.x + 14, s.y + 6), Vector2(-8, s.y + 12)])
	draw_colored_polygon(_shift(paper, Vector2(5, 7)), Color(0, 0, 0, 0.28))
	draw_colored_polygon(paper, Color(0.91, 0.86, 0.72))
	_outline(paper, 2.4)
	_stains(s, 21)
	# Faint ruled lines like a notebook page.
	for k in int(s.y / 34.0):
		var y: float = 24.0 + k * 34.0
		draw_line(Vector2(4, y), Vector2(s.x - 4, y - 2), Color(0.45, 0.55, 0.62, 0.25), 1.0, true)
	for corner in [Vector2(2, 0), Vector2(s.x - 2, -4)]:
		_pin(corner, Color(0.78, 0.2, 0.14))
	for corner in [Vector2(4, s.y + 4), Vector2(s.x, s.y)]:
		_tape_strip(corner, -0.6 if corner.x < s.x * 0.5 else 0.6, 64.0)


## Cardboard sign: tape at the top corners, a crease, coffee and soot stains.
func _draw_tape() -> void:
	var s: Vector2 = size
	_stains(s, 5)
	draw_line(Vector2(s.x * 0.62, -10), Vector2(s.x * 0.58, s.y + 12), Color(INK, 0.22), 2.0, true)
	draw_line(Vector2(s.x * 0.62 + 2, -10), Vector2(s.x * 0.58 + 2, s.y + 12), Color(1, 1, 1, 0.15), 1.5, true)
	_tape_strip(Vector2(-14, -18), -0.7, 86.0)
	_tape_strip(Vector2(s.x + 14, -18), 0.7, 86.0)
	_tape_strip(Vector2(s.x * 0.5, s.y + 22), 0.05, 70.0)


## Newspaper of the end of the world: rules, halftone and a stain.
func _draw_newspaper() -> void:
	var s: Vector2 = size
	for k in 2:
		var y: float = 6.0 + k * 5.0
		draw_line(Vector2(0, y), Vector2(s.x, y), INK, 2.0 - k, true)
	draw_line(Vector2(0, s.y - 6), Vector2(s.x, s.y - 6), INK, 1.5, true)
	for x in [s.x * 0.33, s.x * 0.66]:
		draw_line(Vector2(x, 18), Vector2(x, s.y - 12), Color(INK, 0.18), 1.0, true)
	for i in 70:
		var p := Vector2(_h(i + 300) * s.x, _h(i + 400) * s.y)
		draw_circle(p, 0.8 + _h(i + 500) * 1.2, Color(INK, 0.08))
	_stains(s, 33)


# =====================================================================================
# Title sign
# =====================================================================================

func _draw_title_board() -> void:
	var s: Vector2 = size
	var board := PackedVector2Array([Vector2(8, 18), Vector2(s.x * 0.48, 6), Vector2(s.x - 4, 14), Vector2(s.x - 14, s.y - 10),
			Vector2(s.x * 0.55, s.y - 2), Vector2(4, s.y - 16)])
	draw_colored_polygon(_shift(board, Vector2(8, 12)), Color(0, 0, 0, 0.35))
	draw_colored_polygon(board, Color(0.36, 0.3, 0.22))
	# Planks, grain, peeling paint.
	for k in 2:
		var y: float = s.y * (0.36 + 0.3 * k)
		draw_line(Vector2(12, y + k * 3.0), Vector2(s.x - 12, y - 4.0 + k * 2.0), INK, 2.4, true)
	for i in 14:
		var p := Vector2(20.0 + _h(i + 200) * (s.x - 40.0), 22.0 + _h(i + 220) * (s.y - 44.0))
		draw_line(p, p + Vector2(30.0 + _h(i + 240) * 50.0, 1.0), Color(0.24, 0.19, 0.13, 0.6), 1.4, true)
	for i in 6:
		var p := Vector2(30.0 + _h(i + 260) * (s.x - 60.0), 24.0 + _h(i + 270) * (s.y - 48.0))
		draw_colored_polygon(_blot(p, 7.0 + _h(i + 280) * 9.0, 8, i + 3), Color(0.56, 0.5, 0.38, 0.7))
	_outline(board, 3.4)
	for p in [Vector2(20, 26), Vector2(s.x - 24, 24), Vector2(22, s.y - 26), Vector2(s.x - 30, s.y - 22)]:
		draw_circle(p, 4.4, INK)
		draw_circle(p, 2.6, Color(0.6, 0.52, 0.44))
		draw_line(p + Vector2(1, 2), p + Vector2(2, 8), Color(0.5, 0.25, 0.12, 0.6), 1.6, true)


func _draw_title_crack() -> void:
	var s: Vector2 = size
	var pulse: float = 0.6 + 0.4 * sin(_time * 2.6)
	var crack := PackedVector2Array([Vector2(s.x * 0.58, 4), Vector2(s.x * 0.555, s.y * 0.28), Vector2(s.x * 0.6, s.y * 0.4),
			Vector2(s.x * 0.565, s.y * 0.62), Vector2(s.x * 0.61, s.y * 0.78), Vector2(s.x * 0.59, s.y - 6)])
	draw_polyline(crack, Color(STAR, 0.14 * pulse), 22.0, true)
	draw_polyline(crack, Color(STAR, 0.3 * pulse), 10.0, true)
	draw_polyline(crack, INK, 5.0, true)
	draw_polyline(crack, Color(STAR.lerp(Color(1.0, 0.92, 0.6), 0.5 * pulse), 0.75 + 0.25 * pulse), 2.2, true)
	var branch := PackedVector2Array([crack[2], crack[2] + Vector2(26, 10), crack[2] + Vector2(40, 6)])
	draw_polyline(branch, INK, 3.4, true)
	draw_polyline(branch, Color(STAR, 0.8 * pulse), 1.4, true)


# =====================================================================================
# Game over: a star is born, shadows close in
# =====================================================================================

func _draw_star_birth() -> void:
	var rise: float = 1.0 - pow(1.0 - minf(_t / 0.8, 1.0), 2.0)
	var bloom: float = clampf((_t - 0.6) / 0.4, 0.0, 1.0)
	var p: Vector2 = _star_from.lerp(_star_to, rise) + Vector2(sin(_t * 9.0) * 10.0 * (1.0 - rise), 0.0)
	var twinkle: float = 0.85 + 0.15 * sin(_time * 3.1)
	var col := Color(1.0, 0.86, 0.45)
	# Trail of sparks left on the way up.
	for k in 6:
		var q: Vector2 = _star_from.lerp(p, float(k) / 6.0)
		draw_circle(q, 1.5 + float(k) * 0.4, Color(col, 0.12 + 0.05 * float(k)))
	var r: float = lerpf(3.0, 9.0, rise) + bloom * 7.0
	for k in 4:
		draw_circle(p, r * (2.0 + float(k) * 1.4) * twinkle, Color(col, 0.07))
	draw_circle(p, r, Color(1.0, 0.95, 0.8))
	if bloom > 0.0:
		var outer: float = (14.0 + 10.0 * bloom) * twinkle
		var pts := PackedVector2Array()
		for i in 8:
			var rr: float = outer if i % 2 == 0 else outer * 0.36
			pts.append(p + Vector2.from_angle(TAU * float(i) / 8.0 - PI * 0.5 + _time * 0.2) * rr)
		draw_colored_polygon(pts, Color(col, bloom))
		var closed := PackedVector2Array(pts)
		closed.append(pts[0])
		draw_polyline(closed, Color(INK, bloom), 2.0, true)
		draw_circle(p, 4.0, Color(1, 1, 1, bloom))


## Shadow ducks lean in from the left, right and bottom edges, eyes burning, closing like a vignette.
func _draw_shadow_edge() -> void:
	var k: float = 1.0 - pow(1.0 - _t, 3.0)
	var s: Vector2 = size
	var mass := Color(0.03, 0.02, 0.03, 0.92)
	var heads: int = 14
	for i in heads:
		var side: int = i % 3
		var u: float = (float(i / 3) + 0.5 + _h(i + 600) * 0.4) / (float(heads) / 3.0)
		var r: float = 46.0 + _h(i + 610) * 40.0
		var breath: float = sin(_time * 0.9 + i) * 6.0
		var c: Vector2
		var face: Vector2
		match side:
			0:
				c = Vector2(-r * 0.9 + (r * 0.9 + 20.0) * k + breath, u * s.y)
				face = Vector2.RIGHT
			1:
				c = Vector2(s.x + r * 0.9 - (r * 0.9 + 20.0) * k - breath, u * s.y)
				face = Vector2.LEFT
			_:
				c = Vector2(u * s.x, s.y + r * 0.9 - (r * 0.7 + 10.0) * k - breath)
				face = Vector2.UP
		draw_circle(c, r, mass)
		var beak := PackedVector2Array([c + face * r * 0.6 + face.orthogonal() * r * 0.3, c + face * r * 1.4, c + face * r * 0.6 - face.orthogonal() * r * 0.25])
		draw_colored_polygon(beak, mass)
		if k > 0.4:
			var period: float = 2.0 + _h(i + 620) * 3.0
			var blink: bool = fposmod(_time + _h(i + 630) * period, period) > period - 0.15
			if not blink:
				for e in [-1.0, 1.0]:
					var eye: Vector2 = c + face * r * 0.35 + face.orthogonal() * r * 0.22 * float(e)
					var gold := Color(1.0, 0.82, 0.3) if i % 2 == 0 else Color(0.95, 0.25, 0.15)
					draw_circle(eye, 9.0, Color(gold, 0.15 * (k - 0.4) / 0.6))
					draw_circle(eye, 3.6, Color(gold, (k - 0.4) / 0.6))


# =====================================================================================
# Helpers
# =====================================================================================

func _pin(at: Vector2, head: Color) -> void:
	draw_circle(at + Vector2(2, 3), 7.0, Color(0, 0, 0, 0.3))
	draw_circle(at, 7.0, INK)
	draw_circle(at, 5.2, head)
	draw_circle(at + Vector2(-1.6, -1.8), 1.6, Color(1, 1, 1, 0.6))


func _tape_strip(center: Vector2, rot: float, length: float) -> void:
	var pts := PackedVector2Array()
	for v in [Vector2(-length * 0.5, -11), Vector2(length * 0.5, -13), Vector2(length * 0.5 + 3, 12), Vector2(-length * 0.5 - 2, 10)]:
		pts.append(center + (v as Vector2).rotated(rot))
	draw_colored_polygon(pts, Color(0.86, 0.8, 0.6, 0.85))
	draw_line(pts[0], pts[3], Color(0.6, 0.54, 0.38, 0.9), 1.4, true)
	draw_line(pts[1], pts[2], Color(0.6, 0.54, 0.38, 0.9), 1.4, true)


func _stains(s: Vector2, salt: int) -> void:
	var ring: Vector2 = Vector2(s.x * (0.7 + 0.2 * _h(salt)), s.y * (0.2 + 0.6 * _h(salt + 1)))
	draw_arc(ring, 22.0, 0.3, TAU - 0.6, 24, Color(0.45, 0.3, 0.16, 0.25), 4.0, true)
	for i in 4:
		var p := Vector2(_h(salt + i * 3 + 2) * s.x, _h(salt + i * 3 + 3) * s.y)
		draw_colored_polygon(_blot(p, 6.0 + _h(salt + i * 3 + 4) * 12.0, 9, salt + i), Color(0.35, 0.27, 0.18, 0.14))


## Lumpy ink blot (one point per angle, so never self-intersecting).
func _blot(c: Vector2, r: float, steps: int, salt: int, squash: Vector2 = Vector2.ONE) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		var k: float = 0.78 + _h(salt * 17 + i) * 0.4
		pts.append(c + Vector2(cos(a) * squash.x, sin(a) * squash.y) * r * k)
	return pts


func _outline(pts: PackedVector2Array, width: float) -> void:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, INK, width, true)


func _shift(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + off)
	return out


func _h(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)


func _rng(i: int) -> float:
	return _h(i * 31 + 7)
