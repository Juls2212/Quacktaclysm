class_name FeatherBurst
extends Node2D
## Death puff of a duck: a pop of ink-outlined feathers that fly out, then drift down swaying
## like leaves and fade. Drawn in code (thick-ink style), visual only, frees itself.
## `FeatherBurst.spawn(container, position, tint, count)`.

const INK := Color(0.106, 0.098, 0.122)
const LIFETIME: float = 1.8
const GRAVITY: float = 260.0
const DRAG: float = 3.2

var tint: Color = Color(0.96, 0.94, 0.88)
var count: int = 14
var _feathers: Array[Dictionary] = []
var _age: float = 0.0
var _rng := RandomNumberGenerator.new()


static func spawn(container: Node, at: Vector2, feather_tint: Color = Color(0.96, 0.94, 0.88),
		amount: int = 14) -> FeatherBurst:
	if container == null or not container.is_inside_tree():
		return null
	var burst := FeatherBurst.new()
	burst.name = "FeatherBurst"
	burst.tint = feather_tint
	burst.count = amount
	burst.z_index = 5
	container.add_child(burst)
	burst.global_position = at
	return burst


func _ready() -> void:
	_rng.randomize()
	for i in count:
		var angle: float = _rng.randf_range(-PI, 0.0) + _rng.randf_range(-0.3, 0.3)
		var speed: float = _rng.randf_range(140.0, 360.0)
		var shade: float = _rng.randf_range(-0.12, 0.06)
		_feathers.append({
			"pos": Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-22.0, 0.0)),
			"vel": Vector2.from_angle(angle) * speed,
			"rot": _rng.randf_range(0.0, TAU),
			"spin": _rng.randf_range(-6.0, 6.0),
			"sway": _rng.randf_range(0.0, TAU),
			"len": _rng.randf_range(7.0, 12.0),
			"color": tint.lightened(shade) if shade > 0.0 else tint.darkened(-shade),
		})


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	for f in _feathers:
		var vel: Vector2 = f["vel"]
		vel.x -= vel.x * DRAG * delta
		vel.y += GRAVITY * delta
		# Feathers fall slowly: terminal speed with a side-to-side flutter.
		vel.y = minf(vel.y, 55.0)
		f["sway"] = float(f["sway"]) + delta * 5.0
		var pos: Vector2 = f["pos"]
		f["pos"] = pos + (vel + Vector2(sin(float(f["sway"])) * 38.0, 0.0)) * delta
		f["vel"] = vel
		f["rot"] = float(f["rot"]) + float(f["spin"]) * delta + sin(float(f["sway"])) * delta * 2.0
		f["spin"] = float(f["spin"]) * (1.0 - 1.5 * delta)
	queue_redraw()


func _draw() -> void:
	var alpha: float = clampf((LIFETIME - _age) / 0.6, 0.0, 1.0)
	# The pop: a quick white flash ring in the first moments.
	if _age < 0.18:
		var k: float = _age / 0.18
		draw_arc(Vector2(0, -12), 10.0 + 26.0 * k, 0.0, TAU, 24, Color(1, 1, 1, 0.8 * (1.0 - k)), 4.0 * (1.0 - k) + 1.0, true)
	for f in _feathers:
		_draw_feather(f["pos"], float(f["rot"]), float(f["len"]), f["color"], alpha)


func _draw_feather(at: Vector2, rot: float, length: float, color: Color, alpha: float) -> void:
	var dir := Vector2.from_angle(rot)
	var side := dir.orthogonal() * length * 0.32
	var tip: Vector2 = at + dir * length * 0.5
	var root: Vector2 = at - dir * length * 0.5
	var vane := PackedVector2Array([root, at + side, tip, at - side * 0.8])
	var fill := Color(color, alpha)
	draw_colored_polygon(vane, fill)
	var outline := PackedVector2Array(vane)
	outline.append(root)
	draw_polyline(outline, Color(INK, alpha), 1.5, true)
	draw_line(root - dir * 3.0, tip, Color(INK, alpha * 0.8), 1.2, true)
