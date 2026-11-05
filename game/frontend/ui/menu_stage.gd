extends Node2D
## The living picture behind the main menu: a cold post-apocalyptic night, grey-blue fog over
## ruins and dead trees, and the worn-out hero walking right with a lit torch held high, his katana
## at the waist, glancing back now and then at the wave of shadow ducks rolling in from the left.
## The torch throws a warm flickering circle that keeps the shadows at bay. The ground and the
## ruins scroll slowly so he seems to walk. The sign post on the right holds the menu signs.
## Visual only.

const ShadowWaveScript := preload("res://frontend/ui/shadow_wave.gd")
const INK := Color(0.106, 0.098, 0.122)
const GROUND_Y: float = 612.0
const HERO_X: float = 450.0
const HERO_SCALE: float = 2.1
## Pixels per second the ground slides under the hero's feet.
const GROUND_SPEED: float = 46.0

## Screen x of the sign post the menu hangs from.
@export var post_x: float = 1012.0
@export var post_top: float = 118.0

var _hero: DuckRig
var _wave: Node2D
var _light: PointLight2D
var _time: float = 0.0
var _scroll: float = 0.0
var _next_glance: float = 4.0
var _glance_left: float = 0.0


func _ready() -> void:
	var backdrop := Backdrop.new()
	backdrop.biome = _night_biome()
	backdrop.auto_scroll = 24.0
	# No foreground silhouettes here: they would sit over the menu text.
	backdrop.show_foreground = false
	add_child(backdrop)
	# Everything stays at z 0 so the menu's title, tagline and signs are always drawn on top.
	_wave = ShadowWaveScript.new()
	_wave.set("ground_y", GROUND_Y)
	add_child(_wave)
	_hero = DuckRig.new()
	_hero.look = DuckRig.Look.HERO
	_hero.gesture = DuckRig.Gesture.HOLD_TORCH
	_hero.scale = Vector2.ONE * HERO_SCALE
	_hero.position = Vector2(HERO_X, GROUND_Y + 2.0 - 26.0 * HERO_SCALE)
	add_child(_hero)
	_light = PointLight2D.new()
	_light.texture = _light_texture()
	_light.color = Color(1.0, 0.72, 0.38)
	_light.energy = 0.9
	_light.texture_scale = 1.3
	add_child(_light)


func _process(delta: float) -> void:
	_time += delta
	# Walking in place; now and then a nervous look back at the wave (he stops for it).
	_next_glance -= delta
	if _next_glance <= 0.0:
		_glance_left = 0.9
		_next_glance = 4.5 + fmod(_time * 1.7, 3.5)
	_glance_left = maxf(_glance_left - delta, 0.0)
	var glancing: bool = _glance_left > 0.0
	_hero.scale.x = -HERO_SCALE if glancing else HERO_SCALE
	_hero.ground_speed = 0.0 if glancing else 120.0
	if not glancing:
		_scroll += GROUND_SPEED * delta
	var torch: Vector2 = _hero.position + Vector2(13.0 * signf(_hero.scale.x), -50.0)
	var flicker: float = 0.85 + 0.1 * sin(_time * 11.0) * sin(_time * 7.3 + 1.0) + 0.05 * sin(_time * 23.0)
	_light.position = torch
	_light.energy = flicker
	_wave.set("light_center", torch + Vector2(0, 40))
	_wave.set("light_radius", 165.0 + 12.0 * flicker)
	queue_redraw()


func _draw() -> void:
	_draw_ground()
	_draw_post()
	# A faint warm halo on the fog around the torch, on top of the real light.
	var torch: Vector2 = _hero.position + Vector2(13.0 * signf(_hero.scale.x), -50.0) if _hero != null else Vector2(HERO_X, 470)
	for k in 4:
		draw_circle(torch, 60.0 + k * 42.0, Color(1.0, 0.7, 0.35, 0.035))


