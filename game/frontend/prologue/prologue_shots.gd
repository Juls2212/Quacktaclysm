class_name PrologueShots
extends Control
## Paints the shots of the prologue, all in code with thick ink and brush texture:
## CARD the presenters' card on brushed orange with deformed wings and claws reaching in,
## TITLE the cracking QUACKTACLYSM title, EYE an extreme close-up of the hero's eye with falling
## stars in the iris, FALL the burning city under a rain of corrupted stars, FOREST the dark pine
## wood with huge amber eyes, COMIC the grandfather's comic page, CAVE the prophecy stone lit by a
## torch, OUT the fade to the tutorial. The cutscene sets `shot`, `t` (seconds into the shot) and
## `line` (current subtitle); some shots add their own nodes (ducks, comic panels, the torchlight).
## Visual only.

enum Shot { CARD, TITLE, EYE, FALL, FOREST, COMIC, CAVE, OUT }

const INK := Color(0.07, 0.06, 0.08)
const STAR := Color(1.0, 0.82, 0.32)
const EMBER := Color(1.0, 0.45, 0.15)
const DESIGN := Vector2(1280, 720)

@export var presenters_text: String = "LAURA ESCOBAR Y JULIANA PEÑAFIEL PRESENTAN"
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
	shot = next
	t = 0.0
	line = -1
	match next:
		Shot.FOREST:
			pass
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
		var since: float = fposmod(t - 1.2, 1.9)
		if t > 1.2 and since < 0.35:
			target = Vector2(sin(t * 90.0), cos(t * 70.0)) * 7.0 * (1.0 - since / 0.35)
	_shake = target
	if shot == Shot.CAVE and _elder != null:
		_animate_elder(delta)
	if shot == Shot.COMIC:
		_animate_panels()
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
	var reach: float = 1.0 - pow(1.0 - clampf(t / 1.6, 0.0, 1.0), 3.0)
	for i in 5:
		var y: float = 90.0 + float(i) * 130.0 + sin(float(i) * 2.1) * 30.0
		var tremble := Vector2(sin(t * 38.0 + i) * 2.0, cos(t * 33.0 + i * 2.0) * 2.0)
		var root := Vector2(1340.0, y) + tremble
		var length: float = (300.0 + float(i % 3) * 120.0) * reach
		if i % 2 == 0:
			_wing(root, length, PI + 0.18 * (float(i) - 2.0), Color(0.42, 0.04, 0.05) if i % 4 == 0 else INK)
		else:
			_claw_reach(root, length, PI - 0.1 * (float(i) - 2.0), Color(0.3, 0.02, 0.03) if i == 3 else INK)
	var a: float = clampf((t - 0.5) / 0.8, 0.0, 1.0) * clampf((4.6 - t) / 0.5, 0.0, 1.0)
	var lines: PackedStringArray = _wrap_words(presenters_text, 22)
	for k in lines.size():
		draw_string(_font, Vector2(90, 320 + k * 58), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(INK, a))


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

