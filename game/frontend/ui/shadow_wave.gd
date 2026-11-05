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
	# Small heads piled up deep in the mass, half melted into the black.
	for i in 24:
		var hy: float = 30.0 + _h(i * 3) * (ground_y - 60.0)
		var hx: float = edge_x(hy) - 50.0 - _h(i * 3 + 1) * 220.0
		var r: float = 10.0 + _h(i * 3 + 2) * 10.0
		var bob: float = sin(_time * (0.7 + _h(i) * 0.7) + i * 1.3) * 5.0
		_duck_head(Vector2(hx + bob, hy), r, _aim(Vector2(hx, hy), i, 0.35), _gape(i + 50, 0.25), 0.0, i + 50, 0.45, i % 4 == 0)
	_hatch_mass()
	# Medium heads crowding the front edge.
	for i in 8:
		var hy: float = 40.0 + float(i) * 72.0 + _h(i + 20) * 30.0
		var hx: float = edge_x(hy) - 18.0 + _peek(i + 20) * 10.0
		var r: float = 18.0 + _h(i + 21) * 9.0
		_duck_head(Vector2(hx, hy), r, _aim(Vector2(hx, hy), i + 20, 0.5), _gape(i + 20, 0.45), 0.0, i + 20, 0.75, true)
	# Wings like claws reaching out between the heads.
	for i in 5:
		var cy: float = 110.0 + float(i) * 105.0
		_claw(Vector2(edge_x(cy) - 4.0, cy), 46.0 + _h(i + 70) * 24.0, -0.2 + sin(_time * 0.9 + i) * 0.25, i)
	# More eyes scattered through the mass (the heads carry their own).
	for i in 22:
		var ey: float = 20.0 + _h(i * 5 + 100) * (ground_y - 30.0)
		var ex: float = edge_x(ey) - 20.0 - _h(i * 5 + 101) * 280.0
		_eye(Vector2(ex, ey), 3.0 + _h(i * 5 + 102) * 4.0, i * 5 + 103)
	# A few big heads at the very front: they lean out, duck back, snap their bills.
	for i in 5:
		var hy: float = 95.0 + float(i) * 108.0 + _h(i + 90) * 26.0
		var hx: float = edge_x(hy) + 4.0 + _peek(i + 90) * 18.0
		var r: float = 30.0 + _h(i + 91) * 13.0
		# Every fourth one has a crooked, broken bill that never quite shuts.
		var twist: float = 0.28 if i % 4 == 1 else 0.0
		_duck_head(Vector2(hx, hy), r, _aim(Vector2(hx, hy), i + 90, 0.55), _gape(i + 90, 0.55), twist, i + 90, 1.0, true)
	_draw_lunge()
	_draw_crows()


## A whole shadow duck: neck sinking into the mass, a lumpy skull and a real duck bill (wide,
## flat, gently curved, rounded tip) hinged on the face, aimed by `angle`. `gape` opens the bill
## (radians) on crooked teeth, `twist` bends it out of line. `rim` 0..1 fades the thin edge.
func _duck_head(c: Vector2, r: float, angle: float, gape: float, twist: float, salt: int, rim: float, eye: bool) -> void:
	var edge: Color = _rim_color(c, rim)
	draw_set_transform(c, angle, Vector2.ONE)
	var neck := PackedVector2Array([Vector2(-r * 1.7, r * 1.6), Vector2(-r * 0.8, -r * 0.15), Vector2(r * 0.25, r * 0.3), Vector2(-r * 0.25, r * 2.0)])
	draw_colored_polygon(neck, MASS)
	var squash: float = 0.86 + _h(salt) * 0.16
	var skull := PackedVector2Array()
	for k in 16:
		var a: float = TAU * float(k) / 16.0
		var bump: float = 1.0 + (_h(salt * 7 + k) - 0.5) * 0.22
		skull.append(Vector2(cos(a) * 1.06, sin(a) * squash) * r * bump)
	draw_colored_polygon(skull, MASS)
	# Thin edge over the crown and forehead, where the torchlight catches it.
	var crown := PackedVector2Array()
	for k in [9, 10, 11, 12, 13, 14, 15, 0]:
		crown.append(skull[k])
	draw_polyline(crown, edge, 1.6, true)
	var hinge := Vector2(r * 0.62, r * 0.16)
	var length: float = r * (0.85 + _h(salt + 3) * 0.25)
	var upper := _bill_upper(length, r * 0.46, r * 0.44, hinge, twist)
	var lower := _bill_lower(length * 0.86, r * 0.28, hinge, twist + gape)
	if gape > 0.06:
		var mouth := PackedVector2Array([hinge, hinge + Vector2(length * 0.85, r * 0.06).rotated(twist), hinge + Vector2(length * 0.75, r * 0.08).rotated(twist + gape)])
		draw_colored_polygon(mouth, Color(0.13, 0.02, 0.04))
	draw_colored_polygon(lower, MASS)
	_visible_edge(lower, edge, 1.4)
	if gape > 0.12:
		# Crooked teeth, uneven and leaning.
		for k in 4:
			var u: float = 0.16 + 0.17 * float(k)
			var top: Vector2 = hinge + Vector2(length * u, r * 0.06).rotated(twist)
			var lean: float = (_h(salt * 5 + k) - 0.5) * 0.7
			var tooth_len: float = r * (0.12 + _h(salt * 5 + k + 9) * 0.12)
			var down: Vector2 = Vector2(0, 1).rotated(twist + lean)
			draw_colored_polygon(PackedVector2Array([top - Vector2(r * 0.05, 0).rotated(twist), top + Vector2(r * 0.05, 0).rotated(twist), top + down * tooth_len]), TEETH)
		for k in 2:
			var bottom: Vector2 = hinge + Vector2(length * (0.3 + 0.25 * float(k)), r * 0.06).rotated(twist + gape)
			var up: Vector2 = Vector2(0, -1).rotated(twist + gape + (_h(salt + k + 40) - 0.5) * 0.6)
			draw_colored_polygon(PackedVector2Array([bottom - Vector2(r * 0.04, 0).rotated(twist + gape), bottom + Vector2(r * 0.04, 0).rotated(twist + gape), bottom + up * r * 0.12]), TEETH)
	draw_colored_polygon(upper, MASS)
	_visible_edge(upper, edge, 1.6)
	if gape <= 0.06:
		# Closed bill: just the seam between the two halves.
		draw_line(hinge, hinge + Vector2(length * 0.8, r * 0.1).rotated(twist), Color(edge, edge.a * 0.7), 1.2, true)
	# Nostril on the bill.
	draw_circle(hinge + Vector2(length * 0.28, -r * 0.2).rotated(twist), maxf(r * 0.035, 0.8), Color(edge, edge.a * 0.8))
	if eye:
		_eye(Vector2(r * 0.25, -r * 0.3), maxf(r * 0.18, 2.4), salt * 31 + 7)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Upper bill, hinge frame: broad and flat, the ridge dipping a little before the rounded,