## Scrolling strip of cold, cracked earth with dead grass and rubble, drawn with ink and hatching.
func _draw_ground() -> void:
	var top: float = GROUND_Y
	draw_rect(Rect2(-10, top, 1300, 140), Color(0.2, 0.2, 0.23))
	draw_rect(Rect2(-10, top + 28, 1300, 120), Color(0.15, 0.15, 0.18))
	var edge := PackedVector2Array()
	var x: float = -10.0
	while x <= 1300.0:
		edge.append(Vector2(x, top + sin((x + _scroll) * 0.035) * 2.0 + sin((x + _scroll) * 0.11) * 1.2))
		x += 12.0
	draw_polyline(edge, INK, 3.4, true)
	var spacing: float = 64.0
	var shift: float = fposmod(_scroll, spacing)
	var count: int = int(1300.0 / spacing) + 2
	for i in count:
		var gx: float = float(i) * spacing - shift
		var cell: int = i + int(floorf(_scroll / spacing))
		var r: float = _h(cell)
		# Withered tufts.
		for k in 3:
			var bx: float = gx + float(k) * 4.0
			var tip := Vector2(bx + (float(k) - 1.0) * 3.0, top - 7.0 - r * 7.0)
			draw_line(Vector2(bx, top + 1), tip, INK, 2.6, true)
			draw_line(Vector2(bx, top + 1), tip, Color(0.42, 0.42, 0.36), 1.2, true)
		# Cracks and hatching in the earth.
		draw_line(Vector2(gx + 20, top + 6), Vector2(gx + 26 + r * 8.0, top + 22), Color(INK, 0.7), 1.4, true)
		for k in 3:
			var hx: float = gx + 34.0 + float(k) * 4.0
			draw_line(Vector2(hx, top + 40), Vector2(hx + 8, top + 30), Color(INK, 0.4), 1.0, true)
		# Rubble every few cells.
		if r > 0.7:
			var c := Vector2(gx + 44.0, top - 3.0)
			var rock := PackedVector2Array([c + Vector2(-7, 3), c + Vector2(-5, -4), c + Vector2(4, -5), c + Vector2(8, 3)])
			draw_colored_polygon(rock, Color(0.34, 0.34, 0.37))
			var closed := PackedVector2Array(rock)
			closed.append(rock[0])
			draw_polyline(closed, INK, 2.0, true)


func _draw_post() -> void:
	# The sign post: a weathered pole with a cross beam the signs are nailed to.
	var base := Vector2(post_x, GROUND_Y + 6.0)
	var pole := PackedVector2Array([base + Vector2(-9, 0), Vector2(post_x - 7, post_top), Vector2(post_x + 7, post_top - 2), base + Vector2(10, 0)])
	draw_colored_polygon(pole, Color(0.33, 0.25, 0.19))
	draw_line(Vector2(post_x + 2, post_top + 10), base + Vector2(3, -6), Color(0.22, 0.16, 0.12), 2.0, true)
	_outline(pole)
	var beam := PackedVector2Array([Vector2(post_x - 190, post_top + 6), Vector2(post_x + 190, post_top - 2), Vector2(post_x + 192, post_top + 14),
			Vector2(post_x - 188, post_top + 22)])
	draw_colored_polygon(beam, Color(0.37, 0.27, 0.2))
	_outline(beam)
	draw_circle(Vector2(post_x, post_top + 10), 4.0, INK)


## Cold night over the ruins: grey-blue fog, a pale moon, dead trees, ash in the air.
func _night_biome() -> Biome:
	var b := Biome.new()
	b.kind = Biome.Kind.RUINED_CITY
	b.scenery_seed = 87
	b.sky_top = Color(0.13, 0.16, 0.22)
	b.sky_bottom = Color(0.34, 0.38, 0.44)
	b.haze = Color(0.42, 0.46, 0.52)
	b.sun = Color(0.82, 0.86, 0.88)
	b.sun_position = Vector2(0.8, 0.16)
	b.light_shafts = false
	b.smog = 0.55
	b.far_color = Color(0.28, 0.32, 0.38)
	b.mid_color = Color(0.19, 0.22, 0.27)
	b.near_color = Color(0.11, 0.12, 0.16)
	b.foreground_color = Color(0.04, 0.04, 0.06)
	b.haze_amount = Vector3(0.5, 0.3, 0.12)
	b.backdrop_dim = 0.12
	b.backdrop_desaturation = 0.35
	b.accent = Color(1.0, 0.72, 0.35)
	b.particles = Biome.Particles.ASH
	b.particle_color = Color(0.62, 0.64, 0.68)
	b.particle_count = 45
	b.dead_trees = true
	b.ruin_silhouettes = true
	b.vignette = true
	b.vignette_strength = 0.5
	return b


## Soft radial glow for the torch light.
func _light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _outline(points: PackedVector2Array) -> void:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	draw_polyline(closed, INK, 3.0, true)


func _h(i: int) -> float:
	var v: float = sin(float(i) * 12.9898 + 78.233) * 43758.5453
	return v - floorf(v)
