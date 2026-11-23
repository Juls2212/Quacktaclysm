class_name BossStageFx
extends Node2D
## Draws what the boss 3 stage does (Phase 15j), all by code and read-only: the floor that trembles (cracks, dust, a camera shake), crumbles and
## leaves a void edged with warning stripes, its shimmering outline just before it returns; the lane markers of the platform barrage
## (a stripe with chevrons that pulse and run toward where the projectile comes from, plus an exclamation at the wall: shape and pulse,
## not color alone); and the giant RED EYE of phase 3 with its red lightning (outlined columns and diagonal bolts announced with a rising
## stripe, then a white-hot core with a dark outline so it keeps its contrast against the arena and the possession tint).
## With «Efectos de corrupción» off (reduced) there are no particles, no shake, no pulses and no flash: the same shapes appear static.
## Child of the BossStage. It changes no gameplay value.

const INK := Color(0.106, 0.098, 0.122)
## The red palette of the eye (never the sword wave's): a white-hot core inside a dark outline, a red halo, a pale-red eye.
const BOLT_CORE := Color(1.0, 0.96, 0.82)
const BOLT_RED := Color(1.0, 0.18, 0.12)
## The announcement of a bolt: a lighter red so it reads over a dark red background too (its outline is almost black).
const BOLT_TELEGRAPH := Color(1.0, 0.52, 0.42)
const BOLT_OUTLINE := Color(0.1, 0.0, 0.02)
const EYE_WHITE := Color(1.0, 0.86, 0.82)
const EYE_IRIS := Color(0.86, 0.05, 0.06)
const LANE := Color(1.0, 0.62, 0.12)
const VOID := Color(0.03, 0.02, 0.05)
const MIN_FLASH_GAP: float = 0.34
const MAX_FLASH_ALPHA: float = 0.3
const KICK_GAP: float = 0.2

var reduced: bool = false
var flash_alpha: float = 0.0
var flashes_fired: int = 0
## Dust and crumbling chunks (a hard cap), the seconds since the floor came back and the cracks of the tremble.
var chunks: Array[Dictionary] = []
var returned_left: float = 0.0
var kicks_made: int = 0

var _stage: BossStage = null
var _clock: float = 0.0
var _last_floor: StringName = &"solid"
var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null
var _flash_gap_left: float = 0.0
var _flash_left: float = 0.0
var _kick_left: float = 0.0
var _was_striking: bool = false
var _fx: Node = null


func _ready() -> void:
	_stage = get_parent() as BossStage
	reduced = not GameSettings.is_corruption_effects_enabled()
	z_index = 8
	_build_flash()
	if _stage != null:
		var level: Node = _stage.get_parent().get_parent() if _stage.get_parent() != null else null
		_fx = level.get_node_or_null(^"BossFightFx") if level != null else null


func _process(delta: float) -> void:
	_clock += delta
	if _stage == null:
		return
	returned_left = maxf(returned_left - delta, 0.0)
	if _stage.floor_state != _last_floor:
		if _stage.floor_state == &"crumbling":
			_make_chunks()
		if _stage.floor_state == &"solid" and (_last_floor == &"shimmering" or _last_floor == &"gone"):
			returned_left = 0.5
		_last_floor = _stage.floor_state
	for chunk in chunks:
		chunk["pos"] = (chunk["pos"] as Vector2) + (chunk["vel"] as Vector2) * delta
		chunk["vel"] = (chunk["vel"] as Vector2) + Vector2(0.0, 1500.0) * delta
		chunk["life"] = float(chunk["life"]) - delta
	chunks = chunks.filter(func(c: Dictionary) -> bool: return float(c["life"]) > 0.0)
	_update_shake(delta)
	_update_flash(delta)
	queue_redraw()


# ---------------------------------------------------------------------------------------------
# Shake and flash
# ---------------------------------------------------------------------------------------------

func _update_shake(delta: float) -> void:
	_kick_left -= delta
	if reduced or _stage.floor_state != &"trembling" or _kick_left > 0.0:
		return
	_kick_left = KICK_GAP
	if _fx != null and _fx.has_method(&"kick"):
		_fx.call(&"kick", 0.5)
		kicks_made += 1


func _build_flash() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 90
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1.0, 0.25, 0.2, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_layer.add_child(_flash_rect)


## A red flash when a volley of bolts strikes (never above the cap, never more often than MIN_FLASH_GAP, none in reduced mode).
func _flash() -> void:
	if reduced or _flash_gap_left > 0.0:
		return
	_flash_gap_left = MIN_FLASH_GAP
	_flash_left = 0.18
	flashes_fired += 1


