class_name EndingCreditsSky
extends Control
## The night sky behind the end credits (Phase 15t), drawn by code. "kept" («Estrellas que suben»): small stars rise slowly from the freed city,
## whose silhouette drifts in two parallax layers with its windows lit. "released" («El acantilado»): a cold, almost still sky with a few distant
## stars, a thin mist that barely moves and the cliff silhouette with the sword and the straw hat left at its edge (nothing of the act).
## Only slow motion, no flashes. In reduced mode `time` stays 0 and the picture is drawn once. Drawing only: no gameplay logic.

const SIZE := Vector2(1280.0, 720.0)
const BANDS: int = 28
const HORIZON_KEPT: float = 600.0
const WRAP_WIDTH: float = 1700.0

var style: String = "kept"
var reduced: bool = false
var time: float = 0.0
var config: EndingCreditsConfig = null
## How many times the sky was redrawn (the tests read it).
var redraws: int = 0

var _rising: Array[Dictionary] = []
var _still: Array[Dictionary] = []
var _far_city: Array[Dictionary] = []
var _near_city: Array[Dictionary] = []
var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if config == null:
		config = EndingCreditsConfig.get_default()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_generate()
	queue_redraw()


## Re-reads the style and rebuilds the stars and the city (called when the style or the config changes).
func rebuild() -> void:
	_generate()
	queue_redraw()


func _process(delta: float) -> void:
	if reduced:
		return
	time += delta
	_clock += delta
	if _clock >= 1.0 / maxf(config.redraw_hz, 1.0):
		_clock = 0.0
		queue_redraw()


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 150 if style == "kept" else 151
	_rising.clear()
	_still.clear()
	_far_city.clear()
	_near_city.clear()
	for i in config.rising_star_count if style == "kept" else 0:
		_rising.append({"x": rng.randf_range(20.0, SIZE.x - 20.0), "phase": rng.randf(), "speed": rng.randf_range(config.rising_speed_min, config.rising_speed_max), "size": rng.randf_range(0.6, 1.0) * config.star_size, "sway": rng.randf_range(0.0, TAU)})
	for i in config.still_star_count if style != "kept" else 28:
		_still.append({"p": Vector2(rng.randf_range(0.02, 0.98), rng.randf_range(0.03, 0.62)), "size": rng.randf_range(0.7, 1.4), "phase": rng.randf() * TAU, "base": rng.randf_range(0.35, 0.8)})
	if style == "kept":
		_city_layer(_far_city, rng, 30.0, 60.0, 90.0, 190.0)
		_city_layer(_near_city, rng, 44.0, 90.0, 60.0, 150.0)


func _city_layer(out: Array[Dictionary], rng: RandomNumberGenerator, wmin: float, wmax: float, hmin: float, hmax: float) -> void:
	var x: float = 0.0
	while x < WRAP_WIDTH:
		var w: float = rng.randf_range(wmin, wmax)
		var h: float = rng.randf_range(hmin, hmax)
		var windows: Array[Vector2] = []
		var wy: float = 14.0
		while wy < h - 8.0:
			var wx: float = 8.0
			while wx < w - 12.0:
				if rng.randf() < 0.55:
					windows.append(Vector2(wx, wy))
				wx += 15.0
			wy += 20.0
		out.append({"x": x, "w": w, "h": h, "windows": windows})
		x += w + rng.randf_range(2.0, 14.0)


func _draw() -> void:
	redraws += 1
	var top: Color = config.kept_sky_top if style == "kept" else config.released_sky_top
	var bottom: Color = config.kept_sky_bottom if style == "kept" else config.released_sky_bottom
	var s: Vector2 = SIZE
	for i in BANDS:
		var k0: float = float(i) / BANDS
		var color: Color = top.lerp(bottom, k0 * k0)
		draw_rect(Rect2(0.0, s.y * k0, s.x, s.y / BANDS + 1.0), color)
	_draw_still_stars()
	if style == "kept":
		_draw_rising_stars()
		_draw_city()
	else:
		_draw_mist()
		_draw_cliff()


func _twinkle(phase: float) -> float:
	return 1.0 - config.twinkle_depth * 0.5 * (1.0 + sin(time * TAU * config.twinkle_hz + phase))


