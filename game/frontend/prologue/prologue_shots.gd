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

## The fall (~13 s). 1 (0-4 s): a velvet red sky of souls framed by glowing clouds, golden
## four-pointed stars twinkling, the ruined city below. 2 (4-8 s): the gold stars dim and warm
## five-pointed stars start to fall, turning, with a big one down the middle; the clouds lose
## their gold. 3 (8-13 s): below a certain height each star turns red, cracks and grows an eye or
## a mouth; where they hit the city: a flash, smoke, sparks and embers, a small jolt of the
## camera, and the skyline lit orange from below.
const SKY_CENTER := Color("5e0f12")
const SKY_MID := Color("430a0c")
const SKY_EDGE := Color("1c0304")
const CLOUD := Color("8f8681")
const CLOUD_CREAM := Color("d9cfc4")
const CLOUD_GOLD := Color("ffd98a")
const GOLD_HI := Color("fff1c2")
const GOLD_MID := Color("e2b866")
const GOLD_LOW := Color("8a6524")
const FALL_CORE := Color("fff4c8")
const FALL_AMBER := Color("ffc35a")
const FALL_ORANGE := Color("e07a1a")
const CORRUPT_RED := Color("c2331f")
const CORRUPT_EDGE := Color("3a0608")
const CITY := Color("120304")
const CORRUPT_Y: float = 330.0
## Golden stars of the sky: center, radius.
const GOLD_STARS: Array = [
	[Vector2(330, 150), 34.0], [Vector2(520, 250), 18.0], [Vector2(660, 140), 60.0], [Vector2(820, 230), 24.0],
	[Vector2(960, 130), 40.0], [Vector2(440, 360), 26.0], [Vector2(760, 360), 16.0], [Vector2(900, 330), 44.0],
	[Vector2(270, 300), 15.0], [Vector2(1040, 300), 20.0], [Vector2(590, 420), 22.0],
]

var _falling: Array = []
var _clouds: Array = []


func _build_fall() -> void:
	_falling.clear()
	for i in 18:
		var r: float = 14.0 + _h(i + 1100) * 32.0
		var dir := Vector2(0.45 if i % 2 == 0 else -0.4, 1.0).normalized()
		var start: float = 4.0 + float(i) * 0.31 + _h(i + 1110) * 0.3
		var land := Vector2(90.0 + _h(i + 1120) * 1100.0, 548.0 + _h(i + 1130) * 30.0)
		var y0: float = -60.0 - r
		var speed: float = maxf(170.0 + _h(i + 1140) * 150.0, (land.y - y0) / (dir.y * maxf(12.5 - start, 0.5)))
		_falling.append(_fall_spec(start, r, dir, land, y0, speed, (_h(i + 1150) - 0.5) * 1.4, i))
	# The big one, straight down the middle with a long trail.
	_falling.append(_fall_spec(4.6, 90.0, Vector2(0.08, 1.0).normalized(), Vector2(660, 560), -200.0, 112.0, 0.4, 99))
	_clouds.clear()
	var banks: Array = [[Vector2(60, 300), Vector2(150, 260)], [Vector2(1220, 300), Vector2(150, 260)],
			[Vector2(140, 70), Vector2(220, 80)], [Vector2(1140, 70), Vector2(220, 80)]]
	for b in banks.size():
		var bank: Array = banks[b]
		for k in 16:
			var c: Vector2 = bank[0] + Vector2((_h(b * 40 + k) - 0.5) * 2.0 * bank[1].x, (_h(b * 40 + k + 17) - 0.5) * 2.0 * bank[1].y)
			_clouds.append([c, 40.0 + _h(b * 40 + k + 33) * 75.0, float(k)])


func _fall_spec(start: float, r: float, dir: Vector2, land: Vector2, y0: float, speed: float, spin: float, salt: int) -> Dictionary:
	var travel: float = (land.y - y0) / dir.y
	var origin: Vector2 = land - dir * travel
	return {"start": start, "r": r, "dir": dir, "origin": origin, "land": land, "speed": speed,
			"hit": start + travel / speed, "spin": spin, "salt": salt}