func _update_flash(delta: float) -> void:
	_flash_gap_left = maxf(_flash_gap_left - delta, 0.0)
	_flash_left = maxf(_flash_left - delta, 0.0)
	var striking: bool = _stage.eye != null and _stage.eye.is_striking()
	if striking and not _was_striking:
		_flash()
	_was_striking = striking
	flash_alpha = MAX_FLASH_ALPHA * clampf(_flash_left / 0.18, 0.0, 1.0)
	_flash_rect.color.a = flash_alpha


# ---------------------------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------------------------

func _draw() -> void:
	if _stage == null or _stage.config == null:
		return
	_draw_eye()
	_draw_floor()
	_draw_lanes()
	_draw_bolt_telegraphs()


func _make_chunks() -> void:
	chunks.clear()
	if reduced:
		return
	for i in 26:
		var x: float = lerpf(_stage.arena_left, _stage.arena_right, float(i) / 25.0) + randf_range(-20.0, 20.0)
		chunks.append({"pos": Vector2(x, _stage.floor_top + randf_range(0.0, 30.0)), "vel": Vector2(randf_range(-60.0, 60.0), randf_range(-80.0, 40.0)), "life": randf_range(0.8, 1.4), "size": randf_range(8.0, 22.0)})


func _draw_floor() -> void:
	var left: float = _stage.arena_left
	var right: float = _stage.arena_right
	var top: float = _stage.floor_top
	var state: StringName = _stage.floor_state
	var config: StageConfig = _stage.config
	if state == &"trembling":
		# Cracks that grow over the tremble: jagged dark lines with a pale edge (shape, not color alone).
		var k: float = clampf(_stage.floor_state_time / config.tremble_time, 0.0, 1.0)
		for i in 9:
			var x: float = lerpf(left + 40.0, right - 40.0, float(i) / 8.0)
			var length: float = 38.0 * k * (0.5 + 0.5 * sin(float(i) * 2.1 + 1.0) * 0.5 + 0.25)
			var jitter: float = 0.0 if reduced else sin(_clock * 40.0 + float(i)) * 1.5 * k
			var pts := PackedVector2Array([Vector2(x, top), Vector2(x + 7.0 + jitter, top + length * 0.35), Vector2(x - 5.0, top + length * 0.7), Vector2(x + 4.0, top + length)])
			draw_polyline(pts, Color(0.95, 0.9, 0.8, 0.7), 5.0, true)
			draw_polyline(pts, INK, 3.0, true)
		if not reduced:
			for i in 14:
				var dx: float = lerpf(left, right, fposmod(float(i) * 0.137 + _clock * 0.3, 1.0))
				draw_circle(Vector2(dx, top - 4.0 - fposmod(_clock * 40.0 + float(i) * 9.0, 22.0)), 2.0, Color(0.8, 0.75, 0.65, 0.5 * k))
	elif state == &"crumbling":
		# Dark gaps eat the floor from the middle outward while chunks fall.
		var k: float = clampf(_stage.floor_state_time / config.crumble_time, 0.0, 1.0)
		var middle: float = (left + right) * 0.5
		var half: float = (right - left) * 0.5 * k
		draw_rect(Rect2(middle - half, top - 2.0, half * 2.0, 46.0), VOID)
		for chunk in chunks:
			var at: Vector2 = chunk["pos"]
			var s: float = float(chunk["size"])
			draw_colored_polygon(PackedVector2Array([at + Vector2(-s, -s * 0.5), at + Vector2(s, -s * 0.7), at + Vector2(s * 0.7, s * 0.6), at + Vector2(-s * 0.6, s)]), Color(0.3, 0.25, 0.3))
	if state == &"crumbling" or state == &"gone" or state == &"shimmering":
		# The void: dark, edged with warning stripes along where the floor was, so it reads as a hazard by shape.
		if state != &"crumbling":
			draw_rect(Rect2(left, top - 2.0, right - left, 720.0), VOID)
		var x: float = left
		while x < right:
			draw_colored_polygon(PackedVector2Array([Vector2(x, top - 2.0), Vector2(x + 14.0, top - 2.0), Vector2(x + 20.0, top + 8.0), Vector2(x + 6.0, top + 8.0)]), Color(LANE, 0.85))
			x += 34.0
	if state == &"shimmering":
		# The outline of the floor that comes back: a dashed pulsing line and a faint ghost slab.
		var pulse: float = 1.0 if reduced else 0.55 + 0.45 * sin(_clock * 14.0)
		draw_rect(Rect2(left, top, right - left, 40.0), Color(0.9, 0.95, 1.0, 0.12 * pulse))
		_dashed(Vector2(left, top), Vector2(right, top), Color(0.95, 0.97, 1.0, 0.95 * pulse), 4.0)
		_dashed(Vector2(left, top + 40.0), Vector2(right, top + 40.0), Color(0.95, 0.97, 1.0, 0.6 * pulse), 3.0)
	if returned_left > 0.0 and not reduced:
		draw_line(Vector2(left, top), Vector2(right, top), Color(1.0, 1.0, 1.0, 0.6 * returned_left / 0.5), 5.0)


