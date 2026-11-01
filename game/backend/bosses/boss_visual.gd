extends Node2D
## Drives a boss's DuckRig: swipe, charge and volley animations timed by the running pattern,
## phase 2 rage, the hit flash and telegraph tint, and a ragdoll when the boss is defeated.
## Visual only; it reads boss signals and never changes gameplay state.

@export var health: HealthComponent
## The drawn guardian. `look` picks which one (woodcutter, swamp, storm).
@export var rig: DuckRig
@export var look: DuckRig.Look = DuckRig.Look.BOSS_WOODCUTTER
@export var flash_color: Color = Color(1.0, 0.5, 0.5, 1.0)
@export var telegraph_color: Color = Color(1.0, 0.95, 0.35, 1.0)
@export var phase_2_color: Color = Color(1.0, 0.75, 0.75, 1.0)
## Seconds the ragdoll stays before fading out.
@export_range(0.0, 30.0, 0.5, "suffix:s") var ragdoll_lifetime: float = 6.0

var _base_modulate: Color = Color.WHITE
var _rest_modulate: Color = Color.WHITE
var _flash_left: float = 0.0
var _boss: BossBase
var _last_knockback: Vector2 = Vector2.ZERO
var _ragdoll: DuckRagdoll


func _ready() -> void:
	_boss = get_parent() as BossBase
	_base_modulate = modulate
	_rest_modulate = modulate
	if rig:
		rig.look = look
	if health:
		health.damaged.connect(_on_damaged)
	if _boss:
		_boss.pattern_phase_changed.connect(_on_pattern_phase_changed)
		_boss.pattern_finished.connect(func(_id: StringName) -> void: _set_telegraph(false))
		_boss.pattern_cancelled.connect(func(_id: StringName) -> void: _set_telegraph(false))
		_boss.phase_changed.connect(_on_phase_changed)
		_boss.defeated.connect(_on_defeated)
		_boss.encounter_reset.connect(_on_reset)


func _process(delta: float) -> void:
	_update_rig()
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			modulate = _rest_modulate


func _update_rig() -> void:
	if rig == null or _boss == null:
		return
	rig.ground_speed = absf(_boss.velocity.x)
	rig.grounded = _boss.is_on_floor()
	rig.vertical_speed = _boss.velocity.y
	rig.enraged = _boss.current_phase >= 2
	# The phase transition is a roar: the guardian shudders before its rage starts.
	rig.hurt = _boss.state == BossBase.State.PHASE_TRANSITION
	rig.dead = _boss.state == BossBase.State.DEAD
	var pattern: BossPattern = _boss.current_pattern
	if _boss.state != BossBase.State.PATTERN or pattern == null:
		rig.action = DuckRig.Action.NONE
		return
	if pattern is ChargePattern:
		rig.action = DuckRig.Action.CHARGE
	elif pattern is ProjectileVolleyPattern:
		rig.action = DuckRig.Action.CAST
	else:
		rig.action = DuckRig.Action.ATTACK
	match pattern.phase_name:
		BossPattern.PHASE_TELEGRAPH:
			rig.phase = DuckRig.Phase.WINDUP
		BossPattern.PHASE_ACTIVE:
			rig.phase = DuckRig.Phase.STRIKE
		_:
			rig.phase = DuckRig.Phase.RECOVER
	rig.phase_t = pattern.get_phase_progress()


func _on_pattern_phase_changed(_pattern_id: StringName, phase_name: StringName) -> void:
	_set_telegraph(phase_name == BossPattern.PHASE_TELEGRAPH)


func _set_telegraph(active: bool) -> void:
	var resting: Color = phase_2_color if _boss and _boss.current_phase >= 2 else _base_modulate
	_rest_modulate = telegraph_color if active else resting
	if _flash_left <= 0.0:
		modulate = _rest_modulate


func _on_phase_changed(_phase: int) -> void:
	_set_telegraph(false)


func _on_damaged(info: DamageInfo) -> void:
	_last_knockback = info.knockback
	_flash_left = _boss.stats.hit_flash_time if _boss else 0.1
	modulate = flash_color


## Deferred: the killing hit arrives inside a physics callback, where new bodies can't be added.
func _on_defeated(_defeated_boss: BossBase) -> void:
	modulate = _base_modulate
	if rig != null and _boss != null:
		_spawn_ragdoll.call_deferred(_last_knockback * 0.6 + Vector2(0, -180), _boss.velocity)


func _spawn_ragdoll(push: Vector2, inherited: Vector2) -> void:
	if not is_inside_tree() or _boss.state != BossBase.State.DEAD:
		return
	_free_ragdoll()
	_ragdoll = DuckRagdoll.spawn(rig, _boss.get_parent(), push, inherited, ragdoll_lifetime)
	if _ragdoll != null:
		rig.visible = false


func _on_reset() -> void:
	_flash_left = 0.0
	_rest_modulate = _base_modulate
	modulate = _base_modulate
	_free_ragdoll()
	if rig:
		rig.visible = true


func _free_ragdoll() -> void:
	if is_instance_valid(_ragdoll):
		_ragdoll.queue_free()
	_ragdoll = null
