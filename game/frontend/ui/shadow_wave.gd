@tool
class_name ShadowWave
extends Node2D
## The wave of shadow ducks chasing the hero across the main menu: a huge black mass of deformed
## duck silhouettes piled on each other, dozens of eyes blinking out of step, open beaks full of
## teeth, wings like claws, loose feathers flapping off like crows. It breathes, creeps forward
## and falls back; now and then a claw or a beak lunges at the hero and stops at the edge of the
## torchlight (`light_center`, `light_radius`). Visual only. Origin = screen top-left.

const INK := Color(0.106, 0.098, 0.122)
const MASS := Color(0.035, 0.035, 0.05)
const RIM := Color(0.2, 0.21, 0.26)
const EYE_WHITE := Color(0.95, 0.93, 0.84)
const EYE_GOLD := Color(1.0, 0.84, 0.3)
const TEETH := Color(0.9, 0.88, 0.8)

## Screen x of the wave's front at rest.
@export var front: float = 300.0
@export var ground_y: float = 612.0
## Where the torch light is and how far it keeps the shadows back.
@export var light_center: Vector2 = Vector2(440, 470)
@export var light_radius: float = 170.0

var _time: float = 0.0
var _lunge_t: float = -1.0
var _next_lunge: float = 3.0
var _lunge_kind: int = 0
var _lunge_y: float = 420.0


func _process(delta: float) -> void:
	_time += delta
	_next_lunge -= delta
	if _next_lunge <= 0.0 and _lunge_t < 0.0:
		_lunge_t = 0.0
		_lunge_kind = int(_h(int(_time * 10.0)) * 2.0)
		_lunge_y = 330.0 + _h(int(_time * 7.0) + 3) * 200.0
	if _lunge_t >= 0.0:
		_lunge_t += delta / 0.9
		if _lunge_t >= 1.0:
			_lunge_t = -1.0
			_next_lunge = 3.5 + _h(int(_time * 13.0)) * 3.5
	queue_redraw()


## Front edge x at height y: a leaning crest, breathing and creeping, held back by the light.
func edge_x(y: float) -> float:
	var breath: float = sin(_time * 0.7) * 14.0
	var creep: float = sin(_time * 0.21) * 34.0 + sin(_time * 0.53) * 10.0
	var u: float = clampf(y / ground_y, 0.0, 1.0)
	var x: float = front + creep + breath * (0.5 + u) + 90.0 * sin(u * PI * 0.92) - 110.0 * (1.0 - u)
	x += sin(y * 0.031 + _time * 1.3) * 9.0 + sin(y * 0.083 - _time * 0.9) * 5.0
	# The torchlight pushes the shadow back.
	var d: float = Vector2(x, y).distance_to(light_center)
	if d < light_radius:
		x -= (light_radius - d) * 0.9
	return x


func _draw() -> void:
	# The mass itself.
	var body := PackedVector2Array([Vector2(-40, ground_y + 120), Vector2(-40, -40)])
	var y: float = -40.0
	while y <= ground_y + 120.0:
		body.append(Vector2(edge_x(y), y))
		y += 18.0
	draw_colored_polygon(body, MASS)
	# Piled-up duck silhouettes: rims of heads and backs inside the mass.
	for i in 26:
		var hy: float = 20.0 + _h(i * 3) * (ground_y - 40.0)
		var hx: float = edge_x(hy) - 30.0 - _h(i * 3 + 1) * 230.0
		var r: float = 20.0 + _h(i * 3 + 2) * 26.0
		var bob: float = sin(_time * (0.8 + _h(i) * 0.6) + i) * 4.0
		draw_arc(Vector2(hx, hy + bob), r, PI * 1.05, PI * 1.95, 12, RIM, 2.2, true)
	_hatch_mass()
	# Duck heads bulging out along the front, beaks open on rows of teeth.
	for i in 9:
		var hy: float = 60.0 + float(i) * 62.0 + sin(_time * 0.6 + i) * 6.0
		var hx: float = edge_x(hy) + 6.0
		var r: float = 26.0 + _h(i + 40) * 16.0
		_head(Vector2(hx, hy), r, i)
	# Wings like claws reaching out between the heads.
	for i in 5:
		var cy: float = 110.0 + float(i) * 105.0
		_claw(Vector2(edge_x(cy) - 4.0, cy), 46.0 + _h(i + 70) * 24.0, -0.2 + sin(_time * 0.9 + i) * 0.25, i)
	# Eyes scattered all through the mass.
	for i in 34:
		var ey: float = 20.0 + _h(i * 5 + 100) * (ground_y - 30.0)
		var ex: float = edge_x(ey) - 20.0 - _h(i * 5 + 101) * 280.0
		_eye(Vector2(ex, ey), 3.0 + _h(i * 5 + 102) * 4.0, i * 5 + 103)
	_draw_lunge()
	_draw_crows()


