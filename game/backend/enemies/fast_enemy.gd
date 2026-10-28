class_name FastEnemy
extends EnemyBase
## Fast enemy: same patrol/detect/chase flow as the base, but its attack is a lunge.
## Telegraph (startup, stopped) -> lunge burst with the hitbox active -> recovery (stopped).
## The telegraph cue lives in the Visual (enemy_visual.gd reacts to attack_phase_changed).

var fast_stats: FastEnemyStats:
	get:
		return stats as FastEnemyStats


func _create_default_stats() -> EnemyStats:
	return FastEnemyStats.new()


func _attack_phase_duration(phase: AttackPhase) -> float:
	if phase == AttackPhase.ACTIVE:
		return fast_stats.lunge_duration
	return super._attack_phase_duration(phase)


func _update_attack_motion(delta: float) -> void:
	if _attack_phase == AttackPhase.ACTIVE:
		velocity.x = 0.0 if _lunge_blocked() else facing_direction * fast_stats.lunge_speed
	else:
		super._update_attack_motion(delta)


func _on_attack_phase_entered(phase: AttackPhase) -> void:
	if phase == AttackPhase.RECOVERY:
		velocity.x = 0.0
	super._on_attack_phase_entered(phase)


## Walls always stop the lunge; ledges do when lunge_stop_on_ledge is set.
func _lunge_blocked() -> bool:
	if wall_check.is_colliding():
		return true
	return fast_stats.lunge_stop_on_ledge and is_on_floor() and not ledge_check.is_colliding()