func _dashed(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var length: float = from.distance_to(to)
	var direction: Vector2 = (to - from) / maxf(length, 0.001)
	var at: float = 0.0
	while at < length:
		var end: float = minf(at + 18.0, length)
		draw_line(from + direction * at, from + direction * end, Color(INK, color.a), width + 2.5)
		draw_line(from + direction * at, from + direction * end, color, width)
		at += 30.0


## The lane markers of the barrage: a pulsing stripe across the arena at the height of the platform, chevrons running toward where the
## projectile will go, and an exclamation mark at the wall it comes from.
func _draw_lanes() -> void:
	if _stage.barrage == null:
		return
	var state: Dictionary = _stage.barrage.get_draw_state()
	for lane: Dictionary in state["lanes"]:
		var y: float = StageMath.lane_y(_stage.config, _stage.floor_top, int(lane["lane"]))
		var side: int = int(lane["side"])
		var progress: float = float(lane["progress"])
		var pulse: float = 1.0 if reduced else 0.55 + 0.45 * sin(_clock * (8.0 + 14.0 * progress))
		var left: float = _stage.arena_left
		var right: float = _stage.arena_right
		var alpha: float = (0.35 + 0.6 * progress) * pulse
		draw_rect(Rect2(left, y - 18.0, right - left, 36.0), Color(LANE, 0.10 + 0.14 * progress))
		_dashed(Vector2(left, y - 18.0), Vector2(right, y - 18.0), Color(LANE, alpha), 3.0)
		_dashed(Vector2(left, y + 18.0), Vector2(right, y + 18.0), Color(LANE, alpha), 3.0)
		var direction: float = 1.0 if side < 0 else -1.0
		var step: float = 70.0
		var offset: float = 0.0 if reduced else fposmod(_clock * 160.0, step)
		var x: float = left + offset if direction > 0.0 else right - offset
		while x > left and x < right:
			_chevron(Vector2(x, y), direction, 13.0, Color(LANE, alpha))
			x += direction * step
		var wall_x: float = left + 18.0 if side < 0 else right - 18.0
		_exclamation(Vector2(wall_x, y), Color(LANE, minf(alpha + 0.3, 1.0)))


func _chevron(at: Vector2, direction: float, size: float, color: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(-direction * size, -size), at + Vector2(direction * size * 0.4, 0.0), at + Vector2(-direction * size, size)])
	draw_polyline(pts, INK, 7.0, true)
	draw_polyline(pts, color, 4.0, true)


func _exclamation(at: Vector2, color: Color) -> void:
	draw_circle(at, 17.0, INK)
	draw_circle(at, 14.0, color)
	draw_rect(Rect2(at + Vector2(-2.0, -9.0), Vector2(4.0, 11.0)), INK)
	draw_circle(at + Vector2(0.0, 7.0), 2.4, INK)


## The red eye: appears in the sky above the arena, watches the player, pulses; its bolts are drawn here too.
func _draw_eye() -> void:
	var eye: StormEye = _stage.eye
	if eye == null or not eye.is_active():
		return
	var state: Dictionary = eye.get_draw_state()
	var appear: float = float(state["appear"])
	if appear <= 0.01:
		return
	var center: Vector2 = state["center"]
	var radius: float = float(state["radius"]) * (0.6 + 0.4 * appear)
	var pulse: float = 1.0 if reduced else 0.5 + 0.5 * sin(_clock * 3.2)
	for i in 4:
		draw_circle(center, radius * (1.9 - 0.25 * float(i)) * (1.0 + 0.03 * pulse), Color(BOLT_RED, (0.04 + 0.025 * float(i)) * appear))
	draw_set_transform(center, 0.0, Vector2(1.0, 0.78))
	draw_circle(Vector2.ZERO, radius + 7.0, Color(BOLT_OUTLINE, 0.95 * appear))
	draw_circle(Vector2.ZERO, radius, Color(EYE_WHITE, appear))
	for i in 14:
		var angle: float = float(i) * TAU / 14.0 + 0.2
		var inner: float = radius * (0.45 + 0.1 * sin(float(i) * 3.0))
		var pts := PackedVector2Array([Vector2(cos(angle), sin(angle)) * radius * 0.98, Vector2(cos(angle + 0.06), sin(angle + 0.06)) * radius * 0.7, Vector2(cos(angle - 0.04), sin(angle - 0.04)) * inner])
		draw_polyline(pts, Color(0.72, 0.05, 0.08, 0.85 * appear), 2.2, true)
	var gaze: Vector2 = Vector2.ZERO
	if _stage.boss != null and _stage.boss.is_target_valid():
		gaze = ((_stage.boss.target.global_position - center) / 500.0).limit_length(1.0) * radius * 0.2
	draw_circle(gaze, radius * 0.5 + 5.0, Color(BOLT_OUTLINE, appear))
	draw_circle(gaze, radius * 0.5, Color(EYE_IRIS, appear))
	draw_circle(gaze, radius * 0.34, Color(1.0, 0.3, 0.15, appear))
	var slit: float = 1.0 if reduced else 0.85 + 0.15 * pulse
	draw_colored_polygon(PackedVector2Array([gaze + Vector2(0.0, -radius * 0.48 * slit), gaze + Vector2(radius * 0.09, 0.0), gaze + Vector2(0.0, radius * 0.48 * slit), gaze + Vector2(-radius * 0.09, 0.0)]), Color(BOLT_OUTLINE, appear))
	draw_circle(gaze + Vector2(-radius * 0.14, -radius * 0.16), radius * 0.07, Color(1.0, 1.0, 1.0, 0.9 * appear))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if int(state["phase"]) == StormEye.Phase.STRIKE:
		_draw_strike(state)


