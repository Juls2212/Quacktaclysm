class_name PrologueShots
extends Control
## Paints the shots of the prologue, all in code with thick ink and brush texture:
## CARD the series-style card ("BASADA EN / UNA PROFECÍA") on brushed orange with deformed wings
## and claws reaching in, TITLE the cracking QUACKTACLYSM title, EYE an anime-style close-up of
## the hero's eye with red stars falling in the iris, FALL the town seen from a rooftop through the
## hero's eyes as the sky turns red and the stars rain down on it, FOREST the dark pine
## wood with huge amber eyes, COMIC the grandfather's comic page, CAVE the prophecy stone lit by a
## torch, OUT the fade to the tutorial. The cutscene sets `shot`, `t` (seconds into the shot) and
## `line` (current subtitle); some shots add their own nodes (ducks, comic panels, the torchlight).
## Visual only.

enum Shot { CARD, TITLE, EYE, FALL, FOREST, COMIC, CAVE, OUT }

const INK := Color(0.07, 0.06, 0.08)
const STAR := Color(1.0, 0.82, 0.32)
const EMBER := Color(1.0, 0.45, 0.15)
const DESIGN := Vector2(1280, 720)

## Shot 1: the series-style card, two lines at the left (small and spaced, then big and bold).
@export var card_small_text: String = "BASADA EN"
@export var card_big_text: String = "UNA PROFECÍA"
@export var title_text: String = "QUACKTACLYSM"
@export var sound_text: String = "SHHNK!"

var shot: Shot = Shot.CARD
var t: float = 0.0
var line: int = -1
## Set by the cutscene while the cave plays: where the torch is (for the stone's glow).
var torch_point: Vector2 = Vector2.ZERO

var _shake: Vector2 = Vector2.ZERO
var _font: FontVariation
var _actors: Array[Node] = []
var _elder: DuckRig = null
var _panels: Array[Control] = []
var _hero: DuckRig = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.spacing_glyph = 7
	_font.variation_embolden = 0.6


## Switches to `next`, clearing the previous shot's nodes and building the new ones.
func set_shot(next: Shot) -> void:
	for node in _actors:
		if is_instance_valid(node):
			node.queue_free()
	_actors.clear()
	_panels.clear()
	_elder = null
	_hero = null
	_hero_parts.clear()
	_forest_fx = null
	shot = next
	t = 0.0
	line = -1
	match next:
		Shot.FALL:
			_build_fall()
		Shot.FOREST:
			_build_forest()
		Shot.COMIC:
			_build_comic()
		Shot.CAVE:
			_elder = _add_duck(DuckRig.Look.GRANDFATHER, Vector2(230, 600), 2.6)
			_elder.gesture = DuckRig.Gesture.HOLD_TORCH
	queue_redraw()


func advance(delta: float) -> void:
	t += delta
	var target := Vector2.ZERO
	if shot == Shot.FALL:
		# A short jolt on every impact.
		target = _fall_shake()
	_shake = target
	if shot == Shot.CAVE and _elder != null:
		_animate_elder(delta)
	if shot == Shot.COMIC:
		_animate_panels()
	if shot == Shot.FOREST:
		_sync_hero()
	queue_redraw()


## Torch position of the grandfather in the cave (screen space), for the light.
func cave_torch() -> Vector2:
	if _elder == null:
		return Vector2(-999, -999)
	var dir: float = signf(_elder.scale.x)
	return _elder.position + Vector2(9.5 * dir, -21.0) * absf(_elder.scale.y)


func _draw() -> void:
	draw_set_transform(_shake, 0.0, Vector2.ONE)
	match shot:
		Shot.CARD:
			_draw_card()
		Shot.TITLE:
			_draw_title()
		Shot.EYE:
			_draw_eye()
		Shot.FALL:
			_draw_fall()
		Shot.FOREST:
			_draw_forest()
		Shot.COMIC:
			_draw_comic_page()
		Shot.CAVE:
			_draw_cave()
		Shot.OUT:
			draw_rect(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color.BLACK)
	draw_set_transform_matrix(Transform2D.IDENTITY)


# =====================================================================================
# 1. Card
# =====================================================================================

func _draw_card() -> void:
	_brush_fill(Rect2(Vector2.ZERO, DESIGN), Color(0.93, 0.42, 0.1), Color(0.98, 0.56, 0.16), 3)
	var a: float = clampf((t - 0.5) / 0.8, 0.0, 1.0) * clampf((4.6 - t) / 0.5, 0.0, 1.0)
	# Series-style card on two lines at the left: small and spaced, then big and bold.
	var small_font := FontVariation.new()
	small_font.base_font = ThemeDB.fallback_font
	small_font.spacing_glyph = 12
	var small_pos := Vector2(100, 318)
	var big_pos := Vector2(96, 396)
	draw_string(small_font, small_pos, card_small_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(INK, a))
	draw_string(_font, big_pos, card_big_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 66, Color(INK, a))
	var text_right: float = maxf(small_pos.x + small_font.get_string_size(card_small_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x,
			big_pos.x + _font.get_string_size(card_big_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 66).x)
	# Wings and claws reach in from the right but stop short of the text.
	var reach: float = 1.0 - pow(1.0 - clampf(t / 1.6, 0.0, 1.0), 3.0)
	for i in 5:
		var y: float = 90.0 + float(i) * 130.0 + sin(float(i) * 2.1) * 30.0
		var tremble := Vector2(sin(t * 38.0 + i) * 2.0, cos(t * 33.0 + i * 2.0) * 2.0)
		var root := Vector2(1340.0, y) + tremble
		var room: float = root.x - text_right - 60.0 - (95.0 if i % 2 == 1 else 0.0)
		var length: float = minf(300.0 + float(i % 3) * 120.0, maxf(room, 0.0)) * reach
		if i % 2 == 0:
			_wing(root, length, PI + 0.18 * (float(i) - 2.0), Color(0.42, 0.04, 0.05) if i % 4 == 0 else INK)
		else:
			_claw_reach(root, length, PI - 0.1 * (float(i) - 2.0), Color(0.3, 0.02, 0.03) if i == 3 else INK)


## A fan of long ragged feathers: a deformed wing reaching in from the edge.
func _wing(root: Vector2, length: float, angle: float, color: Color) -> void:
	if length < 4.0:
		return
	for k in 6:
		var a: float = angle + (float(k) - 2.5) * 0.11
		var l: float = length * (0.7 + 0.3 * sin(float(k) * 1.3 + 1.0))
		var dir := Vector2.from_angle(a)
		var n: Vector2 = dir.orthogonal()
		var tip: Vector2 = root + dir * l
		var pts := PackedVector2Array([root - n * 16.0, root + dir * l * 0.5 - n * 13.0, tip + n * 3.0, root + dir * l * 0.55 + n * 12.0, root + n * 16.0])
		draw_colored_polygon(pts, color)
		_ink_outline(pts, 3.0)


func _claw_reach(root: Vector2, length: float, angle: float, color: Color) -> void:
	if length < 4.0:
		return
	var dir := Vector2.from_angle(angle)
	var n: Vector2 = dir.orthogonal()
	var wrist: Vector2 = root + dir * length
	var arm := PackedVector2Array([root - n * 26.0, wrist - n * 14.0, wrist + n * 14.0, root + n * 26.0])
	draw_colored_polygon(arm, color)
	_ink_outline(arm, 3.0)
	for k in 3:
		var a: float = angle + (float(k) - 1.0) * 0.45
		var mid: Vector2 = wrist + Vector2.from_angle(a) * 50.0
		var tip: Vector2 = mid + Vector2.from_angle(a + 0.9) * 40.0
		var finger := PackedVector2Array([wrist + Vector2.from_angle(a).orthogonal() * 8.0, mid, tip, mid + Vector2.from_angle(a).orthogonal() * -6.0, wrist - Vector2.from_angle(a).orthogonal() * 8.0])
		draw_colored_polygon(finger, color)
		_ink_outline(finger, 2.6)


# =====================================================================================
# 2. Title
# =====================================================================================

func _draw_title() -> void:
	draw_rect(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(0.02, 0.02, 0.03))
	# Sparks and stars falling behind.
	for i in 40:
		var speed: float = 120.0 + _h(i) * 220.0
		var p := Vector2(_h(i + 50) * DESIGN.x, fposmod(_h(i + 90) * DESIGN.y + t * speed, DESIGN.y + 40.0) - 20.0)
		if i % 5 == 0:
			_star(p, 5.0 + _h(i + 3) * 5.0, Color(STAR, 0.8))
		else:
			draw_line(p, p - Vector2(2, 10), Color(EMBER, 0.6), 2.0, true)
	var grow: float = clampf(t / 0.9, 0.0, 1.0)
	var cap: float = lerpf(70.0, 96.0, 1.0 - pow(1.0 - grow, 3.0))
	var style := InkType.Style.new()
	style.fill = Color(0.95, 0.88, 0.66, grow)
	style.extrude = Color(0.3, 0.2, 0.1, grow)
	style.ink = Color(INK, grow)
	style.depth = 1.1
	var width: float = InkType.measure(title_text, cap)
	var origin := Vector2((DESIGN.x - width) * 0.5, DESIGN.y * 0.5 - cap * 0.5)
	InkType.draw(self, title_text, origin, cap, style)
	# The crack runs down through the letters and starts to glow.
	var crack_k: float = clampf((t - 1.3) / 0.8, 0.0, 1.0)
	if crack_k > 0.0:
		var pts := PackedVector2Array()
		var x0: float = DESIGN.x * 0.55
		for k in 8:
			var u: float = float(k) / 7.0
			if u > crack_k:
				break
			pts.append(Vector2(x0 + sin(float(k) * 2.3) * 22.0, origin.y - 30.0 + u * (cap + 70.0)))
		if pts.size() > 1:
			var pulse: float = 0.7 + 0.3 * sin(t * 8.0)
			draw_polyline(pts, Color(STAR, 0.2 * pulse), 26.0, true)
			draw_polyline(pts, INK, 7.0, true)
			draw_polyline(pts, Color(1.0, 0.92, 0.5, pulse), 3.0, true)


# =====================================================================================
# 3. The eye
# =====================================================================================

## The eye (anime style, painted): a face lit purple-blue from the upper right with soft shadows,
## dark ink feathers falling from above, an almond eye with a heavy upper lash line, curved lashes
## of different lengths and fine lower ones, a lilac white shaded under the lid, and an iris going
## red to magenta to dark purple with a dark pupil and a rounded pink glint, where red stars fall
## with their trails. It blinks once, softly, while the camera breathes.
const EYE_LIGHT := Color("6a58e6")
const EYE_DARK := Color("22186a")
const EYE_SCLERA := Color("d6cdf4")
const EYE_LID_SHADOW := Color("8a7cc8")
const EYE_INK := Color(0.05, 0.03, 0.1)
const IRIS_RED := Color("ff3b30")
const IRIS_MAGENTA := Color("c21f7a")
const IRIS_PURPLE := Color("2a0b45")
const EYE_L := Vector2(330, 398)
const EYE_R := Vector2(1010, 330)
const IRIS_C := Vector2(690, 372)
const IRIS_R: float = 128.0


## The light on the face: brighter up and to the right, falling off down and to the left. Linear
## in x and y, so per-vertex colours rebuild it exactly on any polygon.
func _face_light(p: Vector2) -> Color:
	var u: float = clampf(p.y / 720.0 * 0.8 + (1.0 - p.x / 1280.0) * 0.35, 0.0, 1.0)
	return EYE_LIGHT.lerp(EYE_DARK, u)


func _face_poly(pts: PackedVector2Array) -> void:
	var colors := PackedColorArray()
	for p in pts:
		colors.append(_face_light(p))
	draw_polygon(pts, colors)


func _lid_upper(u: float, open: float) -> Vector2:
	var up: Vector2 = _bezier(EYE_L, Vector2(640, 168), EYE_R, u)
	return _lid_lower(u).lerp(up, open)


func _lid_lower(u: float) -> Vector2:
	return _bezier(EYE_L, Vector2(700, 520), EYE_R, u)


func _bezier(a: Vector2, b: Vector2, c: Vector2, u: float) -> Vector2:
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


## A stroke that thins from `w0` to `w1` along `pts` (an ink brush line).
func _tapered(pts: PackedVector2Array, w0: float, w1: float, color: Color) -> void:
	var n: int = pts.size()
	if n < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[mini(i + 1, n - 1)]
		var dir: Vector2 = (b - a).normalized()
		var w: float = lerpf(w0, w1, float(i) / float(n - 1)) * 0.5
		left.append(pts[i] + dir.orthogonal() * w)
		right.append(pts[i] - dir.orthogonal() * w)
	right.reverse()
	left.append_array(right)
	draw_colored_polygon(left, color)


func _draw_eye() -> void:
	var breath: float = sin(t * 0.9)
	var zoom: float = 1.0 + 0.012 * breath + t * 0.004
	draw_set_transform(_shake + Vector2(0, breath * 4.0) + DESIGN * 0.5 * (1.0 - zoom), 0.0, Vector2(zoom, zoom))
	# One soft blink: the lid slides down and back up.
	var blink: float = smoothstep(6.2, 6.55, t) * (1.0 - smoothstep(6.6, 7.05, t))
	var open: float = 1.0 - blink
	_face_poly(PackedVector2Array([Vector2(-80, -80), Vector2(1360, -80), Vector2(1360, 800), Vector2(-80, 800)]))
	if open > 0.15:
		var white := PackedVector2Array()
		for k in 25:
			white.append(_lid_upper(float(k) / 24.0, open))
		for k in range(23, 0, -1):
			white.append(_lid_lower(float(k) / 24.0))
		draw_colored_polygon(white, EYE_SCLERA)
		# Shadow of the lid over the top of the white.
		var shade := PackedVector2Array()
		for k in 25:
			shade.append(_lid_upper(float(k) / 24.0, open))
		for k in range(23, 0, -1):
			var u: float = float(k) / 24.0
			shade.append(_lid_upper(u, open) + Vector2(0, 40.0 * sin(u * PI) * open))
		draw_colored_polygon(shade, Color(EYE_LID_SHADOW, 0.75))
		_draw_iris()
	# The face again over everything outside the almond (it hides the iris under the lids).
	var upper := PackedVector2Array([Vector2(-80, -80), Vector2(1360, -80), Vector2(1360, EYE_R.y)])
	for k in range(24, -1, -1):
		upper.append(_lid_upper(float(k) / 24.0, open))
	upper.append(Vector2(-80, EYE_L.y))
	_face_poly(upper)
	var lower := PackedVector2Array([Vector2(-80, EYE_L.y)])
	for k in 25:
		lower.append(_lid_lower(float(k) / 24.0))
	lower.append_array(PackedVector2Array([Vector2(1360, EYE_R.y), Vector2(1360, 800), Vector2(-80, 800)]))
	_face_poly(lower)
	# Soft shadows: under the eye, down the cheek and at the temple.
	for k in 12:
		var f: float = 1.0 - float(k) * 0.07
		draw_colored_polygon(_ellipse(Vector2(560, 560), 420.0 * f, 70.0 * f, 32, -0.08), Color(0.08, 0.04, 0.24, 0.025))
		draw_colored_polygon(_ellipse(Vector2(120, 520), 260.0 * f, 300.0 * f, 32), Color(0.06, 0.03, 0.2, 0.028))
	draw_polyline(PackedVector2Array([Vector2(1110, 470), Vector2(1150, 560), Vector2(1170, 640)]), Color(EYE_INK, 0.35), 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(430, 610), Vector2(560, 600), Vector2(640, 606)]), Color(EYE_INK, 0.3), 2.4, true)
	_draw_lashes(open)
	_draw_eye_feathers()


