class_name Player
extends CharacterBody2D
## Side-view platformer player: run, variable-height jump and dash.
## Movement values come from `stats`; visuals live under the `Visual` node.

signal state_changed(old_state: State, new_state: State)
signal dash_started
signal dash_finished

enum State { IDLE, RUN, JUMP, FALL, DASH }

@export var stats: PlayerStats = preload("res://backend/player/default_player_stats.tres")

## Horizontal facing, 1 (right) or -1 (left). Flips the Visual node.
var facing_direction: int = 1:
	set(value):
		facing_direction = 1 if value >= 0 else -1
		if visual:
			visual.scale.x = float(facing_direction)

var state: State = State.IDLE
var air_dashes_left: int = 0

## True only during the first `dash_invulnerability_time` seconds of a dash.
var is_dash_invulnerable: bool:
	get:
		return state == State.DASH and _dash_elapsed < stats.dash_invulnerability_time

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_elapsed: float = 0.0
var _dash_direction: int = 1

@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	air_dashes_left = stats.max_air_dashes
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = stats.camera_smoothing_speed
	facing_direction = facing_direction


## Later phases can extend this to block input (dead, stunned, etc.).
func can_act() -> bool:
	return true


func _physics_process(delta: float) -> void:
	_update_timers(delta)

	var input_dir: float = 0.0
	if can_act():
		input_dir = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			_jump_buffer_left = stats.jump_buffer_time
		if Input.is_action_just_pressed("dash") and _can_dash():
			_start_dash(input_dir)

	if state == State.DASH and _dash_elapsed >= stats.dash_duration:
		_end_dash()

	if state == State.DASH:
		_dash_step(delta)
	else:
		_move_step(input_dir, delta)

	move_and_slide()

	if state != State.DASH:
		_set_state(_locomotion_state())


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_left = stats.coyote_time
		air_dashes_left = stats.max_air_dashes
	else:
		_coyote_left -= delta
	_jump_buffer_left -= delta
	_dash_cooldown_left -= delta


func _move_step(input_dir: float, delta: float) -> void:
	var on_floor: bool = is_on_floor()

	if not on_floor:
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)

	var accel: float = stats.acceleration if on_floor else stats.air_acceleration
	var fric: float = stats.friction if on_floor else stats.air_friction
	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * stats.max_speed, accel * delta)
		facing_direction = 1 if input_dir > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = stats.jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= stats.jump_cut_multiplier


func _can_dash() -> bool:
	if state == State.DASH or _dash_cooldown_left > 0.0:
		return false
	return is_on_floor() or air_dashes_left > 0


func _start_dash(input_dir: float) -> void:
	if input_dir != 0.0:
		facing_direction = 1 if input_dir > 0.0 else -1
	_dash_direction = facing_direction
	if not is_on_floor():
		air_dashes_left -= 1
	_dash_elapsed = 0.0
	_jump_buffer_left = 0.0
	_set_state(State.DASH)
	dash_started.emit()


func _dash_step(delta: float) -> void:
	velocity.x = _dash_direction * stats.dash_speed
	if stats.dash_disables_gravity:
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
	_dash_elapsed += delta


func _end_dash() -> void:
	_dash_cooldown_left = stats.dash_cooldown
	velocity.x = clampf(velocity.x, -stats.max_speed, stats.max_speed)
	_set_state(_locomotion_state())
	dash_finished.emit()


func _locomotion_state() -> State:
	if is_on_floor():
		return State.IDLE if is_zero_approx(velocity.x) else State.RUN
	return State.JUMP if velocity.y < 0.0 else State.FALL


## Single place where the state changes.
func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old_state: State = state
	state = new_state
	state_changed.emit(old_state, new_state)
