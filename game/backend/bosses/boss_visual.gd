extends Node2D
## Drives a boss's DuckRig: swipe, charge and volley animations timed by the running pattern,
## phase 2 rage, the telegraph (a TelegraphDrawer shape that fills during the pattern's telegraph
## phase, plus the tint), a dim while it recovers, a stronger white hit flash with a small pop, and a
## ragdoll when the boss is defeated.
## Visual only; it reads boss signals and never changes gameplay state.

@export var health: HealthComponent
## The drawn guardian. `look` picks which one (woodcutter, swamp, storm).
@export var rig: DuckRig
@export var look: DuckRig.Look = DuckRig.Look.BOSS_WOODCUTTER
## White-hot flash on a hit (a little stronger than an enemy flash).
@export var flash_color: Color = Color(2.7, 2.7, 2.7, 1.0)
@export var telegraph_color: Color = Color(1.0, 0.95, 0.35, 1.0)
@export var phase_2_color: Color = Color(1.0, 0.75, 0.75, 1.0)
## Tint while it recovers from a pattern (the punish window).
@export var recovery_color: Color = Color(0.72, 0.72, 0.82, 1.0)
@export_range(0.0, 0.5, 0.01, "suffix:s") var pop_time: float = 0.1
@export_range(0.0, 0.5, 0.01) var pop_strength: float = 0.07
## Seconds the ragdoll stays before fading out.
@export_range(0.0, 30.0, 0.5, "suffix:s") var ragdoll_lifetime: float = 6.0

var _base_modulate: Color = Color.WHITE
var _rest_modulate: Color = Color.WHITE
var _flash_left: float = 0.0
var _boss: BossBase
var _last_knockback: Vector2 = Vector2.ZERO
var _ragdoll: DuckRagdoll
var _telegraph: TelegraphDrawer = null
var _telegraphs: TelegraphSet = null
var _pop_left: float = 0.0
var _leap_marker: LeapMarker = null
var _rig_base_scale: Vector2 = Vector2.ONE
var _rig_base_position: Vector2 = Vector2.ZERO
## The possession look (Phase 15d), set from outside by the PossessionDirector: how red it glows (0-1), how far it has
## risen (0-1 of `_rise_px`), how upright it stands (0-1), and the trembling.
var possession_amount: float = 0.0
var possession_rise: float = 0.0
var possession_pose: float = 0.0
var _rise_px: float = 0.0
var _tremble_px: float = 0.0
var _tremble_hz: float = 22.0
var _possession_time: float = 0.0


func _ready() -> void:
	_boss = get_parent() as BossBase
	_base_modulate = modulate
	_rest_modulate = modulate
	if rig:
		rig.look = look
		get_tree().call_group(&"profile_presenter", "register_enemy_rig", rig)
		_rig_base_scale = rig.scale
		_rig_base_position = rig.position
	if health:
		health.damaged.connect(_on_damaged)
	if _boss:
		_boss.pattern_phase_changed.connect(_on_pattern_phase_changed)
		_boss.pattern_finished.connect(func(_id: StringName) -> void: _end_pattern_cues())
		_boss.pattern_cancelled.connect(func(_id: StringName) -> void: _end_pattern_cues())
		_boss.phase_changed.connect(_on_phase_changed)
		_boss.defeated.connect(_on_defeated)
		_boss.encounter_reset.connect(_on_reset)
		_bind_leap_markers.call_deferred()


func _process(delta: float) -> void:
	_update_rig()
	_update_telegraph(delta)
	_update_pop(delta)
	_update_leap_pose()
	_update_possession(delta)
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
	rig.hurt = _boss.state == BossBase.State.PHASE_TRANSITION and possession_pose < 0.05
	if possession_rise > 0.02:
		# Lifted off the ground: no feet on the floor, no walking.
		rig.grounded = false
		rig.ground_speed = 0.0
		rig.vertical_speed = 0.0
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


func _on_pattern_phase_changed(pattern_id: StringName, phase_name: StringName) -> void:
	_set_telegraph(phase_name == BossPattern.PHASE_TELEGRAPH)
	if phase_name == BossPattern.PHASE_TELEGRAPH:
		_show_telegraph(pattern_id)
	else:
		_hide_telegraph()
	if phase_name == BossPattern.PHASE_RECOVERY:
		# The punish window: a faint dim until the pattern is over.
		_rest_modulate = recovery_color
		if _flash_left <= 0.0:
			modulate = _rest_modulate


## The pattern ended or was cancelled (by phase 2, a reset or the boss going down).
func _end_pattern_cues() -> void:
	_hide_telegraph()
	_set_telegraph(false)
	if _leap_marker != null:
		_leap_marker.hide_marker()
	if rig != null and _pop_left <= 0.0:
		rig.scale = _rig_base_scale


## Sets the possession look (the PossessionDirector calls it every frame of the sequence and once more when it ends).
## `glow` and `pose` are 0-1, `rise` is 0-1 of `rise_height` px, `tremble` is in px at `tremble_hz`.
func set_possession(glow: float, rise: float, pose: float, color: Color, rise_height: float, tremble: float, tremble_hz: float, pulse_hz: float) -> void:
	possession_amount = glow
	possession_rise = rise
	possession_pose = pose
	_rise_px = rise_height
	_tremble_px = tremble
	_tremble_hz = tremble_hz
	if rig != null:
		rig.possession = glow
		rig.possession_color = color
		rig.possession_hz = pulse_hz
		rig.possession_pose = pose


## Back to the normal look (the boss died or the fight was cancelled).
func clear_possession() -> void:
	possession_amount = 0.0
	possession_rise = 0.0
	possession_pose = 0.0
	if rig != null:
		rig.possession = 0.0
		rig.possession_pose = 0.0
		rig.position = _rig_base_position