func _head(c: Vector2, r: float, i: int) -> void:
	draw_circle(c, r, MASS)
	draw_arc(c, r, -PI * 0.6, PI * 0.4, 14, RIM, 2.4, true)
	var gape: float = 0.35 + 0.25 * sin(_time * (1.2 + _h(i) * 0.8) + i)
	var tip := c + Vector2(r * 1.75, r * 0.1)
	var upper := PackedVector2Array([c + Vector2(r * 0.6, -r * 0.35), tip, c + Vector2(r * 0.7, r * 0.05)])
	var lower := PackedVector2Array([c + Vector2(r * 0.7, r * 0.2), tip + Vector2(-r * 0.25, r * gape * 1.4), c + Vector2(r * 0.55, r * 0.55)])
	draw_colored_polygon(upper, MASS)
	draw_colored_polygon(lower, MASS)
	_outline(upper, RIM, 2.0)
	_outline(lower, RIM, 2.0)
	# Crooked teeth along both jaws.
	for k in 4:
		var t: float = 0.15 + 0.2 * float(k)
		var a: Vector2 = upper[2].lerp(upper[1], t)
		draw_colored_polygon(PackedVector2Array([a + Vector2(-2.5, 0), a + Vector2(2.5, 0), a + Vector2((_h(i * 9 + k) - 0.5) * 3.0, 6.0 + _h(i * 9 + k + 4) * 4.0)]), TEETH)
		var b: Vector2 = lower[0].lerp(lower[1], t)
		draw_colored_polygon(PackedVector2Array([b + Vector2(-2.0, 0), b + Vector2(2.0, 0), b + Vector2(0.5, -5.0)]), TEETH)
	_eye(c + Vector2(r * 0.25, -r * 0.3), r * 0.2, i * 31 + 7)
	if i % 3 == 0:
		_eye(c + Vector2(-r * 0.25, -r * 0.45), r * 0.14, i * 31 + 9)


func _claw(root: Vector2, length: float, angle: float, i: int) -> void:
	for k in 3:
		var a: float = angle + (float(k) - 1.0) * 0.32
		var mid: Vector2 = root + Vector2.from_angle(a) * length * 0.55 + Vector2(0, -6)
		var tip: Vector2 = root + Vector2.from_angle(a + 0.35) * length * (0.85 + 0.1 * float(k))
		var pts := PackedVector2Array([root + Vector2(0, -7), mid + Vector2(0, -3), tip, mid + Vector2(0, 4), root + Vector2(0, 7)])
		draw_colored_polygon(pts, MASS)
		draw_polyline(PackedVector2Array([root + Vector2(0, -7), mid + Vector2(0, -3), tip]), RIM, 1.8, true)