func _draw_eye() -> void:
	var c := Vector2(640, 380)
	var zoom: float = 1.0 + t * 0.012
	_brush_fill(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(0.55, 0.38, 0.22), Color(0.66, 0.47, 0.28), 7)
	# Eye white, iris with brush streaks, pupil.
	draw_colored_polygon(_ellipse(c, 560.0 * zoom, 250.0 * zoom, 40), Color(0.93, 0.86, 0.7))
	var iris_r: float = 215.0 * zoom
	draw_circle(c, iris_r, Color(0.62, 0.32, 0.1))
	for i in 70:
		var a: float = TAU * float(i) / 70.0
		var col: Color = Color(0.8, 0.46, 0.14) if i % 3 == 0 else Color(0.42, 0.2, 0.07)
		draw_line(c + Vector2.from_angle(a) * iris_r * 0.4, c + Vector2.from_angle(a + 0.04) * iris_r * (0.85 + _h(i) * 0.15), col, 4.0, true)
	draw_arc(c, iris_r, 0.0, TAU, 64, INK, 8.0, true)
	var pupil_r: float = 92.0 * zoom
	draw_circle(c, pupil_r, Color(0.03, 0.02, 0.03))
	# Falling stars reflected in the iris and pupil.
	for i in 9:
		var u: float = fposmod(t * (0.12 + _h(i) * 0.08) + _h(i + 30), 1.0)
		var start := c + Vector2((_h(i + 10) - 0.2) * iris_r, -iris_r * 0.85)
		var p: Vector2 = start + Vector2(-0.6, 1.0).normalized() * u * iris_r * 1.5
		if p.distance_to(c) < iris_r * 0.92:
			draw_line(p, p - Vector2(-0.6, 1.0).normalized() * 50.0, Color(1.0, 0.75, 0.35, 0.55), 3.0, true)
			draw_circle(p, 4.0, Color(1.0, 0.95, 0.75, 0.95))
	draw_circle(c + Vector2(-iris_r * 0.35, -iris_r * 0.4), 26.0 * zoom, Color(1, 1, 1, 0.8))
	draw_circle(c + Vector2(-iris_r * 0.15, -iris_r * 0.55), 10.0 * zoom, Color(1, 1, 1, 0.6))
	# One slow blink.
	var blink: float = 0.0
	if t > 6.2 and t < 6.9:
		blink = sin((t - 6.2) / 0.7 * PI)
	var open: float = 1.0 - blink
	var skin := Color(0.78, 0.62, 0.4)
	var lid_line := PackedVector2Array()
	var bottom_line := PackedVector2Array()
	for k in 25:
		var u: float = float(k) / 24.0
		var x: float = lerpf(-40.0, 1320.0, u)
		lid_line.append(Vector2(x, c.y - (170.0 + sin(u * PI) * 70.0) * zoom * open))
		bottom_line.append(Vector2(x, c.y + (170.0 + sin(u * PI) * 40.0) * zoom * open))
	var upper := PackedVector2Array([Vector2(-40, -40), Vector2(1320, -40)])
	for k in range(24, -1, -1):
		upper.append(lid_line[k])
	var lower := PackedVector2Array([Vector2(1320, 760), Vector2(-40, 760)])
	lower.append_array(bottom_line)
	draw_colored_polygon(upper, skin)
	draw_colored_polygon(lower, skin.darkened(0.1))
	_brush_strokes(Rect2(0, 0, 1280, maxf(c.y - 200.0, 40.0)), skin.darkened(0.15), 11)
	# Lid edges in thick ink and the lashes.
	draw_polyline(lid_line, INK, 14.0, true)
	for k in 16:
		var p: Vector2 = lid_line[4 + k]
		draw_line(p, p + Vector2(-18.0 + float(k) * 1.5, -40.0 - _h(k) * 30.0), INK, 7.0, true)
	draw_polyline(bottom_line, INK, 9.0, true)
	var lid_y: float = 170.0 * zoom * open
	# Dark bag under the eye.
	var bag := PackedVector2Array()
	for k in 20:
		var u: float = float(k) / 19.0
		bag.append(Vector2(lerpf(200.0, 1080.0, u), c.y + lid_y + 40.0 + sin(u * PI) * 70.0 * zoom))
	draw_polyline(bag, Color(0.3, 0.18, 0.2, 0.6), 18.0, true)


# =====================================================================================
# 4. The fall
# =====================================================================================

