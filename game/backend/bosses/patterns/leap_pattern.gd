class_name LeapPattern
extends BossPattern
## The swamp guardian leaps (Phase 15c). Data-driven like the other patterns, on the same state machine:
##   telegraph  crouch (`telegraph_time`) while a landing marker is drawn on the spot it will land on,
##   active     a ballistic jump to an anchor (a BossAnchor of the level: a platform, no pathfinding),
##   perch      stays there and fires the volley (`volley`, a ProjectileVolleyPattern child that never starts by
##              itself) aimed down at the player; the marker shows where it will come down next,
##   return     a second ballistic jump to another anchor (usually the floor near the player),
##   recovery   stopped and vulnerable (`recovery_time`).
## Each landing is a small area of contact damage (`landing_hitbox`, active for `landing_active_time`) that the
## marker announced. The boss can be hit all the time (armor rules are untouched). Cancel (phase change, death,
## reset) stops the leap, hides the marker, switches the hitbox and the volley off and leaves nothing behind.
## Flights end by LANDING, not by a timer, so the aggression multiplier cannot cut a jump short; `flight_timeout_factor`
## is only a safety net. All numbers are exported.

## Where the first jump goes (Phase 15d-bis): PLATFORM is the normal leap (a platform anchor, then the perch);
## NEAREST_TO_PLAYER goes to the anchor closest to the player whatever its tier; FLOOR goes down to the floor anchor
## closest to the player (the stomp).
enum TargetMode { PLATFORM, NEAREST_TO_PLAYER, FLOOR }

const PHASE_PERCH: StringName = &"perch"
const PHASE_RETURN: StringName = &"return"

## A jump begins: from, to (boss body positions).
signal leap_started(from: Vector2, to: Vector2)
## The boss touched down after a jump.
signal landed(position: Vector2)
## The landing marker moves or goes away (world position of the spot on the floor).
signal marker_changed(world_position: Vector2, shown: bool)

@export var landing_hitbox: Hitbox
## The volley used on the perch (a sibling pattern with min_phase above max_phase, so it never starts alone).
@export var volley: ProjectileVolleyPattern
@export var anchor_group: StringName = BossAnchor.GROUP
@export var target_mode: TargetMode = TargetMode.PLATFORM
## true: after the landing the pattern goes straight to its recovery (no perch, no volley, no second jump): the stomp.
@export var skip_perch: bool = false
## The apex of a jump is this far above the higher of the two spots.
@export_range(0.0, 400.0, 1.0, "suffix:px") var apex_clearance: float = 60.0
## Anchors that need a bigger rise than this are never chosen.
@export_range(0.0, 800.0, 1.0, "suffix:px") var max_rise: float = 340.0
## Seconds the landing hitbox stays on after a touchdown.
@export_range(0.05, 1.0, 0.01, "suffix:s") var landing_active_time: float = 0.2
## Chance (0-1) that the first anchor is the platform nearest to the player; otherwise a random platform.
@export_range(0.0, 1.0, 0.05) var aim_at_player_chance: float = 0.7
## A jump is abandoned if it has not landed after this many times the expected flight time.
@export_range(1.5, 10.0, 0.1) var flight_timeout_factor: float = 3.0
## Ignored anchors closer than this to the boss (a leap must go somewhere).
@export_range(0.0, 600.0, 1.0, "suffix:px") var min_leap_distance: float = 120.0

## Test hooks: when set (not Vector2.INF) they replace the random choice of the first and the return spot.
var forced_first: Vector2 = Vector2.INF
var forced_return: Vector2 = Vector2.INF

## Where the boss is heading in the current jump (body center), and the marked spot on the floor.
var destination: Vector2 = Vector2.ZERO
var marker_position: Vector2 = Vector2.ZERO
var marker_visible: bool = false
var last_flight_time: float = 0.0
var leaps_made: int = 0

var _vx: float = 0.0
var _vy0: float = 0.0
var _flight_elapsed: float = 0.0
var _flight_expected: float = 1.0
var _landing_left: float = 0.0
var _return_anchor_position: Vector2 = Vector2.ZERO
var _first_anchor_position: Vector2 = Vector2.ZERO
var _volley_running: bool = false


func can_start(boss: BossBase) -> bool:
	if not super.can_start(boss):
		return false
	if not boss.is_on_floor() or not boss.is_target_valid():
		return false
	return _pick_first(boss, false) != Vector2.INF


