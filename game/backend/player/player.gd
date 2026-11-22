class_name Player
extends CharacterBody2D
## Side-view platformer player: run, variable-height jump, dash, sword, damage and respawn.
## Movement values come from `stats`; visuals live under the `Visual` node.

signal state_changed(old_state: State, new_state: State)
signal dash_started
signal dash_finished
signal attack_started
signal attack_finished
signal heavy_attack_started
signal dash_slash_started
## Emitted when the sword wave projectile is spawned (end of the cast startup).
signal wave_cast(tier: int)
signal died
signal respawned
## The heal action started a focus (held); it was cancelled (released, hit, dash, left the floor...);
## it finished and `healed` hearts came back (0 in the tutorial practice at full health).
## An extra jump in the air was made (Phase 15c).
signal double_jumped
## A bounce pad launched the player (Phase 15c).
signal launched
signal focus_started
signal focus_cancelled
signal focus_completed(healed: int)

enum State { IDLE, RUN, JUMP, FALL, DASH, HURT, ATTACK, DEAD, WAVE, HEAVY, FOCUS }
enum AttackPhase { STARTUP, ACTIVE, RECOVERY }
enum WavePhase { STARTUP, RECOVERY }
enum HeavyPhase { STARTUP, ACTIVE, RECOVERY }
## Which sword move currently owns the shared attack hitbox (read by the Visual).
enum SwordKind { LIGHT, HEAVY, DASH_SLASH }

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
var current_sword_kind: SwordKind = SwordKind.LIGHT
var air_dashes_left: int = 0
var is_dead: bool = false
## The tutorial lets the focus finish at full health (it spends the soul and heals nothing).
var focus_practice: bool = false
## Extra jumps left in this airtime (see PlayerStats.max_air_jumps).
var air_jumps_left: int = 0
## Set by the boss intro while the guardian and the duck talk: nothing can hurt the player (KillZones still can).
var story_invulnerable: bool = false

## True from the first to the last frame of the dash (the window ends exactly when the dash state ends, so it is
## `dash_duration` long), plus the optional `dash_invulnerability_grace`. KillZones ignore it (they kill through
## HealthComponent.kill).
var is_dash_invulnerable: bool:
	get:
		return state == State.DASH or _dash_grace_left > 0.0

var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_grace_left: float = 0.0
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
var _wave_phase: WavePhase = WavePhase.STARTUP
var _wave_time_left: float = 0.0
var _wave_buffer_left: float = 0.0
var _heavy_phase: HeavyPhase = HeavyPhase.STARTUP
var _heavy_time_left: float = 0.0
var _heavy_cooldown_left: float = 0.0
var _heavy_buffer_left: float = 0.0
var _dash_slash_buffer_left: float = 0.0
var _dash_slashing: bool = false
var _dash_slash_used: bool = false
var _dash_slash_extra_left: float = 0.0
var _slash_lock_left: float = 0.0
var _sword_shape_node: CollisionShape2D
var _sword_base_size: Vector2 = Vector2.ZERO
var _sword_base_position: Vector2 = Vector2.ZERO
var _input_locked: bool = false
var _focus_left: float = 0.0
var _launched: bool = false
var _auto_respawn_override: bool = false

@onready var visual: Node2D = $Visual
@onready var camera: Camera2D = $Camera2D
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: Hitbox = $AttackPivot/Hitbox
## Optional: without a SwordWaveCaster child the player simply has no wave.
@onready var wave_caster: SwordWaveCaster = get_node_or_null("SwordWaveCaster") as SwordWaveCaster
## The Soul meter (optional: without it the player cannot heal).
@onready var soul: SoulComponent = get_node_or_null("Soul") as SoulComponent