func _draw_fall() -> void:
	var sky := PackedVector2Array([Vector2(-20, -20), Vector2(1300, -20), Vector2(1300, 740), Vector2(-20, 740)])
	draw_polygon(sky, PackedColorArray([Color(0.45, 0.05, 0.04), Color(0.5, 0.08, 0.04), Color(1.0, 0.52, 0.15), Color(0.95, 0.45, 0.12)]))
	_brush_strokes(Rect2(0, 0, 1280, 460), Color(0.75, 0.22, 0.08, 0.5), 21)
	# Columns of smoke rolling up from a few fires in the city.
	for i in 4:
		var base := Vector2(160.0 + float(i) * 300.0 + _h(i) * 80.0, 560.0)
		for k in 9:
			var u: float = fposmod(t * 0.07 + float(k) / 9.0 + _h(i), 1.0)
			var p: Vector2 = base + Vector2(u * u * 140.0 + sin(u * 6.0 + float(k)) * 14.0, -u * 420.0)
			var blob := _ellipse(p, 40.0 + u * 80.0, (40.0 + u * 80.0) * 0.7, 12, u * 2.0 + float(k))
			draw_colored_polygon(blob, Color(0.14, 0.06, 0.06, 0.32 * (1.0 - u) * minf(u * 6.0, 1.0)))
	# Falling stars with trails; each hits the ground on a beat.
	for i in 7:
		var hit_time: float = 1.2 + float(i) * 1.9
		var fall_k: float = clampf(1.0 - (hit_time - t) / 1.1, 0.0, 1.0)
		var land := Vector2(140.0 + _h(i + 7) * 1000.0, 560.0)
		var from: Vector2 = land + Vector2(-380.0, -640.0)
		if fall_k > 0.0 and fall_k < 1.0:
			var p: Vector2 = from.lerp(land, fall_k)
			for k in 8:
				var q: Vector2 = p.lerp(from, float(k) / 16.0)
				draw_circle(q, 9.0 - float(k), Color(EMBER.lerp(STAR, float(k) / 8.0), 0.7 - float(k) * 0.08))
			_star(p, 16.0, STAR)
		var since: float = t - hit_time
		if since >= 0.0 and since < 2.5:
			draw_circle(land, 30.0 + since * 120.0, Color(1.0, 0.85, 0.5, maxf(0.6 - since, 0.0)))
			for k in 10:
				var a: float = PI + _h(i * 10 + k) * PI
				var e: Vector2 = land + Vector2.from_angle(a) * since * (120.0 + _h(k + i) * 160.0) + Vector2(0, since * since * 60.0)
				draw_circle(e, 3.0, Color(EMBER, maxf(1.0 - since * 0.6, 0.0)))
			draw_circle(land + Vector2(0, -20), 50.0 + since * 60.0, Color(0.3, 0.2, 0.16, maxf(0.5 - since * 0.25, 0.0)))
	# Ruined city in black silhouette, poles leaning, wires down.
	var skyline := PackedVector2Array([Vector2(-20, 740), Vector2(-20, 560)])
	var x: float = -20.0
	var k: int = 0
	while x < 1300.0:
		var w: float = 60.0 + _h(k + 200) * 90.0
		var h: float = 50.0 + _h(k + 220) * 140.0
		skyline.append(Vector2(x, 600.0 - h))
		skyline.append(Vector2(x + w * 0.5, 600.0 - h + _h(k + 240) * 40.0))
		skyline.append(Vector2(x + w, 600.0 - h * (0.7 + 0.3 * _h(k + 260))))
		x += w
		k += 1
	skyline.append(Vector2(1300, 560))
	skyline.append(Vector2(1300, 740))
	draw_colored_polygon(skyline, INK)
	for i in 5:
		var px: float = 120.0 + float(i) * 260.0
		var tilt: float = (_h(i + 300) - 0.5) * 0.6
		var top := Vector2(px, 620) + Vector2.from_angle(-PI * 0.5 + tilt) * 260.0
		draw_line(Vector2(px, 620), top, INK, 9.0, true)
		draw_line(top + Vector2(-26, 8), top + Vector2(26, -8), INK, 6.0, true)
		if i < 4:
			var next_top := Vector2(px + 260.0, 620) + Vector2.from_angle(-PI * 0.5 + (_h(i + 301) - 0.5) * 0.6) * 260.0
			var wire := PackedVector2Array()
			for j in 11:
				var u: float = float(j) / 10.0
				wire.append(top.lerp(next_top, u) + Vector2(0, sin(u * PI) * (40.0 + 60.0 * float(i % 2))))
			draw_polyline(wire, INK, 2.4, true)
	draw_rect(Rect2(-20, 600, 1320, 140), INK)


# =====================================================================================
# 5. The forest
# =====================================================================================