func can_start_fallback(boss: BossBase, ignore_cooldown: bool) -> bool:
	if not super.can_start_fallback(boss, ignore_cooldown):
		return false
	return boss.is_on_floor() and boss.is_target_valid() and _pick_first(boss, false) != Vector2.INF


func _active_duration() -> float:
	return maxf(_flight_expected * flight_timeout_factor, 1.0)


func _phase_duration(phase: StringName) -> float:
	match phase:
		PHASE_PERCH:
			# Ends when the volley is over; this is only a safety net.
			return 8.0
		PHASE_RETURN:
			return _active_duration()
	return super._phase_duration(phase)


func _next_phase(current: StringName) -> StringName:
	match current:
		PHASE_TELEGRAPH:
			return PHASE_ACTIVE
		PHASE_ACTIVE:
			return PHASE_RECOVERY if skip_perch else PHASE_PERCH
		PHASE_PERCH:
			return PHASE_RETURN
		PHASE_RETURN:
			return PHASE_RECOVERY
	return &""


func _on_phase_entered(boss: BossBase, entered: StringName) -> void:
	match entered:
		PHASE_TELEGRAPH:
			boss.velocity.x = 0.0
			_first_anchor_position = _pick_first(boss, true)
			if _first_anchor_position == Vector2.INF:
				_first_anchor_position = boss.global_position
			_plan_flight(boss, _first_anchor_position)
			boss.face_towards(_first_anchor_position.x)
			_show_marker(boss, _first_anchor_position)
		PHASE_ACTIVE:
			_begin_flight(boss, _first_anchor_position)
		PHASE_PERCH:
			boss.velocity.x = 0.0
			_return_anchor_position = _pick_return(boss)
			_show_marker(boss, _return_anchor_position)
			_start_volley(boss)
		PHASE_RETURN:
			_stop_volley(boss)
			_plan_flight(boss, _return_anchor_position)
			boss.face_towards(_return_anchor_position.x)
			_begin_flight(boss, _return_anchor_position)
		PHASE_RECOVERY:
			boss.velocity.x = 0.0


func _on_phase_update(boss: BossBase, delta: float) -> void:
	if _landing_left > 0.0:
		_landing_left -= delta
		if _landing_left <= 0.0 and landing_hitbox != null:
			landing_hitbox.deactivate()
	match phase_name:
		PHASE_TELEGRAPH, PHASE_RECOVERY:
			boss.velocity.x = 0.0
		PHASE_ACTIVE, PHASE_RETURN:
			_flight_elapsed += delta
			boss.velocity.x = _vx
			# It has come down: end the flight now (the timeline moves on to the next phase).
			if _flight_elapsed > 0.1 and boss.is_on_floor() and boss.velocity.y >= 0.0:
				_touch_down(boss)
				_phase_left = 0.0
		PHASE_PERCH:
			boss.velocity.x = 0.0
			if volley != null and _volley_running:
				volley.physics_update(boss, delta)
				if volley.is_finished():
					_volley_running = false
					_phase_left = 0.0
			elif not _volley_running:
				_phase_left = 0.0


func _on_phase_exited(boss: BossBase, exited: StringName) -> void:
	if exited == PHASE_ACTIVE or exited == PHASE_RETURN:
		boss.velocity.x = 0.0
		_hide_marker(boss)
	elif exited == PHASE_PERCH:
		_stop_volley(boss)


func _on_cancel(boss: BossBase) -> void:
	if landing_hitbox != null:
		landing_hitbox.deactivate()
	_landing_left = 0.0
	_stop_volley(boss)
	_hide_marker(boss)
	boss.velocity.x = 0.0


# ---------------------------------------------------------------------------------------------
# Choosing the anchors
# ---------------------------------------------------------------------------------------------

func _anchors(boss: BossBase) -> Array[BossAnchor]:
	var result: Array[BossAnchor] = []
	for node in boss.get_tree().get_nodes_in_group(anchor_group):
		var anchor := node as BossAnchor
		if anchor != null and boss.get_parent() != null and boss.get_parent().is_ancestor_of(anchor):
			result.append(anchor)
	return result


