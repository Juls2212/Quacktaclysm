class_name PrologueShots
extends Control
## Paints the shots of the prologue, all in code with thick ink and brush texture:
## CARD the series-style card ("BASADA EN / UNA PROFECÍA" typed, then the tagline scribbled) on
## brushed orange with deformed wings and claws reaching in, TITLE QUACKTACLYSM dropping in letter
## by letter and cracking, PORTRAIT the hero in a full-screen comic panel, EYE an anime-style
## close-up of his eye with red stars falling in the iris, FALL the town seen from a rooftop
## through his eyes as the sky turns red and the stars rain down on it, FOREST the dark pine wood
## with huge amber eyes, COMIC the grandfather's comic page, CAVE the prophecy stone lit by a
## torch, OUT the fade to the tutorial. The cutscene sets `shot`, `t` (seconds into the shot) and
## `line` (current subtitle); some shots add their own nodes (ducks, comic panels, the torchlight).
## Visual only.

enum Shot { CARD, TITLE, PORTRAIT, EYE, FALL, FOREST, COMIC, CAVE, OUT }

const INK := Color(0.07, 0.06, 0.08)
const STAR := Color(1.0, 0.82, 0.32)
const EMBER := Color(1.0, 0.45, 0.15)
const DESIGN := Vector2(1280, 720)
## Card typing: when it starts and keys per second.
const CARD_TYPE_START: float = 0.45
const CARD_TYPE_SPEED: float = 13.0
## Seconds the tagline takes to be scribbled across the card.
const CARD_WRITE_TIME: float = 1.1

## Shot 1: typed letter by letter on an old typewriter (one line per row; the first row small and
## spaced, the rest big), then the tagline is scribbled below by hand (Rock Salt).
@export_multiline var card_typed_text: String = "BASADA EN
UNA PROFECÍA"
@export var card_tagline_text: String = "Una historia quacktástica"
@export var title_text: String = "QUACKTACLYSM"
@export var sound_text: String = "SHHNK!"

var shot: Shot = Shot.CARD
var t: float = 0.0
var line: int = -1
## Set by the cutscene while the cave plays: where the torch is (for the stone's glow).
var torch_point: Vector2 = Vector2.ZERO

var _shake: Vector2 = Vector2.ZERO
var _actors: Array[Node] = []
var _elder: DuckRig = null
var _panels: Array[Control] = []
var _hero: DuckRig = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	_comic_fx = null
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
	elif shot == Shot.PORTRAIT:
		target = _portrait_shake()
	elif shot == Shot.COMIC:
		# A short jolt as each panel lands.
		target = _comic_shake()
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
		Shot.PORTRAIT:
			_draw_portrait()
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
	var fade: float = clampf((4.6 - t) / 0.5, 0.0, 1.0)
	var paper := Color(0.98, 0.6, 0.22)
	# 1. Typed on an old typewriter, letter by letter: each key lands a little off its line, the
	# ink runs uneven (some letters struck twice, some worn), and a caret waits after the last one.
	var font: Font = GameFonts.TYPEWRITER
	var lines: PackedStringArray = card_typed_text.split("\n")
	var typed: float = maxf(t - CARD_TYPE_START, 0.0) * CARD_TYPE_SPEED
	var count: int = 0
	var y: float = 300.0
	var text_right: float = 0.0
	var caret := Vector2(-1, -1)
	for li in lines.size():
		var line: String = lines[li]
		var size: int = 30 if li == 0 and lines.size() > 1 else 54
		var spacing: float = float(size) * (0.22 if size < 40 else 0.08)
		var x: float = 100.0
		for ci in line.length():
			var ch: String = line[ci]
			var adv: float = font.get_char_size(ch.unicode_at(0), size).x + spacing
			if float(count) < typed and ch != " ":
				var age: float = typed - float(count)
				var jitter := Vector2((_h(count + 2700) - 0.5) * 1.6, (_h(count + 2710) - 0.5) * 2.6)
				var ink: float = (0.72 + 0.28 * _h(count + 2720)) * fade
				# The key strikes dark, then settles.
				var strike: float = 1.0 + 0.25 * maxf(1.0 - age * 2.0, 0.0)
				draw_char(font, Vector2(x, y) + jitter, ch, size, Color(INK.darkened(0.2), minf(ink * strike, 1.0)))
				if _h(count + 2730) > 0.72:
					draw_char(font, Vector2(x, y) + jitter + Vector2(0.9, 0.5), ch, size, Color(INK, 0.3 * fade))
				if _h(count + 2740) > 0.5:
					# Worn spots where the ribbon gave out.
					var spot := Vector2(x + adv * (0.2 + 0.5 * _h(count + 2750)), y - float(size) * (0.2 + 0.4 * _h(count + 2760)))
					draw_circle(spot, 1.0 + _h(count + 2770) * 1.2, Color(paper, 0.85 * fade))
			if float(count) < typed:
				caret = Vector2(x + adv, y)
			x += adv
			count += 1
		text_right = maxf(text_right, x)
		y += float(size) * (1.55 if li == 0 else 1.35)
		count += 3
	var done: float = float(count)
	if typed < done and caret.x > 0.0 and fmod(t, 0.5) < 0.3:
		draw_rect(Rect2(caret + Vector2(2, 4), Vector2(16, 3)), Color(INK, 0.8 * fade))
	# 2. The tagline scribbled by hand across the card: bone white over a dark red shadow, tilted,
	# written left to right, with a little tremble as the pen lifts.
	var land: float = CARD_TYPE_START + done / CARD_TYPE_SPEED + 0.3
	var hand: Font = GameFonts.HAND
	var tag_size: int = 34
	var tilt: float = deg_to_rad(-6.0)
	var tag_pos := Vector2(108.0, y + 52.0)
	var tag_w: float = hand.get_string_size(card_tagline_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size).x
	text_right = maxf(text_right, tag_pos.x + tag_w * cos(tilt) + 10.0)
	var since: float = t - land
	if since >= 0.0:
		var n: int = card_tagline_text.length()
		var written: float = since / CARD_WRITE_TIME * float(n)
		var tremble := Vector2.ZERO
		var after: float = since - CARD_WRITE_TIME
		if after > 0.0 and after < 0.3:
			tremble = Vector2(sin(t * 75.0), cos(t * 61.0)) * 2.5 * (1.0 - after / 0.3)
		draw_set_transform(_shake + tag_pos + tremble, tilt, Vector2.ONE)
		var x: float = 0.0
		for i in n:
			var ch: String = card_tagline_text[i]
			var adv: float = hand.get_char_size(ch.unicode_at(0), tag_size).x
			var a: float = clampf(written - float(i), 0.0, 1.0) * fade
			if a > 0.0 and ch != " ":
				draw_char(hand, Vector2(x + 3.0, 4.0), ch, tag_size, Color(0.45, 0.04, 0.05, 0.9 * a))
				draw_char_outline(hand, Vector2(x, 0.0), ch, tag_size, 3, Color(INK, 0.45 * a))
				draw_char(hand, Vector2(x, 0.0), ch, tag_size, Color(0.937, 0.886, 0.784, a))
			x += adv
		draw_set_transform(_shake, 0.0, Vector2.ONE)
	# Wings and claws reach in from the right but stop short of the text.
	var reach: float = 1.0 - pow(1.0 - clampf(t / 1.6, 0.0, 1.0), 3.0)
	for i in 5:
		var cy: float = 90.0 + float(i) * 130.0 + sin(float(i) * 2.1) * 30.0
		var tremble := Vector2(sin(t * 38.0 + i) * 2.0, cos(t * 33.0 + i * 2.0) * 2.0)
		var root := Vector2(1340.0, cy) + tremble
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

## The title (~3.4 s): black with a fine grain, sparks and small stars drifting down behind; the
## letters drop in one by one (0.06 s apart), each landing with a little bounce and a puff of dust;
## once they are all down the crack opens from top to bottom (~0.4 s) and glows yellow in soft
## pulses; it holds, then the cutscene fades it into the hero's portrait. Centred exactly.
const TITLE_CAP: float = 80.0
const TITLE_DROP_START: float = 0.25
const TITLE_DROP_GAP: float = 0.06
const TITLE_DROP_TIME: float = 0.34


