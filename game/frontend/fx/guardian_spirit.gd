class_name GuardianSpirit
extends Node2D
## The soul of a fallen guardian (Phase 15r): the SAME duck figure (its own rig: the axe of the woodcutter, the cattails and the lotus of the swamp, the
## blade of the storm) drawn in translucent blue where the guardian fell, with a soft glow, a gentle hover, wisps rising and a slow flicker. It speaks the
## last words of the guardian (the dialogue labels them with the name of the spirit) and afterwards DISSOLVES into particles that stream into the spot
## where the fragment appears (`target`); the fragment condenses there. It has no hitbox and no damage and reads nothing of the game: the dialogue tells
## it when to dissolve or to vanish (a skip goes straight to the crystal). Reduced mode ("Efectos de corrupción" off): a still figure and a plain
## fade, no flicker, no hover, no wisps, no particles. It never plays twice for the same defeat (the dialogue creates it once).

## The spirit has dissolved (or vanished): the fragment may appear now.
signal dissolved

enum State { RISING, HOLD, DISSOLVING, DONE }

var config: GuardianSpiritConfig = null
var look: DuckRig.Look = DuckRig.Look.BOSS_WOODCUTTER
var reduced: bool = false
var state: State = State.RISING
## Where the particles stream to (global position; the fragment appears there).
var target: Vector2 = Vector2.ZERO
var rig: DuckRig = null
## Opacity of the whole figure right now (0 to config.opacity).
var strength: float = 0.0
var particles: Array[Dictionary] = []

var _time: float = 0.0
var _state_time: float = 0.0
var _emit_left: float = 0.0
var _overlay: _Front = null
var _rig_scale: Vector2 = Vector2.ONE * DuckRig.BOSS_SCALE
var _done_emitted: bool = false
var _goal_local: Vector2 = Vector2.ZERO


class _Front extends Node2D:
	var spirit: GuardianSpirit = null

	func _draw() -> void:
		spirit._draw_front(self)


## Call before adding to the tree. `at` and `rig_scale` are those of the fallen guardian figure (global position and scale).
func setup(p_look: DuckRig.Look, at: Vector2, rig_scale: Vector2, p_reduced: bool, p_target: Vector2, p_config: GuardianSpiritConfig = null) -> void:
	look = p_look
	position = at
	_rig_scale = rig_scale
	reduced = p_reduced
	target = p_target
	config = p_config if p_config != null else GuardianSpiritConfig.get_default()


func _ready() -> void:
	if config == null:
		config = GuardianSpiritConfig.get_default()
	z_index = 8
	rig = DuckRig.new()
	rig.name = "Figure"
	rig.look = look
	rig.scale = _rig_scale
	rig.enraged = false
	rig.grounded = true
	rig.modulate = Color(config.tint, 0.0)
	add_child(rig)
	_overlay = _Front.new()
	_overlay.name = "Front"
	_overlay.spirit = self
	add_child(_overlay)


func _process(delta: float) -> void:
	_time += delta
	_state_time += delta
	match state:
		State.RISING:
			var k: float = clampf(_state_time / maxf(config.fade_in_seconds, 0.01), 0.0, 1.0)
			strength = config.opacity * k
			if k >= 1.0:
				_enter(State.HOLD)
		State.HOLD:
			strength = config.opacity
		State.DISSOLVING:
			_process_dissolve(delta)
	_apply()
	queue_redraw()
	if _overlay != null:
		_overlay.queue_redraw()


func _enter(next: State) -> void:
	state = next
	_state_time = 0.0


## The last words are over: the figure comes apart into particles that stream into the spot of the fragment.
func dissolve() -> void:
	if state == State.DISSOLVING or state == State.DONE:
		return
	_enter(State.DISSOLVING)
	_emit_left = 0.0
	particles.clear()


## A skip: the spirit is gone at once (the fragment may appear now).
func vanish_now() -> void:
	if state == State.DONE:
		return
	state = State.DONE
	strength = 0.0
	_finish()


func is_done() -> bool:
	return state == State.DONE


func _process_dissolve(delta: float) -> void:
	var total: float = config.reduced_fade_seconds if reduced else config.dissolve_seconds
	var k: float = clampf(_state_time / total, 0.0, 1.0)
	if reduced:
		strength = config.opacity * (1.0 - k)
	else:
		# The body goes first (the first 60%); the particles keep flowing until they have all arrived.
		strength = config.opacity * (1.0 - smoothstep(0.0, 0.6, k))
		_emit_particles(delta, k)
		_move_particles(delta)
	if k >= 1.0:
		state = State.DONE
		_finish()


