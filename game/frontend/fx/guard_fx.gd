class_name GuardFx
extends Node2D
## The drawing of Kenzo's guard (Phase 15e-1), all by code. UP: a shield-like aura of segmented arcs round the body (one
## segment per breaking hit left) and a meter of small shield boxes above the head, so the state reads without color. A blocked hit
## makes a spark and the aura flares. STAGGER: the aura is broken into drifting shards, stars circle the head and a dashed pale
## outline pulses (the window where everything hurts). REGEN: a thin dotted ring that closes while the guard comes back.
## Child of the boss; it reads the BossGuard next to it and changes no gameplay value.

const SHIELD := Color(0.78, 0.9, 1.0)
const SHIELD_DARK := Color(0.2, 0.3, 0.5)
const STAR := Color(1.0, 0.95, 0.6)
const INK := Color(0.106, 0.098, 0.122)

var _guard: BossGuard = null
var _boss: BossBase = null
var _clock: float = 0.0
var _flare: float = 0.0
var _sparks: Array = []
## The "BLOQUEADO" tags floating over a blocked hit (position, seconds left). Kept in reduced mode too (it is information), but
## without the rise and the sparks.
const BLOCK_TEXT: String = "BLOQUEADO"
const BLOCK_TIME: float = 0.8
var block_tags: Array = []
var blocked_count: int = 0
var _reduced: bool = false


func _ready() -> void:
	_boss = get_parent() as BossBase
	z_index = 12
	_reduced = not GameSettings.is_corruption_effects_enabled()
	_guard = _boss.get_node_or_null(^"Guard") as BossGuard if _boss != null else null
	if _guard != null:
		_guard.deflected.connect(_on_deflected)
		_guard.broken.connect(func() -> void: _flare = 1.5)


func _on_deflected(info: DamageInfo) -> void:
	blocked_count += 1
	var tag_side: float = 1.0
	if info.source is Node2D and _boss != null:
		tag_side = 1.0 if (info.source as Node2D).global_position.x >= _boss.global_position.x else -1.0
	block_tags.append({"pos": Vector2(tag_side * 34.0, -34.0), "life": BLOCK_TIME})
	if _reduced:
		return
	_flare = 1.0
	var side: float = 1.0
	if info.source is Node2D and _boss != null:
		side = 1.0 if (info.source as Node2D).global_position.x >= _boss.global_position.x else -1.0
	for i in 7:
		_sparks.append({"pos": Vector2(side * 30.0, -14.0 + randf_range(-14.0, 14.0)), "vel": Vector2(side * randf_range(60.0, 190.0), randf_range(-150.0, 80.0)), "life": 0.3})


func _process(delta: float) -> void:
	_clock += delta
	_flare = maxf(_flare - delta * 3.0, 0.0)
	for spark in _sparks:
		spark["pos"] += (spark["vel"] as Vector2) * delta
		spark["life"] = float(spark["life"]) - delta
	for tag in block_tags:
		tag["life"] = float(tag["life"]) - delta
		if not _reduced:
			tag["pos"] = (tag["pos"] as Vector2) + Vector2(0.0, -30.0) * delta
	block_tags = block_tags.filter(func(t: Dictionary) -> bool: return float(t["life"]) > 0.0)
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["life"]) > 0.0)
	queue_redraw()


func _draw() -> void:
	if _guard == null:
		return
	match _guard.state:
		BossGuard.State.UP:
			_draw_up()
		BossGuard.State.STAGGER:
			_draw_stagger()
		BossGuard.State.REGEN:
			_draw_regen()
	for tag in block_tags:
		_draw_block_tag(tag["pos"], clampf(float(tag["life"]) / 0.3, 0.0, 1.0))
	for spark in _sparks:
		var life: float = float(spark["life"]) / 0.3
		var at: Vector2 = spark["pos"]
		draw_line(at, at - (spark["vel"] as Vector2) * 0.03, Color(1.0, 1.0, 0.85, life), 3.0)