## spoon-wide tip (wider than the middle, like a real duck bill). Its root sits inside the skull.
func _bill_upper(length: float, root_h: float, tip_h: float, hinge: Vector2, twist: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-length * 0.4, -root_h * 1.1), Vector2(length * 0.1, -root_h * 0.92),
			Vector2(length * 0.45, -root_h * 0.74), Vector2(length * 0.7, -tip_h * 0.95)])
	var c := Vector2(length - tip_h * 0.55, -tip_h * 0.42)
	for k in 7:
		var a: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 6.0)
		pts.append(c + Vector2(cos(a), sin(a)) * tip_h * 0.55)
	pts.append_array([Vector2(length * 0.62, root_h * 0.14), Vector2(length * 0.25, root_h * 0.1), Vector2(-length * 0.4, root_h * 0.06)])
	return _place(pts, hinge, twist)


## Lower bill, thinner, with a slight smile, hanging from the same hinge.
func _bill_lower(length: float, h: float, hinge: Vector2, angle: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-length * 0.3, h * 0.1), Vector2(length * 0.4, h * 0.25)])
	var c := Vector2(length - h * 0.55, h * 0.62)
	for k in 7:
		var a: float = lerpf(-PI * 0.5, PI * 0.5, float(k) / 6.0)
		pts.append(c + Vector2(cos(a), sin(a)) * h * 0.55)
	pts.append_array([Vector2(length * 0.4, h * 1.15), Vector2(-length * 0.3, h * 1.05)])
	return _place(pts, hinge, angle)


## Edge of a bill without its root (which is buried in the skull), so no line crosses the face.
func _visible_edge(pts: PackedVector2Array, color: Color, width: float) -> void:
	draw_polyline(pts.slice(1, pts.size() - 1), color, width, true)


func _place(pts: PackedVector2Array, origin: Vector2, angle: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(origin + p.rotated(angle))
	return out


## Aim at the hero's torch, with a small personal wobble; never past `limit` radians.
func _aim(from: Vector2, salt: int, limit: float) -> float:
	var a: float = (light_center - from).angle()
	return clampf(a * 0.5, -limit * 0.6, limit * 0.6) + sin(_time * (0.5 + _h(salt + 7) * 0.6) + salt) * 0.07 + (_h(salt + 8) - 0.5) * 0.16


## Bill opening (radians) for a head: each opens and snaps shut on its own rhythm.
func _gape(salt: int, widest: float) -> float:
	var s: float = sin(_time * (0.6 + _h(salt + 11) * 1.1) + _h(salt + 12) * TAU)
	return clampf(s * 1.7 - 0.5, 0.0, 1.0) * widest


## -1..1: the head ducks back into the mass or leans out, out of step with the others.
func _peek(salt: int) -> float:
	return sin(_time * (0.35 + _h(salt + 13) * 0.5) + _h(salt + 14) * TAU)


## Thin dark-grey edge, warmed by the torch when the head is close to the light.
func _rim_color(at: Vector2, strength: float) -> Color:
	var warm: float = clampf(1.0 - (at.distance_to(light_center) - light_radius) / 260.0, 0.0, 1.0)
	var c: Color = RIM.lerp(Color(0.78, 0.5, 0.28), warm * 0.55)
	return Color(c, strength)


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
		_duck_head(reach, 24.0, d.angle(), 0.45 + 0.2 * k, 0.0, 77, 1.0, true)


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
