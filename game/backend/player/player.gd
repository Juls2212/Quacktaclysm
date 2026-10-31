class_name Player
extends CharacterBody2D
## Side-view platformer player: run, variable-height jump, dash, sword, damage and respawn.
## Movement values come from `stats`; visuals live under the `Visual` node.

signal state_changed(old_state: State, new_state: State)
signal dash_started
signal dash_finished
signal attack_started
signal attack_finished
signal died
signal respawned

enum State { IDLE, RUN, JUMP, FALL, DASH, HURT, ATTACK, DEAD }
enum AttackPhase { STARTUP, ACTIVE, RECOVERY }

@export var stats: PlayerStats = preload("res://backend/player/default_player_stats.tres")

## Horizontal facing, 1 (right) or -1 (left). Flips the Visual node and the attack pivot.
var facing_direction: int = 1:
	set(value):
		facing_direction = 1 if value >= 0 else -1
		if visual:
			visual.scale.x = float(facing_direction)
		if attack_pivot:
			attack_pivot.scale.x = float(facing_direction)

var state: State = State.IDLE
var air_dashes_left: int = 0
var is_dead: bool = false

## True only during the first `dash_invulnerability_time` seconds of a dash.
var is_dash_invulnerable: bool:
	get:
		return state == State.DASH and _dash_elapsed < stats.dash_invulnerability_time

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_elapsed: float = 0.0
var _dash_direction: int = 1
var _hurt_left: float = 0.0
var _attack_phase: AttackPhase = AttackPhase.STARTUP
var _attack_time_left: float = 0.0
var _attack_cooldown_left: float = 0.0
var _attack_buffer_left: float = 0.0
var _respawn_left: float = 0.0
var _respawn_point: Vector2 = Vector2.ZERO
var _auto_respawn_override_set: bool = false
var _input_locked: bool = false
var _auto_respawn_override: bool = false

@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: Hitbox = $AttackPivot/Hitbox


func _ready() -> void:
	air_dashes_left = stats.max_air_dashes
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = stats.camera_smoothing_speed
	facing_direction = facing_direction
	_respawn_point = global_position

	attack_hitbox.damage = stats.attack_damage
	attack_hitbox.knockback = stats.attack_knockback

	health.max_health = stats.max_health
	health.invulnerability_time = stats.hurt_invulnerability_time
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


## Later phases can extend this to block input (cutscenes, etc.).
func can_act() -> bool:
	return not is_dead and state != State.HURT and not _input_locked


## While locked, no input is processed (gravity and physics keep running). Set by levels
## (e.g. during scene fades); respawn() does not clear it.
func set_input_locked(value: bool) -> void:
	_input_locked = value
	if value:
		_jump_buffer_left = 0.0
		_attack_buffer_left = 0.0


func is_input_locked() -> bool:
	return _input_locked


## Used by the Hurtbox: dash and post-hit invulnerability both ignore hits.
func is_invulnerable() -> bool:
	return is_dash_invulnerable or health.is_invulnerable()


## Runtime override of `stats.auto_respawn` (e.g. a Game Over controller). Never mutates the
## shared PlayerStats resource; without a call the stats value applies.
func set_auto_respawn(value: bool) -> void:
	_auto_respawn_override_set = true
	_auto_respawn_override = value


func is_auto_respawn_enabled() -> bool:
	return _auto_respawn_override if _auto_respawn_override_set else stats.auto_respawn


func set_respawn_point(point: Vector2) -> void:
	_respawn_point = point


func get_respawn_point() -> Vector2:
	return _respawn_point


## Restores health and control where the player stands (debugging).
func revive() -> void:
	_restore()


## Restores health and control at the respawn point, with brief invulnerability.
func respawn() -> void:
	global_position = _respawn_point
	velocity = Vector2.ZERO
	_restore()
	health.grant_invulnerability(stats.respawn_invulnerability_time)
	respawned.emit()


func _restore() -> void:
	is_dead = false
	_respawn_left = 0.0
	_hurt_left = 0.0
	_dash_cooldown_left = 0.0
	_jump_buffer_left = 0.0
	_attack_cooldown_left = 0.0
	_attack_buffer_left = 0.0
	_cancel_attack()
	health.reset()
	hurtbox.set_enabled(true)
	_set_state(_locomotion_state())