func _draw_iris() -> void:
	var c: Vector2 = IRIS_C
	# Radial gradient: dark purple rim, magenta, red toward the pupil.
	var rings: int = 22
	for k in rings:
		var u: float = float(k) / float(rings - 1)
		var col: Color = IRIS_PURPLE.lerp(IRIS_MAGENTA, smoothstep(0.0, 0.55, u)).lerp(IRIS_RED, smoothstep(0.5, 1.0, u))
		draw_circle(c, IRIS_R * (1.0 - u * 0.6), col)
	for i in 40:
		var a: float = TAU * float(i) / 40.0 + _h(i + 1500) * 0.1
		draw_line(c + Vector2.from_angle(a) * IRIS_R * 0.42, c + Vector2.from_angle(a) * IRIS_R * (0.8 + _h(i + 1510) * 0.15),
				Color(IRIS_PURPLE, 0.25), 2.0, true)
	draw_arc(c, IRIS_R, 0.0, TAU, 64, Color(IRIS_PURPLE.darkened(0.4), 0.95), 5.0, true)
	var pupil: float = IRIS_R * 0.36
	draw_circle(c, pupil * 1.15, Color(0.1, 0.02, 0.1, 0.5))
	draw_circle(c, pupil, Color(0.07, 0.01, 0.07))
	# Red stars falling across the iris, with their trails.
	var dir := Vector2(-0.45, 1.0).normalized()
	for i in 8:
		var u: float = fposmod(t * (0.16 + _h(i + 1520) * 0.1) + _h(i + 1530), 1.0)
		var p: Vector2 = c + Vector2((_h(i + 1540) - 0.3) * IRIS_R * 1.6, -IRIS_R * 1.1) + dir * u * IRIS_R * 2.4
		if p.distance_to(c) < IRIS_R * 0.92:
			var tail: Vector2 = p - dir * 42.0
			draw_line(tail, p, Color(1.0, 0.45, 0.4, 0.45), 3.0, true)
			draw_line(tail.lerp(p, 0.5), p, Color(1.0, 0.7, 0.65, 0.6), 2.0, true)
			draw_circle(p, 4.0, Color(1.0, 0.86, 0.82))
	# Rounded pink glint and a small white one.
	draw_colored_polygon(_ellipse(c + Vector2(IRIS_R * 0.42, -IRIS_R * 0.42), 24.0, 15.0, 20, -0.45), Color("ffb2d2"))
	draw_circle(c + Vector2(-IRIS_R * 0.3, IRIS_R * 0.34), 6.0, Color(1.0, 0.85, 0.92, 0.8))


## Heavy upper lash line with a flick at the outer corner, curved lashes of different lengths,
## a thin lower line and fine lower lashes.
func _draw_lashes(open: float) -> void:
	var lower := PackedVector2Array()
	for k in 21:
		lower.append(_lid_lower(lerpf(0.06, 0.97, float(k) / 20.0)))
	_tapered(lower, 2.0, 3.0, Color(EYE_INK, 0.85))
	for k in 10:
		var u: float = lerpf(0.28, 0.92, float(k) / 9.0)
		var base: Vector2 = _lid_lower(u)
		var dir: Vector2 = Vector2(0.15 + u * 0.25, 1.0).normalized()
		var length: float = 10.0 + _h(k + 1600) * 10.0
		_tapered(PackedVector2Array([base, base + dir * length * 0.5 + Vector2(1.5, 0), base + dir * length]), 2.2, 0.4, Color(EYE_INK, 0.8))
	var line := PackedVector2Array()
	for k in 31:
		line.append(_lid_upper(float(k) / 30.0, open))
	# Thick in the middle and toward the outer corner, thin at the inner one.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in line.size():
		var u: float = float(i) / float(line.size() - 1)
		var a: Vector2 = line[maxi(i - 1, 0)]
		var b: Vector2 = line[mini(i + 1, line.size() - 1)]
		var nrm: Vector2 = (b - a).normalized().orthogonal()
		var w: float = 3.0 + 13.0 * pow(sin(u * PI * 0.92 + 0.08), 0.7) + 6.0 * smoothstep(0.7, 1.0, u)
		left.append(line[i] + nrm * w * 0.5)
		right.append(line[i] - nrm * w * 0.5)
	right.reverse()
	left.append_array(right)
	draw_colored_polygon(left, EYE_INK)
	# The flick past the outer corner.
	var corner: Vector2 = line[line.size() - 1]
	_tapered(PackedVector2Array([corner + Vector2(-14, 4), corner + Vector2(22, -12), corner + Vector2(54, -34)]), 14.0, 1.0, EYE_INK)
	# Upper lashes: curved strokes, longer toward the outer corner.
	for k in 22:
		var u: float = lerpf(0.1, 0.98, float(k) / 21.0)
		var base: Vector2 = _lid_upper(u, open)
		var bend: float = lerpf(-0.5, 0.95, u)
		var length: float = (26.0 + 44.0 * smoothstep(0.2, 1.0, u)) * (0.65 + 0.6 * _h(k + 1620)) * lerpf(0.55, 1.0, open)
		var d0: Vector2 = Vector2.from_angle(-PI * 0.5 + bend * 0.6)
		var d1: Vector2 = Vector2.from_angle(-PI * 0.5 + bend * 1.25)
		# Closing, the lashes swing down with the lid.
		var flip: float = lerpf(-0.75, 1.0, open)
		d0.y *= flip
		d1.y *= flip
		var mid: Vector2 = base + d0 * length * 0.55
		_tapered(PackedVector2Array([base, mid, mid + d1 * length * 0.5]), 5.5, 0.6, EYE_INK)