func _ready() -> void:
	add_to_group(&"player")
	air_dashes_left = stats.max_air_dashes
	air_jumps_left = stats.max_air_jumps
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = stats.camera_smoothing_speed
	facing_direction = facing_direction
	_respawn_point = global_position

	# Unique sword shape per player: the heavy attack and dash slash widen it, never the shared resource.
	_sword_shape_node = attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	var unique_shape := (_sword_shape_node.shape as RectangleShape2D).duplicate() as RectangleShape2D
	_sword_shape_node.shape = unique_shape
	_sword_base_size = unique_shape.size
	_sword_base_position = _sword_shape_node.position
	_set_sword_profile(SwordKind.LIGHT)

	health.max_health = get_max_health_for_souls(GameState.souls_released)
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
		_wave_buffer_left = 0.0
		_heavy_buffer_left = 0.0
		_dash_slash_buffer_left = 0.0


func is_input_locked() -> bool:
	return _input_locked


## The double jump is unlocked by boss 2's decision: GameState.decisions has 2 or more entries. Derived from the
## decisions (which the save already holds), so no save key and it survives "Continuar".
func has_double_jump() -> bool:
	return GameState.decisions.size() >= stats.double_jump_unlock_decisions


## A bounce pad launches the player straight up (velocity.y = `launch_velocity`, negative is up). The jump cut does
## not apply to it, the extra jump is available again and a focus in progress is cancelled. Returns false (and
## does nothing) when the player cannot be launched now (dead, or in the middle of a dash).
func launch_up(launch_velocity: float) -> bool:
	if is_dead or state == State.DASH:
		return false
	_cancel_focus()
	velocity.y = launch_velocity
	_launched = true
	_coyote_left = 0.0
	_jump_buffer_left = 0.0
	air_jumps_left = stats.max_air_jumps
	launched.emit()
	return true


## Used by the Hurtbox: dash, post-hit and story (boss intro) invulnerability all ignore hits.
func is_invulnerable() -> bool:
	return is_dash_invulnerable or story_invulnerable or health.is_invulnerable()


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


## Base maximum health plus the reward for the souls released so far (see PlayerStats).
func get_max_health_for_souls(released: int) -> int:
	var counted: int = clampi(released, 0, stats.released_souls_cap)
	return stats.max_health + counted * stats.health_per_released_soul


## Restores health and control at the respawn point, with brief invulnerability.
func respawn() -> void:
	global_position = _respawn_point
	velocity = Vector2.ZERO
	health.max_health = get_max_health_for_souls(GameState.souls_released)
	_restore()
	health.grant_invulnerability(stats.respawn_invulnerability_time)
	respawned.emit()