## The platform anchor to jump to (or Vector2.INF if there is none). `roll` false does not use the random numbers
## (can_start must not consume them).
func _pick_first(boss: BossBase, roll: bool) -> Vector2:
	if forced_first != Vector2.INF:
		return forced_first
	var best: Vector2 = Vector2.INF
	var options: Array[Vector2] = []
	var target_x: float = boss.target.global_position.x if boss.is_target_valid() else boss.global_position.x
	for anchor in _anchors(boss):
		if target_mode == TargetMode.PLATFORM and anchor.tier != BossAnchor.Tier.PLATFORM:
			continue
		if target_mode == TargetMode.FLOOR and anchor.tier != BossAnchor.Tier.FLOOR:
			continue
		if boss.global_position.y - anchor.global_position.y > max_rise:
			continue
		if boss.global_position.distance_to(anchor.global_position) < min_leap_distance:
			continue
		options.append(anchor.global_position)
		if best == Vector2.INF or absf(anchor.global_position.x - target_x) < absf(best.x - target_x):
			best = anchor.global_position
	if options.is_empty():
		return Vector2.INF
	if target_mode != TargetMode.PLATFORM:
		return best
	if roll and options.size() > 1 and boss.roll() > aim_at_player_chance:
		return options[int(boss.roll() * float(options.size())) % options.size()]
	return best


## Where to come down: usually the floor anchor nearest to the player, sometimes any other anchor.
func _pick_return(boss: BossBase) -> Vector2:
	if forced_return != Vector2.INF:
		return forced_return
	var target_x: float = boss.target.global_position.x if boss.is_target_valid() else boss.global_position.x
	var floors: Array[Vector2] = []
	var others: Array[Vector2] = []
	for anchor in _anchors(boss):
		var position: Vector2 = anchor.global_position
		if position.distance_to(boss.global_position) < min_leap_distance:
			continue
		if anchor.tier == BossAnchor.Tier.FLOOR:
			floors.append(position)
		else:
			others.append(position)
	if floors.is_empty() and others.is_empty():
		return boss.global_position
	var pool: Array[Vector2] = floors if not floors.is_empty() else others
	var nearest: Vector2 = pool[0]
	for position in pool:
		if absf(position.x - target_x) < absf(nearest.x - target_x):
			nearest = position
	if boss.roll() < 0.65 or pool.size() < 2:
		return nearest
	return pool[int(boss.roll() * float(pool.size())) % pool.size()]


# ---------------------------------------------------------------------------------------------
# The ballistic jump
# ---------------------------------------------------------------------------------------------

## Works out the launch speed and the flight time from the boss' gravity (a small simulation with the same
## fall-speed cap and the same fixed time step as the physics, so the boss lands on the anchor).
func _plan_flight(boss: BossBase, to: Vector2) -> void:
	var from: Vector2 = boss.global_position
	var gravity: float = boss.stats.gravity
	var apex_y: float = minf(from.y, to.y) - apex_clearance
	_vy0 = -sqrt(2.0 * gravity * maxf(from.y - apex_y, 1.0))
	var step: float = 1.0 / float(Engine.physics_ticks_per_second)
	var y: float = from.y
	var vy: float = _vy0
	var time: float = 0.0
	while time < 10.0:
		vy = minf(vy + gravity * step, boss.stats.max_fall_speed)
		y += vy * step
		time += step
		if vy > 0.0 and y >= to.y:
			break
	_flight_expected = maxf(time, step)
	_vx = (to.x - from.x) / _flight_expected
	destination = to


func _begin_flight(boss: BossBase, to: Vector2) -> void:
	destination = to
	_flight_elapsed = 0.0
	boss.velocity = Vector2(_vx, _vy0)
	leaps_made += 1
	leap_started.emit(boss.global_position, to)


func _touch_down(boss: BossBase) -> void:
	last_flight_time = _flight_elapsed
	boss.velocity.x = 0.0
	if landing_hitbox != null:
		landing_hitbox.activate()
		_landing_left = landing_active_time
	landed.emit(boss.global_position)


# ---------------------------------------------------------------------------------------------
# The volley on the perch and the marker
# ---------------------------------------------------------------------------------------------

func _start_volley(boss: BossBase) -> void:
	_volley_running = false
	if volley == null:
		return
	volley.start(boss)
	_volley_running = true


func _stop_volley(boss: BossBase) -> void:
	if volley != null and _volley_running:
		volley.cancel(boss)
	_volley_running = false


func _show_marker(boss: BossBase, body_position: Vector2) -> void:
	marker_position = Vector2(body_position.x, body_position.y + _foot_offset(boss))
	marker_visible = true
	marker_changed.emit(marker_position, true)


func _hide_marker(_boss: BossBase) -> void:
	if marker_visible:
		marker_visible = false
		marker_changed.emit(marker_position, false)


## Distance from the body center to the soles of the boss.
func _foot_offset(boss: BossBase) -> float:
	var rect := boss.body_shape.shape as RectangleShape2D
	if rect != null:
		return boss.body_shape.position.y + rect.size.y * 0.5
	return 44.0
