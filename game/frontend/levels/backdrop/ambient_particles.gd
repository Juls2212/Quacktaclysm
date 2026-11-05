class_name AmbientParticles
extends Node2D
## Air of a biome drifting across the view: dust, leaves, fireflies, rain, ash, feathers, embers
## or eyes floating in the dark. Particles live in world space and wrap around whatever the camera
## shows. Visual only. By default the kind, color and count come from the biome; `setup()` lets the
## backdrop add extra emitters (the biome's ash and feathers) with their own settings.

const INK := Color(0.106, 0.098, 0.122)

@export var biome: Biome

var kind: Biome.Particles = Biome.Particles.NONE
var color: Color = Color.WHITE
var count: int = 0

var _configured: bool = false
var _p: Array[Dictionary] = []
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


## Overrides the biome's own particle settings (call before adding the node to the tree).
func setup(p_kind: Biome.Particles, p_color: Color, p_count: int, p_seed: int = 7) -> void:
	kind = p_kind
	color = p_color
	count = p_count
	_rng.seed = p_seed
	_configured = true


func _ready() -> void:
	if not _configured:
		_rng.seed = 7
		if biome != null:
			kind = biome.particles
			color = biome.particle_color
			count = biome.particle_count
	var view: Rect2 = _view()
	for i in count:
		_p.append({
			"pos": view.position + Vector2(_rng.randf() * view.size.x, _rng.randf() * view.size.y),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.6, 1.4),
			"size": _rng.randf_range(0.7, 1.3),
		})


func _process(delta: float) -> void:
	if kind == Biome.Particles.NONE:
		return
	_time += delta
	var view: Rect2 = _view()
	for p in _p:
		var v: Vector2 = _velocity(p)
		p["pos"] += v * delta
		# Wrap into the visible rectangle (with a margin so nothing pops at the edges).
		var margin: float = 40.0
		var area := Rect2(view.position - Vector2(margin, margin), view.size + Vector2(margin, margin) * 2.0)
		var pos: Vector2 = p["pos"]
		pos.x = area.position.x + fposmod(pos.x - area.position.x, area.size.x)
		pos.y = area.position.y + fposmod(pos.y - area.position.y, area.size.y)
		p["pos"] = pos
	queue_redraw()


func _velocity(p: Dictionary) -> Vector2:
	var s: float = p["speed"]
	var ph: float = p["phase"]
	match kind:
		Biome.Particles.POLLEN:
			return Vector2(18.0 + sin(_time * 0.8 + ph) * 14.0, -10.0 + cos(_time * 1.1 + ph) * 8.0) * s
		Biome.Particles.LEAVES:
			return Vector2(-40.0 + sin(_time * 1.5 + ph) * 40.0, 55.0) * s
		Biome.Particles.FIREFLIES:
			return Vector2(sin(_time * 0.7 + ph) * 22.0, cos(_time * 0.9 + ph * 1.3) * 16.0) * s
		Biome.Particles.RAIN:
			return Vector2(-160.0, 900.0) * s
		Biome.Particles.ASH:
			return Vector2(-14.0 + sin(_time * 0.9 + ph) * 22.0, 26.0 + cos(_time * 1.3 + ph) * 8.0) * s
		Biome.Particles.FEATHERS:
			# Rocking side to side as they sink, like a falling leaf but slower.
			return Vector2(sin(_time * 1.2 + ph) * 46.0 - 8.0, 30.0 + absf(cos(_time * 1.2 + ph)) * 22.0) * s
		Biome.Particles.EMBERS:
			return Vector2(12.0 + sin(_time * 2.1 + ph) * 18.0, -38.0 - cos(_time * 1.7 + ph) * 10.0) * s
		Biome.Particles.EYES:
			return Vector2(sin(_time * 0.3 + ph) * 8.0, cos(_time * 0.25 + ph * 1.3) * 5.0) * s
	return Vector2.ZERO


