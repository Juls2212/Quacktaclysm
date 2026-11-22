class_name GrandfatherReflection
extends CanvasLayer
## A faint reflection of the grandfather in the sky (Phase 16c): a silhouette made of stars, no face, drawn by code. It lives on
## its own canvas layer between the sky (layer -6) and the play field (layer 0), so it is behind the parallax ridges, the play
## field and the UI, and it stays in the sky area of the screen. Levels 1 and 2: BLURRED (few stars, wide soft glow, a faint
## filled shape); level 3: SHARP (more stars, small glow, a thin outline joining them). It fades in, stays while the line is shown
## and fades out (all times in GrandfatherPresentation). With "Efectos de corrupción" off (reduced) it is a plain fade: no
## twinkle, no motion. Presentation only: it never touches gameplay and is never shown during a fight or a possession.

signal faded_out

enum Phase { FADE_IN, HOLD, FADE_OUT, DONE }

## The closed silhouette (a figure with a hat and a long robe) and the sword at his hip, in 0..1 of the figure box.
const BODY: Array = [
	Vector2(0.5, 0.0), Vector2(0.76, 0.14), Vector2(0.58, 0.16), Vector2(0.58, 0.22), Vector2(0.7, 0.27), Vector2(0.82, 0.38),
	Vector2(0.78, 0.62), Vector2(0.86, 1.0), Vector2(0.14, 1.0), Vector2(0.22, 0.62), Vector2(0.18, 0.38), Vector2(0.3, 0.27),
	Vector2(0.42, 0.22), Vector2(0.42, 0.16), Vector2(0.24, 0.14),
]
const SWORD: Array = [Vector2(0.72, 0.52), Vector2(0.98, 0.8)]
const STAR_SEED: int = 1337
## Width of the figure box over its height.
const ASPECT: float = 0.55

var presentation: GrandfatherPresentation = null
var sharp: bool = false
var reduced: bool = false
var phase: Phase = Phase.FADE_IN
## Current opacity (0 to presentation.max_alpha).
var alpha: float = 0.0
var stars: Array[Dictionary] = []

var _time: float = 0.0
var _phase_time: float = 0.0
var _alpha_at_fade_out: float = 0.0
var _drawer: Control = null
var _screen: Vector2 = Vector2(1280.0, 720.0)


## `level` decides blurred or sharp. Call before adding to the tree.
func setup(p_presentation: GrandfatherPresentation, level: int, p_reduced: bool) -> void:
	presentation = p_presentation
	sharp = presentation.is_sharp(level)
	reduced = p_reduced
	layer = presentation.reflection_layer
	_build_stars()


func _ready() -> void:
	if presentation == null:
		setup(GrandfatherPresentation.get_default(), 1, not GameSettings.is_corruption_effects_enabled())
	_drawer = Control.new()
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drawer)
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer.draw.connect(_draw_figure)


func fade_out() -> void:
	if phase == Phase.FADE_OUT or phase == Phase.DONE:
		return
	phase = Phase.FADE_OUT
	_phase_time = 0.0
	_alpha_at_fade_out = alpha


func _process(delta: float) -> void:
	_time += delta
	_phase_time += delta
	match phase:
		Phase.FADE_IN:
			alpha = presentation.max_alpha * clampf(_phase_time / presentation.fade_in_time, 0.0, 1.0)
			if _phase_time >= presentation.fade_in_time:
				phase = Phase.HOLD
				_phase_time = 0.0
		Phase.HOLD:
			alpha = presentation.max_alpha
		Phase.FADE_OUT:
			alpha = _alpha_at_fade_out * (1.0 - clampf(_phase_time / presentation.fade_out_time, 0.0, 1.0))
			if _phase_time >= presentation.fade_out_time:
				phase = Phase.DONE
				alpha = 0.0
				faded_out.emit()
				queue_free()
				return
	if _drawer != null:
		_screen = _drawer.size if _drawer.size.x > 0.0 else _screen
		_drawer.queue_redraw()


