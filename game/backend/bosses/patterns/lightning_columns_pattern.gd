class_name LightningColumnsPattern
extends BossPattern
## Lightning columns (Phase 15e-1): `column_count` vertical bolts strike from the ceiling to the floor at x positions announced
## by the telegraph (at least 1.0 s, unscaled; StormFx draws outlined columns with a rising stripe pattern, so it does not rely on
## color alone), stay `active_time` seconds and hurt (1 heart, never more).
## They are placed so that THERE IS ALWAYS A SAFE LANE: a gap of at least `min_lane_width` px between the edges of neighbouring
## columns, and a lane whose center is at most `max_lane_offset` px from the player, so the lane is always reachable within
## the telegraph with a margin (phase15e1_smoke_test computes the margin from the real walk speed). The columns are laid on a
## grid anchored to that lane; the ones nearest to the player are the ones that are kept.
## The hitboxes are top-level Hitboxes (one per column) created on demand under the boss attack pivot; cancel, death or the
## end of the strike switch them off.

signal strike_started(xs: PackedFloat32Array)

@export_range(1, 12, 1) var column_count: int = 4
@export_range(20.0, 200.0, 1.0, "suffix:px") var column_width: float = 60.0
## The smallest gap between the edges of two columns, and between a column and a wall (px): wide enough for the duck (52 px).
@export_range(80.0, 400.0, 1.0, "suffix:px") var min_lane_width: float = 120.0
## The safe lane is centered at most this far from the player.
@export_range(0.0, 400.0, 1.0, "suffix:px") var max_lane_offset: float = 110.0
@export_range(0.05, 3.0, 0.05, "suffix:s") var active_time: float = 0.4
@export_range(1, 3, 1) var column_damage: int = 1
@export var column_knockback: Vector2 = Vector2(220.0, -300.0)
@export var fallback_left: float = 5655.0
@export var fallback_right: float = 6665.0

## The planned columns (center x) and the safe lane (the x range kept free), for the telegraph and the tests.
var column_xs: PackedFloat32Array = PackedFloat32Array()
var safe_lane: Vector2 = Vector2.ZERO
var floor_level: float = 0.0
var top_level_y: float = 0.0
var left: float = 0.0
var right: float = 0.0
var striking: bool = false

var _hitboxes: Array = []


func _active_duration() -> float:
	return active_time


func start(boss: BossBase) -> void:
	plan(boss)
	super.start(boss)


## Works out where the columns go for the current positions (the tests call it directly).
func plan(boss: BossBase) -> void:
	var bounds: Vector2 = StormArena.bounds(boss, fallback_left, fallback_right)
	left = bounds.x
	right = bounds.y
	floor_level = StormArena.floor_y(boss)
	top_level_y = StormArena.ceiling_y(boss)
	var target_x: float = boss.target.global_position.x if boss.is_target_valid() else (left + right) * 0.5
	var roll_a: float = boss.roll()
	var roll_b: float = boss.roll()
	column_xs = layout(left, right, target_x, roll_a, roll_b)
	safe_lane = _lane_of(target_x, roll_a, roll_b)


## The columns for a player at `player_x` and two random numbers in [0, 1): pure, so the tests can sweep every position.
func layout(arena_left: float, arena_right: float, player_x: float, roll_a: float, roll_b: float) -> PackedFloat32Array:
	var lane: Vector2 = _lane_for(arena_left, arena_right, player_x, roll_a, roll_b)
	var spacing: float = column_width + min_lane_width + 10.0
	var half_lane: float = (lane.y - lane.x) * 0.5
	var center: float = (lane.x + lane.y) * 0.5
	var candidates: Array[float] = []
	for k in 12:
		var offset: float = half_lane + column_width * 0.5 + float(k) * spacing
		candidates.append(center + offset)
		candidates.append(center - offset)
	var inside: Array[float] = []
	for x in candidates:
		# The whole column fits in the arena with a lane (>= min_lane_width) left between it and the wall, or touches the wall.
		if x - column_width * 0.5 >= arena_left and x + column_width * 0.5 <= arena_right:
			inside.append(x)
	inside.sort_custom(func(a: float, b: float) -> bool: return absf(a - player_x) < absf(b - player_x))
	var kept := PackedFloat32Array()
	for x in inside:
		if kept.size() >= column_count:
			break
		kept.append(x)
	return kept


## The safe lane (the x range kept free of columns) for a player at `player_x`.
func lane_for(arena_left: float, arena_right: float, player_x: float, roll_a: float, roll_b: float) -> Vector2:
	return _lane_for(arena_left, arena_right, player_x, roll_a, roll_b)


func _lane_for(arena_left: float, arena_right: float, player_x: float, roll_a: float, roll_b: float) -> Vector2:
	var half: float = min_lane_width * 0.5
	var side: float = 1.0 if roll_a < 0.5 else -1.0
	var offset: float = lerpf(0.4, 1.0, roll_b) * max_lane_offset * side
	var center: float = clampf(player_x + offset, arena_left + half, arena_right - half)
	return Vector2(center - half, center + half)


func _lane_of(player_x: float, roll_a: float, roll_b: float) -> Vector2:
	return _lane_for(left, right, player_x, roll_a, roll_b)


func _on_phase_entered(boss: BossBase, entered: StringName) -> void:
	boss.velocity.x = 0.0
	match entered:
		PHASE_TELEGRAPH:
			boss.face_towards(boss.target.global_position.x)
		PHASE_ACTIVE:
			_strike(boss)


func _on_phase_update(boss: BossBase, _delta: float) -> void:
	boss.velocity.x = 0.0


func _on_phase_exited(_boss: BossBase, exited: StringName) -> void:
	if exited == PHASE_ACTIVE:
		_stop()


func _on_cancel(_boss: BossBase) -> void:
	_stop()


func _strike(boss: BossBase) -> void:
	striking = true
	_ensure_hitboxes(boss, column_xs.size())
	var height: float = maxf(floor_level - top_level_y, 40.0)
	for i in column_xs.size():
		var box: Hitbox = _hitboxes[i]
		var shape_node := box.get_node("CollisionShape2D") as CollisionShape2D
		var rect := RectangleShape2D.new()
		rect.size = Vector2(column_width, height)
		shape_node.shape = rect
		box.damage = column_damage
		box.knockback = column_knockback
		box.global_position = Vector2(column_xs[i], top_level_y + height * 0.5)
		box.activate()
	strike_started.emit(column_xs)


func _stop() -> void:
	striking = false
	for box in _hitboxes:
		if is_instance_valid(box):
			(box as Hitbox).deactivate()


func _ensure_hitboxes(boss: BossBase, count: int) -> void:
	while _hitboxes.size() < count:
		var box := Hitbox.new()
		box.team = CombatLayers.Team.ENEMY
		box.damage = column_damage
		box.rehit_interval = 0.3
		box.owner_body = boss
		box.top_level = true
		var shape_node := CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		shape_node.shape = RectangleShape2D.new()
		box.add_child(shape_node)
		boss.attack_pivot.add_child(box)
		_hitboxes.append(box)


## What StormFx draws.
func get_draw_state() -> Dictionary:
	return {"kind": &"columns", "phase": phase_name, "progress": get_phase_progress(), "xs": column_xs, "width": column_width, "floor": floor_level,
		"top": top_level_y, "lane": safe_lane, "striking": striking}
