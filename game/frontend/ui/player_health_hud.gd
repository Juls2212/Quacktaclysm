class_name PlayerHealthHud
extends CanvasLayer
## Health display: a stone bar drawn in code. A round stone on the left holds a beating heart
## that cracks, splits, grows moss and goes dark as health runs out; inside the chipped frame the
## children of Pips are the segments of one continuous red bar (one per health point). An empty
## segment is a black hole, and the stone above it crumbles and sprouts moss. Losing a point
## shatters its segment into falling bits and shakes the bar; healing fills it left to right with a
## flash. WaveBar (the sword-wave cooldown) is a thin stone bar below with a pale blue fill.
## Bound to a player; the player knows nothing about this HUD.

const RED_LIGHT := Color("ff5a4a")
const RED_MID := Color("d42a22")
const RED_DARK := Color("8a1410")
const RED_SHINE := Color(1.0, 0.78, 0.72, 0.8)
const WAVE_LIGHT := Color("c8f4ff")
const WAVE_MID := Color("74d2f2")
const WAVE_DARK := Color("2e8cb6")
const SHAKE_TIME: float = 0.2
const FILL_TIME: float = 0.3

@export var pip_size: Vector2 = Vector2(22.0, 18.0)
@export var full_color: Color = Color(0.9, 0.2, 0.25, 1.0)
@export var empty_color: Color = Color(0.2, 0.2, 0.25, 0.7)

var current_health: int = 0
var max_health: int = 0

var _health: HealthComponent
var _caster: SwordWaveCaster = null
var _drawer: Control = null
var _time: float = 0.0
var _shown_once: bool = false
## Per segment: how full it is drawn (0..1), seconds to wait before filling, flash, time empty.
var _fill: Array[float] = []
var _delay: Array[float] = []
var _flash: Array[float] = []
var _empty_t: Array[float] = []
var _shards: Array = []
var _shake: float = 0.0
var _rng := RandomNumberGenerator.new()

@onready var pips: HBoxContainer = $Pips
@onready var wave_bar: ProgressBar = $WaveBar


## One health point: a segment of the bar (drawn by the HUD).
class Segment extends Control:
	var filled: bool = false


func _ready() -> void:
	_rng.seed = 5150
	_drawer = Control.new()
	_drawer.name = "StoneBar"
	_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drawer)
	move_child(_drawer, 0)
	_drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawer.draw.connect(_draw_hud)
	# The cooldown bar keeps its value and tint; the stone drawing replaces its own look.
	wave_bar.add_theme_stylebox_override(&"background", StyleBoxEmpty.new())
	wave_bar.add_theme_stylebox_override(&"fill", StyleBoxEmpty.new())


func bind(player: Player) -> void:
	if _health:
		_health.health_changed.disconnect(_on_health_changed)
	_health = player.health
	_health.health_changed.connect(_on_health_changed)
	_on_health_changed(_health.current_health, _health.max_health)
	_caster = player.wave_caster
	wave_bar.visible = _caster != null
	_update_wave_bar()


func _process(delta: float) -> void:
	_update_wave_bar()
	_time += delta
	_shake = maxf(_shake - delta, 0.0)
	for i in _fill.size():
		if _delay[i] > 0.0:
			_delay[i] -= delta
		elif i < pips.get_child_count() and _is_filled(i) and _fill[i] < 1.0:
			_fill[i] = minf(_fill[i] + delta / FILL_TIME, 1.0)
			if _fill[i] >= 1.0:
				_flash[i] = 1.0
		_flash[i] = maxf(_flash[i] - delta * 3.0, 0.0)
		_empty_t[i] = _empty_t[i] + delta if not _is_filled(i) else 0.0
	for i in range(_shards.size() - 1, -1, -1):
		var s: Dictionary = _shards[i]
		s["life"] = float(s["life"]) - delta
		if float(s["life"]) <= 0.0:
			_shards.remove_at(i)
			continue
		var v: Vector2 = s["v"]
		v.y += 520.0 * delta
		s["v"] = v
		s["p"] = (s["p"] as Vector2) + v * delta
		s["rot"] = float(s["rot"]) + float(s["spin"]) * delta
	if _drawer != null:
		_drawer.queue_redraw()


