class_name StageMath
extends RefCounted
## Pure functions of boss 3's stage (Phase 15j): what a jump can do (from the REAL player stats), where the platforms stand, the lanes of the
## platform barrage, and the safe lane of the red eye's bolts. No nodes, no state: BossStage, PlatformBarrage and StormEye call them and
## phase15j_smoke_test sweeps them against the real numbers.

const BODY_HEIGHT: float = 52.0
const BODY_WIDTH: float = 28.0


# ---------------------------------------------------------------------------------------------
# What the player can do
# ---------------------------------------------------------------------------------------------

## How high a single jump lifts the feet (px).
static func jump_rise(stats: PlayerStats) -> float:
	return stats.jump_velocity * stats.jump_velocity / (2.0 * stats.gravity)


## The most a jump followed by the double jump lifts the feet (px): the double jump is made at the best moment.
static func double_rise(stats: PlayerStats) -> float:
	var w: float = absf(stats.double_jump_velocity)
	return jump_rise(stats) + w * w / (2.0 * stats.gravity)


## Seconds from take-off until the feet are back down on something `rise` px above the take-off height (INF if the jump never gets there).
static func air_time_to(stats: PlayerStats, rise: float) -> float:
	var v: float = absf(stats.jump_velocity)
	var disc: float = v * v - 2.0 * stats.gravity * rise
	if disc < 0.0:
		return INF
	return (v + sqrt(disc)) / stats.gravity


## Seconds from take-off until the feet first reach `rise` px above it (the up-going half).
static func rise_time_to(stats: PlayerStats, rise: float) -> float:
	var v: float = absf(stats.jump_velocity)
	var disc: float = v * v - 2.0 * stats.gravity * rise
	if disc < 0.0:
		return INF
	return (v - sqrt(disc)) / stats.gravity


## Seconds to fall `drop` px from rest.
static func fall_time(stats: PlayerStats, drop: float) -> float:
	return sqrt(2.0 * maxf(drop, 0.0) / stats.gravity)


## Horizontal px covered in `seconds` at full speed.
static func run(stats: PlayerStats, seconds: float) -> float:
	return stats.max_speed * seconds


# ---------------------------------------------------------------------------------------------
# The platforms
# ---------------------------------------------------------------------------------------------

## Platform `index`'s horizontal extent (left, right) in world x for an arena centered at `center_x`.
static func platform_span(config: StageConfig, center_x: float, index: int) -> Vector2:
	var middle: float = center_x + config.platform_offsets[index]
	return Vector2(middle - config.platform_width * 0.5, middle + config.platform_width * 0.5)


static func perch_span(config: StageConfig, center_x: float) -> Vector2:
	var middle: float = center_x + config.perch_offset
	return Vector2(middle - config.perch_width * 0.5, middle + config.perch_width * 0.5)


## World y of the TOP surface of platform `index` (the floor surface is `floor_top`).
static func platform_top(config: StageConfig, floor_top: float, index: int) -> float:
	return floor_top - config.platform_heights[index]


# ---------------------------------------------------------------------------------------------
# The barrage
# ---------------------------------------------------------------------------------------------