## The forest (~11 s): fog and pines, the tiny hero with a torch; a giant duck's eyes open
## between the trees, small ones join around it, it tilts its head, the torch dies and only the
## eyes are left burning in the dark until they close one by one.
func _draw_forest() -> void:
	draw_rect(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(0.04, 0.12, 0.13))
	_brush_strokes(Rect2(0, 0, 1280, 720), Color(0.06, 0.18, 0.19, 0.6), 31)
	var light: float = _torch_light()
	# Far row, then the small ducks peering out from behind it, then the middle row.
	_pine_row(Color(0.06, 0.17, 0.18), 500.0, 0.6, 18, 0)
	_fog_band(440.0, 0.2)
	for d in _small_ducks():
		_duck_silhouette(d["head"], d["r"], d["tilt"], Color(0.02, 0.06, 0.065))
	_fog_band(430.0, 0.34)
	_fog_band(500.0, 0.3)
	_pine_row(Color(0.04, 0.11, 0.12), 590.0, 0.85, 13, 1)
	_fog_band(560.0, 0.22)
	# The giant duck, peering out between the near pines, right of center.
	var big_head := Vector2(800, 250)
	var big_r: float = 150.0
	var tilt: float = _big_tilt()
	_duck_silhouette(big_head, big_r, tilt, Color(0.006, 0.008, 0.01))
	# A veil of fog in front of it: the shape is only guessed at.
	for k in 5:
		var grow: float = 1.6 - float(k) * 0.22
		draw_colored_polygon(_ellipse(big_head + Vector2(0, 40), big_r * grow, big_r * grow * 0.85, 40), Color(0.22, 0.34, 0.35, 0.035))
	_fog_band(330.0, 0.22)
	_fog_band(450.0, 0.2)
	# Near row: a few trunks stand in front of its neck.
	for spec in [[Vector2(700, 720), 520.0], [Vector2(905, 720), 470.0], [Vector2(560, 720), 380.0], [Vector2(1080, 720), 440.0], [Vector2(240, 720), 400.0], [Vector2(1230, 720), 420.0]]:
		_pine(spec[0], spec[1], Color(0.02, 0.05, 0.06))
	_fog_band(660.0, 0.18)
	draw_rect(Rect2(-20, 668, 1320, 80), Color(0.01, 0.03, 0.03))
	# Warm torchlight on the ground and the nearest trunks.
	if light > 0.0:
		var torch: Vector2 = _hero_torch()
		for k in 5:
			draw_circle(torch, 40.0 + k * 34.0, Color(1.0, 0.62, 0.25, 0.05 * light))
		draw_colored_polygon(_ellipse(Vector2(torch.x, 672), 170.0, 18.0, 24), Color(1.0, 0.6, 0.25, 0.16 * light))
		for x in [540.0, 610.0]:
			draw_line(Vector2(x, 670), Vector2(x, 540), Color(1.0, 0.6, 0.3, 0.12 * light), 6.0, true)
	_draw_hero_with_torch(light)
	# When the torch dies the world sinks into black; only the eyes are left.
	var dark: float = 0.93 * smoothstep(7.35, 8.1, t)
	if dark > 0.0:
		draw_rect(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(0, 0, 0, dark))
	# Eyes last, so they burn above the darkness.
	for i in _small_ducks().size():
		var d: Dictionary = _small_ducks()[i]
		var appear: float = clampf((t - float(d["start"])) / 0.6, 0.0, 1.0)
		var close_at: float = 9.3 + float(i) * 0.1
		var open: float = appear * (1.0 - clampf((t - close_at) / 0.25, 0.0, 1.0))
		var period: float = 2.2 + _h(i + 700) * 2.0
		if fposmod(t + _h(i + 710) * period, period) > period - 0.16:
			open *= 0.1
		_duck_eyes(d["head"], d["r"], d["tilt"], open, float(d["fade"]))
	var big_open: float = smoothstep(2.0, 3.6, t)
	if t > 6.35 and t < 7.05:
		big_open *= 1.0 - sin((t - 6.35) / 0.7 * PI)
	big_open *= 1.0 - smoothstep(10.2, 10.6, t)
	_duck_eyes(big_head, big_r, tilt, big_open, 1.0)


