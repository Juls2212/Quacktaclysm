@tool
class_name StarPortal
extends Node2D
## Exit of the tutorial: a magic circle on the floor seen in perspective (three thin rings with
## runes between them and eight star points, turning in opposite directions, a dark purple swirl
## in the middle) and, once lit, a vertical beam of light up to the top of the screen with motes
## rising in it. Origin on the floor at the circle's center. Visual only: it listens to the
## TutorialController's public `tutorial_completed` signal and to its parent trigger's
## `body_entered`, and never changes what the game does.
## Off: grey and dim, runes barely there, no beam, turning slowly. Lighting up (~1 s): a flash,
## the rings speed up and the beam rises from the floor. A body entering while lit: a white-purple
## flash and the beam swells for a moment.

const PINK := Color("e8b8ff")
const VIOLET := Color("b26bff")
const DEEP := Color(0.16, 0.04, 0.24)
const OFF := Color(0.62, 0.6, 0.66)
const RX: float = 130.0
const RY: float = 35.0
const BEAM_HEIGHT: float = 900.0

## Starts lit (preview); in the tutorial it follows the controller.
@export var lit_at_start: bool = false

var _time: float = 0.0
var _lit: float = 0.0
var _target: float = 0.0
var _flash: float = 0.0
var _swell: float = 0.0
var _spin: Vector3 = Vector3.ZERO
var _glow: Node2D


func _ready() -> void:
	_glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	_glow.draw.connect(_draw_glow)
	add_child(_glow)
	_target = 1.0 if lit_at_start else 0.0
	_lit = _target
	if Engine.is_editor_hint():
		return
	var controller: Node = _find_controller()
	if controller != null:
		if bool(controller.get(&"is_completed")):
			_target = 1.0
			_lit = 1.0
		if controller.has_signal(&"tutorial_completed"):
			controller.connect(&"tutorial_completed", _light_up)
	var trigger := get_parent() as Area2D
	if trigger != null:
		trigger.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_lit = move_toward(_lit, _target, delta)
	_flash = maxf(_flash - delta * 2.2, 0.0)
	_swell = maxf(_swell - delta * 1.8, 0.0)
	var speed: float = lerpf(0.1, 1.0, _lit)
	_spin += Vector3(0.9, -0.6, 1.4) * speed * delta
	queue_redraw()
	_glow.queue_redraw()


func _light_up() -> void:
	if _target < 1.0:
		_target = 1.0
		_flash = 1.0


func _on_body_entered(body: Node2D) -> void:
	if _lit > 0.5 and body is Player:
		_flash = 1.0
		_swell = 1.0


func _find_controller() -> Node:
	var node: Node = get_parent()
	while node != null:
		var found: Node = node.get_node_or_null(^"TutorialController")
		if found != null:
			return found
		node = node.get_parent()
	return null


## Normal-blend layer: the swirl in the middle and the ring as it looks unlit.
func _draw() -> void:
	for k in 5:
		var s: float = 0.62 - float(k) * 0.1
		var rot: float = _spin.z * (0.6 + float(k) * 0.2)
		draw_colored_polygon(_flat_ellipse(Vector2.ZERO, RX * s, RY * s, 32, rot), Color(DEEP, 0.35 + 0.1 * float(k)))
	# Dark purple whirl turning in the middle.
	var spiral := PackedVector2Array()
	for i in 40:
		var u: float = float(i) / 39.0
		var a: float = u * TAU * 2.0 - _spin.z * 1.6
		spiral.append(Vector2(cos(a) * RX * 0.55 * u, sin(a) * RY * 0.55 * u))
	draw_polyline(spiral, Color(0.4, 0.15, 0.55, 0.35 + 0.4 * _lit), 2.4, true)
	var dim: float = 1.0 - _lit
	if dim > 0.0:
		for ring in [1.0, 0.8, 0.6]:
			draw_polyline(_ring_points(RX * float(ring), RY * float(ring)), Color(OFF, 0.35 * dim), 2.0, true)
		for k in 8:
			var a: float = _spin.x + TAU * float(k) / 8.0
			draw_colored_polygon(_star_point(a), Color(OFF, 0.25 * dim))


