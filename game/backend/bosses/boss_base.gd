class_name BossBase
extends CharacterBody2D
## Reusable boss: an encounter state machine, weighted pattern selection, two phases and
## "armor" (damage never interrupts a pattern). Built from the shared combat components;
## it does not extend EnemyBase.
##
## To add a boss: inherit boss_base.tscn, assign a BossStats resource and put BossPattern
## nodes under `Patterns` (hitboxes go under `AttackPivot`). No code changes are needed.

signal activated
signal encounter_reset
signal health_changed(current: int, maximum: int)
signal phase_changed(phase: int)
signal pattern_started(pattern_id: StringName)
signal pattern_finished(pattern_id: StringName)
signal pattern_cancelled(pattern_id: StringName)
signal pattern_phase_changed(pattern_id: StringName, phase_name: StringName)
signal defeated(boss: BossBase)
signal state_changed(old_state: State, new_state: State)

enum State { INACTIVE, IDLE, PATTERN, PHASE_TRANSITION, DEAD }

@export var stats: BossStats
## 0 seeds the pattern selection randomly. Any other value makes it deterministic.
@export var rng_seed: int = 0

var state: State = State.INACTIVE
var current_phase: int = 1
var target: Node2D = null
var current_pattern: BossPattern = null
var speed_multiplier: float = 1.0
var patterns: Array[BossPattern] = []
## Horizontal facing, 1 (right) or -1 (left). Flips Visual, attack pivot and rays.
var facing_direction: int = 1:
	set(value):
		facing_direction = 1 if value >= 0 else -1
		_apply_facing()
var current_pattern_id: StringName:
	get:
		return current_pattern.pattern_id if current_pattern else &""

var _rng := RandomNumberGenerator.new()
var _previous_pattern: BossPattern = null
var _gap_left: float = 0.0
var _transition_left: float = 0.0
var _fade_left: float = 0.0
var _phase_2_started: bool = false
var _spawn_position: Vector2 = Vector2.ZERO
var _ledge_origin: Vector2 = Vector2.ZERO
var _wall_target: Vector2 = Vector2.ZERO

@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Node2D = $Visual
@onready var attack_pivot: Node2D = $AttackPivot
@onready var patterns_root: Node = $Patterns
@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var wall_check: RayCast2D = $WallCheck


func _ready() -> void:
	if stats == null:
		stats = BossStats.new()
	set_rng_seed(rng_seed)
	_spawn_position = global_position

	health.max_health = stats.max_health
	health.invulnerability_time = 0.0
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_health_died)
	health.health_changed.connect(func(current: int, maximum: int) -> void: health_changed.emit(current, maximum))

	for child in attack_pivot.get_children():
		if child is Hitbox:
			(child as Hitbox).owner_body = self
	_ledge_origin = ledge_check.position
	_wall_target = wall_check.target_position
	_apply_facing()
	refresh_patterns()


## Seed 0 randomizes; any other value makes pattern choice deterministic.
func set_rng_seed(new_seed: int) -> void:
	if new_seed == 0:
		_rng.randomize()
	else:
		_rng.seed = new_seed


## Re-reads the BossPattern children of `Patterns` (call after adding or removing patterns).
func refresh_patterns() -> void:
	for pattern in patterns:
		if is_instance_valid(pattern):
			if pattern.started.is_connected(_on_pattern_started.bind(pattern)):
				pattern.started.disconnect(_on_pattern_started.bind(pattern))
			if pattern.phase_changed.is_connected(_on_pattern_phase_changed.bind(pattern)):
				pattern.phase_changed.disconnect(_on_pattern_phase_changed.bind(pattern))
	patterns.clear()
	for child in patterns_root.get_children():
		if child is BossPattern:
			var pattern := child as BossPattern
			patterns.append(pattern)
			pattern.started.connect(_on_pattern_started.bind(pattern))
			pattern.phase_changed.connect(_on_pattern_phase_changed.bind(pattern))


## Starts the encounter against `new_target` (INACTIVE -> IDLE).
func activate(new_target: Node2D) -> void:
	if state != State.INACTIVE:
		return
	target = new_target
	_gap_left = _gap_time()
	_set_state(State.IDLE)
	activated.emit()


## Returns the boss to its initial INACTIVE state. A defeated boss stays defeated.
func reset_encounter() -> void:
	if state == State.DEAD:
		return
	_cancel_current_pattern()
	_deactivate_all_hitboxes()
	for pattern in patterns:
		pattern.cooldown_left = 0.0
	health.reset()
	current_phase = 1
	speed_multiplier = 1.0
	_phase_2_started = false
	_previous_pattern = null
	target = null
	velocity = Vector2.ZERO
	global_position = _spawn_position
	_set_state(State.INACTIVE)
	encounter_reset.emit()


func is_target_valid() -> bool:
	return target != null and is_instance_valid(target) and target.get("is_dead") != true


func distance_to_target() -> float:
	return global_position.distance_to(target.global_position) if is_target_valid() else INF


func face_towards(world_x: float) -> void:
	if world_x > global_position.x:
		facing_direction = 1
	elif world_x < global_position.x:
		facing_direction = -1


func is_wall_ahead() -> bool:
	return wall_check.is_colliding()