## Torch light: steady, then it trembles, shrinks with a couple of sparks and goes out.
func _torch_light() -> float:
	if t < 7.2:
		return 0.9 + 0.1 * sin(t * 11.0) * sin(t * 7.3)
	var dying: float = 1.0 - smoothstep(7.2, 7.9, t)
	return maxf(dying * (0.6 + 0.4 * sin(t * 47.0)), 0.0)


func _big_tilt() -> float:
	# Leaning in with curiosity, then a little more toward the hero.
	return deg_to_rad(-12.0 - 7.0 * smoothstep(5.2, 6.4, t))


## The small ducks behind the far trunks: where, how big, when their eyes show, how fogged.
func _small_ducks() -> Array:
	var out: Array = []
	for i in 8:
		var depth: float = _h(i + 800)
		out.append({
			"head": Vector2(130.0 + float(i) * 140.0 + _h(i + 810) * 50.0, 360.0 + depth * 120.0),
			"r": 22.0 + depth * 22.0,
			"tilt": deg_to_rad((_h(i + 820) - 0.5) * 30.0),
			"start": 3.8 + _h(i + 830) * 2.4,
			"fade": 0.35 + depth * 0.5,
		})
	return out


## A duck head and its long wide neck as one smooth black shape (head center `c`, radius `r`).
func _duck_silhouette(c: Vector2, r: float, tilt: float, color: Color) -> void:
	var pts := PackedVector2Array()
	# Skull: from the lower left, over the top, to the lower right.
	for k in 33:
		var a: float = deg_to_rad(lerpf(150.0, 390.0, float(k) / 32.0))
		pts.append(Vector2(cos(a) * r * 1.02, sin(a) * r * 0.96))
	# Right side of the neck: it pinches in under the head, then widens as it goes down.
	for k in range(1, 13):
		var u: float = float(k) / 12.0
		var x: float = lerpf(r * 0.93, r * 0.88, u) - sin(u * PI) * r * 0.22
		pts.append(Vector2(x, lerpf(r * 0.4, r * 4.8, u)))
	for k in range(12, 0, -1):
		var u: float = float(k) / 12.0
		var x: float = -lerpf(r * 0.87, r * 0.9, u) + sin(u * PI) * r * 0.22
		pts.append(Vector2(x, lerpf(r * 0.5, r * 4.8, u)))
	var shape := PackedVector2Array()
	for p in pts:
		shape.append(c + p.rotated(tilt))
	draw_colored_polygon(shape, color)
	# The short, wide, rounded bill seen from the front, under the eyes: a broad drop.
	var bill := PackedVector2Array()
	for k in 24:
		var a: float = TAU * float(k) / 24.0
		var w: float = r * 0.34 * (1.0 - 0.35 * maxf(-sin(a), 0.0))
		bill.append(c + Vector2(cos(a) * w, r * 0.36 + sin(a) * r * 0.26).rotated(tilt))
	draw_colored_polygon(bill, color)
	# Barely there: fog catching the top of the skull and the bill's lower edge.
	var rim := PackedVector2Array()
	for k in range(8, 25):
		rim.append(shape[k])
	draw_polyline(rim, Color(0.3, 0.42, 0.42, 0.12), 3.0, true)
	var bill_edge := PackedVector2Array()
	for k in range(2, 11):
		bill_edge.append(bill[k])
	draw_polyline(bill_edge, Color(0.3, 0.42, 0.42, 0.1), 2.0, true)


## Two small amber eyes above the bill; `open` lifts them from the bottom like lids.
func _duck_eyes(c: Vector2, r: float, tilt: float, open: float, strength: float) -> void:
	if open <= 0.12 or strength <= 0.0:
		return
	var eye_r: float = clampf(r * 0.105, 3.0, 17.0)
	for side in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(float(side) * r * 0.3, r * 0.04).rotated(tilt)
		var amber := Color(1.0, 0.66, 0.14, strength)
		for k in 3:
			draw_circle(e, eye_r * (2.2 + float(k) * 1.2), Color(1.0, 0.55, 0.1, 0.06 * strength * open))
		var cut: float = e.y + eye_r - 2.0 * eye_r * open
		var lid := PackedVector2Array()
		for k in 40:
			var a: float = TAU * float(k) / 40.0
			var p: Vector2 = e + Vector2(cos(a) * eye_r, sin(a) * eye_r * 0.86)
			lid.append(Vector2(p.x, maxf(p.y, cut)))
		draw_colored_polygon(lid, amber)
		if open > 0.5:
			draw_circle(e + Vector2(0, eye_r * 0.1), eye_r * 0.38, Color(1.0, 0.93, 0.62, strength))