func _draw_title() -> void:
	draw_rect(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(0.02, 0.02, 0.03))
	_grain(0.06)
	# Sparks and small stars falling slowly behind.
	for i in 44:
		var speed: float = 40.0 + _h(i) * 70.0
		var p := Vector2(_h(i + 50) * DESIGN.x, fposmod(_h(i + 90) * DESIGN.y + t * speed, DESIGN.y + 40.0) - 20.0)
		if i % 4 == 0:
			_star(p, 3.0 + _h(i + 3) * 4.0, Color(STAR, 0.7))
		else:
			draw_line(p, p - Vector2(1, 7), Color(EMBER, 0.5), 2.0, true)
	var cap: float = TITLE_CAP
	var style := InkType.Style.new()
	style.fill = Color(0.95, 0.88, 0.66)
	style.extrude = Color(0.3, 0.2, 0.1)
	style.ink = INK
	style.depth = 1.1
	style.wobble = 0.0
	var u: float = cap / 10.0
	var width: float = InkType.measure(title_text, cap)
	var extrusion := Vector2(0.45, 0.65) * style.depth * u
	var center: Vector2 = DESIGN * 0.5
	var origin := Vector2(center.x - width * 0.5, center.y - cap * 0.5) - extrusion * 0.5
	var letters: String = title_text.to_upper()
	var x: float = 0.0
	for i in letters.length():
		var ch: String = letters[i]
		var w: float = InkType.measure(ch, cap)
		var start: float = TITLE_DROP_START + float(i) * TITLE_DROP_GAP
		var k: float = clampf((t - start) / TITLE_DROP_TIME, 0.0, 1.0)
		if k > 0.0 and ch != " ":
			# Falls with gravity, then a small bounce and squash as it lands.
			var drop: float = -420.0 * (1.0 - k * k) if k < 1.0 else 0.0
			var since: float = t - start - TITLE_DROP_TIME
			var bounce: float = 0.0
			var squash: float = 1.0
			if since > 0.0 and since < 0.25:
				bounce = -sin(since / 0.25 * PI) * 10.0 * (1.0 - since / 0.25)
				squash = 1.0 - 0.12 * maxf(1.0 - since / 0.12, 0.0)
			var tilt: float = (_h(i + 3000) - 0.5) * 0.08
			var pivot: Vector2 = origin + Vector2(x + w * 0.5, cap)
			style.base = Transform2D(0.0, _shake) * Transform2D(tilt, Vector2(1.0 / squash, squash), 0.0, pivot + Vector2(0, drop + bounce)) * Transform2D(0.0, -pivot)
			InkType.draw(self, ch, origin + Vector2(x, 0), cap, style)
			draw_set_transform(_shake, 0.0, Vector2.ONE)
			# A puff of dust where it lands.
			if since > 0.0 and since < 0.5:
				var puff: float = since / 0.5
				for d in 4:
					var side: float = -1.0 if d % 2 == 0 else 1.0
					var p: Vector2 = pivot + Vector2(side * (w * 0.3 + puff * 26.0 * (1.0 + float(d / 2))), 6.0 - puff * 10.0)
					draw_circle(p, 5.0 + puff * 9.0, Color(0.6, 0.55, 0.48, 0.35 * (1.0 - puff)))
		x += w + InkType.SPACING * u
	# The crack opens top to bottom once every letter is down, then pulses yellow.
	var landed: float = TITLE_DROP_START + float(letters.length() - 1) * TITLE_DROP_GAP + TITLE_DROP_TIME + 0.15
	var crack_k: float = clampf((t - landed) / 0.4, 0.0, 1.0)
	if crack_k > 0.0:
		var pts := PackedVector2Array()
		var steps: int = 9
		for k in steps:
			var v: float = float(k) / float(steps - 1)
			if v > crack_k:
				break
			pts.append(Vector2(center.x + sin(float(k) * 2.3) * 20.0, origin.y - 34.0 + v * (cap + 78.0)))
		if pts.size() > 1:
			var pulse: float = 0.6 + 0.4 * sin((t - landed) * 4.5)
			var glow: float = smoothstep(0.0, 0.5, t - landed - 0.4)
			draw_polyline(pts, Color(STAR, (0.12 + 0.18 * pulse) * glow + 0.05), 30.0, true)
			draw_polyline(pts, INK, 7.0, true)
			draw_polyline(pts, Color(1.0, 0.92, 0.5, 0.4 + 0.6 * pulse * glow), 3.0, true)


## Fine film grain over the whole frame, different every frame.
func _grain(alpha: float) -> void:
	var seed_t: int = int(t * 24.0)
	for i in 240:
		var a: float = fposmod(sin(float(i * 7 + seed_t * 131) * 12.9898) * 43758.5453, 1.0)
		var b: float = fposmod(sin(float(i * 13 + seed_t * 71) * 78.233) * 43758.5453, 1.0)
		var shade: float = 0.3 + 0.5 * fposmod(a * 7.0, 1.0)
		draw_rect(Rect2(Vector2(a * DESIGN.x, b * DESIGN.y), Vector2(2, 2)), Color(shade, shade, shade, alpha))


# =====================================================================================
# 2b. The hero's portrait
# =====================================================================================

## The hero's portrait (~5 s), a full-screen comic panel like the grandfather's: purple rays
## (the eye shot's light) and hard black diagonal shadows behind; the hero from below in a medium
## shot, whole and centred (ruffled dark feathers, his red patched kimono, the sheathed katana over
## his shoulder, eye bags, a small scar, dirt), looking a little to the side. It lands with a
## panel hit, he breathes slowly, the wind stirs his feathers and his kimono, and his gaze turns to
## the front. Then the view pushes slowly into his eye while the edges darken, and the cutscene
## fades softly into the eye shot, which starts framed on the same spot.
const PORTRAIT_LIGHT := Color("4a3ac4")
const PORTRAIT_DARK := Color("22186a")
const HERO_FEATHER := Color(0.85, 0.81, 0.66)
const HERO_RED := Color(0.6, 0.21, 0.2)
const HERO_HAIR := Color(0.12, 0.1, 0.16)
const PORTRAIT_ENTER: float = 0.35
const PORTRAIT_PUSH := Vector2(3.4, 4.9)


func _portrait_shake() -> Vector2:
	var since: float = t - PORTRAIT_ENTER * 0.8
	if since < 0.0 or since > 0.25:
		return Vector2.ZERO
	return Vector2(sin(t * 95.0), cos(t * 80.0)) * 8.0 * (1.0 - since / 0.25)


func _portrait_look() -> float:
	return smoothstep(1.4, 2.6, t)


func _portrait_head() -> Vector2:
	return Vector2(640.0 - 18.0 * (1.0 - _portrait_look()), 292.0 + sin(t * 1.2) * 2.0)


## The eye the camera pushes into (his near eye, once he looks to the front).
func _portrait_eye() -> Vector2:
	return _portrait_head() + Vector2(-42.0, -14.0)


func _draw_portrait() -> void:
	draw_rect(Rect2(Vector2(-30, -30), DESIGN + Vector2(60, 60)), Color(0.03, 0.02, 0.05))
	# Entrance: the panel lands big and a little turned, then settles.
	var hit: float = clampf(t / PORTRAIT_ENTER, 0.0, 1.0)
	var land_scale: float = lerpf(1.18, 1.0, 1.0 - pow(1.0 - hit, 3.0))
	var land_rot: float = sin(hit * 14.0) * 0.03 * (1.0 - hit)
	# Push into the eye at the end, the eye drifting to where the eye shot puts it.
	var push: float = smoothstep(PORTRAIT_PUSH.x, PORTRAIT_PUSH.y, t)
	var zoom: float = land_scale * (1.0 + 3.2 * push * push)
	var eye: Vector2 = _portrait_eye()
	var anchor: Vector2 = DESIGN * 0.5
	var focus: Vector2 = anchor.lerp(eye, smoothstep(0.0, 0.4, push))
	var target: Vector2 = anchor.lerp(IRIS_C, push)
	var xf: Transform2D = Transform2D(0.0, _shake) * Transform2D(land_rot, Vector2(zoom, zoom), 0.0, target) * Transform2D(0.0, -focus)
	draw_set_transform_matrix(xf)
	var panel := Rect2(30, 86, 1220, 548)
	# Purple rays from behind his head and hard diagonal shadows.
	draw_rect(panel, PORTRAIT_DARK)
	var src: Vector2 = _portrait_head() + Vector2(0, -20)
	for k in 22:
		var a: float = TAU * float(k) / 22.0 + t * 0.03
		var ray := PackedVector2Array([src, src + Vector2.from_angle(a - 0.07) * 1500.0, src + Vector2.from_angle(a + 0.07) * 1500.0])
		for piece in Geometry2D.intersect_polygons(ray, _rect_poly(panel)):
			draw_colored_polygon(piece, Color(PORTRAIT_LIGHT, 0.85 if k % 2 == 0 else 0.45))
	draw_colored_polygon(PackedVector2Array([panel.position, Vector2(panel.position.x + 330, panel.position.y), Vector2(panel.position.x, panel.position.y + 300)]), Color(0, 0, 0, 0.8))
	draw_colored_polygon(PackedVector2Array([Vector2(panel.end.x - 420, panel.end.y), panel.end, Vector2(panel.end.x, panel.end.y - 260)]), Color(0, 0, 0, 0.75))
	_draw_hero_bust()
	_ink_outline_on(self, _rect_poly(panel), 9.0)
	draw_set_transform(_shake, 0.0, Vector2.ONE)
	# The edges darken as the view closes in on the eye.
	if push > 0.0:
		for k in 20:
			var f: float = 1.0 - float(k) * 0.035
			var hole := _ellipse(IRIS_C, 900.0 * f * (1.0 - 0.45 * push), 560.0 * f * (1.0 - 0.45 * push), 40)
			var ring := PackedVector2Array([Vector2(-60, -60), Vector2(1340, -60), Vector2(1340, 780), Vector2(-60, 780)])
			for piece in Geometry2D.clip_polygons(ring, hole):
				draw_colored_polygon(piece, Color(0, 0, 0, 0.05 * push))