## Dark feathers (or locks) falling from the top in ink strokes of varying width, swaying a little.
func _draw_eye_feathers() -> void:
	var band := PackedVector2Array([Vector2(-80, -80), Vector2(1360, -80), Vector2(1360, 40), Vector2(-80, 70)])
	draw_polygon(band, PackedColorArray([Color("0b0618"), Color("0b0618"), Color(0.04, 0.02, 0.09, 0.9), Color(0.04, 0.02, 0.09, 0.9)]))
	for i in 34:
		var x: float = -60.0 + float(i) * 42.0 + (_h(i + 1700) - 0.5) * 30.0
		var length: float = 170.0 + _h(i + 1710) * 220.0 * (1.25 - float(i) / 40.0)
		var sway: float = sin(t * 0.8 + float(i) * 0.7) * 4.0
		var lean: float = -18.0 + _h(i + 1720) * 26.0
		var pts := PackedVector2Array()
		for k in 7:
			var u: float = float(k) / 6.0
			pts.append(Vector2(x + lean * u * u + sway * u, -20.0 + length * u))
		var w: float = 16.0 + _h(i + 1730) * 22.0
		_tapered(pts, w, 1.0, Color("0b0618") if i % 3 != 0 else Color("1a1033"))
		if i % 2 == 0:
			var shine := PackedVector2Array()
			for k in 4:
				shine.append(pts[k + 1] + Vector2(w * 0.12, 0))
			draw_polyline(shine, Color(0.42, 0.34, 0.8, 0.35), 1.6, true)


# =====================================================================================
# 4. The fall
# =====================================================================================

## The fall (~13 s), seen through the hero's eyes from a rooftop. a (0-4 s): a quiet night town,
## a blue sky with twinkling stars and a crescent moon, three rows of ink-drawn houses and a
## cathedral on the hill, many lit windows; below, the dark edge of the roof and the tip of his
## beak; the view rises and falls with his breath. b (4-7 s): the sky slides, with no cut, into
## blood red and orange; the moon reddens, the houses darken and some windows go out. c (7-13 s):
## red and radioactive green stars rain down diagonally (white core, coloured halo, long trail),
## few then many; two big ones streak past close by; each one that reaches the town bursts into an
## orange glow with smoke and jolts the view; at the end he steps back (the view drops and shakes).
const NIGHT_TOP := Color("0e1a3a")
const NIGHT_LOW := Color("3a4680")
const BLOOD_STOPS: Array = [Color("2a0406"), Color("8a1410"), Color("e2541a"), Color("ff9a3a")]
const SKY_STOP_Y: Array = [0.0, 230.0, 430.0, 600.0]
const STAR_RED := Color("ff3a2a")
const STAR_GREEN := Color("7aff3a")
const WINDOW_LIT := Color("ffd24a")
const HOUSE_INK := Color(0.06, 0.05, 0.1)
## Rows of houses from far to near: [ground y, min w, max w, min h, max h, wall, roof].
const HOUSE_ROWS: Array = [
	[452.0, 46.0, 74.0, 34.0, 60.0, Color("7480bc"), Color("3c4684")],
	[520.0, 66.0, 104.0, 52.0, 84.0, Color("5e6aa8"), Color("323c78")],
	[594.0, 96.0, 146.0, 70.0, 112.0, Color("4a5594"), Color("28306a")],
]
const CATHEDRAL_X: float = 880.0

var _houses: Array = []
var _shooting: Array = []


func _build_fall() -> void:
	_houses.clear()
	for row in HOUSE_ROWS.size():
		var spec: Array = HOUSE_ROWS[row]
		var x: float = -60.0 + _h(row + 1800) * 30.0
		var i: int = 0
		while x < 1340.0:
			var salt: int = row * 100 + i
			var w: float = lerpf(spec[1], spec[2], _h(salt + 1810))
			var h: float = lerpf(spec[3], spec[4], _h(salt + 1820))
			var ground: float = _row_ground(row, x + w * 0.5)
			_houses.append({"row": row, "x": x, "w": w, "h": h, "ground": ground + (_h(salt + 1830) - 0.5) * 8.0,
					"roof": h * (0.35 + _h(salt + 1840) * 0.25), "salt": salt})
			x += w * (0.78 + _h(salt + 1850) * 0.15)
			i += 1
	_shooting.clear()
	for i in 80:
		# Few at first, then many: start times pile up toward the end.
		var start: float = 7.0 + 5.6 * sqrt(_h(i + 1900))
		var green: bool = _h(i + 1910) > 0.6
		var dir := Vector2(-0.34 - _h(i + 1920) * 0.14, 1.0).normalized()
		var row: int = 0 if _h(i + 1930) < 0.5 else 1
		var land_x: float = 40.0 + _h(i + 1940) * 1200.0
		var land := Vector2(land_x, _row_ground(row, land_x) - 20.0 - _h(i + 1950) * 30.0)
		var speed: float = 520.0 + _h(i + 1960) * 360.0
		var travel: float = (land.y + 60.0) / dir.y
		_shooting.append({"start": start, "color": STAR_GREEN if green else STAR_RED, "dir": dir, "origin": land - dir * travel,
				"land": land, "speed": speed, "hit": start + travel / speed, "r": 3.0 + _h(i + 1970) * 3.0,
				"trail": 120.0 + _h(i + 1980) * 160.0, "big": false, "salt": i})
	# Two big ones streaking past close by (they do not land in sight).
	_shooting.append({"start": 8.6, "color": STAR_RED, "dir": Vector2(-0.72, 0.69).normalized(), "origin": Vector2(1500, -160),
			"land": Vector2(-999, -999), "speed": 980.0, "hit": 99.0, "r": 13.0, "trail": 620.0, "big": true, "salt": 91})
	_shooting.append({"start": 10.4, "color": STAR_GREEN, "dir": Vector2(-0.6, 0.8).normalized(), "origin": Vector2(1250, -200),
			"land": Vector2(-999, -999), "speed": 1050.0, "hit": 99.0, "r": 11.0, "trail": 560.0, "big": true, "salt": 92})


## Ground line of a row of houses; the far row climbs a hill toward the cathedral.
func _row_ground(row: int, x: float) -> float:
	var spec: Array = HOUSE_ROWS[row]
	var hill: float = 78.0 * exp(-pow((x - CATHEDRAL_X) / 300.0, 2.0)) if row == 0 else 26.0 * exp(-pow((x - CATHEDRAL_X) / 360.0, 2.0)) * float(2 - row)
	return float(spec[0]) - hill


## Shake of the view: a jolt after every impact, a rumble as the big stars pass, a tremble at the end.
func _fall_shake() -> Vector2:
	var k: float = 0.0
	for s in _shooting:
		var since: float = t - float(s["hit"])
		if since >= 0.0 and since < 0.3:
			k = maxf(k, 1.0 - since / 0.3)
		if bool(s["big"]):
			var pass_t: float = t - float(s["start"])
			if pass_t > 0.0 and pass_t < 1.2:
				k = maxf(k, 0.8 * sin(pass_t / 1.2 * PI))
	k = minf(k, 1.0) + 0.9 * smoothstep(11.8, 12.6, t)
	return Vector2(sin(t * 87.0), cos(t * 71.0)) * 5.0 * k


func _draw_fall() -> void:
	var blood: float = smoothstep(4.0, 7.0, t)
	var retreat: float = smoothstep(11.8, 13.0, t)
	var breath: float = sin(t * 1.25)
	# The whole view rises and falls with the breath; stepping back it drops.
	var view := Vector2(0.0, breath * 3.0 - 34.0 * retreat)
	draw_set_transform(_shake + view, 0.0, Vector2.ONE)
	_draw_fall_sky(blood)
	_draw_fall_moon(blood)
	var landed: int = 0
	for s in _shooting:
		if not bool(s["big"]) and t >= float(s["hit"]):
			landed += 1
	var burn: float = clampf(float(landed) / 30.0, 0.0, 1.0)
	_draw_cathedral(blood)
	for row in HOUSE_ROWS.size():
		for house in _houses:
			if int(house["row"]) == row:
				_draw_house(house, blood, burn)
		# Haze between the rows, the colour of the sky low down.
		var haze: Color = _sky_color(500.0, blood)
		var hy: float = float(HOUSE_ROWS[row][0]) + 10.0
		draw_polygon(PackedVector2Array([Vector2(-60, hy - 60), Vector2(1340, hy - 60), Vector2(1340, hy + 30), Vector2(-60, hy + 30)]),
				PackedColorArray([Color(haze, 0.0), Color(haze, 0.0), Color(haze, 0.22), Color(haze, 0.22)]))
	for s in _shooting:
		if not bool(s["big"]):
			_draw_shooting_star(s)
	for s in _shooting:
		_draw_fall_impact(s)
	if burn > 0.0:
		draw_polygon(PackedVector2Array([Vector2(-60, 360), Vector2(1340, 360), Vector2(1340, 640), Vector2(-60, 640)]),
				PackedColorArray([Color(1.0, 0.45, 0.12, 0.0), Color(1.0, 0.45, 0.12, 0.0), Color(1.0, 0.5, 0.15, 0.4 * burn), Color(1.0, 0.5, 0.15, 0.4 * burn)]))
	for s in _shooting:
		if bool(s["big"]):
			_draw_shooting_star(s)
	# The rooftop he stands on, and the tip of his beak.
	draw_set_transform(_shake + Vector2(0.0, breath * 4.5 - 34.0 - 60.0 * retreat), 0.0, Vector2.ONE)
	_draw_rooftop(blood)
	draw_set_transform(_shake, 0.0, Vector2.ONE)
	var edge := Color(0, 0, 0, 0.55)
	var clear := Color(0, 0, 0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(-30, -30), Vector2(240, -30), Vector2(240, 750), Vector2(-30, 750)]), PackedColorArray([edge, clear, clear, edge]))
	draw_polygon(PackedVector2Array([Vector2(1040, -30), Vector2(1310, -30), Vector2(1310, 750), Vector2(1040, 750)]), PackedColorArray([clear, edge, edge, clear]))


## Sky colour at height `y`: night blue, sliding toward blood red and orange as `blood` rises.
func _sky_color(y: float, blood: float) -> Color:
	var night: Color = NIGHT_TOP.lerp(NIGHT_LOW, clampf(y / 600.0, 0.0, 1.0))
	var red: Color = BLOOD_STOPS[3]
	for i in 3:
		var y0: float = SKY_STOP_Y[i]
		var y1: float = SKY_STOP_Y[i + 1]
		if y <= y1:
			red = (BLOOD_STOPS[i] as Color).lerp(BLOOD_STOPS[i + 1], clampf((y - y0) / (y1 - y0), 0.0, 1.0))
			break
	return night.lerp(red, blood)