## Camera jolt right after each impact.
func _fall_shake() -> Vector2:
	var k: float = 0.0
	for s in _falling:
		var since: float = t - float(s["hit"])
		if since >= 0.0 and since < 0.35:
			k = maxf(k, (1.0 - since / 0.35) * (1.6 if float(s["r"]) > 60.0 else 0.8))
	return Vector2(sin(t * 90.0), cos(t * 70.0)) * 6.0 * k


func _draw_fall() -> void:
	# Velvet sky: radial red, darker toward the edges, with a fine nap of noise.
	draw_rect(Rect2(Vector2(-30, -30), DESIGN + Vector2(60, 60)), SKY_EDGE)
	for k in 10:
		var u: float = float(k) / 9.0
		var col: Color = SKY_EDGE.lerp(SKY_MID, minf(u * 1.6, 1.0)).lerp(SKY_CENTER, maxf(u * 1.6 - 0.6, 0.0))
		draw_colored_polygon(_ellipse(Vector2(640, 330), 900.0 * (1.0 - u * 0.75), 560.0 * (1.0 - u * 0.75), 48), Color(col, 0.55))
	for i in 220:
		var p := Vector2(_h(i + 1200) * 1280.0, _h(i + 1201) * 640.0)
		var a: float = 0.03 + 0.03 * sin(t * 1.5 + float(i))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(1.0, 0.7, 0.7, a) if i % 2 == 0 else Color(0, 0, 0, a * 2.0))
	# Fire glow rising from behind the skyline as the stars land.
	var burning: float = 0.0
	for s in _falling:
		if t > float(s["hit"]):
			burning += 0.12 if float(s["r"]) < 60.0 else 0.5
	burning = clampf(burning, 0.0, 1.0)
	if burning > 0.0:
		draw_polygon(PackedVector2Array([Vector2(-30, 330), Vector2(1310, 330), Vector2(1310, 620), Vector2(-30, 620)]),
				PackedColorArray([Color(1.0, 0.45, 0.1, 0.0), Color(1.0, 0.45, 0.1, 0.0), Color(1.0, 0.5, 0.12, 0.75 * burning), Color(1.0, 0.5, 0.12, 0.75 * burning)]))
	# The golden stars of the souls, dimming once the fall begins.
	var gold_k: float = 1.0 - smoothstep(4.0, 7.5, t)
	if gold_k > 0.0:
		for i in GOLD_STARS.size():
			var spec: Array = GOLD_STARS[i]
			var twinkle: float = 1.0 + 0.07 * sin(t * (2.0 + _h(i + 1300) * 2.0) + float(i))
			_gold_star(spec[0], float(spec[1]) * twinkle, sin(t * 0.4 + float(i)) * 0.06, gold_k)
	_draw_clouds(1.0 - smoothstep(4.0, 8.0, t) * 0.75)
	# Falling stars, then the city they crash into.
	for s in _falling:
		_falling_star(s)
	for i in 3:
		_falling_moon(i)
	_draw_city(burning)
	for s in _falling:
		_impact(s)
	# Dark vignette: soft gradients on every side.
	var edge := Color(0, 0, 0, 0.6)
	var clear := Color(0, 0, 0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(-30, -30), Vector2(1310, -30), Vector2(1310, 200), Vector2(-30, 200)]), PackedColorArray([edge, edge, clear, clear]))
	draw_polygon(PackedVector2Array([Vector2(-30, 520), Vector2(1310, 520), Vector2(1310, 750), Vector2(-30, 750)]), PackedColorArray([clear, clear, edge, edge]))
	draw_polygon(PackedVector2Array([Vector2(-30, -30), Vector2(260, -30), Vector2(260, 750), Vector2(-30, 750)]), PackedColorArray([edge, clear, clear, edge]))
	draw_polygon(PackedVector2Array([Vector2(1020, -30), Vector2(1310, -30), Vector2(1310, 750), Vector2(1020, 750)]), PackedColorArray([clear, edge, edge, clear]))