func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _draw_hero_bust() -> void:
	var look: float = _portrait_look()
	var breath: float = sin(t * 1.2)
	var head: Vector2 = _portrait_head()
	var wind: float = sin(t * 2.6) * 0.5 + sin(t * 4.1) * 0.3
	# The sheathed katana over his right shoulder: the grip and guard stick up past the shoulder.
	var saya_a := Vector2(470, 700)
	var saya_b := Vector2(900, 236)
	var sdir: Vector2 = (saya_b - saya_a).normalized()
	var snrm: Vector2 = sdir.orthogonal()
	_tapered_on(self, PackedVector2Array([saya_a, saya_b]), 30.0, 30.0, INK)
	_tapered_on(self, PackedVector2Array([saya_a, saya_b]), 22.0, 22.0, Color(0.14, 0.08, 0.1))
	var tsuba: Vector2 = saya_b + sdir * 8.0
	draw_colored_polygon(_ellipse(tsuba, 7.0, 26.0, 20, sdir.angle()), Color(0.42, 0.34, 0.12))
	_ink_outline_on(self, _ellipse(tsuba, 7.0, 26.0, 20, sdir.angle()), 3.0)
	var g0: Vector2 = tsuba + sdir * 8.0
	var g1: Vector2 = g0 + sdir * 120.0
	var grip := PackedVector2Array([g0 - snrm * 12.0, g1 - snrm * 11.0, g1 + snrm * 11.0, g0 + snrm * 12.0])
	draw_colored_polygon(grip, Color(0.5, 0.08, 0.08))
	for k in 6:
		var c: Vector2 = g0.lerp(g1, (float(k) + 0.5) / 6.0)
		draw_colored_polygon(PackedVector2Array([c - sdir * 10.0, c - snrm * 9.0, c + sdir * 10.0, c + snrm * 9.0]), Color(0.05, 0.03, 0.04))
	_ink_outline_on(self, grip, 3.0)
	var pommel := PackedVector2Array([g1 - snrm * 12.0, g1 + sdir * 14.0 - snrm * 10.0, g1 + sdir * 14.0 + snrm * 10.0, g1 + snrm * 12.0])
	draw_colored_polygon(pommel, Color(0.55, 0.52, 0.48))
	_ink_outline_on(self, pommel, 3.0)
	# Kimono: broad shoulders spreading out of the bottom, seen from below, breathing.
	var lift: float = breath * 3.0
	var body := PackedVector2Array([Vector2(250, 760), Vector2(300, 520 - lift), Vector2(420, 440 - lift), Vector2(560, 408 - lift), Vector2(720, 408 - lift),
			Vector2(860, 440 - lift), Vector2(980, 520 - lift), Vector2(1030, 760)])
	draw_colored_polygon(body, HERO_RED)
	# The sleeves flutter at the edges in the wind.
	for side in [-1.0, 1.0]:
		var edge := PackedVector2Array()
		for k in 7:
			var v: float = float(k) / 6.0
			var base: Vector2 = Vector2(640.0 + side * (340.0 + v * 70.0), 520.0 + v * 130.0 - lift)
			edge.append(base + Vector2(side * sin(t * 5.0 + v * 6.0) * 6.0 * (0.4 + wind * 0.5), 0))
		draw_polyline(edge, Color(HERO_RED.darkened(0.35), 0.9), 5.0, true)
	var collar_in := PackedVector2Array([Vector2(560, 410 - lift), Vector2(640, 560 - lift), Vector2(720, 410 - lift)])
	draw_colored_polygon(collar_in, Color(0.88, 0.84, 0.74))
	for side in [-1.0, 1.0]:
		var collar := PackedVector2Array([Vector2(640.0 + side * 80.0, 408 - lift), Vector2(640.0 + side * 112.0, 414 - lift), Vector2(640.0 + side * 14.0, 600 - lift), Vector2(640, 560 - lift)])
		draw_colored_polygon(collar, Color(0.2, 0.22, 0.32))
		_ink_outline_on(self, collar, 4.0)
	# The patch sewn on his left shoulder, with big stitches.
	var patch := PackedVector2Array([Vector2(372, 470 - lift), Vector2(450, 458 - lift), Vector2(458, 530 - lift), Vector2(380, 540 - lift)])
	draw_colored_polygon(patch, Color(0.72, 0.55, 0.38))
	for k in 4:
		var a: Vector2 = patch[k]
		var b: Vector2 = patch[(k + 1) % 4]
		for f in [0.3, 0.7]:
			var p: Vector2 = a.lerp(b, f)
			var n: Vector2 = (b - a).normalized().orthogonal() * 5.0
			draw_line(p - n, p + n, INK, 2.0, true)
	_ink_outline_on(self, patch, 3.0)
	for k in 3:
		draw_colored_polygon(_ellipse(Vector2(700 + k * 90, 520 + k * 30 - lift), 22.0, 10.0, 12, 0.3), Color(0.3, 0.12, 0.08, 0.35))
	_ink_outline_on(self, body, 6.0)
	# Neck and head.
	draw_colored_polygon(_ellipse(head + Vector2(0, 104), 70.0, 46.0, 20), HERO_FEATHER.darkened(0.08))
	var skull := _ellipse(head, 112.0, 104.0, 40)
	draw_colored_polygon(skull, HERO_FEATHER)
	draw_colored_polygon(_ellipse(head + Vector2(-58, 40), 18.0, 9.0, 12, 0.4), Color(0.35, 0.25, 0.18, 0.35))
	_ink_outline_on(self, skull, 6.0)
	# Ruffled dark feathers on top, stirred by the wind.
	for k in 15:
		var a: float = -PI + 0.15 + float(k) / 14.0 * (PI - 0.3)
		var root: Vector2 = head + Vector2(cos(a) * 104.0, sin(a) * 96.0)
		var length: float = 46.0 + _h(k + 3100) * 60.0
		var bend: float = (_h(k + 3110) - 0.5) * 0.8 + wind * 0.25 + sin(t * 3.5 + float(k)) * 0.08
		var d0 := Vector2.from_angle(a + bend * 0.4)
		var d1 := Vector2.from_angle(a + bend)
		var mid: Vector2 = root + d0 * length * 0.55
		var lock := PackedVector2Array([root - d0 * 14.0, mid, mid + d1 * length * 0.5])
		_tapered_on(self, lock, 34.0, 2.0, HERO_HAIR)
		if k % 3 == 0:
			draw_line(mid - d0 * 10.0, mid + d1 * 18.0, Color(0.4, 0.36, 0.55, 0.5), 2.0, true)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-112, -10), head + Vector2(-60, -98), head + Vector2(40, -108), head + Vector2(110, -40),
			head + Vector2(90, -52), head + Vector2(10, -70), head + Vector2(-70, -48)]), HERO_HAIR)
	# Eyes: tired, with dark bags, turning from the side to the front.
	for side in [-1.0, 1.0]:
		var e: Vector2 = head + Vector2(side * 42.0 + 22.0 * (1.0 - look), -14.0)
		var far: bool = side > 0.0
		var rx: float = 26.0 * (lerpf(0.75, 1.0, look) if far else 1.0)
		draw_arc(e + Vector2(0, 16), rx * 1.05, 0.3, PI - 0.3, 12, Color(0.3, 0.18, 0.32, 0.8), 6.0, true)
		draw_colored_polygon(_ellipse(e, rx, 15.0, 20), Color(0.95, 0.93, 0.86))
		var gaze := Vector2(lerpf(9.0, 0.0, look) * 1.0, 1.0)
		for piece in Geometry2D.intersect_polygons(_ellipse(e + gaze, 11.0, 11.0, 16), _ellipse(e, rx, 15.0, 20)):
			draw_colored_polygon(piece, Color(0.45, 0.08, 0.12))
		draw_circle(e + gaze, 5.0, Color(0.05, 0.02, 0.04))
		draw_circle(e + gaze + Vector2(3, -4), 2.4, Color(1, 1, 1, 0.9))
		_tapered_on(self, PackedVector2Array([e + Vector2(-rx - 2.0, 2.0), e + Vector2(0, -15.0), e + Vector2(rx + 4.0, -2.0)]), 4.0, 6.0, INK)
	# The beak: from a side wedge to a front view as he turns.
	var side_beak := PackedVector2Array([head + Vector2(60, 4), head + Vector2(110, 10), head + Vector2(162, 26), head + Vector2(150, 40),
			head + Vector2(110, 50), head + Vector2(64, 46), head + Vector2(48, 30), head + Vector2(50, 12)])
	var front_beak := PackedVector2Array()
	for k in 8:
		var a: float = -PI * 0.5 + TAU * float(k) / 8.0 + PI * 0.125
		front_beak.append(head + Vector2(0, 40) + Vector2(cos(a) * 58.0, sin(a) * 26.0))
	var beak := PackedVector2Array()
	for k in 8:
		beak.append(side_beak[k].lerp(front_beak[k], look))
	draw_colored_polygon(beak, Color(0.9, 0.6, 0.27))
	_ink_outline_on(self, beak, 4.0)
	# A small scar over his left eye, stitched.
	var scar_a: Vector2 = head + Vector2(-64, -48)
	var scar_b: Vector2 = head + Vector2(-34, -24)
	draw_line(scar_a, scar_b, Color(0.82, 0.45, 0.45), 4.0, true)
	for f in [0.3, 0.65]:
		var p: Vector2 = scar_a.lerp(scar_b, f)
		draw_line(p + Vector2(-5, 5), p + Vector2(5, -5), INK, 1.6, true)
	# Hard black shadow over his right side (light from the upper left).
	var silhouette: PackedVector2Array = skull
	var merged: Array = Geometry2D.merge_polygons(skull, body)
	if merged.size() == 1:
		silhouette = merged[0]
	var dark := PackedVector2Array([head + Vector2(30, -140), head + Vector2(70, -40), head + Vector2(40, 60), Vector2(700, 470), Vector2(760, 760),
			Vector2(1100, 760), Vector2(1100, 200)])
	for piece in Geometry2D.intersect_polygons(dark, silhouette):
		draw_colored_polygon(piece, Color(0.02, 0.0, 0.05, 0.6))


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
## Length of the eye shot (the cutscene's shot_durations[2]); the push-in spans all of it.
const EYE_SHOT_TIME: float = 13.0


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
	_tapered_on(self, pts, w0, w1, color)