## A small shield with a bar across it and the word BLOQUEADO (shape and text, not color alone).
func _draw_block_tag(at: Vector2, alpha: float) -> void:
	var font: Font = GameFonts.BODY
	var shield := PackedVector2Array([at + Vector2(-9.0, -18.0), at + Vector2(9.0, -18.0), at + Vector2(9.0, -6.0), at + Vector2(0.0, 2.0), at + Vector2(-9.0, -6.0)])
	draw_colored_polygon(shield, Color(SHIELD, 0.95 * alpha))
	draw_polyline(shield + PackedVector2Array([shield[0]]), Color(INK, alpha), 2.0, true)
	draw_line(at + Vector2(-9.0, -10.0), at + Vector2(9.0, -10.0), Color(INK, alpha), 2.0)
	var text_at: Vector2 = at + Vector2(14.0, -6.0)
	draw_string_outline(font, text_at, BLOCK_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(INK, alpha))
	draw_string(font, text_at, BLOCK_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 1.0, 1.0, alpha))


func _center() -> Vector2:
	return Vector2(0.0, -14.0)


func _draw_up() -> void:
	var total: int = _guard.guard_break_hits
	var left: int = total - _guard.break_hits
	var center: Vector2 = _center()
	var radius: float = 52.0 + 4.0 * _flare
	draw_circle(center, radius, Color(SHIELD, 0.08 + 0.1 * _flare))
	# One arc segment per breaking hit left; a segment already broken is just a dim stub.
	for i in total:
		var start: float = -PI * 0.5 + float(i) * TAU / float(total) + 0.06
		var finish: float = start + TAU / float(total) - 0.12
		var alive: bool = i < left
		draw_arc(center, radius, start, finish, 18, Color(INK, 0.9), 7.0, true)
		draw_arc(center, radius, start, finish, 18, Color(SHIELD, 0.95 if alive else 0.25), 4.0, true)
	# The meter above the head: shield boxes (filled = guard left).
	var box: float = 12.0
	var gap: float = 5.0
	var start_x: float = -(float(total) * (box + gap) - gap) * 0.5
	for i in total:
		var rect := Rect2(start_x + float(i) * (box + gap), -92.0, box, box + 2.0)
		draw_rect(rect.grow(2.0), Color(INK, 0.9))
		draw_rect(rect, Color(SHIELD, 0.95) if i < left else Color(SHIELD_DARK, 0.9))
		if i < left:
			draw_line(rect.position + Vector2(box * 0.5, 2.0), rect.position + Vector2(box * 0.5, box), Color(INK, 0.7), 1.5)


func _draw_stagger() -> void:
	var center: Vector2 = _center()
	var pulse: float = 0.5 + 0.5 * sin(_clock * 10.0)
	# Shards of the broken aura drift outward.
	for i in 8:
		var angle: float = float(i) * TAU / 8.0 + _clock * 0.6
		var distance: float = 52.0 + 8.0 * sin(_clock * 3.0 + float(i))
		var at: Vector2 = center + Vector2(cos(angle), sin(angle)) * distance
		var along: Vector2 = Vector2(-sin(angle), cos(angle)) * 8.0
		draw_line(at - along, at + along, Color(INK, 0.85), 5.0, true)
		draw_line(at - along, at + along, Color(SHIELD, 0.7), 2.5, true)
	# Stars circle the head; a dashed pale outline pulses round the body.
	for i in 3:
		var angle: float = _clock * 4.0 + float(i) * TAU / 3.0
		var at: Vector2 = Vector2(cos(angle) * 22.0, -62.0 + sin(angle) * 6.0)
		_star(at, 7.0)
	var dash: int = 18
	for i in dash:
		var start: float = float(i) * TAU / float(dash) + _clock * 0.8
		draw_arc(center, 48.0, start, start + TAU / float(dash) * 0.55, 6, Color(STAR, 0.55 + 0.4 * pulse), 3.0, true)


func _draw_regen() -> void:
	var center: Vector2 = _center()
	var progress: float = 1.0 - clampf(_guard.time_left / maxf(_guard.regen_delay, 0.001), 0.0, 1.0)
	var dots: int = 20
	for i in dots:
		var angle: float = -PI * 0.5 + float(i) * TAU / float(dots)
		var filled: bool = float(i) / float(dots) <= progress
		draw_circle(center + Vector2(cos(angle), sin(angle)) * 50.0, 2.6 if filled else 1.6, Color(SHIELD, 0.85 if filled else 0.3))


func _star(at: Vector2, size: float) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var radius: float = size if i % 2 == 0 else size * 0.45
		var angle: float = -PI * 0.5 + float(i) * TAU / 10.0
		points.append(at + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, STAR)
	draw_polyline(points + PackedVector2Array([points[0]]), INK, 1.5, true)