## The events of one barrage: [{"lane": platform index, "side": -1 (from the left wall) or 1, "start": seconds}]. Consecutive lanes are never the
## same and never neighbours, so a neighbour of any dangerous platform is always safe; the sides alternate.
static func barrage_plan(config: StageConfig, rng: RandomNumberGenerator, lane_count: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var previous: int = -1
	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	for i in config.lane_events:
		var options: Array[int] = []
		for lane in lane_count:
			if previous < 0 or absi(lane - previous) >= 2:
				options.append(lane)
		var lane_pick: int = options[rng.randi_range(0, options.size() - 1)]
		events.append({"lane": lane_pick, "side": int(side), "start": float(i) * config.lane_gap})
		previous = lane_pick
		side = -side
	return events


## The height (world y) of a lane's projectile for platform `lane`.
static func lane_y(config: StageConfig, floor_top: float, lane: int) -> float:
	return platform_top(config, floor_top, lane) - config.lane_torso


## The fastest time (s) for a player standing anywhere on platform `from_index` to be standing on its neighbour `to_index` (the safe one):
## the run to where the jump can reach plus the real air time of the jump or the fall. Conservative: the whole landing counts.
static func neighbour_time(stats: PlayerStats, config: StageConfig, center_x: float, floor_top: float, from_index: int, to_index: int) -> float:
	var from_span: Vector2 = platform_span(config, center_x, from_index)
	var to_span: Vector2 = platform_span(config, center_x, to_index)
	var dy: float = platform_top(config, floor_top, from_index) - platform_top(config, floor_top, to_index)
	var worst: float = 0.0
	for x: float in [from_span.x, from_span.y]:
		var gap: float = maxf(maxf(to_span.x - x, x - to_span.y), 0.0)
		var air: float
		if dy > 0.0:
			air = air_time_to(stats, dy)
		else:
			# Jumping off lands lower after a longer flight; walking off the edge and falling is the same order.
			var v: float = absf(stats.jump_velocity)
			air = (v + sqrt(v * v + 2.0 * stats.gravity * -dy)) / stats.gravity
		var reach: float = run(stats, air)
		var lead: float = 0.0 if gap <= reach else (gap - reach) / stats.max_speed
		worst = maxf(worst, lead + air)
	return worst


## The soonest a lane's projectile can reach platform `index` after its marker appears: the telegraph plus the flight from the wall it comes from.
static func arrival_time(config: StageConfig, projectile_speed: float, arena_left: float, arena_right: float, center_x: float, index: int, side: int) -> float:
	var span: Vector2 = platform_span(config, center_x, index)
	var distance: float = span.x - arena_left if side < 0 else arena_right - span.y
	return config.lane_telegraph + maxf(distance, 0.0) / projectile_speed


# ---------------------------------------------------------------------------------------------
# The red eye's bolts
# ---------------------------------------------------------------------------------------------

## The safe lane (an x range kept free) for a player at `player_x` and two random numbers in [0, 1).
static func lane_for(arena_left: float, arena_right: float, player_x: float, roll_a: float, roll_b: float, min_lane_width: float, max_lane_offset: float) -> Vector2:
	var half: float = min_lane_width * 0.5
	var side: float = 1.0 if roll_a < 0.5 else -1.0
	var offset: float = lerpf(0.4, 1.0, roll_b) * max_lane_offset * side
	var center: float = clampf(player_x + offset, arena_left + half, arena_right - half)
	return Vector2(center - half, center + half)


## How far a diagonal bolt from the eye to the floor point `foot_x` reaches toward the eye at the height of a standing duck (px).
static func radial_shift(eye: Vector2, foot_x: float, floor_y: float) -> float:
	return (foot_x - eye.x) * BODY_HEIGHT / maxf(floor_y - eye.y, 1.0)


## The floor x range a diagonal bolt covers at the height of a duck: from its foot toward the eye, with the bolt half-width on both sides.
static func radial_footprint(eye: Vector2, foot_x: float, floor_y: float, bolt_width: float) -> Vector2:
	var shift: float = radial_shift(eye, foot_x, floor_y)
	var low: float = minf(foot_x, foot_x - shift) - bolt_width * 0.5
	var high: float = maxf(foot_x, foot_x - shift) + bolt_width * 0.5
	return Vector2(low, high)


## The bolts of one volley: `verticals` (center x of each column) and `radials` (floor x of each diagonal), all kept clear of the safe lane.
static func bolt_plan(config: StageConfig, arena_left: float, arena_right: float, eye: Vector2, floor_y: float, player_x: float, roll_a: float, roll_b: float) -> Dictionary:
	var lane: Vector2 = lane_for(arena_left, arena_right, player_x, roll_a, roll_b, config.min_lane_width, config.max_lane_offset)
	var spacing: float = config.bolt_width + config.min_lane_width * 0.5
	var taken: Array[Vector2] = []
	var verticals := PackedFloat32Array()
	var radials := PackedFloat32Array()
	var slots: Array[float] = []
	for k in 10:
		slots.append(lane.y + config.bolt_width * 0.5 + 20.0 + float(k) * spacing)
		slots.append(lane.x - config.bolt_width * 0.5 - 20.0 - float(k) * spacing)
	slots.sort_custom(func(a: float, b: float) -> bool: return absf(a - player_x) < absf(b - player_x))
	var want_vertical: int = config.vertical_bolts
	var want_radial: int = config.radial_bolts
	var turn: int = 0
	for x in slots:
		if want_vertical <= 0 and want_radial <= 0:
			break
		var use_radial: bool = (turn % 2 == 1 and want_radial > 0) or want_vertical <= 0
		var extent: Vector2 = Vector2(x - config.bolt_width * 0.5, x + config.bolt_width * 0.5)
		if use_radial:
			extent = radial_footprint(eye, x, floor_y, config.bolt_width)
		if extent.x < arena_left or extent.y > arena_right:
			continue
		if extent.y > lane.x - 12.0 and extent.x < lane.y + 12.0:
			continue
		var clash: bool = false
		for other in taken:
			if extent.y > other.x - 12.0 and extent.x < other.y + 12.0:
				clash = true
		if clash:
			continue
		taken.append(extent)
		if use_radial:
			radials.append(x)
			want_radial -= 1
		else:
			verticals.append(x)
			want_vertical -= 1
		turn += 1
	return {"lane": lane, "verticals": verticals, "radials": radials, "extents": taken}