func _draw_fall_sky(blood: float) -> void:
	var ys: Array = [-80.0, 0.0, 230.0, 430.0, 600.0, 800.0]
	for i in ys.size() - 1:
		var y0: float = ys[i]
		var y1: float = ys[i + 1]
		var c0: Color = _sky_color(y0, blood)
		var c1: Color = _sky_color(y1, blood)
		draw_polygon(PackedVector2Array([Vector2(-60, y0), Vector2(1340, y0), Vector2(1340, y1), Vector2(-60, y1)]), PackedColorArray([c0, c0, c1, c1]))
	# Twinkling stars, fading as the sky burns.
	var fade: float = 1.0 - smoothstep(4.5, 6.5, t)
	if fade <= 0.0:
		return
	for i in 140:
		var p := Vector2(_h(i + 2000) * 1280.0, 80.0 + _h(i + 2010) * 330.0)
		var tw: float = 0.45 + 0.55 * absf(sin(t * (1.0 + _h(i + 2020) * 2.5) + float(i)))
		var r: float = 1.0 + _h(i + 2030) * 1.6
		draw_circle(p, r, Color(1.0, 0.98, 0.9, tw * fade))
		if i % 17 == 0:
			draw_line(p - Vector2(r * 3.0, 0), p + Vector2(r * 3.0, 0), Color(1, 1, 1, 0.5 * tw * fade), 1.0, true)
			draw_line(p - Vector2(0, r * 3.0), p + Vector2(0, r * 3.0), Color(1, 1, 1, 0.5 * tw * fade), 1.0, true)


## A crescent moon with a soft glow, tinted red as the sky turns.
func _draw_fall_moon(blood: float) -> void:
	var c := Vector2(300, 170)
	var r: float = 44.0
	var col: Color = Color("f6eec8").lerp(Color("e0503e"), blood)
	for k in 5:
		draw_circle(c, r * (1.3 + float(k) * 0.4), Color(col, 0.05))
	# Lit edge on the left: the outer half circle, back along a thinner inner curve that meets it
	# at the tips (so the shape never crosses itself), tilted a little.
	var pts := PackedVector2Array()
	for k in 25:
		var a: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 24.0)
		pts.append(c + Vector2(-cos(a) * r, sin(a) * r).rotated(-0.35))
	for k in range(23, 0, -1):
		var a: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 24.0)
		pts.append(c + Vector2(-cos(a) * r * 0.42 - r * 0.04, sin(a) * r * 0.9).rotated(-0.35))
	draw_colored_polygon(pts, col)
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	draw_polyline(ring, Color(HOUSE_INK, 0.5), 2.0, true)


## Tint of the town as the sky turns: walls and roofs darken toward a red shadow.
func _town_tint(c: Color, blood: float, burn: float) -> Color:
	return c.lerp(Color(0.24, 0.07, 0.09), 0.6 * blood).lerp(Color(0.35, 0.12, 0.08), 0.3 * burn)


func _draw_house(house: Dictionary, blood: float, burn: float) -> void:
	var row: int = house["row"]
	var spec: Array = HOUSE_ROWS[row]
	var x: float = house["x"]
	var w: float = house["w"]
	var h: float = house["h"]
	var g: float = house["ground"]
	var salt: int = house["salt"]
	var ink_w: float = [1.4, 1.9, 2.4][row]
	var wall: Color = _town_tint(spec[5], blood, burn)
	var roof: Color = _town_tint(spec[6], blood, burn)
	var top: float = g - h
	var body := PackedVector2Array([Vector2(x, g + 40.0), Vector2(x, top), Vector2(x + w, top), Vector2(x + w, g + 40.0)])
	draw_colored_polygon(body, wall)
	draw_polyline(PackedVector2Array([Vector2(x, g + 40.0), Vector2(x, top), Vector2(x + w, top), Vector2(x + w, g + 40.0)]), HOUSE_INK, ink_w, true)
	# Roof: pitched or a flat terrace with a parapet, with tile lines.
	var rh: float = house["roof"]
	if _h(salt + 2100) > 0.25:
		var peak_x: float = x + w * (0.35 + _h(salt + 2110) * 0.3)
		var roof_pts := PackedVector2Array([Vector2(x - 6.0, top + 2.0), Vector2(peak_x, top - rh), Vector2(x + w + 6.0, top + 2.0)])
		draw_colored_polygon(roof_pts, roof)
		for k in 3:
			var u: float = (float(k) + 1.0) / 4.0
			draw_line(Vector2(x - 6.0, top + 2.0).lerp(Vector2(peak_x, top - rh), u), Vector2(x + w + 6.0, top + 2.0).lerp(Vector2(peak_x, top - rh), u),
					Color(HOUSE_INK, 0.35), 1.0, true)
		var closed := PackedVector2Array(roof_pts)
		closed.append(roof_pts[0])
		draw_polyline(closed, HOUSE_INK, ink_w, true)
		if _h(salt + 2120) > 0.6:
			# Chimney or a TV antenna.
			var cx: float = lerpf(x + 8.0, peak_x - 6.0, 0.5)
			draw_line(Vector2(cx, top - rh * 0.4), Vector2(cx, top - rh - 14.0), HOUSE_INK, ink_w, true)
			draw_line(Vector2(cx - 7.0, top - rh - 10.0), Vector2(cx + 7.0, top - rh - 12.0), HOUSE_INK, ink_w * 0.7, true)
	else:
		draw_rect(Rect2(x - 3.0, top - 6.0, w + 6.0, 6.0), roof)
		draw_rect(Rect2(x - 3.0, top - 6.0, w + 6.0, 6.0), HOUSE_INK, false, ink_w * 0.8)
	# Windows in a grid, most of them lit; some go out as the sky turns.
	var cols: int = maxi(int(w / [16.0, 22.0, 30.0][row]), 1)
	var rows_n: int = maxi(int(h / [18.0, 24.0, 32.0][row]), 1)
	var ww: float = [5.0, 7.0, 10.0][row]
	var wh: float = [7.0, 9.0, 13.0][row]
	for cy in rows_n:
		for cx2 in cols:
			var id: int = salt * 37 + cy * 7 + cx2
			var px: float = x + (float(cx2) + 0.5) * w / float(cols) - ww * 0.5
			var py: float = top + 8.0 + float(cy) * h / float(rows_n)
			if py + wh > g + 4.0:
				continue
			var lit: bool = _h(id + 2200) > 0.3 and _h(id + 2210) > blood * 0.45
			var col: Color = WINDOW_LIT.lerp(Color(1.0, 0.55, 0.2), maxf(blood, burn)) if lit else wall.darkened(0.45)
			if lit:
				draw_rect(Rect2(px - 2.0, py - 2.0, ww + 4.0, wh + 4.0), Color(col, 0.25))
			draw_rect(Rect2(px, py, ww, wh), col)
			draw_rect(Rect2(px, py, ww, wh), Color(HOUSE_INK, 0.7), false, 1.0)


## The cathedral on the hill: nave, a bell tower with its spire, a dome and a rose window.
func _draw_cathedral(blood: float) -> void:
	var wall: Color = _town_tint(Color("8a94c8"), blood, 0.0)
	var dark: Color = _town_tint(Color("4a5492"), blood, 0.0)
	var g: float = _row_ground(0, CATHEDRAL_X) + 6.0
	# The hill under it.
	var hill := PackedVector2Array()
	for k in 25:
		var x: float = lerpf(380.0, 1380.0, float(k) / 24.0)
		hill.append(Vector2(x, _row_ground(0, x) + 4.0))
	hill.append(Vector2(1380, 560))
	hill.append(Vector2(380, 560))
	draw_colored_polygon(hill, _town_tint(Color("3c4684"), blood, 0.0))
	var nave := PackedVector2Array([Vector2(CATHEDRAL_X - 130, g), Vector2(CATHEDRAL_X - 130, g - 90), Vector2(CATHEDRAL_X - 40, g - 140),
			Vector2(CATHEDRAL_X + 60, g - 90), Vector2(CATHEDRAL_X + 60, g)])
	draw_colored_polygon(nave, wall)
	_ink_outline(nave, 2.2)
	var rose := CATHEDRAL_X - 40.0
	draw_circle(Vector2(rose, g - 82), 20.0, dark)
	draw_arc(Vector2(rose, g - 82), 20.0, 0.0, TAU, 24, HOUSE_INK, 2.0, true)
	for k in 6:
		var a: float = TAU * float(k) / 6.0
		draw_line(Vector2(rose, g - 82), Vector2(rose, g - 82) + Vector2.from_angle(a) * 18.0, Color(HOUSE_INK, 0.6), 1.2, true)
	for k in 3:
		var ax: float = CATHEDRAL_X - 110.0 + float(k) * 30.0
		draw_rect(Rect2(ax, g - 50, 10, 26), dark)
		draw_rect(Rect2(ax, g - 50, 10, 26), HOUSE_INK, false, 1.2)
	# Bell tower and spire.
	var tower := PackedVector2Array([Vector2(CATHEDRAL_X + 60, g), Vector2(CATHEDRAL_X + 60, g - 190), Vector2(CATHEDRAL_X + 120, g - 190), Vector2(CATHEDRAL_X + 120, g)])
	draw_colored_polygon(tower, wall)
	_ink_outline(tower, 2.2)
	var spire := PackedVector2Array([Vector2(CATHEDRAL_X + 54, g - 190), Vector2(CATHEDRAL_X + 90, g - 280), Vector2(CATHEDRAL_X + 126, g - 190)])
	draw_colored_polygon(spire, dark)
	_ink_outline(spire, 2.2)
	draw_line(Vector2(CATHEDRAL_X + 90, g - 280), Vector2(CATHEDRAL_X + 90, g - 302), HOUSE_INK, 2.0, true)
	draw_line(Vector2(CATHEDRAL_X + 82, g - 294), Vector2(CATHEDRAL_X + 98, g - 294), HOUSE_INK, 2.0, true)
	for k in 2:
		var ty: float = g - 160.0 + float(k) * 60.0
		draw_colored_polygon(PackedVector2Array([Vector2(CATHEDRAL_X + 80, ty + 26), Vector2(CATHEDRAL_X + 80, ty + 8), Vector2(CATHEDRAL_X + 90, ty),
				Vector2(CATHEDRAL_X + 100, ty + 8), Vector2(CATHEDRAL_X + 100, ty + 26)]), dark)
	# Dome over the crossing.
	var dome := PackedVector2Array()
	for k in 13:
		var a: float = lerpf(PI, TAU, float(k) / 12.0)
		dome.append(Vector2(CATHEDRAL_X - 100, g - 104) + Vector2(cos(a) * 34.0, sin(a) * 40.0))
	draw_colored_polygon(dome, dark)
	_ink_outline(dome, 2.0)