## 1.0 = ready; fills up while the wave cooldown runs. Tinted by the current wave tier.
func _update_wave_bar() -> void:
	if _caster == null or not is_instance_valid(_caster):
		wave_bar.visible = false
		return
	var total: float = _caster.get_cooldown_total()
	var remaining: float = _caster.get_cooldown_remaining()
	wave_bar.value = 1.0 if remaining <= 0.0 or total <= 0.0 else 1.0 - remaining / total
	wave_bar.modulate = _caster.get_tint()


func filled_pips() -> int:
	var count: int = 0
	for pip in pips.get_children():
		if pip is Segment and (pip as Segment).filled:
			count += 1
	return count


func _is_filled(i: int) -> bool:
	var pip: Node = pips.get_child(i)
	return pip is Segment and (pip as Segment).filled


func _on_health_changed(current: int, maximum: int) -> void:
	var before: int = current_health
	current_health = current
	max_health = maximum
	while pips.get_child_count() < maximum:
		var pip := Segment.new()
		pip.custom_minimum_size = pip_size
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	while pips.get_child_count() > maximum:
		var extra: Node = pips.get_child(pips.get_child_count() - 1)
		pips.remove_child(extra)
		extra.queue_free()
	var count: int = pips.get_child_count()
	_fill.resize(count)
	_delay.resize(count)
	_flash.resize(count)
	_empty_t.resize(count)
	for i in count:
		(pips.get_child(i) as Segment).filled = i < current
	if not _shown_once:
		for i in count:
			_fill[i] = 1.0 if i < current else 0.0
			_delay[i] = 0.0
			_flash[i] = 0.0
			_empty_t[i] = 2.0
		_shown_once = true
		return
	for i in range(current, mini(before, count)):
		_break_segment(i)
	for i in range(maxi(before, 0), mini(current, count)):
		_fill[i] = 0.0
		_delay[i] = float(i - before) * 0.06
		_empty_t[i] = 0.0


## The lost segment shatters into falling red bits and the bar shakes.
func _break_segment(i: int) -> void:
	_fill[i] = 0.0
	_flash[i] = 0.0
	_shake = SHAKE_TIME
	var rect: Rect2 = (pips.get_child(i) as Control).get_global_rect()
	for k in _rng.randi_range(4, 6):
		var at := Vector2(rect.position.x + _rng.randf() * rect.size.x, rect.position.y + _rng.randf() * rect.size.y)
		_shards.append({"p": at, "v": Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-150.0, -50.0)),
				"rot": _rng.randf() * TAU, "spin": _rng.randf_range(-9.0, 9.0), "size": _rng.randf_range(3.0, 5.5),
				"life": 0.7, "max": 0.7})


