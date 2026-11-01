class_name EnemyBase
extends CharacterBody2D
## Shared enemy behavior: gravity, patrol, target tracking, chase, a timed melee-style
## attack, hurt and death. All numbers come from `stats`.
##
## To add an enemy type, inherit enemy_base.tscn, extend this class and override only
## what differs. Virtual hooks (all optional):
##   _enter_state(new_state)   called when the state changes, before `state_changed`
##   _behavior_process(delta)  per-frame dispatch to the _update_* methods below
##   _update_idle / _update_patrol / _update_chase / _update_attack (delta)
##   _can_start_attack() -> bool  extra condition on top of range and cooldown
##   _attack_phase_duration(phase) / _on_attack_phase_entered(phase) /
##   _update_attack_motion(delta)  customize the default timed attack
##   _create_default_stats()   stats used when none are assigned
##   _on_target_acquired / _on_target_lost
##
## attack_range (when an attack may start) and the hitbox reach are coupled settings:
## change one, review the other.

signal target_acquired(target: Node2D)
signal target_lost
signal died(enemy: EnemyBase)
signal state_changed(old_state: State, new_state: State)
signal attack_phase_changed(phase: AttackPhase)
signal attack_ended

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }
enum AttackPhase { STARTUP, ACTIVE, RECOVERY }

@export var stats: EnemyStats
## The contact hitbox is the body shape shrunk by this many pixels per side (grazing a corner is safe).
@export var contact_shape_inset: float = 4.0

var state: State = State.IDLE
var target: Node2D = null
## Horizontal facing, 1 (right) or -1 (left). Flips Visual, attack pivot and ledge/wall rays.
var facing_direction: int = 1:
	set(value):
		facing_direction = 1 if value >= 0 else -1
		_apply_facing()

var _state_time_left: float = 0.0
var _attack_phase: AttackPhase = AttackPhase.STARTUP
var _attack_time_left: float = 0.0
var _attack_cooldown_left: float = 0.0
## True while a dead target is inside the detection area: stand still instead of patrolling.
var _hold_still: bool = false
var _ledge_origin: Vector2 = Vector2.ZERO
var _wall_target: Vector2 = Vector2.ZERO

@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var visual: Node2D = $Visual
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: Hitbox = $AttackPivot/Hitbox
@onready var contact_hitbox: ContactHitbox = $ContactHitbox
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var detection_shape: CollisionShape2D = $DetectionArea/CollisionShape2D
@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var wall_check: RayCast2D = $WallCheck


func _ready() -> void:
	if stats == null:
		stats = _create_default_stats()

	health.max_health = stats.max_health
	health.invulnerability_time = stats.hurt_invulnerability_time
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_health_died)

	attack_hitbox.damage = stats.attack_damage
	attack_hitbox.knockback = stats.attack_knockback
	contact_hitbox.configure(self, body_shape.shape, contact_shape_inset, stats.contact_damage, stats.contact_knockback, stats.contact_rehit_interval)

	var detection_circle := CircleShape2D.new()
	detection_circle.radius = stats.detection_range
	detection_shape.shape = detection_circle

	_ledge_origin = ledge_check.position
	_wall_target = wall_check.target_position
	_apply_facing()
	_state_time_left = stats.patrol_wait_time
	_update_contact_active()


func face_towards(world_x: float) -> void:
	if world_x > global_position.x:
		facing_direction = 1
	elif world_x < global_position.x:
		facing_direction = -1


func _physics_process(delta: float) -> void:
	_attack_cooldown_left -= delta
	if state != State.DEAD:
		_update_target()

	match state:
		State.HURT:
			_update_hurt(delta)
		State.DEAD:
			_update_dead(delta)
		_:
			_behavior_process(delta)

	if not is_on_floor():
		velocity.y = minf(velocity.y + stats.gravity * delta, stats.max_fall_speed)
	move_and_slide()


