class_name SoulPickup
extends Node2D
## The soul of what dies (Phase 15n). A regular enemy leaves a small BLUE FRAGMENT: a glowing shard with a trail that floats up for a moment
## and then homes in on the player, who always collects it (it is never lost while a living player exists); it ONLY adds soul to the Soul
## meter (never hearts; the meter keeps its rules: cap 99, reset on load and respawn). The ducklings of boss 3 drop a smaller one with their
## own value. A boss still leaves the big pale wisp of before (no blue fragment). With nobody alive to absorb it, it only fades. No collision
## and no physics. The number of simultaneous fragments is capped (SoulConfig.fragment_max_active): past the cap a new fragment merges its
## value into an existing one, so nothing is lost and nothing piles up. `SoulPickup.spawn(container, position, amount, style)`.

enum Style { FRAGMENT, SMALL, WISP }

const GROUP: StringName = &"soul_fragment"

var amount: int = 0
var style: Style = Style.FRAGMENT
var absorb_time: float = 0.8

var _target: Player = null
var _age: float = 0.0
var _done: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _trail: Array[Vector2] = []
var _config: SoulConfig = null
var _reduced: bool = false


static func spawn(container: Node, at: Vector2, soul_amount: int, pickup_style: Style = Style.WISP) -> SoulPickup:
	if container == null or not container.is_inside_tree():
		return null
	var config: SoulConfig = SoulConfig.get_default()
	if pickup_style != Style.WISP:
		# Past the cap the value joins a fragment that already exists: nothing is lost and nothing piles up.
		var active: Array[Node] = container.get_tree().get_nodes_in_group(GROUP)
		if active.size() >= config.fragment_max_active and not active.is_empty():
			(active[0] as SoulPickup).amount += soul_amount
			return active[0] as SoulPickup
	var pickup := SoulPickup.new()
	pickup.name = "SoulPickup"
	pickup.amount = soul_amount
	pickup.style = pickup_style
	pickup._config = config
	pickup.absorb_time = config.wisp_absorb_time
	pickup.z_index = 6
	container.add_child(pickup)
	pickup.global_position = at
	var found := container.get_tree().get_first_node_in_group(&"player") as Player
	if found != null and not found.is_dead:
		pickup._target = found
	SoulWisp.spawn(pickup, at)
	if pickup_style != Style.WISP:
		pickup.add_to_group(GROUP)
		pickup._reduced = not GameSettings.is_corruption_effects_enabled()
		pickup._velocity = Vector2(randf_range(-30.0, 30.0), -config.fragment_rise_speed)
	return pickup


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	if style == Style.WISP:
		_process_wisp(delta)
		return
	_process_fragment(delta)
	queue_redraw()


## The old behaviour of the big pale wisp: it homes in and is absorbed by `absorb_time` at the latest.
func _process_wisp(delta: float) -> void:
	var alive: bool = _target != null and is_instance_valid(_target) and not _target.is_dead
	if alive:
		var destination: Vector2 = _target.global_position + Vector2(0.0, -16.0)
		global_position = global_position.move_toward(destination, (220.0 + 1100.0 * _age) * delta)
		if global_position.distance_to(destination) < 18.0 or _age >= absorb_time:
			_absorb()
			return
	elif _age >= absorb_time:
		_finish()


func _process_fragment(delta: float) -> void:
	if _target == null or not is_instance_valid(_target) or _target.is_dead:
		var found := get_tree().get_first_node_in_group(&"player") as Player
		_target = found if found != null and not found.is_dead else null
	if _age < _config.fragment_float_seconds:
		# It floats up and slows down, swaying a little.
		_velocity.y = move_toward(_velocity.y, 0.0, _config.fragment_rise_speed * 2.0 * delta)
		global_position += _velocity * delta
	elif _target != null:
		var destination: Vector2 = _target.global_position + Vector2(0.0, -16.0)
		var homing_age: float = _age - _config.fragment_float_seconds
		global_position = global_position.move_toward(destination, (_config.fragment_homing_speed + _config.fragment_homing_accel * homing_age) * delta)
		if global_position.distance_to(destination) < 16.0:
			_absorb()
			return
	if _age >= _config.fragment_float_seconds + _config.fragment_max_wait and _target == null:
		# Nobody alive to take it: it fades (the soul meter resets on respawn anyway).
		_finish()
		return
	if not _reduced:
		_trail.push_front(global_position)
		if _trail.size() > _config.fragment_trail_points:
			_trail.pop_back()


func _absorb() -> void:
	var soul: SoulComponent = _target.get_node_or_null(^"Soul") as SoulComponent
	if soul != null and amount > 0:
		soul.add_soul(amount)
	_finish()


func _finish() -> void:
	_done = true
	queue_free()


func _draw() -> void:
	if style == Style.WISP:
		return
	var scale_k: float = _config.fragment_small_scale if style == Style.SMALL else 1.0
	var color: Color = _config.fragment_color
	var fade_in: float = clampf(_age / 0.15, 0.0, 1.0)
	# The trail: older points are smaller and fainter.
	for i in _trail.size():
		var k: float = 1.0 - float(i) / float(maxi(_trail.size(), 1))
		draw_circle(to_local(_trail[i]), (4.0 * k + 1.0) * scale_k, Color(color, 0.35 * k * fade_in))
	# The glow and the shard: a small blue crystal, long point up, with a white core.
	draw_circle(Vector2.ZERO, 11.0 * scale_k, Color(color, 0.18 * fade_in))
	draw_circle(Vector2.ZERO, 7.0 * scale_k, Color(color, 0.3 * fade_in))
	var s: float = 7.5 * scale_k
	var shard := PackedVector2Array([Vector2(0, -s * 1.4), Vector2(s * 0.55, -s * 0.1), Vector2(0, s * 0.8), Vector2(-s * 0.55, -s * 0.1)])
	draw_colored_polygon(shard, Color(color.lerp(Color.WHITE, 0.15), fade_in))
	draw_polyline(shard + PackedVector2Array([shard[0]]), Color(0.04, 0.14, 0.42, fade_in), 1.4, true)
	draw_line(Vector2(0, -s * 1.1), Vector2(0, s * 0.3), Color(1, 1, 1, 0.85 * fade_in), 1.4, true)