func _draw_still_stars() -> void:
	for star in _still:
		var p: Vector2 = (star["p"] as Vector2) * SIZE
		var a: float = float(star["base"]) * _twinkle(float(star["phase"]))
		var r: float = float(star["size"])
		draw_circle(p, r, Color(0.85, 0.9, 1.0, a * 0.8))


func _draw_rising_stars() -> void:
	var rise: float = HORIZON_KEPT - 40.0
	for star in _rising:
		var u: float = fposmod(float(star["phase"]) + time * float(star["speed"]) / rise, 1.0)
		var y: float = HORIZON_KEPT - 20.0 - u * rise
		var x: float = float(star["x"]) + sin(time * 0.35 + float(star["sway"])) * 6.0
		# They fade in over the roofs, shine, and melt away near the top.
		var a: float = pow(sin(PI * u), 0.6) * 0.9
		var r: float = float(star["size"])
		draw_circle(Vector2(x, y), r * 2.4, Color(1.0, 0.92, 0.7, a * 0.12))
		draw_circle(Vector2(x, y), r, Color(1.0, 0.95, 0.8, a))


func _draw_city() -> void:
	var base_y: float = SIZE.y - 60.0
	_draw_layer(_far_city, config.city_far_speed, base_y + 10.0, Color(0.075, 0.07, 0.13), 0.35)
	_draw_layer(_near_city, config.city_near_speed, base_y + 30.0, Color(0.035, 0.03, 0.07), 0.85)
	draw_rect(Rect2(0.0, SIZE.y - 32.0, SIZE.x, 40.0), Color(0.02, 0.02, 0.045))


func _draw_layer(buildings: Array[Dictionary], speed: float, base_y: float, color: Color, window_alpha: float) -> void:
	var drift: float = fposmod(time * speed, WRAP_WIDTH)
	for copy in 2:
		for b in buildings:
			var x: float = float(b["x"]) - drift + copy * WRAP_WIDTH
			var w: float = float(b["w"])
			if x > SIZE.x or x + w < 0.0:
				continue
			var h: float = float(b["h"])
			draw_rect(Rect2(x, base_y - h, w, h + 40.0), color)
			for win in b["windows"] as Array[Vector2]:
				draw_rect(Rect2(x + win.x, base_y - h + win.y, 6.0, 9.0), Color(1.0, 0.82, 0.48, window_alpha))


func _draw_mist() -> void:
	for band in 3:
		var y: float = 470.0 + band * 62.0
		var drift: float = time * config.mist_speed * (1.0 + band * 0.4)
		var points := PackedVector2Array()
		for i in 33:
			var x: float = float(i) * SIZE.x / 32.0
			points.append(Vector2(x, y + sin((x + drift * (1.0 if band % 2 == 0 else -1.0)) * 0.006 + band) * 14.0))
		draw_polyline(points, Color(0.75, 0.82, 0.95, config.mist_alpha * (1.0 - band * 0.18)), 26.0 - band * 5.0, true)


func _draw_cliff() -> void:
	var ink := Color(0.012, 0.016, 0.03)
	var poly := PackedVector2Array([Vector2(0.0, SIZE.y), Vector2(0.0, 585.0), Vector2(140.0, 575.0), Vector2(320.0, 566.0), Vector2(520.0, 570.0), Vector2(700.0, 558.0), Vector2(790.0, 560.0), Vector2(806.0, 606.0), Vector2(786.0, 650.0), Vector2(800.0, SIZE.y)])
	draw_colored_polygon(poly, ink)
	# Far hills under the mist.
	var hills := PackedVector2Array([Vector2(820.0, SIZE.y), Vector2(900.0, 640.0), Vector2(1040.0, 622.0), Vector2(1180.0, 640.0), Vector2(SIZE.x, 628.0), Vector2(SIZE.x, SIZE.y)])
	draw_colored_polygon(hills, Color(0.03, 0.04, 0.07))
	# The sword planted and the straw hat left at the edge: flat shapes, nothing else.
	draw_line(Vector2(748.0, 560.0), Vector2(748.0, 512.0), ink, 3.0)
	draw_line(Vector2(738.0, 524.0), Vector2(758.0, 524.0), ink, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(768.0, 562.0), Vector2(776.0, 548.0), Vector2(792.0, 548.0), Vector2(800.0, 562.0)]), ink)