func _emit_particles(delta: float, k: float) -> void:
	if k > 0.6:
		return
	_emit_left += delta * float(config.dissolve_particles) / (config.dissolve_seconds * 0.6)
	while _emit_left >= 1.0 and particles.size() < config.dissolve_particles * 2:
		_emit_left -= 1.0
		var half_w: float = 22.0 * _rig_scale.x
		var height: float = 54.0 * _rig_scale.y
		var start := Vector2(randf_range(-half_w, half_w), randf_range(-height, 0.0))
		var life: float = maxf(config.dissolve_seconds - _state_time - 0.1, 0.35)
		particles.append({"from": start, "t": 0.0, "life": life, "swirl": randf_range(-1.0, 1.0)})


func _move_particles(delta: float) -> void:
	_goal_local = to_local(target)
	for particle in particles:
		particle["t"] = minf(float(particle["t"]) + delta / float(particle["life"]), 1.0)


func _finish() -> void:
	if _done_emitted:
		return
	_done_emitted = true
	dissolved.emit()
	queue_free()


func _apply() -> void:
	if rig == null:
		return
	var flick: float = 1.0
	if not reduced:
		flick = 1.0 - config.flicker_amount * (0.5 + 0.5 * sin(_time * TAU * config.flicker_hz))
	rig.modulate = Color(config.tint, strength * flick)
	var rise: float = 0.0
	var hover: float = 0.0
	if not reduced:
		rise = config.rise_pixels * smoothstep(0.0, 1.0, clampf(_time / maxf(config.fade_in_seconds, 0.01), 0.0, 1.0))
		hover = sin(_time * TAU * config.hover_hz) * config.hover_amplitude
	rig.position = Vector2(0.0, -(rise + hover))


## The glow and the wisps are behind the figure.
func _draw() -> void:
	if config == null or strength <= 0.001:
		return
	var pulse: float = 1.0 if reduced else 0.9 + 0.1 * sin(_time * TAU * 0.4)
	var center := Vector2(0.0, -30.0 * _rig_scale.y)
	for step in range(10, 0, -1):
		var k: float = float(step) / 10.0
		draw_circle(center, config.glow_radius * (0.35 + 0.65 * k), Color(config.glow_color, strength * pulse * 0.075))
	if not reduced and state != State.DISSOLVING:
		for i in config.wisp_count:
			var phase: float = fposmod(_time * 0.25 + float(i) / float(maxi(config.wisp_count, 1)), 1.0)
			var x: float = (float(i % 5) - 2.0) * 7.0 * _rig_scale.x + sin(_time * 1.2 + float(i)) * 5.0
			var y: float = -phase * 70.0 * _rig_scale.y
			draw_circle(Vector2(x, y), 2.6 * (1.0 - phase) + 0.8, Color(config.glow_color, strength * (1.0 - phase) * 0.8))


## The recognizable detail and the particles are in front: the swamp lotus on its head, and the particles streaming to the fragment.
func _draw_front(c: Node2D) -> void:
	if config == null:
		return
	if look == DuckRig.Look.BOSS_SWAMP and strength > 0.001:
		_draw_lotus(c)
	for particle in particles:
		var t: float = float(particle["t"])
		var e: float = t * t * (3.0 - 2.0 * t)
		var from: Vector2 = particle["from"]
		var side: Vector2 = (_goal_local - from).orthogonal().normalized() * float(particle["swirl"]) * 30.0 * sin(t * PI)
		var at: Vector2 = from.lerp(_goal_local, e) + side
		var alpha: float = (1.0 - t * 0.4) * config.opacity * 1.4
		c.draw_circle(at, 7.0 * (1.0 - t * 0.5), Color(config.glow_color, alpha * 0.4))
		c.draw_circle(at, 3.2, Color(0.9, 0.97, 1.0, clampf(alpha, 0.0, 1.0)))


## A lotus flower over the swamp guardian head: the detail that tells it from the others (flat, in the same blue).
func _draw_lotus(c: Node2D) -> void:
	var base := Vector2(5.0 * _rig_scale.x, -50.0 * _rig_scale.y) + (rig.position if rig != null else Vector2.ZERO)
	var color := Color(0.75, 0.92, 1.0, clampf(strength * 1.2, 0.0, 1.0))
	var edge := Color(0.2, 0.35, 0.55, clampf(strength * 1.2, 0.0, 1.0))
	for angle in [-0.9, -0.45, 0.0, 0.45, 0.9]:
		var tip: Vector2 = base + Vector2(sin(angle) * 14.0, -cos(angle) * 20.0)
		var petal := PackedVector2Array([base + Vector2(-4.0, 0.0), tip, base + Vector2(4.0, 0.0)])
		c.draw_colored_polygon(petal, color)
		c.draw_polyline(petal, edge, 1.6, true)
	c.draw_circle(base + Vector2(0.0, -3.0), 3.0, Color(1.0, 0.95, 0.7, clampf(strength * 1.2, 0.0, 1.0)))