func _tapered_on(ci: CanvasItem, pts: PackedVector2Array, w0: float, w1: float, color: Color) -> void:
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
	ci.draw_colored_polygon(left, color)


func _draw_eye() -> void:
	var breath: float = sin(t * 0.9)
	# Slow continuous push-in toward the iris: ~130 % by the last seconds, then it eases on until
	# the iris almost fills the screen for the cut to the town. The iris drifts to the centre.
	var push: float = clampf(t / EYE_SHOT_TIME, 0.0, 1.0)
	var zoom: float = 1.0 + 0.3 * push + 0.75 * pow(push, 8.0) + 0.008 * breath
	var focus: Vector2 = IRIS_C.lerp(DESIGN * 0.5, smoothstep(0.0, 1.0, push))
	draw_set_transform(_shake + Vector2(0, breath * 3.0) + focus - IRIS_C * zoom, 0.0, Vector2(zoom, zoom))
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
## cathedral on the hill, many lit windows; below, the dark edge of the roof; the view rises and falls with his breath. b (4-7 s): the sky slides, with no cut, into
## blood red and orange; the moon reddens, the houses darken and windows go out one or a few at
## a time all through the change, each flickering before it dies. c (7-13 s):
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
	# The rooftop he stands on.
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
			var lit: bool = _h(id + 2200) > 0.3 and _window_on(id)
			var col: Color = WINDOW_LIT.lerp(Color(1.0, 0.55, 0.2), maxf(blood, burn)) if lit else wall.darkened(0.45)
			if lit:
				draw_rect(Rect2(px - 2.0, py - 2.0, ww + 4.0, wh + 4.0), Color(col, 0.25))
			draw_rect(Rect2(px, py, ww, wh), col)
			draw_rect(Rect2(px, py, ww, wh), Color(HOUSE_INK, 0.7), false, 1.0)


## Whether a lit window is still on. One in five goes out at its own moment spread over the
## whole change of sky (4-7.5 s), flickering for a moment first.
func _window_on(id: int) -> bool:
	if _h(id + 2220) > 0.2:
		return true
	var off_at: float = 4.0 + 3.5 * _h(id + 2210)
	if t >= off_at:
		return false
	if t > off_at - 0.4:
		return sin(t * 48.0 + float(id)) > -0.2
	return true


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


## The dark edge of the roof he stands on, with a chimney at the side.
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

## The grandfather's comic page (~16 s). Three panels, each with its own quick entrance (0.3-0.5 s)
## that lands with a short shake of the page. RED: a low-angle medium shot of the grandfather
## (head, beard, shoulders and kimono, his hard black shadow cast on the wall behind); it slides in from the left with speed
## lines, its ink border drawing itself and an ink splash in a corner. BLUE: his two tired eyes
## painted like the prologue's eye (heavy upper lash line with a few short lashes, dark bags,
## fine wrinkles, thick bushy white brows, dark irises with a small glint; one slow blink); it drops from above and bounces,
## with a white flash and halftone dots that come and go. YELLOW: the katana alone across the
## panel (a near-black blade wreathed in red fire, a small square guard, a long red grip wrapped
## in black diamonds, a metal pommel, a star flashing on the blade); it bursts out of the centre (0 -> 110 % -> 100 %) over
## radial impact lines, and "SHHNK!" pops with its own bounce. At the end of the page all the
## panels leave together under a sweep of ink.
const COMIC_RECTS: Array = [Rect2(40, 50, 640, 570), Rect2(705, 50, 535, 270), Rect2(705, 345, 535, 275)]
const COMIC_COLORS: Array = [Color(0.78, 0.12, 0.1), Color(0.05, 0.3, 0.33), Color(0.98, 0.78, 0.12)]
const COMIC_STARTS: Array = [0.4, 5.4, 10.4]
const COMIC_ENTER: Array = [0.4, 0.45, 0.4]
## When the panels leave (the page lasts the cutscene's shot_durations[5] = 16 s).
const COMIC_EXIT: Vector2 = Vector2(15.1, 15.9)
const ELDER_SKIN := Color(0.72, 0.76, 0.68)

var _comic_fx: Control = null


func _build_comic() -> void:
	for i in COMIC_RECTS.size():
		var rect: Rect2 = COMIC_RECTS[i]
		var panel := Control.new()
		panel.position = rect.position
		panel.size = rect.size
		panel.pivot_offset = rect.size * 0.5
		panel.clip_contents = true
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.visible = false
		panel.set_meta("color", COMIC_COLORS[i])
		panel.set_meta("start", COMIC_STARTS[i])
		panel.set_meta("kind", i)
		panel.draw.connect(_draw_panel.bind(panel))
		add_child(panel)
		_actors.append(panel)
		_panels.append(panel)
		if i == 0:
			var shade := Control.new()
			shade.size = rect.size
			shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shade.draw.connect(_draw_hard_shadow.bind(shade))
			panel.add_child(shade)
		# On top of each panel: its border and its entrance effects.
		var frame := Control.new()
		frame.size = rect.size
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.draw.connect(_draw_panel_frame.bind(frame, panel))
		panel.add_child(frame)
		panel.set_meta("frame", frame)
	# Page-level effects over the panels (the ink sweep at the end).
	_comic_fx = Control.new()
	_comic_fx.size = DESIGN
	_comic_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_comic_fx.draw.connect(_draw_comic_sweep)
	add_child(_comic_fx)
	_actors.append(_comic_fx)


## Short jolt of the whole page when a panel lands.
func _comic_shake() -> Vector2:
	var k: float = 0.0
	for i in COMIC_STARTS.size():
		var since: float = t - float(COMIC_STARTS[i]) - float(COMIC_ENTER[i]) * 0.8
		if since >= 0.0 and since < 0.25:
			k = maxf(k, 1.0 - since / 0.25)
	return Vector2(sin(t * 95.0), cos(t * 80.0)) * 7.0 * k


func _animate_panels() -> void:
	var leave: float = smoothstep(COMIC_EXIT.x, COMIC_EXIT.y, t)
	for panel in _panels:
		var kind: int = panel.get_meta("kind")
		var rect: Rect2 = COMIC_RECTS[kind]
		var since: float = t - float(panel.get_meta("start"))
		var enter: float = COMIC_ENTER[kind]
		var u: float = clampf(since / enter, 0.0, 1.0)
		panel.visible = since >= 0.0
		var pos: Vector2 = rect.position
		var sc := Vector2.ONE
		match kind:
			0:
				# Slides in from the left and squashes a little on the hit.
				pos.x -= (rect.end.x + 80.0) * pow(1.0 - u, 3.0)
				var hit: float = clampf((since - enter) / 0.2, 0.0, 1.0)
				if since > enter * 0.85 and hit < 1.0:
					sc = Vector2(1.0 - 0.05 * sin(hit * PI), 1.0 + 0.04 * sin(hit * PI))
			1:
				# Drops from above and bounces.
				pos.y -= 420.0 * (1.0 - _bounce(u))
			2:
				# Bursts out of the centre: 0 -> 110 % -> 100 %.
				var grow: float = 1.1 * smoothstep(0.0, 0.7, u) - 0.1 * smoothstep(0.7, 1.0, u)
				sc = Vector2.ONE * maxf(grow, 0.001)
		# All together off the page at the end, under the ink sweep.
		pos.x += 1500.0 * leave * leave
		panel.position = pos + _shake
		panel.scale = sc * (1.0 - 0.15 * leave)
		panel.rotation = -0.06 * leave
		panel.queue_redraw()
		var frame: Control = panel.get_meta("frame")
		frame.queue_redraw()
	if _comic_fx != null:
		_comic_fx.queue_redraw()