func _bolt_line(a: Vector2, b: Vector2, width: float) -> void:
	var pts := PackedVector2Array([a])
	var steps: int = 6
	for i in range(1, steps):
		var k: float = float(i) / float(steps)
		var jitter: float = 0.0 if reduced else sin(_clock * 60.0 + float(i) * 2.0) * width * 0.35
		pts.append(a.lerp(b, k) + (b - a).orthogonal().normalized() * jitter)
	pts.append(b)
	draw_polyline(pts, BOLT_OUTLINE, width + 8.0, true)
	draw_polyline(pts, BOLT_RED, width + 2.0, true)
	draw_polyline(pts, BOLT_CORE, maxf(width * 0.45, 3.0), true)


func _draw_strike(state: Dictionary) -> void:
	var plan: Dictionary = state["plan"]
	if plan.is_empty():
		return
	var floor_y: float = float(state["floor"])
	var top: float = float(state["top"])
	var width: float = float(state["width"])
	var center: Vector2 = state["center"]
	for x in plan["verticals"] as PackedFloat32Array:
		_bolt_line(Vector2(x, top), Vector2(x, floor_y), width * 0.6)
	for x in plan["radials"] as PackedFloat32Array:
		_bolt_line(center, Vector2(x, floor_y), width * 0.45)


## The announced bolts: outlined columns with a rising stripe, and dashed diagonals with a marker at their foot (shape and pulse).
func _draw_bolt_telegraphs() -> void:
	var eye: StormEye = _stage.eye
	if eye == null or eye.phase != StormEye.Phase.TELEGRAPH:
		return
	var state: Dictionary = eye.get_draw_state()
	var plan: Dictionary = state["plan"]
	if plan.is_empty():
		return
	var progress: float = float(state["progress"])
	var floor_y: float = float(state["floor"])
	var top: float = float(state["top"])
	var width: float = float(state["width"])
	var center: Vector2 = state["center"]
	var pulse: float = 1.0 if reduced else 0.55 + 0.45 * sin(_clock * (6.0 + 16.0 * progress))
	var alpha: float = (0.4 + 0.55 * progress) * pulse
	for x in plan["verticals"] as PackedFloat32Array:
		var rect := Rect2(x - width * 0.5, top, width, floor_y - top)
		draw_rect(rect, Color(BOLT_TELEGRAPH, 0.08 + 0.14 * progress))
		draw_rect(rect, Color(BOLT_OUTLINE, 0.9), false, 5.0)
		draw_rect(rect, Color(BOLT_TELEGRAPH, alpha), false, 2.5)
		var stripe_y: float = floor_y - (floor_y - top) * progress
		draw_rect(Rect2(x - width * 0.5, stripe_y, width, 10.0), Color(BOLT_TELEGRAPH, alpha))
		_exclamation(Vector2(x, floor_y - 30.0), Color(BOLT_TELEGRAPH, minf(alpha + 0.3, 1.0)))
	for x in plan["radials"] as PackedFloat32Array:
		var foot := Vector2(x, floor_y)
		_dashed(center, foot, Color(BOLT_TELEGRAPH, alpha), 3.0)
		draw_circle(foot, 20.0, BOLT_OUTLINE)
		draw_circle(foot, 16.0, Color(BOLT_TELEGRAPH, alpha))
		draw_circle(foot, 7.0, Color(BOLT_CORE, alpha))