func _restore() -> void:
	is_dead = false
	_respawn_left = 0.0
	_hurt_left = 0.0
	_dash_cooldown_left = 0.0
	_dash_grace_left = 0.0
	_jump_buffer_left = 0.0
	_attack_cooldown_left = 0.0
	_attack_buffer_left = 0.0
	_wave_buffer_left = 0.0
	_heavy_buffer_left = 0.0
	_heavy_cooldown_left = 0.0
	_dash_slash_buffer_left = 0.0
	_slash_lock_left = 0.0
	_cancel_attack()
	_cancel_wave()
	_cancel_focus()
	if wave_caster != null:
		wave_caster.reset()
	if soul != null:
		soul.reset()
	health.reset()
	hurtbox.set_enabled(true)
	_set_state(_locomotion_state())


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	# Focusing needs a free player on the floor: a lock (cutscene), a fall or a hit ends it.
	if state == State.FOCUS and (not can_act() or not is_on_floor()):
		_cancel_focus()

	if state == State.HURT:
		_hurt_left -= delta
		if _hurt_left <= 0.0:
			_set_state(_locomotion_state())
	elif state == State.DEAD and is_auto_respawn_enabled():
		_respawn_left -= delta
		if _respawn_left <= 0.0:
			respawn()

	var input_dir: float = 0.0
	if state == State.FOCUS:
		_update_focus(delta)
	elif can_act():
		input_dir = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			_jump_buffer_left = stats.jump_buffer_time
		if Input.is_action_just_pressed("attack"):
			# At least one physics frame, otherwise a buffer of 0 would never start the attack.
			_attack_buffer_left = maxf(stats.attack_input_buffer_time, 1.0 / Engine.physics_ticks_per_second)
			_dash_slash_buffer_left = maxf(stats.dash_slash_input_buffer_time, 1.0 / Engine.physics_ticks_per_second)
		var heavy_pressed: bool = Input.is_action_just_pressed("heavy_attack")
		if heavy_pressed:
			_heavy_buffer_left = maxf(stats.heavy_input_buffer_time, 1.0 / Engine.physics_ticks_per_second)
		if Input.is_action_just_pressed("dash") and _can_dash():
			_start_dash(input_dir)
		if _dash_slash_buffer_left > 0.0 and state == State.DASH and not _dash_slash_used:
			_start_dash_slash()
		var wave_pressed: bool = wave_caster != null and Input.is_action_just_pressed("wave")
		if wave_pressed:
			_wave_buffer_left = maxf(wave_caster.config.input_buffer_time, 1.0 / Engine.physics_ticks_per_second)
		if _attack_buffer_left > 0.0 and _can_attack():
			_start_attack()
			# Sword and wave on the same frame: the sword wins.
			if wave_pressed:
				_wave_buffer_left = 0.0
			if heavy_pressed:
				_heavy_buffer_left = 0.0
		if _wave_buffer_left > 0.0 and _can_wave():
			_start_wave()
		if _heavy_buffer_left > 0.0 and _can_heavy():
			_start_heavy()
		# Last, so any other action pressed this frame wins and the focus never starts on top of it.
		if Input.is_action_just_pressed("heal"):
			_try_start_focus()

	if state == State.DASH and _dash_elapsed >= stats.dash_duration:
		_end_dash()
	if state == State.ATTACK:
		_advance_attack(delta)
	if state == State.WAVE:
		_advance_wave(delta)
	if state == State.HEAVY:
		_advance_heavy(delta)

	if state == State.DASH:
		_dash_step(delta)
	else:
		_move_step(input_dir, delta)

	move_and_slide()

	if state != State.DASH and state != State.HURT and state != State.ATTACK and state != State.DEAD and state != State.WAVE and state != State.HEAVY and state != State.FOCUS:
		_set_state(_locomotion_state())


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_left = stats.coyote_time
		air_dashes_left = stats.max_air_dashes
		air_jumps_left = stats.max_air_jumps
	else:
		_coyote_left -= delta
	# A bounce launch protects its upward speed from the jump cut until the player starts to fall.
	if velocity.y >= 0.0:
		_launched = false
	_jump_buffer_left -= delta
	_dash_cooldown_left -= delta
	_dash_grace_left = maxf(_dash_grace_left - delta, 0.0)
	_attack_cooldown_left -= delta
	_attack_buffer_left -= delta
	_wave_buffer_left -= delta
	_heavy_buffer_left -= delta
	_heavy_cooldown_left -= delta
	_dash_slash_buffer_left -= delta
	_slash_lock_left -= delta
	if _dash_slash_extra_left > 0.0:
		_dash_slash_extra_left -= delta
		if _dash_slash_extra_left <= 0.0:
			_finish_dash_slash_hitbox()