## Fluffy clouds framing the sky: piles of soft balls, lit cream and gold on the side facing the
## middle as if glowing from within. `glow` fades the gold away.
func _draw_clouds(glow: float) -> void:
	var center := Vector2(640, 330)
	var drift := Vector2(sin(t * 0.12) * 10.0, cos(t * 0.09) * 4.0)
	var rim: Color = CLOUD.lerp(CLOUD_CREAM, glow).lerp(CLOUD_GOLD, 0.45 * glow)
	for cloud in _clouds:
		var c: Vector2 = cloud[0] + drift
		var r: float = cloud[1]
		draw_circle(c, r * 1.15, Color(rim, 0.08 * glow))
	for cloud in _clouds:
		var c: Vector2 = cloud[0] + drift
		var r: float = cloud[1]
		var toward: Vector2 = (center - c).normalized()
		draw_circle(c + toward * r * 0.1, r, rim)
	for cloud in _clouds:
		var c: Vector2 = cloud[0] + drift
		var r: float = cloud[1]
		var toward: Vector2 = (center - c).normalized()
		draw_circle(c - toward * r * 0.06, r * 0.97, CLOUD.darkened(0.05 + 0.25 * (1.0 - glow)))


## Four-pointed metallic gold star, the vertical arms longer, with bevel lines and a soft glow.
func _gold_star(c: Vector2, r: float, rot: float, alpha: float) -> void:
	for k in 4:
		draw_circle(c, r * (0.9 + float(k) * 0.45), Color(1.0, 0.85, 0.45, 0.05 * alpha))
	var tips: Array = []
	var inners: Array = []
	for k in 4:
		var a: float = rot + PI * 0.5 * float(k) - PI * 0.5
		var reach: float = r if k % 2 == 0 else r * 0.68
		tips.append(c + Vector2.from_angle(a) * reach)
		inners.append(c + Vector2.from_angle(a + PI * 0.25) * r * 0.2)
	for k in 4:
		var tip: Vector2 = tips[k]
		var left: Vector2 = inners[(k + 3) % 4]
		var right: Vector2 = inners[k]
		draw_polygon(PackedVector2Array([c, left, tip, right]),
				PackedColorArray([Color(GOLD_HI, alpha), Color(GOLD_MID, alpha), Color(GOLD_LOW, alpha), Color(GOLD_MID, alpha)]))
		draw_line(c, tip, Color(1.0, 0.97, 0.85, 0.7 * alpha), maxf(r * 0.04, 1.0), true)
	var outline := PackedVector2Array()
	for k in 4:
		outline.append(tips[k])
		outline.append(inners[k])
	outline.append(tips[0])
	draw_polyline(outline, Color(0.35, 0.22, 0.06, 0.8 * alpha), maxf(r * 0.05, 1.2), true)


