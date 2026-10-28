class_name SwipePattern
extends BossPattern
## Telegraph (boss stopped, facing the target) -> one frontal hitbox window -> recovery.
## The telegraph cue is shown by the boss's Visual (it reacts to phase_changed).

@export var hitbox: Hitbox
@export_range(0.0, 5.0, 0.05, "suffix:s") var active_time: float = 0.2


func _active_duration() -> float:
	return active_time


func _on_phase_entered(boss: BossBase, entered: StringName) -> void:
	boss.velocity.x = 0.0
	match entered:
		PHASE_TELEGRAPH:
			boss.face_towards(boss.target.global_position.x)
		PHASE_ACTIVE:
			hitbox.activate()


func _on_phase_update(boss: BossBase, _delta: float) -> void:
	boss.velocity.x = 0.0


func _on_phase_exited(_boss: BossBase, exited: StringName) -> void:
	if exited == PHASE_ACTIVE:
		hitbox.deactivate()


func _on_cancel(_boss: BossBase) -> void:
	if hitbox:
		hitbox.deactivate()