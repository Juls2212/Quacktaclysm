class_name StormArena
extends RefCounted
## Measures the arena around a boss with rays against the world layer (Phase 15e-1): the walls to its left and right, the floor
## under it and the ceiling above it. The storm patterns (the beam, the columns, the stomp) use it, so they fit whatever arena
## the boss stands in and never need numbers typed for one level. When a ray finds nothing the fallback numbers are used.


static func _space(boss: BossBase) -> PhysicsDirectSpaceState2D:
	return boss.get_world_2d().direct_space_state


static func _mask() -> int:
	return CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)


static func _cast(boss: BossBase, from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to, _mask())
	query.exclude = [boss.get_rid()]
	return _space(boss).intersect_ray(query)


## The y of the floor under the boss (its top surface); `fallback` if there is none.
static func floor_y(boss: BossBase, fallback: float = 600.0) -> float:
	var hit: Dictionary = _cast(boss, boss.global_position, boss.global_position + Vector2(0.0, 1400.0))
	return (hit["position"] as Vector2).y if not hit.is_empty() else fallback


## The y of the ceiling above the boss; `fallback` if there is none.
static func ceiling_y(boss: BossBase, fallback: float = 160.0) -> float:
	var hit: Dictionary = _cast(boss, boss.global_position, boss.global_position + Vector2(0.0, -1400.0))
	return (hit["position"] as Vector2).y if not hit.is_empty() else fallback


## The x of the walls on each side at the height of the boss (the inner faces): Vector2(left, right).
static func bounds(boss: BossBase, fallback_left: float, fallback_right: float) -> Vector2:
	var origin: Vector2 = Vector2(boss.global_position.x, minf(boss.global_position.y, floor_y(boss) - 40.0))
	var left_hit: Dictionary = _cast(boss, origin, origin + Vector2(-3000.0, 0.0))
	var right_hit: Dictionary = _cast(boss, origin, origin + Vector2(3000.0, 0.0))
	var left: float = (left_hit["position"] as Vector2).x if not left_hit.is_empty() else fallback_left
	var right: float = (right_hit["position"] as Vector2).x if not right_hit.is_empty() else fallback_right
	return Vector2(left, right)