## A falling star: long fading trail, coloured halo and a white core.
func _draw_shooting_star(s: Dictionary) -> void:
	var start: float = s["start"]
	if t < start or t >= float(s["hit"]):
		return
	var dir: Vector2 = s["dir"]
	var p: Vector2 = Vector2(s["origin"]) + dir * float(s["speed"]) * (t - start)
	if p.x < -400.0 or p.y > 900.0:
		return
	var col: Color = s["color"]
	var r: float = s["r"]
	var trail: float = s["trail"]
	var steps: int = 10
	for k in steps:
		var u0: float = float(k) / float(steps)
		var u1: float = float(k + 1) / float(steps)
		var a: Vector2 = p - dir * trail * u0
		var b: Vector2 = p - dir * trail * u1
		draw_line(a, b, Color(col, 0.7 * (1.0 - u0)), r * 1.6 * (1.0 - u0 * 0.7), true)
	draw_line(p, p - dir * trail * 0.35, Color(1.0, 1.0, 1.0, 0.6), maxf(r * 0.5, 1.0), true)
	for k in 4:
		draw_circle(p, r * (2.0 + float(k) * 1.6), Color(col, 0.12))
	draw_circle(p, r * 1.4, col)
	draw_circle(p, r * 0.85, Color(1, 1, 1))
	if bool(s["big"]):
		# It lights the whole view as it passes.
		draw_rect(Rect2(Vector2(-60, -60), DESIGN + Vector2(120, 120)), Color(col, 0.08))


## Where a star reaches the town: an orange burst, then smoke and a fire glow that stays.
func _draw_fall_impact(s: Dictionary) -> void:
	if bool(s["big"]):
		return
	var since: float = t - float(s["hit"])
	if since < 0.0:
		return
	var land: Vector2 = s["land"]
	var salt: int = s["salt"]
	if since < 0.55:
		var fade: float = 1.0 - since / 0.55
		for k in 4:
			draw_circle(land, (14.0 + since * 160.0) * (1.0 - float(k) * 0.2), Color(1.0, 0.55 + 0.1 * float(k), 0.2, 0.2 * fade))
		draw_circle(land, 10.0 * fade + 2.0, Color(1.0, 0.95, 0.8, fade))
	var flicker: float = 0.75 + 0.25 * sin(t * 13.0 + float(salt))
	draw_circle(land, 16.0 * flicker, Color(1.0, 0.5, 0.15, 0.22))
	draw_circle(land, 6.0 * flicker, Color(1.0, 0.75, 0.3, 0.5))
	for k in 4:
		var u: float = fposmod(since * 0.35 + float(k) / 4.0, 1.0)
		if since * 0.35 < float(k) / 4.0:
			continue
		var puff: Vector2 = land + Vector2(sin(u * 4.0 + float(salt)) * 8.0 + u * 30.0, -u * 150.0)
		draw_colored_polygon(_ellipse(puff, 12.0 + u * 30.0, 10.0 + u * 22.0, 12, u * 2.0), Color(0.16, 0.07, 0.07, 0.35 * (1.0 - u)))


## The dark edge of the roof he stands on, a chimney at the side and the tip of his beak.
func _draw_rooftop(blood: float) -> void:
	var roof: Color = Color("141a30").lerp(Color("1c0a0c"), blood)
	var ridge := PackedVector2Array([Vector2(-60, 800), Vector2(-60, 628), Vector2(180, 616), Vector2(420, 622), Vector2(700, 612),
			Vector2(980, 620), Vector2(1340, 608), Vector2(1340, 800)])
	draw_colored_polygon(ridge, roof)
	var line := PackedVector2Array()
	for k in range(1, ridge.size() - 1):
		line.append(ridge[k])
	draw_polyline(line, HOUSE_INK, 4.0, true)
	for k in 14:
		var x: float = -40.0 + float(k) * 100.0
		draw_arc(Vector2(x, 640), 40.0, PI * 1.1, PI * 1.9, 8, Color(HOUSE_INK, 0.5), 2.0, true)
	var chimney := PackedVector2Array([Vector2(1110, 620), Vector2(1150, 520), Vector2(1200, 512), Vector2(1240, 616)])
	draw_colored_polygon(chimney, roof.lightened(0.06))
	_ink_outline(chimney, 3.0)
	# The tip of the beak poking into view from below.
	var beak := PackedVector2Array()
	# A rounded beak tip seen from behind: a broad base narrowing to a blunt round end.
	for k in 13:
		var u: float = float(k) / 12.0
		beak.append(Vector2(lerpf(470.0, 640.0, u), lerpf(720.0, 628.0, u) - sin(u * PI) * 10.0))
	for k in 9:
		var a: float = lerpf(-PI * 0.75, PI * 0.35, float(k) / 8.0)
		beak.append(Vector2(668, 640) + Vector2.from_angle(a) * 30.0)
	for k in 7:
		var u: float = float(k) / 6.0
		beak.append(Vector2(lerpf(690.0, 820.0, u), lerpf(664.0, 720.0, u) + sin(u * PI) * 6.0))
	draw_colored_polygon(beak, Color("e8a640").lerp(Color("c46a2a"), blood * 0.5))
	draw_line(Vector2(540, 690), Vector2(650, 640), Color(1.0, 0.9, 0.6, 0.55), 4.0, true)
	draw_circle(Vector2(640, 662), 4.0, Color(HOUSE_INK, 0.7))
	_ink_outline(beak, 4.0)


# =====================================================================================
# 5. The forest
# =====================================================================================

## The forest (~14 s). 1 (0-6 s): the hero walks right along a path through three rows of pines
## that slide by in parallax, his torch throwing a warm circle. 2 (6-8.5 s): he slows down, the
## flame trembles, sputters, flares once and dies to a thread of smoke; an eye half-opens between
## the trees on the right; he stops and looks around. 3 (8.5-14 s): the forest is gone; on a deep
## red ground eleven eyes open around him one by one, then four fanged mouths grin open; at the
## end everything shuts at once into black.
const FOREST_FAR := Color("12302f")
const FOREST_MID := Color("0b2223")
const FOREST_NEAR := Color("030909")
const TORCH_GLOW := Color("ffc56a")
const EYE_WHITE := Color("e6b8ad")
const MOUTH_IN := Color("232323")
const TONGUE := Color("6b6b6b")
const FANG := Color("f3f1ea")
const RED_DEEP := Color("2e0504")
const RED_MID := Color("4a0907")
const HERO_SCALE: float = 1.9
## Eyes: center, horizontal radius, tilt (radians), second at which it opens.
const FOREST_EYES: Array = [
	[Vector2(300, 140), 40.0, 0.12, 9.3], [Vector2(115, 215), 42.0, -0.1, 9.9], [Vector2(640, 178), 70.0, 0.0, 9.0],
	[Vector2(790, 112), 40.0, 0.1, 10.4], [Vector2(852, 288), 58.0, 0.08, 7.2], [Vector2(662, 300), 24.0, 1.35, 10.8],
	[Vector2(250, 378), 52.0, -0.12, 9.6], [Vector2(565, 418), 60.0, 0.06, 10.1], [Vector2(1150, 345), 44.0, 0.1, 10.6],
	[Vector2(430, 555), 46.0, 0.08, 11.0], [Vector2(1030, 600), 36.0, 0.1, 11.3],
]
## Mouths: center, half width, tilt, second at which it starts to open.
const FOREST_MOUTHS: Array = [
	[Vector2(370, 255), 150.0, -0.04, 11.4], [Vector2(1100, 172), 105.0, -0.12, 11.8],
	[Vector2(965, 482), 190.0, 0.14, 11.6], [Vector2(178, 552), 108.0, 0.32, 12.0],
]

var _hero_parts: Array[DuckRig] = []
var _forest_fx: Control = null


func _build_forest() -> void:
	# The game's hero in three synced pieces (body, head, weapon): the full duck with his torch in
	# hand, but without the rig's own flame, so this shot can let it die.
	for piece in [DuckRig.Part.BODY, DuckRig.Part.HEAD, DuckRig.Part.WEAPON]:
		var rig := DuckRig.new()
		rig.look = DuckRig.Look.HERO
		rig.gesture = DuckRig.Gesture.HOLD_TORCH
		rig.part = piece
		rig.scale = Vector2.ONE * HERO_SCALE
		add_child(rig)
		_actors.append(rig)
		_hero_parts.append(rig)
	_forest_fx = Control.new()
	_forest_fx.size = DESIGN
	_forest_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_forest_fx.draw.connect(_draw_forest_fx)
	add_child(_forest_fx)
	_actors.append(_forest_fx)
	_sync_hero()


## Distance walked (px) and current walking speed: steady, then easing to a stop at 8 s.
func _walked() -> Vector2:
	var speed: float = 42.0
	var s: float = clampf(t - 6.0, 0.0, 2.0)
	var dist: float = speed * minf(t, 6.0) + speed * (s - s * s / 4.0)
	var v: float = speed if t < 6.0 else speed * maxf(1.0 - s / 2.0, 0.0)
	return Vector2(dist, v)


func _hero_feet() -> Vector2:
	return Vector2(372.0 + _walked().x, 650.0)


func _sync_hero() -> void:
	var walk: Vector2 = _walked()
	var feet: Vector2 = _hero_feet()
	# Stops and glances left, then right.
	var facing: float = -1.0 if t > 8.05 and t < 8.4 else 1.0
	var dark: float = smoothstep(7.5, 8.4, t)
	var tint: Color = Color.WHITE.lerp(Color(0.14, 0.08, 0.08), dark)
	for rig in _hero_parts:
		rig.position = feet - Vector2(0, 26.0 * HERO_SCALE)
		rig.scale = Vector2(facing, 1.0) * HERO_SCALE
		rig.ground_speed = walk.y * 2.6
		rig.modulate = tint
	if _forest_fx != null:
		_forest_fx.queue_redraw()


## Top of the torch in screen space.
func _torch_top() -> Vector2:
	var facing: float = signf(_hero_parts[0].scale.x) if not _hero_parts.is_empty() else 1.0
	return _hero_feet() + Vector2(0, -26.0 * HERO_SCALE) + Vector2(6.0 * facing, -23.0) * HERO_SCALE


## 1 while lit; trembles, sputters, flares once at 7.25 s and dies at ~7.8 s.
func _flame() -> float:
	if t < 6.0:
		return 1.0
	if t < 7.1:
		return 0.75 + 0.25 * sin(t * 31.0) * sin(t * 17.0)
	if t < 7.25:
		return lerpf(0.55, 0.25, (t - 7.1) / 0.15)
	if t < 7.4:
		return 0.95
	return maxf(0.6 * (1.0 - (t - 7.4) / 0.4) * (0.7 + 0.3 * sin(t * 60.0)), 0.0)