## A warm five-pointed star with rounded tips, falling and turning; corrupts below CORRUPT_Y.
func _falling_star(s: Dictionary) -> void:
	var start: float = s["start"]
	if t < start or t >= float(s["hit"]):
		return
	var r: float = s["r"]
	var dir: Vector2 = s["dir"]
	var p: Vector2 = Vector2(s["origin"]) + dir * float(s["speed"]) * (t - start)
	var rot: float = float(s["spin"]) * (t - start)
	var corrupt: float = smoothstep(CORRUPT_Y, CORRUPT_Y + 90.0, p.y)
	# Trail: fading glow behind it (long for the big one).
	var trail: float = r * (6.0 if r > 60.0 else 3.5)
	for k in 10:
		var u: float = float(k) / 10.0
		var q: Vector2 = p - dir * trail * u
		var col: Color = FALL_AMBER.lerp(CORRUPT_RED, corrupt)
		draw_circle(q, r * (0.6 - u * 0.5), Color(col, 0.12 * (1.0 - u)))
	# Halo, reddening as it corrupts.
	var halo: Color = Color(1.0, 0.8, 0.4).lerp(Color(0.9, 0.2, 0.1), corrupt)
	for k in 4:
		draw_circle(p, r * (1.3 + float(k) * 0.55), Color(halo, 0.05))
	var outer: Color = FALL_ORANGE.lerp(CORRUPT_RED, corrupt)
	var mid: Color = FALL_AMBER.lerp(CORRUPT_RED.lightened(0.15), corrupt)
	var core: Color = FALL_CORE.lerp(Color(0.95, 0.45, 0.3), corrupt)
	# Glowing paper lantern: a soft bloom around the edge, then layers brightening to the middle.
	for k in 3:
		draw_colored_polygon(_round_star(p, r * (1.32 - float(k) * 0.1), rot), Color(mid, 0.1))
	var body := _round_star(p, r, rot)
	draw_colored_polygon(body, Color(outer, 0.92))
	draw_colored_polygon(_round_star(p, r * 0.82, rot), Color(outer.lerp(mid, 0.6), 0.9))
	draw_colored_polygon(_round_star(p, r * 0.62, rot), Color(mid, 0.92))
	draw_colored_polygon(_round_star(p, r * 0.42, rot), Color(mid.lerp(core, 0.6), 0.95))
	draw_colored_polygon(_round_star(p, r * 0.24, rot), core)
	# Paper folds: light ridges out to the tips, faint creases toward the notches.
	for k in 5:
		var a: float = rot - PI * 0.5 + TAU * float(k) / 5.0
		draw_line(p, p + Vector2.from_angle(a) * r * 0.92, Color(core, 0.45 * (1.0 - corrupt)), maxf(r * 0.04, 1.0), true)
		draw_line(p, p + Vector2.from_angle(a + TAU / 10.0) * r * 0.5, Color(outer.darkened(0.25), 0.35), maxf(r * 0.03, 1.0), true)
	if corrupt <= 0.0:
		return
	var edge := PackedVector2Array(body)
	edge.append(body[0])
	draw_polyline(edge, Color(CORRUPT_EDGE, corrupt), maxf(r * 0.09, 2.0), true)
	# A black crack across it and a dark eye or mouth.
	var crack := PackedVector2Array()
	for k in 5:
		var u: float = float(k) / 4.0
		crack.append(p + Vector2(lerpf(-r * 0.7, r * 0.6, u), (0.2 - u * 0.5) * r + (r * 0.12 if k % 2 == 1 else -r * 0.08)).rotated(rot))
	draw_polyline(crack, Color(0.03, 0.0, 0.0, corrupt), maxf(r * 0.07, 1.6), true)
	if int(s["salt"]) % 2 == 0:
		var eye := _ellipse(p + Vector2(r * 0.05, -r * 0.05).rotated(rot), r * 0.26, r * 0.15 * corrupt + 0.5, 16, rot)
		draw_colored_polygon(eye, Color(0.04, 0.0, 0.0, corrupt))
		draw_circle(p + Vector2(r * 0.08, -r * 0.05).rotated(rot), r * 0.07, Color(1.0, 0.55, 0.2, corrupt))
	else:
		var grin := PackedVector2Array()
		for k in 12:
			var u: float = float(k) / 11.0
			grin.append(p + Vector2(lerpf(-r * 0.32, r * 0.32, u), r * 0.12 + sin(u * PI) * r * 0.18 * corrupt).rotated(rot))
		for k in range(10, 0, -1):
			var u: float = float(k) / 11.0
			grin.append(p + Vector2(lerpf(-r * 0.32, r * 0.32, u), r * 0.12 + sin(u * PI) * r * 0.05).rotated(rot))
		draw_colored_polygon(grin, Color(0.04, 0.0, 0.0, corrupt))


## A small warm crescent drifting down among the stars, fading out before it reaches the city.
func _falling_moon(i: int) -> void:
	var start: float = 4.4 + float(i) * 1.1
	if t < start:
		return
	var age: float = t - start
	var p := Vector2(220.0 + float(i) * 380.0 + age * 18.0, -40.0 + age * 70.0)
	var fade: float = 1.0 - smoothstep(CORRUPT_Y - 60.0, CORRUPT_Y + 20.0, p.y)
	if fade <= 0.0:
		return
	var r: float = 18.0 + float(i) * 6.0
	var rot: float = sin(age * 0.8 + float(i)) * 0.6
	var pts := PackedVector2Array()
	for k in 20:
		var a: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 19.0)
		pts.append(p + Vector2(cos(a) * r, sin(a) * r).rotated(rot))
	for k in range(18, 0, -1):
		var a: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 19.0)
		pts.append(p + Vector2(cos(a) * r * 0.45 + r * 0.05, sin(a) * r * 0.92).rotated(rot))
	for k in 3:
		draw_circle(p + Vector2(r * 0.5, 0).rotated(rot), r * (1.0 + float(k) * 0.5), Color(1.0, 0.75, 0.35, 0.06 * fade))
	draw_colored_polygon(pts, Color(FALL_AMBER, 0.9 * fade))