func _bounce(u: float) -> float:
	if u < 0.6:
		var a: float = u / 0.6
		return a * a
	var b: float = (u - 0.6) / 0.4
	return 1.0 - 0.14 * sin(b * PI) * (1.0 - b)


func _draw_comic_page() -> void:
	_brush_fill(Rect2(Vector2(-20, -20), DESIGN + Vector2(40, 40)), Color(0.9, 0.85, 0.72), Color(0.86, 0.8, 0.66), 41)
	# Speed lines trailing the red panel as it slides in.
	var red_since: float = t - float(COMIC_STARTS[0])
	if red_since >= 0.0 and red_since < 0.6:
		var fade: float = 1.0 - red_since / 0.6
		var rect: Rect2 = COMIC_RECTS[0]
		var lead: float = rect.position.x - (rect.end.x + 80.0) * pow(1.0 - clampf(red_since / float(COMIC_ENTER[0]), 0.0, 1.0), 3.0)
		for k in 12:
			var y: float = rect.position.y + 30.0 + float(k) * (rect.size.y - 60.0) / 11.0
			var length: float = 120.0 + _h(k + 2400) * 240.0
			draw_line(Vector2(lead - length, y), Vector2(lead - 8.0, y), Color(INK, 0.6 * fade), 3.0 + _h(k + 2410) * 3.0, true)
	# Radial impact lines behind the yellow panel as it bursts out.
	var y_since: float = t - float(COMIC_STARTS[2])
	if y_since >= 0.0 and y_since < 0.9:
		var fade2: float = 1.0 - y_since / 0.9
		var c: Vector2 = (COMIC_RECTS[2] as Rect2).get_center()
		for k in 28:
			var a: float = TAU * float(k) / 28.0 + _h(k + 2420) * 0.1
			var r0: float = 160.0 + y_since * 220.0
			var r1: float = r0 + 90.0 + _h(k + 2430) * 140.0
			var w: float = 4.0 + _h(k + 2440) * 6.0
			var d := Vector2.from_angle(a)
			draw_colored_polygon(PackedVector2Array([c + d * r0 - d.orthogonal() * w * 0.2, c + d * r1 - d.orthogonal() * w, c + d * r1 + d.orthogonal() * w,
					c + d * r0 + d.orthogonal() * w * 0.2]), Color(INK, 0.85 * fade2))


func _draw_panel(panel: Control) -> void:
	var s: Vector2 = panel.size
	var color: Color = panel.get_meta("color")
	var kind: int = panel.get_meta("kind")
	var since: float = t - float(panel.get_meta("start"))
	panel.draw_rect(Rect2(Vector2.ZERO, s), color)
	if kind == 0:
		# Low angle: light rays fanning up behind him.
		var foot := Vector2(s.x * 0.5, s.y + 60.0)
		for k in 9:
			var a: float = -PI * 0.5 + (float(k) - 4.0) * 0.17
			panel.draw_colored_polygon(PackedVector2Array([foot, foot + Vector2.from_angle(a - 0.05) * 900.0, foot + Vector2.from_angle(a + 0.05) * 900.0]),
					Color(1.0, 0.5, 0.35, 0.18 if k % 2 == 0 else 0.08))
	# Halftone dots in the shadow corner.
	for i in 90:
		var p := Vector2(_h(i + kind * 100) * s.x, _h(i + kind * 100 + 1) * s.y)
		if p.x + p.y < s.x * 0.8:
			continue
		panel.draw_circle(p, 3.0 + _h(i) * 3.0, Color(0, 0, 0, 0.25))
	match kind:
		0:
			_comic_elder(panel, s, since)
		1:
			_comic_eyes(panel, s, since)
		2:
			_comic_katana(panel, s, since)


## Border and entrance effects drawn over a panel's content.
func _draw_panel_frame(frame: Control, panel: Control) -> void:
	var s: Vector2 = frame.size
	var kind: int = panel.get_meta("kind")
	var since: float = t - float(panel.get_meta("start"))
	var border := Rect2(Vector2(3, 3), s - Vector2(6, 6))
	if kind == 0:
		# The border draws itself around the panel.
		var k: float = clampf(since / 0.45, 0.0, 1.0)
		var corners: Array[Vector2] = [border.position, Vector2(border.end.x, border.position.y), border.end, Vector2(border.position.x, border.end.y)]
		var perimeter: float = (border.size.x + border.size.y) * 2.0
		var left: float = perimeter * k
		for e in 4:
			var a: Vector2 = corners[e]
			var b: Vector2 = corners[(e + 1) % 4]
			var length: float = a.distance_to(b)
			if left <= 0.0:
				break
			var part: float = minf(left / length, 1.0)
			frame.draw_line(a, a.lerp(b, part), INK, 7.0, true)
			left -= length
		# Ink splash in the corner once it lands.
		var splash: float = clampf((since - 0.3) / 0.15, 0.0, 1.0)
		if splash > 0.0:
			var c := Vector2(s.x - 34.0, 40.0)
			frame.draw_colored_polygon(_splat(c, 30.0 * splash, 7), INK)
			for d in 6:
				var p: Vector2 = c + Vector2.from_angle(_h(d + 2450) * TAU) * (40.0 + _h(d + 2460) * 40.0) * splash
				frame.draw_circle(p, 3.0 + _h(d + 2470) * 5.0, INK)
	else:
		frame.draw_rect(border, INK, false, 7.0)
	if kind == 1:
		# White flash on landing, then halftone dots that come and go.
		var land: float = since - float(COMIC_ENTER[1]) * 0.6
		if land >= 0.0 and land < 0.3:
			frame.draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.85 * (1.0 - land / 0.3)))
		var dots: float = clampf(land / 0.2, 0.0, 1.0) * (1.0 - clampf((land - 0.35) / 0.4, 0.0, 1.0))
		if dots > 0.0:
			var step: float = 14.0
			for gy in int(s.y / step) + 1:
				for gx in int(s.x / step) + 1:
					var p := Vector2(float(gx) * step + (step * 0.5 if gy % 2 == 1 else 0.0), float(gy) * step)
					var r: float = 1.0 + 4.0 * (p.x / s.x) * dots
					frame.draw_circle(p, r, Color(0.05, 0.12, 0.2, 0.5 * dots))


## A splotch of ink: a lumpy round blob.
func _splat(c: Vector2, r: float, salt: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		pts.append(c + Vector2.from_angle(a) * maxf(r, 1.0) * (0.75 + _h(salt * 16 + k + 2480) * 0.5))
	return pts


## The ink sweep that carries the panels off at the end of the page.
func _draw_comic_sweep() -> void:
	var k: float = smoothstep(COMIC_EXIT.x - 0.1, COMIC_EXIT.y, t)
	if k <= 0.0:
		return
	var front: float = -200.0 + 1700.0 * k
	if front < 60.0:
		return
	var pts := PackedVector2Array([Vector2(-40, -40)])
	for i in 13:
		var y: float = lerpf(-40.0, 760.0, float(i) / 12.0)
		pts.append(Vector2(front + sin(float(i) * 1.7) * 40.0 + _h(i + 2490) * 50.0, y))
	pts.append(Vector2(-40, 760))
	_comic_fx.draw_colored_polygon(pts, INK)
	for i in 10:
		var y: float = 60.0 + float(i) * 66.0
		var tip: float = front + 40.0 + _h(i + 2500) * 120.0
		_comic_fx.draw_line(Vector2(front - 20.0, y), Vector2(tip, y + 6.0), INK, 4.0 + _h(i + 2510) * 6.0, true)


func _draw_hard_shadow(node: Control) -> void:
	var s: Vector2 = node.size
	node.draw_colored_polygon(PackedVector2Array([Vector2(0, s.y * 0.62), Vector2(s.x * 0.34, s.y), Vector2(0, s.y)]), Color(0, 0, 0, 0.8))
	node.draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.78, 0), Vector2(s.x, 0), Vector2(s.x, s.y * 0.42)]), Color(0, 0, 0, 0.7))
	node.draw_rect(Rect2(0, s.y - 46.0, s.x, 46.0), Color(0, 0, 0, 0.85))