func _draw_forest() -> void:
	if t < 8.6:
		_draw_walk_forest()
	var dark: float = 0.97 * smoothstep(7.6, 8.4, t)
	if t >= 8.5:
		_draw_red_void(clampf((t - 8.6) / 1.0, 0.0, 1.0))
		dark = 1.0 - clampf((t - 8.6) / 1.0, 0.0, 1.0)
	# The creatures close all at once at the end: total black.
	if t > 13.45:
		dark = maxf(dark, clampf((t - 13.45) / 0.15, 0.0, 1.0))
	if dark > 0.0:
		draw_rect(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(0, 0, 0, dark))
	# The first eye half-opens between the right-hand trees just before the dark.
	if t > 7.0 and t < 8.7:
		var spec: Array = FOREST_EYES[4]
		var peek: float = 0.45 * smoothstep(7.0, 7.6, t)
		_almond_eye(spec[0], spec[1], spec[2], peek, 0.85)


func _draw_walk_forest() -> void:
	var walk: float = _walked().x
	var sky := PackedVector2Array([Vector2(-20, -20), Vector2(1300, -20), Vector2(1300, 620), Vector2(-20, 620)])
	draw_polygon(sky, PackedColorArray([Color(0.01, 0.04, 0.045), Color(0.02, 0.06, 0.065), Color(0.05, 0.12, 0.12), Color(0.04, 0.1, 0.1)]))
	for k in 6:
		draw_circle(Vector2(1110, 115), 40.0 + float(k) * 34.0, Color(0.55, 0.7, 0.68, 0.035))
	draw_circle(Vector2(1110, 115), 26.0, Color(0.78, 0.86, 0.82, 0.55))
	_brush_strokes(Rect2(0, 60, 1280, 500), Color(0.06, 0.16, 0.16, 0.4), 31)
	_scroll_row(FOREST_FAR, 520.0, 0.55, 16, walk * 0.15, 0, false)
	_fog_band(470.0, 0.22)
	_scroll_row(FOREST_MID, 590.0, 0.8, 11, walk * 0.4, 1, false)
	_fog_band(560.0, 0.2)
	# Ground and the faint path.
	draw_rect(Rect2(-20, 600, 1320, 140), Color(0.015, 0.04, 0.04))
	draw_colored_polygon(PackedVector2Array([Vector2(-20, 656), Vector2(1300, 646), Vector2(1300, 666), Vector2(-20, 672)]), Color(0.05, 0.09, 0.085))
	for i in 46:
		var gx: float = fposmod(float(i) * 31.0 + _h(i + 960) * 20.0 - walk * 1.0, 1400.0) - 60.0
		var gy: float = 612.0 + _h(i + 970) * 26.0
		draw_line(Vector2(gx, gy), Vector2(gx + 3.0, gy - 7.0 - _h(i) * 6.0), Color(0.06, 0.13, 0.12), 2.0, true)
	# Warm torchlight on the ground and the nearest trunks.
	var light: float = clampf(_flame(), 0.0, 1.0) * (1.0 - smoothstep(7.45, 7.85, t))
	if light > 0.0:
		var torch: Vector2 = _torch_top()
		for k in 6:
			draw_circle(torch, 50.0 + float(k) * 42.0, Color(TORCH_GLOW, 0.045 * light))
		draw_colored_polygon(_ellipse(Vector2(torch.x, 652), 190.0 * light + 20.0, 20.0, 28), Color(TORCH_GLOW, 0.16 * light))
	# Near row, only at the sides so the middle stays open; it slides by fastest.
	_scroll_row(FOREST_NEAR, 700.0, 1.25, 6, walk * 1.0, 2, true)
	_draw_trunk_light(walk, light)


## A row of pines with trunks that scrolls by `shift` and wraps. `sides` keeps the middle clear.
func _scroll_row(color: Color, base_y: float, scale_k: float, count: int, shift: float, row: int, sides: bool) -> void:
	var span: float = 1500.0
	for i in count:
		var x: float = fposmod((float(i) + _h(i + row * 40) * 0.6) / float(count) * span - shift, span) - 110.0
		if sides and x > 300.0 and x < 980.0:
			continue
		var h: float = (260.0 + _h(i + row * 50) * 160.0) * scale_k
		draw_rect(Rect2(x - h * 0.03, base_y - h * 0.2, h * 0.06, h * 0.2 + 6.0), color.darkened(0.2))
		_pine(Vector2(x, base_y - h * 0.12), h * 0.9, color)


## Warm strokes on the trunks of the middle row close to the torch.
func _draw_trunk_light(walk: float, light: float) -> void:
	if light <= 0.0:
		return
	var torch: Vector2 = _torch_top()
	var span: float = 1500.0
	for i in 11:
		var x: float = fposmod((float(i) + _h(i + 40) * 0.6) / 11.0 * span - walk * 0.4, span) - 110.0
		var d: float = absf(x - torch.x)
		if d > 260.0:
			continue
		var k: float = (1.0 - d / 260.0) * light
		var h: float = (260.0 + _h(i + 50) * 160.0) * 0.8
		draw_line(Vector2(x - h * 0.02, 590.0), Vector2(x - h * 0.02, 590.0 - h * 0.2), Color(TORCH_GLOW, 0.25 * k), 3.0, true)


## Deep red void with a lighter middle, near-black edges, brush texture and grain; eyes and
## mouths open in it around the hero.
func _draw_red_void(appear: float) -> void:
	draw_rect(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(RED_DEEP, appear))
	for k in 6:
		var r: float = 620.0 - float(k) * 90.0
		draw_colored_polygon(_ellipse(Vector2(640, 380), r * 1.1, r * 0.62, 40), Color(RED_MID, 0.12 * appear))
	_brush_strokes(Rect2(0, 60, 1280, 600), Color(0.25, 0.03, 0.03, 0.25 * appear), 61)
	# Edges sinking into black.
	for k in 5:
		var inset: float = float(k) * 45.0
		var a: float = 0.16 * appear
		var outer := Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40))
		draw_rect(Rect2(outer.position, Vector2(outer.size.x, 60.0 + inset)), Color(0, 0, 0, a))
		draw_rect(Rect2(Vector2(-20, 680.0 - inset), Vector2(outer.size.x, 80.0 + inset)), Color(0, 0, 0, a))
		draw_rect(Rect2(outer.position, Vector2(60.0 + inset, outer.size.y)), Color(0, 0, 0, a))
		draw_rect(Rect2(Vector2(1220.0 - inset, -20), Vector2(80.0 + inset, outer.size.y)), Color(0, 0, 0, a))
	# Grain.
	var seed_step: int = int(t * 24.0)
	for i in 160:
		var p := Vector2(_h(i * 3 + seed_step) * 1280.0, _h(i * 3 + seed_step + 1) * 720.0)
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, 0.035 * appear))
	if appear <= 0.0:
		return
	var shut: float = 1.0 - clampf((t - 13.4) / 0.08, 0.0, 1.0)
	for i in FOREST_EYES.size():
		var spec: Array = FOREST_EYES[i]
		var open: float = smoothstep(float(spec[3]), float(spec[3]) + 0.5, t)
		if i == 4:
			open = maxf(open, 0.45)
		var period: float = 2.6 + _h(i + 980) * 2.4
		var phase: float = fposmod(t + _h(i + 990) * period, period)
		if phase > period - 0.2:
			open *= absf(phase - (period - 0.1)) / 0.1
		_almond_eye(spec[0], spec[1], spec[2], open * shut, 1.0)
	for i in FOREST_MOUTHS.size():
		var spec: Array = FOREST_MOUTHS[i]
		var open: float = smoothstep(float(spec[3]), float(spec[3]) + 1.4, t)
		_fang_mouth(spec[0], spec[1], spec[2], open * shut, i)


## Almond eye with pointed corners, pinkish white, a huge glossy black iris looking at the hero,
## a dark hollow around it and brush strokes for lids and brows. `open` lifts the lids.
func _almond_eye(c: Vector2, rx: float, tilt: float, open: float, alpha: float) -> void:
	if open <= 0.05:
		return
	var up_h: float = rx * 0.5 * open
	var down_h: float = rx * 0.42 * open
	var almond := PackedVector2Array()
	for k in 24:
		var u: float = float(k) / 23.0
		almond.append(Vector2(lerpf(-rx, rx, u), -up_h * pow(sin(u * PI), 0.85)))
	for k in range(22, 0, -1):
		var u: float = float(k) / 23.0
		almond.append(Vector2(lerpf(-rx, rx, u), down_h * pow(sin(u * PI), 0.95)))
	draw_set_transform(_shake + c, tilt, Vector2.ONE)
	# Hollow of red-black shadow around the eye.
	for k in 4:
		draw_colored_polygon(_ellipse(Vector2.ZERO, rx * (1.7 - float(k) * 0.15), rx * (0.95 - float(k) * 0.08), 28), Color(0.08, 0.0, 0.0, 0.12 * alpha))
	draw_colored_polygon(almond, Color(EYE_WHITE, alpha))
	# Reddish shadow under the upper lid and in the corners.
	var shade := PackedVector2Array()
	for k in 24:
		var u: float = float(k) / 23.0
		shade.append(Vector2(lerpf(-rx, rx, u), -up_h * pow(sin(u * PI), 0.85)))
	for k in range(22, 0, -1):
		var u: float = float(k) / 23.0
		shade.append(Vector2(lerpf(-rx, rx, u), -up_h * pow(sin(u * PI), 0.85) * 0.45))
	draw_colored_polygon(shade, Color(0.62, 0.25, 0.24, 0.55 * alpha))
	# Iris: enormous, black and glossy, turned toward the hero (clipped to the eye).
	var to_hero: Vector2 = (_hero_feet() + Vector2(0, -60) - c).rotated(-tilt).normalized()
	var iris_c := Vector2(to_hero.x * rx * 0.28, to_hero.y * up_h * 0.18)
	var iris_r: float = rx * 0.47
	for clipped in Geometry2D.intersect_polygons(_ellipse(iris_c, iris_r, iris_r, 32), almond):
		draw_colored_polygon(clipped, Color(0.03, 0.02, 0.025, alpha))
	if open > 0.35:
		var glint := _ellipse(iris_c + Vector2(iris_r * 0.3, -iris_r * 0.38), iris_r * 0.24, iris_r * 0.13, 16, -0.6)
		for clipped in Geometry2D.intersect_polygons(glint, almond):
			draw_colored_polygon(clipped, Color(1, 1, 1, 0.95 * alpha))
		draw_circle(iris_c + Vector2(iris_r * 0.52, -iris_r * 0.05), iris_r * 0.08, Color(1, 1, 1, 0.9 * alpha))
		draw_arc(iris_c, iris_r * 0.72, PI * 0.25, PI * 0.75, 10, Color(1, 1, 1, 0.25 * alpha), 2.0, true)
	var closed := PackedVector2Array(almond)
	closed.append(almond[0])
	draw_polyline(closed, Color(0.12, 0.02, 0.02, alpha), 2.0, true)
	# Brush strokes over and under: lids and brows.
	for k in 4:
		var lift: float = 5.0 + float(k) * 6.5
		var stroke := PackedVector2Array()
		for j in 11:
			var u: float = float(j) / 10.0
			stroke.append(Vector2(lerpf(-rx * (1.2 - 0.05 * float(k)), rx * (1.1 + 0.04 * float(k)), u), -up_h * sin(u * PI) * (1.0 + 0.15 * float(k)) - lift - sin(u * 5.0 + float(k)) * 2.0))
		draw_polyline(stroke, Color(0.16, 0.02, 0.02, (0.8 - float(k) * 0.16) * alpha), 5.5 - float(k) * 1.1, true)
	for k in 2:
		var under := PackedVector2Array()
		for j in 11:
			var u: float = float(j) / 10.0
			under.append(Vector2(lerpf(-rx * (1.0 + 0.1 * float(k)), rx * 1.05, u), down_h * sin(u * PI) * (1.0 + 0.2 * float(k)) + 6.0 + float(k) * 7.0))
		draw_polyline(under, Color(0.16, 0.02, 0.02, (0.6 - float(k) * 0.2) * alpha), 4.0 - float(k) * 1.2, true)
	draw_set_transform(_shake, 0.0, Vector2.ONE)


