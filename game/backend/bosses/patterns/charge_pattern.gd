class_name ChargePattern
extends BossPattern
## Telegraph -> horizontal charge toward the target's side with the hitbox active
## (stops at walls, optionally at ledges) -> recovery (stopped, vulnerable).

@export var hitbox: Hitbox
@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var charge_speed: float = 450.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var charge_duration: float = 0.7
@export var stop_on_ledge: bool = true

var _direction: int = 1


func _active_duration() -> float:
	return charge_duration


func _on_phase_entered(boss: BossBase, entered: StringName) -> void:
	boss.velocity.x = 0.0
	match entered:
		PHASE_TELEGRAPH:
			boss.face_towards(boss.target.global_position.x)
		PHASE_ACTIVE:
			boss.face_towards(boss.target.global_position.x)
			_direction = boss.facing_direction
			hitbox.activate()


func _on_phase_update(boss: BossBase, _delta: float) -> void:
	if phase_name != PHASE_ACTIVE:
		boss.velocity.x = 0.0
	elif boss.is_wall_ahead() or (stop_on_ledge and boss.is_ledge_ahead()):
		boss.velocity.x = 0.0
	else:
		boss.velocity.x = _direction * charge_speed * boss.speed_multiplier


func _on_phase_exited(boss: BossBase, exited: StringName) -> void:
	if exited == PHASE_ACTIVE:
		hitbox.deactivate()
		boss.velocity.x = 0.0


func _on_cancel(boss: BossBase) -> void:
	if hitbox:
		hitbox.deactivate()
	boss.velocity.x = 0.0