## The grandfather from below, facing the reader: a broad kimono with its collar and sash, a long
## white beard, the beak seen from underneath, small tired eyes under bushy white brows; lit red
## from the left, the right side cut out in hard black shadow, his shadow cast on the wall.
func _comic_elder(panel: Control, s: Vector2, since: float) -> void:
	var feather := Color(0.9, 0.86, 0.74)
	var kimono := Color(0.42, 0.47, 0.55)
	var shadow := Color(0.05, 0.01, 0.02)
	var sway: float = sin(since * 1.4) * 4.0
	var head := Vector2(s.x * 0.5, 232.0)
	var skull := _ellipse(head, 104.0, 96.0, 40)
	var beard := PackedVector2Array([head + Vector2(-86, 40), head + Vector2(-96, 120), head + Vector2(-60, 210), head + Vector2(-24 + sway, 300),
			head + Vector2(0 + sway, 268), head + Vector2(22 + sway, 304), head + Vector2(58, 214), head + Vector2(96, 120), head + Vector2(86, 40)])
	# Kimono: broad shoulders spreading out of the bottom (seen from below), a V collar, the sash.
	var body := PackedVector2Array([Vector2(30, s.y + 10), Vector2(70, 430), Vector2(150, 362), Vector2(250, 330), Vector2(s.x - 250, 330),
			Vector2(s.x - 150, 362), Vector2(s.x - 70, 430), Vector2(s.x - 30, s.y + 10)])
	# Head and beard overlap, the beard overlaps the kimono: merged in that order they make one shape.
	var silhouette: PackedVector2Array = _union_outline(skull, beard, body)
	# His hard shadow cast on the wall behind, up and to the right.
	panel.draw_colored_polygon(Transform2D(0.0, Vector2(1.1, 1.06), 0.0, Vector2(40, -40)) * silhouette, Color(0.12, 0.0, 0.02, 0.8))
	panel.draw_colored_polygon(body, kimono)
	var inner := PackedVector2Array([Vector2(head.x - 88, 336), Vector2(head.x, 500), Vector2(head.x + 88, 336)])
	panel.draw_colored_polygon(inner, Color(0.86, 0.82, 0.72))
	for side in [-1.0, 1.0]:
		var collar := PackedVector2Array([Vector2(head.x + side * 88.0, 334), Vector2(head.x + side * 118.0, 340), Vector2(head.x + side * 16.0, 520), Vector2(head.x, 500)])
		panel.draw_colored_polygon(collar, Color(0.22, 0.24, 0.3))
		_ink_outline_on(panel, collar, 5.0)
	panel.draw_rect(Rect2(60, 520, s.x - 120, 40), Color(0.2, 0.12, 0.14))
	panel.draw_line(Vector2(60, 520), Vector2(s.x - 60, 520), INK, 5.0, true)
	# Fold lines in the sleeves.
	for k in 4:
		var x: float = 110.0 + float(k) * 34.0
		panel.draw_line(Vector2(x, 450 + k * 10), Vector2(x + 30, 560), Color(INK, 0.6), 4.0, true)
		panel.draw_line(Vector2(s.x - x, 450 + k * 10), Vector2(s.x - x - 30, 560), Color(INK, 0.6), 4.0, true)
	_ink_outline_on(panel, body, 6.0)
	# Head: round, ruffled feathers at the crown.
	panel.draw_colored_polygon(skull, feather)
	for k in 7:
		var a: float = -PI * 0.5 + (float(k) - 3.0) * 0.28
		var root: Vector2 = head + Vector2.from_angle(a) * 92.0
		var tip: Vector2 = root + Vector2.from_angle(a + (_h(k + 2600) - 0.5) * 0.8) * (26.0 + _h(k + 2610) * 22.0)
		var side_v: Vector2 = Vector2.from_angle(a).orthogonal() * 9.0
		panel.draw_colored_polygon(PackedVector2Array([root - side_v, tip, root + side_v]), feather)
		panel.draw_polyline(PackedVector2Array([root - side_v, tip, root + side_v]), INK, 4.0, true)
	_ink_outline_on(panel, skull, 6.0)
	# Long white beard falling from under the beak, swaying a little.
	panel.draw_colored_polygon(beard, Color(0.96, 0.95, 0.9))
	for k in 6:
		var x: float = -60.0 + float(k) * 24.0
		panel.draw_line(head + Vector2(x, 70), head + Vector2(x * 0.6 + sway * 0.5, 230 - absf(x) * 0.6), Color(0.62, 0.6, 0.56), 3.0, true)
	_ink_outline_on(panel, beard, 5.0)
	# The beak seen from below: wide and flat, the nostrils on top, the lower part darker.
	var beak := _ellipse(head + Vector2(0, 28), 62.0, 30.0, 28)
	panel.draw_colored_polygon(beak, Color(0.92, 0.58, 0.22))
	panel.draw_colored_polygon(_ellipse(head + Vector2(0, 40), 50.0, 16.0, 20), Color(0.7, 0.38, 0.14))
	panel.draw_circle(head + Vector2(-16, 18), 5.0, INK)
	panel.draw_circle(head + Vector2(16, 18), 5.0, INK)
	_ink_outline_on(panel, beak, 5.0)
	# Small tired eyes under bushy white brows.
	for side in [-1.0, 1.0]:
		var e: Vector2 = head + Vector2(side * 46.0, -26.0)
		panel.draw_colored_polygon(_ellipse(e, 18.0, 10.0, 16), Color(0.97, 0.95, 0.88))
		panel.draw_circle(e + Vector2(side * -2.0, 2.0), 7.0, INK)
		panel.draw_circle(e + Vector2(side * -2.0 + 3.0, -1.0), 2.0, Color(1, 1, 1))
		panel.draw_line(e + Vector2(-20, -4), e + Vector2(20, -6), INK, 6.0, true)
		panel.draw_arc(e + Vector2(0, 12), 18.0, 0.3, PI - 0.3, 10, Color(0.3, 0.2, 0.25, 0.8), 4.0, true)
		for k in 6:
			var b: Vector2 = e + Vector2(side * (-16.0 + float(k) * 8.0), -24.0)
			var tip: Vector2 = b + Vector2(side * (18.0 + _h(k + 2620) * 14.0), -10.0 + _h(k + 2630) * 12.0)
			panel.draw_line(b, tip, INK, 9.0, true)
			panel.draw_line(b, tip, Color(0.97, 0.96, 0.92), 5.0, true)
	# Hard black shadow over his right side (light from the left).
	var dark := PackedVector2Array([head + Vector2(30, -110), head + Vector2(70, -60), head + Vector2(40, 0), head + Vector2(80, 80),
			head + Vector2(50, 170), Vector2(head.x + 70, 400), Vector2(s.x - 140, 480), Vector2(s.x - 40, s.y + 10), Vector2(s.x + 20, s.y + 10),
			Vector2(s.x + 20, 300), head + Vector2(130, -120)])
	var shade_pieces: Array = Geometry2D.intersect_polygons(dark, silhouette)
	for piece in shade_pieces:
		panel.draw_colored_polygon(piece, Color(shadow, 0.88))


## The silhouette of head, kimono and beard together (for clipping his shadow to him).
func _union_outline(a: PackedVector2Array, b: PackedVector2Array, c: PackedVector2Array) -> PackedVector2Array:
	var merged: Array = Geometry2D.merge_polygons(a, b)
	var out: PackedVector2Array = merged[0] if not merged.is_empty() else a
	var more: Array = Geometry2D.merge_polygons(out, c)
	return more[0] if not more.is_empty() else out


## The grandfather's two tired eyes, painted like the prologue's eye: grey-green feathers lit
## from the upper right, almond eyes with a heavy upper lash line and curved lashes, dark bags,
## long messy white brows, dark irises with a small glint. One slow blink.
func _comic_eyes(panel: Control, s: Vector2, since: float) -> void:
	var light := ELDER_SKIN.lightened(0.14)
	var dark := ELDER_SKIN.darkened(0.3)
	panel.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y), Vector2(0, s.y)]),
			PackedColorArray([ELDER_SKIN, light, ELDER_SKIN, dark]))
	var blink: float = smoothstep(2.4, 2.9, since) * (1.0 - smoothstep(3.0, 3.6, since))
	var open: float = 1.0 - blink
	for side in [-1.0, 1.0]:
		var c := Vector2(s.x * 0.5 + float(side) * 128.0, s.y * 0.56)
		_old_eye(panel, c, float(side), open, since)
	# Two frown lines between the brows.
	for k in 2:
		var x: float = s.x * 0.5 + (float(k) - 0.5) * 18.0
		panel.draw_polyline(PackedVector2Array([Vector2(x, s.y * 0.56 - 96.0), Vector2(x + (float(k) - 0.5) * 6.0, s.y * 0.56 - 76.0), Vector2(x + (float(k) - 0.5) * 3.0, s.y * 0.56 - 56.0)]),
				Color(EYE_INK, 0.3), 2.2, true)
	# Blue shadow from the top-left, hard edged.
	panel.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(s.x * 0.3, 0), Vector2(0, s.y * 0.55)]), Color(0.03, 0.16, 0.2, 0.75))


