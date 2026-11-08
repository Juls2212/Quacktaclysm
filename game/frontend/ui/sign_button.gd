@tool
class_name SignButton
extends Button
## A salvaged sign: a broken wooden plank (hanging from ropes or nailed on) or a torn piece of
## cardboard with tape, its label set in InkType (Rubik Wet Paint). Still a regular Button (focus, keyboard,
## `pressed`); only the drawing is custom. Hover or focus swings it, warms the lettering, rims it
## in yellow and points a katana at it; a click shakes it; disabled signs go grey and hang crooked.

enum Look { PLANK, CARDBOARD }

const INK := Color(0.106, 0.098, 0.122)

@export var look: Look = Look.PLANK
@export var wood: Color = Color(0.56, 0.4, 0.25)
@export var letter_color: Color = Color(0.99, 0.94, 0.8)
@export var letter_hot: Color = Color(1.0, 0.82, 0.36)
@export var cap_height: float = 22.0
## Ropes up to the beam or the sign above (off for signs that sit on a panel).
@export var ropes: bool = true
@export var rope_length: float = 30.0
## Fixed tilt in degrees, so a column of signs does not look machine-aligned.
@export var tilt: float = 0.0

var _hot: float = 0.0
var _press: float = 0.0
var _time: float = 0.0
var _shake: float = 0.0


func _ready() -> void:
	flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(key, Color(0, 0, 0, 0))
	button_down.connect(func() -> void: _press = 1.0)
	pressed.connect(func() -> void: _shake = 1.0)
	# Pointing at a sign focuses it, so mouse and keyboard share one marker.
	mouse_entered.connect(func() -> void:
		if not disabled and focus_mode != Control.FOCUS_NONE:
			grab_focus())
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(280, 58)


func _process(delta: float) -> void:
	_time += delta
	var target: float = 1.0 if has_focus() and not disabled else 0.0
	_hot = move_toward(_hot, target, delta * 6.0)
	_press = move_toward(_press, 0.0, delta * 5.0)
	_shake = move_toward(_shake, 0.0, delta * 3.5)
	var sway: float = sin(_time * 1.6 + tilt) * 0.6 + sin(_time * 7.0) * 2.2 * _hot + sin(_time * 55.0) * 5.0 * _shake
	rotation = deg_to_rad(tilt + sway + (5.0 if disabled else 0.0))
	scale = Vector2.ONE * (1.0 + 0.05 * _hot - 0.06 * _press)
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	var cardboard: bool = look == Look.CARDBOARD
	var base_color: Color = Color(0.74, 0.62, 0.43) if cardboard else wood
	var plank_color: Color = base_color.lerp(Color(0.5, 0.48, 0.46), 0.75) if disabled else base_color.lightened(0.08 * _hot)
	if ropes:
		for x in [s.x * 0.18, s.x * 0.82]:
			draw_line(Vector2(x, -rope_length), Vector2(x, 6), INK, 4.0, true)
			draw_line(Vector2(x, -rope_length), Vector2(x, 6), Color(0.66, 0.56, 0.38), 2.0, true)
	var board: PackedVector2Array = _cardboard_shape(s) if cardboard else _plank_shape(s)
	draw_colored_polygon(_shift(board, Vector2(0, 6)), Color(0, 0, 0, 0.25))
	# Focus rim: a hot yellow edge just outside the board.
	if _hot > 0.01:
		var rim := PackedVector2Array(board)
		rim.append(board[0])
		draw_polyline(rim, Color(1.0, 0.78, 0.22, _hot), 9.0, true)
	draw_colored_polygon(board, plank_color)
	if cardboard:
		# Corrugation lines and a stain.
		for k in 4:
			var y: float = s.y * (0.22 + 0.18 * k)
			draw_line(Vector2(10, y), Vector2(s.x - 12, y + 1.0), Color(plank_color.darkened(0.18), 0.5), 1.2, true)
		draw_arc(Vector2(s.x * 0.78, s.y * 0.4), 9.0, 0.4, 5.4, 12, Color(0.4, 0.28, 0.16, 0.3), 3.0, true)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(6, s.y - 10), Vector2(s.x - 14, s.y - 11), Vector2(s.x - 8, s.y - 2), Vector2(6, s.y)]),
				plank_color.darkened(0.22))
		for k in 3:
			var y: float = s.y * (0.28 + 0.2 * k)
			draw_line(Vector2(16, y), Vector2(s.x * (0.35 + 0.12 * k), y + 1.5), Color(plank_color.darkened(0.3), 0.6), 1.5, true)
		# Splinters at the broken end.
		draw_line(Vector2(s.x - 12, s.y * 0.45), Vector2(s.x + 3, s.y * 0.4), INK, 2.0, true)
		draw_line(Vector2(s.x - 8, s.y * 0.7), Vector2(s.x + 5, s.y * 0.76), INK, 1.6, true)
	var closed := PackedVector2Array(board)
	closed.append(board[0])
	draw_polyline(closed, INK, 3.0, true)
	if cardboard:
		_tape(Vector2(14, 4), -0.5)
		_tape(Vector2(s.x - 14, 2), 0.45)
	else:
		for x in [s.x * 0.12, s.x * 0.86]:
			draw_circle(Vector2(x, s.y * 0.45), 3.4, INK)
			draw_circle(Vector2(x, s.y * 0.45), 2.0, Color(0.62, 0.6, 0.58))
			draw_line(Vector2(x + 1, s.y * 0.45 + 2), Vector2(x + 2, s.y * 0.45 + 8), Color(0.5, 0.25, 0.12, 0.55), 1.4, true)
	# Lettering.
	var style := InkType.Style.new()
	if cardboard:
		style.fill = Color(0.24, 0.15, 0.1).lerp(Color(0.62, 0.16, 0.08), _hot)
		style.extrude = plank_color.darkened(0.3)
		style.highlight = Color(1, 1, 1, 0.2)
	else:
		style.fill = letter_color.lerp(letter_hot, _hot)
		style.extrude = plank_color.darkened(0.55)
	style.depth = 0.6
	style.wobble = 0.6
	if disabled:
		style.fill = Color(0.78, 0.76, 0.72)
	# Shrink the lettering if it would not fit on the board.
	var cap: float = cap_height
	var width: float = InkType.measure(text, cap)
	var room: float = s.x - 34.0
	if width > room and width > 0.0:
		cap *= room / width
		width = InkType.measure(text, cap)
	InkType.draw(self, text, Vector2((s.x - width) * 0.5, (s.y - cap) * 0.5 - 2.0), cap, style)
	if _hot > 0.01:
		_draw_katana_pointer(Vector2(-14.0 - 8.0 * sin(_time * 5.0), s.y * 0.5), _hot)