## A wide crescent mouth grinning open: dark throat with rings, a moving tongue and uneven fangs.
func _fang_mouth(c: Vector2, w: float, tilt: float, open: float, salt: int) -> void:
	if open <= 0.04:
		return
	var top_h: float = w * 0.1 * open
	var bottom_h: float = w * 0.34 * open
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for k in 30:
		var u: float = float(k) / 29.0
		var x: float = lerpf(-w, w, u)
		var curve: float = sin(u * PI)
		# A smile: both edges dip toward the middle, the lower one far deeper.
		upper.append(Vector2(x, w * 0.06 * curve - top_h * curve))
		lower.append(Vector2(x, w * 0.06 * curve + bottom_h * pow(curve, 0.8)))
	var mouth := PackedVector2Array(upper)
	for k in range(28, 0, -1):
		mouth.append(lower[k])
	draw_set_transform(_shake + c, tilt, Vector2.ONE)
	draw_colored_polygon(mouth, MOUTH_IN)
	# Rings sinking toward the throat, slightly off-center and irregular.
	var throat := Vector2(w * 0.15, w * 0.12 * open)
	for k in 5:
		var s: float = 1.0 - float(k) * 0.17
		var ring := _ellipse(throat, w * 0.7 * s, (top_h + bottom_h) * 0.42 * s + 1.0, 24, 0.05 * float(k))
		for clipped in Geometry2D.intersect_polygons(ring, mouth):
			var edge := PackedVector2Array(clipped)
			edge.append(clipped[0])
			draw_polyline(edge, Color(0.0, 0.0, 0.0, 0.75), 2.5, true)
	# Tongue lolling about inside.
	var tongue := _ellipse(Vector2(w * (0.25 + 0.08 * sin(t * 1.7 + float(salt))), w * 0.2 * open), w * 0.38, w * 0.07 * open + 1.0, 18, 0.15 + 0.1 * sin(t * 1.3))
	for clipped in Geometry2D.intersect_polygons(tongue, mouth):
		draw_colored_polygon(clipped, TONGUE)
	# Fangs, longer toward the middle, a few much longer, all a little crooked.
	var count: int = int(w / 13.0)
	for edge_i in 2:
		var edge: PackedVector2Array = upper if edge_i == 0 else lower
		var dir: float = 1.0 if edge_i == 0 else -1.0
		for k in count:
			var u: float = (float(k) + 0.5) / float(count)
			var idx: int = clampi(int(u * 29.0), 1, 28)
			var base: Vector2 = edge[idx]
			var half: float = w / float(count) * 0.48
			var length: float = (6.0 + sin(u * PI) * w * 0.11) * (1.7 if _h(salt * 50 + k + edge_i * 25) > 0.85 else 1.0) * (0.7 + 0.4 * _h(salt * 50 + k + 7)) * open
			var lean: float = (_h(salt * 50 + k + 13) - 0.5) * length * 0.5
			var tooth := PackedVector2Array([base + Vector2(-half, 0), base + Vector2(lean * 0.4 - half * 0.3, dir * length * 0.6), base + Vector2(lean, dir * length), base + Vector2(half, 0)])
			draw_colored_polygon(tooth, FANG)
			var outline := PackedVector2Array(tooth)
			outline.append(tooth[0])
			draw_polyline(outline, Color(0.1, 0.08, 0.08), 1.2, true)
	var closed := PackedVector2Array(mouth)
	closed.append(mouth[0])
	draw_polyline(closed, Color(0.04, 0.0, 0.0), 3.0, true)
	draw_set_transform(_shake, 0.0, Vector2.ONE)


## Drawn above the hero: the flame, its dying sputters, then the smoke.
func _draw_forest_fx() -> void:
	if _forest_fx == null or _hero_parts.is_empty():
		return
	var top: Vector2 = _torch_top() + _shake
	var f: float = _flame()
	if f > 0.06:
		var h: float = (24.0 + sin(t * 13.0) * 3.0) * f
		var wide: float = 7.5 * f
		var sway: float = sin(t * 9.0) * 3.0 * f
		for layer in 3:
			var k: float = 1.0 - float(layer) * 0.3
			var flame := PackedVector2Array()
			for j in 10:
				var a: float = PI * float(j) / 9.0
				flame.append(top + Vector2(cos(a) * wide * k, sin(a) * wide * 0.6 * k))
			flame.append(top + Vector2(-wide * 0.7 * k, -h * 0.4 * k))
			flame.append(top + Vector2(sway, -h * k))
			flame.append(top + Vector2(wide * 0.7 * k, -h * 0.4 * k))
			var col: Color = [Color(0.95, 0.4, 0.1), Color(1.0, 0.65, 0.2), Color(1.0, 0.92, 0.6)][layer]
			_forest_fx.draw_colored_polygon(flame, col)
	# Sputters: a few yellow sparks.
	for spark_at in [6.55, 7.05, 7.5]:
		var since: float = t - float(spark_at)
		if since > 0.0 and since < 0.5:
			for k in 5:
				var dir := Vector2.from_angle(-PI * 0.5 + (_h(k + int(spark_at * 10.0)) - 0.5) * 2.2)
				_forest_fx.draw_circle(top + dir * since * 90.0 + Vector2(0, since * since * 60.0), 2.0 * (1.0 - since * 2.0), Color(1.0, 0.85, 0.25, 1.0 - since * 2.0))
	# A thread of grey smoke once it is out.
	if t > 7.6:
		var smoke := PackedVector2Array()
		for k in 12:
			var u: float = float(k) / 11.0
			smoke.append(top + Vector2(sin(u * 7.0 + t * 1.5) * 6.0 * u, -u * 90.0))
		_forest_fx.draw_polyline(smoke, Color(0.55, 0.55, 0.55, 0.5 * (1.0 - smoothstep(12.8, 13.45, t))), 2.0, true)


func _fog_band(y: float, alpha: float) -> void:
	var fog := Color(0.3, 0.45, 0.45)
	var drift: float = sin(t * 0.3 + y) * 30.0
	draw_polygon(PackedVector2Array([Vector2(-20 + drift, y - 70), Vector2(1300 + drift, y - 70), Vector2(1300 + drift, y + 40), Vector2(-20 + drift, y + 40)]),
			PackedColorArray([Color(fog, 0.0), Color(fog, 0.0), Color(fog, alpha), Color(fog, alpha)]))


func _pine(base: Vector2, h: float, color: Color) -> void:
	var pts := PackedVector2Array([base + Vector2(-h * 0.04, 0)])
	for k in 6:
		var u: float = float(k) / 6.0
		var y: float = base.y - h * u
		var w: float = h * 0.28 * (1.0 - u)
		pts.append(Vector2(base.x - w, y))
		pts.append(Vector2(base.x - w * 0.45, y - h * 0.09))
	pts.append(Vector2(base.x, base.y - h))
	for k in range(5, -1, -1):
		var u: float = float(k) / 6.0
		var y: float = base.y - h * u
		var w: float = h * 0.28 * (1.0 - u)
		pts.append(Vector2(base.x + w * 0.45, y - h * 0.09))
		pts.append(Vector2(base.x + w, y))
	pts.append(base + Vector2(h * 0.04, 0))
	draw_colored_polygon(pts, color)


# =====================================================================================
# 6. The comic page
# =====================================================================================

func _draw_comic_page() -> void:
	_brush_fill(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(0.9, 0.85, 0.72), Color(0.86, 0.8, 0.66), 41)


func _build_comic() -> void:
	var specs: Array = [
		[Rect2(40, 50, 640, 570), Color(0.78, 0.12, 0.1), 0.4],
		[Rect2(705, 50, 535, 270), Color(0.05, 0.3, 0.33), 5.4],
		[Rect2(705, 345, 535, 275), Color(0.98, 0.78, 0.12), 10.4],
	]
	for i in specs.size():
		var spec: Array = specs[i]
		var panel := Control.new()
		var rect: Rect2 = spec[0]
		panel.position = rect.position
		panel.size = rect.size
		panel.pivot_offset = rect.size * 0.5
		panel.clip_contents = true
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = false
		panel.set_meta("color", spec[1])
		panel.set_meta("start", spec[2])
		panel.set_meta("kind", i)
		panel.draw.connect(_draw_panel.bind(panel))
		add_child(panel)
		_actors.append(panel)
		_panels.append(panel)
		if i == 0:
			var elder := DuckRig.new()
			elder.look = DuckRig.Look.GRANDFATHER
			elder.gesture = DuckRig.Gesture.TALK
			# Close up from below: the old samurai towers over the reader, cut off by the panel.
			elder.scale = Vector2(-8.0, 8.0)
			elder.position = Vector2(300, 520)
			elder.rotation = -0.08
			elder.modulate = Color(1.0, 0.62, 0.55)
			panel.add_child(elder)
			var shade := Control.new()
			shade.size = rect.size
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shade.draw.connect(_draw_hard_shadow.bind(shade))
			panel.add_child(shade)


func _animate_panels() -> void:
	for panel in _panels:
		var start: float = panel.get_meta("start")
		var since: float = t - start
		panel.visible = since >= 0.0
		if since >= 0.0 and since < 0.35:
			var k: float = 1.0 - since / 0.35
			panel.scale = Vector2.ONE * (1.0 + 0.12 * k)
			panel.rotation = sin(since * 60.0) * 0.03 * k
		else:
			panel.scale = Vector2.ONE
			panel.rotation = 0.0
		panel.queue_redraw()