func _old_eye(panel: Control, c: Vector2, side: float, open: float, since: float) -> void:
	# Inner corner toward the nose (the middle of the panel).
	var inner := c + Vector2(-side * 78.0, 8.0)
	var outer := c + Vector2(side * 82.0, -4.0)
	var up_ctrl := c + Vector2(side * 6.0, -62.0)
	var low_ctrl := c + Vector2(side * 4.0, 40.0)
	var upper := PackedVector2Array()
	var lower := PackedVector2Array()
	for k in 21:
		var u: float = float(k) / 20.0
		var lo: Vector2 = _bezier(inner, low_ctrl, outer, u)
		lower.append(lo)
		upper.append(lo.lerp(_bezier(inner, up_ctrl, outer, u), open))
	# Dark bags: soft shading and two heavy arcs under the eye.
	for k in 6:
		var f: float = 1.0 - float(k) * 0.12
		panel.draw_colored_polygon(_ellipse(c + Vector2(0, 46), 86.0 * f, 26.0 * f, 24), Color(0.25, 0.18, 0.3, 0.07))
	for k in 2:
		var bag := PackedVector2Array()
		for i in 13:
			var u: float = float(i) / 12.0
			bag.append(_bezier(inner, low_ctrl + Vector2(0, 30.0 + float(k) * 16.0), outer, u) + Vector2(0, 10.0 + float(k) * 8.0))
		_tapered_on(panel, bag, 5.0 - float(k) * 2.0, 1.0, Color(0.22, 0.14, 0.26, 0.75 - float(k) * 0.25))
	if open > 0.15:
		var white := PackedVector2Array(upper)
		for k in range(19, 0, -1):
			white.append(lower[k])
		panel.draw_colored_polygon(white, Color(0.93, 0.92, 0.85))
		var shade := PackedVector2Array(upper)
		for k in range(19, 0, -1):
			var u: float = float(k) / 20.0
			shade.append(upper[k] + Vector2(0, 18.0 * sin(u * PI) * open))
		panel.draw_colored_polygon(shade, Color(0.6, 0.62, 0.6, 0.7))
		# Dark iris clipped to the eye, with a small glint.
		var gaze := Vector2(side * 4.0 + sin(since * 0.7) * 3.0, 4.0)
		for ring in 6:
			var r: float = 30.0 * (1.0 - float(ring) * 0.12)
			var col: Color = Color(0.2, 0.15, 0.12).lerp(Color(0.06, 0.04, 0.04), float(ring) / 5.0)
			for piece in Geometry2D.intersect_polygons(_ellipse(c + gaze, r, r, 24), white):
				panel.draw_colored_polygon(piece, col)
		panel.draw_circle(c + gaze + Vector2(9, -9), 5.0, Color(1, 1, 1, 0.9))
		panel.draw_circle(c + gaze + Vector2(-8, 8), 2.0, Color(1, 1, 1, 0.5))
	# Heavy upper lash line and curved lashes swinging out to the side.
	_tapered_on(panel, upper, 4.0, 10.0, EYE_INK)
	_tapered_on(panel, lower, 1.5, 2.5, Color(EYE_INK, 0.7))
	# Only two or three short lashes at the outer corner: an old man's eye.
	for k in 3:
		var base: Vector2 = upper[17 + k]
		var d0 := Vector2(side * (0.6 + 0.15 * float(k)), -1.0 * lerpf(-0.7, 1.0, open)).normalized()
		_tapered_on(panel, PackedVector2Array([base, base + d0 * 5.0, base + (d0 + Vector2(side * 0.4, 0.1)).normalized() * 9.0]), 3.4, 0.6, EYE_INK)
	# Fine wrinkles: crow's feet at the outer corner and soft lines under the bags.
	var crow: Vector2 = outer + Vector2(side * 10.0, 2.0)
	for k in 3:
		var a: float = (float(k) - 1.0) * 0.36
		var d := Vector2(side, 0.0).rotated(a * side)
		panel.draw_polyline(PackedVector2Array([crow, crow + d * 14.0 + Vector2(0, 2), crow + d * 28.0 + Vector2(0, float(k) - 1.0) * 4.0]), Color(EYE_INK, 0.3), 2.0, true)
	for k in 2:
		var line := PackedVector2Array()
		for i in 9:
			var u: float = float(i) / 8.0
			line.append(_bezier(inner + Vector2(side * 14.0, 40.0), c + Vector2(0, 92.0 + float(k) * 13.0), outer + Vector2(-side * 6.0, 34.0), u) + Vector2(0, float(k) * 6.0))
		panel.draw_polyline(line, Color(EYE_INK, 0.22 - float(k) * 0.06), 2.0, true)
	# Thick bushy white brows: three layers of dense messy tufts, some long, falling a little
	# over the eye.
	var tufts: Array = []
	for layer in 3:
		for k in 16:
			var salt: int = k + layer * 40 + int(side) * 9
			var u: float = (float(k) + _h(salt + 2560) * 0.8) / 16.0
			# Arched brow: low at the nose, high in the middle, dropping at the temple.
			var arch: float = sin(u * PI * 0.9 + 0.2) * 18.0 + u * 6.0
			var root: Vector2 = c + Vector2(-side * 86.0 + side * u * 164.0, -74.0 - arch + float(layer) * 6.0 + (_h(salt + 2565) - 0.5) * 12.0)
			var length: float = 22.0 + _h(salt + 2570) * 26.0 + (30.0 if _h(salt + 2580) > 0.82 else 0.0)
			# Each tuft points its own way: most sweep out and down over the eye, some stick up.
			var up: bool = _h(salt + 2585) > 0.72
			var angle: float = (-0.55 - _h(salt + 2590) * 0.5) if up else (0.15 + _h(salt + 2590) * 0.6 + float(layer) * 0.12)
			var sway: float = sin(since * 1.3 + float(k) + float(layer)) * 0.05
			var d0 := Vector2(side, 0.0).rotated((angle + sway) * side)
			var d1 := Vector2(side, 0.0).rotated(clampf(angle * 1.4 + 0.15 + sway, -1.0, 0.85) * side)
			var ctrl: Vector2 = root + d0 * length * 0.55
			var end: Vector2 = ctrl + d1 * length * 0.5
			var curve := PackedVector2Array()
			for i in 6:
				curve.append(_bezier(root, ctrl, end, float(i) / 5.0))
			tufts.append([curve, layer])
	for tuft in tufts:
		_brush_on(panel, tuft[0], 14.0 - float(tuft[1]) * 2.0, 2.5, Color(EYE_INK, 0.85))
	for tuft in tufts:
		var layer: int = tuft[1]
		var col: Color = [Color(0.74, 0.75, 0.71), Color(0.88, 0.88, 0.84), Color(0.98, 0.97, 0.93)][layer]
		_brush_on(panel, tuft[0], 10.0 - float(layer) * 1.5, 1.2, col)


## The katana alone, whole and easy to read, across the panel from the tip (lower left) to the
## pommel (upper right): a slightly curved near-black blade with a bright light edge, a small dark
## guard, a long red grip wrapped in black diamonds and a metal pommel. Red fire licks off the
## blade behind it, with red drops around and a yellow-white star flashing on the blade; a light
## rim keeps the sword's silhouette clear of the flames. It slides in along its own length over
## 0.6 s and the fire grows with it.
const BLADE_BLACK := Color("1a0e10")
const FLAME_DEEP := Color("d42a1a")
const FLAME_HOT := Color("ff6a3a")