func is_ledge_ahead() -> bool:
	return is_on_floor() and not ledge_check.is_colliding()


func _physics_process(delta: float) -> void:
	match state:
		State.INACTIVE:
			velocity.x = 0.0
		State.IDLE:
			_update_idle(delta)
		State.PATTERN:
			_update_pattern(delta)
		State.PHASE_TRANSITION:
			_update_transition(delta)
		State.DEAD:
			_update_dead(delta)

	if not is_on_floor():
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
	move_and_slide()


func _update_idle(delta: float) -> void:
	velocity.x = 0.0
	_tick_cooldowns(delta)
	if not is_target_valid():
		return
	face_towards(target.global_position.x)
	_gap_left -= delta
	if _gap_left > 0.0:
		return
	var chosen: BossPattern = _choose_pattern()
	if chosen != null:
		_start_pattern(chosen)


func _update_pattern(delta: float) -> void:
	_tick_cooldowns(delta)
	if not is_target_valid():
		_cancel_current_pattern()
		_enter_idle()
		return
	current_pattern.physics_update(self, delta)
	if current_pattern.is_finished():
		var finished_id: StringName = current_pattern.pattern_id
		_previous_pattern = current_pattern
		current_pattern = null
		_enter_idle()
		pattern_finished.emit(finished_id)


func _update_transition(delta: float) -> void:
	velocity.x = 0.0
	_tick_cooldowns(delta)
	_transition_left -= delta
	if _transition_left <= 0.0:
		current_phase = 2
		speed_multiplier = stats.phase_2_speed_multiplier
		phase_changed.emit(2)
		_enter_idle()


func _update_dead(delta: float) -> void:
	velocity.x = 0.0
	_fade_left -= delta
	if _fade_left <= 0.0:
		queue_free()


func _enter_idle() -> void:
	_gap_left = _gap_time()
	_set_state(State.IDLE)


func _gap_time() -> float:
	var gap: float = stats.pattern_gap_time
	if current_phase >= 2:
		gap *= stats.phase_2_pattern_gap_multiplier
	return gap


func _tick_cooldowns(delta: float) -> void:
	for pattern in patterns:
		pattern.tick_cooldown(delta)


## Weighted choice among valid patterns; avoids repeating the last one when possible.
func _choose_pattern() -> BossPattern:
	var candidates: Array[BossPattern] = []
	for pattern in patterns:
		if pattern.can_start(self):
			candidates.append(pattern)
	if stats.avoid_immediate_repeat and candidates.size() > 1:
		candidates.erase(_previous_pattern)
	if candidates.is_empty():
		return null
	var total: float = 0.0
	for pattern in candidates:
		total += pattern.weight
	if total <= 0.0:
		return candidates[0]
	var roll: float = _rng.randf() * total
	for pattern in candidates:
		roll -= pattern.weight
		if roll <= 0.0:
			return pattern
	return candidates[candidates.size() - 1]


func _start_pattern(pattern: BossPattern) -> void:
	current_pattern = pattern
	_set_state(State.PATTERN)
	pattern.start(self)


func _cancel_current_pattern() -> void:
	if current_pattern != null:
		var cancelled_id: StringName = current_pattern.pattern_id
		current_pattern.cancel(self)
		_previous_pattern = current_pattern
		current_pattern = null
		pattern_cancelled.emit(cancelled_id)
	velocity.x = 0.0


## Every hitbox under the attack pivot, whichever pattern owns it.
func _deactivate_all_hitboxes() -> void:
	for child in attack_pivot.get_children():
		if child is Hitbox:
			(child as Hitbox).deactivate()


func _on_pattern_started(pattern: BossPattern) -> void:
	pattern_started.emit(pattern.pattern_id)


func _on_pattern_phase_changed(phase_name: StringName, pattern: BossPattern) -> void:
	pattern_phase_changed.emit(pattern.pattern_id, phase_name)


## Armor: damage never interrupts a pattern. It only can trigger the phase change.
func _on_damaged(_info: DamageInfo) -> void:
	if current_phase != 1 or _phase_2_started or health.current_health <= 0:
		return
	if state != State.IDLE and state != State.PATTERN:
		return
	if health.current_health > health.max_health * stats.phase_2_health_ratio:
		return
	_phase_2_started = true
	_cancel_current_pattern()
	_deactivate_all_hitboxes()
	_transition_left = stats.phase_transition_time
	health.grant_invulnerability(stats.phase_transition_time)
	_set_state(State.PHASE_TRANSITION)


func _on_health_died() -> void:
	_cancel_current_pattern()
	_deactivate_all_hitboxes()
	hurtbox.set_enabled(false)
	velocity.x = 0.0
	_fade_left = stats.death_fade_time
	_set_state(State.DEAD)
	defeated.emit(self)


## Single place where the state changes.
func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old_state: State = state
	state = new_state
	state_changed.emit(old_state, new_state)


func _apply_facing() -> void:
	if visual == null:
		return
	visual.scale.x = float(facing_direction)
	attack_pivot.scale.x = float(facing_direction)
	ledge_check.position.x = absf(_ledge_origin.x) * facing_direction
	wall_check.target_position.x = absf(_wall_target.x) * facing_direction
	ledge_check.force_raycast_update()
	wall_check.force_raycast_update()