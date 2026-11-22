class_name StormFx
extends Node2D
## The drawing of the storm patterns of boss 3 (Phase 15e-1), all by code: the floor lane and the beam of the sweeping beam, the
## telegraph and the strike of the lightning columns, and the short screen flash of a strike. Child of the boss (top level, in
## world coordinates). It only READS the patterns (`get_draw_state()`) and the telegraph styles `boss_beam` / `boss_columns` of
## default_telegraphs.tres; it changes no gameplay value.
## Readability: every warning has a SHAPE as well as a color (a dark outline, a dashed border, chevrons running along the lane or
## rising stripes in the column, and an exclamation mark), so it does not depend on color alone. Colors are the cool storm white
## and pale blue, never the orange-red of the enemy projectiles.
## Photosensitivity: at most one flash per strike, never brighter than `flash_cap` (the 0.3 cap of the possession sequence), at
## least `MIN_FLASH_GAP` s apart (so no more than 3 a second), and none at all with the "Efectos de corrupción" option off.

const MIN_FLASH_GAP: float = 0.34
const WHITE := Color(0.96, 0.98, 1.0)
const BOLT_GLOW := Color(0.7, 0.85, 1.0)
const INK := Color(0.106, 0.098, 0.122)

var _boss: BossBase = null
var _telegraphs: TelegraphSet = null
var _clock: float = 0.0
var _flash_left: float = 0.0
var _flash_gap_left: float = 0.0
var _flash_layer: CanvasLayer = null
var _flash_rect: ColorRect = null
var _was_striking: bool = false
var _reduced: bool = false
## Flashes fired (the tests read it) and the opacity of the one now showing.
var flashes_fired: int = 0
var flash_alpha: float = 0.0


func _ready() -> void:
	_boss = get_parent() as BossBase
	top_level = true
	z_index = 30
	_telegraphs = TelegraphSet.get_default()
	_reduced = not GameSettings.is_corruption_effects_enabled()
	_build_flash()


func _process(delta: float) -> void:
	_clock += delta
	_flash_gap_left = maxf(_flash_gap_left - delta, 0.0)
	_update_flash(delta)
	queue_redraw()


func _draw() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var striking: bool = false
	for pattern in _boss.patterns:
		if not pattern.has_method(&"get_draw_state"):
			continue
		var state: Dictionary = pattern.call(&"get_draw_state")
		var phase: StringName = state["phase"]
		if phase == &"":
			continue
		if state["kind"] == &"beam":
			_draw_beam(state)
		elif state["kind"] == &"columns":
			striking = striking or bool(state["striking"])
			_draw_columns(state)
	if striking and not _was_striking:
		_flash()
	_was_striking = striking


func _style(kind: StringName) -> TelegraphStyle:
	return _telegraphs.get_style(kind) if _telegraphs != null else null


# ---------------------------------------------------------------------------------------------
# The beam
# ---------------------------------------------------------------------------------------------

func _draw_beam(state: Dictionary) -> void:
	var style: TelegraphStyle = _style(TelegraphSet.KIND_BOSS_BEAM)
	if style == null:
		return
	var left: float = state["left"]
	var right: float = state["right"]
	var floor_y: float = state["floor"]
	var height: float = state["height"]
	var direction: float = float(state["direction"])
	var pulse: float = 0.5 + 0.5 * sin(_clock * 9.0)
	if state["phase"] == BossPattern.PHASE_TELEGRAPH:
		var progress: float = state["progress"]
		var lane := Rect2(left, floor_y - height, right - left, height)
		draw_rect(lane, Color(style.color, 0.12 + 0.14 * pulse))
		# A dashed ink border and chevrons that run along the lane (the warning does not depend on color).
		_dashed_rect(lane, INK, 3.0)
		_dashed_rect(lane.grow(-2.0), Color(style.color, 0.9), 2.0)
		var spacing: float = 54.0
		var travel: float = fposmod(_clock * 160.0, spacing)
		var x: float = left + travel if direction > 0.0 else right - travel
		while x > left and x < right:
			_chevron(Vector2(x, floor_y - height * 0.5), direction, height * 0.34, style.color)
			x += direction * spacing
		# The start end fills up as the time runs out.
		var start_x: float = left if direction > 0.0 else right
		draw_rect(Rect2(start_x if direction > 0.0 else start_x - 56.0 * progress, floor_y - height, 56.0 * progress, height), Color(style.color, 0.6))
		_exclamation(Vector2(start_x + direction * 30.0, floor_y - height - 26.0), style.color)
	elif bool(state["visible"]):
		var length: float = state["length"]
		var center: float = state["center"]
		var beam := Rect2(center - length * 0.5, floor_y - height, length, height)
		draw_rect(beam.grow(10.0), Color(BOLT_GLOW, 0.22 + 0.1 * pulse))
		draw_rect(beam.grow(3.0), INK)
		draw_rect(beam, WHITE)
		draw_rect(Rect2(beam.position + Vector2(0.0, height * 0.3), Vector2(length, height * 0.4)), Color(BOLT_GLOW, 0.95))
		# A trail behind the beam.
		for i in 6:
			var t: float = float(i + 1) / 6.0
			draw_rect(Rect2(center - length * 0.5 - direction * (24.0 * float(i + 1)) - (0.0 if direction < 0.0 else 18.0), floor_y - height * (1.0 - 0.1 * float(i)), 18.0, height * (1.0 - 0.1 * float(i))), Color(BOLT_GLOW, 0.4 * (1.0 - t)))