## Virtual: dispatches to the per-state updates.
func _behavior_process(delta: float) -> void:
	match state:
		State.IDLE:
			_update_idle(delta)
		State.PATROL:
			_update_patrol(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK:
			_update_attack(delta)


## Virtual.
func _update_idle(delta: float) -> void:
	_decelerate(delta)
	if not stats.patrol_enabled or _hold_still:
		return
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_set_state(State.PATROL)


## Virtual.
func _update_patrol(delta: float) -> void:
	if not stats.patrol_enabled:
		_set_state(State.IDLE)
		return
	if _is_blocked_ahead():
		facing_direction = -facing_direction
		velocity.x = 0.0
		_set_state(State.IDLE)
		return
	_move_horizontally(facing_direction * stats.move_speed * stats.patrol_speed_multiplier, delta)


## Virtual.
func _update_chase(delta: float) -> void:
	face_towards(target.global_position.x)
	if _can_attack_now():
		_start_attack()
		return
	var horizontal_distance: float = absf(target.global_position.x - global_position.x)
	if horizontal_distance > stats.attack_range and not _is_blocked_ahead():
		_move_horizontally(facing_direction * stats.move_speed, delta)
	else:
		_decelerate(delta)


## Virtual: default is a timed swing (startup, active, recovery) driven by the hooks below.
func _update_attack(delta: float) -> void:
	_update_attack_motion(delta)
	_attack_time_left -= delta
	while _attack_time_left <= 0.0 and state == State.ATTACK:
		match _attack_phase:
			AttackPhase.STARTUP:
				_enter_attack_phase(AttackPhase.ACTIVE)
			AttackPhase.ACTIVE:
				_enter_attack_phase(AttackPhase.RECOVERY)
			AttackPhase.RECOVERY:
				_attack_time_left = 0.0
				_finish_attack()


## Virtual: horizontal motion during the attack. Default: stand still.
func _update_attack_motion(delta: float) -> void:
	_decelerate(delta)


## Virtual: how long an attack phase lasts. Default: the attack_* times of the stats.
func _attack_phase_duration(phase: AttackPhase) -> float:
	match phase:
		AttackPhase.STARTUP:
			return stats.attack_startup_time
		AttackPhase.ACTIVE:
			return stats.attack_active_time
	return stats.attack_recovery_time


## Virtual: called when a phase begins. Default: the hitbox is active only in ACTIVE.
func _on_attack_phase_entered(phase: AttackPhase) -> void:
	match phase:
		AttackPhase.ACTIVE:
			attack_hitbox.activate()
		AttackPhase.RECOVERY:
			attack_hitbox.deactivate()

## Virtual: extra condition for starting an attack (range and cooldown are already checked).
func _can_start_attack() -> bool:
	return true


## Virtual.
func _enter_state(new_state: State) -> void:
	if new_state == State.IDLE:
		_state_time_left = stats.patrol_wait_time


## Virtual.
func _create_default_stats() -> EnemyStats:
	return EnemyStats.new()


## Virtual.
func _on_target_acquired(_new_target: Node2D) -> void:
	pass


## Virtual.
func _on_target_lost() -> void:
	pass


func _update_hurt(delta: float) -> void:
	_decelerate(delta)
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_set_state(State.CHASE if target != null else State.IDLE)


func _update_dead(delta: float) -> void:
	velocity.x = 0.0
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		queue_free()


# --- Helpers shared by enemy types ---

func _move_horizontally(target_speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, target_speed, stats.acceleration * delta)


func _decelerate(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, stats.acceleration * delta)


## True if a wall or (when on the floor) a missing floor lies ahead, per the stats flags.
func _is_blocked_ahead() -> bool:
	if stats.turn_on_wall and wall_check.is_colliding():
		return true
	return stats.turn_on_ledge and is_on_floor() and not ledge_check.is_colliding()


## Same check toward either side (e.g. retreating while facing the target).
func _is_blocked_toward(direction: int) -> bool:
	if direction == facing_direction:
		return _is_blocked_ahead()
	ledge_check.position.x = absf(_ledge_origin.x) * direction
	wall_check.target_position.x = absf(_wall_target.x) * direction
	ledge_check.force_raycast_update()
	wall_check.force_raycast_update()
	var blocked: bool = _is_blocked_ahead()
	_apply_facing()
	return blocked


func _can_attack_now() -> bool:
	if _attack_cooldown_left > 0.0 or target == null:
		return false
	if global_position.distance_to(target.global_position) > stats.attack_range:
		return false
	return _can_start_attack()


func _start_attack() -> void:
	_attack_time_left = 0.0
	_set_state(State.ATTACK)
	_enter_attack_phase(AttackPhase.STARTUP)


func _enter_attack_phase(phase: AttackPhase) -> void:
	_attack_phase = phase
	_attack_time_left += _attack_phase_duration(phase)
	_on_attack_phase_entered(phase)
	attack_phase_changed.emit(phase)


func _finish_attack() -> void:
	attack_hitbox.deactivate()
	_attack_cooldown_left = stats.attack_cooldown
	_set_state(State.CHASE if target != null else State.IDLE)
	attack_ended.emit()


## Stops any swing immediately. Leaves no active hitbox.
func _cancel_attack() -> void:
	attack_hitbox.deactivate()
	_attack_time_left = 0.0
	if state == State.ATTACK:
		_attack_cooldown_left = stats.attack_cooldown
		attack_ended.emit()


# --- Target tracking ---

func _update_target() -> void:
	if target != null:
		if not is_instance_valid(target) or _is_target_dead(target) \
				or global_position.distance_to(target.global_position) > maxf(stats.lose_target_range, stats.detection_range):
			_lose_target()
		return
	_hold_still = false
	for body in detection_area.get_overlapping_bodies():
		if _is_target_dead(body):
			_hold_still = true
		elif global_position.distance_to((body as Node2D).global_position) <= stats.detection_range \
				and _has_line_of_sight_to(body as Node2D):
			_acquire_target(body as Node2D)
			return


func _acquire_target(new_target: Node2D) -> void:
	target = new_target
	target_acquired.emit(new_target)
	_on_target_acquired(new_target)
	if state == State.IDLE or state == State.PATROL:
		_set_state(State.CHASE)


func _lose_target() -> void:
	target = null
	target_lost.emit()
	_on_target_lost()
	if state == State.CHASE:
		_set_state(State.IDLE)


## Duck-typed: any target exposing an `is_dead` property counts as dead when it is true.
func _is_target_dead(body: Node) -> bool:
	return body.get("is_dead") == true


func _has_line_of_sight_to(body: Node2D) -> bool:
	return not stats.detection_requires_line_of_sight or _is_line_clear_to(body)


## True if no `world` collider lies on the straight line to the body.
func _is_line_clear_to(body: Node2D) -> bool:
	var query := PhysicsRayQueryParameters2D.create(
			global_position, body.global_position, CombatLayers.layer_bit(CombatLayers.LAYER_WORLD))
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# --- Health ---

func _on_damaged(info: DamageInfo) -> void:
	_cancel_attack()
	velocity = info.knockback * stats.knockback_multiplier
	_state_time_left = stats.hurt_stun_time
	_set_state(State.HURT)


func _on_health_died() -> void:
	_cancel_attack()
	contact_hitbox.set_contact_active(false)
	hurtbox.set_enabled(false)
	detection_area.set_deferred("monitoring", false)
	_drop_health_orbs.call_deferred(stats.health_orb_count)
	velocity.x = 0.0
	_state_time_left = stats.death_fade_time
	target = null
	_set_state(State.DEAD)
	died.emit(self)


# --- State and facing ---

## Single place where the state changes.
func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old_state: State = state
	state = new_state
	_update_contact_active()
	_enter_state(new_state)
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


## Contact damage is on in every living state except HURT (unless `contact_active_while_hurt`).
func _update_contact_active() -> void:
	var wanted: bool = state != State.DEAD and not health.is_dead and (state != State.HURT or stats.contact_active_while_hurt)
	contact_hitbox.set_contact_active(wanted)


## Deferred from the death / phase change: those arrive inside physics callbacks, where new
## bodies can't be added. Bound to this node, so it is skipped if the node is gone by then.
func _drop_health_orbs(count: int) -> void:
	HealthOrbDrop.burst(get_parent(), global_position, count)