func _comic_katana(panel: Control, s: Vector2, since: float) -> void:
	var draw_k: float = clampf(since / 0.6, 0.0, 1.0)
	var fire: float = smoothstep(0.0, 1.0, clampf(since / 0.9, 0.0, 1.0))
	var tip_home := Vector2(34, s.y - 34)
	var pommel_home := Vector2(s.x - 30, 34)
	var dir: Vector2 = (pommel_home - tip_home).normalized()
	var nrm: Vector2 = dir.orthogonal()
	var total: float = tip_home.distance_to(pommel_home)
	# It slides in along its length (from the lower left), easing to a stop.
	var slide: Vector2 = -dir * total * 0.8 * pow(1.0 - draw_k, 3.0)
	var tip: Vector2 = tip_home + slide
	var blade_len: float = total * 0.6
	var guard: Vector2 = tip + dir * blade_len
	var grip_a: Vector2 = guard + dir * 12.0
	var grip_b: Vector2 = grip_a + dir * (total * 0.33)
	# Motion lines along the draw, below the sword.
	for k in 6:
		var p: Vector2 = tip + dir * (80.0 + float(k) * 44.0) - nrm * (34.0 + float(k % 3) * 12.0)
		panel.draw_line(p, p - dir * (40.0 + 70.0 * (1.0 - draw_k) + 20.0), Color(INK, 0.35), 3.0, true)
	# Red drops spattered around the blade.
	for k in 26:
		var u: float = _h(k + 2900)
		var side: float = -1.0 if _h(k + 2910) > 0.45 else 1.0
		var p: Vector2 = tip + dir * blade_len * u + nrm * side * (30.0 + _h(k + 2920) * 80.0) * fire - dir * _h(k + 2930) * 30.0
		p += Vector2(sin(t * 2.0 + float(k)), cos(t * 1.7 + float(k))) * 1.5
		panel.draw_circle(p, (1.5 + _h(k + 2940) * 3.5) * fire, FLAME_DEEP if k % 3 else FLAME_HOT)
	# The blade's spine: slightly curved (the back bows away from the edge), pointed at the tip.
	var back := PackedVector2Array()
	var edge := PackedVector2Array()
	for k in 15:
		var u: float = float(k) / 14.0
		var p: Vector2 = tip + dir * blade_len * u + nrm * sin(u * PI) * 9.0
		var half: float = lerpf(1.5, 9.0, smoothstep(0.0, 0.12, u))
		back.append(p + nrm * half)
		edge.append(p - nrm * half)
	var blade := PackedVector2Array(back)
	var rev := PackedVector2Array(edge)
	rev.reverse()
	blade.append_array(rev)
	# Fire behind the sword: a glow along the blade and tongues swept back toward the tip.
	if fire > 0.02:
		_brush_on(panel, PackedVector2Array([tip + dir * 30.0, tip.lerp(guard, 0.5), guard - dir * 10.0]), 16.0 * fire + 4.0, 30.0 * fire + 6.0, Color(FLAME_DEEP, 0.75))
		for k in 12:
			var u: float = 0.12 + 0.8 * (float(k) + 0.5) / 12.0
			var base: Vector2 = tip + dir * blade_len * u + nrm * sin(u * PI) * 9.0
			var side: float = -1.0 if (k * 7) % 3 == 0 else 1.0
			var strength: float = (0.35 + 0.65 * u) * fire
			var length: float = (45.0 + 95.0 * u) * strength * (0.6 + 0.7 * _h(k + 2950))
			if length < 14.0:
				continue
			var sway: float = sin(t * 5.5 + float(k) * 1.7) * 0.18
			_flame_tongue(panel, base, dir, nrm * side, length, 16.0 + 18.0 * strength, sway, Color(FLAME_DEEP, 0.92))
			_flame_tongue(panel, base, dir, nrm * side, length * 0.6, 9.0 + 10.0 * strength, sway * 1.4, Color(FLAME_HOT, 0.9))
	# A light rim round the whole sword so it reads before the fire.
	var grip := PackedVector2Array([grip_a - nrm * 11.0, grip_b - nrm * 10.0, grip_b + nrm * 10.0, grip_a + nrm * 11.0])
	var pommel := PackedVector2Array([grip_b - nrm * 11.0, grip_b - nrm * 9.0 + dir * 16.0, grip_b + nrm * 9.0 + dir * 16.0, grip_b + nrm * 11.0])
	var tsuba: Vector2 = guard + dir * 5.0
	var square := PackedVector2Array([tsuba + (-dir * 6.0 - nrm * 16.0), tsuba + (dir * 6.0 - nrm * 16.0), tsuba + (dir * 6.0 + nrm * 16.0), tsuba + (-dir * 6.0 + nrm * 16.0)])
	for shape in [blade, grip, pommel, square]:
		var ring := PackedVector2Array(shape)
		ring.append(shape[0])
		panel.draw_polyline(ring, Color(1.0, 0.95, 0.82, 0.95), 9.0, true)
	# Blade: near black, the bright edge, a glint running along it.
	panel.draw_colored_polygon(blade, BLADE_BLACK)
	panel.draw_polyline(edge, Color(0.95, 0.82, 0.78), 2.2, true)
	_ink_outline_on(panel, blade, 2.6)
	var g: float = fposmod(t * 0.9, 1.4)
	if g < 1.0:
		var a: Vector2 = edge[clampi(int(g * 13.0), 1, 13)]
		panel.draw_line(a - dir * 20.0, a + dir * 20.0, Color(1.0, 0.96, 0.88, 0.9), 2.6, true)
	# Small dark guard.
	panel.draw_colored_polygon(square, Color(0.12, 0.08, 0.08))
	panel.draw_line(tsuba - nrm * 12.0, tsuba + nrm * 12.0, Color(0.45, 0.3, 0.26), 1.5, true)
	_ink_outline_on(panel, square, 3.0)
	# Long red grip wrapped in black diamonds.
	panel.draw_colored_polygon(grip, Color(0.62, 0.1, 0.08))
	var diamonds: int = 8
	for k in diamonds:
		var c: Vector2 = grip_a.lerp(grip_b, (float(k) + 0.5) / float(diamonds))
		var step: float = grip_a.distance_to(grip_b) / float(diamonds) * 0.5
		panel.draw_colored_polygon(PackedVector2Array([c - dir * step, c - nrm * 9.0, c + dir * step, c + nrm * 9.0]), Color(0.05, 0.03, 0.04))
		panel.draw_colored_polygon(PackedVector2Array([c - dir * 3.0, c - nrm * 3.0, c + dir * 3.0, c + nrm * 3.0]), Color(0.85, 0.2, 0.14))
	_ink_outline_on(panel, grip, 3.0)
	# Metal pommel.
	panel.draw_colored_polygon(pommel, Color(0.55, 0.53, 0.5))
	panel.draw_line(grip_b + dir * 5.0 - nrm * 7.0, grip_b + dir * 5.0 + nrm * 7.0, Color(0.9, 0.9, 0.86), 2.0, true)
	_ink_outline_on(panel, pommel, 3.0)
	# Yellow-white star flashing on the blade.
	var spark: Vector2 = tip + dir * blade_len * 0.62 + nrm * 9.0
	var flash: float = (0.75 + 0.25 * sin(t * 9.0)) * (0.6 + 0.6 * (1.0 - draw_k)) * smoothstep(0.0, 0.1, since)
	if flash > 0.15:
		var r: float = 32.0 * flash
		panel.draw_circle(spark, r * 0.9, Color(1.0, 0.85, 0.4, 0.25))
		var star := PackedVector2Array()
		for k in 8:
			var a2: float = float(k) * PI * 0.25 + 0.3
			star.append(spark + Vector2.from_angle(a2) * (r if k % 2 == 0 else r * 0.18))
		panel.draw_colored_polygon(star, Color(1.0, 0.92, 0.55))
		panel.draw_circle(spark, r * 0.16, Color(1, 1, 1))
	if since > 0.3:
		# "SHHNK!" pops out with its own little bounce, in the free corner above the sword.
		var style := InkType.Style.new()
		style.fill = Color(1.0, 0.86, 0.15)
		style.extrude = Color(0.55, 0.25, 0.02)
		style.depth = 1.0
		var b: float = clampf((since - 0.3) / 0.35, 0.0, 1.0)
		var pop: float = 0.6 + 0.6 * smoothstep(0.0, 0.5, b) - 0.2 * smoothstep(0.5, 1.0, b) + 0.06 * sin(b * PI * 3.0) * (1.0 - b)
		var cap: float = minf(56.0, 56.0 * (s.x * 0.5) / maxf(InkType.measure(sound_text, 56.0), 1.0)) * pop
		InkType.draw(panel, sound_text, Vector2(26.0 + (56.0 - cap) * 0.5, 22.0 + (56.0 - cap) * 0.4), cap, style)


## A tongue of fire rising off the blade at `base`: a broad foot along the blade, an outer edge
## bulging out toward `out`, the tip swept back (against `dir`) and swaying by `sway` radians.
func _flame_tongue(ci: CanvasItem, base: Vector2, dir: Vector2, out: Vector2, length: float, foot: float, sway: float, color: Color) -> void:
	var b0: Vector2 = base - dir * foot * 0.5
	var b1: Vector2 = base + dir * foot * 0.5
	var tip: Vector2 = base + (out * 0.62 - dir * 0.78).rotated(sway * signf(out.cross(dir))) * length
	var c_out: Vector2 = b1 + out * length * 0.62 + dir * length * 0.05
	var c_in: Vector2 = b0 + out * length * 0.12 - dir * length * 0.35
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(_bezier(b1, c_out, tip, float(i) / 8.0))
	for i in range(1, 8):
		pts.append(_bezier(tip, c_in, b0, float(i) / 8.0))
	ci.draw_colored_polygon(pts, color)


## A brush stroke thinning from `w0` to `w1` made of round segments (no polygon, so tight curls
## never break it).
func _brush_on(ci: CanvasItem, pts: PackedVector2Array, w0: float, w1: float, color: Color) -> void:
	var n: int = pts.size()
	for i in range(n - 1):
		var w: float = lerpf(w0, w1, float(i) / float(maxi(n - 1, 1)))
		ci.draw_line(pts[i], pts[i + 1], color, w, true)
		ci.draw_circle(pts[i], w * 0.5, color)


func _ink_outline_on(ci: CanvasItem, pts: PackedVector2Array, width: float) -> void:
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	ci.draw_polyline(ring, INK, width, true)


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
