@tool
class_name SkyPainter
extends Control
## Screen-space sky for a biome: a three-stop gradient that warms toward the horizon, bands of
## smog, the sun (or a broken moon) with its glow, slow light shafts, storm lightning, and the
## optional marks of the fallen stars: the omen star, glowing cracks and corrupted stars streaking
## down with a trail. Visual only.

const INK := Color(0.106, 0.098, 0.122)

@export var biome: Biome:
	set(value):
		biome = value
		_cracks.clear()
		queue_redraw()

var _time: float = 0.0
var _flash: float = 0.0
var _next_flash: float = 3.0
var _next_star: float = 0.5
var _stars: Array[Dictionary] = []
var _cracks: Array[PackedVector2Array] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 91


func _process(delta: float) -> void:
	_time += delta
	# A Control under a CanvasLayer has no parent rect to anchor to: follow the viewport.
	if size != get_viewport_rect().size:
		size = get_viewport_rect().size
		_cracks.clear()
	if biome != null and biome.lightning and not Engine.is_editor_hint():
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = 4.0 + fmod(_time * 7.31, 5.0)
	_flash = maxf(_flash - delta * 3.5, 0.0)
	if biome != null and biome.falling_stars:
		_update_stars(delta)
	queue_redraw()


func _draw() -> void:
	if biome == null:
		return
	var s: Vector2 = size
	var horizon: float = s.y * 0.72
	var top: Color = _dim(biome.sky_top)
	var bottom: Color = _dim(biome.sky_bottom)
	var haze: Color = _dim(biome.haze)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, horizon), Vector2(0, horizon)]),
			PackedColorArray([top, top, bottom, bottom]))
	draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(s.x, horizon), Vector2(s.x, s.y), Vector2(0, s.y)]),
			PackedColorArray([bottom, bottom, haze, haze]))
	if biome.sky_cracks:
		_draw_cracks(s)
	_draw_sun(s)
	if biome.omen_star:
		_draw_omen_star(biome.omen_star_position * s)
	if biome.light_shafts:
		var sun: Vector2 = biome.sun_position * s
		for k in 5:
			var a: float = deg_to_rad(95.0 + k * 13.0) + sin(_time * 0.25 + k) * 0.03
			var spread: float = deg_to_rad(3.0 + (k % 2) * 2.0)
			var reach: float = s.length()
			draw_colored_polygon(PackedVector2Array([sun, sun + Vector2.from_angle(a - spread) * reach,
					sun + Vector2.from_angle(a + spread) * reach]), Color(biome.sun, 0.04 + 0.02 * (k % 2)))
	if biome.smog > 0.0:
		_draw_smog(s)
	if biome.lightning:
		# Long flat cloud banks sliding past, each a stack of soft lens shapes with a lit rim.
		for k in 3:
			var y: float = s.y * (0.1 + 0.11 * k)
			var drift: float = fmod(_time * (8.0 + k * 5.0) + k * 420.0, s.x + 900.0) - 450.0
			var shade := Color(top.lerp(haze, 0.25 + 0.12 * k), 0.75)
			for j in 5:
				var c := Vector2(drift + j * 85.0, y + sin(j * 1.7 + k) * 8.0)
				var lens := _lens(c, 110.0 - absf(j - 2.0) * 18.0, 18.0 + (2.0 - absf(j - 2.0)) * 5.0)
				draw_colored_polygon(lens, shade)
				draw_polyline(_lens(c + Vector2(0, -2), 100.0 - absf(j - 2.0) * 18.0, 14.0), Color(haze, 0.35), 2.0, true)
	if biome.falling_stars:
		_draw_stars()
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(biome.sun.lerp(biome.star_color, 0.35), 0.4 * _flash))


# =====================================================================================
# Pieces
# =====================================================================================

func _draw_sun(s: Vector2) -> void:
	var sun: Vector2 = biome.sun_position * s
	# Glow falls off in soft rings; the disc itself is small, the light is what reads.
	for k in 6:
		var r: float = 40.0 + k * 38.0
		draw_circle(sun, r, Color(biome.sun, 0.06))
	if biome.broken_moon:
		_draw_broken_moon(sun)
		return
	draw_circle(sun, 30.0, Color(biome.sun, 0.95))
	if biome.lightning:
		# A thin crescent: the storm moon.
		draw_circle(sun + Vector2(9, -5), 26.0, Color(_dim(biome.sky_top), 0.92))
	draw_arc(sun, 30.0, 0.0, TAU, 40, Color(INK, 0.55), 2.4, true)