func _move_step(input_dir: float, delta: float) -> void:
	var on_floor: bool = is_on_floor()
	var attacking: bool = state == State.ATTACK
	var casting: bool = state == State.WAVE
	var heavy: bool = state == State.HEAVY

	if not on_floor:
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)

	var target_speed: float = stats.max_speed
	if attacking:
		target_speed *= stats.attack_move_speed_multiplier
	elif casting and wave_caster != null:
		target_speed *= wave_caster.config.horizontal_speed_multiplier
	elif heavy:
		target_speed *= stats.heavy_move_speed_multiplier
	var accel: float = stats.acceleration if on_floor else stats.air_acceleration
	var fric: float = stats.friction if on_floor else stats.air_friction
	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * target_speed, accel * delta)
		if not attacking and not casting and not heavy:
			facing_direction = 1 if input_dir > 0.0 else -1
	else:
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)

	if _jump_buffer_left > 0.0 and _coyote_left > 0.0 and can_act() and not attacking and not heavy:
		velocity.y = stats.jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
	elif _jump_buffer_left > 0.0 and not on_floor and air_jumps_left > 0 and has_double_jump() and can_act() and not attacking and not heavy:
		# The extra jump (Phase 15c): once per airtime, never spent by a dash.
		velocity.y = stats.double_jump_velocity
		air_jumps_left -= 1
		_jump_buffer_left = 0.0
		_launched = false
		double_jumped.emit()

	if can_act() and Input.is_action_just_released("jump") and velocity.y < 0.0 and not _launched:
		velocity.y *= stats.jump_cut_multiplier


func _can_dash() -> bool:
	if state == State.DASH or state == State.ATTACK or state == State.HEAVY or _dash_cooldown_left > 0.0:
		return false
	return is_on_floor() or air_dashes_left > 0


func _start_dash(input_dir: float) -> void:
	_cancel_wave()
	if input_dir != 0.0:
		facing_direction = 1 if input_dir > 0.0 else -1
	_dash_direction = facing_direction
	if not is_on_floor():
		air_dashes_left -= 1
	_dash_elapsed = 0.0
	_dash_slashing = false
	_dash_slash_used = false
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
	if _dash_slashing:
		_dash_slashing = false
		_dash_slash_extra_left = stats.dash_slash_extra_active_time
		_slash_lock_left = stats.dash_slash_extra_active_time + stats.dash_slash_extra_recovery_time
		if _dash_slash_extra_left <= 0.0:
			_finish_dash_slash_hitbox()
	_dash_cooldown_left = stats.dash_cooldown
	_dash_grace_left = stats.dash_invulnerability_grace
	velocity.x = clampf(velocity.x, -stats.max_speed, stats.max_speed)
	_set_state(_locomotion_state())
	dash_finished.emit()


func _can_attack() -> bool:
	if _attack_cooldown_left > 0.0 or _slash_busy():
		return false
	if state == State.DASH or state == State.ATTACK or state == State.HEAVY or state == State.HURT or state == State.DEAD:
		return false
	return is_on_floor() or stats.can_attack_in_air


func _start_attack() -> void:
	_cancel_wave()
	_attack_buffer_left = 0.0
	_attack_phase = AttackPhase.STARTUP
	_attack_time_left = stats.attack_startup_time
	_set_sword_profile(SwordKind.LIGHT)
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
	_cancel_heavy()
	_cancel_dash_slash()
	attack_hitbox.deactivate()
	_attack_time_left = 0.0
	if state == State.ATTACK:
		_attack_cooldown_left = stats.attack_cooldown
		_set_state(_locomotion_state())
		attack_finished.emit()


## Wave: input is accepted when the caster is ready and no other action owns the player.
func _can_wave() -> bool:
	if wave_caster == null or not wave_caster.can_cast():
		return false
	if state == State.DASH or state == State.ATTACK or state == State.HEAVY or state == State.HURT or state == State.DEAD or state == State.WAVE:
		return false
	return is_on_floor() or wave_caster.config.can_cast_in_air


func _start_wave() -> void:
	_wave_buffer_left = 0.0
	_wave_phase = WavePhase.STARTUP
	_wave_time_left = wave_caster.config.startup_time
	_set_state(State.WAVE)


