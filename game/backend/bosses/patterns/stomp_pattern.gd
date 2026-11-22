class_name StompPattern
extends BossPattern
## A short stomp (Phase 15e-1), the last fallback of boss 3: it works on the floor (Kenzo hops and lands) and in the air (the eye
## swoops down toward the floor and back), and it is always eligible, so the boss never stands without an attack. A telegraph
## (`telegraph_time`, the boss trembles and its marker pulses) comes first; the landing area (`landing_hitbox`, a circle round the
## boss feet) hurts for `landing_active_time` s at the bottom. The hitbox is switched off by the end of the pattern, a cancel or
## the death of the boss.

@export var landing_hitbox: Hitbox
## Floor: the hop (negative is up).
@export_range(-1500.0, 0.0, 10.0, "suffix:px/s") var hop_velocity: float = -480.0
## Air: how long the eye stays low.
@export_range(0.2, 4.0, 0.05, "suffix:s") var swoop_time: float = 1.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var landing_active_time: float = 0.3

var _elapsed: float = 0.0
var _landing_left: float = 0.0
var _hop_started: bool = false
var _swoop: bool = false


func can_start_fallback(boss: BossBase, ignore_cooldown: bool) -> bool:
	return super.can_start_fallback(boss, ignore_cooldown) and boss.is_target_valid() and (boss.is_on_floor() or _hover_of(boss) != null)


func can_start(boss: BossBase) -> bool:
	return super.can_start(boss) and boss.is_target_valid() and (boss.is_on_floor() or _hover_of(boss) != null)


func _hover_of(boss: BossBase) -> BossHover:
	var hover := boss.hover as BossHover
	return hover if hover != null and hover.is_floating() else null


func _active_duration() -> float:
	return swoop_time + 0.6 if _swoop else 1.6


func _on_phase_entered(boss: BossBase, entered: StringName) -> void:
	boss.velocity.x = 0.0
	match entered:
		PHASE_TELEGRAPH:
			boss.face_towards(boss.target.global_position.x)
			_swoop = _hover_of(boss) != null
		PHASE_ACTIVE:
			_elapsed = 0.0
			_landing_left = 0.0
			_hop_started = false
			if _swoop:
				_hover_of(boss).request_dip(swoop_time)
			else:
				boss.velocity.y = hop_velocity
				_hop_started = true


func _on_phase_update(boss: BossBase, delta: float) -> void:
	if landing_hitbox != null and _landing_left > 0.0:
		_landing_left -= delta
		if _landing_left <= 0.0:
			landing_hitbox.deactivate()
	if phase_name != PHASE_ACTIVE:
		boss.velocity.x = 0.0
		return
	_elapsed += delta
	boss.velocity.x = 0.0
	if _swoop:
		# At the bottom of the swoop (the last half of the dip) the area under the eye hurts.
		if _elapsed >= swoop_time * 0.5 and _landing_left <= 0.0 and landing_hitbox != null and not landing_hitbox.is_active:
			landing_hitbox.activate()
			_landing_left = landing_active_time
		if _elapsed >= swoop_time + 0.2:
			_phase_left = 0.0
	elif _hop_started and _elapsed > 0.1 and boss.is_on_floor() and boss.velocity.y >= 0.0:
		_hop_started = false
		if landing_hitbox != null:
			landing_hitbox.activate()
			_landing_left = landing_active_time
		_phase_left = minf(_phase_left, landing_active_time)


func _on_phase_exited(_boss: BossBase, exited: StringName) -> void:
	if exited == PHASE_ACTIVE and landing_hitbox != null:
		landing_hitbox.deactivate()


func _on_cancel(boss: BossBase) -> void:
	if landing_hitbox != null:
		landing_hitbox.deactivate()
	_landing_left = 0.0
	boss.velocity.x = 0.0
