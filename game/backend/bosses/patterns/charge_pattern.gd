class_name ChargePattern
extends BossPattern
## Telegraph -> horizontal charge toward the target's side with the hitbox active
## (stops at walls, optionally at ledges) -> recovery (stopped, vulnerable).
## Phase 15d-bis: a charge is only eligible when its lane is long enough (`min_useful_lane`: measured with rays toward
## the target before the telegraph, up to the first wall or the first ledge), so a boss on a platform never runs to the
## edge and stops: the pattern is not chosen there. The telegraph draws the real lane (`planned_lane`, clipped by a
## wall) and the hitbox is active along all of it.

@export var hitbox: Hitbox
@export_range(0.0, 2000.0, 1.0, "suffix:px/s") var charge_speed: float = 450.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var charge_duration: float = 0.7
@export var stop_on_ledge: bool = true
## The shortest lane worth charging (px). A shorter lane makes the pattern ineligible BEFORE its telegraph starts.
@export_range(0.0, 1000.0, 1.0, "suffix:px") var min_useful_lane: float = 220.0
## Half the width of the boss body, and the height of its center above its soles (for the rays).
@export_range(0.0, 100.0, 1.0, "suffix:px") var body_half_width: float = 28.0
@export_range(0.0, 100.0, 1.0, "suffix:px") var body_half_height: float = 44.0

## The real lane measured when the pattern starts (the telegraph draws it).
var planned_lane: float = 0.0

var _direction: int = 1


func _active_duration() -> float:
	return charge_duration


func can_start(boss: BossBase) -> bool:
	if not super.can_start(boss):
		return false
	if not boss.is_on_floor() or not boss.is_target_valid():
		return false
	return lane_available(boss, _direction_to_target(boss)) >= min_useful_lane


func can_start_fallback(boss: BossBase, ignore_cooldown: bool) -> bool:
	return super.can_start_fallback(boss, ignore_cooldown) and boss.is_on_floor() and boss.is_target_valid() \
			and lane_available(boss, _direction_to_target(boss)) >= min_useful_lane


func start(boss: BossBase) -> void:
	_direction = _direction_to_target(boss)
	planned_lane = minf(lane_available(boss, _direction), _nominal_lane(boss))
	super.start(boss)


func _direction_to_target(boss: BossBase) -> int:
	return 1 if boss.target.global_position.x >= boss.global_position.x else -1


## The full reach of the charge at the current speed (px).
func _nominal_lane(boss: BossBase) -> float:
	return charge_speed * charge_duration * boss.speed_multiplier


## How far (px) the boss could charge in `direction` from where it stands: up to the first wall or the first ledge,
## at most the full reach. Measured with rays against the world layer.
func lane_available(boss: BossBase, direction: int) -> float:
	var space: PhysicsDirectSpaceState2D = boss.get_world_2d().direct_space_state
	var mask: int = CombatLayers.layer_bit(CombatLayers.LAYER_WORLD)
	var full: float = _nominal_lane(boss)
	var origin: Vector2 = boss.global_position
	var reach: float = full
	var wall_query := PhysicsRayQueryParameters2D.create(origin, origin + Vector2(float(direction) * (full + body_half_width), 0.0), mask)
	wall_query.exclude = [boss.get_rid()]
	var wall_hit: Dictionary = space.intersect_ray(wall_query)
	if not wall_hit.is_empty():
		reach = minf(reach, absf((wall_hit["position"] as Vector2).x - origin.x) - body_half_width)
	if stop_on_ledge:
		var feet_y: float = origin.y + body_half_height
		var step: float = 16.0
		var distance: float = step
		while distance <= reach:
			var probe_x: float = origin.x + float(direction) * distance
			var down := PhysicsRayQueryParameters2D.create(Vector2(probe_x, feet_y - 6.0), Vector2(probe_x, feet_y + 26.0), mask)
			down.exclude = [boss.get_rid()]
			if space.intersect_ray(down).is_empty():
				reach = distance - step
				break
			distance += step
	return maxf(reach, 0.0)


func _on_phase_entered(boss: BossBase, entered: StringName) -> void:
	boss.velocity.x = 0.0
	match entered:
		PHASE_TELEGRAPH:
			boss.face_towards(boss.target.global_position.x)
		PHASE_ACTIVE:
			# Re-aim at the target only if the other side still has a useful lane; never turn toward a wasted charge.
			var new_direction: int = _direction_to_target(boss)
			if new_direction != _direction and lane_available(boss, new_direction) >= min_useful_lane:
				_direction = new_direction
			boss.facing_direction = _direction
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