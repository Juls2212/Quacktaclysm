class_name DecisionButton
extends Button
## A choice sign for the fragment card: RELEASE in dark blue with a bright sky-blue rim, KEEP in
## dark red with a red rim. Still a regular Button (focus, keyboard, mouse, `pressed`); with the
## focus it grows a little and glows. Only the drawing is custom.

enum Kind { RELEASE, KEEP }

@export var kind: Kind = Kind.RELEASE

var _hot: float = 0.0
var _time: float = 0.0
var _font: Font


func _ready() -> void:
	flat = true
	_font = GameFonts.BODY
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(key, Color(0, 0, 0, 0))
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _process(delta: float) -> void:
	_time += delta
	_hot = move_toward(_hot, 1.0 if has_focus() and not disabled else 0.0, delta * 7.0)
	scale = Vector2.ONE * (1.0 + 0.07 * _hot)
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	var fill: Color = Color(0.04, 0.13, 0.32) if kind == Kind.RELEASE else Color(0.28, 0.05, 0.05)
	var rim: Color = Color(0.55, 0.88, 1.0) if kind == Kind.RELEASE else Color(0.86, 0.22, 0.16)
	var text_col: Color = Color(0.92, 0.97, 1.0) if kind == Kind.RELEASE else Color(1.0, 0.86, 0.8)
	if disabled:
		fill = fill.lerp(Color(0.2, 0.2, 0.22), 0.6)
		rim = rim.lerp(Color(0.4, 0.4, 0.42), 0.7)
	var tilt: float = -3.0 if kind == Kind.RELEASE else 2.0
	var pts := PackedVector2Array([Vector2(2, tilt), Vector2(s.x - 2, 0), Vector2(s.x, s.y - 2), Vector2(4, s.y + tilt * 0.5)])
	var glow: float = 0.15 + 0.35 * _hot + 0.08 * sin(_time * 3.0) * _hot
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, Color(rim, glow), 14.0, true)
	draw_colored_polygon(pts, fill)
	draw_polyline(closed, rim, 3.0 + _hot, true)
	var size_px: int = 24
	var w: float = _font.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var origin := Vector2((s.x - w) * 0.5, s.y * 0.5 + float(size_px) * 0.36)
	draw_string_outline(_font, origin, text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 6, Color(0.02, 0.02, 0.05))
	draw_string(_font, origin, text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, text_col)