## Startup -> spawn exactly one projectile -> recovery, with physics time (no awaits).
func _advance_wave(delta: float) -> void:
	_wave_time_left -= delta
	while _wave_time_left <= 0.0 and state == State.WAVE:
		match _wave_phase:
			WavePhase.STARTUP:
				_wave_phase = WavePhase.RECOVERY
				_wave_time_left += wave_caster.config.recovery_time
				var tier: int = wave_caster.get_effective_tier()
				if wave_caster.fire(self, facing_direction) != null:
					wave_cast.emit(tier)
			WavePhase.RECOVERY:
				_wave_time_left = 0.0
				_set_state(_locomotion_state())


## Stops a cast. During startup nothing was spawned and no cooldown was consumed; an already
## spawned wave is never touched.
func _cancel_wave() -> void:
	_wave_time_left = 0.0
	if state == State.WAVE:
		_set_state(_locomotion_state())


func _on_damaged(info: DamageInfo) -> void:
	if state == State.DASH:
		_end_dash()
	_cancel_focus()
	_cancel_attack()
	_cancel_wave()
	_jump_buffer_left = 0.0
	_attack_buffer_left = 0.0
	_hurt_left = stats.hurt_stun_time
	velocity = info.knockback
	_set_state(State.HURT)


func _on_died() -> void:
	is_dead = true
	_cancel_focus()
	_cancel_attack()
	_cancel_wave()
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


# --- Sword moves: heavy slash and dash slash (variants of the light attack's shared hitbox) ---

## Applies damage, knockback and hitbox width of a sword move. The near edge of the hitbox stays put.
func _set_sword_profile(kind: SwordKind) -> void:
	var width_multiplier: float = 1.0
	match kind:
		SwordKind.LIGHT:
			attack_hitbox.damage = stats.attack_damage
			attack_hitbox.knockback = stats.attack_knockback
		SwordKind.HEAVY:
			attack_hitbox.damage = stats.heavy_damage
			attack_hitbox.knockback = stats.heavy_knockback
			width_multiplier = stats.heavy_width_multiplier
		SwordKind.DASH_SLASH:
			attack_hitbox.damage = stats.dash_slash_damage
			attack_hitbox.knockback = stats.dash_slash_knockback
			width_multiplier = stats.dash_slash_width_multiplier
	var rect := _sword_shape_node.shape as RectangleShape2D
	rect.size = Vector2(_sword_base_size.x * width_multiplier, _sword_base_size.y)
	var near_edge: float = _sword_base_position.x - _sword_base_size.x * 0.5
	_sword_shape_node.position = Vector2(near_edge + rect.size.x * 0.5, _sword_base_position.y)
	current_sword_kind = kind


## A slash (extra active time or recovery lock) still owns the shared hitbox / blocks new attacks.
func _slash_busy() -> bool:
	return _dash_slash_extra_left > 0.0 or _slash_lock_left > 0.0


func _can_heavy() -> bool:
	if _heavy_cooldown_left > 0.0 or _slash_busy():
		return false
	if state == State.DASH or state == State.ATTACK or state == State.HEAVY or state == State.HURT or state == State.DEAD or state == State.WAVE:
		return false
	return is_on_floor() or stats.heavy_can_use_in_air


func _start_heavy() -> void:
	_heavy_buffer_left = 0.0
	_heavy_phase = HeavyPhase.STARTUP
	_heavy_time_left = stats.heavy_startup_time
	_set_sword_profile(SwordKind.HEAVY)
	_set_state(State.HEAVY)
	heavy_attack_started.emit()


## Startup -> active (hitbox on once) -> recovery -> cooldown, with physics time (no awaits).
func _advance_heavy(delta: float) -> void:
	_heavy_time_left -= delta
	while _heavy_time_left <= 0.0 and state == State.HEAVY:
		match _heavy_phase:
			HeavyPhase.STARTUP:
				_heavy_phase = HeavyPhase.ACTIVE
				_heavy_time_left += stats.heavy_active_time
				attack_hitbox.activate()
			HeavyPhase.ACTIVE:
				_heavy_phase = HeavyPhase.RECOVERY
				_heavy_time_left += stats.heavy_recovery_time
				attack_hitbox.deactivate()
			HeavyPhase.RECOVERY:
				_heavy_time_left = 0.0
				attack_hitbox.deactivate()
				_heavy_cooldown_left = stats.heavy_cooldown
				_set_sword_profile(SwordKind.LIGHT)
				_set_state(_locomotion_state())