## The box the figure occupies on a screen of `screen_size` px, kept inside the sky area.
func figure_rect(screen_size: Vector2) -> Rect2:
	var height: float = screen_size.y * presentation.figure_height_ratio
	var width: float = height * ASPECT
	var top: float = minf(screen_size.y * presentation.anchor_top_ratio, screen_size.y * presentation.sky_bottom_ratio - height)
	top = maxf(top, 0.0)
	var left: float = clampf(screen_size.x * presentation.anchor_x_ratio - width * 0.5, 0.0, maxf(screen_size.x - width, 0.0))
	return Rect2(left, top, width, height)


## Opacity factor of one star at `time` seconds: constant when reduced, a slow twinkle otherwise.
func star_factor(index: int, time: float) -> float:
	if reduced or index < 0 or index >= stars.size():
		return 1.0
	return 0.75 + 0.25 * sin(time * TAU * presentation.twinkle_hz + float(stars[index]["phase"]))


func glow_radius() -> float:
	return presentation.sharp_glow_radius if sharp else presentation.blurred_glow_radius


func _build_stars() -> void:
	stars.clear()
	var count: int = presentation.sharp_star_count if sharp else presentation.blurred_star_count
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	# Spread the stars along the outline and the sword by length; the blurred figure also loses precision (jitter).
	var segments: Array[Vector2] = []
	var total: float = 0.0
	for i in BODY.size():
		var a: Vector2 = BODY[i]
		var b: Vector2 = BODY[(i + 1) % BODY.size()]
		segments.append(a)
		segments.append(b)
		total += a.distance_to(b)
	var sword_start: Vector2 = SWORD[0]
	var sword_end: Vector2 = SWORD[1]
	segments.append(sword_start)
	segments.append(sword_end)
	total += sword_start.distance_to(sword_end)
	var spacing: float = total / float(count)
	var carried: float = 0.0
	for i in range(0, segments.size(), 2):
		var a: Vector2 = segments[i]
		var b: Vector2 = segments[i + 1]
		var length: float = a.distance_to(b)
		var along: float = spacing - carried
		while along <= length and stars.size() < count:
			var point: Vector2 = a.lerp(b, along / length)
			if not sharp:
				point += Vector2(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.04, 0.04))
			stars.append({"p": point, "phase": rng.randf() * TAU})
			along += spacing
		carried = length - (along - spacing)
	while stars.size() < count:
		var fallback_point: Vector2 = BODY[stars.size() % BODY.size()]
		stars.append({"p": fallback_point, "phase": rng.randf() * TAU})


func _draw_figure() -> void:
	if presentation == null or alpha <= 0.001:
		return
	var rect: Rect2 = figure_rect(_screen)
	var color: Color = presentation.star_color
	var points := PackedVector2Array()
	for point: Vector2 in BODY:
		points.append(rect.position + point * rect.size)
	if not sharp:
		# A faint soft body so the blurred shape still reads as a figure.
		_drawer.draw_colored_polygon(points, Color(color, alpha * 0.1))
	else:
		var outline := PackedVector2Array(points)
		outline.append(points[0])
		_drawer.draw_polyline(outline, Color(color, alpha * 0.35), 1.2, true)
		var sword_a: Vector2 = SWORD[0]
		var sword_b: Vector2 = SWORD[1]
		_drawer.draw_line(rect.position + sword_a * rect.size, rect.position + sword_b * rect.size, Color(color, alpha * 0.35), 1.2, true)
	var glow: float = glow_radius()
	var core: float = 1.8 if sharp else 2.6
	for i in stars.size():
		var center: Vector2 = rect.position + (stars[i]["p"] as Vector2) * rect.size
		var factor: float = star_factor(i, _time)
		for step in range(4, 0, -1):
			_drawer.draw_circle(center, glow * float(step) / 4.0, Color(color, alpha * factor * 0.05))
		_drawer.draw_circle(center, core, Color(color, alpha * factor))
