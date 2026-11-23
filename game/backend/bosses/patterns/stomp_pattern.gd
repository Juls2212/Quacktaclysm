class_name StompPattern
extends BossPattern
## A short stomp (Phase 15e-1), the last fallback of boss 3: Kenzo hops and lands on the floor, and it is always eligible there, so the
## boss never stands without an attack. A telegraph
## (`telegraph_time`, the boss trembles and its marker pulses) comes first; the landing area (`landing_hitbox`, a circle round the
## boss feet) hurts for `landing_active_time` s at the bottom. The hitbox is switched off by the end of the pattern, a cancel or
## the death of the boss.

@export var landing_hitbox: Hitbox
## Floor: the hop (negative is up).
@export_range(-1500.0, 0.0, 10.0, "suffix:px/s") var hop_velocity: float = -480.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var landing_active_time: float = 0.3

var _elapsed: float = 0.0
var _landing_left: float = 0.0
var _hop_started: bool = false


func can_start_fallback(boss: BossBase, ignore_cooldown: bool) -> bool:
	return super.can_start_fallback(boss, ignore_cooldown) and boss.is_target_valid() and boss.is_on_floor()


func can_start(boss: BossBase) -> bool:
	return super.can_start(boss) and boss.is_target_valid() and boss.is_on_floor()


func _active_duration() -> float:
	return 1.6


func _on_phase_entered(boss: BossBase, entered: StringName) -> void:
	boss.velocity.x = 0.0
	match entered:
		PHASE_TELEGRAPH:
			boss.face_towards(boss.target.global_position.x)
		PHASE_ACTIVE:
			_elapsed = 0.0
			_landing_left = 0.0
			_hop_started = false
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
	if _hop_started and _elapsed > 0.1 and boss.is_on_floor() and boss.velocity.y >= 0.0:
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