## Damage or death. A hit during STARTUP consumes no cooldown and deals no damage.
func _cancel_heavy() -> void:
	if state != State.HEAVY:
		return
	attack_hitbox.deactivate()
	if _heavy_phase != HeavyPhase.STARTUP:
		_heavy_cooldown_left = stats.heavy_cooldown
	_heavy_time_left = 0.0
	_set_sword_profile(SwordKind.LIGHT)
	_set_state(_locomotion_state())


## Attack pressed during the dash: the dash goes on and its remaining time carries the slash hitbox.
func _start_dash_slash() -> void:
	_dash_slash_buffer_left = 0.0
	_attack_buffer_left = 0.0
	_dash_slash_used = true
	_dash_slashing = true
	_set_sword_profile(SwordKind.DASH_SLASH)
	attack_hitbox.activate()
	dash_slash_started.emit()


func _finish_dash_slash_hitbox() -> void:
	_dash_slash_extra_left = 0.0
	attack_hitbox.deactivate()
	_set_sword_profile(SwordKind.LIGHT)


func _cancel_dash_slash() -> void:
	var was_active: bool = _dash_slashing or _dash_slash_extra_left > 0.0
	_dash_slashing = false
	_dash_slash_extra_left = 0.0
	_slash_lock_left = 0.0
	if was_active:
		attack_hitbox.deactivate()
		_set_sword_profile(SwordKind.LIGHT)


## True during the heavy attack's startup (the readable windup the Visual tints and squashes).
func is_heavy_windup() -> bool:
	return state == State.HEAVY and _heavy_phase == HeavyPhase.STARTUP


# --- Focus heal ---------------------------------------------------------------------------------

## 0..1 through the focus (0 when not focusing); the Visual draws the effect from it.
func get_focus_progress() -> float:
	if state != State.FOCUS or soul == null:
		return 0.0
	return clampf(1.0 - _focus_left / maxf(soul.config.focus_time, 0.01), 0.0, 1.0)


## Pressing the heal action: starts the focus when everything allows it; otherwise it only tells the
## Soul meter why not (full health or not enough soul), spending nothing.
func _try_start_focus() -> void:
	if soul == null or is_dead or not is_on_floor():
		return
	if state != State.IDLE and state != State.RUN:
		return
	if health.current_health >= health.max_health and not focus_practice:
		soul.deny(&"full_health")
		return
	if not soul.can_afford():
		soul.deny(&"not_enough_soul")
		return
	_jump_buffer_left = 0.0
	_focus_left = soul.config.focus_time
	_set_state(State.FOCUS)
	focus_started.emit()


## While focusing: releasing the action ends it, a dash cancels it (and dashes), time completes it.
func _update_focus(delta: float) -> void:
	if not Input.is_action_pressed("heal"):
		_cancel_focus()
		return
	if Input.is_action_just_pressed("dash"):
		_cancel_focus()
		if _can_dash():
			_start_dash(Input.get_axis("move_left", "move_right"))
		return
	_focus_left -= delta
	if _focus_left <= 0.0:
		_complete_focus()


func _complete_focus() -> void:
	_focus_left = 0.0
	if soul == null or not soul.spend(soul.heal_cost()):
		_cancel_focus()
		return
	var before: int = health.current_health
	health.heal(soul.config.heal_hearts)
	var healed: int = health.current_health - before
	_set_state(_locomotion_state())
	focus_completed.emit(healed)


## Ends a focus without healing and without spending anything.
func _cancel_focus() -> void:
	if state != State.FOCUS:
		return
	_focus_left = 0.0
	_set_state(_locomotion_state())
	focus_cancelled.emit()