func _draw_hud() -> void:
	var count: int = pips.get_child_count()
	if count == 0:
		return
	var off := Vector2.ZERO
	if _shake > 0.0:
		var k: float = _shake / SHAKE_TIME
		off = Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-2.0, 2.0)) * k
	var first: Rect2 = (pips.get_child(0) as Control).get_global_rect()
	var last: Rect2 = (pips.get_child(count - 1) as Control).get_global_rect()
	var bar := Rect2(first.position + off, Vector2(last.end.x - first.position.x, first.size.y))
	StoneUi.frame(_drawer, bar, 7.0, 11)
	StoneUi.well(_drawer, bar)
	for i in count:
		var seg: Rect2 = (pips.get_child(i) as Control).get_global_rect()
		seg.position += off
		var amount: float = clampf(_fill[i], 0.0, 1.0) if i < _fill.size() else 0.0
		if amount > 0.0:
			StoneUi.fill(_drawer, Rect2(seg.position, Vector2(seg.size.x * amount, seg.size.y)), RED_LIGHT, RED_MID, RED_DARK, RED_SHINE)
			if amount < 1.0:
				# The bright leading edge while it fills.
				var x: float = seg.position.x + seg.size.x * amount
				_drawer.draw_line(Vector2(x, seg.position.y + 1.0), Vector2(x, seg.end.y - 1.0), Color(1.0, 0.95, 0.8, 0.9), 2.0, true)
		if i < _flash.size() and _flash[i] > 0.0:
			_drawer.draw_rect(seg.grow(-1.0), Color(1.0, 0.95, 0.85, 0.7 * _flash[i]))
		if i > 0:
			_drawer.draw_line(Vector2(seg.position.x, seg.position.y + 1.0), Vector2(seg.position.x, seg.end.y - 1.0), Color(0.18, 0.03, 0.04, 0.85), 1.4, true)
		if not _is_filled(i):
			_draw_crumbled(seg, bar.position.y - 7.0, i)
	_draw_heart(Vector2(bar.position.x - 31.0, bar.get_center().y))
	if wave_bar.visible:
		var wr: Rect2 = wave_bar.get_global_rect()
		wr.position += off * 0.5
		StoneUi.frame(_drawer, wr, 4.0, 23)
		StoneUi.well(_drawer, wr)
		var tint: Color = wave_bar.modulate
		StoneUi.fill(_drawer, Rect2(wr.position, Vector2(wr.size.x * clampf(float(wave_bar.value), 0.0, 1.0), wr.size.y)),
				WAVE_LIGHT * tint, WAVE_MID * tint, WAVE_DARK * tint, Color(1, 1, 1, 0.6))
	for s in _shards:
		var a: float = clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
		var p: Vector2 = s["p"]
		var sz: float = s["size"]
		var rot: float = s["rot"]
		var quad := PackedVector2Array([p + Vector2(-sz, -sz * 0.6).rotated(rot), p + Vector2(sz * 0.8, -sz * 0.7).rotated(rot),
				p + Vector2(sz * 0.6, sz * 0.7).rotated(rot), p + Vector2(-sz * 0.7, sz * 0.5).rotated(rot)])
		_drawer.draw_colored_polygon(quad, Color(RED_MID.lerp(RED_LIGHT, 0.3), a))
		var ring := PackedVector2Array(quad)
		ring.append(quad[0])
		_drawer.draw_polyline(ring, Color(StoneUi.INK, a), 1.4, true)


## Over an empty segment the frame crumbles (black bites) and moss sprouts from it.
func _draw_crumbled(seg: Rect2, frame_top: float, i: int) -> void:
	var grow: float = clampf((_empty_t[i] if i < _empty_t.size() else 2.0) / 1.2, 0.0, 1.0)
	for k in 2:
		var x: float = seg.position.x + seg.size.x * (0.25 + 0.5 * float(k)) + (StoneUi.hash01(i * 7 + k) - 0.5) * 4.0
		var w: float = 3.0 + StoneUi.hash01(i * 7 + k + 3) * 3.0
		var bite := PackedVector2Array([Vector2(x - w, frame_top + 0.5), Vector2(x + w, frame_top + 0.5), Vector2(x + w * 0.4, frame_top + 4.5 + w * 0.3),
				Vector2(x - w * 0.5, frame_top + 3.5)])
		_drawer.draw_colored_polygon(bite, StoneUi.WELL)
	if grow <= 0.02:
		return
	for k in 4:
		var x: float = seg.position.x + 3.0 + (seg.size.x - 6.0) * (float(k) + StoneUi.hash01(i * 13 + k)) / 4.0
		var h: float = (4.0 + StoneUi.hash01(i * 13 + k + 5) * 5.0) * grow
		var lean: float = (StoneUi.hash01(i * 13 + k + 9) - 0.5) * 4.0 + sin(_time * 2.0 + float(k + i)) * 0.6
		var base := Vector2(x, frame_top + 2.0)
		_drawer.draw_line(base, base + Vector2(lean, -h), StoneUi.INK, 3.0, true)
		_drawer.draw_line(base, base + Vector2(lean, -h), StoneUi.MOSS if k % 2 == 0 else StoneUi.MOSS_DARK, 1.6, true)


