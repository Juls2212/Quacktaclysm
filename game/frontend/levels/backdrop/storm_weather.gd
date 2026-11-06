class_name StormWeather
extends Node2D
## Level 3 weather, visual only: wind-driven diagonal rain over the play field, frequent lightning
## bolts forking down behind the scenery, and their flash lighting the whole view for an instant.
## The rain and the flash are drawn in world space just above the foreground (below every UI
## layer); the bolts sit on a canvas layer between the sky and the scenery. Never touches gameplay.

const RAIN_COUNT: int = 170
const RAIN_VELOCITY := Vector2(-460.0, 1150.0)
const RAIN_COLOR := Color(0.78, 0.84, 0.95, 0.38)
const BOLT_COLOR := Color(0.92, 0.95, 1.0)
const GLOW_COLOR := Color(0.6, 0.72, 1.0)
const FLASH_COLOR := Color(0.85, 0.9, 1.0)

## Seconds between strikes (random in this range); some strikes come in pairs.
@export var strike_every: Vector2 = Vector2(1.6, 4.2)
@export_range(0.0, 1.0, 0.01) var flash_strength: float = 0.32

var _time: float = 0.0
var _rain: Array[Vector3] = []
var _next_strike: float = 1.2
var _bolts: Array = []
var _flash: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sky: Node2D = null


func _ready() -> void:
	z_index = 45
	_rng.seed = 7331
	for i in RAIN_COUNT:
		_rain.append(Vector3(_rng.randf(), _rng.randf(), 0.7 + _rng.randf() * 0.6))
	var layer := CanvasLayer.new()
	layer.name = "BoltLayer"
	# Above the sky painter (-5), behind the scenery and the play field.
	layer.layer = -4
	add_child(layer)
	_sky = Node2D.new()
	_sky.name = "Bolts"
	layer.add_child(_sky)
	_sky.draw.connect(_draw_bolts)


func _process(delta: float) -> void:
	_time += delta
	_next_strike -= delta
	if _next_strike <= 0.0:
		_strike()
		_next_strike = _rng.randf_range(strike_every.x, strike_every.y)
		if _rng.randf() < 0.3:
			# A second strike right behind the first.
			_next_strike = _rng.randf_range(0.18, 0.35)
	for i in range(_bolts.size() - 1, -1, -1):
		_bolts[i]["life"] = float(_bolts[i]["life"]) - delta
		if float(_bolts[i]["life"]) <= 0.0:
			_bolts.remove_at(i)
	_flash = maxf(_flash - delta * 3.2, 0.0)
	queue_redraw()
	_sky.queue_redraw()


func _strike() -> void:
	var view: Vector2 = get_viewport_rect().size
	var x: float = _rng.randf_range(0.08, 0.92) * view.x
	var end_y: float = view.y * _rng.randf_range(0.45, 0.7)
	var main := PackedVector2Array([Vector2(x + _rng.randf_range(-60.0, 60.0), -10.0)])
	var p: Vector2 = main[0]
	var steps: int = 11
	for i in steps:
		p = Vector2(p.x + _rng.randf_range(-34.0, 34.0) + (x - p.x) * 0.15, lerpf(-10.0, end_y, float(i + 1) / float(steps)))
		main.append(p)
	var forks: Array = []
	for k in _rng.randi_range(1, 3):
		var from_i: int = _rng.randi_range(2, steps - 3)
		var q: Vector2 = main[from_i]
		var dir: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var fork := PackedVector2Array([q])
		for j in 4:
			q += Vector2(dir * _rng.randf_range(14.0, 34.0), _rng.randf_range(16.0, 30.0))
			fork.append(q)
		forks.append(fork)
	_bolts.append({"main": main, "forks": forks, "life": 0.38, "salt": _rng.randf() * 10.0})
	_flash = 1.0


func _draw() -> void:
	# Screen space: undo the camera so the rain fills the view wherever it is.
	var view: Vector2 = get_viewport_rect().size
	var to_world: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	draw_set_transform_matrix(global_transform.affine_inverse() * to_world)
	var dir: Vector2 = RAIN_VELOCITY.normalized()
	var span := Vector2(view.x + 300.0, view.y + 60.0)
	for drop in _rain:
		var speed: float = drop.z
		var px: float = fposmod(drop.x * span.x + RAIN_VELOCITY.x * speed * _time, span.x) - 150.0
		var py: float = fposmod(drop.y * span.y + RAIN_VELOCITY.y * speed * _time, span.y) - 30.0
		var at := Vector2(px, py)
		draw_line(at, at + dir * 26.0 * speed, Color(RAIN_COLOR, RAIN_COLOR.a * speed), 1.4 if speed > 1.0 else 1.0, true)
	if _flash > 0.0:
		# A double flicker as the strike lands.
		var flick: float = _flash * (0.65 + 0.35 * sin(_flash * 40.0))
		draw_rect(Rect2(Vector2.ZERO, view), Color(FLASH_COLOR, flash_strength * flick))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_bolts() -> void:
	for bolt in _bolts:
		var life: float = float(bolt["life"]) / 0.38
		# Flickers on and off as it fades.
		var on: float = life * (0.55 + 0.45 * signf(sin(float(bolt["salt"]) + life * 30.0)))
		if on <= 0.02:
			continue
		var main: PackedVector2Array = bolt["main"]
		_sky.draw_polyline(main, Color(GLOW_COLOR, 0.25 * on), 14.0, true)
		_sky.draw_polyline(main, Color(GLOW_COLOR, 0.5 * on), 6.0, true)
		_sky.draw_polyline(main, Color(BOLT_COLOR, on), 2.6, true)
		for fork in bolt["forks"]:
			_sky.draw_polyline(fork, Color(GLOW_COLOR, 0.35 * on), 5.0, true)
			_sky.draw_polyline(fork, Color(BOLT_COLOR, 0.85 * on), 1.6, true)
		var end: Vector2 = main[main.size() - 1]
		_sky.draw_circle(end, 26.0, Color(GLOW_COLOR, 0.18 * on))
