class_name ProjectileVolleyPattern
extends BossPattern
## Telegraph -> fires `projectile_count` projectiles one every `shot_interval`, fanned
## evenly across `spread_angle_degrees` -> recovery. Projectiles are added to the current
## scene (not to the boss), so they survive the boss.

@export var projectile_scene: PackedScene = preload("res://backend/combat/projectile.tscn")
@export var projectile_stats: ProjectileStats = preload("res://backend/combat/stats/enemy_projectile_stats.tres")
@export_range(1, 50, 1) var projectile_count: int = 5
@export_range(0.0, 360.0, 1.0, "suffix:°") var spread_angle_degrees: float = 40.0
@export_range(0.0, 5.0, 0.01, "suffix:s") var shot_interval: float = 0.12
## Spawn point relative to the boss; x is mirrored by facing.
@export var spawn_offset: Vector2 = Vector2(50.0, -10.0)
## true aims at the target's position (kept in the half-plane the boss faces); false is horizontal.
@export var aim_at_target: bool = true

var _shots_fired: int = 0
var _active_elapsed: float = 0.0
var _aim_direction: Vector2 = Vector2.RIGHT


func _active_duration() -> float:
	return maxf(projectile_count - 1, 0) * shot_interval


func _on_phase_entered(boss: BossBase, entered: StringName) -> void:
	boss.velocity.x = 0.0
	match entered:
		PHASE_TELEGRAPH:
			boss.face_towards(boss.target.global_position.x)
		PHASE_ACTIVE:
			_shots_fired = 0
			_active_elapsed = 0.0
			_aim_direction = _compute_aim(boss)
			_fire_due_shots(boss)


func _on_phase_update(boss: BossBase, delta: float) -> void:
	boss.velocity.x = 0.0
	if phase_name == PHASE_ACTIVE:
		_active_elapsed += delta * boss.speed_multiplier
		_fire_due_shots(boss)


func _on_phase_exited(boss: BossBase, exited: StringName) -> void:
	if exited == PHASE_ACTIVE:
		_active_elapsed = INF
		_fire_due_shots(boss)


func _on_cancel(_boss: BossBase) -> void:
	_shots_fired = projectile_count
	_active_elapsed = 0.0


func _compute_aim(boss: BossBase) -> Vector2:
	var direction := Vector2(boss.facing_direction, 0.0)
	if aim_at_target and boss.is_target_valid():
		var aim: Vector2 = boss.target.global_position - _spawn_position(boss)
		if aim.x * boss.facing_direction > 0.0:
			direction = aim.normalized()
	return direction


func _spawn_position(boss: BossBase) -> Vector2:
	return boss.global_position + Vector2(spawn_offset.x * boss.facing_direction, spawn_offset.y)


func _fire_due_shots(boss: BossBase) -> void:
	while _shots_fired < projectile_count and _active_elapsed >= _shots_fired * shot_interval:
		_fire_shot(boss, _shots_fired)
		_shots_fired += 1


func _fire_shot(boss: BossBase, index: int) -> void:
	var offset_degrees: float = 0.0
	if projectile_count > 1:
		offset_degrees = -spread_angle_degrees / 2.0 + index * spread_angle_degrees / (projectile_count - 1)
	var projectile := projectile_scene.instantiate() as Projectile
	var parent: Node = boss.get_tree().current_scene if boss.get_tree().current_scene else boss.get_parent()
	parent.add_child(projectile)
	projectile.global_position = _spawn_position(boss)
	projectile.launch(_aim_direction.rotated(deg_to_rad(offset_degrees)), CombatLayers.Team.ENEMY, projectile_stats, boss)