func _physics_process(delta: float) -> void:
	_update_timers(delta)

	if state == State.HURT:
		_hurt_left -= delta
		if _hurt_left <= 0.0:
			_set_state(_locomotion_state())
	elif state == State.DEAD and is_auto_respawn_enabled():
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			respawn()

	var input_dir: float = 0.0
	if can_act():
		input_dir = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			_jump_buffer_left = stats.jump_buffer_time
		if Input.is_action_just_pressed("attack"):
			# At least one physics frame, otherwise a buffer of 0 would never start the attack.
			_attack_buffer_left = maxf(stats.attack_input_buffer_time, 1.0 / Engine.physics_ticks_per_second)
		if Input.is_action_just_pressed("dash") and _can_dash():
			_start_dash(input_dir)
		if _attack_buffer_left > 0.0 and _can_attack():
			_start_attack()

	if state == State.DASH and _dash_elapsed >= stats.dash_duration:
		_end_dash()
	if state == State.ATTACK:
		_advance_attack(delta)

	if state == State.DASH:
		_dash_step(delta)
	else:
		_move_step(input_dir, delta)

	move_and_slide()

	if state != State.DASH and state != State.HURT and state != State.ATTACK and state != State.DEAD:
		_set_state(_locomotion_state())


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_left = stats.coyote_time
		air_dashes_left = stats.max_air_dashes
	else:
		_coyote_left -= delta
	_jump_buffer_left -= delta
	_dash_cooldown_left -= delta
	_attack_cooldown_left -= delta
	_attack_buffer_left -= delta


func _move_step(input_dir: float, delta: float) -> void:
	var on_floor: bool = is_on_floor()
	var attacking: bool = state == State.ATTACK

	if not on_floor:
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)

	var target_speed: float = stats.max_speed
	if attacking:
		target_speed *= stats.attack_move_speed_multiplier
	var accel: float = stats.acceleration if on_floor else stats.air_acceleration
	var fric: float = stats.friction if on_floor else stats.air_friction
	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * target_speed, accel * delta)
		if not attacking:
			facing_direction = 1 if input_dir > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0 and can_act() and not attacking:
		velocity.y = stats.jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0

	if can_act() and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= stats.jump_cut_multiplier


func _can_dash() -> bool:
	if state == State.DASH or state == State.ATTACK or _dash_cooldown_left > 0.0:
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


func _can_attack() -> bool:
	if _attack_cooldown_left > 0.0:
		return false
	if state == State.DASH or state == State.ATTACK or state == State.HURT or state == State.DEAD:
		return false
	return is_on_floor() or stats.can_attack_in_air


func _start_attack() -> void:
	_attack_buffer_left = 0.0
	_attack_phase = AttackPhase.STARTUP
	_attack_time_left = stats.attack_startup_time
	_set_state(State.ATTACK)
	attack_started.emit()


## Advances startup -> active -> recovery using physics time (no awaits).
func _advance_attack(delta: float) -> void:
	_attack_time_left -= delta
	while _attack_time_left <= 0.0 and state == State.ATTACK:
		match _attack_phase:
			AttackPhase.STARTUP:
				_attack_phase = AttackPhase.ACTIVE
				_attack_time_left += stats.attack_active_time
				attack_hitbox.activate()
			AttackPhase.ACTIVE:
				_attack_phase = AttackPhase.RECOVERY
				_attack_time_left += stats.attack_recovery_time
				attack_hitbox.deactivate()
			AttackPhase.RECOVERY:
				_attack_time_left = 0.0
				_finish_attack()


func _finish_attack() -> void:
	attack_hitbox.deactivate()
	_attack_cooldown_left = stats.attack_cooldown
	_set_state(_locomotion_state())
	attack_finished.emit()


## Stops any swing immediately (hurt, death, respawn). Leaves no active hitbox.
func _cancel_attack() -> void:
	attack_hitbox.deactivate()
	_attack_time_left = 0.0
	if state == State.ATTACK:
		_attack_cooldown_left = stats.attack_cooldown
		_set_state(_locomotion_state())
		attack_finished.emit()


func _on_damaged(info: DamageInfo) -> void:
	if state == State.DASH:
		_end_dash()
	_cancel_attack()
	_jump_buffer_left = 0.0
	_attack_buffer_left = 0.0
	_hurt_left = stats.hurt_stun_time
	velocity = info.knockback
	_set_state(State.HURT)


func _on_died() -> void:
	is_dead = true
	_cancel_attack()
	hurtbox.set_enabled(false)
	_respawn_left = stats.respawn_delay
	_set_state(State.DEAD)
	died.emit()


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
