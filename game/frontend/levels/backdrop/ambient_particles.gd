class_name AmbientParticles
extends Node2D
## Air of a biome drifting across the view: pollen, falling leaves, fireflies or rain.
## Particles live in world space and wrap around whatever the camera shows. Visual only.

const INK := Color(0.106, 0.098, 0.122)

@export var biome: Biome

var _p: Array[Dictionary] = []
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	if biome == null:
		return
	var view: Rect2 = _view()
	for i in biome.particle_count:
		_p.append({
			"pos": view.position + Vector2(_rng.randf() * view.size.x, _rng.randf() * view.size.y),
			"phase": _rng.randf() * TAU,
			"speed": _rng.randf_range(0.6, 1.4),
			"size": _rng.randf_range(0.7, 1.3),
		})


func _process(delta: float) -> void:
	if biome == null:
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
	match biome.particles:
		Biome.Particles.POLLEN:
			return Vector2(18.0 + sin(_time * 0.8 + ph) * 14.0, -10.0 + cos(_time * 1.1 + ph) * 8.0) * s
		Biome.Particles.LEAVES:
			return Vector2(-40.0 + sin(_time * 1.5 + ph) * 40.0, 55.0) * s
		Biome.Particles.FIREFLIES:
			return Vector2(sin(_time * 0.7 + ph) * 22.0, cos(_time * 0.9 + ph * 1.3) * 16.0) * s
		Biome.Particles.RAIN:
			return Vector2(-160.0, 900.0) * s
	return Vector2.ZERO


func _draw() -> void:
	if biome == null:
		return
	var c: Color = biome.particle_color
	for p in _p:
		var pos: Vector2 = p["pos"]
		var sz: float = p["size"]
		var ph: float = p["phase"]
		match biome.particles:
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


## The world rectangle the active camera shows (or the viewport when there is none).
func _view() -> Rect2:
	var vp_size: Vector2 = get_viewport_rect().size
	var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam == null:
		return Rect2(Vector2.ZERO, vp_size)
	var zoom: Vector2 = cam.zoom
	var view_size: Vector2 = vp_size / zoom
	return Rect2(cam.get_screen_center_position() - view_size * 0.5, view_size)
