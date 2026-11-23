class_name ElectricPlateArt
extends Node2D
## The drawing of an ElectricPlate (Phase 15g), all in code. WARNING: a pale blue-white band with a pulsing DASHED outline and a short
## zigzag of sparks; ACTIVE: a bright yellow-white band crossed by zigzag bolts with a thick solid outline. It reads by shape (dashed
## against solid outline, the zigzag) and never by color alone, and it never uses red, orange or the enemy-projectile palette. With
## "Efectos de corrupción" off (reduced) there is no flicker and no spark particles: the state changes only by outline and fill.
## `WARN`, `SHOCK` and `OUTLINE` are the colors the contrast test measures. Presentation only.

const WARN := Color(0.78, 0.92, 1.0)
const SHOCK := Color(1.0, 0.97, 0.62)
const BOLT := Color(1.0, 1.0, 1.0)
const OUTLINE := Color(0.106, 0.098, 0.122)

var reduced: bool = false
var particles: Array[Dictionary] = []

var _plate: ElectricPlate = null
var _time: float = 0.0


func _ready() -> void:
	_plate = get_parent() as ElectricPlate
	z_index = 2
	reduced = not GameSettings.is_corruption_effects_enabled()
	if _plate != null:
		_plate.state_changed.connect(func(_state: int) -> void: queue_redraw())


func _process(delta: float) -> void:
	_time += delta
	if _plate == null:
		return
	if reduced or _plate.state == ElectricPlate.State.REST:
		if not particles.is_empty():
			particles.clear()
		if _plate.state != ElectricPlate.State.REST and not reduced:
			queue_redraw()
		return
	for particle in particles:
		particle["life"] = float(particle["life"]) - delta
		particle["pos"] = (particle["pos"] as Vector2) + (particle["vel"] as Vector2) * delta
	particles = particles.filter(func(p: Dictionary) -> bool: return float(p["life"]) > 0.0)
	while particles.size() < _plate.config.max_particles and randf() < 0.5:
		var x: float = randf_range(0.0, _plate.length)
		var speed: float = 160.0 if _plate.state == ElectricPlate.State.ACTIVE else 60.0
		particles.append({"pos": Vector2(x, -_plate.config.band_height), "vel": Vector2(randf_range(-30.0, 30.0), -randf_range(0.4, 1.0) * speed), "life": 0.35})
	queue_redraw()


func _draw() -> void:
	if _plate == null or _plate.state == ElectricPlate.State.REST:
		return
	var band: float = _plate.config.band_height
	var rect := Rect2(0.0, -band, _plate.length, band)
	var warning: bool = _plate.state == ElectricPlate.State.WARNING
	var progress: float = clampf(_plate.state_time / maxf(_plate.state_duration(_plate.state), 0.001), 0.0, 1.0)
	if warning:
		var pulse: float = 0.6 if reduced else 0.5 + 0.5 * sin(_time * (7.0 + 12.0 * progress))
		draw_rect(rect, Color(WARN, 0.18 + 0.2 * pulse))
		_dashed_rect(rect, Color(OUTLINE, 0.95), 4.0 + 1.5 * pulse)
		_dashed_rect(rect.grow(-2.0), Color(WARN, 0.95), 2.0)
		_zigzag(rect, 0.0, 6.0, Color(WARN, 0.9), 2.0)
	else:
		draw_rect(rect, Color(SHOCK, 0.85))
		draw_rect(rect, Color(OUTLINE, 0.95), false, 4.0)
		_zigzag(rect, 0.0, 9.0, Color(OUTLINE, 0.9), 5.0)
		_zigzag(rect, 0.0, 9.0, Color(BOLT, 1.0), 2.5)
		_zigzag(rect, 5.0, 7.0, Color(BOLT, 0.8), 1.8)
	for particle in particles:
		var at: Vector2 = particle["pos"]
		draw_line(at, at + Vector2(randf_range(-4.0, 4.0), 6.0), Color(BOLT, clampf(float(particle["life"]) * 3.0, 0.0, 1.0)), 2.0)


## A zigzag across the plate (the bolt). `shift` offsets it; `height` is how far it swings.
func _zigzag(rect: Rect2, shift: float, height: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var step: float = 18.0
	var x: float = rect.position.x + 4.0 + shift
	var up: bool = true
	while x < rect.end.x - 4.0:
		points.append(Vector2(x, rect.get_center().y + (-height if up else height) * 0.5))
		x += step
		up = not up
	if points.size() >= 2:
		draw_polyline(points, color, width, true)


func _dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	var dash: float = 14.0
	var gap: float = 9.0
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length: float = a.distance_to(b)
		var direction: Vector2 = (b - a) / maxf(length, 0.001)
		var along: float = 0.0
		while along < length:
			draw_line(a + direction * along, a + direction * minf(along + dash, length), color, width)
			along += dash + gap