func _draw() -> void:
	var c: Color = color
	for p in _p:
		var pos: Vector2 = p["pos"]
		var sz: float = p["size"]
		var ph: float = p["phase"]
		match kind:
			Biome.Particles.POLLEN:
				draw_circle(pos, 4.0 * sz, Color(c, 0.18))
				draw_circle(pos, 1.6 * sz, Color(c, 0.85))
			Biome.Particles.LEAVES:
				var rot: float = _time * 2.0 * (p["speed"] as float) + ph
				var leaf := PackedVector2Array()
				for i in 8:
					var a: float = TAU * float(i) / 8.0
					leaf.append(pos + Vector2(cos(a) * 5.0 * sz, sin(a) * 2.6 * sz).rotated(rot))
				draw_colored_polygon(leaf, c)
				var closed := PackedVector2Array(leaf)
				closed.append(leaf[0])
				draw_polyline(closed, INK, 1.4, true)
			Biome.Particles.FIREFLIES:
				var glow: float = 0.5 + 0.5 * sin(_time * 3.0 + ph * 2.0)
				draw_circle(pos, 7.0 * sz, Color(c, 0.14 * glow))
				draw_circle(pos, 2.0 * sz, Color(c, 0.4 + 0.6 * glow))
			Biome.Particles.RAIN:
				draw_line(pos, pos + Vector2(-5.0, 26.0) * sz, Color(c, 0.35), 1.4, true)
			Biome.Particles.ASH:
				var rot: float = _time * 1.1 * (p["speed"] as float) + ph
				var flake := PackedVector2Array([pos + Vector2(-2.6, -1.2).rotated(rot) * sz, pos + Vector2(1.8, -2.0).rotated(rot) * sz,
						pos + Vector2(2.8, 1.4).rotated(rot) * sz, pos + Vector2(-1.4, 2.2).rotated(rot) * sz])
				draw_colored_polygon(flake, Color(c, 0.75))
				# A few flakes still smoulder at the edge.
				if int(ph * 10.0) % 5 == 0:
					draw_circle(pos, 1.2 * sz, Color(1.0, 0.45, 0.15, 0.5 + 0.4 * sin(_time * 4.0 + ph)))
			Biome.Particles.FEATHERS:
				_feather(pos, sz, sin(_time * 1.2 + ph) * 0.9 + 0.4, c)
			Biome.Particles.EMBERS:
				var flicker: float = 0.55 + 0.45 * sin(_time * 7.0 + ph * 3.0)
				draw_circle(pos, 5.0 * sz, Color(c, 0.16 * flicker))
				draw_circle(pos, 1.7 * sz, Color(c.lightened(0.3), 0.5 + 0.5 * flicker))
			Biome.Particles.EYES:
				_eyes(pos, sz, ph, c)


## Little down feather: a curved quill with a soft vane on each side, inked.
func _feather(pos: Vector2, sz: float, rot: float, c: Color) -> void:
	var length: float = 13.0 * sz
	var vane := PackedVector2Array()
	for i in 9:
		var t: float = float(i) / 8.0
		vane.append(Vector2(lerpf(-length * 0.5, length * 0.5, t), -sin(t * PI) * 3.6 * sz))
	# Underside without the two end points the top already has (no duplicate vertices).
	for i in range(7, 0, -1):
		var t: float = float(i) / 8.0
		vane.append(Vector2(lerpf(-length * 0.5, length * 0.5, t), sin(t * PI) * 2.6 * sz + t * 1.2))
	var shape := PackedVector2Array()
	for v in vane:
		shape.append(pos + v.rotated(rot))
	draw_colored_polygon(shape, c)
	var closed := PackedVector2Array(shape)
	closed.append(shape[0])
	draw_polyline(closed, INK, 1.3, true)
	draw_line(pos + Vector2(-length * 0.62, 0.6).rotated(rot), pos + Vector2(length * 0.5, 0.0).rotated(rot), INK, 1.1, true)


## A pair of eyes hanging in the air, blinking out of step with each other.
func _eyes(pos: Vector2, sz: float, ph: float, c: Color) -> void:
	var cycle: float = fposmod(_time * (0.25 + 0.1 * sz) + ph, 1.0)
	var open: float = 1.0
	if cycle > 0.93:
		open = absf(cycle - 0.965) / 0.035
	var gap: float = 6.5 * sz
	draw_circle(pos, 13.0 * sz, Color(c, 0.08))
	for side in [-1.0, 1.0]:
		var e: Vector2 = pos + Vector2(side * gap * 0.5, 0.0)
		var lid := PackedVector2Array()
		for i in 10:
			var a: float = TAU * float(i) / 10.0
			lid.append(e + Vector2(cos(a) * 2.6 * sz, sin(a) * 1.9 * sz * maxf(open, 0.08)))
		draw_colored_polygon(lid, Color(c, 0.95))
		if open > 0.4:
			draw_line(e + Vector2(0, -1.3 * sz * open), e + Vector2(0, 1.3 * sz * open), INK, 1.1, true)


## The world rectangle the active camera shows (or the viewport when there is none).
func _view() -> Rect2:
	var vp_size: Vector2 = get_viewport_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null:
		return Rect2(Vector2.ZERO, vp_size)
	var zoom: Vector2 = cam.zoom
	var view_size: Vector2 = vp_size / zoom
	return Rect2(cam.get_screen_center_position() - view_size * 0.5, view_size)