## The moon split by the fall: a chipped disc and three chunks drifting away from it.
func _draw_broken_moon(c: Vector2) -> void:
	var r: float = 44.0
	var body := PackedVector2Array()
	# Disc with a bite taken out on the lower right, edged by a jagged fracture.
	for i in 25:
		var a: float = lerpf(deg_to_rad(80.0), deg_to_rad(370.0), float(i) / 24.0)
		body.append(c + Vector2.from_angle(a) * r)
	var jag: Array[Vector2] = [Vector2(0.55, 0.12), Vector2(0.28, 0.3), Vector2(0.38, 0.52), Vector2(0.12, 0.66), Vector2(0.3, 0.84)]
	for p in jag:
		body.append(c + p * r)
	draw_colored_polygon(body, biome.sun)
	for k in 3:
		var crater: Vector2 = c + Vector2(-0.45 + k * 0.3, -0.35 + (k % 2) * 0.45) * r
		draw_circle(crater, r * (0.12 + 0.04 * k), Color(biome.sun.darkened(0.18), 0.9))
	var closed := PackedVector2Array(body)
	closed.append(body[0])
	draw_polyline(closed, INK, 2.6, true)
	# Glowing seam where the star hit.
	var seam := PackedVector2Array()
	for p in jag:
		seam.append(c + p * r)
	draw_polyline(seam, Color(biome.star_color, 0.8), 2.0, true)
	for k in 3:
		var drift: Vector2 = Vector2(0.9 + k * 0.38, 0.5 + k * 0.22) * r + Vector2(sin(_time * 0.4 + k), cos(_time * 0.3 + k)) * 3.0
		var piece_r: float = r * (0.24 - 0.05 * k)
		var piece := PackedVector2Array()
		for i in 5:
			var a: float = TAU * float(i) / 5.0 + k + _time * 0.05 * (k + 1)
			piece.append(c + drift + Vector2.from_angle(a) * piece_r * (0.75 + 0.25 * float((i + k) % 2)))
		draw_colored_polygon(piece, biome.sun.darkened(0.05 * k))
		var edge := PackedVector2Array(piece)
		edge.append(piece[0])
		draw_polyline(edge, INK, 2.0, true)


## The omen: a red star far too bright, pulsing slowly, with long thin rays.
func _draw_omen_star(c: Vector2) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_time * 1.3)
	var col: Color = biome.star_color
	for k in 7:
		draw_circle(c, 16.0 + k * (16.0 + pulse * 4.0), Color(col, 0.07))
	var ray: float = 70.0 + pulse * 18.0
	for k in 4:
		var a: float = PI * 0.5 * k + 0.12
		var dir := Vector2.from_angle(a)
		var side := dir.orthogonal() * 2.4
		draw_colored_polygon(PackedVector2Array([c + side, c + dir * ray, c - side]), Color(col.lightened(0.3), 0.55))
	_star_shape(c, 15.0 + pulse * 2.0, 6.0, col.lightened(0.15), 2.2)
	draw_circle(c, 4.5, Color(1.0, 0.95, 0.85))


## Bands of dirty smog sliding slowly across the sky.
func _draw_smog(s: Vector2) -> void:
	var band: Color = _dim(biome.haze.lerp(biome.sky_bottom, 0.4))
	for k in 4:
		var y: float = s.y * (0.16 + 0.13 * k)
		var drift: float = fmod(_time * (5.0 + k * 3.0) + k * 530.0, s.x + 1200.0) - 600.0
		for j in 4:
			var c := Vector2(drift + j * 190.0 - 200.0, y + sin(j * 2.1 + k) * 10.0)
			draw_colored_polygon(_lens(c, 230.0 - j * 20.0, 24.0 + (j % 2) * 10.0), Color(band, biome.smog * (0.16 + 0.05 * k)))


