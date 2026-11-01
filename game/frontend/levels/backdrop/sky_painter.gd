@tool
class_name SkyPainter
extends Control
## Screen-space sky for a biome: a three-stop gradient that warms toward the horizon, the sun
## (or moon) with its glow, slow light shafts, and storm lightning flashes. Visual only.

@export var biome: Biome:
	set(value):
		biome = value
		queue_redraw()

var _time: float = 0.0
var _flash: float = 0.0
var _next_flash: float = 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_time += delta
	# A Control under a CanvasLayer has no parent rect to anchor to: follow the viewport.
	if size != get_viewport_rect().size:
		size = get_viewport_rect().size
	if biome != null and biome.lightning and not Engine.is_editor_hint():
		_next_flash -= delta
		if _next_flash <= 0.0:
			_flash = 1.0
			_next_flash = 4.0 + fmod(_time * 7.31, 5.0)
	_flash = maxf(_flash - delta * 3.5, 0.0)
	queue_redraw()


func _draw() -> void:
	if biome == null:
		return
	var s: Vector2 = size
	var horizon: float = s.y * 0.72
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, horizon), Vector2(0, horizon)]),
			PackedColorArray([biome.sky_top, biome.sky_top, biome.sky_bottom, biome.sky_bottom]))
	draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(s.x, horizon), Vector2(s.x, s.y), Vector2(0, s.y)]),
			PackedColorArray([biome.sky_bottom, biome.sky_bottom, biome.haze, biome.haze]))
	var sun: Vector2 = biome.sun_position * s
	# Glow falls off in soft rings; the disc itself is small, the light is what reads.
	for k in 6:
		var r: float = 40.0 + k * 38.0
		draw_circle(sun, r, Color(biome.sun, 0.07))
	draw_circle(sun, 30.0, Color(biome.sun, 0.95))
	if biome.lightning:
		# A thin crescent: the storm moon.
		draw_circle(sun + Vector2(9, -5), 26.0, Color(biome.sky_top, 0.92))
	if biome.light_shafts:
		for k in 5:
			var a: float = deg_to_rad(95.0 + k * 13.0) + sin(_time * 0.25 + k) * 0.03
			var spread: float = deg_to_rad(3.0 + (k % 2) * 2.0)
			var reach: float = s.length()
			draw_colored_polygon(PackedVector2Array([sun, sun + Vector2.from_angle(a - spread) * reach,
					sun + Vector2.from_angle(a + spread) * reach]), Color(biome.sun, 0.05 + 0.02 * (k % 2)))
	if biome.lightning:
		# Long flat cloud banks sliding past, each a stack of soft lens shapes with a lit rim.
		for k in 3:
			var y: float = s.y * (0.1 + 0.11 * k)
			var drift: float = fmod(_time * (8.0 + k * 5.0) + k * 420.0, s.x + 900.0) - 450.0
			var shade := Color(biome.sky_top.lerp(biome.haze, 0.25 + 0.12 * k), 0.75)
			for j in 5:
				var c := Vector2(drift + j * 85.0, y + sin(j * 1.7 + k) * 8.0)
				var lens := _lens(c, 110.0 - absf(j - 2.0) * 18.0, 18.0 + (2.0 - absf(j - 2.0)) * 5.0)
				draw_colored_polygon(lens, shade)
				draw_polyline(_lens(c + Vector2(0, -2), 100.0 - absf(j - 2.0) * 18.0, 14.0), Color(biome.haze, 0.35), 2.0, true)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1, 1, 1, 0.45 * _flash))


## Flattened ellipse, fatter on top: the silhouette of a cloud bank.
func _lens(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		var squash: float = 0.45 if sin(a) > 0.0 else 1.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry * squash))
	return pts