## The heart in its round stone: beats (faster when low) and wears down with the health left.
func _draw_heart(c: Vector2) -> void:
	StoneUi.round_stone(_drawer, c, 25.0, 5)
	var ratio: float = float(current_health) / float(max_health) if max_health > 0 else 0.0
	var beat: float = 0.0
	if current_health > 0:
		var rate: float = lerpf(1.1, 2.6, 1.0 - ratio)
		var ph: float = fposmod(_time * rate, 1.0)
		beat = exp(-pow((ph - 0.1) * 14.0, 2.0)) + 0.6 * exp(-pow((ph - 0.3) * 14.0, 2.0))
	var s: float = 0.8 * (1.0 + 0.08 * beat)
	var base: Color
	if current_health <= 0:
		base = Color(0.16, 0.1, 0.1)
	elif ratio <= 0.25:
		base = Color(0.5, 0.08, 0.07)
	else:
		base = Color(0.91, 0.2, 0.16)
	var right := _heart_half(c, s, true)
	var left := _heart_half(c, s, false)
	if ratio <= 0.5 and ratio > 0.25 and current_health > 0:
		# Split down the middle: the right half has gone dark and slipped.
		var shifted := PackedVector2Array()
		for p in right:
			shifted.append(p + Vector2(1.5, 1.0))
		_drawer.draw_colored_polygon(left, base)
		_drawer.draw_colored_polygon(shifted, Color(0.3, 0.07, 0.06))
		_outline(left, 2.4)
		_outline(shifted, 2.4)
	else:
		var whole: PackedVector2Array = _heart_full(c, s)
		_drawer.draw_colored_polygon(whole, base)
		_outline(whole, 2.6)
	if current_health > 0 and ratio > 0.25:
		_drawer.draw_circle(c + Vector2(-7.0, -6.0) * s / 0.8, 3.0, Color(1.0, 0.85, 0.8, 0.85))
	if ratio <= 0.75 and current_health > 0:
		_drawer.draw_polyline(PackedVector2Array([c + Vector2(-9, -8), c + Vector2(-4, -2), c + Vector2(-8, 3), c + Vector2(-2, 8)]), StoneUi.INK, 2.0, true)
	if ratio <= 0.25 and current_health > 0:
		for k in 3:
			var at: Vector2 = c + Vector2(-7.0 + float(k) * 6.5, 8.0 - absf(float(k) - 1.0) * 3.5)
			_drawer.draw_circle(at, 2.8, StoneUi.MOSS_DARK)
			_drawer.draw_circle(at + Vector2(-0.6, -0.6), 1.5, StoneUi.MOSS)


func _heart_full(c: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var t: float = TAU * float(i) / 28.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y + 1.5) * s)
	return pts


## Half a heart (right or left of its axis), closed along a jagged line down the middle.
func _heart_half(c: Vector2, s: float, right: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps: int = 14
	for i in steps + 1:
		var t: float = PI * float(i) / float(steps) + (0.0 if right else PI)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y + 1.5) * s)
	# Back along the middle with a little zigzag.
	var tip: Vector2 = pts[pts.size() - 1]
	var notch: Vector2 = pts[0]
	for k in range(1, 4):
		var u: float = float(k) / 4.0
		var p: Vector2 = tip.lerp(notch, u)
		pts.append(p + Vector2((1.2 if k % 2 == 0 else -1.2) * (1.0 if right else -1.0), 0.0))
	return pts


func _outline(pts: PackedVector2Array, w: float) -> void:
	var ring := PackedVector2Array(pts)
	ring.append(pts[0])
	_drawer.draw_polyline(ring, StoneUi.INK, w, true)