## The hero, tiny and black at the bottom, holding up a torch.
func _draw_hero_with_torch(light: float) -> void:
	var feet := Vector2(600, 670)
	var col := Color(0.01, 0.015, 0.02)
	draw_colored_polygon(_ellipse(feet + Vector2(0, -16), 15.0, 12.0, 20), col)
	draw_circle(feet + Vector2(7, -36), 10.0, col)
	draw_colored_polygon(PackedVector2Array([feet + Vector2(14, -38), feet + Vector2(25, -35), feet + Vector2(14, -32)]), col)
	draw_line(feet + Vector2(-4, -6), feet + Vector2(-5, 0), col, 3.0, true)
	draw_line(feet + Vector2(5, -6), feet + Vector2(6, 0), col, 3.0, true)
	for k in 4:
		draw_line(feet + Vector2(-2, -38), feet + Vector2(-14.0 - float(k) * 2.0, -30.0 + float(k) * 4.0), col, 3.0, true)
	var hand: Vector2 = feet + Vector2(16, -30)
	draw_line(feet + Vector2(6, -24), hand, col, 4.0, true)
	var top: Vector2 = _hero_torch()
	draw_line(hand + Vector2(0, 8), top, Color(0.12, 0.08, 0.05), 3.0, true)
	if light <= 0.08:
		# A last thread of smoke from the dead torch.
		if t < 9.5:
			for k in 4:
				var u: float = fposmod(t * 0.6 + float(k) * 0.25, 1.0)
				draw_circle(top + Vector2(sin(u * 6.0) * 4.0, -u * 30.0), 2.0 + u * 3.0, Color(0.3, 0.32, 0.32, 0.25 * (1.0 - u)))
		return
	var h: float = (16.0 + sin(t * 13.0) * 2.0) * light
	var sway: float = sin(t * 9.0) * 2.0
	var flame := PackedVector2Array()
	for k in 10:
		var a: float = PI * float(k) / 9.0
		flame.append(top + Vector2(cos(a) * 5.0 * light, sin(a) * 3.0 * light))
	flame.append(top + Vector2(-4.0 * light, -h * 0.4))
	flame.append(top + Vector2(sway, -h))
	flame.append(top + Vector2(4.0 * light, -h * 0.4))
	draw_colored_polygon(flame, Color(1.0, 0.55, 0.15))
	draw_colored_polygon(_ellipse(top + Vector2(0, -h * 0.3), 2.2 * light, h * 0.3 + 0.5, 12), Color(1.0, 0.9, 0.55))
	# Sparks as it dies.
	if t > 7.2 and t < 7.9:
		for k in 5:
			var u: float = fposmod((t - 7.2) * 3.0 + float(k) * 0.2, 1.0)
			draw_circle(top + Vector2((_h(k + 900) - 0.5) * 40.0 * u, -u * 34.0), 1.6, Color(1.0, 0.75, 0.3, 1.0 - u))


func _hero_torch() -> Vector2:
	return Vector2(616, 618)


func _pine_row(color: Color, base_y: float, scale_k: float, count: int, row: int) -> void:
	for i in count:
		var px: float = (float(i) + _h(i + row * 40) * 0.6) / float(count) * 1400.0 - 60.0
		_pine(Vector2(px, base_y), (260.0 + _h(i + row * 50) * 160.0) * scale_k, color)


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


func _wrap_words(text: String, width: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var current: String = ""
	for word in text.split(" "):
		if current.length() + word.length() + 1 > width and not current.is_empty():
			out.append(current)
			current = word
		else:
			current = word if current.is_empty() else current + " " + word
	if not current.is_empty():
		out.append(current)
	return out


func _h(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)