func _draw_panel(panel: Control) -> void:
	var s: Vector2 = panel.size
	var color: Color = panel.get_meta("color")
	var kind: int = panel.get_meta("kind")
	var since: float = t - float(panel.get_meta("start"))
	panel.draw_rect(Rect2(Vector2.ZERO, s), color)
	# Halftone dots in the shadow corner.
	for i in 90:
		var p := Vector2(_h(i + kind * 100) * s.x, _h(i + kind * 100 + 1) * s.y)
		if p.x + p.y < s.x * 0.8:
			continue
		panel.draw_circle(p, 3.0 + _h(i) * 3.0, Color(0, 0, 0, 0.25))
	match kind:
		1:
			_comic_eyes(panel, s)
		2:
			_comic_katana(panel, s, since)
	panel.draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), INK, false, 7.0)


func _draw_hard_shadow(node: Control) -> void:
	var s: Vector2 = node.size
	node.draw_colored_polygon(PackedVector2Array([Vector2(0, s.y * 0.55), Vector2(s.x * 0.4, s.y), Vector2(0, s.y)]), Color(0, 0, 0, 0.75))
	node.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.72, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.5)]), Color(0, 0, 0, 0.6))


## Extreme close-up of the grandfather's tired eyes under heavy brows.
func _comic_eyes(panel: Control, s: Vector2) -> void:
	var c: Vector2 = s * 0.5
	panel.draw_rect(Rect2(Vector2(0, c.y - 90), Vector2(s.x, 180)), Color(0.75, 0.78, 0.72))
	for side in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(float(side) * 130.0, 8.0)
		panel.draw_colored_polygon(_ellipse(e, 70.0, 40.0, 20), Color(0.95, 0.92, 0.82))
		panel.draw_circle(e + Vector2(6, 4), 20.0, Color(0.15, 0.12, 0.1))
		panel.draw_circle(e + Vector2(0, -2), 6.0, Color(1, 1, 1, 0.8))
		var lid := PackedVector2Array([e + Vector2(-80, -60), e + Vector2(80, -60), e + Vector2(78, -6), e + Vector2(-78, -16)])
		panel.draw_colored_polygon(lid, Color(0.7, 0.72, 0.66))
		panel.draw_line(e + Vector2(-78, -16), e + Vector2(78, -6), INK, 6.0, true)
		panel.draw_arc(e + Vector2(0, 30), 70.0, 0.3, PI - 0.3, 14, Color(0.25, 0.2, 0.3, 0.8), 10.0, true)
		for k in 7:
			var b: Vector2 = e + Vector2(-70.0 + float(k) * 24.0, -64.0)
			panel.draw_line(b, b + Vector2(30, -18 + float(k % 2) * 10.0), Color(0.92, 0.9, 0.82), 7.0, true)
			panel.draw_line(b, b + Vector2(30, -18 + float(k % 2) * 10.0), INK, 2.0, true)
	panel.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.35, 0), Vector2(0, s.y * 0.6)]), Color(0, 0, 0, 0.7))


## The hand drawing the katana, with the sound in big yellow letters.
func _comic_katana(panel: Control, s: Vector2, since: float) -> void:
	var draw_k: float = clampf(since / 0.6, 0.0, 1.0)
	var saya_a := Vector2(40, s.y * 0.7)
	var saya_b := Vector2(s.x * 0.55, s.y * 0.45)
	panel.draw_line(saya_a, saya_b, INK, 30.0, true)
	panel.draw_line(saya_a, saya_b, Color(0.18, 0.12, 0.14), 22.0, true)
	var dir: Vector2 = (saya_b - saya_a).normalized()
	var blade_end: Vector2 = saya_b + dir * 260.0 * draw_k
	panel.draw_line(saya_b, blade_end, INK, 18.0, true)
	panel.draw_line(saya_b, blade_end, Color(0.9, 0.92, 0.94), 11.0, true)
	for k in 6:
		var p: Vector2 = saya_b + dir * (40.0 + float(k) * 40.0) * draw_k
		panel.draw_line(p + dir.orthogonal() * 30.0, p + dir.orthogonal() * 60.0 - dir * 30.0, Color(INK, 0.5), 3.0, true)
	var hand: Vector2 = blade_end - dir * 30.0
	panel.draw_colored_polygon(_ellipse(hand, 46.0, 34.0, 16, dir.angle()), Color(0.88, 0.85, 0.72))
	panel.draw_arc(hand, 40.0, 0.0, TAU, 20, INK, 6.0, true)
	if since > 0.3:
		var style := InkType.Style.new()
		style.fill = Color(1.0, 0.86, 0.15)
		style.extrude = Color(0.55, 0.25, 0.02)
		style.depth = 1.0
		var pop: float = 1.0 + 0.25 * maxf(0.0, 1.0 - (since - 0.3) / 0.25)
		InkType.draw(panel, sound_text, Vector2(s.x * 0.18, 26), 70.0 * pop, style)


# =====================================================================================
# 7. The cave
# =====================================================================================

func _draw_cave() -> void:
	draw_rect(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(0.18, 0.15, 0.13))
	_brush_strokes(Rect2(0, 0, 1280, 720), Color(0.24, 0.2, 0.17, 0.6), 51)
	# Floor and dripping water.
	draw_rect(Rect2(-20, 600, 1320, 140), Color(0.12, 0.1, 0.09))
	for i in 8:
		var x: float = 80.0 + _h(i + 600) * 1120.0
		var u: float = fposmod(t * 0.6 + _h(i + 610), 1.0)
		draw_line(Vector2(x, u * 600.0), Vector2(x, u * 600.0 + 14.0), Color(0.7, 0.78, 0.85, 0.7), 2.0, true)
		if u > 0.92:
			draw_arc(Vector2(x, 600), 6.0 + (u - 0.92) * 120.0, PI, TAU, 8, Color(0.7, 0.78, 0.85, 0.6), 1.5, true)
	# The prophecy stone: a huge cracked slab with ducks and stars carved into it.
	var stone := PackedVector2Array([Vector2(700, 610), Vector2(712, 150), Vector2(830, 110), Vector2(1010, 130), Vector2(1120, 170), Vector2(1135, 610)])
	draw_colored_polygon(stone, Color(0.42, 0.38, 0.34))
	_ink_outline(stone, 6.0)
	draw_polyline(PackedVector2Array([Vector2(905, 112), Vector2(880, 240), Vector2(930, 330), Vector2(890, 470), Vector2(920, 610)]), INK, 5.0, true)
	for i in 6:
		var p := Vector2(770.0 + float(i % 3) * 120.0, 220.0 + float(i / 3) * 170.0)
		var glow: float = clampf(1.0 - p.distance_to(torch_point) / 380.0, 0.0, 1.0)
		var col := Color(1.0, 0.82, 0.4).lerp(Color(0.3, 0.27, 0.24), 1.0 - glow)
		if i % 2 == 0:
			_carved_duck(p, col)
		else:
			_star(p, 22.0, col)
		if glow > 0.3:
			draw_circle(p, 50.0, Color(1.0, 0.8, 0.4, 0.15 * glow))


func _carved_duck(p: Vector2, col: Color) -> void:
	draw_arc(p, 26.0, PI * 0.9, PI * 2.1, 14, col, 4.0, true)
	draw_circle(p + Vector2(22, -28), 12.0, Color(col, 0.0))
	draw_arc(p + Vector2(22, -28), 12.0, 0.0, TAU, 12, col, 4.0, true)
	draw_line(p + Vector2(32, -28), p + Vector2(50, -24), col, 4.0, true)
	draw_line(p + Vector2(-26, 0), p + Vector2(26, 0), col, 4.0, true)


func _animate_elder(delta: float) -> void:
	# Walks to the stone, holds up the torch; before the last lines steps in front of it.
	var target_x: float = 640.0
	if line >= 6:
		target_x = 900.0
	_elder.position.x = move_toward(_elder.position.x, target_x, delta * 70.0)
	_elder.ground_speed = 60.0 if absf(_elder.position.x - target_x) > 1.0 else 0.0
	if line >= 6:
		# Turned to face us, the stone behind his back.
		_elder.scale.x = -absf(_elder.scale.x) if _elder.position.x >= target_x - 1.0 else absf(_elder.scale.x)
	else:
		_elder.scale.x = absf(_elder.scale.x)
	torch_point = cave_torch()


# =====================================================================================
# Helpers
# =====================================================================================

func _add_duck(look: DuckRig.Look, feet: Vector2, s: float) -> DuckRig:
	var rig := DuckRig.new()
	rig.look = look
	rig.scale = Vector2.ONE * s
	rig.position = feet - Vector2(0, 26.0 * s)
	add_child(rig)
	_actors.append(rig)
	return rig


## Base color with layered translucent brush strokes over it.
func _brush_fill(rect: Rect2, a: Color, b: Color, salt: int) -> void:
	draw_rect(rect, a)
	_brush_strokes(rect, b, salt)


func _brush_strokes(rect: Rect2, color: Color, salt: int) -> void:
	for i in 26:
		var y: float = rect.position.y + _h(salt * 13 + i) * rect.size.y
		var x0: float = rect.position.x - 40.0 + _h(salt * 13 + i + 1) * rect.size.x * 0.5
		var length: float = rect.size.x * (0.3 + _h(salt * 13 + i + 2) * 0.6)
		var h: float = 14.0 + _h(salt * 13 + i + 3) * 30.0
		var pts := PackedVector2Array()
		for k in 9:
			var u: float = float(k) / 8.0
			pts.append(Vector2(x0 + length * u, y - h * 0.5 + sin(u * 7.0 + float(i)) * 4.0))
		for k in range(8, -1, -1):
			var u: float = float(k) / 8.0
			pts.append(Vector2(x0 + length * u, y + h * 0.5 * (1.0 - 0.6 * u) + sin(u * 5.0 + float(i)) * 3.0))
		draw_colored_polygon(pts, Color(color, color.a * (0.35 + 0.3 * _h(i + salt))))
		# Dry-brush streaks at the end of the stroke.
		for k in 3:
			var sy: float = y + (float(k) - 1.0) * h * 0.25
			draw_line(Vector2(x0 + length * 0.8, sy), Vector2(x0 + length * (1.0 + 0.08 * float(k)), sy + 1.0), Color(color, color.a * 0.4), 2.0, true)


func _star(c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var rr: float = r if i % 2 == 0 else r * 0.38
		pts.append(c + Vector2.from_angle(TAU * float(i) / 8.0 - PI * 0.5) * rr)
	draw_colored_polygon(pts, color)
	_ink_outline(pts, 2.4)


func _ink_outline(pts: PackedVector2Array, width: float) -> void:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, INK, width, true)


func _ellipse(c: Vector2, rx: float, ry: float, steps: int, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


func _h(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)
