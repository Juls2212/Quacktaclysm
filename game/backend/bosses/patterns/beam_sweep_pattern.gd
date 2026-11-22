class_name BeamSweepPattern
extends BossPattern
## The sweeping beam of the floating eye (Phase 15e-1): a short horizontal bar of storm light that skids along the FLOOR from one
## wall to the other. Telegraph (at least 0.9 s, unscaled; the floor lane is drawn by StormFx with the boss_beam style, with
## chevrons that run along it, so it does not rely on color) -> the beam crosses the arena -> recovery.
## It can be avoided three ways, all checked by calculation in phase15e1_smoke_test from the real player numbers:
##   - a jump: the feet stay above the beam (`beam_height`) for about 0.57 s, the beam is over a given spot for
##     (beam_length + body width) / beam_speed = 0.39 s;
##   - a dash, which is fully invulnerable for its 0.18 s (dashing toward the beam closes the gap at beam_speed + dash speed);
##   - the double jump (an even longer window).
## The hitbox is a top-level Hitbox moved by this pattern; cancel, death or the end of the sweep switch it off.

signal sweep_started(direction: int)

@export var hitbox: Hitbox
@export_range(40.0, 400.0, 1.0, "suffix:px") var beam_length: float = 110.0
@export_range(10.0, 120.0, 1.0, "suffix:px") var beam_height: float = 34.0
@export_range(100.0, 1500.0, 10.0, "suffix:px/s") var beam_speed: float = 420.0
## Where the arena is when no wall is found (px); the sweep starts and ends this far inside the walls.
@export var fallback_left: float = 5655.0
@export var fallback_right: float = 6665.0
@export_range(0.0, 60.0, 1.0, "suffix:px") var wall_margin: float = 6.0

## 1 sweeps left to right, -1 right to left (chosen when the pattern starts).
var direction: int = 1
var left: float = 0.0
var right: float = 0.0
var floor_level: float = 0.0
var beam_center_x: float = 0.0
var beam_visible: bool = false

var _elapsed: float = 0.0


func _active_duration() -> float:
	return maxf((right - left - beam_length) / beam_speed, 0.1) + 0.15 if right > left else 3.0


func start(boss: BossBase) -> void:
	var bounds: Vector2 = StormArena.bounds(boss, fallback_left, fallback_right)
	left = bounds.x + wall_margin
	right = bounds.y - wall_margin
	floor_level = StormArena.floor_y(boss)
	# The beam starts at the wall farther from the player, so it always crosses the player's side.
	var target_x: float = boss.target.global_position.x if boss.is_target_valid() else (left + right) * 0.5
	direction = 1 if target_x > (left + right) * 0.5 else -1
	if boss.roll() < 0.25:
		direction = -direction
	beam_visible = false
	super.start(boss)


## The horizontal reach of the telegraph lane: the whole floor from the start wall to the far wall.
func lane_span() -> Vector2:
	return Vector2(left, right)


func _on_phase_entered(boss: BossBase, entered: StringName) -> void:
	boss.velocity.x = 0.0
	match entered:
		PHASE_TELEGRAPH:
			boss.face_towards(boss.global_position.x + float(direction))
		PHASE_ACTIVE:
			_elapsed = 0.0
			beam_visible = true
			_place(boss)
			hitbox.activate()
			sweep_started.emit(direction)


func _on_phase_update(boss: BossBase, delta: float) -> void:
	boss.velocity.x = 0.0
	if phase_name == PHASE_ACTIVE:
		_elapsed += delta * boss.speed_multiplier
		_place(boss)


func _on_phase_exited(_boss: BossBase, exited: StringName) -> void:
	if exited == PHASE_ACTIVE:
		_stop()


func _on_cancel(_boss: BossBase) -> void:
	_stop()


func _stop() -> void:
	beam_visible = false
	if hitbox != null:
		hitbox.deactivate()


## Moves the beam hitbox along the floor: it enters at the start wall and leaves at the far one.
func _place(boss: BossBase) -> void:
	var travel: float = beam_speed * _elapsed
	var start_x: float = left + beam_length * 0.5 if direction > 0 else right - beam_length * 0.5
	beam_center_x = start_x + float(direction) * travel
	var shape_node := hitbox.get_node("CollisionShape2D") as CollisionShape2D
	var rect := shape_node.shape as RectangleShape2D
	if rect != null and (rect.size.x != beam_length or rect.size.y != beam_height):
		rect = rect.duplicate() as RectangleShape2D
		rect.size = Vector2(beam_length, beam_height)
		shape_node.shape = rect
	hitbox.global_position = Vector2(beam_center_x, floor_level - beam_height * 0.5)


## What StormFx draws (the pattern knows nothing about drawing).
func get_draw_state() -> Dictionary:
	return {"kind": &"beam", "phase": phase_name, "progress": get_phase_progress(), "direction": direction, "left": left, "right": right,
		"floor": floor_level, "center": beam_center_x, "length": beam_length, "height": beam_height, "visible": beam_visible}