## Plank snapped off at the right end.
func _plank_shape(s: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Vector2(4, 3), Vector2(s.x * 0.5, 1), Vector2(s.x - 14, 0), Vector2(s.x - 4, s.y * 0.25),
			Vector2(s.x - 12, s.y * 0.45), Vector2(s.x - 2, s.y * 0.62), Vector2(s.x - 8, s.y - 2), Vector2(6, s.y), Vector2(1, s.y * 0.55)])


## Piece of a cardboard box with a torn top edge.
func _cardboard_shape(s: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(2, 5)])
	for i in range(1, 8):
		var x: float = s.x * float(i) / 8.0
		pts.append(Vector2(x, 2.0 + (4.0 if i % 2 == 0 else 0.0)))
	pts.append_array([Vector2(s.x - 2, 4), Vector2(s.x, s.y - 3), Vector2(s.x * 0.5, s.y + 1), Vector2(3, s.y - 1)])
	return pts


func _tape(at: Vector2, rot: float) -> void:
	var pts := PackedVector2Array()
	for v in [Vector2(-16, -6), Vector2(16, -7), Vector2(17, 6), Vector2(-15, 7)]:
		pts.append(at + (v as Vector2).rotated(rot))
	draw_colored_polygon(pts, Color(0.88, 0.82, 0.62, 0.88))
	draw_line(pts[0], pts[3], Color(0.6, 0.54, 0.38), 1.2, true)
	draw_line(pts[1], pts[2], Color(0.6, 0.54, 0.38), 1.2, true)


## A small katana pointing at the sign: the focus marker.
func _draw_katana_pointer(tip: Vector2, k: float) -> void:
	var a := Color(1, 1, 1, k)
	var base: Vector2 = tip + Vector2(-46, 0)
	draw_line(base + Vector2(-16, 0), base, Color(INK, k), 7.0, true)
	draw_line(base + Vector2(-16, 0), base, Color(0.32, 0.13, 0.15, k), 4.0, true)
	draw_circle(base + Vector2(2, 0), 4.5, Color(INK, k))
	var blade := PackedVector2Array([base + Vector2(4, -3), tip + Vector2(-6, -3), tip, tip + Vector2(-8, 2.5), base + Vector2(4, 2.5)])
	draw_colored_polygon(blade, Color(0.91, 0.93, 0.95) * a)
	var closed := PackedVector2Array(blade)
	closed.append(blade[0])
	draw_polyline(closed, Color(INK, k), 2.0, true)


func _shift(pts: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + off)
	return out
