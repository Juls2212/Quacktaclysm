class_name HealthOrbDrop
extends RefCounted
## Spawns a burst of health orbs. Used by EnemyBase on death and BossBase on phase 2 and defeat.
## Call it outside physics callbacks (callers defer it): it adds rigid bodies to the tree.

const ORB_SCENE := preload("res://backend/combat/health_orb.tscn")


## Pops `count` orbs out of `at` (global position) inside `container`.
static func burst(container: Node, at: Vector2, count: int) -> void:
	if container == null or count <= 0 or not container.is_inside_tree():
		return
	for i in count:
		var orb: HealthOrb = ORB_SCENE.instantiate()
		container.add_child(orb)
		orb.global_position = at + Vector2(randf_range(-6.0, 6.0), -12.0)
		var stats: HealthOrbStats = orb.stats
		# Fan the orbs out evenly around straight up, with a little jitter.
		var u: float = 0.5 if count == 1 else float(i) / float(count - 1)
		var angle: float = deg_to_rad(lerpf(-stats.launch_spread, stats.launch_spread, u) + randf_range(-8.0, 8.0))
		orb.launch(Vector2.UP.rotated(angle), randf_range(stats.launch_speed_min, stats.launch_speed_max))
