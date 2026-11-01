@tool
class_name SignButton
extends Button
## A wooden plank sign hanging from two ropes, with its label set in InkType.
## Still a regular Button (focus, keyboard, `pressed`); only the drawing is custom.
## Hover or focus swings the plank, warms the lettering and points a katana at it;
## disabled signs go grey and hang crooked.

const INK := Color(0.106, 0.098, 0.122)

@export var wood: Color = Color(0.62, 0.42, 0.25)
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


func _ready() -> void:
	flat = true
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(key, Color(0, 0, 0, 0))
	button_down.connect(func() -> void: _press = 1.0)
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
	var sway: float = sin(_time * 1.6 + tilt) * 0.6 + sin(_time * 7.0) * 2.2 * _hot
	rotation = deg_to_rad(tilt + sway + (5.0 if disabled else 0.0))
	scale = Vector2.ONE * (1.0 + 0.05 * _hot - 0.06 * _press)
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	var plank_color: Color = wood.lerp(Color(0.5, 0.48, 0.46), 0.75) if disabled else wood.lightened(0.08 * _hot)
	if ropes:
		for x in [s.x * 0.18, s.x * 0.82]:
			draw_line(Vector2(x, -rope_length), Vector2(x, 6), INK, 4.0, true)
			draw_line(Vector2(x, -rope_length), Vector2(x, 6), Color(0.78, 0.66, 0.44), 2.0, true)
	# Plank: slightly irregular board with a darker lower edge, grain and two nails.
	var board := PackedVector2Array([Vector2(4, 3), Vector2(s.x - 6, 0), Vector2(s.x - 2, s.y * 0.5), Vector2(s.x - 5, s.y - 2),
			Vector2(6, s.y), Vector2(1, s.y * 0.55)])
	draw_colored_polygon(_shift(board, Vector2(0, 6)), Color(0, 0, 0, 0.22))
	draw_colored_polygon(board, plank_color)
	draw_colored_polygon(PackedVector2Array([Vector2(6, s.y - 10), Vector2(s.x - 5, s.y - 11), Vector2(s.x - 5, s.y - 2), Vector2(6, s.y)]),
			plank_color.darkened(0.22))
	for k in 3:
		var y: float = s.y * (0.28 + 0.2 * k)
		draw_line(Vector2(16, y), Vector2(s.x * (0.35 + 0.12 * k), y + 1.5), Color(plank_color.darkened(0.3), 0.6), 1.5, true)
	var closed := PackedVector2Array(board)
	closed.append(board[0])
	draw_polyline(closed, INK, 3.0, true)
	for x in [s.x * 0.18, s.x * 0.82]:
		draw_circle(Vector2(x, 9), 3.2, INK)
		draw_circle(Vector2(x, 9), 1.8, Color(0.7, 0.7, 0.72))
	# Lettering.
	var style := InkType.Style.new()
	style.fill = letter_color.lerp(letter_hot, _hot)
	style.extrude = plank_color.darkened(0.55)
	style.depth = 0.6
	style.wobble = 0.6
	if disabled:
		style.fill = Color(0.78, 0.76, 0.72)
	var width: float = InkType.measure(text, cap_height)
	InkType.draw(self, text, Vector2((s.x - width) * 0.5, (s.y - cap_height) * 0.5 - 2.0), cap_height, style)
	if _hot > 0.01:
		_draw_katana_pointer(Vector2(-14.0 - 8.0 * sin(_time * 5.0), s.y * 0.5), _hot)


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