func _chevron(at: Vector2, direction: float, size: float, color: Color) -> void:
	var points := PackedVector2Array([at + Vector2(-direction * size, -size), at + Vector2(direction * size * 0.4, 0.0), at + Vector2(-direction * size, size)])
	draw_polyline(points, INK, 4.5, true)
	draw_polyline(points, color, 2.5, true)


# ---------------------------------------------------------------------------------------------
# The columns
# ---------------------------------------------------------------------------------------------

func _draw_columns(state: Dictionary) -> void:
	var style: TelegraphStyle = _style(TelegraphSet.KIND_BOSS_COLUMNS)
	if style == null:
		return
	var xs: PackedFloat32Array = state["xs"]
	var width: float = state["width"]
	var floor_y: float = state["floor"]
	var top: float = state["top"]
	var pulse: float = 0.5 + 0.5 * sin(_clock * 10.0)
	var progress: float = state["progress"]
	for x in xs:
		var rect := Rect2(x - width * 0.5, top, width, floor_y - top)
		if state["phase"] == BossPattern.PHASE_TELEGRAPH:
			draw_rect(rect, Color(style.color, 0.1 + 0.12 * pulse))
			# Stripes that rise up the column, a dashed border and an exclamation mark at the floor.
			var stripe: float = 36.0
			var offset: float = fposmod(_clock * 120.0, stripe)
			var y: float = floor_y - offset
			while y > top:
				draw_line(Vector2(rect.position.x + 4.0, y), Vector2(rect.end.x - 4.0, y), Color(style.color, 0.7), 3.0)
				y -= stripe
			_dashed_rect(rect, INK, 3.5)
			_dashed_rect(rect.grow(-2.0), Color(style.color, 0.95), 2.0)
			# A tall bar fills from the floor as the strike gets closer.
			var fill_h: float = (floor_y - top) * progress * 0.18
			draw_rect(Rect2(rect.position.x, floor_y - fill_h, width, fill_h), Color(style.color, 0.55))
			_exclamation(Vector2(x, floor_y - 34.0), style.color)
		elif state["phase"] == BossPattern.PHASE_ACTIVE:
			draw_rect(rect.grow(14.0), Color(BOLT_GLOW, 0.2))
			draw_rect(rect.grow(2.0), INK)
			draw_rect(rect, WHITE)
			_bolt(x, top, floor_y, width)
		else:
			draw_rect(Rect2(x - 4.0, top, 8.0, floor_y - top), Color(BOLT_GLOW, 0.18 * (1.0 - progress)))
	# The safe lane is marked with two small floor arrows (a lane exists, always).
	if state["phase"] == BossPattern.PHASE_TELEGRAPH:
		var lane: Vector2 = state["lane"]
		var center: float = (lane.x + lane.y) * 0.5
		_floor_arrows(center, floor_y, style.color)


func _bolt(x: float, top: float, floor_y: float, width: float) -> void:
	var points := PackedVector2Array()
	var steps: int = 9
	for i in steps + 1:
		var t: float = float(i) / float(steps)
		var jitter: float = sin(_clock * 40.0 + float(i) * 2.3) * width * 0.28 * (0.3 + 0.7 * sin(t * PI))
		points.append(Vector2(x + jitter, lerpf(top, floor_y, t)))
	draw_polyline(points, INK, 7.0, true)
	draw_polyline(points, BOLT_GLOW, 4.0, true)
	draw_polyline(points, WHITE, 1.8, true)


func _floor_arrows(center: float, floor_y: float, color: Color) -> void:
	for side in [-1.0, 1.0]:
		var tip := Vector2(center + side * 8.0, floor_y - 10.0)
		var points := PackedVector2Array([tip + Vector2(side * 16.0, -8.0), tip, tip + Vector2(side * 16.0, 8.0)])
		draw_polyline(points, INK, 4.5, true)
		draw_polyline(points, color, 2.5, true)


func _dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	var dash: float = 14.0
	var gap: float = 9.0
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var length: float = a.distance_to(b)
		var direction: Vector2 = (b - a) / maxf(length, 0.001)
		var along: float = fposmod(_clock * 30.0, dash + gap) - (dash + gap)
		while along < length:
			var start: float = maxf(along, 0.0)
			var finish: float = minf(along + dash, length)
			if finish > start:
				draw_line(a + direction * start, a + direction * finish, color, width)
			along += dash + gap


func _exclamation(at: Vector2, color: Color) -> void:
	draw_circle(at, 13.0, Color(INK, 0.85))
	draw_circle(at, 11.0, color)
	draw_line(at + Vector2(0.0, -6.0), at + Vector2(0.0, 2.0), INK, 3.0)
	draw_circle(at + Vector2(0.0, 6.5), 1.8, INK)


# ---------------------------------------------------------------------------------------------
# The flash
# ---------------------------------------------------------------------------------------------

func _build_flash() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 56
	add_child(_flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(0.85, 0.92, 1.0, 0.0)
	_flash_layer.add_child(_flash_rect)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _flash() -> void:
	if _reduced or _flash_gap_left > 0.0:
		return
	var cap: float = PossessionConfig.get_default().flash_alpha_cap
	flash_alpha = minf(cap, 0.3)
	_flash_left = 0.18
	_flash_gap_left = MIN_FLASH_GAP
	flashes_fired += 1


func _update_flash(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
	var k: float = _flash_left / 0.18
	var current: float = flash_alpha * k
	_flash_rect.color = Color(0.85, 0.92, 1.0, current)
	_flash_rect.visible = current > 0.003