func _eye(c: Vector2, r: float, salt: int) -> void:
	var period: float = 2.0 + _h(salt) * 3.5
	var t: float = fposmod(_time + _h(salt + 1) * period, period)
	if t > period - 0.16:
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), RIM, 1.4, true)
		return
	var col: Color = EYE_GOLD if salt % 3 == 0 else EYE_WHITE
	draw_circle(c, r * 2.2, Color(col, 0.08))
	var lid := PackedVector2Array()
	for k in 10:
		var a: float = TAU * float(k) / 10.0
		lid.append(c + Vector2(cos(a) * r, sin(a) * r * 0.75))
	draw_colored_polygon(lid, col)
	draw_circle(c + Vector2(sin(_time * 0.7 + salt) * r * 0.3, 0), maxf(r * 0.3, 0.8), MASS)


## Now and then one claw or beak shoots out toward the hero and snaps back at the light's edge.
func _draw_lunge() -> void:
	if _lunge_t < 0.0:
		return
	var k: float = sin(PI * _lunge_t)
	var root := Vector2(edge_x(_lunge_y), _lunge_y)
	var target: Vector2 = light_center + (root - light_center).normalized() * light_radius * 0.95
	var reach: Vector2 = root.lerp(target, k)
	var d: Vector2 = (reach - root)
	if d.length() < 4.0:
		return
	var n: Vector2 = d.normalized().orthogonal()
	var arm := PackedVector2Array([root - n * 16.0, root.lerp(reach, 0.6) - n * 9.0, reach, root.lerp(reach, 0.6) + n * 9.0, root + n * 16.0])
	draw_colored_polygon(arm, MASS)
	_outline(arm, RIM, 2.0)
	if _lunge_kind == 0:
		for s in [-1.0, 0.0, 1.0]:
			var tip: Vector2 = reach + d.normalized().rotated(float(s) * 0.5) * 22.0
			draw_line(reach, tip, MASS, 6.0, true)
			draw_line(reach, tip, RIM, 1.4, true)
	else:
		var jaw := PackedVector2Array([reach - n * 12.0, reach + d.normalized() * 30.0, reach + n * 12.0])
		draw_colored_polygon(jaw, MASS)
		for t in [0.3, 0.55, 0.8]:
			var p: Vector2 = (reach - n * 12.0).lerp(reach + d.normalized() * 30.0, t)
			draw_colored_polygon(PackedVector2Array([p, p + n * 5.0 + d.normalized() * 2.0, p + d.normalized() * 4.0]), TEETH)
		_eye(reach - d.normalized() * 10.0, 4.0, 77)


## Loose feathers flapping off the wave like a flock of crows.
func _draw_crows() -> void:
	for i in 12:
		var u: float = fposmod(_time * (0.07 + _h(i + 200) * 0.06) + _h(i + 210), 1.0)
		var start := Vector2(edge_x(100.0 + _h(i + 220) * 300.0) - 20.0, 100.0 + _h(i + 220) * 300.0)
		var p: Vector2 = start + Vector2(u * 900.0, -u * 260.0 + sin(u * 12.0 + i) * 20.0)
		var flap: float = sin(_time * 9.0 + i) * 5.0
		var s: float = (1.0 - u * 0.5) * (0.8 + _h(i + 230) * 0.6)
		var c := Color(MASS, 1.0 - u * 0.6)
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(-10, -flap) * s, p + Vector2(-4, 3) * s]), c)
		draw_colored_polygon(PackedVector2Array([p, p + Vector2(10, -flap) * s, p + Vector2(4, 3) * s]), c)
		draw_circle(p + Vector2(0, 1) * s, 2.2 * s, c)


## Pen hatching across the mass, so the darkness reads as drawn ink.
func _hatch_mass() -> void:
	for i in 40:
		var hy: float = _h(i + 300) * ground_y
		var hx: float = edge_x(hy) - 40.0 - _h(i + 301) * 240.0
		var l: float = 18.0 + _h(i + 302) * 22.0
		for k in 3:
			var off := Vector2(float(k) * 4.0, float(k) * 2.0)
			draw_line(Vector2(hx, hy) + off, Vector2(hx + l * 0.7, hy - l * 0.7) + off, Color(RIM, 0.45), 1.0, true)


func _outline(pts: PackedVector2Array, color: Color, width: float) -> void:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, color, width, true)


func _h(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)