func _update_possession(delta: float) -> void:
	if rig == null or (possession_rise <= 0.0 and possession_amount <= 0.0):
		return
	_possession_time += delta
	var shake: float = _tremble_px * possession_rise * sin(_possession_time * TAU * _tremble_hz)
	rig.position = _rig_base_position + Vector2(shake, -_rise_px * possession_rise)


## The leap patterns announce where the boss will come down: a marker on that spot of the floor.
func _bind_leap_markers() -> void:
	if _boss == null:
		return
	for pattern in _boss.patterns:
		if pattern is LeapPattern and not (pattern as LeapPattern).marker_changed.is_connected(_on_leap_marker):
			(pattern as LeapPattern).marker_changed.connect(_on_leap_marker)


func _on_leap_marker(world_position: Vector2, shown: bool) -> void:
	if not shown:
		if _leap_marker != null:
			_leap_marker.hide_marker()
		return
	if _telegraphs == null:
		_telegraphs = TelegraphSet.get_default()
	var style: TelegraphStyle = _telegraphs.get_style(TelegraphSet.KIND_BOSS_LEAP)
	if style == null:
		return
	if _leap_marker == null:
		_leap_marker = LeapMarker.new()
		_leap_marker.name = "LeapMarker"
		_boss.add_child(_leap_marker)
	_leap_marker.show_marker(world_position, style)


## The guardian crouches while a leap winds up (the rig only).
func _update_leap_pose() -> void:
	if rig == null or _boss == null or _pop_left > 0.0:
		return
	var pattern: BossPattern = _boss.current_pattern
	if pattern is LeapPattern and pattern.phase_name == BossPattern.PHASE_TELEGRAPH:
		var k: float = pattern.get_phase_progress()
		rig.scale = _rig_base_scale * Vector2(1.0 + 0.12 * k, 1.0 - 0.3 * k)


func _hide_telegraph() -> void:
	if _telegraph != null:
		_telegraph.hide_telegraph()


## Shows the telegraph of the pattern that just began its telegraph phase.
func _show_telegraph(pattern_id: StringName) -> void:
	if rig == null or _boss == null:
		return
	if _telegraphs == null:
		_telegraphs = TelegraphSet.get_default()
	var style: TelegraphStyle = _telegraphs.get_style(TelegraphSet.kind_of_pattern(pattern_id))
	if style == null:
		return
	if _telegraph == null:
		_telegraph = TelegraphDrawer.new()
		_telegraph.name = "Telegraph"
		_boss.add_child(_telegraph)
	var offset: Vector2 = rig.global_position - _boss.global_position
	var s: float = absf(rig.global_scale.y)
	_telegraph.ground_y = offset.y + rig.foot_y * s
	_telegraph.center = offset + Vector2(0.0, -12.0 * s)
	_telegraph.muzzle = _telegraph.center
	_telegraph.reach = 0.0
	_telegraph.fan_count = 1
	_telegraph.fan_degrees = 0.0
	var pattern: BossPattern = _boss.current_pattern
	if pattern is ChargePattern:
		_telegraph.reach = (pattern as ChargePattern).charge_speed * (pattern as ChargePattern).charge_duration
	elif pattern is ProjectileVolleyPattern:
		var volley := pattern as ProjectileVolleyPattern
		_telegraph.fan_count = volley.projectile_count
		_telegraph.fan_degrees = volley.spread_angle_degrees
		_telegraph.muzzle = Vector2(volley.spawn_offset.x, volley.spawn_offset.y)
	_telegraph.aim_target = _boss.target
	_telegraph.show_telegraph(style)


## While the telegraph phase runs: the shape follows the pattern's own progress.
func _update_telegraph(delta: float) -> void:
	if _telegraph == null or not _telegraph.active:
		return
	var pattern: BossPattern = _boss.current_pattern
	if pattern == null or pattern.phase_name != BossPattern.PHASE_TELEGRAPH:
		_telegraph.hide_telegraph()
		return
	_telegraph.update_windup(pattern.get_phase_progress(), _boss.facing_direction, delta)


## A short squash-and-stretch after a hit (the rig only).
func _update_pop(delta: float) -> void:
	if _pop_left <= 0.0 or rig == null:
		return
	_pop_left = maxf(_pop_left - delta, 0.0)
	var k: float = _pop_left / maxf(pop_time, 0.001)
	rig.scale = _rig_base_scale * Vector2(1.0 + pop_strength * k, 1.0 - pop_strength * 0.75 * k)


func _set_telegraph(active: bool) -> void:
	var resting: Color = phase_2_color if _boss and _boss.current_phase >= 2 else _base_modulate
	_rest_modulate = telegraph_color if active else resting
	if _flash_left <= 0.0:
		modulate = _rest_modulate


func _on_phase_changed(_phase: int) -> void:
	_hide_telegraph()
	_set_telegraph(false)


func _on_damaged(info: DamageInfo) -> void:
	_last_knockback = info.knockback
	_flash_left = _boss.stats.hit_flash_time if _boss else 0.1
	modulate = flash_color
	_pop_left = pop_time


## Deferred: the killing hit arrives inside a physics callback, where new bodies can't be added.
func _on_defeated(_defeated_boss: BossBase) -> void:
	modulate = _base_modulate
	_hide_telegraph()
	_pop_left = 0.0
	if rig != null:
		rig.scale = _rig_base_scale
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
	_hide_telegraph()
	_pop_left = 0.0
	if rig != null:
		rig.scale = _rig_base_scale
	_rest_modulate = _base_modulate
	modulate = _base_modulate
	_free_ragdoll()
	if rig:
		rig.visible = true


func _free_ragdoll() -> void:
	if is_instance_valid(_ragdoll):
		_ragdoll.queue_free()
	_ragdoll = null