## Additive layer: glow on the ground, rings, runes, star points, the beam and its motes.
func _draw_glow() -> void:
	var lit: float = _lit
	var glow: Color = VIOLET.lerp(PINK, 0.4)
	_glow.draw_colored_polygon(_flat_ellipse(Vector2.ZERO, RX * 1.7, RY * 1.7, 40, 0.0), Color(VIOLET, 0.1 * lit))
	_glow.draw_colored_polygon(_flat_ellipse(Vector2.ZERO, RX * 1.2, RY * 1.2, 40, 0.0), Color(VIOLET, 0.12 * lit))
	var rings: Array = [[1.0, _spin.x, PINK], [0.8, _spin.y, VIOLET], [0.6, _spin.z, PINK]]
	for r in rings:
		var k: float = float(r[0])
		_glow.draw_polyline(_ring_points(RX * k, RY * k), Color(r[2], 0.9 * lit), 2.4, true)
		_glow.draw_polyline(_ring_points(RX * k, RY * k), Color(r[2], 0.2 * lit), 7.0, true)
	# Runes between the outer and middle ring, marks between the middle and inner ring.
	var rune_a: float = 0.25 + 0.75 * lit
	for k in 16:
		var a: float = _spin.x + TAU * float(k) / 16.0
		var p: Vector2 = _on_ellipse(a, 0.9)
		var t: Vector2 = _on_ellipse(a + 0.06, 0.9) - p
		var n := Vector2(0, -RY * 0.06)
		var col := Color(PINK, rune_a * lit + 0.05)
		match k % 3:
			0:
				_glow.draw_line(p - t, p + t, col, 1.6, true)
				_glow.draw_line(p, p + n, col, 1.6, true)
			1:
				_glow.draw_line(p - t + n * 0.5, p + t - n * 0.5, col, 1.6, true)
				_glow.draw_line(p + t + n * 0.5, p - t - n * 0.5, col, 1.6, true)
			_:
				_glow.draw_arc(p, 3.0, 0.0, TAU, 8, col, 1.4, true)
	for k in 24:
		var a: float = _spin.y + TAU * float(k) / 24.0
		var p: Vector2 = _on_ellipse(a, 0.7)
		_glow.draw_line(p, _on_ellipse(a, 0.66), Color(VIOLET, 0.8 * lit), 1.4, true)
	for k in 8:
		var a: float = _spin.x + TAU * float(k) / 8.0
		_glow.draw_colored_polygon(_star_point(a), Color(PINK, 0.85 * lit))
	# Bright core in the swirl.
	_glow.draw_colored_polygon(_flat_ellipse(Vector2.ZERO, 16.0, 5.0, 16, 0.0), Color(1.0, 0.95, 1.0, 0.8 * lit))
	# The beam: rises from the floor as it lights up, pulses, swells when someone steps in.
	var rise: float = smoothstep(0.15, 1.0, lit)
	if rise > 0.0:
		var top: float = -BEAM_HEIGHT * rise
		var pulse: float = 1.0 + 0.08 * sin(_time * 3.0) + 0.9 * _swell
		for layer in [[95.0, 0.08], [60.0, 0.12], [30.0, 0.22], [12.0, 0.5]]:
			var w: float = float(layer[0]) * pulse * 0.5
			var a: float = float(layer[1])
			_glow.draw_polygon(PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.7, top), Vector2(-w * 0.7, top)]),
					PackedColorArray([Color(glow, a), Color(glow, a), Color(glow, 0.0), Color(glow, 0.0)]))
		_glow.draw_polygon(PackedVector2Array([Vector2(-2.5 * pulse, 0), Vector2(2.5 * pulse, 0), Vector2(1.5, top), Vector2(-1.5, top)]),
				PackedColorArray([Color(1, 0.95, 1, 0.9), Color(1, 0.95, 1, 0.9), Color(1, 0.9, 1, 0.0), Color(1, 0.9, 1, 0.0)]))
		for k in 22:
			var u: float = fposmod(_time * (0.25 + 0.2 * _h(k)) + _h(k + 30), 1.0)
			var y: float = -u * BEAM_HEIGHT * 0.7 * rise
			var x: float = (_h(k + 60) - 0.5) * 50.0 + sin(_time * 2.0 + float(k)) * 6.0
			_glow.draw_circle(Vector2(x, y), 1.5 + _h(k + 90) * 1.5, Color(PINK, (1.0 - u) * 0.8))
	if _flash > 0.0:
		_glow.draw_colored_polygon(_flat_ellipse(Vector2.ZERO, RX * (1.0 + (1.0 - _flash) * 1.4), RY * (1.0 + (1.0 - _flash) * 1.4), 40, 0.0),
				Color(1.0, 0.9, 1.0, 0.35 * _flash))
		_glow.draw_circle(Vector2(0, -60), 120.0 * _flash, Color(0.9, 0.7, 1.0, 0.15 * _flash))


func _on_ellipse(a: float, k: float) -> Vector2:
	return Vector2(cos(a) * RX * k, sin(a) * RY * k)


func _ring_points(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 65:
		var a: float = TAU * float(i) / 64.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## A star point on the outer ring, aimed outward and flattened like the circle.
func _star_point(a: float) -> PackedVector2Array:
	return PackedVector2Array([_on_ellipse(a - 0.09, 1.0), _on_ellipse(a, 1.24), _on_ellipse(a + 0.09, 1.0)])


func _flat_ellipse(c: Vector2, rx: float, ry: float, steps: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var a: float = TAU * float(i) / float(steps) + rot
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _h(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)
