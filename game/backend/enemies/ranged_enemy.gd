class_name RangedEnemy
extends EnemyBase
## Ranged enemy: keeps its preferred distance, retreats when the target is too close
## (never into walls or off ledges) and fires one projectile per shot cycle.
## Startup is the aim/charge (telegraph in the Visual), ACTIVE is the instant of firing.
## Being hurt or killed before ACTIVE cancels the shot.

var ranged_stats: RangedEnemyStats:
	get:
		return stats as RangedEnemyStats


func _create_default_stats() -> EnemyStats:
	return RangedEnemyStats.new()


func _update_chase(delta: float) -> void:
	face_towards(target.global_position.x)
	if _can_attack_now():
		_start_attack()
		return
	var distance: float = absf(target.global_position.x - global_position.x)
	var min_range: float = minf(ranged_stats.min_range, ranged_stats.preferred_range)
	if distance < min_range:
		var away: int = -facing_direction
		if _is_blocked_toward(away):
			_decelerate(delta)
		else:
			_move_horizontally(away * stats.move_speed * ranged_stats.retreat_speed_multiplier, delta)
	elif distance > ranged_stats.preferred_range and not _is_blocked_ahead():
		_move_horizontally(facing_direction * stats.move_speed, delta)
	else:
		_decelerate(delta)


func _can_start_attack() -> bool:
	if ranged_stats.projectile_scene == null or ranged_stats.projectile_stats == null:
		return false
	return not ranged_stats.shoot_requires_line_of_sight or _is_line_clear_to(target)


## ACTIVE is the moment of firing; the melee hitbox is never used.
func _on_attack_phase_entered(phase: AttackPhase) -> void:
	if phase == AttackPhase.ACTIVE:
		_fire_projectile()


func _fire_projectile() -> void:
	if target == null or not is_instance_valid(target) or _is_target_dead(target):
		return
	var spawn_position: Vector2 = global_position + Vector2(
			ranged_stats.projectile_spawn_offset.x * facing_direction, ranged_stats.projectile_spawn_offset.y)
	var direction := Vector2(facing_direction, 0.0)
	if ranged_stats.aim_at_target:
		var aim: Vector2 = target.global_position - spawn_position
		if aim.x * facing_direction > 0.0:
			direction = aim.normalized()
	var projectile := ranged_stats.projectile_scene.instantiate() as Projectile
	# Not a child of the enemy: it must outlive its shooter.
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	parent.add_child(projectile)
	projectile.global_position = spawn_position
	projectile.launch(direction, CombatLayers.Team.ENEMY, ranged_stats.projectile_stats, self)