## Five-pointed star with rounded tips (a smooth radius curve, so never self-intersecting).
func _round_star(c: Vector2, r: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 60:
		var a: float = TAU * float(k) / 60.0
		var lobe: float = pow(0.5 + 0.5 * cos(5.0 * a), 2.2)
		pts.append(c + Vector2.from_angle(a + rot - PI * 0.5) * r * lerpf(0.44, 1.0, lobe))
	return pts


## Flash, smoke column, sparks and embers where a star hits the city.
func _impact(s: Dictionary) -> void:
	var since: float = t - float(s["hit"])
	if since < 0.0:
		return
	var land: Vector2 = s["land"]
	var big: float = 2.0 if float(s["r"]) > 60.0 else 1.0
	if since < 0.6:
		var fade: float = 1.0 - since / 0.6
		for k in 5:
			draw_circle(land, (20.0 + since * 200.0) * big * (1.0 - float(k) * 0.17), Color(1.0, 0.62 + 0.07 * float(k), 0.25, 0.14 * fade))
	for k in 6:
		var u: float = fposmod(since * 0.25 + float(k) / 6.0, 1.0)
		if since * 0.25 < float(k) / 6.0:
			continue
		var puff: Vector2 = land + Vector2(sin(u * 5.0 + float(k)) * 12.0 + u * 40.0, -u * 260.0 * big)
		draw_colored_polygon(_ellipse(puff, (20.0 + u * 50.0) * big, (16.0 + u * 38.0) * big, 14, u * 3.0),
				Color(0.12, 0.05, 0.05, 0.4 * (1.0 - u)))
	if since < 1.6:
		for k in 12:
			var a: float = PI + 0.15 + _h(int(s["salt"]) * 12 + k) * (PI - 0.3)
			var spd: float = (80.0 + _h(int(s["salt"]) * 12 + k + 5) * 200.0) * big
			var e: Vector2 = land + Vector2.from_angle(a) * since * spd + Vector2(0, since * since * 160.0)
			var col: Color = Color(1.0, 0.85, 0.3) if k % 3 == 0 else Color(1.0, 0.45, 0.12)
			draw_circle(e, 2.2 if k % 3 == 0 else 1.6, Color(col, maxf(1.0 - since / 1.6, 0.0)))


## The ruined city in black-red silhouette with poles and fallen wires, its edge lit by fire.
func _draw_city(burning: float) -> void:
	var skyline := PackedVector2Array([Vector2(-30, 740), Vector2(-30, 580)])
	var x: float = -30.0
	var k: int = 0
	while x < 1310.0:
		var w: float = 60.0 + _h(k + 200) * 90.0
		var h: float = 40.0 + _h(k + 220) * 120.0
		skyline.append(Vector2(x, 612.0 - h))
		skyline.append(Vector2(x + w * 0.5, 612.0 - h + _h(k + 240) * 36.0))
		skyline.append(Vector2(x + w, 612.0 - h * (0.7 + 0.3 * _h(k + 260))))
		x += w
		k += 1
	skyline.append(Vector2(1310, 580))
	skyline.append(Vector2(1310, 740))
	draw_colored_polygon(skyline, CITY)
	if burning > 0.0:
		var rim := PackedVector2Array()
		for i in range(2, skyline.size() - 2):
			rim.append(skyline[i])
		draw_polyline(rim, Color(1.0, 0.55, 0.15, 0.55 * burning), 3.0, true)
	for i in 5:
		var px: float = 120.0 + float(i) * 260.0
		var tilt: float = (_h(i + 300) - 0.5) * 0.6
		var top := Vector2(px, 640) + Vector2.from_angle(-PI * 0.5 + tilt) * 230.0
		draw_line(Vector2(px, 650), top, CITY, 8.0, true)
		draw_line(top + Vector2(-24, 8), top + Vector2(24, -8), CITY, 5.0, true)
		if i < 4:
			var next_top := Vector2(px + 260.0, 640) + Vector2.from_angle(-PI * 0.5 + (_h(i + 301) - 0.5) * 0.6) * 230.0
			var wire := PackedVector2Array()
			for j in 11:
				var u: float = float(j) / 10.0
				wire.append(top.lerp(next_top, u) + Vector2(0, sin(u * PI) * (40.0 + 60.0 * float(i % 2))))
			draw_polyline(wire, CITY, 2.4, true)
	draw_rect(Rect2(-30, 630, 1340, 120), CITY)


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