## Glowing fractures across the sky: an ink seam with a hot core, breathing slowly.
func _draw_cracks(s: Vector2) -> void:
	if _cracks.is_empty():
		_build_cracks(s)
	var pulse: float = 0.65 + 0.35 * sin(_time * 1.7)
	var col: Color = biome.star_color
	for crack in _cracks:
		draw_polyline(crack, Color(col, 0.1 * pulse), 18.0, true)
		draw_polyline(crack, Color(col, 0.22 * pulse), 8.0, true)
		draw_polyline(crack, INK, 4.5, true)
		draw_polyline(crack, Color(col.lightened(0.35), 0.85 * pulse + 0.15), 1.8, true)


func _build_cracks(s: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = biome.scenery_seed * 31 + 5
	for k in 4:
		var p := Vector2(rng.randf_range(0.05, 0.95) * s.x, rng.randf_range(0.02, 0.3) * s.y)
		var dir: float = rng.randf_range(0.3, 2.8)
		var line := PackedVector2Array([p])
		for j in 7:
			dir += rng.randf_range(-0.7, 0.7)
			p += Vector2.from_angle(dir) * rng.randf_range(26.0, 60.0)
			line.append(p)
			# Short branches split off the main fracture.
			if j % 3 == 1:
				var b := PackedVector2Array([p])
				var bd: float = dir + (0.9 if rng.randf() > 0.5 else -0.9)
				var bp: Vector2 = p
				for _i in 3:
					bp += Vector2.from_angle(bd + rng.randf_range(-0.4, 0.4)) * rng.randf_range(14.0, 30.0)
					b.append(bp)
				_cracks.append(b)
		_cracks.append(line)


func _update_stars(delta: float) -> void:
	_next_star -= delta
	if _next_star <= 0.0:
		_next_star = _rng.randf_range(0.4, 1.6) / maxf(biome.falling_star_rate, 0.05)
		var s: Vector2 = size
		var angle: float = deg_to_rad(_rng.randf_range(100.0, 128.0))
		if _rng.randf() > 0.6:
			angle = PI - angle
		_stars.append({
			"pos": Vector2(_rng.randf_range(-0.1, 1.1) * s.x, _rng.randf_range(-0.05, 0.25) * s.y),
			"vel": Vector2.from_angle(angle) * _rng.randf_range(380.0, 760.0),
			"len": _rng.randf_range(90.0, 220.0),
			"size": _rng.randf_range(0.7, 1.3),
		})
	var floor_y: float = size.y * 0.82
	for i in range(_stars.size() - 1, -1, -1):
		var star: Dictionary = _stars[i]
		star["pos"] += (star["vel"] as Vector2) * delta
		if (star["pos"] as Vector2).y > floor_y:
			_stars.remove_at(i)


func _draw_stars() -> void:
	var col: Color = biome.star_color
	for star in _stars:
		var pos: Vector2 = star["pos"]
		var dir: Vector2 = (star["vel"] as Vector2).normalized()
		var length: float = star["len"]
		var sz: float = star["size"]
		# Trail: segments that thin out and fade, hot near the head.
		var segments: int = 8
		for k in segments:
			var t0: float = float(k) / float(segments)
			var t1: float = float(k + 1) / float(segments)
			var a := pos - dir * length * t0
			var b := pos - dir * length * t1
			var w: float = lerpf(5.0, 0.8, t0) * sz
			draw_line(a, b, Color(col.lerp(Color(1.0, 0.9, 0.5), 1.0 - t0), (1.0 - t0) * 0.75), w, true)
		draw_circle(pos, 12.0 * sz, Color(col, 0.18))
		_star_shape(pos, 7.0 * sz, 2.8 * sz, Color(1.0, 0.86, 0.45), 1.6)


## Four-pointed star with an ink outline.
func _star_shape(c: Vector2, outer: float, inner: float, color: Color, ink_w: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var r: float = outer if i % 2 == 0 else inner
		pts.append(c + Vector2.from_angle(TAU * float(i) / 8.0 - PI * 0.5) * r)
	draw_colored_polygon(pts, color)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, INK, ink_w, true)


## Sky colors are dimmed a little with the backdrop so the play field reads first.
func _dim(c: Color) -> Color:
	return c.darkened(biome.backdrop_dim * 0.3)


## Flattened ellipse, fatter on top: the silhouette of a cloud bank.
func _lens(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		var squash: float = 0.45 if sin(a) > 0.0 else 1.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry * squash))
	return pts
